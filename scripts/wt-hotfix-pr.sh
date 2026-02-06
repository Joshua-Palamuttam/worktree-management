#!/bin/bash
# wt-hotfix-pr.sh - Cherry-pick a merged develop PR onto a release branch
# Usage: wt-hotfix-pr <pr_number> [--ticket <JIRA-ID>] [--release <branch>] [--dry-run] [--workdir <path>]

set -e

# Parse arguments
pr_number=""
release_branch=""
ticket=""
dry_run=false
workdir=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            release_branch="$2"
            shift 2
            ;;
        --ticket)
            ticket="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --workdir)
            workdir="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: wt-hotfix-pr <pr_number> [options]"
            echo ""
            echo "Cherry-pick a merged develop PR onto the latest release branch."
            echo ""
            echo "Options:"
            echo "  --ticket <JIRA-ID>   Jira ticket ID (prompted if not provided)"
            echo "  --release <branch>   Target release branch (default: latest release/*)"
            echo "  --dry-run            Show what would happen without making changes"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  wt-hotfix-pr 456                          # Cherry-pick PR #456 to latest release"
            echo "  wt-hotfix-pr 456 --ticket AI-1234         # With Jira ticket"
            echo "  wt-hotfix-pr 456 --release release/2026-02-04"
            echo "  wt-hotfix-pr 456 --dry-run                # Preview only"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$pr_number" ]; then
                pr_number="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$pr_number" ]; then
    echo "Usage: wt-hotfix-pr <pr_number> [--release <branch>] [--dry-run]"
    echo ""
    echo "Example: wt-hotfix-pr 456"
    exit 1
fi

# Change to workdir if provided
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

# Validate gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is required but not installed."
    echo "   Install: https://cli.github.com/"
    exit 1
fi

# Get repo root
repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)
cd "$repo_root"

# Fetch latest
echo "📥 Fetching latest from origin..."
git fetch origin < /dev/null

# Get PR metadata (single API call)
echo "🔍 Looking up PR #${pr_number}..."
pr_data=$(gh pr view "$pr_number" --json state,mergeCommit,title,headRefName,baseRefName,commits \
    -q '[.state, .mergeCommit.oid, .title, .headRefName, .baseRefName, (.commits | length | tostring), .commits[-1].oid] | join("\t")' < /dev/null 2>/dev/null) || {
    echo "❌ Could not find PR #${pr_number}. Check the PR number and try again."
    exit 1
}

IFS=$'\t' read -r pr_state merge_commit pr_title pr_head pr_base commit_count last_pr_commit <<< "$pr_data"

# Validate PR is merged
if [ "$pr_state" = "CLOSED" ]; then
    echo "❌ PR #${pr_number} was closed without merging"
    echo "   Title: ${pr_title}"
    echo "   Branch: ${pr_head} → ${pr_base}"
    exit 1
fi

if [ "$pr_state" != "MERGED" ]; then
    echo "❌ PR #${pr_number} is not merged (state: ${pr_state})"
    echo "   Title: ${pr_title}"
    echo "   Branch: ${pr_head} → ${pr_base}"
    echo ""
    echo "   Re-run this command after the PR is merged."
    exit 1
fi

if [ -z "$merge_commit" ]; then
    echo "❌ Could not determine merge commit for PR #${pr_number}"
    exit 1
fi

# Detect merge strategy
echo "🔍 Detecting merge strategy..."

parent_count=$(git cat-file -p "$merge_commit" | grep -c '^parent ' || true)
strategy=""
cherry_pick_cmd=""
cherry_pick_display=""

if [ "$parent_count" -gt 1 ]; then
    # Merge commit
    strategy="merge commit"
    cherry_pick_cmd="cherry-pick -m 1 $merge_commit"
    commit_msg=$(git log -1 --format="%s" "$merge_commit")
    cherry_pick_display="   Commit:   ${merge_commit:0:8} (merge commit, using -m 1)"
    cherry_pick_display="${cherry_pick_display}\n   Message:  ${commit_msg}"

elif [ "$commit_count" -le 1 ]; then
    # Single commit (squash or 1-commit PR)
    strategy="squash merge (single commit)"
    cherry_pick_cmd="cherry-pick $merge_commit"
    commit_msg=$(git log -1 --format="%s" "$merge_commit")
    cherry_pick_display="   Commit:   ${merge_commit:0:8} - ${commit_msg}"

