local shuffled = false
local original_playlist = {}
local original_index_map = {}
local current_file = ""
local current_position = 0

-- Improved random seed initialization
math.randomseed(os.time() + os.clock() * 1000000)

function shuffle_table(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

function save_original_playlist()
    original_playlist = {}
    original_index_map = {}
    for i = 0, mp.get_property_number("playlist-count", 0) - 1 do
        local item = mp.get_property("playlist/" .. i .. "/filename")
        table.insert(original_playlist, item)
        original_index_map[item] = i
    end
end

function apply_shuffle()
    save_original_playlist()
    local playlist = {table.unpack(original_playlist)}
    shuffle_table(playlist)
    mp.commandv("playlist-clear")
    for i = 1, #playlist do
        mp.commandv("loadfile", playlist[i], "append")
    end
    shuffled = true
end

function toggle_shuffle()
    mp.msg.info("Toggle shuffle called")
    current_file = mp.get_property("path")
    current_position = mp.get_property_number("time-pos", 0)
    if shuffled then
        mp.msg.info("Restoring original playlist")
        mp.commandv("playlist-clear")
        for i = 1, #original_playlist do
            mp.commandv("loadfile", original_playlist[i], "append")
        end
        mp.set_property_number("playlist-pos", original_index_map[current_file])
        mp.set_property_number("time-pos", current_position)
        shuffled = false
    else
        mp.msg.info("Applying shuffle")
        apply_shuffle()
    end
end

function on_file_end(event)
    if shuffled then
        current_file = mp.get_property("path")
    end
end

mp.register_event("end-file", on_file_end)
mp.add_key_binding("v", "toggle-shuffle", toggle_shuffle)
