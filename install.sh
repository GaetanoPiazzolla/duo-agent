#!/bin/bash
# Installs /duo-plan and /duo-ask for Claude Code and Antigravity, plus their Herdr templates.
# macOS only. Safe to run again.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
SKILLS="duo-plan duo-ask"
TEMPLATES="duo-claude duo-agy"
SKILLS_HOME="$HOME/.agents/skills"
TEMPLATES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/herdr-core/templates"
MODE=install
LINK=0
EXTRA_CLAUDE_DIRS=""

usage() {
  cat <<EOF
Usage: ./install.sh [options]

  --link               symlink the skills to this checkout instead of copying them
  --claude-dir <dir>   also install into this Claude Code config dir (repeatable)
  --uninstall          remove everything this installer created
  -h, --help           show this help
EOF
}

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'
else B=; G=; Y=; R=; D=; N=; fi
step() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
skip() { printf '  %s-%s %s\n' "$D" "$N" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$1"; }
die()  { printf '%serror:%s %s\n' "$R" "$N" "$1" >&2; exit 1; }
short() { case "$1" in "$HOME"*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

while [ $# -gt 0 ]; do
  case "$1" in
    --link) LINK=1 ;;
    --claude-dir) [ $# -ge 2 ] && [ -d "$2" ] || die "--claude-dir needs an existing directory"
                  EXTRA_CLAUDE_DIRS="$EXTRA_CLAUDE_DIRS$2"$'\n'; shift ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

[ "$(uname -s)" = Darwin ] || die "macOS only for now (found $(uname -s))"

# Claude Code config dirs: the default one, the active one, other profiles, and --claude-dir.
claude_dirs() {
  {
    printf '%s\n' "$HOME/.claude" "${CLAUDE_CONFIG_DIR:-}"
    for d in "$HOME"/.claude-*; do
      if [ -f "$d/.claude.json" ]; then printf '%s\n' "$d"; fi
    done
    printf '%s' "$EXTRA_CLAUDE_DIRS"
  } | while IFS= read -r d; do
    if [ -n "$d" ] && [ -d "$d" ]; then (cd "$d" && pwd -P); fi
  done | awk '!seen[$0]++'
}

# Every agent skills dir we link into, one per line as "label<TAB>dir".
agent_skill_dirs() {
  claude_dirs | while IFS= read -r d; do printf 'Claude Code\t%s/skills\n' "$d"; done
  if [ -d "$HOME/.gemini" ]; then printf 'Antigravity\t%s\n' "$HOME/.gemini/config/skills"; fi
}

# True when the path is one of ours: a symlink, or a skill folder carrying our name.
is_ours() {
  [ -L "$1" ] || { [ -f "$1/SKILL.md" ] && grep -q "^name: $2\$" "$1/SKILL.md"; }
}

install_skills() {
  step "Skills → $(short "$SKILLS_HOME")"
  mkdir -p "$SKILLS_HOME"
  for s in $SKILLS; do
    target="$SKILLS_HOME/$s"
    if [ -e "$target" ] || [ -L "$target" ]; then
      is_ours "$target" "$s" || die "$target exists and is not a $s install; move it away first"
      rm -rf "$target"
    fi
    if [ "$LINK" = 1 ]; then
      ln -s "$REPO/skills/$s" "$target"; ok "$s (linked to this checkout)"
    else
      cp -R "$REPO/skills/$s" "$target"; ok "$s"
    fi
  done
  chmod +x "$SKILLS_HOME/duo-plan/bin/duo-claude"
}

link_agents() {
  step "Slash commands"
  agent_skill_dirs | while IFS=$'\t' read -r label dir; do
    mkdir -p "$dir"
    for s in $SKILLS; do
      link="$dir/$s"
      if [ -e "$link" ] && [ ! -L "$link" ]; then
        warn "$label: $(short "$link") is a real folder, left alone"; continue
      fi
      ln -sfn "$SKILLS_HOME/$s" "$link"
    done
    ok "$label: $(short "$dir")"
  done
  if [ ! -d "$HOME/.claude" ]; then warn "Claude Code config not found (~/.claude); run claude once, then install again"; fi
  if [ ! -d "$HOME/.gemini" ]; then warn "Antigravity config not found (~/.gemini); run agy once, then install again"; fi
}

install_templates() {
  step "Herdr templates → $(short "$TEMPLATES_DIR")"
  mkdir -p "$TEMPLATES_DIR"
  for t in $TEMPLATES; do
    sed "s|__DUO_HOME__|$SKILLS_HOME/duo-plan|g" "$REPO/templates/$t.md" > "$TEMPLATES_DIR/$t.md"
    ok "$t"
  done
}

check_tools() {
  step "Requirements"
  for pair in "hc:Herdr" "claude:Claude Code" "agy:Antigravity CLI"; do
    bin=${pair%%:*}; name=${pair#*:}
    if path=$(command -v "$bin" 2>/dev/null); then ok "$name ($(short "$path"))"
    else warn "$name: \`$bin\` is not on PATH; install it before using the commands"; fi
  done
}

uninstall() {
  step "Removing"
  agent_skill_dirs | while IFS=$'\t' read -r label dir; do
    for s in $SKILLS; do
      if [ -L "$dir/$s" ]; then rm "$dir/$s"; ok "$(short "$dir/$s")"; fi
    done
  done
  for s in $SKILLS; do
    target="$SKILLS_HOME/$s"
    if [ -e "$target" ] || [ -L "$target" ]; then
      if is_ours "$target" "$s"; then rm -rf "$target"; ok "$(short "$target")"
      else warn "$(short "$target") is not a $s install, left alone"; fi
    fi
  done
  for t in $TEMPLATES; do
    if [ -f "$TEMPLATES_DIR/$t.md" ]; then rm "$TEMPLATES_DIR/$t.md"; ok "$(short "$TEMPLATES_DIR/$t.md")"; fi
  done
  printf '\nDone. Project folders named .duo-plan/ are yours to delete.\n'
}

if [ "$MODE" = uninstall ]; then uninstall; exit 0; fi

check_tools
install_skills
link_agents
install_templates

printf '\n%sInstalled.%s Open a Herdr terminal, start claude or agy in a project and run:\n\n' "$B" "$N"
printf '  /duo-plan <what to plan>\n  /duo-ask  <what to answer>\n\n'
