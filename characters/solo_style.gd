# characters/solo_style.gd
# Per-character visual and musical identity during the ATTACK phase.
# A SoloStyle resource is attached to CharacterData and read by the combat UI
# to tint the stage, route audio to the correct instrument bus, and label the
# on-screen input map with instrument-appropriate direction names.
class_name SoloStyle
extends Resource

## Human-readable instrument name shown in UI (e.g. "Lute", "Drum", "Flute").
@export var instrument_name: String = "Instrument"

## AudioBus name to route attack-phase SFX through. Must exist in AudioServer.
## Allows per-character reverb/EQ while sharing the same BeatClock.
@export var audio_bus: String = "Master"

## Notes in the character's musical scale, as semitone offsets from root.
## The four directions map to scale degrees:
##   up    → scale_steps[0]  (root or tonic)
##   right → scale_steps[1]  (second/third)
##   down  → scale_steps[2]  (fourth/fifth)
##   left  → scale_steps[3]  (sixth/seventh)
## For major pentatonic: [0, 2, 7, 9] (C, D, G, A)
## For minor scale:      [0, 3, 7, 10] (C, Eb, G, Bb)
@export var scale_steps: Array[int] = [0, 2, 7, 9]

## MIDI root note (60 = middle C). Direction inputs play scale_steps[i] + root_note.
@export var root_note: int = 60

## UI accent color for this character's phase (used in HP bar, phase label).
@export var accent_color: Color = Color(1.0, 1.0, 1.0)

## Short flavor text shown in the phase transition label (e.g. "Luthier takes the stage!").
@export var phase_intro_text: String = "Your turn!"
