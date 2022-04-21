local fileselect = require 'fileselect'
local textentry = require 'textentry'
local util = require 'util'

-- mod stuff
-- local mod = require 'norns-tape-mod/lib/mod'
-- local tapename = mod.return_tapename()

local TAPE_MODE_PLAY = 1
local TAPE_MODE_REC = 2

local TAPE_PLAY_LOAD = 1
local TAPE_PLAY_PLAY = 2
local TAPE_PLAY_STOP = 3
local TAPE_PLAY_PAUSE = 4
local TAPE_REC_ARM = 1
local TAPE_REC_START = 2
local TAPE_REC_STOP = 3

local m = {
  mode = TAPE_MODE_PLAY,
  play = {
    sel = TAPE_PLAY_LOAD,
    status = TAPE_PLAY_STOP,
    file = nil,
    dir_prev = nil,
    pos_tick = 0
  },
  rec = {
    file = nil,
    sel = TAPE_REC_ARM,
    pos_tick = 0
  },
  diskfree = 0
}

-- metro for tape
local tape_play_counter = metro[33]
local tape_rec_counter = metro[34]

local DISK_RESERVE = 250
local function tape_diskfree()
  if norns.disk then
    m.diskfree = math.floor((norns.disk - DISK_RESERVE) / .192) -- seconds of 48k/16bit stereo disk free with reserve
  end
end

local function tape_exists(index)
  if type(index) == "number" then
    index = string.format("%04d",index)
  end
  -- local filename = _path.audio.."tape/"..index..".wav"
  -- local filename = _path.audio.."tape/" .. tapename .. "_" ..index..".wav"
  -- local filename = _path.audio.."tape/" .. get_tapename() .. "_" ..index..".wav"
  
  -- local filename = _path.audio.."tape/" .. index .. "_" .. get_tapename() .. ".wav"
  local tapename = select(2, get_tapename())
  -- local filename = _path.audio.."tape/" .. index .. get_tapename() .. ".wav"
  local filename = _path.audio.."tape/" .. index .. tapename .. ".wav"
  -- tab.print(util.scandir(_path.audio.."tape/"))
  -- print(util.file_exists(filename))
  if util.file_exists(filename) then
    -- return true
    return true, "file"
  end
  local tapes = util.scandir(_path.audio.."tape/")
  for i=1, #tapes do
    local t = string.gsub(tapes[i], ".wav", "")
    -- local t = t:sub(-4)
    local t = t:sub(1,4)
    if t == index then
      -- return true
      return true, "index"
    end
  end
  return util.file_exists(filename)
end

local function read_tape_index()
  local f = io.open(_path.tape..'index.txt','r')
  if f ~= nil then
    local a = tonumber(f:read("*line"))
    m.fileindex = a or 0
    f:close()
  else
    m.fileindex = 0
  end
  while select(1,tape_exists(m.fileindex)) do
    m.fileindex = m.fileindex+1
  end
end

local function write_tape_index_v(v)
  local f = io.open(_path.tape..'index.txt','w')
  if f == nil then
    os.execute("mkdir -p ".._path.tape)
    f = io.open(_path.tape..'index.txt','w')
  end
  if f == nil then
    print("WARNING: couldn't write index file, even after creating `tape/`")
  else
    f:write(tostring(v))
    f:close()
  end
end

local function update_tape_index()
  read_tape_index()
  write_tape_index_v(m.fileindex)
end

local function edit_filename(txt)
  if txt then
    m.rec.file = txt .. ".wav"
  else
    _menu.redraw()
    return
  end
  
  -- if txt == string.format("%04d",m.fileindex) then
  if txt:match("%d%d%d%d$") == string.format("%04d",m.fileindex) then
    update_tape_index()
  end
  audio.tape_record_open(_path.audio.."tape/"..m.rec.file)
  m.rec.sel = TAPE_REC_START
  m.rec.pos_tick = 0
  tape_rec_counter.time = 0.25
  tape_rec_counter.event = function()
    m.rec.pos_tick = m.rec.pos_tick + 0.25
    if m.rec.pos_tick > m.diskfree then
      print("out of space!")
      audio.tape_record_stop()
      tape_rec_counter:stop()
      m.rec.sel = TAPE_REC_ARM
    end
    if _menu.mode == true and _menu.page == "TAPE" then
      _menu.redraw()
    end
  end
  _menu.redraw()
end


