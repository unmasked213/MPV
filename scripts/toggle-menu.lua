-- | START: toggle-menu.lua
-- |  PATH: D:\MPV\mpv\scripts\toggle-menu.lua

-- ➔ Modern, visually appealing overlay with enhanced layout and design
--    Card-based sections with visual progress indicators
--    Intelligent grouping and intuitive iconography
--    Responsive color coding and improved typography
--
-- ✅ LINTING FIXES APPLIED:
--    • Added safe property access with nil checking
--    • Protected against division by zero errors
--    • Added input validation and bounds checking
--    • Optimized string concatenation using table.concat
--    • Consistent color format in configuration
--    • Enhanced error handling with pcall
--    • Fixed mathematical operations safety
--    • Improved type conversion with fallbacks
--    • Extracted magic numbers to constants
--    • Improved function readability with early returns

local mpv = {
  mp = require 'mp',
  assdraw = require 'mp.assdraw',
  msg = require 'mp.msg'
}

--------------------------------------------------
-- Enhanced Configuration
--------------------------------------------------

local Config = {
  -- Enhanced color palette (consistent hex format)
  colors = {
    primary = "FFFFFF",       -- Primary text (white)
    accent = "00D4FF",        -- Accent color (bright blue)
    success = "00FF88",       -- Success/good state (green)
    warning = "FFB800",       -- Warning/medium state (orange)
    danger = "FF4757",        -- Error/bad state (red)
    muted = "8E8E93",         -- Secondary text (gray)
    background = "1A1A1A",    -- Dark background
    card = "2A2A2A",          -- Card background
    progress_bg = "404040",   -- Progress bar background
    overlay = "000000"        -- Overlay background
  },

  -- Video start behavior
  playback = {
    start_position_percent = 1,
    min_duration_threshold = 999999
  },

  -- Enhanced UI settings
  ui = {
    panel_width = 420,
    panel_height = 480,
    card_spacing = 12,
    padding = 20,
    corner_radius = 12,
    font_size_title = 24,
    font_size_normal = 18,
    font_size_small = 14,
    panel_x = 60,
    panel_y = 60,
    progress_height = 6,
    transparency = "E6"  -- More opaque for better readability
  },

  -- Constants
  constants = {
    TITLE_MAX_LENGTH = 28,
    TITLE_TRUNCATE_LENGTH = 25,
    MIN_SPEED_THRESHOLD = 0.001,
    MIN_TRANSFORM_THRESHOLD = 0.01,
    MIN_PAN_THRESHOLD = 0.002,
    MIN_ROTATION_THRESHOLD = 0.1,
    PROGRESS_BAR_WIDTH = 30,
    VOLUME_BAR_WIDTH = 20,
    POSITION_BAR_WIDTH = 35
  }
}

--------------------------------------------------
-- State
--------------------------------------------------

local State = {
  menu_visible = false,
  menu_ass = mpv.mp.create_osd_overlay("ass-events"),
  shuffled = false
}

--------------------------------------------------
-- Enhanced Formatting Helpers
--------------------------------------------------

local Format = {}

-- Safe property access with fallback
local function safe_get_property(name, property_type, fallback)
  local value = mpv.mp.get_property(name)
  if value == nil then return fallback end

  if property_type == "number" then
    local num = tonumber(value)
    return num or fallback
  elseif property_type == "bool" then
    return value == "yes" or value == "true"
  end

  return value or fallback
end

local function safe_get_property_number(name, fallback)
  return mpv.mp.get_property_number(name) or fallback or 0
end

local function safe_get_property_bool(name, fallback)
  local val = mpv.mp.get_property_bool(name)
  return val ~= nil and val or (fallback or false)
end

-- Create colored text with optional background
Format.colored = function(text, color, bg_color)
  if not text then return "" end
  color = color or Config.colors.primary
  local result = string.format("{\\1c&H%s&}%s", color, tostring(text))
  if bg_color then
    result = string.format("{\\3c&H%s&}%s", bg_color, result)
  end
  return result .. "{\\1c&H" .. Config.colors.primary .. "&}"
end

-- Create section headers with enhanced styling
Format.section_header = function(icon, title)
  return string.format("%s %s",
    Format.colored(icon or "", Config.colors.accent),
    Format.colored(title or "", Config.colors.primary)
  )
