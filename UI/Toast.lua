-- Forever Journey: a small banner for chapters, zone memories and run recaps.
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets
local Toast = FJ:NewModule("Toast")

local WIDTH, HEIGHT = 360, 64
local frame, hold
local queue, showing = {}, false

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    FJ.gdb.settings.toastPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function Build()
    frame = W.Frame(UIParent, WIDTH, HEIGHT, T.colors.bg, T.colors.border)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    local pos = FJ.gdb.settings.toastPos
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
    frame:Hide()

    frame.accent = frame:CreateTexture(nil, "ARTWORK")
    frame.accent:SetPoint("TOPLEFT")
    frame.accent:SetPoint("BOTTOMLEFT")
    frame.accent:SetWidth(3)
    W.SetColor(frame.accent, T.colors.gold)

    frame.icon = W.Icon(frame, 36)
    frame.icon:SetPoint("LEFT", 14, 0)
    frame.kicker = W.Text(frame, 10, "", T.colors.goldDim)
    frame.kicker:SetPoint("TOPLEFT", 60, -9)
    frame.kicker:SetPoint("RIGHT", -12, 0)
    frame.kicker:SetWordWrap(false)
    frame.title = W.Text(frame, 13, "", T.colors.text, "")
    frame.title:SetPoint("TOPLEFT", 60, -23)
    frame.title:SetPoint("RIGHT", -12, 0)
    frame.title:SetWordWrap(false)
    frame.sub = W.Text(frame, 10, "", T.colors.muted)
    frame.sub:SetPoint("TOPLEFT", 60, -41)
    frame.sub:SetPoint("RIGHT", -12, 0)
    frame.sub:SetWordWrap(false)

    frame.anim = frame:CreateAnimationGroup()
    local fadeIn = frame.anim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.25)
    fadeIn:SetOrder(1)
    hold = frame.anim:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(4)
    hold:SetOrder(2)
    local fadeOut = frame.anim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.6)
    fadeOut:SetOrder(3)
    frame.anim:SetScript("OnFinished", function()
        frame:Hide()
        showing = false
        Toast:Next()
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and frame.anim:IsPlaying() then
            frame.anim:Stop()
            frame:Hide()
            showing = false
            Toast:Next()
        end
    end)
end

-- opts: kicker, title, text, icon, color (hex "ffrrggbb"), duration, sound (false to mute, or SOUNDKIT key)
function Toast:Show(opts)
    if not (FJ.gdb and FJ.gdb.settings.toasts) or not opts or not opts.title then return end
    queue[#queue + 1] = opts
    if #queue > 5 then table.remove(queue, 1) end
    if not showing then self:Next() end
end

function Toast:Next()
    local opts = table.remove(queue, 1)
    if not opts then return end
    if not frame then Build() end
    showing = true
    frame.kicker:SetText(opts.kicker or "NEW CHAPTER")
    frame.title:SetText(opts.title or "")
    frame.sub:SetText(opts.text or "")
    frame.icon:SetTexture(opts.icon or T.icons.journey)
    W.SetColor(frame.accent, opts.color and W.HexToRGB(opts.color) or T.colors.gold)
    hold:SetDuration(opts.duration or 4)
    frame:SetAlpha(0)
    frame:Show()
    frame.anim:Play()
    if opts.sound ~= false then
        FJ.API.PlaySound(opts.sound or "IG_QUEST_LIST_COMPLETE", 878)
    end
end

function Toast:Test()
    self:Show({ kicker = "NEW CHAPTER", title = "This is what a chapter looks like", text = "Drag me to where you want banners to appear.", icon = T.icons.journey })
end
