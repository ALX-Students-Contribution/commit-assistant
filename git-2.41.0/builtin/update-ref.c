#include "cache.h"
#include "config.h"
#include "gettext.h"
#include "hash.h"
#include "refs.h"
#include "builtin.h"
#include "object-name.h"
#include "parse-options.h"
#include "quote.h"
#include "repository.h"
#include "strvec.h"

static const char * const git_update_ref_usage[] = {
	N_("git update-ref [<options>] -d <refname> [<old-val>]"),
	N_("git update-ref [<options>]    <refname> <new-val> [<old-val>]"),
	N_("git update-ref [<options>] --stdin [-z]"),
	NULL
};

static char line_termination = '\n';
static unsigned int update_flags;
static unsigned int default_flags;
static unsigned create_reflog_flag;
static const char *msg;

/*
 * Parse one whitespace- or NUL-terminated, possibly C-quoted argument
 * and append the result to arg.  Return a pointer to the terminator.
 * Die if there is an error in how the argument is C-quoted.  This
 * function is only used if not -z.
 */
static const char *parse_arg(const char *next, struct strbuf *arg)
{
	if (*next == '"') {
		const char *orig = next;

		if (unquote_c_style(arg, next, &next))
			die("badly quoted argument: %s", orig);
		if (*next && !isspace(*next))
			die("unexpected character after quoted argument: %s", orig);
	} else {
		while (*next && !isspace(*next))
			strbuf_addch(arg, *next++);
	}

	return next;
}

/*
 * Parse the reference name immediately after "command SP".  If not
 * -z, then handle C-quoting.  Return a pointer to a newly allocated
 * string containing the name of the reference, or NULL if there was
 * an error.  Update *next to point at the character that terminates
 * the argument.  Die if C-quoting is malformed or the reference name
 * is invalid.
 */
static char *parse_refname(const char **next)
{
	struct strbuf ref = STRBUF_INIT;

	if (line_termination) {
		/* Without -z, use the next argument */
		*next = parse_arg(*next, &ref);
	} else {
		/* With -z, use everything up to the next NUL */
		strbuf_addstr(&ref, *next);
		*next += ref.len;
	}

	if (!ref.len) {
		strbuf_release(&ref);
		return NULL;
	}

	if (check_refname_format(ref.buf, REFNAME_ALLOW_ONELEVEL))
		die("invalid ref format: %s", ref.buf);

	return strbuf_detach(&ref, NULL);
}

/*
 * The value being parsed is <oldvalue> (as opposed to <newvalue>; the
 * difference affects which error messages are generated):
 */
#define PARSE_SHA1_OLD 0x01

/*
 * For backwards compatibility, accept an empty string for update's
 * <newvalue> in binary mode to be equivalent to specifying zeros.
 */
#define PARSE_SHA1_ALLOW_EMPTY 0x02

/*
 * Parse an argument separator followed by the next argument, if any.
 * If there is an argument, convert it to a SHA-1, write it to sha1,
 * set *next to point at the character terminating the argument, and
 * return 0.  If there is no argument at all (not even the empty
 * string), return 1 and leave *next unchanged.  If the value is
 * provided but cannot be converted to a SHA-1, die.  flags can
 * include PARSE_SHA1_OLD and/or PARSE_SHA1_ALLOW_EMPTY.
 */
static int parse_next_oid(const char **next, const char *end,
			  struct object_id *oid,
			  const char *command, const char *refname,
			  int flags)
{
	struct strbuf arg = STRBUF_INIT;
	int ret = 0;

	if (*next == end)
		goto eof;

	if (line_termination) {
		/* Without -z, consume SP and use next argument */
		if (!**next || **next == line_termination)
			return 1;
		if (**next != ' ')
			die("%s %s: expected SP but got: %s",
			    command, refname, *next);
		(*next)++;
		*next = parse_arg(*next, &arg);
		if (arg.len) {
			if (repo_get_oid(the_repository, arg.buf, oid))
				goto invalid;
		} else {
			/* Without -z, an empty value means all zeros: */
			oidclr(oid);
		}
	} else {
		/* With -z, read the next NUL-terminated line */
		if (**next)
			die("%s %s: expected NUL but got: %s",
			    command, refname, *next);
		(*next)++;
		if (*next == end)
			goto eof;
		strbuf_addstr(&arg, *next);
		*next += arg.len;

		if (arg.len) {
			if (repo_get_oid(the_repository, arg.buf, oid))
				goto invalid;
		} else if (flags & PARSE_SHA1_ALLOW_EMPTY) {
			/* With -z, treat an empty value as all zeros: */
			warning("%s %s: missing <newvalue>, treating as zero",
				command, refname);
			oidclr(oid);
		} else {
			/*
			 * With -z, an empty non-required value means
			 * unspecified:
			 */
			ret = 1;
		}
	}

	strbuf_release(&arg);

	return ret;

 invalid:
	die(flags & PARSE_SHA1_OLD ?
	    "%s %s: invalid <oldvalue>: %s" :
	    "%s %s: invalid <newvalue>: %s",
	    command, refname, arg.buf);

 eof:
	die(flags & PARSE_SHA1_OLD ?
	    "%s %s: unexpected end of input when reading <oldvalue>" :
	    "%s %s: unexpected end of input when reading <newvalue>",
	    command, refname);
}


