# Development and stable releases

The current development branch is `dev`. Stable releases will use `main` and
version tags. There is no stable 1.0.0 or LTS release yet.

| Stage | Source | Automated result |
|---|---|---|
| Development | `dev`, currently `1.0.0-dev` | Lightweight source checks; no app build |
| Staging validation | Manual run on `dev` or `main` | DMG, app ZIP, SHA-256 files, and commit identification; retained in Actions for 14 days |
| Test distribution | Manual `dev` run with **Prepare a test release draft** selected | The same files in a GitHub Release **draft**, marked as a pre-release |
| Stable preparation | `main`, for example `1.0.0` | Lightweight source checks; no app build |
| Release point | A tag such as `v1.0.0` on a commit included in `main` | A GitHub Release **draft** after a successful build |
| Change review | Pull request targeting `dev` or `main` | Lightweight source checks only |

Development commits do not each produce a Mac build or Release. Staging is a
manual validation step at a selected commit, not a branch. Do not add `latest`,
`stable`, or `beta` branches. Publish only approved versions in GitHub Releases.
Current development source is published on `dev`; create `main` when promoting
the first stable release.

## Build the current development version

Use `dev` to test the integrated application. A separate branch is not needed
just to produce a build. For an independent feature or experiment, create a
working branch from `dev`, test locally, and submit a pull request to `dev` before
using this shared build workflow. Manual CI app builds accept `dev` and `main`
only; pull requests still receive source checks.

1. Commit and push the changes to `dev` after their checks pass.
2. Open **Actions → Build → Run workflow** and select **dev**.
3. Leave **Prepare a test release draft (dev only)** unchecked for an Actions-only
   build. Check it when preparing files for a test distribution.
4. Start the workflow. Confirm its commit matches the intended source, and wait
   for source checks and the macOS job to pass.
5. Download `Cinder-staging-1.0.0-dev-<commit>-arm64` from the run's **Artifacts**.
   Unzip the artifact container to find the DMG, app ZIP, checksums, and build details.

The branch choice selects its current commit when the run is dispatched; later
commits do not change that run's source. Check the displayed commit before using
its result. For repeat testing of an earlier run, choose **Re-run all jobs** on
that run. It uses the original commit. Workflow changes made later will not be
part of that rerun.

If GitHub CLI is installed and authenticated with repository write access:

```bash
# Build files only.
gh workflow run build.yml --repo alienatiz/Cinder --ref dev
# Also prepare a test release draft.
gh workflow run build.yml --repo alienatiz/Cinder --ref dev -f test_release=true
```

With the draft option selected, the final job prepares a release named
`Cinder test-1.0.0-dev-<commit>`. Tags use `test-{version}-{branch}-{commit}`:
the base version (`1.0.0`), source branch (`dev`), and seven-character commit hash.
For example, `test-1.0.0-dev-47c362d` targets the full commit used for the build.
The app retains its full prerelease version, currently `1.0.0-dev`, on the `dev`
channel. Run IDs and attempt numbers appear in the notes, not the tag or title.

New runs and reruns of the same commit use the same tag. If its release already
exists for that full commit, the job keeps the original notes and assets and
skips creation. Inspect an incomplete draft manually before sharing it; a rerun
does not replace partial uploads. An existing tag without a release, or a release
for a different target, stops creation for review. Existing tags and releases are
not moved or overwritten. The `test-` prefix does not trigger the stable `v*`
workflow. Earlier tags keep their original names and links.

A draft is not publicly downloadable. Review the assets and notes under
**Releases**, keep **Set as a pre-release** enabled, then publish the draft when
ready to share it. It is not designated as the latest stable release. Public
test downloads can then use the Release assets without relying on expiring
Actions artifacts. No draft or release is created when the option is unchecked.

Test builds currently use ad-hoc signing and are not notarized. See
[Installing Cinder](INSTALLING.md) for the first-launch steps and current testing
limits. Publishing a test pre-release does not satisfy the stable release gates.
For a local DMG without GitHub Actions, run `bash Build-DMG.command`; see the
[build guide](BUILDING.md).

### Optional Intel test distribution

