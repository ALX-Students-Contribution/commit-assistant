#!/bin/sh

test_description='test git worktree add'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'setup' '
	test_commit init
'

test_expect_success '"add" an existing worktree' '
	mkdir -p existing/subtree &&
	test_must_fail git worktree add --detach existing main
'

test_expect_success '"add" an existing empty worktree' '
	mkdir existing_empty &&
	git worktree add --detach existing_empty main
'

test_expect_success '"add" using shorthand - fails when no previous branch' '
	test_must_fail git worktree add existing_short -
'

test_expect_success '"add" using - shorthand' '
	git checkout -b newbranch &&
	echo hello >myworld &&
	git add myworld &&
	git commit -m myworld &&
	git checkout main &&
	git worktree add short-hand - &&
	echo refs/heads/newbranch >expect &&
	git -C short-hand rev-parse --symbolic-full-name HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '"add" refuses to checkout locked branch' '
	test_must_fail git worktree add zere main &&
	! test -d zere &&
	! test -d .git/worktrees/zere
'

test_expect_success 'checking out paths not complaining about linked checkouts' '
	(
	cd existing_empty &&
	echo dirty >>init.t &&
	git checkout main -- init.t
	)
'

test_expect_success '"add" worktree' '
	git rev-parse HEAD >expect &&
	git worktree add --detach here main &&
	(
		cd here &&
		test_cmp ../init.t init.t &&
		test_must_fail git symbolic-ref HEAD &&
		git rev-parse HEAD >actual &&
		test_cmp ../expect actual &&
		git fsck
	)
'

test_expect_success '"add" worktree with lock' '
	git worktree add --detach --lock here-with-lock main &&
	test_when_finished "git worktree unlock here-with-lock || :" &&
	test -f .git/worktrees/here-with-lock/locked
'

test_expect_success '"add" worktree with lock and reason' '
	lock_reason="why not" &&
	git worktree add --detach --lock --reason "$lock_reason" here-with-lock-reason main &&
	test_when_finished "git worktree unlock here-with-lock-reason || :" &&
	test -f .git/worktrees/here-with-lock-reason/locked &&
	echo "$lock_reason" >expect &&
	test_cmp expect .git/worktrees/here-with-lock-reason/locked
'

test_expect_success '"add" worktree with reason but no lock' '
	test_must_fail git worktree add --detach --reason "why not" here-with-reason-only main &&
	test_path_is_missing .git/worktrees/here-with-reason-only/locked
'

test_expect_success '"add" worktree from a subdir' '
	(
		mkdir sub &&
		cd sub &&
		git worktree add --detach here main &&
		cd here &&
		test_cmp ../../init.t init.t
	)
'

test_expect_success '"add" from a linked checkout' '
	(
		cd here &&
		git worktree add --detach nested-here main &&
		cd nested-here &&
		git fsck
	)
'

test_expect_success '"add" worktree creating new branch' '
	git worktree add -b newmain there main &&
	(
		cd there &&
		test_cmp ../init.t init.t &&
		git symbolic-ref HEAD >actual &&
		echo refs/heads/newmain >expect &&
		test_cmp expect actual &&
		git fsck
	)
'

test_expect_success 'die the same branch is already checked out' '
	(
		cd here &&
		test_must_fail git checkout newmain
	)
'

test_expect_success SYMLINKS 'die the same branch is already checked out (symlink)' '
	head=$(git -C there rev-parse --git-path HEAD) &&
	ref=$(git -C there symbolic-ref HEAD) &&
	rm "$head" &&
	ln -s "$ref" "$head" &&
	test_must_fail git -C here checkout newmain
'

test_expect_success 'not die the same branch is already checked out' '
	(
		cd here &&
		git worktree add --force anothernewmain newmain
	)
'

test_expect_success 'not die on re-checking out current branch' '
	(
		cd there &&
		git checkout newmain
	)
'

test_expect_success '"add" from a bare repo' '
	(
		git clone --bare . bare &&
		cd bare &&
		git worktree add -b bare-main ../there2 main
	)
'