/*
 * The following five parse_cmd_*() functions parse the corresponding
 * command.  In each case, next points at the character following the
 * command name and the following space.  They each return a pointer
 * to the character terminating the command, and die with an
 * explanatory message if there are any parsing problems.  All of
 * these functions handle either text or binary format input,
 * depending on how line_termination is set.
 */

static void parse_cmd_update(struct ref_transaction *transaction,
			     const char *next, const char *end)
{
	struct strbuf err = STRBUF_INIT;
	char *refname;
	struct object_id new_oid, old_oid;
	int have_old;

	refname = parse_refname(&next);
	if (!refname)
		die("update: missing <ref>");

	if (parse_next_oid(&next, end, &new_oid, "update", refname,
			   PARSE_SHA1_ALLOW_EMPTY))
		die("update %s: missing <newvalue>", refname);

	have_old = !parse_next_oid(&next, end, &old_oid, "update", refname,
				   PARSE_SHA1_OLD);

	if (*next != line_termination)
		die("update %s: extra input: %s", refname, next);

	if (ref_transaction_update(transaction, refname,
				   &new_oid, have_old ? &old_oid : NULL,
				   update_flags | create_reflog_flag,
				   msg, &err))
		die("%s", err.buf);

	update_flags = default_flags;
	free(refname);
	strbuf_release(&err);
}

static void parse_cmd_create(struct ref_transaction *transaction,
			     const char *next, const char *end)
{
	struct strbuf err = STRBUF_INIT;
	char *refname;
	struct object_id new_oid;

	refname = parse_refname(&next);
	if (!refname)
		die("create: missing <ref>");

	if (parse_next_oid(&next, end, &new_oid, "create", refname, 0))
		die("create %s: missing <newvalue>", refname);

	if (is_null_oid(&new_oid))
		die("create %s: zero <newvalue>", refname);

	if (*next != line_termination)
		die("create %s: extra input: %s", refname, next);

	if (ref_transaction_create(transaction, refname, &new_oid,
				   update_flags | create_reflog_flag,
				   msg, &err))
		die("%s", err.buf);

	update_flags = default_flags;
	free(refname);
	strbuf_release(&err);
}

static void parse_cmd_delete(struct ref_transaction *transaction,
			     const char *next, const char *end)
{
	struct strbuf err = STRBUF_INIT;
	char *refname;
	struct object_id old_oid;
	int have_old;

	refname = parse_refname(&next);
	if (!refname)
		die("delete: missing <ref>");

	if (parse_next_oid(&next, end, &old_oid, "delete", refname,
			   PARSE_SHA1_OLD)) {
		have_old = 0;
	} else {
		if (is_null_oid(&old_oid))
			die("delete %s: zero <oldvalue>", refname);
		have_old = 1;
	}

	if (*next != line_termination)
		die("delete %s: extra input: %s", refname, next);

	if (ref_transaction_delete(transaction, refname,
				   have_old ? &old_oid : NULL,
				   update_flags, msg, &err))
		die("%s", err.buf);

	update_flags = default_flags;
	free(refname);
	strbuf_release(&err);
}

static void parse_cmd_verify(struct ref_transaction *transaction,
			     const char *next, const char *end)
{
	struct strbuf err = STRBUF_INIT;
	char *refname;
	struct object_id old_oid;

	refname = parse_refname(&next);
	if (!refname)
		die("verify: missing <ref>");

	if (parse_next_oid(&next, end, &old_oid, "verify", refname,
			   PARSE_SHA1_OLD))
		oidclr(&old_oid);

	if (*next != line_termination)
		die("verify %s: extra input: %s", refname, next);

	if (ref_transaction_verify(transaction, refname, &old_oid,
				   update_flags, &err))
		die("%s", err.buf);

	update_flags = default_flags;
	free(refname);
	strbuf_release(&err);
}

