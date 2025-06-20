-- | START: toggle-menu.lua
-- |  PATH: D:\MPV\mpv\scripts\toggle-menu.lua

-- ➔ Displays a clean overlay with all essential video information.
--    Colors highlight important changes to video state.
--    Custom seeking behavior for playlists.
--    Comprehensive property monitoring.


local mpv = {
  mp = require 'mp',
  assdraw = require 'mp.assdraw',
  msg = require 'mp.msg'
}

--------------------------------------------------
-- Configuration
--------------------------------------------------

local Config = {
  -- Colors (ASS format)
  colors = {
    default = "&HFFFFFF&",     -- Normal text (white)
    value = "&H44F8CA&",       -- Highlighted values (green)
    bad = "&H8A91FF&",         -- Warning state/low quality (red-ish)
    good = "&HFFB344&",        -- Good state/high quality (orange)
    background = "&H30201E&"   -- Semi-transparent background
  },

  -- Video start behavior
  playback = {
    start_position_percent = 1,  -- Where to start videos (% of duration)
    min_duration_threshold = 999999   -- Minimum duration to apply custom start (seconds)
  },

  -- UI settings
  ui = {
    menu_width = 300,
    menu_height = 400,
    corner_radius = 10,
    font_size = 20,
    menu_x = 50,
    menu_y = 50,
    transparency = "19"  -- Background transparency (hex, 00-FF)
  }
}

--------------------------------------------------
-- State
--------------------------------------------------

local State = {
  menu_visible = false,
  menu_ass = mpv.mp.create_osd_overlay("ass-events"),
  shuffled = false  -- Should reflect actual shuffle state
}

--------------------------------------------------
-- Formatting Helpers
--------------------------------------------------

local Format = {}

-- Wrap text with colored formatting
Format.colored = function(text, color)
  color = color or Config.colors.default
  return string.format("{\\1c&H%s&}%s{\\1c&H%s&}", color, text, Config.colors.default)
end

-- Format and clean up media title
Format.title = function(title)
  title = title:gsub("_", " "):gsub("-", " "):gsub("%d", ""):gsub("[^%w%s%(%)]", ""):sub(1, 20)
  mpv.msg.info("Formatted title: " .. title)
  return title
end

-- Format playback position as percentage
Format.position = function()
  local percent = math.min(math.max(mpv.mp.get_property_number("percent-pos", 0), 0), 100)
  mpv.msg.verbose("Playback position: " .. percent)

  if percent == 0 then return "0%" end
  return string.format("%.1f%%", percent):gsub("%.0%%", "%%")
end

-- Format remaining time in human-readable format
Format.time_remaining = function()
  local remaining = mpv.mp.get_property_number("playtime-remaining", 0) / mpv.mp.get_property_number("speed", 1)
  remaining = math.max(remaining, 0)

  local h = math.floor(remaining / 3600)
  local m = math.floor((remaining % 3600) / 60)
  local s = math.floor(remaining % 60)

  local str = ""
  if h > 0 then str = str .. h .. "h " end
  if m > 0 or h > 0 then str = str .. m .. "m " end
  if h == 0 and m < 10 then str = str .. s .. "s" end

  mpv.msg.verbose("Time remaining: " .. str)
  return str
end

