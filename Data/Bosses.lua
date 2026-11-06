-- Forever Journey: boss NPC IDs for dungeon/raid detection, and a dungeon catalogue
-- for suggestions. NPC IDs are stable across locales; names are English display fallbacks.
-- Forever's new dungeons use the NPC IDs published by the Dungeon Journal addon.
local ADDON_NAME, FJ = ...
FJ.Data = FJ.Data or {}

local B = {}
-- entry: { npcID, "Name", isFinal }
local function add(dungeon, list, isRaid)
    for i = 1, #list do
        local e = list[i]
        B[e[1]] = { n = e[2], d = dungeon, f = e[3] or nil, r = isRaid or nil }
    end
end

-- Forever dungeons
add("Hall of Thanes", { {261306, "Faldrim Anvilmar"}, {261311, "Plunder"}, {261319, "Durgen Dirgehammer", true} })
add("Ruins of Lordaeron", { {250660, "The Baron"}, {250483, "Witherfang"}, {250631, "The Abandoned"}, {256097, "Bjork"}, {256035, "Viktor the Vile"}, {250657, "Rath'mael", true} })
add("City of Dalaran", { {247126, "Atrexis the Grave Knight"}, {245999, "Arcane Anomaly"}, {246003, "Fel Ancient"}, {246017, "Unstable Sentinel"}, {246931, "Mana Wraith"}, {246008, "Mana Devourer"}, {247032, "Lyn the Ignored"}, {246020, "Shade of the Archmage", true} })

