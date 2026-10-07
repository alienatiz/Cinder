# Cinder 1.0.0 roadmap

The current version is **1.0.0-dev**. The goal is a first stable release verified
on macOS 14 or later / Apple Silicon. No release date has been set.

An optional Intel 64-bit development build supports **macOS 14 through 26 only**
for experimental testing; **macOS 27 and later are not supported for Intel**.
See the [build guide](Docs/BUILDING.md#experimental-intel-package). It does not
expand the official 1.0.0 support target or promise ongoing Intel releases.
Physical Intel Mac and older-OS validation remain pending. No 32-bit build is planned.

## Feature scope

The [1.0 scope](Docs/RELEASE-SCOPE.md) draws on official feature descriptions of
burn-in tools and macOS players. Implementation and validation are tracked separately.

| Category | Scope |
|---|---|
| 1.0 core | Continuous playback, output control, time/rest plans, Quick Play Lite, seven-track quality, schedules, settings, installation checks |
| 1.0 priorities | Clear time accounting, local history and interruption reasons, summary export, optional completion/error notifications |
| Advanced settings | Theme editor, meter style, DAC reference specs, preset files, update channel, changelog |
| After release | Left/right checks, more signals, resuming plans, longer music queues, media keys, actual automatic updates |
| Excluded from 1.0 | Streaming/accounts, EQ/DSD/bit-perfect modes, burn-in effect scoring, automatic gain increases, persistent helper, LTS |

## Implementation and release validation

| Area | Current state | Remaining before stable release |
|---|---|---|
| Build | Local builds: 94 tests in each language mode. GitHub staging at `bc444ab`: 91 tests per mode, downloaded arm64 archive and ad-hoc signature verified | Verify the signed distribution build and installation |
| OS compatibility | Deployment target macOS 14; Xcode 27 / Swift 6.4 build tools retained | Run on macOS 14, 15, and 26; prioritize oldest/latest OS physical playback, menu/window, settings and sleep/wake checks |
| Swift 6 | Separate-mode build and 94 tests passed; default remains Swift 5 | Review concurrency/resource lifetimes before deciding on the default mode |
| Audio | Noise loop boundaries and offline source-node/mixer checks passed | Continuous real-device output, jack/USB/Bluetooth, device changes/disconnection |
| Music | Revision 5 arrangements, dynamics, and instrumentation; loop/conversion checks passed | Listening evaluation and further arrangement refinement |
| UI/settings | Four main areas, pagination, offline help, playback shortcuts, Quick Play Lite implemented | Menu popup use, three languages, themes, minimum window, VoiceOver, errors, upgrades |
| Scheduling | One-time/repeating schedules and presets implemented | Time zones, DST, wake from sleep, cancellation on quit |
| Long sessions | Continuous/split 40-hour plans and custom duration; simulated transitions/rests passed | 1/8/40-hour playback, device output after rests, CPU/memory/energy, repeated cancellation |
| Distribution | Local ad-hoc app and packaging paths | App relocation, installation/upgrades, Developer ID signing/notarization |
| Time/history | Time breakdown, whole-plan finish estimate, 500 local records, interruption reasons/export | Real long-session records, interrupted recovery, UI validation |
| Completion/errors | Optional notifications, preferences, denial/delivery-failure checks passed | Real signed-app banners and permission settings |
| Update channel | Dev/Stable selection saved; installed version/channel shown separately | Clear manual distribution path and installed-build information for the first release; actual lookup/download/install/switching remains post-release scope |

Automated signal tests do not establish listening quality on physical outputs.
Real-device noise continuity and all seven arrangements remain open release items.
Environment details and evidence are recorded in [VALIDATION.md](VALIDATION.md).

Development stays on `dev`; app builds run manually at staging. Promote source
that meets these gates to `main` and manage releases with tags. Consider LTS only
after the first stable release, based on support needs and scope. See the
[release guide](Docs/RELEASING.md).