The official 1.0.0 release targets macOS 14 or later on Apple Silicon. An optional
`x86_64` development package can be built with
`bash Build-DMG.command intel-experimental` and shared separately for Intel user
testing. See [Intel build instructions](BUILDING.md#experimental-intel-package).
There is no 32-bit build or ongoing Intel support commitment.

For a test pre-release, attach the Intel experimental DMG and matching checksum
from `dist/intel-experimental/` manually and include the
[Intel installation and testing limits](INSTALLING-INTEL.md) in its notes.
Keep it marked as experimental and distinguish Rosetta test results from physical
Intel Mac results. The existing GitHub workflow continues to produce arm64 files;
it does not build or attach Intel packages automatically. Do not present the Intel
package as a stable release or as physically validated without device evidence.

## Channel selection in the app

Choose `dev` or `stable` in Settings → Updates. The choice is saved in
`swift-updates-v1.json` in the existing settings directory without modifying
playback or UI settings files. Existing installations without this file default
to the installed app's channel: `stable` for stable builds and `dev` for development
and validation builds.

The current feature saves the choice and shows the installed version and channel.
Release distribution is not connected, so it does not download, install, or restart
the app. Selecting `stable` does not rename or convert a development build, create
a Git branch, or change the Swift compiler or language mode.

Actual switching will require approved distribution lookup, Developer ID signature
and notarization verification, settings compatibility, and installation/restart
after playback has ended. Do not serve development or staging artifacts as stable.
Keep the unreleased-status notice until distribution integration is ready.

## Automation

The repository uses one workflow, `.github/workflows/build.yml`. Pushes and pull
requests run only step 1 below. When enough work is ready, choose `dev` under
Actions → Build → Run workflow to start staging validation. Commit count does not
trigger it. Stable version tags also trigger app builds. There is no always-on
server or scheduled build.

Source checks and release draft jobs use `ubuntu-24.04` explicitly so a change to
`ubuntu-latest` does not switch their OS version. GitHub still updates packages
within that image. The app itself is built on the `xcode-27` macOS runner.

1. Check metadata, translations, music hashes, Bash syntax, and branch/tag policy.
2. Prepare dependencies on GitHub's `xcode-27` arm64 runner.
3. Run the separate Swift 6 check, default-mode XCTest, and release-configuration app build.
4. Create and verify a DMG; store it alongside an app ZIP preserving executable permissions, checksums, and build identification in Actions.
5. Create a Release draft for a stable version tag, or a pre-release draft when explicitly requested on `dev`. Never publish either automatically.

New push/PR checks cancel older checks of the same event kind and branch. A manual
or tag build already in progress is allowed to finish. Logs are
retained for 7 days and app artifacts for 14 days; neither build products nor local
working records belong in the repository. Staging filenames include the version
and short commit hash to distinguish builds. The development app displays
`Cinder (Dev)` and public version `1.0.0-dev`.

GitHub's `xcode-27` runner was in **public preview** when checked on 2026-09-24.
The workflow verifies the actual OS, Xcode, SDK, and Swift and fails on a mismatch.
An image name does not establish real-device compatibility. Check availability
and run results in Actions. See the [runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
and [Xcode 27 image](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).

## Promoting a version

Keep development at `1.0.0-dev` without a numeric suffix. Do not bump the version
for each commit; staging artifacts use the commit hash. If separate validation
stages become necessary, versions such as `1.0.0-beta.1` or `1.0.0-rc.1` can be
introduced deliberately. `dev` accepts prerelease versions only; `main` accepts
stable versions such as `1.0.0` only.

For release preparation, update these together and run the source checks:

- `VERSION`
- `Build-Identity.sh`: public, marketing, and build versions; channel; app name
- `Sources/CinderCore/Models.swift`: Identity version, build, and channel
- `Sources/CinderApp/Resources/changelog.json`: actual changes for the version

Stable builds use channel `stable` and name `Cinder`. Current development builds
use channel `dev` and name `Cinder (Dev)`. Future alpha/beta/rc builds use their
respective channels and `Cinder (Beta)`. Increase the internal build number for
each new distribution. Preserve `local.chu.cinder` and the existing `Swinder`
settings location. Channels currently share settings; separate installations and
isolated settings are not supported.

Promote source that satisfies [ROADMAP.md](../ROADMAP.md) to `main`, then tag the
release commit with `v` followed by the exact VERSION value. Do not move or
overwrite tags. Release checks reject invalid tags, development version tags,
and commits that are not included in `main`.

Automated builds currently use ad-hoc signing. Review device results and release
notes, then prepare Developer ID signed and notarized files before publishing.
The [release body](RELEASE-DRAFT.md) begins with an introduction to Cinder as an
audio burn-in app. Check the description against that version's actual features,
complete distribution instructions, and remove the **Before publishing** section
only when all release gates have been met.

## When to add LTS

LTS is a commitment to provide bug and security fixes for an older version after
new versions are released. Cinder does not designate an LTS before its first stable
release. If new features or OS requirements later leave users on an older version,
define its support end date and maintenance scope before adding a branch such as
`release/1.x`. Explicitly extend CI branch and tag-origin rules at that point;
current CI does not accept that branch.

## Collaboration

Every ChatGPT/Codex commit records Byeongcheol Kim's author identity and
`Co-Authored-By: OpenAI <noreply@openai.com>`.
