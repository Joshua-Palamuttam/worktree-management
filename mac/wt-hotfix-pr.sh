#!/bin/bash
# wt-hotfix-pr.sh - Cherry-pick a merged develop PR onto a release branch (macOS)
# Usage: wt-hotfix-pr <pr_number> [--ticket <JIRA-ID>] [--release <branch>] [--quick] [--dry-run]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

# Parse arguments
pr_number=""
release_branch=""
ticket=""
dry_run=false
quick=false

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
        --quick|-q)
            quick=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --help|-h)
            echo "Usage: wt-hotfix-pr <pr_number> [options]"
            echo ""
            echo "Cherry-pick a merged develop PR onto the latest release branch."
            echo ""
            echo "Options:"
            echo "  --ticket <JIRA-ID>   Jira ticket ID (prompted if not provided)"
            echo "  --release <branch>   Target release branch (default: latest release/*)"
            echo "  --quick, -q          Skip Jira prompt, postmortem, and AI summary"
            echo "  --dry-run            Show what would happen without making changes"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  wt-hotfix-pr 456                          # Cherry-pick PR #456 to latest release"
            echo "  wt-hotfix-pr 456 --ticket AI-1234         # With Jira ticket"
            echo "  wt-hotfix-pr 456 --quick                  # Fast hotfix, no postmortem"
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

# Capture invoking worktree before cd to repo root
invoking_wt=$(git rev-parse --show-toplevel 2>/dev/null) || true

# Validate gh CLI
if ! command -v gh &> /dev/null; then
    err "GitHub CLI (gh) is required but not installed."
    echo "   Install: brew install gh"
    exit 1
fi

# Get repo root
repo_root=$(get_repo_root) || {
    err "Not in a git repository."
    exit 1
}
cd "$repo_root"

# Fetch latest
info "Fetching latest from origin..."
git fetch origin < /dev/null

# Get PR metadata
info "Looking up PR #${pr_number}..."
pr_data=$(gh pr view "$pr_number" --json state,mergeCommit,title,headRefName,baseRefName,commits \
    -q '[.state, .mergeCommit.oid, .title, .headRefName, .baseRefName, (.commits | length | tostring), .commits[-1].oid] | join("\t")' < /dev/null 2>/dev/null) || {
    err "Could not find PR #${pr_number}. Check the PR number and try again."
    exit 1
}

IFS=$'\t' read -r pr_state merge_commit pr_title pr_head pr_base commit_count last_pr_commit <<< "$pr_data"

# Validate PR is merged
if [ "$pr_state" = "CLOSED" ]; then
    err "PR #${pr_number} was closed without merging"
    echo "   Title: ${pr_title}"
    echo "   Branch: ${pr_head} -> ${pr_base}"
    exit 1
fi

if [ "$pr_state" != "MERGED" ]; then
    err "PR #${pr_number} is not merged (state: ${pr_state})"
    echo "   Title: ${pr_title}"
    echo "   Branch: ${pr_head} -> ${pr_base}"
    echo ""
    echo "   Re-run this command after the PR is merged."
    exit 1
fi

if [ -z "$merge_commit" ]; then
    err "Could not determine merge commit for PR #${pr_number}"
    exit 1
fi

# Detect merge strategy
info "Detecting merge strategy..."

parent_count=$(git cat-file -p "$merge_commit" | grep -c '^parent ' || true)
strategy=""
cherry_pick_cmd=""
cherry_pick_display=""
commit_list=""

if [ "$parent_count" -gt 1 ]; then
    strategy="merge commit"
    cherry_pick_cmd="cherry-pick -m 1 $merge_commit"
    commit_msg=$(git log -1 --format="%s" "$merge_commit")
    cherry_pick_display="   Commit:   ${merge_commit:0:8} (merge commit, using -m 1)"
    cherry_pick_display="${cherry_pick_display}\n   Message:  ${commit_msg}"
elif [ "$commit_count" -le 1 ]; then
    strategy="squash merge (single commit)"
    cherry_pick_cmd="cherry-pick $merge_commit"
    commit_msg=$(git log -1 --format="%s" "$merge_commit")
    cherry_pick_display="   Commit:   ${merge_commit:0:8} - ${commit_msg}"
