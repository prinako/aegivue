#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx is required (install Node.js/npm first)" >&2
  exit 1
fi

# Codex is the default. Additional skills CLI agent identifiers may be passed
# as arguments, for example: ./scripts/install-agent-skills.sh codex claude-code
if (( $# == 0 )); then
  agents=(codex)
else
  agents=("$@")
fi

cd -- "${REPO_ROOT}"

install_skills() {
  local source=$1
  shift

  # No --global flag: all payloads stay project-scoped in this checkout.
  npx --yes skills add "${source}" \
    --agent "${agents[@]}" \
    --yes \
    --skill "$@"
}

# Flutter and Dart web development.
install_skills https://github.com/flutter/agent-plugins \
  flutter-apply-architecture-best-practices \
  flutter-setup-declarative-routing \
  dart-run-static-analysis

# PostgreSQL schema, migration, and query guidance.
install_skills https://github.com/neondatabase/postgres-skills \
  postgres-best-practices

# FFmpeg/ffprobe media inspection and bounded transformations.
install_skills https://github.com/wyattowalsh/agents \
  ffmpeg

# General engineering workflow and Git conflict resolution.
install_skills https://github.com/mattpocock/skills \
  diagnosing-bugs \
  code-review \
  codebase-design \
  resolving-merge-conflicts

# Root-cause debugging, TDD, and evidence-based completion checks.
install_skills https://github.com/obra/superpowers \
  systematic-debugging \
  test-driven-development \
  verification-before-completion
