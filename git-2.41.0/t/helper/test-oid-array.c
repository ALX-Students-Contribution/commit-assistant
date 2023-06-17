#include "test-tool.h"
#include "hex.h"
#include "oid-array.h"
#include "setup.h"
#include "strbuf.h"

static int print_oid(const struct object_id *oid, void *data)
{
	puts(oid_to_hex(oid));
	return 0;
}

int cmd__oid_array(int argc UNUSED, const char **argv UNUSED)
{
	struct oid_array array = OID_ARRAY_INIT;
	struct strbuf line = STRBUF_INIT;
	int nongit_ok;

	setup_git_directory_gently(&nongit_ok);

	while (strbuf_getline(&line, stdin) != EOF) {
		const char *arg;
		struct object_id oid;

		if (skip_prefix(line.buf, "append ", &arg)) {
			if (get_oid_hex(arg, &oid))
				die("not a hexadecimal oid: %s", arg);
			oid_array_append(&array, &oid);
		} else if (skip_prefix(line.buf, "lookup ", &arg)) {
			if (get_oid_hex(arg, &oid))
				die("not a hexadecimal oid: %s", arg);
			printf("%d\n", oid_array_lookup(&array, &oid));
		} else if (!strcmp(line.buf, "clear"))
			oid_array_clear(&array);
		else if (!strcmp(line.buf, "for_each_unique"))
			oid_array_for_each_unique(&array, print_oid, NULL);
		else
			die("unknown command: %s", line.buf);
	}

	strbuf_release(&line);
	oid_array_clear(&array);

	return 0;
}
