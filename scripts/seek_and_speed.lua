-- | START: seek_and_speed.lua
-- |  PATH: D:\MPV\mpv\scripts\seek_and_speed.lua

-- ➔ Allows you to seek forward or backward by 5% of the video duration.
--    Also allows you to increase or decrease the playback speed.

function format_time(seconds)
    local time_str = ""
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local seconds = math.floor(seconds % 60)
    if hours > 0 then
        time_str = time_str .. hours .. "h "
    end
    if minutes > 0 then
        time_str = time_str .. minutes .. "m "
    end
    if seconds > 0 then
        time_str = time_str .. seconds .. "s"
    end
    return time_str
end

function seek_percentage_forward()
    local duration = mp.get_property_number("duration") -- duration of the current video
    local speed = mp.get_property_number("speed") -- current playback speed
    if duration and speed then -- check if duration and speed are not nil
        local seek_amount = duration * 0.05 -- 5% of the current video
        local filename = mp.get_property("filename/no-ext")
        filename = filename:gsub('_', ' ')
        filename = filename:gsub('-', ' ')
        filename = filename:gsub('%d','')
        filename = filename:gsub('%.%w+$', '')
        filename = filename:gsub('%p','')
        filename = filename:gsub('%w+', function(w) return w:sub(1,1):upper()..w:sub(2):lower() end)
        filename = filename:gsub('%sP$', '')
        filename = filename:gsub('%s+', ' ')
        mp.commandv("seek", seek_amount, "relative")
        mp.add_timeout(0.05, function()
            local new_time = mp.get_property_number("time-pos")
            if new_time then -- check if new_time is not nil
                local remaining_time = (duration - new_time) / speed -- adjust remaining time based on playback speed
                local percentage = math.floor((new_time / duration) * 100) -- remove decimal places
                mp.osd_message(string.format("� %s\n\nNow at: %s (%d%%)\nTime left: %s", filename, format_time(new_time), percentage, format_time(remaining_time)))
            end
        end)
    else
        print("No video loaded.")
    end
end

function seek_percentage_backward()
    local duration = mp.get_property_number("duration") -- duration of the current video
    local speed = mp.get_property_number("speed") -- current playback speed
    if duration and speed then -- check if duration and speed are not nil
        local seek_amount = duration * -0.05 -- 5% of the current video, backward
        local filename = mp.get_property("filename/no-ext")
        filename = filename:gsub('_', ' ')
        filename = filename:gsub('-', ' ')
        filename = filename:gsub('%d','')
        filename = filename:gsub('%.%w+$', '')
        filename = filename:gsub('%p','')
        filename = filename:gsub('%w+', function(w) return w:sub(1,1):upper()..w:sub(2):lower() end)
        filename = filename:gsub('%sP$', '')
        filename = filename:gsub('%s+', ' ')
        mp.commandv("seek", seek_amount, "relative")
        mp.add_timeout(0.05, function()
            local new_time = mp.get_property_number("time-pos")
            if new_time then -- check if new_time is not nil
                if new_time < 0 then new_time = 0 end -- if new_time is negative, set it to 0
                local remaining_time = (duration - new_time) / speed -- adjust remaining time based on playback speed
                local percentage = math.floor((new_time / duration) * 100) -- remove decimal places
                mp.osd_message(string.format("� %s\n\nNow at: %s (%d%%)\nTime left: %s", filename, format_time(new_time), percentage, format_time(remaining_time)))
            end
        end)
    else
        print("No video loaded.")
    end
end

mp.register_script_message("seek_percentage_forward", seek_percentage_forward)
mp.register_script_message("seek_percentage_backward", seek_percentage_backward)

mp.add_key_binding(nil, "increase_speed", function()
    local speed = mp.get_property_number("speed")
    local duration = mp.get_property_number("duration")
    local time_pos = mp.get_property_number("time-pos")
    local time_remaining = math.floor((duration - time_pos) / speed + 0.5) -- calculate time_remaining based on current speed

    local hours = math.floor(time_remaining / 3600)
    local minutes = math.floor((time_remaining % 3600) / 60)
    local seconds = time_remaining % 60

    local time_str = ""
    if hours > 0 then
        time_str = string.format("%dh %02dm %02ds", hours, minutes, seconds)
    elseif minutes > 0 then
        time_str = string.format("%dm %02ds", minutes, seconds)
    else
        time_str = string.format("%ds", seconds)
    end

    if speed < 1 then
        mp.set_property_number("speed", 1)
        mp.osd_message("Video speed set to 1x\nRemaining time: " .. time_str)
    elseif speed == 1 then
        mp.set_property_number("speed", 10)
        local new_duration = math.floor((duration - time_pos) / 10 + 0.5)
        mp.osd_message("Video speed set to 10x\nNew video duration: " .. format_time(new_duration))
    elseif speed == 10 then
        mp.set_property_number("speed", 15)
        local new_duration = math.floor((duration - time_pos) / 15 + 0.5)
        mp.osd_message("Video speed set to 15x\nNew video duration: " .. format_time(new_duration))
    elseif speed == 15 then
        mp.set_property_number("speed", 20)
        local new_duration = math.floor((duration - time_pos) / 20 + 0.5)
        mp.osd_message("Video speed set to 20x\nNew video duration: " .. format_time(new_duration))
    elseif speed == 20 then
        mp.set_property_number("speed", 25)
        local new_duration = math.floor((duration - time_pos) / 25 + 0.5)
        mp.osd_message("Video speed set to 25x\nNew video duration: " .. format_time(new_duration))
    end
end)

mp.add_key_binding(nil, "reduce_speed", function()
    local speed = mp.get_property_number("speed")
    local duration = mp.get_property_number("duration")
    local time_pos = mp.get_property_number("time-pos")
    local time_remaining = math.floor((duration - time_pos) / speed + 0.5) -- calculate time_remaining based on current speed

    local hours = math.floor(time_remaining / 3600)
    local minutes = math.floor((time_remaining % 3600) / 60)
    local seconds = time_remaining % 60

    local time_str = ""
    if hours > 0 then
        time_str = string.format("%dh %02dm %02ds", hours, minutes, seconds)
    elseif minutes > 0 then
        time_str = string.format("%dm %02ds", minutes, seconds)
    else
        time_str = string.format("%ds", seconds)
    end

    if speed > 1 then
        mp.set_property_number("speed", 1)
        mp.osd_message("Video speed: 1x\nRemaining time: " .. time_str)
    else
        local new_speed = math.floor((speed - 0.1) * 10) / 10
        if new_speed < 0.1 then new_speed = 0.1 end
        mp.set_property_number("speed", new_speed)
        local new_duration = math.floor((duration - time_pos) / new_speed + 0.5)
        mp.osd_message("Speed decreased to " .. new_speed .. "x.\nRemaining time: " .. format_time(new_duration))
    end
end)


-- Add error handling
mp.add_hook("on_load_fail", 50, function()
    print("Failed to load video. Resetting script.")
    -- Reset any variables or states here
end)

mp.add_hook("on_unload", 50, function()
    print("Video unloaded. Resetting script.")
    -- Reset any variables or states here
end)

-- |   END: seek_and_speed.lua
