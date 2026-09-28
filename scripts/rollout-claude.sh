#!/usr/bin/env bash
# Opens a PR adding the Claude Code stub (workflow-templates/claude.yml) to
# every repo in the org that does not have it yet.
#
#   scripts/rollout-claude.sh                 dry run: list what would happen
#   scripts/rollout-claude.sh --apply         open the PRs
#   scripts/rollout-claude.sh --apply vm hub  only these repos
#
# VISIBILITY="private internal public" widens the set; by default the public
# sample repos are left alone, since anyone can comment there.
#
# BASE_OVERRIDES="vm=develop other=main" targets a branch other than the
# default, for repos whose default branch only takes promotions.
set -euo pipefail

ORG=${ORG:-testingbot}
BRANCH=${BRANCH:-add-claude-code-workflow}
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

	if gh api "repos/$ORG/$repo/contents/$TARGET?ref=$base" --silent 2>/dev/null; then
		echo "skip   $repo: already has $TARGET on $base"
		continue
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
	gh api -X PUT "repos/$ORG/$repo/contents/$TARGET" \
		-f message="ci: let @claude answer and push fixes on issues and PRs" \
		-f content="$content" -f branch="$BRANCH" --silent
	url=$(gh pr create -R "$ORG/$repo" --base "$base" --head "$BRANCH" \
		--title "ci: add the Claude Code workflow" \
		--body "Adds the stub that forwards issue, PR comment and review events to the shared Claude Code workflow in $ORG/.github. Once merged, mention @claude in an issue, PR comment or review to have Claude answer or push changes.

Note: comment-triggered workflows run from the **default branch**, so @claude only answers once this file is on $default.")
	echo "opened $repo: $url"
done <<< "$repos"
