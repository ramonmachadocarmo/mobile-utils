#!/usr/bin/env bash
# Cria a tag da versão atual do pubspec.yaml e a envia para o GitHub, o que
# dispara o workflow Android (deploy no teste interno da Play Store).
#
# Fluxo típico:
#   scripts/bump_version.sh patch
#   scripts/release.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

version="$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
tag="v${version}"

if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "A tag $tag já existe. Rode scripts/bump_version.sh antes." >&2
  exit 1
fi

# Commita a mudança de versão, se o pubspec estiver alterado.
if ! git diff --quiet -- pubspec.yaml; then
  git add pubspec.yaml
  git commit -m "chore: release $tag"
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
git push origin "$branch"

# Cria a tag e a envia — o push da tag dispara o deploy.
git tag -a "$tag" -m "$tag"
git push origin "$tag"

echo "Tag $tag publicada. Acompanhe o deploy em Actions."
