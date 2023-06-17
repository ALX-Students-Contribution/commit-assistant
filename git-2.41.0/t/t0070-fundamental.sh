#!/bin/sh

test_description='check that the most basic functions work


Verify wrappers and compatibility functions.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'character classes (isspace, isalpha etc.)' '
	test-tool ctype
'

test_expect_success 'mktemp to nonexistent directory prints filename' '
	test_must_fail test-tool mktemp doesnotexist/testXXXXXX 2>err &&
	grep "doesnotexist/test" err
'

test_expect_success POSIXPERM,SANITY 'mktemp to unwritable directory prints filename' '
	mkdir cannotwrite &&
	test_when_finished "chmod +w cannotwrite" &&
	chmod -w cannotwrite &&
	test_must_fail test-tool mktemp cannotwrite/testXXXXXX 2>err &&
	grep "cannotwrite/test" err
'

test_expect_success 'git_mkstemps_mode does not fail if fd 0 is not open' '
	git commit --allow-empty -m message <&-
'

test_expect_success 'check for a bug in the regex routines' '
	# if this test fails, re-build git with NO_REGEX=1
	test-tool regex --bug
'

test_expect_success 'incomplete sideband messages are reassembled' '
	test-tool pkt-line send-split-sideband >split-sideband &&
	test-tool pkt-line receive-sideband <split-sideband 2>err &&
	grep "Hello, world" err
'

test_expect_success 'eof on sideband message is reported' '
	printf 1234 >input &&
	test-tool pkt-line receive-sideband <input 2>err &&
	test_i18ngrep "unexpected disconnect" err
'

test_expect_success 'missing sideband designator is reported' '
	printf 0004 >input &&
	test-tool pkt-line receive-sideband <input 2>err &&
	test_i18ngrep "missing sideband" err
'

test_done
