# Installing Cinder for Intel (experimental)

This package is a development build for **64-bit Intel Macs running macOS 14
or later**, up to the latest macOS supported by the computer. It does not support
32-bit Macs. Cinder 1.0.0's official release target remains Apple Silicon.
Intel builds are experimental, with no commitment to ongoing Intel releases.

Compilation and automated tests through Rosetta on Apple Silicon do not establish
physical Intel Mac compatibility. Launch, audio output, sleep/wake, long sessions,
and runtime compatibility on macOS 14, 15, and 26 still require Intel testing.
Noise continuity and all seven music arrangements still need listening evaluation.

## Install and open

1. Use the DMG whose filename ends in **x86_64-experimental.dmg**. Apple Silicon
   users should use the standard **arm64.dmg** package instead.
2. Open the DMG and drag **Cinder (Dev)** into Applications. Quit any existing copy
   before replacing it. Eject the disk image, then open the app from Applications.
3. This test build is ad-hoc signed, not Developer ID signed or notarized. After
   verifying its source, allow the first launch in **System Settings > Privacy &
   Security > Open Anyway** if macOS blocks it. Follow
   [Apple's instructions](https://support.apple.com/en-us/102445) if needed.
   Managed Macs may disallow this exception. The accompanying SHA-256 file checks
   download integrity; it does not replace signing or notarization.

Intel Macs run this app natively and do not need Rosetta. Existing Cinder settings
are shared, so this package does not provide a separate settings profile.

## Testing and feedback

Choose an output and begin with a short session at a low level. Check play, pause,
resume, stop, and output changes before trying long sessions. Closing the main
window keeps the app in the menu bar; choosing Quit ends playback.

When [reporting an issue](https://github.com/alienatiz/Cinder/issues), include the
app version and internal build number from Settings, Mac model and Intel CPU,
macOS version, output device and connection, and steps to reproduce it. For audio
dropouts, include the selected signal or music preset and elapsed playback time.
The [user guide](https://github.com/alienatiz/Cinder/blob/dev/README.md) describes
playback controls and language options.
