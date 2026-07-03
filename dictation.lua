-- dictation.lua — OS glue for the local dictation tool.
-- Double-tap Ctrl toggles: tap-tap once to record, tap-tap again to stop.
-- (Ctrl+Option+D still works as a fallback trigger.)
-- On stop: runs dictate.sh (whisper -> ollama) and pastes the result
-- at the cursor of whatever app is focused. Keep focus in your target
-- text field until the text lands.

require("hs.ipc")   -- lets the `hs` command-line tool talk to Hammerspoon

local DIR = os.getenv("HOME") .. "/Fable5-Projects/local-wispr-flow"
local WAV = DIR .. "/dictation.wav"
local FFMPEG = "/opt/homebrew/bin/ffmpeg"
local MIC_DEVICE = ":0"   -- MacBook Pro Microphone (ffmpeg avfoundation index)

local DOUBLE_TAP_SECS = 0.4   -- max gap between the two Ctrl taps

local recorder = nil      -- the running ffmpeg task, nil when idle
local recSecs = 0
local recTimer = nil

-- Menu-bar status: IDLE / REC m:ss / "..."
local menubar = hs.menubar.new()
local function setStatus(s) menubar:setTitle(s) end
setStatus("IDLE")

-- Paste text at the cursor: save clipboard, paste ours, restore theirs.
local function injectText(text)
  local previous = hs.pasteboard.getContents()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v")
  hs.timer.doAfter(0.4, function()
    if previous then hs.pasteboard.setContents(previous) end
  end)
end

-- Called when ffmpeg has exited and the WAV is finalized.
local function processRecording()
  setStatus("...")
  hs.task.new(DIR .. "/dictate.sh", function(exitCode, stdOut, stdErr)
    hs.alert.closeAll()
    setStatus("IDLE")
    if exitCode == 0 and stdOut:match("%S") then
      injectText(stdOut)
      hs.sound.getByName("Submarine"):play()
    elseif exitCode == 0 then
      hs.alert.show("No speech detected", 1.5)
    else
      hs.notify.new({title = "Dictation failed",
                     informativeText = stdErr or "unknown error"}):send()
    end
  end, {WAV}):start()
end

local function toggleDictation()
  if recorder == nil then
    -- START recording. The exit callback fires after we stop it below,
    -- once ffmpeg has flushed and closed the WAV file.
    recorder = hs.task.new(FFMPEG, function() processRecording() end,
      {"-hide_banner", "-loglevel", "error",
       "-f", "avfoundation", "-i", MIC_DEVICE,
       "-ar", "16000", "-ac", "1", "-y", WAV})
    recorder:start()
    hs.sound.getByName("Glass"):play()
    hs.alert.show("● Recording — double-tap Ctrl to stop", 2)
    recSecs = 0
    setStatus("REC 0:00")
    recTimer = hs.timer.doEvery(1, function()
      recSecs = recSecs + 1
      setStatus(string.format("REC %d:%02d", math.floor(recSecs / 60), recSecs % 60))
    end)
  else
    -- STOP: SIGINT tells ffmpeg to finalize the file and exit cleanly.
    if recTimer then recTimer:stop(); recTimer = nil end
    hs.alert.show("Transcribing… keep your cursor where the text should go", 90)
    recorder:interrupt()
    recorder = nil
  end
end

-- Double-tap Ctrl detector.
-- A "tap" only counts if Ctrl went down alone and came up without any
-- other key being pressed while it was held — so Ctrl+C, Ctrl+A etc.
-- never accidentally trigger dictation.
local lastTap = 0
local chorded = false
local types = hs.eventtap.event.types

ctrlWatcher = hs.eventtap.new({types.flagsChanged, types.keyDown}, function(e)
  if e:getType() == types.keyDown then
    chorded = true          -- Ctrl is being used as part of a shortcut
    return false
  end
  local f = e:getFlags()
  if f.ctrl and not (f.cmd or f.alt or f.shift or f.fn) then
    -- Ctrl just went down, alone
    chorded = false
    local now = hs.timer.secondsSinceEpoch()
    if (now - lastTap) < DOUBLE_TAP_SECS then
      lastTap = 0
      toggleDictation()
    else
      lastTap = now
    end
  elseif not f.ctrl then
    -- Ctrl released; a chorded press doesn't count as a tap
    if chorded then lastTap = 0 end
    chorded = false
  end
  return false              -- never swallow the event; typing is unaffected
end)
ctrlWatcher:start()

-- Fallback trigger, in case the event watcher is ever unavailable.
hs.hotkey.bind({"ctrl", "alt"}, "d", toggleDictation)
