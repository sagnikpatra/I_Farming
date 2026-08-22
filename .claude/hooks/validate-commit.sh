#!/bin/bash
# Claude Code PreToolUse hook: Validates git commit commands
# Receives JSON on stdin with tool_input.command
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)
#
# Input schema (PreToolUse for Bash):
# { "tool_name": "Bash", "tool_input": { "command": "git commit -m ..." } }

INPUT=$(cat)

# Parse command -- use jq if available, fall back to grep
if command -v jq >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Only process git commit commands
if ! echo "$COMMAND" | grep -qE '^git[[:space:]]+commit'; then
    exit 0
fi

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null)
if [ -z "$STAGED" ]; then
    exit 0
fi

WARNINGS=""

# Check design documents for required sections
DESIGN_FILES=$(echo "$STAGED" | grep -E '^design/gdd/')
if [ -n "$DESIGN_FILES" ]; then
    while IFS= read -r file; do
        if [[ "$file" == *.md ]] && [ -f "$file" ]; then
            for section in "Overview" "Player Fantasy" "Detailed" "Formulas" "Edge Cases" "Dependencies" "Tuning Knobs" "Acceptance Criteria"; do
                if ! grep -qi "$section" "$file"; then
                    WARNINGS="$WARNINGS\nDESIGN: $file missing required section: $section"
                fi
            done
        fi
    done <<< "$DESIGN_FILES"
fi

# Validate JSON data files -- block invalid JSON
DATA_FILES=$(echo "$STAGED" | grep -E '^assets/data/.*\.json$')
if [ -n "$DATA_FILES" ]; then
    # Find a working Python command
    PYTHON_CMD=""
    for cmd in python python3 py; do
        if command -v "$cmd" >/dev/null 2>&1; then
            PYTHON_CMD="$cmd"
            break
        fi
    done

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if [ -n "$PYTHON_CMD" ]; then
                if ! "$PYTHON_CMD" -m json.tool "$file" > /dev/null 2>&1; then
                    echo "BLOCKED: $file is not valid JSON" >&2
                    exit 2
                fi
            else
                echo "WARNING: Cannot validate JSON (python not found): $file" >&2
            fi
        fi
    done <<< "$DATA_FILES"
fi

# Check for hardcoded gameplay values in gameplay code
# Uses grep -E (POSIX extended) instead of grep -P (Perl) for cross-platform compatibility
# Update (2026-08-23): also matches godot/scripts/economy/ -- this
# project's real gameplay-logic root (no src/gameplay/ exists here).
# Verified by direct empirical test: this check never fired for any
# godot/scripts/economy/ commit before this fix, confirmed with a
# staged synthetic file containing an obvious hardcoded value.
CODE_FILES=$(echo "$STAGED" | grep -E '^(src/gameplay/|godot/scripts/economy/)')
if [ -n "$CODE_FILES" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Update (2026-08-23): also matches GDScript's typed-declaration
            # syntax (`name: Type = value`) via an optional type-annotation
            # group between the identifier and the `=` -- the original
            # pattern only matched an untyped `name = value`/`name: value`,
            # which never fires against this project's actual GDScript
            # style (every real const/var declaration is typed). Verified
            # empirically: a synthetic `const damage: int = 25` line
            # produced zero warning before this fix, a real one after.
            if grep -nE '(damage|health|speed|rate|chance|cost|duration)[[:space:]]*(:[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)?[:=][[:space:]]*[0-9]+' "$file" 2>/dev/null; then
                WARNINGS="$WARNINGS\nCODE: $file may contain hardcoded gameplay values. Use data files."
            fi
        fi
    done <<< "$CODE_FILES"
fi

# Check for TODO/FIXME without assignee -- uses grep -E instead of grep -P
# Update (2026-08-23): also matches godot/ -- this project's real source
# root (no root-level src/ exists here). Note: this project's own
# established convention throughout is bare TODO/FIXME with a dated,
# contextual explanation in a doc comment right above (not a `TODO(name)`
# owner tag) -- this check will flag that convention as a style warning
# every time it fires. Left the check itself as-is (a WARNING, not a
# BLOCKED, so it doesn't stop a real commit) rather than silently
# suppressing it -- surfacing the convention mismatch honestly is more
# useful than hiding it, and a human can decide whether to adopt owner
# tags or leave the check as an accepted, ignorable warning for this repo.
SRC_FILES=$(echo "$STAGED" | grep -E '^(src/|godot/)')
if [ -n "$SRC_FILES" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if grep -nE '(TODO|FIXME|HACK)[^(]' "$file" 2>/dev/null; then
                WARNINGS="$WARNINGS\nSTYLE: $file has TODO/FIXME without owner tag. Use TODO(name) format."
            fi
        fi
    done <<< "$SRC_FILES"
fi

# Print warnings (non-blocking) and allow commit
if [ -n "$WARNINGS" ]; then
    echo -e "=== Commit Validation Warnings ===$WARNINGS\n================================" >&2
fi

exit 0