else
    if [ -n "$last_pr_commit" ] && git cat-file -e "$last_pr_commit" 2>/dev/null; then
        merge_patch_id=$(git diff-tree -p "$merge_commit" | git patch-id --stable 2>/dev/null | awk '{print $1}')
        pr_patch_id=$(git diff-tree -p "$last_pr_commit" | git patch-id --stable 2>/dev/null | awk '{print $1}')

        if [ -n "$merge_patch_id" ] && [ -n "$pr_patch_id" ] && [ "$merge_patch_id" = "$pr_patch_id" ]; then
            strategy="rebase merge (${commit_count} commits)"
            cherry_pick_cmd="cherry-pick ${merge_commit}~${commit_count}..${merge_commit}"
            commit_list=$(git log --format="     %h - %s" "${merge_commit}~${commit_count}..${merge_commit}" --reverse)
        else
            strategy="squash merge (single commit)"
            cherry_pick_cmd="cherry-pick $merge_commit"
            commit_msg=$(git log -1 --format="%s" "$merge_commit")
            cherry_pick_display="   Commit:   ${merge_commit:0:8} - ${commit_msg}"
        fi
    else
        strategy="squash merge (single commit)"
        cherry_pick_cmd="cherry-pick $merge_commit"
        commit_msg=$(git log -1 --format="%s" "$merge_commit")
        cherry_pick_display="   Commit:   ${merge_commit:0:8} - ${commit_msg}"
    fi
fi

# Find release branch
if [ -n "$release_branch" ]; then
    if ! git show-ref --verify --quiet "refs/remotes/origin/${release_branch}"; then
        err "Release branch '${release_branch}' not found on remote"
        exit 1
    fi
else
    release_branches=$(git branch -r --list 'origin/release/*' --sort=-committerdate | sed 's|^ *origin/||' | head -20)

    if [ -z "$release_branches" ]; then
        err "No release branches found (origin/release/*)"
        echo "   Use --release <branch> to specify a target branch."
        exit 1
    fi

    # Use fzf to select release branch
    release_branch=$(echo "$release_branches" | fzf_select "Release branch")
    [[ -z "$release_branch" ]] && { echo "Cancelled."; exit 1; }
fi

# Prompt for Jira ticket
if [ -z "$ticket" ]; then
    if [ "$quick" = true ]; then
        ticket="none"
    else
        echo ""
        read -p "Jira ticket for this hotfix (e.g. AI-1234, or 'none' to skip): " ticket < /dev/tty
        if [ -z "$ticket" ]; then
            ticket="none"
        fi
    fi
fi

# Build branch and worktree names
release_date=$(echo "$release_branch" | sed 's|release/||')
hotfix_branch="hotfix/${ticket}-pr-${pr_number}-to-${release_date}"
release_date_safe=$(echo "$release_date" | sed 's|/|-|g')
worktree_dir="_hotfix/hotfix-pr-${pr_number}-to-${release_date_safe}"

# Check if already on release
if git merge-base --is-ancestor "$merge_commit" "origin/${release_branch}" 2>/dev/null; then
    echo ""
    success "PR #${pr_number} is already on ${release_branch}. Nothing to do."
    exit 0
fi

# Show summary
echo ""
echo "Ready to cherry-pick:"
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

if [ "$dry_run" = true ]; then
    echo "   (dry run - no changes made)"
    echo ""
    if [ "$ticket" = "none" ]; then
        echo "   Would create PR: Cherry-pick PR #${pr_number} to ${release_branch}"
    else
        echo "   Would create PR: [${ticket}] Cherry-pick PR #${pr_number} to ${release_branch}"
    fi
    exit 0
fi

read -p "Proceed? [Y/n] " proceed < /dev/tty
case "$proceed" in
    ""|[Yy]|[Yy]es) ;;
    *)
        echo "Cancelled."
        exit 1
        ;;
esac

# Handle existing worktree
if [ -d "$worktree_dir" ]; then
    echo ""
    warn "Worktree directory already exists: ${worktree_dir}"
    read -p "Remove it and continue? [Y/n] " cleanup_choice < /dev/tty
    case "$cleanup_choice" in
        ""|[Yy]|[Yy]es)
            git worktree remove "$worktree_dir" --force 2>/dev/null || rm -rf "$worktree_dir"
            git worktree prune
            ;;
        *)
            echo "Aborted. Remove the existing worktree first:"
            echo "  wt-hotfix-done hotfix-pr-${pr_number}-to-${release_date_safe}"
            exit 1
            ;;
    esac
fi

# Create worktree
echo ""
info "Creating worktree..."
mkdir -p "_hotfix"
git worktree add -b "$hotfix_branch" "$worktree_dir" "origin/${release_branch}"

sync_config_to_worktree "$repo_root" "$worktree_dir" "$invoking_wt"

