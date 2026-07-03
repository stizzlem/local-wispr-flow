-- hud.lua — small floating status pill for the dictation tool.
-- Replaces the big hs.alert banners with a compact, always-on-top
-- rounded pill (bottom-center of the main screen) that shows:
--   IDLE            -> hidden
--   recording       -> red dot + live mm:ss + animated waveform bars
--   transcribing    -> spinner-style pulsing dot + "Transcribing..."
--   done / error    -> brief flash, then auto-hides
--
-- Pure hs.canvas, no webview — stays lightweight and dependency-free.

local M = {}

local WIDTH, HEIGHT = 220, 44
local BAR_COUNT = 24
local canvas = nil
local animTimer = nil
local hideTimer = nil
local phase = 0            -- drives the waveform animation
local barHeights = {}
for i = 1, BAR_COUNT do barHeights[i] = 0.15 end

local function screenFrame()
  local f = hs.screen.mainScreen():frame()
  local x = f.x + (f.w - WIDTH) / 2
  local y = f.y + f.h - HEIGHT - 90   -- sits just above the dock
  return hs.geometry.rect(x, y, WIDTH, HEIGHT)
end

local function ensureCanvas()
  if canvas then return end
  canvas = hs.canvas.new(screenFrame())
  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:behavior({ "canJoinAllSpaces", "stationary" })
end

-- Build the full element list each frame: background pill, dot, label, bars.
local function render(mode, label)
  ensureCanvas()
  local elements = {
    {
      type = "rectangle",
      roundedRectRadii = { xRadius = HEIGHT / 2, yRadius = HEIGHT / 2 },
      frame = { x = 0, y = 0, w = WIDTH, h = HEIGHT },
      fillColor = { red = 0.09, green = 0.09, blue = 0.10, alpha = 0.92 },
      strokeColor = { white = 1, alpha = 0.08 },
      strokeWidth = 1,
      action = "strokeAndFill",
    },
  }

  local dotColor
  if mode == "rec" then
    dotColor = { red = 0.95, green = 0.25, blue = 0.25, alpha = 1 }
  elseif mode == "busy" then
    dotColor = { red = 0.95, green = 0.75, blue = 0.15, alpha = 1 }
  else
    dotColor = { red = 0.3, green = 0.85, blue = 0.4, alpha = 1 }
  end

  table.insert(elements, {
    type = "circle",
    center = { x = 18, y = HEIGHT / 2 },
    radius = 5,
    fillColor = dotColor,
    action = "fill",
  })

  local labelW = (mode == "rec") and 66 or (WIDTH - 32 - 14)
  table.insert(elements, {
    type = "text",
    text = label,
    textFont = "Menlo",
    textSize = 12,
    textColor = { white = 1, alpha = 0.95 },
    textAlignment = "left",
    frame = { x = 32, y = HEIGHT / 2 - 9, w = labelW, h = 18 },
  })

  if mode == "rec" then
    -- Waveform bars fill the right two-thirds of the pill.
    local barsX0 = 108
    local barsW = WIDTH - barsX0 - 14
    local gap = 3
    local barW = (barsW - gap * (BAR_COUNT - 1)) / BAR_COUNT
    for i = 1, BAR_COUNT do
      local h = math.max(2, barHeights[i] * (HEIGHT - 16))
      table.insert(elements, {
        type = "rectangle",
        frame = {
          x = barsX0 + (i - 1) * (barW + gap),
          y = (HEIGHT - h) / 2,
          w = barW,
          h = h,
        },
        fillColor = { red = 0.4, green = 0.75, blue = 1, alpha = 0.9 },
        roundedRectRadii = { xRadius = barW / 2, yRadius = barW / 2 },
        action = "fill",
      })
    end
  end

  -- hs.canvas has no bulk "set elements" method — assign by index, and
  -- trim any leftover elements from a previous frame that had more shapes
  -- (e.g. switching from "rec" mode with bars down to "busy" with none).
  for i, el in ipairs(elements) do
    canvas[i] = el
  end
  -- Nil trailing leftovers back-to-front — canvas only allows removing
  -- the last element at a time, not an arbitrary middle index.
  for i = canvas:elementCount(), #elements + 1, -1 do
    canvas[i] = nil
  end
end

-- Randomized-but-smooth bar motion: each tick nudges every bar toward a
-- new random target so the waveform looks organic without real audio
-- amplitude data.
local barTargets = {}
local function stepWaveform()
  for i = 1, BAR_COUNT do
    barTargets[i] = barTargets[i] or 0.2
    if math.random() < 0.35 then
      barTargets[i] = 0.15 + math.random() * 0.85
    end
    barHeights[i] = barHeights[i] + (barTargets[i] - barHeights[i]) * 0.5
  end
end

local recSecs = 0

local function formatSecs(secs)
  return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

function M.showRecording(secs)
  if hideTimer then hideTimer:stop(); hideTimer = nil end
  ensureCanvas()
  recSecs = secs
  stepWaveform()
  render("rec", formatSecs(recSecs))
  canvas:show()
  if not animTimer then
    animTimer = hs.timer.doEvery(0.08, function()
      if canvas then
        stepWaveform()
        render("rec", formatSecs(recSecs))
      end
    end)
  end
end

function M.showBusy(text)
  if animTimer then animTimer:stop(); animTimer = nil end
  ensureCanvas()
  render("busy", text or "...")
  canvas:show()
end

function M.flash(text, secs)
  if animTimer then animTimer:stop(); animTimer = nil end
  ensureCanvas()
  render("idle", text)
  canvas:show()
  if hideTimer then hideTimer:stop() end
  hideTimer = hs.timer.doAfter(secs or 1.2, function() M.hide() end)
end

function M.hide()
  if animTimer then animTimer:stop(); animTimer = nil end
  if hideTimer then hideTimer:stop(); hideTimer = nil end
  if canvas then canvas:hide() end
end

return M