-- Classic dungeons
-- Forever's own statistics count Bazzalan as Ragefire Chasm's final boss; Taragaman also ends a run.
add("Ragefire Chasm", { {11517, "Oggleflint"}, {11518, "Jergosh the Invoker"}, {11519, "Bazzalan", true}, {11520, "Taragaman the Hungerer", true} })
add("Wailing Caverns", { {3653, "Kresh"}, {3669, "Lord Cobrahn"}, {3670, "Lord Pythas"}, {3671, "Lady Anacondra"}, {3673, "Lord Serpentis"}, {3674, "Skum"}, {5775, "Verdan the Everliving"}, {5912, "Deviate Faerie Dragon"}, {3654, "Mutanus the Devourer", true} })
add("The Deadmines", { {644, "Rhahk'Zor"}, {3586, "Miner Johnson"}, {642, "Sneed's Shredder"}, {643, "Sneed"}, {1763, "Gilnid"}, {646, "Mr. Smite"}, {647, "Captain Greenskin"}, {645, "Cookie"}, {639, "Edwin VanCleef", true} })
add("Shadowfang Keep", { {3914, "Rethilgore"}, {3886, "Razorclaw the Butcher"}, {3887, "Baron Silverlaine"}, {4278, "Commander Springvale"}, {4279, "Odo the Blindwatcher"}, {3872, "Deathsworn Captain"}, {4274, "Fenrus the Devourer"}, {3927, "Wolf Master Nandos"}, {4275, "Archmage Arugal", true} })
add("Blackfathom Deeps", { {4887, "Ghamoo-ra"}, {4831, "Lady Sarevess"}, {6243, "Gelihast"}, {12902, "Lorgus Jett"}, {12876, "Baron Aquanis"}, {4830, "Old Serra'kis"}, {4832, "Twilight Lord Kelris"}, {4829, "Aku'mai", true} })
add("The Stockade", { {1696, "Targorr the Dread"}, {1666, "Kam Deepfury"}, {1717, "Hamhock"}, {1663, "Dextren Ward"}, {1720, "Bruegal Ironknuckle"}, {1716, "Bazil Thredd", true} })
add("Gnomeregan", { {7361, "Grubbis"}, {7079, "Viscous Fallout"}, {6235, "Electrocutioner 6000"}, {6229, "Crowd Pummeler 9-60"}, {6231, "Techbot"}, {6228, "Dark Iron Ambassador"}, {7800, "Mekgineer Thermaplugg", true} })
add("Razorfen Kraul", { {6168, "Roogug"}, {4424, "Aggem Thorncurse"}, {4428, "Death Speaker Jargba"}, {4420, "Overlord Ramtusk"}, {4422, "Agathelos the Raging"}, {4425, "Blind Hunter"}, {4842, "Earthcaller Halmgar"}, {4421, "Charlga Razorflank", true} })
add("Scarlet Monastery: Graveyard", { {3983, "Interrogator Vishas"}, {6490, "Azshir the Sleepless"}, {6488, "Fallen Champion"}, {6489, "Ironspine"}, {4543, "Bloodmage Thalnos", true} })
add("Scarlet Monastery: Library", { {3974, "Houndmaster Loksey"}, {6487, "Arcanist Doan", true} })
add("Scarlet Monastery: Armory", { {3975, "Herod", true} })
add("Scarlet Monastery: Cathedral", { {3976, "Scarlet Commander Mograine"}, {3977, "High Inquisitor Whitemane", true}, {4542, "High Inquisitor Fairbanks"} })
add("Razorfen Downs", { {7355, "Tuten'kash"}, {7357, "Mordresh Fire Eye"}, {8567, "Glutton"}, {7354, "Ragglesnout"}, {7356, "Plaguemaw the Rotting"}, {7358, "Amnennar the Coldbringer", true} })
add("Uldaman", { {6910, "Revelosh"}, {6906, "Baelog"}, {7228, "Ironaya"}, {7023, "Obsidian Sentinel"}, {7206, "Ancient Stone Keeper"}, {7291, "Galgann Firehammer"}, {4854, "Grimlok"}, {2748, "Archaedas", true} })
add("Zul'Farrak", { {7273, "Gahz'rilla"}, {8127, "Antu'sul"}, {7272, "Theka the Martyr"}, {7271, "Witch Doctor Zum'rah"}, {7796, "Nekrum Gutchewer"}, {7275, "Shadowpriest Sezz'ziz"}, {7604, "Sergeant Bly"}, {7795, "Hydromancer Velratha"}, {7267, "Chief Ukorz Sandscalp", true} })
add("Maraudon", { {13282, "Noxxion"}, {12258, "Razorlash"}, {12236, "Lord Vyletongue"}, {12225, "Celebras the Cursed"}, {12203, "Landslide"}, {13601, "Tinkerer Gizlock"}, {13596, "Rotgrip"}, {12201, "Princess Theradras", true} })
add("Temple of Atal'Hakkar", { {8580, "Atal'alarion"}, {5721, "Dreamscythe"}, {5720, "Weaver"}, {5710, "Jammal'an the Prophet"}, {5711, "Ogom the Wretched"}, {5719, "Morphaz"}, {5722, "Hazzas"}, {8443, "Avatar of Hakkar"}, {5709, "Shade of Eranikus", true} })
add("Blackrock Depths", { {9018, "High Interrogator Gerstahn"}, {9025, "Lord Roccor"}, {9319, "Houndmaster Grebmar"}, {9024, "Pyromancer Loregrain"}, {9017, "Lord Incendius"}, {9041, "Warder Stilgiss"}, {9056, "Fineous Darkvire"}, {9016, "Bael'Gar"}, {9033, "General Angerforge"}, {8983, "Golem Lord Argelmach"}, {9537, "Hurley Blackbreath"}, {9502, "Phalanx"}, {9499, "Plugger Spazzring"}, {9156, "Ambassador Flamelash"}, {9938, "Magmus"}, {8929, "Princess Moira Bronzebeard"}, {9019, "Emperor Dagran Thaurissan", true} })
add("Lower Blackrock Spire", { {9196, "Highlord Omokk"}, {9236, "Shadow Hunter Vosh'gajin"}, {9237, "War Master Voone"}, {10596, "Mother Smolderweb"}, {10584, "Urok Doomhowl"}, {9736, "Quartermaster Zigris"}, {10220, "Halycon"}, {10268, "Gizrul the Slavener"}, {9568, "Overlord Wyrmthalak", true} })
add("Upper Blackrock Spire", { {9816, "Pyroguard Emberseer"}, {10264, "Solakar Flamewreath"}, {10429, "Warchief Rend Blackhand"}, {10339, "Gyth"}, {10430, "The Beast"}, {10363, "General Drakkisath", true} })
add("Dire Maul: East", { {14327, "Lethtendris"}, {13280, "Hydrospawn"}, {11490, "Zevrim Thornhoof"}, {14354, "Pusillin"}, {11492, "Alzzin the Wildshaper", true} })
add("Dire Maul: West", { {11489, "Tendris Warpwood"}, {11488, "Illyanna Ravenoak"}, {11487, "Magister Kalendris"}, {11496, "Immol'thar"}, {14506, "Lord Hel'nurath"}, {11486, "Prince Tortheldrin", true} })
add("Dire Maul: North", { {14326, "Guard Mol'dar"}, {14322, "Stomper Kreeg"}, {14321, "Guard Fengus"}, {14323, "Guard Slip'kik"}, {14325, "Captain Kromcrush"}, {14324, "Cho'Rush the Observer"}, {11501, "King Gordok", true} })
add("Stratholme", { {10435, "Magistrate Barthilas"}, {10439, "Ramstein the Gorger"}, {10436, "Baroness Anastari"}, {10437, "Nerub'enkan"}, {10438, "Maleki the Pallid"}, {10997, "Cannon Master Willey"}, {10811, "Archivist Galford"}, {10808, "Timmy the Cruel"}, {10516, "The Unforgiven"}, {10558, "Hearthsinger Forresten"}, {11143, "Postmaster Malown"}, {10813, "Balnazzar", true}, {10440, "Baron Rivendare", true} })
add("Scholomance", { {10506, "Kirtonos the Herald"}, {10503, "Jandice Barov"}, {11622, "Rattlegore"}, {10433, "Marduk Blackpool"}, {10432, "Vectus"}, {10508, "Ras Frostwhisper"}, {10505, "Instructor Malicia"}, {11261, "Doctor Theolen Krastinov"}, {10901, "Lorekeeper Polkelt"}, {10507, "The Ravenian"}, {10504, "Lord Alexei Barov"}, {10502, "Lady Illucia Barov"}, {1853, "Darkmaster Gandling", true} })

