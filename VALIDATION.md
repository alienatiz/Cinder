# 1.0.0-dev validation status

Evidence includes the **2026-10-07** experimental Intel and arm64 package checks,
the **2026-10-03** deployment compatibility build, and
**2026-09-25** local/GitHub automated checks and local app inspection.
Stable distribution and full device validation remain in progress.

## Experimental Intel package and arm64 regression - 2026-10-07

Execution host: macOS 27.0.1 (26A434), Apple Silicon arm64; Xcode 27.0 (27A266a),
Swift 6.4, selected SDK 27.0. Public version: 1.0.0-dev; internal build: 5.0.1.
The official 1.0.0 target remains macOS 14 or later on Apple Silicon.

- Default-mode XCTest passed 99 tests (79 core/audio/storage/platform, 20 app)
  for each architecture: arm64 natively and x86_64 through Rosetta. Intel tests
  use the universal XCTest runner explicitly; SwiftPM's helper is arm64-only.
- Both release-configuration app builds and DMGs passed resource and ad-hoc
  signature checks. Mach-O minimum OS and Info.plist both report macOS 14.0.
- The Intel DMG passed integrity and SHA-256 checks. Read-only inspection verified
  an x86_64-only app matching the build, the experimental installation guide,
  and the Applications link. The image was unmounted after inspection.
- Source validation passed all nine groups; 13 tooling tests passed, including
  isolated output/cache paths and development-only Intel packaging.
- Xcode emits an x86_64 deprecation warning referring to macOS 27 during the
  Intel builds; the packaged app's minimum OS was separately verified as 14.0.
  The arm64 build has no compiler warnings. The existing hdiutil commands emit
  deprecation warnings on this host; image creation and verification succeed.

Logs: `.build/intel-experimental-dmg.log`,
`.build/golden-gate-app-intel-experimental/`, and
`.build/intel-change-arm64-regression.log`. Swift 6 mode was not rerun for this
packaging change. Physical Intel hardware, earlier-OS execution, UI, actual audio
output, sleep/wake, and long sessions remain unverified. No stable release or
ongoing Intel support is implied. Existing noise and music listening gates remain open.

## macOS 14 deployment build — 2026-10-03

Execution host: macOS 27.0.1 (26A434), arm64. Build tools: Xcode 27.0 (27A266a),
Swift 6.4, selected macOS SDK 27.0. The app deployment target is now macOS 14.0;
the development host and compiler requirements remain unchanged.

- Default-mode app build and separate Swift 6 check each passed 94 tests
  (76 core/audio/storage/platform and 18 app-model), with zero compiler warnings.
- The arm64 app's Mach-O minimum OS and Info.plist `LSMinimumSystemVersion` both
  report 14.0. Resource checks and strict ad-hoc signature verification passed.
- Source/resource validation, six release-policy tests, Bash syntax, and local
  documentation links passed.
- Offline audio continuity and ownership/pause tests use the same connection
  compatibility helper as playback. On this host they exercise the macOS 27 path.
  The macOS 14–26 setup path is compiled but has not been executed on those OSes.

Logs: `.build/macos14-app.log` and `.build/macos14-swift6.log`.
No physical playback or new UI inspection was performed for this change. No new
GitHub app build was dispatched. Prior UI/device evidence below remains tied to
its recorded environment and build; it does not establish earlier-OS support.

| Target OS | Runtime evidence for this deployment change |
|---|---|
| macOS 14 Sonoma | Pending: launch, playback/output changes, menu/window, settings and sleep/wake |
| macOS 15 Sequoia | Pending: launch and core playback; expand checks for OS-specific issues |
| macOS 26 Tahoe | Pending: launch and core playback; expand checks for OS-specific issues |
| macOS 27 Golden Gate | Automated tests on 27.0.1 passed; physical playback and full release gates remain open |

## Earlier environment and results — 2026-09-25

Execution environment: macOS 27.0 / arm64, Xcode 27.0, macOS SDK 27.0, Swift 6.4.