static void report_ok(const char *command)
{
	fprintf(stdout, "%s: ok\n", command);
	fflush(stdout);
}

static void parse_cmd_option(struct ref_transaction *transaction,
			     const char *next, const char *end)
{
	const char *rest;
	if (skip_prefix(next, "no-deref", &rest) && *rest == line_termination)
		update_flags |= REF_NO_DEREF;
	else
		die("option unknown: %s", next);
}

static void parse_cmd_start(struct ref_transaction *transaction,
			    const char *next, const char *end)
{
	if (*next != line_termination)
		die("start: extra input: %s", next);
	report_ok("start");
}

static void parse_cmd_prepare(struct ref_transaction *transaction,
			      const char *next, const char *end)
{
	struct strbuf error = STRBUF_INIT;
	if (*next != line_termination)
		die("prepare: extra input: %s", next);
	if (ref_transaction_prepare(transaction, &error))
		die("prepare: %s", error.buf);
	report_ok("prepare");
}

static void parse_cmd_abort(struct ref_transaction *transaction,
			    const char *next, const char *end)
{
	struct strbuf error = STRBUF_INIT;
	if (*next != line_termination)
		die("abort: extra input: %s", next);
	if (ref_transaction_abort(transaction, &error))
		die("abort: %s", error.buf);
	report_ok("abort");
}

static void parse_cmd_commit(struct ref_transaction *transaction,
			     const char *next, const char *end)
{
	struct strbuf error = STRBUF_INIT;
	if (*next != line_termination)
		die("commit: extra input: %s", next);
	if (ref_transaction_commit(transaction, &error))
		die("commit: %s", error.buf);
	report_ok("commit");
	ref_transaction_free(transaction);
}

enum update_refs_state {
	/* Non-transactional state open for updates. */
	UPDATE_REFS_OPEN,
	/* A transaction has been started. */
	UPDATE_REFS_STARTED,
	/* References are locked and ready for commit */
	UPDATE_REFS_PREPARED,
	/* Transaction has been committed or closed. */
	UPDATE_REFS_CLOSED,
};

static const struct parse_cmd {
	const char *prefix;
	void (*fn)(struct ref_transaction *, const char *, const char *);
	unsigned args;
	enum update_refs_state state;
} command[] = {
	{ "update",  parse_cmd_update,  3, UPDATE_REFS_OPEN },
	{ "create",  parse_cmd_create,  2, UPDATE_REFS_OPEN },
	{ "delete",  parse_cmd_delete,  2, UPDATE_REFS_OPEN },
	{ "verify",  parse_cmd_verify,  2, UPDATE_REFS_OPEN },
	{ "option",  parse_cmd_option,  1, UPDATE_REFS_OPEN },
	{ "start",   parse_cmd_start,   0, UPDATE_REFS_STARTED },
	{ "prepare", parse_cmd_prepare, 0, UPDATE_REFS_PREPARED },
	{ "abort",   parse_cmd_abort,   0, UPDATE_REFS_CLOSED },
	{ "commit",  parse_cmd_commit,  0, UPDATE_REFS_CLOSED },
};