-- Determine video quality with appropriate color coding
Format.quality = function()
  local width = mpv.mp.get_property_number("width", 0)
  local height = mpv.mp.get_property_number("height", 0)
  local max_dim = math.max(width, height)
  mpv.msg.verbose("Video resolution: " .. width .. "x" .. height)

  -- Resolution definitions with thresholds, midpoints and colors
  local resolutions = {
    {label = "4K",    threshold = 3840, midpoint = (3840 + 2560) / 2, color = Config.colors.good},
    {label = "1440p", threshold = 2560, midpoint = (2560 + 1920) / 2, color = Config.colors.good},
    {label = "1080p", threshold = 1920, midpoint = (1920 + 1280) / 2, color = Config.colors.default},
    {label = "720p",  threshold = 1280, midpoint = (1280 + 854) / 2,  color = Config.colors.default},
    {label = "480p",  threshold = 854,  midpoint = (854 + 640) / 2,   color = Config.colors.bad},
    {label = "360p",  threshold = 640,  midpoint = (640 + 426) / 2,   color = Config.colors.bad},
    {label = "240p",  threshold = 426,  midpoint = (426 + 256) / 2,   color = Config.colors.bad},
    {label = "144p",  threshold = 256,  midpoint = (256 + 160) / 2,   color = Config.colors.bad},
    {label = "120p",  threshold = 160,  midpoint = 0,                 color = Config.colors.bad}
  }

  -- Find the best matching resolution
  for _, res in ipairs(resolutions) do
    if max_dim >= res.midpoint then
      mpv.msg.verbose("Matched resolution: " .. res.label)
      return Format.colored(res.label, res.color)
    end
  end

  -- Fallback for unknown resolution
  return Format.colored(tostring(max_dim) .. "p", Config.colors.bad)
end

-- Format file size with appropriate unit
Format.filesize = function()
  local size = mpv.mp.get_property_number("file-size", 0)
  local result

  if size >= 1e9 then
    result = string.format("%.0fgb", size / 1e9)
  elseif size >= 1e6 then
    result = string.format("%.0fmb", size / 1e6)
  else
    result = string.format("%dkb", size / 1e3)
  end

  mpv.msg.verbose("File size: " .. result)
  return result
end

-- Format playback speed with color for non-normal
Format.speed = function()
  local speed = mpv.mp.get_property_number("speed", 1)
  mpv.msg.verbose("Playback speed: " .. speed)

  if speed == 1 then
    return "Normal"
  else
    return Format.colored(string.format("%.1fx", speed), Config.colors.value)
  end
end

-- Format zoom level with color when zoomed
Format.zoom = function()
  local zoom = mpv.mp.get_property_number("video-zoom", 0)
  mpv.msg.verbose("Zoom level: " .. zoom)

  if math.abs(zoom) < 0.01 then
    return "None"
  else
    return Format.colored(string.format("%.3fx", zoom), Config.colors.value)
  end
end

-- Format pan state with directional indicators
Format.pan = function()
  local pan_x = mpv.mp.get_property_number("video-pan-x", 0)
  local pan_y = mpv.mp.get_property_number("video-pan-y", 0)
  local threshold = 0.002
  local result = ""

  -- Reset tiny values to zero
  if math.abs(pan_x) < threshold then pan_x = 0 end
  if math.abs(pan_y) < threshold then pan_y = 0 end

  -- X-axis pan
  if pan_x ~= 0 then
    local direction = pan_x > 0 and "R" or "L"
    result = Format.colored(string.format("%s %.1f%%", direction, math.abs(pan_x * 100)), Config.colors.value)
  end

  -- Y-axis pan
  if pan_y ~= 0 then
    local direction = pan_y > 0 and "D" or "U"
    local y_text = string.format("%s %.1f%%", direction, math.abs(pan_y * 100))

    -- Add space if we already have x-axis pan
    if result ~= "" then
      result = result .. " "
    end

    result = result .. Format.colored(y_text, Config.colors.value)
  end

  -- If no panning is applied
  if result == "" then
    return "Center"
  end

  mpv.msg.verbose("Pan: " .. result)
  return result
end

-- Format audio status (volume or silent)
Format.audio = function()
  local codec = mpv.mp.get_property("audio-codec")
  if not codec or codec == "none" then
    mpv.msg.warn("No audio codec detected")
    return Format.colored("Silent", Config.colors.bad)
  end

  local vol = mpv.mp.get_property_number("volume", 100)
  mpv.msg.verbose("Volume: " .. vol)
  return string.format("%d%%", vol)
end

-- Convert aspect ratio to standard label
Format.aspect = function()
  local aspect = mpv.mp.get_property_number("video-params/aspect", 0)
  mpv.msg.verbose("Aspect ratio: " .. aspect)

  if aspect > 2.35 then return "21:9"
  elseif aspect > 1.7 then return "16:9"
  elseif aspect > 1.3 then return "4:3"
  else return string.format("%.2f", aspect)
  end
