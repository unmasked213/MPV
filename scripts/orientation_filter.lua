-- | START: orientation_filter.lua (Enhanced with FFprobe indexing and critical fixes)
-- |  PATH: D:\MPV\mpv\scripts\orientation_filter.lua

local mp    = require 'mp'
local msg   = require 'mp.msg'
local utils = require 'mp.utils'

---------------------------------------------------------------------
-- Configuration -----------------------------------------------------
---------------------------------------------------------------------
local ENABLE_FFPROBE_INDEXING = true
local MAX_NAVIGATION_ATTEMPTS = 50      -- bounded‑search skips before we give up
local FFPROBE_TIMEOUT         = 5       -- seconds per probe
local PROGRESS_UPDATE_INTERVAL= 25      -- index progress cadence

---------------------------------------------------------------------
-- State -------------------------------------------------------------
---------------------------------------------------------------------
local current_mode     = "OFF"   -- "OFF" | "LANDSCAPE" | "PORTRAIT"
local orientation_index= { landscape = {}, portrait = {}, unknown = {} }
local orientation_cache= {}      -- persistent JSON on disk
local indexing_in_progress = false
local active_timeouts   = {}     -- non‑navigation timers
local active_navigation_timer = nil -- single bounded‑search timer

---------------------------------------------------------------------
-- Helpers -----------------------------------------------------------
---------------------------------------------------------------------
local function get_cache_file_path()
    local script_dir = mp.get_script_directory()
    if not script_dir then
        msg.warn("Could not determine script directory, cache disabled")
        return nil
    end
    return script_dir .. "/orientation_cache.json"
end
local CACHE_FILE = get_cache_file_path()

-- managed timeout ---------------------------------------------------
local function cleanup_timeout(id)
    active_timeouts[id] = nil
end
local function add_managed_timeout(delay, fn, id)
    id = id or tostring(math.random(10000,99999))
    active_timeouts[id] = true
    mp.add_timeout(delay, function()
        if active_timeouts[id] then
            cleanup_timeout(id)
            fn()
        end
    end)
    return id
end

-- safe IO -----------------------------------------------------------
local function safe_file_read(path)
    if not path then return nil end
    local f, err = io.open(path, "r")
    if not f then msg.debug("read error: "..(err or "?")); return nil end
    local c = f:read("*all"); f:close(); return c
end
local function safe_file_write(path, content)
    if not path or not content then return false end
    local f, err = io.open(path, "w")
    if not f then msg.warn("write error: "..(err or "?")); return false end
    f:write(content); f:close(); return true
end

-- cache load/save ---------------------------------------------------
local function load_cache()
    if not CACHE_FILE then return end
    local raw = safe_file_read(CACHE_FILE)
    if not raw then return end
    local ok, data = pcall(utils.parse_json, raw)
    if ok and type(data)=="table" then orientation_cache = data end
    msg.info(string.format("Loaded orientation cache (%d entries)", (function(t) local c=0; for _ in pairs(t) do c=c+1 end; return c end)(orientation_cache)))
end
local function save_cache()
    if not CACHE_FILE then return end
    local ok, json = pcall(utils.format_json, orientation_cache)
    if not ok then msg.error("Failed to serialize cache"); return end
    safe_file_write(CACHE_FILE, json)
end

---------------------------------------------------------------------
-- New: cache helpers (critical fix) ---------------------------------
---------------------------------------------------------------------
local function get_cache_size()
    local n = 0; for _ in pairs(orientation_cache) do n=n+1 end; return n
end
local function get_cached_orientation(path, finfo)
    if not finfo or not finfo.size or not finfo.mtime then return nil end
    local key = string.format("%s|%d|%d", path, finfo.size, finfo.mtime)
    local entry = orientation_cache[key]
    if entry and entry.orientation then return entry.orientation, entry.width, entry.height end
    return nil
end

---------------------------------------------------------------------
-- ffprobe probe -----------------------------------------------------
---------------------------------------------------------------------
local function get_video_dimensions_ffprobe(path)
    if not path then return nil,nil end
    local res = utils.subprocess({
        args = {"ffprobe","-v","quiet","-print_format","json","-show_streams","-select_streams","v:0", path},
        max_size = 8192,
        timeout  = FFPROBE_TIMEOUT,
    })
    if res.status ~= 0 or not res.stdout then return nil,nil end
    local ok, data = pcall(utils.parse_json, res.stdout)
    if not ok or not data or not data.streams or not data.streams[1] then return nil,nil end
    local s = data.streams[1]
    local w,h = tonumber(s.width), tonumber(s.height)
    if w and h and w>0 and h>0 then return w,h end
    return nil,nil
