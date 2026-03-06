#!/bin/bash
# wt-sync-permissions.sh - Promote worktree permissions to global settings (macOS)
# Usage: wt-sync-permissions [--all]
#
# Scans .claude/settings.local.json across worktrees and lets you promote
# new permissions to ~/.claude/settings.local.json (applies to all projects).

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

scan_all=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            scan_all=true
            shift
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

# Validate node is available
if ! command -v node &> /dev/null; then
    err "Node.js is required but not installed."
    echo "   Install: brew install node"
    exit 1
fi

global_settings="$HOME/.claude/settings.local.json"

# Ensure global settings file exists
if [ ! -f "$global_settings" ]; then
    mkdir -p "$HOME/.claude"
    echo '{"permissions":{"allow":[],"deny":[],"ask":[]}}' > "$global_settings"
fi

# Build list of worktree settings files to scan
settings_files=()

if [ "$scan_all" = true ]; then
    wt_root="${WORKTREE_ROOT:-$HOME/Developer/worktrees}"

    for repo_dir in "$wt_root"/*.git; do
        [ -d "$repo_dir" ] || continue
        while IFS= read -r wt_path; do
            wt_dir=$(echo "$wt_path" | awk '{print $1}')
            settings="$wt_dir/.claude/settings.local.json"
            if [ -f "$settings" ]; then
                settings_files+=("$settings")
            fi
        done < <(git -C "$repo_dir" worktree list 2>/dev/null || true)
    done
else
    repo_root=$(get_repo_root) || {
        err "Not in a git repository. Use --all to scan all repos."
        exit 1
    }

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

info "Scanning ${#settings_files[@]} worktree settings file(s)..."

# Build JSON array of file paths
files_json="["
first=true
for f in "${settings_files[@]}"; do
    if [ "$first" = true ]; then first=false; else files_json+=","; fi
    files_json+="\"$f\""
done
files_json+="]"

# Use node to collect unique permissions not in global settings
new_perms=$(node -e "
const fs = require('fs');

const globalSettings = JSON.parse(fs.readFileSync('$global_settings', 'utf8'));
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
    err "Error reading settings files."
    exit 1
}

# Parse JSON array into bash array (bash 3 compatible - no readarray)
perm_array=()
while IFS= read -r line; do
    [[ -n "$line" ]] && perm_array+=("$line")
done < <(node -e "
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

for i in "${!perm_array[@]}"; do
    perm="${perm_array[$i]}"
    printf "  %s\n" "$perm"
    read -p "  Add to global settings? [y/n/a(ll)/q(uit)] " choice < /dev/tty
    case "$choice" in
        [Yy]|[Yy]es)
            selected+=("$perm")
            ;;
        [Aa]|[Aa]ll)
            selected+=("$perm")
            # Add all remaining
            for (( j=i+1; j<${#perm_array[@]}; j++ )); do
                selected+=("${perm_array[$j]}")
                echo "  ${perm_array[$j]}  -> added"
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

# Build JSON array of selected permissions
selected_json="["
first=true
for p in "${selected[@]}"; do
    if [ "$first" = true ]; then first=false; else selected_json+=","; fi
    selected_json+="\"$p\""
done
selected_json+="]"

node -e "
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync('$global_settings', 'utf8'));
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
fs.writeFileSync('$global_settings', JSON.stringify(settings, null, 2) + '\n');
console.log('Added ' + added + ' permission(s) to global settings.');
"

echo ""
success "Global settings updated: $global_settings"
