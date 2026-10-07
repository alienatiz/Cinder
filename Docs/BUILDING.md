# Building and checking Cinder

Run commands from the project root, or open `Package.swift` in Xcode.
The development workflow requires a macOS 27.0 or later host on Apple Silicon, Xcode 27.x,
the macOS 27 SDK, and a Swift 6.x compiler at version 6.4 or later.
The app deployment target is **macOS 14.0 or later, arm64**. Build-host requirements
are separate from the app's minimum OS. Keep a single codebase;
guard APIs introduced after macOS 14 with an appropriate fallback when needed.
Builds on macOS 27 do not establish runtime compatibility with earlier versions.

For staging, prioritize physical playback, menu/window behavior, settings, and
sleep/wake checks on macOS 14 and the latest target OS. Check launch and core
playback on intermediate target versions (currently 15 and 26) before claiming
support. Use each major version's latest available patch for validation. Keep
the [runtime evidence](../VALIDATION.md) separate from deployment metadata.

## Compiler, language mode, and app channel

| Setting | Current value | Meaning |
|---|---|---|
| Swift compiler | 6.4 | The tool that checks sources and produces executables |
| Swift language mode | 5 by default; separate check in 6 | Language and concurrency rules applied by the compiler |
| Cinder version and channel | `1.0.0-dev` · `dev` | The app's version and distribution stage |

The project already uses the Swift 6.4 compiler. The default is Swift 5 language
mode with complete concurrency diagnostics. `Check-Xcode.command swift6` checks
Swift 6 language mode using the same compiler. Dev/Stable channel selection does
not change either setting. See the [Swift compatibility guide](https://docs.swift.org/latest/documentation/the-swift-programming-language/compatibility/).

## Prepare and build

```bash
bash Setup-Mac.command
bash Check-Xcode.command
bash Build-App.command
```

Setup checks the host, versions, and resources, then resolves the pinned Yams
dependency. Use `bash Setup-Mac.command --check-only` to inspect the environment
without downloading dependencies. Check-Xcode builds and runs XCTest in the
default language mode. Build-App runs tests and produces a release-configuration
app at `dist/Cinder (Dev).app`; this configuration does not make it a stable release.

Scripts respect the selected Xcode installation. Set `DEVELOPER_DIR` for a command
to use another installation; the global Xcode selection is not changed.
Keep `Package.resolved` in source control and exclude build caches.

```bash
# Check Swift 6 language mode separately.
bash Check-Xcode.command swift6
# Test, build, and create local installer packages.
bash Build-DMG.command
bash Build-PKG.command
```

For a local test DMG, `bash Setup-Mac.command` followed by
`bash Build-DMG.command` is sufficient: the latter already runs default-mode
tests and builds the app. The current output is
`dist/Cinder-v1.0.0-dev-arm64.dmg` with a `.dmg.sha256` checksum file. The DMG
contains the app, an Applications shortcut, and a standalone installation guide.
Building it does not change the app version, create a branch, or publish a release.
The [release guide](RELEASING.md#build-the-current-development-version) covers
manual GitHub Actions builds and optional test release drafts.

Logs are stored in `.build/mac-setup/`, `.build/compatibility-native/`,
`.build/compatibility-swift6/`, and `.build/golden-gate-app/`.
Review compiler warnings as well as exit status. Current packages use local
ad-hoc signing. Test packages can be shared without a Developer ID, but macOS may
require an explicit first-launch exception; see [installation instructions](INSTALLING.md).
Developer ID signing, notarization, and installation checks remain requirements
for Cinder's stable release.

## Experimental Intel package

Cinder 1.0.0's official release target remains macOS 14 or later on Apple Silicon.
To prepare an optional Intel test DMG from the development channel:

```bash
bash Build-DMG.command intel-experimental
```

This builds the same sources for `x86_64`, runs the tests through Rosetta on the
Apple Silicon build host, and packages an ad-hoc signed app. Rosetta must already
be available on the build host. Physical Intel Macs do not need Rosetta to use it.
The Intel path builds the XCTest bundles and invokes the universal XCTest runner
with `arch -x86_64`; Xcode 27's SwiftPM test helper is arm64-only. The current test
suite uses XCTest, not Swift Testing.
The command rejects non-dev channels; it does not create a stable Intel release.
Use `bash Build-App.command intel-experimental` to build only the app.

Outputs are kept in `dist/intel-experimental/`, including
`Cinder-v1.0.0-dev-x86_64-experimental.dmg` and its SHA-256 file. They do not replace
the arm64 outputs. Logs use `.build/golden-gate-app-intel-experimental/`.
The DMG contains the [Intel installation guide](INSTALLING-INTEL.md).

Intel support is limited to **macOS 14 through 26**; macOS 27 and later are not
supported. This is an experimental compatibility build, not a commitment to
ongoing Intel releases. Intel hardware playback, long sessions, sleep/wake, and older-OS
runtime checks remain separate from successful compilation and Rosetta tests.
GitHub manual builds on `dev` can include Intel packages with the **Include
experimental Intel build** option; see the [release guide](RELEASING.md).
The default GitHub build and the PKG command remain arm64-only.

## Project layout

| Path | Contents |
|---|---|
| Sources/ | App, Core, Audio, DSP, Platform, and Storage modules |
| Tests/ | XCTest, audio fixtures, and release policy checks |
| Tools/ | Source validation, packaging, and optional music generation |
| Examples/ · ReferenceProfiles/ | Example settings and hardware reference data |
| Docs/ | Architecture, music, tooling, and release guides |
| Docs/Locales/ | Korean and Japanese README translations |

The seven FLAC tracks and test fixtures are included. Normal builds do not need a
synthesizer or instrument bank. See the [architecture guide](ARCHITECTURE.md) for
module boundaries and real-time audio constraints.

## Source checks and packaging

These checks require only Python 3 and its standard library:

```bash
python3 Tools/Validate-Source.py
python3 -m unittest discover -s Tests/Tooling -v
python3 Tools/Package-Source.py
```

CI also runs `python3 Tools/Check-Release.py` against the pull request's target
branch. For local use, this policy check expects a committed `dev` or `main`
checkout; it rejects arbitrary feature branch names. Run the source checks and
relevant tests on your feature branch, then let PR CI validate its target.

Source checks do not replace native compilation or listening tests.
Package-Source writes a development
source ZIP under `Cinder-artifacts` beside the project; use `--output` to choose
another directory outside the source tree. The archive has a `Cinder/` root and
a checksum. Caches, build products, and private working records are excluded.

## Optional SDK checks

Run `bash Check-LiveActivities.command` to probe Live Activities SDK availability.
Use `--require-supported` as the gate before implementing an integration. The
[SDK guide](LIVE-ACTIVITIES.md) explains the current limitations and how dependency
preparation is kept separate from runtime features.

## Documentation and contribution

Write default guides in English. Maintain the product introduction and basic
usage instructions in [English](../README.md), [Korean](Locales/README.ko.md), and
[Japanese](Locales/README.ja.md), preserving equivalent features, limits, and
release status. Use relative links so navigation also works in source archives.

For submitting changes, see [Contributing with pull requests](../DEVELOPMENT.md).
The [release guide](RELEASING.md) and [roadmap](../ROADMAP.md) describe staging and
release gates. Preserve the app ID and existing `Swinder` preferences; opening the
app or loading a preset must not start playback or activate a schedule.
