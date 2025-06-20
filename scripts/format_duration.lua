-- | START: format_duration.lua
-- |  PATH: C:\Program Files\mpv\mpv\scripts\format_duration.lua

-- ➔ Shows how long the video is.
--   For example: "2h 30m" for a 2 hour 30 minute video.

mp.register_script_message("format_duration", function()
    local duration = mp.get_property_number("duration")
    local h = math.floor(duration / 3600)
    local m = math.floor((duration % 3600) / 60)
    local s = duration % 60
    local str = ""
    if h > 0 then str = str .. h .. "h " end
    if m > 0 then str = str .. m .. "m " end
    if s > 0 then str = str .. s .. "s " end
    mp.set_property_string("formatted-duration", str)
end)

-- |   END: format_duration.lua
