# Live Activities SDK boundaries

ActivityKit and WidgetKit are Apple system frameworks bundled with Xcode.
Do not install a separate Swift package or copy these frameworks into the repository.

## Current support

The macOS 27 SDK can import the frameworks, but marks the Live Activities
creation, update, and end APIs, and `ActivityConfiguration`, unavailable on macOS.
Mac system Live Activities are received through the iPhone integration.

- [ActivityKit](https://developer.apple.com/documentation/activitykit)
- [iPhone notifications and Live Activities on Mac](https://support.apple.com/en-us/120684)
- [Apple DTS guidance on Mac presentation](https://developer.apple.com/forums/thread/834361)

## Check the SDK

Run these against the project's selected Xcode, SDK, and deployment target.
They respect `DEVELOPER_DIR` and do not change the global Xcode selection.

```bash
bash Check-LiveActivities.command
bash Check-LiveActivities.command --require-supported
```

Each run checks module imports, then compilation of the activity lifecycle and
presentation APIs. Probe code is not executed. Results, environment details, and
compiler logs are written to `.build/live-activities-sdk/check.*/`.

| Status | Default exit code | `--require-supported` exit code | Meaning |
|---|---:|---:|---|
| `compile-supported` | 0 | 0 | Compiles; permissions, system presentation, and long sessions still need validation |
| `unsupported` | 0 | 2 | The SDK explicitly marks the APIs unavailable on macOS |
| `error` | 1 | 1 | Environment, module, or other compilation error; support is undetermined |

A default exit code of 0 means the investigation completed. Use
`--require-supported` as the gate for feature implementation and integration.
Do not enable the feature based only on `canImport(ActivityKit)`.

## Feature commits and reverts

SDK preparation includes only the probe, diagnostic sources, and documentation.
It adds no dependency to app targets, the audio engine, settings, or UI. Normal
app builds and dev CI do not run this optional probe. Reverting its preparation
commit therefore does not affect the current playback source.

Add a runtime feature in a separate commit after choosing a supported platform
and implementation. Include state delivery, presentation extensions, permissions,
metadata, UI, and checks in that integration commit. To remove the feature, revert
integration first while retaining preparation. To remove both, revert integration
before preparation. Later edits to shared files can still cause conflicts;
separate commits do not guarantee every revert will be conflict-free.
