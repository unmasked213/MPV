-- | START: zoom_control.lua
-- |  PATH: D:\MPV\mpv\scripts\zoom_control.lua

-- ➔ Allows you to zoom in and out of the video.


-- Zoom increment value
local ZOOM_STEP = 0.02

local function change_zoom(direction)
    local delta = (direction == "in") and ZOOM_STEP or -ZOOM_STEP
    local zoom = mp.get_property_number("video-zoom", 0) + delta
    mp.set_property_number("video-zoom", zoom)
    zoom = math.floor(zoom * 100 + 0.5) / 100
    local message = math.abs(zoom) < 0.01 and "Zoom level reset" or ("Zoom: " .. string.format("%.2f", zoom) .. "x")
    mp.osd_message(message)
end

mp.register_script_message("zoom_in", function() change_zoom("in") end)
mp.register_script_message("zoom_out", function() change_zoom("out") end)


-- |   END: zoom_control.lua
