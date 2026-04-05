---
name: pr-stack
description: Manage stacked pull requests for linear rebase-merge workflows. Use when creating, rebasing, or reorganizing multiple dependent PRs so that merging them in order produces a clean linear history with preserved commit hashes.
---

# PR Stacking for Rebase Merge

You are managing a stack of pull requests designed for sequential rebase merge. The goal: merging PRs in order produces a clean linear history where each PR's commit hashes are preserved through the merge.

## Principles

### Each branch owns only its commits

A PR branch contains exactly the commits that belong to that PR — nothing more. It forks from its prerequisite branch (or the main branch for the first in the stack). Shared history must not leak across branches.

### The stack is a linear chain

Even when PRs are logically independent, they form a single chain for merge ordering. Dependencies dictate the earliest a PR can appear; independent PRs slot in wherever they fit logically.

### Rebase merge preserves hashes

When GitHub performs a rebase merge on PR N, it replays N's commits onto the target branch. If N's base is the tip of the already-merged PR N-1, the commits replay with identical hashes — no rewrite needed.

## Procedure

### 1. Identify logical PRs and their commits

Map each commit to exactly one PR by semantic concern. A commit belongs to the PR whose purpose it serves, not the branch it happened to land on during development.

### 2. Determine dependency order

Build the dependency graph:
- If PR B modifies or depends on files introduced by PR A, B must come after A.
- Independent PRs have no constraints — slot them where they make logical sense.

Flatten into a linear chain: `main → PR1 → PR2 → PR3 → ...`

### 3. Create branches by cherry-pick

For each PR in order:

```bash
# First PR: fork from main
git checkout -B u/<user>/<pr1-name> origin/main
git cherry-pick <commit1> <commit2> ...

# Subsequent PRs: fork from the previous PR branch
git checkout -B u/<user>/<pr2-name> u/<user>/<pr1-name>
git cherry-pick <commit3> <commit4> ...
```

Cherry-pick (not rebase) when constructing from scratch — it's explicit about which commits go where.

### 4. Set PR bases on GitHub

Each PR's base branch is its prerequisite PR branch, not main (except the first). This scopes GitHub's diff view to only that PR's commits.

```bash
gh pr edit <number> --base u/<user>/<prerequisite-branch>
```

### 5. Create a dev branch for CI

The dev branch sits at the tip of the stack (same as the last PR branch) or is an octopus merge of all PR branches. It exists for CI validation only — never merge it.

```bash
git checkout -B u/<user>/dev u/<user>/<last-pr-branch>
git push origin u/<user>/dev
```

Open a PR for it to trigger CI, or use `gh workflow run` for manual dispatch. The PR body should list the merge order and note that it should not be merged directly.

### 6. Merge in order

Merge PRs sequentially via rebase merge:

1. Merge PR1 into main (rebase merge)
2. PR2's base automatically becomes main — its commits replay with preserved hashes
3. Repeat for PR3, PR4, ...

After each merge, the next PR in the stack should show no conflicts and a clean diff.

## Rebasing an existing stack onto updated main

When main moves forward (from merges or other work):

```bash
git fetch origin main

# Rebase each branch in order
git checkout u/<user>/<pr1-name>
git rebase origin/main

git checkout u/<user>/<pr2-name>
git rebase u/<user>/<pr1-name>

# ... continue for each branch

# Force-push all at once
git push origin u/<user>/<pr1-name> u/<user>/<pr2-name> ... --force-with-lease
```

Git will automatically skip commits that are already on main (e.g., from a previously merged PR). If a branch becomes empty after rebase, its PR is effectively merged — close it.

## Handling empty PRs

When a PR's commits are already on main (from a prior merge that included them), rebase will skip all its commits. The PR is empty and can be closed. Do not delete the branch on close — restore to GitHub's remembered SHA and reopen if needed later.

## Updating PR metadata

After any rebase or restructure, update:
- PR titles to match their actual content
- PR bodies with current merge order and predecessor references
- PR base branches if the stack order changed

## Audit on every commit

Every commit created or modified during stacking must pass a pathwise audit (see `pathwise-audit` skill) before it is pushed. This applies to:

- New commits written during the session
- Commits whose summary changed during a reword or rebase
- Commits that gained or lost hunks during a split or squash

Run the "and" test and path test before committing. After a rebase that rewords or squashes, spot-check the affected summaries against their diffs.

## What NOT to do

- Do **not** let development branches accumulate commits from multiple PRs — this is the anti-pattern stacking solves.
- Do **not** merge the dev/CI branch — it exists for validation only.
- Do **not** delete branches on PR close — you may need to reopen. Use `gh pr close` without `--delete-branch`.
- Do **not** rebase with `--reapply-cherry-picks` unless you intentionally want duplicate commits.
- Do **not** create a new PR when correcting a mistake on a closed one — reopen the existing PR instead.
