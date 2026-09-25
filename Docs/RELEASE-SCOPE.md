# Cinder 1.0 feature scope

Review date: 2026-09-24 · Baseline: 1.0.0-dev

The first stable release centers on audio burn-in: choose an output, play defined
signals continuously, and track session time, rests, and interruption results.
Reliability of that flow takes priority over adding signal types or music-player
features. Implement and validate each item separately; do not describe unimplemented
features as available. Keep implementation status aligned with [ROADMAP.md](../ROADMAP.md).

## Lessons from other products

This comparison uses official product descriptions and developer feature lists.
It is not a hands-on assessment of their playback quality, resource use, or current
OS compatibility.

| Reference | Published features | Decision for Cinder |
|---|---|---|
| [JLab Audio Burn-in](https://www.jlab.com/pages/audio-burn-in-app-youtube) | Repeating noise/sweep/rest files, getting-started instructions, suggested 40-hour and split runs | Keep a basic cycle, rests, and simple startup. Do not generalize a manufacturer's duration or effect claims to every device |
| [1MORE Assistant](https://apps.apple.com/us/app/1more-assistant/id1064417017) | Manufacturer describes Smart Burn-in, music, connectivity, and product features | Use convenient burn-in setup as a reference; exclude shopping, accounts, and earphone firmware management. The listed last update was in 2020, so it is not evidence of current behavior |
| [Headphone Burn-In web tool](https://burninheadphones.com/) | Pink/Brown/White noise, sweeps, duration, current stage/elapsed time, left/right output | Stage and remaining time are core. Left/right checks are a later candidate; more noise types and unlimited loops are not release requirements |
| [IINA](https://iina.io/) | Music Mode, system media controls, native macOS appearance | Reference compact playback controls and consistent keyboard access; exclude online streams, plugins, and video |
| [Cog](https://cog.losno.co/) | Gapless/repeat playback, shortcuts, notifications, automatic updates, EQ, visualization, broad format support | Prioritize loop quality and status notifications. Separate general library/effects/format expansion; consider automatic update installation later |

40 hours is a plan option. JLab suggests that duration, while Shure reports no
change over time in its KSE1500 driver-performance measurements. Product-specific
claims do not establish a required duration or guaranteed sound improvement for
all earphones. Cinder distinguishes completing a plan from judging sound quality.
See the [Shure KSE1500 FAQ](https://www.shure.com/en-ASIA/go/kse1500/en/faq.html).

## A. Features to complete and validate for 1.0

Implementation and automated checks are separate from physical-device and
distribution validation.

| Feature | Current state | Required scope and acceptance criteria |
|---|---|---|
| A1. Continuous playback and transitions | Implemented; automated checks passed; device validation open | Highest reliability priority. Check physical output for unintended gaps or pops at loops, start/pause/resume/stop, and signal changes. Distinguish planned rests from dropouts |
| A2. Output and gain | Output selection, initial −30 dB, manual −60 to 0 dB gain, meters, stop on device change | Test jack/USB/Bluetooth disconnect/reconnect and format changes without unexpected playback on another output. Show device, signal, duration, and gain before Start. Never present app gain as actual sound pressure |
| A3. Plans and time accounting | Continuous/split 40 hours, custom duration, session/signal/rest breakdown, whole-plan finish estimate | Keep estimates clearly provisional when preparation, pauses, or sleep affect them. Check actual rest/resume behavior and layout |
| A4. History and interruption reasons | Latest 500 local records, search, summary copy/export | Record time, selected output, signal, gain, and completed sessions for completion/user stop/device change/error. Retain records after relaunch. Provide user-initiated copy/export without automatic file upload |
| A5. Window closing and menu controls | Quick Play Lite and continued execution after window close; menu UI use unverified | Validate main-window/Lite output, duration, and controls against one shared session. Distinguish closing from quitting; cancel remaining schedules on quit. Respect normal menu icon order |
| A6. Completion and failure feedback | Optional completion/error notifications and settings, off by default | Notify selectively for completion/errors/device changes/missed schedules. Preserve results when denied. Ask permission on enable, not at every stage |
| A7. Music and basic signals | Pink-like, Band-limited, sweep, external music, seven built-in tracks | Keep current signals/tracks. Revision 5 adds development/dynamics/instrumentation; listening and loop-quality evaluation remain open. Explain external music limits/processing and test read failure/cancellation. Defer new genres/signals |
| A8. Scheduling, rests, and sleep | One-time/repeating schedules and split rests; simulated-time checks passed | Check real rest/resume, sleep/wake, time zones, and late cancellation. Restore history only on relaunch, without autoplay or reactivating schedules. Explain that continued execution requires the app to remain running |
| A9. Settings, accessibility, and help | Three languages, persistence, music inspection, themes, offline help, playback shortcuts; full UI checks open | Keep core controls visible at minimum size. Check keyboard/VoiceOver/contrast/errors, settings upgrades, and corrupt files. Explain offline core features, supported formats, minimum OS, and support routes |
| A10. Installation and distribution | Local ad-hoc app; Dev/Stable preference only | Developer ID signing/notarization; fresh install, overwrite, settings retention, relocation. Provide a manual route to approved releases and notes. Do not imply channel selection has replaced the app |

Long-session validation includes 1/8/40-hour playback and resume after split rests.
Measure CPU, memory, energy, and resource recovery after repeated preparation and
cancellation. Verify the minimum supported Mac class, such as M1, before asserting
coverage across Apple Silicon, and check actual formats per output. Automated tests
on one M2 Pro do not establish support for every Mac and device.

### Time and history rules

The full 60-minute cycle contains two 5-minute rests. Running this cycle for
40 hours of session time schedules **33 hours 20 minutes of signal** and
**6 hours 40 minutes of internal rest**. Inter-session rests are additional.
Preserve the meaning of the existing 40-hour setting and show the breakdown in
plan summaries and history.

Separate session progress, signal intervals, rests, pauses, and preparation in
records. App-counted signal time is not a measurement of sound pressure, earphone
output, or sound-quality change; it also includes any silence inside a music file.
Analog earphones swapped on the same jack cannot be identified automatically, so
1.0 records are associated with the selected output. Per-earphone totals may later
use names supplied by the user.

Reading interrupted history is separate from resuming a plan. Restoring history
in 1.0 does not start playback. Any later resume feature must confirm the current
output, gain, and remaining time before the user starts. History storage and export
stay outside the real-time audio path.

### Music scope

External music currently has a combined 10-minute limit, mono/stereo input at
8–96 kHz, and a 256 MB limit after conversion to output PCM. Preparation applies
band processing and end fades, so this path is not unprocessed or bit-perfect
playback. Duration limits and processing must be clear during music selection.

Eliminating unintended noise-loop gaps is required by A1. Seamless album-style
transitions between arbitrary external tracks, long-file streaming, and an
unprocessed listening path are later scope. Improving the existing seven tracks
remains a release requirement; it does not imply expanding genres or generating
music in real time.

## B. Features retained in advanced settings

| Existing feature | Presentation |
|---|---|
| Full/single signals; gain/playback/schedule presets; JSON/YAML import/export | Allow a simple default start; put preset management and file formats in detail views |
| Mac/DAC specs, UID, PCM/sample-rate information | Always show the output name; expand for reference specs, identifiers, and technical details. Do not derive gain automatically from specs |
| Theme editing, color tokens, needle meters | Default to system appearance and group under personalization; defer more themes |
| Dev/Stable selection | Keep in Updates with clear release/installer availability. Do not add it to the playback view |
| Changelog | Paginated under About/Settings, with a name and purpose distinct from session history |

Do not remove implemented features merely because they belong in advanced settings.
Preserve settings compatibility and commit actual UI moves as separate changes.

## C. Candidates after 1.0

| Candidate | Reason to defer and conditions |
|---|---|
| Left/right checks and short output preview | Useful diagnostics, not essential to burn-in. Design a separate short check with automatic stop and preserved gain |
| White/Brown signals and custom cycles | Validate continuity of current signals first. More noise types do not imply stronger effects |
| Per-earphone goals and resuming remaining plans | Depend on local history; distinguish user-named devices from selected outputs and keep explicit Start |
| Long external files, gapless queues, ReplayGain | Require new memory, file I/O, and level policies; assess separately from the current burn-in music path |
| Media keys, Now Playing, optional launch at login | Need checks for player conflicts and unintended starts; complete Lite and app-local shortcuts first |
| Update lookup/download/install and actual channel switching | Require approved distributions, signature checks, and upgrade/downgrade policy; manual distribution can serve the first release |
| Default Swift 6 language mode | A maintenance/quality decision after concurrency/lifetime review. The compiler is already 6.4; this is unrelated to Dev/Stable |

## D. Excluded from 1.0

| Item | Reason |
|---|---|
| Streaming services, accounts, cloud libraries, lyrics, tag editing, large album libraries | Separate product scope with authentication, networking, and library maintenance |
| EQ, AutoEQ, upsampling, DSD, exclusive/bit-perfect modes, plugins | Need different output and processing policies and can obscure the current gain/processing path |
| Frequency-response/SPL/hearing diagnosis without measurement hardware; burn-in scores or sound-improvement guarantees | Cannot be inferred from digital signals and elapsed time |
| Forced volume increases, automatic sound-pressure compensation, guaranteed device-specific durations, unlimited default loops | Preserve explicit duration and manual gain instead of assumptions about devices or surroundings |
| A helper/daemon surviving actual quit, forced autoplay | Window-close persistence and menu controls cover current needs; relaunch/login alone must not produce sound |
| Native Live Activities and an always-visible floating window | Finish the menu bar flow first; ActivityKit availability follows the separate [SDK checks](LIVE-ACTIVITIES.md) |
| LTS, extra stable/staging branches, Mac builds on every development commit | Avoid extra operation before the first release; retain dev source checks, manual staging, and reviewed stable releases |

## Screen layout and implementation order

The four main areas are **Quick Play / Music / Output / Settings**.
Schedule is part of Quick Play. Output groups device selection, gain, and Mac
information. Session history is in Settings, with the changelog under About. Quick Play and Lite keep device, signal, duration,
gain summary, progress, and playback controls visible. Long music/history lists
use pagination and search, with core controls fixed. Do not shrink text or harm
accessibility to force content into the window.

1. **Check and fix current issues:** real-device noise continuity, output changes, preparation cancellation, rest/resume.
2. **Time and history:** plan summary, local record model/storage, history view/export.
3. **Background use:** Lite in practice, completion/error notifications, keyboard/accessibility.
4. **Music and layout:** seven-track refinement/listening, external music guidance, advanced settings placement.
5. **Release validation:** long sessions, minimum Mac, three languages, settings upgrades, signing/notarization, installation.

Within each stage, validate and commit independent features and fixes separately.
For example, a history UI can be reverted before its storage foundation, but
reverting the foundation alone cannot be promised to preserve that UI. Validate
SDK preparation before committing dependent runtime features. Retain version,
branch, and build policies while recording implementation and verification status.
