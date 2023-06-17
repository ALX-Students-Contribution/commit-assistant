#!/bin/sh

test_description='verify safe.directory checks'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

GIT_TEST_ASSUME_DIFFERENT_OWNER=1
export GIT_TEST_ASSUME_DIFFERENT_OWNER

expect_rejected_dir () {
	test_must_fail git status 2>err &&
	grep "dubious ownership" err
}

test_expect_success 'safe.directory is not set' '
	expect_rejected_dir
'

test_expect_success 'safe.directory on the command line' '
	git -c safe.directory="$(pwd)" status
'

test_expect_success 'safe.directory in the environment' '
	env GIT_CONFIG_COUNT=1 \
	    GIT_CONFIG_KEY_0="safe.directory" \
	    GIT_CONFIG_VALUE_0="$(pwd)" \
	    git status
'

test_expect_success 'safe.directory in GIT_CONFIG_PARAMETERS' '
	env GIT_CONFIG_PARAMETERS="${SQ}safe.directory${SQ}=${SQ}$(pwd)${SQ}" \
	    git status
'

test_expect_success 'ignoring safe.directory in repo config' '
	(
		unset GIT_TEST_ASSUME_DIFFERENT_OWNER &&
		git config safe.directory "$(pwd)"
	) &&
	expect_rejected_dir
'

test_expect_success 'safe.directory does not match' '
	git config --global safe.directory bogus &&
	expect_rejected_dir
'

test_expect_success 'path exist as different key' '
	git config --global foo.bar "$(pwd)" &&
	expect_rejected_dir
'

test_expect_success 'safe.directory matches' '
	git config --global --add safe.directory "$(pwd)" &&
	git status
'

test_expect_success 'safe.directory matches, but is reset' '
	git config --global --add safe.directory "" &&
	expect_rejected_dir
'

test_expect_success 'safe.directory=*' '
	git config --global --add safe.directory "*" &&
	git status
'

test_expect_success 'safe.directory=*, but is reset' '
	git config --global --add safe.directory "" &&
	expect_rejected_dir
'

test_expect_success 'safe.directory in included file' '
	cat >gitconfig-include <<-EOF &&
	[safe]
		directory = "$(pwd)"
	EOF
	git config --global --add include.path "$(pwd)/gitconfig-include" &&
	git status
'

test_done