# Cherry-pick
echo ""
info "Cherry-picking..."
cd "$worktree_dir"

set +e
git $cherry_pick_cmd
cherry_pick_result=$?
set -e

if [ $cherry_pick_result -eq 0 ]; then
    success "Cherry-pick succeeded!"
else
    echo ""
    warn "Cherry-pick has conflicts!"
    echo ""

    conflicting_files=$(git diff --name-only --diff-filter=U)
    echo "Conflicting files:"
    echo "$conflicting_files" | sed 's/^/  /'
    echo ""

    editor="${EDITOR:-code --wait}"
    read -p "Open conflicts in editor ($editor)? [Y/n] " open_editor < /dev/tty
    case "$open_editor" in
        ""|[Yy]|[Yy]es)
            echo "Opening editor..."
            $editor $conflicting_files 2>/dev/null || true
            ;;
    esac

    echo ""
    read -p "Have you resolved all conflicts? [y/N] " resolved < /dev/tty
    case "$resolved" in
        [Yy]|[Yy]es)
            if git diff --name-only --diff-filter=U | grep -q .; then
                err "There are still unresolved conflicts. Resolve them and run:"
                echo "  cd ${repo_root}/${worktree_dir}"
                echo "  git add ."
                echo "  git cherry-pick --continue"
                exit 1
            fi
            git add .
            git cherry-pick --continue --no-edit || git commit --no-edit
            success "Conflicts resolved!"
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
            echo "  wt-hotfix-done hotfix-pr-${pr_number}-to-${release_date_safe}"
            exit 1
            ;;
    esac
fi

# Push branch
echo ""
info "Pushing branch..."
if git push -u origin "$hotfix_branch"; then
    success "Branch pushed!"
else
    warn "Push failed. You can retry manually:"
    echo "  cd ${repo_root}/${worktree_dir}"
    echo "  git push -u origin ${hotfix_branch}"
    exit 1
fi

# Build PR body
if [ "$quick" = true ]; then
    pr_body="## Cherry-pick Info
- **Original PR:** #${pr_number}
- **Jira:** ${ticket}
- **Merge strategy:** ${strategy}
- **Merge commit:** ${merge_commit:0:8}"
else
    echo ""
    echo "Hotfix Postmortem - please provide context:"
    echo ""

    read -p "Why is this change needed in the release?
> " pm_reason < /dev/tty

    read -p "What is the customer/business impact if this isn't hotfixed?
> " pm_impact < /dev/tty

    read -p "What testing was done on the original PR?
> " pm_testing < /dev/tty

    read -p "Any additional risks or notes for reviewers? (Enter to skip)
> " pm_notes < /dev/tty

    if [ -z "$pm_notes" ]; then
        pm_notes="None"
    fi

    # Generate postmortem via claude CLI if available
    postmortem=""
    if command -v claude &> /dev/null; then
        echo ""
        info "Generating postmortem with Claude..."
        postmortem=$(claude --print "Generate a concise hotfix postmortem in markdown. Keep it to 2-3 short paragraphs. Do not include a title heading — start directly with the content. Summarize why this hotfix is needed, the risk assessment, and testing confidence." <<EOF
PR #${pr_number}: ${pr_title}
Branch: ${pr_head} -> ${pr_base}
Release target: ${release_branch}
Merge strategy: ${strategy}

Why needed in release: ${pm_reason}
Business impact: ${pm_impact}
Testing done: ${pm_testing}
Additional notes: ${pm_notes}
EOF
        ) || true
    fi

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
fi

# Create PR
echo ""
info "Creating pull request..."

if [ "$ticket" = "none" ]; then
    pr_title="Cherry-pick PR #${pr_number} to ${release_branch}"
else
    pr_title="[${ticket}] Cherry-pick PR #${pr_number} to ${release_branch}"
fi

pr_url=$(gh pr create \
    --base "$release_branch" \
    --title "$pr_title" \
    --body "$pr_body" \
    2>/dev/null) || {
    warn "PR creation failed. Branch is pushed - create it manually:"
    echo "  gh pr create --base ${release_branch} --title \"${pr_title}\""
    exit 1
}

success "Pull request created!"
echo ""
echo "   PR: ${pr_url}"
echo ""
echo "   Worktree: ${repo_root}/${worktree_dir}"
echo ""
echo "When done:"
echo "  wt-hotfix-done hotfix-pr-${pr_number}-to-${release_date_safe}"

# Write worktree dir for shell wrapper auto-cd
echo "$worktree_dir" > /tmp/.wt-hotfix-pr-last-dir
