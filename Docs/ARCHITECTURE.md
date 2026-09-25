# Cinder 1.0 architecture

The root `Package.swift` defines modules and resources. Sources, resources, and
test fixtures are resolved through paths relative to the repository.

| Module | Responsibility |
|---|---|
| CinderApp | SwiftUI views, AppModel, scheduling and task lifetimes, user actions |
| CinderCore | Session, preset, theme, genre, duration, gain, and schedule rules |
| CinderAudio | AVAudioEngine, loading/converting external music and built-in presets, PCM ownership transfer |
| CinderDSP | C11 render callback, fixed buffers, gain, fades, and meter aggregation |
| CinderPlatform | Core Audio device discovery/observation, model information, sleep prevention, main-run-loop timer |
| CinderStorage | JSON/YAML settings, presets, themes, and resource discovery |

Music preparation runs outside the render callback and checks cancellation.
Prepared PCM ownership transfers to the C engine. The playback callback performs
no music generation, file access, or dynamic allocation. The engine stops after
the pause fade completes, and meters aggregate audio blocks between UI updates.

Playback plans separate persistable `PlaybackPlan` from in-memory `PlaybackPlanRun`.
Split sessions total 2,400 minutes; rests are measured from each actual completion.
AppModel starts the engine for each session and uses the existing schedule timer
between sessions. Active runs and timers are not persisted or automatically restored
after quitting. Existing `hours` values remain custom durations, and presets without
the optional plan fields remain readable.

The main window and `MenuBarExtra` share one app-lifetime AppModel. Closing the
window does not end playback, schedules, or device observation. AppDelegate handles
activation and actual termination; `AppModel.shutdown()` cleans up playback,
schedules, sleep prevention, and pending saves. Playback state refreshes once a
second when the main window is closed or the app is inactive. The menu countdown
is display-only; the existing timer starts the next session. No ActivityKit or
separate background service is required.

Quick Play Lite creates neither a separate playback engine nor a settings copy.
`AppModel.selectOutput()` checks locking and device availability, then updates the
sample rate and stored choice. Both views share start eligibility and duration/plan
methods. Custom-time editing blocks Start and ends on apply, cancel, popup close,
or an external settings change. CinderAppTests use temporary settings and virtual
devices to check windowless actions without starting audio.

The menu item uses standard `MenuBarExtra` placement. The app does not assign
position or priority, overwrite stored icon order, or demand a slot beside Control
Center. macOS manages the order chosen by the user.

Tests/CinderCoreTests cover core rules, storage, scheduling, noise, and music
loading. Fixture paths are relative to test sources. SwiftPM bundles JSON, images,
and FLAC from Sources/CinderApp/Resources. App generation checks bundle layout and
preset hashes.

Normal development needs the project and Xcode. Python tools validate sources,
create archives, or optionally regenerate music offline. Using the supplied FLAC
files does not require Python, FluidSynth, or a SoundFont at runtime.

Live output, memory, and energy are checked separately on a Mac. See
[VALIDATION.md](../VALIDATION.md) for the current evidence and limits.

## Main navigation

The main areas are Quick Play, Music, Output, and Settings. Output reuses the
shared device and gain controls, live meters, and gain presets. Device details
are a read-only Core Audio snapshot refreshed on selection, device-list refresh,
or opening Output; reads stay outside the render callback. Unsupported metadata
remains unknown. Physical channel counts and supported rate ranges describe the
driver, while Cinder still renders stereo at 32–192 kHz. Mac/DAC reference profiles
are presented separately and are not detected hardware capabilities. Quick Play's Output
details action and ⌘3 open the same tab. Session history lives inside Settings;
its storage, capture, search, and export are unchanged. History pages show three
records to fit the settings area without adding a main-view scroll container.

## Session history storage

`SessionRecorder` accumulates played frames and preparation, pause, and inter-session
wait times in the control flow. `SessionHistoryStore` atomically saves the latest
500 records to `swift-history-v1.json`, separately from playback/UI settings, and
rejects invalid records before saving. A FIFO background queue writes about every
5 seconds and on state transitions, and drains at actual app termination.
Encoding and file I/O never enter the render callback.

An unfinished record can be marked `interrupted` at its last saved timestamp on
next load. This is historical state, not an instruction to restore playback or
schedules. Playback integration and the history view depend on this storage;
revert integration before the foundation. Records omit music file paths and
output device UIDs.

## System notifications

`CinderPlatform.SessionNotifications` uses UserNotifications from the macOS SDK.
Without installing an external SDK, it checks authorization, requests permission
when the user enables notifications, and sends silent banners. Initialization
alone never requests permission; CLI/XCTest hosts do not access the system service.
`SessionNotifying` isolates app tests from real permission dialogs and delivery.
Preferences are stored separately and default to disabled.

The settings view and completion/error delivery depend on this foundation.
Revert app integration first, not the foundation alone. Notifications are optional
and not a prerequisite for playback.

After a record becomes final, the app notifies only for completion, device change,
failure, or missed schedule. Permission is requested when enabled in Settings;
delivery only checks the current authorization. Denial or delivery failure does
not change history or playback state. Notifications are off by default and silent.
