# Cinder

**English** · [한국어](Docs/Locales/README.ko.md) · [日本語](Docs/Locales/README.ja.md)

**Audio burn-in, made simple.**

Cinder is an audio burn-in app for earphones and headphones. Choose pink noise,
music, or a frequency sweep and start a burn-in session that fits your needs.
Set playback and rest times, follow progress from the menu bar, and keep your
burn-in history in one place.

The current version is **1.0.0-dev**, targeting **macOS 14 Sonoma or later · Apple Silicon**.
This development build is preparing for the first stable release. See the
[release notes](RELEASE-NOTES.md) for features and changes.
The deployment target is macOS 14. Runtime checks on macOS 14, 15, and 26 remain
pending; current execution evidence is from macOS 27. See [validation](VALIDATION.md).

## Getting started

1. Open your locally built `Cinder (Dev).app`. See **Build locally** below for build instructions.
2. In Quick Play, select the output connected to your earphones or headphones.
3. Choose a signal and a playback plan. A full cycle requires at least 60 minutes; split plans let you set each session's duration and the rest between sessions.
4. To use music, choose a built-in track or add music files from your Mac in Music.
5. Keep earphones out of your ears, start with low system/DAC volume, and check the output and app gain before pressing Start.

Pause, resume, or stop from the main window or the menu bar during playback.
Built-in signals and music work without an account or internet connection.

## Features

- **Quick Play** — Run a continuous 40-hour plan, split 40 hours into sessions, or set a custom duration. Adjust session and rest lengths. Play noise, music, a sweep, or a full 60-minute cycle, with start, pause, resume, and stop in one view.
- **Quick Play Lite** — Choose an output and duration from the menu bar. Control playback and check status, remaining time, and schedules even with the main window closed.
- **Music** — Select and reorder local music files, inspect file information and initial read results, or loop one of seven built-in tracks.
- **Output** — See the selected device, connection, manufacturer, current sample rate and output channels. View device-supported rates in details; use live meters, precise gain controls and named gain presets. Mac information and published reference specifications are shown separately.
- **Schedule** — Configure one-time or repeating schedules and import or export playback and schedule presets as JSON/YAML.
- **Settings** — English, Korean, and Japanese; system, light, dark, and custom themes; bar or needle Peak/RMS meters; Dev/Stable update channel selection.
- **Session history (Settings)** — Keep the latest 500 runs on this Mac, including time, rests, gain, and completion or interruption results. Search, copy summaries, or export records.

App gain starts at −30 dB and can be adjusted manually from −60 to 0 dB.
Choosing a device or reference profile does not change gain automatically.
Digital gain and meters do not represent actual sound pressure. Opening the app
or loading a preset does not start playback or activate a schedule.

## Playback plans

| Plan | Behavior |
|---|---|
| Continuous 40 hours | Run one 40-hour session |
| Split 40 hours | Set session duration and rest intervals; the final session uses the remaining time so sessions total 40 hours |
| Custom duration | Run one session from 1 minute to 1000 hours, in one-minute increments |

For example, 3-hour sessions with 30-minute rests produce thirteen 3-hour sessions
and a final 1-hour session. Thirteen rests bring the estimated total to 46 hours
30 minutes. The next session starts after its rest. Closing the window keeps the
plan running. Stop, Quit, an output change, or disconnection cancels the remaining
plan. If a start is missed by more than one minute, for example after sleep,
Cinder does not resume it automatically.

40 hours is an available plan, not a universal burn-in recommendation.
Session time includes rests within the selected full cycle; rests between sessions
are added separately. Quick Play shows session time, signal time, cycle rests, and
rests between sessions separately. The finish estimate covers the entire split
plan and moves later during preparation or pauses. With a full cycle, every
session, including the last, must be at least 60 minutes.

**Quick Play Lite** offers 1, 2, 4, 8, or 40 hours and custom time entry. The 1-, 2-,
4-, and 8-hour options and custom durations are single sessions; continuous 40-hour
and existing split plans are also available. Opening the popup does not change
your plan. Adjust session lengths, rests, signal, music, and gain in the main
window; Lite shares those settings. Device and time controls are locked while
running or waiting for a schedule.