test_expect_success 'checkout from a bare repo without "add"' '
	(
		cd bare &&
		test_must_fail git checkout main
	)
'

test_expect_success '"add" default branch of a bare repo' '
	(
		git clone --bare . bare2 &&
		cd bare2 &&
		git worktree add ../there3 main &&
		cd ../there3 &&
		# Simple check that a Git command does not
		# immediately fail with the current setup
		git status
	) &&
	cat >expect <<-EOF &&
	init.t
	EOF
	ls there3 >actual &&
	test_cmp expect actual
'

test_expect_success '"add" to bare repo with worktree config' '
	(
		git clone --bare . bare3 &&
		cd bare3 &&
		git config extensions.worktreeconfig true &&

		# Add config values that are erroneous to have in
		# a config.worktree file outside of the main
		# working tree, to check that Git filters them out
		# when copying config during "git worktree add".
		git config --worktree core.bare true &&
		git config --worktree core.worktree "$(pwd)" &&

		# We want to check that bogus.key is copied
		git config --worktree bogus.key value &&
		git config --unset core.bare &&
		git worktree add ../there4 main &&
		cd ../there4 &&

		# Simple check that a Git command does not
		# immediately fail with the current setup
		git status &&
		git worktree add --detach ../there5 &&
		cd ../there5 &&
		git status
	) &&

	# the worktree has the arbitrary value copied.
	test_cmp_config -C there4 value bogus.key &&
	test_cmp_config -C there5 value bogus.key &&

	# however, core.bare and core.worktree were removed.
	test_must_fail git -C there4 config core.bare &&
	test_must_fail git -C there4 config core.worktree &&

	cat >expect <<-EOF &&
	init.t
	EOF

	ls there4 >actual &&
	test_cmp expect actual &&
	ls there5 >actual &&
	test_cmp expect actual
'

test_expect_success 'checkout with grafts' '
	test_when_finished rm .git/info/grafts &&
	test_commit abc &&
	SHA1=$(git rev-parse HEAD) &&
	test_commit def &&
	test_commit xyz &&
	mkdir .git/info &&
	echo "$(git rev-parse HEAD) $SHA1" >.git/info/grafts &&
	cat >expected <<-\EOF &&
	xyz
	abc
	EOF
	git log --format=%s -2 >actual &&
	test_cmp expected actual &&
	git worktree add --detach grafted main &&
	git --git-dir=grafted/.git log --format=%s -2 >actual &&
	test_cmp expected actual
'

test_expect_success '"add" from relative HEAD' '
	test_commit a &&
	test_commit b &&
	test_commit c &&
	git rev-parse HEAD~1 >expected &&
	git worktree add relhead HEAD~1 &&
	git -C relhead rev-parse HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '"add -b" with <branch> omitted' '
	git worktree add -b burble flornk &&
	test_cmp_rev HEAD burble
'

test_expect_success '"add --detach" with <branch> omitted' '
	git worktree add --detach fishhook &&
	git rev-parse HEAD >expected &&
	git -C fishhook rev-parse HEAD >actual &&
	test_cmp expected actual &&
	test_must_fail git -C fishhook symbolic-ref HEAD
'

test_expect_success '"add" with <branch> omitted' '
	git worktree add wiffle/bat &&
	test_cmp_rev HEAD bat
'

test_expect_success '"add" checks out existing branch of dwimd name' '
	git branch dwim HEAD~1 &&
	git worktree add dwim &&
	test_cmp_rev HEAD~1 dwim &&
	(
		cd dwim &&
		test_cmp_rev HEAD dwim
	)
'

test_expect_success '"add <path>" dwim fails with checked out branch' '
	git checkout -b test-branch &&
	test_must_fail git worktree add test-branch &&
	test_path_is_missing test-branch
'

test_expect_success '"add --force" with existing dwimd name doesnt die' '
	git checkout test-branch &&
	git worktree add --force test-branch
'

test_expect_success '"add" no auto-vivify with --detach and <branch> omitted' '
	git worktree add --detach mish/mash &&
	test_must_fail git rev-parse mash -- &&
	test_must_fail git -C mish/mash symbolic-ref HEAD
'

