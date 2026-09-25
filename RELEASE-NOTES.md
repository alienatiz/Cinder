# Cinder 1.0.0-dev

**Audio burn-in, made simple.**

Cinder is an audio burn-in app for earphones and headphones. Choose pink noise,
music, or a frequency sweep and start a burn-in session that fits your needs.
Set playback and rest times, follow progress from the menu bar, and keep your
burn-in history in one place.

The current version is 1.0.0-dev, targeting macOS 27 and Apple Silicon.
These are the features and changes in the development build preparing for the
first stable release.

## Playback and music

- Play pink noise, band-limited noise, music, or sweeps individually, or use a full 60-minute cycle with rests. Set sessions from 1 minute to 1000 hours in one-minute increments.
- Quick Play offers continuous 40 hours, split 40 hours, and custom duration. Set each split session and rest interval; the last session uses the remaining time. The app shows session count, estimated duration including rests, and completed sessions, and starts the next session after its rest.
- Output, plan, progress, gain, and playback controls fit in one Quick Play view without scrolling. Stop, Quit, or an output change cancels remaining split sessions. A start missed by more than one minute does not resume automatically.
- The macOS menu bar shows status, remaining time, output, and the next schedule, with pause, resume, stop, and schedule cancellation. Closing the window keeps playback running; Open Cinder returns to it. Quit Cinder or ⌘Q ends playback and cancels remaining plans.
- Quick Play Lite offers output selection, 1/2/4/8/40-hour or custom duration, and player-style start/pause/resume/stop buttons. It shares the existing split plan, signal, music, and gain. Device/time changes are locked during a run or schedule, and windowless device selection uses the same validation and settings storage.
- Select and reorder library tracks. View format, bit depth, sample rate, duration, and initial read checks. Detected problems in selected files block playback and scheduling.
- Seven built-in tracks are available: Classic, Balanced, Electronic, Acoustic, POP, Rock, and Metal. Revision 5 revises introductions, bridges, instrument entries, reprises, and endings while preserving BPM and loop length. The chosen track loops until the session ends.

## Time, history, and controls

- Plan summaries distinguish session time, signal intervals, cycle rests, and rests between sessions. The whole-plan finish estimate reflects pauses, preparation, and rests.
- Store the latest 500 runs locally, including completion, user stop, device change, failure, app quit, and missed schedules. Search history and copy or export time, rest, gain-range, and completed-session summaries.
- Save history about every 5 seconds and on state changes. After an unexpected exit, restore only up to the last checkpoint without starting playback.
- Optionally enable completion/error notifications in Settings. Permission is requested when enabled, and banners are silent. Denied permission does not remove history.
- Four main areas: Quick Play, Music, Output, and Settings. Output groups device selection, gain, and Mac information; Quick Play links to it and retains schedule settings. Session history, theme editing, About, and the changelog open from Settings. Music, history, and changelogs use pagination.
- App-local shortcuts: `⌘Return` starts/pauses/resumes, `⌘.` stops, `⌘1`–`⌘4` switch areas, and `⌘,` opens Settings.

## Output, schedules, and preferences

- Select and save Dev/Stable under Updates in Settings. Installed version/channel remain visible separately. No stable release exists yet, and update download/installation are not implemented. Selection does not alter playback, schedules, or the installed app.
- Manually adjust gain from −60 to 0 dB and save named gain presets. Reset restores the saved default or the gain in the applied playback preset.
- View connected outputs, app PCM information, and Mac/DAC reference specifications in Output. Selecting a device or reference profile does not automatically change gain.
- Set one-time or daily repeating schedules and a total run count. Import/export playback and schedule presets as JSON/YAML. Schedules require explicit activation and are cancelled when the app quits.
- English, Korean, and Japanese; system/light/dark appearance and custom themes; bar or needle Peak/RMS meters.
- Preserve existing duration, gain, theme, music selection, and presets. Launching the app or loading a preset does not start playback or activate a schedule.

## Improvements

- Revised processing that caused volume dips at pink and band-limited noise loop boundaries.
- Stop the engine after the pause fade completes and report resume failures. Clean up playback state and resources on stop, output change, or disconnection.
- Improve cancellation during music preparation and reduce unnecessary conversion and copies. Check required memory before handling large files.
- Separate Peak/RMS measurement from UI refreshes and prevent paused silence from affecting RMS immediately after resume.
- Improve duration display after completion and progress reset after settings changes. Reduce repeated meter refreshes and apply theme background/text colors together.

## Validation still in progress

Automated Mac signal tests passed, but continuous noise output needs further checks
with physical earphones and output devices. The seven revised arrangements still
need listening evaluation and refinement. Long sessions, output changes,
scheduling/wake behavior, and distribution validation remain open.

Current builds are for development. Digital gain and meters do not represent actual
sound pressure. The 60-minute cycle describes playback structure; 40 hours is an
available plan, not a universal burn-in recommendation. Session time includes
rests inside a full cycle; rests between sessions are additional.
See [VALIDATION.md](VALIDATION.md) for evidence and limits.
