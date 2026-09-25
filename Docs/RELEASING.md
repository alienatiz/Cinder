# Development and stable releases

The current development branch is `dev`. Stable releases will use `main` and
version tags. There is no stable 1.0.0 or LTS release yet.

| Stage | Source | Automated result |
|---|---|---|
| Development | `dev`, currently `1.0.0-dev` | Lightweight source checks; no app build |
| Staging validation | Manual run at a chosen commit on `dev` or `main` | App ZIP and SHA-256, retained in Actions for 14 days |
| Stable preparation | `main`, for example `1.0.0` | Lightweight source checks; no app build |
| Release point | A tag such as `v1.0.0` on a commit included in `main` | A GitHub Release **draft** after a successful build |
| Change review | Pull request targeting `dev` or `main` | Lightweight source checks only |

Development commits do not each produce a Mac build or Release. Staging is a
manual validation step at a selected commit, not a branch. Do not add `latest`,
`stable`, or `beta` branches. Publish only approved versions in GitHub Releases.
Current development source is published on `dev`; create `main` when promoting
the first stable release.

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

1. Check metadata, translations, music hashes, Bash syntax, and branch/tag policy.
2. Prepare dependencies on GitHub's `xcode-27` arm64 runner.
3. Run the separate Swift 6 check, default-mode XCTest, and release-configuration app build.
4. Store an app ZIP preserving executable permissions, checksums, and build identification in Actions.
5. Create a Release draft only for a stable version tag. Never publish it automatically.

New branch checks cancel older checks of the same event kind and branch. Logs are
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