test_expect_success '"add" -b/-B mutually exclusive' '
	test_must_fail git worktree add -b poodle -B poodle bamboo main
'

test_expect_success '"add" -b/--detach mutually exclusive' '
	test_must_fail git worktree add -b poodle --detach bamboo main
'

test_expect_success '"add" -B/--detach mutually exclusive' '
	test_must_fail git worktree add -B poodle --detach bamboo main
'

test_expect_success '"add -B" fails if the branch is checked out' '
	git rev-parse newmain >before &&
	test_must_fail git worktree add -B newmain bamboo main &&
	git rev-parse newmain >after &&
	test_cmp before after
'

test_expect_success 'add -B' '
	git worktree add -B poodle bamboo2 main^ &&
	git -C bamboo2 symbolic-ref HEAD >actual &&
	echo refs/heads/poodle >expected &&
	test_cmp expected actual &&
	test_cmp_rev main^ poodle
'

test_expect_success 'add --quiet' '
	git worktree add --quiet another-worktree main 2>actual &&
	test_must_be_empty actual
'

test_expect_success 'local clone from linked checkout' '
	git clone --local here here-clone &&
	( cd here-clone && git fsck )
'

test_expect_success 'local clone --shared from linked checkout' '
	git -C bare worktree add --detach ../baretree &&
	git clone --local --shared baretree bare-clone &&
	grep /bare/ bare-clone/.git/objects/info/alternates
'

test_expect_success '"add" worktree with --no-checkout' '
	git worktree add --no-checkout -b swamp swamp &&
	! test -e swamp/init.t &&
	git -C swamp reset --hard &&
	test_cmp init.t swamp/init.t
'

test_expect_success '"add" worktree with --checkout' '
	git worktree add --checkout -b swmap2 swamp2 &&
	test_cmp init.t swamp2/init.t
'

test_expect_success 'put a worktree under rebase' '
	git worktree add under-rebase &&
	(
		cd under-rebase &&
		set_fake_editor &&
		FAKE_LINES="edit 1" git rebase -i HEAD^ &&
		git worktree list | grep "under-rebase.*detached HEAD"
	)
'

test_expect_success 'add a worktree, checking out a rebased branch' '
	test_must_fail git worktree add new-rebase under-rebase &&
	! test -d new-rebase
'

test_expect_success 'checking out a rebased branch from another worktree' '
	git worktree add new-place &&
	test_must_fail git -C new-place checkout under-rebase
'

test_expect_success 'not allow to delete a branch under rebase' '
	(
		cd under-rebase &&
		test_must_fail git branch -D under-rebase
	)
'

test_expect_success 'rename a branch under rebase not allowed' '
	test_must_fail git branch -M under-rebase rebase-with-new-name
'

test_expect_success 'check out from current worktree branch ok' '
	(
		cd under-rebase &&
		git checkout under-rebase &&
		git checkout - &&
		git rebase --abort
	)
'

test_expect_success 'checkout a branch under bisect' '
	git worktree add under-bisect &&
	(
		cd under-bisect &&
		git bisect start &&
		git bisect bad &&
		git bisect good HEAD~2 &&
		git worktree list | grep "under-bisect.*detached HEAD" &&
		test_must_fail git worktree add new-bisect under-bisect &&
		! test -d new-bisect
	)
'

test_expect_success 'rename a branch under bisect not allowed' '
	test_must_fail git branch -M under-bisect bisect-with-new-name
'
# Is branch "refs/heads/$1" set to pull from "$2/$3"?
test_branch_upstream () {
	printf "%s\n" "$2" "refs/heads/$3" >expect.upstream &&
	{
		git config "branch.$1.remote" &&
		git config "branch.$1.merge"
	} >actual.upstream &&
	test_cmp expect.upstream actual.upstream
}

test_expect_success '--track sets up tracking' '
	test_when_finished rm -rf track &&
	git worktree add --track -b track track main &&
	test_branch_upstream track . main
'