else
    # Ambiguous: squash or rebase - use patch-id comparison
    if [ -n "$last_pr_commit" ] && git cat-file -e "$last_pr_commit" 2>/dev/null; then
        # Compare patch-ids
        merge_patch_id=$(git diff-tree -p "$merge_commit" | git patch-id --stable 2>/dev/null | awk '{print $1}')
        pr_patch_id=$(git diff-tree -p "$last_pr_commit" | git patch-id --stable 2>/dev/null | awk '{print $1}')

        if [ -n "$merge_patch_id" ] && [ -n "$pr_patch_id" ] && [ "$merge_patch_id" = "$pr_patch_id" ]; then
            # Rebase merge - cherry-pick the range
            strategy="rebase merge (${commit_count} commits)"
            cherry_pick_cmd="cherry-pick ${merge_commit}~${commit_count}..${merge_commit}"

            # Build commit list display
            cherry_pick_display=""
            commit_list=$(git log --format="     %h - %s" "${merge_commit}~${commit_count}..${merge_commit}" --reverse)
            cherry_pick_display="   Strategy: rebase merge (${commit_count} commits)"
        else
            # Squash merge
            strategy="squash merge (single commit)"
            cherry_pick_cmd="cherry-pick $merge_commit"
            commit_msg=$(git log -1 --format="%s" "$merge_commit")
            cherry_pick_display="   Commit:   ${merge_commit:0:8} - ${commit_msg}"
        fi
    else
        # Can't find the original PR commits - assume squash
        strategy="squash merge (single commit)"
        cherry_pick_cmd="cherry-pick $merge_commit"
        commit_msg=$(git log -1 --format="%s" "$merge_commit")
        cherry_pick_display="   Commit:   ${merge_commit:0:8} - ${commit_msg}"
    fi
fi

# Find release branch
if [ -n "$release_branch" ]; then
    # Validate provided release branch exists
    if ! git show-ref --verify --quiet "refs/remotes/origin/${release_branch}"; then
        echo "❌ Release branch '${release_branch}' not found on remote"
        exit 1
    fi
else
    # Auto-detect latest release branch
    release_branches=$(git branch -r --list 'origin/release/*' --sort=-committerdate | sed 's|^ *origin/||' | head -20)

    if [ -z "$release_branches" ]; then
        echo "❌ No release branches found (origin/release/*)"
        echo "   Use --release <branch> to specify a target branch."
        exit 1
    fi

    latest_release=$(echo "$release_branches" | head -1)

    echo ""
    echo "🔍 Found release branches:"

    # Show top branches
    i=0
    while IFS= read -r branch; do
        if [ $i -eq 0 ]; then
            echo "   → ${branch}  (latest)"
        else
            echo "     ${branch}"
        fi
        i=$((i + 1))
        if [ $i -ge 5 ]; then break; fi
    done <<< "$release_branches"

    echo ""
    read -p "Use ${latest_release}? [Y/n/other] " choice

    case "$choice" in
        ""|[Yy]|[Yy]es)
            release_branch="$latest_release"
            ;;
        [Nn]|[Nn]o)
            # Show numbered list for selection
            IFS=$'\n' read -d '' -r -a branch_array <<< "$release_branches" || true
            echo ""
            echo "Select a release branch:"
            i=1
            for branch in "${branch_array[@]}"; do
                echo "  ${i}) ${branch}"
                i=$((i + 1))
            done
            echo "  q) Cancel"
            echo ""
            read -p "Enter number or branch name: " selection

            if [ "$selection" = "q" ] || [ -z "$selection" ]; then
                echo "Cancelled."
                exit 1
            fi

            if [[ "$selection" =~ ^[0-9]+$ ]]; then
                idx=$((selection - 1))
                if [ $idx -ge 0 ] && [ $idx -lt ${#branch_array[@]} ]; then
                    release_branch="${branch_array[$idx]}"
                else
                    echo "Invalid selection"
                    exit 1
                fi
            else
                # User typed a branch name
                if git show-ref --verify --quiet "refs/remotes/origin/${selection}"; then
                    release_branch="$selection"
                else
                    echo "❌ Branch '${selection}' not found on remote"
                    exit 1
                fi
            fi
            ;;
        *)
            # User typed a branch name
            if git show-ref --verify --quiet "refs/remotes/origin/${choice}"; then
                release_branch="$choice"
            else
                echo "❌ Branch '${choice}' not found on remote"
                exit 1
            fi
            ;;
    esac
fi

# Prompt for Jira ticket if not provided
if [ -z "$ticket" ]; then
    echo ""
    read -p "🎫 Jira ticket for this hotfix (e.g. AI-1234): " ticket
    if [ -z "$ticket" ]; then
        echo "❌ Jira ticket is required."
        exit 1
    fi
fi

# Extract date from release branch for naming
release_date=$(echo "$release_branch" | sed 's|release/||')
hotfix_branch="hotfix/${ticket}-pr-${pr_number}-to-${release_date}"
worktree_dir="_hotfix/hotfix-pr-${pr_number}"

# Check if commit is already on release branch
if git merge-base --is-ancestor "$merge_commit" "origin/${release_branch}" 2>/dev/null; then
    echo ""
    echo "✅ PR #${pr_number} is already on ${release_branch}. Nothing to do."
    exit 0
fi

# Show cherry-pick summary
echo ""
echo "🍒 Ready to cherry-pick:"
echo ""
echo "   PR:       #${pr_number} - ${pr_title}"
echo "   Jira:     ${ticket}"

if [[ "$strategy" == rebase* ]] && [ -n "$commit_list" ]; then
    echo "   Strategy: ${strategy}"
    echo "   Target:   ${release_branch}"
    echo "   Branch:   ${hotfix_branch}"
    echo ""
    echo "   Commits to cherry-pick:"
    echo "$commit_list"
else
    echo -e "$cherry_pick_display"
    echo "   Strategy: ${strategy}"
    echo "   Target:   ${release_branch}"
    echo "   Branch:   ${hotfix_branch}"
fi

echo ""

# Dry run exits here
if [ "$dry_run" = true ]; then
    echo "   (dry run - no changes made)"
    echo ""
    echo "   Would create PR: [${ticket}] Cherry-pick PR #${pr_number} to ${release_branch}"
    exit 0
fi

read -p "Proceed? [Y/n] " proceed
case "$proceed" in
    ""|[Yy]|[Yy]es) ;;
    *)
        echo "Cancelled."
        exit 1
        ;;
