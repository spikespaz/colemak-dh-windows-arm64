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

### 1. Fetch and assess before reorganizing

Before closing, creating, or restructuring any PRs, fetch main and check what's already merged:

```bash
git fetch origin main
git log --oneline origin/main
```

Rebase existing branches onto `origin/main` first. Commits already on main will drop, revealing which branches are empty or reduced. Only then decide which PRs to close, keep, or create. Reorganizing before this step wastes PRs — you may close a PR and create a new one only to discover they're identical after rebase.

### 2. Identify logical PRs and their commits

Map each commit to exactly one PR by semantic concern. A commit belongs to the PR whose purpose it serves, not the branch it happened to land on during development.

### 3. Determine dependency order

Build the dependency graph:
- If PR B modifies or depends on files introduced by PR A, B must come after A.
- Independent PRs have no constraints — slot them where they make logical sense.

Flatten into a linear chain: `main → PR1 → PR2 → PR3 → ...`

### 4. Create branches by cherry-pick

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

### 5. Set PR bases on GitHub

Every PR's base branch is main/master. GitHub performs rebase merge into the base branch — setting a prerequisite branch as the base causes commits to land on the wrong branch when merged out of order. The merge order is enforced by convention (documented in PR bodies), not by base branch targeting.

```bash
gh pr edit <number> --base main
```

### 6. Create a dev branch for CI

The dev branch sits at the tip of the stack (same as the last PR branch) or is an octopus merge of all PR branches. It exists for CI validation only — never merge it.

```bash
git checkout -B u/<user>/dev u/<user>/<last-pr-branch>
git push origin u/<user>/dev
```

Open a PR for it to trigger CI, or use `gh workflow run` for manual dispatch. The PR body should list the merge order and note that it should not be merged directly.

### 7. Merge in order

Merge PRs sequentially via rebase merge, strictly in stack order:

1. Merge PR1 into main via rebase merge
2. Merge PR2 — its commits replay onto main with preserved hashes (since PR2's branch was rebased on PR1's tip, and PR1 is now on main)
3. Repeat for PR3, PR4, ...

**Never merge a PR before its prerequisites are merged.** The prerequisite's commits are not yet on main, so the dependent PR's commits won't replay cleanly — GitHub may report conflicts or produce duplicate commits.

When presenting the stack to the user, always include the merge order. Example PR body:

```
## Merge order
**Nth in stack** — merge #M first, then this PR. Do not merge out of order.
```

## Cascade discipline

**Rebasing one branch requires rebasing every downstream branch, rebuilding dev, updating PR metadata, and pushing — as a single atomic operation.** Doing any of these steps in isolation leaves the stack in an inconsistent state.

The full cascade after any change:

```bash
git fetch origin main

# 1. Rebase each branch in order
git checkout u/<user>/<pr1-name>
git rebase origin/main

git checkout u/<user>/<pr2-name>
git rebase u/<user>/<pr1-name>

# ... continue for each branch

# 2. Rebuild dev at the tip
git checkout u/<user>/dev
git reset --hard u/<user>/<last-pr-branch>

# 3. Push all at once
git push origin u/<user>/<pr1-name> u/<user>/<pr2-name> ... u/<user>/dev --force-with-lease

# 4. Update PR metadata (see below)
```

Git will automatically skip commits that are already on main (e.g., from a previously merged PR). If a branch becomes empty after rebase, its PR is effectively merged — close it.

### `--force-with-lease` rejection after external merge

When GitHub merges a PR (or the user merges manually on the web), the remote branch SHA changes in a way the local tracking ref doesn't know about. `--force-with-lease` will reject the push for that specific branch. Use `--force` for the affected branch only — not as a blanket flag:

```bash
# Only for the branch GitHub mutated
git push origin u/<user>/<branch> --force
# All others still use --force-with-lease
```

## Handling empty PRs

When a PR's commits are already on main (from a prior merge that included them), rebase will skip all its commits. The PR is empty and can be closed. Do not delete the branch on close — restore to GitHub's remembered SHA and reopen if needed later.

## Updating PR metadata

**This is a blocking step — do not push without updating metadata.** Every rebase cascade makes PR metadata stale. After any rebase or restructure, update all of the following before pushing:

- PR titles to match their actual content
- PR bodies with current merge order, predecessor references, and the merge-order warning
- PR base branches if the stack order changed
- Remove stale notes (e.g., "PR #X closed" if it was reopened)

Stale metadata is how PRs get merged into the wrong branch — the body says one thing, the base says another, and the user trusts the body.

**Check top-level PR comments too.** Review threads on diffs are visible per-commit, but top-level comments (on the PR conversation tab) are easy to miss. Before declaring a PR ready for merge, check `gh api repos/{owner}/{repo}/issues/{number}/comments` for unresolved feedback.

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
