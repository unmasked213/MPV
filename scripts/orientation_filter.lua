-- orientation_filter.lua
local mp = require 'mp'
local msg = require 'mp.msg'

-- Mode state - use a simple string for clarity
local current_mode = "OFF"  -- Options: "OFF", "LANDSCAPE", "PORTRAIT"

-- Function to format filename for display
local function format_filename(filename)
    if not filename then return "" end
    filename = filename:gsub('_', ' ')
    filename = filename:gsub('-', ' ')
    filename = filename:gsub('%d','')
    filename = filename:gsub('%.%w+$', '') 
    filename = filename:gsub('%p','')
    filename = filename:gsub('%w+', function(w) return w:sub(1,1):upper()..w:sub(2):lower() end)
    filename = filename:gsub('%sP$', '') 
    filename = filename:gsub('%s+', ' ')
    return filename
end

-- Determine if current video is landscape or portrait
local function is_landscape()
    local width = mp.get_property_number("width")
    local height = mp.get_property_number("height")
    
    if not width or not height then
        msg.warn("Could not determine video dimensions")
        return false
    end
    
    return width > height
end

local function is_portrait()
    local width = mp.get_property_number("width")
    local height = mp.get_property_number("height")
    
    if not width or not height then
        msg.warn("Could not determine video dimensions")
        return false
    end
    
    return height > width
end

-- Function to handle next video navigation
local function next_video_handler()
    if current_mode == "OFF" then
        mp.commandv("playlist-next", "weak")
        return
    end

    local playlist_pos = mp.get_property_number("playlist-pos")
    local playlist_count = mp.get_property_number("playlist-count")
    
    -- If we're at the end of the playlist, don't do anything
    if playlist_pos == playlist_count - 1 then
        local filename = format_filename(mp.get_property("filename"))
        mp.osd_message(string.format("End of playlist reached\nCurrent: %s", filename))
        return
    end
    
    -- Move to next video
    mp.commandv("playlist-next", "weak")
    
    -- Wait for video properties to be available
    mp.add_timeout(0.2, function()
        local width = mp.get_property_number("width")
        local height = mp.get_property_number("height")
        local filename = format_filename(mp.get_property("filename"))
        
        msg.debug(string.format("Checking video: %s (%dx%d)", filename, width or 0, height or 0))
        
        -- If the current video doesn't match our mode, skip it
        if (current_mode == "LANDSCAPE" and not is_landscape()) or
           (current_mode == "PORTRAIT" and not is_portrait()) then
            local skip_msg = ""
            if current_mode == "LANDSCAPE" then
                skip_msg = string.format("Skipping portrait video: %s\nDimensions: %dx%d", 
                    filename, width or 0, height or 0)
            else
                skip_msg = string.format("Skipping landscape video: %s\nDimensions: %dx%d", 
                    filename, width or 0, height or 0)
            end
            mp.osd_message(skip_msg)
            next_video_handler()
        end
    end)
end

-- Function to handle previous video navigation
local function prev_video_handler()
    if current_mode == "OFF" then
        mp.commandv("playlist-prev", "weak")
        return
    end

    local playlist_pos = mp.get_property_number("playlist-pos")
    
    -- If we're at the start of the playlist, don't do anything
    if playlist_pos == 0 then
        local filename = format_filename(mp.get_property("filename"))
        mp.osd_message(string.format("Start of playlist reached\nCurrent: %s", filename))
        return
    end
    
    -- Move to previous video
    mp.commandv("playlist-prev", "weak")
    
    -- Wait for video properties to be available
    mp.add_timeout(0.2, function()
        local width = mp.get_property_number("width")
        local height = mp.get_property_number("height")
        local filename = format_filename(mp.get_property("filename"))
        
        msg.debug(string.format("Checking video: %s (%dx%d)", filename, width or 0, height or 0))
        
        -- If the current video doesn't match our mode, skip it
        if (current_mode == "LANDSCAPE" and not is_landscape()) or
           (current_mode == "PORTRAIT" and not is_portrait()) then
            local skip_msg = ""
            if current_mode == "LANDSCAPE" then
                skip_msg = string.format("Skipping portrait video: %s\nDimensions: %dx%d", 
                    filename, width or 0, height or 0)
            else
                skip_msg = string.format("Skipping landscape video: %s\nDimensions: %dx%d", 
                    filename, width or 0, height or 0)
            end
            mp.osd_message(skip_msg)
            prev_video_handler()
        end
    end)
