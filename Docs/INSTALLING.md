# Installing Cinder

Cinder is an audio burn-in app for Mac. It plays continuous noise or bundled
music through a selected output, with timed sessions and optional rest intervals.

## Requirements

The standard **arm64** package targets Apple Silicon and macOS 14 or later.
An optional **x86_64-experimental** package is for Intel Macs on **macOS 14 through
26 only**; macOS 27 and later are not supported for Intel. See the
[Intel installation guide](https://github.com/alienatiz/Cinder/blob/dev/Docs/INSTALLING-INTEL.md)
for its testing limits. Runtime checks on macOS 14,
15, and 26 are still pending. Development builds are intended for testing;
physical-device playback, long sessions, and the seven music arrangements still
need evaluation before the first stable release.

## Install and open

1. Download the DMG for your Mac's processor from the selected build in
   [Cinder Releases](https://github.com/alienatiz/Cinder/releases), or use a local build.
2. Open the DMG and drag Cinder into Applications. Development builds are named
   **Cinder (Dev)**. Quit an existing copy before replacing it.
3. Eject the disk image, then open Cinder from Applications.

Current test builds use local ad-hoc signing. They are not signed with an Apple
Developer ID or notarized, so macOS may block the first launch. After checking
that the build came from this repository or your own local source, go to
**System Settings → Privacy & Security → Open Anyway** and confirm opening the
app. Follow [Apple's instructions](https://support.apple.com/en-us/102445) if the
option does not appear. Organization-managed Macs may disallow this exception.

The ZIP is an alternative containing the same app; extract it and move the app to
Applications. SHA-256 files accompany both packages so you can check download
integrity. They do not replace Developer ID signing or notarization.

## Testing and feedback

Choose an output, start at a low level, and try a short session before a long run.
Closing the main window keeps Cinder in the menu bar; choosing Quit ends playback.
Development builds share existing Cinder preferences. Installing a different
test build does not provide an isolated settings profile.

When [reporting an issue](https://github.com/alienatiz/Cinder/issues), include the
build's commit from the release notes or accompanying text file, macOS version,
output device, and steps to reproduce the problem. See the
[user guide](https://github.com/alienatiz/Cinder/blob/dev/README.md) for playback
controls and language options.
