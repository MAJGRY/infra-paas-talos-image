# AGENTS.md

Rules for agents and people who change this repository. `README.md` explains the images, the
build and the files (`image.env` by hand, `image.lock` generated, `hack/*.sh`, `build.yml`).

## This repository is public
- Commits, pull requests, workflow logs, release notes and images are readable by anyone. Never add
  internal hostnames, IP addresses, node or cluster inventories, cluster names, runner labels,
  account ids, tokens, keys or customer data; describe targets generically ("a node"), and name
  other repositories only as `README.md` does.
- Never put a machine config, talosconfig, kubeconfig or Talos secrets here or into an image (no
  `--embedded-config-path`): they carry the cluster PKI and join tokens.

## Releases are never overwritten
- `${TALOS_VERSION}-${REVISION}` (tag, GitHub release, GHCR installer tags) is published once by
  CI and never overwritten, re-tagged or deleted: nodes pin it by digest.
- Never run `hack/publish.sh`, `gh release delete` or `gh release upload --clobber` yourself, move or
  delete a tag, or push to or delete a GHCR package. Fix a broken release with the next `REVISION`.

## Update flow (Talos versions and extensions)
1. Edit `image.env`; a new `TALOS_VERSION` resets `REVISION=1`.
2. `hack/resolve.sh` rewrites `image.lock` (never by hand); commit both files together.
3. Pull request: `build.yml` checks the lock and builds every output (artifact `talos-assets`,
   3 days). Summarise the Talos release notes and the extension changes of `image.lock` in it.
4. Merge when green: the push to `main` or `release/<ver>` publishes the release.
- Bump `REVISION` with every change of `EXTENSIONS`, `image.lock` or `hack/build.sh` within one
  Talos version, or the merge publishes nothing (`check` notes that the release exists). Docs and
  workflow changes that leave the outputs alone do not bump it.
- Extensions: official Talos ones, by name, versions from the release's own list. Never remove one
  that nodes use: `gvisor` (ADR 0007), `iscsi-tools` and `util-linux-tools` (Longhorn, ADR 0006),
  `tailscale` (ADR 0010).
- No Kata Containers (microVM sandboxes) before the owner confirms nodes with `/dev/kvm` (owner
  action OA-15-12); it will be a separate image variant and the current image stays unchanged.

## Older Talos versions
- They build on `release/<talos-version>` branches (README); pull requests into them come from a
  work branch. Never force-push or delete a `release/` branch or make it the head of a pull
  request (this repository deletes head branches on merge). Single-branch clones miss them:
  `git fetch origin '+refs/heads/release/*:refs/remotes/origin/release/*'`.

## Merge rules
- Agents may merge with a green `build.yml`: `image.env`/`image.lock` patch updates (v1.14.6 to
  v1.14.7) and docs. Other changes (Talos minor or major, extension set, `hack/`, workflow) only
  when the task asks for them explicitly, with the reason in the pull request.
- Never: anything that contains internal data; deleting or overwriting a release.

## Check and verify (no cluster needed)
- `hack/install-crane.sh <dir>` (pinned crane), then `hack/resolve.sh --check`; if that fails on a
  pull request that left `image.env` alone, an upstream tag moved: resolve and bump `REVISION`.
- Local build: Linux or WSL2 with Docker, `hack/build.sh <dir>` (about 1.1 GB; `_out/` is ignored);
  it fails on a missing output and prints the kexec kernel command line for review.
- After a merge the newest run is `success` (an image change also has its release):
  `gh run list -R MAJGRY/infra-paas-talos-image --workflow build.yml --branch main --limit 1`.
- Verify a release by its sums and digests, not by rebuilding (a rebuild matches only the kernel and
  the command line). Assets: `sha256sum -c --ignore-missing SHA256SUMS` after
  `gh release download <tag> -R MAJGRY/infra-paas-talos-image -p SHA256SUMS -p <asset>`.
  Installers: `crane digest ghcr.io/majgry/infra-paas-talos-image/<platform>-installer:<tag>`
  equals the digest in the release notes.

## Workflows and pitfalls
- GitHub-hosted `ubuntu-24.04` runners only (a self-hosted runner would run code from fork PRs);
  `pull_request`, never `pull_request_target`; top-level `contents: read`, write permissions only in
  `publish`; actions pinned by SHA; `persist-credentials: false`; no secret but `github.token`.
- LF only; `hack/*.sh` keep mode 100755 (Windows: `git update-index --chmod=+x`), pass `shellcheck`.
- WSL: Linux git cannot use a worktree created by Windows git; run scripts on a `git archive` copy.
- Commits: conventional (`feat:`, `fix:`, `docs:`), ticket or card id at the end of the subject.
