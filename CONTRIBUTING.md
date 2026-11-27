# Contributing to LotJ-MudForge-Plugin

The canonical repository is [maxjonata/LotJ-MudForge-Plugin](https://github.com/maxjonata/LotJ-MudForge-Plugin). Use `origin` for that repository. Never put passwords, tokens, or private keys in remote URLs, commits, PRs, logs, or chat. Use approved authentication, such as an SSH agent or a Git credential manager, instead of embedding credentials in a URL.

The [GitHub Project roadmap](https://github.com/users/maxjonata/projects/1/views/1)
is the shared work queue. Record scope and acceptance criteria there before
implementation and update each item with evidence after verification. See the
[repository roadmap reference](docs/ROADMAP.md) for the historical baseline.

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

## Tests first

Every roadmap card in Todo has a pending acceptance spec in `tests/acceptance/`,
generated from the card's **Aceite** criteria. `lua tests/run.lua` prints them
and reports how many cards are pending, without failing.

1. When you start a card, replace its `pending(...)` call with real assertions
   and confirm they fail before writing the code. Add focused specs for the
   domain, application and adapter layers as well.
2. Keep `lua tests/coverage.lua` passing on Lua 5.1 and 5.4. When coverage
   rises, run `lua tests/coverage.lua --update` on each version and commit the
   new floor.
3. After adding cards to the board, regenerate the missing placeholders. The
   generator never overwrites an existing spec:

   ```sh
   gh project item-list 1 --owner maxjonata --format json -L 500 > board.json
   python scripts/roadmap/pending_specs.py board.json tests/acceptance
   ```

## Feature tests inside MudForge (DEV plugin)

`dev/` holds **LotJ Plugin DEV**, a separate plugin that bundles the production
code with feature scenarios (`dev/scenarios/*.lua`, listed in
`dev/scenarios/index.lua`). It replaces `send`, `sendGMCP`, `getSession` and
the timers with recorders, so nothing reaches the MUD, and drives the real code
with simulated GMCP, MUD lines (`onLine` and the client's own trigger engine via
`feedTriggers`) and widget messages. It is never part of the release ZIP.

The same scenarios run offline in `tests/acceptance/qa_07_spec.lua`. To run
them in the desktop app, use a throwaway world with the release plugin off:

1. First time: `python scripts/dev/install_dev_plugin.py --zip lotj-dev.zip`,
   then import `lotj-dev.zip` in Plugin Manager.
2. After each change: `python scripts/dev/install_dev_plugin.py`. It copies the
   files into `~/MudForge/plugins`, the app hot-reloads the plugin, and the
   terminal prints one `LOTJDEV PASS|FAIL <scenario>` line each and
   `LOTJDEV SUMMARY passed=N failed=M`. Type `lotjdev [filter]` to rerun.

Add a scenario for every feature that crosses layers, and list it in the index.

Two client rules shape the DEV plugin (seen in MudForge 2.0.6762):

- A plugin cannot reassign MudForge API names such as `send`. Production
  modules therefore take `send`, `getSession`, the timers, `createWidget`,
  `sendWidgetMessage`, `registerWidgetEvent` and `onGMCPUpdate` from
  `LotjHost` when it is set. The release plugin never sets it.
- The hot reload matches a saved file to a plugin by its `plugin = { id }`
  table and did not refresh the imported `src/` modules. The installer serves
  the production modules from `release/` instead, and renames the entry
  point's table in that copy only.

## Verification and review

1. Review the diff for scope and run `git diff --check` (use `git diff --cached --check` for staged changes). Run focused tests or lint checks for the affected paths. In the PR, state what ran, what passed, and what could not be run or did not apply.
2. When publication is authorized, push only the topic branch and open its PR against `main`. Where real CI checks are defined for the change, verify they passed for the exact current PR head SHA. If the head changes, rerun or recheck against the new head. A placeholder job or a run for a different SHA is not evidence that the change passed. If no real checks are defined, say so rather than reporting green CI.
3. Merge verified changes once applicable checks pass and repository rules are satisfied. Routine merges do not require separate owner approval. Ask before deleting branches, files, or other project data, and do not enable automatic branch deletion. These conventions do not override GitHub branch protections.

## History-preserving imports

A source recovery or history-preserving import is not a routine topic change. Keep it on a dedicated integration branch, retain the original source commits and any archive refs involved, and document the source tip, conflict resolutions, and which files were checked against the source. Before review, verify that the imported source tip is an ancestor of the integration candidate (for example, `git merge-base --is-ancestor <source-tip> <candidate-tip>`). If the integration is approved, use a merge method that keeps those commits in the destination's ancestry; do not squash, rebase, or cherry-pick the import as a substitute for preserving history. Do not rewrite or force-push `main` to perform an import.
