#!/usr/bin/env bash
# Sobe a versão em pubspec.yaml e incrementa o build number (o +N), que vira o
# versionCode do Android — sempre crescente, então o deploy não quebra.
#
# Uso: scripts/bump_version.sh <major|minor|patch>
#   1.2.3+1010  --patch-->  1.2.4+1011
#   1.2.3+1010  --minor-->  1.3.0+1011
#   1.2.3+1010  --major-->  2.0.0+1011
set -euo pipefail

part="${1:-}"
case "$part" in
  major | minor | patch) ;;
  *)
    echo "Uso: $0 <major|minor|patch>" >&2
    exit 1
    ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
pubspec="$root/pubspec.yaml"

line="$(grep -E '^version:' "$pubspec")"
current="${line#version: }"
name="${current%%+*}"
build="${current#*+}"
[[ "$current" == *+* ]] || build=1000
IFS='.' read -r major minor patch <<<"$name"

case "$part" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch) patch=$((patch + 1)) ;;
esac

build=$((build + 1))
# Trava de segurança: o versionCode precisa ficar acima do último upload (1000).
((build > 1000)) || build=1001

new="${major}.${minor}.${patch}+${build}"
tmp="$(mktemp)"
sed -E "s/^version:.*/version: ${new}/" "$pubspec" >"$tmp" && mv "$tmp" "$pubspec"
echo "$current -> $new"
