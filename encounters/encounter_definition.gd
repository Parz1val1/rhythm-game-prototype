## Defines a single combat encounter — a named group of enemies with their note patterns.
##
## To create a new encounter:
##   1. Right-click the encounters/ folder in the FileSystem dock.
##   2. "Create New Resource" → type "EncounterDefinition" → Save.
##   3. Fill in encounter_id and add enemies in the Inspector.
##
## To edit an existing encounter:
##   Select its .tres file in the FileSystem dock — all fields are live-editable.
##
## To use in test_scene: drag the .tres file into the "Encounter" field in the Inspector.
class_name EncounterDefinition
extends Resource

## Human-readable identifier for this encounter.
## Should match the .tres filename (e.g. "goblin_single" → goblin_single.tres).
@export var encounter_id: String = ""

## All enemies that participate in this encounter, in turn order.
## Each enemy acts in sequence during the DEFEND phase;
## once all are dead the combat_won signal fires.
@export var enemies: Array[EnemyData] = []
