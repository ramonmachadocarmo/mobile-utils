#!/usr/bin/env bash
# Publica a versão atual do pubspec.yaml como Release no GitHub, o que dispara o
# workflow Android (deploy no teste interno da Play Store).
#
# Fluxo típico:
#   scripts/bump_version.sh patch
#   scripts/release.sh
#
# Requer o GitHub CLI (gh) autenticado: gh auth login
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

command -v gh >/dev/null || {
  echo "Instale o GitHub CLI (gh) e rode 'gh auth login'." >&2
  exit 1
}

version="$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
tag="v${version}"

if git rev-parse "$tag" >/dev/null 2>&1 || gh release view "$tag" >/dev/null 2>&1; then
  echo "Release/tag $tag já existe. Rode scripts/bump_version.sh antes." >&2
  exit 1
fi

# Commita a mudança de versão, se o pubspec estiver alterado.
if ! git diff --quiet -- pubspec.yaml; then
  git add pubspec.yaml
  git commit -m "chore: release $tag"
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
git push origin "$branch"

# Publica o Release (cria a tag). O workflow dispara em release: published.
gh release create "$tag" --title "$tag" --generate-notes

echo "Release $tag publicado. Acompanhe o deploy em Actions."