# setup remote repository $1 and repository $2 with $1 set up as
# remote.  The remote has two branches, main and foo.
setup_remote_repo () {
	git init $1 &&
	(
		cd $1 &&
		test_commit $1_main &&
		git checkout -b foo &&
		test_commit upstream_foo
	) &&
	git init $2 &&
	(
		cd $2 &&
		test_commit $2_main &&
		git remote add $1 ../$1 &&
		git config remote.$1.fetch \
			"refs/heads/*:refs/remotes/$1/*" &&
		git fetch --all
	)
}

test_expect_success '--no-track avoids setting up tracking' '
	test_when_finished rm -rf repo_upstream repo_local foo &&
	setup_remote_repo repo_upstream repo_local &&
	(
		cd repo_local &&
		git worktree add --no-track -b foo ../foo repo_upstream/foo
	) &&
	(
		cd foo &&
		test_must_fail git config "branch.foo.remote" &&
		test_must_fail git config "branch.foo.merge" &&
		test_cmp_rev refs/remotes/repo_upstream/foo refs/heads/foo
	)
'

test_expect_success '"add" <path> <non-existent-branch> fails' '
	test_must_fail git worktree add foo non-existent
'

test_expect_success '"add" <path> <branch> dwims' '
	test_when_finished rm -rf repo_upstream repo_dwim foo &&
	setup_remote_repo repo_upstream repo_dwim &&
	git init repo_dwim &&
	(
		cd repo_dwim &&
		git worktree add ../foo foo
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_upstream foo &&
		test_cmp_rev refs/remotes/repo_upstream/foo refs/heads/foo
	)
'

test_expect_success '"add" <path> <branch> dwims with checkout.defaultRemote' '
	test_when_finished rm -rf repo_upstream repo_dwim foo &&
	setup_remote_repo repo_upstream repo_dwim &&
	git init repo_dwim &&
	(
		cd repo_dwim &&
		git remote add repo_upstream2 ../repo_upstream &&
		git fetch repo_upstream2 &&
		test_must_fail git worktree add ../foo foo &&
		git -c checkout.defaultRemote=repo_upstream worktree add ../foo foo &&
		git status -uno --porcelain >status.actual &&
		test_must_be_empty status.actual
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_upstream foo &&
		test_cmp_rev refs/remotes/repo_upstream/foo refs/heads/foo
	)
'

test_expect_success 'git worktree add does not match remote' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		git worktree add ../foo
	) &&
	(
		cd foo &&
		test_must_fail git config "branch.foo.remote" &&
		test_must_fail git config "branch.foo.merge" &&
		test_cmp_rev ! refs/remotes/repo_a/foo refs/heads/foo
	)
'

test_expect_success 'git worktree add --guess-remote sets up tracking' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		git worktree add --guess-remote ../foo
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_a foo &&
		test_cmp_rev refs/remotes/repo_a/foo refs/heads/foo
	)
'

test_expect_success 'git worktree add with worktree.guessRemote sets up tracking' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		git config worktree.guessRemote true &&
		git worktree add ../foo
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_a foo &&
		test_cmp_rev refs/remotes/repo_a/foo refs/heads/foo
	)
'

test_expect_success 'git worktree --no-guess-remote option overrides config' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		git config worktree.guessRemote true &&
		git worktree add --no-guess-remote ../foo
	) &&
	(
		cd foo &&
		test_must_fail git config "branch.foo.remote" &&
		test_must_fail git config "branch.foo.merge" &&
		test_cmp_rev ! refs/remotes/repo_a/foo refs/heads/foo
	)
'

post_checkout_hook () {
	test_when_finished "rm -rf .git/hooks" &&
	mkdir .git/hooks &&
	test_hook -C "$1" post-checkout <<-\EOF
	{
		echo $*
		git rev-parse --git-dir --show-toplevel
	} >hook.actual
	EOF
}

test_expect_success '"add" invokes post-checkout hook (branch)' '
	post_checkout_hook &&
	{
		echo $ZERO_OID $(git rev-parse HEAD) 1 &&
		echo $(pwd)/.git/worktrees/gumby &&
		echo $(pwd)/gumby
	} >hook.expect &&
	git worktree add gumby &&
	test_cmp hook.expect gumby/hook.actual
'

