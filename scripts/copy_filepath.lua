-- | START: copy_filepath.lua
-- |  PATH: D:\MPV\mpv\scripts\copy_filepath.lua

-- ➔ Copies the current video file path to the clipboard.

local utils = require 'mp.utils'

function copy_filepath()
    local path = mp.get_property("path")
    path = path:gsub('^"', ''):gsub('"$', '')
    local res = utils.subprocess({args={"powershell", "-NoProfile", "-Command", string.format([[echo "%s"|clip]], path)}})
    if res.error == nil then
        mp.osd_message("File path copied to clipboard")
    else
        mp.osd_message("Failed to copy file path")
    end
end

mp.add_key_binding("c", "copy_filepath", copy_filepath)

-- |   END: copy_filepath.lua
