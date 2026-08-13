# Combat V1 Playtest Loops

These are temporary, procedurally synthesized backing loops for the Combat V1
human playtest. They contain no external samples or third-party music.

All three files use the same musical timeline:

- 130 BPM in 4/4;
- eight bars / 32 beats;
- 14.769229 seconds;
- stereo, 44.1 kHz, 16-bit PCM; and
- forward looping across the full file in the V1 harness.

## Options

1. **Campfire Strings** — warm, sparse plucked chords with a soft pulse. This is
   the default and the least likely to compete with phrase prompts.
2. **Stonebeat** — an earthy, rhythm-forward option with low thumps, wood hits,
   shaker, and muted bass plucks.
3. **Starcurrent** — an airy sustained texture with occasional bright plucks and
   the lightest rhythmic footprint.

Press `1`, `2`, or `3` in the Combat V1 harness to switch without resetting the
combat clock. The current option is shown in the playtest control panel.

Open `playtest_audio_comparison.rpp` in Reaper to audition or process the three
files together. Campfire Strings starts unmuted; the other two tracks start muted
for quick solo comparisons.

Regenerate the WAV files from the repository root with:

```powershell
godot --headless --path . -s res://tools/generate_playtest_audio.gd
```

The generator overwrites all three WAV files, so preserve any manual Reaper edits
under new filenames.
