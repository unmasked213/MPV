-- | START: nuke_file.lua
-- |  PATH: C:\Program Files\mpv\mpv\scripts\nuke_file.lua

-- ➔ Deletes the current video file and plays the next one.

mp.add_key_binding("Ctrl+v", "nuke_current_file", function()
    local current_file_path = mp.get_property("path")
    local current_file_name = mp.get_property("filename")
    if os.remove(current_file_path) then
        mp.osd_message("Video '" .. current_file_name .. "' deleted successfully")
        mp.commandv("playlist-next")
    end
end)

-- |   END: nuke_file.lua
