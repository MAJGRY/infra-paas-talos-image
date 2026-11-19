#!/usr/bin/env bash
# Builds the Talos boot assets pinned in image.lock with the Talos imager (needs Docker).
#
#   hack/build.sh [<out-dir>]      default: _out
#
# Output:
#   <out>/release/nocloud-amd64.qcow2        disk image for Contabo custom images (NoCloud)
#   <out>/release/kernel-amd64               kernel, initramfs and kernel command line for the
#   <out>/release/initramfs-metal-amd64.xz   kexec install from a running Linux
#   <out>/release/cmdline-metal-amd64        (infra-paas-controlplane-config, talos/pilot)
#   <out>/installers/<platform>/installer-amd64.tar   installer images (metal, nocloud) for
#                                                     machine configs and `talosctl upgrade`
#
# Nothing in the output is secret: machine configs are never baked into these images.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../image.env
source "${ROOT}/image.env"
# shellcheck source=../image.lock
source "${ROOT}/image.lock"

out="${1:-_out}"
mkdir -p "${out}"
out="$(cd "${out}" && pwd -P)"

ext_flags=()
for ref in ${EXTENSION_IMAGES}; do
  ext_flags+=(--system-extension-image "${ref}")
done

imager() { # <out-subdir> <imager args...>
  local dir="${out}/$1"
  shift
  mkdir -p "${dir}"
  # Not privileged: the v1.14 imager builds disk images from partition image files, without loop
  # devices (as in the boot assets docs).
  docker run --rm -i -v "${dir}:/out" "${IMAGER_IMAGE}" "$@"
}

# NoCloud disk image as QCOW2. The imager has no flag for the disk format, so the base profile
# `nocloud` is extended through a profile on stdin (fields: pkg/imager/profile in siderolabs/talos).
# diskSize is the profile default (MinRAWDiskSize, 1246 MiB); the imager enlarges the image when
# the partitions need more, and Talos grows into the real disk. diskFormatOptions is required for
# QCOW2 (the imager always passes `-o` to qemu-img); the value is the one the Image Factory uses.
echo "build: nocloud-amd64.qcow2"
{
  cat <<EOF
baseProfileName: nocloud
arch: amd64
version: ${TALOS_VERSION}
input:
  baseInstaller:
    imageRef: ${INSTALLER_BASE_IMAGE}
  systemExtensions:
EOF
  for ref in ${EXTENSION_IMAGES}; do
    echo "    - imageRef: ${ref}"
  done
  cat <<EOF
output:
  kind: image
  outFormat: raw
  imageOptions:
    diskSize: 1306525696
    diskFormat: qcow2
    diskFormatOptions: cluster_size=8k
EOF
} | imager release -

# Kexec assets (metal platform). Kernel arguments are not baked in: the kexec script passes the
# command line and the network settings itself.
echo "build: kernel, initramfs, cmdline"
imager release iso --output-kind kernel
imager release iso --output-kind initramfs "${ext_flags[@]}"
imager release iso --output-kind cmdline "${ext_flags[@]}"

# Installer images. The platform is part of the image, so a node installed from the NoCloud
# disk image upgrades with the nocloud installer and a kexec/metal node with the metal one.
for platform in metal nocloud; do
  echo "build: ${platform} installer"
  imager "installers/${platform}" installer --platform "${platform}" \
    --base-installer-image "${INSTALLER_BASE_IMAGE}" "${ext_flags[@]}"
done

expected=(
  release/nocloud-amd64.qcow2
  release/kernel-amd64
  release/initramfs-metal-amd64.xz
  release/cmdline-metal-amd64
  installers/metal/installer-amd64.tar
  installers/nocloud/installer-amd64.tar
)
for f in "${expected[@]}"; do
  [[ -s "${out}/${f}" ]] || { echo "build: ${out}/${f} is missing or empty" >&2; ls -lR "${out}" >&2; exit 1; }
done
(cd "${out}" && ls -l "${expected[@]}")
# Kernel arguments of the kexec install, for review (the Talos production notes ask self-built
# media to carry the right ones).
echo "build: cmdline-metal-amd64: $(cat "${out}/release/cmdline-metal-amd64")"