-- Raids
add("Onyxia's Lair", { {10184, "Onyxia", true} }, true)
add("Molten Core", { {12118, "Lucifron"}, {11982, "Magmadar"}, {12259, "Gehennas"}, {12057, "Garr"}, {12056, "Baron Geddon"}, {12264, "Shazzrah"}, {12098, "Sulfuron Harbinger"}, {11988, "Golemagg the Incinerator"}, {12018, "Majordomo Executus"}, {11502, "Ragnaros", true} }, true)
add("Blackwing Lair", { {12435, "Razorgore the Untamed"}, {13020, "Vaelastrasz the Corrupt"}, {12017, "Broodlord Lashlayer"}, {11983, "Firemaw"}, {14601, "Ebonroc"}, {11981, "Flamegor"}, {14020, "Chromaggus"}, {11583, "Nefarian", true} }, true)
add("Zul'Gurub", { {14507, "High Priest Venoxis"}, {14517, "High Priestess Jeklik"}, {14510, "High Priestess Mar'li"}, {14509, "High Priest Thekal"}, {14515, "High Priestess Arlokk"}, {11382, "Bloodlord Mandokir"}, {15114, "Gahz'ranka"}, {11380, "Jin'do the Hexxer"}, {15083, "Hazza'rah"}, {15082, "Gri'lek"}, {15084, "Renataki"}, {15085, "Wushoolay"}, {14834, "Hakkar", true} }, true)
add("Ruins of Ahn'Qiraj", { {15348, "Kurinnaxx"}, {15341, "General Rajaxx"}, {15340, "Moam"}, {15370, "Buru the Gorger"}, {15369, "Ayamiss the Hunter"}, {15339, "Ossirian the Unscarred", true} }, true)
add("Temple of Ahn'Qiraj", { {15263, "The Prophet Skeram"}, {15516, "Battleguard Sartura"}, {15510, "Fankriss the Unyielding"}, {15509, "Princess Huhuran"}, {15299, "Viscidus"}, {15275, "Emperor Vek'nilash"}, {15276, "Emperor Vek'lor"}, {15517, "Ouro"}, {15727, "C'Thun", true} }, true)
add("Naxxramas", { {15956, "Anub'Rekhan"}, {15953, "Grand Widow Faerlina"}, {15952, "Maexxna"}, {15954, "Noth the Plaguebringer"}, {15936, "Heigan the Unclean"}, {16011, "Loatheb"}, {16061, "Instructor Razuvious"}, {16060, "Gothik the Harvester"}, {16064, "Thane Korth'azz"}, {16065, "Lady Blaumeux"}, {16062, "Highlord Mograine"}, {16063, "Sir Zeliek"}, {16028, "Patchwerk"}, {15931, "Grobbulus"}, {15932, "Gluth"}, {15928, "Thaddius"}, {15989, "Sapphiron"}, {15990, "Kel'Thuzad", true} }, true)

