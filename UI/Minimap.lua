-- Forever Journey: minimap button (no library dependency).
local ADDON_NAME, FJ = ...
local M = FJ:NewModule("Minimap")

local button

local function Settings()
    return FJ.gdb.settings.minimap
end

local function UpdatePosition()
    if not button then return end
    local angle = math.rad(Settings().angle or 220)
    local x, y = math.cos(angle), math.sin(angle)
    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local radius = (Minimap:GetWidth() / 2) + 5
    if shape == "SQUARE" then
        x = FJ.Clamp(x * radius * 1.42, -radius, radius)
        y = FJ.Clamp(y * radius * 1.42, -radius, radius)
    else
        x, y = x * radius, y * radius
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    Settings().angle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Forever Journey", 1, 0.82, 0.2)
    local lvl = UnitLevel("player") or 1
    GameTooltip:AddDoubleLine("Level", tostring(lvl), 0.85, 0.85, 0.85, 1, 1, 1)
    GameTooltip:AddDoubleLine("Played", FJ.FormatDuration(FJ.Session:GetPlayed()), 0.85, 0.85, 0.85, 1, 1, 1)
    local s = FJ.Stats:SessionNow()
    if s then
        GameTooltip:AddDoubleLine("This session", FJ.FormatDuration(s.duration), 0.85, 0.85, 0.85, 1, 1, 1)
        if s.xp > 0 then
            GameTooltip:AddDoubleLine("XP per hour", FJ.FormatNumber(s.xph), 0.85, 0.85, 0.85, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open your journey", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Right-click: Forever Wrapped", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Drag to move", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function M:Create()
    if button then return button end
    button = CreateFrame("Button", "ForeverJourneyMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(FJ.Theme.icons.dashboard)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            FJ.UI:Toggle("wrapped")
        else
            FJ.UI:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
    if Settings().hide then button:Hide() end
    return button
end

function M:SetShown(show)
    Settings().hide = not show
    if button then
        if show then button:Show() else button:Hide() end
    end
end

function M:OnEnable()
    self:Create()
end