One manual staging build on `dev` succeeded for commit
`bc444ab893d80dd55ed04a835c05e73f198b4b83`:
[GitHub Actions run 36087628029](https://github.com/alienatiz/Cinder/actions/runs/36087628029).
The `xcode-27` runner reported macOS 27.0 / arm64, Xcode 27.0 (27A266a),
Swift 6.4, and macOS SDK 27.0. Both default-mode and separate Swift 6 checks
passed 91 tests with no compiler warnings. Source and release-policy checks,
app packaging, and artifact uploads passed; the Release draft job was skipped.

The downloaded `Cinder-staging-1.0.0-dev-bc444ab-arm64.zip` matched its SHA-256
checksum (`5c89fbda510865f895f4eaf237fb554e0752f49e612343c5c9fa02dae71c3953`).
Artifact digests, build identification, arm64 architecture, executable permissions,
and strict codesign verification passed after extraction. The app is ad-hoc
signed and not notarized. These results establish CI build and archive validity;
they do not establish installation, physical playback, or stable-release readiness.
The app artifact is retained in Actions for 14 days and validation logs for 7 days.

| Check | Scope | Result |
|---|---|---|
| Default build/XCTest | Swift 5 mode, complete concurrency diagnostics | 94 tests passed; 0 compiler warnings |
| Separate Swift 6 check | Language-mode migration compatibility | 94 tests passed; 0 compiler warnings |
| App packaging | Default-mode XCTest, arm64 release build, bundle/signature checks | 94 tests, resources, and strict codesign passed |
| Source/resources | Version, translations, seven music hashes, paths, scripts | 9 groups passed |
| Release policy | Development/stable separation, tag origin, source publication scope | 6 tests passed |
| App basics | Development name/version/changelog, settings restoration, no automatic playback | Confirmed |
| Playback plans | 40-hour total, final remainder, rests, stop, late cancellation, storage, presets | 7 XCTest cases passed (included in 94) |
| Quick Play UI | Korean/English, plan changes, session/rest entry, retained duration, invalid split feedback | Checked at 1280×800 with no Quick Play scrolling |
| Window lifetime | Close/reopen during brief live playback, pause, ⌘Q | Elapsed time retained, pause and process termination confirmed |
| Shared output selection UI | Clear and reselect the existing output in the main window | Start disabled/enabled; gain and split plan retained; no automatic playback |
| Quick Play Lite logic | Windowless output storage, time edits, locks, start validation, split-rest cancellation | 5 new app-model tests passed (included in 94), using temporary settings and virtual devices |
| Update channel logic | Existing settings, invalid files, choice save/restore, unchanged playback/schedules, save failure | 5 new tests passed (included in 94), using temporary settings |
| Update settings UI | Channel choice, installed information, unreleased notice | Native build passed; actual clicks/layout remain unchecked |
| Time/history | Session/signal/rest distinctions, whole-plan estimate, results, atomic storage, recovery, corrupt files | 12 new XCTest cases passed (included in 94) |
| System notifications | Off by default, explicit permission, denial/delivery failure with retained results | 5 new XCTest cases passed (included in 94); actual system banners unverified |
| Initial four-area UI | Quick Play, Music, Session history, Settings; music pagination; output/schedule/About/changelog | Layout and routes checked in Korean at 1280×800 before the Output navigation change |
| Initial Output navigation and history placement | Main Output tab, device/gain/Mac information, ⌘3, Session history inside Settings | Default app build and separate Swift 6 check each passed 91 tests with 0 compiler warnings. New app launched; Korean Output and Settings/history routes and an existing record were checked. Minimum-size and full three-language interaction checks remain open |
| Output device details | Driver-reported manufacturer, connection, sample rate, channel count and supported rate ranges; shared meters, gain and presets | 94 tests passed in each language mode with 0 compiler warnings. Missing-device, malformed-rate and cleared-selection cases passed. Korean layout, MacBook Pro Speakers metadata (48 kHz, 2 channels), details/reference sheets and gain synchronization checked at 1280×800 without scrolling; no physical playback started |
| Shortcuts and live records | External Headphones at −30 dB; ⌘Return start/pause/resume, ⌘. stop, former ⌘3 history shortcut | 17 seconds playback, 5 paused, 3 preparing; text export and record restoration after relaunch; no automatic playback. ⌘3 now opens Output |
| Built-in music revision 5 | Seven regenerated tracks, peaks, finite samples, hashes, loop boundaries, conversion | Passed including 6 existing music XCTest cases; musical listening evaluation incomplete |
| Menu bar UI | Lite output/time choices, player controls, status/schedules | Native build passed; current UI tool did not expose the system menu bar, so direct click/layout checks remain incomplete |

Default-mode `Build-App.command` packaging and the separate Swift 6 check were
rerun for timing, history, notifications, navigation, shortcuts, and revised music.
The current 94 tests comprise 76 core/audio/storage/platform tests and 18 app-model
tests, including three additional output metadata and selection cases. New
automated tests do not start physical playback. The brief live run was a separate
UI check, not listening evidence that noise dropouts are resolved. Three-language
resource parity and the changelog were checked, but not every UI path in all
languages. Execution logs remain in `.build/`.

Split-plan tests simulate time to verify transitions and cancellation. They do
not establish successful physical 40-hour playback, device output after rests,
or wake-from-sleep behavior.

## Audio test coverage

- AVAudioEngine offline output through the app's source node and mixer: Pink, Band-limited, and Pink fallback without music at 32/44.1/48/192 kHz; one minute per case and varying callback sizes. Zero sample difference from the C DSP reference.
- Energy-drop checks passed at the 12/24/36/48-second loop boundaries.
- PCM ownership/release and pause/engine restart checks passed.
- Built-in music and external FLAC conversion through AVAudioConverter, plus preparation cancellation, passed.

Offline tests do not verify physical output latency, dropouts, or analog quality.
**Real-device noise continuity validation is not complete.** Numeric music checks
do not establish the quality of the arrangements.

## Remaining validation

- Runtime checks on macOS 14, 15, and 26; actual audio output on the compatibility path.
- Jack, USB, and Bluetooth output; device changes/disconnection; actual listening.
- Play, pause, resume, stop, preparation cancellation, and varied session lengths.
- Lite popup layout in all three languages, keyboard access, output/time selection, playback controls, open window, and quit.
- Automatic starts/cancellation for schedules and split rests with the window closed; time zones, DST, and wake from sleep.
- Fresh installation, settings upgrades, three languages, themes, minimum window size, keyboard access, and errors.
- Update settings selection, persistence after relaunch, and three-language layout. Actual download/install/switching after distribution integration.
- CPU, memory, and energy for 1/8/40-hour runs; real split-plan restart; resource cleanup after repeated cancellation.
- Listening evaluation of all seven revision 5 tracks and further arrangement, dynamics, and development adjustments.
- DMG/PKG installation/upgrades, Developer ID signing, and notarization. The host currently has no Developer ID Application certificate.

Ordinary GitHub pushes and pull requests run source checks only. Native app builds
run on manual staging or stable tags, and never publish a stable release automatically.