end

-- Enhanced title formatting with safety checks
Format.title = function(title)
  if not title or title == "" then return "Unknown" end

  title = tostring(title)
  title = title:gsub("_", " "):gsub("-", " "):gsub("%d", ""):gsub("[^%w%s%(%)]", "")

  if #title > Config.constants.TITLE_MAX_LENGTH then
    title = title:sub(1, Config.constants.TITLE_TRUNCATE_LENGTH) .. "..."
  end

  return title ~= "" and title or "Unknown"
end

-- Visual progress bar with input validation
Format.progress_bar = function(percent, width, show_text)
  percent = tonumber(percent) or 0
  width = tonumber(width) or Config.constants.PROGRESS_BAR_WIDTH

  -- Clamp percent between 0 and 100
  percent = math.max(0, math.min(100, percent))
  width = math.max(1, width)

  local filled = math.floor(percent * width / 100)
  local empty = width - filled

  local colored_bar = Format.colored(string.rep("█", filled), Config.colors.accent) ..
                     Format.colored(string.rep("░", empty), Config.colors.progress_bg)

  if show_text then
    return string.format("%s %s", colored_bar, Format.colored(string.format("%.1f%%", percent), Config.colors.muted))
  end
  return colored_bar
end

-- Enhanced position formatting with visual bar
Format.position = function()
  local percent = safe_get_property_number("percent-pos", 0)
  percent = math.max(0, math.min(100, percent))
  return Format.progress_bar(percent, Config.constants.POSITION_BAR_WIDTH, true)
end

-- Enhanced time formatting with safety checks
Format.time_info = function()
  local current = safe_get_property_number("playback-time", 0)
  local duration = safe_get_property_number("duration", 0)
  local speed = safe_get_property_number("speed", 1)

  -- Prevent division by zero
  if speed == 0 then speed = 1 end

  local remaining = safe_get_property_number("playtime-remaining", 0) / speed

  local function format_time(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 0 then seconds = 0 end

    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)

    return h > 0 and string.format("%d:%02d:%02d", h, m, s) or string.format("%d:%02d", m, s)
  end

  if duration and duration > 0 then
    return string.format("%s %s / %s",
      Format.colored("●", Config.colors.accent),
      format_time(current),
      Format.colored(format_time(duration), Config.colors.muted)
    )
  end

  return Format.colored("⚫ LIVE", Config.colors.danger)
end

-- Enhanced quality with resolution icons and safety checks
Format.quality = function()
  local width = safe_get_property_number("width", 0)
  local height = safe_get_property_number("height", 0)

  if width <= 0 or height <= 0 then
    return Format.colored("○ Unknown", Config.colors.muted)
  end

  local max_dim = math.max(width, height)

  local quality_map = {
    {threshold = 3840, label = "4K", icon = "◆", color = Config.colors.success},
    {threshold = 2560, label = "1440p", icon = "◆", color = Config.colors.success},
    {threshold = 1920, label = "1080p", icon = "●", color = Config.colors.accent},
    {threshold = 1280, label = "720p", icon = "●", color = Config.colors.warning},
    {threshold = 854, label = "480p", icon = "○", color = Config.colors.danger},
    {threshold = 640, label = "360p", icon = "○", color = Config.colors.danger},
    {threshold = 0, label = "Low", icon = "○", color = Config.colors.danger}
  }

  for _, q in ipairs(quality_map) do
    if max_dim >= q.threshold then
      return string.format("%s %s",
        Format.colored(q.icon, q.color),
        Format.colored(q.label, q.color)
      )
    end
  end

  return Format.colored("○ Unknown", Config.colors.muted)
end

-- Enhanced file size with better units and safety checks
Format.filesize = function()
  local size = safe_get_property_number("file-size", -1)

  if size <= 0 then
    return Format.colored("📄 Unknown", Config.colors.muted)
  end

  local units = {"B", "KB", "MB", "GB", "TB"}
  local unit_index = 1
  local display_size = size

  while display_size >= 1024 and unit_index < #units do
    display_size = display_size / 1024
    unit_index = unit_index + 1
  end

  local formatted = string.format("%.1f %s", display_size, units[unit_index])
  return string.format("%s %s",
    Format.colored("📄", Config.colors.accent),
    formatted
  )
