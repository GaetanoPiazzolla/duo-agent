#!/bin/bash
# Runs the installer against a throwaway HOME and checks what it leaves behind.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; unset XDG_CONFIG_HOME CLAUDE_CONFIG_DIR
FAILED=0

check() {  # check <description> <command...>
  local what=$1; shift
  if "$@" >/dev/null 2>&1; then printf '  ok    %s\n' "$what"
  else printf '  FAIL  %s\n' "$what"; FAILED=1; fi
}
fresh_home() {
  rm -rf "$HOME"
  mkdir -p "$HOME/.claude" "$HOME/.claude-alt" "$HOME/.claude-notaprofile" "$HOME/.gemini"
  touch "$HOME/.claude-alt/.claude.json"
}
installed() { [ -f "$HOME/.agents/skills/$1/SKILL.md" ]; }
no_placeholder() { ! grep -q __DUO_HOME__ "$HOME/.config/herdr-core/templates/$1.md"; }
points_home() { grep -q "$HOME/.agents/skills/duo-plan" "$HOME/.config/herdr-core/templates/$1.md"; }
nothing_left() { [ -z "$(find "$HOME" -name 'duo-*' -print -quit)" ]; }

echo "install (copy)"
fresh_home
"$REPO/install.sh" >/dev/null
check "duo-plan skill copied"           installed duo-plan
check "duo-ask skill copied"            installed duo-ask
check "skill is a copy, not a link"     test ! -L "$HOME/.agents/skills/duo-plan"
check "launcher is executable"          test -x "$HOME/.agents/skills/duo-plan/bin/duo-claude"
check "linked into ~/.claude"           test -f "$HOME/.claude/skills/duo-plan/SKILL.md"
check "linked into detected profile"    test -f "$HOME/.claude-alt/skills/duo-ask/SKILL.md"
check "non-profile folder left alone"   test ! -e "$HOME/.claude-notaprofile/skills"
check "linked into Antigravity"         test -f "$HOME/.gemini/config/skills/duo-plan/SKILL.md"
check "duo-claude template rendered"    no_placeholder duo-claude
check "duo-agy template rendered"       no_placeholder duo-agy
check "templates point at the install"  points_home duo-agy

echo "install again (idempotent)"
check "second run succeeds"             "$REPO/install.sh"
check "skill still in place"            installed duo-plan

echo "install --link --claude-dir"
fresh_home; mkdir -p "$HOME/custom-claude"
"$REPO/install.sh" --link --claude-dir "$HOME/custom-claude" >/dev/null
check "skill links to the checkout"     test "$(readlink "$HOME/.agents/skills/duo-plan")" = "$REPO/skills/duo-plan"
check "extra Claude dir linked"         test -f "$HOME/custom-claude/skills/duo-plan/SKILL.md"

echo "refuses to overwrite a foreign folder"
fresh_home; mkdir -p "$HOME/.agents/skills/duo-plan"; echo mine > "$HOME/.agents/skills/duo-plan/notes.txt"
check "install fails"                   bash -c '! "$0/install.sh"' "$REPO"
check "foreign folder untouched"        test -f "$HOME/.agents/skills/duo-plan/notes.txt"

echo "launcher"
fresh_home; "$REPO/install.sh" >/dev/null
mkdir -p "$TMP/bin" "$TMP/project/.duo-plan"
printf '#!/bin/sh\necho "dir=[$CLAUDE_CONFIG_DIR] args=$*"\n' > "$TMP/bin/claude"; chmod +x "$TMP/bin/claude"
check "no profile file: default account" bash -c '[[ "$(cd "$1" && PATH="$2:$PATH" "$3")" == "dir=[] args=--settings "*claude-planner-settings.json ]]' _ "$TMP/project" "$TMP/bin" "$HOME/.agents/skills/duo-plan/bin/duo-claude"
printf '%s' "$HOME/.claude-alt" > "$TMP/project/.duo-plan/.claude-config-dir"
check "profile file: uses that account"  bash -c '[[ "$(cd "$1" && PATH="$2:$PATH" "$3")" == "dir=[$4]"* ]]' _ "$TMP/project" "$TMP/bin" "$HOME/.agents/skills/duo-plan/bin/duo-claude" "$HOME/.claude-alt"

echo "uninstall"
"$REPO/install.sh" --uninstall >/dev/null
check "nothing named duo-* remains"     nothing_left

echo
if [ "$FAILED" = 0 ]; then echo "all checks passed"; else echo "some checks failed"; exit 1; fi
