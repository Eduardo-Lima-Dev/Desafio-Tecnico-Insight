#!/usr/bin/env bash
# Calcula a próxima versão a partir dos commits que mexeram em app/ desde a
# última tag, seguindo Conventional Commits:
#   tipo!: ou BREAKING CHANGE no corpo  -> major
#   feat                                -> minor
#   fix ou perf                         -> patch
#   docs, chore, ci, test, refactor...  -> sem release
# Imprime linhas chave=valor: previous, bump e next.
set -euo pipefail

previous=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)
range=HEAD
base=0.0.0
if [ -n "$previous" ]; then
  range="$previous..HEAD"
  base=${previous#v}
fi

subjects=$(git log --format=%s "$range" -- app)
bodies=$(git log --format=%b "$range" -- app)

bump=none
if printf '%s\n' "$subjects" | grep -Eq '^[a-z]+(\([^)]*\))?!:' ||
  printf '%s\n' "$bodies" | grep -Eq '^BREAKING[ -]CHANGE'; then
  bump=major
elif printf '%s\n' "$subjects" | grep -Eq '^feat(\([^)]*\))?:'; then
  bump=minor
elif printf '%s\n' "$subjects" | grep -Eq '^(fix|perf)(\([^)]*\))?:'; then
  bump=patch
fi

IFS=. read -r major minor patch <<<"$base"
case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

echo "previous=$previous"
echo "bump=$bump"
echo "next=v$major.$minor.$patch"
