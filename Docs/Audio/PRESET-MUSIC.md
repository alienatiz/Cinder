# Built-in music

Cinder includes seven instrumental presets that work without external music files.
The current arrangements are revision 5. Instrumentation and phrasing distinguish
introductions, development, quieter passages, reprises, and returns to the loop.
Listening evaluation remains in progress.

| Preset | BPM | Loop length | Instrumentation |
|---|---:|---:|---|
| Classic | 90 | 56 seconds | Orchestra, piano, and harp |
| Balanced | 100 | 38.4 seconds | Electric piano, chords, and restrained rhythm |
| Electronic | 112 | 60 seconds | Synths, bass, pads, and electronic percussion |
| Acoustic | 96 | 60 seconds | Fingerpicked guitar, melody, and piano |
| POP | 112 | 60 seconds | Piano and guitar melodies with a bridge |
| Rock | 128 | 60 seconds | Guitar and bass riffs with piano |
| Metal | 160 | 60 seconds | Muted riffs, power chords, and half-time rhythm |

## Using the presets

Choose preset music and a genre in Music, then select Music mode in Quick Play.
The full cycle uses the selected track during its music step. The track loops
until the session ends. Selecting it does not start playback or replace your
external music library.

## Resources and playback

The tracks are 48 kHz, 24-bit, stereo FLAC files totaling about 58.5 MB. Electronic
uses custom electronic synthesis; the other six were rendered in advance with
GeneralUser GS 2.0.3 and FluidSynth 2.6.1 on macOS. Running the app and normal builds
require no synthesizer, instrument bank, or music download.

Only the selected track is prepared and converted to the output sample rate before
playback. Surrounding loop samples handle conversion at repeat boundaries. Built-in
music bypasses the low-frequency cut and silent end fades used for external files.
A 192 kHz, 60-second stereo PCM buffer can occupy 92.16 MB regardless of session
length. This is not the app's total memory usage.

Classic divides 56 seconds into seven 8-second sections emphasizing 20–60 Hz,
60–250 Hz, 250–500 Hz, 500 Hz–2 kHz, 2–4 kHz, 4–6 kHz, and 6–16 kHz in order.
The central band in each section is emphasized by up to about 3.5 dB; energy is
not forced to be equal across bands.

## Validation and regeneration

Source checks and app packaging verify music hashes. XCTest checks sample-rate
conversion through AVAudioConverter and loop playback. Signal tests are separate
from musical quality and real listening evaluation. See [validation status](../../VALIDATION.md).

Regeneration is optional. Pass `--library`, `--bank`, `--output`, and `--previews`
paths to the [generator](../../Tools/Generate-PresetMusic.py). Check the
[dependencies](../../Tools/requirements-music.txt),
[tool hashes](../../Tools/INSTRUMENT-SOURCES.json), and
[credits and licenses](../../Sources/CinderApp/Resources/preset-music-credits.txt).

To prepare the tools on macOS, install Homebrew's `fluid-synth` and install
`Tools/requirements-music.txt` in a project-local virtual environment. Verify the
instrument bank against its SHA-256 in `Tools/INSTRUMENT-SOURCES.json` before
rendering. The existing Balanced score was rendered and checked using FluidSynth
2.6.1 on macOS 27 arm64. These tools are not app target dependencies; normal builds
and installed apps use the supplied FLAC files. Arrangement resources are managed
separately from generation-tool preparation.

## Revision 5 development

- Classic: a piano/cello opening grows into strings and brass, moves through a chamber passage led by woodwinds, and returns to the theme. The ending reduces instrumentation before looping.
- Balanced: separate electric-piano opening, rhythm entry, short bridge, and octave reprise.
- Electronic: bass, chords, and percussion build over a pad opening. A higher lead follows the middle bridge before a dominant return.
- Acoustic: sparse fingerpicking alternates with fuller accompaniment; piano, an ascending melody, and strumming enter later.
- POP: reduced accompaniment in the introduction and bridge, followed by an octave melody and denser rhythm in the reprise.
- Rock and Metal: reduced drum and riff density in the opening, breakdown, and final return, with answering leads at the climax.

These revisions change scores and instrumentation rather than relying on master
volume changes alone. BPM, loop lengths, and preset identifiers are preserved.
Resource hashes, peaks, loop boundaries, and conversion are checked again.
Passing numeric checks does not establish musical completion or listening approval.