test_expect_success '"add" invokes post-checkout hook (detached)' '
	post_checkout_hook &&
	{
		echo $ZERO_OID $(git rev-parse HEAD) 1 &&
		echo $(pwd)/.git/worktrees/grumpy &&
		echo $(pwd)/grumpy
	} >hook.expect &&
	git worktree add --detach grumpy &&
	test_cmp hook.expect grumpy/hook.actual
'

test_expect_success '"add --no-checkout" suppresses post-checkout hook' '
	post_checkout_hook &&
	rm -f hook.actual &&
	git worktree add --no-checkout gloopy &&
	test_path_is_missing gloopy/hook.actual
'

test_expect_success '"add" in other worktree invokes post-checkout hook' '
	post_checkout_hook &&
	{
		echo $ZERO_OID $(git rev-parse HEAD) 1 &&
		echo $(pwd)/.git/worktrees/guppy &&
		echo $(pwd)/guppy
	} >hook.expect &&
	git -C gloopy worktree add --detach ../guppy &&
	test_cmp hook.expect guppy/hook.actual
'

test_expect_success '"add" in bare repo invokes post-checkout hook' '
	rm -rf bare &&
	git clone --bare . bare &&
	{
		echo $ZERO_OID $(git --git-dir=bare rev-parse HEAD) 1 &&
		echo $(pwd)/bare/worktrees/goozy &&
		echo $(pwd)/goozy
	} >hook.expect &&
	post_checkout_hook bare &&
	git -C bare worktree add --detach ../goozy &&
	test_cmp hook.expect goozy/hook.actual
'

test_expect_success '"add" an existing but missing worktree' '
	git worktree add --detach pneu &&
	test_must_fail git worktree add --detach pneu &&
	rm -fr pneu &&
	test_must_fail git worktree add --detach pneu &&
	git worktree add --force --detach pneu
'

test_expect_success '"add" an existing locked but missing worktree' '
	git worktree add --detach gnoo &&
	git worktree lock gnoo &&
	test_when_finished "git worktree unlock gnoo || :" &&
	rm -fr gnoo &&
	test_must_fail git worktree add --detach gnoo &&
	test_must_fail git worktree add --force --detach gnoo &&
	git worktree add --force --force --detach gnoo
'

test_expect_success '"add" not tripped up by magic worktree matching"' '
	# if worktree "sub1/bar" exists, "git worktree add bar" in distinct
	# directory `sub2` should not mistakenly complain that `bar` is an
	# already-registered worktree
	mkdir sub1 sub2 &&
	git -C sub1 --git-dir=../.git worktree add --detach bozo &&
	git -C sub2 --git-dir=../.git worktree add --detach bozo
'

test_expect_success FUNNYNAMES 'sanitize generated worktree name' '
	git worktree add --detach ".  weird*..?.lock.lock" &&
	test -d .git/worktrees/---weird-.-
'

test_expect_success '"add" should not fail because of another bad worktree' '
	git init add-fail &&
	(
		cd add-fail &&
		test_commit first &&
		mkdir sub &&
		git worktree add sub/to-be-deleted &&
		rm -rf sub &&
		git worktree add second
	)
'

test_expect_success '"add" with uninitialized submodule, with submodule.recurse unset' '
	test_config_global protocol.file.allow always &&
	test_create_repo submodule &&
	test_commit -C submodule first &&
	test_create_repo project &&
	git -C project submodule add ../submodule &&
	git -C project add submodule &&
	test_tick &&
	git -C project commit -m add_sub &&
	git clone project project-clone &&
	git -C project-clone worktree add ../project-2
'
test_expect_success '"add" with uninitialized submodule, with submodule.recurse set' '
	git -C project-clone -c submodule.recurse worktree add ../project-3
'

test_expect_success '"add" with initialized submodule, with submodule.recurse unset' '
	test_config_global protocol.file.allow always &&
	git -C project-clone submodule update --init &&
	git -C project-clone worktree add ../project-4
'

test_expect_success '"add" with initialized submodule, with submodule.recurse set' '
	git -C project-clone -c submodule.recurse worktree add ../project-5
'

test_done
