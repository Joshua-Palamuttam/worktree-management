#!/bin/bash
# wt-sync-permissions.sh - Promote worktree permissions to global settings
# Usage: wt-sync-permissions [--all] [--workdir <path>]
#
# Scans .claude/settings.local.json across worktrees and lets you promote
# new permissions to ~/.claude/settings.local.json (applies to all projects).

set -e

scan_all=false
workdir=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            scan_all=true
            shift
            ;;
        --workdir)
            workdir="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: wt-sync-permissions [--all]"
            echo ""
            echo "Scan worktree permissions and promote selected ones to global settings."
            echo ""
            echo "Options:"
            echo "  --all, -a   Scan all repos under WORKTREE_ROOT (default: current repo only)"
            echo "  --help, -h  Show this help"
            echo ""
            echo "What it does:"
            echo "  1. Scans .claude/settings.local.json across worktrees"
            echo "  2. Finds permissions not already in ~/.claude/settings.local.json"
            echo "  3. Presents each new permission for interactive selection"
            echo "  4. Merges selected permissions into global settings"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [ -n "$workdir" ]; then
    cd "$workdir"
fi

global_settings="$HOME/.claude/settings.local.json"

# Convert paths for Node.js (Windows binary can't read /c/Users/... paths)
# Uses cygpath -m for forward-slash Windows paths (avoids backslash escaping issues in JS)
to_node_path() {
    if command -v cygpath &>/dev/null; then
        cygpath -m "$1"
    else
        echo "$1"
    fi
}

# Ensure global settings file exists
if [ ! -f "$global_settings" ]; then
    mkdir -p "$HOME/.claude"
    echo '{"permissions":{"allow":[],"deny":[],"ask":[]}}' > "$global_settings"
fi

# Build list of worktree settings files to scan
settings_files=()

if [ "$scan_all" = true ]; then
    # Find WORKTREE_ROOT from wt-config.sh or default
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$script_dir/wt-config.sh" ]; then
        source "$script_dir/wt-config.sh"
    fi
    wt_root="${WORKTREE_ROOT:-$(dirname "$(git rev-parse --git-common-dir 2>/dev/null || echo ".")")}"

    # Scan all .git directories under worktree root
    for repo_dir in "$wt_root"/*.git; do
        [ -d "$repo_dir" ] || continue
        # Find all worktree directories
        while IFS= read -r wt_path; do
            wt_dir=$(echo "$wt_path" | awk '{print $1}')
            settings="$wt_dir/.claude/settings.local.json"
            if [ -f "$settings" ]; then
                settings_files+=("$settings")
            fi
        done < <(git -C "$repo_dir" worktree list 2>/dev/null || true)
    done
else
    # Current repo only
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    if [ -z "$repo_root" ]; then
        echo "Not in a git repository. Use --all to scan all repos."
        exit 1
    fi

    while IFS= read -r wt_path; do
        wt_dir=$(echo "$wt_path" | awk '{print $1}')
        settings="$wt_dir/.claude/settings.local.json"
        if [ -f "$settings" ]; then
            settings_files+=("$settings")
        fi
    done < <(git -C "$repo_root" worktree list 2>/dev/null || true)
fi

if [ ${#settings_files[@]} -eq 0 ]; then
    echo "No worktree settings files found."
    exit 0
fi

echo "Scanning ${#settings_files[@]} worktree settings file(s)..."

# Convert global settings path for Node.js
global_settings_node=$(to_node_path "$global_settings")

# Build JSON array of file paths (converted for Node.js)
files_json="["
first=true
for f in "${settings_files[@]}"; do
    if [ "$first" = true ]; then first=false; else files_json+=","; fi
    files_json+="\"$(to_node_path "$f")\""
done
files_json+="]"

# Use node to collect unique permissions not in global settings
new_perms=$(node -e "
const fs = require('fs');

const globalSettings = JSON.parse(fs.readFileSync('$global_settings_node', 'utf8'));
const globalAllow = new Set((globalSettings.permissions && globalSettings.permissions.allow) || []);

const allPerms = new Set();
const files = $files_json;

for (const f of files) {
    try {
        const s = JSON.parse(fs.readFileSync(f, 'utf8'));
        const perms = (s.permissions && s.permissions.allow) || [];
        for (const p of perms) allPerms.add(p);
    } catch {}
}

const newPerms = [...allPerms].filter(p => !globalAllow.has(p)).sort();
console.log(JSON.stringify(newPerms));
") || {
    echo "Error reading settings files. Is node installed?"
    exit 1
}

# Parse the JSON array into a bash array
readarray -t perm_array < <(node -e "
const perms = $new_perms;
perms.forEach(p => console.log(p));
")

if [ ${#perm_array[@]} -eq 0 ]; then
    echo "All worktree permissions are already in global settings. Nothing to do."
    exit 0
fi

echo ""
echo "Found ${#perm_array[@]} permission(s) not in global settings:"
echo ""

selected=()

for perm in "${perm_array[@]}"; do
    printf "  %s\n" "$perm"
    read -p "  Add to global settings? [y/n/a(ll)/q(uit)] " choice < /dev/tty
    case "$choice" in
        [Yy]|[Yy]es)
            selected+=("$perm")
            ;;
        [Aa]|[Aa]ll)
            selected+=("$perm")
            # Add all remaining
            local_started=false
            for remaining in "${perm_array[@]}"; do
                if [ "$local_started" = true ]; then
                    selected+=("$remaining")
                    echo "  $remaining  -> added"
                fi
                if [ "$remaining" = "$perm" ]; then
                    local_started=true
                fi
            done
            break
            ;;
        [Qq]|[Qq]uit)
            break
            ;;
        *)
            # Skip
            ;;
    esac
done

if [ ${#selected[@]} -eq 0 ]; then
    echo ""
    echo "No permissions selected. Global settings unchanged."
    exit 0
fi

# Build JSON array of selected permissions in bash
selected_json="["
first=true
for p in "${selected[@]}"; do
    if [ "$first" = true ]; then first=false; else selected_json+=","; fi
    selected_json+="\"$p\""
done
selected_json+="]"

node -e "
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync('$global_settings_node', 'utf8'));
if (!settings.permissions) settings.permissions = {};
if (!settings.permissions.allow) settings.permissions.allow = [];

const selected = $selected_json;
const existing = new Set(settings.permissions.allow);
let added = 0;
for (const p of selected) {
    if (!existing.has(p)) {
        settings.permissions.allow.push(p);
        added++;
    }
}

settings.permissions.allow.sort();
fs.writeFileSync('$global_settings_node', JSON.stringify(settings, null, 2) + '\n');
console.log('Added ' + added + ' permission(s) to global settings.');
"

echo ""
echo "Global settings updated: $global_settings"