end

---------------------------------------------------------------------
-- Orientation predicates -------------------------------------------
---------------------------------------------------------------------
local function check_orientation_with_rotation()
    -- use display‑aware dwidth/dheight first (MPV already rotates)
    local dw = mp.get_property_number("dwidth")
    local dh = mp.get_property_number("dheight")
    if dw and dh then
        if current_mode=="LANDSCAPE" and dw>dh then return true end
        if current_mode=="PORTRAIT"  and dh>dw then return true end
        return false
    end
    -- fallback manual rotate property
    local w = mp.get_property_number("width")
    local h = mp.get_property_number("height")
    local rot = mp.get_property_number("video-params/rotate",0)
    if not w or not h then return false end
    local ew,eh = w,h
    if rot==90 or rot==270 then ew,eh = h,w end
    if current_mode=="LANDSCAPE" and ew>eh then return true end
    if current_mode=="PORTRAIT"  and eh>ew then return true end
    return false
end

---------------------------------------------------------------------
-- Index builder (critical fixes applied) ----------------------------
---------------------------------------------------------------------
local function build_ffprobe_index()
    if indexing_in_progress then return end
    indexing_in_progress = true

    local count = mp.get_property_number("playlist-count",0)
    if count<=0 then indexing_in_progress=false; return end

    orientation_index = {landscape={}, portrait={}, unknown={}}
    mp.osd_message(string.format("Building orientation index... (0/%d)",count))
    msg.info(string.format("Start indexing | cached=%d", get_cache_size()))

    local stat = {processed=0,landscape=0,portrait=0,failed=0,cached=0}

    for i = 0, count - 1 do
        local filepath = mp.get_property_native(string.format("playlist/%d/filename", i))

        if not filepath then
            msg.warn("Missing path at index " .. i)
            table.insert(orientation_index.unknown, i)
            stat.failed = stat.failed + 1
        else
            local file_info = utils.file_info(filepath)
            if not file_info then
                msg.warn("file_info failed: " .. filepath)
                table.insert(orientation_index.unknown, i)
                stat.failed = stat.failed + 1
            else
                local ori, w, h = get_cached_orientation(filepath, file_info)
                if ori then
                    table.insert(orientation_index[ori], i)
                    stat[ori] = stat[ori] + 1
                    stat.cached = stat.cached + 1
                else
                    w, h = get_video_dimensions_ffprobe(filepath)
                    if w and h then
                        local ori2 = w > h and "landscape" or "portrait"
                        local key = string.format("%s|%d|%d", filepath, file_info.size, file_info.mtime)
                        orientation_cache[key] = { orientation = ori2, width = w, height = h }
                        table.insert(orientation_index[ori2], i)
                        stat[ori2] = stat[ori2] + 1
                    else
                        table.insert(orientation_index.unknown, i)
                        stat.failed = stat.failed + 1
                    end
                end
            end
        end

        stat.processed = stat.processed + 1
        if stat.processed % PROGRESS_UPDATE_INTERVAL == 0 or stat.processed == count then
            mp.osd_message(string.format(
                "Indexing... (%d/%d) L:%d P:%d Cache:%d",
                stat.processed, count, stat.landscape, stat.portrait, stat.cached
            ))
        end
    end


    save_cache()
    indexing_in_progress = false
    local summary = string.format("Index complete: %d landscape, %d portrait (%d cache)", stat.landscape, stat.portrait, stat.cached)
    mp.osd_message(summary)
    msg.info(summary)
end

