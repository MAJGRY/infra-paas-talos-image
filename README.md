# infra-paas-talos-image

Talos Linux boot images for the nodes of the PaaS (ADR 0003 in `infra-paas-controlplane`). One
image for every node and every cluster: the official Talos release plus the system extensions the
platform needs, every input pinned by digest. Cluster-specific settings and secrets are never in
the image; they come with the machine config (`infra-paas-controlplane-config`, `talos/`).

Before changing anything, read [`AGENTS.md`](AGENTS.md): what may never be published here, the
update flow, and which changes agents may merge.

## What is built

| Output | Where | Used for |
| --- | --- | --- |
| `nocloud-amd64.qcow2` | release asset | Contabo custom image (NoCloud platform): new nodes are created or reinstalled from it |
| `kernel-amd64`, `initramfs-metal-amd64.xz`, `cmdline-metal-amd64` | release assets | kexec install from a running Linux (`talos/pilot/kexec-install.sh` in the config repository) |
| `metal-installer`, `nocloud-installer` | `ghcr.io/majgry/infra-paas-talos-image/<platform>-installer:<tag>` | `installer.image` of the `UnattendedInstallConfig` document (Talos v1.14) and `talosctl upgrade --image`; use the one matching how the node was installed |
| `SHA256SUMS` | release asset | checksums of the release assets |

Extensions (`image.env`): `gvisor` (ADR 0007), `iscsi-tools` and `util-linux-tools` (Longhorn,
ADR 0006), `tailscale` (ADR 0010).

Releases are named `${TALOS_VERSION}-${REVISION}`, for example `v1.14.6-1`, and never
overwritten. Reference installer images by digest; the release notes list them.

## How it works

1. `image.env` (edited by hand): Talos version, build revision, extension names.
2. `hack/resolve.sh` pins the Talos imager, the base installer and the extension images that the
   Talos release lists (`ghcr.io/siderolabs/extensions:<version>`) to digests in `image.lock`.
   CI fails when `image.lock` does not match `image.env`.
3. `hack/build.sh` runs the pinned Talos imager in Docker and builds every output.
4. On `main` and `release/*`, CI builds and publishes (`hack/publish.sh`) unless that release
   already exists; then a push builds nothing.

Pull requests build everything too; the outputs are kept as a workflow artifact for 3 days.

## Updating Talos

```bash
$EDITOR image.env              # TALOS_VERSION=v1.14.7, REVISION=1
hack/resolve.sh                # needs crane; hack/install-crane.sh <dir> installs it
git commit -am "feat: Talos v1.14.7"
```

Check the Talos release notes and the extension versions in the `image.lock` diff before merging.
A change to the extensions or the build of the same Talos version bumps `REVISION`.

## Older Talos versions (release branches)

`main` builds the newest Talos version and its releases are marked "Latest". An older version, for
example the one the pilot installs before its upgrade check, is built on a branch
`release/<talos-version>`:

```bash
git push origin main:refs/heads/release/v1.14.5   # content of main: its release exists, nothing runs
git switch -c talos-v1.14.5 origin/release/v1.14.5
$EDITOR image.env                                  # TALOS_VERSION=v1.14.5, REVISION=1
hack/resolve.sh
git commit -am "feat: Talos v1.14.5"               # pull request into release/v1.14.5
```

Merging that pull request publishes `v1.14.5-1` like `main` does, without marking it "Latest".
To bring later build changes to a release branch, merge `main` into it and keep the branch's
`image.env` and `image.lock` (bump `REVISION` if the build changed).

## Visibility

The repository, its releases and its GHCR packages are public: Contabo imports a custom image only
from a URL without authentication, and nodes pull the installer image without credentials. Nothing
here is secret. Machine configs, keys and anything else per cluster never go into this repository
or into an image.

## Rules

- Never bake a machine config into an image (the imager can, `--embedded-config-path`): machine
  configs contain the cluster PKI and join secrets.
- Only official Talos extensions, pinned through the release's own extension list.
- Building locally needs Linux or WSL2 with Docker: `hack/build.sh _out`.
