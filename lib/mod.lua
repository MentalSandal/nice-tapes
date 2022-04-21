local mod = require 'core/mods'
local custom_tape = require 'core/menu'
local textentry = require 'textentry'

local menu = {"include date:", "include bpm: ", "include script name:", "set prefix (K3): ", "preview: (E3 to scroll)", "preview: "}
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

function get_tapename()
  
  local _today = date_option == 1 and "_" .. today or ""
  local _script = script_option == 1 and script ~= nil and "_" .. script or ""
  local _tempo = bpm_option == 1 and "_" .. tempo .. "_bpm" or ""
  -- local _extension = bpm_option == 1 and "_bpm_####.wav" or "_####.wav"
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
  -- print("ran get_tapename from hook register")
  
  -- local _today = date_option == 1 and "_" .. today or ""
  -- local _script = script_option == 1 and script ~= nil and "_" .. script or ""
  -- local _tempo = bpm_option == 1 and "_" .. tempo .. "_bpm" or ""
  -- -- local _extension = bpm_option == 1 and "_bpm_####.wav" or "_####.wav"
  -- local _extension = "_####.wav"
  -- preview_name = prefix .. _today .. _script .. _tempo .. _extension
  -- tapename = prefix .. _today .. _script .. _tempo
  
  if not util.file_exists(_path.data.."norns-tape-mod") then
    os.execute("mkdir -p ".._path.data.."norns-tape-mod/")
    print("created data folder in ".. _path.data.."norns-tape-mod/")
  else
    print("found data folder ".. _path.data.."norns-tape-mod/")
  end
  local user_preset = tab.load(_path.data.."norns-tape-mod/tape_naming.txt")
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
  script = string.gsub(norns.state.script, ".lua", "")
  script = script:match("[^/]+$")
  -- print("script: ".. script)
  -- tweak global environment here ahead of the script `init()` function being called
end)

local function edit_prefix(txt)
  prefix = txt or prefix
  -- prefix_length = screen.text_extents(prefix)
  prefix_length = px_length(prefix)
  local modconfig = {
    ["prefix"] = prefix, 
    ["creation"] = date_option,
    ["bpm"] = bpm_option,
    ["script"] = script_option
  }
  tab.save(modconfig, _path.data.."norns-tape-mod/tape_naming.txt")
  mod.menu.redraw()
  return prefix, prefix_length
end
_menu.m["TAPE"] = dofile('home/we/dust/code/norns-tape-mod/lib/tape_inject.lua')
--
-- [optional] menu: extending the menu system is done by creating a table with
-- all the required menu functions defined.
--

local m = {}

-- m.key = function(n, z)
--   if n == 2 and z == 1 then
--     -- return to the mod selection menu
--     mod.menu.exit()
--   elseif n == 3 and z == 1 then
--     textentry.enter(edit_prefix, prefix, "prefix: ")
--   end
-- end

-- m.enc = function(n, d)

--   if n == 2 then state.x = state.x + d
--   elseif n == 3 then state.y = state.y + d end
--   -- tell the menu system to redraw, which in turn calls the mod's menu redraw
--   -- function
--   mod.menu.redraw()
-- end

m.enc = function(n, d)
  
  if n == 2 then
    position = util.clamp(position + d, 1, 5)
    switch = 1
  elseif n == 3 and position < 5 then
    switch = util.clamp(switch + d, 0, 1)
  elseif n == 3 and position == 5 then
    if name_length >= 124 then
      local extra = name_length - 124
      scroll = util.clamp(scroll - d, 0, extra)
    else
      scroll = 0
    end
  end
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
  if n == 2 and z == 1 then
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

-- m.textentry = function()
--   -- define prefix entry
--   textentry.enter(callback, prefix, "prefix")
-- end

local function return_prefix(txt)
  prefix = txt
  prefix_length = screen.text_extents(prefix)
  mod.menu.redraw()
  return prefix, prefix_length
end

m.redraw = function()

  -- print(prefix_length)
  screen.clear()
  
  local l_margin = 2
  local t_margin = 10
  local o_margin = 126
  
  get_tapename()
  
  screen.level(3)
  screen.move(64, t_margin)
  screen.text_center("~ nice-tapes ~")
  -- date
  screen.move(l_margin, t_margin + 9)
  if position == 1 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.text(menu[1])
  -- screen.move(100 + m.l_justify(date_option, 5), t_margin)
  screen.move(o_margin, t_margin + 9)
  screen.text_right(choice[date_option])
    
  -- bpm
  if position == 2 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.move(l_margin, t_margin + 16)
  screen.text(menu[2])
  screen.move(o_margin, t_margin + 16)
  screen.text_right(choice[bpm_option])
  
  -- script name
  if position == 3 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.move(l_margin, t_margin + 23)
  screen.text(menu[3])
  screen.move(o_margin, t_margin + 23)
  screen.text_right(choice[script_option])
  
  -- prefix
  if position == 4 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.move(l_margin, t_margin + 31)
  screen.text(menu[4])
  screen.move(o_margin, t_margin + 31)
  screen.text_right(prefix)
  
  
  -- preview
  -- local _today = date_option == 1 and "_" .. today or ""
  -- local _script = script_option == 1 and script ~= nil and "_" .. script or ""
  -- local _tempo = bpm_option == 1 and "_" .. tempo or ""
  -- local _extension = bpm_option == 1 and "_bpm_####.wav" or "_####.wav"
  -- local preview_name = prefix .. _today .. _script .. _tempo .. _extension
  -- tapename = prefix .. _today .. _script .. _tempo
  
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
    

  -- margin
  screen.level(0)
  screen.aa(1)
  screen.line_width(4)
  screen.rect(0,0,128,64)
  screen.stroke()
  screen.update()
end

m.init = function() end -- on menu entry, ie, if you wanted to start timers
m.deinit = function() end -- on menu exit

-- register the mod menu
--
-- NOTE: `mod.this_name` is a convienence variable which will be set to the name
-- of the mod which is being loaded. in order for the menu to work it must be
-- registered with a name which matches the name of the mod in the dust folder.
--
mod.menu.register(mod.this_name, m)


--
-- [optional] returning a value from the module allows the mod to provide
-- library functionality to scripts via the normal lua `require` function.
--
-- NOTE: it is important for scripts to use `require` to load mod functionality
-- instead of the norns specific `include` function. using `require` ensures
-- that only one copy of the mod is loaded. if a script were to use `include`
-- new copies of the menu, hook functions, and state would be loaded replacing
-- the previous registered functions/menu each time a script was run.
--
-- here we provide a single function which allows a script to get the mod's
-- state table. using this in a script would look like:
--
-- local mod = require 'name_of_mod/lib/mod'
-- local the_state = mod.get_state()
--
-- local api = {}

-- api.get_state = function()
--   return state
-- end

-- return api

local api = {}

api.return_tapename = function()
  local t = get_tapename()
  return t
end

return api