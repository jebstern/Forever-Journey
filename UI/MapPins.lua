-- Forever Journey: World Map pins. Tombstones where you died, and footprints per zone on the
-- continent and world maps sized by time spent. Uses the map's own data provider system.
local ADDON_NAME, FJ = ...
local MapPins = FJ:NewModule("MapPins")

if not (MapCanvasPinMixin and MapCanvasDataProviderMixin and CreateFromMixins) then
    MapPins.unavailable = true
    return
end

local DEATH_TEMPLATE = "ForeverJourneyDeathPinTemplate"
local FOOT_TEMPLATE = "ForeverJourneyFootprintPinTemplate"

---------------------------------------------------------------------------
-- Death pin
---------------------------------------------------------------------------
ForeverJourneyDeathPinMixin = CreateFromMixins(MapCanvasPinMixin)

function ForeverJourneyDeathPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.2)
    if self.UseFrameLevelType then pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_AREA_POI") end
end

function ForeverJourneyDeathPinMixin:OnAcquired(death)
    self.death = death
    self:SetPosition(death.x, death.y)
end

function ForeverJourneyDeathPinMixin:OnMouseEnter()
    local d = self.death
    if not d then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("You died here", 1, 0.82, 0.2)
    GameTooltip:AddLine(FJ.FormatDateTime(d.t) .. "  -  level " .. tostring(d.l or 0), 0.9, 0.9, 0.9)
    if d.k then GameTooltip:AddLine("Killed by " .. d.k, 1, 0.45, 0.45) end
    GameTooltip:Show()
end

function ForeverJourneyDeathPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Footprint pin (one per zone with recorded time, on continent/world maps)
---------------------------------------------------------------------------
ForeverJourneyFootprintPinMixin = CreateFromMixins(MapCanvasPinMixin)

function ForeverJourneyFootprintPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.0)
    if self.UseFrameLevelType then pcall(self.UseFrameLevelType, self, "PIN_FRAME_LEVEL_AREA_POI") end
end

function ForeverJourneyFootprintPinMixin:OnAcquired(info)
    self.info = info
    self:SetPosition(info.x, info.y)
    local size = 10 + 22 * (info.share or 0)
    self:SetSize(size, size)
    local r, g, b = FJ.ClassColor()
    self.Icon:SetVertexColor(r, g, b, 0.35 + 0.55 * (info.share or 0))
end

function ForeverJourneyFootprintPinMixin:OnMouseEnter()
    local info = self.info
    if not info then return end
    local z = info.zone
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(z.name or "?", 1, 0.82, 0.2)
    GameTooltip:AddDoubleLine("Time spent", FJ.FormatDuration(z.time or 0), 0.85, 0.85, 0.85, 1, 1, 1)
    GameTooltip:AddDoubleLine("First visit", FJ.FormatDate(z.first) .. " at level " .. tostring(z.lvl or 0), 0.85, 0.85, 0.85, 1, 1, 1)
    local pct, total, done = FJ.ZoneQuests:Percent(info.mapID)
    if pct then
        GameTooltip:AddDoubleLine("Quests", format("%d of %d (%d%%)", done, total, pct * 100), 0.85, 0.85, 0.85, 1, 1, 1)
    elseif (z.q or 0) > 0 then
        GameTooltip:AddDoubleLine("Quests handed in", tostring(z.q), 0.85, 0.85, 0.85, 1, 1, 1)
    end
    local explored, totalAreas = FJ.Zones:Exploration(info.mapID)
    if explored and totalAreas and totalAreas > 0 then
        GameTooltip:AddDoubleLine("Map uncovered", format("%d of %d areas", explored, totalAreas), 0.85, 0.85, 0.85, 1, 1, 1)
    end
    if (z.d or 0) > 0 then GameTooltip:AddDoubleLine("Deaths", tostring(z.d), 0.85, 0.85, 0.85, 1, 0.5, 0.5) end
    GameTooltip:Show()
end

function ForeverJourneyFootprintPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Data providers
---------------------------------------------------------------------------
local DeathProvider = CreateFromMixins(MapCanvasDataProviderMixin)

function DeathProvider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(DEATH_TEMPLATE)
end

function DeathProvider:RefreshAllData()
    self:RemoveAllData()
    if not (FJ.db and FJ.gdb.settings.mapDeaths) then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    if not mapID then return end
    for _, d in ipairs(FJ.db.deaths) do
        if d.m == mapID and d.x and d.y then
            map:AcquirePin(DEATH_TEMPLATE, d)
        end
    end
end

local FootprintProvider = CreateFromMixins(MapCanvasDataProviderMixin)
local TYPE_WORLD = (Enum and Enum.UIMapType and Enum.UIMapType.World) or 1
local TYPE_CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
local TYPE_ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

function FootprintProvider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(FOOT_TEMPLATE)
end

function FootprintProvider:RefreshAllData()
    self:RemoveAllData()
    if not (FJ.db and FJ.gdb.settings.mapFootprints) then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local info = mapID and FJ.API.MapInfo(mapID)
    if not info or (info.mapType ~= TYPE_CONTINENT and info.mapType ~= TYPE_WORLD) then return end
    if not (C_Map.GetMapChildrenInfo and C_Map.GetMapRectOnMap) then return end
    local ok, children = pcall(C_Map.GetMapChildrenInfo, mapID, TYPE_ZONE, info.mapType == TYPE_WORLD)
    if not ok or type(children) ~= "table" then return end
    local entries, maxTime = {}, 0
    for _, child in ipairs(children) do
        local z = FJ.db.zones[child.mapID]
        if z and (z.time or 0) > 0 then
            local okR, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, child.mapID, mapID)
            if okR and minX and maxX and minY and maxY then
                entries[#entries + 1] = { mapID = child.mapID, zone = z, x = (minX + maxX) / 2, y = (minY + maxY) / 2 }
                if z.time > maxTime then maxTime = z.time end
            end
        end
    end
    for _, e in ipairs(entries) do
        e.share = maxTime > 0 and (e.zone.time / maxTime) or 0
        map:AcquirePin(FOOT_TEMPLATE, e)
    end
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------
local deathProvider, footProvider

function MapPins:Register()
    if deathProvider then return true end
    if not (WorldMapFrame and WorldMapFrame.AddDataProvider) then return false end
    deathProvider = CreateFromMixins(DeathProvider)
    footProvider = CreateFromMixins(FootprintProvider)
    WorldMapFrame:AddDataProvider(deathProvider)
    WorldMapFrame:AddDataProvider(footProvider)
    return true
end

function MapPins:Refresh()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if deathProvider then pcall(deathProvider.RefreshAllData, deathProvider) end
        if footProvider then pcall(footProvider.RefreshAllData, footProvider) end
    end
end

function MapPins:OnLogin()
    if not self:Register() then
        FJ:RegisterEvent("ADDON_LOADED", function(_, name)
            if name == "Blizzard_WorldMap" then MapPins:Register() end
        end)
    end
    FJ:RegisterMessage("FJ_DATA_CHANGED", function() MapPins:Refresh() end)
end
