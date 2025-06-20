-- | START: format_info.lua
-- |  PATH: D:\MPV\mpv\scripts\format_info.lua

-- ➔ Shows video details on screen.
--   Shows the video name, how long it is, how good it looks, and how big the file is.
--   Also tells you if the video is less than 1 minute long.

function format_info()
    local filename = mp.get_property("filename/no-ext")
    filename = filename:gsub('_', ' ')
    filename = filename:gsub('-', ' ')
    filename = filename:gsub('%d','')
    filename = filename:gsub('%.%w+$', '') -- This line removes the file extension
    filename = filename:gsub('%p','')
    filename = filename:gsub('%w+', function(w) return w:sub(1,1):upper()..w:sub(2):lower() end)
    filename = filename:gsub('%sP$', '') -- This line removes the letter "P" if it's the last character and preceded by a space
    filename = filename:gsub('%s+', ' ') -- This line changes occurrences of multiple space characters to be single space characters

    local duration = mp.get_property_number("duration")
    local hours = math.floor(duration / 3600)
    local minutes = math.floor((duration % 3600) / 60)
    local seconds = duration % 60

    local duration_str = ""
    if hours > 0 then
        duration_str = string.format("%dh %02dm %02ds", hours, minutes, seconds)
    elseif minutes > 0 then
        duration_str = string.format("%dm %02ds", minutes, seconds)
    else
        duration_str = string.format("%ds", seconds)
    end

    local video_params = mp.get_property_native("video-out-params")
    local quality
    if video_params then
        quality = video_params["h"]
    else
        quality = "N/A"
    end

    local file_size = mp.get_property_number("file-size") / (1024 * 1024) -- Convert to MB

    local file_size_str = ""
    if file_size > 1024 then
        file_size_str = string.format("%.0fGB", file_size / 1024) -- Convert to GB if size is more than 1024 MB
    else
        file_size_str = string.format("%.0fMB", file_size)
    end

    local playlist_pos = mp.get_property_number("playlist-pos-1")
    local playlist_count = mp.get_property_number("playlist-count")
    local remaining = playlist_count - playlist_pos

    local remaining_str = ""
    if remaining > 1 then
        remaining_str = "\n" .. remaining .. " more videos"
    elseif remaining == 1 then
        remaining_str = "\n" .. remaining .. " more video"
    end

    local formatted_text = playlist_pos .. ". " .. filename ..
    "\n\n" .. duration_str

    if quality ~= "N/A" then
        formatted_text = formatted_text .. "\n" .. quality .. "p | " .. file_size_str
    else
        formatted_text = formatted_text .. "\n" .. file_size_str
    end

    formatted_text = formatted_text .. remaining_str

    -- Set the OSD dimensions
    local screenx, screeny, aspect = mp.get_osd_size()

    -- Check if the duration is less than 2 minutes
    if duration <= 60 then
        -- Add the yellow text
        local short_video_text = "\n{\\1c&H00FFFF&}Short video detected"

        -- Set the OSD content
        mp.set_osd_ass(screenx, screeny, formatted_text .. short_video_text)
        mp.add_timeout(4, function() mp.set_osd_ass(0, 0, "") end)
    else
        -- Clear the OSD content
        mp.set_osd_ass(0, 0, "")

        mp.osd_message(formatted_text)
    end
end

mp.register_event("file-loaded", format_info)

-- |   END: format_info.lua
