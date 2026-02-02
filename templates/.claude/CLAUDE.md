# Claude Code Context

## Worktree Information

This is a git worktree-based development environment. Key points:

1. **Worktree Types**:
   - `main/` - Clean reference branch, avoid modifications
   - `develop/` - Integration branch for testing
   - `_feature/*/` - Active feature development
   - `_review/current/` - PR review workspace (ephemeral)
   - `_hotfix/*/` - Emergency production fixes

2. **Safe Operations**:
   - Make commits on feature branches
   - Create new branches from develop or main
   - Run tests and builds

3. **Avoid**:
   - Modifying files in `main/` worktree directly
   - Making commits in `_review/` worktrees
   - Cross-worktree file modifications

4. **Navigation**:
   - Bare repo root: `*.git/` directory
   - Each subdirectory is a separate worktree
   - Use `git worktree list` to see all worktrees

## Project-Specific Notes

(Add project-specific context here)