FJ.Data.Bosses = B

-- Merges boss definitions from the Dungeon Journal addon when it is installed, so new
-- Forever dungeons it documents are recognised without an update here.
local merged = false
function FJ.Data.MergeExternalBosses()
    if merged then return end
    merged = true
    local ns = _G.ForeverDungeonJournal_NS
    local db = ns and ns.DB
    if type(db) ~= "table" then return end
    for dungeonName, d in pairs(db) do
        if type(d) == "table" and type(d.bosses) == "table" then
            for _, boss in ipairs(d.bosses) do
                local id = tonumber(boss.npcID)
                if id and not B[id] and type(boss.name) == "string" then
                    B[id] = { n = boss.name, d = tostring(dungeonName) }
                end
            end
        end
    end
end

-- English name -> npcID index, used as a fallback when only a name is available.
local byName
function FJ.Data.BossByName(name)
    if not byName then
        byName = {}
        for id, b in pairs(B) do byName[b.n] = id end
    end
    local id = byName[name]
    return id, id and B[id] or nil
end

-- Catalogue used by the "Next" page: { name, minLevel, maxLevel, faction, isRaid }
FJ.Data.Dungeons = {
    { "Ragefire Chasm", 13, 18, "Horde" },
    { "Hall of Thanes", 13, 20 },
    { "Ruins of Lordaeron", 15, 22 },
    -- Forever dungeons known only from the game's boss-kill statistics; level ranges unknown.
    { "Shaper's Terrace" },
    { "Alcaz Prison" },
    { "Barrow Deeps" },
    { "Hyjal Summit", 60, 60, nil, true },
    { "The Deadmines", 17, 26 },
    { "Wailing Caverns", 17, 24 },
    { "Shadowfang Keep", 22, 30 },
    { "The Stockade", 24, 32, "Alliance" },
    { "Blackfathom Deeps", 24, 32 },
    { "City of Dalaran", 28, 35 },
    { "Gnomeregan", 29, 38 },
    { "Razorfen Kraul", 29, 38 },
    { "Scarlet Monastery: Graveyard", 28, 38 },
    { "Scarlet Monastery: Library", 29, 39 },
    { "Scarlet Monastery: Armory", 32, 42 },
    { "Scarlet Monastery: Cathedral", 35, 45 },
    { "Razorfen Downs", 37, 46 },
    { "Uldaman", 41, 51 },
    { "Zul'Farrak", 44, 54 },
    { "Maraudon", 46, 55 },
    { "Temple of Atal'Hakkar", 50, 56 },
    { "Blackrock Depths", 52, 60 },
    { "Lower Blackrock Spire", 55, 60 },
    { "Dire Maul: East", 56, 60 },
    { "Dire Maul: West", 57, 60 },
    { "Dire Maul: North", 57, 60 },
    { "Scholomance", 58, 60 },
    { "Stratholme", 58, 60 },
    { "Upper Blackrock Spire", 58, 60 },
    { "Onyxia's Lair", 60, 60, nil, true },
    { "Molten Core", 60, 60, nil, true },
    { "Blackwing Lair", 60, 60, nil, true },
    { "Zul'Gurub", 60, 60, nil, true },
    { "Ruins of Ahn'Qiraj", 60, 60, nil, true },
    { "Temple of Ahn'Qiraj", 60, 60, nil, true },
    { "Naxxramas", 60, 60, nil, true },
}
