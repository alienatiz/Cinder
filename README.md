# Cinder

**English** · [한국어](Docs/Locales/README.ko.md) · [日本語](Docs/Locales/README.ja.md)

**Audio burn-in, made simple.**

Cinder is an audio burn-in app for earphones and headphones on Mac. Play pink
noise, frequency sweeps, your own music, or one of seven built-in tracks. Set
playback and rest times, control sessions from the menu bar, and review past
sessions.

The current version is **1.0.0-dev**, targeting **macOS 14 Sonoma or later · Apple Silicon**.
This is a development build for the first stable release. See the
[release notes](RELEASE-NOTES.md) for features and changes.
Compatibility testing on macOS 14, 15, and 26 is still in progress. See the
[current limitations and validation status](VALIDATION.md).

Optional **Intel (x86_64) experimental builds support macOS 14 through 26 only**;
macOS 27 and later are not supported for Intel. Test packages are shared through
[GitHub pre-releases](https://github.com/alienatiz/Cinder/releases).
[Intel installation and testing limits](Docs/INSTALLING-INTEL.md) apply; physical
Intel Mac validation is still pending.

## Getting started

1. Open your locally built `Cinder (Dev).app`. See **Build locally** below for build instructions.
2. In Quick Play, select the output connected to your earphones or headphones.
3. Choose a signal and a playback plan. A full cycle requires at least 60 minutes; split plans let you set each session's duration and the rest between sessions.
4. To use music, choose a built-in track or add music files from your Mac in Music.
5. Keep earphones out of your ears, start with low system/DAC volume, and check the output and app gain before pressing Start.

Pause, resume, or stop from the main window or the menu bar during playback.
Built-in signals and music work without an account or internet connection.

## Features

- **Quick Play:** Choose noise, music, a frequency sweep, or the 60-minute full cycle. Start, pause, resume, and stop in one view.
- **Quick Play Lite:** Select an output and duration, control playback, and check status, remaining time, and scheduled starts from the menu bar.
- **Music:** Select and reorder local music files, check file information and initial read results, or loop one of seven built-in tracks.
- **Output:** Check the selected device's connection type, manufacturer, current sample rate, channel count, and supported rates. Adjust gain, save gain presets, and monitor Peak/RMS levels. Mac information and published reference specifications are listed separately.
- **Schedule:** Set one-time or repeating schedules. Import and export playback and schedule presets as JSON/YAML.
- **Settings:** Choose English, Korean, or Japanese; system, light, dark, or custom themes; bar or needle meters; and a Dev/Stable update channel preference.
- **Session history (Settings):** Review the latest 500 runs, including time, rests, gain, and completion or interruption results. Search records, copy summaries, or export them.

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

Quick Play Lite offers single sessions of 1, 2, 4, or 8 hours, a custom duration,
or the continuous 40-hour plan. You can also select your existing split 40-hour
plan. Adjust session lengths, rests, signal, music, and gain in the main window;
Lite uses the same settings. Opening the popup does not change your plan. Device
and time controls are locked during playback or while waiting for a schedule.

The close button and ⌘W close only the window. **Quit Cinder or ⌘Q** stops playback
and cancels remaining schedules and plans. Choose **Open Cinder** in the menu bar
to return to the session. Relaunching does not automatically restore playback or
schedules. Hold ⌘ and drag the Cinder menu bar icon to reposition it. See [Apple's menu bar guide](https://support.apple.com/guide/mac-help/whats-in-the-menu-bar-mchlp1446/mac).

## History and current limitations

Session history stays on this Mac. After an unexpected exit, Cinder restores the
last saved records without restarting playback or schedules; the most recent
activity may be missing. Totals cover the latest 500 retained records. Records
and summaries exclude music file paths and device identifiers.

This is a development build. Real-device playback, built-in music quality,
long sessions, and installation are still being evaluated. See the
[validation status](VALIDATION.md) for confirmed checks and remaining limitations.

## Build locally

Build the development version from the `dev` branch. Building requires an
Apple Silicon Mac running macOS 27 or later with Xcode 27. This build requirement
is separate from the app's macOS 14 minimum. Initial setup needs internet access.

```bash
bash Setup-Mac.command
bash Check-Xcode.command
bash Build-App.command
```

Open the generated `dist/Cinder (Dev).app`. Development builds are locally signed
and are not Developer ID signed or notarized. See the [build guide](Docs/BUILDING.md)
for detailed requirements and packaging instructions.

## Navigation and notifications

Completion and error notifications are optional in Settings. Cinder requests macOS
notification permission the first time you enable them. Notifications are silent
and cover completion, device changes, failures, and missed schedules. Pauses and
rests do not trigger notifications. History is retained even if permission is denied.

The main areas are Quick Play, Music, Output, and Settings. Output contains device
selection, gain, and Mac information; Quick Play’s Output details button opens that
tab. Scheduling stays in Quick Play. Open Session history from Settings, or the
changelog and help from About Cinder in Settings. Use search and page controls
to browse long music lists and changelogs.

While the app is active, `⌘Return` starts, pauses, or resumes; `⌘.` stops playback.
`⌘1`–`⌘4` switch main areas, and `⌘,` opens Settings. The start shortcut is also
disabled during preparation or while waiting for a schedule. Cinder does not
intercept other players' global media keys.

## Updates

No stable version has been released yet. **Settings → Updates** lets you save a
Dev or Stable channel preference and view the installed version. Selecting a
channel does not replace the app or change playback. Automatic update downloads
and installation are not available.

## Contributing and credits

To contribute, follow the [pull request guide](DEVELOPMENT.md).

Cinder is a collaboration between **Byeongcheol Kim and OpenAI**.
See [AUTHORS.md](AUTHORS.md) and the
[music and tool credits](Sources/CinderApp/Resources/preset-music-credits.txt).