end

-- Enhanced speed with visual indicators and safety checks
Format.speed = function()
  local speed = safe_get_property_number("speed", 1)
  local icon, color

  if math.abs(speed - 1) < Config.constants.MIN_SPEED_THRESHOLD then
    icon, color = "▶", Config.colors.success
  elseif speed > 1 then
    icon, color = "⏩", Config.colors.warning
  else
    icon, color = "⏪", Config.colors.warning
  end

  local speed_text = math.abs(speed - 1) < Config.constants.MIN_SPEED_THRESHOLD and "Normal" or string.format("%.1fx", speed)
  return string.format("%s %s", Format.colored(icon, color), speed_text)
end

-- Volume with visual bar and safety checks
Format.volume = function()
  local codec = safe_get_property("audio-codec", "string", "")
  if not codec or codec == "" or codec == "none" then
    return Format.colored("🔇 Silent", Config.colors.danger)
  end

  local vol = safe_get_property_number("volume", 100)
  local muted = safe_get_property_bool("mute", false)

  if muted then
    return Format.colored("🔇 Muted", Config.colors.danger)
  end

  vol = math.max(0, math.min(100, vol))

  local icon = vol == 0 and "🔇" or vol < 30 and "🔉" or vol < 70 and "🔊" or "🔊"
  local bar = Format.progress_bar(vol, Config.constants.VOLUME_BAR_WIDTH, false)

  return string.format("%s %s %d%%",
    Format.colored(icon, Config.colors.accent),
    bar,
    vol
  )
end

-- Enhanced transform info with visual indicators and safety checks
Format.transform_info = function()
  local zoom = safe_get_property_number("video-zoom", 0)
  local pan_x = safe_get_property_number("video-pan-x", 0)
  local pan_y = safe_get_property_number("video-pan-y", 0)
  local rotation = safe_get_property_number("video-rotate", 0)

  local parts = {}

  -- Zoom
  if math.abs(zoom) > Config.constants.MIN_TRANSFORM_THRESHOLD then
    local zoom_factor = math.exp(zoom)
    table.insert(parts, Format.colored("🔍", Config.colors.accent) .. string.format(" %.2fx", zoom_factor))
  end

  -- Pan
  if math.abs(pan_x) > Config.constants.MIN_PAN_THRESHOLD or math.abs(pan_y) > Config.constants.MIN_PAN_THRESHOLD then
    local pan_text = ""
    if math.abs(pan_x) > Config.constants.MIN_PAN_THRESHOLD then
      pan_text = pan_text .. (pan_x > 0 and "→" or "←")
    end
    if math.abs(pan_y) > Config.constants.MIN_PAN_THRESHOLD then
      pan_text = pan_text .. (pan_y > 0 and "↓" or "↑")
    end
    table.insert(parts, Format.colored("🎯", Config.colors.accent) .. " " .. pan_text)
  end

  -- Rotation
  if math.abs(rotation) > Config.constants.MIN_ROTATION_THRESHOLD then
    table.insert(parts, Format.colored("↻", Config.colors.accent) .. string.format(" %d°", math.floor(rotation + 0.5)))
  end

  if #parts == 0 then
    return Format.colored("📐 Default", Config.colors.muted)
  end

  return table.concat(parts, "  ")
end

-- Playback state with enhanced icons and safety checks
Format.playback_state = function()
  local paused = safe_get_property_bool("pause", false)
  return paused and Format.colored("⏸ PAUSED", Config.colors.warning) or Format.colored("▶ PLAYING", Config.colors.success)
end

-- Enhanced aspect ratio with safety checks
Format.aspect = function()
  local aspect = safe_get_property_number("video-params/aspect", 0)
  local icon = "📺"

  if aspect <= 0 then
    return Format.colored(icon .. " Unknown", Config.colors.muted)
  end

  local ratio_text
  if aspect > 2.35 then
    ratio_text = "21:9 Ultra-wide"
  elseif aspect > 1.9 then
    ratio_text = "16:9 Widescreen"
  elseif aspect > 1.5 then
    ratio_text = "16:10"
  elseif aspect > 1.2 then
    ratio_text = "4:3 Standard"
  else
    ratio_text = string.format("%.2f:1", aspect)
  end

  return string.format("%s %s", Format.colored(icon, Config.colors.accent), ratio_text)
