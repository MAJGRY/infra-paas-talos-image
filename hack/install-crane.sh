#!/usr/bin/env bash
# Installs a pinned crane (github.com/google/go-containerregistry) for Linux x86_64 and verifies
# its checksum.
#
#   hack/install-crane.sh <bin-dir>
set -euo pipefail

VERSION=v0.22.1
# From checksums.txt of the release.
SHA256=0ab7a1d6932a213aed964ce97666c3077fe691c8606413674a8b3e0b9ec4cda0

dir="${1:?usage: hack/install-crane.sh <bin-dir>}"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

curl -fsSLo "${tmp}/crane.tar.gz" \
  "https://github.com/google/go-containerregistry/releases/download/${VERSION}/go-containerregistry_Linux_x86_64.tar.gz"
echo "${SHA256}  ${tmp}/crane.tar.gz" | sha256sum -c --quiet -
mkdir -p "${dir}"
tar -xzf "${tmp}/crane.tar.gz" -C "${dir}" crane
"${dir}/crane" version
