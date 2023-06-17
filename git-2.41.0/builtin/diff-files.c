/*
 * GIT - The information manager from hell
 *
 * Copyright (C) Linus Torvalds, 2005
 */
#include "cache.h"
#include "config.h"
#include "diff.h"
#include "diff-merges.h"
#include "commit.h"
#include "revision.h"
#include "builtin.h"
#include "submodule.h"

static const char diff_files_usage[] =
"git diff-files [-q] [-0 | -1 | -2 | -3 | -c | --cc] [<common-diff-options>] [<path>...]"
"\n"
COMMON_DIFF_OPTIONS_HELP;

int cmd_diff_files(int argc, const char **argv, const char *prefix)
{
	struct rev_info rev;
	int result;
	unsigned options = 0;

	if (argc == 2 && !strcmp(argv[1], "-h"))
		usage(diff_files_usage);

	git_config(git_diff_basic_config, NULL); /* no "diff" UI options */

	prepare_repo_settings(the_repository);
	the_repository->settings.command_requires_full_index = 0;

	repo_init_revisions(the_repository, &rev, prefix);
	rev.abbrev = 0;

	/*
	 * Consider "intent-to-add" files as new by default, unless
	 * explicitly specified in the command line or anywhere else.
	 */
	rev.diffopt.ita_invisible_in_index = 1;

	prefix = precompose_argv_prefix(argc, argv, prefix);

	argc = setup_revisions(argc, argv, &rev, NULL);
	while (1 < argc && argv[1][0] == '-') {
		if (!strcmp(argv[1], "--base"))
			rev.max_count = 1;
		else if (!strcmp(argv[1], "--ours"))
			rev.max_count = 2;
		else if (!strcmp(argv[1], "--theirs"))
			rev.max_count = 3;
		else if (!strcmp(argv[1], "-q"))
			options |= DIFF_SILENT_ON_REMOVED;
		else
			usage(diff_files_usage);
		argv++; argc--;
	}
	if (!rev.diffopt.output_format)
		rev.diffopt.output_format = DIFF_FORMAT_RAW;
	rev.diffopt.rotate_to_strict = 1;

	/*
	 * Make sure there are NO revision (i.e. pending object) parameter,
	 * rev.max_count is reasonable (0 <= n <= 3), and
	 * there is no other revision filtering parameters.
	 */
	if (rev.pending.nr ||
	    rev.min_age != -1 || rev.max_age != -1 ||
	    3 < rev.max_count)
		usage(diff_files_usage);

	/*
	 * "diff-files --base -p" should not combine merges because it
	 * was not asked to.  "diff-files -c -p" should not densify
	 * (the user should ask with "diff-files --cc" explicitly).
	 */
	if (rev.max_count == -1 &&
	    (rev.diffopt.output_format & DIFF_FORMAT_PATCH))
		diff_merges_set_dense_combined_if_unset(&rev);

	if (repo_read_index_preload(the_repository, &rev.diffopt.pathspec, 0) < 0) {
		perror("repo_read_index_preload");
		result = -1;
		goto cleanup;
	}
	result = run_diff_files(&rev, options);
	result = diff_result_code(&rev.diffopt, result);
cleanup:
	release_revisions(&rev);
	return result;
}