esac

# Check if worktree path already exists
if [ -d "$worktree_dir" ]; then
    echo ""
    echo "⚠️  Worktree directory already exists: ${worktree_dir}"
    read -p "Remove it and continue? [Y/n] " cleanup_choice
    case "$cleanup_choice" in
        ""|[Yy]|[Yy]es)
            git worktree remove "$worktree_dir" --force 2>/dev/null || rm -rf "$worktree_dir"
            git worktree prune
            ;;
        *)
            echo "Aborted. Remove the existing worktree first:"
            echo "  wt-hotfix-done hotfix-pr-${pr_number}"
            exit 1
            ;;
    esac
fi

# Create worktree
echo ""
echo "📁 Creating worktree..."
mkdir -p "_hotfix"
git worktree add -b "$hotfix_branch" "$worktree_dir" "origin/${release_branch}"

# Cherry-pick
echo ""
echo "🍒 Cherry-picking..."
cd "$worktree_dir"

set +e
git $cherry_pick_cmd
cherry_pick_result=$?
set -e

if [ $cherry_pick_result -eq 0 ]; then
    echo "✅ Cherry-pick succeeded!"
else
    echo ""
    echo "⚠️  Cherry-pick has conflicts!"
    echo ""

    # List conflicting files
    conflicting_files=$(git diff --name-only --diff-filter=U)
    echo "Conflicting files:"
    echo "$conflicting_files" | sed 's/^/  /'
    echo ""

    # Try to open in editor
    editor="${EDITOR:-code --wait}"
    read -p "Open conflicts in editor ($editor)? [Y/n] " open_editor
    case "$open_editor" in
        ""|[Yy]|[Yy]es)
            echo "Opening editor..."
            $editor $conflicting_files 2>/dev/null || true
            ;;
    esac

    echo ""
    read -p "Have you resolved all conflicts? [y/N] " resolved
    case "$resolved" in
        [Yy]|[Yy]es)
            # Check if there are still unresolved conflicts
            if git diff --name-only --diff-filter=U | grep -q .; then
                echo "❌ There are still unresolved conflicts. Resolve them and run:"
                echo "  cd ${repo_root}/${worktree_dir}"
                echo "  git add ."
                echo "  git cherry-pick --continue"
                exit 1
            fi
            git add .
            git cherry-pick --continue --no-edit || git commit --no-edit
            echo "✅ Conflicts resolved!"
            ;;
        *)
            echo ""
            echo "The worktree is ready for manual conflict resolution:"
            echo "  cd ${repo_root}/${worktree_dir}"
            echo ""
            echo "After resolving conflicts:"
            echo "  git add ."
            echo "  git cherry-pick --continue"
            echo "  git push -u origin ${hotfix_branch}"
            echo "  gh pr create --base ${release_branch} --title \"[${ticket}] Cherry-pick PR #${pr_number} to ${release_branch}\" --body \"Cherry-pick of #${pr_number}\""
            echo ""
            echo "When done:"
            echo "  wt-hotfix-done hotfix-pr-${pr_number}"
            exit 1
            ;;
    esac