end

-- Format rotation with color for non-zero
Format.rotation = function()
  local rotation = mpv.mp.get_property_number("video-rotate", 0)
  mpv.msg.verbose("Rotation: " .. rotation)

  if rotation == 0 then
    return "None"
  else
    return Format.colored(rotation .. "°", Config.colors.value)
  end
end

-- Format flip state with color highlighting
Format.flip = function()
  local vf_table = mpv.mp.get_property_native("vf") or {}
  local vflip, hflip = false, false

  -- Check for vertical and horizontal flip filters
  for _, filter in ipairs(vf_table) do
    if filter.name == "vflip" then vflip = true end
    if filter.name == "hflip" then hflip = true end
  end

  -- Generate appropriate status text
  if vflip and hflip then
    return Format.colored("Both", Config.colors.value)
  elseif vflip then
    return Format.colored("Vertical", Config.colors.value)
  elseif hflip then
    return Format.colored("Horizontal", Config.colors.value)
  else
    return "None"
  end
end

-- Format playback state with color
Format.playback_state = function()
  local paused = mpv.mp.get_property_bool("pause", false)
  local state = paused and "Paused" or "Playing"
  mpv.msg.verbose("Playback state: " .. state)

  if paused then
    return Format.colored(state, Config.colors.bad)
  else
    return Format.colored(state, Config.colors.good)
  end
end

-- Format shuffle status with color when active
Format.shuffle = function()
  if State.shuffled then
    return "Shuffle: " .. Format.colored("On", Config.colors.value)
  else
    return "Shuffle: Off"
  end
end

--------------------------------------------------
-- Menu Handling
--------------------------------------------------

local Menu = {}

-- Render overlay with all current state information
Menu.draw = function()
  mpv.msg.info("Drawing menu overlay")
  local ass = mpv.assdraw.ass_new()
  ass:new_event()
  ass:pos(Config.ui.menu_x, Config.ui.menu_y)

  -- Create semi-transparent background
  ass:append(string.format("{\\bord0}{\\shad0}{\\1c&H%s&}{\\1a&H%s&}{\\p1}",
    Config.colors.background, Config.ui.transparency))
  ass:draw_start()
  ass:round_rect_cw(0, 0, Config.ui.menu_width, Config.ui.menu_height, Config.ui.corner_radius)
  ass:draw_stop()

  -- Set text formatting
  ass:append(string.format("{\\an7}{\\fs%d}{\\bord2}{\\shad0}{\\1c&H%s&}{\\3c&H000000&}{\\bord1}{\\fscx100}{\\fscy100}",
    Config.ui.font_size, Config.colors.default))

  -- Title with icon
  ass:append(string.format("🔴 %s\\N\\N", Format.title(mpv.mp.get_property("media-title", ""))))

  -- Arrange items in a clear two-column layout with related items paired
  ass:append(string.format("Status:    %-15s Position:  %s\\N",
    Format.playback_state(), Format.position()))

  ass:append(string.format("Remaining: %-15s Speed:     %s\\N",
    Format.time_remaining(), Format.speed()))

  ass:append(string.format("Quality:   %-15s Size:      %s\\N",
    Format.quality(), Format.filesize()))

  ass:append(string.format("Zoom:      %-15s Pan:       %s\\N",
    Format.zoom(), Format.pan()))

  ass:append(string.format("Rotate:    %-15s Flip:      %s\\N",
    Format.rotation(), Format.flip()))

  ass:append(string.format("Audio:     %-15s Aspect:    %s\\N",
    Format.audio(), Format.aspect()))

  ass:append(string.format("%s\\N", Format.shuffle()))

  return ass.text
end

-- Update the OSD overlay with current values
Menu.update = function()
  mpv.msg.debug("Updating menu overlay")
  State.menu_ass.data = Menu.draw()
  State.menu_ass:update()
end

