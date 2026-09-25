# Building and checking Cinder

Run commands from the project root, or open `Package.swift` in Xcode.
Building and testing require macOS 27.0 or later on Apple Silicon, Xcode 27.x,
the macOS 27 SDK, and a Swift 6.x compiler at version 6.4 or later.

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

Logs are stored in `.build/mac-setup/`, `.build/compatibility-native/`,
`.build/compatibility-swift6/`, and `.build/golden-gate-app/`.
Review compiler warnings as well as exit status. Current packages use local
ad-hoc signing. Public distribution requires Developer ID signing, notarization,
and installation checks.

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