fi

# Push branch
echo ""
echo "📤 Pushing branch..."
if git push -u origin "$hotfix_branch"; then
    echo "✅ Branch pushed!"
else
    echo "⚠️  Push failed. You can retry manually:"
    echo "  cd ${repo_root}/${worktree_dir}"
    echo "  git push -u origin ${hotfix_branch}"
    exit 1
fi

# Postmortem questions
echo ""
echo "📋 Hotfix Postmortem - please provide context:"
echo ""

read -p "Why is this change needed in the release?
> " pm_reason

read -p "What is the customer/business impact if this isn't hotfixed?
> " pm_impact

read -p "What testing was done on the original PR?
> " pm_testing

read -p "Any additional risks or notes for reviewers? (Enter to skip)
> " pm_notes

if [ -z "$pm_notes" ]; then
    pm_notes="None"
fi

# Generate postmortem via claude CLI if available
postmortem=""
if command -v claude &> /dev/null; then
    echo ""
    echo "🤖 Generating postmortem with Claude..."
    postmortem=$(claude --print "Generate a concise hotfix postmortem in markdown. Keep it to 2-3 short paragraphs. Do not include a title heading — start directly with the content. Summarize why this hotfix is needed, the risk assessment, and testing confidence." <<EOF
PR #${pr_number}: ${pr_title}
Branch: ${pr_head} → ${pr_base}
Release target: ${release_branch}
Merge strategy: ${strategy}

Why needed in release: ${pm_reason}
Business impact: ${pm_impact}
Testing done: ${pm_testing}
Additional notes: ${pm_notes}
EOF
    ) || true
fi

# Build PR body
if [ -n "$postmortem" ]; then
    pr_body="## Cherry-pick Info
- **Original PR:** #${pr_number}
- **Jira:** ${ticket}
- **Merge strategy:** ${strategy}
- **Merge commit:** ${merge_commit:0:8}

## Hotfix Postmortem

${postmortem}

### Context provided
- **Why needed:** ${pm_reason}
- **Business impact:** ${pm_impact}
- **Testing done:** ${pm_testing}
- **Additional notes:** ${pm_notes}"
else
    pr_body="## Cherry-pick Info
- **Original PR:** #${pr_number}
- **Jira:** ${ticket}
- **Merge strategy:** ${strategy}
- **Merge commit:** ${merge_commit:0:8}

## Hotfix Postmortem

### Why is this change needed in the release?
${pm_reason}

### What is the customer/business impact?
${pm_impact}

### What testing was done?
${pm_testing}

### Additional risks or notes
${pm_notes}"
fi

# Create PR
echo ""
echo "📝 Creating pull request..."

pr_url=$(gh pr create \
    --base "$release_branch" \
    --title "[${ticket}] Cherry-pick PR #${pr_number} to ${release_branch}" \
    --body "$pr_body" \
    2>/dev/null) || {
    echo "⚠️  PR creation failed. Branch is pushed - create it manually:"
    echo "  gh pr create --base ${release_branch} --title \"[${ticket}] Cherry-pick PR #${pr_number} to ${release_branch}\""
    exit 1
}

echo "✅ Pull request created!"
echo ""
echo "   PR: ${pr_url}"
echo ""
echo "📂 Worktree: ${repo_root}/${worktree_dir}"
echo ""
echo "When done:"
echo "  wt-hotfix-done hotfix-pr-${pr_number}"
