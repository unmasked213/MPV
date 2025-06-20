-- | START: auto_cache.lua
-- |  PATH: C:\Program Files\mpv\mpv\scripts\auto_cache.lua

-- ➔ This script protects the HDD from overworking and speeds up the SSD for smooth playback.
--    D: drive  = HDD  = short cache (avoid wear)
--    Others    = SSD  = long cache  (run fast)

local utils = require 'mp.utils'
mp.add_hook("on_preloaded", 50, function ()
  local path = mp.get_property("path", "")
  if path:find("^%a:[/\\]") and path:sub(1,1):lower() == "d" then   -- D: = HDD in my build
    mp.set_property("cache-secs", "60")
  else
    mp.set_property("cache-secs", "360")
  end
end)

-- |   END: auto_cache.lua
