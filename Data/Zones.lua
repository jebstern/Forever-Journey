-- Forever Journey: static zone hints. Zone *lists* always come from the map API at runtime;
-- this file only adds level ranges (for suggestions) and which maps are capital cities.
-- Keys are Classic UiMapIDs. Unknown zones (new Forever content) simply have no hint.
local ADDON_NAME, FJ = ...
FJ.Data = FJ.Data or {}

-- [uiMapID] = { minLevel, maxLevel, faction }  faction only for strongly one-sided zones
FJ.Data.ZoneLevels = {
    -- Eastern Kingdoms
    [1429] = { 1, 10, "Alliance" },   -- Elwynn Forest
    [1426] = { 1, 10, "Alliance" },   -- Dun Morogh
    [1420] = { 1, 10, "Horde" },      -- Tirisfal Glades
    [1436] = { 10, 20, "Alliance" },  -- Westfall
    [1432] = { 10, 20, "Alliance" },  -- Loch Modan
    [1421] = { 10, 20, "Horde" },     -- Silverpine Forest
    [1433] = { 15, 25, "Alliance" },  -- Redridge Mountains
    [1431] = { 18, 30, "Alliance" },  -- Duskwood
    [1437] = { 20, 30, "Alliance" },  -- Wetlands
    [1424] = { 20, 30 },              -- Hillsbrad Foothills
    [1416] = { 30, 40 },              -- Alterac Mountains
    [1417] = { 30, 40 },              -- Arathi Highlands
    [1434] = { 30, 45 },              -- Stranglethorn Vale
    [1418] = { 35, 45 },              -- Badlands
    [1435] = { 35, 45 },              -- Swamp of Sorrows
    [1425] = { 40, 50 },              -- The Hinterlands
    [1427] = { 43, 50 },              -- Searing Gorge
    [1419] = { 45, 55 },              -- Blasted Lands
    [1428] = { 50, 58 },              -- Burning Steppes
    [1422] = { 51, 58 },              -- Western Plaguelands
    [1423] = { 53, 60 },              -- Eastern Plaguelands
    [1430] = { 55, 60 },              -- Deadwind Pass
    -- Kalimdor
    [1411] = { 1, 10, "Horde" },      -- Durotar
    [1412] = { 1, 10, "Horde" },      -- Mulgore
    [1438] = { 1, 10, "Alliance" },   -- Teldrassil
    [1413] = { 10, 25, "Horde" },     -- The Barrens
    [1439] = { 10, 20, "Alliance" },  -- Darkshore
    [1442] = { 15, 27 },              -- Stonetalon Mountains
    [1440] = { 18, 30 },              -- Ashenvale
    [1441] = { 25, 35 },              -- Thousand Needles
    [1443] = { 30, 40 },              -- Desolace
    [1445] = { 35, 45 },              -- Dustwallow Marsh
    [1444] = { 40, 50 },              -- Feralas
    [1446] = { 40, 50 },              -- Tanaris
    [1447] = { 45, 55 },              -- Azshara
    [1448] = { 48, 55 },              -- Felwood
    [1449] = { 48, 55 },              -- Un'Goro Crater
    [1452] = { 55, 60 },              -- Winterspring
    [1451] = { 55, 60 },              -- Silithus
    -- Forever
    [2521] = { 1, 12 },               -- Zephras Isle
    [2548] = { 35, 45 },              -- Riverglades
    [2652] = { 35, 45 },              -- Shen'dralas
    [2482] = { 60, 60 },              -- Hyjal
}

-- Number of map exploration overlays per zone (uiMapID -> art ID and total). Used with
-- C_MapExplorationInfo.GetExploredMapTextures to compute an exploration percentage.
FJ.Data.Explore = {
    [1411] = { art = 2169, total = 11 }, -- Durotar
    [1412] = { art = 1200, total = 15 }, -- Mulgore
    [1413] = { art = 2181, total = 25 }, -- The Barrens
    [1416] = { art = 2133, total = 15 }, -- Alterac Mountains
    [1417] = { art = 2147, total = 16 }, -- Arathi Highlands
    [1418] = { art = 2159, total = 14 }, -- Badlands
    [1419] = { art = 2148, total = 9 },  -- Blasted Lands
    [1420] = { art = 2126, total = 17 }, -- Tirisfal Glades
    [1421] = { art = 2158, total = 15 }, -- Silverpine Forest
    [1422] = { art = 2164, total = 13 }, -- Western Plaguelands
    [1423] = { art = 2134, total = 23 }, -- Eastern Plaguelands
    [1424] = { art = 2154, total = 12 }, -- Hillsbrad Foothills
    [1425] = { art = 2162, total = 14 }, -- The Hinterlands
    [1426] = { art = 2151, total = 18 }, -- Dun Morogh
    [1427] = { art = 2157, total = 7 },  -- Searing Gorge
    [1428] = { art = 2149, total = 10 }, -- Burning Steppes
    [1429] = { art = 2153, total = 12 }, -- Elwynn Forest
    [1430] = { art = 2150, total = 3 },  -- Deadwind Pass
    [1431] = { art = 2152, total = 13 }, -- Duskwood
    [1432] = { art = 2156, total = 11 }, -- Loch Modan
    [1433] = { art = 2121, total = 11 }, -- Redridge Mountains
    [1434] = { art = 2160, total = 26 }, -- Stranglethorn Vale
    [1435] = { art = 2161, total = 11 }, -- Swamp of Sorrows
    [1436] = { art = 2165, total = 14 }, -- Westfall
    [1437] = { art = 2166, total = 15 }, -- Wetlands
    [1438] = { art = 2180, total = 11 }, -- Teldrassil
    [1439] = { art = 2171, total = 9 },  -- Darkshore
    [1440] = { art = 2167, total = 18 }, -- Ashenvale
    [1441] = { art = 2182, total = 9 },  -- Thousand Needles
    [1442] = { art = 2178, total = 11 }, -- Stonetalon Mountains
    [1443] = { art = 2130, total = 15 }, -- Desolace
    [1444] = { art = 2170, total = 16 }, -- Feralas
    [1445] = { art = 2173, total = 7 },  -- Dustwallow Marsh
    [1446] = { art = 2179, total = 20 }, -- Tanaris
    [1447] = { art = 2168, total = 19 }, -- Azshara
    [1448] = { art = 2174, total = 12 }, -- Felwood
    [1449] = { art = 2184, total = 7 },  -- Un'Goro Crater
    [1450] = { art = 2175, total = 1 },  -- Moonglade
    [1451] = { art = 2177, total = 7 },  -- Silithus
    [1452] = { art = 2185, total = 13 }, -- Winterspring
    [2482] = { art = 1997, total = 9 },  -- Hyjal
    [2521] = { art = 2031, total = 15 }, -- Zephras Isle
    [2548] = { art = 2054, total = 13 }, -- Riverglades
    [2652] = { art = 2132, total = 7 },  -- Shen'dralas
}

FJ.Data.Capitals = {
    [1453] = true, -- Stormwind City
    [1455] = true, -- Ironforge
    [1457] = true, -- Darnassus
    [1454] = true, -- Orgrimmar
    [1456] = true, -- Thunder Bluff
    [1458] = true, -- Undercity
}

-- Root map of the world and continent fallbacks when the API gives nothing.
FJ.Data.WorldMapID = 947
FJ.Data.CosmicMapID = 946
FJ.Data.ContinentFallback = { 1414, 1415 } -- Kalimdor, Eastern Kingdoms
