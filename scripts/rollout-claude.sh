#!/usr/bin/env bash
# Opens a PR adding the Claude Code stub (workflow-templates/claude.yml) to
# every repo in the org that does not have it yet - or, with UPDATE=1, a PR
# replacing it in every repo whose copy differs from the template.
#
#   scripts/rollout-claude.sh                 dry run: list what would happen
#   scripts/rollout-claude.sh --apply         open the PRs
#   scripts/rollout-claude.sh --apply vm hub  only these repos
#   UPDATE=1 scripts/rollout-claude.sh        dry run of an update rollout
#
# VISIBILITY="private internal public" widens the set; by default the public
# sample repos are left alone, since anyone can comment there.
#
# BASE_OVERRIDES="vm=develop other=main" targets a branch other than the
# default, for repos whose default branch only takes promotions.
set -euo pipefail

ORG=${ORG:-testingbot}
UPDATE=${UPDATE:-}
if [ -n "$UPDATE" ]; then
	BRANCH=${BRANCH:-update-claude-code-workflow}
else
	BRANCH=${BRANCH:-add-claude-code-workflow}
fi
VISIBILITY=${VISIBILITY:-private internal}
TARGET=.github/workflows/claude.yml
STUB="$(cd "$(dirname "$0")/.." && pwd)/workflow-templates/claude.yml"

apply=false
if [ "${1:-}" = "--apply" ]; then
	apply=true
	shift
fi

base_for() {
	local repo=$1 default=$2 pair
	for pair in ${BASE_OVERRIDES:-}; do
		if [ "${pair%%=*}" = "$repo" ]; then
			echo "${pair#*=}"
			return
		fi
	done
	echo "$default"
}

if [ $# -gt 0 ]; then
	repos=$(for r in "$@"; do gh repo view "$ORG/$r" --json name,defaultBranchRef --jq '"\(.name) \(.defaultBranchRef.name)"'; done)
else
	# Own, non-archived, non-empty repos; forks follow their upstream.
	repos=$(for v in $VISIBILITY; do
		gh repo list "$ORG" --limit 1000 --no-archived --source --visibility "$v" \
			--json name,defaultBranchRef,isEmpty \
			--jq '.[] | select((.isEmpty | not) and .defaultBranchRef.name != null) | "\(.name) \(.defaultBranchRef.name)"'
	done)
fi

content=$(base64 < "$STUB" | tr -d '\n')

while read -r repo default; do
	[ -n "$repo" ] || continue
	[ "$repo" = ".github" ] && continue
	base=$(base_for "$repo" "$default")

	# The existing file's blob sha, or empty when the repo has none.
	existing=$(gh api "repos/$ORG/$repo/contents/$TARGET?ref=$base" --jq .sha 2>/dev/null || true)
	if [ -z "$UPDATE" ] && [ -n "$existing" ]; then
		echo "skip   $repo: already has $TARGET on $base"
		continue
	fi
	if [ -n "$UPDATE" ]; then
		if [ -z "$existing" ]; then
			echo "skip   $repo: no $TARGET on $base (run without UPDATE to add one)"
			continue
		fi
		if [ "$existing" = "$(git hash-object "$STUB")" ]; then
			echo "skip   $repo: $TARGET on $base already matches the template"
			continue
		fi
	fi
	if [ -n "$(gh pr list -R "$ORG/$repo" --head "$BRANCH" --state open --json number --jq '.[].number')" ]; then
		echo "skip   $repo: PR from $BRANCH already open"
		continue
	fi
	if ! $apply; then
		echo "would  $repo: PR $BRANCH -> $base"
		continue
	fi

	sha=$(gh api "repos/$ORG/$repo/git/ref/heads/$base" --jq .object.sha)
	gh api -X POST "repos/$ORG/$repo/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$sha" --silent
	if [ -n "$UPDATE" ]; then
		gh api -X PUT "repos/$ORG/$repo/contents/$TARGET" \
			-f message="ci: update the Claude Code workflow stub from $ORG/.github" \
			-f content="$content" -f sha="$existing" -f branch="$BRANCH" --silent
		url=$(gh pr create -R "$ORG/$repo" --base "$base" --head "$BRANCH" \
			--title "ci: update the Claude Code workflow" \
			--body "Replaces $TARGET with the current stub from $ORG/.github (workflow-templates/claude.yml).

This version adds automatic PR review: on every non-draft PR from this repo, Claude waits for the other checks, then approves when it finds nothing blocking and CI is green, requests changes when it finds something blocking, and otherwise comments. @claude mentions work as before.

This PR is the first one reviewed that way, since pull_request workflows run from the PR's own branch.")
		echo "opened $repo: $url"
		continue
	fi
	gh api -X PUT "repos/$ORG/$repo/contents/$TARGET" \
		-f message="ci: let @claude answer and push fixes on issues and PRs" \
		-f content="$content" -f branch="$BRANCH" --silent
	url=$(gh pr create -R "$ORG/$repo" --base "$base" --head "$BRANCH" \
		--title "ci: add the Claude Code workflow" \
		--body "Adds the stub that forwards issue, PR comment and review events to the shared Claude Code workflow in $ORG/.github. Once merged, mention @claude in an issue, PR comment or review to have Claude answer or push changes.

Note: comment-triggered workflows run from the **default branch**, so @claude only answers once this file is on $default.")
	echo "opened $repo: $url"
done <<< "$repos"
