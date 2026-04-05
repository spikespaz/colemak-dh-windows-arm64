# Claude Session Guidelines

## Commit Discipline

This repository uses **Pathwise Commit Summaries** (see `.claude/skills/pathwise-commit/skill.md`).

### Session Workflow

At every natural subject boundary in the conversation — when the topic shifts, when a logical unit of work completes, or when the user moves on — commit the current changes using the Pathwise format.

- **Commit every edit**: every time you create or edit a file, commit immediately. Do not accumulate uncommitted changes. The history is the ledger.
- **Temporary commits by default**: most edits during a session are temporary. Use rebase-prefix commits (`f`, `s`, `r`, `d`) to record intermediate state. Include rebase instructions in the commit body. But if you are adding new content — not correcting or refining an existing commit — that is a **real commit**, not a fixup. The prefix reflects rebase intent, not your confidence level.
- **Ask about granularity**: if unsure whether a change warrants its own commit, a fixup, or a standalone permanent commit, ask the user.
- **Rebase housekeeping**: before pushing, during natural pauses, or when returning to a prior subject, rebase and clean up temporary commits. Squash/fixup as the prefixes indicate.
- **Never lose work**: prefer a temporary commit over uncommitted changes when context-switching.

### Commit Body Convention

When a commit incorporates information shared by the user (links, discussions, external review), briefly describe the source in the commit body. This preserves provenance without cluttering the summary line.

### Judgment Over Rules

The skill file teaches the format. These guidelines teach judgment:

- **Granularity is the real discipline.** The format is easy. Committing every edit, immediately, with the right scope — that is the hard part. Default to smaller commits. If you catch yourself batching, stop and commit what you have.
- **The history is the deliverable.** A clean history with well-scoped commits is more valuable than the final file state. When in doubt, make the history more granular, not less.
- **Never assume the environment.** Ask before using tools, interpreters, or services that haven't been confirmed available. This applies to subagents too.
- **Always end files with a newline.** Every file must have a trailing newline at EOF. No exceptions.
- **Audit your own commits.** The pathwise-audit skill applies to commits you produce, not just commits you review. Before every commit, test the summary against the full pathwise-commit spec — not just the "and" test, but naming, phrasing, granularity, mechanical consequences, and the "What NOT To Do" list. Do this incrementally: audit each commit as it is created or changed.

## CI and Branch Management

- **Push and iterate autonomously on feature branches.** Do not ask for confirmation before pushing, force-pushing (with lease), or re-running CI on non-main branches. The user expects you to drive the feedback loop.
- **Clean up after merge.** Delete merged branches (local and remote) and rebase remaining branches onto updated master.

### PR Stacking

When multiple PRs are in flight, stack them as a linear chain for rebase merge:

- **Each branch contains only its own commits.** Fork from the prerequisite PR branch (or master for the first in the stack), and cherry-pick or rebase only the commits that belong to that PR. Do not let shared history leak across branches. The user may override this on a case-by-case basis.
- **Order branches by dependency, then by logical sequence.** If PR B depends on files introduced by PR A, B's branch is based on A's. Independent PRs slot into the chain wherever they fit logically. The goal: rebase-merging PRs in order produces a clean linear history where commit hashes are preserved through each merge.
- **Set PR base branches accordingly.** Each PR's base is its prerequisite PR branch, not master (except the first). This keeps GitHub's diff scoped to that PR's commits only. The user may override this. After merging PRs and rebalancing the stack, suggest re-pointing remaining bases to master where prerequisites are now merged.
- **Dev branch is optional.** For stacks of 3 or fewer PRs, trigger CI with `gh workflow run` or push individual PR branches. For 4+ PRs, suggest a dev branch at the tip for CI validation. If created, it is never merged — individual PRs are merged in order.

## Documentation

- **Link rendered versions after pushing.** When documentation changes are pushed (README, markdown files), provide a GitHub link to the rendered version of each affected file so the user can verify formatting visually: `https://github.com/<owner>/<repo>/blob/<branch>/<file>#<section>`.

## Skill Provenance

The `pathwise-commit` and `pathwise-audit` skills originate from [spikespaz/claude](https://github.com/spikespaz/claude). When updating these skills, check the source repo for newer versions.
