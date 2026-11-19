#!/usr/bin/env bash
# Publishes the output of hack/build.sh as ${TALOS_VERSION}-${REVISION}: the installer images go
# to GHCR, the boot assets with SHA256SUMS to a GitHub release. Runs in CI on main only.
# A release that already exists is never overwritten.
#
#   hack/publish.sh <out-dir>
#
# Environment: GH_TOKEN (contents: write, packages: write), GHCR_USER, GITHUB_REPOSITORY,
# GITHUB_SHA. Needs crane and gh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../image.env
source "${ROOT}/image.env"

out="${1:?usage: hack/publish.sh <out-dir>}"
: "${GH_TOKEN:?}" "${GHCR_USER:?}" "${GITHUB_REPOSITORY:?}" "${GITHUB_SHA:?}"
tag="${TALOS_VERSION}-${REVISION}"

if gh release view "${tag}" --repo "${GITHUB_REPOSITORY}" >/dev/null 2>&1; then
  echo "::notice::release ${tag} already exists; bump REVISION in image.env to publish a new build"
  exit 0
fi

registry="ghcr.io/${GITHUB_REPOSITORY,,}"
crane auth login ghcr.io -u "${GHCR_USER}" --password-stdin <<<"${GH_TOKEN}"

installers=""
for platform in metal nocloud; do
  ref="$(crane push "${out}/installers/${platform}/installer-amd64.tar" "${registry}/${platform}-installer:${tag}")"
  echo "publish: ${ref}"
  installers+="| ${platform} | \`${registry}/${platform}-installer:${tag}\` | \`${ref#*@}\` |"$'\n'
done

(cd "${out}/release" && sha256sum -- * >SHA256SUMS)

notes="$(mktemp)"
trap 'rm -f "${notes}"' EXIT
cat >"${notes}" <<EOF
Talos ${TALOS_VERSION} with the extensions ${EXTENSIONS}, built from ${GITHUB_SHA}.

| Installer | Image | Digest |
| --- | --- | --- |
${installers}
Use the digest in machine configs (\`machine.install.image\`) and for \`talosctl upgrade --image\`.
Assets: \`nocloud-amd64.qcow2\` (Contabo custom image), \`kernel-amd64\`,
\`initramfs-metal-amd64.xz\` and \`cmdline-metal-amd64\` (kexec install), \`SHA256SUMS\`.

<details><summary>image.lock</summary>

\`\`\`
$(cat "${ROOT}/image.lock")
\`\`\`
</details>
EOF

gh release create "${tag}" --repo "${GITHUB_REPOSITORY}" --target "${GITHUB_SHA}" --title "Talos ${TALOS_VERSION} (${tag})" \
  --notes-file "${notes}" "${out}"/release/*
echo "publish: release ${tag}"
