#!/usr/bin/env bash
# stack-prs.sh — Rebase a sequence of branches into a linear stack for rebase merge.
#
# Usage:
#   stack-prs.sh [--base <branch>] [--push] [--update-prs] <branch1> <branch2> ...
#
# Branches are listed in merge order. Each branch is rebased onto the previous
# one (or --base for the first). Commits already on the parent are skipped
# automatically by git rebase.
#
# Options:
#   --base <branch>   Base branch for the first PR (default: origin/main or origin/master)
#   --push            Force-push rebased branches with --force-with-lease
#   --update-prs      Update GitHub PR base branches via gh cli
#   --dry-run         Show what would be done without modifying anything
#
# Each argument can be a branch name or a PR number (e.g., #5 or 5).
# PR numbers are resolved to branch names via gh.

set -euo pipefail

base=""
push=false
update_prs=false
dry_run=false
branches=()

usage() {
    sed -n '2,/^$/{ s/^# \?//; p }' "$0"
    exit "${1:-0}"
}

die() { echo "error: $*" >&2; exit 1; }

resolve_branch() {
    local arg="$1"
    # Strip leading # if present
    arg="${arg#\#}"
    # If it's a number, resolve via gh
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        local ref
        ref=$(gh pr view "$arg" --json headRefName -q .headRefName 2>/dev/null) \
            || die "could not resolve PR #$arg to a branch"
        echo "$ref"
    else
        echo "$arg"
    fi
}

detect_base() {
    if git rev-parse --verify origin/main &>/dev/null; then
        echo "origin/main"
    elif git rev-parse --verify origin/master &>/dev/null; then
        echo "origin/master"
    else
        die "could not detect base branch (no origin/main or origin/master)"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)   base="$2"; shift 2 ;;
        --push)   push=true; shift ;;
        --update-prs) update_prs=true; shift ;;
        --dry-run) dry_run=true; shift ;;
        -h|--help) usage 0 ;;
        -*)       die "unknown option: $1" ;;
        *)        branches+=("$1"); shift ;;
    esac
done

[[ ${#branches[@]} -gt 0 ]] || usage 1

# Resolve PR numbers to branch names
resolved=()
for b in "${branches[@]}"; do
    resolved+=("$(resolve_branch "$b")")
done
branches=("${resolved[@]}")

[[ -n "$base" ]] || base=$(detect_base)

echo "Base: $base"
echo "Stack: ${branches[*]}"
echo

parent="$base"
push_refs=()

for branch in "${branches[@]}"; do
    echo "--- $branch (onto $parent) ---"

    if ! git rev-parse --verify "$branch" &>/dev/null; then
        die "branch '$branch' does not exist"
    fi

    if $dry_run; then
        count=$(git rev-list --count "$parent".."$branch" 2>/dev/null || echo "?")
        echo "  would rebase $count commit(s) onto $parent"
    else
        git checkout "$branch" --quiet
        git rebase "$parent" --quiet || die "rebase of '$branch' onto '$parent' failed — resolve conflicts and re-run"

        count=$(git rev-list --count "$parent".."$branch")
        if [[ "$count" -eq 0 ]]; then
            echo "  empty after rebase (all commits already on parent)"
        else
            echo "  $count commit(s)"
        fi
    fi

    push_refs+=("$branch")
    parent="$branch"
done

echo

# Push
if $push && ! $dry_run; then
    echo "Pushing ${push_refs[*]} ..."
    git push origin "${push_refs[@]}" --force-with-lease
    echo
fi

# Update PR bases
if $update_prs && ! $dry_run; then
    parent="$base"
    # Strip origin/ prefix for gh
    gh_base="${parent#origin/}"

    for branch in "${branches[@]}"; do
        pr_num=$(gh pr list --head "$branch" --json number -q '.[0].number' 2>/dev/null || true)
        if [[ -n "$pr_num" ]]; then
            echo "PR #$pr_num ($branch): setting base to $gh_base"
            gh pr edit "$pr_num" --base "$gh_base"
        else
            echo "PR for $branch: not found, skipping"
        fi
        gh_base="$branch"
    done
    echo
fi

# Summary
echo "Stack ready. Merge order:"
i=1
parent="$base"
for branch in "${branches[@]}"; do
    count=$(git rev-list --count "$parent".."$branch" 2>/dev/null || echo "?")
    echo "  $i. $branch ($count commits, base: $parent)"
    parent="$branch"
    ((i++))
done
