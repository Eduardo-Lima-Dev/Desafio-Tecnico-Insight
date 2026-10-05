#!/usr/bin/env bash
# Gera as notas de uma Release agrupando os commits que mexeram em app/ desde
# a tag anterior. Uso: release-notes.sh <tag anterior ou vazio> <nova tag>
set -euo pipefail

previous=${1:-}
version=${2:?informe a nova tag}
range=HEAD
[ -n "$previous" ] && range="$previous..HEAD"

section() {
  local title=$1 pattern=$2 lines
  lines=$(git log --format='%s (%h)' "$range" -- app | grep -E "$pattern" |
    sed -E 's/^[a-z]+(\([^)]*\))?!?: //' || true)
  [ -z "$lines" ] && return 0
  printf '## %s\n\n' "$title"
  printf '%s\n' "$lines" | sed 's/^/- /'
  printf '\n'
}

section 'Novidades' '^feat(\([^)]*\))?!?:'
section 'Correções' '^fix(\([^)]*\))?!?:'
section 'Outras mudanças' '^(perf|refactor|build)(\([^)]*\))?!?:'

if [ -n "$previous" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
  printf '**Comparação completa:** https://github.com/%s/compare/%s...%s\n' \
    "$GITHUB_REPOSITORY" "$previous" "$version"
fi
