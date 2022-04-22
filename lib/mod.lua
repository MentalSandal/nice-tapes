--
-- nice-tapes is based on the excellent norns-example-mod
--
local mod = require 'core/mods'
local custom_tape = require 'core/menu'
local textentry = require 'textentry'

local menu = {"include date:",
              "include bpm: ",
              "include script name:",
              "set prefix (K3): ",
              "preview: (E3 to scroll)",
               "preview: "
             }
local choice = {"yes", "no"}
local position = 1
local switch = 1
local scroll = 0
local date_option = 1
local bpm_option = 1
local script_option = 1
local prefix_entry = false
local state = {}
local tempo = tostring(clock.get_tempo()):gsub("%.", "_")
local today = util.os_capture("date +%y%m%d") or "datenotfound"
local script = nil
local prefix = "norns"
local prefix_length = 0
local name_length = 0
local preview_name = nil


local function px_length(txt) -- return length of txt in pixels
  return screen.text_extents(txt)
end

function get_tapename() -- returns the current name
                        -- based on the user's naming convention
                        -- this function is global because it's also called by
                        -- tape_inject.lua
  
  local _today = date_option == 1 and "_" .. today or ""
  local _script = script_option == 1 and script ~= nil and "_" .. script or ""
  local _tempo = bpm_option == 1 and "_" .. tempo .. "_bpm" or ""
  local _extension = ".wav"
  local prefix = prefix ~= '' and "_" .. prefix or ""
  local _index = "####"
  
  tapename = prefix .. _today .. _script .. _tempo
  preview_name = _index .. tapename .. _extension
  
  return preview_name, tapename
end
  

mod.hook.register("system_post_startup", "my startup hacks", function()
  
  state.system_post_startup = true
  
  get_tapename()

  -- create a data folder if it doesn't exist
  if not util.file_exists(_path.data.."nice-tapes") then
    os.execute("mkdir -p ".._path.data.."nice-tapes/")
    print("created data folder in ".. _path.data.."nice-tapes/")
  else
    print("found data folder ".. _path.data.."nice-tapes/")
  end

  -- load user presets from data folder
  local user_preset = tab.load(_path.data.."nice-tapes/tape_naming.txt")

  if user_preset ~= nil then
    prefix = user_preset.prefix or prefix
    date_option = user_preset.creation or date_option
    bpm_option = user_preset.bpm or bpm_option
    script_option = user_preset.script or script_option
    prefix_length = px_length(prefix)
    return prefix_length
  end
end)

mod.hook.register("script_pre_init", "my init hacks", function()

  get_tapename()

  -- get the name is the script being loaded
  script = string.gsub(norns.state.script, ".lua", "")
  script = script:match("[^/]+$")
end)

local function edit_prefix(txt) -- callback for textentry
                                -- saves the mod config
                                -- return prefix name and length
  prefix = txt or prefix
  prefix_length = px_length(prefix)
  local modconfig = {
    ["prefix"] = prefix, 
    ["creation"] = date_option,
    ["bpm"] = bpm_option,
    ["script"] = script_option
  }
  tab.save(modconfig, _path.data.."nice-tapes/tape_naming.txt")
  mod.menu.redraw()
  return prefix, prefix_length
end

-- supercedes norns tape.lua file
_menu.m["TAPE"] = dofile('home/we/dust/code/nice-tapes/lib/tape_inject.lua')

local m = {}

m.enc = function(n, d)
  
  if n == 2 then -- scroll through UI options 1 to 5
    position = util.clamp(position + d, 1, 5)
    switch = 1
  elseif n == 3 and position < 5 then -- yes/no switch
    switch = util.clamp(switch + d, 0, 1)
  elseif n == 3 and position == 5 then -- preview scroll
    if name_length >= 124 then
      local extra = name_length - 124
      scroll = util.clamp(scroll - d, 0, extra)
    else
      scroll = 0
    end
  end
  -- yes/no switch for each option
  if position == 1 and n == 3 then
    date_option = 1 + switch
  elseif position == 2 and n == 3 then
    bpm_option = 1 + switch
  elseif position == 3 and n == 3 then
    script_option = 1 + switch
  end
  if position <= 3 and n == 3 then
    scroll = 0
  end
    
  mod.menu.redraw()
  return position, switch, scroll
end

m.key = function(n, z)
  if n == 2 and z == 1 or n == 1 and z == 1 then
    -- return to the mod selection menu
    mod.menu.exit()
  elseif n == 3 and z == 1 then
    prefix_entry = true
    if position == 4 then
      textentry.enter(edit_prefix, prefix, "prefix: ")
      scroll = 0
    end
  else 
    prefix_entry = false
  end
  mod.menu.redraw()
  return edit_prefix
end

-- function below is probs useless

-- local function return_prefix(txt)
--   prefix = txt
--   prefix_length = screen.text_extents(prefix)
--   mod.menu.redraw()
--   return prefix, prefix_length
-- end

m.redraw = function()

  -- print(prefix_length)
  screen.clear()
  
  -- safe-margins
  local l_margin = 2 
  local t_margin = 10
  -- spacing value for options
  local o_margin = 126
  
  get_tapename()
  
  screen.level(3)
  screen.move(64, t_margin)
  screen.text_center("~ nice-tapes ~")

  -- date option
  screen.move(l_margin, t_margin + 9)
  if position == 1 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.text(menu[1])
  screen.move(o_margin, t_margin + 9)
  screen.text_right(choice[date_option])
    
  -- bpm option
  if position == 2 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.move(l_margin, t_margin + 16)
  screen.text(menu[2])
  screen.move(o_margin, t_margin + 16)
  screen.text_right(choice[bpm_option])
  
  -- script name option
  if position == 3 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.move(l_margin, t_margin + 23)
  screen.text(menu[3])
  screen.move(o_margin, t_margin + 23)
  screen.text_right(choice[script_option])
  
  -- prefix option
  if position == 4 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.move(l_margin, t_margin + 31)
  screen.text(menu[4])
  screen.move(o_margin, t_margin + 31)
  screen.text_right(prefix)
  
  name_length = px_length(preview_name)
  
  -- resetting scroll if name short enough
  if position <= 3 and name_length <= 124 then 
    scroll = 0
  end
  screen.level(3)
  screen.move(64, 51)
  if name_length >= 124 then
    screen.text_center(menu[5])
  else
    screen.text_center(menu[6])
  end
  screen.move(l_margin - scroll ,59)
  if position == 5 then
    screen.level(15)
  else
    screen.level(3)
  end
  if name_length >= 124 then
    screen.text(preview_name)
  else
    screen.move(64, 59)
    screen.text_center(preview_name)
  end
    
  -- black matte
  screen.level(0)
  screen.aa(1)
  screen.line_width(4)
  screen.rect(0,0,128,64)
  screen.stroke()
  screen.update()
end

m.init = function() end -- on menu entry, ie, if you wanted to start timers
m.deinit = function() end -- on menu exit

mod.menu.register(mod.this_name, m)

local api = {}

api.return_tapename = function()
  local t = get_tapename()
  return t
end

return api