The close button and ⌘W close only the window. **Quit Cinder or ⌘Q** stops playback
and cancels remaining schedules and plans. Choose **Open Cinder** in the menu bar
to return to the session. Relaunching does not automatically restore playback or
schedules. Cinder uses a normal menu bar icon and respects macOS and your chosen
icon order without forcing a position or priority. Hold ⌘ and drag the icon to
reposition it. See [Apple's menu bar guide](https://support.apple.com/guide/mac-help/whats-in-the-menu-bar-mchlp1446/mac).

## Development status

History is saved about every 5 seconds during playback and at state changes.
After an unexpected exit, records recover up to the last saved checkpoint without
restarting playback or schedules. Recorded signal time describes the app's
playback intervals, not a measurement at the earphones. Totals cover only the
latest 500 retained records. Records and summaries exclude music paths and
device UIDs.

Automated Mac builds and audio signal checks have passed. Noise continuity on
real devices, the arrangements and dynamics of all seven tracks, long sessions,
and distribution checks remain in progress. See the [validation status](VALIDATION.md)
and [1.0.0 roadmap](ROADMAP.md).

## Build locally

The development workflow requires a macOS 27.0 or later build host, Apple Silicon,
Xcode 27.x, and the macOS 27 SDK. The generated app targets macOS 14.0 or later.
The default uses the Swift 6.4 compiler in Swift 5 language mode with complete
concurrency diagnostics. Yams 6.2.2 is pinned; initial setup needs internet access.

```bash
bash Setup-Mac.command
bash Check-Xcode.command
bash Build-App.command
```

The output is `dist/Cinder (Dev).app`. It uses a local ad-hoc signature and is not
a Developer ID signed or notarized distribution build. See the [build guide](Docs/BUILDING.md)
for packaging and the separate Swift 6 check.

The public version is `1.0.0-dev`. To meet macOS bundle numbering requirements,
the marketing version is `1.0.0` and the internal build is `5.0.0`. The app ID
remains `local.chu.cinder`; existing preferences remain in
`~/Library/Application Support/Swinder/`.

## Navigation and notifications

Completion and error notifications are optional in Settings. Enabling them first
requests macOS notification permission. Silent notifications cover completion,
device changes, failures, and missed schedules, not every pause or rest.
History is retained even if permission is denied.

The main areas are Quick Play, Music, Output, and Settings. Output contains device
selection, gain, and Mac information; Quick Play’s Output details button opens that
tab. Scheduling stays in Quick Play. Open Session history from Settings, or the
changelog and help from About Cinder in Settings. Long music lists and changelogs use search or pagination.

While the app is active, `⌘Return` starts, pauses, or resumes; `⌘.` stops playback.
`⌘1`–`⌘4` switch main areas, and `⌘,` opens Settings. The start shortcut is also
disabled during preparation or while waiting for a schedule. Cinder does not
intercept other players' global media keys.

## Development and stable releases

Select and save Dev or Stable under **Settings → Updates**. The installed app's
version and channel are shown separately. Channel selection does not replace the
app or alter playback. No stable version has been released yet; update download
and installation are not implemented. Swift language mode and update channel
are separate settings.

| Stage | Policy |
|---|---|
| `dev` | Development source; commits and pull requests run source checks only |
| Staging | Manually build and validate accumulated changes in Actions |
| `main` | Reviewed source, starting with the first stable release |
| Tags such as `v1.0.0` | Build for release and create a Release draft |

There is no staging branch or always-on build server. Development app artifacts
are retained in Actions for 14 days and identified by commit hash within a
development version. LTS will be considered after the first stable release if
maintenance needs justify it. See the [release guide](Docs/RELEASING.md).

## Documentation and credits

English is the default for guides and contribution documentation. The README
language links are independent of the app's language setting.

[Submit a pull request](DEVELOPMENT.md) · [Build guide](Docs/BUILDING.md) ·
[Architecture](Docs/ARCHITECTURE.md) · [Built-in music](Docs/Audio/PRESET-MUSIC.md) ·
[Release notes](RELEASE-NOTES.md)

Cinder is a collaboration between **Byeongcheol Kim and OpenAI**. Commits produced
through ChatGPT/Codex record this attribution. See [AUTHORS.md](AUTHORS.md) and the
[music and tool credits](Sources/CinderApp/Resources/preset-music-credits.txt).