end

-- Shuffle status with safety checks
Format.shuffle = function()
  return State.shuffled and Format.colored("🔀 ON", Config.colors.success) or Format.colored("➡ OFF", Config.colors.muted)
end

--------------------------------------------------
-- Enhanced Menu Rendering
--------------------------------------------------

local Menu = {}

-- Create a visual card section
Menu.create_card = function(x, y, width, height, content)
  local ass = mpv.assdraw.ass_new()

  -- Card background
  ass:new_event()
  ass:pos(x, y)
  ass:append(string.format("{\\bord0}{\\shad2}{\\1c&H%s&}{\\1a&H%s&}{\\p1}",
    Config.colors.card, Config.ui.transparency))
  ass:draw_start()
  ass:round_rect_cw(0, 0, width, height, 8)
  ass:draw_stop()

  -- Card content
  ass:new_event()
  ass:pos(x + 15, y + 15)
  ass:append(string.format("{\\an7}{\\fs%d}{\\bord1}{\\shad1}{\\1c&H%s&}%s",
    Config.ui.font_size_normal, Config.colors.primary, content))

  return ass.text
end

-- Main drawing function with enhanced layout and optimized string handling
Menu.draw = function()
  local parts = {}
  local x = Config.ui.panel_x
  local y = Config.ui.panel_y
  local card_width = (Config.ui.panel_width - Config.ui.padding * 3) / 2
  local full_width = Config.ui.panel_width - Config.ui.padding * 2

  -- Main background with gradient effect
  local bg_ass = mpv.assdraw.ass_new()
  bg_ass:new_event()
  bg_ass:pos(x, y)
  bg_ass:append(string.format("{\\bord0}{\\shad3}{\\1c&H%s&}{\\1a&H%s&}{\\p1}",
    Config.colors.overlay, Config.ui.transparency))
  bg_ass:draw_start()
  bg_ass:round_rect_cw(0, 0, Config.ui.panel_width, Config.ui.panel_height, Config.ui.corner_radius)
  bg_ass:draw_stop()
  table.insert(parts, bg_ass.text)

  local current_y = y + Config.ui.padding

  -- Header Section - Title and Status
  local title = Format.title(safe_get_property("media-title", "string", ""))
  local header_content = string.format(
    "%s\\N\\N%s",
    Format.colored("🎬 " .. title, Config.colors.primary),
    Format.playback_state()
  )
  table.insert(parts, Menu.create_card(x + Config.ui.padding, current_y, full_width, 80, header_content))
  current_y = current_y + 80 + Config.ui.card_spacing

  -- Progress Section
  local progress_content = string.format(
    "%s\\N%s\\N%s",
    Format.section_header("⏱", "PROGRESS"),
    Format.position(),
    Format.time_info()
  )
  table.insert(parts, Menu.create_card(x + Config.ui.padding, current_y, full_width, 90, progress_content))
  current_y = current_y + 90 + Config.ui.card_spacing

  -- Media Info Section (Left)
  local media_content = string.format(
    "%s\\N%s\\N%s\\N%s",
    Format.section_header("📊", "MEDIA"),
    Format.quality(),
    Format.filesize(),
    Format.aspect()
  )
  table.insert(parts, Menu.create_card(x + Config.ui.padding, current_y, card_width, 110, media_content))

  -- Playback Info Section (Right)
  local playback_content = string.format(
    "%s\\N%s\\N%s",
    Format.section_header("⚙", "PLAYBACK"),
    Format.speed(),
    Format.shuffle()
  )
  table.insert(parts, Menu.create_card(x + Config.ui.padding + card_width + Config.ui.card_spacing, current_y, card_width, 110, playback_content))
  current_y = current_y + 110 + Config.ui.card_spacing

  -- Audio Section
  local audio_content = string.format(
    "%s\\N%s",
    Format.section_header("🔊", "AUDIO"),
    Format.volume()
  )
  table.insert(parts, Menu.create_card(x + Config.ui.padding, current_y, full_width, 70, audio_content))
  current_y = current_y + 70 + Config.ui.card_spacing

  -- Transform Section (if any transforms are active)
  local transform_info = Format.transform_info()
  if not transform_info:find("Default") then
    local transform_content = string.format(
      "%s\\N%s",
      Format.section_header("🔧", "TRANSFORM"),
      transform_info
    )
    table.insert(parts, Menu.create_card(x + Config.ui.padding, current_y, full_width, 70, transform_content))
  end

  return table.concat(parts)