m.key = function(n,z)
  if n==2 and z==1 then
    m.mode = (m.mode==1) and 2 or 1
    _menu.redraw()
  elseif n==3 and z==1 then
    if m.mode == TAPE_MODE_PLAY then
      if m.play.sel == TAPE_PLAY_LOAD then
        local playfile_callback = function(path)
          if path ~= "cancel" then
            audio.tape_play_open(path)
            m.play.file = path:match("[^/]*$")
            m.play.dir_prev = path:match("(.*/)")
            m.play.status = TAPE_PLAY_PAUSE
            m.play.sel = TAPE_PLAY_PLAY
            local _, samples, rate = _norns.sound_file_inspect(path)
            m.play.length = math.floor(samples / rate)
            m.play.length_text = util.s_to_hms(m.play.length)
            m.play.pos_tick = 0
            tape_play_counter.time = 0.25
            tape_play_counter.event = function()
              m.play.pos_tick = m.play.pos_tick + 0.25
              if m.play.pos_tick > m.play.length
                  and m.play.status == TAPE_PLAY_PLAY then
                if (samples / rate > 1 ) then
                  --loop to start..displayed play time will drift
                  m.play.pos_tick = m.play.pos_tick - m.play.length
                else
                  print("tape is over!")
                  audio.tape_play_stop()
                  tape_play_counter:stop()
                  m.play.file = nil
                  m.play.stats = TAPE_PLAY_STOP
                  m.play.sel = TAPE_PLAY_LOAD
                end
              end
              if _menu.mode == true and _menu.page == "TAPE" then
                _menu.redraw()
              end
            end
          else
            m.play.file = nil
          end
          _menu.redraw()
        end
        fileselect.enter(_path.audio, playfile_callback)
        if m.play.dir_prev ~= nil then
          fileselect.pushd(m.play.dir_prev)
        end
      elseif m.play.sel == TAPE_PLAY_PLAY then
        tape_play_counter:start()
        audio.tape_play_start()
        m.play.status = m.play.sel
        m.play.sel = TAPE_PLAY_STOP
        _menu.redraw()
      elseif m.play.sel == TAPE_PLAY_STOP then
        audio.tape_play_stop()
        tape_play_counter:stop()
        m.play.file = nil
        m.play.status = m.play.sel
        m.play.sel = TAPE_PLAY_LOAD
        _menu.redraw()
      end
    else -- REC CONTROLS
      if m.rec.sel == TAPE_REC_ARM then
        get_tapename() -- mod stuff
        tape_diskfree()
        read_tape_index()
        textentry.enter(
          edit_filename,
          -- tapename .. "_" .. string.format("%04d",m.fileindex), -- mod stuff
          -- string.format("%04d",m.fileindex) .. "_" .. tapename,
          string.format("%04d",m.fileindex) .. tapename,
          "custom tape filename:", -- mod stuff
          function(txt)
            if select(1,tape_exists(txt)) and select(2,tape_exists(txt)) == "file" then
              return "FILE EXISTS"
            end
          end)
      elseif m.rec.sel == TAPE_REC_START then
        tape_rec_counter:start()
        audio.tape_record_start()
        m.rec.sel = TAPE_REC_STOP
      elseif m.rec.sel == TAPE_REC_STOP then
        tape_rec_counter:stop()
        audio.tape_record_stop()
        m.rec.sel = TAPE_REC_ARM
        tape_diskfree()
      end
      _menu.redraw()
    end
  end
end

m.enc = norns.none

m.redraw = function()
  screen.clear()

  _menu.draw_panel()

  screen.move(128,10)
	screen.level(m.mode==TAPE_MODE_PLAY and 15 or 1)
	screen.text_right("PLAY")
  screen.level(2)
  screen.rect(0.5,13.5,127,2)
  screen.stroke()

  if m.play.file then
    screen.level(2)
    screen.move(0,10)
    screen.text(m.play.file)
    screen.move(0,24)
    screen.text(util.s_to_hms(math.floor(m.play.pos_tick)))
    screen.move(128,24)
    screen.text_right(m.play.length_text)
    screen.level(15)
    screen.move((m.play.pos_tick / m.play.length * 128),13.5)
    screen.line_rel(0,2)
    screen.stroke()
    if m.mode==TAPE_MODE_PLAY then
      screen.level(15)
      screen.move(64,24)
      if m.play.sel == TAPE_PLAY_PLAY then screen.text_center("START")
      elseif m.play.sel == TAPE_PLAY_STOP then screen.text_center("STOP") end
    end
  end

  screen.move(128,48)
  screen.level(m.mode==TAPE_MODE_REC and 15 or 1)
  screen.text_right("REC")
  screen.level(2)
  screen.rect(0.5,51.5,127,2)
  screen.stroke()
  if m.mode==TAPE_MODE_REC then
    screen.level(15)
    screen.move(64,62)
    if m.rec.sel == TAPE_REC_START then screen.text_center("START")
    elseif m.rec.sel == TAPE_REC_STOP then screen.text_center("STOP") end
  end
  if m.rec.sel ~= TAPE_REC_ARM then
    screen.level(1)
    screen.move(0,48)
    screen.text(m.rec.file)
    screen.level(2)
    screen.move(0,62)
    screen.text(util.s_to_hms(math.floor(m.rec.pos_tick)))
  end
  screen.level(2)
  screen.move(127,62)
  screen.text_right(util.s_to_hms(m.diskfree))
  screen.level(15)
  screen.move((m.rec.pos_tick / m.diskfree * 128),51.5)
  screen.line_rel(0,2)
  screen.stroke()

  screen.update()
end

m.init = function()
  tape_diskfree()
end
m.deinit = norns.none

return m