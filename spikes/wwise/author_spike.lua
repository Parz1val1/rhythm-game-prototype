-- Deterministically authors the Wwise side of GitHub issue #45.
-- Run with WwiseConsole 2025.1.9 from the repository root; the script derives
-- audio paths from the loaded .wproj so it does not contain workstation paths.

local function call(uri, args, options)
    local result = wa_call(uri, args or {}, options or {})
    if result == nil then
        error("WAAPI call failed: " .. uri)
    end
    return result
end

local function parent_directory(path)
    return path:match("^(.*)[/\\][^/\\]+$")
end

local project_query = call(
    "ak.wwise.core.object.get",
    { from = { ofType = { "Project" } } },
    { ["return"] = { "filePath" } }
)
if not project_query["return"] or not project_query["return"][1] then
    error("Could not resolve the loaded Wwise project path")
end

local project_directory = parent_directory(project_query["return"][1].filePath)
local repository_root = project_directory
for _ = 1, 4 do
    repository_root = parent_directory(repository_root)
end
if not repository_root then
    error("Could not derive the repository root from the Wwise project")
end

local campfire = repository_root .. "\\audio\\playtest_v1\\campfire_strings.wav"
local stonebeat = repository_root .. "\\audio\\playtest_v1\\stonebeat.wav"
local starcurrent = repository_root .. "\\audio\\playtest_v1\\starcurrent.wav"

local state_root = "\\States\\Default Work Unit"
local layer_group = state_root .. "\\Combat_Layer"
local section_group = state_root .. "\\Combat_Section"
local music_root = "\\Containers\\Default Work Unit\\Combat_Spike"
local segment_duration_ms = 14769.231 -- 32 beats at 130 BPM.

local function make_track(name, audio_file, volume)
    return {
        type = "MusicTrack",
        name = name,
        ["@Volume"] = volume or 0,
        import = {
            files = {
                { audioFile = audio_file }
            }
        }
    }
end

local function make_playlist(name, segment_name, tracks)
    local segment_path = music_root .. "\\" .. name .. "\\" .. segment_name
    return {
        type = "MusicPlaylistContainer",
        name = name,
        ["@PlaylistRoot"] = {
            type = "MusicPlaylistItem",
            name = "",
            ["@LoopCount"] = 0,
            children = {
                {
                    type = "MusicPlaylistItem",
                    name = "",
                    ["@PlaylistItemType"] = 1,
                    ["@Segment"] = segment_path
                }
            }
        },
        children = {
            {
                type = "MusicSegment",
                name = segment_name,
                ["@OverrideClockSettings"] = true,
                ["@Tempo"] = 130,
                ["@TimeSignatureUpper"] = 4,
                ["@TimeSignatureLower"] = 4,
                ["@GridFrequencyPreset"] = 53,
                ["@EndPosition"] = segment_duration_ms,
                ["@Cues"] = {
                    {
                        type = "MusicCue",
                        name = "Entry Cue",
                        ["@CueType"] = 0,
                        ["@TimeMs"] = 0
                    },
                    {
                        type = "MusicCue",
                        name = "Exit Cue",
                        ["@CueType"] = 1,
                        ["@TimeMs"] = segment_duration_ms
                    }
                },
                children = tracks
            }
        }
    }
end

local function make_entry(layer_state, section_state, arrangement_name)
    return {
        type = "MultiSwitchEntry",
        name = "",
        ["@EntryPath"] = {
            {
                type = "EntryPathSlot",
                name = "",
                ["@EntryPathObject"] = layer_group .. "\\" .. layer_state
            },
            {
                type = "EntryPathSlot",
                name = "",
                ["@EntryPathObject"] = section_group .. "\\" .. section_state
            }
        },
        ["@AudioNode"] = music_root .. "\\" .. arrangement_name
    }
end

local result = call(
    "ak.wwise.core.object.set",
    {
        objects = {
            {
                object = state_root,
                children = {
                    {
                        type = "StateGroup",
                        name = "Combat_Layer",
                        ["@DefaultTransitionTime"] = 0,
                        children = {
                            { type = "State", name = "Disabled" },
                            { type = "State", name = "Enabled" }
                        }
                    },
                    {
                        type = "StateGroup",
                        name = "Combat_Section",
                        ["@DefaultTransitionTime"] = 0,
                        children = {
                            { type = "State", name = "Loop" },
                            { type = "State", name = "Alternate" }
                        }
                    }
                }
            },
            {
                object = "\\Containers\\Default Work Unit",
                children = {
                    {
                        type = "MusicSwitchContainer",
                        name = "Combat_Spike",
                        ["@OverrideClockSettings"] = true,
                        ["@Tempo"] = 130,
                        ["@TimeSignatureUpper"] = 4,
                        ["@TimeSignatureLower"] = 4,
                        ["@GridFrequencyPreset"] = 53,
                        ["@ContinuePlay"] = true,
                        ["@TransitionRoot"] = {
                            type = "MusicTransition",
                            name = "",
                            ["@ExitSourceAt"] = 2,
                            ["@PlaySourcePostExit"] = false,
                            ["@DestinationJumpPositionPreset"] = 1,
                            ["@PlayDestinationPreEntry"] = false
                        },
                        ["@Arguments"] = {
                            {
                                type = "MusicArgumentsSlot",
                                name = "",
                                ["@Argument"] = layer_group
                            },
                            {
                                type = "MusicArgumentsSlot",
                                name = "",
                                ["@Argument"] = section_group
                            }
                        },
                        ["@Entries"] = {
                            make_entry("Disabled", "Loop", "Loop_Disabled"),
                            make_entry("Enabled", "Loop", "Loop_Enabled"),
                            make_entry("Disabled", "Alternate", "Alternate_Disabled"),
                            make_entry("Enabled", "Alternate", "Alternate_Enabled")
                        },
                        children = {
                            make_playlist("Loop_Disabled", "Loop", {
                                make_track("Base", campfire, -3)
                            }),
                            make_playlist("Loop_Enabled", "Loop", {
                                make_track("Base", campfire, -3),
                                make_track("Layer", stonebeat, -3)
                            }),
                            make_playlist("Alternate_Disabled", "Alternate", {
                                make_track("Base", starcurrent, -3)
                            }),
                            make_playlist("Alternate_Enabled", "Alternate", {
                                make_track("Base", starcurrent, -3),
                                make_track("Layer", stonebeat, -3)
                            })
                        }
                    }
                }
            },
            {
                object = "\\Events\\Default Work Unit",
                children = {
                    {
                        type = "Event",
                        name = "Play_Combat_Spike",
                        children = {
                            {
                                type = "Action",
                                name = "",
                                ["@ActionType"] = 1,
                                ["@Target"] = music_root
                            }
                        }
                    }
                }
            },
            {
                object = "\\SoundBanks\\Default Work Unit",
                children = {
                    { type = "SoundBank", name = "Combat_Spike" }
                }
            }
        },
        onNameConflict = "merge",
        listMode = "replaceAll",
        autoAddToSourceControl = false
    },
    { ["return"] = { "id", "name", "path" } }
)

call(
    "ak.wwise.core.soundbank.setInclusions",
    {
        soundbank = "\\SoundBanks\\Default Work Unit\\Combat_Spike",
        operation = "replace",
        inclusions = {
            {
                object = "\\Events\\Default Work Unit\\Play_Combat_Spike",
                filter = { "events", "structures", "media" }
            }
        }
    }
)

call("ak.wwise.core.project.save", { autoCheckOutToSourceControl = false })
print("Authored Combat_Spike: " .. tostring(#result.objects) .. " root operations")
return 0