end

-- Function to toggle landscape-only mode
local function toggle_landscape_mode()
    msg.info("Toggle landscape mode called, current mode: " .. current_mode)
    
    -- If we're already in landscape mode, turn it off
    if current_mode == "LANDSCAPE" then
        current_mode = "OFF"
        mp.osd_message("Landscape Only Mode: Disabled")
    else
        -- Otherwise, enable landscape mode (regardless of what mode we were in before)
        current_mode = "LANDSCAPE"
        mp.osd_message("Landscape Only Mode: Enabled")
        
        -- If enabling landscape mode and current video is portrait, skip it
        mp.add_timeout(0.2, function()
            if not is_landscape() then
                local width = mp.get_property_number("width", 0)
                local height = mp.get_property_number("height", 0)
                local filename = format_filename(mp.get_property("filename"))
                
                mp.osd_message(string.format("Skipping portrait video: %s\nDimensions: %dx%d", 
                    filename, width, height))
                next_video_handler()
            end
        end)
    end
end

-- Function to toggle portrait-only mode
local function toggle_portrait_mode()
    msg.info("Toggle portrait mode called, current mode: " .. current_mode)
    
    -- If we're already in portrait mode, turn it off
    if current_mode == "PORTRAIT" then
        current_mode = "OFF"
        mp.osd_message("Portrait Only Mode: Disabled")
    else
        -- Otherwise, enable portrait mode (regardless of what mode we were in before)
        current_mode = "PORTRAIT"
        mp.osd_message("Portrait Only Mode: Enabled")
        
        -- If enabling portrait mode and current video is landscape, skip it
        mp.add_timeout(0.2, function()
            if not is_portrait() then
                local width = mp.get_property_number("width", 0)
                local height = mp.get_property_number("height", 0)
                local filename = format_filename(mp.get_property("filename"))
                
                mp.osd_message(string.format("Skipping landscape video: %s\nDimensions: %dx%d", 
                    filename, width, height))
                next_video_handler()
            end
        end)
    end
end

-- Check initial video when a mode is enabled
mp.register_event("file-loaded", function()
    if current_mode == "OFF" then return end
    
    -- Wait for video properties to be available
    mp.add_timeout(0.2, function()
        -- Skip video if it doesn't match the current mode
        if (current_mode == "LANDSCAPE" and not is_landscape()) or
           (current_mode == "PORTRAIT" and not is_portrait()) then
            local width = mp.get_property_number("width", 0)
            local height = mp.get_property_number("height", 0)
            local filename = format_filename(mp.get_property("filename"))
            
            local skip_msg = ""
            if current_mode == "LANDSCAPE" then
                skip_msg = string.format("Skipping portrait video: %s\nDimensions: %dx%d", 
                    filename, width, height)
            else
                skip_msg = string.format("Skipping landscape video: %s\nDimensions: %dx%d", 
                    filename, width, height)
            end
            mp.osd_message(skip_msg)
            next_video_handler()
        end
    end)
end)

-- Register script messages with the same names as original scripts
mp.register_script_message("toggle_landscape_mode", toggle_landscape_mode)
mp.register_script_message("toggle_portrait_mode", toggle_portrait_mode)
mp.register_script_message("next_landscape", next_video_handler)
mp.register_script_message("prev_landscape", prev_video_handler)
mp.register_script_message("next_portrait", next_video_handler)
mp.register_script_message("prev_portrait", prev_video_handler)

-- Debug message to confirm script is loaded
msg.info("Orientation filter script loaded successfully")
msg.info("Orientation filter script loaded successfully")
msg.info("Orientation filter script loaded successfully")