static void update_refs_stdin(void)
{
	struct strbuf input = STRBUF_INIT, err = STRBUF_INIT;
	enum update_refs_state state = UPDATE_REFS_OPEN;
	struct ref_transaction *transaction;
	int i, j;

	transaction = ref_transaction_begin(&err);
	if (!transaction)
		die("%s", err.buf);

	/* Read each line dispatch its command */
	while (!strbuf_getwholeline(&input, stdin, line_termination)) {
		const struct parse_cmd *cmd = NULL;

		if (*input.buf == line_termination)
			die("empty command in input");
		else if (isspace(*input.buf))
			die("whitespace before command: %s", input.buf);

		for (i = 0; i < ARRAY_SIZE(command); i++) {
			const char *prefix = command[i].prefix;
			char c;

			if (!starts_with(input.buf, prefix))
				continue;

			/*
			 * If the command has arguments, verify that it's
			 * followed by a space. Otherwise, it shall be followed
			 * by a line terminator.
			 */
			c = command[i].args ? ' ' : line_termination;
			if (input.buf[strlen(prefix)] != c)
				continue;

			cmd = &command[i];
			break;
		}
		if (!cmd)
			die("unknown command: %s", input.buf);

		/*
		 * Read additional arguments if NUL-terminated. Do not raise an
		 * error in case there is an early EOF to let the command
		 * handle missing arguments with a proper error message.
		 */
		for (j = 1; line_termination == '\0' && j < cmd->args; j++)
			if (strbuf_appendwholeline(&input, stdin, line_termination))
				break;

		switch (state) {
		case UPDATE_REFS_OPEN:
		case UPDATE_REFS_STARTED:
			if (state == UPDATE_REFS_STARTED && cmd->state == UPDATE_REFS_STARTED)
				die("cannot restart ongoing transaction");
			/* Do not downgrade a transaction to a non-transaction. */
			if (cmd->state >= state)
				state = cmd->state;
			break;
		case UPDATE_REFS_PREPARED:
			if (cmd->state != UPDATE_REFS_CLOSED)
				die("prepared transactions can only be closed");
			state = cmd->state;
			break;
		case UPDATE_REFS_CLOSED:
			if (cmd->state != UPDATE_REFS_STARTED)
				die("transaction is closed");

			/*
			 * Open a new transaction if we're currently closed and
			 * get a "start".
			 */
			state = cmd->state;
			transaction = ref_transaction_begin(&err);
			if (!transaction)
				die("%s", err.buf);

			break;
		}

		cmd->fn(transaction, input.buf + strlen(cmd->prefix) + !!cmd->args,
			input.buf + input.len);
	}

	switch (state) {
	case UPDATE_REFS_OPEN:
		/* Commit by default if no transaction was requested. */
		if (ref_transaction_commit(transaction, &err))
			die("%s", err.buf);
		ref_transaction_free(transaction);
		break;
	case UPDATE_REFS_STARTED:
	case UPDATE_REFS_PREPARED:
		/* If using a transaction, we want to abort it. */
		if (ref_transaction_abort(transaction, &err))
			die("%s", err.buf);
		break;
	case UPDATE_REFS_CLOSED:
		/* Otherwise no need to do anything, the transaction was closed already. */
		break;
	}

	strbuf_release(&err);
	strbuf_release(&input);
}

int cmd_update_ref(int argc, const char **argv, const char *prefix)
{
	const char *refname, *oldval;
	struct object_id oid, oldoid;
	int delete = 0, no_deref = 0, read_stdin = 0, end_null = 0;
	int create_reflog = 0;
	struct option options[] = {
		OPT_STRING( 'm', NULL, &msg, N_("reason"), N_("reason of the update")),
		OPT_BOOL('d', NULL, &delete, N_("delete the reference")),
		OPT_BOOL( 0 , "no-deref", &no_deref,
					N_("update <refname> not the one it points to")),
		OPT_BOOL('z', NULL, &end_null, N_("stdin has NUL-terminated arguments")),
		OPT_BOOL( 0 , "stdin", &read_stdin, N_("read updates from stdin")),
		OPT_BOOL( 0 , "create-reflog", &create_reflog, N_("create a reflog")),
		OPT_END(),
	};

	git_config(git_default_config, NULL);
	argc = parse_options(argc, argv, prefix, options, git_update_ref_usage,
			     0);
	if (msg && !*msg)
		die("Refusing to perform update with empty message.");

	create_reflog_flag = create_reflog ? REF_FORCE_CREATE_REFLOG : 0;

	if (no_deref) {
		default_flags = REF_NO_DEREF;
		update_flags = default_flags;
	}

	if (read_stdin) {
		if (delete || argc > 0)
			usage_with_options(git_update_ref_usage, options);
		if (end_null)
			line_termination = '\0';
		update_refs_stdin();
		return 0;
	}

	if (end_null)
		usage_with_options(git_update_ref_usage, options);

	if (delete) {
		if (argc < 1 || argc > 2)
			usage_with_options(git_update_ref_usage, options);
		refname = argv[0];
		oldval = argv[1];
	} else {
		const char *value;
		if (argc < 2 || argc > 3)
			usage_with_options(git_update_ref_usage, options);
		refname = argv[0];
		value = argv[1];
		oldval = argv[2];
		if (repo_get_oid(the_repository, value, &oid))
			die("%s: not a valid SHA1", value);
	}

	if (oldval) {
		if (!*oldval)
			/*
			 * The empty string implies that the reference
			 * must not already exist:
			 */
			oidclr(&oldoid);
		else if (repo_get_oid(the_repository, oldval, &oldoid))
			die("%s: not a valid old SHA1", oldval);
	}

	if (delete)
		/*
		 * For purposes of backwards compatibility, we treat
		 * NULL_SHA1 as "don't care" here:
		 */
		return delete_ref(msg, refname,
				  (oldval && !is_null_oid(&oldoid)) ? &oldoid : NULL,
				  default_flags);
	else
		return update_ref(msg, refname, &oid, oldval ? &oldoid : NULL,
				  default_flags | create_reflog_flag,
				  UPDATE_REFS_DIE_ON_ERR);
}
