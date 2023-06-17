#!/bin/sh

test_description='git for-each-repo builtin'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'run based on configured value' '
	git init one &&
	git init two &&
	git init three &&
	git init ~/four &&
	git -C two commit --allow-empty -m "DID NOT RUN" &&
	git config run.key "$TRASH_DIRECTORY/one" &&
	git config --add run.key "$TRASH_DIRECTORY/three" &&
	git config --add run.key "~/four" &&
	git for-each-repo --config=run.key commit --allow-empty -m "ran" &&
	git -C one log -1 --pretty=format:%s >message &&
	grep ran message &&
	git -C two log -1 --pretty=format:%s >message &&
	! grep ran message &&
	git -C three log -1 --pretty=format:%s >message &&
	grep ran message &&
	git -C ~/four log -1 --pretty=format:%s >message &&
	grep ran message &&
	git for-each-repo --config=run.key -- commit --allow-empty -m "ran again" &&
	git -C one log -1 --pretty=format:%s >message &&
	grep again message &&
	git -C two log -1 --pretty=format:%s >message &&
	! grep again message &&
	git -C three log -1 --pretty=format:%s >message &&
	grep again message &&
	git -C ~/four log -1 --pretty=format:%s >message &&
	grep again message
'

test_expect_success 'do nothing on empty config' '
	# the whole thing would fail if for-each-ref iterated even
	# once, because "git help --no-such-option" would fail
	git for-each-repo --config=bogus.config -- help --no-such-option
'

test_expect_success 'error on bad config keys' '
	test_expect_code 129 git for-each-repo --config=a &&
	test_expect_code 129 git for-each-repo --config=a.b. &&
	test_expect_code 129 git for-each-repo --config="'\''.b"
'

test_expect_success 'error on NULL value for config keys' '
	cat >>.git/config <<-\EOF &&
	[empty]
		key
	EOF
	cat >expect <<-\EOF &&
	error: missing value for '\''empty.key'\''
	EOF
	test_expect_code 129 git for-each-repo --config=empty.key 2>actual.raw &&
	grep ^error actual.raw >actual &&
	test_cmp expect actual
'

test_done