end

-- Update function
Menu.update = function()
  if State.menu_visible then
    State.menu_ass.data = Menu.draw()
    State.menu_ass:update()
  end
end

-- Toggle function with enhanced property monitoring and error handling
Menu.toggle = function()
  State.menu_visible = not State.menu_visible
  mpv.msg.info("Enhanced menu toggle: " .. tostring(State.menu_visible))

  if State.menu_visible then
    -- Safely update menu with error handling
    local success, err = pcall(Menu.update)
    if not success then
      mpv.msg.error("Failed to update menu: " .. tostring(err))
      State.menu_visible = false
      return
    end

    -- Enhanced property observation with batching
    local properties = {
      {"playtime-remaining", "number"},
      {"playback-time", "number"},
      {"percent-pos", "number"},
      {"duration", "number"},
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
      {"mute", "bool"},
      {"audio-codec", "string"},
      {"video-params/aspect", "number"},
      {"media-title", "string"}
    }

    -- Register observers with error handling
    for _, prop in ipairs(properties) do
      local success_obs, err_obs = pcall(function()
        mpv.mp.observe_property(prop[1], prop[2], Menu.update)
      end)
      if not success_obs then
        mpv.msg.warn("Failed to observe property " .. prop[1] .. ": " .. tostring(err_obs))
      end
    end
  else
    -- Safely remove overlay and unregister observers
    pcall(function()
      State.menu_ass:remove()
      mpv.mp.unobserve_property(Menu.update)
    end)
  end
end

--------------------------------------------------
-- Playback Control
--------------------------------------------------

local Playback = {}

Playback.reset_flipping = function()
  local vf_table = mpv.mp.get_property_native("vf")
  if not vf_table then return end

  for i = #vf_table, 1, -1 do
    if vf_table[i].name == "vflip" or vf_table[i].name == "hflip" then
      mpv.mp.commandv("vf", "del", tostring(i - 1))
    end
  end
end

Playback.reset_properties = function()
  local properties = {
    {"video-pan-x", 0},
    {"video-pan-y", 0},
    {"video-rotate", 0},
    {"video-zoom", 0},
    {"ab-loop-a", "no"},
    {"ab-loop-b", "no"}
  }

  for _, prop in ipairs(properties) do
    mpv.mp.set_property(prop[1], prop[2])
  end

  Playback.reset_flipping()
end

Playback.skip_to_position = function()
  local duration = mpv.mp.get_property_number("duration", 0)
  if not duration or duration <= 0 then return end

  local seek_pos = duration > Config.playback.min_duration_threshold and
                   duration * (Config.playback.start_position_percent / 100) or 0
  mpv.mp.commandv("seek", seek_pos, "absolute")
end

Playback.on_file_loaded = function()
  Playback.reset_properties()
  Playback.skip_to_position()
end

Playback.next_video = function()
  mpv.mp.unregister_event(Playback.on_file_loaded)
  mpv.mp.commandv("playlist-next", "weak")
  mpv.mp.register_event("file-loaded", Playback.on_file_loaded)
end

Playback.prev_video = function()
  mpv.mp.unregister_event(Playback.on_file_loaded)
  mpv.mp.commandv("playlist-prev", "weak")
  mpv.mp.register_event("file-loaded", Playback.on_file_loaded)
end

--------------------------------------------------
-- Key Bindings and Events
--------------------------------------------------

mpv.mp.add_key_binding("Ctrl+k", "toggle_menu", Menu.toggle)
mpv.mp.add_key_binding("j", "playlist_next_custom", Playback.next_video)
mpv.mp.add_key_binding("k", "playlist_prev_custom", Playback.prev_video)

mpv.mp.register_script_message("shuffle_state", function(value)
  State.shuffled = (value == "on" or value == "true" or value == "1")
  Menu.update()
end)

mpv.mp.register_event("file-loaded", Playback.on_file_loaded)

-- |   END: toggle-menu.lua
