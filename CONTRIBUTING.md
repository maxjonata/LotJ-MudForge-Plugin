# Contributing to LotJ-MudForge-Plugin

The canonical repository is [maxjonata/LotJ-MudForge-Plugin](https://github.com/maxjonata/LotJ-MudForge-Plugin). Use `origin` for that repository. Never put passwords, tokens, or private keys in remote URLs, commits, PRs, logs, or chat. Use approved authentication, such as an SSH agent or a Git credential manager, instead of embedding credentials in a URL.

## Branches and parallel worktrees

- Use one scoped topic branch and one pull request (PR) per change. Start each routine change from a current `origin/main`, target `main` in the PR, and keep unrelated edits out of it. Never commit directly on `main` or push to it, with or without force.
- Use a separate Git worktree for each simultaneous change. Assign paths up front and avoid parallel edits to the same paths unless the contributors explicitly agree on the order. If two changes need the same file, agree which lands first, then update the second branch from the new `origin/main` before editing that file.
- For an authorized routine change, run the following from the canonical checkout. This creates the topic branch without switching or moving local `main`. Use a distinct branch name and directory for each change.

  ```sh
  git fetch origin
  git worktree add -b docs/contribution-guide ../lotj-contribution-guide origin/main
  cd ../lotj-contribution-guide
  ```

  Use `git worktree list` to see which branches are checked out where. Remove a worktree only after handing off or merging its work and confirming there are no uncommitted edits. Keep the branch if it is still needed for review or handoff.

## Verification and review

1. Review the diff for scope and run `git diff --check` (use `git diff --cached --check` for staged changes). Run focused tests or lint checks for the affected paths. In the PR, state what ran, what passed, and what could not be run or did not apply.
2. When publication is authorized, push only the topic branch and open its PR against `main`. Where real CI checks are defined for the change, verify they passed for the exact current PR head SHA. If the head changes, rerun or recheck against the new head. A placeholder job or a run for a different SHA is not evidence that the change passed. If no real checks are defined, say so rather than reporting green CI.
3. Get the user's review and approval before merging, in addition to passing any applicable checks. If the reviewed content changes, send the updated PR back for review. These are project conventions; this guide does not assert that GitHub branch protections or CI are configured.

## History-preserving imports

A source recovery or history-preserving import is not a routine topic change. Keep it on a dedicated integration branch, retain the original source commits and any archive refs involved, and document the source tip, conflict resolutions, and which files were checked against the source. Before review, verify that the imported source tip is an ancestor of the integration candidate (for example, `git merge-base --is-ancestor <source-tip> <candidate-tip>`). If the integration is approved, use a merge method that keeps those commits in the destination's ancestry; do not squash, rebase, or cherry-pick the import as a substitute for preserving history. Do not rewrite or force-push `main` to perform an import.