-- Toggle menu visibility and register/unregister property observers
Menu.toggle = function()
  State.menu_visible = not State.menu_visible
  mpv.msg.info("Toggle menu: " .. tostring(State.menu_visible))

  if State.menu_visible then
    Menu.update()

    -- Properties to observe for menu updates
    local properties = {
      {"playtime-remaining", "number"},
      {"percent-pos", "number"},
      {"width", "number"},
      {"height", "number"},
      {"file-size", "number"},
      {"speed", "number"},
      {"video-zoom", "number"},
      {"video-pan-x", "number"},
      {"video-pan-y", "number"},
      {"video-rotate", "number"},
      {"vf", "native"},
      {"pause", "bool"},
      {"volume", "number"},
      {"audio-codec", "string"},
      {"video-params/aspect", "number"}
    }

    -- Register all observers
    for _, prop in ipairs(properties) do
      mpv.mp.observe_property(prop[1], prop[2], Menu.update)
    end
  else
    State.menu_ass:remove()
    mpv.mp.unobserve_property(Menu.update)
  end
end

--------------------------------------------------
-- Playback Control
--------------------------------------------------

local Playback = {}

-- Reset video flipping filters
Playback.reset_flipping = function()
  mpv.msg.debug("Resetting flip filters")
  local vf_table = mpv.mp.get_property_native("vf")

  for i = #vf_table, 1, -1 do
    if vf_table[i].name == "vflip" or vf_table[i].name == "hflip" then
      mpv.mp.commandv("vf", "del", tostring(i - 1))
    end
  end
end

-- Reset all video properties to defaults
Playback.reset_properties = function()
  mpv.msg.debug("Resetting video properties")
  mpv.mp.set_property("video-pan-x", 0)
  mpv.mp.set_property("video-pan-y", 0)
  mpv.mp.set_property("video-rotate", 0)
  mpv.mp.set_property("video-zoom", 0)
  mpv.mp.set_property("ab-loop-a", "no")
  mpv.mp.set_property("ab-loop-b", "no")
  Playback.reset_flipping()
end

-- Seek to custom start position based on config
Playback.skip_to_position = function()
  local duration = mpv.mp.get_property_number("duration", 0)

  if not duration or duration <= 0 then
    mpv.msg.error("Invalid or missing video duration")
    return
  end

  if duration > Config.playback.min_duration_threshold then
    mpv.msg.debug(string.format("Seeking to %.1f%% position", Config.playback.start_position_percent))
    mpv.mp.commandv("seek", duration * (Config.playback.start_position_percent / 100), "absolute")
  else
    mpv.msg.debug("Video too short, starting from beginning")
    mpv.mp.commandv("seek", 0, "absolute")
  end
end

-- Handle file loaded event - reset properties and seek to start position
Playback.on_file_loaded = function()
  mpv.msg.info("New file loaded - initializing")
  Playback.reset_properties()
  Playback.skip_to_position()
end

-- Skip to next video in playlist
Playback.next_video = function()
  mpv.msg.info("Next video")
  mpv.mp.unregister_event(Playback.on_file_loaded)
  mpv.mp.commandv("playlist-next", "weak")
  mpv.mp.register_event("file-loaded", Playback.on_file_loaded)
end

-- Go to previous video in playlist
Playback.prev_video = function()
  mpv.msg.info("Previous video")
  mpv.mp.unregister_event(Playback.on_file_loaded)
  mpv.mp.commandv("playlist-prev", "weak")
  mpv.mp.register_event("file-loaded", Playback.on_file_loaded)
end

--------------------------------------------------
-- Key Bindings
--------------------------------------------------

-- Register key bindings
mpv.mp.add_key_binding("Ctrl+k", "toggle_menu", Menu.toggle)
mpv.mp.add_key_binding("j", "playlist_next_custom", Playback.next_video)
mpv.mp.add_key_binding("k", "playlist_prev_custom", Playback.prev_video)

-- Receive shuffle state updates from other scripts
mpv.mp.register_script_message("shuffle_state", function(value)
  mpv.msg.info("Shuffle state message received: " .. tostring(value))
  State.shuffled = (value == "on" or value == "true" or value == "1")
  if State.menu_visible then Menu.update() end
end)


-- |   END: toggle-menu.lua