---------------------------------------------------------------------
-- Navigation --------------------------------------------------------
---------------------------------------------------------------------
-- indexed navigation
local function navigate_indexed(dir)
    if current_mode=="OFF" then return end
    local lst = current_mode=="LANDSCAPE" and orientation_index.landscape or orientation_index.portrait
    if #lst==0 then mp.osd_message("No "..current_mode:lower().." videos in playlist"); return end

    local cur = mp.get_property_number("playlist-pos",0)
    local target
    if dir=="next" then
        for _,p in ipairs(lst) do if p>cur then target=p; break end end
        if not target then target=lst[1] end
    else
        for i=#lst,1,-1 do if lst[i]<cur then target=lst[i]; break end end
        if not target then target=lst[#lst] end
    end
    if target then
        mp.set_property_number("playlist-pos", target)
        mp.osd_message(string.format("Jumped to %s video #%d", current_mode:lower(), target+1))
    end
end

-- bounded navigation (single timer fix) ----------------------------
local function navigate_bounded(dir)
    -- cancel existing nav timer if any
    if active_navigation_timer then active_navigation_timer:kill(); active_navigation_timer=nil end

    local count = mp.get_property_number("playlist-count",0)
    local start = mp.get_property_number("playlist-pos",0)
    local attempts = 0

    local function step()
        if attempts>=MAX_NAVIGATION_ATTEMPTS then
            mp.osd_message(string.format("No %s videos found after %d attempts", current_mode:lower(), attempts))
            active_navigation_timer=nil
            return
        end
        if dir=="next" then mp.commandv("playlist-next","weak") else mp.commandv("playlist-prev","weak") end
        attempts = attempts + 1
        active_navigation_timer = mp.add_timeout(0.2, function()
            active_navigation_timer=nil
            local cur = mp.get_property_number("playlist-pos",0)
            if attempts>1 and cur==start then mp.osd_message("Searched entire playlist - no matches found"); return end
            if not check_orientation_with_rotation() then
                mp.osd_message(string.format("Skipping: %s [%d/%d]", (mp.get_property("filename") or "?"), attempts, MAX_NAVIGATION_ATTEMPTS))
                step()
            else
                mp.osd_message(string.format("Found %s video: %s", current_mode:lower(), (mp.get_property("filename") or "?")))
            end
        end)
    end
    step()
end

-- dispatcher --------------------------------------------------------
local function smart_navigate(dir)
    if current_mode=="OFF" then return end
    if #orientation_index.landscape>0 or #orientation_index.portrait>0 then navigate_indexed(dir) else navigate_bounded(dir) end
end

local function next_video_handler() if current_mode=="OFF" then mp.commandv("playlist-next","weak") else smart_navigate("next") end end
local function prev_video_handler() if current_mode=="OFF" then mp.commandv("playlist-prev","weak") else smart_navigate("prev") end end

---------------------------------------------------------------------
-- Mode toggles ------------------------------------------------------
---------------------------------------------------------------------
local function set_mode(new_mode, friendly_name)
    current_mode = new_mode
    if new_mode=="OFF" then mp.osd_message(friendly_name.." Only Mode: Disabled"); return end
    mp.osd_message(friendly_name.." Only Mode: Enabled")
    if ENABLE_FFPROBE_INDEXING and not indexing_in_progress then
        local tgt = new_mode=="LANDSCAPE" and orientation_index.landscape or orientation_index.portrait
        if #tgt==0 then build_ffprobe_index() end
    end
    add_managed_timeout(0.2,function()
        if not check_orientation_with_rotation() then next_video_handler() end
    end)
end
local function toggle_landscape_mode() set_mode(current_mode=="LANDSCAPE" and "OFF" or "LANDSCAPE","Landscape") end
local function toggle_portrait_mode()  set_mode(current_mode=="PORTRAIT"  and "OFF" or "PORTRAIT" ,"Portrait" ) end

---------------------------------------------------------------------
-- File-loaded auto‑skip --------------------------------------------
---------------------------------------------------------------------
local function on_file_loaded()
    if current_mode=="OFF" then return end
    add_managed_timeout(0.2,function()
        if not check_orientation_with_rotation() then next_video_handler() end
    end)
end

---------------------------------------------------------------------
-- Init / Cleanup ----------------------------------------------------
---------------------------------------------------------------------
local function initialize()
    load_cache()
    msg.info("Orientation filter initialized (FFprobe="..tostring(ENABLE_FFPROBE_INDEXING)..")")
end

local function cleanup()
    if active_navigation_timer then active_navigation_timer:kill(); active_navigation_timer=nil end
    for id in pairs(active_timeouts) do cleanup_timeout(id) end
    msg.debug("Orientation filter cleanup completed")
end

---------------------------------------------------------------------
-- Bindings & events -------------------------------------------------
---------------------------------------------------------------------
mp.register_event("file-loaded", on_file_loaded)
mp.register_event("shutdown",    cleanup)

mp.register_script_message("toggle_landscape_mode", toggle_landscape_mode)
mp.register_script_message("toggle_portrait_mode",  toggle_portrait_mode)
mp.register_script_message("next_landscape",        next_video_handler)
mp.register_script_message("prev_landscape",        prev_video_handler)
mp.register_script_message("next_portrait",         next_video_handler)
mp.register_script_message("prev_portrait",         prev_video_handler)

initialize()

-- | END: orientation_filter.lua
