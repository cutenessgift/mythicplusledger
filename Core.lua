local ADDON_NAME, ADDON_NS = ...
local ADDON_VERSION = "0.1.300"

MPlusLedger = MPlusLedger or {}
local Addon = MPlusLedger
-- MPlusLedgerSkin\LedgerSkin.lua (loaded before this file, see the .toc) populates ADDON_NS.LedgerSkin
-- with the gold-trimmed nine-slice skin pack (Skin.Apply/Button/Progress/Tab) -- per user request
-- 2026-09-30 ("using these [assets], can we create the attached image in World of Warcraft for our
-- addon?"). ADDON_NS is WoW's own per-addon shared table (automatically the same table instance
-- across every file this addon's .toc lists), not something this addon set up itself -- this is the
-- first file in this addon to actually use it, everything else so far has used explicit globals
-- (see UI\PieChart.lua's own comment on why) since a single shared table wasn't needed until now.
local Skin = ADDON_NS and ADDON_NS.LedgerSkin
Addon.Skin = Skin
local TableUnpack = unpack or (table and table.unpack)

local DEFAULTS = {
    runs = {},
    runOrder = {},
    nextRunID = 0,
    currentRunID = nil,
    lastRunID = nil,
    retainRuns = 100,
    lastRepairWindow = 300,
    mainView = "currentSeason",
    mainSort = "highestKey",
    overallDifficultyOpacity = 0.22,
    runCardOpacity = 0.72,
    shareUseCurrentChat = true,
    shareTarget = "GUILD",
    trackRaids = true,
    broadcastPlayerReports = false,
    broadcastPlayerReportsOnApply = false,
    showApplicantAlertPopup = true,
    hidePostDungeonReputation = true,
    bossOverrides = {},
    customBossMaps = {},
    customBossOrders = {},
    dungeonMetadata = {},
    instanceCatalog = {},
    npcCatalog = {},
    bossCatalog = {},
    seasonLinks = {},
    playerRatings = {},
    mobNameOverrides = {},
    playerCode = nil,
    tracker = {
        shown = true,
        point = "TOP",
        relativePoint = "TOP",
        x = 0,
        y = -120,
        scale = 1,
        width = 650,
        height = 108, -- was 132 -- shrunk 2026-09-16 when the Enemy Forces bar was removed
    },
    minimap = {
        shown = true,
        angle = 225,
    },
    liveEvents = true,
    uiTheme = "classic",
    debug = false,
    fullDebug = false,
    debugLog = {},
    iconDumps = {},
}

local CLASS_COLORS = {
    DEATHKNIGHT = "|cffc41e3a",
    DEMONHUNTER = "|cffa330c9",
    DRUID = "|cffff7c0a",
    EVOKER = "|cff33937f",
    HUNTER = "|cffaad372",
    MAGE = "|cff3fc7eb",
    MONK = "|cff00ff98",
    PALADIN = "|cfff48cba",
    PRIEST = "|cffffffff",
    ROGUE = "|cfffff468",
    SHAMAN = "|cff0070dd",
    WARLOCK = "|cff8788ee",
    WARRIOR = "|cffc69b6d",
}

local CLASS_BACKDROP_COLORS = {
    DEATHKNIGHT = { 0.55, 0.06, 0.13 },
    DEMONHUNTER = { 0.42, 0.13, 0.55 },
    DRUID = { 0.65, 0.30, 0.04 },
    EVOKER = { 0.08, 0.42, 0.36 },
    HUNTER = { 0.38, 0.50, 0.23 },
    MAGE = { 0.10, 0.47, 0.58 },
    MONK = { 0.00, 0.48, 0.30 },
    PALADIN = { 0.58, 0.28, 0.43 },
    PRIEST = { 0.46, 0.46, 0.46 },
    ROGUE = { 0.55, 0.50, 0.18 },
    SHAMAN = { 0.03, 0.22, 0.55 },
    WARLOCK = { 0.31, 0.29, 0.55 },
    WARRIOR = { 0.50, 0.34, 0.18 },
}

-- Raw class tokens (CLASS_COLORS' keys, e.g. "DEATHKNIGHT") are what's stored/compared everywhere,
-- but showing that literal token to the user reads as shouty all-caps -- per user request
-- 2026-10-01 ("all the Classes names are capitals could you change this to Capital first letter?").
-- LOCALIZED_CLASS_NAMES_MALE is Blizzard's own token->display map (gives "Death Knight", "Demon
-- Hunter", etc. -- not just a capitalize-first-letter transform, which would mangle compound class
-- names), already used the same way elsewhere in this file (see GetDebugPlayerOptions-era code);
-- this just gives every OTHER spot that renders a class token the same helper instead of each
-- re-deriving it.
local function ClassDisplayName(token)
    if not token or token == "" then
        return token
    end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
end

-- Every currently playable race (12.0 "Midnight") grouped by faction, plus the three
-- both-factions-available races -- per user request 2026-09-05 (Race should be a dropdown, not
-- free text). Kept as one flat list rather than per-faction lists since a saved player's race
-- doesn't need to be cross-checked against their Faction pick here.
local RACE_OPTIONS = {
    "Human", "Dwarf", "Night Elf", "Gnome", "Draenei", "Worgen", "Void Elf",
    "Lightforged Draenei", "Dark Iron Dwarf", "Kul Tiran", "Mechagnome",
    "Orc", "Undead", "Tauren", "Troll", "Blood Elf", "Goblin",
    "Highmountain Tauren", "Nightborne", "Mag'har Orc", "Zandalari Troll", "Vulpera",
    "Pandaren", "Dracthyr", "Earthen",
}
-- Race -> Faction, built from RACE_OPTIONS' own Alliance/Horde grouping above -- per user request
-- 2026-10-01 ("if the race of lets say Human is selected, can the Faction auto select Alliance").
-- Pandaren/Dracthyr/Earthen are deliberately absent -- both factions can play them, so there's no
-- single correct faction to auto-pick; the user's own Faction choice stays authoritative for those.
local RACE_FACTION = {
    Human = "Alliance", Dwarf = "Alliance", ["Night Elf"] = "Alliance", Gnome = "Alliance",
    Draenei = "Alliance", Worgen = "Alliance", ["Void Elf"] = "Alliance",
    ["Lightforged Draenei"] = "Alliance", ["Dark Iron Dwarf"] = "Alliance",
    ["Kul Tiran"] = "Alliance", Mechagnome = "Alliance",
    Orc = "Horde", Undead = "Horde", Tauren = "Horde", Troll = "Horde", ["Blood Elf"] = "Horde",
    Goblin = "Horde", ["Highmountain Tauren"] = "Horde", Nightborne = "Horde",
    ["Mag'har Orc"] = "Horde", ["Zandalari Troll"] = "Horde", Vulpera = "Horde",
}

local STATUS_BACKDROP_COLORS_DEFAULT = {
    Completed = { 0.02, 0.36, 0.08 },
    CompletedOvertime = { 0.18, 0.40, 0.05 },
    Failed = { 0.32, 0.02, 0.02 },
    Abandoned = { 0.32, 0.02, 0.02 },
    Active = { 0.02, 0.15, 0.45 },
}
-- Wrapped in a metatable (added 2026-09-08, see Addon:GetCustomStatusColor) so every existing
-- call site -- both STATUS_BACKDROP_COLORS[status] and the dotted STATUS_BACKDROP_COLORS.Completed
-- form used throughout Manage Data -- picks up a user-picked custom color automatically, with no
-- changes needed at any individual call site. Only Completed/CompletedOvertime/Abandoned are ever
-- actually customizable (matches the three pickers in Settings > Colours); Failed/Active simply
-- never have a custom entry to find, so they always fall through to the default here.
local STATUS_BACKDROP_COLORS = setmetatable({}, {
    __index = function(_, status)
        return Addon:GetCustomStatusColor(status) or STATUS_BACKDROP_COLORS_DEFAULT[status]
    end,
})
-- STATUS_BACKDROP_COLORS is chunk-local to this file -- this exposes the same lookup (including
-- the user's own Settings > Colours customization) to the UI/*.lua presentation files, which run
-- AFTER MenuPolish.lua strips every button's raw backdrop in favor of the skinned nine-slice
-- texture -- ApplyButtonColor's SetBackdropColor() call silently stops doing anything visible once
-- that happens, so status-button coloring has to happen later, as a LedgerSkinTextures tint, from
-- whichever file runs last for that window (per user report 2026-10-02, "the Completed, Overtime,
-- Abandoned and Active buttons need to be coloured to what they mean").
function Addon:GetStatusBackdropColor(status)
    return STATUS_BACKDROP_COLORS[status]
end

local DUNGEON_ICONS = {
    ["Murder Row"] = "Interface\\Icons\\inv_achievement_dungeon_silvermooncity",
    ["The Eternal Palace"] = "Interface\\Icons\\achievement_boss_queenazshara",
    ["Hellfire Citadel"] = "Interface\\Icons\\achievement_boss_archimonde",
    ["Ulduar"] = "Interface\\Icons\\achievement_dungeon_ulduar80_25man",
    ["Maisara Caverns"] = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider",
    ["Bloodmaul Slag Mines"] = 1041996,
    ["Iron Docks"] = 1060548,
    ["Pit of Saron"] = 608210,
    ["Skyreach"] = 1041999,
    ["Shadowmoon Burial Grounds"] = 1041998,
    ["The Rookery"] = 5912553,
    ["The Everbloom"] = 1060547,
    ["Grimrail Depot"] = "Interface\\Icons\\achievement_dungeon_grimraildepot",
    ["Auchindoun"] = "Interface\\Icons\\achievement_dungeon_auchindoun",
    ["Upper Blackrock Spire"] = "Interface\\Icons\\achievement_dungeon_upperblackrockspire",
}
local STATIC_DUNGEON_METADATA = {
    ["Temple of Sethraliss"] = {
        mythicPlusTimeLimitSeconds = 32 * 60,
    },
}
local DUNGEON_ICON_CROPS = {}
local DEFAULT_DUNGEON_ICON = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider"
local challengeIconCache = nil
local challengeNameCache = nil
local chatRepairHooked = false

-- Consolidated 2026-09-10: was 18 separate top-level locals -- Lua's main-chunk local-
-- variable limit is a hard 200, and the file had grown past it (the actual load-breaking bug
-- this consolidation fixes). One table instead of 18 locals; every use site below updated to
-- MainLayoutConst.NAME accordingly. Values unchanged.
local MainLayoutConst = {
    MAIN_VISIBLE_ROWS = 15,
    DETAIL_VISIBLE_ROWS = 3,
    DETAIL_ROW_HEIGHT = 142,
    DETAIL_ROW_SPACING = 154,
    DETAIL_ROW_WIDTH = 1012,
    DETAIL_ROW_START_Y = -354,
    WINDOW_WIDTH = 1080,
    WINDOW_HEIGHT = 900,
    PANEL_WIDTH = 1000,
    ROW_WIDTH = 960,
    MAIN_GRID_COLUMNS = 4,
    MAIN_CARD_WIDTH = 244,
    MAIN_CARD_HEIGHT = 236,
    MAIN_CARD_X = 34,
    MAIN_CARD_Y = -266,
    MAIN_LIST_BOTTOM_Y = -870,
    MAIN_CARD_H_SPACING = 12,
    MAIN_CARD_V_SPACING = 12,
}

local DIFFICULTY_BUCKET_ORDER = { "timewalking", "normal", "heroic", "mythic", "mythicPlus", "follower" }
local DIFFICULTY_BUCKETS = {
    normal = { label = "Normal", short = "N", color = "|cff33d6cc", id = 1, backdrop = { 0.03, 0.30, 0.30 } },
    heroic = { label = "Heroic", short = "H", color = "|cffff33cc", id = 2, backdrop = { 0.34, 0.03, 0.30 } },
    mythic = { label = "Mythic", short = "M", color = "|cffff9900", id = 23, backdrop = { 0.38, 0.18, 0.02 } },
    mythicPlus = { label = "Mythic+", short = "M+", color = "|cffff3333", id = 8, backdrop = { 0.28, 0.02, 0.02 } },
    timewalking = { label = "Timewalking", short = "TW", color = "|cff99ccff", id = 24, backdrop = { 0.04, 0.18, 0.38 } },
    follower = { label = "Follower Dungeon", short = "FD", color = "|cff66ff99", id = 205, backdrop = { 0.04, 0.30, 0.12 } },
    lfr = { label = "LFR", short = "LFR", color = "|cffcc99ff", id = 17, backdrop = { 0.23, 0.10, 0.34 } },
}

local MAIN_SORT_OPTIONS = {
    { text = "Most Recent", value = "recent" },
    { text = "Most Deaths", value = "totalDeaths" },
    { text = "Highest Key", value = "highestKey" },
    { text = "Most Runs", value = "runs" },
    { text = "Most Abandons", value = "abandoned" },
    { text = "Most Repair Cost", value = "repairCost" },
}

local MAIN_VIEW_OPTIONS = {
    { text = "Current Season", value = "currentSeason" },
    { text = "Mythic+ Season", value = "season" },
    { text = "Expansion", value = "expansion" },
    { text = "All Dungeons", value = "all" },
}

-- Data Tools "Assign Mobs & Bosses" type selector -- Delve has no Encounter Journal catalog to
-- pick from (see BuildExpansionCatalog's Delve note), so it gets a free-text name field instead
-- of the Expansion/Instance dropdowns Dungeon and Raid use.
local ASSIGNMENT_TYPE_OPTIONS = {
    { text = "Dungeon", value = "dungeon" },
    { text = "Raid", value = "raid" },
    { text = "Delve", value = "delve" },
    { text = "Open World", value = "openworld" },
}

local SHARE_TARGET_OPTIONS = {
    { text = "Say", value = "SAY", channel = "SAY" },
    { text = "Yell", value = "YELL", channel = "YELL" },
    { text = "Guild Chat", value = "GUILD", channel = "GUILD" },
    { text = "Officer Chat", value = "OFFICER", channel = "OFFICER" },
    { text = "Guild Discord Chat", value = "GUILD_DISCORD", namedChannel = "Guild Discord" },
    { text = "Party", value = "PARTY", channel = "PARTY" },
    { text = "Raid", value = "RAID", channel = "RAID" },
    { text = "Instance", value = "INSTANCE_CHAT", channel = "INSTANCE_CHAT" },
    { text = "General", value = "GENERAL", namedChannel = "General" },
    { text = "Trade", value = "TRADE", namedChannel = "Trade" },
    { text = "LocalDefense", value = "LOCALDEFENSE", namedChannel = "LocalDefense" },
    { text = "Services", value = "SERVICES", namedChannel = "Services" },
}

local DIFFICULTY_SORT_RANK = {
    follower = 1,
    normal = 2,
    heroic = 3,
    timewalking = 4,
    mythic = 5,
    mythicPlus = 6,
    lfr = 7,
}

local INSTANCE_KIND_OVERRIDES = {
    ["FW Horde Garrison Level 2"] = "Place",
    ["FW Horde Garrison"] = "Place",
    ["Hellfire Citadel"] = "Raid",
    ["The Eternal Palace"] = "Raid",
    ["Ulduar"] = "Raid",
}

local EXCLUDED_INSTANCE_NAMES = {
    ["FW Horde Garrison Level 2"] = true,
    ["FW Horde Garrison"] = true,
}

local DUNGEON_BOSSES = {
    ["Bloodmaul Slag Mines"] = {
        bosses = {
            [1653] = { name = "Slave Watcher Crushto", optional = false },
            [1655] = { name = "Magmolatus", optional = false },
            [1652] = { name = "Roltall", optional = false },
            [1654] = { name = "Gug'rokk", optional = false },
        },
        names = {
            ["Slave Watcher Crushto"] = 1653,
            ["Magmolatus"] = 1655,
            ["Roltall"] = 1652,
            ["Gug'rokk"] = 1654,
        },
        final = {
            [1654] = true,
            ["Gug'rokk"] = true,
        },
    },
    ["Iron Docks"] = {
        bosses = {
            [1749] = { name = "Fleshrender Nok'gar", optional = false },
            [1748] = { name = "Grimrail Enforcers", optional = false },
            [1750] = { name = "Oshir", optional = false },
            [1747] = { name = "Skulloc", optional = false },
        },
        names = {
            ["Fleshrender Nok'gar"] = 1749,
            ["Grimrail Enforcers"] = 1748,
            ["Ahri'ok Dugru"] = 1748,
            ["Makogg Emberblade"] = 1748,
            ["Neesa Nox"] = 1748,
            ["Oshir"] = 1750,
            ["Skulloc"] = 1747,
        },
        final = {
            [1747] = true,
            ["Skulloc"] = true,
        },
    },
    ["Skyreach"] = {
        bosses = {
            [1698] = { name = "Ranjit", optional = false },
            [1699] = { name = "Araknath", optional = false },
            [1700] = { name = "Rukhran", optional = false },
            [1701] = { name = "High Sage Viryx", optional = false },
        },
        names = {
            ["Ranjit"] = 1698,
            ["Araknath"] = 1699,
            ["Rukhran"] = 1700,
            ["High Sage Viryx"] = 1701,
        },
        final = {
            [1701] = true,
            ["High Sage Viryx"] = true,
        },
    },
    ["Shadowmoon Burial Grounds"] = {
        bosses = {
            [1677] = { name = "Sadana Bloodfury", optional = false },
            [1688] = { name = "Nhallish", optional = false },
            [1679] = { name = "Bonemaw", optional = false },
            [1682] = { name = "Ner'zhul", optional = false },
        },
        names = {
            ["Sadana Bloodfury"] = 1677,
            ["Nhallish"] = 1688,
            ["Bonemaw"] = 1679,
            ["Ner'zhul"] = 1682,
        },
        final = {
            [1682] = true,
            ["Ner'zhul"] = true,
        },
    },
    ["Freehold"] = {
        bosses = {
            [2102] = { name = "Skycap'n Kragg", optional = false },
            [2093] = { name = "Council o' Captains", optional = false },
            [2094] = { name = "Ring of Booty", optional = false },
            [2095] = { name = "Harlan Sweete", optional = false },
        },
        names = {
            ["Skycap'n Kragg"] = 2102,
            ["Council o' Captains"] = 2093,
            ["Ring of Booty"] = 2094,
            ["Trothak"] = 2094,
            ["Harlan Sweete"] = 2095,
        },
        final = {
            [2095] = true,
            ["Harlan Sweete"] = true,
        },
    },
    ["Pit of Saron"] = {
        bosses = {
            [608] = { name = "Forgemaster Garfrost", optional = false },
            [609] = { name = "Krick and Ick", optional = false },
            [610] = { name = "Scourgelord Tyrannus", optional = false },
        },
        names = {
            ["Forgemaster Garfrost"] = 608,
            ["Krick"] = 609,
            ["Ick"] = 609,
            ["Krick and Ick"] = 609,
            ["Scourgelord Tyrannus"] = 610,
        },
        final = {
            [610] = true,
            ["Scourgelord Tyrannus"] = true,
        },
    },
    ["The Forge of Souls"] = {
        bosses = {
            [-1001] = { name = "Bronjahm", optional = false },
            [-1002] = { name = "Devourer of Souls", optional = false },
        },
        names = {
            ["Bronjahm"] = -1001,
            ["Devourer of Souls"] = -1002,
        },
        final = {
            [-1002] = true,
            ["Devourer of Souls"] = true,
        },
    },
    ["Gundrak"] = {
        bosses = {
            [-1011] = { name = "Slad'ran", optional = false },
            [-1012] = { name = "Drakkari Colossus", optional = false },
            [-1013] = { name = "Moorabi", optional = false },
            [-1014] = { name = "Gal'darah", optional = false },
            [-1015] = { name = "Eck the Ferocious", optional = true },
        },
        names = {
            ["Slad'ran"] = -1011,
            ["Drakkari Colossus"] = -1012,
            ["Moorabi"] = -1013,
            ["Gal'darah"] = -1014,
            ["Eck"] = -1015,
            ["Eck the Ferocious"] = -1015,
        },
        final = {
            [-1014] = true,
            ["Gal'darah"] = true,
        },
    },
    ["Halls of Lightning"] = {
        bosses = {
            [-1021] = { name = "General Bjarngrim", optional = false },
            [-1022] = { name = "Volkhan", optional = false },
            [-1023] = { name = "Ionar", optional = false },
            [-1024] = { name = "Loken", optional = false },
        },
        names = {
            ["General Bjarngrim"] = -1021,
            ["Volkhan"] = -1022,
            ["Ionar"] = -1023,
            ["Loken"] = -1024,
        },
        final = {
            [-1024] = true,
            ["Loken"] = true,
        },
    },
    ["The Nexus"] = {
        bosses = {
            [-1031] = { name = "Grand Magus Telestra", optional = false },
            [-1032] = { name = "Anomalus", optional = false },
            [-1033] = { name = "Ormorok the Tree-Shaper", optional = false },
            [-1034] = { name = "Keristrasza", optional = false },
            [-1035] = { name = "Commander Kolurg", optional = true },
            [-1036] = { name = "Commander Stoutbeard", optional = true },
        },
        names = {
            ["Grand Magus Telestra"] = -1031,
            ["Anomalus"] = -1032,
            ["Ormorok the Tree-Shaper"] = -1033,
            ["Ormorok"] = -1033,
            ["Keristrasza"] = -1034,
            ["Commander Kolurg"] = -1035,
            ["Commander Stoutbeard"] = -1036,
        },
        final = {
            [-1034] = true,
            ["Keristrasza"] = true,
        },
    },
    ["Den of Nalorakk"] = {
        bosses = {
            [-1041] = { name = "The Hoardmonger", optional = false },
            [-1042] = { name = "Sentinel of Winter", optional = false },
            [-1043] = { name = "Nalorakk", optional = false },
        },
        names = {
            ["The Hoardmonger"] = -1041,
            ["Hoardmonger"] = -1041,
            ["Sentinel of Winter"] = -1042,
            ["Winter Sentinel"] = -1042,
            ["Nalorakk"] = -1043,
        },
        final = {
            [-1043] = true,
            ["Nalorakk"] = true,
        },
    },
    -- Real Encounter Journal encounterIDs, captured live from this account's own bossCatalog
    -- (ENCOUNTER_END, patch 12.1) -- not looked up externally, so these are as trustworthy as the
    -- client itself. No `final` boss is flagged for either dungeon below: kill order wasn't
    -- confirmed from any source good enough to risk it, and it isn't actually needed --
    -- HaveAllRequiredBossesDied already completes the run once every boss listed here (all
    -- required, none optional) is dead, regardless of order.
    ["Murder Row"] = {
        bosses = {
            [3101] = { name = "Kystia Manaheart", optional = false },
            [3102] = { name = "Zaen Bladesorrow", optional = false },
            [3103] = { name = "Xathuux the Annihilator", optional = false },
            [3105] = { name = "Lithiel Cinderfury", optional = false },
        },
        names = {
            ["Kystia Manaheart"] = 3101,
            ["Zaen Bladesorrow"] = 3102,
            ["Xathuux the Annihilator"] = 3103,
            ["Lithiel Cinderfury"] = 3105,
        },
    },
    ["The Blinding Vale"] = {
        bosses = {
            [3199] = { name = "Lightblossom Trinity", optional = false },
            [3200] = { name = "Ikuzz the Light Hunter", optional = false },
            [3201] = { name = "Lightwarden Ruia", optional = false },
            [3202] = { name = "Ziekket", optional = false },
        },
        names = {
            ["Lightblossom Trinity"] = 3199,
            ["Ikuzz the Light Hunter"] = 3200,
            ["Lightwarden Ruia"] = 3201,
            ["Ziekket"] = 3202,
        },
    },
}

local DUNGEON_BOSS_ORDER = {
    ["Bloodmaul Slag Mines"] = { 1653, 1655, 1652, 1654 },
    ["Iron Docks"] = { 1749, 1748, 1750, 1747 },
    ["Skyreach"] = { 1698, 1699, 1700, 1701 },
    ["Shadowmoon Burial Grounds"] = { 1677, 1688, 1679, 1682 },
    ["Freehold"] = { 2102, 2093, 2094, 2095 },
    ["Pit of Saron"] = { 608, 609, 610 },
    ["The Forge of Souls"] = { -1001, -1002 },
    ["Gundrak"] = { -1011, -1012, -1013, -1014, -1015 },
    ["Halls of Lightning"] = { -1021, -1022, -1023, -1024 },
    ["The Nexus"] = { -1031, -1032, -1033, -1034, -1035, -1036 },
    ["Den of Nalorakk"] = { -1041, -1042, -1043 },
    -- Display order only (affects the boss checklist UI, not completion detection) -- ascending
    -- by encounterID since no confirmed kill order was available; correct either way.
    ["Murder Row"] = { 3101, 3102, 3103, 3105 },
    ["The Blinding Vale"] = { 3199, 3200, 3201, 3202 },
}


local function CopyDefaults(target, defaults)
    target = target or {}

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local function RegisterEscCloseFrame(frameName)
    if not frameName or not UISpecialFrames then
        return
    end

    for _, registeredName in ipairs(UISpecialFrames) do
        if registeredName == frameName then
            return
        end
    end

    table.insert(UISpecialFrames, frameName)
end

-- Shared OnLeave handler for the many hand-rolled dropdown "menu" frames scattered across this
-- file (Run Editor, Manage Runs, Record Repair, the legacy All Runs renderer, ...) -- per user
-- report 2026-10-02 ("Can you check all dropdown boxes as well as this seems to be a persistent
-- issue?"). An audit found FIVE separate near-identical reimplementations of the same
-- button+BackdropTemplate-menu pattern across this addon, and every one of them was missing
-- close-on-cursor-leave -- only the two standalone Add/Update Player windows and the Stats Hub's
-- CreateStatsHubDropdown ever had it. Delayed and re-checked against IsMouseOver() (a pure
-- bounding-box test), not hidden immediately: OnLeave also fires on the transition from the menu's
-- own background onto one of its child OPTION buttons (the button becomes the new topmost frame
-- under the cursor), and hiding right then would close the menu the instant you tried to hover an
-- option to click it -- IsMouseOver() still reads true in that case since the cursor is
-- geometrically still within the menu's bounds. Pass directly as a frame's OnLeave script
-- (`menu:SetScript("OnLeave", CloseDropdownOnLeave)`); every caller's menu already calls
-- EnableMouse(true) alongside it, which OnLeave requires to fire at all.
local function CloseDropdownOnLeave(self)
    C_Timer.After(0.15, function()
        if self:IsShown() and not self:IsMouseOver() then
            self:Hide()
        end
    end)
end

-- Every M+ Ledger window uses this for ESC-to-close, so EnableKeyboard(true) here is active
-- on essentially every window the addon has. Patch 12.0's rework (v0.1.135) removed the
-- SetPropagateKeyboardInput(true) call this used to make for every non-ESCAPE key, as a quick
-- workaround when it started erroring -- but that restriction (confirmed via Blizzard's own
-- history: SetPropagateKeyboardInput has been combat-only restricted since patch 10.1.5, not a
-- general 12.0 block) only ever applied in combat. Removing it outright meant every window
-- silently swallowed every key while shown -- not just ESCAPE -- including Delete/Enter meant for
-- the chat edit box. Restored, pcall-wrapped so the rare in-combat case degrades to "this one key
-- gets consumed" instead of erroring, rather than reintroducing the original crash.
local function EnableEscHandler(frame, handler)
    if not frame or not handler then
        return
    end

    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            handler()
        elseif self.SetPropagateKeyboardInput then
            pcall(self.SetPropagateKeyboardInput, self, true)
        end
    end)
end

local function ApplyButtonColor(button, color)
    if not button then
        return
    end

    button.normalBackdrop = color
    if color then
        button:SetBackdropColor(color[1] or 0.45, color[2] or 0.02, color[3] or 0.02, 0.88)
    else
        button:SetBackdropColor(0.45, 0.02, 0.02, 0.85)
    end
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffM+ Ledger:|r " .. tostring(message))
end

local function Debug(message)
    if MPlusLedgerDB then
        MPlusLedgerDB.debugLog = MPlusLedgerDB.debugLog or {}
        table.insert(MPlusLedgerDB.debugLog, {
            time = time(),
            timeText = date("%Y-%m-%d %H:%M:%S"),
            message = tostring(message),
        })
        -- Was 120 -- the per-kill diagnostic dumps added while chasing the Secret Value mob-kill
        -- bug (2-3 lines per PARTY_KILL/UNIT_DIED/PLAYER_TARGET_DIED firing) exhaust that within
        -- a couple of trash pulls in an active M+ run, silently rotating out exactly the evidence
        -- (e.g. a boss kill's CaptureUnitDisplayID trace) needed to diagnose anything that
        -- happened earlier in the same session. Raised so a full run's worth survives to /reload.
        --
        -- Was 600 -- confirmed live 2026-09-10: a manually-run /dl scenario dump (7-8 lines) got
        -- rotated out before the next /reload because ~55 nameplate-watcher failure lines from a
        -- single pull filled the remaining budget first (that specific source is now throttled,
        -- see CheckNameplateForMissedMobKill, but the general lesson -- a busy pull can burn
        -- hundreds of entries fast -- means 600 wasn't enough headroom even with that fixed).
        while #MPlusLedgerDB.debugLog > 1200 do
            table.remove(MPlusLedgerDB.debugLog, 1)
        end
    end
    if MPlusLedgerDB and MPlusLedgerDB.debug then
        Print("Debug: " .. tostring(message))
    end
end

local function FullDebug(message)
    Debug(message)
    if MPlusLedgerDB and MPlusLedgerDB.fullDebug then
        Print("FullDebug: " .. tostring(message))
    end
end

local function FormatMoney(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100
    return string.format("%dg %02ds %02dc", gold, silver, copperOnly)
end

local function FormatMoneyIcons(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100
    return string.format(
        "%d|TInterface\\MoneyFrame\\UI-GoldIcon:13:13:0:0|t %02d|TInterface\\MoneyFrame\\UI-SilverIcon:13:13:0:0|t %02d|TInterface\\MoneyFrame\\UI-CopperIcon:13:13:0:0|t",
        gold,
        silver,
        copperOnly
    )
end

local function ParseMoneyMessage(message)
    if not message then
        return 0
    end

    local gold = tonumber(message:match("(%d+)%s+Gold")) or 0
    local silver = tonumber(message:match("(%d+)%s+Silver")) or 0
    local copper = tonumber(message:match("(%d+)%s+Copper")) or 0
    return (gold * 10000) + (silver * 100) + copper
end

local function ParseMoneyAmount(value)
    value = tostring(value or "")
    local lowerValue = string.lower(value)
    local gold = tonumber(lowerValue:match("(%d+)%s*g")) or tonumber(lowerValue:match("(%d+)%s+gold"))
    local silver = tonumber(lowerValue:match("(%d+)%s*s")) or tonumber(lowerValue:match("(%d+)%s+silver"))
    local copper = tonumber(lowerValue:match("(%d+)%s*c")) or tonumber(lowerValue:match("(%d+)%s+copper"))

    gold = gold or tonumber(value:match("(%d+)%s*|T[^|]-[Gg]old[Ii]con"))
    silver = silver or tonumber(value:match("(%d+)%s*|T[^|]-[Ss]ilver[Ii]con"))
    copper = copper or tonumber(value:match("(%d+)%s*|T[^|]-[Cc]opper[Ii]con"))

    if not gold and not silver and not copper then
        local first, second, third = value:match("^%s*(%d+)%s+(%d+)%s+(%d+)%s*$")
        gold = tonumber(first)
        silver = tonumber(second)
        copper = tonumber(third)
    end

    return ((gold or 0) * 10000) + ((silver or 0) * 100) + (copper or 0)
end

local function FormatDuration(seconds)
    seconds = tonumber(seconds) or 0
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end

    if minutes > 0 then
        return string.format("%dm %02ds", minutes, secs)
    end

    return string.format("%ds", secs)
end

local function StripColor(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

local function GetAngleDegrees(y, x)
    if math.atan2 then
        return math.deg(math.atan2(y, x))
    end

    if x == 0 then
        return y >= 0 and 90 or -90
    end

    local angle = math.deg(math.atan(y / x))
    if x < 0 then
        angle = angle + 180
    end
    return angle
end


local GetRunTimerStart
local function GetRunDuration(run)
    if not run then
        return 0
    end

    if run.durationOverride then
        return tonumber(run.durationOverride) or 0
    end

    local timerStart = GetRunTimerStart(run)
    if not timerStart and run.endedAt and run.duration then
        return run.duration
    end
    timerStart = timerStart or run.startedAt

    if run.endedAt then
        return math.max(0, run.endedAt - (timerStart or run.endedAt))
    end

    if timerStart then
        return math.max(0, time() - timerStart)
    end

    return 0
end

local function CoerceSeconds(value)
    local numeric = tonumber(value)
    if not numeric or numeric <= 0 then
        return nil
    end
    return math.floor(numeric)
end

function Addon:GetMythicPlusTimeLimit(runOrInstanceName)
    local run = type(runOrInstanceName) == "table" and runOrInstanceName or nil
    if run then
        local live = CoerceSeconds(run.mythicPlusTimeLimitSeconds)
        if live then
            return live
        end
    end

    local instanceName = run and run.instanceName or runOrInstanceName
    if not instanceName or instanceName == "" then
        return nil
    end

    local metadata = self.db and self.db.dungeonMetadata and self.db.dungeonMetadata[instanceName]
    local catalog = self.db and self.db.instanceCatalog and self.db.instanceCatalog[instanceName]
    local static = STATIC_DUNGEON_METADATA[instanceName]
    return CoerceSeconds(metadata and (metadata.mythicPlusTimeLimitSeconds or metadata.mythicPlusTimerSeconds or metadata.timeLimitSeconds))
        or CoerceSeconds(catalog and (catalog.mythicPlusTimeLimitSeconds or catalog.mythicPlusTimerSeconds or catalog.timeLimitSeconds))
        or CoerceSeconds(static and static.mythicPlusTimeLimitSeconds)
end

function Addon:ApplyMythicPlusCompletionStatus(run)
    if not run or not self:IsMythicPlusRun(run) then
        return
    end

    local limit = self:GetMythicPlusTimeLimit(run)
    local duration = GetRunDuration(run)
    if limit and duration > limit then
        run.runStatus = "CompletedOvertime"
        run.completedOvertime = true
        run.overtime = true
    else
        run.runStatus = "Completed"
        run.completedOvertime = nil
        run.overtime = nil
    end
end

local function GetUnitFullName(unit)
    if not UnitExists(unit) then
        return nil
    end

    local name, realm = UnitName(unit)
    if not name or name == "" then
        return nil
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end


local function GetShortName(name)
    if not name then
        return "Unknown"
    end

    return tostring(name):match("^[^-]+") or tostring(name)
end

local function ToBase36(value)
    value = tonumber(value) or 0
    local alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    if value <= 0 then
        return "0"
    end

    local parts = {}
    while value > 0 do
        local index = (value % 36) + 1
        table.insert(parts, 1, alphabet:sub(index, index))
        value = math.floor(value / 36)
    end
    return table.concat(parts)
end

local function PadLeft(text, length, char)
    text = tostring(text or "")
    char = char or "0"
    while #text < length do
        text = char .. text
    end
    return text
end

local function StripWowText(text)
    -- A Secret Value (patch 12.x) can't be indexed or gsub'd -- treat it as unreadable text.
    if issecretvalue and issecretvalue(text) then
        return ""
    end
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    text = text:gsub("|H.-|h%[(.-)%]|h", "%1")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return strtrim(text)
end

local function NormalizePlayerName(name)
    name = StripWowText(name)
    name = name:gsub("^%[", ""):gsub("%]$", "")
    return string.lower(GetShortName(name))
end

local function GetPlayerRealmName(name)
    local clean = StripWowText(name or "")
    local player, realm = strsplit("-", clean)
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName() or ""
    end
    return player or clean, realm or ""
end

local function GetPlayerProfileKey(name)
    local player, realm = GetPlayerRealmName(name)
    if not player or player == "" then
        return nil
    end
    return string.lower(player .. "-" .. (realm or ""))
end

local function GetRoleLabel(role)
    if role == "DAMAGER" then
        return "DPS"
    end
    if role == "HEALER" then
        return "Heals"
    end
    if role == "TANK" then
        return "Tank"
    end
    return "None"
end

local function FormatDeathIDPlayerName(name)
    local cleanName = GetShortName(StripWowText(name or "Player"))
    cleanName = cleanName:gsub("%s+", "")
    cleanName = cleanName:gsub("[%-:|%[%]]", "")
    if cleanName == "" then
        cleanName = "Player"
    end
    return cleanName
end

-- Live-tested finding: UnitGUID() and raw combat/death event arguments can come back as Secret
-- Values under conditions this addon hadn't hit before patch 12.1 (confirmed via a live debug
-- log: "attempt to index/compare a secret string value, execution tainted by 'InstanceLedger'" on
-- every PARTY_KILL/UNIT_DIED/PLAYER_TARGET_DIED, which silently broke all trash-kill tracking).
-- type(v) == "string" stays true for a secret string -- the type check itself never errors, only
-- reading or comparing the value does -- so every GUID read anywhere in this file that might see
-- one needs this guard, not just a type() check. Defined this early so it's available to
-- GetGroupRoster below as well as the death-signal handling much further down the file.
local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function SafeUnitGUID(unit)
    local guid = UnitGUID(unit)
    if IsSecret(guid) then
        return nil
    end
    return guid
end

local function GetNPCIDFromGUID(guid)
    local unitType, _, _, _, _, npcID = strsplit("-", tostring(guid or ""))
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

local function TableContainsNumber(list, value)
    for _, entry in ipairs(list or {}) do
        if tonumber(entry) == value then
            return true
        end
    end
    return false
end

local function AppendDropToCatalogEntry(info, itemLink)
    info.drops = info.drops or {}
    for _, existing in ipairs(info.drops) do
        if existing == itemLink then
            return false
        end
    end
    table.insert(info.drops, itemLink)
    return true
end

-- There is no reliable API to resolve an arbitrary NPC ID to a creature display ID (the visual
-- asset ID a model frame actually needs) without a live unit token -- Wowhead-style NPC-ID
-- databases are the usual workaround, and this addon doesn't carry or fake one (same stance as
-- the Delve gaps elsewhere in this file). What IS documented and reliable: CharacterModelBase
-- (PlayerModel's base) can SetUnit() on any currently-existing unit token and then GetDisplayInfo()
-- hands back the resolved display ID, which SetDisplayInfo() can redraw later even after the unit
-- is long gone. So the display ID is captured opportunistically at kill time, the same moment
-- level/health already are below, using a permanently hidden, off-screen model frame that's never
-- actually shown to the player.
function Addon:GetCaptureModelFrame()
    if self.captureModel then
        return self.captureModel
    end
    local model = CreateFrame("PlayerModel", nil, UIParent)
    model:SetSize(4, 4)
    model:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10000, -10000)
    -- Deliberately NOT :Hide() -- the off-screen position alone already keeps this invisible to
    -- the player, and a hidden frame appears not to actually load/resolve its model data at all
    -- (found 2026-09-01: a real, confirmed boss kill produced zero displayID captures the whole
    -- time this was hidden). :Show() so the model pipeline actually runs.
    model:Show()
    self.captureModel = model
    return model
end

function Addon:CaptureUnitDisplayID(unit)
    if not unit or not UnitExists(unit) then
        Debug("CaptureUnitDisplayID: unit missing or doesn't exist: " .. tostring(unit))
        return nil
    end
    local model = self:GetCaptureModelFrame()
    local setOk, setErr = pcall(model.SetUnit, model, unit)
    if not setOk then
        Debug("CaptureUnitDisplayID: SetUnit(" .. tostring(unit) .. ") failed: " .. tostring(setErr))
        return nil
    end
    local infoOk, displayID = pcall(model.GetDisplayInfo, model)
    if not infoOk then
        Debug("CaptureUnitDisplayID: GetDisplayInfo(" .. tostring(unit) .. ") errored: " .. tostring(displayID))
        return nil
    end
    if not displayID then
        Debug("CaptureUnitDisplayID: GetDisplayInfo(" .. tostring(unit) .. ") returned nil")
        return nil
    end
    if issecretvalue and issecretvalue(displayID) then
        Debug("CaptureUnitDisplayID: displayID for " .. tostring(unit) .. " is a secret value")
        return nil
    end
    return displayID
end

-- ENCOUNTER_END only hands back Blizzard's small Encounter Journal ID, not the boss creature's
-- actual NPC ID (the one Wowhead shows) -- so scrape the boss1-boss8 unit GUIDs at the same
-- moment to recover the real creature ID(s) for cross-referencing. The boss1-8 unit tokens are
-- still valid for a moment after the kill (dead, but not yet despawned), so level, max health, and
-- a display ID for the Mob & Boss Browser's model preview can be scraped here too -- closes the
-- boss catalog's "[verify]" gap for level/health without a separate ENCOUNTER_START listener.
local function GetEncounterNPCIDs()
    local ids, levels, maxHealths, displayIDs = {}, {}, {}, {}
    local position = 0
    for index = 1, 8 do
        local unit = "boss" .. index
        if UnitExists(unit) then
            position = position + 1
            -- npcID needs a readable GUID -- a genuine Secret Value for hostile units during an
            -- active M+ run (confirmed 2026-09-01 chasing the trash-mob tracking bug: UnitGUID()
            -- itself returns secret, not just the raw kill-event args), so this can legitimately
            -- come back nil even though the boss unit is completely valid. Level, max health, and
            -- the model preview all read the live unit token directly and don't need the GUID at
            -- all -- capture those regardless of whether npcID resolved, instead of gating the
            -- whole block behind it succeeding (that silently skipped level/health/displayID
            -- capture for every single boss kill during M+, matching the "zero displayID ever
            -- captured account-wide" finding -- v0.1.166's :Hide() fix was real but wasn't the
            -- actual blocker for bosses; this upstream gate never let it get called in the first
            -- place).
            local npcID = GetNPCIDFromGUID(SafeUnitGUID(unit))
            if npcID then
                table.insert(ids, npcID)
            end
            -- UnitLevel/UnitHealthMax guarded the same way as everything else touching a hostile
            -- unit's state this session -- health is one of the explicitly Secret-Value-protected
            -- categories, and an unguarded read here would throw and abort the whole function
            -- (losing npcID/level/maxHealth/displayID for this boss, not just the health field),
            -- unlike CaptureUnitDisplayID right below, which was already pcall-protected. Found
            -- during the 2026-09-04 full-file audit.
            local levelOk, level = pcall(UnitLevel, unit)
            local healthOk, maxHealth = pcall(UnitHealthMax, unit)
            if levelOk and IsSecret(level) then
                levelOk, level = false, nil
            end
            if healthOk and IsSecret(maxHealth) then
                healthOk, maxHealth = false, nil
            end
            levels[position] = (levelOk and level and level > 0) and level or nil
            maxHealths[position] = (healthOk and maxHealth and maxHealth > 0) and maxHealth or nil
            displayIDs[position] = Addon:CaptureUnitDisplayID(unit)
        end
    end
    return ids, levels, maxHealths, displayIDs
end

local function NormalizeDungeonName(name)
    name = tostring(name or ""):lower()
    name = name:gsub("|c%x%x%x%x%x%x%x%x", "")
    name = name:gsub("|r", "")
    name = name:gsub("[^%w]+", "")
    return name
end

local function FirstTextureValue(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" and value > 100000 then
            return value
        elseif type(value) == "string" and value ~= "" and (value:find("\\") or value:find("/")) then
            return value
        end
    end
    return nil
end

local function GetUnitRole(unit)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or nil
    if role and role ~= "NONE" then
        return role
    end

    if unit == "player" and GetSpecialization and GetSpecializationRole then
        local specIndex = GetSpecialization()
        if specIndex then
            role = GetSpecializationRole(specIndex)
            if role and role ~= "NONE" then
                return role
            end
        end
    end

    return "DAMAGER"
end

local function GetGroupRoster()
    local roster = {}
    local seen = {}

    local function addUnit(unit)
        local fullName = GetUnitFullName(unit)
        if not fullName or seen[fullName] then
            return
        end

        -- Race/faction added 2026-09-05 so the end-of-run rating popup can show them automatically
        -- (per user request) without needing a manual Player Reputation entry first -- UnitRace/
        -- UnitFactionGroup are the same kind of freely-available, no-privacy-restriction unit info
        -- as UnitClass/GetUnitRole just above, safe for any grouped unit.
        local localizedRace = UnitRace(unit)
        local englishFaction = UnitFactionGroup(unit)
        seen[fullName] = true
        table.insert(roster, {
            name = fullName,
            class = select(2, UnitClass(unit)),
            level = UnitLevel(unit),
            role = GetUnitRole(unit),
            race = localizedRace,
            faction = englishFaction,
            guid = SafeUnitGUID(unit),
            guild = GetGuildInfo and GetGuildInfo(unit) or nil,
        })
    end

    addUnit("player")

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            addUnit("raid" .. index)
        end
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            addUnit("party" .. index)
        end
    end

    table.sort(roster, function(left, right)
        return (left.name or "") < (right.name or "")
    end)

    return roster
end

-- Unit tokens (not the richer data GetGroupRoster returns) -- kept separate since
-- PollForMissedDeaths needs the actual token to call UnitIsDeadOrGhost/UnitGUID on every tick,
-- which GetGroupRoster's already-resolved snapshot doesn't retain.
local function GetGroupUnitTokens()
    local tokens = { "player" }
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            table.insert(tokens, "raid" .. index)
        end
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            table.insert(tokens, "party" .. index)
        end
    end
    return tokens
end

-- Death-location capture (CaptureUnitMapPosition) and the Cords live-position system it fed were
-- removed 2026-09-06: a full read of the live SavedVariables confirmed "deathPos" had NEVER once
-- been successfully written, for any death, in any run, across this account's entire history --
-- C_Map.GetPlayerMapPosition returns nil for every unit while inside an instance, a hard client-side
-- API limitation (cross-verified against this addon's own instrumented debug log and two other
-- independent addons' source), not something fixable in this addon. Cut as part of a feature-focus
-- pass alongside the Death Map UI that consumed it.

local function MergeRoster(previous, latest)
    local merged = {}
    local byKey = {}

    local function addOrUpdate(member, allowUpdate)
        if not member or not member.name then
            return
        end

        local key = member.guid or member.name
        local existing = byKey[key]
        if existing then
            if allowUpdate then
                existing.name = member.name or existing.name
                existing.class = member.class or existing.class
                existing.level = member.level or existing.level
                existing.role = member.role or existing.role
                existing.race = member.race or existing.race
                existing.faction = member.faction or existing.faction
                existing.guid = member.guid or existing.guid
            end
            return
        end

        local copy = {
            name = member.name,
            class = member.class,
            level = member.level,
            role = member.role,
            race = member.race,
            faction = member.faction,
            guid = member.guid,
        }
        byKey[key] = copy
        table.insert(merged, copy)
    end

    for _, member in ipairs(previous or {}) do
        addOrUpdate(member, false)
    end
    for _, member in ipairs(latest or {}) do
        addOrUpdate(member, true)
    end

    table.sort(merged, function(left, right)
        return (left.name or "") < (right.name or "")
    end)

    return merged
end

local function GetMemberCount(run)
    if run and run.currentMemberCount then
        return run.currentMemberCount
    end
    return run and run.members and #run.members or 0
end

GetRunTimerStart = function(run)
    return run and (run.timerStartedAt or run.challengeStartedAt or run.timingStartedAt or run.startedAt)
end

local function GetRunElapsedAt(run, eventTime)
    local timerStart = GetRunTimerStart(run)
    eventTime = tonumber(eventTime) or time()
    if not timerStart then
        return 0
    end
    return math.max(0, eventTime - timerStart)
end

local function GetChallengeModeSnapshot()
    local level
    local challengeMapID

    if C_ChallengeMode then
        if C_ChallengeMode.GetActiveKeystoneInfo then
            local ok, activeLevel = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
            if ok then
                level = tonumber(activeLevel) or level
            end
        end

        if (not level or level <= 0) and C_ChallengeMode.GetSlottedKeystoneInfo then
            -- Found via code review 2026-09-05: this call's real signature is
            -- (mapChallengeModeID, affixIDs, keystoneLevel) -- the level is the THIRD return, not
            -- the second (that's the affixIDs table). This previously read the level via
            -- `tonumber(secondReturn) or tonumber(thirdReturn)`, which still worked correctly only
            -- because tonumber() on a table quietly returns nil instead of erroring, silently
            -- falling through to the real (third) value every time. Named correctly now so it
            -- doesn't rely on that by accident.
            local ok, slottedMapID, _affixIDs, keystoneLevel = pcall(C_ChallengeMode.GetSlottedKeystoneInfo)
            if ok then
                challengeMapID = tonumber(slottedMapID) or challengeMapID
                level = tonumber(keystoneLevel) or level
            end
        end

        if C_ChallengeMode.GetActiveChallengeMapID then
            local ok, activeMapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
            if ok then
                challengeMapID = tonumber(activeMapID) or challengeMapID
            end
        end
    end

    return level, challengeMapID
end

local function GetChallengeMapTimeLimitSeconds(challengeMapID)
    if not challengeMapID or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        Debug("GetChallengeMapTimeLimitSeconds: no challengeMapID or API missing (challengeMapID=" .. tostring(challengeMapID) .. ")")
        return nil
    end
    local values = { pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID) }
    if not values[1] then
        Debug("GetChallengeMapTimeLimitSeconds: GetMapUIInfo pcall failed: " .. tostring(values[2]))
        return nil
    end
    local rawLimit = values[4]
    -- Patch 12.x can hand back a "Secret Value" for protected/instance-timing data (the same
    -- class of restriction already worked around for chat payloads elsewhere in this file) --
    -- tonumber() on one of those doesn't error, it just silently yields nil, which is
    -- indistinguishable from "API returned nothing" without this check.
    if issecretvalue and issecretvalue(rawLimit) then
        Debug("GetChallengeMapTimeLimitSeconds: raw time limit is a secret value (patch 12.x restriction), cannot read it directly")
        return nil
    end
    local timeLimit = tonumber(rawLimit)
    Debug(string.format("GetChallengeMapTimeLimitSeconds: mapID=%s name=%s id=%s timeLimit=%s (raw values[4]=%s, type=%s)",
        tostring(challengeMapID), tostring(values[2]), tostring(values[3]), tostring(timeLimit), tostring(rawLimit), type(rawLimit)))
    if timeLimit and timeLimit > 0 then
        return timeLimit
    end
    return nil
end

local function GetClientPatchInfo()
    local version, build, buildDate, interfaceVersion
    if GetBuildInfo then
        version, build, buildDate, interfaceVersion = GetBuildInfo()
    end
    return {
        version = version,
        build = build,
        buildDate = buildDate,
        interfaceVersion = interfaceVersion,
    }
end

-- Real expansion display name for a client version, when known -- used instead of the raw
-- "Patch X.Y.Z" placeholder wherever the current expansion can be named with confidence, the same
-- way GetNamedMythicPlusSeason below already hardcodes "Midnight" for major version 12. Found
-- 2026-09-01: a dungeon whose dungeonMetadata was never manually linked to a real expansion name
-- (via Manage Data) fell back to "Patch 12.1.0" forever once first written, even though this
-- addon already knows major version 12 is Midnight everywhere else in this file.
local function GetKnownExpansionNameForVersion(version)
    local major = tostring(version or ""):match("^(%d+)%.")
    if major == "12" then
        return "Midnight"
    end
    return nil
end

local function IsPlaceholderExpansionName(name)
    return not name or name == "" or name == "Unknown Expansion" or tostring(name):match("^Patch ") ~= nil
end

local function GetEstimatedMythicPlusSeason(version)
    local major, minor = tostring(version or ""):match("^(%d+)%.(%d+)")
    minor = tonumber(minor)
    if major and minor then
        return string.format("%s.%d Season %d", major, minor, minor + 1)
    end
    return "Unknown Season"
end

local function GetNamedMythicPlusSeason(version)
    local major, minor = tostring(version or ""):match("^(%d+)%.(%d+)")
    minor = tonumber(minor)
    if major == "12" and minor then
        return string.format("Midnight Season %d", minor + 1)
    end
    return nil
end

local function GetSeasonNumberFromText(seasonName)
    return tonumber(tostring(seasonName or ""):match("[Ss]eason%s*(%d+)"))
end

local function IsGenericSeasonName(seasonName)
    local text = tostring(seasonName or "")
    return text:match("^%s*[Ss]eason%s*%d+%s*$")
        or text:match("^%s*[Mm]ythic%+%s*[Ss]eason%s*%d+%s*$")
        or text:match("^%s*[Mm]%+%s*[Ss]eason%s*%d+%s*$")
end

local function GetInstanceSnapshot()
    -- 8th return of GetInstanceInfo() is the unique per-instantiation instanceID (verified against
    -- Blizzard API docs 2026-09-04) -- NOT a map ID despite the old local var name here. It's the
    -- only reliable way to tell "still standing in the same physical instance" apart from "entered
    -- a fresh copy of the same dungeon", which CheckInstanceState needs to avoid spawning a phantom
    -- duplicate run when a stray PLAYER_ENTERING_WORLD/ZONE_CHANGED_NEW_AREA fires after a key is
    -- already done but the player hasn't actually left the instance yet.
    local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = GetInstanceInfo()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or instanceID
    local challengeLevel, challengeMapID = GetChallengeModeSnapshot()

    return {
        name = name or GetRealZoneText() or "Unknown Dungeon",
        instanceType = instanceType or "none",
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        maxPlayers = maxPlayers,
        mapID = mapID or instanceID,
        instanceID = instanceID,
        challengeLevel = challengeLevel,
        keyLevel = challengeLevel,
        challengeMapID = challengeMapID,
        zoneText = GetRealZoneText(),
        subZoneText = GetSubZoneText(),
    }
end

local function IsTrackedDungeonInstance()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return false
    end
    if instanceType == "party" then
        return true
    end
    if instanceType == "raid" and Addon.db and Addon.db.trackRaids ~= false then
        return true
    end
    local difficultyID = select(3, GetInstanceInfo())
    return difficultyID == 205
end

function Addon:GetRun(runID)
    return runID and self.db and self.db.runs and self.db.runs[runID] or nil
end

function Addon:RunHasBossKill(run)
    if not run then
        return false
    end
    for _, killed in pairs(run.killedBosses or {}) do
        if killed then
            return true
        end
    end
    for _, boss in pairs(run.bossKills or {}) do
        if boss and (tonumber(boss.count) or 0) > 0 then
            return true
        end
    end
    return run.bossKillLog and #run.bossKillLog > 0 or false
end

function Addon:RunHasMobKill(run)
    if not run then
        return false
    end
    if (tonumber(run.mobKillTotal) or 0) > 0 then
        return true
    end
    for _, mob in pairs(run.mobKills or {}) do
        if mob and (tonumber(mob.count) or 0) > 0 then
            return true
        end
    end
    return run.mobKillLog and #run.mobKillLog > 0 or false
end

function Addon:DeleteRun(runOrID, reason)
    local run = type(runOrID) == "table" and runOrID or self:GetRun(runOrID)
    if not run or not self.db or not self.db.runs then
        Print("Select a run first.")
        return false
    end

    local runID = tostring(run.id or runOrID)
    local code = self:GetRunCode(run)
    self.db.runs[runID] = nil
    for index = #(self.db.runOrder or {}), 1, -1 do
        if tostring(self.db.runOrder[index]) == runID then
            table.remove(self.db.runOrder, index)
        end
    end
    if tostring(self.db.currentRunID or "") == runID then
        self.db.currentRunID = nil
    end
    if tostring(self.db.lastRunID or "") == runID then
        self.db.lastRunID = self.db.runOrder and self.db.runOrder[1] or nil
    end
    if self.debugSelectedRunID and tostring(self.debugSelectedRunID) == runID then
        self.debugSelectedRunID = nil
    end
    if self.dataToolSelectedRunID and tostring(self.dataToolSelectedRunID) == runID then
        self.dataToolSelectedRunID = nil
    end
    if self.selectedRunForShare and tostring(self.selectedRunForShare.id or "") == runID then
        self.selectedRunForShare = nil
    end
    if self.repairWindowSelectedRun and tostring(self.repairWindowSelectedRun.id or "") == runID then
        self.repairWindowSelectedRun = nil
    end
    Print("Deleted run " .. tostring(code or runID) .. (reason and (" (" .. reason .. ")") or "") .. ".")
    self:RefreshAllDisplays()
    return true
end

function Addon:EnsurePlayerCode()
    if not self.db then
        return "X-00000"
    end
    if self.db.playerCode and self.db.playerCode ~= "" then
        return self.db.playerCode
    end

    local alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
    local randomPart = {}
    if math.randomseed then
        math.randomseed((time and time() or 1) + (GetTime and math.floor(GetTime() * 1000) or 0))
    end
    for index = 1, 5 do
        local charIndex = math.random(1, #alphabet)
        randomPart[index] = alphabet:sub(charIndex, charIndex)
    end

    local name = GetShortName(GetUnitFullName("player") or "X")
    local firstLetter = tostring(name):sub(1, 1):upper()
    if firstLetter == "" then
        firstLetter = "X"
    end

    self.db.playerCode = firstLetter .. "-" .. table.concat(randomPart)
    return self.db.playerCode
end

function Addon:GetRunCode(run)
    if not run then
        return nil
    end
    if run.code and run.code ~= "" then
        return run.code
    end

    local base = self:EnsurePlayerCode()
    local sequence = PadLeft(ToBase36(run.id or 0), 4, "0")
    run.code = base .. "-" .. sequence
    return run.code
end

local function NormalizeRunCode(code)
    code = StripWowText(code or ""):upper()
    code = code:gsub("%s+", "")
    return code
end

function Addon:FindRunByCode(code)
    local wanted = NormalizeRunCode(code)
    if wanted == "" then
        return nil
    end

    for _, runID in ipairs(self.db and self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and NormalizeRunCode(self:GetRunCode(run)) == wanted then
            return run
        end
    end
    return nil
end

function Addon:GetEditableRun(runCode)
    if runCode and runCode ~= "" then
        local run = self:FindRunByCode(runCode)
        if run then
            return run
        end
        Print("Run code not found: " .. tostring(runCode))
        return nil
    end
    return self:GetCurrentRun() or self.selectedRunForShare or self:GetLastRun()
end

function Addon:ExtractTrailingRunCode(text)
    text = strtrim(tostring(text or ""))
    local code = text:match("([%w]%-[%w][%w][%w][%w][%w]%-[%w]+)$")
    if code then
        text = strtrim(text:sub(1, #text - #code))
    end
    return text, code
end

function Addon:GetCurrentRun()
    return self:GetRun(self.db and self.db.currentRunID)
end

function Addon:GetLastRun()
    return self:GetRun(self.db and self.db.lastRunID)
end

function Addon:PruneRuns()
    local keep = tonumber(self.db.retainRuns) or 100

    while #self.db.runOrder > keep do
        local oldRunID = table.remove(self.db.runOrder)
        self.db.runs[oldRunID] = nil
    end
end

function Addon:StartRun(source)
    local current = self:GetCurrentRun()
    if current then
        return current
    end

    local snapshot = GetInstanceSnapshot()
    local isTrackedRaid = snapshot.instanceType == "raid" and self.db.trackRaids ~= false
    if snapshot.instanceType ~= "party" and snapshot.difficultyID ~= 205 and not isTrackedRaid then
        Debug("Ignored non-dungeon/raid instance: " .. tostring(snapshot.name) .. " (instanceType=" .. tostring(snapshot.instanceType) .. ", difficultyID=" .. tostring(snapshot.difficultyID) .. ")")
        return nil
    end

    -- Found 2026-09-04 (2nd occurrence, Den of Nalorakk, via CHALLENGE_MODE_COMPLETED this time):
    -- putting this guard only in CheckInstanceState wasn't enough -- RefreshChallengeModeInfo and
    -- MarkRunTimerStarted also call StartRun directly on their own event paths (CHALLENGE_MODE_START/
    -- COMPLETED, LFG_COMPLETION_REWARD), completely bypassing that caller-side check. Moved into
    -- StartRun itself so every call site is covered: if a stray event fires while still standing in
    -- an instance whose key was already resolved (real instanceID match, verified against Blizzard
    -- API docs), don't spawn a new run for it -- it's the same physical instance, not a new key.
    --
    -- Fixed 2026-09-07, per user report: a completed Blinding Vale +10 went entirely unrecorded
    -- after an abandoned +11 in the same session. Root cause -- the guard above never expired. The
    -- user's own follow-up nailed it: "some players will stay on after a dungeon has abandoned or
    -- completed to do it again or another dungeon." Since the party never left the instance, a
    -- genuine NEW keystone attempt (re-inserting a key at the font, CHALLENGE_MODE_START) has the
    -- same instanceID as the just-ended run and was being silently swallowed by this same guard --
    -- StartRun returned nil, GetCurrentRun() stayed nil for the entire +10 attempt, and its eventual
    -- CHALLENGE_MODE_COMPLETED had no run object to complete. The stray-duplicate events this guard
    -- was actually built for (RefreshChallengeModeInfo/MarkRunTimerStarted re-firing moments after
    -- MarkRunCompleted already cleared currentRunID -- see QueueChallengeModeRefresh's 0/0.5s/2s
    -- retries) all land within a couple seconds of the run ending; a real re-key takes a walk to the
    -- font plus a dialogue, always far longer. So the guard now only blocks a same-instance restart
    -- within a short window after the last run ended, instead of forever.
    local lastRun = self.db.lastRunID and self.db.runs[self.db.lastRunID]
    if lastRun and lastRun.instanceID and snapshot.instanceID and lastRun.instanceID == snapshot.instanceID and lastRun.runStatus ~= "Active" then
        local sinceEnded = time() - tonumber(lastRun.endedAt or lastRun.abandonedAt or 0)
        if sinceEnded < 10 then
            Debug(string.format("StartRun: skipping new run (source=%s) -- stray duplicate for already-ended run %s (status=%s), only %ds after it ended.", tostring(source), tostring(lastRun.id), tostring(lastRun.runStatus), sinceEnded))
            return nil
        end
    end

    self.db.nextRunID = (self.db.nextRunID or 0) + 1

    local runID = tostring(self.db.nextRunID)
    local patchInfo = GetClientPatchInfo()
    local mythicPlusSeason = GetEstimatedMythicPlusSeason(patchInfo.version)
    local run = {
        id = runID,
        code = nil,
        instanceName = snapshot.name,
        instanceType = snapshot.instanceType,
        difficultyID = snapshot.difficultyID,
        difficultyName = snapshot.difficultyName,
        challengeLevel = snapshot.challengeLevel,
        keyLevel = snapshot.keyLevel,
        challengeMapID = snapshot.challengeMapID,
        maxPlayers = snapshot.maxPlayers,
        mapID = snapshot.mapID,
        instanceID = snapshot.instanceID,
        zoneText = snapshot.zoneText,
        subZoneText = snapshot.subZoneText,
        clientVersion = patchInfo.version,
        clientBuild = patchInfo.build,
        clientBuildDate = patchInfo.buildDate,
        clientInterfaceVersion = patchInfo.interfaceVersion,
        clientPatch = patchInfo.version,
        expansionName = GetKnownExpansionNameForVersion(patchInfo.version) or (patchInfo.version and ("Patch " .. tostring(patchInfo.version)) or nil),
        mythicPlusSeasonName = mythicPlusSeason,
        mythicPlusSeason = mythicPlusSeason,
        playerGUID = SafeUnitGUID("player"),
        playerName = GetUnitFullName("player"),
        startedAt = time(),
        startedAtText = date("%Y-%m-%d %H:%M:%S"),
        endedAt = nil,
        duration = 0,
        runStatus = "Active",
        completionReason = nil,
        deaths = 0,
        goldLooted = 0,
        repairCost = 0,
        repairs = {},
        moneyLoot = {},
        itemLoot = {},
        chatLog = {},
        members = {},
        memberDeaths = {},
        memberDeathLog = {},
        memberDeathIDs = {},
        nextDeathEventID = 0,
        memberInterrupts = {},
        memberEvents = {},
        encounters = {},
        killedBosses = {},
        bossKills = {},
        bossKillLog = {},
        mobKills = {},
        mobKillLog = {},
        mobKillTotal = 0,
    }

    self.db.runs[runID] = run
    self:GetRunCode(run)
    table.insert(self.db.runOrder, 1, runID)
    self.db.currentRunID = runID
    self.db.lastRunID = runID
    self.deathPending = false

    self:PruneRuns()
    self:CatalogCurrentInstance(run)
    self:QueueRosterRefresh("run started")
    Print("Started run: " .. run.instanceName)
    self:RefreshAllDisplays()
    Debug("Run started by " .. tostring(source))
    return run
end

-- New 2026-09-06, per user follow-up ("just combine those records please. silverfox was a good
-- player") -- confirms several of /dl duplicates' findings really are the same real person under
-- two realm keys, not just name-sharing coincidences. Merges keyB INTO keyA or vice versa
-- (whichever already has richer data survives -- which literal realm string wins doesn't matter,
-- the displayed name is the same either way), rather than requiring the user to know/pick a
-- "correct" realm for cases where that isn't actually known. Idempotent/safe to call with a key
-- that no longer exists (a no-op) -- both this and MergeKnownDuplicatePlayers below can run every
-- load without re-doing anything.
function Addon:MergePlayerProfiles(keyA, keyB)
    if not keyA or not keyB or keyA == keyB or not self.db.playerRatings then
        return
    end
    local profileA = self.db.playerRatings[keyA]
    local profileB = self.db.playerRatings[keyB]
    if not profileA or not profileB then
        return
    end

    local function Richness(p)
        local score = 0
        if p.notes and p.notes ~= "" then
            score = score + 2
        end
        if p.starHistory then
            score = score + #p.starHistory
        end
        if p.rating and p.rating ~= "Okay" then
            score = score + 1
        end
        score = score + (p.groupCount or 0) * 0.01
        return score
    end

    local survivorKey, survivor, mergeKey, merged
    if Richness(profileA) >= Richness(profileB) then
        survivorKey, survivor, mergeKey, merged = keyA, profileA, keyB, profileB
    else
        survivorKey, survivor, mergeKey, merged = keyB, profileB, keyA, profileA
    end

    survivor.groupCount = (survivor.groupCount or 0) + (merged.groupCount or 0)
    if (not survivor.notes or survivor.notes == "") and merged.notes and merged.notes ~= "" then
        survivor.notes = merged.notes
    end
    -- Real rating (Good/Bad) beats an untouched "Okay" default from the other side, rather than
    -- risking a real rating getting silently overwritten by a never-touched default.
    if (not survivor.rating or survivor.rating == "Okay") and merged.rating and merged.rating ~= "Okay" then
        survivor.rating = merged.rating
    end
    if merged.starHistory then
        survivor.starHistory = survivor.starHistory or {}
        for _, entry in ipairs(merged.starHistory) do
            table.insert(survivor.starHistory, entry)
        end
        table.sort(survivor.starHistory, function(a, b) return (a.date or 0) < (b.date or 0) end)
        while #survivor.starHistory > 20 do
            table.remove(survivor.starHistory, 1)
        end
    end
    if survivor.isGuildMember == nil and merged.isGuildMember ~= nil then
        survivor.isGuildMember = merged.isGuildMember
    end
    if survivor.isFrequent == nil and merged.isFrequent ~= nil then
        survivor.isFrequent = merged.isFrequent
    end
    if (merged.lastInstanceAt or 0) > (survivor.lastInstanceAt or 0) then
        survivor.lastInstanceAt = merged.lastInstanceAt
        survivor.lastInstanceName = merged.lastInstanceName
        survivor.lastInstanceType = merged.lastInstanceType
        survivor.lastInstanceDate = merged.lastInstanceDate
        survivor.lastRunID = merged.lastRunID
        survivor.lastClass = merged.lastClass or survivor.lastClass
        survivor.lastRole = merged.lastRole or survivor.lastRole
    end

    self.db.playerRatings[mergeKey] = nil
    if self.dataToolSelectedPlayerKey == mergeKey then
        self.dataToolSelectedPlayerKey = survivorKey
    end
    Print(string.format("Merged duplicate player profile: %s -> %s", mergeKey, survivorKey))
end

-- One-time (but safe to run every load) merge for the specific duplicates the user confirmed are
-- really the same person, per /dl duplicates' findings 2026-09-06. Keys copied exactly from the
-- live SavedVariables (not retyped) to avoid any risk of an encoding mismatch on the accented name.
function Addon:MergeKnownDuplicatePlayers()
    self:MergePlayerProfiles("gily-sargeras", "gily-saurfang")
    self:MergePlayerProfiles("dtdpreacher-stormrage", "dtdpreacher-saurfang")
    self:MergePlayerProfiles("uhtrédx-kel'thuzad", "uhtrédx-saurfang")
    self:MergePlayerProfiles("silverfoxx-frostmourne", "silverfoxx-saurfang")
end

-- New 2026-09-06, per user request ("look for players with the same name and list them please"),
-- prompted by a real case: "Calmviolent" had a profile under the wrong realm (Saurfang instead of
-- Illidan). Confirmed directly against the SavedVariables that this specific one is already fixed
-- -- the existing "edit Realm + Save" flow in Manage Data -> Player (SaveDataToolPlayer) already
-- re-keys and merges a profile when its realm is corrected, so no separate merge tool is needed --
-- this just finds and lists OTHER same-name-different-realm pairs so they can be reviewed/fixed the
-- same way. Read-only -- doesn't change anything itself.
function Addon:FindDuplicatePlayerNames()
    local byName = {}
    for key, profile in pairs(self.db.playerRatings or {}) do
        local name = profile.name or key
        local lname = string.lower(name)
        byName[lname] = byName[lname] or { displayName = name, entries = {} }
        table.insert(byName[lname].entries, { key = key, realm = profile.realm or "Unknown" })
    end

    local groups = {}
    for _, data in pairs(byName) do
        if #data.entries > 1 then
            table.insert(groups, data)
        end
    end
    table.sort(groups, function(a, b) return a.displayName < b.displayName end)

    if #groups == 0 then
        Print("No duplicate player names found across your saved players.")
        return
    end
    Print(string.format("|cffffcc00%d possible duplicate player name(s)|r (same name, different realm) -- if it's really the same person, open Manage Data -> Player, select one, correct the Realm field, and Save to merge them:", #groups))
    for _, data in ipairs(groups) do
        local realms = {}
        for _, entry in ipairs(data.entries) do
            table.insert(realms, entry.realm)
        end
        table.sort(realms)
        Print(string.format("  %s -- %s", data.displayName, table.concat(realms, ", ")))
    end
end

-- One-time backfill (per user request 2026-09-06, "have you recorded these players already...
-- can you allow those players to populate the menu"): LogGroupedPlayers below only applies to
-- runs ending AFTER v0.1.239 shipped -- anyone grouped with before that never got a profile at
-- all. Confirmed directly against the live SavedVariables before writing this: 200 distinct real
-- players (Player-prefixed GUIDs, not Vehicle-/Creature-) appear across existing run history, only
-- 18 had a playerRatings profile. Safe to call on every load (not just once) -- each run's own
-- run.groupLogRecorded flag (set by LogGroupedPlayers) means a run already processed is skipped
-- instantly, so after the first pass this is a fast no-op.
-- verbose: only true from the /dl backfillplayers slash command -- the automatic OnLoaded call
-- stays silent when there's nothing to do, so this doesn't print a "nothing to backfill" message
-- on every single login/reload forever after the first real pass.
function Addon:BackfillGroupedPlayersFromHistory(verbose)
    local processedRuns = 0
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and not run.groupLogRecorded then
            self:LogGroupedPlayers(run)
            processedRuns = processedRuns + 1
        end
    end
    if processedRuns > 0 then
        Print(string.format("Backfilled the grouped-player log from %d previously-untracked run(s).", processedRuns))
        self:RefreshAllDisplays()
    elseif verbose then
        Print("Grouped-player log is already up to date -- nothing to backfill.")
    end
end

-- One-time backfill for a real bug found 2026-09-06 via a direct SavedVariables audit:
-- RemoveDataToolPlayerRunAppearance deletes a removed player's memberDeathLog entries and
-- memberDeaths[*].count, but never subtracted that from run.deaths -- the aggregate counter
-- GetRunDeathTotal treats as authoritative via math.max, so a run's displayed death total stayed
-- permanently inflated by however many deaths the removed player had. Confirmed live: run 104
-- (Kings' Rest) showed run.deaths=9 against only 8 real remaining memberDeathLog entries. The bug
-- itself is fixed at the source (RemoveDataToolPlayerRunAppearance now decrements run.deaths too);
-- this only cleans up runs already left inconsistent by it before that fix existed. Only ever
-- LOWERS run.deaths, never raises it -- a removed player's actual death count is genuinely gone,
-- not just uncounted, so there's nothing to restore it to.
function Addon:BackfillDeathCountConsistency(verbose)
    local fixed = 0
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and not run.deathCountBackfilled then
            self:EnsureMemberDeathTables(run)
            local logCount = #run.memberDeathLog
            local memberSum = 0
            for _, info in pairs(run.memberDeaths) do
                memberSum = memberSum + (tonumber(info and info.count) or 0)
            end
            local correctTotal = math.max(logCount, memberSum)
            local currentTotal = tonumber(run.deaths) or 0
            if currentTotal > correctTotal then
                Debug(string.format("BackfillDeathCountConsistency: run %s (%s) run.deaths %d -> %d", tostring(runID), tostring(run.instanceName), currentTotal, correctTotal))
                run.deaths = correctTotal
                fixed = fixed + 1
            end
            run.deathCountBackfilled = true
        end
    end
    if fixed > 0 then
        Print(string.format("Corrected %d run(s) whose death count was left stale by a since-fixed player-removal bug.", fixed))
        self:RefreshAllDisplays()
    elseif verbose then
        Print("Death counts are already consistent -- nothing to backfill.")
    end
end

-- New 2026-09-06, per user request ("keep a log of all the players i group with"): auto-creates/
-- updates a playerRatings profile for every OTHER member of a run, dungeon or raid, regardless of
-- whether they've ever been manually rated/added. Called once per run (guarded by
-- run.groupLogRecorded) from EndRun, which fires for every run ending -- completed, abandoned, or
-- otherwise -- so this covers both dungeons and raids the same way. Uses the same GetPlayerProfile
-- get-or-create path SaveRatingPopup already uses, so a rating saved later for the same player
-- updates this exact profile rather than creating a second one.
--
-- The "last instance" fields are gated on run.startedAt actually being newer than whatever's
-- already stored (new profile.lastInstanceAt, a raw timestamp kept alongside for this comparison)
-- rather than just overwritten unconditionally -- needed because BackfillGroupedPlayersFromHistory
-- calls this once per run across a player's ENTIRE history in runOrder's newest-first order, and an
-- unconditional overwrite would let an older run processed later in that pass clobber the correct
-- most-recent instance a newer run already set. groupCount still increments unconditionally either
-- way, since that's a total count, not a "latest" value.
function Addon:LogGroupedPlayers(run)
    if not run or not run.members or run.groupLogRecorded then
        return
    end
    run.groupLogRecorded = true
    local playerFullName = GetUnitFullName and GetUnitFullName("player") or nil
    for _, member in ipairs(run.members) do
        if member.name and member.name ~= playerFullName then
            local profile = self:GetPlayerProfile(member.name)
            if profile then
                profile.groupCount = (profile.groupCount or 0) + 1
                if not profile.lastInstanceAt or (run.startedAt or 0) > profile.lastInstanceAt then
                    profile.lastInstanceAt = run.startedAt
                    profile.lastInstanceName = run.instanceName
                    profile.lastInstanceType = run.instanceType
                    profile.lastInstanceDate = run.startedAtText
                    profile.lastRunID = run.id
                    if member.class then
                        profile.lastClass = member.class
                    end
                    if member.role then
                        profile.lastRole = member.role
                    end
                end
            end
        end
    end
end

function Addon:EndRun(reason)
    local run = self:GetCurrentRun()
    if not run then
        return
    end

    self:UpdateGroupRoster("run ended")
    local snapshot = GetInstanceSnapshot()
    local noLongerInSameDungeon = not IsTrackedDungeonInstance() or snapshot.name ~= run.instanceName
    -- Found 2026-09-04: this used to delete on RunHasBossKill/RunHasMobKill alone -- but trash-mob
    -- kill tracking has been unreliable for a large part of this addon's history (the Secret Value
    -- restriction on hostile-unit GUIDs during M+, still only partially mitigated), so a real run
    -- where the group fought and killed trash but left before downing a boss had RunHasMobKill
    -- wrongly return false, and got silently auto-deleted as if nothing happened. Confirmed live:
    -- ~20 run IDs missing entirely from both runOrder and the runs table. Duration is a far more
    -- robust signal for "did anything actually happen here" than a kill-tracking path already
    -- known to be unreliable -- a run that lasted under 20 seconds genuinely didn't have time for
    -- meaningful activity regardless of what got recorded; one that ran for minutes almost
    -- certainly did, recorded kills or not. Deleting real data is worse than keeping a rare true
    -- empty entry around, so this only deletes when ALL THREE signals agree there was nothing.
    if noLongerInSameDungeon and not self:RunHasBossKill(run) and not self:RunHasMobKill(run) and GetRunDuration(run) < 20 then
        Debug("Deleting run: no activity before leaving (" .. tostring(run.instanceName) .. ")")
        self:DeleteRun(run, "no activity before leaving")
        self.deathPending = false
        return
    end

    -- Real activity happened (survived the delete check above), so this is a genuine grouped run --
    -- log the party regardless of completion status, and prompt for ratings if the Completed path
    -- (MarkRunCompleted) hasn't already done so. Covers raids and partial/abandoned runs, which
    -- rarely hit MarkRunCompleted's "all required bosses died" trigger, per user request ("at the
    -- end of the dungeon or raid... have the reputation popup window").
    self:LogGroupedPlayers(run)
    self:PromptPlayerRatings(run)

    if run.runStatus ~= "Completed" and run.runStatus ~= "CompletedOvertime" then
        run.runStatus = "Abandoned"
        run.completionReason = reason or "left before completion"
        run.leftWithoutCompletion = true
        run.abandonedAt = time()
        run.abandonedReason = reason or "left before completion"
    end
    run.endedAt = time()
    run.endedAtText = date("%Y-%m-%d %H:%M:%S")
    run.duration = GetRunDuration(run)
    self.db.currentRunID = nil
    self.db.lastRunID = run.id
    self.deathPending = false

    Print(string.format(
        "Ended %s: %d death(s), %s repairs.",
        run.instanceName or "run",
        self:GetRunDeathTotal(run),
        FormatMoneyIcons(run.repairCost or 0)
    ))
    self:RefreshAllDisplays()
    Debug("Run ended by " .. tostring(reason))
end

-- New 2026-09-05, per a sibling-addon comparison (MythicHelper registers this specifically to
-- reset its own timer state): CHALLENGE_MODE_RESET is Blizzard's purpose-built signal for "this
-- keystone attempt just ended/reset" -- a more precise, direct trigger than inferring an abandon
-- from a zone change (CheckInstanceState via PLAYER_ENTERING_WORLD), which this session already
-- found real bugs in (a genuine completed run getting mis-marked Abandoned via that path). This is
-- additive, not a replacement -- EndRun already no-ops harmlessly if the run is already Completed
-- or already ended, so having both signals can't double-end or conflict with anything.
function Addon:HandleChallengeModeReset(reason)
    local run = self:GetCurrentRun()
    if not run or not self:IsMythicPlusRun(run) then
        return
    end
    self:EndRun(reason or "CHALLENGE_MODE_RESET")
end

function Addon:CheckInstanceState(source)
    if IsTrackedDungeonInstance() then
        local current = self:GetCurrentRun()
        local snapshot = GetInstanceSnapshot()

        if current and current.instanceName ~= snapshot.name then
            self:EndRun("instance changed")
            self:StartRun(source or "instance changed")
        elseif not current then
            self:StartRun(source or "instance detected")
        end
    elseif self:GetCurrentRun() then
        self:EndRun(source or "left dungeon")
    end
end

function Addon:MarkRunTimerStarted(source)
    local run = self:GetCurrentRun() or self:StartRun(source or "timer started")
    if not run then
        return
    end

    local startedAt = time()
    run.timerStartedAt = startedAt
    run.timerStartedAtText = date("%Y-%m-%d %H:%M:%S")
    run.challengeStartedAt = startedAt
    run.challengeStartedAtText = run.timerStartedAtText
    run.duration = 0
    Debug("Run timer started by " .. tostring(source or "timer event") .. " for " .. tostring(run.instanceName or "run"))
    self:RefreshAllDisplays()
end

function Addon:QueueInstanceScan(source)
    if self:IsUiLocked() then
        self:MarkUiDirty()
        self.pendingInstanceScan = source or "combat deferred scan"
        return
    end

    self.pendingInstanceScan = nil
    self:CheckInstanceState(source)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.7, function()
            Addon:CheckInstanceState((source or "scan") .. " delayed")
        end)
        C_Timer.After(2, function()
            Addon:CheckInstanceState((source or "scan") .. " settled")
        end)
    end
end

function Addon:RefreshChallengeModeInfo(reason)
    local run = self:GetCurrentRun()
    if not run then
        if IsTrackedDungeonInstance() then
            run = self:StartRun(reason or "challenge mode detected")
        else
            return
        end
    end
    if not run then
        return
    end

    local snapshot = GetInstanceSnapshot()
    local changed = false

    if snapshot.challengeLevel and snapshot.challengeLevel > 0 and run.challengeLevel ~= snapshot.challengeLevel then
        run.challengeLevel = snapshot.challengeLevel
        run.keyLevel = snapshot.challengeLevel
        changed = true
    end
    if snapshot.keyLevel and snapshot.keyLevel > 0 and run.keyLevel ~= snapshot.keyLevel then
        run.keyLevel = snapshot.keyLevel
        run.challengeLevel = snapshot.keyLevel
        changed = true
    end
    if snapshot.challengeMapID and run.challengeMapID ~= snapshot.challengeMapID then
        run.challengeMapID = snapshot.challengeMapID
        changed = true
    end
    if snapshot.challengeMapID and not run.mythicPlusTimeLimitSeconds then
        local timeLimit = GetChallengeMapTimeLimitSeconds(snapshot.challengeMapID)
        if timeLimit then
            run.mythicPlusTimeLimitSeconds = timeLimit
            changed = true
        end
    end
    if snapshot.difficultyID and run.difficultyID ~= snapshot.difficultyID then
        run.difficultyID = snapshot.difficultyID
        changed = true
    end
    if snapshot.difficultyName and run.difficultyName ~= snapshot.difficultyName then
        run.difficultyName = snapshot.difficultyName
        changed = true
    end

    if changed then
        Debug(string.format(
            "Mythic+ info updated: %s +%s (%s)",
            run.instanceName or "unknown dungeon",
            tostring(run.challengeLevel or 0),
            tostring(reason or "refresh")
        ))
        self:RefreshAllDisplays()
    end
end

function Addon:QueueChallengeModeRefresh(reason)
    self:RefreshChallengeModeInfo(reason)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            Addon:RefreshChallengeModeInfo(reason)
        end)
        C_Timer.After(2, function()
            Addon:RefreshChallengeModeInfo(reason)
        end)
    end
end


function Addon:UpdateGroupRoster(reason)
    local latestRoster = GetGroupRoster()
    self:WarnForRatedPlayers(latestRoster)
    self:BroadcastPlayerReports(latestRoster)

    if IsInGroup and IsInGroup() then
        self:BroadcastMythicPlusSync(reason or "roster update")
    else
        self.partyMythicPlusInfo = nil
    end

    local run = self:GetCurrentRun()
    if not run then
        return
    end
    if run.runStatus == "Completed" or run.endedAt then
        Debug("Roster update ignored for finished run: " .. tostring(reason or "roster update"))
        return
    end

    run.members = MergeRoster(run.members, latestRoster)
    run.currentMemberCount = #latestRoster
    run.rosterUpdatedAt = time()
    run.rosterUpdatedAtText = date("%Y-%m-%d %H:%M:%S")
    run.memberEvents = run.memberEvents or {}
    table.insert(run.memberEvents, {
        time = run.rosterUpdatedAt,
        timeText = run.rosterUpdatedAtText,
        reason = reason or "roster update",
        count = #run.members,
        observed = #latestRoster,
        members = run.members,
    })

    Debug(string.format("Roster updated: %d member(s) (%d ever seen this run)", #latestRoster, #run.members))
    self:RefreshAllDisplays()
end

-- Read-only presentation lookup: never creates or changes a reputation record.
function Addon:GetApplicantReputation(member, preview)
    if preview then return member.rating, member.groupCount, member.notes end
    local key = GetPlayerProfileKey(member.name)
    local profile = key and self.db and self.db.playerRatings and self.db.playerRatings[key]
    if profile then return profile.rating, profile.groupCount, profile.notes end
    return member.rating, member.groupCount, member.notes
end

function Addon:GetPlayerProfile(name)
    local key = GetPlayerProfileKey(name)
    if not key then
        return nil, nil
    end
    self.db.playerRatings = self.db.playerRatings or {}
    self.db.playerRatings[key] = self.db.playerRatings[key] or {}
    local profile = self.db.playerRatings[key]
    local player, realm = GetPlayerRealmName(name)
    profile.name = profile.name or player
    profile.realm = profile.realm or realm
    profile.rating = profile.rating or "Okay"
    profile.notes = profile.notes or ""
    return profile, key
end

-- Which of the user's own characters was logged in when a rating was recorded -- pure bookkeeping
-- for the user's own reference (per user request, 2026-09-16: "is it possible when logging the
-- data to just add players character name Hikari and call that?"). This is NOT a way to detect an
-- applicant's own alts -- nothing can do that, since the game never exposes that data for a
-- stranger (confirmed this same session). MPlusLedgerDB is account-wide (declared as plain
-- `SavedVariables` in the .toc, not `SavedVariablesPerCharacter` -- checked directly), so a rating
-- is already visible no matter which of the user's OWN characters is logged in; this field just
-- additionally records which one happened to be active when the rating was actually set.
function Addon:StampProfileRecordedBy(profile)
    if not profile then
        return
    end
    local myName = (GetUnitFullName and GetUnitFullName("player")) or (UnitName and UnitName("player"))
    if myName and not IsSecret(myName) then
        profile.lastRatedByCharacter = GetShortName(myName)
    end
end

-- Direct rating set for the Applicant Alert popup below -- unlike the post-run star-rating flow
-- (which converts 1-5 stars via StarsToRatingCategory and appends to starHistory), a quick apply-
-- stage decision has no stars to convert and isn't a performance review of a completed run, so it
-- just sets the same Good/Okay/Bad category directly.
function Addon:SetPlayerRatingQuick(name, rating)
    local profile = self:GetPlayerProfile(name)
    if not profile then
        return
    end
    profile.rating = rating
    self:StampProfileRecordedBy(profile)
    profile.updatedAt = time()
    profile.updatedAtText = date("%Y-%m-%d %H:%M:%S")
end

-- Rating metadata shared between the Player Menu table, the edit form's dropdown, and the
-- notification messages below -- one place to keep the display label/color/icon in sync. The
-- STORED value (profile.rating) stays "Good"/"Okay"/"Bad" -- only ever the display label changed
-- (user asked for friendlier names, picked "Trusted/Neutral/Avoid" 2026-09-04) -- so no saved data
-- needs migrating and every existing `profile.rating == "Bad"` style check keeps working untouched.
-- Icons are Blizzard's own ready-check textures (verified against the live FrameXML source,
-- ReadyCheck.lua/READY_CHECK_READY_TEXTURE et al.), not custom art.
local RATING_META = {
    Good = { label = "Trusted", color = "|cff00ff00", bg = { 0.05, 0.28, 0.08 }, border = { 0.25, 0.9, 0.35 }, icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
    Okay = { label = "Neutral", color = "|cffffff00", bg = { 0.30, 0.26, 0.04 }, border = { 0.9, 0.8, 0.25 }, icon = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
    Bad = { label = "Avoid", color = "|cffff5555", bg = { 0.34, 0.05, 0.05 }, border = { 0.95, 0.3, 0.3 }, icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
}
local function GetRatingMeta(rating)
    return RATING_META[rating or "Okay"] or RATING_META.Okay
end
local function GetRatingIconString(rating, size)
    return string.format("|T%s:%d|t", GetRatingMeta(rating).icon, size or 14)
end

-- Real texture icons, not text -- found live 2026-09-06 (user screenshot): the Unicode star glyphs
-- (U+2605/U+2606) this used to render as plain FontString text came out as tofu boxes in-game.
-- WoW's default client font doesn't actually include glyphs for those characters, contrary to what
-- the old comment here assumed without checking. Generated programmatically (Python + Pillow, same
-- approach as the PieChart wedge texture) as plain white silhouettes, tinted via SetVertexColor at
-- render time, rather than guessing a built-in Blizzard atlas name that might not exist either.
local RATING_STAR_FILLED_TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\Rating\\rating_star_filled.png"
local RATING_STAR_EMPTY_TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\Rating\\rating_star_empty.png"

-- Maps a 1-5 star pick to the existing Good/Okay/Bad category above, per the user's own thresholds
-- (2026-09-05): "1 star is avoid, 2-3 stars neutral, 4-5 stars good or excellent".
local function StarsToRatingCategory(stars)
    if stars <= 1 then
        return "Bad"
    elseif stars <= 3 then
        return "Okay"
    end
    return "Good"
end

-- Shared by roster-join warnings and the LFG applicant check below -- one throttle table, one
-- notification style, regardless of which stage ("joined the group" vs. "applied to your group")
-- caught the Bad-rated player.
-- Returns true only when it actually fired a new warning (not throttled/not rated Bad) -- lets
-- CheckLFGApplicantsForRatedPlayers below know whether it's worth also pulling the applicant list
-- on screen for the user.
function Addon:WarnIfPlayerIsBad(name, context)
    if not (self.db and self.db.playerRatings and name) then
        return false
    end
    local key = GetPlayerProfileKey(name)
    local profile = key and self.db.playerRatings[key]
    if not (profile and profile.rating == "Bad") then
        return false
    end
    local now = time()
    self.playerWarningThrottle = self.playerWarningThrottle or {}
    if (now - (self.playerWarningThrottle[key] or 0)) <= 60 then
        return false
    end
    self.playerWarningThrottle[key] = now
    local displayName = (profile.name or GetShortName(name)) .. ((profile.realm and profile.realm ~= "") and ("-" .. profile.realm) or "")
    local note = profile.notes and profile.notes ~= "" and (" - " .. profile.notes) or ""
    local message = GetRatingIconString("Bad", 16) .. " M+ Ledger warning: " .. displayName .. " is marked " .. GetRatingMeta("Bad").label .. (context and (" (" .. context .. ")") or "") .. note
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(message, 1, 0.12, 0.12, 1)
    end
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0, b = 0 })
    end
    if PlaySound then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
    Print(message)
    return true
end

function Addon:WarnForRatedPlayers(roster)
    if not (self.db and self.db.playerRatings) then
        return
    end
    for _, member in ipairs(roster or {}) do
        self:WarnIfPlayerIsBad(member and member.name, "joined the group")
    end
end

-- Player-report broadcast, added 2026-09-04 per user request: unlike WarnIfPlayerIsBad (local-only,
-- Bad-rated players only), this covers every rating tier plus the never-rated case, and is meant to
-- be seen by the whole party/raid, not just the player running the addon. Deliberately does NOT
-- read the profile through GetPlayerProfile -- that function auto-creates and permanently saves a
-- default "Okay" entry the instant it's called, which would make "never actually reviewed in
-- Manage Data" indistinguishable from "reviewed and rated Okay." Reading self.db.playerRatings[key]
-- directly means a nil entry reliably means "no play history," matching the user's own wording.
-- forChat: pass true when this string is going into SendChatMessage. Confirmed live via a real
-- BroadcastPlayerReport failure caught in the debug log 2026-09-07: SendChatMessage rejects the
-- |T texture:size|t icon markup outright ("Invalid escape code in chat message") -- that escape
-- code is a client-side FontString rendering feature, not part of the small safe set (|c, |r, |H
-- hyperlinks) SendChatMessage actually allows across the network. It rendered fine wherever this
-- string only ever went through local Print(), which is why this went unnoticed until a rated
-- player (the only case that adds the icon at all -- see the "no profile" branch below, which
-- never did) actually got reported to a live party.
function Addon:GetPlayerReportMessage(name, forChat, role, classToken, itemLevel, omitNamePrefix)
    if not name then
        return nil
    end
    local key = GetPlayerProfileKey(name)
    local profile = key and self.db and self.db.playerRatings and self.db.playerRatings[key]
    local myName = (GetUnitFullName and GetUnitFullName("player")) or (UnitName and UnitName("player")) or "me"
    local displayName = GetShortName(name)
    -- Role, added per user request 2026-09-08 -- assignedRole comes from
    -- C_LFGList.GetApplicantMemberInfo (applicant path) or the roster's own member.role (join
    -- path), both already the standard TANK/HEALER/DAMAGER/NONE tokens GetRoleLabel expects.
    -- Class/item level, added same day, same request: classToken is the raw English UnitClass-
    -- style token (e.g. "WARRIOR") from GetApplicantMemberInfo's own `class` return (apply path)
    -- or GetGroupRoster's `member.class` (join path, from UnitClass directly) -- kept as the raw
    -- token rather than a pre-localized string so it can be both localized AND colored here from
    -- one source, via the same RAID_CLASS_COLORS[token] this file already uses for FontStrings
    -- (PromptPlayerRatings). |c.../|r IS one of the escape codes SendChatMessage actually allows
    -- across the network (confirmed 2026-09-07 chasing the |T icon-markup rejection -- |c, |r, |H
    -- hyperlinks are the safe set), so this colors correctly in the real broadcast, not just the
    -- local Print(). Item level: live item level for an existing party member needs a full
    -- NotifyInspect/INSPECT_READY round trip, which isn't built, so itemLevel is simply nil (and
    -- omitted) on the join path rather than faked.
    -- Role colors, per user request 2026-09-09: DPS red, Heals white, Tank blue -- the same |c
    -- escape codes already confirmed safe across SendChatMessage (see the class-color comment
    -- below), so this colors correctly in the real broadcast too, not just the local Print().
    local ROLE_REPORT_COLORS = { DAMAGER = "|cffff2020", HEALER = "|cffffffff", TANK = "|cff2090ff" }
    local roleLabel = (role and role ~= "NONE") and GetRoleLabel(role) or nil
    local infoParts = {}
    if roleLabel then
        local roleColor = ROLE_REPORT_COLORS[role]
        table.insert(infoParts, roleColor and (roleColor .. roleLabel .. "|r") or roleLabel)
    end
    if classToken and classToken ~= "" then
        local classLabel = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or classToken
        local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
        -- RAID_CLASS_COLORS[token].colorStr already IS the full 8-hex-char string ready to follow
        -- |c directly (e.g. "ff9482c9" for Warlock -- confirmed via Blizzard's own convention,
        -- not assumed) -- it already includes the alpha byte. Prepending "|cff" here double-counts
        -- that alpha byte, so the color escape only consumes the first 8 of the resulting 10 hex
        -- characters and the leftover 2 characters render as literal text right before the class
        -- name (e.g. "eeWarlock") -- exactly the bug the user spotted in a live chat screenshot,
        -- 2026-09-09. Fixed: use colorStr directly after a bare |c, no extra "ff".
        local classText = (classColor and classColor.colorStr) and ("|c" .. classColor.colorStr .. classLabel .. "|r") or classLabel
        table.insert(infoParts, classText)
    end
    local ilvl = tonumber(itemLevel)
    if ilvl and ilvl > 0 then
        table.insert(infoParts, "ilvl " .. ilvl)
    end
    local infoText = #infoParts > 0 and (" (" .. table.concat(infoParts, ", ") .. ")") or ""
    -- omitNamePrefix (added 2026-09-16 for the redesigned Applicant Alert panel): that panel now
    -- renders name/role/class/ilvl itself as actual icons/colored text in its own row header,
    -- rather than needing them embedded in this string -- true strips just that leading identity
    -- portion so the panel isn't showing the same name/role/class/ilvl twice. Every existing caller
    -- omits this argument, so its behavior is completely unchanged for them.
    local namePrefix = omitNamePrefix and "" or (displayName .. infoText)
    if not profile then
        return string.format("%shas no play history with %s.", namePrefix ~= "" and (namePrefix .. " ") or "", GetShortName(myName))
    end
    local rating = profile.rating or "Okay"
    local reason = (profile.notes and profile.notes ~= "") and profile.notes or "no reason given"
    local recommend = (rating == "Bad") and "Decline" or "Accept"
    local groupCount = tonumber(profile.groupCount) or 0
    local timesPlayed = groupCount == 1 and "1 time" or (groupCount .. " times")
    local prefix = forChat and "" or (GetRatingIconString(rating, 16) .. " ")
    -- Rating label already colored via RATING_META.color (Trusted green/Neutral yellow/Avoid red)
    -- -- was defined but never actually used here before. "recommend" colored to match the
    -- addon's own established section-label gold (|cffffcc00, used throughout this file); Accept/
    -- Decline colored green/red to parallel Trusted/Avoid, since recommend is literally derived
    -- from rating == "Bad" a few lines up. All per user request 2026-09-09.
    local ratingMeta = GetRatingMeta(rating)
    local coloredRatingLabel = ratingMeta.color .. ratingMeta.label .. "|r"
    local recommendColor = (recommend == "Decline") and "|cffff5555" or "|cff00ff00"
    local coloredRecommend = recommendColor .. recommend .. "|r"
    -- "Played with <X>" now names whichever of the user's own characters actually recorded this
    -- rating (profile.lastRatedByCharacter, see StampProfileRecordedBy), not whichever character
    -- happens to be logged in right now -- per user clarification, 2026-09-16: the account-wide
    -- alt-sharing this addon already does was never in question, but the message text itself was
    -- still naming the CURRENT character even when a different one of the user's own alts is the
    -- one that actually played with this person. Falls back to the current character for a profile
    -- that predates this field (nothing else to show).
    local playedWithName = (profile.lastRatedByCharacter and profile.lastRatedByCharacter ~= "") and profile.lastRatedByCharacter or GetShortName(myName)
    return string.format("%s%s%sreported as %s for reason: %s -- |cffffcc00recommend|r %s. (Played with %s: %s)", prefix, namePrefix, namePrefix ~= "" and " " or "", coloredRatingLabel, reason, coloredRecommend, playedWithName, timesPlayed)
end

-- One broadcast per player per game session (self.reportedPlayers is never cleared) rather than a
-- short time throttle -- once the party has been told, repeating it every time GROUP_ROSTER_UPDATE
-- happens to refire for the same still-grouped player would spam the same line over and over.
--
-- Fixed 2026-09-07, per user report/screenshot ("i am not seeing the players that are same being
-- sent to the party"): reportedPlayers[key] used to get locked BEFORE the channel check below ever
-- ran. Right after accepting/forming a group, GROUP_ROSTER_UPDATE (and this function, called
-- synchronously from it via UpdateGroupRoster) can fire before IsInGroup() itself reflects the new
-- group state -- confirmed exactly by the screenshot: the local "reported as Trusted" print appeared
-- (proving this ran), but no PARTY chat line went out, meaning `channel` was nil on that call. That
-- first call locked the key anyway, so the 1s/3s follow-up passes QueueRosterRefresh already makes
-- (which would have seen a real channel by then) found the key already "reported" and skipped
-- silently -- permanently starving that player of ever actually being broadcast for the session.
-- Now only locks the key once a real channel was available to send on.
-- Gating moved to callers 2026-09-08 (BroadcastPlayerReports for the join path,
-- CheckLFGApplicantsForRatedPlayers for the apply path) so the "on join" and "on apply" toggles
-- can be controlled independently, per user request -- previously one shared flag governed both.
-- sendToChat (added same day, per user request "have the...request to join still show but do not
-- broadcast it"): decouples the local Print (always happens, this addon's own on-screen record of
-- who applied/joined) from the actual party/raid SendChatMessage. Callers pass false to keep this
-- addon's own visibility without telling the rest of the group -- the reportedPlayers dedupe lock
-- still applies either way (once shown locally, not shown again this session), just without the
-- "wait for a real channel" nuance below, which only matters when actually sending to chat.
function Addon:BroadcastPlayerReport(name, role, classToken, itemLevel, sendToChat)
    if not (self.db and name) then
        return
    end
    local key = GetPlayerProfileKey(name)
    if not key then
        return
    end
    self.reportedPlayers = self.reportedPlayers or {}
    if self.reportedPlayers[key] then
        return
    end

    local message = self:GetPlayerReportMessage(name, false, role, classToken, itemLevel)
    if not message then
        return
    end

    if sendToChat then
        local channel = nil
        if IsInRaid and IsInRaid() then
            channel = "RAID"
        elseif IsInGroup and IsInGroup() then
            channel = "PARTY"
        end
        if channel then
            self.reportedPlayers[key] = true
            if SendChatMessage then
                -- forChat=true strips the |T icon:size|t markup GetPlayerReportMessage otherwise
                -- adds -- SendChatMessage rejects that escape code outright (confirmed live, see
                -- the comment on GetPlayerReportMessage). The icon-bearing version below is only
                -- ever used locally.
                local chatMessage = self:GetPlayerReportMessage(name, true, role, classToken, itemLevel) or message
                local ok, err = pcall(SendChatMessage, chatMessage, channel)
                if not ok then
                    Debug("BroadcastPlayerReport: SendChatMessage(" .. channel .. ") failed: " .. tostring(err))
                end
            end
        end
    else
        self.reportedPlayers[key] = true
    end
    Print(message)
end

function Addon:BroadcastPlayerReports(roster)
    if not self.db then
        return
    end
    if self.db.broadcastPlayerReports ~= true then
        return
    end
    local myName = GetUnitFullName and GetUnitFullName("player")
    for _, member in ipairs(roster or {}) do
        if member and member.name and member.name ~= myName then
            -- member.class is GetGroupRoster's raw English UnitClass token (e.g. "WARRIOR") --
            -- passed straight through; GetPlayerReportMessage localizes and colors it from that
            -- token itself. No item level here -- see the comment on GetPlayerReportMessage.
            -- sendToChat=true: this whole function already early-returned above unless
            -- broadcastPlayerReports is on, so by this point actually sending is the right call.
            self:BroadcastPlayerReport(member.name, member.role, member.class, nil, true)
        end
    end
end

-- CORRECTED 2026-09-12 (see the Applicant Alert panel below): "true auto-decline/auto-invite isn't
-- possible" was right about full automation but wrong about a real popup click. HW-event-gated
-- functions like InviteApplicant/DeclineApplicant CAN be called from an addon's OWN button OnClick
-- -- the restriction is "must originate from an actual hardware click", not "must be Blizzard's own
-- frame". Verified against a real published addon (OakLFGSorter, github.com/Smokenoaken/
-- OakLFGSorter) that does exactly this from its own custom row buttons. FocusLFGApplicationViewer
-- itself is still kept below as a fallback for anything the popup doesn't cover, but it's no longer
-- the primary mechanism.
function Addon:FocusLFGApplicationViewer()
    local ok = pcall(function()
        if PVEFrame_ShowFrame then
            PVEFrame_ShowFrame("GroupFinderFrame")
        end
    end)
    if not ok then
        Debug("FocusLFGApplicationViewer: PVEFrame_ShowFrame unavailable or failed.")
    end
end

-- Applicant Alert panel, per user request ("add a popup that shows people applying... Red X for
-- avoid, Green tick for accept, [yellow] for the neutral"). Three real buttons per row, each a
-- genuine hardware click, so each can safely call the protected Invite/DeclineApplicant functions
-- (see the corrected comment on FocusLFGApplicationViewer above) as well as record a rating in one
-- motion -- confirmed as the intended design with the user before building (2026-09-12): Accept
-- invites AND rates Trusted, Avoid declines AND rates Avoid, Not Sure only rates Neutral and
-- leaves the application pending in Blizzard's own list for a manual decision later.
--
-- REVISED 2026-09-16 per user report (with screenshots): this used to be one Blizzard StaticPopup
-- per newly-seen applicantID. StaticPopup does stack multiple dialogs correctly, but each one still
-- has to be dismissed individually before the next is visible -- when several people apply within
-- moments of each other (the screenshots showed six), that meant reading and clicking through six
-- separate stacked popups one at a time instead of seeing everyone who needed a decision at once.
-- Replaced with a single custom panel holding one row per currently-pending applicant, all visible
-- together; each row keeps its own three real Button widgets, so the hardware-click requirement
-- for InviteApplicant/DeclineApplicant is still satisfied per-row exactly as it was per-popup
-- before (same technique verified against OakLFGSorter, github.com/Smokenoaken/OakLFGSorter).
--
-- REDESIGNED AGAIN 2026-09-16, same day, per user feedback on the live panel (with screenshots
-- and annotations): icon buttons instead of text buttons, a role icon instead of a role name,
-- Mythic+ score colored to match Blizzard's own UI, smaller rows, and a scrollbar. All layout
-- numbers below are grouped into one table (APPLICANT_LAYOUT) rather than a dozen separate
-- top-level locals -- see STATUS.md's "CRITICAL" note on the 200-local-variable compile limit this
-- file has hit once already; a redesign this size is exactly the kind of change that note warns
-- about.
local APPLICANT_LAYOUT = {
    width = 460,
    maxHeight = 460,
    rowPool = 20,
    maxMembersPerRow = 5,
    rowPadding = 6,
    rowGap = 6,
    memberHeaderHeight = 16,
    memberStatusHeight = 22,
    memberBlockGap = 1,
    memberRowGap = 2,
    commentHeight = 16,
    footerHeight = 30,
    iconButtonSize = 22,
    closeButtonSize = 24,
}
APPLICANT_LAYOUT.memberBlockHeight = APPLICANT_LAYOUT.memberHeaderHeight + APPLICANT_LAYOUT.memberBlockGap + APPLICANT_LAYOUT.memberStatusHeight

-- roleicon-tiny-<role> atlases, confirmed via a real AtlasID reference (added patch 6.0.2, still
-- present in retail) before use, not guessed. The older, commonly-referenced
-- GetTexCoordsForRoleSmallCircle helper was checked and found REMOVED from the modern API entirely
-- -- using it would have silently rendered a blank icon rather than erroring, exactly the kind of
-- failure this project has learned (the hard way, more than once) to verify against before shipping.
local APPLICANT_ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
local function SetApplicantRoleIcon(texture, role)
    local atlas = role and role ~= "NONE" and APPLICANT_ROLE_ATLAS[role]
    if not atlas then
        texture:Hide()
        return
    end
    local ok = pcall(texture.SetAtlas, texture, atlas, false)
    if not ok then
        texture:Hide()
        return
    end
    texture:Show()
end

-- Matches the exact color Blizzard's own UI uses for a given Mythic+ score, read directly from
-- Blizzard's own API rather than hand-coded thresholds -- the user's own guessed bands (white/
-- green/purple/orange) skipped a tier, and this project has been burned before by hand-replicating
-- data Blizzard already exposes directly (see the Enemy Forces removal above). Falls back to plain
-- white if the API is unavailable, secret, or returns something unexpected.
local function GetApplicantScoreColor(score)
    if not score or (issecretvalue and issecretvalue(score)) then
        return 1, 1, 1
    end
    if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        local ok, color = pcall(C_ChallengeMode.GetDungeonScoreRarityColor, score)
        if ok and type(color) == "table" and type(color.r) == "number" then
            return color.r, color.g, color.b
        end
    end
    return 1, 1, 1
end

-- Oceanic Time Zone realms (US-region realms physically hosted for Australia/NZ players), per
-- Wowpedia's own "Category:Oceanic Time Zone servers" list (checked 2026-09-29). There's no
-- addon-facing API that reports an arbitrary applicant's realm region, so this stays a maintained
-- static list rather than a guess -- same reasoning as GetApplicantScoreColor above about not
-- hand-replicating data that could silently drift out of date.
local OCEANIC_REALMS = {
    ["Aman'Thul"] = true, ["Barthilas"] = true, ["Caelestrasz"] = true, ["Dath'Remar"] = true,
    ["Dreadmaul"] = true, ["Frostmourne"] = true, ["Gundrak"] = true, ["Jubei'Thos"] = true,
    ["Khaz'goroth"] = true, ["Saurfang"] = true, ["Thaurissan"] = true,
}

-- Per user request 2026-09-29 ("add the server name and the server location and colour... Red for
-- America, Green for Australia or Oceanic servers, Orange for Europe" -- Europe changed to yellow 2026-10-08). Group Finder applicants
-- are always from the player's own account region (it's region-locked), so this only ever really
-- splits US-mainland vs. Oceanic realms for a US-region player, or shows plain Europe orange for an
-- EU-region player -- the EU/other branches are kept for correctness rather than assuming every
-- player is on a US account.
local function GetServerRegionColor(realm)
    if not realm or realm == "" then
        return "?", 0.6, 0.6, 0.6
    end
    if OCEANIC_REALMS[realm] then
        return "OCE", 0.2, 0.85, 0.3 -- green
    end
    local regionOk, region = pcall(GetCurrentRegionName)
    region = (regionOk and region) or "US"
    if region == "EU" then
        return "EU", 1, 0.85, 0.1 -- yellow (user request 2026-10-08, was orange)
    elseif region == "US" then
        return "US", 0.9, 0.2, 0.2 -- red
    end
    return region, 0.6, 0.6, 0.6
end
Addon.GetServerRegionColor = GetServerRegionColor

-- Plain icon button (no text, no colored backdrop) -- the ready-check textures already read as
-- accept/avoid/neutral on their own, matching how Blizzard's own UI presents these same three
-- icons elsewhere, so a text label underneath would be redundant; a tooltip covers anyone unsure.
local function CreateApplicantAlertIconButton(parent, texturePath, size, tooltipText)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:SetNormalTexture(texturePath)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.25)
    button:SetHighlightTexture(highlight)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

-- One applicant's info block within a row: role icon, class-colored name, item level, Mythic+
-- score (colored via GetApplicantScoreColor), then a rating icon + status/reason text underneath.
-- Rendered as actual icons/colored widgets instead of one flat pre-colored string (the old design)
-- so smaller rows can drop the role/rating NAMES entirely and still read at a glance.
local function CreateApplicantAlertMemberBlock(row)
    local block = CreateFrame("Frame", nil, row)
    -- No anchor set here -- RefreshApplicantAlertPanel positions this every refresh via
    -- TOPLEFT/TOPRIGHT at a computed Y (blockY), since a row's member count varies.
    block:SetHeight(APPLICANT_LAYOUT.memberBlockHeight)

    block.roleIcon = block:CreateTexture(nil, "ARTWORK")
    block.roleIcon:SetSize(14, 14)
    block.roleIcon:SetPoint("TOPLEFT", 0, -1)

    block.name = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    block.name:SetPoint("LEFT", block.roleIcon, "RIGHT", 4, 0)
    block.name:SetPoint("TOP", block.roleIcon, "TOP", 0, 0)

    block.ilvl = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    block.ilvl:SetPoint("LEFT", block.name, "RIGHT", 8, 0)
    block.ilvl:SetPoint("TOP", block.roleIcon, "TOP", 0, 0)

    block.score = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    block.score:SetPoint("TOPRIGHT", 0, -1)

    -- Server name + region label (e.g. "Azralon · US"), colored by GetServerRegionColor. Inline on
    -- the header row, in the gap between ilvl and score, rather than its own row -- keeps rows
    -- compact instead of growing every applicant block by an extra line.
    block.server = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    block.server:SetPoint("LEFT", block.ilvl, "RIGHT", 8, 0)
    block.server:SetPoint("TOP", block.roleIcon, "TOP", 0, 0)
    block.server:SetPoint("RIGHT", block.score, "LEFT", -6, 0)
    block.server:SetJustifyH("LEFT")

    block.ratingIcon = block:CreateTexture(nil, "ARTWORK")
    block.ratingIcon:SetSize(12, 12)
    block.ratingIcon:SetPoint("TOPLEFT", 0, -(APPLICANT_LAYOUT.memberHeaderHeight + APPLICANT_LAYOUT.memberBlockGap))

    block.status = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    block.status:SetPoint("TOPLEFT", block.ratingIcon, "TOPRIGHT", 4, 1)
    block.status:SetPoint("RIGHT", 0, 0)
    block.status:SetJustifyH("LEFT")
    block.status:SetJustifyV("TOP")
    block.status:SetWordWrap(true)
    block.status:SetHeight(APPLICANT_LAYOUT.memberStatusHeight)

    return block
end

function Addon:CreateApplicantAlertPanel(preview)
    if (preview and self.previewApplicantPanel) or (not preview and self.applicantAlertPanel) then
        return
    end

    local frame = CreateFrame("Frame", preview and "MPlusLedgerPreviewApplicantFrame" or "MPlusLedgerApplicantAlertFrame", UIParent, "BackdropTemplate")
    frame:SetSize(APPLICANT_LAYOUT.width, 100)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0, 0, 0, 1.00)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(preview and "TEST - Applicant reputation" or "Applicant reputation")
    frame.title = title

    -- Close (X) button, per user request 2026-09-29 -- dismisses the whole panel without acting on
    -- any pending applicant; it reappears automatically on the next new applicant or resolved
    -- application, same as RefreshApplicantAlertPanel already re-Shows it for those.
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetSize(APPLICANT_LAYOUT.closeButtonSize, APPLICANT_LAYOUT.closeButtonSize)
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    frame.closeButton = closeButton

    -- Scrollable list (user request, 2026-09-16: smaller rows + a scrollbar + mouse-wheel scroll)
    -- -- same UIPanelScrollFrameTemplate + smooth target-scroll pattern already used throughout
    -- this file (Mob Browser, Season tab, etc.). The panel now caps at APPLICANT_LAYOUT.maxHeight
    -- and scrolls internally instead of growing without bound as more applicants arrive.
    local listFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", 10, -36)
    listFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    listFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    listFrame:SetBackdropColor(0.03, 0.03, 0.03, 0.9)
    frame.listFrame = listFrame

    local scrollFrame = CreateFrame("ScrollFrame", nil, listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 6)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self:GetVerticalScrollRange())
        local target = math.max(0, math.min(maxScroll, (self.targetScroll or self:GetVerticalScroll()) - (delta * 40)))
        self.targetScroll = target
    end)
    scrollFrame:SetScript("OnUpdate", function(self, elapsed)
        local target = self.targetScroll
        if not target then
            return
        end
        local current = self:GetVerticalScroll()
        if math.abs(target - current) < 0.5 then
            self:SetVerticalScroll(target)
            self.targetScroll = nil
            return
        end
        self:SetVerticalScroll(current + (target - current) * math.min(1, elapsed * 12))
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollContent)
    frame.scrollFrame = scrollFrame
    frame.scrollContent = scrollContent

    frame.rows = {}
    for i = 1, APPLICANT_LAYOUT.rowPool do
        local row = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", 0, 0)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        row:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
        row:SetBackdropBorderColor(0.55, 0.42, 0.15, 0.8)

        row.memberBlocks = {}
        for m = 1, APPLICANT_LAYOUT.maxMembersPerRow do
            row.memberBlocks[m] = CreateApplicantAlertMemberBlock(row)
        end

        -- Smaller/dimmer than before (was GameFontHighlightSmall) per user request 2026-09-29 --
        -- the "Message:" prefix keeps its own inline yellow color code, only the applicant's actual
        -- comment text picks up this font object's smaller, dimmer default.
        row.comment = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.comment:SetPoint("LEFT", 10, 0)
        row.comment:SetPoint("RIGHT", -10, 0)
        row.comment:SetHeight(APPLICANT_LAYOUT.commentHeight)
        row.comment:SetJustifyH("LEFT")
        row.comment:SetJustifyV("TOP")
        row.comment:SetWordWrap(true)

        -- Pass icon changed again 2026-09-30 per user feedback (with screenshot) -- the loot-roll
        -- "Pass" texture rendered as a red circle-slash "prohibited" sign, reading as aggressive/
        -- forbidding rather than a neutral skip. Interface\Buttons\UI-SpellbookIcon-NextPage-Up is
        -- Blizzard's own "next page" arrow (Spellbook, quest log, etc. all use it) -- a plain right
        -- arrow, verified-real asset, reads as neutral "move past this one."
        row.notsure = CreateApplicantAlertIconButton(row, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", APPLICANT_LAYOUT.iconButtonSize, "Pass -- skip, leave pending in Group Finder")
        row.notsure:SetPoint("BOTTOMRIGHT", -10, 6)
        row.avoid = CreateApplicantAlertIconButton(row, "Interface\\RaidFrame\\ReadyCheck-NotReady", APPLICANT_LAYOUT.iconButtonSize, "Decline this application")
        row.avoid:SetPoint("RIGHT", row.notsure, "LEFT", -10, 0)
        row.accept = CreateApplicantAlertIconButton(row, "Interface\\RaidFrame\\ReadyCheck-Ready", APPLICANT_LAYOUT.iconButtonSize, "Accept and invite")
        row.accept:SetPoint("RIGHT", row.avoid, "LEFT", -10, 0)

        row:Hide()
        frame.rows[i] = row
    end

    frame:Hide()
    if preview then self.previewApplicantPanel = frame else self.applicantAlertPanel = frame end
    self.pendingApplicantAlerts = self.pendingApplicantAlerts or {}
end

-- The comment (when present) no longer adds its own line -- per user request 2026-09-30, it now
-- shares the footer row with the Accept/Decline/Pass buttons (see RefreshApplicantAlertPanel),
-- so footerHeight alone is enough room for either case.
local function GetApplicantAlertEntryHeight(entry)
    local memberCount = math.max(1, math.min(#entry.members, APPLICANT_LAYOUT.maxMembersPerRow))
    return APPLICANT_LAYOUT.rowPadding * 2
        + memberCount * APPLICANT_LAYOUT.memberBlockHeight
        + math.max(0, memberCount - 1) * APPLICANT_LAYOUT.memberRowGap
        + APPLICANT_LAYOUT.footerHeight
end

function Addon:RefreshApplicantAlertPanel(preview)
    local frame = preview and self.previewApplicantPanel or self.applicantAlertPanel
    if not frame then
        return
    end
    local pending = (preview and self.previewApplicantAlerts or self.pendingApplicantAlerts) or {}
    if #pending == 0 then
        frame:Hide()
        return
    end

    local totalHeight = 0
    for i, row in ipairs(frame.rows) do
        local entry = pending[i]
        if entry then
            local rowHeight = GetApplicantAlertEntryHeight(entry)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -totalHeight)
            row:SetPoint("TOPRIGHT", 0, -totalHeight)
            row:SetHeight(rowHeight)

            local memberCount = math.min(#entry.members, APPLICANT_LAYOUT.maxMembersPerRow)
            local blockY = -APPLICANT_LAYOUT.rowPadding
            for m, block in ipairs(row.memberBlocks) do
                local member = entry.members[m]
                if member and m <= memberCount then
                    if m > 1 then
                        blockY = blockY - APPLICANT_LAYOUT.memberRowGap
                    end
                    block:ClearAllPoints()
                    block:SetPoint("TOPLEFT", row, "TOPLEFT", 10, blockY)
                    block:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, blockY)

                    SetApplicantRoleIcon(block.roleIcon, member.role)

                    local classColor = RAID_CLASS_COLORS and member.class and RAID_CLASS_COLORS[member.class]
                    if classColor then
                        block.name:SetTextColor(classColor.r, classColor.g, classColor.b)
                    else
                        block.name:SetTextColor(1, 1, 1)
                    end
                    block.name:SetText(GetShortName(member.name))

                    if member.ilvl and member.ilvl > 0 then
                        block.ilvl:SetText(string.format("i%d", math.floor(member.ilvl)))
                        block.ilvl:Show()
                    else
                        block.ilvl:Hide()
                    end

                    if member.dungeonScore and member.dungeonScore > 0 then
                        local r, g, b = GetApplicantScoreColor(member.dungeonScore)
                        block.score:SetTextColor(r, g, b)
                        block.score:SetText(tostring(math.floor(member.dungeonScore)))
                        block.score:Show()
                    else
                        block.score:Hide()
                    end

                    if member.realm and member.realm ~= "" then
                        local location, r, g, b = GetServerRegionColor(member.realm)
                        block.server:SetTextColor(r, g, b)
                        block.server:SetText(string.format("%s \194\183 %s", member.realm, location))
                        block.server:Show()
                    else
                        block.server:Hide()
                    end

                    if member.rating then
                        block.ratingIcon:SetTexture(GetRatingMeta(member.rating).icon)
                        block.ratingIcon:Show()
                    else
                        block.ratingIcon:Hide()
                    end
                    block.status:SetText(member.statusText or "")

                    block:Show()
                    blockY = blockY - APPLICANT_LAYOUT.memberBlockHeight
                else
                    block:Hide()
                end
            end

            -- Same line as the Accept/Decline/Pass buttons now, per user request 2026-09-30 (was
            -- its own line above them) -- bottom-anchored and vertically centered on the button
            -- row's height, with its RIGHT edge stopping at the leftmost button instead of the
            -- row's own right edge, so the text can't run underneath the icons.
            if entry.comment and entry.comment ~= "" then
                row.comment:ClearAllPoints()
                row.comment:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 6 + (APPLICANT_LAYOUT.iconButtonSize - APPLICANT_LAYOUT.commentHeight) / 2)
                row.comment:SetPoint("RIGHT", row.accept, "LEFT", -10, 0)
                row.comment:SetText("|cffffcc00Message:|r " .. entry.comment)
                row.comment:Show()
            else
                row.comment:Hide()
            end

            row.accept:SetScript("OnClick", function()
                Addon:ResolveApplicantAlert(entry, "accept")
            end)
            row.avoid:SetScript("OnClick", function()
                Addon:ResolveApplicantAlert(entry, "avoid")
            end)
            row.notsure:SetScript("OnClick", function()
                Addon:ResolveApplicantAlert(entry, "notsure")
            end)

            row:Show()
            totalHeight = totalHeight + rowHeight + APPLICANT_LAYOUT.rowGap
        else
            row:Hide()
        end
    end

    frame.scrollContent:SetSize(math.max(1, frame.scrollFrame:GetWidth()), math.max(1, totalHeight))
    frame:SetHeight(math.min(APPLICANT_LAYOUT.maxHeight, 46 + totalHeight))
    frame:Show()
end

-- action: "accept" invites, "avoid" declines, "notsure" ("Pass") just leaves the application
-- pending in Blizzard's own list -- per user request 2026-09-29 ("I don't want the accept,
-- decline and pass to mark that player as such. It is just a accept, decline or pass"), none of
-- the three touch playerRatings anymore.
function Addon:ResolveApplicantAlert(entry, action)
    if entry.preview then
        for i, item in ipairs(self.previewApplicantAlerts or {}) do
            if item == entry then table.remove(self.previewApplicantAlerts, i);break end
        end
        self:RefreshApplicantAlertPanel(true)
        return
    end
    if action == "accept" then
        local ok, err = pcall(C_LFGList.InviteApplicant, entry.applicantID)
        if not ok then
            Debug("Applicant Alert: InviteApplicant failed: " .. tostring(err))
        end
    elseif action == "avoid" then
        local ok, err = pcall(C_LFGList.DeclineApplicant, entry.applicantID)
        if not ok then
            Debug("Applicant Alert: DeclineApplicant failed: " .. tostring(err))
        end
    elseif action == "notsure" then
        Print("Passed. Their application is still pending -- decide in the Group Finder window when ready.")
    end

    if self.pendingApplicantAlerts then
        for i, pendingEntry in ipairs(self.pendingApplicantAlerts) do
            if pendingEntry.applicantID == entry.applicantID then
                table.remove(self.pendingApplicantAlerts, i)
                break
            end
        end
    end
    self:RefreshApplicantAlertPanel()
end

function Addon:QueueApplicantAlert(applicantID, members, comment)
    if not (members and #members > 0) then
        return
    end
    self:CreateApplicantAlertPanel()
    self.pendingApplicantAlerts = self.pendingApplicantAlerts or {}
    for i, entry in ipairs(self.pendingApplicantAlerts) do
        if entry.applicantID == applicantID then
            table.remove(self.pendingApplicantAlerts, i)
            break
        end
    end
    table.insert(self.pendingApplicantAlerts, { applicantID = applicantID, members = members, comment = comment })
    self:RefreshApplicantAlertPanel()
end

-- Separate test entries use the live panel renderer; their actions only dismiss examples.
function Addon:PreviewApplicantAlert()
    self:CreateApplicantAlertPanel(true)
    self.previewApplicantAlerts = {
        {preview=true, applicantID="test-tank", members={{name="ExampleTank",role="TANK",class="PALADIN",rating="Good",ilvl=300,dungeonScore=2400,statusText="TEST: Trusted player - 5 runs together"}},comment="Test data. Buttons only dismiss this example."},
        {preview=true, applicantID="test-healer", members={{name="ExampleHealer",role="HEALER",class="PRIEST",ilvl=295,dungeonScore=2100,statusText="TEST: No recorded history with this player"}},comment="Test applicant message"},
        {preview=true, applicantID="test-damage", members={{name="ExampleDamage",role="DAMAGER",class="MAGE",rating="Bad",ilvl=305,dungeonScore=2600,statusText="TEST: Avoid - example saved note"}},comment="Fictional values; no reputation is saved."},
    }
    self:RefreshApplicantAlertPanel(true)
end

-- Drops any pending alert row whose application is no longer in Blizzard's own applicant list --
-- e.g. the applicant cancelled, or was accepted/declined from the real Group Finder window instead
-- of this panel. Called from CheckLFGApplicantsForRatedPlayers on every LFG_LIST_APPLICANT_LIST_UPDATED.
function Addon:PruneResolvedApplicantAlerts(currentApplicantIDs)
    if not self.pendingApplicantAlerts or #self.pendingApplicantAlerts == 0 then
        return
    end
    local stillPresent = {}
    for _, id in ipairs(currentApplicantIDs or {}) do
        local ok, info = pcall(C_LFGList.GetApplicantInfo, id)
        -- Only an application still awaiting a decision belongs in this panel.
        if not ok or (info and (IsSecret(info.applicationStatus) or IsSecret(info.pendingApplicationStatus))) then
            stillPresent[id] = true -- do not discard rows because a read failed
        elseif info and info.applicationStatus == "applied" and (not info.pendingApplicationStatus or info.pendingApplicationStatus == "applied") then
            stillPresent[id] = true
        end
    end
    local removedAny = false
    for i = #self.pendingApplicantAlerts, 1, -1 do
        local entry = self.pendingApplicantAlerts[i]
        if not stillPresent[entry.applicantID] then
            table.remove(self.pendingApplicantAlerts, i)
            if self.seenApplicantAlertIDs then self.seenApplicantAlertIDs[entry.applicantID] = nil end
            removedAny = true
        end
    end
    if removedAny then
        self:RefreshApplicantAlertPanel()
    end
end

-- Lightweight re-check of the pending cards against Blizzard's live applicant list, without the
-- warning/broadcast side effects of CheckLFGApplicantsForRatedPlayers -- safe to call on a timer
-- while the panel is open (see ApplicantExperience.lua), so an applicant who cancels disappears
-- even if no LFG event reached us. No active listing at all = every card is stale.
function Addon:PruneApplicantAlertsNow()
    if not self.pendingApplicantAlerts or #self.pendingApplicantAlerts == 0 or not C_LFGList then
        return
    end
    if C_LFGList.HasActiveEntryInfo then
        local ok, hasEntry = pcall(C_LFGList.HasActiveEntryInfo)
        if ok and hasEntry == false then
            self:PruneResolvedApplicantAlerts({})
            return
        end
    end
    if not C_LFGList.GetApplicants then
        return
    end
    local ok, applicantIDs = pcall(C_LFGList.GetApplicants)
    if ok and type(applicantIDs) == "table" then
        self:PruneResolvedApplicantAlerts(applicantIDs)
    end
end

-- Catches a Bad-rated player at the Premade Groups application stage, before you've even accepted
-- them into the party. C_LFGList.GetApplicantInfo/.GetApplicantMemberInfo signatures verified
-- against Blizzard's own API docs 2026-09-04. Also shows the Applicant Alert popup above once per
-- newly-seen applicantID (self.seenApplicantAlertIDs, session-only -- an applicant that cancels
-- and re-applies gets treated as new again, which is fine/desired).
function Addon:CheckLFGApplicantsForRatedPlayers()
    if not (self.db and self.db.playerRatings and C_LFGList and C_LFGList.GetApplicants and C_LFGList.GetApplicantInfo and C_LFGList.GetApplicantMemberInfo) then
        return
    end
    local listOk, applicantIDs = pcall(C_LFGList.GetApplicants)
    if not listOk or not applicantIDs then
        -- No applicant list at all usually means the group was delisted -- every card left in the
        -- panel is stale then (user report 2026-10-04: names stayed listed after people cancelled).
        self:PruneApplicantAlertsNow()
        return
    end
    self.seenApplicantAlertIDs = self.seenApplicantAlertIDs or {}
    local warnedAny = false
    for _, applicantID in ipairs(applicantIDs) do
        local infoOk, applicantData = pcall(C_LFGList.GetApplicantInfo, applicantID)
        if infoOk and applicantData and not IsSecret(applicantData.applicationStatus) and not IsSecret(applicantData.pendingApplicationStatus) and applicantData.applicationStatus == "applied" and (not applicantData.pendingApplicationStatus or applicantData.pendingApplicationStatus == "applied") then
        local numMembers = applicantData.numMembers or 1
        local isNewApplicant = not self.seenApplicantAlertIDs[applicantID]
        local structuredMembers = {}
        for memberIndex = 1, numMembers do
            -- Full signature (verified 2026-09-08): name, class, localizedClass, level, itemLevel,
            -- honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore,
            -- pvpItemLevel. dungeonScore (added 2026-09-16, was previously discarded) is the same
            -- Mythic+ score Blizzard's own applicant list column shows -- no separate lookup needed.
            -- level (4th) and specID (16th) captured too (2026-10-04) for the applicant card's
            -- "Level 90 Balance Druid" line, the same detail Blizzard's own applicant tooltip shows.
            local memberOk, name, classToken, _, level, itemLevel, _, _, _, _, assignedRole, _, dungeonScore, _, _, _, specID = pcall(C_LFGList.GetApplicantMemberInfo, applicantID, memberIndex)
            if memberOk and name and not IsSecret(name) then
                local role = (not IsSecret(assignedRole)) and assignedRole or nil
                local class = (not IsSecret(classToken)) and classToken or nil
                local ilvl = (not IsSecret(itemLevel)) and tonumber(itemLevel) or nil
                local score = (not IsSecret(dungeonScore)) and tonumber(dungeonScore) or nil
                -- Always shown locally (this addon's own record of who applied) regardless of the
                -- toggle -- per user request 2026-09-08 ("have the...request to join still show
                -- but do not broadcast it"); only whether it goes out to party/raid chat depends
                -- on broadcastPlayerReportsOnApply now.
                self:BroadcastPlayerReport(name, role, class, ilvl, self.db.broadcastPlayerReportsOnApply == true)
                if self:WarnIfPlayerIsBad(name, "applied to your group") then
                    warnedAny = true
                end
                if isNewApplicant then
                    local key = GetPlayerProfileKey(name)
                    local profile = key and self.db.playerRatings and self.db.playerRatings[key]
                    local _, realm = GetPlayerRealmName(name)
                    -- Spec name/level and best keys (best in the listed dungeon, best overall),
                    -- matching Blizzard's applicant tooltip -- see ApplicantExperience.lua.
                    local extras = self.GetApplicantExtras and self:GetApplicantExtras(applicantID, memberIndex, class, level, specID) or {}
                    table.insert(structuredMembers, {
                        name = name,
                        role = role,
                        class = class,
                        ilvl = ilvl,
                        dungeonScore = score,
                        realm = realm,
                        level = extras.level,
                        spec = extras.spec,
                        bestHere = extras.bestHere,
                        bestRun = extras.bestRun,
                        rating = profile and profile.rating,
                        -- omitNamePrefix=true: the panel renders name/role/class/ilvl itself as
                        -- icons/colored text (see CreateApplicantAlertMemberBlock), so this only
                        -- needs the "has no play history.../reported as..." tail text.
                        statusText = self:GetPlayerReportMessage(name, false, nil, nil, nil, true),
                    })
                end
            end
        end
        if isNewApplicant and #structuredMembers > 0 then
            self.seenApplicantAlertIDs[applicantID] = true
            local comment = (infoOk and applicantData and applicantData.comment)
            if comment and IsSecret(comment) then
                comment = nil
            end
            if comment and comment ~= "" then
                comment = StripWowText(comment)
            end
            if self.db.showApplicantAlertPopup ~= false then
                self:QueueApplicantAlert(applicantID, structuredMembers, comment)
            end
        end
        end
    end
    self:PruneResolvedApplicantAlerts(applicantIDs)
    if warnedAny then
        self:FocusLFGApplicationViewer()
    end
end

function Addon:QueueRosterRefresh(reason)
    self:UpdateGroupRoster(reason)
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            Addon:UpdateGroupRoster((reason or "roster") .. " delayed")
        end)
        C_Timer.After(3, function()
            Addon:UpdateGroupRoster((reason or "roster") .. " settled")
        end)
    end
end

function Addon:PrintMembers()
    local run = self:GetCurrentRun() or self:GetLastRun()
    if not run or not run.members or #run.members == 0 then
        Print("No party members recorded yet.")
        return
    end

    Print(string.format("Members for %s:", run.instanceName or "last run"))
    for _, member in ipairs(run.members) do
        local role = member.role and member.role ~= "NONE" and (" - " .. member.role) or ""
        Print((member.name or "Unknown") .. role)
    end
end

function Addon:EnsureMemberDeathTables(run)
    if not run then
        return
    end

    run.memberDeaths = run.memberDeaths or {}
    run.memberDeathLog = run.memberDeathLog or {}
    run.memberDeathIDs = run.memberDeathIDs or {}
    run.nextDeathEventID = tonumber(run.nextDeathEventID) or 0
    local backfillCountsByPlayer = {}
    for index, entry in ipairs(run.memberDeathLog) do
        if entry and not entry.deathID and self.CreateMemberDeathID then
            local normalizedName = NormalizePlayerName(entry.name)
            backfillCountsByPlayer[normalizedName] = (backfillCountsByPlayer[normalizedName] or 0) + 1
            local deathID, deathNumber = self:CreateMemberDeathID(run, entry.time, entry.name, backfillCountsByPlayer[normalizedName])
            entry.id = deathID
            entry.deathID = deathID
            entry.deathNumber = deathNumber or index
            entry.playerDeathCount = backfillCountsByPlayer[normalizedName]
        elseif entry and entry.deathID and not entry.id then
            entry.id = entry.deathID
        end
        if entry and entry.deathNumber then
            run.nextDeathEventID = math.max(run.nextDeathEventID, tonumber(entry.deathNumber) or 0)
        end
        if entry and entry.deathID then
            run.memberDeathIDs[entry.deathID] = true
        end
    end
    run.nextDeathEventID = math.max(run.nextDeathEventID, #run.memberDeathLog)
    run.memberDeathCooldowns = run.memberDeathCooldowns or {}
    run.memberDeathNameCooldowns = run.memberDeathNameCooldowns or {}
    -- Bookkeeping for PollForMissedDeaths' alive/dead edge-detection -- see that function's own
    -- comment for why a simple cooldown window isn't enough to avoid double-counting there.
    run.deathPollDeadState = run.deathPollDeadState or {}
    run.deathPollLastCount = run.deathPollLastCount or {}
end

function Addon:GetMemberByGUID(run, guid)
    if not run or not guid or IsSecret(guid) then
        return nil
    end

    for _, member in ipairs(run.members or {}) do
        if member.guid and not IsSecret(member.guid) and member.guid == guid then
            return member
        end
    end

    return nil
end


function Addon:GetMemberByName(run, name)
    if not run or not name then
        return nil
    end

    local wanted = NormalizePlayerName(name)
    for _, member in ipairs(run.members or {}) do
        local memberName = NormalizePlayerName(member.name)
        if memberName == wanted or string.lower(tostring(member.name or "")) == string.lower(StripWowText(name)) then
            return member
        end
    end

    return nil
end

function Addon:CreateMemberDeathID(run, eventTime, playerName, playerDeathCount)
    if not run then
        return nil, nil
    end

    run.nextDeathEventID = (tonumber(run.nextDeathEventID) or 0) + 1
    local deathNumber = run.nextDeathEventID
    local timestamp = tonumber(eventTime) or time()
    local cleanName = FormatDeathIDPlayerName(playerName)
    local deathCount = math.max(tonumber(playerDeathCount) or 1, 1)
    return string.format("%s-%d-%d-%s", cleanName, deathCount, timestamp, PadLeft(tostring(deathNumber), 3, "0")), deathNumber
end

function Addon:AddMemberDeathLogEntry(run, key, guid, name, source, eventTime, externalDeathID, externalDeathNumber, playerDeathCount, killerName, killerNPCID)
    if not run then
        return false
    end

    self:EnsureMemberDeathTables(run)
    local timestamp = tonumber(eventTime) or time()
    local deathID, deathNumber = externalDeathID, externalDeathNumber
    local deathCount = math.max(tonumber(playerDeathCount) or ((run.memberDeaths[key] and tonumber(run.memberDeaths[key].count) or 0) + 1), 1)
    if not deathID then
        deathID, deathNumber = self:CreateMemberDeathID(run, timestamp, name, deathCount)
    end
    if not deathID or run.memberDeathIDs[deathID] then
        return false
    end

    run.memberDeathIDs[deathID] = true
    table.insert(run.memberDeathLog, {
        id = deathID,
        deathID = deathID,
        deathNumber = deathNumber,
        playerDeathCount = deathCount,
        time = timestamp,
        timeText = date("%Y-%m-%d %H:%M:%S", timestamp),
        key = key,
        guid = guid,
        name = name,
        source = source or "unknown",
        killerName = killerName,
        killerNPCID = killerNPCID,
    })
    return true, deathID
end

function Addon:RecordMemberDeathByDisplayName(run, name, source)
    if not run or not name then
        return false
    end

    self:EnsureMemberDeathTables(run)
    local cleanName = StripWowText(name)
    local normalizedName = NormalizePlayerName(cleanName)
    if normalizedName == "" or normalizedName == "unknown" then
        return false
    end

    -- Realm-qualified identity key (see RecordMemberDeathByGUID's matching comment) -- with no
    -- GUID at all on this fallback path, this is the only thing standing between two different
    -- party members who share a character name (possible cross-realm) sharing both a death-count
    -- bucket and a cooldown slot, which would silently merge their separate deaths into one.
    local identityKey = GetPlayerProfileKey(cleanName) or normalizedName

    local now = time()
    if run.memberDeathNameCooldowns[identityKey] and now - run.memberDeathNameCooldowns[identityKey] < 3 then
        return false
    end

    local fallbackKey = "name:" .. identityKey
    if not self:AddMemberDeathLogEntry(run, fallbackKey, fallbackKey, cleanName, source or "name fallback", now) then
        return false
    end

    run.memberDeathNameCooldowns[identityKey] = now
    run.memberDeaths[fallbackKey] = run.memberDeaths[fallbackKey] or {
        name = cleanName,
        count = 0,
    }
    run.memberDeaths[fallbackKey].name = cleanName
    run.memberDeaths[fallbackKey].count = (run.memberDeaths[fallbackKey].count or 0) + 1
    run.deaths = (run.deaths or 0) + 1
    run.lastDeathAt = now
    run.lastDeathAtText = date("%Y-%m-%d %H:%M:%S")

    Print(string.format("%s death count: %d", GetShortName(cleanName), run.memberDeaths[fallbackKey].count or 0))
    self:RefreshAllDisplays()
    return true
end

function Addon:RecordMemberDeathByName(name, source, killerName, killerNPCID)
    local run = self:GetCurrentRun()
    if not run or not name then
        return false
    end

    local member = self:GetMemberByName(run, name)
    if not member then
        self:UpdateGroupRoster("death message")
        member = self:GetMemberByName(run, name)
    end
    if not member or not member.guid then
        Debug("Death message did not match roster member: " .. tostring(name))
        return self:RecordMemberDeathByDisplayName(run, name, source or "system message fallback")
    end

    return self:RecordMemberDeathByGUID(member.guid, member.name or name, source or "system message", killerName, killerNPCID)
end

function Addon:HandleSystemDeathMessage(message)
    if not message or not self:GetCurrentRun() then
        return
    end

    local cleanMessage = StripWowText(message)
    local completedDungeon, completedLevel = cleanMessage:match("^(.+) %(Level (%d+)%) completed in .+")
    if completedDungeon then
        local run = self:GetCurrentRun()
        run.completionMessage = cleanMessage
        run.completionLevel = tonumber(completedLevel) or run.challengeLevel
        if run.completionLevel and run.completionLevel > 0 then
            run.challengeLevel = run.completionLevel
            run.keyLevel = run.completionLevel
        end
        self:MarkCurrentRunCompleted("mythic plus chat completion")
        return
    end

    local playerName = cleanMessage:match("^%[?([^%]]-)%]? has died%.?$")
    if playerName then
        if not self:RecordMemberDeathByName(playerName, "system message") then
            Debug("Death message found but was not recorded: " .. tostring(cleanMessage))
        end
        return
    end

    if cleanMessage == "You died." then
        self:RecordMemberDeathByGUID(SafeUnitGUID("player"), GetUnitFullName("player"), "system message")
    end
end

function Addon:HandleSystemTimerMessage(message)
    if not message then
        return false
    end

    local cleanMessage = StripWowText(message)
    if cleanMessage:find("You have joined a Mythic%+ instance", 1) then
        self:RefreshChallengeModeInfo("mythic plus system message")
        self:MarkRunTimerStarted("mythic plus system message")
        return true
    end

    return false
end

function Addon:RecordMemberDeathByGUID(guid, name, source, killerName, killerNPCID)
    local run = self:GetCurrentRun()
    if not run or not guid then
        return false
    end

    self:EnsureMemberDeathTables(run)

    local now = time()
    if run.memberDeathCooldowns[guid] and now - run.memberDeathCooldowns[guid] < 2 then
        return false
    end

    local member = self:GetMemberByGUID(run, guid)
    if IsSecret(name) then
        name = nil
    end
    local displayName = name or (member and member.name) or guid
    -- Realm-qualified (not just NormalizePlayerName's bare short name) so two different party
    -- members who happen to share a character name -- possible in a cross-realm group, where
    -- WoW already attaches "-Realm" to the non-local one -- don't share a cooldown slot and
    -- silently suppress each other's very real, distinct deaths.
    local nameCooldownKey = GetPlayerProfileKey(displayName)
    if nameCooldownKey and run.memberDeathNameCooldowns[nameCooldownKey] and now - run.memberDeathNameCooldowns[nameCooldownKey] < 3 then
        return false
    end

    if not self:AddMemberDeathLogEntry(run, guid, guid, displayName, source or "unknown", now, nil, nil, nil, killerName, killerNPCID) then
        return false
    end

    run.memberDeathCooldowns[guid] = now
    if nameCooldownKey then
        run.memberDeathNameCooldowns[nameCooldownKey] = now
    end
    run.memberDeaths[guid] = run.memberDeaths[guid] or {
        name = displayName,
        count = 0,
    }
    run.memberDeaths[guid].name = displayName
    run.memberDeaths[guid].count = (run.memberDeaths[guid].count or 0) + 1
    if killerName then
        run.memberDeaths[guid].lastKillerName = killerName
        run.memberDeaths[guid].lastKillerNPCID = killerNPCID
    end
    run.deaths = (run.deaths or 0) + 1
    if guid == self:GetPlayerGUIDForRun(run) then
        run.playerDeaths = (run.playerDeaths or 0) + 1
    end
    run.lastDeathAt = now
    run.lastDeathAtText = date("%Y-%m-%d %H:%M:%S")

    if guid == SafeUnitGUID("player") then
        self.deathPending = true
    end

    Print(string.format("%s death count: %d%s", GetShortName(displayName), run.memberDeaths[guid].count or 0, killerName and (" (likely killed by " .. killerName .. ")") or ""))
    self:RefreshAllDisplays()
    return true
end

-- Safety net for the event-driven death detection (PARTY_KILL/UNIT_DIED/PLAYER_TARGET_DIED), added
-- 2026-09-05 per user request ("player deaths are getting recorded only some of the time... could
-- this be from the api timings?"). It's plausible: this addon's own documented constraints (see
-- STATUS.md's "Critical environment fact" section) mean kill detection can't use the combat log at
-- all post-12.0, only these dedicated events plus UnitGUID -- and a "Secret Values" system can make
-- a payload GUID unreadable, which is exactly why name-based fallbacks already exist elsewhere.
-- It's entirely plausible some deaths still fall through every one of those paths. This doesn't
-- replace the event system (which gets the exact death timestamp; this only catches up to 5s late)
-- -- it just checks, every 5 seconds, whether any group member who was alive last check is now
-- dead/ghost, and if the event system hasn't already logged that same death, logs it here.
--
-- Double-count guard: a plain cooldown window isn't enough on its own here, since our poll interval
-- (5s) is longer than the existing 2-3s per-death cooldowns (RecordMemberDeathByGUID) -- an
-- already-correctly-recorded death would still look "new" to a poll running 5s later. Instead this
-- tracks each member's own death COUNT (run.memberDeaths[guid].count) across ticks: only fires when
-- someone transitions alive->dead AND their count hasn't moved since the last tick, meaning nothing
-- else caught it.
-- Shared alive->dead edge-check, factored out 2026-09-05 so both the 5s poll below and the new
-- instant UNIT_HEALTH watcher (see UpdateUnitHealthWatchers) share one implementation of the
-- dedup bookkeeping (deathPollDeadState/deathPollLastCount), rather than keeping two copies of the
-- same logic in sync by hand.
function Addon:CheckUnitForMissedDeath(unit, sourceLabel)
    local run = self:GetCurrentRun()
    if not run or not unit then
        return
    end
    self:EnsureMemberDeathTables(run)
    local guid = SafeUnitGUID(unit)
    if not guid then
        return
    end
    local isDead = UnitIsDeadOrGhost(unit) and true or false
    local currentCount = (run.memberDeaths[guid] and run.memberDeaths[guid].count) or 0
    local wasDead = run.deathPollDeadState[guid]
    if wasDead == nil then
        -- First time seeing this member this run -- just establish the baseline, don't assume a
        -- death happened before we started watching.
        run.deathPollDeadState[guid] = isDead
        run.deathPollLastCount[guid] = currentCount
        return
    end
    if isDead and not wasDead and currentCount == (run.deathPollLastCount[guid] or 0) then
        self:RecordMemberDeathByGUID(guid, GetUnitFullName(unit), sourceLabel, nil, nil)
    end
    run.deathPollDeadState[guid] = isDead
    run.deathPollLastCount[guid] = (run.memberDeaths[guid] and run.memberDeaths[guid].count) or run.deathPollLastCount[guid] or 0
end

function Addon:PollForMissedDeaths()
    for _, unit in ipairs(GetGroupUnitTokens()) do
        self:CheckUnitForMissedDeath(unit, "periodic poll fallback (5s alive-check found a missed death)")
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(5, function()
            Addon:PollForMissedDeaths()
        end)
    end
end

-- Instant, event-driven death detection via RegisterUnitEvent("UNIT_HEALTH", ...), found by
-- inspecting two real third-party addons built specifically for current retail (MementoMori
-- v1.4.0, DeathAnnouncer v3.0), per user request. MementoMori's actual source uses exactly this
-- mechanism: UNIT_HEALTH fires the instant a watched unit's health changes, including hitting
-- 0/ghost, with no combat log and no chat message involved at all -- so it isn't affected by
-- either Secret Value restriction this project has already hit (UNIT_DIED's GUID argument, or
-- CHAT_MSG_SYSTEM's payload during an active timer -- see RegisterDeathSignalEvents' and
-- HandleSystemDeathMessage's own comments). This complements PollForMissedDeaths rather than
-- replacing it -- both share the same dedup bookkeeping via CheckUnitForMissedDeath, so whichever
-- notices first (almost always this one, being instant) naturally stops the other from
-- re-triggering on the same death.
local UNIT_HEALTH_WATCHER_FRAMES = {}
function Addon:UpdateUnitHealthWatchers()
    local units = GetGroupUnitTokens()
    local frameIndex = 1
    -- RegisterUnitEvent only accepts up to 5 unit tokens per call (4 used here to match the
    -- verified-working precedent exactly) -- a 40-man raid needs multiple small watcher frames,
    -- not one frame per unit.
    for i = 1, #units, 4 do
        local chunk = {}
        for j = i, math.min(i + 3, #units) do
            table.insert(chunk, units[j])
        end
        local watcherFrame = UNIT_HEALTH_WATCHER_FRAMES[frameIndex]
        if not watcherFrame then
            watcherFrame = CreateFrame("Frame")
            watcherFrame:SetScript("OnEvent", function(_, _, unit)
                Addon:CheckUnitForMissedDeath(unit, "unit health watcher (instant)")
            end)
            UNIT_HEALTH_WATCHER_FRAMES[frameIndex] = watcherFrame
        end
        local ok, err = pcall(watcherFrame.RegisterUnitEvent, watcherFrame, "UNIT_HEALTH", unpack(chunk))
        if not ok then
            Debug("UpdateUnitHealthWatchers: RegisterUnitEvent failed: " .. tostring(err))
        end
        frameIndex = frameIndex + 1
    end
    -- Unregister any watcher frames left over from a larger group (e.g. raid -> party demotion)
    -- so they don't keep firing for stale/reused unit tokens.
    for i = frameIndex, #UNIT_HEALTH_WATCHER_FRAMES do
        UNIT_HEALTH_WATCHER_FRAMES[i]:UnregisterAllEvents()
    end
end

function Addon:RecordMobKillByGUID(guid, name, source, displayID)
    local run = self:GetCurrentRun()
    if not guid or (run and self:GetMemberByGUID(run, guid)) then
        return false
    end

    local npcID = GetNPCIDFromGUID(guid)
    if not npcID then
        FullDebug("RecordMobKillByGUID: could not parse npcID from guid " .. tostring(guid))
        return false
    end

    if not run then
        local context = self:GetCurrentCatalogContext(source or "combat log")
        Debug("Cataloging mob without an active run: npcID=" .. tostring(npcID) .. " name=" .. tostring(name) .. " instanceName=" .. tostring(context.instanceName))
        self:CatalogMob(context, npcID, name, nil, nil, displayID)
        return true
    end

    run.mobKills = run.mobKills or {}
    run.mobKillLog = run.mobKillLog or {}
    run.mobKillTotal = (tonumber(run.mobKillTotal) or 0) + 1

    local overrideName = self.db and self.db.mobNameOverrides and self.db.mobNameOverrides[tostring(npcID)]
    local info = run.mobKills[npcID] or {
        npcID = npcID,
        name = overrideName or name or ("NPC " .. tostring(npcID)),
        count = 0,
    }
    info.name = overrideName or name or info.name
    info.count = (tonumber(info.count) or 0) + 1
    info.lastKilledAt = time()
    info.lastKilledAtText = date("%Y-%m-%d %H:%M:%S")
    info.lastKillTime = GetRunElapsedAt(run, info.lastKilledAt)
    run.mobKills[npcID] = info
    self:CatalogMob(run, npcID, info.name, nil, nil, displayID)

    table.insert(run.mobKillLog, {
        time = info.lastKilledAt,
        timeText = info.lastKilledAtText,
        killTime = info.lastKillTime,
        npcID = npcID,
        guid = guid,
        name = info.name,
        source = source or "combat log",
    })
    while #run.mobKillLog > 500 do
        table.remove(run.mobKillLog, 1)
    end

    -- Was previously silent on success too -- a 2026-09-10 SavedVariables audit found
    -- mobKillTotal=0/mobKillLog empty across EVERY stored run in this player's history, with no
    -- way to tell from the log whether this function ever actually got called successfully at all
    -- (only its failure paths logged anything). One line per confirmed kill closes that gap.
    Debug("RecordMobKillByGUID: recorded npcID=" .. tostring(npcID) .. " name=" .. tostring(info.name) .. " source=" .. tostring(source))

    return true
end

-- Fallback when a trash mob's GUID is a genuine Secret Value (confirmed 2026-09-01 via live debug
-- dump: UnitGUID("target") itself returns secret during an active M+ run, not just the raw
-- PARTY_KILL/UNIT_DIED event args -- no pcall/guard gets around that, the data is deliberately
-- unreadable). Without a GUID there's no npcID to key run.mobKills by (GetNPCIDFromGUID parses it
-- out of the GUID string), so this counts the kill by name instead -- worse cross-referencing
-- (no npcID for Wowhead-style lookups, can't tell two same-named-but-different mobs apart), but
-- still satisfies this addon's core mission ("count/log every trash mob killed per run") instead
-- of silently recording nothing at all.
function Addon:RecordMobKillByName(name, source, displayID)
    local run = self:GetCurrentRun()
    if not run or not name or name == "" then
        return false
    end

    run.mobKills = run.mobKills or {}
    run.mobKillLog = run.mobKillLog or {}
    run.mobKillTotal = (tonumber(run.mobKillTotal) or 0) + 1

    local key = "name:" .. string.lower(StripWowText(name))
    local info = run.mobKills[key] or {
        npcID = nil,
        name = name,
        count = 0,
    }
    info.name = name
    info.count = (tonumber(info.count) or 0) + 1
    info.lastKilledAt = time()
    info.lastKilledAtText = date("%Y-%m-%d %H:%M:%S")
    info.lastKillTime = GetRunElapsedAt(run, info.lastKilledAt)
    if displayID then
        info.displayID = displayID
    end
    run.mobKills[key] = info
    self:CatalogMobByName(run, info.name, displayID)

    table.insert(run.mobKillLog, {
        time = info.lastKilledAt,
        timeText = info.lastKilledAtText,
        killTime = info.lastKillTime,
        npcID = nil,
        name = info.name,
        source = (source or "combat log") .. " (name fallback -- GUID was a Secret Value)",
    })
    while #run.mobKillLog > 500 do
        table.remove(run.mobKillLog, 1)
    end

    -- See the matching comment in RecordMobKillByGUID above -- this path used to be silent on
    -- success too, leaving no way to confirm from the log whether name-fallback tracking ever
    -- actually worked either.
    Debug("RecordMobKillByName: recorded name=" .. tostring(info.name) .. " source=" .. tostring(source))

    return true
end

function Addon:GetDeathSummary(run)
    if not run or not run.members or #run.members == 0 then
        return "No players recorded"
    end

    self:EnsureMemberDeathTables(run)

    local parts = {}
    for _, member in ipairs(run.members) do
        table.insert(parts, string.format("%s:%d", GetShortName(member.name), self:GetMemberDeathCount(run, member)))
    end

    return table.concat(parts, "  ")
end
function Addon:RecordDeath()
    if self.deathPending then
        return
    end

    local killerName, killerNPCID
    if UnitExists("target") and not UnitIsPlayer("target") then
        killerName = UnitName("target")
        killerNPCID = GetNPCIDFromGUID(SafeUnitGUID("target"))
    end
    self:RecordMemberDeathByGUID(SafeUnitGUID("player"), GetUnitFullName("player"), "player dead", killerName, killerNPCID)
end

function Addon:RecordRunChatEvent(event, message, sender, languageName, channelName, target, flags, unknown1, channelNumber, channelBaseName, ...)
    local run = self:GetCurrentRun()
    if not run or not message then
        return false
    end

    run.chatLog = run.chatLog or {}
    local now = time()
    table.insert(run.chatLog, {
        time = now,
        timeText = date("%Y-%m-%d %H:%M:%S", now),
        runTime = GetRunElapsedAt(run, now),
        event = event,
        message = StripWowText(message),
        rawMessage = tostring(message or ""),
        sender = StripWowText(sender or ""),
        channelName = StripWowText(channelName or channelBaseName or ""),
        channelNumber = channelNumber,
    })
    while #run.chatLog > 300 do
        table.remove(run.chatLog, 1)
    end
    return true
end

function Addon:PrintRunChatLog(runID)
    local run = self:GetRun(runID) or self:GetCurrentRun() or self:GetLastRun()
    if not run then
        Print("No run found for chat log.")
        return
    end

    local log = run.chatLog or {}
    if #log == 0 then
        Print("No chat lines logged for " .. tostring(self:GetRunCode(run) or run.instanceName or "this run") .. ".")
        return
    end

    local startIndex = math.max(1, #log - 19)
    Print("Last " .. tostring(#log - startIndex + 1) .. " chat line(s) for " .. tostring(self:GetRunCode(run) or run.instanceName or "this run") .. ":")
    for index = startIndex, #log do
        local entry = log[index]
        local senderText = entry.sender and entry.sender ~= "" and (" " .. entry.sender .. ":") or ""
        Print(string.format("%s [%s %s]%s %s", tostring(entry.timeText or "?"), tostring(entry.event or "CHAT"), FormatDuration(entry.runTime or 0), senderText, tostring(entry.message or "")))
    end
end

function Addon:RecordMoneyLoot(message)
    local run = self:GetCurrentRun()
    if not run then
        return false
    end

    local copper = ParseMoneyMessage(message)
    if copper <= 0 then
        return false
    end

    run.goldLooted = (run.goldLooted or 0) + copper
    run.moneyLoot = run.moneyLoot or {}
    table.insert(run.moneyLoot, {
        time = time(),
        timeText = date("%Y-%m-%d %H:%M:%S"),
        amount = copper,
        message = message,
    })

    Debug("Recorded coin loot: " .. FormatMoney(copper))
    self:RefreshAllDisplays()
    return true
end

function Addon:RecordItemLoot(message)
    local run = self:GetCurrentRun()
    if not run or not message then
        return false
    end

    local itemLink = tostring(message):match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then
        return false
    end

    run.itemLoot = run.itemLoot or {}
    table.insert(run.itemLoot, {
        time = time(),
        timeText = date("%Y-%m-%d %H:%M:%S"),
        itemLink = itemLink,
        message = StripWowText(message),
    })
    while #run.itemLoot > 500 do
        table.remove(run.itemLoot, 1)
    end
    return true
end

-- Self-built loot database (Phase 2 item from TODO.md). GetLootSourceInfo(slot) returns
-- guid/quantity pairs per loot slot -- multiple pairs when several corpses were consolidated into
-- one loot window -- letting each item be attributed to the real creature(s) it dropped from,
-- independent of the CHAT_MSG_LOOT text parsing RecordItemLoot already does for the per-run loot
-- log above. Confirmed both LOOT_OPENED and GetLootSourceInfo still fire/populate under auto-loot
-- (the loot window opens and closes programmatically either way), so this isn't limited to players
-- who loot manually.
function Addon:RecordItemDropForNPC(npcID, itemLink)
    if not npcID or not itemLink or not self.db then
        return
    end

    local key = tostring(npcID)
    local mob = self.db.npcCatalog and self.db.npcCatalog[key]
    if mob and AppendDropToCatalogEntry(mob, itemLink) then
        mob.verify = not mob.name or not mob.level or not mob.drops or #mob.drops == 0
    end

    -- bossCatalog is keyed by Encounter Journal encounterID, not the real npcID (see CatalogBoss),
    -- so matching has to walk entries comparing their captured npcID/npcIDs instead of indexing.
    if self.db.bossCatalog then
        for _, boss in pairs(self.db.bossCatalog) do
            if boss and (tonumber(boss.npcID) == npcID or TableContainsNumber(boss.npcIDs, npcID)) then
                if AppendDropToCatalogEntry(boss, itemLink) then
                    boss.verify = not boss.name or not boss.level or not boss.health or not boss.drops or #boss.drops == 0
                end
            end
        end
    end
end

function Addon:RecordLootDrops()
    if not GetNumLootItems or not GetLootSlotLink or not GetLootSourceInfo then
        return
    end

    local ok, count = pcall(GetNumLootItems)
    if not ok or not count then
        return
    end

    for slot = 1, count do
        local linkOk, itemLink = pcall(GetLootSlotLink, slot)
        if linkOk and itemLink and not (issecretvalue and issecretvalue(itemLink)) then
            local sourceOk, sourceResults = pcall(function() return { GetLootSourceInfo(slot) } end)
            if sourceOk then
                local seenNPCIDs = {}
                for index = 1, #sourceResults, 2 do
                    local guid = sourceResults[index]
                    if type(guid) == "string" and not (issecretvalue and issecretvalue(guid)) then
                        local npcID = GetNPCIDFromGUID(guid)
                        if npcID and not seenNPCIDs[npcID] then
                            seenNPCIDs[npcID] = true
                            self:RecordItemDropForNPC(npcID, itemLink)
                        end
                    end
                end
            else
                Debug("RecordLootDrops: GetLootSourceInfo failed for slot " .. tostring(slot) .. ": " .. tostring(sourceResults))
            end
        end
    end
end

function Addon:GetRepairTargetRun()
    local active = self:GetCurrentRun()
    if active then
        return active
    end

    local last = self:GetLastRun()
    if not last then
        return nil
    end

    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        return last
    end

    local endedAt = last.endedAt or last.startedAt or 0
    if time() - endedAt <= (self.db.lastRepairWindow or 300) then
        return last
    end

    return nil
end

function Addon:RecordRepairCost(cost, reason, targetRun)
    cost = tonumber(cost) or 0
    if cost <= 0 then
        return false
    end

    -- Two independent detection paths both funnel into this one function -- chat-message parsing
    -- (RecordRepairCostFromMessage, its own dedup only guards against the same chat line firing
    -- twice) and merchant money-delta detection (HandleMoneyChanged, no dedup of its own at all).
    -- Neither is aware of the other, so a single real repair transaction that both paths happen to
    -- detect would double-count. Found during the 2026-09-04 full-file audit. Centralized here,
    -- the one place both paths already share, rather than patched separately in each.
    local now = time()
    if self.lastRecordedRepairCost == cost and self.lastRecordedRepairAt and now - self.lastRecordedRepairAt <= 5 then
        Debug(string.format("RecordRepairCost: ignoring likely duplicate of %s recorded %ds ago (source: %s)", FormatMoney(cost), now - self.lastRecordedRepairAt, tostring(reason)))
        return false
    end

    local run = targetRun or self:GetRepairTargetRun()
    if not run then
        Print("No active or recent dungeon run to attach that repair cost to.")
        return false
    end

    self.lastRecordedRepairCost = cost
    self.lastRecordedRepairAt = now
    run.repairCost = (run.repairCost or 0) + cost
    run.repairs = run.repairs or {}
    table.insert(run.repairs, {
        time = time(),
        timeText = date("%Y-%m-%d %H:%M:%S"),
        cost = cost,
        reason = reason or "repair",
    })

    Print(string.format("Added %s repair cost to %s.", FormatMoney(cost), run.instanceName or "last run"))
    self.pendingRepairCost = 0
    self.pendingRepairAt = nil
    self:RefreshAllDisplays()
    return true
end

function Addon:RecordRepairCostFromMessage(message, source)
    local cleanMessage = StripWowText(message or "")
    if cleanMessage == "" or cleanMessage:find("M+ Ledger:", 1, true) then
        return false
    end

    local lowerMessage = string.lower(cleanMessage)
    if not lowerMessage:find("repair%s*cost") then
        return false
    end

    local cost = ParseMoneyAmount(message)
    if cost <= 0 then
        cost = ParseMoneyAmount(cleanMessage)
    end
    if cost <= 0 then
        Debug("Repair cost message had no readable amount: " .. cleanMessage)
        return false
    end

    local now = time()
    if self.lastRepairMessageText == cleanMessage and self.lastRepairMessageCost == cost and self.lastRepairMessageAt and now - self.lastRepairMessageAt <= 3 then
        return false
    end

    local run = self:GetRepairTargetRun()
    if not run then
        Debug("Ignored repair cost message without active/recent run: " .. cleanMessage)
        return false
    end

    self.lastRepairMessageText = cleanMessage
    self.lastRepairMessageCost = cost
    self.lastRepairMessageAt = now
    return self:RecordRepairCost(cost, source or "repair cost message", run)
end

function Addon:HandleMoneyChanged()
    if not GetMoney then
        return
    end

    local currentMoney = GetMoney()
    local previousMoney = self.merchantMoneySnapshot or self.lastKnownMoney
    self.merchantMoneySnapshot = currentMoney
    self.lastKnownMoney = currentMoney

    if not previousMoney or currentMoney >= previousMoney then
        return
    end

    local spent = previousMoney - currentMoney
    local quote = self.pendingRepairCost or 0
    local quoteRecent = self.pendingRepairAt and (time() - self.pendingRepairAt <= 10)
    local likelyRepair = self.repairMerchantOpen or quoteRecent
    if likelyRepair and (quote <= 0 or spent <= quote) then
        self:RecordRepairCost(spent, "merchant money change")
    else
        Debug("Ignored money decrease outside repair context: " .. FormatMoney(spent))
    end
end

function Addon:CaptureRepairQuote()
    if not CanMerchantRepair or not CanMerchantRepair() or not GetRepairAllCost then
        return
    end

    local cost = GetRepairAllCost() or 0
    if cost > 0 then
        self.pendingRepairCost = cost
        self.pendingRepairAt = time()
    end

    if cost > 0 then
        Debug("Repair quote captured: " .. FormatMoney(cost))
    end
end

function Addon:CheckRepairQuoteSettled()
    local quoteRecent = self.pendingRepairAt and (time() - self.pendingRepairAt <= 10)
    if (not self.repairMerchantOpen and not quoteRecent) or not GetRepairAllCost then
        return
    end

    local quote = tonumber(self.pendingRepairCost) or 0
    if quote <= 0 then
        return
    end

    local currentCost = GetRepairAllCost() or 0
    if currentCost <= 0 then
        self:RecordRepairCost(quote, "merchant repair quote settled")
    else
        self.pendingRepairCost = currentCost
        self.pendingRepairAt = time()
    end
end

function Addon:CatchMerchantOpenRepair()
    if not GetMoney then
        return
    end

    local currentMoney = GetMoney()
    local previousMoney = self.lastKnownMoney
    if previousMoney and currentMoney < previousMoney then
        local spent = previousMoney - currentMoney
        local quote = self.pendingRepairCost or 0
        if quote <= 0 or spent <= quote then
            self:RecordRepairCost(spent, "merchant open money drop")
        end
    end
    self.lastKnownMoney = currentMoney
    self.merchantMoneySnapshot = currentMoney
end

function Addon:QueueMerchantOpenRepairCheck()
    self:CatchMerchantOpenRepair()
    self:CheckRepairQuoteSettled()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
            Addon:CatchMerchantOpenRepair()
            Addon:CheckRepairQuoteSettled()
        end)
        C_Timer.After(1, function()
            Addon:CatchMerchantOpenRepair()
            Addon:CheckRepairQuoteSettled()
        end)
        C_Timer.After(2, function()
            Addon:CatchMerchantOpenRepair()
            Addon:CheckRepairQuoteSettled()
        end)
    end
end

function Addon:HookRepairs()
    -- Avoid protected repair hooks while we are chasing taint.
    -- Use /dl repair or the Record Repair button after opening a repair merchant.
    self.repairHooked = true
end

function Addon:HookChatRepairMessages()
    if chatRepairHooked or not hooksecurefunc then
        return
    end

    local function hookFrame(frame)
        if not frame or frame.mplusLedgerRepairHooked then
            return
        end

        frame.mplusLedgerRepairHooked = true
        hooksecurefunc(frame, "AddMessage", function(_, message)
            if not (Addon and Addon.db) then
                return
            end
            if issecretvalue and issecretvalue(message) then
                return
            end
            pcall(Addon.RecordRepairCostFromMessage, Addon, message, "repair cost chat text")
        end)
    end

    if NUM_CHAT_WINDOWS and _G then
        for index = 1, NUM_CHAT_WINDOWS do
            hookFrame(_G["ChatFrame" .. index])
        end
    else
        hookFrame(DEFAULT_CHAT_FRAME)
    end

    chatRepairHooked = true
end


function Addon:GetPlayerGUIDForRun(run)
    return run and (run.playerGUID or SafeUnitGUID("player")) or SafeUnitGUID("player")
end

function Addon:GetPlayerDeaths(run)
    if not run then
        return 0
    end

    if run.playerDeaths then
        return run.playerDeaths
    end

    self:EnsureMemberDeathTables(run)
    local playerGUID = self:GetPlayerGUIDForRun(run)
    local deathInfo = playerGUID and run.memberDeaths and run.memberDeaths[playerGUID]
    return deathInfo and deathInfo.count or 0
end

-- Boss-to-boss segment timings ("splits"): how long each phase of a run took, derived entirely
-- from run.bossKillLog's killTime (elapsed seconds since run start). Boss kill tracking is
-- unaffected by the Secret Value restriction that blocks trash-mob GUIDs (see v0.1.168's
-- findings) -- this is built on already-confirmed-working data, no new event tracking needed.
function Addon:GetBossSegmentTimings(run)
    if not run or not run.bossKillLog or #run.bossKillLog == 0 then
        return {}
    end

    -- bossKillLog is appended in kill order already, but sort by killTime defensively in case an
    -- entry was ever added out of order (e.g. a manual Debug Editor edit).
    local sorted = {}
    for _, entry in ipairs(run.bossKillLog) do
        table.insert(sorted, entry)
    end
    table.sort(sorted, function(a, b) return (tonumber(a.killTime) or 0) < (tonumber(b.killTime) or 0) end)

    local segments = {}
    local previousTime = 0
    for _, entry in ipairs(sorted) do
        local killTime = tonumber(entry.killTime) or previousTime
        -- startTime (from ENCOUNTER_START, added 2026-09-05) splits the old lumped segmentSeconds
        -- into how long the fight itself took vs. how long was spent clearing trash/traveling to
        -- get there. Only available for encounters tracked live since this shipped -- older runs
        -- and manual debug-menu boss entries have no startTime, so fightSeconds/pullSeconds stay
        -- nil for those and only the original lumped segmentSeconds is meaningful.
        local startTime = tonumber(entry.startTime)
        -- Trash-mob count for this same pull window (previousTime -> startTime, or -> killTime if
        -- no startTime), per user request 2026-09-05 ("extend Boss Pacing to trash too") -- the
        -- Pull/Mob zone already measured this whole window's duration, this just tells you how
        -- much of it was actually spent killing trash rather than just traveling. Counts every
        -- run.mobKillLog entry whose own killTime (same elapsed-seconds basis) falls in that
        -- window, so it benefits directly from the more reliable nameplate-based mob-kill capture.
        local windowEnd = startTime or killTime
        local mobKillCount = 0
        for _, mobEntry in ipairs(run.mobKillLog or {}) do
            local mobKillTime = tonumber(mobEntry.killTime)
            if mobKillTime and mobKillTime > previousTime and mobKillTime <= windowEnd then
                mobKillCount = mobKillCount + 1
            end
        end
        table.insert(segments, {
            bossName = entry.name or "Unknown boss",
            bossID = entry.bossID,
            segmentSeconds = math.max(0, killTime - previousTime),
            cumulativeSeconds = killTime,
            startSeconds = startTime,
            fightSeconds = startTime and math.max(0, killTime - startTime) or nil,
            pullSeconds = startTime and math.max(0, startTime - previousTime) or nil,
            pullMobKillCount = mobKillCount,
        })
        previousTime = killTime
    end
    return segments
end

function Addon:GetRunDeathTotal(run)
    if not run then
        return 0
    end

    local total = tonumber(run.deaths) or 0
    self:EnsureMemberDeathTables(run)
    local totalsByIdentity = {}
    local nameToGuid = {}

    for _, member in ipairs(run.members or {}) do
        local normalizedName = NormalizePlayerName(member.name)
        if normalizedName ~= "" and member.guid then
            nameToGuid[normalizedName] = member.guid
        end
    end

    for key, deathInfo in pairs(run.memberDeaths or {}) do
        local count = tonumber(deathInfo and deathInfo.count) or 0
        if count > 0 then
            local normalizedName = NormalizePlayerName(deathInfo.name or tostring(key):gsub("^name:", ""))
            local identity = key
            if type(key) == "string" and key:match("^name:") then
                identity = nameToGuid[normalizedName] or key
            end
            totalsByIdentity[identity] = math.max(totalsByIdentity[identity] or 0, count)
        end
    end

    local memberTotal = 0
    for _, count in pairs(totalsByIdentity) do
        memberTotal = memberTotal + count
    end

    total = math.max(total, memberTotal, tonumber(run.playerDeaths) or 0)
    return total
end

function Addon:GetRunStatus(run)
    if not run then
        return "No run"
    end

    if not run.endedAt then
        return "Active"
    end

    return run.runStatus or "Abandoned"
end

function Addon:GetIncompleteStatusLabel(run)
    return self:IsMythicPlusRun(run) and "Abandoned" or "Left"
end

-- Xal'atath's Guile (this season's death-timer affix, verified level 12+ -- see AFFIX_KNOWLEDGE)
-- subtracts 15 seconds off the keystone timer per death. Below that key level there's no verified
-- death-timer penalty, so this returns 0 rather than guessing at one. Per user request 2026-09-05
-- ("time lost to deaths... as a stat").
local DEATH_TIMER_PENALTY_SECONDS = 15
local DEATH_TIMER_PENALTY_MIN_KEY_LEVEL = 12
function Addon:GetRunDeathTimePenaltySeconds(run)
    if not run or self:GetRunKeyLevel(run) < DEATH_TIMER_PENALTY_MIN_KEY_LEVEL then
        return 0
    end
    return self:GetRunDeathTotal(run) * DEATH_TIMER_PENALTY_SECONDS
end

-- Only meaningful for a run that actually went overtime: the penalty is what pushed the EFFECTIVE
-- time (real clock duration + penalty) past the limit, so this compares the real clock duration
-- alone against the limit to see whether the deaths were the actual reason it didn't time. Left
-- deliberately unanswered (returns nil) for Completed/Abandoned runs -- a Completed run timed
-- regardless, and an Abandoned one wasn't necessarily a timer failure at all (could be a disband),
-- so there's nothing honest to claim there without more data than M+ Ledger actually has.
function Addon:WouldHaveTimedWithoutDeaths(run)
    if self:GetRunStatus(run) ~= "CompletedOvertime" then
        return nil
    end
    local penalty = self:GetRunDeathTimePenaltySeconds(run)
    if penalty <= 0 then
        return nil
    end
    local timeLimit = self:GetMythicPlusTimeLimit(run) or self:GetMythicPlusTimeLimit(run.instanceName)
    if not timeLimit then
        return nil
    end
    return GetRunDuration(run) <= timeLimit
end

function Addon:GetRunDisplayStatus(run)
    local status = self:GetRunStatus(run)
    if status == "CompletedOvertime" then
        return "Completed / Overtime"
    end
    if status == "Abandoned" then
        return self:GetIncompleteStatusLabel(run)
    end
    return status
end

function Addon:MarkRunCompleted(run, reason)
    if not run then
        return false
    end

    run.completionReason = reason or "completion detected"
    run.completedAt = time()
    run.completedAtText = date("%Y-%m-%d %H:%M:%S")
    run.leftWithoutCompletion = false
    run.abandonedReason = nil
    run.runStatus = "Completed"
    run.completedOvertime = nil
    run.overtime = nil
    if not run.endedAt then
        run.endedAt = run.completedAt
        run.endedAtText = run.completedAtText
    end
    run.duration = GetRunDuration(run)
    self:ApplyMythicPlusCompletionStatus(run)
    if self.db and self.db.currentRunID == run.id then
        self.db.currentRunID = nil
    end
    if self.db then
        self.db.lastRunID = run.id
    end
    self.deathPending = false
    Print("Completed " .. tostring(run.instanceName or "run") .. ".")
    self:RefreshAllDisplays()
    self:PromptPlayerRatings(run)
    return true
end

function Addon:MarkCurrentRunCompleted(reason)
    return self:MarkRunCompleted(self:GetCurrentRun(), reason)
end

-- ============================================================================================
-- Post-run rating popup, per user request 2026-09-05 ("add a popup menu for when the dungeon is
-- finished, to ask the user to rate each player... 1-5 stars... a comment as well... added into
-- the player manage data section"). Fires from MarkRunCompleted (the actual "dungeon is finished"
-- moment, not EndRun -- that also covers abandons, which aren't what "finished" means here).
-- Feeds the EXISTING Good/Okay/Bad rating system (see RATING_META/GetPlayerProfile above) rather
-- than building a parallel one -- StarsToRatingCategory maps the star pick to that category using
-- the user's own thresholds, and the star pick/comment are additionally kept as their own history
-- (profile.starHistory) so more detail survives than the single-value rating/notes fields alone.
-- ============================================================================================
local RATING_POPUP_STAR_COUNT = 5
local RATING_POPUP_ROW_HEIGHT = 100
local RATING_POPUP_ROW_GAP = 6
-- Was 8 -- raids can have far more than 8 other members, and any member past the pool size wasn't
-- just visually cut off, it was silently never shown or saveable at all (PromptPlayerRatings loops
-- ipairs(frame.rows), so ratable[9+] was never even looked at). Raised to comfortably cover any
-- raid size; scrolling (below) keeps the window itself from growing to fit all of them at once.
local RATING_POPUP_ROW_POOL = 40
-- How many rows are visible at once before the list scrolls -- keeps the popup a sane, constant
-- size for a 2-person dungeon group and a 30-person raid alike, instead of the window growing to
-- fit every member (which for a raid produced a mostly-empty window taller than the screen, since
-- only the first 8 of those rows actually existed).
local RATING_POPUP_VISIBLE_ROWS = 4

function Addon:CreateRatingPopupWindow()
    if self.ratingPopup then
        return
    end

    local frame = CreateFrame("Frame", "MPlusLedgerRatingPopup", UIParent, "BackdropTemplate")
    frame:SetSize(640, 156 + RATING_POPUP_VISIBLE_ROWS * (RATING_POPUP_ROW_HEIGHT + RATING_POPUP_ROW_GAP))
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    frame:SetBackdropColor(Addon:GetTableBackgroundColor(0.97))
    frame:SetBackdropBorderColor(self:GetThemeBorderColor(true, 1))
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetTextColor(1, 1, 1)
    title:SetText("Rate Your Party"); frame.partyTitle = title

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", 18, -40)
    subtitle:SetWidth(604)
    subtitle:SetJustifyH("LEFT")
    frame.subtitle = subtitle

    -- Note line + per-row meta text added 2026-09-05, per user request: name/class/race/faction/
    -- role/realm should all be pulled in automatically, leaving only Rating and Comment for the
    -- user to actually fill in.
    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 18, -62)
    note:SetText("Choose stars for anyone you want to rate. Click the selected star again to clear it."); frame.partyNote = note

    local skip = self:CreatePlainButton(frame, "Skip for now", 126, 32); frame.partySkip = skip
    skip:SetPoint("BOTTOMRIGHT", -192, 16)
    skip:SetScript("OnClick", function()
        frame:Hide()
    end)

    local save = self:CreatePlainButton(frame, "Save Ratings", 160, 32)
    save:SetPoint("BOTTOMRIGHT", -18, 16)
    frame.saveButton = save
    frame.selectionSummary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.selectionSummary:SetPoint("BOTTOMLEFT", 18, 34)
    frame.selectionSummary:SetWidth(280)
    frame.selectionSummary:SetJustifyH("LEFT")
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 18, 18)
    hint:SetText("Unrated players stay unchanged."); frame.partyHint = hint
    function frame:UpdateSelectionSummary()
        local count, total = 0, 0
        for _, row in ipairs(self.rows or {}) do
            if row.memberName then
                total = total + 1
                if row.selectedStars then count = count + 1 end
            end
        end
        self.selectionSummary:SetText(string.format("%d of %d players rated", count, total))
        self.saveButton:SetEnabled(count > 0)
    end
    save:SetScript("OnClick", function()
        Addon:SaveRatingPopup()
    end)

    -- Scrollable row list, added 2026-09-09 per user request ("could you make it so there are
    -- pages or scrolls there are over 5 players?") -- a raid's roster no longer fits on-screen as
    -- a flat list the way a 4-person dungeon party did. Same smooth-scroll technique already used
    -- elsewhere in this file (Season/Progress/Trends tabs).
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -90)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 66)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self:GetVerticalScrollRange())
        local target = math.max(0, math.min(maxScroll, (self.targetScroll or self:GetVerticalScroll()) - (delta * 40)))
        self.targetScroll = target
    end)
    scrollFrame:SetScript("OnUpdate", function(self, elapsed)
        local target = self.targetScroll
        if not target then
            return
        end
        local current = self:GetVerticalScroll()
        if math.abs(target - current) < 0.5 then
            self:SetVerticalScroll(target)
            self.targetScroll = nil
            return
        end
        self:SetVerticalScroll(current + (target - current) * math.min(1, elapsed * 12))
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(600, RATING_POPUP_ROW_POOL * (RATING_POPUP_ROW_HEIGHT + RATING_POPUP_ROW_GAP))
    scrollFrame:SetScrollChild(scrollContent)
    frame.scrollFrame = scrollFrame
    frame.scrollContent = scrollContent

    frame.rows = {}
    for index = 1, RATING_POPUP_ROW_POOL do
        local row = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        row:SetSize(596, RATING_POPUP_ROW_HEIGHT)
        row:SetPoint("TOP", 0, -(index - 1) * (RATING_POPUP_ROW_HEIGHT + RATING_POPUP_ROW_GAP))
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        row:SetBackdropColor(0.035, 0.04, 0.05, 1)
        row:SetBackdropBorderColor(self:GetThemeBorderColor(false, 0.6))

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", 14, -10)
        row.name:SetWidth(560)
        row.name:SetJustifyH("LEFT")

        -- Race/Faction/Class/Role/Realm, pulled from the run's own roster capture (see
        -- GetGroupRoster's UnitRace/UnitFactionGroup addition) -- see BuildRatingMetaText.
        row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.meta:SetPoint("TOPLEFT", 14, -29)
        row.meta:SetWidth(560)
        row.meta:SetJustifyH("LEFT")

        row.ratingLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.ratingLabel:SetPoint("TOPLEFT", 14, -82)
        row.ratingLabel:SetText("Not rated")

        -- Sets every star's icon/highlight for a given "count" (how many stars should look
        -- filled+highlighted) -- shared by click (permanent selection) and hover (temporary
        -- preview) so both stay perfectly consistent instead of duplicating the same logic twice.
        local ratingNames = {"Avoid", "Neutral", "Neutral", "Good", "Excellent"}
        local function SetRowStarDisplay(count)
            row.ratingLabel:SetText(count > 0 and (count .. "/5 - " .. ratingNames[count]) or "Not rated")
            for i, star in ipairs(row.stars) do
                if i <= count then
                    star.icon:SetTexture(RATING_STAR_FILLED_TEXTURE)
                    star.icon:SetVertexColor(1, 0.82, 0, 1)
                    star.highlight:Show()
                else
                    star.icon:SetTexture(RATING_STAR_EMPTY_TEXTURE)
                    star.icon:SetVertexColor(0.5, 0.5, 0.5, 1)
                    star.highlight:Hide()
                end
            end
        end
        row.SetRowStarDisplay = SetRowStarDisplay

        row.stars = {}
        for starIndex = 1, RATING_POPUP_STAR_COUNT do
            local starButton = CreateFrame("Button", nil, row)
            starButton:SetSize(28, 28)
            starButton:SetPoint("TOPLEFT", 14 + (starIndex - 1) * 32, -50)

            -- Semi-transparent yellow box behind the star, per user request -- shown for every
            -- star at-or-below whichever count is currently being displayed (hover preview or the
            -- real selection), so it reads as "these stars are what you're about to/did pick."
            starButton.highlight = starButton:CreateTexture(nil, "BACKGROUND")
            starButton.highlight:SetAllPoints(starButton)
            starButton.highlight:SetColorTexture(1, 0.85, 0, 0.35)
            starButton.highlight:Hide()

            starButton.icon = starButton:CreateTexture(nil, "ARTWORK")
            starButton.icon:SetPoint("CENTER")
            starButton.icon:SetSize(24, 24)
            starButton.icon:SetTexture(RATING_STAR_EMPTY_TEXTURE)
            starButton.icon:SetVertexColor(0.5, 0.5, 0.5, 1)

            starButton.starIndex = starIndex
            starButton:SetScript("OnClick", function()
                row.selectedStars = row.selectedStars ~= starIndex and starIndex or nil
                SetRowStarDisplay(row.selectedStars or 0)
                frame:UpdateSelectionSummary()
            end)
            starButton:SetScript("OnEnter", function(self)
                SetRowStarDisplay(self.starIndex)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.starIndex .. " star" .. (self.starIndex > 1 and "s" or ""))
                if self.starIndex == 1 then
                    GameTooltip:AddLine("Avoid", 1, 0.4, 0.4)
                elseif self.starIndex <= 3 then
                    GameTooltip:AddLine("Neutral", 1, 1, 0.4)
                else
                    GameTooltip:AddLine("Good / Excellent", 0.4, 1, 0.4)
                end
                GameTooltip:Show()
            end)
            starButton:SetScript("OnLeave", function()
                -- Reverts to the real selection (or nothing selected) rather than staying on
                -- whatever star was just hovered -- otherwise leaving the row would freeze the
                -- last-hovered preview in place instead of showing the actual saved choice.
                SetRowStarDisplay(row.selectedStars or 0)
                GameTooltip:Hide()
            end)
            row.stars[starIndex] = starButton
        end

        row.comment = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.comment:SetHeight(28)
        row.comment:SetPoint("TOPLEFT", 226, -64)
        local commentLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        commentLabel:SetPoint("TOPLEFT", 222, -46)
        commentLabel:SetText("Note (optional; saved with a rating)"); row.commentLabel = commentLabel
        row.comment:SetPoint("RIGHT", -14, 0)
        row.comment:SetAutoFocus(false)
        row.comment:SetTextInsets(4, 4, 0, 0)
        row.comment:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        local placeholder = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        placeholder:SetPoint("LEFT", row.comment, "LEFT", 8, 0)
        placeholder:SetText("What would you like to remember?")
        row.comment:SetScript("OnEditFocusGained", function()
            placeholder:Hide()
        end)
        row.comment:SetScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                placeholder:Show()
            end
        end)
        row.placeholder = placeholder

        row:Hide()
        frame.rows[index] = row
    end

    self.ratingPopup = frame
end

-- Builds the "Race | Faction | Class | Role | Realm" line per row -- degrades gracefully, omitting
-- whichever pieces aren't known (an older run recorded before UnitRace/UnitFactionGroup capture
-- was added, or a member only ever resolved through a name fallback with no live unit data).
local function BuildRatingMetaText(member, realm)
    local parts = {}
if member.faction and member.faction ~= "" then
        table.insert(parts, member.faction)
    end
    if member.class and member.class ~= "" then
        table.insert(parts, (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[member.class]) or member.class)
    end
    if member.role and member.role ~= "" and member.role ~= "NONE" then
        table.insert(parts, GetRoleLabel(member.role))
    end
    if realm and realm ~= "" then
        table.insert(parts, realm)
    end
    return table.concat(parts, " | ")
end

-- preview: shown from /mledger test with a made-up party -- ignores the hide setting and the
-- once-per-run guard, and SaveRatingPopup never writes anything for it.
function Addon:PromptPlayerRatings(run, preview)
    -- Default-on privacy/display preference; manual Player History remains available.
    if not preview and (not self.db or self.db.hidePostDungeonReputation ~= false) then
        return
    end
    -- Guarded against firing twice for the same run -- this is now called from both
    -- MarkRunCompleted (boss-kill completion) and EndRun (covers raids/partial runs that never
    -- hit that trigger), so a run that completes AND THEN the player leaves shortly after would
    -- otherwise show this popup twice.
    if not run or not run.members or (run.ratingsPrompted and not preview) then
        return
    end
    run.ratingsPrompted = true
    local playerFullName = GetUnitFullName and GetUnitFullName("player") or nil
    local ratable = {}
    for _, member in ipairs(run.members) do
        if member.name and member.name ~= playerFullName then
            table.insert(ratable, member)
        end
    end
    if #ratable == 0 then
        return
    end

    self:CreateRatingPopupWindow()
    local frame = self.ratingPopup
    frame.runID = run.id
    frame.preview = preview and true or nil
    frame.subtitle:SetText((run.instanceName and ("After " .. run.instanceName) or "After this run") .. (preview and "  |cff9aa3a8- PREVIEW|r" or ""))

    for index, row in ipairs(frame.rows) do
        local member = ratable[index]
        if member then
            row.memberName = member.name; row.ratingMember = member
            local classColor = RAID_CLASS_COLORS and member.class and RAID_CLASS_COLORS[member.class]
            if classColor then
                row.name:SetTextColor(classColor.r, classColor.g, classColor.b)
            else
                row.name:SetTextColor(1, 1, 1)
            end
            row.name:SetText(GetShortName(member.name))
            local _, realm = GetPlayerRealmName(member.name)
            row.meta:SetText(BuildRatingMetaText(member, realm))
            row.selectedStars = nil
            row.SetRowStarDisplay(0)
            row.comment:SetText("")
            row.placeholder:Show()
            row:Show()
        else
            row.memberName = nil
            row:Hide()
        end
    end

    -- Outer window stays a fixed height (enough for RATING_POPUP_VISIBLE_ROWS at once) regardless
    -- of party vs. raid size -- only the scroll content grows with #ratable, so a 25-person raid
    -- scrolls instead of producing a mostly-empty window taller than the screen.
    local visibleRows = math.min(#ratable, RATING_POPUP_VISIBLE_ROWS)
    frame:SetHeight(156 + math.max(1, visibleRows) * (RATING_POPUP_ROW_HEIGHT + RATING_POPUP_ROW_GAP))
    frame.scrollContent:SetHeight(math.max(1, #ratable * (RATING_POPUP_ROW_HEIGHT + RATING_POPUP_ROW_GAP)))
    frame.scrollFrame.targetScroll = nil
    frame.scrollFrame:SetVerticalScroll(0)
    frame:UpdateSelectionSummary()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:Show()
    frame:Raise()
end

function Addon:SaveRatingPopup()
    local frame = self.ratingPopup
    if not frame then
        return
    end
    if frame.preview then
        frame:Hide()
        Print("Preview only -- example ratings were not saved.")
        return
    end

    local savedCount = 0
    for _, row in ipairs(frame.rows) do
        if row.memberName and row.selectedStars then
            local profile = self:GetPlayerProfile(row.memberName)
            if profile then
                profile.rating = StarsToRatingCategory(row.selectedStars)
                profile.lastStars = row.selectedStars
                self:StampProfileRecordedBy(profile)
                local comment = strtrim(row.comment:GetText() or "")
                if comment ~= "" then
                    profile.notes = comment
                end
                profile.starHistory = profile.starHistory or {}
                table.insert(profile.starHistory, {
                    stars = row.selectedStars,
                    comment = comment ~= "" and comment or nil,
                    runID = frame.runID,
                    date = time(),
                    dateText = date("%Y-%m-%d %H:%M:%S"),
                })
                -- Cap history length -- this is a supplementary log, not meant to grow unbounded
                -- across a whole account's lifetime.
                while #profile.starHistory > 20 do
                    table.remove(profile.starHistory, 1)
                end
                savedCount = savedCount + 1
            end
        end
    end

    frame:Hide()
    if savedCount > 0 then
        Print(string.format("Saved %d player rating(s).", savedCount))
        self:RefreshAllDisplays()
    else
        Print("No ratings selected -- nothing saved.")
    end
end

-- SCENARIO_COMPLETED used to call MarkCurrentRunCompleted directly, with zero validation -- the
-- one remaining completion trigger in this file with none, found during the 2026-09-04 full-file
-- audit. Couldn't confirm via documentation whether this event is genuinely guaranteed to fire
-- only once at the true end of a multi-stage scenario, or whether (like SCENARIO_CRITERIA_UPDATE
-- turned out to be) it can fire per-stage too. Applying the same currentStage==numStages guard as
-- CheckScenarioCriteriaCompletion costs nothing if this event is already reliable (a real
-- whole-scenario completion naturally has currentStage==numStages anyway) and protects against it
-- if it isn't -- matching this session's now-established rule of never trusting a single Blizzard
-- completion signal without a second check.
function Addon:HandleScenarioCompletedEvent(reason)
    local run = self:GetCurrentRun()
    if not run or run.runStatus == "Completed" or run.runStatus == "CompletedOvertime" then
        return
    end
    if C_Scenario and C_Scenario.GetInfo then
        local stageOk, _, currentStage, numStages = pcall(C_Scenario.GetInfo)
        if stageOk and currentStage and numStages and currentStage < numStages then
            Debug(string.format("HandleScenarioCompletedEvent: ignoring SCENARIO_COMPLETED on stage %s/%s (not the final stage).", tostring(currentStage), tostring(numStages)))
            return
        end
    end
    self:MarkCurrentRunCompleted(reason)
end

function Addon:CheckScenarioCriteriaCompletion(reason)
    local run = self:GetCurrentRun()
    if not run or run.runStatus == "Completed" or run.runStatus == "CompletedOvertime" then
        return
    end
    if not C_Scenario or not C_Scenario.GetStepInfo or not C_ScenarioInfo or not C_ScenarioInfo.GetCriteriaInfo then
        return
    end

    -- Found 2026-09-04: a dungeon with sequential/phased objectives (confirmed on Voidscar Arena,
    -- an "Arena"-style M+ with 3 bosses gating progression) only exposes the CURRENT phase's
    -- criteria via GetCriteriaInfo -- so "every visible boss criterion is completed" was true
    -- after just the first of three bosses, and this function wrongly ended the whole run right
    -- there. Confirmed live: run marked Completed at 9:06 elapsed having killed only Taz'Rah,
    -- while the actual key kept running another ~20 minutes -- this is also why the tracker bar
    -- appeared to "stop tracking" around that mark, since GetCurrentRun() then returned nil for
    -- the rest of the real dungeon. C_Scenario.GetStepInfo()'s 3rd return is the CURRENT stage's
    -- criteria count, not a total-stage count -- that's a separate call, C_Scenario.GetInfo(),
    -- which returns currentStage/numStages. Require actually being on the final stage before
    -- trusting "criteria all completed" as "run completed"; if that call isn't available, stay
    -- conservative and skip this path entirely (boss-checklist-based completion elsewhere is
    -- unaffected). Harmless for an ordinary single-stage dungeon (currentStage == numStages there
    -- from the start).
    if not C_Scenario.GetInfo then
        return
    end
    local stageOk, _, currentStage, numStages = pcall(C_Scenario.GetInfo)
    if not stageOk or not currentStage or not numStages or currentStage < numStages then
        return
    end

    local ok, _, _, steps = pcall(C_Scenario.GetStepInfo)
    if not ok or not steps or steps <= 0 then
        return
    end

    local sawBossCriteria = false
    for i = 1, steps do
        local infoOk, criteriaInfo = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
        if not infoOk or not criteriaInfo then
            return
        end
        if not criteriaInfo.isWeightedProgress then
            sawBossCriteria = true
            if not criteriaInfo.completed then
                return
            end
        end
    end

    if not sawBossCriteria then
        return
    end

    Debug(string.format("All boss scenario criteria completed on final stage %s/%s (%s).", tostring(currentStage), tostring(numStages), tostring(reason)))
    self:MarkCurrentRunCompleted(reason or "scenario criteria completed")
end

-- Enemy Forces % tracking (GetEnemyForcesProgress, GetEnemyForcesCrossCheck, the MDT-sourced
-- per-mob weight tables, the tracker bar's Enemy Forces bar, and the /dl scenario debug command)
-- was removed here per user request (2026-09-16) -- despite several rounds of fixes across this
-- project's history (mismatched criteria, Secret Value fields, wrong-criterion disambiguation),
-- it never became reliable, and Blizzard's own client-side scenario tracker already shows this
-- information natively. Removing the MDT-derived data also removed this project's only reason for
-- carrying the GPL-2.0 license -- see the License section in STATUS.md and the .toc for that.

function Addon:BuildChallengeIconCache()
    if challengeIconCache and challengeNameCache then
        return
    end

    challengeIconCache = {}
    challengeNameCache = {}

    if not C_ChallengeMode or not C_ChallengeMode.GetMapTable or not C_ChallengeMode.GetMapUIInfo then
        return
    end

    local ok, mapTable = pcall(C_ChallengeMode.GetMapTable)
    if not ok or type(mapTable) ~= "table" then
        return
    end

    for _, challengeMapID in ipairs(mapTable) do
        local values = { pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID) }
        if values[1] then
            local name = values[2]
            local texture = values[5] or FirstTextureValue(select(2, TableUnpack(values)))
            if texture then
                challengeIconCache[challengeMapID] = texture
            end
            if name and texture then
                challengeNameCache[NormalizeDungeonName(name)] = texture
            end
        end
    end
end

function Addon:GetChallengeDungeonIcon(runOrName)
    self:BuildChallengeIconCache()
    if not challengeIconCache or not challengeNameCache then
        return nil
    end

    if type(runOrName) == "table" then
        local challengeMapID = tonumber(runOrName.challengeMapID)
        if challengeMapID and challengeIconCache[challengeMapID] then
            return challengeIconCache[challengeMapID]
        end
        if challengeMapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
            local values = { pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID) }
            if values[1] then
                local texture = values[5] or FirstTextureValue(select(2, TableUnpack(values)))
                if texture then
                    challengeIconCache[challengeMapID] = texture
                    if values[2] then
                        challengeNameCache[NormalizeDungeonName(values[2])] = texture
                    end
                    return texture
                end
            end
        end
        return challengeNameCache[NormalizeDungeonName(runOrName.instanceName)]
    end

    return challengeNameCache[NormalizeDungeonName(runOrName)]
end

function Addon:GetDumpedDungeonIcon(runOrName)
    local name = type(runOrName) == "table" and runOrName.instanceName or runOrName
    local normalizedName = NormalizeDungeonName(name)
    if normalizedName == "" or not self.db or not self.db.iconDumps then
        return nil
    end

    for _, entry in ipairs(self.db.iconDumps.challengeDungeons or {}) do
        if NormalizeDungeonName(entry.name) == normalizedName and entry.texture and entry.texture ~= "" then
            return entry.texture
        end
    end

    for _, entry in ipairs(self.db.iconDumps.encounterJournal or {}) do
        local entryName = entry.name
        if type(entryName) ~= "string" and type(entry.mapID) == "string" then
            entryName = entry.mapID:match("%[(.-)%]")
        end

        if NormalizeDungeonName(entryName) == normalizedName then
            local texture = entry.buttonImage
            if not texture or texture == "" or type(entry.name) ~= "string" then
                texture = entry.buttonImage2 or entry.loreImage or entry.bgImage
            end
            if texture and texture ~= "" then
                return texture
            end
        end
    end

    return nil
end

-- UI theme (new 2026-09-06, per user request for a toggle-able redesign concept): a small shared
-- color palette, not a parallel set of frames -- every existing window keeps its exact layout and
-- widgets, only the border/accent colors it already pulls from a fixed RGB literal now come from
-- here instead, so "classic" (the original gold WoW-tooltip look) and "arcane" (the new teal/
-- violet look from the mockup) can be toggled live without maintaining two codebases. Real WoW
-- frames can't do CSS rounded corners, gradients, or glow, so this is a re-color, not a re-shape.
local UI_THEMES = {
    classic = {
        tileBorder = { 0.55, 0.42, 0.15, 0.8 },
        tileBorderHover = { 0.9, 0.75, 0.25, 1 },
        accentText = { 1, 0.82, 0.35 },
        barGood = { 0.20, 0.70, 0.30 },
        barWarn = { 0.85, 0.65, 0.15 },
    },
    arcane = {
        tileBorder = { 0.16, 0.45, 0.42, 0.85 },
        tileBorderHover = { 0.26, 0.85, 0.78, 1 },
        accentText = { 0.42, 0.85, 0.78 },
        barGood = { 0.29, 0.76, 0.49 },
        barWarn = { 0.63, 0.48, 1.0 },
    },
}

function Addon:GetTheme()
    -- A custom accent color (Settings > Colours, added 2026-09-08) overrides the classic/arcane
    -- theme choice for the accent-ish fields specifically -- barGood/barWarn (status-adjacent, not
    -- really "accent") still come from the base theme so a single accent pick doesn't also
    -- silently recolor unrelated good/warn indicators.
    -- Custom accent/table colours removed 2026-10-08 (user request): the theme decides them now,
    -- and any old saved override (db.colors.accent / tableBackground) is ignored.
    local custom
    if self.db then
        if self.db.assetTheme == "garnetsilver" then custom = { .83, .85, .88 }
        elseif self.db.assetTheme == "garnet" then custom = { .78, .34, .46 }
        elseif self.db.assetTheme == "midnight" then custom = { .66, .46, .94 } end
    end
    if custom then
        local base = UI_THEMES[(self.db.uiTheme) or "classic"] or UI_THEMES.classic
        local function brighten(v, factor)
            return math.min((v or 0) * factor, 1)
        end
        return {
            tileBorder = { custom[1], custom[2], custom[3], 0.8 },
            tileBorderHover = { brighten(custom[1], 1.25), brighten(custom[2], 1.25), brighten(custom[3], 1.25), 1 },
            accentText = { brighten(custom[1], 1.15), brighten(custom[2], 1.15), brighten(custom[3], 1.15) },
            barGood = base.barGood,
            barWarn = base.barWarn,
        }
    end
    local key = (self.db and self.db.uiTheme) or "classic"
    return UI_THEMES[key] or UI_THEMES.classic
end

-- ============================================================================================
-- Customizable colors (added 2026-09-08, per user request: "adding changing of colours for
-- dungeons, tables etc... have a selection menu for it"). self.db.colors holds only the
-- OVERRIDES a user has actually picked -- an unset field always means "use the addon's own
-- built-in default", never a color literal duplicated here, so there's exactly one place (the
-- original tables/literals already in the file) that defines what "default" means.
-- ============================================================================================

-- Table/list backgrounds: was a hardcoded (0.04, 0.04, 0.04) literal at 16 call sites across
-- every major window (Season/Progress/M+ Stats/Trends tabs, Mob Browser, etc.) -- bulk-replaced
-- with calls to this getter so one picked color re-themes all of them at once.
function Addon:GetTableBackgroundColor(alpha)
    if self.db and self.db.assetTheme == "garnetsilver" then return .065,.025,.034,alpha or .95 end
    if self.db and self.db.assetTheme == "garnet" then return .075,.025,.041,alpha or .95 end
    if self.db and self.db.assetTheme == "midnight" then return .039,.025,.078,alpha or .95 end
    return 0.04, 0.04, 0.04, alpha or 0.95
end

-- Status colors (Completed/Overtime/Abandoned): STATUS_BACKDROP_COLORS and PROGRESS_STATUS_COLORS
-- (below) are wrapped in a metatable that checks this first -- every existing call site (both the
-- bracket and dotted-field forms, ~20 of them across Manage Data buttons, the Progress chart, and
-- dungeon card ribbons) picks up a custom color automatically, with zero changes needed at any of
-- those call sites individually.
function Addon:GetCustomStatusColor(status)
    return self.db and self.db.colors and self.db.colors.status and self.db.colors.status[status]
end

-- Per-dungeon accent color: applied to that dungeon's card border on the main window. name is the
-- dungeon's instanceName (matches every other per-dungeon lookup in this file, e.g. DUNGEON_ICONS).
function Addon:GetDungeonColor(name)
    return name and self.db and self.db.colors and self.db.colors.dungeon and self.db.colors.dungeon[name]
end

function Addon:SetDungeonColor(name, r, g, b)
    if not name then
        return
    end
    self.db.colors = self.db.colors or {}
    self.db.colors.dungeon = self.db.colors.dungeon or {}
    if r then
        self.db.colors.dungeon[name] = { r, g, b }
    else
        self.db.colors.dungeon[name] = nil
    end
end

-- Per user request 2026-09-30: 0-45% red, 46-70% yellow, 71-90% green, 91-100% a distinct
-- "special" color -- WoW's own Legendary-quality orange, the most prestigious item rarity color in
-- the game, so a genuinely great completion rate reads as such at a glance rather than blending in
-- with "merely good" green.
function Addon:GetCompletionRateColor(pct)
    pct = tonumber(pct) or 0
    if pct >= 91 then
        return 1.0, 0.5, 0.0
    elseif pct >= 71 then
        return 0.20, 0.85, 0.30
    elseif pct >= 46 then
        return 0.90, 0.80, 0.10
    end
    return 0.85, 0.20, 0.20
end

-- Shared color-picker plumbing. ColorPickerFrame:SetupColorPickerAndShow is the current API
-- (relocated here from the old global OpenColorPicker in patch 10.2.5, confirmed still current
-- before using it) -- there is only ever one ColorPickerFrame instance, so this can't be open
-- twice at once, same limitation every other addon using it has.
function Addon:ShowColorPicker(r, g, b, onColorChosen)
    if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
        Print("Color picker unavailable on this client.")
        return
    end
    local function Apply()
        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        if onColorChosen then
            onColorChosen(newR, newG, newB)
        end
    end
    local function Restore()
        local oldR, oldG, oldB = ColorPickerFrame:GetPreviousValues()
        if onColorChosen then
            onColorChosen(oldR, oldG, oldB)
        end
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        swatchFunc = Apply,
        cancelFunc = Restore,
        hasOpacity = false,
        r = r or 1,
        g = g or 1,
        b = b or 1,
    })
end

-- A small color-swatch button: click to open the picker, shows the current color as a filled
-- square. getColor() returns r,g,b (or nil for "use default", shown as a checkerboard-free plain
-- grey). setColor(r,g,b) is called with nil,nil,nil to mean "reset to default" (from the button's
-- own right-click, since the picker itself has no "clear" option).
function Addon:CreateColorSwatchButton(parent, size, getColor, setColor)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    size = size or 24
    button:SetSize(size, size)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    function button:Refresh()
        local r, g, b = getColor()
        if r then
            self:SetBackdropColor(r, g, b, 1)
        else
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end
    end

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            setColor(nil, nil, nil)
            self:Refresh()
            return
        end
        local r, g, b = getColor()
        Addon:ShowColorPicker(r or 1, g or 1, b or 1, function(newR, newG, newB)
            setColor(newR, newG, newB)
            self:Refresh()
        end)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Left-click to pick a color, right-click to reset to default.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:Refresh()
    return button
end

-- Shared helper so every window's border color routes through the active theme instead of a
-- hardcoded literal -- `hover` picks the brighter/accent variant (the old flat gold used for
-- window frames, active borders, and OnEnter states), false picks the dimmer/idle variant (the
-- old muted gold used for resting tile/panel borders). `alpha` overrides that variant's own
-- default alpha so every existing call site's exact original alpha is preserved.
function Addon:GetThemeBorderColor(hover, alpha)
    local theme = self:GetTheme()
    local base = hover and theme.tileBorderHover or theme.tileBorder
    return base[1], base[2], base[3], alpha or base[4]
end

function Addon:GetDungeonIcon(runOrName)
    local name = type(runOrName) == "table" and runOrName.instanceName or runOrName
    return self:GetChallengeDungeonIcon(runOrName) or self:GetDumpedDungeonIcon(runOrName) or DUNGEON_ICONS[name or ""] or DEFAULT_DUNGEON_ICON
end

function Addon:SetRowIcon(row, texture, size, dungeonName)
    if not row or not row.icon then
        return
    end

    row.icon:SetTexture(texture or DEFAULT_DUNGEON_ICON)
    row.icon:SetSize(size or 42, size or 42)
    local crop = DUNGEON_ICON_CROPS[dungeonName or ""]
    if crop then
        row.icon:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
    else
        row.icon:SetTexCoord(0.16, 0.84, 0.16, 0.84)
    end
end

local function TextureToSavedValue(texture)
    if type(texture) == "number" or type(texture) == "string" then
        return texture
    end
    return tostring(texture or "")
end

function Addon:DumpChallengeDungeonIcons()
    local entries = {}
    if not C_ChallengeMode or not C_ChallengeMode.GetMapTable or not C_ChallengeMode.GetMapUIInfo then
        return entries
    end

    local ok, mapTable = pcall(C_ChallengeMode.GetMapTable)
    if not ok or type(mapTable) ~= "table" then
        return entries
    end

    for _, challengeMapID in ipairs(mapTable) do
        local values = { pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID) }
        if values[1] then
            local name = values[2]
            local texture = values[5] or FirstTextureValue(select(2, TableUnpack(values)))
            local rawLimit = values[4]
            local timeLimitSeconds = (not (issecretvalue and issecretvalue(rawLimit))) and tonumber(rawLimit) or nil
            if timeLimitSeconds and timeLimitSeconds <= 0 then
                timeLimitSeconds = nil
            end
            if name or texture then
                table.insert(entries, {
                    challengeMapID = challengeMapID,
                    name = name or ("Challenge Map " .. tostring(challengeMapID)),
                    texture = TextureToSavedValue(texture),
                    timeLimitSeconds = timeLimitSeconds,
                })
            end
        end
    end

    table.sort(entries, function(left, right)
        return tostring(left.name or "") < tostring(right.name or "")
    end)
    return entries
end

function Addon:LoadEncounterJournalForIconDump()
    if EJ_GetInstanceByIndex then
        return true
    end

    if EncounterJournal_LoadUI then
        local ok, result = pcall(EncounterJournal_LoadUI)
        if not ok then
            Print("Could not load Encounter Journal UI: " .. tostring(result))
        end
    end

    local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if not EJ_GetInstanceByIndex and loader then
        local ok, result = pcall(loader, "Blizzard_EncounterJournal")
        if not ok then
            Print("Could not load Blizzard_EncounterJournal: " .. tostring(result))
        end
    end

    return EJ_GetInstanceByIndex and true or false
end

function Addon:DumpEncounterJournalIcons()
    local entries = {}
    self:LoadEncounterJournalForIconDump()
    if not EJ_GetNumTiers or not EJ_GetTierInfo or not EJ_SelectTier or not EJ_GetInstanceByIndex then
        Print("Encounter Journal icon APIs are not available yet.")
        return entries
    end

    local tierCount = EJ_GetNumTiers() or 0
    for tierIndex = 1, tierCount do
        local tierID, tierName = tierIndex, "Tier " .. tostring(tierIndex)
        local tierValues = { pcall(EJ_GetTierInfo, tierIndex) }
        if tierValues[1] then
            for valueIndex = 2, #tierValues do
                if type(tierValues[valueIndex]) == "number" and tierID == tierIndex then
                    tierID = tierValues[valueIndex]
                elseif type(tierValues[valueIndex]) == "string" and tierName == ("Tier " .. tostring(tierIndex)) then
                    tierName = tierValues[valueIndex]
                end
            end
        end

        local selected = pcall(EJ_SelectTier, tierIndex)
        if not selected then
            Print("Icon dump skipped journal tier " .. tostring(tierIndex) .. " because it could not be selected.")
        end

        if selected then
            for _, isRaid in ipairs({ false, true }) do
                local instanceIndex = 1
                while true do
                    local values = { pcall(EJ_GetInstanceByIndex, instanceIndex, isRaid) }
                    if not values[1] then
                        Print("Icon dump stopped journal " .. (isRaid and "raid" or "dungeon") .. " tier " .. tostring(tierIndex) .. ": " .. tostring(values[2]))
                        break
                    end

                    local journalInstanceID = values[2]
                    local instanceName = values[3]
                    local bgImage = values[5]
                    local buttonImage1 = values[6]
                    local loreImage = values[7]
                    local buttonImage2 = values[8]
                    local dungeonAreaMapID = values[9]
                    local journalLink = values[10]
                    local shouldDisplayDifficulty = values[11]
                    local instanceID = values[12]
                    if not journalInstanceID then
                        break
                    end

                    local bosses = {}
                    if EJ_GetEncounterInfoByIndex then
                        local selectedInstance = EJ_SelectInstance and pcall(EJ_SelectInstance, journalInstanceID)
                        local bossIndex = 1
                        while true do
                            local bossValues = { pcall(EJ_GetEncounterInfoByIndex, bossIndex, journalInstanceID) }
                            if not bossValues[1] then
                                break
                            end
                            local bossName = bossValues[2]
                            local journalEncounterID = bossValues[4]
                            local isFinal = bossValues[8]
                            if not bossName and not journalEncounterID then
                                break
                            end
                            table.insert(bosses, {
                                journalEncounterID = journalEncounterID,
                                name = bossName or ("Encounter " .. tostring(journalEncounterID)),
                                isFinal = isFinal and true or false,
                            })
                            bossIndex = bossIndex + 1
                        end
                    end

                    table.insert(entries, {
                        journalInstanceID = journalInstanceID,
                        name = instanceName or ("Journal Instance " .. tostring(journalInstanceID)),
                        type = isRaid and "raid" or "dungeon",
                        tierID = tierID,
                        tierName = tierName,
                        buttonImage = TextureToSavedValue(buttonImage1),
                        buttonImage2 = TextureToSavedValue(buttonImage2),
                        bgImage = TextureToSavedValue(bgImage),
                        loreImage = TextureToSavedValue(loreImage),
                        dungeonAreaMapID = dungeonAreaMapID,
                        journalLink = journalLink,
                        shouldDisplayDifficulty = shouldDisplayDifficulty,
                        instanceID = instanceID,
                        bosses = bosses,
                    })
                    instanceIndex = instanceIndex + 1
                end
            end
        end
    end

    table.sort(entries, function(left, right)
        if tostring(left.type or "") == tostring(right.type or "") then
            return tostring(left.name or "") < tostring(right.name or "")
        end
        return tostring(left.type or "") < tostring(right.type or "")
    end)
    return entries
end

function Addon:DumpInstanceIcons()
    self.db.iconDumps = self.db.iconDumps or {}
    self.db.iconDumps.generatedAt = time()
    self.db.iconDumps.generatedAtText = date("%Y-%m-%d %H:%M:%S")

    Print("Starting icon dump...")

    local challengeOK, challengeEntries = pcall(function()
        return self:DumpChallengeDungeonIcons()
    end)
    if not challengeOK then
        local errorMessage = challengeEntries
        challengeEntries = {}
        Print("Challenge icon dump failed: " .. tostring(errorMessage))
    end

    local journalOK, journalEntries = pcall(function()
        return self:DumpEncounterJournalIcons()
    end)
    if not journalOK then
        local errorMessage = journalEntries
        journalEntries = {}
        Print("Encounter Journal icon dump failed: " .. tostring(errorMessage))
    end

    self.db.iconDumps.challengeDungeons = challengeEntries or {}
    self.db.iconDumps.encounterJournal = journalEntries or {}

    Print("Saved " .. tostring(#self.db.iconDumps.challengeDungeons) .. " Mythic+/Challenge dungeon icon(s).")
    Print("Saved " .. tostring(#self.db.iconDumps.encounterJournal) .. " Encounter Journal dungeon/raid icon(s).")
end

-- Full dungeon/raid/Delve/boss reference catalog, built from the client's own Encounter Journal
-- and Mythic+ map table (no addon dependency -- DataStore doesn't carry this data, only
-- account-wide character data). Reuses DumpInstanceIcons's already-patch-tested EJ walk rather
-- than querying the API twice.
-- One-time-per-load cleanup: BuildExpansionCatalog's Encounter Journal boss auto-seed used to
-- write into customBossMaps using journalEncounterID -- a different ID space than the real
-- ENCOUNTER_END encounterID that a hardcoded DUNGEON_BOSSES entry uses (and that boss kills
-- actually match against). For a dungeon that already has a hand-verified DUNGEON_BOSSES entry,
-- any customBossMaps boss whose NAME duplicates a hardcoded boss is that contamination -- it can
-- never be matched by a real kill, and GetDungeonBossInfo merging it in doubled the "required"
-- checklist, meaning HaveAllRequiredBossesDied could never be satisfied. Strip only those
-- name-colliding entries; anything that doesn't collide with the hardcoded roster is left alone
-- (could be a legitimate manual/Manage Data addition). Cheap and idempotent -- runs every load.
-- Self-healing migration for the v0.1.198-and-earlier BroadcastMythicPlusSync retry bug: a failed
-- retry called itself again with `reason .. " retry"`, uncapped, so once the native
-- SendAddonMessage throttle was hit, every retry hit it again forever -- confirmed live, 319
-- separate debugLog entries on one user's SavedVariables, some with the word "retry" repeated
-- hundreds of times in a single message. That bloat doesn't go away on its own (the 600-entry cap
-- only rotates by count, not size), so this prunes any already-bloated entry once on load.
function Addon:PruneBloatedDebugLogEntries()
    if not (self.db and self.db.debugLog) then
        return
    end
    local removed = 0
    for i = #self.db.debugLog, 1, -1 do
        local entry = self.db.debugLog[i]
        if entry and entry.message and #tostring(entry.message) > 500 then
            table.remove(self.db.debugLog, i)
            removed = removed + 1
        end
    end
    if removed > 0 then
        Debug("Pruned " .. removed .. " bloated debugLog entr" .. (removed == 1 and "y" or "ies") .. " from the BroadcastMythicPlusSync retry bug.")
    end
end

function Addon:CleanupContaminatedCustomBossMaps()
    if not (self.db and self.db.customBossMaps) then
        return
    end
    local removedTotal = 0
    for dungeonName, hardcoded in pairs(DUNGEON_BOSSES) do
        local custom = self.db.customBossMaps[dungeonName]
        if custom and custom.bosses then
            local hardcodedNames = {}
            for _, boss in pairs(hardcoded.bosses or {}) do
                local name = type(boss) == "table" and boss.name or tostring(boss)
                if name then
                    hardcodedNames[name] = true
                end
            end
            for bossID, boss in pairs(custom.bosses) do
                local name = type(boss) == "table" and boss.name or tostring(boss)
                if name and hardcodedNames[name] then
                    custom.bosses[bossID] = nil
                    if custom.names then
                        custom.names[name] = nil
                    end
                    if custom.final then
                        custom.final[bossID] = nil
                        custom.final[name] = nil
                    end
                    removedTotal = removedTotal + 1
                end
            end
        end
    end
    if removedTotal > 0 then
        Debug("CleanupContaminatedCustomBossMaps: removed " .. removedTotal .. " wrong-ID-space boss entr" .. (removedTotal == 1 and "y" or "ies") .. " duplicating a hardcoded DUNGEON_BOSSES roster")
    end

    -- Separate contamination, found live 2026-09-04: BuildExpansionCatalog used to trust the
    -- Encounter Journal's per-boss isFinal field, which turned out to be true for 2260 of 2360
    -- boss entries account-wide -- not a reliable "this is the last boss" signal at all. Any
    -- auto-seeded dungeon where more than one boss ended up flagged final can make IsFinalBoss
    -- true on the very first kill, short-circuiting the whole run complete (confirmed live: Altar
    -- of Fangs closed out after one of its three required bosses). The saved customBossMaps
    -- structure doesn't preserve Journal listing order, so there's no way to safely guess which
    -- one is genuinely final after the fact -- clear the ambiguous flags entirely for any
    -- contaminated dungeon instead of guessing wrong. HaveAllRequiredBossesDied (needs every
    -- required boss, not just "the final one") still works correctly without this shortcut.
    local finalFixedCount = 0
    for dungeonName, custom in pairs(self.db.customBossMaps) do
        if custom.final and custom.bosses then
            local finalBossCount = 0
            for bossID in pairs(custom.bosses) do
                if custom.final[bossID] then
                    finalBossCount = finalBossCount + 1
                end
            end
            if finalBossCount > 1 then
                custom.final = {}
                finalFixedCount = finalFixedCount + 1
                Debug("CleanupContaminatedCustomBossMaps: cleared ambiguous final-boss flags for " .. tostring(dungeonName) .. " (" .. finalBossCount .. " bosses were all marked final)")
            end
        end
    end
    if finalFixedCount > 0 then
        Debug("CleanupContaminatedCustomBossMaps: fixed final-boss flags for " .. finalFixedCount .. " dungeon(s)")
    end
end

-- One-time data fix, 2026-09-05, per user report: The Blinding Vale's boss 3202 was hardcoded here
-- as "Ziekett" -- a typo, corrected above to the real spelling "Ziekket". That only fixes the
-- CURRENT catalog lookup (GetBossName) -- every run recorded before this fix still has the
-- misspelled name frozen in its own bossKillLog/bossKills/encounters entries (snapshots taken at
-- kill time, not a live lookup), and the auto-seeded customBossMaps entry it had spawned under a
-- DIFFERENT id (2772, since the correct spelling never matched the typoed hardcode to get cleaned
-- up by CleanupContaminatedCustomBossMaps until now) needs the same cleanup pass that function
-- already does -- fixing the hardcode's spelling is what makes that happen automatically on the
-- next load, this only needs to correct the OLD frozen name strings.
function Addon:FixZiekketNameTypo()
    if not (self.db and self.db.runOrder) then
        return
    end
    local fixed = 0
    for _, runID in ipairs(self.db.runOrder) do
        local run = self.db.runs and self.db.runs[runID]
        if run then
            for _, entry in ipairs(run.bossKillLog or {}) do
                if entry.name == "Ziekett" then
                    entry.name = "Ziekket"
                    fixed = fixed + 1
                end
            end
            for _, entry in ipairs(run.encounters or {}) do
                if entry.encounterName == "Ziekett" then
                    entry.encounterName = "Ziekket"
                end
            end
            if run.bossKills and run.bossKills[3202] and run.bossKills[3202].name == "Ziekett" then
                run.bossKills[3202].name = "Ziekket"
            end
        end
    end
    if self.db.bossCatalog and self.db.bossCatalog["3202"] and self.db.bossCatalog["3202"].name == "Ziekett" then
        self.db.bossCatalog["3202"].name = "Ziekket"
    end
    if fixed > 0 then
        Debug("FixZiekketNameTypo: corrected " .. fixed .. " historical boss-kill-log entr" .. (fixed == 1 and "y" or "ies") .. " from 'Ziekett' to 'Ziekket'")
    end
end

function Addon:BuildExpansionCatalog()
    self:DumpInstanceIcons()

    local journalEntries = self.db.iconDumps and self.db.iconDumps.encounterJournal or {}
    local challengeEntries = self.db.iconDumps and self.db.iconDumps.challengeDungeons or {}

    local challengeByName = {}
    for _, entry in ipairs(challengeEntries) do
        if entry.name then
            challengeByName[entry.name] = entry
        end
    end

    self.db.expansionCatalog = {}
    local expansionCount, dungeonCount, raidCount, bossCount = 0, 0, 0, 0
    local seenExpansions = {}

    for _, entry in ipairs(journalEntries) do
        local expansionName = entry.tierName or "Unknown"
        if not seenExpansions[expansionName] then
            seenExpansions[expansionName] = true
            expansionCount = expansionCount + 1
        end
        self.db.expansionCatalog[expansionName] = self.db.expansionCatalog[expansionName] or { dungeons = {}, raids = {} }
        local bucket = entry.type == "raid" and self.db.expansionCatalog[expansionName].raids or self.db.expansionCatalog[expansionName].dungeons
        if entry.type == "raid" then
            raidCount = raidCount + 1
        else
            dungeonCount = dungeonCount + 1
        end

        local bossMap = {}
        for _, boss in ipairs(entry.bosses or {}) do
            if boss.journalEncounterID then
                bossMap[tostring(boss.journalEncounterID)] = { name = boss.name, isFinal = boss.isFinal }
                bossCount = bossCount + 1
            end
        end

        local challengeMatch = challengeByName[entry.name]
        bucket[entry.name] = {
            journalInstanceID = entry.journalInstanceID,
            bosses = bossMap,
            isCurrentSeasonMythicPlus = challengeMatch and true or false,
            challengeMapID = challengeMatch and challengeMatch.challengeMapID or nil,
            mythicPlusTimeLimitSeconds = challengeMatch and challengeMatch.timeLimitSeconds or nil,
        }

        -- Auto-seed the live boss roster used for kill-tracking/completion (Data Tools' Boss/Mob
        -- tabs) so this dungeon stops showing "not mapped yet" without hand-typing every boss.
        -- Never overwrites an existing manual entry, and never seeds a dungeon that already has a
        -- hand-verified DUNGEON_BOSSES entry -- journalEncounterID (used here) is a different ID
        -- space than the real ENCOUNTER_END encounterID DUNGEON_BOSSES uses, and GetDungeonBossInfo
        -- merges both, so seeding on top of a hardcoded roster doubles the "required" checklist
        -- with entries a real kill can never match (found 2026-09-01: exactly this happened to
        -- Murder Row after /dl catalog ran post-hardcoding).
        if next(bossMap) and not DUNGEON_BOSSES[entry.name] and not (self.db.customBossMaps and self.db.customBossMaps[entry.name]) then
            self.db.customBossMaps = self.db.customBossMaps or {}
            local map = { bosses = {}, names = {}, final = {} }
            local lastID, lastName = nil, nil
            for _, boss in ipairs(entry.bosses or {}) do
                if boss.journalEncounterID then
                    local id = tonumber(boss.journalEncounterID) or boss.journalEncounterID
                    map.bosses[id] = { name = boss.name, optional = false }
                    map.names[boss.name] = id
                    lastID, lastName = id, boss.name
                end
            end
            -- Never trust the Encounter Journal's own per-boss isFinal field -- confirmed
            -- 2026-09-04 (Altar of Fangs, live): it was true on all three of that dungeon's
            -- bosses, and account-wide, 2260 of 2360 isFinal fields across the whole catalog are
            -- true. Whatever this field actually represents in Blizzard's data, it is not
            -- reliably "closes the instance" -- trusting it here previously flagged every boss in
            -- an auto-seeded dungeon as final, so IsFinalBoss short-circuited the whole run
            -- complete on the very first kill (confirmed live: Altar of Fangs closed out after
            -- Rav'i alone, of three required bosses). Use only "last boss in Journal listing
            -- order" as the final-boss heuristic -- imperfect if Journal order doesn't match real
            -- kill order, but nowhere near as broken as trusting a field that's true 96% of the
            -- time. HaveAllRequiredBossesDied (needs every required boss, not just "the final
            -- one") remains the primary, more reliable completion signal regardless.
            if lastID then
                map.final[lastID] = true
                if lastName then
                    map.final[lastName] = true
                end
            end
            self.db.customBossMaps[entry.name] = map
        end

        -- Auto-seed the M+ time limit fallback that GetMythicPlusTimeLimit already checks, so
        -- the Progress graph's reference line and overtime detection work even while the live
        -- capture bug (run.mythicPlusTimeLimitSeconds never populating) is unresolved.
        if challengeMatch and challengeMatch.timeLimitSeconds then
            self.db.instanceCatalog = self.db.instanceCatalog or {}
            self.db.instanceCatalog[entry.name] = self.db.instanceCatalog[entry.name] or {}
            self.db.instanceCatalog[entry.name].mythicPlusTimeLimitSeconds = challengeMatch.timeLimitSeconds
        end
    end

    -- Best-effort Delves: no classic EJ tier/instance walk covers these, and this addon has no
    -- confirmed-working C_Delves enumeration yet. Report what's actually present on this client
    -- rather than guess at function names that might not exist on this patch.
    if C_Delves then
        local names = {}
        for key in pairs(C_Delves) do
            table.insert(names, tostring(key))
        end
        Debug("BuildExpansionCatalog: C_Delves namespace exists, members: " .. table.concat(names, ", "))
    else
        Debug("BuildExpansionCatalog: C_Delves namespace not found on this client -- Delves not catalogued yet")
    end

    Print(string.format("Catalog built: %d expansion(s), %d dungeon(s), %d raid(s), %d boss(es). Delves not included yet -- see debug log for what C_Delves exposes on this client.",
        expansionCount, dungeonCount, raidCount, bossCount))
end

function Addon:GetRunKind(runOrName)
    local name = type(runOrName) == "table" and runOrName.instanceName or runOrName
    if name and INSTANCE_KIND_OVERRIDES[name] then
        return INSTANCE_KIND_OVERRIDES[name]
    end

    if type(runOrName) == "table" then
        if runOrName.instanceType == "raid" then
            return "Raid"
        elseif runOrName.instanceType == "party" then
            return "Dungeon"
        end
    end

    return "Dungeon"
end

function Addon:IsMPlusLedgerRun(run)
    if not run then
        return false
    end
    if EXCLUDED_INSTANCE_NAMES[run.instanceName or ""] then
        return false
    end
    local kind = self:GetRunKind(run)
    if kind ~= "Dungeon" and kind ~= "Raid" then
        return false
    end
    if run.instanceType and run.instanceType ~= "party" and run.instanceType ~= "raid" then
        return false
    end
    return true
end

function Addon:IsMythicPlusRun(run)
    return run and ((tonumber(run.keyLevel) or 0) > 0 or (tonumber(run.challengeLevel) or 0) > 0)
end

function Addon:GetRunKeyLevel(run)
    return tonumber(run and (run.keyLevel or run.challengeLevel or run.completionLevel)) or 0
end

function Addon:GetDungeonDisplayName(runOrName)
    local name = type(runOrName) == "table" and runOrName.instanceName or runOrName
    local run = type(runOrName) == "table" and runOrName or nil
    if run and self:IsMythicPlusRun(run) then
        return string.format("%s |cffff3333+%d|r", name or "Unknown Dungeon", self:GetRunKeyLevel(run))
    end
    return name or "Unknown Dungeon"
end

-- Tag listing EVERY Mythic+ season a dungeon has ever been confirmed part of, grouped by
-- expansion -- not just whichever single one GetRunMythicPlusSeasonText picks for grouping
-- purposes -- per user request 2026-09-30 ("dungeons can be a part of multiple different seasons",
-- e.g. Timewalking-eligible legacy dungeons rotating back into more than one season's M+ pool).
-- Sourced from instanceCatalog[name].seasonLinks, the same set LinkInstanceToSeason accumulates --
-- built up from what's actually been observed live, never predicted/hardcoded, so an unreleased
-- future season (e.g. Season 3 before patch 12.2 ships) simply won't be listed until it happens.
--
-- Grouped by expansion, not flattened to bare "S1"/"S2" -- season numbers reset PER EXPANSION, so
-- a dungeon linked to both "Midnight Season 1" and "Dragonflight Season 1" needs both expansion
-- names kept, or the two would collapse into one meaningless duplicate "S1" tag. Per the user's own
-- example: Pit of Saron could be Wrath of the Lich King (origin) with Timewalking-rotation links to
-- both Midnight Season 1 and Dragonflight Season 1 -- three genuinely different facts, not one.
function Addon:GetDungeonSeasonTagsText(name)
    local catalog = name and self.db and self.db.instanceCatalog and self.db.instanceCatalog[name]
    local links = catalog and catalog.seasonLinks
    if not links or not next(links) then
        return nil
    end
    local byExpansion, order, others = {}, {}, {}
    for seasonName in pairs(links) do
        if seasonName ~= "Current WoW Season" then
            local expansionPrefix, num = seasonName:match("^(.-)%s+[Ss]eason%s*(%d+)%s*$")
            if expansionPrefix and num then
                if not byExpansion[expansionPrefix] then
                    byExpansion[expansionPrefix] = {}
                    table.insert(order, expansionPrefix)
                end
                table.insert(byExpansion[expansionPrefix], tonumber(num))
            else
                table.insert(others, seasonName)
            end
        end
    end
    table.sort(order)
    local parts = {}
    for _, expansionPrefix in ipairs(order) do
        local nums = byExpansion[expansionPrefix]
        table.sort(nums)
        local numText = {}
        for _, num in ipairs(nums) do
            table.insert(numText, "S" .. num)
        end
        table.insert(parts, string.format("%s %s", expansionPrefix, table.concat(numText, "/")))
    end
    table.sort(others)
    for _, otherName in ipairs(others) do
        table.insert(parts, otherName)
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

-- Y/N flag: is this dungeon actually in the CURRENT live Mythic+ pool right now -- distinct from
-- GetDungeonSeasonTagsText's historical list, which can include seasons that already ended. Ground
-- truth from GetMythicPlusPoolEntries (C_ChallengeMode.GetMapTable), same source already trusted
-- for the season-mislabeling fixes above -- not a guess. Per user request 2026-09-30.
function Addon:IsDungeonInCurrentSeason(name)
    if not name then
        return false
    end
    for _, entry in ipairs(self:GetMythicPlusPoolEntries()) do
        if entry.name == name then
            return true
        end
    end
    return false
end

-- Dungeon card title on the main window: always shows the current season's highest completed
-- M+ key for that dungeon (if any), independent of whether the most recent run happened to be
-- M+ -- a Normal/Heroic clear right after a big key push shouldn't hide the key from the card.
--
-- REVERTED to plain "Name +Key" 2026-09-30 per user report/screenshot: the expansion/season/
-- current-flag suffix this briefly grew genuinely didn't fit the card's fixed 2-line title box
-- ("[Midnight, Midn..." truncating mid-word) -- that info now lives in GetDungeonCardTooltipLines
-- below instead, shown on hover, where there's no hard space limit to fight.
function Addon:GetDungeonCardTitleText(summary)
    local name = (summary and summary.name) or "Unknown Dungeon"
    local highestKey = summary and tonumber(summary.currentSeasonHighestKey) or 0
    if highestKey and highestKey > 0 then
        return string.format("%s |cffff3333+%d|r", name, highestKey)
    end
    return name
end

-- Expansion/season/current-pool detail for a dungeon card's hover tooltip -- moved here 2026-09-30
-- from the card title itself (see that function's comment) since it never reliably fit as visible
-- text. Returns nil if there's no M+ relevance at all (a pure leveling dungeon with no season tag
-- and not in the current pool), so the tooltip can skip adding these lines entirely.
function Addon:GetDungeonCardTooltipLines(summary)
    local name = (summary and summary.name) or nil
    if not name then
        return nil
    end
    local seasonTags = self:GetDungeonSeasonTagsText(name)
    local isCurrent = self:IsDungeonInCurrentSeason(name)
    if not seasonTags and not isCurrent then
        return nil
    end
    local lines = {}
    local expansionText = summary and summary.expansionText
    if expansionText and expansionText ~= "Unknown Expansion" then
        table.insert(lines, { "Expansion: " .. expansionText, 0.8, 0.8, 0.8 })
    end
    table.insert(lines, { "Season(s): " .. (seasonTags or "no season data"), 0.8, 0.8, 0.8 })
    if isCurrent then
        table.insert(lines, { "In the current M+ pool", 0.2, 0.85, 0.3 })
    else
        table.insert(lines, { "Not in the current M+ pool", 0.6, 0.6, 0.6 })
    end
    return lines
end

function Addon:GetDifficultyText(run)
    if not run then
        return "Unknown"
    end

    if self:IsMythicPlusRun(run) then
        return string.format("|cffff3333Mythic +%d|r", self:GetRunKeyLevel(run))
    end

    local text = run.difficultyName or (run.difficultyID and ("Difficulty " .. tostring(run.difficultyID))) or "Unknown"
    local lower = string.lower(text)
    local bucket = self:GetDifficultyBucket(run)
    local config = DIFFICULTY_BUCKETS[bucket]
    if config then
        return config.color .. text .. "|r"
    end

    if lower:find("heroic") then
        return "|cffff33cc" .. text .. "|r"
    elseif lower:find("mythic") then
        return "|cffff9900" .. text .. "|r"
    elseif lower:find("normal") then
        return "|cff33d6cc" .. text .. "|r"
    end

    return text
end

function Addon:GetDifficultyBucket(run)
    if self:IsMythicPlusRun(run) then
        return "mythicPlus"
    end

    local text = string.lower(tostring((run and run.difficultyName) or ""))
    local difficultyID = tonumber(run and run.difficultyID)
    if text:find("timewalking") or difficultyID == 24 or difficultyID == 33 then
        return "timewalking"
    elseif text:find("follower") or difficultyID == 205 then
        return "follower"
    elseif text:find("looking for raid") or text:find("lfr") or difficultyID == 7 or difficultyID == 17 then
        return "lfr"
    elseif text:find("heroic") or difficultyID == 2 or difficultyID == 5 or difficultyID == 6 then
        return "heroic"
    elseif text:find("mythic") or difficultyID == 23 or difficultyID == 16 then
        return "mythic"
    end

    return "normal"
end

function Addon:GetRunDifficultyRank(run)
    return DIFFICULTY_SORT_RANK[self:GetDifficultyBucket(run)] or 0
end

function Addon:GetDifficultyBackdropColor(run)
    local config = DIFFICULTY_BUCKETS[self:GetDifficultyBucket(run)]
    return config and config.backdrop or { 0.45, 0.02, 0.02 }
end

-- Real Encounter Journal tier lookup by journalInstanceID (ground truth, from /dl catalog's own
-- dump of Blizzard's Encounter Journal via DumpEncounterJournalIcons -- each entry's real tierName,
-- e.g. "Battle for Azeroth"), not a guess. Used by GetRunExpansionText below to correct/avoid the
-- timing-based mislabeling bug described there.
function Addon:FindJournalExpansionName(journalInstanceID)
    if not journalInstanceID then
        return nil
    end
    for _, entry in ipairs(self.db and self.db.iconDumps and self.db.iconDumps.encounterJournal or {}) do
        -- Skips the Journal's "Current Season" tab, which lists this season's dungeons a second
        -- time on top of their real expansion tab.
        if entry.journalInstanceID == journalInstanceID and entry.tierName and entry.tierName ~= "Current Season" then
            return tostring(entry.tierName)
        end
    end
    return nil
end

-- Dungeons the Journal lists under more than one expansion, oldest first (user report 2026-10-08:
-- Scarlet Halls, Scarlet Monastery and Scholomance have Classic and Mists of Pandaria versions).
-- See GetRunVersionExpansion for how a run picks its version.
function Addon:GetJournalVersions(name)
    if not name then
        return {}
    end
    self.journalVersionCache = self.journalVersionCache or {}
    if self.journalVersionCache[name] then
        return self.journalVersionCache[name]
    end
    local entries = {}
    for _, entry in ipairs(self.db and self.db.iconDumps and self.db.iconDumps.encounterJournal or {}) do
        if entry.name == name and entry.type ~= "raid" and entry.tierName and entry.tierName ~= "Current Season" then
            table.insert(entries, entry)
        end
    end
    table.sort(entries, function(a, b) return (tonumber(a.tierID) or 0) < (tonumber(b.tierID) or 0) end)
    local versions, seen = {}, {}
    for _, entry in ipairs(entries) do
        local expansion = entry.tierName == "Burning Crusade" and "The Burning Crusade" or tostring(entry.tierName)
        if not seen[expansion] then
            seen[expansion] = true
            table.insert(versions, { expansion = expansion, journalInstanceID = entry.journalInstanceID, instanceID = entry.instanceID })
        end
    end
    self.journalVersionCache[name] = versions
    return versions
end

-- The original Scholomance and four-wing Scarlet Monastery are still separate instances in retail,
-- with their own entrances, alongside the Mists of Pandaria remakes -- the Journal's Classic tab
-- just points at the remakes (user report 2026-10-08, confirmed against warcraft.wiki.gg's
-- InstanceID list: 289 "Scholomance (Classic)", 189 "Scarlet Monastery of Old"; remakes 1007,
-- 1001 Scarlet Halls, 1004 Scarlet Monastery). Same for 309 "Ancient Zul'Gurub" alongside the
-- Cataclysm dungeon 859.
local ORIGINAL_INSTANCE_EXPANSIONS = { [289] = "Classic", [189] = "Classic", [309] = "Classic" }
local REMAKES_WITH_SEPARATE_ORIGINAL = { ["Scholomance"] = true, ["Scarlet Halls"] = true, ["Scarlet Monastery"] = true }

-- Which version of a multi-version dungeon a run was, from the instance it recorded. Remakes whose
-- original is a separate instance are always the remake; dungeons that are one instance at two
-- difficulties (Deadmines, Shadowfang Keep) go by difficulty (Normal = original). nil when the
-- dungeon has only one version or the run can't be matched.
function Addon:GetRunVersionExpansion(run)
    local originalExpansion = run and ORIGINAL_INSTANCE_EXPANSIONS[tonumber(run.instanceID) or 0]
    if originalExpansion then
        return originalExpansion
    end
    local versions = run and self:GetJournalVersions(run.instanceName) or {}
    if #versions < 2 then
        return nil
    end
    if REMAKES_WITH_SEPARATE_ORIGINAL[run.instanceName] then
        return versions[#versions].expansion
    end
    local sameInstance = true
    for _, version in ipairs(versions) do
        if version.journalInstanceID ~= versions[1].journalInstanceID then
            sameInstance = false
        end
    end
    if not sameInstance then
        for _, version in ipairs(versions) do
            if (run.journalInstanceID and version.journalInstanceID == run.journalInstanceID) or (run.instanceID and version.instanceID == run.instanceID) then
                return version.expansion
            end
        end
        return nil
    end
    if tonumber(run.difficultyID) == 1 then
        return versions[1].expansion
    end
    return versions[#versions].expansion
end

function Addon:GetRunExpansionText(run)
    if not run then
        return "Unknown Expansion"
    end

    local instanceName = run.instanceName or ""
    local metadata = self.db and self.db.dungeonMetadata and self.db.dungeonMetadata[instanceName]

    -- An explicit manual link (Manage Data) always wins outright -- the user may deliberately be
    -- overriding real Journal data.
    if metadata and metadata.expansionManual and metadata.expansionName then
        return tostring(metadata.expansionName)
    end

    local versionExpansion = self:GetRunVersionExpansion(run)
    if versionExpansion then
        return versionExpansion
    end

    -- Real Encounter Journal tier lookup next -- checked BEFORE trusting any earlier unverified
    -- guess, so a returning classic dungeon whose true tier is now cached (via /dl catalog) gets
    -- corrected even if it was already mislabeled below on a previous run.
    --
    -- FIXED 2026-09-30 per user report/screenshot ("dungeons are not getting saved to the correct
    -- expansion"): this addon's own auto-catalog-update path (UpdateInstanceCatalog, called from
    -- StartRun) writes catalog.expansionName = GetRunExpansionText(run) the FIRST time any dungeon
    -- is ever recorded, then self-heals dungeonMetadata.expansionName from that same value -- but
    -- only when the stored value was a "Patch X.Y.Z" placeholder, never when it was already a
    -- real-looking (but possibly WRONG) expansion name. Previously this function fell straight to
    -- GetKnownExpansionNameForVersion (whichever expansion the CLIENT PATCH happens to be on right
    -- now) whenever no metadata existed yet -- so a real Battle for Azeroth dungeon like Kings' Rest,
    -- returning in this season's M+ pool, got permanently tagged "Midnight" just because that's what
    -- was live the first time it was ever run, well before /dl catalog had a chance to cache its
    -- true Encounter Journal tier -- and since "Midnight" isn't a placeholder string, the self-heal
    -- check never revisited it even once real data existed. Moving the journal lookup here, ahead
    -- of the stored-guess fallback below, means every read (not just the one-time write) has a
    -- chance to self-correct once real data is cached, without needing to touch the stale stored
    -- value at all.
    local catalog = self.db and self.db.instanceCatalog and self.db.instanceCatalog[instanceName]
    local journalInstanceID = (metadata and metadata.journalInstanceID) or (catalog and catalog.journalInstanceID) or run.journalInstanceID
    if journalInstanceID then
        local journalTier = self:FindJournalExpansionName(journalInstanceID)
        if journalTier then
            return journalTier
        end
    end

    -- Unverified stored value (an earlier best-effort guess, kept only because nothing better has
    -- been seen yet). A "Patch X.Y.Z" placeholder doesn't count -- fall through to the timing guess
    -- below instead of trusting that stale placeholder forever (found 2026-09-01: exactly this
    -- happened to a Murder Row dungeonMetadata entry, while its sibling The Blinding Vale had been
    -- correctly linked to "Midnight").
    if metadata and metadata.expansionName and not IsPlaceholderExpansionName(metadata.expansionName) then
        return tostring(metadata.expansionName)
    end

    local known = GetKnownExpansionNameForVersion(run.clientVersion or run.clientPatch)
    if known then
        return known
    end

    return tostring(run.expansionName or run.expansion or run.expansionID or run.mapExpansionID or "Unknown Expansion")
end

function Addon:GetRunMythicPlusSeasonText(run)
    if not run then
        return "Unknown Season"
    end

    local instanceName = run.instanceName
    local catalog = instanceName and self.db and self.db.instanceCatalog and self.db.instanceCatalog[instanceName]
    if catalog and catalog.seasonLinks then
        local currentNamed = self:GetCurrentNamedSeasonName()
        -- A link to what LOOKS like the current season's name is only trusted if the dungeon is
        -- actually in the real current M+ pool (GetMythicPlusPoolEntries, sourced from Blizzard's
        -- own C_ChallengeMode.GetMapTable) -- fixed 2026-09-30 per user report/screenshot: several
        -- old Cataclysm Timewalking dungeons (Blackrock Depths/Caverns, The Stonecore, Lost City of
        -- Tol'vir, Throne of the Tides) had been manually linked to "12.1 Season 2" via Manage Data
        -- at some point, so the "Mythic+ Season" grouped main-window view showed them banner-grouped
        -- right alongside real Season 2 M+ dungeons even though none of them are part of that
        -- season's actual keystone rotation -- just old leveling dungeons that happened to be run
        -- (via the Timewalking event) during that same time window. Other/older season links are
        -- left untouched -- there's no live-API ground truth for a PAST season's pool to verify
        -- against, only the current one.
        --
        -- REVISED same day: the first version of this fix only checked currentNamed
        -- (GetCurrentNamedSeasonName, e.g. "Midnight Season 2") -- but GetCurrentSeasonName returns
        -- a SEPARATE, differently-formatted "current" identifier (e.g. "12.1 Season 2"), and the
        -- bad links were made against THAT string, not the named one, so they sailed straight past
        -- the unverified fallback loop below untouched. Both are "the current season" and now both
        -- require the same pool-membership check before being trusted.
        local currentGeneric = self:GetCurrentSeasonName()
        local inCurrentPool = nil
        local function IsCurrentlyInPool()
            if inCurrentPool == nil then
                inCurrentPool = false
                for _, entry in ipairs(self:GetMythicPlusPoolEntries()) do
                    if entry.name == instanceName then
                        inCurrentPool = true
                        break
                    end
                end
            end
            return inCurrentPool
        end
        if currentNamed and catalog.seasonLinks[currentNamed] and IsCurrentlyInPool() then
            return currentNamed
        end
        if currentGeneric and catalog.seasonLinks[currentGeneric] and IsCurrentlyInPool() then
            return currentGeneric
        end
        for seasonName in pairs(catalog.seasonLinks) do
            if seasonName and seasonName ~= "Current WoW Season" and seasonName ~= currentNamed and seasonName ~= currentGeneric then
                return seasonName
            end
        end
    end
    -- REAL root cause found 2026-09-30 (via direct SavedVariables inspection, since the earlier
    -- catalog.seasonLinks fix alone didn't clear the user's screenshot): StartRun stamps
    -- mythicPlusSeasonName/mythicPlusSeason onto EVERY run -- dungeon, raid, Normal, Timewalking,
    -- anything -- based purely on whichever M+ season is active when the run STARTS, with no check
    -- that the run is an actual M+ keystone run at all. A Timewalking clear of a classic dungeon
    -- run during the current season's patch window was getting stamped with that season's name
    -- just from timing, and this final fallback trusted it completely unconditionally -- the exact
    -- mechanism behind Blackrock Depths/Caverns, The Stonecore, Lost City of Tol'vir, and Throne of
    -- the Tides still showing grouped under "12.1 Season 2" even after the seasonLinks fix (none of
    -- them had a seasonLinks entry at all -- they hit this line directly). Now only trusted for a
    -- genuine M+ keystone run (IsMythicPlusRun: keyLevel/challengeLevel > 0) -- a Normal/Timewalking/
    -- raid run can't inherit a season label just from when it happened to be run.
    if self:IsMythicPlusRun(run) then
        local stamped = run.mythicPlusSeasonName or run.mythicPlusSeason or run.seasonName or run.season or run.seasonID
        if stamped then
            return tostring(stamped)
        end
    end
    return "Unknown Season"
end

function Addon:CreateEmptyDifficultySummary()
    local summary = {}
    for _, key in ipairs(DIFFICULTY_BUCKET_ORDER) do
        local config = DIFFICULTY_BUCKETS[key]
        summary[key] = { label = config.label, runs = 0, completed = 0, completedOvertime = 0, abandoned = 0, playerDeaths = 0, partyDeaths = 0, repairCost = 0 }
    end
    return summary
end

function Addon:AddRunToDifficultySummary(summary, run)
    if not summary or not run then
        return
    end

    local bucket = self:GetDifficultyBucket(run)
    local info = summary[bucket]
    if not info then
        return
    end

    info.runs = info.runs + 1
    info.playerDeaths = info.playerDeaths + self:GetPlayerDeaths(run)
    info.partyDeaths = info.partyDeaths + self:GetRunDeathTotal(run)
    info.repairCost = info.repairCost + (run.repairCost or 0)

    local status = self:GetRunStatus(run)
    if status == "Completed" or status == "CompletedOvertime" then
        info.completed = info.completed + 1
        if status == "CompletedOvertime" then
            info.completedOvertime = (info.completedOvertime or 0) + 1
        end
    elseif status == "Abandoned" then
        info.abandoned = info.abandoned + 1
    end
end

function Addon:GetDungeonBossInfo(run)
    if not run then
        return nil
    end

    local dungeonName = run.instanceName or ""
    local base = DUNGEON_BOSSES[dungeonName]
    local custom = self.db and self.db.customBossMaps and self.db.customBossMaps[dungeonName]
    if not custom then
        return base
    end

    local merged = { bosses = {}, names = {}, final = {} }
    if base then
        for bossID, boss in pairs(base.bosses or {}) do
            if type(boss) == "table" then
                merged.bosses[bossID] = { name = boss.name, optional = boss.optional and true or false }
                if boss.name then
                    merged.names[boss.name] = bossID
                end
            else
                merged.bosses[bossID] = boss
                merged.names[tostring(boss)] = bossID
            end
        end
        for name, bossID in pairs(base.names or {}) do
            merged.names[name] = bossID
        end
        for key, value in pairs(base.final or {}) do
            merged.final[key] = value
        end
    end

    for bossID, boss in pairs(custom.bosses or {}) do
        local numericID = tonumber(bossID) or bossID
        local name = type(boss) == "table" and boss.name or tostring(boss)
        merged.bosses[numericID] = {
            name = name,
            optional = type(boss) == "table" and boss.optional and true or false,
        }
        if name and name ~= "" then
            merged.names[name] = numericID
        end
    end
    for key, value in pairs(custom.names or {}) do
        merged.names[key] = tonumber(value) or value
    end
    for key, value in pairs(custom.final or {}) do
        merged.final[tonumber(key) or key] = value and true or nil
    end

    return merged
end

function Addon:GetEncounterKey(run, encounterID, encounterName)
    local bossInfo = self:GetDungeonBossInfo(run)
    local numericID = tonumber(encounterID)
    if bossInfo and numericID and bossInfo.bosses and bossInfo.bosses[numericID] then
        return numericID
    end
    if bossInfo and encounterName and bossInfo.names and bossInfo.names[tostring(encounterName)] then
        return bossInfo.names[tostring(encounterName)]
    end
    return numericID or tostring(encounterName or "unknown")
end

function Addon:IsFinalBoss(run, encounterID, encounterName)
    local bossInfo = self:GetDungeonBossInfo(run)
    if not bossInfo or not bossInfo.final then
        return false
    end
    local key = self:GetEncounterKey(run, encounterID, encounterName)
    return bossInfo.final[key] or bossInfo.final[tostring(encounterName or "")]
end

function Addon:GetBossName(run, bossID)
    local bossInfo = self:GetDungeonBossInfo(run)
    local boss = bossInfo and bossInfo.bosses and bossInfo.bosses[bossID]
    if type(boss) == "table" then
        return boss.name or ("Boss " .. tostring(bossID))
    end
    return boss or ("Boss " .. tostring(bossID))
end

function Addon:IsBossOptional(run, bossID)
    local bossInfo = self:GetDungeonBossInfo(run)
    local boss = bossInfo and bossInfo.bosses and bossInfo.bosses[bossID]
    local optional = type(boss) == "table" and boss.optional or false
    local dungeonName = run and run.instanceName
    local override = dungeonName and self.db and self.db.bossOverrides and self.db.bossOverrides[dungeonName]
    if override and override[bossID] ~= nil then
        optional = override[bossID] and true or false
    end
    return optional
end

function Addon:HaveAllRequiredBossesDied(run)
    local bossInfo = self:GetDungeonBossInfo(run)
    if not bossInfo or not bossInfo.bosses then
        return false
    end
    run.killedBosses = run.killedBosses or {}
    for bossID in pairs(bossInfo.bosses) do
        if not self:IsBossOptional(run, bossID) and not run.killedBosses[bossID] then
            return false
        end
    end
    return true
end

function Addon:GetKilledBossCount(run)
    local bossInfo = self:GetDungeonBossInfo(run)
    if not bossInfo or not bossInfo.bosses then
        return 0, 0
    end
    local killed = 0
    local total = 0
    run.killedBosses = run.killedBosses or {}
    for bossID in pairs(bossInfo.bosses) do
        total = total + 1
        if run.killedBosses[bossID] then
            killed = killed + 1
        end
    end
    return killed, total
end

function Addon:GetRequiredBossCount(run)
    local bossInfo = self:GetDungeonBossInfo(run)
    if not bossInfo or not bossInfo.bosses then
        return 0, 0
    end
    local killed = 0
    local total = 0
    run.killedBosses = run.killedBosses or {}
    for bossID in pairs(bossInfo.bosses) do
        if not self:IsBossOptional(run, bossID) then
            total = total + 1
            if run.killedBosses[bossID] then
                killed = killed + 1
            end
        end
    end
    return killed, total
end

function Addon:GetOptionalBossCount(run)
    local bossInfo = self:GetDungeonBossInfo(run)
    if not bossInfo or not bossInfo.bosses then
        return 0, 0
    end
    local killed = 0
    local total = 0
    run.killedBosses = run.killedBosses or {}
    for bossID in pairs(bossInfo.bosses) do
        if self:IsBossOptional(run, bossID) then
            total = total + 1
            if run.killedBosses[bossID] then
                killed = killed + 1
            end
        end
    end
    return killed, total
end

function Addon:FormatBossProgress(run)
    local requiredKilled, requiredTotal = self:GetRequiredBossCount(run)
    local optionalKilled, optionalTotal = self:GetOptionalBossCount(run)
    if requiredTotal <= 0 and optionalTotal <= 0 then
        return "not mapped yet"
    end
    if optionalTotal > 0 then
        return string.format("%d/%d req, %d/%d opt", requiredKilled, requiredTotal, optionalKilled, optionalTotal)
    end
    return tostring(requiredKilled) .. "/" .. tostring(requiredTotal) .. " req"
end

-- New 2026-09-05, per user request: separates actual boss-fight duration from trash/travel time
-- between bosses (previously lumped together as one "segment" -- time between consecutive kills).
-- Only ENCOUNTER_END was tracked before; this adds ENCOUNTER_START so RecordEncounterEnd can
-- compute how long the fight itself took. A single pending slot is enough -- a 5-player group
-- can't be mid-fight on two encounters at once, so nothing here needs per-encounter keying.
function Addon:RecordEncounterStart(encounterID, encounterName)
    local run = self:GetCurrentRun()
    if not run then
        return
    end
    run.pendingEncounterStartTime = GetRunElapsedAt(run, time())
    run.pendingEncounterStartID = encounterID
    Debug("Encounter started: " .. tostring(encounterName) .. " (" .. tostring(encounterID) .. ") at " .. tostring(run.pendingEncounterStartTime) .. "s")
end

function Addon:RecordEncounterEnd(encounterID, encounterName, endStatus)
    local run = self:GetCurrentRun()
    if tonumber(endStatus) ~= 1 then
        if run then run.pendingEncounterStartTime=nil;run.pendingEncounterStartID=nil end
        return
    end
    local npcIDs, npcLevels, npcMaxHealths, npcDisplayIDs = GetEncounterNPCIDs()

    -- Guard against a real race, confirmed by hand-inspecting a live account's SavedVariables:
    -- ENCOUNTER_END for a boss killed right before/during a fast exit (portal, immediate teleport,
    -- queueing straight into the next dungeon) can be processed by this addon AFTER
    -- PLAYER_ENTERING_WORLD for the *next* instance already fired. QueueInstanceScan calls
    -- CheckInstanceState synchronously on PLAYER_ENTERING_WORLD (not deferred outside combat
    -- lockdown), and CheckInstanceState ends the old run and starts the new one immediately when
    -- the tracked instance name changes -- so by the time the late ENCOUNTER_END arrives,
    -- GetCurrentRun() already returns the *new* dungeon's run, not the one the boss actually died
    -- in. Left unguarded this misattributes the kill to the wrong run's bossKills/completion state
    -- and mislabels the catalog entry's instanceName (exactly what was found and hand-corrected in
    -- this account's saved data before this fix existed). If the live instance name no longer
    -- matches `run` AND the encounter's own boss1-8 units are gone too (the strongest signal we
    -- really did leave, not just a transient GetInstanceInfo() hiccup -- CheckInstanceState already
    -- re-verifies at +0.7s/+2s for exactly that reason), treat this as unattributable rather than
    -- guess -- skip it instead of crediting/cataloguing it under either dungeon.
    if run and run.instanceName then
        local liveSnapshot = GetInstanceSnapshot()
        if liveSnapshot.name and liveSnapshot.name ~= run.instanceName and #npcIDs == 0 then
            Debug(string.format(
                "RecordEncounterEnd: instance mismatch for %s (run=%s, live=%s) with no boss1-8 units found -- likely a PLAYER_ENTERING_WORLD/ENCOUNTER_END race after leaving the instance; skipping to avoid misattributing this kill.",
                tostring(encounterName), tostring(run.instanceName), tostring(liveSnapshot.name)
            ))
            return
        end
    end

    if not run then
        self:CatalogBoss(self:GetCurrentCatalogContext("encounter"), tonumber(encounterID) or encounterID, encounterName, npcLevels[1], npcMaxHealths[1], nil, npcIDs[1], npcIDs, npcDisplayIDs[1])
        return
    end

    run.encounters = run.encounters or {}
    run.killedBosses = run.killedBosses or {}
    run.bossKills = run.bossKills or {}
    run.bossKillLog = run.bossKillLog or {}
    local encounterKey = self:GetEncounterKey(run, encounterID, encounterName)
    local alreadyKilled = run.killedBosses[encounterKey]
    run.killedBosses[encounterKey] = true
    local bossID = tonumber(encounterKey) or tonumber(encounterID)

    -- The pending ENCOUNTER_START slot only matches if it's for THIS encounter -- a wipe leaves it
    -- set (ENCOUNTER_END with endStatus~=1 returns before reaching here), but the next real pull's
    -- own ENCOUNTER_START overwrites it, so by the time a kill lands here it always reflects the
    -- pull that actually killed the boss, not an earlier wipe.
    local startTime = nil
    if run.pendingEncounterStartTime and tostring(run.pendingEncounterStartID) == tostring(encounterID) then
        startTime = run.pendingEncounterStartTime
    end
    run.pendingEncounterStartTime = nil
    run.pendingEncounterStartID = nil

    if not alreadyKilled then
        local killedAt = time()
        local killedAtText = date("%Y-%m-%d %H:%M:%S", killedAt)
        local killTime = GetRunElapsedAt(run, killedAt)
        table.insert(run.encounters, {
            time = killedAt,
            timeText = killedAtText,
            killTime = killTime,
            encounterID = encounterID,
            encounterName = encounterName,
            encounterKey = encounterKey,
        })
        if bossID then
            local bossInfo = run.bossKills[bossID] or {
                bossID = bossID,
                encounterID = encounterID,
                encounterKey = encounterKey,
                name = encounterName or self:GetBossName(run, encounterKey),
                count = 0,
            }
            bossInfo.name = encounterName or bossInfo.name
            bossInfo.count = (tonumber(bossInfo.count) or 0) + 1
            bossInfo.lastKilledAt = killedAt
            bossInfo.lastKilledAtText = killedAtText
            bossInfo.lastKillTime = killTime
            run.bossKills[bossID] = bossInfo
            self:CatalogBoss(run, bossID, bossInfo.name, npcLevels[1], npcMaxHealths[1], nil, npcIDs[1], npcIDs, npcDisplayIDs[1])
            table.insert(run.bossKillLog, {
                time = bossInfo.lastKilledAt,
                timeText = bossInfo.lastKilledAtText,
                killTime = killTime,
                startTime = startTime,
                bossID = bossID,
                encounterID = encounterID,
                encounterKey = encounterKey,
                name = bossInfo.name,
                source = "encounter",
            })
        end
    end

    Debug("Encounter completed: " .. tostring(encounterName) .. " (" .. tostring(encounterID) .. ")" .. (alreadyKilled and " duplicate ignored" or ""))
    local killed, total = self:GetKilledBossCount(run)
    if total > 0 then
        Debug("Boss checklist: " .. tostring(killed) .. "/" .. tostring(total) .. " for " .. tostring(run.instanceName or "unknown dungeon"))
    end

    if self:HaveAllRequiredBossesDied(run) then
        self:MarkCurrentRunCompleted("all required bosses killed")
    elseif self:IsFinalBoss(run, encounterID, encounterName) then
        self:MarkCurrentRunCompleted("final boss: " .. tostring(encounterName or encounterID))
    end
end

function Addon:RecordBossKill(encounterID, encounterName)
    self:RecordEncounterEnd(encounterID, encounterName, 1)
end

function Addon:ReconcileSavedCompletions()
    if not self.db or not self.db.runOrder then
        return
    end

    -- Uses HaveAllRequiredBossesDied, not IsFinalBoss -- found during the 2026-09-04 full-file
    -- audit: this function runs on every single load and permanently rewrites a run's saved
    -- status, so it needs the most defensible signal available, not a heuristic. IsFinalBoss's
    -- "last boss in Journal listing order" fallback (v0.1.176) is still just a guess when the
    -- Journal's own isFinal field can't be trusted -- fine as a live in-run shortcut where being
    -- occasionally wrong just means a slightly early completion the player can see and correct,
    -- but too risky to use for silently rewriting historical Abandoned/Active runs to Completed
    -- on every reload if it's ever wrong for some dungeon. HaveAllRequiredBossesDied requires
    -- every required boss to be in the run's own recorded killedBosses, not a guess about which
    -- one closes the instance.
    local repaired = 0
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and self:IsMPlusLedgerRun(run) and run.runStatus ~= "Completed" and run.runStatus ~= "CompletedOvertime" then
            if self:HaveAllRequiredBossesDied(run) then
                local lastEncounter = run.encounters and run.encounters[#run.encounters]
                run.runStatus = "Completed"
                run.completionReason = "saved: all required bosses killed"
                run.completedAt = (lastEncounter and lastEncounter.time) or run.endedAt or time()
                run.completedAtText = (lastEncounter and lastEncounter.timeText) or run.endedAtText or date("%Y-%m-%d %H:%M:%S")
                run.leftWithoutCompletion = false
                run.abandonedReason = nil
                self:ApplyMythicPlusCompletionStatus(run)
                repaired = repaired + 1
            end
        end
    end

    if repaired > 0 then
        Print("Updated " .. tostring(repaired) .. " saved run(s) from failed/abandoned to completed.")
    end
end

function Addon:GetOverallSummary()
    local summary = { runs = 0, playerDeaths = 0, partyDeaths = 0, repairCost = 0, completed = 0, completedOvertime = 0, abandoned = 0, difficulties = self:CreateEmptyDifficultySummary() }
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and self:IsMPlusLedgerRun(run) then
            summary.runs = summary.runs + 1
            summary.playerDeaths = summary.playerDeaths + self:GetPlayerDeaths(run)
            summary.partyDeaths = summary.partyDeaths + self:GetRunDeathTotal(run)
            summary.repairCost = summary.repairCost + (run.repairCost or 0)
            -- Only Mythic+ runs count toward completed/abandoned here -- see GetDungeonSummary
            -- for why non-M+ runs (no key to succeed or fail) are excluded from this ratio.
            if self:IsMythicPlusRun(run) then
                local status = self:GetRunStatus(run)
                if status == "Completed" or status == "CompletedOvertime" then
                    summary.completed = summary.completed + 1
                    if status == "CompletedOvertime" then
                        summary.completedOvertime = (summary.completedOvertime or 0) + 1
                    end
                elseif status == "Abandoned" then
                    summary.abandoned = summary.abandoned + 1
                end
            end
            self:AddRunToDifficultySummary(summary.difficulties, run)
        end
    end
    return summary
end

function Addon:GetCompletionText(completed, abandoned, incompleteLabel)
    local done = tonumber(completed) or 0
    local left = tonumber(abandoned) or 0
    incompleteLabel = incompleteLabel or "Left"
    local total = done + left
    if total <= 0 then
        return string.format("|cff00ff00Completed 0%%|r  |  |cffff3333%s 0%%|r", incompleteLabel)
    end
    local donePct = math.floor((done / total) * 100 + 0.5)
    local leftPct = math.max(0, 100 - donePct)
    return string.format("|cff00ff00Completed %d%%|r  |  |cffff3333%s %d%%|r", donePct, incompleteLabel, leftPct)
end

function Addon:GetCompactCompletionText(completed, abandoned, incompleteLetter)
    local done = tonumber(completed) or 0
    local left = tonumber(abandoned) or 0
    incompleteLetter = incompleteLetter or "F"
    local total = done + left
    if total <= 0 then
        return string.format("|cff00ff00C 0%%|r  |cffff5555%s 0%%|r", incompleteLetter)
    end

    local donePct = math.floor((done / total) * 100 + 0.5)
    local leftPct = math.max(0, 100 - donePct)
    return string.format("|cff00ff00C %d%%|r  |cffff5555%s %d%%|r", donePct, incompleteLetter, leftPct)
end

function Addon:GetCompactDifficultyText(difficulties)
    difficulties = difficulties or {}
    local parts = {}
    for _, key in ipairs(DIFFICULTY_BUCKET_ORDER) do
        local runs = difficulties[key] and difficulties[key].runs or 0
        if runs > 0 then
            local config = DIFFICULTY_BUCKETS[key]
            table.insert(parts, string.format("%s%s|r %d", config.color, config.short, runs))
        end
    end

    if #parts == 0 then
        return "|cff33d6ccN|r 0"
    end

    return table.concat(parts, " ")
end

function Addon:GetSummaryRibbonStatus(summary)
    if summary and summary.active then
        return "Active"
    end

    local completed = summary and tonumber(summary.completed) or 0
    local failed = summary and tonumber(summary.abandoned) or 0
    if completed >= failed and completed > 0 then
        return "Completed"
    end
    return "Failed"
end

function Addon:GetDungeonSummary(name)
    local summary = { name = name, runs = 0, playerDeaths = 0, partyDeaths = 0, repairCost = 0, duration = 0, completed = 0, completedOvertime = 0, abandoned = 0, bestRun = nil, difficulties = self:CreateEmptyDifficultySummary() }
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and self:IsMPlusLedgerRun(run) and run.instanceName == name then
            summary.runs = summary.runs + 1
            summary.playerDeaths = summary.playerDeaths + self:GetPlayerDeaths(run)
            summary.partyDeaths = summary.partyDeaths + self:GetRunDeathTotal(run)
            summary.repairCost = summary.repairCost + (run.repairCost or 0)
            summary.duration = summary.duration + GetRunDuration(run)
            local status = self:GetRunStatus(run)
            -- Completed/abandoned counts (and the card's status ribbon/text derived from them)
            -- only reflect Mythic+ runs -- Normal/Heroic/Mythic/Follower/Timewalking runs don't
            -- have a "key" to succeed or fail, so mixing them in skewed the bar meaninglessly.
            if self:IsMythicPlusRun(run) then
                if status == "Completed" or status == "CompletedOvertime" then
                    summary.completed = summary.completed + 1
                    if status == "CompletedOvertime" then
                        summary.completedOvertime = (summary.completedOvertime or 0) + 1
                    end
                elseif status == "Abandoned" then
                    summary.abandoned = summary.abandoned + 1
                end
            end
            -- bestRun = highest-level run actually completed ON TIME (status == "Completed" only,
            -- not "CompletedOvertime"), ties broken by fastest completion of that same level.
            -- Was previously "fastest completion of ANY level, timed or not" -- picked by lowest
            -- duration alone, no key-level comparison at all. User found this confusing 2026-09-10:
            -- a card could show "Best: +2 in 14m 12s" right next to "Season: +10 (overtime)" for
            -- the same dungeon, because a quick low-key clear beat a slower high-key one purely on
            -- time, even though the high key is clearly the more impressive result. "Best" now
            -- means what a player actually expects it to mean.
            if status == "Completed" then
                local level = self:GetRunKeyLevel(run) or 0
                local bestLevel = summary.bestRun and (self:GetRunKeyLevel(summary.bestRun) or 0) or -1
                if not summary.bestRun or level > bestLevel or (level == bestLevel and GetRunDuration(run) < GetRunDuration(summary.bestRun)) then
                    summary.bestRun = run
                end
            end
            self:AddRunToDifficultySummary(summary.difficulties, run)
        end
    end
    return summary
end

function Addon:FormatMemberSummaryColored(run)
    if not run or not run.members or #run.members == 0 then
        return "No player roster recorded"
    end
    local parts = {}
    for _, member in ipairs(run.members) do
        local color = CLASS_COLORS[member.class or ""] or "|cffffffff"
        local guild = member.guild and member.guild ~= "" and (" <" .. member.guild .. ">") or ""
        table.insert(parts, string.format("%s%s%s|r: %d", color, GetShortName(member.name), guild, self:GetMemberDeathCount(run, member)))
    end
    return table.concat(parts, "\n")
end

function Addon:GetRoleColumnText(run, wantedRole)
    if not run or not run.members or #run.members == 0 then
        return "-"
    end

    local lines = {}
    for _, member in ipairs(run.members) do
        local role = member.role or "DAMAGER"
        if role == "NONE" then
            role = "DAMAGER"
        end
        if role == wantedRole then
            local color = CLASS_COLORS[member.class or ""] or "|cffffffff"
            table.insert(lines, string.format("%s%s|r: %d", color, GetShortName(member.name), self:GetMemberDeathCount(run, member)))
        end
    end

    if #lines == 0 then
        return "-"
    end

    table.sort(lines)
    return table.concat(lines, "\n")
end

function Addon:GetRunShareText(run)
    if not run then
        return nil
    end
    return string.format(
        "M+ Ledger: %s, %s, %s, Your deaths %d, Party deaths %d, Repairs %s, Time %s",
        run.instanceName or "Unknown Dungeon",
        self:GetRunDisplayStatus(run),
        StripColor(self:GetDifficultyText(run)),
        self:GetPlayerDeaths(run),
        self:GetRunDeathTotal(run),
        FormatMoney(run.repairCost or 0),
        FormatDuration(GetRunDuration(run))
    )
end

function Addon:GetRunDeathShareText(run)
    if not run or not run.members or #run.members == 0 then
        return "Deaths: no party roster recorded"
    end

    local parts = {}
    for _, member in ipairs(run.members) do
        local count = self:GetMemberDeathCount(run, member)
        if count > 0 then
            table.insert(parts, string.format("%s x%d", GetShortName(member.name), count))
        end
    end
    table.sort(parts)
    if #parts == 0 then
        return "Deaths: no party deaths recorded"
    end
    return "Deaths: " .. table.concat(parts, ", ")
end

function Addon:GetRecentDungeonSummaries(limit)
    limit = limit or 10
    local summaries = {}
    local byName = {}

    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and self:IsMPlusLedgerRun(run) then
            local name = run.instanceName or "Unknown Dungeon"
            local summary = byName[name]
            if not summary and #summaries < limit then
                summary = {
                    name = name,
                    latestRun = run,
                    runs = 0,
                    playerDeaths = 0,
                    partyDeaths = 0,
                    repairCost = 0,
                    goldLooted = 0,
                    duration = 0,
                    bestDuration = nil,
                    highestKey = 0,
                    currentSeasonHighestKey = 0,
                    difficultyRank = 0,
                    expansionText = "Unknown Expansion",
                    seasonText = "Unknown Season",
                    completed = 0,
                    completedOvertime = 0,
                    abandoned = 0,
                    active = false,
                    difficulties = self:CreateEmptyDifficultySummary(),
                    latestStartedAtText = run.startedAtText,
                }
                byName[name] = summary
                table.insert(summaries, summary)
            end

            if summary then
                summary.runs = summary.runs + 1
                summary.playerDeaths = summary.playerDeaths + self:GetPlayerDeaths(run)
                summary.partyDeaths = summary.partyDeaths + self:GetRunDeathTotal(run)
                summary.repairCost = summary.repairCost + (run.repairCost or 0)
                summary.goldLooted = (summary.goldLooted or 0) + (run.goldLooted or 0)
                summary.duration = summary.duration + GetRunDuration(run)
                summary.highestKey = math.max(summary.highestKey or 0, self:GetRunKeyLevel(run))
                if self:RunMatchesCurrentSeason(run) then
                    summary.currentSeasonHighestKey = math.max(summary.currentSeasonHighestKey or 0, self:GetRunKeyLevel(run))
                end
                summary.difficultyRank = math.max(summary.difficultyRank or 0, self:GetRunDifficultyRank(run))
                local expansionText = self:GetRunExpansionText(run)
                if expansionText ~= "Unknown Expansion" or summary.expansionText == "Unknown Expansion" then
                    summary.expansionText = expansionText
                end
                local seasonText = self:GetRunMythicPlusSeasonText(run)
                if seasonText ~= "Unknown Season" or summary.seasonText == "Unknown Season" then
                    summary.seasonText = seasonText
                end
                local status = self:GetRunStatus(run)
                if status == "Completed" or status == "CompletedOvertime" then
                    summary.completed = (summary.completed or 0) + 1
                    if status == "CompletedOvertime" then
                        summary.completedOvertime = (summary.completedOvertime or 0) + 1
                    end
                    local duration = GetRunDuration(run)
                    if duration > 0 and (not summary.bestDuration or duration < summary.bestDuration) then
                        summary.bestDuration = duration
                    end
                elseif status == "Abandoned" then
                    summary.abandoned = (summary.abandoned or 0) + 1
                end
                if not run.endedAt then
                    summary.active = true
                end
                self:AddRunToDifficultySummary(summary.difficulties, run)
            end
        end
    end

    return summaries
end

-- Season Overview data: unlike GetRecentDungeonSummaries (all-time, capped at `limit` distinct
-- dungeons), this is scoped to the current season only and seeded from the full M+ pool
-- (GetMythicPlusPoolEntries, populated by /dl icons) so a dungeon with zero runs this season still
-- shows up as "not run yet" instead of silently missing from the comparison.
function Addon:GetSeasonOverviewData()
    local byName = {}
    local order = {}
    for _, entry in ipairs(self:GetMythicPlusPoolEntries()) do
        if entry.name and not byName[entry.name] then
            local row = { name = entry.name, runs = 0, onTime = 0, overtime = 0, abandoned = 0, highestKey = 0 }
            byName[entry.name] = row
            table.insert(order, row)
        end
    end

    -- highestKeyRun (any attempt, any outcome) vs. highestKeyCompleted (actually finished --
    -- Completed or CompletedOvertime, not Abandoned) split out 2026-09-30 per user request ("it
    -- should be highest key run, and highest key completed" instead of one ambiguous "Highest Key").
    local totalRuns, totalOnTime, totalOvertime, totalAbandoned, totalDeaths, highestKeyRun, highestKeyCompleted = 0, 0, 0, 0, 0, 0, 0

    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and self:IsMPlusLedgerRun(run) and self:IsMythicPlusRun(run) and self:RunMatchesCurrentSeason(run) then
            local name = run.instanceName or "Unknown Dungeon"
            local row = byName[name]
            if not row then
                row = { name = name, runs = 0, onTime = 0, overtime = 0, abandoned = 0, highestKey = 0 }
                byName[name] = row
                table.insert(order, row)
            end

            row.runs = row.runs + 1
            totalRuns = totalRuns + 1
            local status = self:GetRunStatus(run)
            local wasCompleted = false
            if status == "Completed" then
                row.onTime = row.onTime + 1
                totalOnTime = totalOnTime + 1
                wasCompleted = true
            elseif status == "CompletedOvertime" then
                row.overtime = row.overtime + 1
                totalOvertime = totalOvertime + 1
                wasCompleted = true
            elseif status == "Abandoned" then
                row.abandoned = row.abandoned + 1
                totalAbandoned = totalAbandoned + 1
            end

            local key = self:GetRunKeyLevel(run)
            row.highestKey = math.max(row.highestKey, key)
            highestKeyRun = math.max(highestKeyRun, key)
            if wasCompleted then
                highestKeyCompleted = math.max(highestKeyCompleted, key)
            end
            totalDeaths = totalDeaths + self:GetRunDeathTotal(run)
        end
    end

    table.sort(order, function(a, b)
        if (a.runs > 0) ~= (b.runs > 0) then
            return a.runs > 0
        end
        if a.runs ~= b.runs then
            return a.runs > b.runs
        end
        return tostring(a.name) < tostring(b.name)
    end)

    local maxDungeonRuns = 1
    for _, row in ipairs(order) do
        maxDungeonRuns = math.max(maxDungeonRuns, row.runs)
    end

    local completedTotal = totalOnTime + totalOvertime
    return {
        seasonLabel = self:GetCurrentSeasonName() or "Current Season",
        dungeons = order,
        maxDungeonRuns = maxDungeonRuns,
        totalRuns = totalRuns,
        onTime = totalOnTime,
        overtime = totalOvertime,
        abandoned = totalAbandoned,
        completed = completedTotal,
        completionPct = totalRuns > 0 and (completedTotal / totalRuns * 100) or 0,
        avgDeaths = totalRuns > 0 and (totalDeaths / totalRuns) or 0,
        highestKeyRun = highestKeyRun,
        highestKeyCompleted = highestKeyCompleted,
    }
end

function Addon:GetMainSortOptions()
    return MAIN_SORT_OPTIONS
end

function Addon:GetMainViewOptions()
    return MAIN_VIEW_OPTIONS
end

function Addon:GetMainViewLabel()
    local selected = self.db and self.db.mainView or "currentSeason"
    for _, option in ipairs(MAIN_VIEW_OPTIONS) do
        if option.value == selected then
            return option.text
        end
    end
    return "Current Season"
end

function Addon:GetMainSortLabel()
    local selected = self.db and self.db.mainSort or "highestKey"
    for _, option in ipairs(MAIN_SORT_OPTIONS) do
        if option.value == selected then
            return option.text
        end
    end
    return "Highest Key"
end

local function GetSummaryLatestTime(summary)
    return tonumber(summary and summary.latestRun and summary.latestRun.startedAt) or 0
end

local function CompareSummaryTiebreak(left, right)
    local leftTime = GetSummaryLatestTime(left)
    local rightTime = GetSummaryLatestTime(right)
    if leftTime ~= rightTime then
        return leftTime > rightTime
    end
    return tostring(left and left.name or "") < tostring(right and right.name or "")
end

local function CompareSummaryNumberDesc(left, right, field)
    local leftValue = tonumber(left and left[field]) or 0
    local rightValue = tonumber(right and right[field]) or 0
    if leftValue ~= rightValue then
        return leftValue > rightValue
    end
    return CompareSummaryTiebreak(left, right)
end

local function CompareSummaryTextAsc(left, right, field, unknownText)
    local leftValue = tostring(left and left[field] or unknownText or "")
    local rightValue = tostring(right and right[field] or unknownText or "")
    if leftValue == (unknownText or "") and rightValue ~= (unknownText or "") then
        return false
    elseif rightValue == (unknownText or "") and leftValue ~= (unknownText or "") then
        return true
    elseif leftValue ~= rightValue then
        return leftValue < rightValue
    end
    return CompareSummaryTiebreak(left, right)
end

function Addon:SortDungeonSummaries(summaries)
    if not summaries then
        return summaries
    end

    local sortMode = self.db and self.db.mainSort or "highestKey"
    if sortMode == "difficulty" then
        table.sort(summaries, function(left, right)
            local leftValue = tonumber(left and left.difficultyRank) or 0
            local rightValue = tonumber(right and right.difficultyRank) or 0
            if leftValue ~= rightValue then
                return leftValue > rightValue
            end
            local leftKey = tonumber(left and left.highestKey) or 0
            local rightKey = tonumber(right and right.highestKey) or 0
            if leftKey ~= rightKey then
                return leftKey > rightKey
            end
            return CompareSummaryTiebreak(left, right)
        end)
    elseif sortMode == "partyDeaths" then
        table.sort(summaries, function(left, right) return CompareSummaryNumberDesc(left, right, "partyDeaths") end)
    elseif sortMode == "playerDeaths" then
        table.sort(summaries, function(left, right) return CompareSummaryNumberDesc(left, right, "playerDeaths") end)
    elseif sortMode == "totalDeaths" then
        table.sort(summaries, function(left, right)
            local leftValue = (tonumber(left and left.partyDeaths) or 0) + (tonumber(left and left.playerDeaths) or 0)
            local rightValue = (tonumber(right and right.partyDeaths) or 0) + (tonumber(right and right.playerDeaths) or 0)
            if leftValue ~= rightValue then
                return leftValue > rightValue
            end
            return CompareSummaryTiebreak(left, right)
        end)
    elseif sortMode == "bestTime" then
        table.sort(summaries, function(left, right)
            local leftValue = tonumber(left and left.bestDuration) or 0
            local rightValue = tonumber(right and right.bestDuration) or 0
            if leftValue <= 0 and rightValue > 0 then
                return false
            elseif rightValue <= 0 and leftValue > 0 then
                return true
            elseif leftValue ~= rightValue then
                return leftValue < rightValue
            end
            return CompareSummaryTiebreak(left, right)
        end)
    elseif sortMode == "highestKey" then
        table.sort(summaries, function(left, right) return CompareSummaryNumberDesc(left, right, "highestKey") end)
    elseif sortMode == "runs" then
        table.sort(summaries, function(left, right) return CompareSummaryNumberDesc(left, right, "runs") end)
    elseif sortMode == "abandoned" then
        table.sort(summaries, function(left, right) return CompareSummaryNumberDesc(left, right, "abandoned") end)
    elseif sortMode == "completed" then
        table.sort(summaries, function(left, right) return CompareSummaryNumberDesc(left, right, "completed") end)
    elseif sortMode == "repairCost" then
        table.sort(summaries, function(left, right) return CompareSummaryNumberDesc(left, right, "repairCost") end)
    elseif sortMode == "expansion" then
        table.sort(summaries, function(left, right) return CompareSummaryTextAsc(left, right, "expansionText", "Unknown Expansion") end)
    elseif sortMode == "season" then
        table.sort(summaries, function(left, right)
            local leftKey = tonumber(left and left.highestKey) or 0
            local rightKey = tonumber(right and right.highestKey) or 0
            if leftKey ~= rightKey then
                return leftKey > rightKey
            end
            return CompareSummaryTextAsc(left, right, "seasonText", "Unknown Season")
        end)
    else
        table.sort(summaries, CompareSummaryTiebreak)
    end

    return summaries
end

function Addon:GetSummaryGroupText(summary, viewMode)
    if viewMode == "expansion" then
        return tostring(summary and summary.expansionText or "Unknown Expansion")
    elseif viewMode == "season" or viewMode == "currentSeason" then
        return tostring(summary and summary.seasonText or "Unknown Season")
    end
    return nil
end

function Addon:GetSortedSummaryGroups(summaries, viewMode)
    local grouped = {}
    local order = {}
    local ranks = {}
    local rankOptions = viewMode == "expansion" and self:GetDataToolExpansionOptions() or self:GetDataToolSeasonOptions()
    for index, option in ipairs(rankOptions or {}) do
        ranks[tostring(option.value or option.text or "")] = index
    end
    for _, summary in ipairs(summaries or {}) do
        local groupName = self:GetSummaryGroupText(summary, viewMode)
        if groupName then
            if not grouped[groupName] then
                grouped[groupName] = {}
                table.insert(order, groupName)
            end
            table.insert(grouped[groupName], summary)
        end
    end

    table.sort(order, function(left, right)
        local leftRank = ranks[left]
        local rightRank = ranks[right]
        if leftRank and rightRank and leftRank ~= rightRank then
            return leftRank < rightRank
        elseif leftRank and not rightRank then
            return true
        elseif rightRank and not leftRank then
            return false
        end
        if left == "Unknown Expansion" or left == "Unknown Season" then
            return false
        elseif right == "Unknown Expansion" or right == "Unknown Season" then
            return true
        end
        return left < right
    end)

    for _, groupName in ipairs(order) do
        self:SortDungeonSummaries(grouped[groupName])
    end
    return order, grouped
end

function Addon:BuildMainDisplayItems(summaries)
    local viewMode = self.db and self.db.mainView or "currentSeason"
    if viewMode == "currentSeason" then
        summaries = self:FilterSummariesForActiveSeason(summaries)
    elseif viewMode == "season" then
        -- "Mythic+ Season" filter should only show dungeons that actually HAVE a real M+ season
        -- association -- per user report/screenshot 2026-09-30 ("the Mythic+ Season filter still
        -- shows dungeons under the Unknown header. this should not be there"). A dungeon that's
        -- only ever been run at Normal/Timewalking/etc (GetRunMythicPlusSeasonText correctly
        -- returns "Unknown Season" for those -- see that function's own history of fixes) isn't a
        -- missing label to fill in, it genuinely has no M+ season to show here, so it's excluded
        -- from this view entirely rather than bucketed under a catch-all header.
        local filtered = {}
        for _, summary in ipairs(summaries or {}) do
            if summary.seasonText and summary.seasonText ~= "Unknown Season" then
                table.insert(filtered, summary)
            end
        end
        summaries = filtered
    end
    if viewMode ~= "expansion" and viewMode ~= "season" and viewMode ~= "currentSeason" then
        self:SortDungeonSummaries(summaries)
        local flat = {}
        for _, summary in ipairs(summaries or {}) do
            table.insert(flat, { kind = "card", summary = summary })
        end
        return flat, summaries
    end

    local items = {}
    local order, grouped = self:GetSortedSummaryGroups(summaries, viewMode)
    for _, groupName in ipairs(order) do
        table.insert(items, { kind = "banner", text = groupName })
        for _, summary in ipairs(grouped[groupName] or {}) do
            table.insert(items, { kind = "card", summary = summary })
        end
    end
    return items, summaries
end

function Addon:GetRunLine(run)
    if not run then
        return "No dungeon run recorded yet."
    end

    local duration = GetRunDuration(run)
    return string.format(
        "%s - %s | Your deaths: %d | Party deaths: %d | Gold looted: %s | Your repairs: %s | Duration: %s | Code: %s",
        self:GetRunDisplayStatus(run),
        run.instanceName or "Unknown Dungeon",
        self:GetPlayerDeaths(run),
        self:GetRunDeathTotal(run),
        FormatMoney(run.goldLooted or 0),
        FormatMoneyIcons(run.repairCost or 0),
        FormatDuration(duration),
        self:GetRunCode(run) or "-"
    )
end



function Addon:IsUiLocked()
    return InCombatLockdown and InCombatLockdown()
end

function Addon:MarkUiDirty()
    self.uiDirty = true
end

function Addon:FlushDeferredUi()
    if self:IsUiLocked() then
        self:MarkUiDirty()
        return
    end

    if self.uiDirty then
        self.uiDirty = false
        self:RefreshAllDisplays()
    end
    if self.pendingInstanceScan then
        local source = self.pendingInstanceScan
        self.pendingInstanceScan = nil
        self:QueueInstanceScan(source .. " after combat")
    end
end
function Addon:CreatePlainButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 100, height or 24)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.45, 0.02, 0.02, 0.85)
    button:SetBackdropBorderColor(self:GetThemeBorderColor(true, 0.9))
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("CENTER")
    button.text:SetText(text or "Button")
    button:SetScript("OnEnter", function(self)
        local color = self.normalBackdrop
        if color then
            self:SetBackdropColor(math.min((color[1] or 0) + 0.12, 1), math.min((color[2] or 0) + 0.12, 1), math.min((color[3] or 0) + 0.12, 1), 0.96)
        else
            self:SetBackdropColor(0.65, 0.05, 0.05, 0.95)
        end
    end)
    button:SetScript("OnLeave", function(self)
        local color = self.normalBackdrop
        if color then
            self:SetBackdropColor(color[1] or 0.45, color[2] or 0.02, color[3] or 0.02, 0.88)
        else
            self:SetBackdropColor(0.45, 0.02, 0.02, 0.85)
        end
    end)
    button.SetText = function(self, value)
        self.text:SetText(value or "")
    end
    return button
end

function Addon:CreateCheckButton(parent, label, getter, setter)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(260, 24)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 0.72)

    button.check = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.check:SetPoint("LEFT", 8, 0)
    button.check:SetWidth(18)
    button.check:SetJustifyH("CENTER")

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button.check, "RIGHT", 8, 0)
    button.label:SetText(label)
    button.label:SetJustifyH("LEFT")

    button.Refresh = function(self)
        self.check:SetText(getter() and "|cff00ff00X|r" or "|cff777777-|r")
    end
    button:SetScript("OnClick", function(self)
        setter(not getter())
        self:Refresh()
    end)
    button:Refresh()
    return button
end

-- Generic per-page refresh, used by both the main Settings page and the Colours/Chats
-- subcategory pages -- each page only has whatever fields it actually created (e.g. only the
-- Colours page has overallDifficultyOpacitySlider), so every block below is a no-op on pages
-- that don't have that control.
function Addon:RefreshSettingsPanelGroup(panel)
    if not panel or not panel.checkButtons then
        return
    end

    for _, button in ipairs(panel.checkButtons) do
        button:Refresh()
    end

    local opacitySlider = panel.overallDifficultyOpacitySlider
    if opacitySlider and self.db then
        local value = math.floor(((self.db.overallDifficultyOpacity or DEFAULTS.overallDifficultyOpacity) * 100) + 0.5)
        opacitySlider:SetValue(value)
        if panel.overallDifficultyOpacityValue then
            panel.overallDifficultyOpacityValue:SetText(tostring(value) .. "%")
        end
    end
    local runOpacitySlider = panel.runCardOpacitySlider
    if runOpacitySlider and self.db then
        local value = math.floor(((self.db.runCardOpacity or DEFAULTS.runCardOpacity) * 100) + 0.5)
        runOpacitySlider:SetValue(value)
        if panel.runCardOpacityValue then
            panel.runCardOpacityValue:SetText(tostring(value) .. "%")
        end
    end
    if panel.shareTargetButton then
        local usingCurrentChat = not self.db or self.db.shareUseCurrentChat ~= false
        local label = "Share send to: " .. self:GetShareTargetLabel()
        panel.shareTargetButton.text:SetText(usingCurrentChat and ("|cff808080" .. label .. " (inactive)|r") or label)
    end
    if panel.shareTargetMenu then
        self:RefreshSimpleDropdown(panel.shareTargetMenu, SHARE_TARGET_OPTIONS, function(value)
            Addon.db.shareTarget = value
            Addon:RefreshSettingsPanel()
        end)
        panel.shareTargetMenu:Hide()
    end
end

function Addon:RefreshSettingsPanel()
    self:RefreshSettingsPanelGroup(self.settingsPanel)
    for _, panel in ipairs(self.settingsSubPanels or {}) do
        self:RefreshSettingsPanelGroup(panel)
    end
end

function Addon:PositionMinimapButton()
    if not self.minimapButton or not Minimap then
        return
    end

    local angle = math.rad((self.db and self.db.minimap and self.db.minimap.angle) or 225)
    local minimapRadius = ((Minimap:GetWidth() or 140) / 2)
    local radius = minimapRadius + 6
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function Addon:CreateMinimapButton()
    if self.minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    button:SetSize(38, 38)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(80)
    -- Keep the minimap book freestanding, without a background or border.
    button:SetBackdrop(nil)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button.icon:SetSize(34, 34)
    -- Match the current ledger cover and follow artwork-theme changes.
    button.icon:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\MPlusLedgerSkin\\Media\\MenuIcons\\Book.png")
    if Skin and Skin.ThemeAsset then Skin.ThemeAsset(button.icon, "runs") end

    button:SetScript("OnClick", function(self, mouseButton)
        if self.wasDragging then
            self.wasDragging = false
            return
        end
        if mouseButton == "RightButton" then
            Addon:OpenSettings()
        else
            -- M+ Summary is now the addon's main entry point -- see the matching /dl change.
            Addon:ToggleStatsHubWindow("mplus")
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = GetAngleDegrees(py - my, px - mx)
            Addon.db.minimap.angle = angle
            Addon:PositionMinimapButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.wasDragging = true
        Addon:PositionMinimapButton()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.2, function()
                if self then
                    self.wasDragging = false
                end
            end)
        end
    end)
    button:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("M+ Ledger")
            GameTooltip:AddLine("Left-click: open ledger", 1, 1, 1)
            GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.minimapButton = button
    self:PositionMinimapButton()
    self:RefreshMinimapButton()
end

function Addon:RefreshMinimapButton()
    if self.db and self.db.minimap and self.db.minimap.shown then
        if not self.minimapButton then
            self:CreateMinimapButton()
        end
        if not self.minimapButton then
            return
        end
        self.minimapButton:Show()
    else
        if not self.minimapButton then
            return
        end
        self.minimapButton:Hide()
    end
    self:RefreshSettingsPanel()
end

-- Section headers, shared by the main Settings page and both subcategory pages below. Purely
-- visual/organizational -- no setting's key, default, or behavior changes based on which page it
-- lives on.
local function CreateSettingsSectionHeader(panel, anchorFrame, anchorPoint, text, topGap)
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", anchorFrame, anchorPoint, 0, -(topGap or 22))
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0, 1)
    return header
end

-- Rebuilt 2026-09-08 into three pages (per user request: "add a tabbed card section... one for
-- chats, one for colours and one for settings") using Blizzard's own Settings.
-- RegisterCanvasLayoutSubcategory -- confirmed a real, current API before using it (parentCategory,
-- frame, name), rather than building a custom tab bar squeezed inside one canvas competing with
-- Blizzard's own Okay/Cancel/Defaults footer for vertical space. Each page is its own nested,
-- clickable entry under "M+ Ledger" in the Settings tree -- Blizzard's native equivalent of
-- tabs for this kind of panel, and consistent with how other well-organized addons (ElvUI,
-- WeakAuras) split their own settings.
function Addon:CreateSettingsPanel()
    if self.settingsPanel then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = "M+ Ledger"
    panel.checkButtons = {}

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("M+ Ledger")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Dungeon run tracking, repairs, deaths, and display options. See Colours and Chats below for appearance and chat-broadcast settings.")

    -- === General ===
    local generalHeader = CreateSettingsSectionHeader(panel, subtitle, "BOTTOMLEFT", "General", 14)

    local open = self:CreatePlainButton(panel, "Open Ledger", 130, 26)
    open:SetPoint("TOPLEFT", generalHeader, "BOTTOMLEFT", 0, -10)
    open:SetScript("OnClick", function()
        Addon:ToggleWindow()
    end)

    local tracker = self:CreatePlainButton(panel, "Toggle Bar", 130, 26)
    tracker:SetPoint("LEFT", open, "RIGHT", 12, 0)
    tracker:SetScript("OnClick", function()
        Addon:ToggleTrackerBar()
        Addon:RefreshSettingsPanel()
    end)

    local minimapCheck = self:CreateCheckButton(panel, "Show minimap button", function()
        return Addon.db and Addon.db.minimap and Addon.db.minimap.shown
    end, function(value)
        Addon.db.minimap.shown = value and true or false
        Addon:RefreshMinimapButton()
    end)
    minimapCheck:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -14)
    table.insert(panel.checkButtons, minimapCheck)

    local trackerCheck = self:CreateCheckButton(panel, "Show live tracker bar", function()
        return Addon.db and Addon.db.tracker and Addon.db.tracker.shown
    end, function(value)
        if value then
            Addon:ShowTrackerBar()
        else
            Addon:HideTrackerBar()
        end
    end)
    trackerCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, trackerCheck)

    local reputationCheck = self:CreateCheckButton(panel, "Hide post-dungeon Player Reputation popup", function()
        return not Addon.db or Addon.db.hidePostDungeonReputation ~= false
    end, function(value)
        Addon.db.hidePostDungeonReputation = value and true or false
        if value and Addon.ratingPopup then Addon.ratingPopup:Hide() end
    end)
    reputationCheck:SetSize(390, 24)
    reputationCheck:SetPoint("TOPLEFT", trackerCheck, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, reputationCheck)

    -- Tracker bar scale -- user asked "can this menu be resized?" 2026-09-10. A true drag-to-
    -- resize handle would need every internal element (title/meta/deaths text, enemy forces bar)
    -- to re-flow at arbitrary widths/heights, which none of them are built for (all fixed pixel
    -- offsets). SetScale scales the whole frame -- text, bars, backdrop -- uniformly as one unit
    -- instead, the same approach most WoW HUD-style addons use for "resize this" requests.
    local trackerScaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    trackerScaleLabel:SetPoint("TOPLEFT", reputationCheck, "BOTTOMLEFT", 22, -14)
    trackerScaleLabel:SetText("Tracker bar size")

    local trackerScaleValue = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    trackerScaleValue:SetPoint("LEFT", trackerScaleLabel, "RIGHT", 12, 0)

    local trackerScaleSlider = CreateFrame("Slider", "MPlusLedgerTrackerScaleSlider", panel, "OptionsSliderTemplate")
    trackerScaleSlider:SetPoint("TOPLEFT", trackerScaleLabel, "BOTTOMLEFT", 6, -8)
    trackerScaleSlider:SetSize(240, 18)
    trackerScaleSlider:SetMinMaxValues(70, 200)
    trackerScaleSlider:SetValueStep(5)
    if trackerScaleSlider.SetObeyStepOnDrag then
        trackerScaleSlider:SetObeyStepOnDrag(true)
    end
    if trackerScaleSlider.Low then
        trackerScaleSlider.Low:SetText("70%")
    end
    if trackerScaleSlider.High then
        trackerScaleSlider.High:SetText("200%")
    end
    if trackerScaleSlider.Text then
        trackerScaleSlider.Text:SetText("")
    end
    trackerScaleSlider:SetValue(math.floor(((Addon.db and Addon.db.tracker and Addon.db.tracker.scale) or 1) * 100 + 0.5))
    trackerScaleValue:SetText(tostring(math.floor(((Addon.db and Addon.db.tracker and Addon.db.tracker.scale) or 1) * 100 + 0.5)) .. "%")
    trackerScaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((tonumber(value) or 100) + 0.5)
        Addon.db.tracker = Addon.db.tracker or CopyDefaults({}, DEFAULTS.tracker)
        Addon.db.tracker.scale = value / 100
        trackerScaleValue:SetText(tostring(value) .. "%")
        if Addon.trackerBar then
            Addon.trackerBar:SetScale(value / 100)
        end
    end)
    panel.trackerScaleSlider = trackerScaleSlider
    panel.trackerScaleValue = trackerScaleValue

    -- === Mythic+ Tracking ===
    local trackingHeader = CreateSettingsSectionHeader(panel, trackerScaleSlider, "BOTTOMLEFT", "Mythic+ Tracking")

    local trackRaidsCheck = self:CreateCheckButton(panel, "Track raid runs (in addition to dungeons)", function()
        return Addon.db and Addon.db.trackRaids ~= false
    end, function(value)
        Addon.db.trackRaids = value and true or false
        Print("Raid tracking is now " .. (Addon.db.trackRaids and "on" or "off") .. ".")
    end)
    trackRaidsCheck:SetPoint("TOPLEFT", trackingHeader, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, trackRaidsCheck)

    -- === Debug ===
    local debugHeader = CreateSettingsSectionHeader(panel, trackRaidsCheck, "BOTTOMLEFT", "Debug")

    local debugCheck = self:CreateCheckButton(panel, "Debug messages", function()
        return Addon.db and Addon.db.debug
    end, function(value)
        Addon.db.debug = value and true or false
        -- Turning this off must also turn off fullDebug -- fullDebug previously had NO UI
        -- control at all (only /dl fulldebug), so it stayed stuck on for the rest of the account
        -- indefinitely after being toggled on once for diagnostics, even with this checkbox
        -- showing unchecked. Found 2026-09-01: user reported still seeing FullDebug: chat spam
        -- with this checkbox off. Turning debug ON does not also enable fullDebug -- that stays a
        -- separate, more-verbose opt-in via the checkbox below or /dl fulldebug.
        if not Addon.db.debug then
            Addon.db.fullDebug = false
        end
        Print("Debug is now " .. (Addon.db.debug and "on" or "off") .. ".")
        Addon:RefreshAllDisplays()
    end)
    debugCheck:SetPoint("TOPLEFT", debugHeader, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, debugCheck)

    local fullDebugCheck = self:CreateCheckButton(panel, "Full (verbose) debug messages", function()
        return Addon.db and Addon.db.fullDebug
    end, function(value)
        Addon.db.fullDebug = value and true or false
        Print("Full debug is now " .. (Addon.db.fullDebug and "on" or "off") .. ".")
    end)
    fullDebugCheck:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, fullDebugCheck)

    self.settingsPanel = panel
    self.settingsSubPanels = {}
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "M+ Ledger")
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
        if Settings.RegisterCanvasLayoutSubcategory then
            self:CreateSettingsColoursPanel(category)
            self:CreateSettingsChatsPanel(category)
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- === Colours subcategory ===
function Addon:CreateSettingsColoursPanel(category)
    local panel = CreateFrame("Frame")
    panel.name = "Colours"
    panel.checkButtons = {}

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("M+ Ledger - Colours")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Theme and opacity settings for run cards and difficulty colours.")

    local themeCheck = self:CreateCheckButton(panel, "Use new Arcane UI theme (experimental)", function()
        return Addon.db and Addon.db.uiTheme == "arcane"
    end, function(value)
        Addon.db.uiTheme = value and "arcane" or "classic"
        -- Most windows/buttons only set their border color once, at the moment they're first
        -- created -- and by the time this checkbox exists, virtually everything has already been
        -- created for this session. RefreshAllDisplays only repaints the handful of elements that
        -- happen to redraw on every refresh (Dungeon List tiles, Season Overview, Tracker Bar);
        -- everything else needs a genuine reload to be rebuilt with the new theme. Found live
        -- 2026-09-06: toggling this without reloading looked like it did nothing at all.
        Addon:RefreshAllDisplays()
        Print("UI theme is now " .. Addon.db.uiTheme .. ". Type /reload to fully apply it to windows already open this session.")
    end)
    themeCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -18)
    table.insert(panel.checkButtons, themeCheck)

    local opacityLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    opacityLabel:SetPoint("TOPLEFT", themeCheck, "BOTTOMLEFT", 0, -14)
    opacityLabel:SetText("Overall difficulty colour opacity")

    local opacityValue = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    opacityValue:SetPoint("LEFT", opacityLabel, "RIGHT", 12, 0)

    local opacitySlider = CreateFrame("Slider", "MPlusLedgerOverallDifficultyOpacitySlider", panel, "OptionsSliderTemplate")
    opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 6, -8)
    opacitySlider:SetSize(240, 18)
    opacitySlider:SetMinMaxValues(0, 70)
    opacitySlider:SetValueStep(5)
    if opacitySlider.SetObeyStepOnDrag then
        opacitySlider:SetObeyStepOnDrag(true)
    end
    if opacitySlider.Low then
        opacitySlider.Low:SetText("0%")
    end
    if opacitySlider.High then
        opacitySlider.High:SetText("70%")
    end
    if opacitySlider.Text then
        opacitySlider.Text:SetText("")
    end
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((tonumber(value) or 0) + 0.5)
        Addon.db.overallDifficultyOpacity = value / 100
        opacityValue:SetText(tostring(value) .. "%")
        Addon:RefreshAllDisplays()
    end)
    panel.overallDifficultyOpacitySlider = opacitySlider
    panel.overallDifficultyOpacityValue = opacityValue

    local runOpacityLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    runOpacityLabel:SetPoint("TOPLEFT", opacitySlider, "BOTTOMLEFT", -6, -28)
    runOpacityLabel:SetText("Run card background opacity")

    local runOpacityValue = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    runOpacityValue:SetPoint("LEFT", runOpacityLabel, "RIGHT", 12, 0)

    local runOpacitySlider = CreateFrame("Slider", "MPlusLedgerRunCardOpacitySlider", panel, "OptionsSliderTemplate")
    runOpacitySlider:SetPoint("TOPLEFT", runOpacityLabel, "BOTTOMLEFT", 6, -8)
    runOpacitySlider:SetSize(240, 18)
    runOpacitySlider:SetMinMaxValues(25, 95)
    runOpacitySlider:SetValueStep(5)
    if runOpacitySlider.SetObeyStepOnDrag then
        runOpacitySlider:SetObeyStepOnDrag(true)
    end
    if runOpacitySlider.Low then
        runOpacitySlider.Low:SetText("25%")
    end
    if runOpacitySlider.High then
        runOpacitySlider.High:SetText("95%")
    end
    if runOpacitySlider.Text then
        runOpacitySlider.Text:SetText("")
    end
    runOpacitySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((tonumber(value) or 0) + 0.5)
        Addon.db.runCardOpacity = value / 100
        runOpacityValue:SetText(tostring(value) .. "%")
        Addon:RefreshAllDisplays()
    end)
    panel.runCardOpacitySlider = runOpacitySlider
    panel.runCardOpacityValue = runOpacityValue

    -- === Custom Colors === (added 2026-09-08, per user request for "changing of colours for
    -- dungeons, tables etc... a selection menu for it"). Each swatch opens Blizzard's own
    -- ColorPickerFrame; right-click a swatch to reset that one color back to its default.
    local customColorsHeader = CreateSettingsSectionHeader(panel, runOpacitySlider, "BOTTOMLEFT", "Custom Colors", 28)

    local accentLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    accentLabel:SetPoint("TOPLEFT", customColorsHeader, "BOTTOMLEFT", 0, -12)
    accentLabel:SetText("Accent / border color")
    local accentSwatch = self:CreateColorSwatchButton(panel, 22, function()
        local c = Addon.db and Addon.db.colors and Addon.db.colors.accent
        return c and c[1], c and c[2], c and c[3]
    end, function(r, g, b)
        Addon.db.colors = Addon.db.colors or {}
        Addon.db.colors.accent = r and { r, g, b } or nil
        Addon:RefreshAllDisplays()
    end)
    accentSwatch:SetPoint("LEFT", accentLabel, "RIGHT", 10, 0)
    table.insert(panel.checkButtons, accentSwatch)

    local tableBgLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tableBgLabel:SetPoint("TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -14)
    tableBgLabel:SetText("Table / list background")
    local tableBgSwatch = self:CreateColorSwatchButton(panel, 22, function()
        local c = Addon.db and Addon.db.colors and Addon.db.colors.tableBackground
        return c and c[1], c and c[2], c and c[3]
    end, function(r, g, b)
        Addon.db.colors = Addon.db.colors or {}
        Addon.db.colors.tableBackground = r and { r, g, b } or nil
        Addon:RefreshAllDisplays()
    end)
    tableBgSwatch:SetPoint("LEFT", tableBgLabel, "RIGHT", 10, 0)
    table.insert(panel.checkButtons, tableBgSwatch)

    local statusLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusLabel:SetPoint("TOPLEFT", tableBgLabel, "BOTTOMLEFT", 0, -18)
    statusLabel:SetText("Run status colors:")

    -- One text+swatch pair, placed to the RIGHT of whatever frame is passed as anchor (the
    -- previous pair's swatch, or statusLabel for the first one) -- builds a left-to-right row.
    local function statusSwatch(status, label, anchorFrame, gap)
        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        text:SetPoint("LEFT", anchorFrame, "RIGHT", gap, 0)
        text:SetText(label)
        local swatch = self:CreateColorSwatchButton(panel, 20, function()
            local c = Addon:GetCustomStatusColor(status)
            return c and c[1], c and c[2], c and c[3]
        end, function(r, g, b)
            Addon.db.colors = Addon.db.colors or {}
            Addon.db.colors.status = Addon.db.colors.status or {}
            Addon.db.colors.status[status] = r and { r, g, b } or nil
            Addon:RefreshAllDisplays()
        end)
        swatch:SetPoint("LEFT", text, "RIGHT", 6, 0)
        table.insert(panel.checkButtons, swatch)
        return swatch
    end
    local completedSwatch = statusSwatch("Completed", "Completed", statusLabel, 8)
    local overtimeSwatch = statusSwatch("CompletedOvertime", "Overtime", completedSwatch, 16)
    statusSwatch("Abandoned", "Abandoned", overtimeSwatch, 16)

    local dungeonColorsButton = self:CreatePlainButton(panel, "Per-Dungeon Colors...", 200, 24)
    dungeonColorsButton:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", 0, -34)
    dungeonColorsButton:SetScript("OnClick", function()
        Addon:ToggleDungeonColorsWindow()
    end)

    local colorHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    colorHint:SetPoint("TOPLEFT", dungeonColorsButton, "BOTTOMLEFT", 0, -8)
    colorHint:SetWidth(500)
    colorHint:SetJustifyH("LEFT")
    colorHint:SetWordWrap(true)
    colorHint:SetText("Right-click any swatch to reset that color back to default. Some windows need a fresh /reload to fully pick up a color changed after they were first opened this session.")

    panel:SetScript("OnShow", function()
        Addon:RefreshSettingsPanelGroup(panel)
    end)
    Settings.RegisterCanvasLayoutSubcategory(category, panel, panel.name)
    table.insert(self.settingsSubPanels, panel)
end

-- === Chats subcategory === (broadcast reports + share-to-chat, grouped together since both are
-- fundamentally "what this addon sends into chat channels")
function Addon:CreateSettingsChatsPanel(category)
    local panel = CreateFrame("Frame")
    panel.name = "Chats"
    panel.checkButtons = {}

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("M+ Ledger - Chats")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("What this addon sends to party/raid/guild chat, and the player-report broadcast.")

    -- === Player Reports ===
    local reportsHeader = CreateSettingsSectionHeader(panel, subtitle, "BOTTOMLEFT", "Player Reports", 14)

    -- Default OFF as of 2026-09-08 per explicit user request (was default-on since introduction).
    -- Reads as `== true` rather than `~= false` so an unset/nil value reads as off, matching that
    -- intent defensively even if CopyDefaults hasn't populated the field yet for some reason.
    local broadcastReportsCheck = self:CreateCheckButton(panel, "Broadcast player reports when someone joins your group", function()
        return Addon.db and Addon.db.broadcastPlayerReports == true
    end, function(value)
        Addon.db.broadcastPlayerReports = value and true or false
        Print("Broadcasting player reports on join is now " .. (Addon.db.broadcastPlayerReports and "on" or "off") .. ".")
    end)
    broadcastReportsCheck:SetPoint("TOPLEFT", reportsHeader, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, broadcastReportsCheck)

    -- Split out from the join-stage toggle above so the two moments can be controlled
    -- independently -- someone merely applying via Premade Groups (not yet in your party) is
    -- arguably noisier/more sensitive than someone who's actually joined. Also default OFF.
    -- Relabeled 2026-09-08 per user request: applicant reports now ALWAYS print locally
    -- regardless of this setting -- it only controls whether that report also goes out to
    -- party/raid chat (see BroadcastPlayerReport's sendToChat parameter).
    local broadcastApplyCheck = self:CreateCheckButton(panel, "Send player reports to party/raid chat when someone requests to join", function()
        return Addon.db and Addon.db.broadcastPlayerReportsOnApply == true
    end, function(value)
        Addon.db.broadcastPlayerReportsOnApply = value and true or false
        Print("Sending player reports to chat on apply is now " .. (Addon.db.broadcastPlayerReportsOnApply and "on" or "off") .. " (still always shown locally).")
    end)
    broadcastApplyCheck:SetPoint("TOPLEFT", broadcastReportsCheck, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, broadcastApplyCheck)

    -- Default ON (unlike the two toggles above) -- this is the feature the user directly asked
    -- for ("add a popup that shows people applying"), not an opt-in extra.
    local applicantAlertCheck = self:CreateCheckButton(panel, "Show an Accept/Not Sure/Avoid panel listing every new Premade Group applicant", function()
        return Addon.db and Addon.db.showApplicantAlertPopup ~= false
    end, function(value)
        Addon.db.showApplicantAlertPopup = value and true or false
        Print("Applicant Alert popup is now " .. (Addon.db.showApplicantAlertPopup and "on" or "off") .. ".")
    end)
    applicantAlertCheck:SetPoint("TOPLEFT", broadcastApplyCheck, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, applicantAlertCheck)

    -- === Sharing ===
    local sharingHeader = CreateSettingsSectionHeader(panel, applicantAlertCheck, "BOTTOMLEFT", "Sharing")

    -- Renamed + hint added 2026-09-05: user had "Share send to: Guild Chat" picked below but Share
    -- kept opening the chat edit box instead, because this checkbox (types into current chat)
    -- takes priority over the target below and defaults on -- the two controls looked unrelated.
    local shareCurrentCheck = self:CreateCheckButton(panel, "Share button types into current chat box", function()
        return Addon.db and Addon.db.shareUseCurrentChat ~= false
    end, function(value)
        Addon.db.shareUseCurrentChat = value and true or false
        Addon:RefreshSettingsPanel()
    end)
    shareCurrentCheck:SetPoint("TOPLEFT", sharingHeader, "BOTTOMLEFT", 0, -10)
    table.insert(panel.checkButtons, shareCurrentCheck)

    local shareHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    shareHint:SetPoint("TOPLEFT", shareCurrentCheck, "BOTTOMLEFT", 20, -2)
    shareHint:SetText("Uncheck this for Share to auto-send straight to the target below instead.")
    panel.shareHint = shareHint

    local shareTarget = self:CreatePlainButton(panel, "Share send to: Guild Chat", 260, 24)
    shareTarget:SetPoint("TOPLEFT", shareHint, "BOTTOMLEFT", 0, -6)
    shareTarget:SetScript("OnClick", function()
        if panel.shareTargetMenu:IsShown() then
            panel.shareTargetMenu:Hide()
        else
            panel.shareTargetMenu:Show()
        end
    end)
    panel.shareTargetButton = shareTarget

    local shareMenu = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    shareMenu:SetSize(260, 30)
    shareMenu:SetPoint("TOPLEFT", shareTarget, "BOTTOMLEFT", 0, -2)
    shareMenu:SetFrameLevel(120)
    shareMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    shareMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    shareMenu:EnableMouse(true)
    shareMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    shareMenu:Hide()
    panel.shareTargetMenu = shareMenu

    panel:SetScript("OnShow", function()
        Addon:RefreshSettingsPanelGroup(panel)
    end)
    Settings.RegisterCanvasLayoutSubcategory(category, panel, panel.name)
    table.insert(self.settingsSubPanels, panel)
end

-- ============================================================================================
-- Per-Dungeon Colors window: one swatch per dungeon, opened from Settings > Colours. A separate
-- popup rather than crammed into the Settings canvas -- the dungeon list (GetProgressTabDungeonList,
-- the same M+-pool-plus-tracked-history list the Progress tab's selector already uses) can run
-- long, and Blizzard's canvas Settings pages don't nest scroll frames comfortably.
-- ============================================================================================
local DUNGEON_COLORS_ROW_HEIGHT = 32
local DUNGEON_COLORS_ROW_POOL = 60

function Addon:CreateDungeonColorsWindow()
    if self.dungeonColorsWindow then
        return
    end

    local frame = CreateFrame("Frame", "MPlusLedgerDungeonColorsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(460, 620)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(430)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    EnableEscHandler(frame, function()
        frame:Hide()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0, 0, 0, 1.00)

    local portraitRing = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    portraitRing:SetSize(50, 50)
    portraitRing:SetPoint("TOPLEFT", 9, -7)
    portraitRing:SetColorTexture(self:GetThemeBorderColor(true, 0.9))
    local portrait = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    portrait:SetSize(44, 44)
    portrait:SetPoint("CENTER", portraitRing, "CENTER", 0, 0)
    portrait:SetTexture("Interface\\Icons\\INV_Misc_Gem_01")
    portrait:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 10, -18)
    title:SetText("Per-Dungeon Colors")

    local close = self:CreatePlainButton(frame, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -18, -18)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", 70, -32)
    help:SetPoint("TOPRIGHT", -18, -32)
    help:SetJustifyH("LEFT")
    help:SetWordWrap(true)
    help:SetText("Tints that dungeon's card border on the main window and its name in Season Overview. Left-click a swatch to pick a color, right-click to reset to default.")

    local listFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", 18, -70)
    listFrame:SetPoint("BOTTOMRIGHT", -18, 18)
    listFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    listFrame:SetBackdropColor(self:GetTableBackgroundColor(0.95))

    local scrollFrame = CreateFrame("ScrollFrame", nil, listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self:GetVerticalScrollRange())
        local target = math.max(0, math.min(maxScroll, (self.targetScroll or self:GetVerticalScroll()) - (delta * 36)))
        self.targetScroll = target
    end)
    scrollFrame:SetScript("OnUpdate", function(self, elapsed)
        local target = self.targetScroll
        if not target then
            return
        end
        local current = self:GetVerticalScroll()
        if math.abs(target - current) < 0.5 then
            self:SetVerticalScroll(target)
            self.targetScroll = nil
            return
        end
        self:SetVerticalScroll(current + (target - current) * math.min(1, elapsed * 12))
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(390, DUNGEON_COLORS_ROW_POOL * DUNGEON_COLORS_ROW_HEIGHT)
    scrollFrame:SetScrollChild(scrollContent)
    frame.scrollContent = scrollContent

    frame.rows = {}
    for index = 1, DUNGEON_COLORS_ROW_POOL do
        local row = CreateFrame("Frame", nil, scrollContent)
        row:SetHeight(DUNGEON_COLORS_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 4, -(index - 1) * DUNGEON_COLORS_ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -4, -(index - 1) * DUNGEON_COLORS_ROW_HEIGHT)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetPoint("RIGHT", -34, 0)
        row.name:SetJustifyH("LEFT")

        row.swatch = self:CreateColorSwatchButton(row, 22, function()
            local c = row.dungeonName and Addon:GetDungeonColor(row.dungeonName)
            return c and c[1], c and c[2], c and c[3]
        end, function(r, g, b)
            if row.dungeonName then
                Addon:SetDungeonColor(row.dungeonName, r, g, b)
                Addon:RefreshAllDisplays()
            end
        end)
        row.swatch:SetPoint("RIGHT", -4, 0)

        row:Hide()
        frame.rows[index] = row
    end

    frame:Hide()
    self.dungeonColorsWindow = frame
end

function Addon:RefreshDungeonColorsWindow()
    local frame = self.dungeonColorsWindow
    if not frame then
        return
    end
    local names = self:GetProgressTabDungeonList(true)
    for index, row in ipairs(frame.rows) do
        local name = names[index]
        if name then
            row.dungeonName = name
            row.name:SetText(name)
            row.swatch:Refresh()
            row:Show()
        else
            row.dungeonName = nil
            row:Hide()
        end
    end
    frame.scrollContent:SetHeight(math.max(1, #names * DUNGEON_COLORS_ROW_HEIGHT))
end

function Addon:ToggleDungeonColorsWindow()
    self:CreateDungeonColorsWindow()
    if self.dungeonColorsWindow:IsShown() then
        self.dungeonColorsWindow:Hide()
    else
        self:RefreshDungeonColorsWindow()
        self.dungeonColorsWindow:Show()
        self.dungeonColorsWindow:Raise()
    end
end

function Addon:OpenSettings()
    -- Opening the Blizzard Settings/Options panel is combat-protected -- Settings.OpenToCategory
    -- (and its older InterfaceOptionsFrame_OpenToCategory equivalent) throws a real, player-visible
    -- "Interface action failed because of an AddOn" / ADDON_ACTION_BLOCKED error if called during
    -- combat, same as any other protected action, regardless of it being a direct right-click or a
    -- slash command. Found live (2026-09-06): the minimap button's right-click reached this during
    -- an active boss pull. Every other window-opener in this addon already guards on IsUiLocked()
    -- (see ToggleWindow) -- this one didn't.
    if self:IsUiLocked() then
        Print("Settings can't be opened during combat -- try again once combat ends.")
        return
    end

    self:CreateSettingsPanel()
    self:RefreshSettingsPanel()

    if Settings and Settings.OpenToCategory and self.settingsCategory then
        local categoryID = self.settingsCategory.ID or (self.settingsCategory.GetID and self.settingsCategory:GetID())
        Settings.OpenToCategory(categoryID or self.settingsCategory)
    elseif InterfaceOptionsFrame_OpenToCategory and self.settingsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
    else
        Print("Open the WoW Options menu and select M+ Ledger.")
    end
    -- Removed 2026-09-12: this used to force SettingsPanel/InterfaceOptionsFrame's own
    -- FrameStrata to FULLSCREEN_DIALOG and FrameLevel to 720 here, to stop this addon's own
    -- FULLSCREEN_DIALOG windows (main Ledger, Debug Editor, Repair, etc.) from covering
    -- Settings when both were open at once. That was the wrong fix -- Blizzard's SettingsPanel
    -- already has its own children (nav sidebar, search box, and every registered category's
    -- canvas, including this addon's own panel) built at fixed levels relative to ITS original
    -- strata/level. Changing the parent's strata/level after those children already exist
    -- doesn't cascade to them, so the parent's own background started drawing in a HIGHER tier
    -- than its own children -- hiding literally every control on every settings page behind
    -- Settings' own chrome. User reported this exactly: "even normal settings are behind the
    -- settings menu. i cannot select any settings." Settings already reliably renders above
    -- normal game UI on its own; the rare case of this addon's own big windows covering it is
    -- a much smaller problem than breaking Settings outright every time it opens.
end

function Addon:GetRunsForDungeon(name, limit)
    limit = limit or 10
    local runs = {}
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and self:IsMPlusLedgerRun(run) and run.instanceName == name then
            table.insert(runs, run)
            if #runs >= limit then
                break
            end
        end
    end
    return runs
end

function Addon:GetMemberDeathCount(run, member)
    if not run or not member then
        return 0
    end
    self:EnsureMemberDeathTables(run)
    local deathInfo = member.guid and run.memberDeaths and run.memberDeaths[member.guid]
    local guidCount = deathInfo and deathInfo.count or 0
    -- Must match RecordMemberDeathByDisplayName's fallbackKey construction exactly (realm-
    -- qualified via GetPlayerProfileKey, not the bare NormalizePlayerName it used to be).
    local nameKey = "name:" .. (GetPlayerProfileKey(member.name) or NormalizePlayerName(member.name))
    local nameInfo = run.memberDeaths and run.memberDeaths[nameKey]
    local nameCount = nameInfo and nameInfo.count or 0
    return math.max(guidCount, nameCount)
end

-- +/- on the Party panel's Deaths column (user request 2026-10-08: "it should have a + and - to
-- increase or decrease the deaths"). Keeps every death store in step -- memberDeaths (GUID and
-- name keys, since GetMemberDeathCount takes the max of both), memberDeathLog (charts/Trends read
-- it), run.deaths and run.playerDeaths -- the same set AddDebugPlayerDeaths and
-- RemoveDataToolPlayerRunAppearance keep consistent.
function Addon:AdjustMemberDeathCount(run, member, delta)
    if not run or not member or (delta ~= 1 and delta ~= -1) then
        return
    end
    self:EnsureMemberDeathTables(run)
    local current = self:GetMemberDeathCount(run, member)
    if delta < 0 and current <= 0 then
        return
    end
    local guid = member.guid and not IsSecret(member.guid) and member.guid or nil
    local profileKey = GetPlayerProfileKey(member.name)
    local nameKey = "name:" .. (profileKey or NormalizePlayerName(member.name))
    local isPlayer = guid and guid == self:GetPlayerGUIDForRun(run)

    if delta > 0 then
        local key = guid or nameKey
        local now = time()
        self:AddMemberDeathLogEntry(run, key, guid or key, member.name, "manual edit", now, nil, nil, current + 1)
        run.memberDeaths[key] = run.memberDeaths[key] or { name = member.name, count = 0 }
        run.memberDeaths[key].count = current + 1
        run.lastDeathAt = now
        run.lastDeathAtText = date("%Y-%m-%d %H:%M:%S", now)
    else
        for _, key in ipairs({ guid or false, nameKey }) do
            local info = key and run.memberDeaths[key]
            if info and (tonumber(info.count) or 0) >= current then
                info.count = current - 1
            end
        end
        for i = #run.memberDeathLog, 1, -1 do
            local entry = run.memberDeathLog[i]
            if entry and (entry.key == nameKey or (guid and (entry.key == guid or entry.guid == guid))
                or (entry.name and GetPlayerProfileKey(entry.name) == profileKey)) then
                table.remove(run.memberDeathLog, i)
                break
            end
        end
    end

    run.deaths = math.max(0, (tonumber(run.deaths) or 0) + delta)
    -- playerDeaths left nil means GetPlayerDeaths reads memberDeaths instead, already adjusted.
    if isPlayer and run.playerDeaths then
        run.playerDeaths = math.max(0, (tonumber(run.playerDeaths) or 0) + delta)
    end
    self:RefreshAllDisplays()
end

function Addon:GetRunMemberSummary(run)
    return self:FormatMemberSummaryColored(run)
end

function Addon:GetRunMemberCount(run)
    if run and run.members and #run.members > 0 then
        return #run.members
    end

    return 0
end

function Addon:HideStaleRowElements()
    if not self.window or not self.window.rows then
        return
    end
    for _, row in ipairs(self.window.rows) do
        if row.roleHeaders then
            row.roleHeaders.dps:Hide()
            row.roleHeaders.tank:Hide()
            row.roleHeaders.heals:Hide()
            row.roleColumns.dps:Hide()
            row.roleColumns.tank:Hide()
            row.roleColumns.heals:Hide()
        end
    end
end

function Addon:SelectDungeon(name)
    self.selectedDungeonName = name
    if self.window then
        self.window.listOffset = 0
    end
    self:HideStaleRowElements()
    self:RefreshWindow()
end

function Addon:ClearSelectedDungeon()
    self.selectedDungeonName = nil
    if self.window then
        self.window.listOffset = 0
    end
    self:HideStaleRowElements()
    self:RefreshWindow()
end

function Addon:GetVisibleRowCount()
    return self.selectedDungeonName and MainLayoutConst.DETAIL_VISIBLE_ROWS or MainLayoutConst.MAIN_VISIBLE_ROWS
end

function Addon:SetListOffset(offset, total)
    if not self.window then
        return
    end

    local visible = self:GetVisibleRowCount()
    local maximum = math.max(0, (tonumber(total) or 0) - visible)
    if not self.selectedDungeonName then
        maximum = math.ceil(maximum / MainLayoutConst.MAIN_GRID_COLUMNS) * MainLayoutConst.MAIN_GRID_COLUMNS
    end
    offset = math.max(0, math.min(maximum, tonumber(offset) or 0))
    if not self.selectedDungeonName then
        offset = math.floor(offset / MainLayoutConst.MAIN_GRID_COLUMNS) * MainLayoutConst.MAIN_GRID_COLUMNS
    end
    self.window.listOffset = offset
end

function Addon:ScrollList(delta)
    if not self.window then
        return
    end

    local total = self.window.currentListTotal or 0
    local step = self.selectedDungeonName and 1 or MainLayoutConst.MAIN_GRID_COLUMNS
    self:SetListOffset((self.window.listOffset or 0) + ((tonumber(delta) or 0) * step), total)
    self.scrollFadeActive = true
    self:RefreshWindow()
end

function Addon:UpdateScrollButtons(total)
    if not self.window or not self.window.scrollUpButton or not self.window.scrollDownButton then
        return
    end

    self.window.currentListTotal = total or 0
    local visible = self:GetVisibleRowCount()
    local offset = self.window.listOffset or 0
    local hasScroll = (total or 0) > visible

    if hasScroll then
        self.window.scrollUpButton:Show()
        self.window.scrollDownButton:Show()
        self.window.scrollUpButton:SetAlpha(offset > 0 and 1 or 0.45)
        self.window.scrollDownButton:SetAlpha(offset + visible < (total or 0) and 1 or 0.45)
    else
        self.window.scrollUpButton:Hide()
        self.window.scrollDownButton:Hide()
    end
end

function Addon:GetDebugSelectedRun()
    local run = self:GetRun(self.debugSelectedRunID)
    if run then
        return run
    end

    run = self.selectedRunForShare or self:GetCurrentRun() or self:GetLastRun()
    if run then
        self.debugSelectedRunID = run.id
    end
    return run
end

function Addon:SelectDebugRun(run)
    if not run then
        return
    end

    if self.debugSelectedRunID ~= run.id then
        self.debugSelectedPlayerName = nil
        self.debugSelectedBossID = nil
    end
    self.debugSelectedRunID = run.id
    self.selectedRunForShare = run
    self:RefreshWindow()
end

function Addon:StepDebugRun(delta)
    if not self.db or not self.db.runOrder or #self.db.runOrder == 0 then
        Print("No saved runs yet.")
        return
    end

    local selected = self:GetDebugSelectedRun()
    local selectedID = selected and selected.id
    local selectedIndex = 1
    for index, runID in ipairs(self.db.runOrder) do
        if runID == selectedID then
            selectedIndex = index
            break
        end
    end

    local nextIndex = selectedIndex + (tonumber(delta) or 0)
    if nextIndex < 1 then
        nextIndex = #self.db.runOrder
    elseif nextIndex > #self.db.runOrder then
        nextIndex = 1
    end

    self:SelectDebugRun(self:GetRun(self.db.runOrder[nextIndex]))
end

function Addon:SetRunStatusDebug(status)
    local run = self:GetDebugSelectedRun()
    if not run then
        Print("No run selected.")
        return
    end

    if status == "Completed" or status == "CompletedOvertime" then
        self:MarkRunCompleted(run, status == "CompletedOvertime" and "debug menu overtime" or "debug menu")
        if status == "CompletedOvertime" then
            run.runStatus = "CompletedOvertime"
            run.completedOvertime = true
            run.overtime = true
            Print("Marked " .. tostring(run.instanceName or "run") .. " completed / overtime.")
            self:RefreshAllDisplays()
        else
            run.completedOvertime = nil
            run.overtime = nil
        end
    elseif status == "Abandoned" then
        run.runStatus = "Abandoned"
        run.completedOvertime = nil
        run.overtime = nil
        run.completionReason = "debug menu"
        run.leftWithoutCompletion = true
        run.abandonedAt = time()
        run.abandonedReason = "debug menu"
        run.completedAt = nil
        run.completedAtText = nil
        if not run.endedAt then
            run.endedAt = time()
            run.endedAtText = date("%Y-%m-%d %H:%M:%S")
            run.duration = run.endedAt - (run.startedAt or run.endedAt)
        end
        if self.db.currentRunID == run.id then
            self.db.currentRunID = nil
        end
        self.db.lastRunID = run.id
        Print("Marked " .. tostring(run.instanceName or "run") .. " " .. string.lower(self:GetRunDisplayStatus(run)) .. ".")
        self:RefreshAllDisplays()
    elseif status == "Active" then
        run.runStatus = "Active"
        run.completedOvertime = nil
        run.overtime = nil
        run.completionReason = nil
        run.leftWithoutCompletion = false
        run.abandonedReason = nil
        run.completedAt = nil
        run.completedAtText = nil
        run.endedAt = nil
        run.endedAtText = nil
        run.duration = 0
        run.durationOverride = nil
        run.timerStartedAt = nil
        run.timerStartedAtText = nil
        self.db.currentRunID = run.id
        self.db.lastRunID = run.id
        Print("Marked " .. tostring(run.instanceName or "run") .. " active.")
        self:RefreshAllDisplays()
    end
end

function Addon:SetRunDifficultyDebug(bucket, skipRefresh)
    local run = self:GetDebugSelectedRun()
    if not run then
        Print("No run selected.")
        return
    end

    local editor = self.debugEditor
    local dataTools = self.dataTools
    local enteredLevel
    if dataTools and dataTools:IsShown() and dataTools.keyLevelBox then
        enteredLevel = tonumber(dataTools.keyLevelBox:GetText() or "")
    end
    if not enteredLevel and editor and editor.difficultyLevelBox then
        enteredLevel = tonumber(editor.difficultyLevelBox:GetText() or "")
    end
    local mythicPlusLevel = math.max(enteredLevel or tonumber(run.keyLevel) or tonumber(run.challengeLevel) or tonumber(run.completionLevel) or 2, 1)
    local configs = {
        normal = { name = "Normal", id = 1 },
        heroic = { name = "Heroic", id = 2 },
        mythic = { name = "Mythic", id = 23 },
        mythicPlus = { name = "Mythic+", id = 8, challengeLevel = mythicPlusLevel },
        timewalking = { name = "Timewalking", id = 24 },
        follower = { name = "Follower Dungeon", id = 205 },
        lfr = { name = "Looking for Raid", id = 17 },
    }
    local config = configs[bucket]
    if not config then
        Print("Unknown difficulty.")
        return
    end

    run.difficultyName = config.name
    run.difficultyID = config.id
    run.manualDifficulty = true
    if bucket == "mythicPlus" then
        run.challengeLevel = config.challengeLevel
        run.keyLevel = config.challengeLevel
        run.completionLevel = config.challengeLevel
    else
        run.challengeLevel = nil
        run.keyLevel = nil
        run.completionLevel = nil
    end

    if not skipRefresh then
        Print("Marked " .. tostring(run.instanceName or "run") .. " as " .. config.name .. ".")
        self:RefreshAllDisplays()
    end
end

function Addon:AddDebugRepairCost()
    local run = self:GetDebugSelectedRun()
    if not run then
        Print("No run selected.")
        return
    end

    local editor = self.debugEditor
    local cost = 0
    if editor and editor.repairGoldBox and editor.repairSilverBox and editor.repairCopperBox then
        local gold = tonumber(editor.repairGoldBox:GetText() or "") or 0
        local silver = tonumber(editor.repairSilverBox:GetText() or "") or 0
        local copper = tonumber(editor.repairCopperBox:GetText() or "") or 0
        cost = (math.max(0, math.floor(gold)) * 10000) + (math.max(0, math.floor(silver)) * 100) + math.max(0, math.floor(copper))
    else
        local editBox = (editor and editor.repairBox) or (self.window and self.window.debugRepairEditBox)
        cost = ParseMoneyAmount(editBox and editBox:GetText() or "")
    end
    if cost <= 0 then
        Print("Enter a repair amount in gold, silver, or copper.")
        return
    end

    self:RecordRepairCost(cost, "debug menu", run)
    if editor and editor.repairGoldBox then
        editor.repairGoldBox:SetText("")
        editor.repairSilverBox:SetText("")
        editor.repairCopperBox:SetText("")
    elseif self.window and self.window.debugRepairEditBox then
        self.window.debugRepairEditBox:SetText("")
    end
end

function Addon:AddDebugPlayerDeaths()
    local run = self:GetDebugSelectedRun()
    if not run then
        Print("No run selected.")
        return
    end

    local playerBox = (self.debugEditor and self.debugEditor.playerBox) or (self.window and self.window.debugPlayerEditBox)
    local countBox = (self.debugEditor and self.debugEditor.deathCountBox) or (self.window and self.window.debugDeathCountEditBox)
    local playerText = self.debugSelectedPlayerName or (playerBox and playerBox:GetText()) or ""
    local count = tonumber(countBox and countBox:GetText() or "") or 1
    count = math.max(1, math.floor(count))

    local member = self:GetMemberByName(run, playerText)
    local guid = member and member.guid
    local displayName = member and member.name or StripWowText(playerText)
    if displayName == "" then
        displayName = GetUnitFullName("player") or "Unknown"
        guid = SafeUnitGUID("player")
    end

    self:EnsureMemberDeathTables(run)
    -- Must match RecordMemberDeathByDisplayName's fallbackKey / GetMemberDeathCount's nameKey.
    local key = guid or ("name:" .. (GetPlayerProfileKey(displayName) or NormalizePlayerName(displayName)))
    local addedCount = 0
    local now = time()
    local startingDeathCount = run.memberDeaths[key] and tonumber(run.memberDeaths[key].count) or 0
    for _ = 1, count do
        if self:AddMemberDeathLogEntry(run, key, guid or key, displayName, "debug menu", now, nil, nil, startingDeathCount + addedCount + 1) then
            addedCount = addedCount + 1
        end
    end
    if addedCount <= 0 then
        Print("No new deaths were added.")
        return
    end

    run.memberDeaths[key] = run.memberDeaths[key] or {
        name = displayName,
        count = 0,
    }
    run.memberDeaths[key].name = displayName
    run.memberDeaths[key].count = (run.memberDeaths[key].count or 0) + addedCount
    run.deaths = (tonumber(run.deaths) or 0) + addedCount
    if guid and guid == self:GetPlayerGUIDForRun(run) then
        run.playerDeaths = (tonumber(run.playerDeaths) or 0) + addedCount
    end

    run.lastDeathAt = now
    run.lastDeathAtText = date("%Y-%m-%d %H:%M:%S", now)
    Print(string.format("Added %d death(s) to %s.", addedCount, GetShortName(displayName)))
    if countBox then
        countBox:SetText("1")
    end
    self:RefreshAllDisplays()
end

function Addon:GetDebugTimeSeconds(prefix)
    local editor = self.debugEditor
    if not editor then
        return 0
    end

    local minutesBox = editor[prefix .. "MinutesBox"]
    local secondsBox = editor[prefix .. "SecondsBox"]
    local minutes = tonumber(minutesBox and minutesBox:GetText() or "") or 0
    local seconds = tonumber(secondsBox and secondsBox:GetText() or "") or 0
    return (math.max(0, math.floor(minutes)) * 60) + math.max(0, math.floor(seconds))
end

function Addon:SetDebugRunTime()
    local run = self:GetDebugSelectedRun()
    if not run then
        Print("No run selected.")
        return
    end

    local seconds = self:GetDebugTimeSeconds("runTime")
    if seconds <= 0 then
        Print("Enter a run time in minutes and seconds.")
        return
    end

    if self:GetRunStatus(run) == "Active" then
        run.timerStartedAt = time() - seconds
        run.timerStartedAtText = date("%Y-%m-%d %H:%M:%S", run.timerStartedAt)
        run.durationOverride = nil
    else
        run.durationOverride = seconds
    end
    run.duration = seconds
    Print("Set run time to " .. FormatDuration(seconds) .. ".")
    self:RefreshAllDisplays()
end

function Addon:SetRunTimeOverride(runOrCode, minutes, seconds)
    local run = type(runOrCode) == "table" and runOrCode or self:FindRunByCode(runOrCode)
    if not run then
        run = self:GetEditableRun()
    end
    if not run then
        return false
    end

    local totalSeconds = (math.max(0, math.floor(tonumber(minutes) or 0)) * 60) + math.max(0, math.floor(tonumber(seconds) or 0))
    if totalSeconds <= 0 then
        Print("Enter a run time in minutes and seconds.")
        return false
    end

    run.durationOverride = totalSeconds
    run.duration = totalSeconds
    Print(string.format("Set %s run time to %s.", self:GetRunCode(run) or tostring(run.id or "?"), FormatDuration(totalSeconds)))
    self:RefreshAllDisplays()
    return true
end

function Addon:SetDebugBossKillTime()
    local run = self:GetDebugSelectedRun()
    if not run then
        Print("No run selected.")
        return
    end

    local bossID = self.debugSelectedBossID
    if not bossID then
        Print("Select a boss first.")
        return
    end

    local seconds = self:GetDebugTimeSeconds("bossTime")
    if seconds <= 0 then
        Print("Enter a boss kill time in minutes and seconds.")
        return
    end

    run.bossKills = run.bossKills or {}
    local boss = run.bossKills[bossID] or {
        bossID = bossID,
        encounterID = bossID,
        encounterKey = bossID,
        name = self:GetBossName(run, bossID),
        count = run.killedBosses and run.killedBosses[bossID] and 1 or 0,
    }
    boss.lastKillTime = seconds
    boss.manualKillTime = true
    run.bossKills[bossID] = boss
    for _, encounter in ipairs(run.encounters or {}) do
        if tonumber(encounter.encounterKey) == tonumber(bossID) or tonumber(encounter.encounterID) == tonumber(bossID) then
            encounter.killTime = seconds
            encounter.manualKillTime = true
        end
    end
    for _, entry in ipairs(run.bossKillLog or {}) do
        if tonumber(entry.bossID) == tonumber(bossID) or tonumber(entry.encounterKey) == tonumber(bossID) or tonumber(entry.encounterID) == tonumber(bossID) then
            entry.killTime = seconds
            entry.manualKillTime = true
        end
    end
    Print("Set boss kill time to " .. FormatDuration(seconds) .. ".")
    self:RefreshAllDisplays()
end

function Addon:SetDebugMobKillTime()
    local run = self:GetDebugSelectedRun()
    if not run then
        Print("No run selected.")
        return
    end

    local seconds = self:GetDebugTimeSeconds("mobTime")
    if seconds <= 0 then
        Print("Enter a mob kill time in minutes and seconds.")
        return
    end

    run.mobKillTimeOverride = seconds
    local latest = run.mobKillLog and run.mobKillLog[#run.mobKillLog]
    if latest then
        latest.killTime = seconds
        latest.manualKillTime = true
        if latest.npcID and run.mobKills and run.mobKills[latest.npcID] then
            run.mobKills[latest.npcID].lastKillTime = seconds
            run.mobKills[latest.npcID].manualKillTime = true
        end
    end
    Print("Set latest mob kill time to " .. FormatDuration(seconds) .. ".")
    self:RefreshAllDisplays()
end

function Addon:SetDebugTimeBoxes(prefix, seconds)
    local editor = self.debugEditor
    if not editor then
        return
    end

    seconds = math.max(0, tonumber(seconds) or 0)
    local minutesBox = editor[prefix .. "MinutesBox"]
    local secondsBox = editor[prefix .. "SecondsBox"]
    if minutesBox then
        minutesBox:SetText(tostring(math.floor(seconds / 60)))
    end
    if secondsBox then
        secondsBox:SetText(tostring(seconds % 60))
    end
end

function Addon:GetDebugBossKillTime(run, bossID)
    local boss = run and run.bossKills and bossID and run.bossKills[bossID]
    return tonumber(boss and boss.lastKillTime) or 0
end

function Addon:GetDebugMobKillTime(run)
    if not run then
        return 0
    end

    local latest = run.mobKillLog and run.mobKillLog[#run.mobKillLog]
    return tonumber(run.mobKillTimeOverride) or tonumber(latest and latest.killTime) or 0
end

function Addon:SetDebugBossKilled(killed)
    local run = self:GetDebugSelectedRun()
    if not run then
        Print("No run selected.")
        return
    end

    local bossBox = (self.debugEditor and self.debugEditor.bossBox) or (self.window and self.window.debugBossEditBox)
    local bossToken = self.debugSelectedBossID or (bossBox and bossBox:GetText()) or ""
    if strtrim(tostring(bossToken or "")) == "" then
        Print("Enter a boss name or boss ID.")
        return
    end

    self:SetBossKilled(bossToken, killed, self:GetRunCode(run))
end

function Addon:GetDebugRunDetails(run)
    if not run then
        return "Select a run to edit."
    end

    local repairText = FormatMoneyIcons(run.repairCost or 0)
    local bossText = self:FormatBossProgress(run)
    local rosterText = self:GetRunMemberSummary(run)

    return string.format("Repairs: %s | Bosses: %s\nPlayers:\n%s", repairText, bossText, rosterText)
end

function Addon:GetDebugPlayerOptions(run)
    local options = {}
    for _, member in ipairs(run and run.members or {}) do
        if member.name and member.name ~= "" then
            local classColor = CLASS_COLORS[member.class or ""] or "|cffffffff"
            local backdrop = CLASS_BACKDROP_COLORS[member.class or ""]
            table.insert(options, {
                text = string.format("%s%s (%d)|r", classColor, GetShortName(member.name), self:GetMemberDeathCount(run, member)),
                value = member.name,
                backdrop = backdrop,
            })
        end
    end

    if #options == 0 and run and run.playerName then
        table.insert(options, {
            text = GetShortName(run.playerName),
            value = run.playerName,
        })
    end

    return options
end

function Addon:GetDebugDifficultyOptions()
    local options = {}
    for _, key in ipairs(DIFFICULTY_BUCKET_ORDER) do
        local config = DIFFICULTY_BUCKETS[key]
        table.insert(options, {
            text = config.color .. config.label .. "|r",
            value = key,
            backdrop = config.backdrop,
        })
    end
    return options
end

function Addon:GetDebugStatusOptions()
    return {
        { text = "|cff00ff00Completed|r", value = "Completed", backdrop = STATUS_BACKDROP_COLORS.Completed },
        { text = "|cff99cc33Completed / Overtime|r", value = "CompletedOvertime", backdrop = STATUS_BACKDROP_COLORS.CompletedOvertime },
        { text = "|cffff5555Failed / Abandoned|r", value = "Abandoned", backdrop = STATUS_BACKDROP_COLORS.Abandoned },
        { text = "|cff66aaffActive|r", value = "Active", backdrop = STATUS_BACKDROP_COLORS.Active },
    }
end

function Addon:GetRunOptionText(run)
    if not run then
        return "Unknown run"
    end
    return string.format(
        "%s | %s | %s | %s",
        self:GetRunExpansionText(run),
        run.instanceName or "Unknown run",
        self:GetRunDisplayStatus(run),
        self:GetRunCode(run) or tostring(run.id or "?")
    )
end

function Addon:RunMatchesCurrentSeason(run)
    if not run then
        return false
    end
    local currentName = self:GetCurrentSeasonName()
    local namedSeason = self:GetCurrentNamedSeasonName()
    local runSeason = self:GetRunMythicPlusSeasonText(run)
    if runSeason == currentName or (namedSeason and runSeason == namedSeason) then
        return true
    end
    local currentSeasonNumber = GetSeasonNumberFromText(currentName) or GetSeasonNumberFromText(namedSeason)
    if currentSeasonNumber and IsGenericSeasonName(runSeason) and GetSeasonNumberFromText(runSeason) == currentSeasonNumber then
        return true
    end
    local linked = self:GetActiveSeasonLinkSet()
    return linked and linked[run.instanceName or ""] and true or false
end

function Addon:GetFilteredDataToolRunOptions(prefix)
    local options = {}
    local seasonOnly = self[prefix .. "SeasonOnly"]
    local expansionName = self[prefix .. "ExpansionName"]
    local instanceName = self[prefix .. "InstanceName"]
    for _, runID in ipairs(self.db and self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run
            and (not seasonOnly or self:RunMatchesCurrentSeason(run))
            and (not expansionName or expansionName == "" or self:GetRunExpansionText(run) == expansionName)
            and (not instanceName or instanceName == "" or run.instanceName == instanceName) then
            table.insert(options, {
                text = self:GetRunOptionText(run),
                value = run.id,
            })
        end
    end
    return options
end

function Addon:SelectFirstFilteredRun(prefix, selectedField)
    local options = self:GetFilteredDataToolRunOptions(prefix)
    local selectedID = self[selectedField]

    -- A real, still-existing run stays selected even if the CURRENT filter (season/expansion/
    -- instance) would otherwise exclude it from the dropdown -- fixed 2026-09-30 per user report/
    -- screenshot ("click Edit on a run, it opens a different run instead"): this used to require
    -- the selection to appear in the FILTERED options list specifically, so explicitly opening a
    -- non-current-season run's Edit button (e.g. a Timewalking Blackrock Depths run, with "Show
    -- Current Mythic+ Season" checked) got silently overwritten with options[1] -- whichever
    -- current-season run happened to be first -- right after OpenDataToolsMenu had JUST set the
    -- correct selectedID moments earlier, discarding the click before the user ever saw it. Only
    -- fall back to options[1] when the selection is genuinely gone (nil or a deleted run), not
    -- merely filtered out.
    if selectedID and self:GetRun(selectedID) then
        return options
    end

    local selectedMatches = false
    for _, option in ipairs(options) do
        if tostring(option.value or "") == tostring(selectedID or "") then
            selectedMatches = true
            break
        end
    end
    if not selectedMatches then
        self[selectedField] = options[1] and options[1].value or nil
        if selectedField == "dataToolSelectedRunID" then
            self.debugSelectedRunID = self[selectedField]
        end
    end
    return options
end

function Addon:GetDataToolRunOptions()
    return self:GetFilteredDataToolRunOptions("dataToolRunFilter")
end

function Addon:GetRepairRunOptions()
    return self:GetFilteredDataToolRunOptions("repairRunFilter")
end

function Addon:GetExpansionFilterOptions()
    local options = { { text = "All Expansions", value = "" } }
    for _, option in ipairs(self:GetDataToolExpansionOptions()) do
        table.insert(options, option)
    end
    return options
end

function Addon:GetInstanceFilterOptions(expansionName)
    local options = { { text = "All Instances", value = "" } }
    local source = expansionName and expansionName ~= "" and self:GetDataToolInstancesForExpansion(expansionName) or self:GetDataToolInstanceOptions()
    for _, option in ipairs(source) do
        table.insert(options, option)
    end
    return options
end

function Addon:GetDataToolInstanceOptions()
    local seen = {}
    local options = {}
    for _, runID in ipairs(self.db and self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        local name = run and run.instanceName
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(options, { text = name, value = name })
        end
    end
    for name in pairs(self.db and self.db.dungeonMetadata or {}) do
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(options, { text = name, value = name })
        end
    end
    table.sort(options, function(a, b)
        return tostring(a.text or "") < tostring(b.text or "")
    end)
    return options
end

-- Name-suggestion sources for the free-text EditBox fields in Data Tools -- per user request
-- 2026-09-05 ("context search in all fields where you need to enter a name or id"). Each just
-- returns a flat, sorted list of known names; the actual type-ahead filtering/menu lives in the
-- autocompleteBox() helper inside BuildDataToolsEditor, which calls these.
-- Shared with the Update Player window (new 2026-09-06) -- was previously a local function scoped
-- only inside the Player Menu's own rendering closure; hoisted to a real method so a separate
-- top-level window can use the exact same "what class/role did we last actually see them as"
-- lookup for pre-filling its fields.
function Addon:FindMostRecentMember(name)
    if not name or name == "" then
        return nil
    end
    for _, runID in ipairs(self.db.runOrder or {}) do
        local candidateRun = self.db.runs and self.db.runs[runID]
        for _, candidate in ipairs(candidateRun and candidateRun.members or {}) do
            if candidate.name and NormalizePlayerName(candidate.name) == NormalizePlayerName(name) then
                return candidate
            end
        end
    end
    return nil
end

function Addon:GetKnownPlayerNames()
    local names, seen = {}, {}
    for _, savedProfile in pairs(self.db.playerRatings or {}) do
        local name = savedProfile.name
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    return names
end

function Addon:GetKnownInstanceNames()
    local names = {}
    for _, option in ipairs(self:GetDataToolInstanceOptions()) do
        table.insert(names, option.text)
    end
    return names
end

function Addon:GetKnownExpansionNames()
    local names = {}
    for _, option in ipairs(self:GetDataToolExpansionOptions()) do
        if option.value ~= "" then
            table.insert(names, option.text)
        end
    end
    return names
end

function Addon:GetKnownBossNames()
    local names, seen = {}, {}
    for _, info in pairs(self.db.bossCatalog or {}) do
        local name = info and info.name
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    for _, dungeonData in pairs(DUNGEON_BOSSES) do
        for name in pairs(dungeonData.names or {}) do
            if name and name ~= "" and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    return names
end

function Addon:GetKnownMobNames()
    local names, seen = {}, {}
    for key, info in pairs(self.db.npcCatalog or {}) do
        local name = (self.db.mobNameOverrides and self.db.mobNameOverrides[tostring(key)]) or (info and info.name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    return names
end

-- No confirmed-working C_Delves enumeration exists yet (see BuildExpansionCatalog's own Delve
-- note), so there's no catalog to suggest from -- this just offers back whatever Delve names this
-- addon has already recorded from real runs, growing organically rather than guessing at names.
function Addon:GetKnownDelveNames()
    local names, seen = {}, {}
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and run.expansionName == "Delve" and run.instanceName and run.instanceName ~= "" and not seen[run.instanceName] then
            seen[run.instanceName] = true
            table.insert(names, run.instanceName)
        end
    end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    return names
end

-- No addon-accessible API lists every realm in the game (that's a server-side list, hundreds of
-- realms across every region -- not something a client addon can enumerate) -- per user request
-- 2026-09-?? ("make this a dropdown box and have all the realms listed"). This offers the
-- player's own current realm (always first, almost always correct for who you're adding) plus
-- every realm this addon has actually seen -- from saved player profiles and every run roster ever
-- recorded -- which in practice covers every realm the people you actually group with are on. The
-- Realm control stays an editable field underneath the dropdown (see CreateAddPlayerWindow/
-- CreateUpdatePlayerWindow), so a genuinely new realm not in this list yet can still be typed.
function Addon:GetKnownRealmNames()
    local names, seen = {}, {}
    local myRealm = GetRealmName and GetRealmName()
    if myRealm and myRealm ~= "" then
        seen[myRealm] = true
        table.insert(names, myRealm)
    end
    for _, profile in pairs(self.db.playerRatings or {}) do
        local realm = profile.realm
        if realm and realm ~= "" and not seen[realm] then
            seen[realm] = true
            table.insert(names, realm)
        end
    end
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        for _, member in ipairs(run and run.members or {}) do
            local realm = member.realm
            if realm and realm ~= "" and not seen[realm] then
                seen[realm] = true
                table.insert(names, realm)
            end
        end
    end
    -- Leaves the player's own realm first (most likely pick), sorts everything else alphabetically
    -- after it rather than sorting the whole list and losing that priority.
    if #names > 1 then
        local rest = {}
        for i = 2, #names do
            table.insert(rest, names[i])
        end
        table.sort(rest, function(a, b) return string.lower(a) < string.lower(b) end)
        for i, name in ipairs(rest) do
            names[i + 1] = name
        end
    end
    return names
end

function Addon:GetDataToolExpansionOptions()
    local seen = {}
    local options = {}
    local defaults = {
        "Midnight",
        "The War Within",
        "Dragonflight",
        "Shadowlands",
        "Battle for Azeroth",
        "Legion",
        "Warlords of Draenor",
        "Mists of Pandaria",
        "Cataclysm",
        "Wrath of the Lich King",
        "The Burning Crusade",
        "Classic",
    }
    local function add(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(options, { text = name, value = name })
        end
    end
    for _, name in ipairs(defaults) do
        add(name)
    end
    for _, metadata in pairs(self.db and self.db.dungeonMetadata or {}) do
        add(metadata and metadata.expansionName)
    end
    for _, catalog in pairs(self.db and self.db.instanceCatalog or {}) do
        add(catalog and catalog.expansionName)
    end
    for _, runID in ipairs(self.db and self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        add(run and run.expansionName)
    end
    return options
end

function Addon:GetDataToolSeasonOptions()
    local seen = {}
    local options = {}
    local defaults = {
        "Current WoW Season",
        "Midnight Season 1",
        "Midnight Season 2",
        "Midnight Season 3",
        "The War Within Season 1",
        "The War Within Season 2",
        "The War Within Season 3",
        "The War Within Season 4",
    }
    local function add(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(options, { text = name, value = name })
        end
    end
    for _, name in ipairs(defaults) do
        add(name)
    end
    for seasonName in pairs(self.db and self.db.seasonLinks or {}) do
        add(seasonName)
    end
    for _, runID in ipairs(self.db and self.db.runOrder or {}) do
        add(self:GetRunMythicPlusSeasonText(self:GetRun(runID)))
    end
    return options
end

function Addon:LinkInstanceToSeason(instanceName, seasonName)
    if not instanceName or instanceName == "" or not seasonName or seasonName == "" then
        Print("Select an instance and season first.")
        return
    end
    self.db.seasonLinks = self.db.seasonLinks or {}
    self.db.seasonLinks[seasonName] = self.db.seasonLinks[seasonName] or {}
    self.db.seasonLinks[seasonName][instanceName] = true
    self.db.instanceCatalog = self.db.instanceCatalog or {}
    self.db.instanceCatalog[instanceName] = self.db.instanceCatalog[instanceName] or { name = instanceName }
    self.db.instanceCatalog[instanceName].seasonLinks = self.db.instanceCatalog[instanceName].seasonLinks or {}
    self.db.instanceCatalog[instanceName].seasonLinks[seasonName] = true
    Print("Linked " .. instanceName .. " to " .. seasonName .. ".")
end

function Addon:LinkInstanceToExpansion(instanceName, expansionName)
    if not instanceName or instanceName == "" or not expansionName or expansionName == "" then
        Print("Select an instance and expansion first.")
        return
    end
    self.db.instanceCatalog = self.db.instanceCatalog or {}
    self.db.dungeonMetadata = self.db.dungeonMetadata or {}
    self.db.instanceCatalog[instanceName] = self.db.instanceCatalog[instanceName] or { name = instanceName }
    self.db.instanceCatalog[instanceName].expansionName = expansionName
    self.db.instanceCatalog[instanceName].name = instanceName
    self.db.instanceCatalog[instanceName].lastLinkedAt = time()
    self.db.instanceCatalog[instanceName].lastLinkedAtText = date("%Y-%m-%d %H:%M:%S")
    self.db.dungeonMetadata[instanceName] = self.db.dungeonMetadata[instanceName] or {}
    self.db.dungeonMetadata[instanceName].expansionName = expansionName
    -- Explicit user action -- outranks everything else GetRunExpansionText tries, including a real
    -- Encounter Journal tier lookup, since the user might deliberately be overriding it. Added
    -- 2026-09-30 alongside the expansion-mislabeling fix below (see GetRunExpansionText).
    self.db.dungeonMetadata[instanceName].expansionManual = true
    Print("Linked " .. instanceName .. " to " .. expansionName .. ".")
end

function Addon:GetCurrentSeasonName()
    local patchInfo = GetClientPatchInfo()
    return GetEstimatedMythicPlusSeason(patchInfo.version)
end

function Addon:GetCurrentNamedSeasonName()
    local patchInfo = GetClientPatchInfo()
    return GetNamedMythicPlusSeason(patchInfo.version)
end

function Addon:GetActiveSeasonLinkSet()
    if not (self.db and self.db.seasonLinks) then
        return nil
    end
    local currentName = self:GetCurrentSeasonName()
    local namedSeason = self:GetCurrentNamedSeasonName()
    local currentSeasonNumber = GetSeasonNumberFromText(currentName) or GetSeasonNumberFromText(namedSeason)
    local merged = {}
    local found = false
    local function merge(name)
        local links = name and self.db.seasonLinks[name]
        if links then
            found = true
            for instanceName in pairs(links) do
                merged[instanceName] = true
            end
        end
    end
    merge(currentName)
    merge(namedSeason)
    if currentSeasonNumber then
        merge("Season " .. currentSeasonNumber)
        merge("Mythic+ Season " .. currentSeasonNumber)
        merge("M+ Season " .. currentSeasonNumber)
        for seasonName in pairs(self.db.seasonLinks or {}) do
            if IsGenericSeasonName(seasonName) and GetSeasonNumberFromText(seasonName) == currentSeasonNumber then
                merge(seasonName)
            end
        end
    end
    merge("Current WoW Season")
    return found and merged or nil
end

-- REWRITTEN 2026-09-29 per user report ("I still got the raid and other non m+ dungeons showing
-- up" with the main window's default "Current Season" filter on): the old version matched on
-- summary.seasonText, a free-text heuristic (see GetRunMythicPlusSeasonText/GetCurrentSeasonName)
-- that never checked dungeon-vs-raid at all, AND fell back to returning the FULL unfiltered list
-- whenever the text heuristic matched nothing (`#filtered > 0 and filtered or summaries`) -- a
-- raid's seasonText is essentially never going to equal a Mythic+ season name, so that fallback
-- was firing constantly, silently defeating the whole filter and showing every raid/old-season
-- dungeon right alongside current ones. Now reuses GetMythicPlusPoolEntries() -- the same real,
-- non-text-based "current M+ season pool" source Season Overview and the Progress tab already
-- filter against (see GetSeasonOverviewData/GetProgressTabDungeonList) -- as a plain name
-- membership test: a raid or Normal/Heroic/Timewalking dungeon is never IN that pool, so this
-- excludes them by construction, no separate raid check needed.
function Addon:FilterSummariesForActiveSeason(summaries)
    local pool = {}
    for _, entry in ipairs(self:GetMythicPlusPoolEntries()) do
        if entry.name then
            pool[entry.name] = true
        end
    end
    if next(pool) then
        local filtered = {}
        for _, summary in ipairs(summaries or {}) do
            if summary and pool[summary.name] then
                table.insert(filtered, summary)
            end
        end
        return filtered
    end

    -- No cached M+ pool yet (user has never run /dl icons or /dl catalog) -- best-effort fallback
    -- to the old seasonText heuristic rather than an unexplained empty list, but no longer falls
    -- back further to "show everything" if even that matches nothing.
    local linked = self:GetActiveSeasonLinkSet()
    local currentName = self:GetCurrentSeasonName()
    local namedSeason = self:GetCurrentNamedSeasonName()
    local currentSeasonNumber = GetSeasonNumberFromText(currentName) or GetSeasonNumberFromText(namedSeason)
    local filtered = {}
    for _, summary in ipairs(summaries or {}) do
        local summarySeasonNumber = GetSeasonNumberFromText(summary and summary.seasonText)
        if summary and ((linked and linked[summary.name])
            or summary.seasonText == currentName
            or (namedSeason and summary.seasonText == namedSeason)
            or (currentSeasonNumber and IsGenericSeasonName(summary.seasonText) and summarySeasonNumber == currentSeasonNumber)) then
            table.insert(filtered, summary)
        end
    end
    return filtered
end

function Addon:GetExpansionForInstanceName(instanceName)
    local metadata = instanceName and self.db and self.db.dungeonMetadata and self.db.dungeonMetadata[instanceName]
    local catalog = instanceName and self.db and self.db.instanceCatalog and self.db.instanceCatalog[instanceName]
    return (metadata and metadata.expansionName) or (catalog and catalog.expansionName) or "Unknown Expansion"
end

function Addon:GetDataToolInstancesForExpansion(expansionName)
    local options = {}
    local seen = {}
    if not expansionName or expansionName == "" then
        return options
    end
    for _, option in ipairs(self:GetDataToolInstanceOptions()) do
        if option and option.value and self:GetExpansionForInstanceName(option.value) == expansionName and not seen[option.value] then
            seen[option.value] = true
            table.insert(options, option)
        end
    end
    for instanceName, info in pairs(self.db and self.db.instanceCatalog or {}) do
        if info and info.expansionName == expansionName and not seen[instanceName] then
            seen[instanceName] = true
            table.insert(options, { text = instanceName, value = instanceName })
        end
    end
    return options
end

-- kind is "dungeons" or "raids", matching self.db.expansionCatalog[expansionName]'s own keys
-- (built by /dl catalog from the Encounter Journal). Falls back to the unfiltered instance list
-- when the catalog hasn't been built yet, or has nothing of that kind for this expansion, rather
-- than showing an empty picker.
function Addon:GetDataToolInstancesForExpansionKind(expansionName, kind)
    local options = {}
    local seen = {}
    if not expansionName or expansionName == "" then
        return options
    end
    local catalogExpansion = self.db and self.db.expansionCatalog and self.db.expansionCatalog[expansionName]
    local bucket = catalogExpansion and catalogExpansion[kind]
    if bucket then
        for instanceName in pairs(bucket) do
            if not seen[instanceName] then
                seen[instanceName] = true
                table.insert(options, { text = instanceName, value = instanceName })
            end
        end
    end
    if #options == 0 then
        return self:GetDataToolInstancesForExpansion(expansionName)
    end
    table.sort(options, function(a, b) return tostring(a.text or "") < tostring(b.text or "") end)
    return options
end

function Addon:FindJournalInstanceByName(instanceName)
    if not instanceName or instanceName == "" then
        return nil
    end
    local metadata = self.db and self.db.dungeonMetadata and self.db.dungeonMetadata[instanceName]
    if metadata and metadata.journalInstanceID then
        return metadata.journalInstanceID
    end
    self:LoadEncounterJournalForIconDump()
    if not EJ_GetNumTiers or not EJ_SelectTier or not EJ_GetInstanceByIndex then
        return nil
    end
    local wanted = NormalizeDungeonName(instanceName)
    for tierIndex = 1, EJ_GetNumTiers() or 0 do
        pcall(EJ_SelectTier, tierIndex)
        for _, isRaid in ipairs({ false, true }) do
            local instanceIndex = 1
            while true do
                local values = { pcall(EJ_GetInstanceByIndex, instanceIndex, isRaid) }
                if not values[1] or not values[2] then
                    break
                end
                if NormalizeDungeonName(values[3]) == wanted then
                    return values[2]
                end
                instanceIndex = instanceIndex + 1
            end
        end
    end
    return nil
end

function Addon:CatalogCurrentInstance(run)
    run = run or self:GetCurrentRun()
    if not run or not run.instanceName or run.instanceName == "" then
        return nil
    end

    self.db.instanceCatalog = self.db.instanceCatalog or {}
    self.db.dungeonMetadata = self.db.dungeonMetadata or {}
    local catalog = self.db.instanceCatalog[run.instanceName] or {}
    catalog.name = run.instanceName
    catalog.instanceType = run.instanceType
    catalog.mapID = run.mapID or catalog.mapID
    catalog.instanceMapID = run.instanceMapID or catalog.instanceMapID
    catalog.challengeMapID = run.challengeMapID or catalog.challengeMapID
    catalog.expansionName = self:GetRunExpansionText(run) or catalog.expansionName or run.expansionName
    catalog.lastSeenAt = time()
    catalog.lastSeenAtText = date("%Y-%m-%d %H:%M:%S")
    catalog.verify = not catalog.journalInstanceID
    local journalID = catalog.journalInstanceID or run.journalInstanceID or self:FindJournalInstanceByName(run.instanceName)
    if journalID then
        catalog.journalInstanceID = journalID
        catalog.verify = false
        run.journalInstanceID = run.journalInstanceID or journalID
    end
    self.db.instanceCatalog[run.instanceName] = catalog

    local metadata = self.db.dungeonMetadata[run.instanceName] or {}
    -- Self-heal a stale placeholder ("Patch X.Y.Z") saved before a real name was resolvable,
    -- but never clobber a real manually-linked or Journal-derived name.
    if IsPlaceholderExpansionName(metadata.expansionName) then
        metadata.expansionName = catalog.expansionName or metadata.expansionName
    end
    metadata.journalInstanceID = metadata.journalInstanceID or catalog.journalInstanceID
    self.db.dungeonMetadata[run.instanceName] = metadata
    return catalog
end

function Addon:GetCurrentCatalogContext(source)
    local snapshot = GetInstanceSnapshot()
    local inInstance, instanceType = IsInInstance()
    local patchInfo = GetClientPatchInfo()
    local instanceName = snapshot.name or snapshot.zoneText or GetRealZoneText()
    if not inInstance then
        instanceName = nil
    end
    return {
        id = "catalog",
        instanceName = instanceName,
        instanceType = inInstance and (instanceType or snapshot.instanceType or "instance") or "openworld",
        difficultyID = snapshot.difficultyID,
        difficultyName = snapshot.difficultyName,
        challengeMapID = snapshot.challengeMapID,
        mapID = snapshot.mapID,
        zoneText = snapshot.zoneText or GetRealZoneText(),
        subZoneText = snapshot.subZoneText or GetSubZoneText(),
        expansionName = inInstance and (GetKnownExpansionNameForVersion(patchInfo.version) or (patchInfo.version and ("Patch " .. tostring(patchInfo.version)) or nil)) or nil,
        catalogOnly = true,
        source = source or "catalog",
    }
end

function Addon:CatalogMob(run, npcID, name, level, drops, displayID)
    if not run or not npcID then
        return nil
    end
    self:CatalogCurrentInstance(run)
    self.db.npcCatalog = self.db.npcCatalog or {}
    local key = tostring(npcID)
    local info = self.db.npcCatalog[key] or {}
    info.npcID = key
    info.name = self.db.mobNameOverrides and self.db.mobNameOverrides[key] or name or info.name
    info.level = level or info.level
    info.drops = drops or info.drops or {}
    info.displayID = displayID or info.displayID
    info.expansionName = self:GetRunExpansionText(run) or info.expansionName or run.expansionName
    info.instanceName = run.instanceName or info.instanceName
    info.instanceType = run.instanceType or info.instanceType
    info.mapID = run.mapID or info.mapID
    info.zoneText = run.zoneText or info.zoneText
    info.lastSeenAt = time()
    info.lastSeenAtText = date("%Y-%m-%d %H:%M:%S")
    info.verify = not info.name or not info.level or not info.drops or #info.drops == 0
    self.db.npcCatalog[key] = info
    return info
end

-- Name-keyed sibling of CatalogMob, for the RecordMobKillByName fallback (no npcID available --
-- see that function). Kept as a separate synthetic-keyed entry rather than merged into a real
-- npcID entry, since there's no reliable way to know they're the same creature without the ID.
function Addon:CatalogMobByName(run, name, displayID)
    if not run or not name or name == "" then
        return nil
    end
    self:CatalogCurrentInstance(run)
    self.db.npcCatalog = self.db.npcCatalog or {}
    local key = "name:" .. string.lower(StripWowText(name))
    local info = self.db.npcCatalog[key] or {}
    info.npcID = nil
    info.name = self.db.mobNameOverrides and self.db.mobNameOverrides[key] or name or info.name
    info.drops = info.drops or {}
    info.displayID = displayID or info.displayID
    info.expansionName = self:GetRunExpansionText(run) or info.expansionName or run.expansionName
    info.instanceName = run.instanceName or info.instanceName
    info.instanceType = run.instanceType or info.instanceType
    info.mapID = run.mapID or info.mapID
    info.zoneText = run.zoneText or info.zoneText
    info.lastSeenAt = time()
    info.lastSeenAtText = date("%Y-%m-%d %H:%M:%S")
    info.verify = true
    info.idUnavailable = true
    self.db.npcCatalog[key] = info
    return info
end

function Addon:CatalogBoss(run, bossID, name, level, health, drops, npcID, npcIDs, displayID)
    if not run or not bossID then
        return nil
    end
    self:CatalogCurrentInstance(run)
    self.db.bossCatalog = self.db.bossCatalog or {}
    local key = tostring(bossID)
    local info = self.db.bossCatalog[key] or {}
    info.bossID = key
    info.name = name or info.name or self:GetBossName(run, bossID)
    info.level = level or info.level
    info.health = health or info.health
    info.drops = drops or info.drops or {}
    info.displayID = displayID or info.displayID
    -- `bossID`/`key` here is Blizzard's Encounter Journal encounterID (from ENCOUNTER_END), not
    -- the creature's NPC ID -- Wowhead's NPC ID lookup won't match it. `npcID` is the real
    -- creature ID scraped from the boss1-boss8 unit GUIDs at the same moment, kept alongside for
    -- Wowhead cross-referencing without disturbing the encounterID-keyed roster/completion system.
    info.npcID = npcID or info.npcID
    if npcIDs and #npcIDs > 0 then
        info.npcIDs = npcIDs
    end
    info.expansionName = self:GetRunExpansionText(run) or info.expansionName or run.expansionName
    info.instanceName = run.instanceName or info.instanceName
    info.instanceType = run.instanceType or info.instanceType
    info.mapID = run.mapID or info.mapID
    info.zoneText = run.zoneText or info.zoneText
    info.lastSeenAt = time()
    info.lastSeenAtText = date("%Y-%m-%d %H:%M:%S")
    info.verify = not info.name or not info.level or not info.health or not info.drops or #info.drops == 0
    self.db.bossCatalog[key] = info
    return info
end

function Addon:GetDataToolCatalogOptions(catalog, idField, expansionName, instanceName, includeUnassigned)
    local options = {}
    for key, info in pairs(catalog or {}) do
        local assigned = info and not IsPlaceholderExpansionName(info.expansionName) and info.instanceName and info.instanceName ~= ""
        local include = includeUnassigned and not assigned
        if not includeUnassigned then
            include = info and info.expansionName == expansionName and info.instanceName == instanceName
        end
        if include then
            local id = tostring((info and info[idField]) or key)
            local name = (info and info.name) or ("ID " .. id)
            table.insert(options, {
                text = string.format("%s%s (%s)", info and info.verify and "|cffffff00Verify |r" or "", name, id),
                value = id,
            })
        end
    end
    table.sort(options, function(a, b) return tostring(a.text or "") < tostring(b.text or "") end)
    return options
end

-- Every catalog entry, assigned or not, with its current dungeon shown -- lets Save Assignment
-- also be used to re-map a boss/mob that was auto-linked to the wrong dungeon, not just to fill
-- in ones that were never linked.
function Addon:GetDataToolCatalogOptionsAll(catalog, idField)
    local options = {}
    for key, info in pairs(catalog or {}) do
        local id = tostring((info and info[idField]) or key)
        local name = (info and info.name) or ("ID " .. id)
        local assigned = info and not IsPlaceholderExpansionName(info.expansionName) and info.instanceName and info.instanceName ~= ""
        local where
        if assigned then
            where = info.instanceName
        elseif info and info.expansionName == "Open World" then
            where = "Open World"
        else
            where = "Unassigned"
        end
        local idText = (idField == "bossID" and info and info.npcID) and (id .. ", NPC " .. tostring(info.npcID)) or id
        table.insert(options, {
            text = string.format("%s%s (%s) - %s", info and info.verify and "|cffffff00Verify |r" or "", name, idText, where),
            value = id,
        })
    end
    table.sort(options, function(a, b) return tostring(a.text or "") < tostring(b.text or "") end)
    return options
end

function Addon:GetUnassignedCatalogText()
    local lines = {}
    local function addList(label, catalog, idField)
        local added = 0
        table.insert(lines, label)
        for key, info in pairs(catalog or {}) do
            local assigned = info and not IsPlaceholderExpansionName(info.expansionName) and info.instanceName and info.instanceName ~= ""
            if info and not assigned then
                added = added + 1
                if added <= 12 then
                    local id = tostring(info[idField] or key)
                    local name = tostring(info.name or "name not captured")
                    local where = info.zoneText or info.instanceType or "unknown area"
                    local verify = info.verify and " | Verify" or ""
                    table.insert(lines, string.format("%s. %s (%s) - %s%s", added, name, id, where, verify))
                end
            end
        end
        if added == 0 then
            table.insert(lines, "None")
        elseif added > 12 then
            table.insert(lines, "...and " .. tostring(added - 12) .. " more")
        end
        table.insert(lines, "")
    end
    addList("Mobs needing assignment:", self.db and self.db.npcCatalog, "npcID")
    addList("Bosses needing assignment:", self.db and self.db.bossCatalog, "bossID")
    return table.concat(lines, "\n")
end

-- Mob & Boss Browser window removed entirely 2026-09-06, per user request (feature audit --
-- confirmed dead: its toolbar button was already removed 2026-09-05, leaving ~480 lines of
-- unreachable UI code with no path to open it). GetCatalogBrowserEntries (only ever used by this
-- window's list-building) removed alongside it. The catalog DATA itself (npcCatalog/bossCatalog/
-- expansionCatalog) is untouched -- /dl catalog still builds/updates it for whatever else reads it.

-- Mythic+ stats/history dashboard (Phase 2 item from TODO.md). Combines this addon's own tracked
-- run history (best time/completion rate per dungeon) with three live Blizzard APIs confirmed
-- unaffected by patch 12.0's restriction overhaul (checked against warcraft.wiki.gg's 12.0.0,
-- 12.0.5, 12.0.7, and 12.1.0 API-changes pages before writing this): C_ChallengeMode.
-- GetOverallDungeonScore(), C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(), and
-- C_WeeklyRewards.GetActivities(). All three are wrapped in pcall + issecretvalue() guards anyway,
-- matching this file's existing defensive posture for any client-provided value.
function Addon:GetOverallMythicPlusScore()
    if not C_ChallengeMode or not C_ChallengeMode.GetOverallDungeonScore then
        return nil
    end
    local ok, score = pcall(C_ChallengeMode.GetOverallDungeonScore)
    if not ok or not score then
        return nil
    end
    if issecretvalue and issecretvalue(score) then
        return nil
    end
    return tonumber(score)
end

-- Per user request 2026-09-05 ("could we... find out all the Mythic+ Dungeon Affixes there are and
-- workout if this week will be hard or not"). Effects below verified against warcraft.wiki.gg
-- (Fortified/Tyrannical/Xal'atath's Bargain variants/Xal'atath's Guile pages, 2026-09-05) -- not
-- guessed. Matched by exact affix NAME (from the live C_ChallengeMode.GetAffixInfo call) rather
-- than hardcoding numeric affix IDs, since the name strings are what's actually verified; an
-- affix that's active but not in this table (a future patch adding/renaming one) still displays
-- fine with its live name/description, it just won't contribute to the weight/assessment below.
-- `weight` is M+ Ledger's own rough "how much harder does this make the week" read -- not an
-- official Blizzard difficulty number, just a transparent, explained heuristic.
local AFFIX_KNOWLEDGE = {
    ["Fortified"] = {
        category = "Stat check",
        note = "Non-boss enemies have 20% more health and inflict up to 20% increased damage.",
        weight = 1,
    },
    ["Tyrannical"] = {
        category = "Stat check",
        note = "Bosses have 25% more health. Bosses and their minions inflict up to 15% increased damage.",
        weight = 1,
    },
    ["Xal'atath's Bargain: Devour"] = {
        category = "Mechanic check",
        note = "A stacking Shadow-damage debuff needs a defensive dispel or ~47% healing to clear -- clear it for a buff, or it empowers every enemy if it expires.",
        weight = 1,
    },
    ["Xal'atath's Bargain: Pulsar"] = {
        category = "Mechanic check",
        note = "Orbiting void pulsars must be collected within 15s for a party buff, or they empower every enemy instead.",
        weight = 1,
    },
    ["Xal'atath's Bargain: Ascendant"] = {
        category = "Mechanic check",
        note = "Orbs need interrupting/dispelling for a speed+haste buff, or they empower every enemy if left to complete.",
        weight = 1,
    },
    ["Xal'atath's Bargain: Voidbound"] = {
        category = "Mechanic check",
        note = "An unkillable-shield Void Emissary must be burned down fast for a buff -- the longer its shield survives, the bigger the enemy buff if it finishes casting.",
        weight = 1,
    },
    ["Xal'atath's Guile"] = {
        category = "Timer pressure",
        note = "Every death subtracts 15 seconds from the timer -- no room for careless deaths at this key level.",
        weight = 1,
    },
    ["Lindormi's Guidance"] = {
        category = "Helpful",
        note = "Highlights and weakens enemies on a suggested route, and removes the death timer penalty -- an easier, low-key-only affix.",
        weight = -1,
    },
}

-- Reads whatever C_MythicPlus.GetCurrentAffixes() actually returns for the account this week --
-- never assumes a fixed count or specific combination, since that varies by key level and week.
function Addon:GetCurrentMythicPlusAffixes()
    if not C_MythicPlus or not C_MythicPlus.GetCurrentAffixes or not C_ChallengeMode or not C_ChallengeMode.GetAffixInfo then
        return {}
    end
    local ok, affixes = pcall(C_MythicPlus.GetCurrentAffixes)
    if not ok or type(affixes) ~= "table" then
        return {}
    end
    local results = {}
    for _, entry in ipairs(affixes) do
        local affixID = type(entry) == "table" and entry.id or entry
        if affixID then
            local infoOk, name, description, icon = pcall(C_ChallengeMode.GetAffixInfo, affixID)
            if infoOk and name then
                table.insert(results, {
                    id = affixID,
                    name = name,
                    description = description,
                    icon = icon,
                    known = AFFIX_KNOWLEDGE[name],
                })
            end
        end
    end
    return results
end

-- Transparent, explained heuristic -- see AFFIX_KNOWLEDGE's comment. Returns a verdict label plus
-- the list of reasons (one per recognized affix) that produced it, so this never reads as an
-- unexplained black-box number.
function Addon:GetMythicPlusWeekAssessment(affixes)
    local totalWeight = 0
    local reasons = {}
    for _, affix in ipairs(affixes) do
        if affix.known then
            totalWeight = totalWeight + affix.known.weight
            -- Colored per user request 2026-09-09: the affix name, and any percentage figures in
            -- its note, colored green if the affix helps the run (weight < 0, e.g. Lindormi's
            -- Guidance) or red if it makes the run harder (weight > 0) -- reusing this addon's own
            -- established green/red (matches the player-report Trusted/Avoid colors) rather than
            -- introducing a new pair.
            local isHelpful = affix.known.weight < 0
            local color = isHelpful and "|cff33ff33" or "|cffff5555"
            local coloredName = color .. affix.name .. "|r"
            local coloredNote = (affix.known.note:gsub("(%d+%%)", color .. "%1|r"))
            table.insert(reasons, string.format("%s (%s): %s", coloredName, affix.known.category, coloredNote))
        end
    end
    local verdict
    if totalWeight <= 0 then
        verdict = "Easier week"
    elseif totalWeight == 1 then
        verdict = "Standard week"
    elseif totalWeight == 2 then
        verdict = "Tougher week"
    else
        verdict = "Brutal week"
    end
    return verdict, reasons
end

function Addon:GetWeeklyVaultMythicPlusActivities()
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities or not Enum or not Enum.WeeklyRewardChestThresholdType then
        return {}
    end
    local ok, activities = pcall(C_WeeklyRewards.GetActivities, Enum.WeeklyRewardChestThresholdType.Activities)
    if not ok or type(activities) ~= "table" then
        Debug("GetWeeklyVaultMythicPlusActivities: C_WeeklyRewards.GetActivities failed: " .. tostring(activities))
        return {}
    end

    local results = {}
    for _, activity in ipairs(activities) do
        if type(activity) == "table" and not (issecretvalue and (issecretvalue(activity.progress) or issecretvalue(activity.threshold))) then
            table.insert(results, {
                threshold = tonumber(activity.threshold),
                progress = tonumber(activity.progress),
                level = tonumber(activity.level),
            })
        end
    end
    table.sort(results, function(a, b) return (tonumber(a.threshold) or 0) < (tonumber(b.threshold) or 0) end)
    return results
end

-- The current M+ pool. Read live from C_ChallengeMode once per session and saved over the old
-- dump (2026-10-08: on a fresh install the list was empty until /dl icons or /dl catalog had been
-- run, so Overview/Progress/Season showed "Dungeon data is not available yet"; it also kept last
-- season's list after a season change). The saved dump is only the fallback if the live read
-- comes back empty.
function Addon:GetMythicPlusPoolEntries()
    if not self.liveMythicPlusPoolLoaded and self.db then
        local live = self:DumpChallengeDungeonIcons()
        if #live > 0 then
            self.db.iconDumps = self.db.iconDumps or {}
            self.db.iconDumps.challengeDungeons = live
            self.liveMythicPlusPoolLoaded = true
        end
    end
    local entries = {}
    for _, entry in ipairs(self.db and self.db.iconDumps and self.db.iconDumps.challengeDungeons or {}) do
        if entry and entry.name and entry.challengeMapID then
            table.insert(entries, { name = entry.name, challengeMapID = entry.challengeMapID })
        end
    end
    table.sort(entries, function(a, b) return tostring(a.name or "") < tostring(b.name or "") end)
    return entries
end

function Addon:GetLiveSeasonBestForMap(challengeMapID)
    if not challengeMapID or not C_MythicPlus or not C_MythicPlus.GetSeasonBestAffixScoreInfoForMap then
        return nil
    end
    local ok, affixScores, bestOverallScore = pcall(C_MythicPlus.GetSeasonBestAffixScoreInfoForMap, challengeMapID)
    if not ok then
        Debug("GetLiveSeasonBestForMap: GetSeasonBestAffixScoreInfoForMap failed for map " .. tostring(challengeMapID) .. ": " .. tostring(affixScores))
        return nil
    end
    if issecretvalue and issecretvalue(bestOverallScore) then
        return nil
    end

    local bestLevel, bestDuration, bestOverTime
    for _, info in ipairs(affixScores or {}) do
        if type(info) == "table" and not (issecretvalue and issecretvalue(info.level)) then
            local level = tonumber(info.level)
            if level and (not bestLevel or level > bestLevel) then
                bestLevel = level
                bestDuration = tonumber(info.durationSec)
                bestOverTime = info.overTime and true or false
            end
        end
    end

    local overallScore = tonumber(bestOverallScore)
    if not overallScore and not bestLevel then
        return nil
    end
    return {
        overallScore = overallScore,
        bestLevel = bestLevel,
        bestDuration = bestDuration,
        bestOverTime = bestOverTime,
    }
end

-- Cross-party Mythic+ info (KeyMaster-style, roadmap item 3). Session-only, addon-comm sync of
-- score/keystone/vault progress between group members running this addon -- never written to
-- SavedVariables, cleared on logout/reload like any other live-only state.
local PARTY_SYNC_PREFIX = "MPlusLedgerMP"
local PARTY_SYNC_VERSION = 1

-- Interrupt tracking (2026-09-10): Details/DBM's interrupt count has always come from the
-- SPELL_INTERRUPT combat-log subevent, but patch 12.0 (Midnight) removed COMBAT_LOG_EVENT_
-- UNFILTERED for addons entirely (see the "mobs" event group comment above, which already had to
-- move mob-kill tracking off it for the same reason) -- that whole approach is a dead end here.
-- Confirmed via a Midnight-specific interrupt-tracking addon (github.com/josh-the-dev/
-- InteruptTracker) that the working replacement is UNIT_SPELLCAST_SUCCEEDED matched against a
-- known spell-ID table, since that event is unaffected. Keys are strings (not numbers): the
-- incoming spellID from UNIT_SPELLCAST_SUCCEEDED can be a tainted/Secret Value on some paths, and
-- comparing/looking it up as a number can silently misbehave, while stringifying it first
-- (GetLaunderedSpellID below) and keying this table by string sidesteps that -- same trick the
-- reference addon uses.
local InterruptSpells = {
    ["2139"] = true,    -- Counterspell (Mage)
    ["6552"] = true,    -- Pummel (Warrior)
    ["47528"] = true,   -- Mind Freeze (Death Knight)
    ["57994"] = true,   -- Wind Shear (Shaman)
    ["96231"] = true,   -- Rebuke (Paladin)
    ["106839"] = true,  -- Skull Bash (Druid - Feral/Guardian/Resto)
    ["78675"] = true,   -- Solar Beam (Druid - Balance)
    ["116705"] = true,  -- Spear Hand Strike (Monk)
    ["147362"] = true,  -- Counter Shot (Hunter - BM/MM)
    ["187707"] = true,  -- Muzzle (Hunter - Survival)
    ["183752"] = true,  -- Disrupt (Demon Hunter)
    ["351338"] = true,  -- Quell (Evoker)
    ["1766"] = true,    -- Kick (Rogue)
    ["19647"] = true,   -- Spell Lock (Warlock - Felhunter, Affliction/Destruction)
    ["119914"] = true,  -- Axe Toss (Warlock - Felguard, Demonology)
    ["15487"] = true,   -- Silence (Priest - Shadow)
}

function Addon:GetChallengeMapName(mapID)
    mapID = tonumber(mapID)
    if not mapID or mapID == 0 then
        return nil
    end
    for _, entry in ipairs(self.db and self.db.iconDumps and self.db.iconDumps.challengeDungeons or {}) do
        if entry.challengeMapID == mapID then
            return entry.name
        end
    end
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
        if ok and name and not (issecretvalue and issecretvalue(name)) then
            return name
        end
    end
    return nil
end

function Addon:GetOwnMythicPlusSyncInfo()
    local score = self:GetOverallMythicPlusScore() or 0
    local mapID, keyLevel = 0, 0
    if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneLevel then
        local okMap, ownedMapID = pcall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
        local okLevel, ownedLevel = pcall(C_MythicPlus.GetOwnedKeystoneLevel)
        if okMap and ownedMapID and not (issecretvalue and issecretvalue(ownedMapID)) then
            mapID = tonumber(ownedMapID) or 0
        end
        if okLevel and ownedLevel and not (issecretvalue and issecretvalue(ownedLevel)) then
            keyLevel = tonumber(ownedLevel) or 0
        end
    end
    local vault = { 0, 0, 0 }
    for index, activity in ipairs(self:GetWeeklyVaultMythicPlusActivities()) do
        if index <= 3 then
            vault[index] = tonumber(activity.level) or 0
        end
    end
    return { score = math.floor(score), mapID = mapID, keyLevel = keyLevel, vault = vault }
end

function Addon:EncodeMythicPlusSyncMessage(info)
    return string.format("%d|%d|%d|%d|%d|%d|%d", PARTY_SYNC_VERSION, info.score or 0, info.mapID or 0, info.keyLevel or 0, info.vault[1] or 0, info.vault[2] or 0, info.vault[3] or 0)
end

function Addon:FormatMythicPlusSyncLine(name, info)
    local keyText = "no key"
    if info.keyLevel and info.keyLevel > 0 then
        local mapName = self:GetChallengeMapName(info.mapID) or ("Map " .. tostring(info.mapID))
        keyText = string.format("+%d %s", info.keyLevel, mapName)
    end
    local vaultBest = math.max(info.vault and info.vault[1] or 0, info.vault and info.vault[2] or 0, info.vault and info.vault[3] or 0)
    local vaultText = vaultBest > 0 and ("vault best +" .. vaultBest) or "no vault progress"
    return string.format("%s -- Score %.1f | %s | %s", GetShortName(name), tonumber(info.score) or 0, keyText, vaultText)
end

-- Registered once at load (OnLoaded). Recipients must register the same prefix to receive
-- messages at all -- this addon can't sync with a party member who doesn't also run it, same as
-- KeyMaster's own comms.
function Addon:RegisterMythicPlusSyncPrefix()
    if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix then
        return
    end
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PARTY_SYNC_PREFIX)
end

-- Self-throttled well under SendAddonMessage's own 10-burst/1-per-second limit (Enum.
-- SendAddonMessageResult.AddonMessageThrottle) since this only needs to fire on meaningful
-- changes (roster update, opening the dashboard), not continuously -- no ChatThrottleLib/AceComm
-- dependency needed at this message rate, and this addon carries no embedded libraries by design
-- (single-file Core.lua).
-- Found 2026-09-05 via a live SavedVariables debugLog dump: a failed retry used to call itself
-- again with `reason .. " retry"`, uncapped -- once the native SendAddonMessageThrottle got hit
-- (result=11), that retry ALSO hit the same throttle, forever, every 3 seconds, for as long as the
-- session ran. Confirmed live: single debugLog entries with the word "retry" repeated hundreds of
-- times (the reason string growing every retry) and, since nothing ever stopped it, this was very
-- likely a real, ongoing contributor to reported in-game lag, independent of anything UI-side.
-- Fixed with an explicit retry counter (not string concatenation) capped at 5 attempts.
--
-- Found 2026-09-05 via code review against Blizzard's own SendAddonMessage documentation, which
-- explicitly recommends a SHARED queue (ChatThrottleLib/AceComm) specifically because per-call
-- throttling alone can still collectively burst past the native 10-message/1-per-second allowance
-- when several independent triggers fire close together -- this addon has ~4 independent call
-- paths (own-data broadcast, dashboard-open, request, answering a request), each previously
-- throttled only against ITSELF, not against each other. Added a shared minimum-gap gate below,
-- covering every call path (including retries), as a lightweight stand-in for a real queue --
-- still no embedded library, matching this file's single-file design.
function Addon:BroadcastMythicPlusSync(reason, message, retryCount)
    if not IsInGroup or not IsInGroup() then
        return
    end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end

    retryCount = retryCount or 0
    local now = GetTime and GetTime() or time()
    if not message and self.lastMythicPlusSyncBroadcastAt and (now - self.lastMythicPlusSyncBroadcastAt) < 15 then
        return
    end

    local sinceLastAttempt = self.lastMythicPlusSyncAttemptAt and (now - self.lastMythicPlusSyncAttemptAt) or math.huge
    if sinceLastAttempt < 1.1 then
        if C_Timer and C_Timer.After then
            C_Timer.After(1.1 - sinceLastAttempt, function()
                Addon:BroadcastMythicPlusSync(reason, message, retryCount)
            end)
        end
        return
    end
    self.lastMythicPlusSyncAttemptAt = now

    local payload = message or self:EncodeMythicPlusSyncMessage(self:GetOwnMythicPlusSyncInfo())
    local channel = self:GetGroupShareChannel() or "PARTY"
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PARTY_SYNC_PREFIX, payload, channel)
    local success = ok and (result == 0 or (Enum and Enum.SendAddonMessageResult and result == Enum.SendAddonMessageResult.Success))
    if success then
        if not message then
            self.lastMythicPlusSyncBroadcastAt = now
        end
        Debug("Broadcast M+ sync (" .. tostring(reason) .. "): " .. payload)
    elseif retryCount < 5 then
        Debug("M+ sync broadcast failed (" .. tostring(reason) .. ", retry " .. (retryCount + 1) .. "/5): ok=" .. tostring(ok) .. " result=" .. tostring(result))
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                Addon:BroadcastMythicPlusSync(reason, message, retryCount + 1)
            end)
        end
    else
        Debug("M+ sync broadcast gave up (" .. tostring(reason) .. ") after 5 retries: ok=" .. tostring(ok) .. " result=" .. tostring(result))
    end
end

-- Independently throttled from BroadcastMythicPlusSync's own-data cooldown, since this bypasses
-- that cooldown by passing an explicit message -- without its own limit, repeated clicks on
-- "Request Party Sync" (or repeatedly opening the dashboard) could burn through
-- SendAddonMessage's native 10-message throttle allowance.
function Addon:RequestMythicPlusSync()
    local now = GetTime and GetTime() or time()
    if self.lastMythicPlusSyncRequestAt and (now - self.lastMythicPlusSyncRequestAt) < 10 then
        return
    end
    self.lastMythicPlusSyncRequestAt = now
    self:BroadcastMythicPlusSync("request", "REQUEST")
end

-- Records one interrupt credit for `guid` (a real UnitGUID, or a "name:<key>" fallback bucket --
-- see RecordInterruptByDisplayName) against the currently active run. Mirrors RecordMemberDeathByGUID's
-- guid-or-name-fallback key scheme (GetMemberInterruptCount below does the same dual-key lookup
-- GetMemberDeathCount does) but with a much shorter (1s) cooldown than deaths use, since a real
-- interrupt ability's own cooldown (12-60s) already rules out legitimate back-to-back credit --
-- this window exists only to stop the SAME interrupt being counted twice from two different
-- detection paths (e.g. the addon-message broadcast AND the nameplate-correlation fallback both
-- firing for one kick).
function Addon:RecordInterruptByGUID(guid, name, confirmed)
    local run = self:GetCurrentRun()
    if not run or not guid then
        return false
    end
    run.memberInterrupts = run.memberInterrupts or {}
    run.memberInterruptCooldowns = run.memberInterruptCooldowns or {}
    local now = time()
    -- Duplicate unit-token events are deduplicated by cast identity in the event handler.
    run.memberInterruptCooldowns[guid] = now
    run.memberInterrupts[guid] = run.memberInterrupts[guid] or { name = name, count = 0 }
    run.memberInterrupts[guid].name = name or run.memberInterrupts[guid].name
    run.memberInterrupts[guid].count = (run.memberInterrupts[guid].count or 0) + 1
    if not confirmed then
        run.memberInterrupts[guid].attemptOnly = (run.memberInterrupts[guid].attemptOnly or 0) + 1
    end
    self:RefreshTrackerBar()
    return true
end

-- Used when only a display name is known (the addon-message broadcast path -- CHAT_MSG_ADDON's
-- `sender` is a name, not a GUID). Buckets under the same "name:<realm-qualified key>" scheme
-- RecordMemberDeathByDisplayName uses, so a player who's both directly observed (real GUID) and
-- name-credited via broadcast doesn't silently fragment into two separate people in the summary --
-- GetMemberInterruptCount below takes the max of both buckets, same as death counts already do.
function Addon:RecordInterruptByDisplayName(name, confirmed)
    if not name then
        return false
    end
    local identityKey = GetPlayerProfileKey(name) or NormalizePlayerName(name)
    if not identityKey or identityKey == "" then
        return false
    end
    return self:RecordInterruptByGUID("name:" .. identityKey, name, confirmed)
end

function Addon:GetMemberInterruptCount(run, member)
    if not run or not member then
        return 0
    end
    local guidInfo = member.guid and run.memberInterrupts and run.memberInterrupts[member.guid]
    local guidCount = guidInfo and guidInfo.count or 0
    local nameKey = "name:" .. (GetPlayerProfileKey(member.name) or NormalizePlayerName(member.name))
    local nameInfo = run.memberInterrupts and run.memberInterrupts[nameKey]
    local nameCount = nameInfo and nameInfo.count or 0
    return math.max(guidCount, nameCount)
end

function Addon:GetInterruptSummary(run)
    if not run or not run.members or #run.members == 0 then
        return "No players recorded"
    end
    local parts = {}
    for _, member in ipairs(run.members) do
        table.insert(parts, string.format("%s:%d", GetShortName(member.name), self:GetMemberInterruptCount(run, member)))
    end
    return table.concat(parts, "  ")
end

-- Use the event's actual interrupter identity. Timing correlation cannot prove a kick.
function Addon:InitInterruptCorrelationTracking()
    if self.interruptCorrelationInited then return end
    self.interruptCorrelationInited = true
    local frame = CreateFrame("Frame")
    self.interruptEventFrame = frame
    local recent, lastRun = {}, nil
    frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    frame:SetScript("OnEvent", function(_, _, unit, castGUID, spellID, interruptedBy, castBarID)
        local run = Addon:GetCurrentRun()
        if not run then return end
        if lastRun ~= run then recent = {};lastRun = run end
        if IsSecret(interruptedBy) or type(interruptedBy) ~= "string" or interruptedBy == "" then
            run.interruptCoverageLimited = true
            return
        end
        local owner, name
        local units = {"player", "pet"}
        for i=1,4 do units[#units+1]="party"..i;units[#units+1]="partypet"..i end
        for _, token in ipairs(units) do
            local guid = SafeUnitGUID(token)
            if guid and guid == interruptedBy then
                local credit = token == "pet" and "player" or token:gsub("^partypet", "party")
                owner = SafeUnitGUID(credit);name = GetUnitFullName(credit)
                break
            end
        end
        if not owner then return end
        local key
        if not IsSecret(castGUID) and type(castGUID)=="string" and castGUID~="" then key=castGUID end
        if not key and not IsSecret(castBarID) and type(castBarID)=="number" then key=tostring(castBarID) end
        local now=GetTime()
        key=owner..":"..(key or "recent")
        if recent[key] and now-recent[key]<1 then return end
        recent[key]=now
        for k,t in pairs(recent) do if now-t>3 then recent[k]=nil end end
        Addon:RecordInterruptByGUID(owner,name,true)
    end)
end

function Addon:InitInterruptTracking()
    if self.interruptTrackingInited then
        return
    end
    self.interruptTrackingInited = true

    self:InitInterruptCorrelationTracking()
end

function Addon:HandleMythicPlusSyncMessage(prefix, text, channel, sender)
    if prefix ~= PARTY_SYNC_PREFIX or not sender then
        return
    end
    if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then
        return
    end
    if sender == GetUnitFullName("player") then
        return
    end
    if text == "REQUEST" then
        self:BroadcastMythicPlusSync("answering request from " .. tostring(sender))
        return
    end
    if text == "IK" then
        -- Older IK messages were based on timing guesses, not confirmed attribution.
        return
    end

    local version, score, mapID, keyLevel, vault1, vault2, vault3 = strsplit("|", tostring(text or ""))
    if tonumber(version) ~= PARTY_SYNC_VERSION then
        Debug("Ignored M+ sync message from " .. tostring(sender) .. " with unknown version " .. tostring(version))
        return
    end

    self.partyMythicPlusInfo = self.partyMythicPlusInfo or {}
    self.partyMythicPlusInfo[NormalizePlayerName(sender)] = {
        score = tonumber(score) or 0,
        mapID = tonumber(mapID) or 0,
        keyLevel = tonumber(keyLevel) or 0,
        vault = { tonumber(vault1) or 0, tonumber(vault2) or 0, tonumber(vault3) or 0 },
        updatedAt = time(),
    }
    if self.statsHubWindow and self.statsHubWindow:IsShown() and self.statsHubWindow.activeTab == "mplus" then
        self:RefreshMythicPlusStatsTabData()
    end
end


-- ============================================================================================
-- Stats & Progress hub: one tabbed window (Season / Progress / M+ Stats / Trends) replacing the
-- three separate popups those used to be. Each tab is a persistent child panel of the same frame
-- -- switching tabs just shows/hides/refreshes a panel, no re-creating windows -- so there is
-- exactly one window to manage relative to the main window, not three juggling each other's
-- return targets.
-- ============================================================================================
-- "M+ Summary" is first/default per user request 2026-09-05 -- it's the closest thing to a single
-- at-a-glance overview (score, vault, party), so it makes more sense as the landing tab than
-- Season did.
-- "M+ Summary" -> "Overview" 2026-09-30, matching the mockup's own tab label (cosmetic only, same
-- reasoning as the earlier "Instance Ledger" -> "M+ Ledger" title rename -- the key stays "mplus"
-- so every other reference to this tab, saved SavedVariables state, etc. is untouched).
local STATS_HUB_TABS = {
    { key = "mplus", label = "Overview" },
    { key = "season", label = "Season" },
    { key = "progress", label = "Progress" },
    { key = "trends", label = "Trends" },
    { key = "pacing", label = "Boss Pacing" },
}

function Addon:CreateStatsHubWindow()
    if self.statsHubWindow then
        return
    end

    local frame = CreateFrame("Frame", "MPlusLedgerStatsHubFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1100, 760)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(390)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    EnableEscHandler(frame, function()
        Addon:CloseAllWindows()
    end)
    frame:SetScript("OnShow", function()
        if Addon.window then
            Addon.window:Hide()
        end
    end)
    frame:SetScript("OnHide", function()
        if Addon.ledgerSwitchingWindows then return end
        local returnTo = frame.returnToWindow or Addon.window
        frame.returnToWindow = nil
        if returnTo then
            returnTo:Show()
        end
    end)
    -- Skinned with the M+ Ledger asset pack, per user request 2026-09-30 ("using these [assets],
    -- can we create the attached image in World of Warcraft for our addon?") -- falls back to the
    -- old plain dialog-box backdrop if the skin pack folder (MPlusLedgerSkin) is ever stripped out,
    -- since it's an optional media pack, not a hard dependency (see its own README).
    if Skin then
        Skin.Apply(frame, "Window")
    else
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        frame:SetBackdropColor(0, 0, 0, 1.00)
    end

    -- Portrait-style icon, top-left corner -- circular mask over a Mythic+ icon, the same trick
    -- Blizzard's own portrait frames use (Texture:SetMask against a circular alpha texture),
    -- plus a thin gold ring so it doesn't just look like a floating square-cropped icon.
    local portraitRing = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    portraitRing:SetSize(50, 50)
    portraitRing:SetPoint("TOPLEFT", 9, -7)
    portraitRing:Hide()
    local portrait = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    portrait:SetSize(48, 48)
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -16)
    portrait:SetTexture("Interface\\Icons\\Achievement_ChallengeMode_Gold")
    portrait:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    if Skin and Skin.ThemeAsset then
        portrait:Hide()
        frame.themeHeaderIcon = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        frame.themeHeaderIcon:SetSize(48,48)
        frame.themeHeaderIcon:SetPoint("TOPLEFT",24,-16)
        Skin.ThemeAsset(frame.themeHeaderIcon,"runs")
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 84, -18)
    title:SetFont(STANDARD_TEXT_FONT, 28, "")
    title:SetTextColor(0.78, 0.82, 0.86)
    -- Renamed 2026-09-30 per user request ("rename this Addon to M+ Ledger") -- this window's
    -- title specifically, since it's now the addon's main entry point (see the earlier menu-swap
    -- work). The underlying addon folder/TOC/SavedVariables name is untouched -- see the reply to
    -- the user for why that's a separate, much riskier change not done here.
    title:SetText("M+ Ledger")
    frame.title = title

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Your tracked history, live Blizzard data, and trends -- all in one place")
    frame.subtitle = subtitle

    local close
    if Skin then
        close = Skin.Button(frame, "X", 30, 28, function() Addon:CloseAllWindows() end)
    else
        close = self:CreatePlainButton(frame, "X", 28, 24)
        close:SetScript("OnClick", function() Addon:CloseAllWindows() end)
    end
    local closeRed = close:CreateTexture(nil, "BACKGROUND", nil, 1)
    closeRed:SetPoint("TOPLEFT", 3, -3); closeRed:SetPoint("BOTTOMRIGHT", -3, 3)
    closeRed:SetColorTexture(0.48, 0.025, 0.035, 1)
    close:SetPoint("TOPRIGHT", -18, -18)

    -- View All Runs: opens the old main window (recent runs, repairs, deaths, roster) -- now the
    -- secondary "view all runs and instances" screen per user request 2026-09-30, reachable from
    -- here since Stats Hub is the addon's new main entry point. Visible on the frame itself (not a
    -- per-tab panel), so it's available from every tab, not just M+ Summary.
    local viewAllRuns
    if Skin then
        viewAllRuns = Skin.Button(frame, "All Runs", 132, 36, function() Addon:ToggleWindow() end)
    else
        viewAllRuns = self:CreatePlainButton(frame, "View All Runs", 140, 24)
        viewAllRuns:SetScript("OnClick", function() Addon:ToggleWindow() end)
    end
    viewAllRuns:SetPoint("TOPRIGHT", close, "TOPLEFT", -10, 0)
    if viewAllRuns.Label then viewAllRuns.Label:SetFont(STANDARD_TEXT_FONT,12,"") end
    frame.viewAllRunsButton = viewAllRuns
    if Skin then
        local history = Skin.Button(frame, "Player History", 150, 36, function() Addon:OpenPlayerHistoryWindow() end)
        history.Label:SetFont(STANDARD_TEXT_FONT,12,"")
        history:SetPoint("TOPRIGHT", viewAllRuns, "TOPLEFT", -10, 0)
        local manage = Skin.Button(frame, "Manage Runs", 150, 36, function() Addon:OpenDataToolsMenu("create") end)
        manage.Label:SetFont(STANDARD_TEXT_FONT,12,"")
        manage:SetPoint("TOPRIGHT", history, "TOPLEFT", -10, 0)
        frame.manageRunsButton = manage
        local repair = Skin.Button(frame, "Record Repair", 150, 36, function() Addon:ManualRecordRepair() end)
        repair.Label:SetFont(STANDARD_TEXT_FONT,12,"")
        repair:SetPoint("TOPRIGHT", manage, "TOPLEFT", -10, 0)
        frame.recordRepairButton = repair
    end

    -- Tab bar: the addon's own proven button widget (CreatePlainButton) styled with a clear
    -- selected/unselected state, rather than Blizzard's PanelTabButtonTemplate -- that template
    -- requires exact global-name conventions ($parentTab1, $parentTab2, ...) to work with
    -- PanelTemplates_SetTab/UpdateTabs, and a mistake there fails silently/inconsistently with no
    -- way to verify visually outside a live client. This reaches the same "clear tab bar" result
    -- with code this addon fully controls.
    frame.tabButtons = {}
    frame.tabPanels = {}
    local tabWidth = 126
    -- Found via user report 2026-09-05: this used to space every tab by a fixed (tabWidth + 6)
    -- regardless of that tab's OWN width, so "M+ Summary"/"Boss Pacing" (widened to 150 to fit
    -- their labels) overlapped the tab immediately after them. Tracks a running X offset built
    -- from each tab's REAL width instead, so a wider tab just pushes everything after it over.
    local navX = 282
    for _, tabDef in ipairs(STATS_HUB_TABS) do
        local width = (tabDef.key == "pacing" or tabDef.key == "mplus") and 150 or tabWidth
        local tab = self:CreatePlainButton(frame, tabDef.label, width, 28)
        tab:SetPoint("TOPLEFT", navX, -64)
        tab:SetScript("OnClick", function()
            Addon:ShowStatsHubTab(tabDef.key)
        end)
        -- Flat text-tab look with a gold underline for the selected tab, matching the mockup's own
        -- tab row, per user request 2026-09-30 -- replaces the old filled-box tab backdrop (see
        -- ShowStatsHubTab, which now toggles tab.underline/text color instead of backdrop color).
        if Skin then
            tab:SetBackdrop(nil)
            tab.underline = frame:CreateTexture(nil, "ARTWORK")
            tab.underline:SetHeight(2)
            tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, -4)
            tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, -4)
            Skin.ThemeAccentTexture(tab.underline)
            tab.underline:Hide()
            tab:SetScript("OnEnter", nil)
            tab:SetScript("OnLeave", nil)
        end
        frame.tabButtons[tabDef.key] = tab
        navX = navX + width + 6

        local panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", 24, -100)
        panel:SetPoint("BOTTOMRIGHT", -24, 20)
        panel:Hide()
        frame.tabPanels[tabDef.key] = panel
    end

    self.statsHubWindow = frame
    self:BuildSeasonTabContent(frame.tabPanels.season)
    self:BuildProgressTabContent(frame.tabPanels.progress)
    self:BuildMythicPlusStatsTabContent(frame.tabPanels.mplus)
    self:BuildTrendsTabContent(frame.tabPanels.trends)
    self:BuildBossPacingTabContent(frame.tabPanels.pacing)
end

function Addon:ShowStatsHubTab(tabKey)
    local frame = self.statsHubWindow
    if not frame then
        return
    end
    frame.activeTab = tabKey
    for key, panel in pairs(frame.tabPanels) do
        if key == tabKey then
            panel:Show()
        else
            panel:Hide()
        end
    end
    for key, tab in pairs(frame.tabButtons) do
        local selected = key == tabKey
        if tab.underline then
            -- Flat gold-underline tab style (skin pack present) -- see tab creation above.
            tab.underline:SetShown(selected)
            if selected then
                Skin.ThemeText(tab.text)
            else
                tab.text:SetTextColor(Skin.colors.muted[1], Skin.colors.muted[2], Skin.colors.muted[3])
            end
        elseif selected then
            tab.normalBackdrop = { 0.55, 0.42, 0.08 }
            tab:SetBackdropColor(0.55, 0.42, 0.08, 0.95)
            tab:SetBackdropBorderColor(self:GetThemeBorderColor(true, 1))
            tab.text:SetTextColor(1, 1, 1)
        else
            tab.normalBackdrop = nil
            tab:SetBackdropColor(0.3, 0.02, 0.02, 0.85)
            tab:SetBackdropBorderColor(self:GetThemeBorderColor(true, 0.5))
            tab.text:SetTextColor(0.75, 0.75, 0.75)
        end
    end
    if tabKey == "season" then
        self:RefreshSeasonTabContent()
    elseif tabKey == "progress" then
        self:RefreshProgressTabContent()
    elseif tabKey == "mplus" then
        self:RefreshMythicPlusStatsTabContent()
    elseif tabKey == "trends" then
        self:RefreshTrendsTabContent()
    elseif tabKey == "pacing" then
        self:RefreshBossPacingTabContent()
    end
end

-- Shared "click a dungeon to see its history" entry point -- used by M+ Summary's dungeon icon
-- grid (new 2026-09-05). Switches to Progress first (which refreshes with whatever dungeon was
-- last selected there), then immediately re-refreshes with the one actually clicked.
function Addon:OpenProgressForDungeon(dungeonName)
    self:ShowStatsHubTab("progress")
    self:RefreshProgressTabContent(dungeonName)
end

-- initialTab: which tab to land on. dungeonName: only meaningful for the "progress" tab (mirrors
-- the old ToggleProgressWindow(dungeonName) signature so existing call sites don't need to change).
-- Found via user report 2026-09-05: clicking Progress from within a run could open the Stats Hub
-- BEHIND another already-open addon window. Root cause was two separate gaps working together:
-- (1) each overlay window's own Toggle* only hid/raised itself on the FIRST transition into view --
-- if it was already shown (e.g. switching tabs/dungeon while open), it never re-raised, so it could
-- stay behind something that came to front afterward; (2) none of these overlay windows hid the
-- OTHERS, so two could end up simultaneously visible with no reliable ordering between them.
-- Called at the top of every overlay window's "show" path -- hides every other known overlay
-- (each one's own OnHide, where it has one, re-shows the main window itself, so this doesn't need
-- to special-case that) and always raises the one being shown, whether or not it was already open.
function Addon:BringWindowToFront(frame)
    if not frame then
        return
    end
    local switching = self.ledgerSwitchingWindows
    self.ledgerSwitchingWindows = true
    -- Close any open Stats Hub dropdown before switching -- per user report 2026-10-01 (see
    -- Addon:CloseActiveDropdown's own comment for the full root cause). Hiding the old window
    -- below does NOT do this on its own: WoW doesn't fire a child frame's OnHide just because an
    -- ancestor got hidden, so a dropdown's menu (and the full-screen click-catcher behind it)
    -- would otherwise stay active and silently block every click in whatever window opens next.
    self:CloseActiveDropdown()
    -- Found and fixed a real bug 2026-09-05: this used ipairs() over a table literal, but any of
    -- these windows can be nil until first opened -- ipairs stops at the FIRST nil it hits, so if
    -- (for example) self.mobBrowser was still nil, self.dataTools and self.debugEditor after it in
    -- the list were silently never even checked, let alone hidden. pairs() has no such early-stop
    -- behavior, so every present window actually gets considered regardless of what's nil.
    for _, other in pairs({ self.window, self.statsHubWindow, self.dataTools, self.debugEditor, self.addPlayerWindow, self.playerHistoryWindow, self.updatePlayerWindow }) do
        if other and other ~= frame and other:IsShown() then
            other:Hide()
        end
    end
    frame:Show()
    frame:Raise()
    self.ledgerSwitchingWindows = switching
end

-- ESC closes the addon completely, no matter which window/sub-window currently has focus -- per
-- user request 2026-10-01 ("the ESC key will exit the addon completely no matter what menu you
-- are in"). Before this, ESC on most windows just hid THAT window, which (for addPlayerWindow and
-- updatePlayerWindow especially, which had no ESC handling at all) could leave the user looking at
-- an empty screen with no ledger window visible, or back at a stale window several navigation
-- steps behind where they actually were. Reuses the same ledgerSwitchingWindows guard
-- BringWindowToFront uses, so none of the per-window OnHide "return to the previous window"
-- handlers (statsHubWindow/self.window/playerHistoryWindow/debugEditor) fire while this runs.
function Addon:CloseAllWindows()
    local switching = self.ledgerSwitchingWindows
    self.ledgerSwitchingWindows = true
    self:CloseActiveDropdown()
    for _, win in pairs({ self.window, self.statsHubWindow, self.dataTools, self.debugEditor, self.addPlayerWindow, self.playerHistoryWindow, self.updatePlayerWindow, self.repairWindow }) do
        if win and win:IsShown() then
            win:Hide()
        end
    end
    self.ledgerSwitchingWindows = switching
end

-- The X button on every window except the Stats Hub itself steps back to the Stats Hub (the
-- addon's main screen, per the 2026-09-30 redesign) instead of closing the addon outright -- per
-- user request 2026-10-01 ("if you hit the X button, it take you back to the main menu"). Reuses
-- BringWindowToFront, which already hides every other ledger window and closes any open dropdown.
function Addon:ReturnToMainMenu()
    self:CreateStatsHubWindow()
    self:BringWindowToFront(self.statsHubWindow)
end

function Addon:ToggleStatsHubWindow(initialTab, dungeonName)
    self:CreateStatsHubWindow()
    if self.statsHubWindow:IsShown() and (not initialTab or initialTab == self.statsHubWindow.activeTab) then
        self.statsHubWindow:Hide()
        return
    end
    if dungeonName then
        self.progressDungeonName = dungeonName
    end
    self.statsHubWindow.returnToWindow = self.window
    self:BringWindowToFront(self.statsHubWindow)
    self:ShowStatsHubTab(initialTab or self.statsHubWindow.activeTab or "mplus")
end

local MPLUS_TAB_VAULT_SLOTS = 3
-- Dungeon icon grid (replaced the old text-row list 2026-09-05): 4 across per user request, sized
-- generously enough (40 tiles) that it'll never run out even as the M+ pool grows mid-season.
local MPLUS_TAB_DUNGEON_TILE_COLS = 4
local MPLUS_TAB_DUNGEON_TILE_WIDTH = 256
-- Grew 90 -> 104 (2026-09-06) to fit the new on-time-rate bar + deaths/run line, per the UI
-- redesign concept's "Dungeon List" mockup.
local MPLUS_TAB_DUNGEON_TILE_HEIGHT = 104
local MPLUS_TAB_DUNGEON_TILE_GAP = 8
local MPLUS_TAB_DUNGEON_TILE_POOL = 40

function Addon:BuildMythicPlusStatsTabContent(panel)
    -- Refresh button removed 2026-09-30 per user's repeated request ("the Refresh buttons are
    -- still there"). Season Best/Vault/Score still read live from Blizzard's own API, but that
    -- query now runs automatically every time this tab is shown (see RefreshMythicPlusStatsTabData
    -- calls in ShowStatsHubTab/RefreshMythicPlusStatsTabContent) instead of needing a manual click.

    -- Quick access to the standalone Player Reputation History window, per user request 2026-09-30
    -- ("also can you add a button for that into the M+ Summary section") -- corrected same day: this
    -- was meant to open the Player History window itself, not the destructive clear (that stays
    -- inside the Player Reputation History window's own Row C, where it belongs).
    local playerHistoryButton
    if Skin then
        playerHistoryButton = Skin.Button(panel, "Player History", 160, 24, function() Addon:OpenPlayerHistoryWindow() end)
    else
        playerHistoryButton = self:CreatePlainButton(panel, "Player History", 160, 24)
        playerHistoryButton:SetScript("OnClick", function() Addon:OpenPlayerHistoryWindow() end)
    end
    playerHistoryButton:SetPoint("TOPRIGHT", 0, 0)

    -- "Request Party Sync" button removed 2026-09-08: the M+ Summary tab's party-data display
    -- block was dropped in the 2026-09-05 redesign (see the "Party section removed" comments
    -- below), leaving this button pointing at a sync result nothing on screen ever showed --
    -- clicking it looked like it did nothing because, functionally, it didn't display anything.
    -- self.partyMythicPlusInfo/BroadcastMythicPlusSync/HandleMythicPlusSyncMessage themselves are
    -- untouched (still harmless background code, not currently consumed by any UI).

    -- Score tile + 3 Vault slot cards, same KPI-tile visual language as the Season tab, since the
    -- Great Vault genuinely has exactly 3 tiers -- this reads as one coherent 4-tile row instead
    -- of the old plain text dump.
    local tileWidth = 1052 / 4
    local scoreTile = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    scoreTile:SetSize(tileWidth - 8, 74)
    scoreTile:SetPoint("TOPLEFT", 0, -36)
    if Skin then
        Skin.Apply(scoreTile, "Card")
    else
        scoreTile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        scoreTile:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))
        scoreTile:SetBackdropBorderColor(self:GetThemeBorderColor(false))
    end
    scoreTile.value = scoreTile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scoreTile.value:SetPoint("TOP", 0, -14)
    scoreTile.label = scoreTile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    scoreTile.label:SetPoint("BOTTOM", 0, 10)
    scoreTile.label:SetText("Overall M+ Score")
    panel.scoreTile = scoreTile

    -- Great Vault section header -- real icon this time, per user request 2026-09-05. Confirmed
    -- against Blizzard's own current Blizzard_WeeklyRewards.lua source (not guessed): the M+/
    -- dungeons category uses atlas "evergreen-weeklyrewards-category-dungeons"; a slot's own
    -- unlocked/locked state uses "evergreen-weeklyrewards-reward-unlocked"/"-locked".
    local vaultHeaderIcon = panel:CreateTexture(nil, "OVERLAY")
    vaultHeaderIcon:SetSize(20, 20)
    vaultHeaderIcon:SetPoint("TOPLEFT", scoreTile, "TOPRIGHT", 18, -2)
    vaultHeaderIcon:SetAtlas("evergreen-weeklyrewards-category-dungeons", false)
    local vaultHeaderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vaultHeaderLabel:SetPoint("LEFT", vaultHeaderIcon, "RIGHT", 6, 0)
    vaultHeaderLabel:SetText("Great Vault -- Mythic+")

    panel.vaultTiles = {}
    for slot = 1, MPLUS_TAB_VAULT_SLOTS do
        local tile = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        tile:SetSize(tileWidth - 8, 74)
        tile:SetPoint("TOPLEFT", slot * tileWidth, -36)
        if Skin then
            Skin.Apply(tile, "Card")
        else
            tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
            tile:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))
            tile:SetBackdropBorderColor(self:GetThemeBorderColor(false))
        end

        tile.lockIcon = tile:CreateTexture(nil, "OVERLAY")
        tile.lockIcon:SetSize(16, 16)
        tile.lockIcon:SetPoint("TOPLEFT", 6, -6)

        tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tile.value:SetPoint("TOP", 0, -12)

        tile.progressBg = tile:CreateTexture(nil, "ARTWORK")
        tile.progressBg:SetPoint("BOTTOMLEFT", 8, 22)
        tile.progressBg:SetPoint("BOTTOMRIGHT", -8, 22)
        tile.progressBg:SetHeight(6)
        tile.progressBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

        tile.progressFill = tile:CreateTexture(nil, "ARTWORK", nil, 1)
        tile.progressFill:SetPoint("BOTTOMLEFT", tile.progressBg, "BOTTOMLEFT", 0, 0)
        tile.progressFill:SetHeight(6)
        -- Left green/gold (unlocked vs in-progress) -- that's a real status signal, matched to
        -- Blizzard's own vault UI convention, not just a palette choice -- see
        -- RefreshMythicPlusStatsTabData below, which sets both width and color every refresh.

        tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tile.label:SetPoint("BOTTOM", 0, 8)

        panel.vaultTiles[slot] = tile
    end

    -- This week's affixes + a transparent "how hard is this week" read, per user request
    -- 2026-09-05 (they'd seen KeyMaster show the week's affixes and wanted a difficulty read on
    -- top of that). Live data via C_MythicPlus.GetCurrentAffixes -- see AFFIX_KNOWLEDGE for the
    -- verified effect text and GetMythicPlusWeekAssessment for how the verdict is derived.
    local affixesLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    affixesLabel:SetPoint("TOPLEFT", 0, -118)
    affixesLabel:SetText("|cffffcc00This Week's Affixes|r")
    panel.affixesLabel = affixesLabel

    panel.affixTiles = {}
    for index = 1, 6 do
        local tile = CreateFrame("Frame", nil, panel)
        tile:SetSize(160, 46)
        tile:SetPoint("TOPLEFT", (index - 1) * 165, -140)

        tile.icon = tile:CreateTexture(nil, "OVERLAY")
        tile.icon:SetSize(32, 32)
        tile.icon:SetPoint("TOPLEFT", 0, 0)

        tile.name = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tile.name:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", 6, -2)
        tile.name:SetPoint("RIGHT", 0, 0)
        tile.name:SetJustifyH("LEFT")
        tile.name:SetWordWrap(true)

        tile:SetScript("OnEnter", function(self)
            if not self.affixData then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.affixData.name)
            GameTooltip:AddLine(self.affixData.description or "", 1, 1, 1, true)
            if self.affixData.known then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(self.affixData.known.note, 0.8, 0.8, 1, true)
            end
            GameTooltip:Show()
        end)
        tile:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        tile:Hide()
        panel.affixTiles[index] = tile
    end

    local assessmentText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    assessmentText:SetPoint("TOPLEFT", 0, -192)
    panel.assessmentText = assessmentText

    local assessmentReasons = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    assessmentReasons:SetPoint("TOPLEFT", 0, -214)
    assessmentReasons:SetPoint("TOPRIGHT", 0, -214)
    assessmentReasons:SetJustifyH("LEFT")
    assessmentReasons:SetWordWrap(true)
    panel.assessmentReasons = assessmentReasons

    -- Per-dungeon: redesigned 2026-09-05 from a text-row list into a clickable icon grid, per user
    -- request ("change the Per-Dungeon area... to the Dungeon Icons... thinking of making M+
    -- Summary the main menu and you click the dungeons like in the main screen"). Party section
    -- removed per the same request (self.partyMythicPlusInfo/sync itself is untouched -- other
    -- features still use it, this just drops its own display block here). GetMythicPlusPoolEntries
    -- is inherently this season's dungeon pool already, so no separate season filter is needed.
    local perDungeonLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    perDungeonLabel:SetPoint("TOPLEFT", 0, -272)
    perDungeonLabel:SetText("|cffffcc00This Season's Dungeons|r (click one to open Progress)")
    panel.perDungeonLabel = perDungeonLabel

    local dungeonGrid = CreateFrame("Frame", nil, panel)
    dungeonGrid:SetPoint("TOPLEFT", 0, -296)
    dungeonGrid:SetPoint("TOPRIGHT", 0, -296)
    panel.dungeonGrid = dungeonGrid

    panel.dungeonTiles = {}
    for index = 1, MPLUS_TAB_DUNGEON_TILE_POOL do
        local col = (index - 1) % MPLUS_TAB_DUNGEON_TILE_COLS
        local row = math.floor((index - 1) / MPLUS_TAB_DUNGEON_TILE_COLS)
        local tile = CreateFrame("Button", nil, dungeonGrid, "BackdropTemplate")
        tile:SetSize(MPLUS_TAB_DUNGEON_TILE_WIDTH, MPLUS_TAB_DUNGEON_TILE_HEIGHT)
        tile:SetPoint("TOPLEFT", col * (MPLUS_TAB_DUNGEON_TILE_WIDTH + MPLUS_TAB_DUNGEON_TILE_GAP), -row * (MPLUS_TAB_DUNGEON_TILE_HEIGHT + MPLUS_TAB_DUNGEON_TILE_GAP))
        tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        tile:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))
        tile:SetBackdropBorderColor(unpack(Addon:GetTheme().tileBorder))

        tile.icon = tile:CreateTexture(nil, "ARTWORK")
        tile.icon:SetPoint("TOPLEFT", 8, -8)

        tile.name = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tile.name:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", 8, -1)
        tile.name:SetPoint("RIGHT", -6, 0)
        tile.name:SetJustifyH("LEFT")
        tile.name:SetWordWrap(true)

        tile.tracked = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tile.tracked:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", 8, -19)
        tile.tracked:SetPoint("RIGHT", -6, 0)
        tile.tracked:SetJustifyH("LEFT")

        tile.seasonBest = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tile.seasonBest:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", 8, -35)
        tile.seasonBest:SetPoint("RIGHT", -6, 0)
        tile.seasonBest:SetJustifyH("LEFT")

        -- On-time rate bar + deaths/run line, new 2026-09-06 per the UI redesign concept's
        -- "Dungeon List" mockup -- all-time stats (Addon:GetDungeonSummary), not season-filtered,
        -- since this same tile can now represent a dungeon outside the current pool too (All
        -- Instances scope).
        tile.onTimeTrack = CreateFrame("Frame", nil, tile, "BackdropTemplate")
        tile.onTimeTrack:SetPoint("TOPLEFT", 10, -56)
        tile.onTimeTrack:SetPoint("TOPRIGHT", -10, -56)
        tile.onTimeTrack:SetHeight(6)
        tile.onTimeTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        tile.onTimeTrack:SetBackdropColor(1, 1, 1, 0.08)

        tile.onTimeFill = tile.onTimeTrack:CreateTexture(nil, "ARTWORK")
        tile.onTimeFill:SetPoint("TOPLEFT")
        tile.onTimeFill:SetPoint("BOTTOMLEFT")
        tile.onTimeFill:SetColorTexture(1, 1, 1, 1)

        tile.statsLine = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tile.statsLine:SetPoint("TOPLEFT", tile.onTimeTrack, "BOTTOMLEFT", 0, -4)
        tile.statsLine:SetPoint("RIGHT", -10, 0)
        tile.statsLine:SetJustifyH("LEFT")

        tile:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(Addon:GetTheme().tileBorderHover))
            if self.isBestDungeon then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("Best Dungeon to Run")
                GameTooltip:AddLine("Highest combined on-time %, key level, and fewest deaths/run among this season's dungeons.", 0.6, 1, 0.6, true)
                GameTooltip:Show()
            end
        end)
        tile:SetScript("OnLeave", function(self)
            -- Best-dungeon tiles keep their green border after the mouse leaves -- see
            -- RefreshMythicPlusStatsTabData, which sets self.isBestDungeon per user request
            -- 2026-09-30 ("green border around the dungeon that is best dungeon to run").
            if self.isBestDungeon then
                self:SetBackdropBorderColor(unpack(Addon:GetTheme().barGood))
            else
                self:SetBackdropBorderColor(unpack(Addon:GetTheme().tileBorder))
            end
            GameTooltip:Hide()
        end)
        tile:SetScript("OnClick", function(self)
            if self.dungeonName then
                Addon:OpenProgressForDungeon(self.dungeonName)
            end
        end)

        tile:Hide()
        panel.dungeonTiles[index] = tile
    end

    panel.help = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.help:SetPoint("BOTTOMLEFT", 0, 0)
    panel.help:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.help:SetJustifyH("LEFT")
    panel.help:SetWordWrap(true)
    panel.help:SetText("Your Best/Tracked come from M+ Ledger's own run history. Season Best/Vault/Score are read live from Blizzard's API and may need a Refresh after logging in. Party info only syncs with group members who also run MPlusLedger. For a season-wide comparison across every dungeon, see the Season tab.")

    self.mplusTabPanel = panel
end

-- C_WeeklyRewards.GetActivities() only returns real data after the server has pushed it for this
-- session -- historically that only happened when the Blizzard Weekly Rewards frame was opened.
-- C_WeeklyRewards.OnUIInteract() (added 9.2.5, still present as of 12.1.0) requests that push
-- without needing the frame itself, but the response arrives asynchronously, so re-check the text
-- a couple of times after asking rather than assuming it's already there.
function Addon:RequestWeeklyVaultData()
    if C_WeeklyRewards and C_WeeklyRewards.OnUIInteract then
        pcall(C_WeeklyRewards.OnUIInteract)
    end
end

-- Data-only refresh (no server request) -- used for the delayed re-checks below so each one
-- doesn't also re-trigger RequestWeeklyVaultData.
function Addon:RefreshMythicPlusStatsTabData()
    local panel = self.mplusTabPanel
    if not panel then
        return
    end

    local overallScore = self:GetOverallMythicPlusScore()
    panel.scoreTile.value:SetText(overallScore and string.format("%.1f", overallScore) or "|cff808080unavailable|r")

    local vaultActivities = self:GetWeeklyVaultMythicPlusActivities()
    for slot = 1, MPLUS_TAB_VAULT_SLOTS do
        local tile = panel.vaultTiles[slot]
        local activity = vaultActivities[slot]
        if activity then
            local levelText = (activity.level and activity.level > 0) and ("+" .. tostring(activity.level)) or "no key yet"
            tile.value:SetText(levelText)
            local unlocked = (activity.threshold or 0) > 0 and (activity.progress or 0) >= activity.threshold
            tile.label:SetText(string.format("Vault Slot %d (%d/%d runs)", slot, activity.progress or 0, activity.threshold or 0))
            local pct = (activity.threshold or 0) > 0 and math.min(1, (activity.progress or 0) / activity.threshold) or 0
            local fillWidth = math.max(0.01, tile.progressBg:GetWidth() * pct)
            tile.progressFill:SetWidth(fillWidth)
            tile.progressFill:SetColorTexture(pct >= 1 and 0.20 or 0.85, pct >= 1 and 0.85 or 0.70, pct >= 1 and 0.30 or 0.10, 0.95)
            tile.lockIcon:SetAtlas(unlocked and "evergreen-weeklyrewards-reward-unlocked" or "evergreen-weeklyrewards-reward-locked", false)
            tile.lockIcon:Show()
        else
            tile.value:SetText("|cff808080--|r")
            tile.label:SetText(string.format("Vault Slot %d", slot))
            tile.progressFill:SetWidth(0.01)
            tile.lockIcon:Hide()
        end
    end
    if #vaultActivities == 0 then
        panel.vaultTiles[1].label:SetText("Vault unavailable -- open Weekly Rewards once, or /reload")
    end

    do
        local affixes = self:GetCurrentMythicPlusAffixes()
        for index, tile in ipairs(panel.affixTiles) do
            local affix = affixes[index]
            if affix then
                tile.affixData = affix
                tile.icon:SetTexture(affix.icon)
                local color = affix.known and (affix.known.weight < 0 and "|cff33d94d" or (affix.known.weight > 0 and "|cffff6666" or "|cffffffff")) or "|cffffffff"
                tile.name:SetText(color .. affix.name .. "|r")
                tile:Show()
            else
                tile.affixData = nil
                tile:Hide()
            end
        end
        if #affixes == 0 then
            panel.assessmentText:SetText("|cff808080Affixes unavailable -- open the Mythic+ keystone frame once, or /reload|r")
            panel.assessmentReasons:SetText("")
        else
            local verdict, reasons = self:GetMythicPlusWeekAssessment(affixes)
            local verdictColor = (verdict == "Easier week" and "|cff33d94d") or (verdict == "Standard week" and "|cffffd94d") or (verdict == "Tougher week" and "|cffff9933") or "|cffff3333"
            panel.assessmentText:SetText(verdictColor .. verdict .. "|r -- M+ Ledger's own read, not an official difficulty rating")
            panel.assessmentReasons:SetText(#reasons > 0 and table.concat(reasons, "\n") or "No recognized stat/mechanic-check affixes active this week.")
        end
    end

    -- Dungeon icon grid: this season's M+ pool, one clickable tile per dungeon (opens Progress).
    -- Party section removed here 2026-09-05 per user request -- self.partyMythicPlusInfo/the sync
    -- broadcast itself is untouched, this just dropped its own display block.
    local poolEntries = self:GetMythicPlusPoolEntries()

    -- "All Instances" scope toggle (added 2026-09-06, its button removed 2026-09-09 per user
    -- request -- it rendered awkwardly positioned over other UI). Reverted to always showing just
    -- the season pool, its simpler original behavior, rather than leave the toggle logic reachable
    -- by nothing. If a way to see dungeons that rotated out of the pool is wanted again later, it
    -- needs a real UI entry point, not a resurrected dead field.
    if panel.perDungeonLabel then
        panel.perDungeonLabel:SetText("|cffffcc00This Season's Dungeons|r (click one to open Progress)")
    end

    local theme = self:GetTheme()
    local tileRows = math.max(1, math.ceil(#poolEntries / MPLUS_TAB_DUNGEON_TILE_COLS))
    panel.dungeonGrid:SetHeight(tileRows * (MPLUS_TAB_DUNGEON_TILE_HEIGHT + MPLUS_TAB_DUNGEON_TILE_GAP))

    -- Best dungeon to run: highest combined on-time %, key level, and fewest deaths/run, among
    -- dungeons with at least one completed run -- highlighted with a green tile border below, per
    -- user request 2026-09-30 ("green border around the dungeon that is best dungeon to run based
    -- of the numbers. i.e. On time %, key level and deaths per run"). Each metric is normalized
    -- 0-1 relative to the OTHER candidate dungeons (not an absolute scale), since "good" key level
    -- or deaths/run has no fixed universal threshold -- only relative comparison makes sense here.
    local candidates = {}
    for _, entry in ipairs(poolEntries) do
        local summary = self:GetDungeonSummary(entry.name)
        local timedTotal = summary.completed + summary.completedOvertime + summary.abandoned
        if timedTotal > 0 and summary.runs > 0 then
            table.insert(candidates, {
                name = entry.name,
                onTimePct = (summary.completed / timedTotal) * 100,
                keyLevel = summary.bestRun and self:GetRunKeyLevel(summary.bestRun) or 0,
                deathsPerRun = summary.partyDeaths / summary.runs,
            })
        end
    end
    local bestDungeonName = nil
    if #candidates > 0 then
        local minKey, maxKey = candidates[1].keyLevel, candidates[1].keyLevel
        local minDeaths, maxDeaths = candidates[1].deathsPerRun, candidates[1].deathsPerRun
        for _, c in ipairs(candidates) do
            minKey = math.min(minKey, c.keyLevel)
            maxKey = math.max(maxKey, c.keyLevel)
            minDeaths = math.min(minDeaths, c.deathsPerRun)
            maxDeaths = math.max(maxDeaths, c.deathsPerRun)
        end
        local bestScore = -1
        for _, c in ipairs(candidates) do
            local onTimeScore = c.onTimePct / 100
            local keyScore = (maxKey > minKey) and ((c.keyLevel - minKey) / (maxKey - minKey)) or 1
            -- Fewer deaths is better, so this is inverted; when every candidate has the same
            -- deaths/run (maxDeaths == minDeaths) they all score full marks here rather than an
            -- undefined 0/0.
            local deathScore = (maxDeaths > minDeaths) and (1 - ((c.deathsPerRun - minDeaths) / (maxDeaths - minDeaths))) or 1
            local score = (onTimeScore + keyScore + deathScore) / 3
            if score > bestScore then
                bestScore = score
                bestDungeonName = c.name
            end
        end
    end

    for index, tile in ipairs(panel.dungeonTiles) do
        local entry = poolEntries[index]
        if entry then
            tile.dungeonName = entry.name
            tile.name:SetText(entry.name)
            self:SetRowIcon(tile, self:GetDungeonIcon(entry.name), 40, entry.name)
            tile.isBestDungeon = bestDungeonName ~= nil and entry.name == bestDungeonName
            tile:SetBackdropBorderColor(unpack(tile.isBestDungeon and theme.barGood or theme.tileBorder))

            local summary = self:GetDungeonSummary(entry.name)
            if summary.bestRun then
                tile.tracked:SetText(string.format("Best (on-time): +%d in %s", self:GetRunKeyLevel(summary.bestRun), FormatDuration(GetRunDuration(summary.bestRun))))
            elseif summary.completed > 0 then
                -- Distinguishes "completed, but only ever overtime" from "never completed at all"
                -- -- bestRun above only considers on-time completions now, so this case is real and
                -- shouldn't read as if the dungeon had never been finished.
                tile.tracked:SetText("|cff808080completed, none on-time yet|r")
            else
                tile.tracked:SetText("|cff808080no completed run|r")
            end

            local live = self:GetLiveSeasonBestForMap(entry.challengeMapID)
            if live and live.bestLevel then
                tile.seasonBest:SetText(string.format("Season: +%d%s%s", live.bestLevel, live.bestOverTime and " (overtime)" or "", live.overallScore and string.format(", %.1f", live.overallScore) or ""))
            elseif live and live.overallScore then
                tile.seasonBest:SetText(string.format("Season score: %.1f", live.overallScore))
            else
                tile.seasonBest:SetText("|cff808080season data unavailable|r")
            end

            -- On-time rate bar + deaths/run, new 2026-09-06 (UI redesign concept's "Dungeon List").
            -- All-time, not season-filtered -- see GetDungeonSummary -- since this tile can now
            -- represent a dungeon outside the current pool too (All Instances scope above).
            local timedTotal = summary.completed + summary.completedOvertime + summary.abandoned
            local trackWidth = tile.onTimeTrack:GetWidth() or 0
            if timedTotal > 0 then
                local onTimePct = (summary.completed / timedTotal) * 100
                tile.onTimeFill:SetWidth(math.max(1, trackWidth * (onTimePct / 100)))
                tile.onTimeFill:SetColorTexture(unpack(onTimePct >= 70 and theme.barGood or theme.barWarn))
                tile.onTimeFill:Show()
                local deathsPerRun = summary.runs > 0 and (summary.partyDeaths / summary.runs) or 0
                tile.statsLine:SetText(string.format("On-time %d%%  \194\183  %.1f deaths/run", math.floor(onTimePct + 0.5), deathsPerRun))
            else
                tile.onTimeFill:Hide()
                tile.statsLine:SetText(summary.runs > 0 and "|cff808080no timed keys yet|r" or "|cff808080no runs recorded yet|r")
            end
            tile:Show()
        else
            tile.dungeonName = nil
            tile:Hide()
        end
    end

    if self.statsHubWindow then
        self.statsHubWindow.subtitle:SetText("Mythic+ Stats - live Blizzard score and dungeon data")
    end
end

function Addon:RefreshMythicPlusStatsTabContent()
    if not self.mplusTabPanel then
        return
    end
    self:RequestWeeklyVaultData()
    self:RequestMythicPlusSync()
    self:BroadcastMythicPlusSync("dashboard opened")
    self:RefreshMythicPlusStatsTabData()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.6, function()
            if Addon.statsHubWindow and Addon.statsHubWindow:IsShown() and Addon.statsHubWindow.activeTab == "mplus" then
                Addon:RefreshMythicPlusStatsTabData()
            end
        end)
        C_Timer.After(2, function()
            if Addon.statsHubWindow and Addon.statsHubWindow:IsShown() and Addon.statsHubWindow.activeTab == "mplus" then
                Addon:RefreshMythicPlusStatsTabData()
            end
        end)
    end
end

-- ============================================================================================
-- Trends tab: deaths per run, oldest to newest. Replaced the original net-gold-per-run design
-- (user's call: repair cost/gold looted aren't part of this addon's own stated mission and
-- weren't an interesting trend to track). Deaths per run directly matches two mission items at
-- once -- "Player deaths" and, indirectly, "Run speed vs. time limit" (dying costs time) -- and
-- shows real improvement (or regression) across every dungeon combined, which neither the
-- per-dungeon Progress tab nor Season Overview's per-dungeon breakdown shows on its own.
-- ============================================================================================
local TRENDS_LOOKBACK_OPTIONS = { 10, 25, 50, 999999 }
local TRENDS_LOOKBACK_LABELS = { [10] = "Last 10", [25] = "Last 25", [50] = "Last 50", [999999] = "All Runs" }
local TRENDS_ROW_POOL = 60
local TRENDS_CHART_HEIGHT = 220
local TRENDS_COL_WIDTH = 24
local TRENDS_COL_SPACING = 34
local TRENDS_BASELINE_Y = 40

-- Per Section view: two independently-scaled zones (mob/travel on top, boss fights on bottom),
-- same proven layout Boss Pacing already uses for its own mob/pull vs boss/fight split -- per user
-- request 2026-09-30 ("split the boss and mobs into separate table... make sure the axis are
-- listed and the titles are visible and are not hidden by the graph"). Reuses the exact same
-- constants/ratios Boss Pacing's own bug-fix history already worked out (see the Pacing table
-- above) rather than re-deriving them from scratch.
local TRENDS_SECTION_ZONE_HEIGHT = 150
local TRENDS_SECTION_ZONE_GAP = 46
local TRENDS_SECTION_CHART_HEIGHT = (TRENDS_SECTION_ZONE_HEIGHT * 2) + TRENDS_SECTION_ZONE_GAP
local TRENDS_SECTION_BASELINE_Y = 46
local TRENDS_SECTION_BOSS_BASELINE_Y = TRENDS_SECTION_BASELINE_Y
local TRENDS_SECTION_MOB_BASELINE_Y = TRENDS_SECTION_BASELINE_Y + TRENDS_SECTION_ZONE_HEIGHT + TRENDS_SECTION_ZONE_GAP
local TRENDS_SECTION_ZONE_FILL_RATIO = 0.78
local TRENDS_SECTION_ZONE_LABEL_Y_OFFSET = (TRENDS_SECTION_ZONE_HEIGHT * TRENDS_SECTION_ZONE_FILL_RATIO) + 20
-- Wider than TRENDS_COL_SPACING (34, sized for short dates/"#N") -- per user report/screenshot
-- 2026-09-30 ("bars should be spread out to see the names"): boss names need real room, not a
-- truncated "Add..." /"Galv...".
local TRENDS_SECTION_COL_SPACING = 110
-- Centers the (narrower) bar texture within the (wider) column slot, so the bar sits directly
-- under its boss-name label instead of hugging the column's left edge -- per user report/
-- screenshot 2026-09-30 ("the bars should be in center of the boss name").
local TRENDS_SECTION_BAR_X = (TRENDS_SECTION_COL_SPACING - TRENDS_COL_WIDTH) / 2

-- dungeonName added 2026-09-30 per user request ("Trends menu... look to have the Dungeon filter
-- added as well") -- nil/omitted keeps the old "every dungeon combined" behavior.
function Addon:GetTrendData(limit, dungeonName)
    local runs = {}
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and self:IsMPlusLedgerRun(run) and (not dungeonName or run.instanceName == dungeonName) then
            table.insert(runs, run)
            if #runs >= limit then
                break
            end
        end
    end
    -- runOrder is newest-first; reverse so the chart reads oldest -> newest, matching Progress.
    for i = 1, math.floor(#runs / 2) do
        runs[i], runs[#runs - i + 1] = runs[#runs - i + 1], runs[i]
    end

    local points = {}
    local totalPartyDeaths, totalYourDeaths, deathFreeRuns = 0, 0, 0
    for _, run in ipairs(runs) do
        local partyDeaths = self:GetRunDeathTotal(run)
        local yourDeaths = self:GetPlayerDeaths(run)
        totalPartyDeaths = totalPartyDeaths + partyDeaths
        totalYourDeaths = totalYourDeaths + yourDeaths
        if partyDeaths == 0 then
            deathFreeRuns = deathFreeRuns + 1
        end
        table.insert(points, {
            name = run.instanceName or "Unknown",
            date = run.startedAtText,
            keyLevel = self:GetRunKeyLevel(run),
            status = self:GetRunDisplayStatus(run),
            partyDeaths = partyDeaths,
            yourDeaths = yourDeaths,
        })
    end
    return {
        points = points,
        totalPartyDeaths = totalPartyDeaths,
        totalYourDeaths = totalYourDeaths,
        deathFreeRuns = deathFreeRuns,
        avgPartyDeaths = #points > 0 and (totalPartyDeaths / #points) or 0,
    }
end

-- Classifies every death in one run as "mob" (died during travel/trash between bosses) or "boss"
-- (died during an actual boss fight), and which numbered section it happened in -- per user
-- request 2026-09-30 ("deaths for last 10/25/50 runs related to mobs and bosses... a bar chart
-- could have Deaths per section, 1st mob section, boss 1, 2nd mob section, boss 2 etc.").
--
-- There's no killer-NPC-ID-to-boss lookup this addon can trust here: DUNGEON_BOSSES/bossCatalog
-- are keyed by journalEncounterID (Encounter Journal's own ID), not the creature NPC ID a death's
-- killerNPCID actually is (GetNPCIDFromGUID, a different ID space entirely) -- so instead this
-- reuses the SAME boss segment timings Boss Splits/Boss Pacing already compute (GetBossSegmentTimings,
-- which comes from real ENCOUNTER_START/END timestamps) as time windows, and places each death by
-- WHEN it happened relative to those windows. memberDeathLog's `time` is an absolute epoch
-- timestamp (matches its own timeText = date(...) formatting) while boss segments are elapsed-
-- seconds-since-run-start, so death times are converted via (death.time - run.startedAt) first.
function Addon:GetRunDeathBreakdown(run)
    local result = { mobCount = 0, bossCount = 0, sections = {} }
    if not run or not run.memberDeathLog or #run.memberDeathLog == 0 then
        return result
    end

    local segments = self:GetBossSegmentTimings(run)
    local sections = {}
    local previousCumulative = 0
    for index, seg in ipairs(segments) do
        local bossStart = seg.startSeconds or seg.cumulativeSeconds
        table.insert(sections, { type = "mob", index = index, label = string.format("Mob %d", index), from = previousCumulative, to = bossStart, count = 0 })
        table.insert(sections, { type = "boss", index = index, label = string.format("Boss %d", index), bossName = seg.bossName, from = bossStart, to = seg.cumulativeSeconds, count = 0 })
        previousCumulative = seg.cumulativeSeconds
    end
    -- Catch-all trailing section for deaths after the last logged boss kill (a wipe with no kill
    -- recorded yet, or trash after the last required boss) -- trimmed below if nothing lands in it.
    table.insert(sections, { type = "mob", index = #segments + 1, label = string.format("Mob %d", #segments + 1), from = previousCumulative, to = math.huge, count = 0 })

    local runStart = tonumber(run.startedAt) or 0
    for _, entry in ipairs(run.memberDeathLog) do
        local elapsed = math.max(0, (tonumber(entry.time) or 0) - runStart)
        local matched = sections[#sections]
        for _, sec in ipairs(sections) do
            if elapsed >= sec.from and elapsed < sec.to then
                matched = sec
                break
            end
        end
        matched.count = matched.count + 1
        if matched.type == "boss" then
            result.bossCount = result.bossCount + 1
        else
            result.mobCount = result.mobCount + 1
        end
    end

    if sections[#sections].count == 0 and sections[#sections].type == "mob" then
        table.remove(sections)
    end
    result.sections = sections
    return result
end

-- Aggregates GetRunDeathBreakdown across the same run selection GetTrendData uses (same limit/
-- dungeon filter, so both views of the Trends tab always agree on which runs are "in scope").
-- Per-section totals only accumulate when scoped to ONE dungeonName -- different dungeons have
-- different boss counts/order, so merging sections across dungeons wouldn't mean anything.
function Addon:GetTrendDeathBreakdown(limit, dungeonName)
    local runs = {}
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and self:IsMPlusLedgerRun(run) and (not dungeonName or run.instanceName == dungeonName) then
            table.insert(runs, run)
            if #runs >= limit then
                break
            end
        end
    end

    local totalMob, totalBoss = 0, 0
    local sectionTotals, sectionOrder = {}, {}
    for _, run in ipairs(runs) do
        local breakdown = self:GetRunDeathBreakdown(run)
        totalMob = totalMob + breakdown.mobCount
        totalBoss = totalBoss + breakdown.bossCount
        if dungeonName then
            for _, sec in ipairs(breakdown.sections) do
                local existing = sectionTotals[sec.label]
                if not existing then
                    existing = { label = sec.label, type = sec.type, index = sec.index, bossName = sec.bossName, count = 0 }
                    sectionTotals[sec.label] = existing
                    table.insert(sectionOrder, sec.label)
                end
                existing.count = existing.count + sec.count
            end
        end
    end

    local sections = {}
    for _, label in ipairs(sectionOrder) do
        table.insert(sections, sectionTotals[label])
    end
    table.sort(sections, function(a, b)
        if a.index ~= b.index then
            return (a.index or 0) < (b.index or 0)
        end
        return a.type == "boss" and b.type ~= "boss"
    end)

    return {
        runCount = #runs,
        mobDeaths = totalMob,
        bossDeaths = totalBoss,
        sections = sections,
    }
end

local TRENDS_VIEW_MODES = { "perrun", "mobboss", "sections" }
local TRENDS_VIEW_LABELS = { perrun = "Deaths Per Run", mobboss = "Mob vs Boss", sections = "Per Section" }

-- Shared click-outside-to-close catcher for every CreateStatsHubDropdown menu -- per user report
-- 2026-09-30 ("if i click a dropdown menu and then click out of it, it does not close"). One
-- full-screen invisible button, created once and reused, shown behind whichever dropdown is
-- currently open; any click that isn't on the dropdown itself hits this catcher instead and closes
-- it. The menu's own OnHide closes the catcher too, so every existing way a menu already gets
-- hidden (picking an option, clicking the toggle button again) cleans this up automatically -- no
-- need to touch any of those call sites.
--
-- REVISED 2026-09-30 (user report: neither click-outside nor cursor-leave was actually closing
-- it) -- the catcher's level used to be computed as menu:GetFrameLevel() - 1 at open time, but
-- menu's own level (panel:GetFrameLevel() + 30, set once at BUILD time before the panel is ever
-- shown/parented into its final position) isn't a reliable absolute number to subtract from --
-- cross-parent frame level comparisons in WoW aren't guaranteed to respect a simple relative
-- offset like same-parent siblings do. Both the catcher and every menu now use large FIXED levels
-- (900/901) that are unambiguously above every real window in this addon (Data Tools, the
-- highest, tops out at 410), removing that uncertainty entirely. Also added: closing on cursor-
-- leave, per the same user report -- delayed via C_Timer.After and re-checked against
-- GetMouseFocus() so it doesn't fire while the mouse crosses from the menu's own background onto
-- one of its child option buttons (a bare OnLeave fires on that transition too, since the button
-- becomes the new topmost frame under the cursor -- would otherwise close the menu the instant
-- you tried to hover an option to click it).
local DROPDOWN_CATCHER_LEVEL = 900
local DROPDOWN_MENU_LEVEL = 901
local dropdownClickCatcher
-- Addon:CloseActiveDropdown (a method, not a bare local function) -- per user report 2026-10-01
-- ("Player Reputation... i can't do anything but if i hit next, it goes back to the old way").
-- Root cause: BringWindowToFront switches windows by calling :Hide() on whichever window was open
-- before -- but WoW does NOT fire a child frame's own OnHide script just because an ANCESTOR got
-- hidden (IsShown vs IsVisible). So leaving a Stats Hub dropdown open (e.g. Trends' dungeon
-- filter) and then opening Player Reputation never fires that dropdown menu's own OnHide handler
-- (the one that normally cleans up dropdownClickCatcher below) -- the catcher, a UIParent-wide
-- invisible Button at a fixed high frame level, stays active and silently eats every click
-- anywhere on screen until something coincidentally dismisses it. Needs to be callable from
-- BringWindowToFront, which is declared earlier in this file than this local -- a plain local
-- function call would hit the exact same forward-reference bug CreateStatsHubDropdown already hit
-- once this session (Lua resolves a bare name to whatever's lexically in scope at the point the
-- CALLING function's body was PARSED, not at the point it's later called); an Addon: method call
-- is a table lookup resolved at call time instead, so declaration order doesn't matter.
function Addon:CloseActiveDropdown()
    if dropdownClickCatcher and dropdownClickCatcher.activeMenu then
        dropdownClickCatcher.activeMenu:Hide()
    end
end
local function OpenDropdownMenu(menu)
    if not dropdownClickCatcher then
        dropdownClickCatcher = CreateFrame("Button", nil, UIParent)
        dropdownClickCatcher:SetAllPoints(UIParent)
        dropdownClickCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
        dropdownClickCatcher:SetFrameLevel(DROPDOWN_CATCHER_LEVEL)
        dropdownClickCatcher:EnableMouse(true)
        dropdownClickCatcher:SetScript("OnClick", function() Addon:CloseActiveDropdown() end)
        dropdownClickCatcher:Hide()
    end
    dropdownClickCatcher.activeMenu = menu
    dropdownClickCatcher:Show()
    menu:Show()
end

-- Small self-contained dropdown builder, matching the button+menu pattern used throughout Manage
-- Data (CreatePlainButton + a BackdropTemplate menu frame populated via RefreshSimpleDropdown) --
-- reimplemented here (not just reused from Manage Data) since that one lives inside
-- RefreshDataToolsWindow's own closure and isn't callable from other windows.
--
-- MOVED here 2026-09-30 (was originally declared right before BuildBossPacingTabContent, further
-- down the file) -- this is a chunk-scoped `local function`, and Lua resolves a bare name to
-- whatever local is lexically visible AT THE POINT A FUNCTION BODY IS PARSED, not at the point it's
-- later CALLED. BuildTrendsTabContent's new dungeon-filter dropdown (added this same session) is
-- defined earlier in the file than the old declaration site, so calling CreateStatsHubDropdown from
-- inside it resolved to a nil GLOBAL instead of this local -- "attempt to call a nil value" the
-- instant the Stats Hub window was built (which now happens immediately on /dl, since M+ Summary/
-- Stats Hub is the addon's new default entry point). Declaring it before its EARLIEST caller fixes
-- this for good rather than just patching around it.
local function CreateStatsHubDropdown(panel, width)
    local button = Addon:CreatePlainButton(panel, "Select...", width, 24)
    local menu = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    menu:SetSize(width, 30)
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    menu:SetFrameLevel(DROPDOWN_MENU_LEVEL)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    menu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    menu:EnableMouse(true)
    menu:Hide()
    menu:SetScript("OnHide", function()
        if dropdownClickCatcher and dropdownClickCatcher.activeMenu == menu then
            dropdownClickCatcher.activeMenu = nil
            dropdownClickCatcher:Hide()
        end
    end)
    -- Closes on cursor-leave too, per user request -- delayed and re-checked against
    -- menu:IsMouseOver() (a pure bounding-box test, unrelated to which child frame currently has
    -- mouse focus) rather than hiding immediately: OnLeave fires on the transition from the menu's
    -- own background onto one of its child OPTION buttons too (the button becomes the new topmost
    -- frame under the cursor), and hiding right then would close the menu the instant you tried to
    -- hover an option to click it. IsMouseOver() still reads true in that case since the cursor is
    -- geometrically still within the menu's bounds, so the delayed check correctly leaves it open.
    menu:SetScript("OnLeave", function(self)
        C_Timer.After(0.15, function()
            if self:IsShown() and not self:IsMouseOver() then
                self:Hide()
            end
        end)
    end)
    button:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            OpenDropdownMenu(menu)
        end
    end)
    button.menu = menu
    return button, menu
end

function Addon:BuildTrendsTabContent(panel)
    -- "More options": how many recent runs to include.
    local lookbackButton = self:CreatePlainButton(panel, "Last 25", 130, 24)
    lookbackButton:SetPoint("TOPLEFT", 0, 0)
    lookbackButton:SetScript("OnClick", function()
        local current = self.db.trendsLookback or 25
        local currentIndex = 1
        for i, value in ipairs(TRENDS_LOOKBACK_OPTIONS) do
            if value == current then
                currentIndex = i
                break
            end
        end
        local nextValue = TRENDS_LOOKBACK_OPTIONS[(currentIndex % #TRENDS_LOOKBACK_OPTIONS) + 1]
        self.db.trendsLookback = nextValue
        lookbackButton:SetText(TRENDS_LOOKBACK_LABELS[nextValue])
        Addon:RefreshTrendsTabContent()
    end)
    panel.lookbackButton = lookbackButton

    -- Dungeon filter, per user request 2026-09-30 ("look to have the Dungeon filter added as
    -- well"). nil = every dungeon combined (the original behavior).
    local dungeonButton, dungeonMenu = CreateStatsHubDropdown(panel, 220)
    dungeonButton:SetPoint("LEFT", lookbackButton, "RIGHT", 10, 0)
    panel.dungeonButton = dungeonButton
    panel.dungeonMenu = dungeonMenu

    -- View cycle: same run selection (lookback + dungeon filter), three different breakdowns.
    -- "Per Section" only means something with a specific dungeon picked (different dungeons have
    -- different boss counts/order) -- RefreshTrendsTabContent falls back to Mob vs Boss with an
    -- explanatory message if it's selected while the dungeon filter is "All Dungeons".
    local viewButton = self:CreatePlainButton(panel, "View: Deaths Per Run", 190, 24)
    viewButton:SetPoint("LEFT", dungeonButton, "RIGHT", 10, 0)
    viewButton:SetScript("OnClick", function()
        local current = self.trendsViewMode or "perrun"
        local currentIndex = 1
        for i, mode in ipairs(TRENDS_VIEW_MODES) do
            if mode == current then
                currentIndex = i
                break
            end
        end
        Addon.trendsViewMode = TRENDS_VIEW_MODES[(currentIndex % #TRENDS_VIEW_MODES) + 1]
        Addon:RefreshTrendsTabContent()
    end)
    panel.viewButton = viewButton

    -- Refresh button removed 2026-09-30 per user report ("do nothing from what i see") -- this
    -- tab only shows locally-tracked run history, already re-rendered on every control change and
    -- every time this tab becomes active (ShowStatsHubTab).

    -- Mob vs Boss donut (shown instead of the bar chart area for that view).
    local mobBossChart = MPlusLedgerPieChart.New(panel, { radius = 110, innerRadiusRatio = 0.55, centerColor = { 0.04, 0.04, 0.04, 1 } })
    mobBossChart.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 40, -160)
    panel.mobBossChart = mobBossChart

    local mobBossLegend = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mobBossLegend:SetPoint("LEFT", mobBossChart.frame, "RIGHT", 24, 0)
    mobBossLegend:SetJustifyH("LEFT")
    panel.mobBossLegend = mobBossLegend

    -- KPI row
    panel.kpis = {}
    local kpiDefs = { "runs", "totalDeaths", "avgDeaths", "deathFree" }
    local kpiLabels = { runs = "Runs Shown", totalDeaths = "Total Party Deaths", avgDeaths = "Avg Deaths / Run", deathFree = "Death-Free Runs" }
    local kpiWidth = 1052 / 4
    for index, key in ipairs(kpiDefs) do
        local tile = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        tile:SetSize(kpiWidth - 8, 64)
        tile:SetPoint("TOPLEFT", (index - 1) * kpiWidth, -36)
        tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        tile:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))
        tile:SetBackdropBorderColor(self:GetThemeBorderColor(false))

        tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tile.value:SetPoint("TOP", 0, -12)

        tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tile.label:SetPoint("BOTTOM", 0, 8)
        tile.label:SetText(kpiLabels[key])

        panel.kpis[key] = tile
    end

    local legend = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    legend:SetPoint("TOPLEFT", 0, -114)
    legend:SetText("Bar height = party deaths that run. |cffff3333Red number|r above a bar = your own deaths that run. One bar per run, oldest to newest, left to right.")
    panel.legend = legend

    local chartFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    chartFrame:SetPoint("TOPLEFT", 0, -136)
    chartFrame:SetPoint("BOTTOMRIGHT", 0, 32)
    chartFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    chartFrame:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))

    local scrollFrame = CreateFrame("ScrollFrame", nil, chartFrame)
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self:GetHorizontalScrollRange())
        local target = math.max(0, math.min(maxScroll, (self.targetScroll or self:GetHorizontalScroll()) - (delta * 60)))
        self.targetScroll = target
    end)
    scrollFrame:SetScript("OnUpdate", function(self, elapsed)
        local target = self.targetScroll
        if not target then
            return
        end
        local current = self:GetHorizontalScroll()
        if math.abs(target - current) < 0.5 then
            self:SetHorizontalScroll(target)
            self.targetScroll = nil
            return
        end
        self:SetHorizontalScroll(current + (target - current) * math.min(1, elapsed * 12))
    end)

    -- Sized to fit the TALLER Per Section dual-zone layout (not just the shorter Deaths Per Run
    -- bar chart) -- fixed 2026-09-30, a real bug (not just cosmetic): a ScrollFrame clips its
    -- scroll child to the child's OWN declared size, so anything positioned above this height
    -- (the mob zone bars, which sit well above TRENDS_CHART_HEIGHT + 40) was being silently
    -- clipped away, while the zone TITLE labels -- anchored to scrollFrame itself, not
    -- scrollContent -- aren't affected by that clipping and rendered fine, which is exactly the
    -- mismatch in the user's screenshot (titles in the right place, bars clipped/misplaced).
    local trendsScrollContentHeight = math.max(TRENDS_CHART_HEIGHT + 40, TRENDS_SECTION_CHART_HEIGHT + 60)
    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(600, trendsScrollContentHeight)
    scrollFrame:SetScrollChild(scrollContent)
    panel.chartFrame = chartFrame
    panel.scrollFrame = scrollFrame
    panel.scrollContent = scrollContent

    local baseline = scrollContent:CreateTexture(nil, "ARTWORK")
    baseline:SetColorTexture(1, 1, 1, 0.15)
    baseline:SetHeight(1)
    baseline:SetPoint("BOTTOMLEFT", scrollContent, "BOTTOMLEFT", 0, TRENDS_BASELINE_Y)
    baseline:SetPoint("BOTTOMRIGHT", scrollContent, "BOTTOMRIGHT", 0, TRENDS_BASELINE_Y)
    panel.baseline = baseline

    -- Per Section view's two zone baselines -- boss (fight) zone on the bottom, mob (travel/trash)
    -- zone on top, each independently scaled. Hidden except while that view is active.
    local bossBaseline = scrollContent:CreateTexture(nil, "ARTWORK")
    bossBaseline:SetColorTexture(1, 1, 1, 0.15)
    bossBaseline:SetHeight(1)
    bossBaseline:SetPoint("BOTTOMLEFT", scrollContent, "BOTTOMLEFT", 0, TRENDS_SECTION_BOSS_BASELINE_Y)
    bossBaseline:SetPoint("BOTTOMRIGHT", scrollContent, "BOTTOMRIGHT", 0, TRENDS_SECTION_BOSS_BASELINE_Y)
    bossBaseline:Hide()
    panel.sectionBossBaseline = bossBaseline

    local mobBaseline = scrollContent:CreateTexture(nil, "ARTWORK")
    mobBaseline:SetColorTexture(1, 1, 1, 0.15)
    mobBaseline:SetHeight(1)
    mobBaseline:SetPoint("BOTTOMLEFT", scrollContent, "BOTTOMLEFT", 0, TRENDS_SECTION_MOB_BASELINE_Y)
    mobBaseline:SetPoint("BOTTOMRIGHT", scrollContent, "BOTTOMRIGHT", 0, TRENDS_SECTION_MOB_BASELINE_Y)
    mobBaseline:Hide()
    panel.sectionMobBaseline = mobBaseline

    -- Zone titles, positioned above the REDUCED max a bar can actually reach (ZONE_FILL_RATIO),
    -- not the raw zone height -- otherwise the tallest bar's own value label sits right on top of
    -- the title (the exact bug Boss Pacing's own history already found and fixed; same offset
    -- constant reused here for the same reason).
    local bossZoneLabel = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bossZoneLabel:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 8, TRENDS_SECTION_BOSS_BASELINE_Y + TRENDS_SECTION_ZONE_LABEL_Y_OFFSET)
    bossZoneLabel:SetText("|cffff9933Boss Deaths|r")
    bossZoneLabel:Hide()
    panel.sectionBossZoneLabel = bossZoneLabel

    local mobZoneLabel = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mobZoneLabel:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 8, TRENDS_SECTION_MOB_BASELINE_Y + TRENDS_SECTION_ZONE_LABEL_Y_OFFSET)
    mobZoneLabel:SetText("|cff59d9ffMob Deaths|r")
    mobZoneLabel:Hide()
    panel.sectionMobZoneLabel = mobZoneLabel

    -- Average reference line per zone, spanning the full chart width -- the number itself is shown
    -- in the zone title text (see bossZoneLabel/mobZoneLabel above and their Refresh-time update),
    -- per user request 2026-09-30 ("the Avg amount should be next to the Boss Deaths text") rather
    -- than as its own separate floating label on the line, like Boss Pacing's Avg/Best treatment
    -- originally used.
    local function createSectionReferenceLine()
        local line = scrollContent:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 0.85, 0.3, 0.65)
        line:SetHeight(1)
        line:Hide()
        return line
    end
    panel.sectionBossAvgLine = createSectionReferenceLine()
    panel.sectionMobAvgLine = createSectionReferenceLine()

    local columnHeight = trendsScrollContentHeight
    panel.columns = {}
    for index = 1, TRENDS_ROW_POOL do
        local col = CreateFrame("Button", nil, scrollContent)
        col:SetSize(TRENDS_COL_WIDTH, columnHeight)

        col.bar = col:CreateTexture(nil, "ARTWORK")
        col.bar:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, TRENDS_BASELINE_Y)
        col.bar:SetWidth(TRENDS_COL_WIDTH)

        col.yourDeathsLabel = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.yourDeathsLabel:SetPoint("BOTTOM", col.bar, "TOP", 0, 2)
        col.yourDeathsLabel:SetTextColor(1, 0.35, 0.35)

        -- Second bar/label pair for Per Section view's boss zone -- col.bar/yourDeathsLabel double
        -- as the MOB zone bar there (repositioned to TRENDS_SECTION_MOB_BASELINE_Y), while these
        -- are the BOSS zone's own bar/label at TRENDS_SECTION_BOSS_BASELINE_Y, so one column can
        -- show both a mob death count AND a boss death count for the same encounter position at
        -- once (mirroring Boss Pacing's own pull-bar/fight-bar pair per column).
        -- Centered (TRENDS_SECTION_BAR_X, not 0) so the bar sits under its boss-name label instead
        -- of the column's left edge -- this bar is ONLY ever used in the sections view (unlike
        -- col.bar, which doubles as the perrun view's bar and needs to stay repositionable), so its
        -- x-offset can just be fixed here at build time.
        col.bossBar = col:CreateTexture(nil, "ARTWORK")
        col.bossBar:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", TRENDS_SECTION_BAR_X, TRENDS_SECTION_BOSS_BASELINE_Y)
        col.bossBar:SetWidth(TRENDS_COL_WIDTH)
        col.bossBar:Hide()

        col.bossDeathsLabel = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.bossDeathsLabel:SetPoint("BOTTOM", col.bossBar, "TOP", 0, 2)
        col.bossDeathsLabel:SetTextColor(1, 0.35, 0.35)
        col.bossDeathsLabel:Hide()

        col.dateLabel = col:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        col.dateLabel:SetPoint("BOTTOM", col, "BOTTOMLEFT", TRENDS_COL_WIDTH / 2, 4)
        col.dateLabel:SetWidth(TRENDS_COL_SPACING)

        -- Per-column "Mobs -> Boss N" detail, sections view only -- per user request 2026-09-30
        -- ("provide details for the mob section please like mobs till boss 1"). Sits in the gap
        -- between the two zones (just below the mob bars' own baseline), fixed position since this
        -- label, like col.bossBar above, is only ever used in the sections view.
        col.mobSectionLabel = col:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        col.mobSectionLabel:SetPoint("BOTTOM", col, "BOTTOMLEFT", TRENDS_SECTION_COL_SPACING / 2, TRENDS_SECTION_MOB_BASELINE_Y - 20)
        col.mobSectionLabel:SetWidth(TRENDS_SECTION_COL_SPACING - 6)
        col.mobSectionLabel:SetTextColor(0.59, 0.85, 1)
        col.mobSectionLabel:Hide()

        -- Generic tooltip 2026-09-30 (was hardcoded to per-run "point" data only) -- tooltipTitle/
        -- tooltipLines ({text, r, g, b}) let RefreshTrendsTabContent populate the same column pool
        -- for the Per Section view too, not just Deaths Per Run.
        col:SetScript("OnEnter", function(self)
            if not self.tooltipTitle then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tooltipTitle)
            for _, line in ipairs(self.tooltipLines or {}) do
                GameTooltip:AddLine(line[1], line[2] or 1, line[3] or 1, line[4] or 1)
            end
            GameTooltip:Show()
        end)
        col:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        col:Hide()
        panel.columns[index] = col
    end

    panel.help = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.help:SetPoint("BOTTOMLEFT", 0, 0)
    panel.help:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.help:SetJustifyH("LEFT")
    panel.help:SetWordWrap(true)
    panel.help:SetText("Deaths per run, across every dungeon, oldest to newest. Hover a bar for the exact breakdown. Change how many recent runs are shown with the button above.")

    self.trendsTabPanel = panel
end

function Addon:RefreshTrendsTabContent()
    local panel = self.trendsTabPanel
    if not panel then
        return
    end

    local lookback = self.db.trendsLookback or 25
    panel.lookbackButton:SetText(TRENDS_LOOKBACK_LABELS[lookback] or TRENDS_LOOKBACK_LABELS[25])

    local dungeonFilter = self.db.trendsDungeonFilter
    if dungeonFilter == "" then
        dungeonFilter = nil
    end
    do
        -- Current M+ season pool only (was every dungeon ever tracked) -- per user report/
        -- screenshot 2026-09-30 ("this should only show the current season M+ Dungeons"), same
        -- GetMythicPlusPoolEntries ground truth Progress/Boss Pacing/Season already filter by.
        local dungeonOptions = { { text = "All Dungeons", value = "" } }
        local seen = {}
        for _, entry in ipairs(self:GetMythicPlusPoolEntries()) do
            if entry.name and not seen[entry.name] then
                seen[entry.name] = true
                table.insert(dungeonOptions, { text = entry.name, value = entry.name })
            end
        end
        -- A previously-picked dungeon that's since rotated out of the pool (e.g. Gundrak, not a
        -- current-season dungeon) no longer appears as an option -- reset to "All Dungeons" rather
        -- than silently keep showing stale data for something the dropdown no longer offers.
        if dungeonFilter and not seen[dungeonFilter] then
            dungeonFilter = nil
            self.db.trendsDungeonFilter = ""
        end
        Addon:RefreshSimpleDropdown(panel.dungeonMenu, dungeonOptions, function(value)
            panel.dungeonMenu:Hide()
            Addon.db.trendsDungeonFilter = value
            Addon:RefreshTrendsTabContent()
        end)
    end
    panel.dungeonButton:SetText(dungeonFilter or "All Dungeons")

    local viewMode = self.trendsViewMode or "perrun"
    -- "Per Section" needs one specific dungeon (different dungeons have different boss counts/
    -- order) -- falls back to showing Mob vs Boss with an explanatory line instead, rather than a
    -- meaningless merged bar chart, while leaving the button/stored mode as "Per Section" so
    -- picking a dungeon afterward reveals it immediately without having to cycle the view again.
    local effectiveView = (viewMode == "sections" and not dungeonFilter) and "mobboss" or viewMode
    panel.viewButton:SetText("View: " .. (TRENDS_VIEW_LABELS[viewMode] or TRENDS_VIEW_LABELS.perrun))

    local data = self:GetTrendData(lookback, dungeonFilter)
    panel.kpis.runs.value:SetText(tostring(#data.points))
    panel.kpis.totalDeaths.value:SetText(tostring(data.totalPartyDeaths))
    panel.kpis.avgDeaths.value:SetText(string.format("%.1f", data.avgPartyDeaths))
    panel.kpis.deathFree.value:SetText(#data.points > 0 and string.format("%d (%.0f%%)", data.deathFreeRuns, (data.deathFreeRuns / #data.points) * 100) or "0")

    if self.statsHubWindow then
        self.statsHubWindow.subtitle:SetText("Trends - deaths across your last " .. tostring(#data.points) .. " run(s)")
    end

    panel.mobBossChart.frame:SetShown(effectiveView == "mobboss")
    panel.mobBossLegend:SetShown(effectiveView == "mobboss")
    panel.chartFrame:SetShown(effectiveView ~= "mobboss")

    -- Per Section's dual-zone furniture (baselines/titles/reference lines) only ever shows in that
    -- view -- hidden here up front so every other return path doesn't need its own copy of this.
    local showingSections = effectiveView == "sections"
    panel.baseline:SetShown(not showingSections)
    panel.sectionBossBaseline:SetShown(showingSections)
    panel.sectionMobBaseline:SetShown(showingSections)
    panel.sectionBossZoneLabel:SetShown(showingSections)
    panel.sectionMobZoneLabel:SetShown(showingSections)
    if not showingSections then
        panel.sectionBossAvgLine:Hide()
        panel.sectionMobAvgLine:Hide()
        for _, col in ipairs(panel.columns) do
            col.bossBar:Hide()
            col.bossDeathsLabel:Hide()
            col.mobSectionLabel:Hide()
        end
    end

    if #data.points == 0 then
        for _, col in ipairs(panel.columns) do
            col:Hide()
        end
        panel.scrollContent:SetWidth(600)
        panel.mobBossChart:Hide()
        panel.mobBossLegend:SetText("No runs recorded yet.")
        panel.help:SetText("Deaths per run, across every dungeon, oldest to newest. Hover a bar for the exact breakdown. Change how many recent runs are shown with the button above.")
        return
    end

    if effectiveView == "mobboss" then
        for _, col in ipairs(panel.columns) do
            col:Hide()
        end
        local breakdown = self:GetTrendDeathBreakdown(lookback, dungeonFilter)
        local total = breakdown.mobDeaths + breakdown.bossDeaths
        if total > 0 then
            panel.mobBossChart:SetData({
                { label = "Mob deaths", value = breakdown.mobDeaths, color = { 0.35, 0.85, 1.00 } },
                { label = "Boss deaths", value = breakdown.bossDeaths, color = { 1.00, 0.60, 0.20 } },
            })
            panel.mobBossChart.frame:Show()
        else
            panel.mobBossChart:Hide()
        end
        local legendText = string.format(
            "%d death%s across %d run%s\n|cff59d9ffMob:|r %d (%.0f%%)\n|cffff9933Boss:|r %d (%.0f%%)",
            total, total == 1 and "" or "s", breakdown.runCount, breakdown.runCount == 1 and "" or "s",
            breakdown.mobDeaths, total > 0 and (breakdown.mobDeaths / total * 100) or 0,
            breakdown.bossDeaths, total > 0 and (breakdown.bossDeaths / total * 100) or 0
        )
        if viewMode == "sections" and not dungeonFilter then
            legendText = legendText .. "\n\n|cffffcc00Pick a specific dungeon above to see the Per Section breakdown.|r"
        end
        panel.mobBossLegend:SetText(legendText)
        panel.help:SetText("Deaths classified by WHEN they happened relative to each boss's real fight timing -- during an actual boss fight counts as a boss death, anything else (travel/trash between bosses) counts as a mob death.")
        return
    end

    if effectiveView == "sections" then
        local breakdown = self:GetTrendDeathBreakdown(lookback, dungeonFilter)
        local sections = breakdown.sections
        if #sections == 0 then
            for _, col in ipairs(panel.columns) do
                col:Hide()
            end
            panel.scrollContent:SetWidth(600)
            panel.sectionBossAvgLine:Hide()
            panel.sectionMobAvgLine:Hide()
            panel.help:SetText("No deaths recorded yet for " .. tostring(dungeonFilter) .. " in this range.")
            return
        end

        -- Two independently-scaled zones -- mob (top) and boss (bottom) -- per user request
        -- 2026-09-30 ("split the boss and mobs into separate table"). Grouped by encounter index
        -- (sec.index) so a mob section and its following boss share the same column/X position,
        -- same convention Boss Pacing already uses for its own pull/fight pair per column.
        local byIndex = {}
        local maxIndex = 0
        local mobTotal, mobCount, bossTotal, bossCount = 0, 0, 0, 0
        local mobMax, bossMax = 1, 1
        for _, sec in ipairs(sections) do
            local idx = sec.index or 1
            maxIndex = math.max(maxIndex, idx)
            byIndex[idx] = byIndex[idx] or {}
            byIndex[idx][sec.type] = sec
            if sec.type == "boss" then
                bossMax = math.max(bossMax, sec.count)
                bossTotal = bossTotal + sec.count
                bossCount = bossCount + 1
            else
                mobMax = math.max(mobMax, sec.count)
                mobTotal = mobTotal + sec.count
                mobCount = mobCount + 1
            end
        end
        local mobScale = (TRENDS_SECTION_ZONE_HEIGHT * TRENDS_SECTION_ZONE_FILL_RATIO) / mobMax
        local bossScale = (TRENDS_SECTION_ZONE_HEIGHT * TRENDS_SECTION_ZONE_FILL_RATIO) / bossMax
        local contentWidth = math.max(600, panel.scrollFrame:GetWidth(), 20 + (maxIndex * TRENDS_SECTION_COL_SPACING) + 40)
        panel.scrollContent:SetWidth(contentWidth)

        for colIndex, col in ipairs(panel.columns) do
            local entry = byIndex[colIndex]
            if entry then
                local colX = 20 + (colIndex - 1) * TRENDS_SECTION_COL_SPACING
                col:ClearAllPoints()
                col:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", colX, 0)
                col:Show()

                local mobSec = entry.mob
                if mobSec then
                    col.bar:ClearAllPoints()
                    col.bar:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", TRENDS_SECTION_BAR_X, TRENDS_SECTION_MOB_BASELINE_Y)
                    col.bar:SetHeight(math.max(2, mobSec.count * mobScale))
                    col.bar:SetColorTexture(0.35, 0.85, 1.00, 0.95)
                    col.bar:Show()
                    col.yourDeathsLabel:ClearAllPoints()
                    col.yourDeathsLabel:SetPoint("BOTTOM", col.bar, "TOP", 0, 2)
                    col.yourDeathsLabel:SetText(mobSec.count > 0 and tostring(mobSec.count) or "")
                    col.yourDeathsLabel:Show()
                else
                    col.bar:Hide()
                    col.yourDeathsLabel:Hide()
                end

                local bossSec = entry.boss
                if bossSec then
                    col.bossBar:SetHeight(math.max(2, bossSec.count * bossScale))
                    col.bossBar:SetColorTexture(1.00, 0.60, 0.20, 0.95)
                    col.bossBar:Show()
                    col.bossDeathsLabel:SetText(bossSec.count > 0 and tostring(bossSec.count) or "")
                    col.bossDeathsLabel:Show()
                else
                    col.bossBar:Hide()
                    col.bossDeathsLabel:Hide()
                end

                col.dateLabel:ClearAllPoints()
                col.dateLabel:SetPoint("BOTTOM", col, "BOTTOMLEFT", TRENDS_SECTION_COL_SPACING / 2, 4)
                col.dateLabel:SetWidth(TRENDS_SECTION_COL_SPACING - 6)
                col.dateLabel:SetText((bossSec and bossSec.bossName) and bossSec.bossName or ("#" .. colIndex))

                -- "Mobs -> Boss N" per user request 2026-09-30 ("provide details for the mob
                -- section please like mobs till boss 1") -- ties the mob zone's bar back to which
                -- boss encounter it leads into, without having to look all the way down to the
                -- shared boss-name label under the boss zone.
                col.mobSectionLabel:SetText("Mobs -> Boss " .. colIndex)
                col.mobSectionLabel:Show()

                local title = bossSec and bossSec.bossName and ("Boss " .. colIndex .. ": " .. bossSec.bossName) or ("Position " .. colIndex)
                col.tooltipTitle = title
                col.tooltipLines = {
                    { string.format("Mob deaths: %d", mobSec and mobSec.count or 0), 0.5, 0.85, 1 },
                    { string.format("Boss deaths: %d", bossSec and bossSec.count or 0), 1, 0.7, 0.4 },
                }
            else
                col:Hide()
            end
        end

        -- Average reference line per zone -- a visual scale marker on the chart; the actual number
        -- is shown in the zone title itself (below), not as a separate floating label anymore.
        local function placeAvgLine(line, baselineY, avg, scale)
            if not avg or avg <= 0 then
                line:Hide()
                return
            end
            local y = baselineY + (avg * scale)
            line:ClearAllPoints()
            line:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", 0, y)
            line:SetPoint("BOTTOMRIGHT", panel.scrollContent, "BOTTOMRIGHT", 0, y)
            line:Show()
        end
        local mobAvg = mobCount > 0 and (mobTotal / mobCount) or nil
        local bossAvg = bossCount > 0 and (bossTotal / bossCount) or nil
        placeAvgLine(panel.sectionMobAvgLine, TRENDS_SECTION_MOB_BASELINE_Y, mobAvg, mobScale)
        placeAvgLine(panel.sectionBossAvgLine, TRENDS_SECTION_BOSS_BASELINE_Y, bossAvg, bossScale)

        -- Avg shown right next to each zone's title -- per user request 2026-09-30 ("the Avg
        -- amount should be next to the Boss Deaths text") -- instead of a separate floating label.
        panel.sectionMobZoneLabel:SetText(string.format("|cff59d9ffMob Deaths|r  |cffffd94dAvg %s|r", mobAvg and string.format("%.1f", mobAvg) or "-"))
        panel.sectionBossZoneLabel:SetText(string.format("|cffff9933Boss Deaths|r  |cffffd94dAvg %s|r", bossAvg and string.format("%.1f", bossAvg) or "-"))

        panel.help:SetText(string.format("Deaths per section for %s, summed across %d run%s -- top zone is travel/trash between bosses, bottom zone is the boss fights themselves. Each zone is scaled to its own max.", dungeonFilter, breakdown.runCount, breakdown.runCount == 1 and "" or "s"))
        return
    end

    -- "perrun": original per-run bar chart.
    local maxDeaths = 1
    for _, point in ipairs(data.points) do
        maxDeaths = math.max(maxDeaths, point.partyDeaths)
    end
    local scale = TRENDS_CHART_HEIGHT / maxDeaths

    if self.GetLedgerChartPage then data.points = self:GetLedgerChartPage("trends", data.points, 50, panel) end
    local TRENDS_COL_SPACING = math.max(TRENDS_COL_SPACING, (panel.scrollFrame:GetWidth()-60)/math.max(1,#data.points))
    local contentWidth = math.max(600, panel.scrollFrame:GetWidth(), 20 + (#data.points * TRENDS_COL_SPACING) + 40)
    panel.scrollContent:SetWidth(contentWidth)

    for index, col in ipairs(panel.columns) do
        local point = data.points[index]
        if point then
            local colX = 20 + (index - 1) * TRENDS_COL_SPACING
            col:ClearAllPoints()
            col:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", colX, 0)
            col:Show()

            -- Explicitly restored to the plain single-baseline position -- the Per Section view
            -- (see above) repositions this same bar to its own MOB zone baseline, so switching
            -- back to this view can't just rely on col.bar's original creation-time anchor still
            -- being in effect.
            col.bar:ClearAllPoints()
            col.bar:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, TRENDS_BASELINE_Y)
            col.yourDeathsLabel:ClearAllPoints()
            col.yourDeathsLabel:SetPoint("BOTTOM", col.bar, "TOP", 0, 2)
            col.yourDeathsLabel:Show()
            col.bar:Show()

            local barHeight = math.max(2, point.partyDeaths * scale)
            col.bar:SetHeight(barHeight)
            if point.partyDeaths == 0 then
                col.bar:SetColorTexture(0.20, 0.85, 0.30, 0.95)
            elseif point.partyDeaths <= 2 then
                col.bar:SetColorTexture(0.90, 0.70, 0.10, 0.95)
            else
                col.bar:SetColorTexture(0.85, 0.20, 0.20, 0.95)
            end

            col.yourDeathsLabel:SetText(point.yourDeaths > 0 and tostring(point.yourDeaths) or "")
            -- Explicitly restored to the narrow single-line position -- the Per Section view (see
            -- above) widens this same label for full boss names, so switching back can't just
            -- rely on the original creation-time width/position still being in effect.
            col.dateLabel:ClearAllPoints()
            col.dateLabel:SetPoint("BOTTOM", col, "BOTTOMLEFT", TRENDS_COL_WIDTH / 2, 4)
            col.dateLabel:SetWidth(TRENDS_COL_SPACING)
            col.dateLabel:SetText(point.date and point.date:match("^%d+-(%d+-%d+)") or "?")
            col.tooltipTitle = string.format("%s%s", point.name, point.keyLevel > 0 and (" +" .. point.keyLevel) or "")
            col.tooltipLines = {
                { point.date or "Unknown date", 0.8, 0.8, 0.8 },
                { string.format("Status: %s", point.status), 0.9, 0.9, 0.9 },
                { string.format("Party deaths: %d  |  Your deaths: %d", point.partyDeaths, point.yourDeaths), 1, 0.6, 0.6 },
            }
        else
            col:Hide()
        end
    end
    panel.help:SetText("Deaths per run, across every dungeon, oldest to newest. Hover a bar for the exact breakdown. Change how many recent runs are shown with the button above.")
end

-- New 2026-09-05, per user request: average boss-to-boss pacing for a chosen dungeon, over time --
-- the historical-trend half of the boss-timing feature (the per-run half lives in the Boss Menu
-- tab of Manage Data, and in this same window's Progress-tab tooltip).
-- Consolidated 2026-09-10 (see MainLayoutConst above for why) -- sequential field
-- assignment, not a single table constructor, since some of these reference earlier
-- siblings (a Lua table constructor can't reference its own sibling fields mid-literal).
local Pacing = {}
Pacing.ROW_POOL = 20
-- Split into two independently-scaled zones (mob/pull on top, boss/fight on bottom) instead of one
-- stacked bar -- per user request 2026-09-05, to actually use the chart's spare vertical space and
-- let each metric read on its own scale rather than fighting for the same one.
Pacing.ZONE_HEIGHT = 150
Pacing.ZONE_GAP = 46
Pacing.CHART_HEIGHT = (Pacing.ZONE_HEIGHT * 2) + Pacing.ZONE_GAP
Pacing.COL_WIDTH = 46
Pacing.COL_SPACING = 66
Pacing.BASELINE_Y = 46
Pacing.FIGHT_BASELINE_Y = Pacing.BASELINE_Y
Pacing.PULL_BASELINE_Y = Pacing.BASELINE_Y + Pacing.ZONE_HEIGHT + Pacing.ZONE_GAP
Pacing.LOOKBACK = 15
-- Fixed 2026-09-07, per user report with a screenshot: the tallest bar in a zone always reached
-- the FULL zone height by definition (it sets the scale), leaving zero room between its own
-- value label and the zone title sitting right above -- "the mob title is being hidden by the mob
-- bars." Bars now only ever fill this fraction of the zone, reserving the rest purely as headroom
-- for the tallest bar's own label plus the zone title above it.
Pacing.ZONE_FILL_RATIO = 0.78
-- The chart's left margin used to be a bare 20px -- barely wider than column 1 itself -- so
-- whichever zone's Avg/Best reference labels (both previously stacked at the same X) landed at a
-- similar height to column 1's own bar always overlapped it. Reserves real room for both labels
-- side by side before the first column starts.
Pacing.CHART_LEFT_MARGIN = 170

function Addon:GetBossPacingData(dungeonName, limit)
    limit = limit or Pacing.LOOKBACK
    if not dungeonName then
        return { points = {}, runCount = 0 }
    end

    -- Restricted to the current Mythic+ season only, per user request 2026-09-05 -- pacing from a
    -- past season (different affixes, different tuning) isn't a meaningful comparison against how
    -- you're running the dungeon now. Same `RunMatchesCurrentSeason` predicate the Data Tools "Show
    -- Current Mythic+ Season" run filter already uses.
    local runs = {}
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and run.instanceName == dungeonName and self:IsMythicPlusRun(run) and self:RunMatchesCurrentSeason(run) then
            local status = self:GetRunStatus(run)
            if status == "Completed" or status == "CompletedOvertime" then
                table.insert(runs, run)
                if #runs >= limit then
                    break
                end
            end
        end
    end

    -- Aggregated by boss POSITION (kill order index), not by name -- a dungeon's boss order is
    -- stable across runs, so this lines up the same boss across every sampled run even if a name
    -- ever changes (patch rename, localization, etc.).
    local positions = {}
    local maxIndex = 0
    for _, run in ipairs(runs) do
        for index, segment in ipairs(self:GetBossSegmentTimings(run)) do
            local bucket = positions[index]
            if not bucket then
                bucket = { pullTotal = 0, pullCount = 0, fightTotal = 0, fightCount = 0, lumpedTotal = 0, lumpedCount = 0, mobKillTotal = 0, mobKillCount = 0 }
                positions[index] = bucket
            end
            bucket.bossName = segment.bossName
            if segment.pullSeconds and segment.fightSeconds then
                bucket.pullTotal = bucket.pullTotal + segment.pullSeconds
                bucket.pullCount = bucket.pullCount + 1
                bucket.fightTotal = bucket.fightTotal + segment.fightSeconds
                bucket.fightCount = bucket.fightCount + 1
            end
            if segment.pullMobKillCount then
                bucket.mobKillTotal = bucket.mobKillTotal + segment.pullMobKillCount
                bucket.mobKillCount = bucket.mobKillCount + 1
            end
            bucket.lumpedTotal = bucket.lumpedTotal + segment.segmentSeconds
            bucket.lumpedCount = bucket.lumpedCount + 1
            maxIndex = math.max(maxIndex, index)
        end
    end

    local points = {}
    for index = 1, maxIndex do
        local bucket = positions[index]
        if bucket then
            local bossName = bucket.bossName or ("Boss " .. index)
            table.insert(points, {
                position = index,
                bossName = bossName,
                columnLabel = bossName,
                tooltipSubtitle = nil,
                avgPull = bucket.pullCount > 0 and (bucket.pullTotal / bucket.pullCount) or nil,
                avgFight = bucket.fightCount > 0 and (bucket.fightTotal / bucket.fightCount) or nil,
                avgLumped = bucket.lumpedCount > 0 and (bucket.lumpedTotal / bucket.lumpedCount) or 0,
                avgMobKillCount = bucket.mobKillCount > 0 and (bucket.mobKillTotal / bucket.mobKillCount) or nil,
                sampleCount = bucket.lumpedCount,
                splitSampleCount = bucket.pullCount,
            })
        end
    end

    return { points = points, runCount = #runs }
end

-- The per-run drill-down for one specific boss (by kill-order position within dungeonName) --
-- same point shape as GetBossPacingData (columnLabel/avgPull/avgFight/avgLumped/sampleCount) so
-- the chart-rendering code doesn't need to branch on which mode it's showing.
function Addon:GetBossPacingRunHistory(dungeonName, bossPosition, limit)
    limit = limit or Pacing.LOOKBACK
    if not dungeonName or not bossPosition then
        return { points = {}, runCount = 0 }
    end

    local runs = {}
    for _, runID in ipairs(self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and run.instanceName == dungeonName and self:IsMythicPlusRun(run) and self:RunMatchesCurrentSeason(run) then
            local status = self:GetRunStatus(run)
            if status == "Completed" or status == "CompletedOvertime" then
                table.insert(runs, run)
                if #runs >= limit then
                    break
                end
            end
        end
    end
    -- runOrder is newest-first; reverse so the chart reads oldest -> newest, matching every other
    -- per-run chart in this addon (Progress, Trends).
    for i = 1, math.floor(#runs / 2) do
        runs[i], runs[#runs - i + 1] = runs[#runs - i + 1], runs[i]
    end

    local points = {}
    for _, run in ipairs(runs) do
        local segment = self:GetBossSegmentTimings(run)[bossPosition]
        if segment then
            local dateLabel = run.startedAtText and run.startedAtText:match("^%d+-(%d+-%d+)") or "?"
            local keyLevel = self:GetRunKeyLevel(run)
            table.insert(points, {
                bossName = segment.bossName,
                keyLevel = keyLevel,
                runID = run.id,
                columnLabel = dateLabel .. (keyLevel > 0 and (" +" .. keyLevel) or ""),
                tooltipSubtitle = run.startedAtText,
                avgPull = segment.pullSeconds,
                avgFight = segment.fightSeconds,
                avgLumped = segment.segmentSeconds,
                avgMobKillCount = segment.pullMobKillCount,
                sampleCount = 1,
            })
        end
    end

    return { points = points, runCount = #points }
end

function Addon:BuildBossPacingTabContent(panel)
    -- Per user request 2026-09-05: a real dropdown instead of prev/next arrows, plus a second
    -- dropdown to pick one specific boss within the selected dungeon (linked to it -- its options
    -- are rebuilt from that dungeon's own boss list every time the dungeon changes).
    local dungeonButton, dungeonMenu = CreateStatsHubDropdown(panel, 260)
    dungeonButton:SetPoint("TOPLEFT", 0, 0)
    panel.dungeonButton = dungeonButton
    panel.dungeonMenu = dungeonMenu

    local bossButton, bossMenu = CreateStatsHubDropdown(panel, 220)
    bossButton:SetPoint("LEFT", dungeonButton, "RIGHT", 8, 0)
    panel.bossButton = bossButton
    panel.bossMenu = bossMenu

    -- Refresh button removed 2026-09-30 per user report ("do nothing from what i see") -- this
    -- tab only shows locally-tracked run history, already re-rendered on every dungeon/boss pick
    -- and every time this tab becomes active (ShowStatsHubTab), so a manual button never had a
    -- scenario the other controls hadn't already covered.

    local stats = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stats:SetPoint("TOPLEFT", 0, -36)
    stats:SetPoint("TOPRIGHT", 0, -36)
    stats:SetJustifyH("LEFT")
    panel.stats = stats

    local legend = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    legend:SetPoint("TOPLEFT", 0, -58)
    legend:SetText("|cff59d9ffCyan|r = pull/travel time since the previous boss   |cffff9933Orange|r = the boss fight itself. \"All Bosses\" averages one bar per boss over your last " .. Pacing.LOOKBACK .. " completed runs THIS SEASON; pick a specific boss to see it broken out run by run instead.")
    panel.legend = legend

    local chartFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    chartFrame:SetPoint("TOPLEFT", 0, -86)
    chartFrame:SetPoint("BOTTOMRIGHT", 0, 32)
    chartFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    chartFrame:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))

    local scrollFrame = CreateFrame("ScrollFrame", nil, chartFrame)
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self:GetHorizontalScrollRange())
        local target = math.max(0, math.min(maxScroll, (self.targetScroll or self:GetHorizontalScroll()) - (delta * 60)))
        self.targetScroll = target
    end)
    scrollFrame:SetScript("OnUpdate", function(self, elapsed)
        local target = self.targetScroll
        if not target then
            return
        end
        local current = self:GetHorizontalScroll()
        if math.abs(target - current) < 0.5 then
            self:SetHorizontalScroll(target)
            self.targetScroll = nil
            return
        end
        self:SetHorizontalScroll(current + (target - current) * math.min(1, elapsed * 12))
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(600, Pacing.CHART_HEIGHT + 60)
    scrollFrame:SetScrollChild(scrollContent)
    panel.scrollFrame = scrollFrame
    panel.scrollContent = scrollContent

    -- Two independent baselines -- fight (boss) zone on the bottom, pull (mob/travel) zone on top,
    -- each scaled to its own max instead of sharing one stacked bar's scale.
    local fightBaseline = scrollContent:CreateTexture(nil, "ARTWORK")
    fightBaseline:SetColorTexture(1, 1, 1, 0.15)
    fightBaseline:SetHeight(1)
    fightBaseline:SetPoint("BOTTOMLEFT", scrollContent, "BOTTOMLEFT", 0, Pacing.FIGHT_BASELINE_Y)
    fightBaseline:SetPoint("BOTTOMRIGHT", scrollContent, "BOTTOMRIGHT", 0, Pacing.FIGHT_BASELINE_Y)

    local pullBaseline = scrollContent:CreateTexture(nil, "ARTWORK")
    pullBaseline:SetColorTexture(1, 1, 1, 0.15)
    pullBaseline:SetHeight(1)
    pullBaseline:SetPoint("BOTTOMLEFT", scrollContent, "BOTTOMLEFT", 0, Pacing.PULL_BASELINE_Y)
    pullBaseline:SetPoint("BOTTOMRIGHT", scrollContent, "BOTTOMRIGHT", 0, Pacing.PULL_BASELINE_Y)

    -- Found and fixed a real bug 2026-09-05 (user screenshot: these overlapped the bars/reference
    -- lines instead of sitting above them): both labels anchored to scrollFrame's TOPLEFT using a
    -- NEGATED baseline-from-bottom value as the offset -- mixing a bottom-relative measurement into
    -- a top-relative anchor, which placed "Boss Fight" way up near the top of the chart instead of
    -- above its own zone. Baselines themselves anchor to BOTTOMLEFT with a positive offset (see
    -- fightBaseline/pullBaseline above) -- these now do the same.
    --
    -- Fixed again 2026-09-07, per user report with a screenshot: the tallest bar in a zone always
    -- reaches the full zone height by definition (it's what sets the scale), so anchoring the title
    -- only 6px above that gave zero real clearance -- the tallest bar's own value label sat right
    -- on top of the zone title ("the mob title is being hidden by the mob bars"). Now anchored just
    -- above the REDUCED max a bar can actually reach (Pacing.ZONE_FILL_RATIO), with real headroom.
    local PACING_ZONE_LABEL_Y_OFFSET = (Pacing.ZONE_HEIGHT * Pacing.ZONE_FILL_RATIO) + 20
    local fightZoneLabel = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fightZoneLabel:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 8, Pacing.FIGHT_BASELINE_Y + PACING_ZONE_LABEL_Y_OFFSET)
    fightZoneLabel:SetText("|cffff9933Boss Fight|r")

    local pullZoneLabel = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pullZoneLabel:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 8, Pacing.PULL_BASELINE_Y + PACING_ZONE_LABEL_Y_OFFSET)
    pullZoneLabel:SetText("|cff59d9ffMob / Pull|r")

    -- Average + Best (fastest) reference lines, one pair per zone, spanning the full chart width --
    -- per user request. Positioned per-refresh based on the values actually shown.
    local function createReferenceLine(color)
        local line = scrollContent:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(color[1], color[2], color[3], 0.65)
        line:SetHeight(1)
        line:Hide()
        local label = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:Hide()
        return line, label
    end
    panel.fightAvgLine, panel.fightAvgLabel = createReferenceLine({ 1, 0.85, 0.3 })
    panel.fightBestLine, panel.fightBestLabel = createReferenceLine({ 0.3, 1, 0.4 })
    panel.pullAvgLine, panel.pullAvgLabel = createReferenceLine({ 1, 0.85, 0.3 })
    panel.pullBestLine, panel.pullBestLabel = createReferenceLine({ 0.3, 1, 0.4 })

    panel.columns = {}
    for index = 1, Pacing.ROW_POOL do
        local col = CreateFrame("Button", nil, scrollContent)
        col:SetSize(Pacing.COL_WIDTH, Pacing.CHART_HEIGHT + 60)

        -- Separate bars now, each growing from its OWN zone's baseline -- no longer stacked.
        col.fightBar = col:CreateTexture(nil, "ARTWORK")
        col.fightBar:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, Pacing.FIGHT_BASELINE_Y)
        col.fightBar:SetWidth(Pacing.COL_WIDTH)
        col.fightBar:SetColorTexture(1, 0.6, 0.2, 0.95)

        col.pullBar = col:CreateTexture(nil, "ARTWORK")
        col.pullBar:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, Pacing.PULL_BASELINE_Y)
        col.pullBar:SetWidth(Pacing.COL_WIDTH)
        col.pullBar:SetColorTexture(0.35, 0.85, 1, 0.95)

        col.fightLabel = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.pullLabel = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

        col.nameLabel = col:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        col.nameLabel:SetPoint("BOTTOM", col, "BOTTOMLEFT", Pacing.COL_WIDTH / 2, 4)
        col.nameLabel:SetWidth(Pacing.COL_SPACING)
        col.nameLabel:SetWordWrap(true)

        col:SetScript("OnEnter", function(self)
            local point = self.point
            if not point then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(point.bossName)
            if point.tooltipSubtitle then
                GameTooltip:AddLine(point.tooltipSubtitle, 0.8, 0.8, 0.8)
            end
            local prefix = point.tooltipSubtitle and "" or "Avg "
            if point.avgPull and point.avgFight then
                local pullLine = string.format("%sPull: %s", prefix, FormatDuration(point.avgPull))
                -- Trash-mob count for this same pull window, per user request 2026-09-05 ("extend
                -- Boss Pacing to trash too") -- Pull already measured this whole window's
                -- duration, this says how much of it was actually spent killing trash.
                if point.avgMobKillCount and point.avgMobKillCount > 0 then
                    pullLine = pullLine .. string.format(" (%.0f trash mob%s)", point.avgMobKillCount, point.avgMobKillCount == 1 and "" or "s")
                end
                GameTooltip:AddLine(pullLine, 0.35, 0.85, 1)
                GameTooltip:AddLine(string.format("%sFight: %s", prefix, FormatDuration(point.avgFight)), 1, 0.6, 0.2)
            else
                GameTooltip:AddLine("No pull/fight split yet -- needs a run tracked live since this feature shipped.", 0.8, 0.8, 0.8)
            end
            GameTooltip:AddLine(string.format("%sTotal since previous boss: %s", prefix, FormatDuration(point.avgLumped)), 0.9, 0.9, 0.9)
            if not point.tooltipSubtitle then
                GameTooltip:AddLine(string.format("Sample size: %d run(s)", point.sampleCount), 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        col:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        col:Hide()
        panel.columns[index] = col
    end

    panel.help = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.help:SetPoint("BOTTOMLEFT", 0, 0)
    panel.help:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.help:SetJustifyH("LEFT")
    panel.help:SetWordWrap(true)
    panel.help:SetText("Only encounters tracked live since this feature shipped have a real pull/fight split -- older runs and manual Boss Menu entries show as a single gray bar (total time since the previous boss) instead. The number in parentheses under a Pull bar is how many trash mobs died during that pull.")

    self.pacingTabPanel = panel
end

-- dungeonName: pass to switch dungeons (also resets the boss selection back to "All Bosses",
-- since boss positions are dungeon-specific). bossPosition: pass explicitly to switch which boss
-- is shown for the CURRENT dungeon; omit to keep whatever was last selected.
function Addon:RefreshBossPacingTabContent(dungeonName, bossPosition)
    local panel = self.pacingTabPanel
    if not panel then
        return
    end

    local dungeonChanged = dungeonName ~= nil and dungeonName ~= self.pacingDungeonName
    dungeonName = dungeonName or self.pacingDungeonName
    -- Defaults to the last run's dungeon rather than an empty state, per user request 2026-09-30
    -- ("make them pull up the last run by default").
    if not dungeonName then
        local lastRun = self:GetLastRun()
        dungeonName = lastRun and lastRun.instanceName
    end
    self.pacingDungeonName = dungeonName
    if dungeonChanged then
        self.pacingBossPosition = nil
    end
    if bossPosition ~= nil then
        self.pacingBossPosition = (bossPosition ~= 0) and bossPosition or nil
    end

    if self.statsHubWindow then
        self.statsHubWindow.subtitle:SetText(dungeonName and ("Boss Pacing - " .. dungeonName) or "Boss Pacing")
    end

    -- Dungeon dropdown: found via user report 2026-09-05 -- GetProgressTabDungeonList (shared with
    -- the Progress tab) also mixes in every dungeon you've EVER run (GetRecentDungeonSummaries),
    -- including old/timewalking/raid instances no longer in rotation, which doesn't fit Boss
    -- Pacing now that it's restricted to the current season's data anyway (selecting one just
    -- showed "no completed runs this season"). Uses GetMythicPlusPoolEntries directly instead --
    -- only the dungeons actually in the current Mythic+ pool.
    local dungeonOptions = {}
    for _, entry in ipairs(self:GetMythicPlusPoolEntries()) do
        if entry.name then
            table.insert(dungeonOptions, { text = entry.name, value = entry.name })
        end
    end
    panel.dungeonButton:SetText(dungeonName or "Select a dungeon")
    Addon:RefreshSimpleDropdown(panel.dungeonMenu, dungeonOptions, function(value)
        panel.dungeonMenu:Hide()
        Addon:RefreshBossPacingTabContent(value)
    end)

    local function hidePacingReferenceLines()
        panel.fightAvgLine:Hide()
        panel.fightAvgLabel:Hide()
        panel.fightBestLine:Hide()
        panel.fightBestLabel:Hide()
        panel.pullAvgLine:Hide()
        panel.pullAvgLabel:Hide()
        panel.pullBestLine:Hide()
        panel.pullBestLabel:Hide()
    end

    if not dungeonName then
        panel.bossButton:SetText("All Bosses")
        Addon:RefreshSimpleDropdown(panel.bossMenu, {}, function() end)
        panel.stats:SetText("Pick a dungeon above to see its average boss pacing.")
        for _, col in ipairs(panel.columns) do
            col:Hide()
        end
        hidePacingReferenceLines()
        return
    end

    -- Boss dropdown: rebuilt from THIS dungeon's own boss list every refresh, so it's always
    -- linked to whatever dungeon is currently selected -- picking a different dungeon above
    -- rebuilds this with that dungeon's bosses, not the previous one's.
    local allData = self:GetBossPacingData(dungeonName, Pacing.LOOKBACK)
    local bossOptions = { { text = "All Bosses", value = 0 } }
    for _, point in ipairs(allData.points) do
        table.insert(bossOptions, { text = point.bossName, value = point.position })
    end
    panel.bossButton:SetText(self.pacingBossPosition and (allData.points[self.pacingBossPosition] and allData.points[self.pacingBossPosition].bossName or ("Boss " .. self.pacingBossPosition)) or "All Bosses")
    Addon:RefreshSimpleDropdown(panel.bossMenu, bossOptions, function(value)
        panel.bossMenu:Hide()
        Addon:RefreshBossPacingTabContent(dungeonName, value)
    end)

    local data
    if self.pacingBossPosition then
        data = self:GetBossPacingRunHistory(dungeonName, self.pacingBossPosition, Pacing.LOOKBACK)
    else
        data = allData
    end

    if #data.points == 0 then
        panel.stats:SetText(self.pacingBossPosition
            and ("No completed runs of " .. dungeonName .. " this season have a recorded kill for that boss yet.")
            or ("No completed Mythic+ runs recorded yet for " .. dungeonName .. " this season."))
        for _, col in ipairs(panel.columns) do
            col:Hide()
        end
        hidePacingReferenceLines()
        panel.scrollContent:SetWidth(600)
        return
    end

    if self.pacingBossPosition then
        panel.stats:SetText(string.format("%s: %d completed run(s) of %s this season, oldest to newest.", data.points[1] and data.points[1].bossName or "Boss", data.runCount, dungeonName))
    else
        panel.stats:SetText(string.format("Averaged over %d completed run(s) of %s this season.", data.runCount, dungeonName))
    end

    -- Each zone scales to its OWN max now (not a shared stacked-bar scale), and average/best
    -- (fastest) reference lines are computed from whichever split values are actually on screen --
    -- per user request, to compare an individual bar against your own average/best at a glance.
    local maxFight, maxPull, maxLumped = 1, 1, 1
    local fightTotal, fightCount, fightBest = 0, 0, nil
    local pullTotal, pullCount, pullBest = 0, 0, nil
    for _, point in ipairs(data.points) do
        maxLumped = math.max(maxLumped, point.avgLumped)
        if point.avgFight then
            maxFight = math.max(maxFight, point.avgFight)
            fightTotal = fightTotal + point.avgFight
            fightCount = fightCount + 1
            fightBest = fightBest and math.min(fightBest, point.avgFight) or point.avgFight
        end
        if point.avgPull then
            maxPull = math.max(maxPull, point.avgPull)
            pullTotal = pullTotal + point.avgPull
            pullCount = pullCount + 1
            pullBest = pullBest and math.min(pullBest, point.avgPull) or point.avgPull
        end
    end
    -- Columns with no split fall back to a single gray bar in the fight zone showing the lumped
    -- total (see the per-column loop below) -- that zone's scale needs to fit those too.
    maxFight = math.max(maxFight, maxLumped)
    -- Bars now only ever fill Pacing.ZONE_FILL_RATIO of the zone (see that constant's comment) --
    -- reserving the rest as headroom so the tallest bar's own label never runs into the zone title.
    local fightScale = (Pacing.ZONE_HEIGHT * Pacing.ZONE_FILL_RATIO) / maxFight
    local pullScale = (Pacing.ZONE_HEIGHT * Pacing.ZONE_FILL_RATIO) / maxPull

    -- xOffset added 2026-09-07, per user report ("the best and Avg should be side by side not on
    -- top of each other"): Avg and Best used to both anchor at the same X, so whenever their
    -- values landed close together in height, the two labels printed on top of one another. Each
    -- pair now gets its own fixed column (see the call sites below) so they always read side by
    -- side regardless of how close the underlying values are.
    local function placeReferenceLine(line, label, text, baselineY, value, scale, xOffset)
        if not value then
            line:Hide()
            label:Hide()
            return
        end
        local y = baselineY + math.min(Pacing.ZONE_HEIGHT * Pacing.ZONE_FILL_RATIO, value * scale)
        line:ClearAllPoints()
        line:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", 0, y)
        line:SetPoint("BOTTOMRIGHT", panel.scrollContent, "BOTTOMRIGHT", 0, y)
        line:Show()
        label:ClearAllPoints()
        label:SetPoint("BOTTOMLEFT", panel.scrollFrame, "BOTTOMLEFT", xOffset, y - 6)
        label:SetText(text)
        label:Show()
    end
    placeReferenceLine(panel.fightAvgLine, panel.fightAvgLabel, "|cffffd94dAvg " .. FormatDuration(fightCount > 0 and (fightTotal / fightCount) or 0) .. "|r", Pacing.FIGHT_BASELINE_Y, fightCount > 0 and (fightTotal / fightCount) or nil, fightScale, 12)
    placeReferenceLine(panel.fightBestLine, panel.fightBestLabel, "|cff4dff66Best " .. FormatDuration(fightBest or 0) .. "|r", Pacing.FIGHT_BASELINE_Y, fightBest, fightScale, 100)
    placeReferenceLine(panel.pullAvgLine, panel.pullAvgLabel, "|cffffd94dAvg " .. FormatDuration(pullCount > 0 and (pullTotal / pullCount) or 0) .. "|r", Pacing.PULL_BASELINE_Y, pullCount > 0 and (pullTotal / pullCount) or nil, pullScale, 12)
    placeReferenceLine(panel.pullBestLine, panel.pullBestLabel, "|cff4dff66Best " .. FormatDuration(pullBest or 0) .. "|r", Pacing.PULL_BASELINE_Y, pullBest, pullScale, 100)

    local contentWidth = math.max(600, panel.scrollFrame:GetWidth(), Pacing.CHART_LEFT_MARGIN + (#data.points * Pacing.COL_SPACING) + 40)
    panel.scrollContent:SetWidth(contentWidth)

    for index, col in ipairs(panel.columns) do
        local point = data.points[index]
        if point then
            local colX = Pacing.CHART_LEFT_MARGIN + (index - 1) * Pacing.COL_SPACING
            col.point = point
            col:ClearAllPoints()
            col:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", colX, 0)
            col:Show()

            if point.avgPull and point.avgFight then
                col.fightBar:SetColorTexture(1, 0.6, 0.2, 0.95)
                col.fightBar:SetHeight(math.max(1, point.avgFight * fightScale))
                col.fightBar:Show()
                col.fightLabel:ClearAllPoints()
                col.fightLabel:SetPoint("BOTTOM", col.fightBar, "TOP", 0, 2)
                col.fightLabel:SetText(FormatDuration(point.avgFight))
                col.fightLabel:Show()

                col.pullBar:SetHeight(math.max(1, point.avgPull * pullScale))
                col.pullBar:Show()
                col.pullLabel:ClearAllPoints()
                col.pullLabel:SetPoint("BOTTOM", col.pullBar, "TOP", 0, 2)
                -- Trash-mob count appended inline (not a 2nd line) to avoid growing into the "Mob /
                -- Pull" zone label above -- per user request 2026-09-05 ("extend Boss Pacing to
                -- trash too"), visible on the chart itself, not just the tooltip.
                local pullText = FormatDuration(point.avgPull)
                if point.avgMobKillCount and point.avgMobKillCount > 0 then
                    pullText = pullText .. string.format(" (%.0f)", point.avgMobKillCount)
                end
                col.pullLabel:SetText(pullText)
                col.pullLabel:Show()
            else
                -- No live-tracked split for this boss position yet -- one plain gray bar in the
                -- fight zone showing the lumped total instead of leaving both zones blank.
                col.fightBar:SetColorTexture(0.5, 0.5, 0.5, 0.7)
                col.fightBar:SetHeight(math.max(1, point.avgLumped * fightScale))
                col.fightBar:Show()
                col.fightLabel:ClearAllPoints()
                col.fightLabel:SetPoint("BOTTOM", col.fightBar, "TOP", 0, 2)
                col.fightLabel:SetText(FormatDuration(point.avgLumped) .. " (total)")
                col.fightLabel:Show()

                col.pullBar:Hide()
                col.pullLabel:Hide()
            end
            col.nameLabel:SetText(point.columnLabel or point.bossName)
        else
            col.point = nil
            col:Hide()
        end
    end
end

local PROGRESS_POOL_SIZE = 150
local PROGRESS_CHART_HEIGHT = 300
local PROGRESS_COL_WIDTH = 34
local PROGRESS_COL_SPACING = 54
local PROGRESS_BASELINE_Y = 46
-- Duration view only, per user request 2026-09-07 ("move the table to the right, and then have
-- time indicators in intervals"): the bars used to start right at x=20, crowding the "^ Duration"
-- axis title and leaving no room for a real Y-axis. This margin makes space on the left for the
-- new duration gridline labels (see PROGRESS_DURATION_GRID_POOL below) before the first bar.
local PROGRESS_DURATION_LEFT_MARGIN = 60
local PROGRESS_DURATION_GRID_POOL = 14
-- Recolored 2026-09-05 per user request ("hard to see the stats"): darker/truer hues so the three
-- statuses read apart clearly, and a color reserved just for Key Level (see PROGRESS_KEY_LEVEL_COLOR
-- below) that doesn't repeat any of these or PROGRESS_BOSS_PALETTE.
local PROGRESS_STATUS_COLORS_DEFAULT = {
    Completed = { 0.05, 0.50, 0.14 },
    CompletedOvertime = { 0.95, 0.45, 0.05 },
    Abandoned = { 0.55, 0.05, 0.05 },
    Active = { 0.25, 0.55, 0.95 },
}
-- Same metatable customization as STATUS_BACKDROP_COLORS above -- one picked color per status
-- applies to both this (brighter, opaque bar-fill) table and that (darker, translucent backdrop)
-- one at once.
local PROGRESS_STATUS_COLORS = setmetatable({}, {
    __index = function(_, status)
        return Addon:GetCustomStatusColor(status) or PROGRESS_STATUS_COLORS_DEFAULT[status]
    end,
})
-- Vivid magenta -- not used anywhere else on Progress (not a status color, not in the boss
-- palette below) so the Key Level line/dots are never confused with anything else on the chart.
local PROGRESS_KEY_LEVEL_COLOR = { 1.00, 0.10, 0.80 }
-- Best-run ring: bright white reads clearly against all three (now darker) status colors.
local PROGRESS_BEST_RING_COLOR = { 1.00, 1.00, 1.00, 0.95 }

-- New 2026-09-05, per user request for more visual variety on Progress: a "Chart View" selector
-- cycling between four ways to look at the same run history, instead of only the one duration-bar
-- chart. WoW's UI toolkit has no native chart widgets -- everything here (including what already
-- existed) is hand-built from colored Texture rectangles, so these four all reuse the same
-- primitives rather than needing anything exotic.
-- Scatter and Heatmap Calendar views removed 2026-09-30 per user request (Scatter was "very hard
-- to understand" with no clear axis story, Heatmap was "not required") -- Boss Splits and Duration
-- cover the same ground (key level vs. deaths is visible per-column in Duration's hover tooltip
-- already; activity-over-time isn't something this addon needs a dedicated calendar for).
local PROGRESS_VIEW_MODES = { "duration", "bosssplits" }
local PROGRESS_VIEW_LABELS = {
    duration = "Duration",
    bosssplits = "Boss Splits",
}
-- Distinct color per boss KILL-ORDER POSITION (not per boss name -- a dungeon's boss order is
-- stable across runs, same reasoning as Boss Pacing's own per-position aggregation), so the same
-- position reads as the same color across every run's stacked bar in Boss Splits view.
local PROGRESS_BOSS_PALETTE = {
    { 0.35, 0.85, 1.00 },
    { 1.00, 0.60, 0.20 },
    { 0.60, 0.90, 0.30 },
    { 0.90, 0.40, 0.90 },
    { 1.00, 0.85, 0.20 },
    { 0.80, 0.30, 0.30 },
    { 0.50, 0.70, 1.00 },
    { 1.00, 1.00, 1.00 },
}
-- Point-to-point line via a rotated/stretched texture -- there's no native line widget in the
-- WoW UI toolkit, so length becomes the texture width (sqrt(dx^2+dy^2)) and the angle (atan2)
-- becomes its rotation. `line` is a pre-existing pooled texture; ax/ay/bx/by are offsets from
-- `parent`'s BOTTOMLEFT.
local function PositionTextureLine(line, parent, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then
        line:Hide()
        return
    end
    local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
    line:ClearAllPoints()
    line:SetSize(length, 2)
    line:SetPoint("CENTER", parent, "BOTTOMLEFT", ax + dx / 2, ay + dy / 2)
    if line.SetRotation then
        line:SetRotation(atan2(dy, dx))
    end
    line:Show()
end

-- Ordered list of dungeon names the Progress tab's prev/next selector cycles through -- the
-- current M+ pool first (most relevant), then any other dungeon with tracked runs.
-- showAllInstances=false (default): only this season's actual M+ pool -- fixes a real bug where
-- rotated-out/past-season dungeons kept showing up because this used to always merge in every
-- dungeon ever recorded. showAllInstances=true: every instance (dungeon AND raid) ever tracked,
-- for the user's explicit "I would also like an all instances option" request.
-- mode: true/"all" = every known instance ever (used by the Dungeon Colors window, unrelated to
-- the Progress tab's own filter button); "previous" = last season's dungeons (see
-- GetPreviousSeasonDungeonList); anything else (nil/"current") = the current M+ pool, as before.
function Addon:GetProgressTabDungeonList(mode)
    if mode == true or mode == "all" then
        return self:GetKnownInstanceNames()
    end
    if mode == "previous" then
        return self:GetPreviousSeasonDungeonList()
    end
    local seen = {}
    local names = {}
    for _, entry in ipairs(self:GetMythicPlusPoolEntries()) do
        if entry.name and not seen[entry.name] then
            seen[entry.name] = true
            table.insert(names, entry.name)
        end
    end
    return names
end

-- The exact name of the season immediately before the current one, same expansion -- e.g. if
-- GetCurrentNamedSeasonName() is "Midnight Season 2", returns "Midnight Season 1". nil if the
-- current season is Season 1 of its expansion (no same-expansion "Season 0" to fall back to) or
-- the season name doesn't parse. Shared by GetPreviousSeasonDungeonList (which dungeons) and the
-- Progress tab's filter button label -- per user follow-up 2026-09-30 ("Previous Season wording
-- might need to change, as it should refer to [the specific] previous season the dungeon was in"),
-- since a dungeon can have run through several different past seasons and "previous" alone doesn't
-- say which one is actually being shown.
function Addon:GetPreviousSeasonName()
    local currentNamed = self:GetCurrentNamedSeasonName()
    local expansionPrefix, num = currentNamed and currentNamed:match("^(.-)%s+[Ss]eason%s*(%d+)%s*$")
    num = tonumber(num)
    if not expansionPrefix or not num or num <= 1 then
        return nil
    end
    return string.format("%s Season %d", expansionPrefix, num - 1)
end

-- Dungeons confirmed (via seasonLinks) to be part of GetPreviousSeasonName(). Per user request
-- 2026-09-30 (Progress tab filter: "current season, and previous season" instead of "current
-- season, and all instances"). There's no live API for a past season's pool (only the CURRENT one
-- is ever queryable), so this relies on the same accumulating seasonLinks data
-- GetDungeonSeasonTagsText reads -- whatever this addon actually observed while that season was live.
function Addon:GetPreviousSeasonDungeonList()
    local previousSeasonName = self:GetPreviousSeasonName()
    if not previousSeasonName then
        return {}
    end
    local seen, names = {}, {}
    for name, catalog in pairs(self.db and self.db.instanceCatalog or {}) do
        if catalog.seasonLinks and catalog.seasonLinks[previousSeasonName] and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function Addon:BuildProgressTabContent(panel)
    -- Real dropdown instead of prev/next arrows -- per user request 2026-09-05, same reasoning and
    -- same CreateStatsHubDropdown builder as Boss Pacing's own dungeon selector.
    local dungeonButton, dungeonMenu = CreateStatsHubDropdown(panel, 280)
    dungeonButton:SetPoint("TOPLEFT", 0, 0)
    panel.dungeonLabel = dungeonButton
    panel.dungeonMenu = dungeonMenu

    -- Refresh button removed 2026-09-30 per user report ("look to do nothing") -- every control on
    -- this tab (dungeon picker, view cycle, filter toggle) already calls RefreshProgressTabContent
    -- itself on change, and the tab's own OnShow/tab-switch path refreshes it too, so a separate
    -- manual button never had a scenario where it did anything the others hadn't already covered.
    -- "Chart View" cycle: same run history, four different ways to look at it. See
    -- PROGRESS_VIEW_MODES -- all four are hand-built from the same Texture/FontString primitives,
    -- nothing exotic, just different arrangements of them.
    local viewButton = self:CreatePlainButton(panel, "View: Duration", 190, 24)
    viewButton:SetPoint("LEFT", dungeonButton, "RIGHT", 10, 0)
    viewButton:SetScript("OnClick", function()
        local current = self.progressChartView or "duration"
        local currentIndex = 1
        for i, mode in ipairs(PROGRESS_VIEW_MODES) do
            if mode == current then
                currentIndex = i
                break
            end
        end
        local nextMode = PROGRESS_VIEW_MODES[(currentIndex % #PROGRESS_VIEW_MODES) + 1]
        Addon.progressChartView = nextMode
        Addon:RefreshProgressTabContent()
    end)
    panel.viewButton = viewButton

    -- Filter toggle changed 2026-09-30 per user request: "current season, and previous season"
    -- instead of "current season, and all instances" (see GetPreviousSeasonDungeonList).
    local instanceFilterButton = self:CreatePlainButton(panel, "Filter: Current Season", 200, 24)
    instanceFilterButton:SetPoint("LEFT", viewButton, "RIGHT", 10, 0)
    instanceFilterButton:SetScript("OnClick", function()
        Addon.progressSeasonFilterMode = (Addon.progressSeasonFilterMode == "previous") and "current" or "previous"
        -- The currently-selected dungeon might not exist in the new list (e.g. it rotated out of
        -- the season pool) -- rather than silently keep showing stale data for it, drop back to
        -- "no dungeon selected" when that happens.
        local stillValid = false
        for _, name in ipairs(Addon:GetProgressTabDungeonList(Addon.progressSeasonFilterMode)) do
            if name == Addon.progressDungeonName then
                stillValid = true
                break
            end
        end
        Addon:RefreshProgressTabContent(stillValid and Addon.progressDungeonName or nil)
    end)
    panel.instanceFilterButton = instanceFilterButton

    -- Empty/error message -- shown INSTEAD of the KPI tile row below when there's no dungeon
    -- selected or no runs recorded yet.
    local stats = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stats:SetPoint("TOPLEFT", 0, -36)
    stats:SetPoint("TOPRIGHT", 0, -36)
    stats:SetJustifyH("LEFT")
    panel.stats = stats

    -- KPI tile row, replacing the old single text line -- per user request for a more visual
    -- summary. Same tile pattern as the Trends tab.
    -- 5th tile added 2026-09-05 per user request ("time lost to deaths... as a stat"): the
    -- Xal'atath's Guile death-timer penalty (see GetRunDeathTimePenaltySeconds), summed across
    -- whichever runs are currently shown.
    panel.kpis = {}
    local kpiDefs = { "runs", "completion", "avgDeaths", "bestRun", "deathTimeLost" }
    local kpiLabels = { runs = "Runs", completion = "Completion", avgDeaths = "Avg Deaths / Run", bestRun = "Best Run (on-time)", deathTimeLost = "Time Lost to Deaths" }
    local kpiWidth = 1052 / 5
    for index, key in ipairs(kpiDefs) do
        local tile = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        tile:SetSize(kpiWidth - 8, 64)
        tile:SetPoint("TOPLEFT", (index - 1) * kpiWidth, -36)
        tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        tile:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))
        tile:SetBackdropBorderColor(self:GetThemeBorderColor(false))

        tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tile.value:SetPoint("TOP", 0, -12)

        tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tile.label:SetPoint("BOTTOM", 0, 8)
        tile.label:SetText(kpiLabels[key])

        panel.kpis[key] = tile
    end

    local legend = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    legend:SetPoint("TOPLEFT", 0, -108)
    legend:SetPoint("TOPRIGHT", 0, -108)
    legend:SetJustifyH("LEFT")
    legend:SetWordWrap(true)
    panel.legend = legend

    local chartFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    chartFrame:SetPoint("TOPLEFT", 0, -130)
    chartFrame:SetPoint("BOTTOMRIGHT", 0, 32)
    chartFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    chartFrame:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))
    panel.chartFrame = chartFrame

    local scrollFrame = CreateFrame("ScrollFrame", nil, chartFrame)
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self:GetHorizontalScrollRange())
        local target = math.max(0, math.min(maxScroll, (self.targetScroll or self:GetHorizontalScroll()) - (delta * 60)))
        self.targetScroll = target
    end)
    scrollFrame:SetScript("OnUpdate", function(self, elapsed)
        local target = self.targetScroll
        if not target then
            return
        end
        local current = self:GetHorizontalScroll()
        if math.abs(target - current) < 0.5 then
            self:SetHorizontalScroll(target)
            self.targetScroll = nil
            return
        end
        self:SetHorizontalScroll(current + (target - current) * math.min(1, elapsed * 12))
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(600, PROGRESS_CHART_HEIGHT + 90)
    scrollFrame:SetScrollChild(scrollContent)
    panel.scrollFrame = scrollFrame
    panel.scrollContent = scrollContent

    local baseline = scrollContent:CreateTexture(nil, "ARTWORK")
    panel.baseline = baseline
    baseline:SetColorTexture(1, 1, 1, 0.15)
    baseline:SetHeight(1)
    baseline:SetPoint("BOTTOMLEFT", scrollContent, "BOTTOMLEFT", 0, PROGRESS_BASELINE_Y)
    baseline:SetPoint("BOTTOMRIGHT", scrollContent, "BOTTOMRIGHT", 0, PROGRESS_BASELINE_Y)

    -- Made more prominent per user request 2026-09-05 ("please show the dungeon time limit") --
    -- was a thin 55%-alpha 1px line easy to miss against tall bars; thicker, brighter, and the
    -- label now states the actual time (e.g. "Time Limit: 33m 00s") instead of a static caption,
    -- so it reads as real data rather than a stray line.
    -- OVERLAY (not ARTWORK) so this always draws above the bars: it was created before
    -- panel.columns below, and same-layer textures draw in creation order, so at ARTWORK it was
    -- actually rendering BEHIND every bar -- exactly the "hard to see, bars cover the line" bug.
    local limitLine = scrollContent:CreateTexture(nil, "OVERLAY", nil, 7)
    limitLine:SetColorTexture(1, 0.35, 0.35, 0.9)
    limitLine:SetHeight(2)
    limitLine:Hide()
    panel.limitLine = limitLine

    local limitLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    limitLabel:SetTextColor(1, 0.5, 0.5)
    limitLabel:SetText("Time Limit")
    limitLabel:Hide()
    panel.limitLabel = limitLabel

    -- Duration Y-axis gridlines, per user request 2026-09-07 ("time indicators please in intervals,
    -- like 3 or 5 minutes"). The line scrolls with the bars (parented to scrollContent, like
    -- limitLine above) so it stays aligned to the right height at any scroll position; the label is
    -- parented to chartFrame and anchored to scrollFrame instead (same trick Boss Pacing's Avg/Best
    -- reference labels already use) so it stays pinned to the left edge instead of scrolling away.
    panel.durationGridLines = {}
    panel.durationGridLabels = {}
    for index = 1, PROGRESS_DURATION_GRID_POOL do
        local gridLine = scrollContent:CreateTexture(nil, "ARTWORK")
        gridLine:SetColorTexture(1, 1, 1, 0.12)
        gridLine:SetHeight(1)
        gridLine:Hide()
        panel.durationGridLines[index] = gridLine

        local gridLabel = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        gridLabel:SetTextColor(0.7, 0.7, 0.7)
        gridLabel:Hide()
        panel.durationGridLabels[index] = gridLabel
    end

    panel.columns = {}
    for index = 1, PROGRESS_POOL_SIZE do
        local col = CreateFrame("Button", nil, scrollContent)
        col:SetSize(PROGRESS_COL_WIDTH, PROGRESS_CHART_HEIGHT + 90)

        -- Best-run ring: BACKGROUND layer so col.bar (ARTWORK) covers its middle, leaving only the
        -- inset margin visible as a ring. Widened from 3px to 6px and switched to bright white
        -- (was gold, too close to the overtime bar color) per user request 2026-09-05 ("gold ring
        -- is hard to see").
        col.highlight = col:CreateTexture(nil, "BACKGROUND")
        col.highlight:SetColorTexture(PROGRESS_BEST_RING_COLOR[1], PROGRESS_BEST_RING_COLOR[2], PROGRESS_BEST_RING_COLOR[3], PROGRESS_BEST_RING_COLOR[4])
        col.highlight:Hide()

        col.bestLabel = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.bestLabel:SetTextColor(1, 1, 1)
        col.bestLabel:SetText("BEST")
        col.bestLabel:Hide()

        col.bar = col:CreateTexture(nil, "ARTWORK")
        col.bar:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, PROGRESS_BASELINE_Y)
        col.bar:SetWidth(PROGRESS_COL_WIDTH)

        -- Boss Splits view stacks these instead of using the single solid col.bar -- one per boss
        -- kill-order position, colored from PROGRESS_BOSS_PALETTE, height proportional to that
        -- boss's segment time so the total stack height still equals the run's real duration.
        col.segments = {}
        for segIndex = 1, #PROGRESS_BOSS_PALETTE do
            local seg = col:CreateTexture(nil, "ARTWORK")
            seg:SetWidth(PROGRESS_COL_WIDTH)
            seg:Hide()
            col.segments[segIndex] = seg
        end

        col.keyDot = col:CreateTexture(nil, "OVERLAY", nil, 7)
        col.keyDot:SetColorTexture(PROGRESS_KEY_LEVEL_COLOR[1], PROGRESS_KEY_LEVEL_COLOR[2], PROGRESS_KEY_LEVEL_COLOR[3], 1)
        col.keyDot:SetSize(8, 8)

        col.durationLabel = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.durationLabel:SetPoint("BOTTOM", col.bar, "TOP", 0, 2)

        col.keyLabel = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.keyLabel:SetTextColor(PROGRESS_KEY_LEVEL_COLOR[1], PROGRESS_KEY_LEVEL_COLOR[2], PROGRESS_KEY_LEVEL_COLOR[3])

        col.deathLabel = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        col.deathLabel:SetPoint("BOTTOM", col, "BOTTOMLEFT", PROGRESS_COL_WIDTH / 2, 22)

        col.dateLabel = col:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        col.dateLabel:SetPoint("BOTTOM", col, "BOTTOMLEFT", PROGRESS_COL_WIDTH / 2, 4)
        col.dateLabel:SetWidth(PROGRESS_COL_SPACING)

        col:SetScript("OnEnter", function(self)
            local run = self.run
            if not run then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(Addon:GetDungeonDisplayName(run))
            GameTooltip:AddLine(run.startedAtText or "Unknown date", 0.8, 0.8, 0.8)
            GameTooltip:AddLine(string.format("Key Level: +%d", Addon:GetRunKeyLevel(run)), 1, 1, 1)
            GameTooltip:AddLine(string.format("Duration: %s", FormatDuration(GetRunDuration(run))), 1, 1, 1)
            GameTooltip:AddLine(string.format("Status: %s", Addon:GetRunDisplayStatus(run)), 1, 1, 1)
            GameTooltip:AddLine(string.format("Party Deaths: %d | Your Deaths: %d", Addon:GetRunDeathTotal(run), Addon:GetPlayerDeaths(run)), 1, 0.6, 0.6)
            local deathPenalty = Addon:GetRunDeathTimePenaltySeconds(run)
            if deathPenalty > 0 then
                GameTooltip:AddLine(string.format("Time Lost to Deaths: %s (Xal'atath's Guile)", FormatDuration(deathPenalty)), 1, 0.6, 0.6)
                local wouldHaveTimed = Addon:WouldHaveTimedWithoutDeaths(run)
                if wouldHaveTimed == true then
                    GameTooltip:AddLine("Would've timed with zero deaths!", 0.4, 1, 0.4)
                elseif wouldHaveTimed == false then
                    GameTooltip:AddLine("Still would not have timed, even with zero deaths.", 0.7, 0.7, 0.7)
                end
            end
            GameTooltip:AddLine(string.format("Repairs: %s", FormatMoneyIcons(run.repairCost or 0)), 1, 1, 1)
            local segments = Addon:GetBossSegmentTimings(run)
            if #segments > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Boss splits:", 1, 0.82, 0)
                for _, segment in ipairs(segments) do
                    if segment.pullSeconds and segment.fightSeconds then
                        GameTooltip:AddLine(string.format("  %s: %s pull + %s fight", segment.bossName, FormatDuration(segment.pullSeconds), FormatDuration(segment.fightSeconds)), 0.9, 0.9, 0.9)
                    else
                        GameTooltip:AddLine(string.format("  %s: %s", segment.bossName, FormatDuration(segment.segmentSeconds)), 0.9, 0.9, 0.9)
                    end
                end
            end
            GameTooltip:Show()
        end)
        col:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        col:Hide()
        panel.columns[index] = col
    end

    -- Dedicated overlay frame (not scrollContent itself) for the pink key-level line, given an
    -- explicitly high FrameLevel -- per user report/screenshot 2026-09-30 ("make [the pink line] in
    -- the foreground on top of the bars"). A texture owned directly by scrollContent draws BEHIND
    -- any child FRAME's own content (each `col` button is a real child frame with its own,
    -- higher, auto-assigned FrameLevel) regardless of the texture's own draw layer -- OVERLAY sublayer
    -- 7 only wins against other regions on the SAME frame, not against a separate child frame's
    -- content. This sibling frame is explicitly leveled above every col button so its line textures
    -- always composite on top of the bars, no matter the columns' own creation order.
    local lineOverlay = CreateFrame("Frame", nil, scrollContent)
    lineOverlay:SetAllPoints(scrollContent)
    lineOverlay:SetFrameLevel(scrollContent:GetFrameLevel() + 50)
    panel.lines = {}
    for index = 1, PROGRESS_POOL_SIZE do
        local line = lineOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetColorTexture(PROGRESS_KEY_LEVEL_COLOR[1], PROGRESS_KEY_LEVEL_COLOR[2], PROGRESS_KEY_LEVEL_COLOR[3], 0.9)
        line:Hide()
        panel.lines[index] = line
    end

    -- Boss Splits view (redesigned as a line graph per user request 2026-09-05): one connector
    -- line per boss kill-order position, between each pair of consecutive runs that both have a
    -- timing for that position -- reuses PROGRESS_BOSS_PALETTE so the same boss position is the
    -- same color as before. col.segments (already built above) double as that line's per-run dot
    -- markers, repurposed from their old job as stacked-bar segments.
    panel.bossLines = {}
    for segIndex = 1, #PROGRESS_BOSS_PALETTE do
        panel.bossLines[segIndex] = {}
        for index = 1, PROGRESS_POOL_SIZE do
            local line = scrollContent:CreateTexture(nil, "OVERLAY", nil, 7)
            local segColor = PROGRESS_BOSS_PALETTE[segIndex]
            line:SetColorTexture(segColor[1], segColor[2], segColor[3], 0.85)
            line:Hide()
            panel.bossLines[segIndex][index] = line
        end
    end

    -- Shared axis label FontStrings -- Duration and Boss Splits both retext these for their own
    -- axes (used to also serve the since-removed Scatter view, hence the name).
    panel.scatterXLabel = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    -- Was y=-8, which sits 8px BELOW scrollFrame's actual bottom edge -- outside the visible chart
    -- area, crowding whatever's below it (the help text). Moved up to sit just inside instead, per
    -- user report ("move the Date axis label up").
    panel.scatterXLabel:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 8, 6)
    panel.scatterXLabel:SetText("Key Level ->")
    panel.scatterXLabel:Hide()

    panel.scatterYLabel = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.scatterYLabel:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 8, -8)
    panel.scatterYLabel:SetText("^ Party Deaths")
    panel.scatterYLabel:Hide()

    panel.help = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.help:SetPoint("BOTTOMLEFT", 0, 0)
    panel.help:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.help:SetJustifyH("LEFT")
    panel.help:SetWordWrap(true)
    panel.help:SetText("Mythic+ runs for this dungeon, oldest to newest, left to right. Scroll to see more. Hover a bar for full details, including boss splits.")

    self.progressTabPanel = panel
end

-- Shared "nothing to show" reset for every Chart View -- each view's own render function still
-- explicitly sets up whatever IT needs afterward, but this guarantees no stale state (a bar height,
-- a shown segment, old boss-split lines) leaks from whichever view was active a moment ago.
--
-- FIXED 2026-09-30 per user report/screenshot ("the lines on the Duration graph, what are they?"):
-- this was ONLY ever called from the two early-return "nothing to show" guards below, never before
-- an actual render -- so switching FROM Boss Splits TO Duration left Boss Splits' own per-boss
-- lines (panel.bossLines) still on screen behind the bars, since RenderProgressDurationView never
-- hides them itself. Now also called right before every real render (see RefreshProgressTabContent
-- below), so every view genuinely starts from a clean slate regardless of which view was active a
-- moment ago -- the comment above was already describing this as the intent, it just wasn't wired
-- up to guarantee it.
local function HideAllProgressChartElements(panel)
    for _, col in ipairs(panel.columns) do
        col:Hide()
    end
    for _, line in ipairs(panel.lines) do
        line:Hide()
    end
    for _, linePool in ipairs(panel.bossLines) do
        for _, line in ipairs(linePool) do
            line:Hide()
        end
    end
    panel.limitLine:Hide()
    panel.limitLabel:Hide()
    for _, gridLine in ipairs(panel.durationGridLines) do
        gridLine:Hide()
    end
    for _, gridLabel in ipairs(panel.durationGridLabels) do
        gridLabel:Hide()
    end
    panel.scrollFrame:Hide()
    panel.scatterXLabel:Hide()
    panel.scatterYLabel:Hide()
    for _, tile in pairs(panel.kpis) do
        tile:Hide()
    end
end

function Addon:RefreshProgressTabContent(dungeonName)
    local panel = self.progressTabPanel
    if not panel then
        return
    end
    dungeonName = dungeonName or self.progressDungeonName
    -- Defaults to the last run's dungeon rather than an empty "Select a dungeon" state, per user
    -- request 2026-09-30 ("make them pull up the last run by default").
    if not dungeonName then
        local lastRun = self:GetLastRun()
        dungeonName = lastRun and lastRun.instanceName
    end
    self.progressDungeonName = dungeonName
    local view = self.progressChartView or "duration"
    self.progressChartView = view
    panel.viewButton:SetText("View: " .. (PROGRESS_VIEW_LABELS[view] or "Duration"))
    if self.progressSeasonFilterMode == "previous" then
        panel.instanceFilterButton:SetText("Filter: " .. (self:GetPreviousSeasonName() or "Previous Season"))
    else
        panel.instanceFilterButton:SetText("Filter: Current Season")
    end

    if self.statsHubWindow then
        self.statsHubWindow.subtitle:SetText(dungeonName and ("M+ Progress - " .. dungeonName) or "M+ Progress")
    end

    do
        local dungeonOptions = {}
        for _, name in ipairs(self:GetProgressTabDungeonList(self.progressSeasonFilterMode)) do
            table.insert(dungeonOptions, { text = name, value = name })
        end
        Addon:RefreshSimpleDropdown(panel.dungeonMenu, dungeonOptions, function(value)
            panel.dungeonMenu:Hide()
            Addon:RefreshProgressTabContent(value)
        end)
    end

    if not dungeonName then
        panel.dungeonLabel:SetText("Select a dungeon")
        panel.stats:SetText("Use the dropdown above, or click a dungeon card/Season Overview row, to see its Mythic+ history.")
        panel.stats:Show()
        panel.legend:SetText("")
        HideAllProgressChartElements(panel)
        return
    end

    panel.dungeonLabel:SetText(dungeonName)

    local allRuns = self:GetRunsForDungeon(dungeonName, math.max(1, #(self.db.runOrder or {})))
    local runs = {}
    local previousOnly = self.progressSeasonFilterMode == "previous"
    for _, run in ipairs(allRuns) do
        -- When "Previous Season" is selected, current-season runs are hidden from the chart too --
        -- not just excluded from the dungeon picker -- per user request 2026-09-30 ("when Previous
        -- Season is selected, the current season data is hidden"). A dungeon can have run history
        -- spanning several old seasons; this hides only THIS season's runs, not just the one
        -- immediately-previous season's (matches "previous season data isn't mixed with current",
        -- without needing to know exactly which of possibly-many past seasons each old run was in).
        if self:IsMythicPlusRun(run) and (not previousOnly or not self:RunMatchesCurrentSeason(run)) then
            table.insert(runs, run)
        end
    end
    -- GetRunsForDungeon returns newest-first; reverse so the chart reads oldest -> newest.
    for i = 1, math.floor(#runs / 2) do
        runs[i], runs[#runs - i + 1] = runs[#runs - i + 1], runs[i]
    end

    if #runs == 0 then
        panel.stats:SetText("No Mythic+ runs recorded yet for " .. dungeonName .. ".")
        panel.stats:Show()
        panel.legend:SetText("")
        HideAllProgressChartElements(panel)
        panel.scrollContent:SetWidth(600)
        return
    end

    -- Clean slate before every real render -- see HideAllProgressChartElements's own comment for
    -- why this matters (fixes stale Boss Splits lines bleeding into Duration view).
    HideAllProgressChartElements(panel)

    panel.stats:Hide()
    for _, tile in pairs(panel.kpis) do
        tile:Show()
    end

    local summary = self:GetDungeonSummary(dungeonName)
    local totalDeaths = 0
    local totalDeathTimeLost = 0
    for _, run in ipairs(runs) do
        totalDeaths = totalDeaths + self:GetRunDeathTotal(run)
        totalDeathTimeLost = totalDeathTimeLost + self:GetRunDeathTimePenaltySeconds(run)
    end
    local avgDeaths = #runs > 0 and (totalDeaths / #runs) or 0
    local bestText = summary.bestRun and string.format("%s (+%d)", FormatDuration(GetRunDuration(summary.bestRun)), self:GetRunKeyLevel(summary.bestRun)) or "-"
    panel.kpis.runs.value:SetText(tostring(#runs))
    panel.kpis.completion.value:SetText(self:GetCompactCompletionText(summary.completed, summary.abandoned, "F"))
    panel.kpis.avgDeaths.value:SetText(string.format("%.1f", avgDeaths))
    panel.kpis.deathTimeLost.value:SetText(totalDeathTimeLost > 0 and FormatDuration(totalDeathTimeLost) or "-")
    panel.kpis.bestRun.value:SetText(bestText)

    if view == "bosssplits" then
        -- panel.legend gets its real text from RenderProgressBossSplitsView itself (a per-boss
        -- color key built from whichever bosses are actually in this dungeon's data).
        -- Expanded 2026-09-30 per user request ("boss splits needs more information as to what it
        -- is for") -- "that boss's time" was ambiguous about what's actually being measured.
        -- Verified against GetBossSegmentTimings' own segmentSeconds (Core.lua): it's the gap from
        -- the PREVIOUS boss's death (or run start, for the first boss) to THIS boss's death -- so
        -- it lumps travel/trash-clearing together with the fight itself, not just fight time alone.
        panel.help:SetText("One line per boss, oldest run to newest, left to right. Y = time from the PREVIOUS boss's death (or run start, for the first boss) to this boss's death -- includes travel and trash-clearing, not just the fight. Bottom strip = key level. Hover a dot for the exact run.")
        self:RenderProgressBossSplitsView(panel, runs, summary)
    else
        panel.legend:SetText("|cff0d8f24Dark Green|r = Completed  |cfff37300Orange|r = Overtime  |cff8c0d0dDark Red|r = Abandoned  |cffff1acdBottom strip|r = Key level  |cffffffffWhite ring|r = Best Run")
        panel.help:SetText("Mythic+ runs for this dungeon, oldest to newest, left to right. Scroll to see more. Hover a bar for full details, including boss splits.")
        self:RenderProgressDurationView(panel, runs, summary, dungeonName)
    end
end

function Addon:RenderProgressDurationView(panel, runs, summary, dungeonName)
    local PROGRESS_BASELINE_Y, PROGRESS_CHART_HEIGHT = 96, 240
    local PROGRESS_COL_SPACING = math.max(PROGRESS_COL_SPACING, (panel.scrollFrame:GetWidth()-100)/math.max(1,#runs))
    panel.baseline:ClearAllPoints()
    panel.baseline:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", 0, PROGRESS_BASELINE_Y)
    panel.baseline:SetPoint("BOTTOMRIGHT", panel.scrollContent, "BOTTOMRIGHT", 0, PROGRESS_BASELINE_Y)
    panel.scrollFrame:Show()
    -- Axis labels added 2026-09-05 ("make sure everything is labelled") -- reuses the same
    -- FontStrings the Scatter/Boss Splits views already retext for their own axes.
    panel.scatterXLabel:Show()
    panel.scatterXLabel:SetText("Date ->")
    panel.scatterYLabel:Show()
    panel.scatterYLabel:SetText("Duration (minutes)")

    local maxDuration = 60
    local maxKeyLevel = 1
    -- run.mythicPlusTimeLimitSeconds itself has never populated live (separate open bug); go
    -- through GetMythicPlusTimeLimit so the dungeonMetadata/instanceCatalog/static fallbacks it
    -- already knows about get a chance instead of the chart just never showing a reference line.
    local timeLimit = self:GetMythicPlusTimeLimit(dungeonName)
    for _, run in ipairs(runs) do
        maxDuration = math.max(maxDuration, GetRunDuration(run))
        maxKeyLevel = math.max(maxKeyLevel, self:GetRunKeyLevel(run))
        if not timeLimit then
            local runLimit = self:GetMythicPlusTimeLimit(run)
            if runLimit and runLimit > 0 then
                timeLimit = runLimit
            end
        end
    end
    maxDuration = math.max(maxDuration, timeLimit or 0)

    local durationScale = PROGRESS_CHART_HEIGHT / maxDuration
    local keyScale = 24 / maxKeyLevel

    local contentWidth = math.max(600, panel.scrollFrame:GetWidth(), PROGRESS_DURATION_LEFT_MARGIN + (#runs * PROGRESS_COL_SPACING) + 40)
    panel.scrollContent:SetWidth(contentWidth)

    -- Gridline spacing: 3-minute ticks for a short chart, 5-minute ticks once it gets tall enough
    -- that 3-minute lines would crowd together -- per user request ("like 3 or 5 minutes").
    local gridInterval = maxDuration <= 20 * 60 and 180 or 300
    local gridCount = 0
    for t = gridInterval, maxDuration - 1, gridInterval do
        gridCount = gridCount + 1
        if gridCount > PROGRESS_DURATION_GRID_POOL then
            break
        end
        local gridLine = panel.durationGridLines[gridCount]
        local gridLabel = panel.durationGridLabels[gridCount]
        local y = PROGRESS_BASELINE_Y + (t * durationScale)
        gridLine:ClearAllPoints()
        gridLine:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", 0, y)
        gridLine:SetPoint("BOTTOMRIGHT", panel.scrollContent, "BOTTOMRIGHT", 0, y)
        gridLine:Show()
        gridLabel:ClearAllPoints()
        gridLabel:SetPoint("BOTTOMLEFT", panel.scrollFrame, "BOTTOMLEFT", 4, y - 6)
        gridLabel:SetText(string.format("%dm", math.floor(t / 60)))
        gridLabel:Show()
    end
    for index = gridCount + 1, PROGRESS_DURATION_GRID_POOL do
        panel.durationGridLines[index]:Hide()
        panel.durationGridLabels[index]:Hide()
    end

    if timeLimit then
        local limitY = PROGRESS_BASELINE_Y + (timeLimit * durationScale)
        panel.limitLine:ClearAllPoints()
        panel.limitLine:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", 0, limitY)
        panel.limitLine:SetPoint("BOTTOMRIGHT", panel.scrollContent, "BOTTOMRIGHT", 0, limitY)
        panel.limitLabel:ClearAllPoints()
        -- Was pinned at the line's own (dynamic) height, which put it right on top of whichever
        -- gridline label happened to land nearby (e.g. "35m") -- moved to a fixed spot beside the
        -- "^ Duration..." axis label instead, per user report. The red reference line itself still
        -- tracks the real time-limit height on the chart; only the text label is now static.
        panel.limitLabel:SetPoint("LEFT", panel.scatterYLabel, "RIGHT", 10, 0)
        panel.limitLabel:SetText("Time Limit: " .. FormatDuration(timeLimit))
        panel.limitLine:Show()
        panel.limitLabel:Show()
    else
        panel.limitLine:Hide()
        panel.limitLabel:Hide()
    end

    local dotX, dotY = {}, {}
    for index, col in ipairs(panel.columns) do
        local run = runs[index]
        if run then
            local colX = PROGRESS_DURATION_LEFT_MARGIN + (index - 1) * PROGRESS_COL_SPACING
            col.run = run
            col:ClearAllPoints()
            col:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", colX, 0)
            col:Show()

            for _, seg in ipairs(col.segments) do
                seg:Hide()
            end

            local status = self:GetRunStatus(run)
            local color = PROGRESS_STATUS_COLORS[status] or PROGRESS_STATUS_COLORS.Abandoned
            local barHeight = math.max(2, GetRunDuration(run) * durationScale)
            col.bar:ClearAllPoints()
            col.bar:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, PROGRESS_BASELINE_Y)
            col.bar:Show()
            col.bar:SetHeight(barHeight)
            col.bar:SetColorTexture(color[1], color[2], color[3], 0.95)

            if summary.bestRun and run.id == summary.bestRun.id then
                col.highlight:ClearAllPoints()
                col.highlight:SetPoint("BOTTOMLEFT", col.bar, "BOTTOMLEFT", -6, -6)
                col.highlight:SetPoint("TOPRIGHT", col.bar, "TOPRIGHT", 6, 6)
                col.highlight:Show()
                col.bestLabel:ClearAllPoints()
                col.bestLabel:SetPoint("BOTTOM", col.highlight, "TOP", 0, 12)
                col.bestLabel:Show()
            else
                col.highlight:Hide()
                col.bestLabel:Hide()
            end

            col.durationLabel:Show()
            col.durationLabel:ClearAllPoints()
            col.durationLabel:SetPoint("BOTTOM", col.bar, "TOP", 0, 2)
            col.durationLabel:SetText(FormatDuration(GetRunDuration(run)))

            local keyLevel = self:GetRunKeyLevel(run)
            local keyY = 50 + (keyLevel * keyScale)
            dotX[index] = colX + (PROGRESS_COL_WIDTH / 2)
            dotY[index] = keyY
            col.keyDot:Show()
            col.keyDot:SetSize(8, 8)
            col.keyDot:ClearAllPoints()
            col.keyDot:SetPoint("CENTER", col, "BOTTOMLEFT", PROGRESS_COL_WIDTH / 2, keyY)
            col.keyLabel:Show()
            col.keyLabel:ClearAllPoints()
            col.keyLabel:SetPoint("BOTTOM", col.keyDot, "TOP", 0, 2)
            col.keyLabel:SetText("+" .. tostring(keyLevel))

            col.deathLabel:Show()
            local deaths = self:GetRunDeathTotal(run)
            col.deathLabel:SetText("D:" .. tostring(deaths))
            if deaths > 0 then
                col.deathLabel:SetTextColor(1, 0.35, 0.35)
            else
                col.deathLabel:SetTextColor(0.6, 0.6, 0.6)
            end

            col.dateLabel:Show()
            col.dateLabel:SetText(run.startedAt and date("%m/%d", run.startedAt) or "?")
        else
            col.run = nil
            col:Hide()
        end
    end

    for index, line in ipairs(panel.lines) do
        if index < #runs and dotX[index] and dotX[index + 1] then
            PositionTextureLine(line, panel.scrollContent, dotX[index], dotY[index], dotX[index + 1], dotY[index + 1])
        else
            line:Hide()
        end
    end
end

-- Redesigned as a line graph per user request 2026-09-05 (the stacked-bar version was "hard to
-- see the information") -- one line per boss (kill-order position, same color across every run,
-- from PROGRESS_BOSS_PALETTE), X = run date, Y = that boss's time. Still shows key level via the
-- same cyan dot/line used in every other view, and labels both axes.
function Addon:RenderProgressBossSplitsView(panel, runs, summary)
    local PROGRESS_BASELINE_Y, PROGRESS_CHART_HEIGHT = 96, 240
    local PROGRESS_COL_SPACING = math.max(PROGRESS_COL_SPACING, (panel.scrollFrame:GetWidth()-100)/math.max(1,#runs))
    panel.baseline:ClearAllPoints()
    panel.baseline:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", 0, PROGRESS_BASELINE_Y)
    panel.baseline:SetPoint("BOTTOMRIGHT", panel.scrollContent, "BOTTOMRIGHT", 0, PROGRESS_BASELINE_Y)
    panel.scrollFrame:Show()
    panel.limitLine:Hide()
    panel.limitLabel:Hide()
    panel.scatterXLabel:Show()
    panel.scatterXLabel:SetText("Date ->")
    panel.scatterYLabel:Show()
    panel.scatterYLabel:SetText("Boss segment time (travel + fight)")

    local maxSegmentTime = 60
    local maxKeyLevel = 1
    local bossNamesByPosition = {}
    for _, run in ipairs(runs) do
        maxKeyLevel = math.max(maxKeyLevel, self:GetRunKeyLevel(run))
        for segIndex, timing in ipairs(self:GetBossSegmentTimings(run)) do
            maxSegmentTime = math.max(maxSegmentTime, timing.segmentSeconds)
            bossNamesByPosition[segIndex] = bossNamesByPosition[segIndex] or timing.bossName
        end
    end
    local timeScale = PROGRESS_CHART_HEIGHT / maxSegmentTime
    local keyScale = 24 / maxKeyLevel
    for i=1,PROGRESS_DURATION_GRID_POOL do
        local line, tick = panel.durationGridLines[i], panel.durationGridLabels[i]
        if i<=4 then
            local seconds=maxSegmentTime*i/4
            local y=PROGRESS_BASELINE_Y+seconds*timeScale
            line:ClearAllPoints()
            line:SetPoint("BOTTOMLEFT",panel.scrollContent,"BOTTOMLEFT",0,y)
            line:SetPoint("BOTTOMRIGHT",panel.scrollContent,"BOTTOMRIGHT",0,y)
            tick:ClearAllPoints();tick:SetPoint("BOTTOMLEFT",panel.scrollFrame,"BOTTOMLEFT",4,y-6)
            tick:SetText(FormatDuration(seconds));line:Show();tick:Show()
        else line:Hide();tick:Hide() end
    end


    do
        -- Small color-key so the lines are identifiable without hovering every point.
        local legendParts = {}
        for segIndex, bossName in ipairs(bossNamesByPosition) do
            local color = PROGRESS_BOSS_PALETTE[((segIndex - 1) % #PROGRESS_BOSS_PALETTE) + 1]
            table.insert(legendParts, string.format("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, bossName))
        end
        if #legendParts > 0 then
            panel.legend:SetText(table.concat(legendParts, "   ") .. "   |cffff1acdBottom strip|r = Key level")
        end
    end

    local contentWidth = math.max(600, panel.scrollFrame:GetWidth(), 20 + (#runs * PROGRESS_COL_SPACING) + 40)
    panel.scrollContent:SetWidth(contentWidth)

    -- bossDotX/Y[segIndex][index]: this boss position's point for run `index`, nil if that run
    -- doesn't have a boss at this position (e.g. an optional boss skipped) -- connector lines only
    -- draw between two runs that both actually have one.
    local bossDotX, bossDotY = {}, {}
    for segIndex = 1, #panel.bossLines do
        bossDotX[segIndex], bossDotY[segIndex] = {}, {}
    end
    local keyDotX, keyDotY = {}, {}

    for index, col in ipairs(panel.columns) do
        local run = runs[index]
        if run then
            local colX = 20 + (index - 1) * PROGRESS_COL_SPACING
            col.run = run
            col:ClearAllPoints()
            col:SetPoint("BOTTOMLEFT", panel.scrollContent, "BOTTOMLEFT", colX, 0)
            col:Show()
            col.bar:Hide()
            col.highlight:Hide()
            col.bestLabel:Hide()
            col.durationLabel:Hide()

            local segments = self:GetBossSegmentTimings(run)
            for segIndex = 1, #col.segments do
                local dot = col.segments[segIndex]
                local timing = segments[segIndex]
                if timing then
                    local y = PROGRESS_BASELINE_Y + (timing.segmentSeconds * timeScale)
                    local color = PROGRESS_BOSS_PALETTE[((segIndex - 1) % #PROGRESS_BOSS_PALETTE) + 1]
                    dot:ClearAllPoints()
                    dot:SetSize(7, 7)
                    dot:SetPoint("CENTER", col, "BOTTOMLEFT", PROGRESS_COL_WIDTH / 2, y)
                    dot:SetColorTexture(color[1], color[2], color[3], 0.95)
                    dot:Show()
                    bossDotX[segIndex][index] = colX + (PROGRESS_COL_WIDTH / 2)
                    bossDotY[segIndex][index] = y
                else
                    dot:Hide()
                end
            end

            local keyLevel = self:GetRunKeyLevel(run)
            local keyY = 50 + (keyLevel * keyScale)
            keyDotX[index] = colX + (PROGRESS_COL_WIDTH / 2)
            keyDotY[index] = keyY
            col.keyDot:Show()
            col.keyDot:SetSize(8, 8)
            col.keyDot:ClearAllPoints()
            col.keyDot:SetPoint("CENTER", col, "BOTTOMLEFT", PROGRESS_COL_WIDTH / 2, keyY)
            col.keyLabel:Show()
            col.keyLabel:ClearAllPoints()
            col.keyLabel:SetPoint("BOTTOM", col.keyDot, "TOP", 0, 2)
            col.keyLabel:SetText("+" .. tostring(keyLevel))

            col.deathLabel:Show()
            local deaths = self:GetRunDeathTotal(run)
            col.deathLabel:SetText("D:" .. tostring(deaths))
            col.deathLabel:SetTextColor(deaths > 0 and 1 or 0.6, deaths > 0 and 0.35 or 0.6, deaths > 0 and 0.35 or 0.6)

            col.dateLabel:Show()
            col.dateLabel:SetText(run.startedAt and date("%m/%d", run.startedAt) or "?")
        else
            col.run = nil
            col:Hide()
            for _, dot in ipairs(col.segments) do
                dot:Hide()
            end
        end
    end

    for segIndex, linePool in ipairs(panel.bossLines) do
        for index, line in ipairs(linePool) do
            local x1, y1 = bossDotX[segIndex][index], bossDotY[segIndex][index]
            local x2, y2 = bossDotX[segIndex][index + 1], bossDotY[segIndex][index + 1]
            if index < #runs and x1 and y1 and x2 and y2 then
                PositionTextureLine(line, panel.scrollContent, x1, y1, x2, y2)
            else
                line:Hide()
            end
        end
    end

    for index, line in ipairs(panel.lines) do
        if index < #runs and keyDotX[index] and keyDotX[index + 1] then
            PositionTextureLine(line, panel.scrollContent, keyDotX[index], keyDotY[index], keyDotX[index + 1], keyDotY[index + 1])
        else
            line:Hide()
        end
    end
end

-- Season Overview: a single dashboard comparing every M+ pool dungeon for the current season side
-- by side (KPI row, an overall completion meter, then one stacked outcome bar + key badge per
-- dungeon). Built from the same stacked-bar technique already used for the per-run Progress chart
-- above, kept as plain segmented textures rather than a WoW StatusBar so the on-time/overtime/
-- abandoned split can share one bar (StatusBar only supports a single fill).
local SEASON_ROW_POOL_SIZE = 24
local SEASON_ROW_HEIGHT = 50
local SEASON_BAR_HEIGHT = 16

-- Metallic sheen per user request 2026-09-05: a vertical gradient (brightened highlight at the
-- top, darkened shade at the bottom) instead of one flat color, like a brushed-metal bar catching
-- light from above. SetGradientAlpha is a long-standing Texture API (predates retail's UI
-- overhaul) -- not independently re-verified against this specific patch's docs, so if a bar ever
-- renders flat instead of gradiented, that's the first thing to check; falls back to the old flat
-- fill if the API isn't there for some reason, so this can't break the bar outright either way.
local function SetSegmentFill(texture, r, g, b, width)
    if width <= 0 then
        -- Width still needs resetting even when hidden -- the next segment anchors to this
        -- texture's TOPRIGHT, and a hidden texture keeps whatever width it last had, which would
        -- silently offset the next segment by a stale amount on the row's next refresh.
        texture:SetWidth(0.01)
        texture:Hide()
        return
    end
    if texture.SetGradientAlpha then
        local lightR, lightG, lightB = math.min(1, r * 1.35 + 0.15), math.min(1, g * 1.35 + 0.15), math.min(1, b * 1.35 + 0.15)
        local darkR, darkG, darkB = r * 0.45, g * 0.45, b * 0.45
        texture:SetGradientAlpha("VERTICAL", darkR, darkG, darkB, 0.95, lightR, lightG, lightB, 0.95)
    else
        texture:SetColorTexture(r, g, b, 0.95)
    end
    texture:SetWidth(width)
    texture:Show()
end

local SEASON_TAB_SORT_MODES = { "runs", "key", "name" }
local SEASON_TAB_SORT_LABELS = { runs = "Sort: Most Runs", key = "Sort: Highest Key", name = "Sort: A-Z" }

local function SortSeasonDungeons(dungeons, mode)
    local sorted = {}
    for _, d in ipairs(dungeons) do
        table.insert(sorted, d)
    end
    if mode == "key" then
        table.sort(sorted, function(a, b)
            if a.highestKey ~= b.highestKey then
                return a.highestKey > b.highestKey
            end
            return tostring(a.name) < tostring(b.name)
        end)
    elseif mode == "name" then
        table.sort(sorted, function(a, b) return tostring(a.name) < tostring(b.name) end)
    end
    -- "runs" mode: already sorted that way by GetSeasonOverviewData; leave as-is.
    return sorted
end

function Addon:BuildSeasonTabContent(panel)
    -- Refresh button removed 2026-09-30 per user report ("do nothing from what i see") -- this
    -- tab only shows locally-tracked run history, already re-rendered every time it becomes
    -- active (ShowStatsHubTab) or the sort mode changes, so a manual button never had a scenario
    -- the other controls hadn't already covered.
    -- "More options": cycles which order the dungeon rows sort in, remembered across sessions.
    local sortButton = self:CreatePlainButton(panel, "Sort: Most Runs", 150, 24)
    sortButton:SetPoint("TOPLEFT", 0, 0)
    sortButton:SetScript("OnClick", function()
        local current = self.db.seasonTabSortMode or "runs"
        local currentIndex = 1
        for i, mode in ipairs(SEASON_TAB_SORT_MODES) do
            if mode == current then
                currentIndex = i
                break
            end
        end
        local nextMode = SEASON_TAB_SORT_MODES[(currentIndex % #SEASON_TAB_SORT_MODES) + 1]
        self.db.seasonTabSortMode = nextMode
        sortButton:SetText(SEASON_TAB_SORT_LABELS[nextMode])
        Addon:RefreshSeasonTabContent()
    end)
    panel.sortButton = sortButton

    -- KPI row: five stat tiles, each a big number over a label. "Highest Key" split into
    -- highestKeyRun/highestKeyCompleted 2026-09-30 per user request -- one ambiguous number didn't
    -- say whether it was ever actually finished.
    panel.kpis = {}
    local kpiDefs = { "runs", "completion", "highestKeyRun", "highestKeyCompleted", "avgDeaths" }
    local kpiLabels = { runs = "Runs This Season", completion = "Completion Rate", highestKeyRun = "Highest Key (Run)", highestKeyCompleted = "Highest Key (Completed)", avgDeaths = "Avg Deaths / Run" }
    local kpiWidth = 1052 / 5
    for index, key in ipairs(kpiDefs) do
        local tile = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        tile:SetSize(kpiWidth - 8, 64)
        tile:SetPoint("TOPLEFT", (index - 1) * kpiWidth, -36)
        tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        tile:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))
        tile:SetBackdropBorderColor(self:GetThemeBorderColor(false))

        tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tile.value:SetPoint("TOP", 0, -12)

        tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tile.label:SetPoint("BOTTOM", 0, 8)
        tile.label:SetText(kpiLabels[key])

        panel.kpis[key] = tile
    end

    -- Overall completion meter: one wide stacked bar, same on-time/overtime/abandoned split as
    -- each dungeon row below, so "season completion" reads as the sum of everything under it.
    local meterLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    meterLabel:SetPoint("TOPLEFT", 0, -116)
    meterLabel:SetText("Season completion (all M+ pool dungeons)")
    panel.meterLabel = meterLabel

    local meterBg = panel:CreateTexture(nil, "BACKGROUND")
    meterBg:SetPoint("TOPLEFT", 0, -134)
    meterBg:SetPoint("TOPRIGHT", 0, -134)
    meterBg:SetHeight(22)
    meterBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
    panel.meterBg = meterBg

    panel.meterOnTime = panel:CreateTexture(nil, "ARTWORK")
    panel.meterOnTime:SetPoint("TOPLEFT", meterBg, "TOPLEFT", 0, 0)
    panel.meterOnTime:SetHeight(22)

    panel.meterOvertime = panel:CreateTexture(nil, "ARTWORK")
    panel.meterOvertime:SetHeight(22)

    panel.meterAbandoned = panel:CreateTexture(nil, "ARTWORK")
    panel.meterAbandoned:SetHeight(22)

    local meterText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    meterText:SetPoint("CENTER", meterBg, "CENTER", 0, 0)
    panel.meterText = meterText

    local legend = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    legend:SetPoint("TOPLEFT", 0, -160)
    legend:SetText("|cff33d94dGreen|r = Completed in time  |cffe6b21aGold|r = Completed overtime  |cffd93333Red|r = Abandoned  |cffff3333Red text|r = highest key this season")
    panel.legend = legend

    -- Arcane-theme alternative to the stacked bar above: same on-time/overtime/abandoned split,
    -- as a donut chart via the new reusable MPlusLedgerPieChart module (UI/PieChart.lua). Both
    -- this and the bar above are always built; RefreshSeasonTabContent shows exactly one of them
    -- based on Addon:GetTheme(), per user request ("have this as a toggle for the new redesign").
    local completionChart = MPlusLedgerPieChart.New(panel, { radius = 36, innerRadiusRatio = 0.55, centerColor = { 0.04, 0.04, 0.04, 1 } })
    completionChart.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -100)
    panel.completionChart = completionChart

    local chartLegend = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chartLegend:SetPoint("LEFT", completionChart.frame, "RIGHT", 18, 0)
    chartLegend:SetJustifyH("LEFT")
    panel.completionChartLegend = chartLegend

    -- Second donut: on-time completions broken down BY DUNGEON (not by outcome, like the one
    -- above) -- per user request 2026-09-30 ("Voidscar Arena has 14 runs completed on time, while
    -- Murder Row has had 7"). Slice colors reuse GetDungeonColor (Settings > Colours' existing
    -- per-dungeon color picker -- the same one that already tints dungeon names in the rows below
    -- and card borders on the main window), so no separate color picker was needed; a dungeon with
    -- no custom color falls back to a deterministic palette (see RefreshSeasonTabContent) so every
    -- slice still reads distinctly before anyone's customized anything. No separate text legend --
    -- the dungeon rows below already color their name text the same way, serving as one.
    local dungeonOnTimeChart = MPlusLedgerPieChart.New(panel, { radius = 36, innerRadiusRatio = 0.55, centerColor = { 0.04, 0.04, 0.04, 1 } })
    dungeonOnTimeChart.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 560, -100)
    panel.dungeonOnTimeChart = dungeonOnTimeChart

    local dungeonOnTimeLegend = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dungeonOnTimeLegend:SetPoint("LEFT", dungeonOnTimeChart.frame, "RIGHT", 18, 0)
    dungeonOnTimeLegend:SetJustifyH("LEFT")
    panel.dungeonOnTimeLegend = dungeonOnTimeLegend

    -- Per-dungeon rows: every dungeon in the M+ pool, run or not, so the comparison never
    -- silently drops one this season hasn't touched yet.
    local listFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", 0, -182)
    listFrame:SetPoint("BOTTOMRIGHT", 0, 32)
    listFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    listFrame:SetBackdropColor(Addon:GetTableBackgroundColor(0.95))

    local scrollFrame = CreateFrame("ScrollFrame", nil, listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self:GetVerticalScrollRange())
        local target = math.max(0, math.min(maxScroll, (self.targetScroll or self:GetVerticalScroll()) - (delta * 40)))
        self.targetScroll = target
    end)
    scrollFrame:SetScript("OnUpdate", function(self, elapsed)
        local target = self.targetScroll
        if not target then
            return
        end
        local current = self:GetVerticalScroll()
        if math.abs(target - current) < 0.5 then
            self:SetVerticalScroll(target)
            self.targetScroll = nil
            return
        end
        self:SetVerticalScroll(current + (target - current) * math.min(1, elapsed * 12))
    end)

    -- Fixed width matching the visible scroll area (panel is 1052 wide; scrollFrame insets 8px
    -- left / 28px right for the scrollbar) -- rows anchor TOPLEFT+TOPRIGHT to this frame, so it
    -- needs a real width, not the "1" a purely-vertical list might default to.
    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(1016, SEASON_ROW_POOL_SIZE * SEASON_ROW_HEIGHT)
    scrollFrame:SetScrollChild(scrollContent)
    panel.scrollFrame = scrollFrame
    panel.scrollContent = scrollContent

    panel.rows = {}
    for index = 1, SEASON_ROW_POOL_SIZE do
        local row = CreateFrame("Button", nil, scrollContent)
        row:SetHeight(SEASON_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 4, -(index - 1) * SEASON_ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -4, -(index - 1) * SEASON_ROW_HEIGHT)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("TOPLEFT", 0, -2)
        row.name:SetWidth(820)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.keyBadge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.keyBadge:SetPoint("TOPRIGHT", 0, -2)
        row.keyBadge:SetJustifyH("RIGHT")

        row.barBg = row:CreateTexture(nil, "BACKGROUND")
        row.barBg:SetPoint("TOPLEFT", 0, -20)
        row.barBg:SetPoint("TOPRIGHT", 0, -20)
        row.barBg:SetHeight(SEASON_BAR_HEIGHT)
        row.barBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

        row.onTimeFill = row:CreateTexture(nil, "ARTWORK")
        row.onTimeFill:SetPoint("TOPLEFT", row.barBg, "TOPLEFT", 0, 0)
        row.onTimeFill:SetHeight(SEASON_BAR_HEIGHT)

        row.overtimeFill = row:CreateTexture(nil, "ARTWORK")
        row.overtimeFill:SetHeight(SEASON_BAR_HEIGHT)

        row.abandonedFill = row:CreateTexture(nil, "ARTWORK")
        row.abandonedFill:SetHeight(SEASON_BAR_HEIGHT)

        row.runsText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.runsText:SetPoint("TOPLEFT", row.barBg, "BOTTOMLEFT", 2, -2)

        local rowHighlight = row:CreateTexture(nil, "HIGHLIGHT")
        rowHighlight:SetAllPoints(row)
        rowHighlight:SetColorTexture(1, 1, 1, 0.06)
        row:SetHighlightTexture(rowHighlight)

        row:SetScript("OnEnter", function(self)
            local d = self.dungeonRow
            if not d then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(d.name)
            GameTooltip:AddLine(string.format("%d run%s this season", d.runs, d.runs == 1 and "" or "s"), 1, 1, 1)
            GameTooltip:AddLine(string.format("On time: %d  |  Overtime: %d  |  Abandoned: %d", d.onTime, d.overtime, d.abandoned), 0.8, 0.8, 0.8)
            if d.highestKey > 0 then
                GameTooltip:AddLine(string.format("Highest key this season: +%d", d.highestKey), 1, 0.3, 0.3)
            else
                GameTooltip:AddLine("No Mythic+ run recorded this season yet.", 0.6, 0.6, 0.6)
            end
            GameTooltip:AddLine("Click to open this dungeon's Progress chart.", 0.4, 0.7, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self)
            local d = self.dungeonRow
            if not d then
                return
            end
            GameTooltip:Hide()
            Addon:ToggleStatsHubWindow("progress", d.name)
        end)

        row:Hide()
        panel.rows[index] = row
    end

    panel.help = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.help:SetPoint("BOTTOMLEFT", 0, 0)
    panel.help:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.help:SetJustifyH("LEFT")
    panel.help:SetWordWrap(true)
    panel.help:SetText("Every dungeon in the current Mythic+ pool, run or not, for the current season only. Hover a row for the exact breakdown, click it to open that dungeon's own Progress chart. This is your own tracked history -- for live Blizzard score/vault/party data, see the M+ Stats tab.")

    self.seasonTabPanel = panel
end

function Addon:RefreshSeasonTabContent()
    local panel = self.seasonTabPanel
    if not panel then
        return
    end

    local data = self:GetSeasonOverviewData()
    local sortMode = self.db.seasonTabSortMode or "runs"
    if panel.sortButton then
        panel.sortButton:SetText(SEASON_TAB_SORT_LABELS[sortMode] or SEASON_TAB_SORT_LABELS.runs)
    end
    if self.statsHubWindow then
        self.statsHubWindow.subtitle:SetText("Season Overview - " .. tostring(data.seasonLabel))
    end

    panel.kpis.runs.value:SetText(tostring(data.totalRuns))
    panel.kpis.completion.value:SetText(string.format("%.0f%%", data.completionPct))
    panel.kpis.completion.value:SetTextColor(self:GetCompletionRateColor(data.completionPct))
    panel.kpis.highestKeyRun.value:SetText(data.highestKeyRun > 0 and ("|cffff3333+" .. data.highestKeyRun .. "|r") or "-")
    panel.kpis.highestKeyCompleted.value:SetText(data.highestKeyCompleted > 0 and ("|cffff3333+" .. data.highestKeyCompleted .. "|r") or "-")
    panel.kpis.avgDeaths.value:SetText(string.format("%.1f", data.avgDeaths))

    -- Donut chart permanently replaces the stacked bar here, per user request 2026-09-06 ("ignore
    -- the theme but keep the circles now, makes it easier to see stats") -- no longer tied to
    -- self.db.uiTheme at all; the bar-drawing code below is left in place (unreachable while this
    -- is true) rather than deleted, in case a bar view is ever wanted back as an option.
    local useArcane = true
    panel.meterLabel:SetShown(not useArcane)
    panel.meterBg:SetShown(not useArcane)
    panel.legend:SetShown(not useArcane)
    panel.completionChart.frame:SetShown(useArcane)
    panel.completionChartLegend:SetShown(useArcane)

    local meterWidth = panel.meterBg:GetWidth()
    if data.totalRuns > 0 then
        if useArcane then
            panel.meterOnTime:Hide()
            panel.meterOvertime:Hide()
            panel.meterAbandoned:Hide()
            panel.completionChart:SetData({
                { label = "Completed in time", value = data.onTime, color = { 0.20, 0.85, 0.30 } },
                { label = "Completed overtime", value = data.overtime, color = { 0.90, 0.70, 0.10 } },
                { label = "Abandoned", value = data.abandoned, color = { 0.85, 0.20, 0.20 } },
            })
            panel.completionChartLegend:SetText(string.format(
                "%d runs this season\n|cff33d94dOn time:|r %d (%.0f%%)\n|cffe6b21aOvertime:|r %d (%.0f%%)\n|cffd93333Abandoned:|r %d (%.0f%%)",
                data.totalRuns,
                data.onTime, data.totalRuns > 0 and (data.onTime / data.totalRuns * 100) or 0,
                data.overtime, data.totalRuns > 0 and (data.overtime / data.totalRuns * 100) or 0,
                data.abandoned, data.totalRuns > 0 and (data.abandoned / data.totalRuns * 100) or 0
            ))
        else
            local onTimeWidth = meterWidth * (data.onTime / data.totalRuns)
            local overtimeWidth = meterWidth * (data.overtime / data.totalRuns)
            local abandonedWidth = meterWidth * (data.abandoned / data.totalRuns)
            SetSegmentFill(panel.meterOnTime, 0.20, 0.85, 0.30, onTimeWidth)
            panel.meterOvertime:ClearAllPoints()
            panel.meterOvertime:SetPoint("TOPLEFT", panel.meterOnTime, "TOPRIGHT", 0, 0)
            SetSegmentFill(panel.meterOvertime, 0.90, 0.70, 0.10, overtimeWidth)
            panel.meterAbandoned:ClearAllPoints()
            panel.meterAbandoned:SetPoint("TOPLEFT", panel.meterOvertime:IsShown() and panel.meterOvertime or panel.meterOnTime, "TOPRIGHT", 0, 0)
            SetSegmentFill(panel.meterAbandoned, 0.85, 0.20, 0.20, abandonedWidth)
            panel.meterText:SetText(string.format("%d runs | %.0f%% completed | %d abandoned", data.totalRuns, data.completionPct, data.abandoned))
        end
    else
        panel.meterOnTime:Hide()
        panel.meterOvertime:Hide()
        panel.meterAbandoned:Hide()
        panel.meterText:SetText("No Mythic+ runs recorded this season yet.")
        if useArcane then
            panel.completionChart:Hide()
            panel.completionChartLegend:SetText("No Mythic+ runs recorded this season yet.")
        end
    end

    -- Second donut: on-time completions per dungeon. Slice color = GetDungeonColor (Settings >
    -- Colours) when the user's set one, else a deterministic fallback (PROGRESS_BOSS_PALETTE,
    -- cycled by sorted dungeon order so the same dungeon always lands on the same fallback color
    -- across refreshes) -- every slice reads distinctly even before anyone's customized anything.
    local onTimeTotal = 0
    for _, d in ipairs(data.dungeons) do
        onTimeTotal = onTimeTotal + (d.onTime or 0)
    end
    if onTimeTotal > 0 then
        local slices = {}
        local sortedByOnTime = {}
        for _, d in ipairs(data.dungeons) do
            table.insert(sortedByOnTime, d)
        end
        table.sort(sortedByOnTime, function(a, b) return tostring(a.name) < tostring(b.name) end)
        local colorByName = {}
        for index, d in ipairs(sortedByOnTime) do
            if d.onTime and d.onTime > 0 then
                local customColor = self:GetDungeonColor(d.name)
                local color = customColor or PROGRESS_BOSS_PALETTE[((index - 1) % #PROGRESS_BOSS_PALETTE) + 1]
                colorByName[d.name] = color
                table.insert(slices, { label = d.name, value = d.onTime, color = color })
            end
        end
        panel.dungeonOnTimeChart:SetData(slices)
        panel.dungeonOnTimeChart.frame:Show()

        -- Real legend (name, matching color, count) per user request 2026-09-30 -- was just a
        -- generic "see colored names below" line before. Sorted by on-time count, most first.
        local legendRows = {}
        for _, d in ipairs(sortedByOnTime) do
            if d.onTime and d.onTime > 0 then
                table.insert(legendRows, d)
            end
        end
        table.sort(legendRows, function(a, b) return a.onTime > b.onTime end)
        local legendLines = {}
        for _, d in ipairs(legendRows) do
            local color = colorByName[d.name]
            table.insert(legendLines, string.format("|cff%02x%02x%02x%s|r: %d", color[1] * 255, color[2] * 255, color[3] * 255, d.name, d.onTime))
        end
        panel.dungeonOnTimeLegend:SetText(table.concat(legendLines, "\n"))
    else
        panel.dungeonOnTimeChart:Hide()
        panel.dungeonOnTimeLegend:SetText("No on-time completions this season yet.")
    end

    local barWidth = 1
    if panel.rows[1] then
        barWidth = panel.rows[1]:GetWidth()
    end

    local sortedDungeons = SortSeasonDungeons(data.dungeons, sortMode)
    for index, row in ipairs(panel.rows) do
        local d = sortedDungeons[index]
        if d then
            row.dungeonRow = d
            row.name:SetText(d.name)
            -- Per-dungeon custom color (Settings > Colours), added 2026-09-08 -- tints the name
            -- text directly since these rows don't have their own border to color like the main
            -- window's dungeon cards do.
            local dungeonColor = self:GetDungeonColor(d.name)
            if dungeonColor then
                row.name:SetTextColor(dungeonColor[1], dungeonColor[2], dungeonColor[3])
            else
                row.name:SetTextColor(1, 1, 1)
            end
            row.keyBadge:SetText(d.highestKey > 0 and ("|cffff3333+" .. d.highestKey .. "|r") or "|cff808080no key yet|r")

            local shareOfMax = data.maxDungeonRuns > 0 and (d.runs / data.maxDungeonRuns) or 0
            local totalBarWidth = barWidth * shareOfMax
            if d.runs > 0 and totalBarWidth > 0 then
                local onTimeWidth = totalBarWidth * (d.onTime / d.runs)
                local overtimeWidth = totalBarWidth * (d.overtime / d.runs)
                local abandonedWidth = totalBarWidth * (d.abandoned / d.runs)
                SetSegmentFill(row.onTimeFill, 0.20, 0.85, 0.30, onTimeWidth)
                row.overtimeFill:ClearAllPoints()
                row.overtimeFill:SetPoint("TOPLEFT", row.onTimeFill, "TOPRIGHT", 0, 0)
                SetSegmentFill(row.overtimeFill, 0.90, 0.70, 0.10, overtimeWidth)
                row.abandonedFill:ClearAllPoints()
                row.abandonedFill:SetPoint("TOPLEFT", row.overtimeFill:IsShown() and row.overtimeFill or row.onTimeFill, "TOPRIGHT", 0, 0)
                SetSegmentFill(row.abandonedFill, 0.85, 0.20, 0.20, abandonedWidth)
                row.runsText:SetText(string.format("%d run%s", d.runs, d.runs == 1 and "" or "s"))
            else
                row.onTimeFill:Hide()
                row.overtimeFill:Hide()
                row.abandonedFill:Hide()
                row.runsText:SetText("Not run this season")
            end

            row:Show()
        else
            row.dungeonRow = nil
            row:Hide()
        end
    end

    panel.scrollContent:SetHeight(math.max(1, #sortedDungeons * SEASON_ROW_HEIGHT))
end

function Addon:SelectDataToolInstance(instanceName)
    self.dataToolSelectedInstanceName = instanceName
    local runs = self:GetRunsForDungeon(instanceName, 1)
    if runs and runs[1] then
        self.dataToolSelectedRunID = runs[1].id
        self.debugSelectedRunID = runs[1].id
        self.dataToolSelectedDifficulty = nil
    end
end

function Addon:GetCustomBossOrder(dungeonName)
    return self.db and self.db.customBossOrders and self.db.customBossOrders[dungeonName]
end

function Addon:GetOrderedBossIDs(run)
    local bossInfo = self:GetDungeonBossInfo(run)
    local ordered = {}
    local seen = {}
    if not bossInfo or not bossInfo.bosses then
        return ordered
    end

    local dungeonName = run and run.instanceName or ""
    local function addOrder(source)
        for _, bossID in ipairs(source or {}) do
            bossID = tonumber(bossID) or bossID
            if bossInfo.bosses[bossID] and not seen[bossID] then
                table.insert(ordered, bossID)
                seen[bossID] = true
            end
        end
    end
    addOrder(self:GetCustomBossOrder(dungeonName))
    addOrder(DUNGEON_BOSS_ORDER[dungeonName])
    for bossID in pairs(bossInfo.bosses) do
        if not seen[bossID] then
            table.insert(ordered, bossID)
        end
    end
    return ordered
end

function Addon:GetDebugBossOptions(run)
    local options = {}
    local bossInfo = self:GetDungeonBossInfo(run)
    if not bossInfo or not bossInfo.bosses then
        return options
    end

    local requiredIndex = 0
    for _, bossID in ipairs(self:GetOrderedBossIDs(run)) do
        local killed = run and run.killedBosses and run.killedBosses[bossID]
        local prefix
        if self:IsBossOptional(run, bossID) then
            prefix = "Optional Boss"
        else
            requiredIndex = requiredIndex + 1
            prefix = "Boss " .. tostring(requiredIndex)
        end
        local label = string.format("%s: %s (%s)", prefix, self:GetBossName(run, bossID), killed and "killed" or "not killed")
        table.insert(options, {
            text = killed and ("|cff00ff00" .. label .. "|r") or label,
            value = bossID,
            backdrop = killed and { 0.02, 0.36, 0.08 } or nil,
        })
    end
    return options
end

function Addon:GetDataToolMobOptions(run)
    local options = {}
    for npcID, info in pairs(run and run.mobKills or {}) do
        local override = self.db and self.db.mobNameOverrides and self.db.mobNameOverrides[tostring(npcID)]
        local name = override or (info and info.name) or ("Mob " .. tostring(npcID))
        table.insert(options, {
            text = string.format("%s (%s)", name, tostring(npcID)),
            value = tostring(npcID),
        })
    end
    return options
end

function Addon:GetDataToolSelectedRun()
    local selectedID = self.dataToolSelectedRunID or self.debugSelectedRunID or (self:GetLastRun() and self:GetLastRun().id)
    return self:GetRun(selectedID)
end

function Addon:CreateDebugRunFromDataTools()
    local editor = self.dataTools
    if not editor then
        return
    end

    local instanceName = strtrim(editor.instanceNameBox and editor.instanceNameBox:GetText() or "")
    if instanceName == "" then
        Print("Enter an instance name first.")
        return
    end

    self.db.nextRunID = (self.db.nextRunID or 0) + 1
    local runID = tostring(self.db.nextRunID)
    local patchInfo = GetClientPatchInfo()
    local bucket = self.dataToolSelectedDifficulty or "normal"
    local difficultyConfig = DIFFICULTY_BUCKETS[bucket] or DIFFICULTY_BUCKETS.normal
    local keyLevel = bucket == "mythicPlus" and math.max(tonumber(editor.keyLevelBox and editor.keyLevelBox:GetText() or "") or 2, 1) or nil
    local now = time()
    local mythicPlusSeason = GetEstimatedMythicPlusSeason(patchInfo.version)
    -- The Create Run form's Expansion/Guide ID fields (auto-filled from the dungeon catalogue on
    -- instance pick, or hand-edited) used to be silently discarded here -- this always guessed the
    -- expansion from the CLIENT'S current patch version instead, and never read the Guide ID box at
    -- all. Only SaveDataToolRunBasics (used from Edit Run) actually applied them, so every new
    -- manual run needed a second trip through Edit Run just to fix Expansion/Guide ID back to what
    -- was already typed on the Create Run screen a moment earlier.
    local typedExpansion = strtrim(editor.expansionNameBox and editor.expansionNameBox:GetText() or "")
    local catalogueEntry = self:GetLedgerDungeonCatalogue()[instanceName]
    local typedJournalID = catalogueEntry and catalogueEntry.journalInstanceID or nil
    local run = {
        id = runID,
        instanceName = instanceName,
        instanceType = "party",
        difficultyID = difficultyConfig.id,
        difficultyName = difficultyConfig.label,
        challengeLevel = keyLevel,
        keyLevel = keyLevel,
        completionLevel = keyLevel,
        clientVersion = patchInfo.version,
        clientBuild = patchInfo.build,
        clientBuildDate = patchInfo.buildDate,
        clientInterfaceVersion = patchInfo.interfaceVersion,
        clientPatch = patchInfo.version,
        expansionName = (typedExpansion ~= "" and typedExpansion) or GetKnownExpansionNameForVersion(patchInfo.version) or (patchInfo.version and ("Patch " .. tostring(patchInfo.version)) or nil),
        journalInstanceID = typedJournalID,
        mythicPlusSeasonName = mythicPlusSeason,
        mythicPlusSeason = mythicPlusSeason,
        playerGUID = SafeUnitGUID("player"),
        playerName = GetUnitFullName("player"),
        startedAt = now,
        startedAtText = date("%Y-%m-%d %H:%M:%S", now),
        duration = 0,
        runStatus = "Active",
        deaths = 0,
        goldLooted = 0,
        repairCost = 0,
        repairs = {},
        moneyLoot = {},
        itemLoot = {},
        chatLog = {},
        members = {},
        memberDeaths = {},
        memberDeathLog = {},
        memberDeathIDs = {},
        nextDeathEventID = 0,
        memberInterrupts = {},
        memberEvents = {},
        encounters = {},
        killedBosses = {},
        bossKills = {},
        bossKillLog = {},
        mobKills = {},
        mobKillLog = {},
        mobKillTotal = 0,
        manualRun = true,
    }

    self.db.runs[runID] = run
    self:GetRunCode(run)
    table.insert(self.db.runOrder, 1, runID)
    self.db.currentRunID = runID
    self.db.lastRunID = runID
    self.dataToolSelectedRunID = runID
    self.debugSelectedRunID = runID
    self:PruneRuns()
    self:CatalogCurrentInstance(run)
    Print("Created debug run: " .. instanceName .. ".")
    self:RefreshAllDisplays()
end

function Addon:SaveDataToolRunBasics(skipRefresh)
    local editor = self.dataTools
    local run = self:GetDataToolSelectedRun()
    if not editor or not run then
        Print("Select a run first.")
        return
    end

    local instanceName = strtrim(editor.instanceNameBox and editor.instanceNameBox:GetText() or "")
    if instanceName ~= "" then
        run.instanceName = instanceName
    end
    local expansionName = strtrim(editor.expansionNameBox and editor.expansionNameBox:GetText() or "")
    if expansionName ~= "" then
        run.expansionName = expansionName
    end
    local journalInstanceID = tonumber(editor.journalInstanceIDBox and editor.journalInstanceIDBox:GetText() or "")
    if journalInstanceID then
        run.journalInstanceID = journalInstanceID
    end
    -- Was never read here at all -- the box existed and displayed the current key level, but
    -- saving silently discarded any edit to it. GetRunKeyLevel checks keyLevel/challengeLevel/
    -- completionLevel in that order, so all three get set to stay consistent with anything else
    -- in the file that might read one of the other two fields directly.
    if editor.keyLevelBox and editor.keyLevelBox:IsShown() then
        local keyLevel = tonumber(editor.keyLevelBox:GetText() or "")
        if keyLevel and keyLevel > 0 then
            keyLevel = math.floor(keyLevel)
            run.keyLevel = keyLevel
            run.challengeLevel = keyLevel
            run.completionLevel = keyLevel
        end
    end
    if editor.runTimeMinutesBox or editor.runTimeSecondsBox then
        local minutes = tonumber(editor.runTimeMinutesBox and editor.runTimeMinutesBox:GetText() or "") or 0
        local seconds = tonumber(editor.runTimeSecondsBox and editor.runTimeSecondsBox:GetText() or "") or 0
        local totalSeconds = (math.max(0, math.floor(minutes)) * 60) + math.max(0, math.floor(seconds))
        if totalSeconds > 0 then
            run.durationOverride = totalSeconds
            run.duration = totalSeconds
        end
    end
    if run.instanceName and run.instanceName ~= "" then
        self.db.dungeonMetadata = self.db.dungeonMetadata or {}
        self.db.dungeonMetadata[run.instanceName] = self.db.dungeonMetadata[run.instanceName] or {}
        local metadata = self.db.dungeonMetadata[run.instanceName]
        if expansionName ~= "" then
            metadata.expansionName = expansionName
        end
        if journalInstanceID then
            metadata.journalInstanceID = journalInstanceID
        end
    end
    if self.dataToolSelectedDifficulty then
        self.debugSelectedRunID = run.id
        self:SetRunDifficultyDebug(self.dataToolSelectedDifficulty, skipRefresh)
    end
    if not skipRefresh then
        Print("Saved run details.")
        self:RefreshAllDisplays()
    end
end

-- Manually add a party member to a run's roster -- for a pug who left before the roster scan
-- caught them, or a run created by hand via Create Run that never had a real roster at all.
-- Mirrors the roster-touch-up block inside SaveDataToolPlayer, but as its own explicit action on
-- the Run tab instead of a side effect of saving a rating.
function Addon:AddDataToolRunMember()
    local editor = self.dataTools
    local run = self:GetDataToolSelectedRun()
    if not editor or not run then
        Print("Select a run first.")
        return
    end

    local rawName = strtrim(editor.addPlayerNameBox and editor.addPlayerNameBox:GetText() or "")
    if rawName == "" then
        Print("Enter a player name.")
        return
    end

    -- Realm matters -- the same name can exist on a different (connected) realm, and
    -- GetPlayerRealmName/GetPlayerProfileKey silently assume the LOCAL PLAYER's own realm when
    -- none is given, which would misfile a cross-realm teammate under the wrong key (the same
    -- class of bug v0.1.193 fixed for Save Player). Priority: a realm typed directly into the name
    -- box ("Name-Realm") wins, then the separate Realm box, then your own realm (stored bare, no
    -- suffix, matching the format Blizzard's own GetUnitFullName produces for same-realm units).
    local bareName, embeddedRealm = strsplit("-", StripWowText(rawName))
    local realmBoxText = strtrim(editor.addPlayerRealmBox and editor.addPlayerRealmBox:GetText() or "")
    local localRealm = GetRealmName and GetRealmName() or ""
    local realm = (embeddedRealm ~= "" and embeddedRealm) or (realmBoxText ~= "" and realmBoxText) or localRealm
    local fullName = bareName
    if realm ~= "" and realm ~= localRealm then
        fullName = bareName .. "-" .. realm
    end

    run.members = run.members or {}
    local key = GetPlayerProfileKey(fullName)
    local alreadyInRoster = false
    for _, existingMember in ipairs(run.members) do
        if GetPlayerProfileKey(existingMember.name) == key then
            alreadyInRoster = true
            break
        end
    end

    if not alreadyInRoster then
        local class = self.dataToolAddPlayerClass
        local role = self.dataToolAddPlayerRole or "NONE"
        table.insert(run.members, {
            name = fullName,
            guid = "name:" .. (key or NormalizePlayerName(fullName)),
            class = class ~= "" and class or nil,
            role = role,
        })
    end

    -- Since v0.1.194, the Player Menu table only lists players already in `playerRatings` (that's
    -- what fixed the lag from auto-seeding off every run's roster) -- but that means someone added
    -- here would otherwise never show up there to be rated at all. Unlike the old passive scan,
    -- this is one explicit, deliberate add at a time, so creating a default (Neutral, no notes)
    -- profile for them is safe -- it won't reintroduce the mass auto-seed performance problem.
    --
    -- Deliberately checked even when alreadyInRoster: a player added before this backfill shipped
    -- (v0.1.199) is already on the run's roster but still has no playerRatings entry -- clicking
    -- Add Player again for them is the way to backfill that, so this can't early-return before it.
    local createdProfile = false
    if key and not (self.db.playerRatings and self.db.playerRatings[key]) then
        self.db.playerRatings = self.db.playerRatings or {}
        self.db.playerRatings[key] = {
            name = bareName,
            realm = realm,
            rating = "Okay",
            notes = "",
            updatedAt = time(),
            updatedAtText = date("%Y-%m-%d %H:%M:%S"),
        }
        createdProfile = true
    end
    if editor.addPlayerNameBox then
        editor.addPlayerNameBox:SetText("")
    end
    if editor.addPlayerRealmBox then
        editor.addPlayerRealmBox:SetText("")
    end
    self.dataToolAddPlayerName = nil
    self.dataToolAddPlayerRealm = nil
    self.dataToolAddPlayerClass = nil
    self.dataToolAddPlayerRole = nil
    if alreadyInRoster then
        Print(bareName .. " is already in this run's roster" .. (createdProfile and "; added them to Player Menu to rate." or "."))
    else
        Print("Added " .. fullName .. " to this run" .. (createdProfile and "; also added them to Player Menu to rate." or "."))
    end
    self:RefreshAllDisplays()
end

function Addon:SaveDataToolBoss(skipRefresh)
    local editor = self.dataTools
    local run = self:GetDataToolSelectedRun()
    if not editor or not run then
        Print("Select a run first.")
        return
    end

    local bossID = tonumber(editor.bossIDBox and editor.bossIDBox:GetText() or "") or tonumber(self.dataToolSelectedBossID)
    local bossName = strtrim(editor.bossNameBox and editor.bossNameBox:GetText() or "")
    if not bossID or bossName == "" then
        Print("Enter a boss ID and boss name.")
        return
    end

    local dungeonName = run.instanceName or "Unknown Dungeon"
    self.db.customBossMaps = self.db.customBossMaps or {}
    self.db.customBossMaps[dungeonName] = self.db.customBossMaps[dungeonName] or { bosses = {}, names = {}, final = {} }
    local map = self.db.customBossMaps[dungeonName]
    map.bosses = map.bosses or {}
    map.names = map.names or {}
    map.final = map.final or {}
    map.bosses[bossID] = {
        name = bossName,
        optional = editor.bossOptionalCheck and editor.bossOptionalCheck.checked and true or false,
    }
    map.names[bossName] = bossID
    if editor.bossFinalCheck and editor.bossFinalCheck.checked then
        map.final[bossID] = true
        map.final[bossName] = true
    else
        map.final[bossID] = nil
        map.final[bossName] = nil
    end

    self.db.customBossOrders = self.db.customBossOrders or {}
    self.db.customBossOrders[dungeonName] = self.db.customBossOrders[dungeonName] or {}
    local order = self.db.customBossOrders[dungeonName]
    for index = #order, 1, -1 do
        if tonumber(order[index]) == bossID then
            table.remove(order, index)
        end
    end
    local orderNumber = tonumber(editor.bossOrderBox and editor.bossOrderBox:GetText() or "")
    if orderNumber and orderNumber > 0 then
        table.insert(order, math.min(math.floor(orderNumber), #order + 1), bossID)
    else
        table.insert(order, bossID)
    end

    if run.bossKills and run.bossKills[bossID] then
        run.bossKills[bossID].name = bossName
    end
    local level = tonumber(editor.bossLevelBox and editor.bossLevelBox:GetText() or "")
    local health = tonumber(editor.bossHealthBox and editor.bossHealthBox:GetText() or "")
    local dropsText = strtrim(editor.bossDropsBox and editor.bossDropsBox:GetText() or "")
    local drops
    if dropsText ~= "" then
        drops = {}
        for dropName in dropsText:gmatch("[^,]+") do
            table.insert(drops, strtrim(dropName))
        end
    end
    self:CatalogBoss(run, bossID, bossName, level, health, drops)
    for _, entry in ipairs(run.bossKillLog or {}) do
        if tonumber(entry.bossID) == bossID or tonumber(entry.encounterID) == bossID or tonumber(entry.encounterKey) == bossID then
            entry.name = bossName
        end
    end
    for _, encounter in ipairs(run.encounters or {}) do
        if tonumber(encounter.encounterID) == bossID or tonumber(encounter.encounterKey) == bossID then
            encounter.encounterName = bossName
        end
    end

    self.dataToolSelectedBossID = bossID
    if not skipRefresh then
        Print("Saved boss mapping for " .. bossName .. ".")
        self:RefreshAllDisplays()
    end
end

function Addon:SaveDataToolMob(skipRefresh)
    local editor = self.dataTools
    local run = self:GetDataToolSelectedRun()
    if not editor or not run then
        Print("Select a run first.")
        return
    end

    local npcID = tostring(tonumber(editor.mobIDBox and editor.mobIDBox:GetText() or "") or self.dataToolSelectedMobID or "")
    local mobName = strtrim(editor.mobNameBox and editor.mobNameBox:GetText() or "")
    if npcID == "" or mobName == "" then
        Print("Enter a mob ID and mob name.")
        return
    end

    self.db.mobNameOverrides = self.db.mobNameOverrides or {}
    self.db.mobNameOverrides[npcID] = mobName
    run.mobKills = run.mobKills or {}
    run.mobKills[npcID] = run.mobKills[npcID] or { npcID = npcID, count = 0 }
    run.mobKills[npcID].name = mobName
    self:CatalogMob(run, npcID, mobName)
    for _, entry in ipairs(run.mobKillLog or {}) do
        if tostring(entry.npcID or "") == npcID then
            entry.name = mobName
        end
    end

    self.dataToolSelectedMobID = npcID
    if not skipRefresh then
        Print("Saved mob name for " .. mobName .. ".")
        self:RefreshAllDisplays()
    end
end

-- sourceEditor (new 2026-09-05, for the standalone Add Player window): the widget container to
-- read playerNameBox/playerRealmBox/playerNotesBox from. Defaults to self.dataTools so every
-- existing call site (the Data Tools Player tab) is unaffected. When called from the standalone
-- window, `run` is deliberately skipped -- that window has no run context at all, and using
-- whatever run happened to be selected elsewhere would touch up an unrelated run's roster.
function Addon:SaveDataToolPlayer(skipRefresh, sourceEditor)
    local editor = sourceEditor or self.dataTools
    if not editor then
        return
    end
    -- Redesigned 2026-09-04 alongside the new Player Menu table: `run` is no longer required here.
    -- The rating/notes profile below is global (self.db.playerRatings), not per-run, so saving it
    -- was previously blocked by an unrelated "select a run first" guard the new player-browsing
    -- flow doesn't naturally satisfy anymore. If a run still happens to be selected (e.g. the user
    -- was just on the Run tab), the roster-touch-up behavior below still runs as a bonus -- it's
    -- just no longer required for the profile save to go through.
    local run = (editor == self.dataTools) and self:GetDataToolSelectedRun() or nil

    -- Found in review 2026-09-06: this function used to always read/write the Data Tools Player
    -- tab's own dataToolSelectedPlayer* fields, even when called from the standalone Add Player
    -- window (sourceEditor = that window). That meant saving a brand-new player through Add Player
    -- would silently overwrite whichever player Data Tools had selected (previousKey), and point
    -- Data Tools' selection at the just-added player afterward -- real data corruption, not just a
    -- display glitch. The Add Player window now keeps its own separate addPlayerForm* fields; pick
    -- the correct set based on which window is actually saving.
    local isAddPlayerForm = (editor == self.addPlayerWindow)
    local selClass = isAddPlayerForm and self.addPlayerFormClass or self.dataToolSelectedPlayerClass
    local selRole = isAddPlayerForm and self.addPlayerFormRole or self.dataToolSelectedPlayerRole
    local selRace = isAddPlayerForm and self.addPlayerFormRace or self.dataToolSelectedPlayerRace
    local selFaction = isAddPlayerForm and self.addPlayerFormFaction or self.dataToolSelectedPlayerFaction
    local selRating = isAddPlayerForm and self.addPlayerFormRating or self.dataToolSelectedPlayerRating
    local selIsGuild = isAddPlayerForm and self.addPlayerFormIsGuild or self.dataToolSelectedPlayerIsGuild
    local selIsFrequent = isAddPlayerForm and self.addPlayerFormIsFrequent or self.dataToolSelectedPlayerIsFrequent

    local oldName = self.dataToolSelectedPlayerName or ""
    local newName = strtrim(editor.playerNameBox and editor.playerNameBox:GetText() or "")
    if newName == "" then
        Print("Enter a player name.")
        return
    end

    if run then
        local matched = false
        local oldNormalized = NormalizePlayerName(oldName)
        run.members = run.members or {}
        for _, member in ipairs(run.members) do
            if oldNormalized == "" or NormalizePlayerName(member.name) == oldNormalized then
                member.name = newName
                if selClass ~= nil then
                    member.class = selClass ~= "" and selClass or nil
                end
                if selRole ~= nil then
                    member.role = selRole ~= "" and selRole or "NONE"
                end
                matched = true
                break
            end
        end
        if not matched then
            table.insert(run.members, {
                name = newName,
                guid = "name:" .. (GetPlayerProfileKey(newName) or NormalizePlayerName(newName)),
                class = selClass ~= "" and selClass or nil,
                role = selRole or "NONE",
            })
        end

        for _, entry in ipairs(run.memberDeathLog or {}) do
            if oldName == "" or NormalizePlayerName(entry.name) == NormalizePlayerName(oldName) then
                entry.name = newName
                if selClass ~= nil then
                    entry.class = selClass ~= "" and selClass or nil
                end
                if selRole ~= nil then
                    entry.role = selRole ~= "" and selRole or "NONE"
                end
            end
        end
        for key, info in pairs(run.memberDeaths or {}) do
            if info and (oldName == "" or NormalizePlayerName(info.name) == NormalizePlayerName(oldName)
                or key == ("name:" .. NormalizePlayerName(oldName))
                or key == ("name:" .. (GetPlayerProfileKey(oldName) or ""))) then
                info.name = newName
                if selClass ~= nil then
                    info.class = selClass ~= "" and selClass or nil
                end
                if selRole ~= nil then
                    info.role = selRole ~= "" and selRole or "NONE"
                end
            end
        end
    end
    do
        local player, realm = GetPlayerRealmName(newName)
        local chosenRealm = strtrim(editor.playerRealmBox and editor.playerRealmBox:GetText() or "") ~= "" and strtrim(editor.playerRealmBox:GetText()) or realm
        local key = string.lower((player or newName) .. "-" .. (chosenRealm or ""))
        self.db.playerRatings = self.db.playerRatings or {}
        -- This is an update to whichever profile was actually selected (by key, not just name --
        -- see the duplicate-profile fix above) as long as the name/Realm boxes weren't changed to
        -- resolve to a different key. If they WERE changed (e.g. correcting a wrong realm), that's
        -- still meant as editing the same person, not creating a second one -- carry their old
        -- rating/notes/markers forward as the starting point, then remove the old key so editing a
        -- realm can never again leave a stale duplicate behind (the exact class of bug that caused
        -- the "phantom player" reports fixed in v0.1.197).
        -- The Add Player window never has a "previously selected" player at all -- it's always a
        -- fresh form -- so it falls straight through to the new key's own existing profile (if any)
        -- below, which already correctly merges into an existing player if the typed name+realm
        -- matches one.
        local previousKey = (not isAddPlayerForm) and self.dataToolSelectedPlayerKey or nil
        -- Two real WoW players can never share the same exact name+realm, so a previousKey/newKey
        -- collision with someone ELSE's existing profile isn't a real-world case here -- prefer
        -- whichever table already exists (previousKey's, since that's the one actually being
        -- edited), falling back to the new key's only for a brand-new player with no prior key.
        local profile = (previousKey and self.db.playerRatings[previousKey]) or self.db.playerRatings[key] or {}
        self.db.playerRatings[key] = profile
        if previousKey and previousKey ~= key then
            self.db.playerRatings[previousKey] = nil
        end
        profile.name = player
        profile.realm = chosenRealm
        profile.rating = selRating or profile.rating or "Okay"
        self:StampProfileRecordedBy(profile)
        profile.notes = strtrim(editor.playerNotesBox and editor.playerNotesBox:GetText() or "")
        -- Class/Role/Race/Faction persisted on the profile itself (new 2026-09-05) -- previously
        -- Class/Role only ever got written to a run's member/deathLog entries below, which meant a
        -- manually-added player with no run yet had nowhere for that choice to actually stick.
        if selClass ~= nil then
            profile.class = selClass ~= "" and selClass or nil
        end
        if selRole ~= nil then
            profile.role = selRole ~= "" and selRole or nil
        end
        if selRace ~= nil then
            profile.race = selRace ~= "" and selRace or nil
        end
        if selFaction ~= nil then
            profile.faction = selFaction ~= "" and selFaction or nil
        end
        if selIsGuild ~= nil then
            profile.isGuildMember = selIsGuild
        end
        if selIsFrequent ~= nil then
            profile.isFrequent = selIsFrequent
        end
        profile.updatedAt = time()
        profile.updatedAtText = date("%Y-%m-%d %H:%M:%S")
        -- Only the Data Tools Player tab's own save should move ITS selection -- the Add Player
        -- window closes right after this (see its Save button) and has nothing of its own left to
        -- point at, and must never repoint Data Tools' selection out from under it.
        if not isAddPlayerForm then
            -- Point selection at the exact key just written, not a name that could still match more
            -- than one saved profile (see the duplicate-profile fix above).
            self.dataToolSelectedPlayerKey = key
        end
    end
    if not isAddPlayerForm then
        self.dataToolSelectedPlayerName = newName
    end
    if not skipRefresh then
        Print("Saved player: " .. newName .. ".")
        self:RefreshAllDisplays()
    end
end

-- Only removes the saved rating/notes profile (self.db.playerRatings) -- does not touch that
-- player's name/class/role on any past run's roster, same as how Delete Run only removes the run
-- itself, not unrelated data.
function Addon:DeleteDataToolPlayer()
    local name = self.dataToolSelectedPlayerName
    -- The explicit selected key wins when set -- re-deriving from name would risk deleting the
    -- wrong one of two same-named duplicate profiles (see the duplicate-profile fix above).
    local key = self.dataToolSelectedPlayerKey or GetPlayerProfileKey(name)
    if not key or key == "" then
        return
    end
    if self.db.playerRatings then
        self.db.playerRatings[key] = nil
    end
    Print("Deleted saved player: " .. (name or key) .. ".")
    self.dataToolSelectedPlayerKey = nil
    self.dataToolSelectedPlayerName = nil
    self.dataToolSelectedPlayerClass = nil
    self.dataToolSelectedPlayerRole = nil
    self.dataToolSelectedPlayerRace = nil
    self.dataToolSelectedPlayerFaction = nil
    self.dataToolSelectedPlayerRealm = nil
    self.dataToolSelectedPlayerNotes = nil
    self.dataToolSelectedPlayerRating = nil
    self.dataToolSelectedPlayerIsGuild = nil
    self.dataToolSelectedPlayerIsFrequent = nil
    self:RefreshAllDisplays()
end

-- Bulk clear operations for the Player Reputation History window -- per user request 2026-09-30
-- ("Clear All Player Data History as well as Clear Trusted, Clear Avoid, Clear Neutral"). Only
-- ever touches self.db.playerRatings (the same table Delete Player above removes one entry from)
-- -- run history/rosters themselves are untouched, same scope boundary as Delete Player. Both are
-- genuinely irreversible bulk deletes, so both are only ever called from behind the
-- MPLUSLEDGER_CONFIRM_CLEAR_PLAYERS popup below, never directly from a button's OnClick.
StaticPopupDialogs["MPLUSLEDGER_CONFIRM_CLEAR_PLAYERS"] = {
    text = "%s",
    button1 = "Clear",
    button2 = "Cancel",
    OnAccept = function(_, data)
        if data and data.onConfirm then
            data.onConfirm()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Addon:ConfirmClearPlayerData(message, onConfirm)
    StaticPopup_Show("MPLUSLEDGER_CONFIRM_CLEAR_PLAYERS", message, nil, { onConfirm = onConfirm })
end

function Addon:ClearAllPlayerData()
    local count = 0
    for _ in pairs(self.db.playerRatings or {}) do
        count = count + 1
    end
    self.db.playerRatings = {}
    self.dataToolSelectedPlayerKey = nil
    self.dataToolSelectedPlayerName = nil
    self.dataToolPlayerHistoryOffset = 0
    Print(string.format("Cleared all player data (%d player%s removed).", count, count == 1 and "" or "s"))
    self:RefreshAllDisplays()
end

-- rating: "Good"/"Okay"/"Bad" (the stored value -- see RATING_META for the friendlier displayed
-- Trusted/Neutral/Avoid labels).
function Addon:ClearPlayerDataByRating(rating)
    local count = 0
    for key, profile in pairs(self.db.playerRatings or {}) do
        if (profile.rating or "Okay") == rating then
            if self.dataToolSelectedPlayerKey == key then
                self.dataToolSelectedPlayerKey = nil
                self.dataToolSelectedPlayerName = nil
            end
            self.db.playerRatings[key] = nil
            count = count + 1
        end
    end
    self.dataToolPlayerHistoryOffset = 0
    Print(string.format("Cleared %d %s player%s.", count, GetRatingMeta(rating).label, count == 1 and "" or "s"))
    self:RefreshAllDisplays()
end

-- Removes one specific run's worth of a player's appearance -- for a wrong roster capture (e.g.
-- "Calmviolent shows 3 runs, only 2 are real"), not their whole saved rating (that's Delete
-- Player above). Strips that player from the run's roster and cleans up their death records on
-- that same run so nothing orphaned points at a run they were never actually in.
function Addon:RemoveDataToolPlayerRunAppearance(key, runID)
    local run = self:GetRun(runID)
    if not run or not key then
        return
    end
    local removedName = nil
    if run.members then
        for i = #run.members, 1, -1 do
            local member = run.members[i]
            if member.name and GetPlayerProfileKey(member.name) == key then
                removedName = removedName or member.name
                table.remove(run.members, i)
            end
        end
    end
    if run.memberDeathLog then
        for i = #run.memberDeathLog, 1, -1 do
            local entry = run.memberDeathLog[i]
            if entry.name and GetPlayerProfileKey(entry.name) == key then
                table.remove(run.memberDeathLog, i)
            end
        end
    end
    -- Bug found 2026-09-06 via a direct SavedVariables audit (run 104, Kings' Rest: run.deaths=9
    -- but only 8 memberDeathLog entries / 8 summed memberDeaths.count remained) -- this function
    -- deleted a removed player's own death records but never subtracted them from run.deaths (the
    -- aggregate counter RecordMemberDeathByGUID/ByDisplayName increment, and the one GetRunDeathTotal
    -- treats as authoritative via math.max). Every historical/current run's displayed death total
    -- inflates by however many deaths the removed player had, permanently, the moment this ran.
    local removedDeathCount = 0
    local removedWasPlayer = false
    local playerGUIDForRun = self:GetPlayerGUIDForRun(run)
    if run.memberDeaths then
        for deathKey, info in pairs(run.memberDeaths) do
            if deathKey == ("name:" .. key) or (info and info.name and GetPlayerProfileKey(info.name) == key) then
                removedDeathCount = removedDeathCount + (tonumber(info and info.count) or 0)
                if deathKey == playerGUIDForRun then
                    removedWasPlayer = true
                end
                run.memberDeaths[deathKey] = nil
            end
        end
    end
    if removedDeathCount > 0 then
        run.deaths = math.max(0, (tonumber(run.deaths) or 0) - removedDeathCount)
        if removedWasPlayer then
            run.playerDeaths = math.max(0, (tonumber(run.playerDeaths) or 0) - removedDeathCount)
        end
    end
    if not removedName then
        Print("That player wasn't found on this run's roster.")
        return
    end
    Print("Removed " .. removedName .. " from " .. (run.instanceName or "that run") .. ".")
    self:RefreshAllDisplays()
end

function Addon:SaveDataToolsAll()
    local editor = self.dataTools
    local mode = self.dataToolMode or (editor and editor.mode)
    if mode == "instanceData" or mode == "unassigned" or mode == "hub" then
        Print("Use the save button inside this data page.")
        return
    end

    local run = self:GetDataToolSelectedRun()
    if not editor or not run then
        Print("Select or create a run first.")
        return
    end

    if mode == "run" or mode == "instance" or mode == "expansion" or mode == "create" then
        self:SaveDataToolRunBasics()
        return
    elseif mode == "boss" then
        self:SaveDataToolBoss()
        return
    elseif mode == "mob" then
        self:SaveDataToolMob()
        return
    elseif mode == "player" then
        self:SaveDataToolPlayer()
        return
    end

    self:SaveDataToolRunBasics(true)
    if strtrim(editor.bossIDBox and editor.bossIDBox:GetText() or "") ~= "" and strtrim(editor.bossNameBox and editor.bossNameBox:GetText() or "") ~= "" then
        self:SaveDataToolBoss(true)
    end
    if strtrim(editor.mobIDBox and editor.mobIDBox:GetText() or "") ~= "" and strtrim(editor.mobNameBox and editor.mobNameBox:GetText() or "") ~= "" then
        self:SaveDataToolMob(true)
    end
    if strtrim(editor.playerNameBox and editor.playerNameBox:GetText() or "") ~= "" then
        self:SaveDataToolPlayer(true)
    end
    self:RefreshAllDisplays()
    Print("Data tools saved.")
end

function Addon:OpenAdventureGuideForRun(run)
    run = run or self:GetDataToolSelectedRun()
    local metadata = run and self.db and self.db.dungeonMetadata and self.db.dungeonMetadata[run.instanceName or ""]
    local journalInstanceID = tonumber((metadata and metadata.journalInstanceID) or (run and run.journalInstanceID))
    if not journalInstanceID then
        Print("Add the Adventure Guide ID for this dungeon in Manage Data first.")
        return
    end

    if EncounterJournal_LoadUI then
        EncounterJournal_LoadUI()
    end
    if EncounterJournal_OpenJournal then
        -- Mythic+ runs stored their real difficultyID (8, "Mythic Keystone") -- the Adventure
        -- Guide has no separate content filed under that ID, so requesting it opened nothing
        -- useful. Per user report 2026-09-30 ("there is no guide for M+"): a Mythic+ run's guide
        -- content actually lives under plain Mythic (23, the base dungeon difficulty, same
        -- encounter/ability data keystone runs use) -- use that instead for M+ runs specifically.
        local difficultyID = tonumber(run and run.difficultyID) or 1
        if run and self:IsMythicPlusRun(run) then
            difficultyID = 23
        end
        local ok = pcall(EncounterJournal_OpenJournal, difficultyID, journalInstanceID)
        if ok then
            return
        end
    end
    if EncounterJournal and ShowUIPanel then
        ShowUIPanel(EncounterJournal)
    end
    if EJ_SelectInstance then
        EJ_SelectInstance(journalInstanceID)
    else
        Print("Adventure Guide is not available on this client.")
    end
end

function Addon:RefreshSimpleDropdown(menu, options, onPick)
    if not menu then
        return
    end

    menu.buttons = menu.buttons or {}
    for _, button in ipairs(menu.buttons) do
        button:Hide()
    end

    if not options or #options == 0 then
        menu:Hide()
        return
    end

    menu.options = options
    menu.onPick = onPick
    menu.offset = math.max(0, math.min(tonumber(menu.offset) or 0, math.max(0, #options - 12)))
    menu:EnableMouseWheel(true)
    menu:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math.max(0, #(self.options or {}) - 12)
        self.offset = math.max(0, math.min(maxOffset, (tonumber(self.offset) or 0) + (delta > 0 and -1 or 1)))
        Addon:RefreshSimpleDropdown(self, self.options, self.onPick)
        self:Show()
    end)

    local height = 6
    local visibleCount = math.min(#options, 12)
    for visibleIndex = 1, visibleCount do
        local index = visibleIndex + menu.offset
        local option = options[index]
        local button = menu.buttons[index]
        if not button then
            button = self:CreatePlainButton(menu, "", 220, 22)
            menu.buttons[index] = button
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 4, -4 - ((visibleIndex - 1) * 24))
        if not menu.buttons[index] then
            menu.buttons[index] = button
        end
        button:SetWidth(math.max(80, (menu:GetWidth() or 228) - 8))
        button:SetText(option.text or tostring(option.value or ""))
        button.value = option.value
        if option.backdrop then
            button:SetBackdropColor(option.backdrop[1] or 0.45, option.backdrop[2] or 0.02, option.backdrop[3] or 0.02, 0.88)
            button.normalBackdrop = option.backdrop
        else
            button:SetBackdropColor(0.45, 0.02, 0.02, 0.85)
            button.normalBackdrop = nil
        end
        button:SetScript("OnClick", function(self)
            menu:Hide()
            onPick(self.value)
        end)
        button:Show()
        height = height + 24
    end
    menu:SetHeight(height)
end

function Addon:CreateDebugEditorWindow()
    if self.debugEditor then
        return
    end

    local editor = CreateFrame("Frame", "MPlusLedgerDebugEditorFrame", UIParent, "BackdropTemplate")
    editor:SetSize(820, 620)
    editor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    editor:SetFrameStrata("FULLSCREEN_DIALOG")
    editor:SetFrameLevel(320)
    editor:SetToplevel(true)
    editor:SetMovable(true)
    editor:EnableMouse(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", editor.StartMoving)
    editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
    EnableEscHandler(editor, function()
        Addon:HandleDebugEditorEscape()
    end)
    editor:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    editor:SetBackdropColor(0, 0, 0, 1.00)

    -- Portrait icon, matching the rest of the addon's windows (UI consistency pass, 2026-09-01).
    local portraitRing = editor:CreateTexture(nil, "OVERLAY", nil, 1)
    portraitRing:SetSize(50, 50)
    portraitRing:SetPoint("TOPLEFT", 9, -9)
    portraitRing:SetColorTexture(self:GetThemeBorderColor(true, 0.9))
    local portrait = editor:CreateTexture(nil, "OVERLAY", nil, 2)
    portrait:SetSize(44, 44)
    portrait:SetPoint("CENTER", portraitRing, "CENTER", 0, 0)
    portrait:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    portrait:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")

    local title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -22)
    title:SetText("M+ Ledger Run Editor")

    local close = self:CreatePlainButton(editor, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -18, -18)
    close:SetScript("OnClick", function()
        Addon:ReturnToMainMenu()
    end)

    editor.runLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editor.runLabel:SetPoint("TOPLEFT", 36, -58)
    editor.runLabel:SetWidth(680)
    editor.runLabel:SetJustifyH("LEFT")

    editor.detail = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editor.detail:SetPoint("TOPLEFT", editor.runLabel, "BOTTOMLEFT", 0, -8)
    editor.detail:SetWidth(680)
    editor.detail:SetHeight(66)
    editor.detail:SetJustifyH("LEFT")
    editor.detail:SetJustifyV("TOP")
    editor.detail:SetWordWrap(true)

    local function addLabel(text, anchor, x, y)
        local label = editor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetPoint("TOPLEFT", anchor, x, y)
        label:SetText(text)
        return label
    end

    local tabFields = {}
    local function focusNextField(current)
        if #tabFields == 0 then
            return
        end

        local currentIndex = 1
        for index, field in ipairs(tabFields) do
            if field == current then
                currentIndex = index
                break
            end
        end

        local delta = IsShiftKeyDown and IsShiftKeyDown() and -1 or 1
        local nextIndex = currentIndex + delta
        if nextIndex > #tabFields then
            nextIndex = 1
        elseif nextIndex < 1 then
            nextIndex = #tabFields
        end

        for _ = 1, #tabFields do
            local nextField = tabFields[nextIndex]
            if nextField and (not nextField.IsShown or nextField:IsShown()) then
                nextField:SetFocus()
                nextField:HighlightText()
                return
            end
            nextIndex = nextIndex + delta
            if nextIndex > #tabFields then
                nextIndex = 1
            elseif nextIndex < 1 then
                nextIndex = #tabFields
            end
        end
    end

    local function createMoneyBox(label, icon, x)
        addLabel(label .. " " .. icon, editor, x, -150)
        local box = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        box:SetSize(58, 24)
        box:SetPoint("TOPLEFT", x, -168)
        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetTextInsets(4, 4, 0, 0)
        box:SetScript("OnEnterPressed", function(self)
            Addon:AddDebugRepairCost()
            self:ClearFocus()
            Addon:RefreshDebugEditorWindow()
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        box:SetScript("OnTabPressed", function(self)
            focusNextField(self)
        end)
        table.insert(tabFields, box)
        return box
    end

    local function createTimeBox(prefix, label, x, y, onApply)
        addLabel(label, editor, x, y)
        addLabel("Minutes", editor, x, y - 18)
        local minutesBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        minutesBox:SetSize(54, 24)
        minutesBox:SetPoint("TOPLEFT", x, y - 36)
        minutesBox:SetAutoFocus(false)
        minutesBox:SetNumeric(true)
        minutesBox:SetTextInsets(4, 4, 0, 0)
        minutesBox:SetScript("OnEnterPressed", function(self)
            onApply()
            self:ClearFocus()
            Addon:RefreshDebugEditorWindow()
        end)
        minutesBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        minutesBox:SetScript("OnTabPressed", function(self)
            focusNextField(self)
        end)
        table.insert(tabFields, minutesBox)

        addLabel("Seconds", editor, x + 64, y - 18)
        local secondsBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        secondsBox:SetSize(54, 24)
        secondsBox:SetPoint("TOPLEFT", x + 64, y - 36)
        secondsBox:SetAutoFocus(false)
        secondsBox:SetNumeric(true)
        secondsBox:SetTextInsets(4, 4, 0, 0)
        secondsBox:SetScript("OnEnterPressed", function(self)
            onApply()
            self:ClearFocus()
            Addon:RefreshDebugEditorWindow()
        end)
        secondsBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        secondsBox:SetScript("OnTabPressed", function(self)
            focusNextField(self)
        end)
        table.insert(tabFields, secondsBox)

        local apply = self:CreatePlainButton(editor, "Set", 58, 24)
        apply:SetPoint("TOPLEFT", x + 128, y - 36)
        apply:SetScript("OnClick", function()
            onApply()
            Addon:RefreshDebugEditorWindow()
        end)

        editor[prefix .. "MinutesBox"] = minutesBox
        editor[prefix .. "SecondsBox"] = secondsBox
    end

    editor.repairGoldBox = createMoneyBox("Gold", "|TInterface\\MoneyFrame\\UI-GoldIcon:13:13:0:0|t", 36)
    editor.repairSilverBox = createMoneyBox("Silver", "|TInterface\\MoneyFrame\\UI-SilverIcon:13:13:0:0|t", 104)
    editor.repairCopperBox = createMoneyBox("Copper", "|TInterface\\MoneyFrame\\UI-CopperIcon:13:13:0:0|t", 172)

    local addRepair = self:CreatePlainButton(editor, "Add Repair", 100, 24)
    addRepair:SetPoint("LEFT", editor.repairCopperBox, "RIGHT", 12, 0)
    addRepair:SetScript("OnClick", function()
        Addon:AddDebugRepairCost()
        Addon:RefreshDebugEditorWindow()
    end)

    addLabel("Difficulty", editor, 380, -150)
    editor.difficultyButton = self:CreatePlainButton(editor, "Difficulty", 130, 24)
    editor.difficultyButton:SetPoint("TOPLEFT", 380, -168)

    editor.difficultyLevelLabel = addLabel("M+ level", editor, 524, -150)
    local difficultyLevelBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    difficultyLevelBox:SetSize(54, 24)
    difficultyLevelBox:SetPoint("TOPLEFT", 524, -168)
    difficultyLevelBox:SetAutoFocus(false)
    difficultyLevelBox:SetNumeric(true)
    difficultyLevelBox:SetTextInsets(4, 4, 0, 0)
    difficultyLevelBox:SetScript("OnEnterPressed", function(self)
        Addon:SetRunDifficultyDebug("mythicPlus")
        self:ClearFocus()
        Addon:RefreshDebugEditorWindow()
    end)
    difficultyLevelBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    difficultyLevelBox:SetScript("OnTabPressed", function(self)
        focusNextField(self)
    end)
    editor.difficultyLevelBox = difficultyLevelBox
    table.insert(tabFields, difficultyLevelBox)
    editor.difficultyLevelLabel:Hide()
    editor.difficultyLevelBox:Hide()

    addLabel("Player", editor, 36, -224)
    editor.playerButton = self:CreatePlainButton(editor, "Select Player", 280, 24)
    editor.playerButton:SetPoint("TOPLEFT", 36, -242)

    addLabel("Deaths to add", editor, 350, -224)
    local deathCountBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    deathCountBox:SetSize(60, 24)
    deathCountBox:SetPoint("TOPLEFT", 350, -242)
    deathCountBox:SetAutoFocus(false)
    deathCountBox:SetTextInsets(4, 4, 0, 0)
    deathCountBox:SetText("1")
    deathCountBox:SetScript("OnEnterPressed", function(self)
        Addon:AddDebugPlayerDeaths()
        self:ClearFocus()
        Addon:RefreshDebugEditorWindow()
    end)
    deathCountBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    deathCountBox:SetScript("OnTabPressed", function(self)
        focusNextField(self)
    end)
    editor.deathCountBox = deathCountBox
    table.insert(tabFields, deathCountBox)

    local addDeath = self:CreatePlainButton(editor, "Add Death", 96, 24)
    addDeath:SetPoint("LEFT", deathCountBox, "RIGHT", 12, 0)
    addDeath:SetScript("OnClick", function()
        Addon:AddDebugPlayerDeaths()
        Addon:RefreshDebugEditorWindow()
    end)

    addLabel("Boss", editor, 36, -298)
    editor.bossButton = self:CreatePlainButton(editor, "Select Boss", 440, 24)
    editor.bossButton:SetPoint("TOPLEFT", 36, -316)

    local bossKilled = self:CreatePlainButton(editor, "Mark Killed", 110, 24)
    bossKilled:SetPoint("LEFT", editor.bossButton, "RIGHT", 12, 0)
    bossKilled:SetScript("OnClick", function()
        Addon:SetDebugBossKilled(true)
        Addon:RefreshDebugEditorWindow()
    end)

    local bossReset = self:CreatePlainButton(editor, "Reset Boss", 100, 24)
    bossReset:SetPoint("LEFT", bossKilled, "RIGHT", 10, 0)
    bossReset:SetScript("OnClick", function()
        Addon:SetDebugBossKilled(false)
        Addon:RefreshDebugEditorWindow()
    end)

    createTimeBox("runTime", "Run Time", 36, -360, function()
        Addon:SetDebugRunTime()
    end)
    createTimeBox("bossTime", "Boss Kill Time", 262, -360, function()
        Addon:SetDebugBossKillTime()
    end)
    createTimeBox("mobTime", "Mob Kill Time", 508, -360, function()
        Addon:SetDebugMobKillTime()
    end)

    local completed = self:CreatePlainButton(editor, "Completed", 110, 26)
    completed:SetPoint("BOTTOMLEFT", 36, 34)
    ApplyButtonColor(completed, STATUS_BACKDROP_COLORS.Completed)
    completed:SetScript("OnClick", function()
        Addon:SetRunStatusDebug("Completed")
        Addon:RefreshDebugEditorWindow()
    end)

    local overtime = self:CreatePlainButton(editor, "Overtime", 100, 26)
    overtime:SetPoint("LEFT", completed, "RIGHT", 12, 0)
    ApplyButtonColor(overtime, STATUS_BACKDROP_COLORS.CompletedOvertime)
    overtime:SetScript("OnClick", function()
        Addon:SetRunStatusDebug("CompletedOvertime")
        Addon:RefreshDebugEditorWindow()
    end)

    local abandoned = self:CreatePlainButton(editor, "Failed", 110, 26)
    abandoned:SetPoint("LEFT", overtime, "RIGHT", 12, 0)
    ApplyButtonColor(abandoned, STATUS_BACKDROP_COLORS.Abandoned)
    abandoned:SetScript("OnClick", function()
        Addon:SetRunStatusDebug("Abandoned")
        Addon:RefreshDebugEditorWindow()
    end)
    editor.abandonedButton = abandoned

    local active = self:CreatePlainButton(editor, "Active", 90, 26)
    active:SetPoint("LEFT", abandoned, "RIGHT", 12, 0)
    ApplyButtonColor(active, STATUS_BACKDROP_COLORS.Active)
    active:SetScript("OnClick", function()
        Addon:SetRunStatusDebug("Active")
        Addon:RefreshDebugEditorWindow()
    end)

    local save = self:CreatePlainButton(editor, "Save", 90, 26)
    save:SetPoint("BOTTOMRIGHT", -36, 34)
    save:SetScript("OnClick", function()
        Addon:RefreshAllDisplays()
        Print("Run editor saved.")
    end)

    editor.playerMenu = CreateFrame("Frame", nil, editor, "BackdropTemplate")
    editor.playerMenu:SetSize(290, 30)
    editor.playerMenu:SetPoint("TOPLEFT", editor.playerButton, "BOTTOMLEFT", 0, -2)
    editor.playerMenu:SetFrameLevel(editor:GetFrameLevel() + 20)
    editor.playerMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    editor.playerMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    editor.playerMenu:EnableMouse(true)
    editor.playerMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    editor.playerMenu:Hide()

    editor.bossMenu = CreateFrame("Frame", nil, editor, "BackdropTemplate")
    editor.bossMenu:SetSize(450, 30)
    editor.bossMenu:SetPoint("TOPLEFT", editor.bossButton, "BOTTOMLEFT", 0, -2)
    editor.bossMenu:SetFrameLevel(editor:GetFrameLevel() + 20)
    editor.bossMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    editor.bossMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    editor.bossMenu:EnableMouse(true)
    editor.bossMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    editor.bossMenu:Hide()

    editor.difficultyMenu = CreateFrame("Frame", nil, editor, "BackdropTemplate")
    editor.difficultyMenu:SetSize(140, 30)
    editor.difficultyMenu:SetPoint("TOPLEFT", editor.difficultyButton, "BOTTOMLEFT", 0, -2)
    editor.difficultyMenu:SetFrameLevel(editor:GetFrameLevel() + 20)
    editor.difficultyMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    editor.difficultyMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    editor.difficultyMenu:EnableMouse(true)
    editor.difficultyMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    editor.difficultyMenu:Hide()

    editor.playerButton:SetScript("OnClick", function()
        editor.bossMenu:Hide()
        editor.difficultyMenu:Hide()
        if editor.playerMenu:IsShown() then
            editor.playerMenu:Hide()
        else
            editor.playerMenu:Show()
        end
    end)
    editor.bossButton:SetScript("OnClick", function()
        editor.playerMenu:Hide()
        editor.difficultyMenu:Hide()
        if editor.bossMenu:IsShown() then
            editor.bossMenu:Hide()
        else
            editor.bossMenu:Show()
        end
    end)
    editor.difficultyButton:SetScript("OnClick", function()
        editor.playerMenu:Hide()
        editor.bossMenu:Hide()
        if editor.difficultyMenu:IsShown() then
            editor.difficultyMenu:Hide()
        else
            editor.difficultyMenu:Show()
        end
    end)

    editor:Hide()
    self.debugEditor = editor
end

function Addon:RefreshDebugEditorWindow()
    if not self.debugEditor then
        return
    end

    local editor = self.debugEditor
    local run = self:GetDebugSelectedRun()
    if not run then
        editor.runLabel:SetText("No run selected.")
        editor.detail:SetText("Select a run in the M+ Ledger window first.")
        editor.playerButton:SetText("No players")
        editor.bossButton:SetText("No bosses")
        editor.difficultyButton:SetText("Difficulty")
        if editor.difficultyLevelBox then
            editor.difficultyLevelBox:SetText("")
            editor.difficultyLevelBox:Hide()
        end
        if editor.difficultyLevelLabel then
            editor.difficultyLevelLabel:Hide()
        end
        if editor.difficultyMenu then
            editor.difficultyMenu:Hide()
        end
        self:SetDebugTimeBoxes("runTime", 0)
        self:SetDebugTimeBoxes("bossTime", 0)
        self:SetDebugTimeBoxes("mobTime", 0)
        return
    end

    editor.runLabel:SetText(string.format("%s | %s | %s", self:GetRunCode(run) or tostring(run.id or "?"), run.instanceName or "Unknown run", self:GetRunDisplayStatus(run)))
    editor.detail:SetText(self:GetDebugRunDetails(run))
    self:SetDebugTimeBoxes("runTime", GetRunDuration(run))
    self:SetDebugTimeBoxes("mobTime", self:GetDebugMobKillTime(run))
    if editor.abandonedButton then
        editor.abandonedButton:SetText(self:IsMythicPlusRun(run) and "Abandoned" or "Left")
    end

    local difficultyOptions = self:GetDebugDifficultyOptions()
    local selectedDifficulty = self:GetDifficultyBucket(run)
    local selectedDifficultyText = "Difficulty"
    local selectedDifficultyBackdrop = nil
    for _, option in ipairs(difficultyOptions) do
        if option.value == selectedDifficulty then
            selectedDifficultyText = option.text
            selectedDifficultyBackdrop = option.backdrop
            break
        end
    end
    editor.difficultyButton:SetText(selectedDifficultyText)
    ApplyButtonColor(editor.difficultyButton, selectedDifficultyBackdrop)
    if editor.difficultyLevelBox then
        if selectedDifficulty == "mythicPlus" then
            editor.difficultyLevelBox:SetText(tostring(self:GetRunKeyLevel(run) > 0 and self:GetRunKeyLevel(run) or 2))
            editor.difficultyLevelBox:Show()
            if editor.difficultyLevelLabel then
                editor.difficultyLevelLabel:Show()
            end
        else
            editor.difficultyLevelBox:SetText("")
            editor.difficultyLevelBox:Hide()
            if editor.difficultyLevelLabel then
                editor.difficultyLevelLabel:Hide()
            end
        end
    end
    self:RefreshSimpleDropdown(editor.difficultyMenu, difficultyOptions, function(value)
        Addon:SetRunDifficultyDebug(value)
        Addon:RefreshDebugEditorWindow()
    end)

    local playerOptions = self:GetDebugPlayerOptions(run)
    if #playerOptions > 0 and not self.debugSelectedPlayerName then
        self.debugSelectedPlayerName = playerOptions[1].value
    end
    local selectedPlayerText = "Select Player"
    local selectedPlayerBackdrop = nil
    for _, option in ipairs(playerOptions) do
        if option.value == self.debugSelectedPlayerName then
            selectedPlayerText = option.text
            selectedPlayerBackdrop = option.backdrop
            break
        end
    end
    editor.playerButton:SetText(selectedPlayerText)
    editor.playerButton.normalBackdrop = selectedPlayerBackdrop
    if selectedPlayerBackdrop then
        editor.playerButton:SetBackdropColor(selectedPlayerBackdrop[1] or 0.45, selectedPlayerBackdrop[2] or 0.02, selectedPlayerBackdrop[3] or 0.02, 0.88)
    else
        editor.playerButton:SetBackdropColor(0.45, 0.02, 0.02, 0.85)
    end
    self:RefreshSimpleDropdown(editor.playerMenu, playerOptions, function(value)
        Addon.debugSelectedPlayerName = value
        Addon:RefreshDebugEditorWindow()
    end)

    local bossOptions = self:GetDebugBossOptions(run)
    if #bossOptions > 0 and not self.debugSelectedBossID then
        self.debugSelectedBossID = bossOptions[1].value
    end
    local selectedBossText = "Select Boss"
    local selectedBossBackdrop = nil
    for _, option in ipairs(bossOptions) do
        if option.value == self.debugSelectedBossID then
            selectedBossText = option.text
            selectedBossBackdrop = option.backdrop
            break
        end
    end
    editor.bossButton:SetText(selectedBossText)
    editor.bossButton.normalBackdrop = selectedBossBackdrop
    if selectedBossBackdrop then
        editor.bossButton:SetBackdropColor(selectedBossBackdrop[1] or 0.45, selectedBossBackdrop[2] or 0.02, selectedBossBackdrop[3] or 0.02, 0.88)
    else
        editor.bossButton:SetBackdropColor(0.45, 0.02, 0.02, 0.85)
    end
    self:RefreshSimpleDropdown(editor.bossMenu, bossOptions, function(value)
        Addon.debugSelectedBossID = value
        Addon:RefreshDebugEditorWindow()
    end)
    self:SetDebugTimeBoxes("bossTime", self:GetDebugBossKillTime(run, self.debugSelectedBossID))
end

function Addon:ToggleDebugEditorWindow(run)
    if self.debugEditor and self.debugEditor:IsShown() then
        self.debugEditor:SetFrameLevel(420)
        if run and tostring(run.id or "") ~= tostring(self.debugSelectedRunID or "") then
            Print("The run editor is already open. Save or close it before editing another run.")
            return
        end
    end

    if run then
        self:SelectDebugRun(run)
    end
    self:CreateDebugEditorWindow()
    self:RefreshDebugEditorWindow()
    if not run and self.debugEditor:IsShown() then
        self.debugEditor:Hide()
    else
        self.debugEditor:SetFrameLevel(420)
        self.debugEditor:Show()
    end
end

function Addon:CreateDataToolsWindow()
    if self.dataTools then
        return
    end

    local editor = CreateFrame("Frame", "MPlusLedgerDataToolsFrame", UIParent, "BackdropTemplate")
    -- UI/MockupLayouts.lua's dataLayout() resizes this to 1040x784 for "run"/"create" mode every
    -- refresh -- this base size only matters for the brief window before that first refresh runs.
    editor:SetSize(980, 700)
    editor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    editor:SetFrameStrata("FULLSCREEN_DIALOG")
    editor:SetFrameLevel(390)
    editor:SetToplevel(true)
    editor:SetClampedToScreen(true)
    editor:SetMovable(true)
    editor:EnableMouse(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", editor.StartMoving)
    editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
    EnableEscHandler(editor, function()
        Addon:HandleDataToolsEscape()
    end)
    editor:SetScript("OnShow", function()
        if Addon.window then
            Addon.window:Hide()
        end
    end)
    editor:SetScript("OnHide", function()
        if Addon.window then
            Addon.window:Show()
        end
    end)
    editor:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    editor:SetBackdropColor(0, 0, 0, 1.00)

    -- Portrait icon, matching the main window/Stats hub treatment (found missing entirely here
    -- during the UI consistency pass, 2026-09-01).
    local portraitRing = editor:CreateTexture(nil, "OVERLAY", nil, 1)
    portraitRing:SetSize(50, 50)
    portraitRing:SetPoint("TOPLEFT", 9, -9)
    portraitRing:SetColorTexture(self:GetThemeBorderColor(true, 0.9))
    local portrait = editor:CreateTexture(nil, "OVERLAY", nil, 2)
    portrait:SetSize(44, 44)
    portrait:SetPoint("CENTER", portraitRing, "CENTER", 0, 0)
    editor.legacyPortrait = portrait
    editor.legacyPortraitRing = portraitRing
    portrait:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    portrait:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")

    local title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -22)
    title:SetText("Manage Runs")

    local close = self:CreatePlainButton(editor, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -18, -18)
    close:SetScript("OnClick", function()
        Addon:ReturnToMainMenu()
    end)

    -- Instance Data/Unassigned/Boss/Mob tabs removed 2026-09-05 per user request ("I also think the
    -- tabs, Instance Data, Unassigned, Boss and Mob can be removed from this manage data section
    -- now"). Nothing else in the addon ever sets dataToolMode to those values, so removing the nav
    -- buttons makes them fully unreachable rather than leaving a dangling entry point; the
    -- underlying mode-handling code for them is simply unused now rather than deleted outright.
    --
    -- Kept deliberately plain here -- UI/MockupLayouts.lua's dataLayout() repositions/resizes these
    -- two buttons (and everything else in "run"/"create" mode) every single refresh to match the
    -- approved mockup, so anything elaborate built here would just get overridden or, worse, left
    -- stranded at stale coordinates once MockupLayouts.lua resizes the button out from under it
    -- (exactly what happened to an earlier version of this that tried to add a subtitle line here
    -- directly -- see MockupLayouts.lua's own nav styling for where that now lives instead).
    editor.navButtons = {}
    local nav = {
        { "Create Run", "create", 130 },
        { "Edit Run", "run", 116 },
    }
    local navX = 34
    for index, entry in ipairs(nav) do
        local width = entry[3] or 116
        local button = self:CreatePlainButton(editor, entry[1], width, 24)
        button:SetPoint("TOPLEFT", navX, -58)
        button.mode = entry[2]
        button:SetScript("OnClick", function(self)
            Addon.dataToolMode = self.mode
            if self.mode ~= "run" and self.mode ~= "create" then
                Addon.dataToolSelectedDifficulty = nil
            end
            if editor.HideMenus then
                editor:HideMenus()
            end
            Addon:RefreshDataToolsWindow()
        end)
        editor.navButtons[entry[2]] = button
        navX = navX + width + 10
    end

    -- The "Player Reputation History" quick-access button that used to sit here was removed per
    -- user request 2026-10-02 ("The Player Reputation history button also can be removed from this
    -- menu, it should not be there") -- the Stats Hub's own "Player History" button (see
    -- BuildMythicPlusStatsTabContent) is still the way to reach that window.

    editor.content = CreateFrame("Frame", nil, editor, "BackdropTemplate")
    editor.content:SetPoint("TOPLEFT", 34, -96)
    editor.content:SetPoint("BOTTOMRIGHT", -34, 64)
    editor.content:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    editor.content:SetBackdropColor(0.02, 0.02, 0.02, 1.00)

    editor.footer = editor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    editor.footer:SetPoint("BOTTOMLEFT", 34, 34)
    editor.footer:SetWidth(780)
    editor.footer:SetJustifyH("LEFT")
    editor.footer:SetText("Pick a page above, then save the page you changed.")

    editor.saveAllButton = self:CreatePlainButton(editor, "Save", 90, 26)
    editor.saveAllButton:SetPoint("BOTTOMRIGHT", -34, 30)
    editor.saveAllButton:SetScript("OnClick", function()
        Addon:SaveDataToolsAll()
    end)

    editor.dynamicFrames = {}
    editor.menus = {}
    editor:Hide()
    self.dataTools = editor
end

function Addon:OpenDataToolsMenu(mode, run)
    run = run or self:GetCurrentRun()
    if run then
        self:CatalogCurrentInstance(run)
        self.dataToolSelectedRunID = run.id
        self.debugSelectedRunID = run.id
        self.dataToolSelectedInstanceName = run.instanceName
        self.dataToolSelectedExpansionName = run.expansionName or self:GetRunExpansionText(run)
        self.dataToolSelectedDifficulty = nil
        self.dataToolSelectedBossID = nil
        self.dataToolSelectedMobID = nil
        self.dataToolSelectedPlayerName = nil
        self.dataToolSelectedPlayerKey = nil
    end

    self.dataToolMode = (mode and mode ~= "hub") and mode or "create"
    self:CreateDataToolsWindow()
    self:RefreshDataToolsWindow()
    -- Was a bare SetFrameLevel(410) + Show() -- fixed 2026-09-30 per user report ("edit run...
    -- will appear behind instead of infront"): a fixed level number only wins against another
    -- window's OWN fixed level, but Stats Hub can get repeatedly :Raise()'d through its normal
    -- ToggleStatsHubWindow/BringWindowToFront path, which bumps its EFFECTIVE level each time --
    -- after enough toggles that can climb above this hardcoded 410 and start winning instead.
    -- BringWindowToFront is the addon's own already-correct helper for this exact problem: it
    -- explicitly hides every other major window (including Stats Hub) before showing and raising
    -- this one, so precedence no longer depends on two different windows' level numbers racing.
    self.dataTools:SetFrameLevel(410)
    self:BringWindowToFront(self.dataTools)
end

function Addon:ToggleDataToolsWindow()
    self:CreateDataToolsWindow()
    if self.dataTools:IsShown() then
        self.dataTools:Hide()
        if self.window then
            self.window:Show()
        end
    else
        local run = self:GetCurrentRun()
        if run then
            self:CatalogCurrentInstance(run)
            self.dataToolSelectedRunID = self.dataToolSelectedRunID or run.id
            self.debugSelectedRunID = self.debugSelectedRunID or run.id
            self.dataToolSelectedInstanceName = self.dataToolSelectedInstanceName or run.instanceName
            self.dataToolSelectedExpansionName = self.dataToolSelectedExpansionName or run.expansionName or self:GetRunExpansionText(run)
        end
        if not self.dataToolMode or self.dataToolMode == "hub" then self.dataToolMode = "create" end
        self:RefreshDataToolsWindow()
        self.dataTools:SetFrameLevel(410)
        self:BringWindowToFront(self.dataTools)
    end
end

-- ============================================================================================
-- Standalone "Player Reputation History" window, per user request 2026-09-30 ("make the Player
-- Menu section it's own menu, i would like to rename it to Player Reputation History"). Pulled out
-- of the shared Manage Data/Data Tools editor (still reachable from there via a button -- see the
-- "Player Reputation History" button in CreateDataToolsWindow) into its own frame, same reasoning
-- as the standalone Update/Add Player windows below: a genuinely separate concern gets its own
-- frame instead of another mode sharing one big shared editor.
--
-- Real page navigation (First/Prev/Next/Last, 20 rows/page) replaces the old per-notch mouse-wheel
-- scrolling, which was the actual cause of the reported freeze: every wheel notch called a full
-- RefreshDataToolsWindow(), which re-scans every player's ENTIRE run history (Pass 1 below,
-- O(players x runs x members)) from scratch -- a single fast scroll gesture fires dozens of wheel
-- deltas in a fraction of a second, each one triggering that full rescan synchronously. Paging
-- still calls the same full refresh, but only once per click, at human speed, which is the actual
-- fix -- not the rescan cost itself (that part is untouched, same Pass 1/2/3/4 as before).
-- ============================================================================================

function Addon:CreatePlayerHistoryWindow()
    if self.playerHistoryWindow then
        return
    end

    local frame = CreateFrame("Frame", "MPlusLedgerPlayerHistoryWindow", UIParent, "BackdropTemplate")
    frame:SetSize(1040, 760)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(390)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    EnableEscHandler(frame, function()
        Addon:CloseAllWindows()
    end)
    frame:SetScript("OnShow", function()
        if Addon.window then
            Addon.window:Hide()
        end
    end)
    frame:SetScript("OnHide", function()
        if Addon.ledgerSwitchingWindows then return end
        if Addon.window then
            Addon.window:Show()
        end
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0, 0, 0, 1.00)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -22)
    title:SetText("Player Reputation History")

    local close = self:CreatePlainButton(frame, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -18, -18)
    close:SetScript("OnClick", function()
        Addon:ReturnToMainMenu()
    end)

    frame.content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.content:SetPoint("TOPLEFT", 34, -56)
    frame.content:SetPoint("BOTTOMRIGHT", -34, 30)
    frame.content:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame.content:SetBackdropColor(0.02, 0.02, 0.02, 1.00)
    -- Belt-and-suspenders against row content ever visually spilling past this box's own border --
    -- per user report/screenshot 2026-09-30 ("make the players fit into the box as the play data
    -- is outside the border"). A plain Frame doesn't clip its children by default in WoW, so
    -- without this, any column position that ever ends up past the box's own declared width would
    -- render right over the window's outer border/backdrop instead of being cut off cleanly.
    if frame.content.SetClipsChildren then
        frame.content:SetClipsChildren(true)
    end

    -- Search box created ONCE here, not every refresh -- per user report 2026-09-30 ("the search
    -- box is not working"). RefreshPlayerHistoryWindow tears down and recreates every widget in
    -- frame.dynamicFrames on every call, including on every OnTextChanged firing from THIS box --
    -- destroying and replacing the very EditBox the player is actively typing into, from inside its
    -- own keystroke handler, silently ate every keystroke after the first. Kept out of
    -- dynamicFrames entirely so it survives every refresh untouched; only its stored search text
    -- (Addon.dataToolPlayerSearchText) drives what gets filtered.
    frame.searchBox = CreateFrame("EditBox", nil, frame.content, "InputBoxTemplate")
    frame.searchBox:SetSize(300, 24)
    frame.searchBox:SetPoint("TOPLEFT", 22, -24)
    frame.searchBox:SetAutoFocus(false)
    frame.searchBox:SetTextInsets(4, 4, 0, 0)
    frame.searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    -- Context search, per user request 2026-09-30 ("this should allow for context search as
    -- well") -- matches name, class, most recent instance, AND the saved reason/notes text, not
    -- just an exact player-name substring (see the passesSearch check in Pass 2 below).
    frame.searchBox:SetScript("OnTextChanged", function(self)
        Addon.dataToolPlayerSearchText = self:GetText() or ""
        Addon.dataToolPlayerHistoryOffset = 0
        Addon:RefreshPlayerHistoryWindow()
    end)
    local searchLabel = frame.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchLabel:SetPoint("BOTTOMLEFT", frame.searchBox, "TOPLEFT", 0, 2)
    searchLabel:SetText("Search (name, class, instance, reason)")

    frame.dynamicFrames = {}
    frame.menus = {}
    frame:Hide()
    self.playerHistoryWindow = frame
end

function Addon:OpenPlayerHistoryWindow()
    local switching = self.ledgerSwitchingWindows
    self.ledgerSwitchingWindows = true
    self:CreatePlayerHistoryWindow()
    self:RefreshPlayerHistoryWindow()
    self:BringWindowToFront(self.playerHistoryWindow)
    self.ledgerSwitchingWindows = switching
end

-- Extracted from what used to be Manage Data's "Player" mode (see RefreshDataToolsWindow's history
-- for the original Pass 1-4 comments this mirrors) -- logic is otherwise unchanged from that
-- version except: a search box (Pass 2 gets a name-substring filter), Clear All/Trusted/Avoid/
-- Neutral buttons, First/Prev/Next/Last paging instead of Newer/Older + mouse-wheel, and a wider
-- table to match this window's own larger size.
function Addon:RefreshPlayerHistoryWindow()
    local editor = self.playerHistoryWindow
    if not editor then
        return
    end

    for _, frame in ipairs(editor.dynamicFrames or {}) do
        frame:Hide()
    end
    editor.dynamicFrames = {}
    editor.ledgerHistoryRows = {}
    editor.ledgerNameCells = {}
    for _, menu in pairs(editor.menus or {}) do
        menu:Hide()
    end
    editor.menus = {}

    local function remember(frame)
        table.insert(editor.dynamicFrames, frame)
        return frame
    end
    local function text(line, x, y, template, width)
        local font = remember(editor.content:CreateFontString(nil, "OVERLAY", template or "GameFontDisableSmall"))
        font:SetPoint("TOPLEFT", x, y)
        if width then
            font:SetWidth(width)
            font:SetJustifyH("LEFT")
        end
        font:SetText(line)
        return font
    end
    local function label(line, x, y)
        return text(line, x, y, "GameFontDisableSmall")
    end
    local function button(key, line, x, y, width, onClick, backdrop)
        local btn = remember(Addon:CreatePlainButton(editor.content, line, width or 130, 24))
        btn:SetPoint("TOPLEFT", x, y)
        if backdrop then
            ApplyButtonColor(btn, backdrop)
        end
        if key then
            editor[key] = btn
        end
        if onClick then
            btn:SetScript("OnClick", onClick)
        end
        return btn
    end
    local function menu(key, anchor, width, options, onPick)
        local drop = remember(CreateFrame("Frame", nil, editor.content, "BackdropTemplate"))
        drop:SetSize(width or 220, 30)
        drop:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        drop:SetFrameLevel(editor:GetFrameLevel() + 30)
        drop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        drop:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
        drop:EnableMouse(true)
        -- Closes on cursor-leave -- per user report 2026-10-02 ("Can you check all dropdown boxes
        -- as well as this seems to be a persistent issue?"). This button+menu builder is
        -- duplicated almost verbatim across several windows in this file (Run Editor, Manage Runs,
        -- ...), each missing the same close-on-cursor-leave handling -- see CreateStatsHubDropdown's
        -- own comment for why a delayed IsMouseOver() recheck, not an immediate hide, is required.
        drop:SetScript("OnLeave", CloseDropdownOnLeave)
        editor[key] = drop
        editor.menus[key] = drop
        Addon:RefreshSimpleDropdown(drop, options, onPick)
        drop:Hide()
        return drop
    end
    function editor:HideMenus()
        for _, drop in pairs(self.menus or {}) do
            drop:Hide()
        end
    end
    local function dropdown(menuKey, buttonKey, line, x, y, width, options, onPick)
        local btn = button(buttonKey, line, x, y, width)
        local drop = menu(menuKey, btn, width, options, onPick)
        btn:SetScript("OnClick", function()
            if drop:IsShown() then
                drop:Hide()
            else
                editor:HideMenus()
                drop:Show()
            end
        end)
        return btn
    end

    local function FormatHistoryDate(isoDateText)
        local y, m, d = tostring(isoDateText or ""):match("^(%d+)-(%d+)-(%d+)")
        if y and m and d then
            return string.format("%s/%s/%s", d, m, y)
        end
        return ""
    end

    local FREQUENT_PLAYER_THRESHOLD = 3
    local myGuildName = GetGuildInfo and GetGuildInfo("player")
    self.dataToolPlayerFilterMode = self.dataToolPlayerFilterMode or "all"
    self.dataToolPlayerStatusFilter = self.dataToolPlayerStatusFilter or "all"
    self.dataToolPlayerClassFilter = self.dataToolPlayerClassFilter or "all"
    self.dataToolPlayerInstanceFilter = self.dataToolPlayerInstanceFilter or "all"
    self.dataToolPlayerSortMode = self.dataToolPlayerSortMode or "name"
    self.dataToolPlayerSearchText = self.dataToolPlayerSearchText or ""

    local myProfileKey = GetPlayerProfileKey(GetUnitFullName and GetUnitFullName("player") or (UnitName and UnitName("player")))
    local playersByKey = {}
    for key, profile in pairs(self.db.playerRatings or {}) do
        if key ~= myProfileKey then
            playersByKey[key] = profile
        end
    end

    -- Pass 1: gather every (non-raid) appearance per player once, plus enough metadata to both
    -- filter and sort without re-scanning run history a second time.
    --
    -- Rewritten 2026-09-30 (real root cause of the reported freeze/lag, per user report "wow that
    -- is lagging the game so much" + "as soon as i cleared the neutral players it is loading way
    -- faster" -- that second report is what pinned it down: fewer PLAYERS made it faster, which
    -- only makes sense if the cost scaled with player count). The previous version looped over
    -- EVERY tracked player and, for each one, rescanned the account's ENTIRE run history looking
    -- for their appearances -- O(players x runs x members). With 468 tracked players and ~2,900
    -- runs/raids ever recorded (self.db.runOrder has no cap, unlike the 500-run cap used for
    -- dungeon summaries elsewhere), that's on the order of several million GetPlayerProfileKey
    -- calls (each doing multiple string.gsub/strsplit/string.lower operations) on EVERY refresh --
    -- and this window refreshes on every search keystroke, dropdown change, and page click. This
    -- version does the reverse: ONE pass over run history (O(runs x members)), bucketing each
    -- member's appearance into their own player's list as it's encountered -- a ~500x fewer
    -- GetPlayerProfileKey calls for this account's actual data.
    local playerData = {}
    local seenClasses, seenInstances = {}, {}
    local appearancesByKey, inMyGuildByKey, mostRecentByKey = {}, {}, {}
    for _, runID in ipairs(self.db.runOrder or {}) do
        local candidateRun = self.db.runs and self.db.runs[runID]
        if candidateRun then
            local instanceName = candidateRun.instanceName or "Unknown instance"
            local dateText = nil
            -- Guards against double-counting if a run's roster ever has the same player listed
            -- twice (a data anomaly) -- matches the original per-player `break`-on-first-match
            -- behavior exactly, just applied per-run instead of per-player-per-run.
            local seenInThisRun = {}
            for _, candidateMember in ipairs(candidateRun.members or {}) do
                local key = candidateMember.name and GetPlayerProfileKey(candidateMember.name)
                if key and playersByKey[key] and not seenInThisRun[key] then
                    seenInThisRun[key] = true
                    dateText = dateText or FormatHistoryDate(candidateRun.startedAtText)
                    local list = appearancesByKey[key]
                    if not list then
                        list = {}
                        appearancesByKey[key] = list
                    end
                    table.insert(list, {
                        instanceName = instanceName,
                        role = candidateMember.role,
                        class = candidateMember.class,
                        dateText = dateText,
                        runID = runID,
                    })
                    if candidateMember.class then
                        seenClasses[candidateMember.class] = true
                    end
                    seenInstances[instanceName] = true
                    if candidateRun.startedAt and (not mostRecentByKey[key] or candidateRun.startedAt > mostRecentByKey[key]) then
                        mostRecentByKey[key] = candidateRun.startedAt
                    end
                    if myGuildName and candidateMember.guild and candidateMember.guild == myGuildName then
                        inMyGuildByKey[key] = true
                    end
                end
            end
        end
    end
    for key, profile in pairs(playersByKey) do
        local appearances = appearancesByKey[key] or {}
        local appearanceCount = #appearances
        local isGuild = (profile.isGuildMember ~= nil) and profile.isGuildMember or (inMyGuildByKey[key] or false)
        local isFrequent = (profile.isFrequent ~= nil) and profile.isFrequent or (appearanceCount >= FREQUENT_PLAYER_THRESHOLD)
        table.insert(playerData, {
            key = key,
            profile = profile,
            appearances = appearances,
            appearanceCount = appearanceCount,
            isGuild = isGuild,
            isFrequent = isFrequent,
            mostRecentStartedAt = mostRecentByKey[key] or 0,
            class = (appearances[1] and appearances[1].class) or profile.class,
            role = (appearances[1] and appearances[1].role) or profile.role,
        })
    end

    -- Pass 2: player-level filters (relationship, status, name search), then row-level filters
    -- (class, instance) narrow which of that player's appearances actually get shown.
    local searchQuery = strtrim(self.dataToolPlayerSearchText or ""):lower()
    local filteredPlayers = {}
    for _, p in ipairs(playerData) do
        local passesRelationship = true
        if self.dataToolPlayerFilterMode == "guild" then
            passesRelationship = p.isGuild
        elseif self.dataToolPlayerFilterMode == "frequent" then
            passesRelationship = p.isFrequent
        elseif self.dataToolPlayerFilterMode == "hideGuild" then
            passesRelationship = not p.isGuild
        elseif self.dataToolPlayerFilterMode == "hideKnown" then
            passesRelationship = not p.isGuild and not p.isFrequent
        end
        local passesStatus = (self.dataToolPlayerStatusFilter == "all") or ((p.profile.rating or "Okay") == self.dataToolPlayerStatusFilter)
        -- Context search, not just name -- per user request 2026-09-30 ("this should allow for
        -- context search as well"): also matches class and the saved reason/notes text outright,
        -- and any instance this player has ever been grouped with you in (checked last since it's
        -- the only one requiring a loop over their appearances).
        local passesSearch = searchQuery == ""
        if not passesSearch then
            if tostring(p.profile.name or p.key):lower():find(searchQuery, 1, true) then
                passesSearch = true
            elseif p.class and tostring(p.class):lower():find(searchQuery, 1, true) then
                passesSearch = true
            elseif p.profile.notes and tostring(p.profile.notes):lower():find(searchQuery, 1, true) then
                passesSearch = true
            else
                for _, appearance in ipairs(p.appearances) do
                    if appearance.instanceName and tostring(appearance.instanceName):lower():find(searchQuery, 1, true) then
                        passesSearch = true
                        break
                    end
                end
            end
        end
        if passesRelationship and passesStatus and passesSearch then
            local matchingAppearances = p.appearances
            if self.dataToolPlayerClassFilter ~= "all" or self.dataToolPlayerInstanceFilter ~= "all" then
                matchingAppearances = {}
                for _, appearance in ipairs(p.appearances) do
                    local classOk = (self.dataToolPlayerClassFilter == "all") or (appearance.class == self.dataToolPlayerClassFilter)
                    local instanceOk = (self.dataToolPlayerInstanceFilter == "all") or (appearance.instanceName == self.dataToolPlayerInstanceFilter)
                    if classOk and instanceOk then
                        table.insert(matchingAppearances, appearance)
                    end
                end
            end
            if #matchingAppearances > 0 or p.appearanceCount == 0 then
                table.insert(filteredPlayers, {
                    key = p.key, profile = p.profile, appearances = matchingAppearances,
                    appearanceCount = p.appearanceCount, class = p.class, role = p.role,
                })
            end
        end
    end

    -- Pass 3: sort.
    local RATING_SORT_ORDER = { Bad = 1, Okay = 2, Good = 3 }
    local ROLE_SORT_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
    table.sort(filteredPlayers, function(a, b)
        local aName = string.lower(tostring(a.profile.name or a.key))
        local bName = string.lower(tostring(b.profile.name or b.key))
        if self.dataToolPlayerSortMode == "status" then
            local ao, bo = RATING_SORT_ORDER[a.profile.rating or "Okay"] or 2, RATING_SORT_ORDER[b.profile.rating or "Okay"] or 2
            if ao ~= bo then return ao < bo end
        elseif self.dataToolPlayerSortMode == "class" then
            local ac, bc = tostring(a.class or "zzzz"), tostring(b.class or "zzzz")
            if ac ~= bc then return ac < bc end
        elseif self.dataToolPlayerSortMode == "role" then
            local ao, bo = ROLE_SORT_ORDER[a.role or "NONE"] or 4, ROLE_SORT_ORDER[b.role or "NONE"] or 4
            if ao ~= bo then return ao < bo end
        elseif self.dataToolPlayerSortMode == "runs" then
            local ac, bc = a.appearanceCount or 0, b.appearanceCount or 0
            if ac ~= bc then return ac > bc end
        end
        return aName < bName
    end)

    -- Pass 4: flatten into display rows -- one row per player, appearances[1] is their most recent
    -- (runOrder is newest-first).
    local historyRows = {}
    for _, p in ipairs(filteredPlayers) do
        local latest = p.appearances[1] or { instanceName = "No recorded runs", role = nil, class = nil, dateText = "" }
        table.insert(historyRows, {
            key = p.key,
            displayName = p.profile.name or p.key,
            role = latest.role and GetRoleLabel(latest.role) or "-",
            class = latest.class,
            instanceName = latest.instanceName,
            groupCount = p.appearanceCount,
            status = p.profile.rating or "Okay",
            reason = (p.profile.notes and p.profile.notes ~= "") and p.profile.notes or "No reason given",
            dateText = latest.dateText,
            runID = latest.runID,
        })
    end

    -- Row A: Show/Status/Sort filters -- the search box itself lives at editor.searchBox, created
    -- once in CreatePlayerHistoryWindow (see that function's comment for why it's NOT rebuilt here
    -- every refresh like everything else on this page).
    local filterOptions = {
        { text = "All Players", value = "all" },
        { text = "Guild Members", value = "guild" },
        { text = string.format("Frequent (%d+ runs)", FREQUENT_PLAYER_THRESHOLD), value = "frequent" },
        { text = "Hide Guild Members", value = "hideGuild" },
        { text = "Hide Guild/Frequent", value = "hideKnown" },
    }
    local statusOptions = {
        { text = "All Statuses", value = "all" },
        { text = GetRatingMeta("Good").color .. GetRatingMeta("Good").label .. "|r", value = "Good" },
        { text = GetRatingMeta("Okay").color .. GetRatingMeta("Okay").label .. "|r", value = "Okay" },
        { text = GetRatingMeta("Bad").color .. GetRatingMeta("Bad").label .. "|r", value = "Bad" },
    }
    local classOptions = { { text = "All Classes", value = "all" } }
    do
        local classNames = {}
        for className in pairs(seenClasses) do
            table.insert(classNames, className)
        end
        table.sort(classNames)
        for _, className in ipairs(classNames) do
            table.insert(classOptions, { text = (CLASS_COLORS[className] or "|cffffffff") .. ClassDisplayName(className) .. "|r", value = className })
        end
    end
    local instanceOptions = { { text = "All Instances", value = "all" } }
    do
        local instanceNames = {}
        for instanceName in pairs(seenInstances) do
            table.insert(instanceNames, instanceName)
        end
        table.sort(instanceNames)
        for _, instanceName in ipairs(instanceNames) do
            table.insert(instanceOptions, { text = instanceName, value = instanceName })
        end
    end
    local sortOptions = {
        { text = "Name", value = "name" },
        { text = "Status", value = "status" },
        { text = "Class", value = "class" },
        { text = "Role", value = "role" },
        { text = "Most Runs", value = "runs" },
    }
    local function pickedLabel(options, selectedValue, prefix)
        for _, option in ipairs(options) do
            if option.value == selectedValue then
                return prefix .. option.text
            end
        end
        return prefix .. "?"
    end
    dropdown("playerFilterMenu", "playerFilterButton", pickedLabel(filterOptions, self.dataToolPlayerFilterMode, "Show: "), 340, -24, 150, filterOptions, function(value)
        Addon.dataToolPlayerFilterMode = value
        Addon.dataToolPlayerHistoryOffset = 0
        Addon:RefreshPlayerHistoryWindow()
    end)
    dropdown("playerStatusFilterMenu", "playerStatusFilterButton", pickedLabel(statusOptions, self.dataToolPlayerStatusFilter, "Status: "), 496, -24, 120, statusOptions, function(value)
        Addon.dataToolPlayerStatusFilter = value
        Addon.dataToolPlayerHistoryOffset = 0
        Addon:RefreshPlayerHistoryWindow()
    end)
    dropdown("playerSortMenu", "playerSortButton", pickedLabel(sortOptions, self.dataToolPlayerSortMode, "Sort: "), 622, -24, 170, sortOptions, function(value)
        Addon.dataToolPlayerSortMode = value
        Addon.dataToolPlayerHistoryOffset = 0
        Addon:RefreshPlayerHistoryWindow()
    end)
    -- Row B: Class/Instance filters -- kept off Row A (which is already Search+Show+Status+Sort)
    -- so nothing crowds the content box's own right edge.
    dropdown("playerClassFilterMenu", "playerClassFilterButton", pickedLabel(classOptions, self.dataToolPlayerClassFilter, "Class: "), 22, -58, 170, classOptions, function(value)
        Addon.dataToolPlayerClassFilter = value
        Addon.dataToolPlayerHistoryOffset = 0
        Addon:RefreshPlayerHistoryWindow()
    end)
    dropdown("playerInstanceFilterMenu", "playerInstanceFilterButton", pickedLabel(instanceOptions, self.dataToolPlayerInstanceFilter, "Instance: "), 210, -58, 280, instanceOptions, function(value)
        Addon.dataToolPlayerInstanceFilter = value
        Addon.dataToolPlayerHistoryOffset = 0
        Addon:RefreshPlayerHistoryWindow()
    end)

    -- Row C: bulk clear buttons -- per user request 2026-09-30 ("Clear All Player Data History as
    -- well as Clear Trusted, Clear Avoid, Clear Neutral"). All genuinely irreversible, so all go
    -- through the same confirm popup (see ConfirmClearPlayerData) rather than deleting on click.
    button(nil, (self.showReputationDataActions and "Hide data actions" or "Manage player data"), 720, -92, 180, function()
        Addon.showReputationDataActions = not Addon.showReputationDataActions
        Addon:RefreshPlayerHistoryWindow()
    end)
    if self.showReputationDataActions then
    button(nil, "Clear All Player Data", 22, -92, 180, function()
        Addon:ConfirmClearPlayerData("Clear ALL saved player reputation data? This cannot be undone.", function()
            Addon:ClearAllPlayerData()
            Addon:RefreshPlayerHistoryWindow()
        end)
    end, STATUS_BACKDROP_COLORS.Abandoned)
    button(nil, "Clear Trusted", 210, -92, 120, function()
        Addon:ConfirmClearPlayerData("Clear all players marked Trusted? This cannot be undone.", function()
            Addon:ClearPlayerDataByRating("Good")
            Addon:RefreshPlayerHistoryWindow()
        end)
    end, STATUS_BACKDROP_COLORS.Abandoned)
    button(nil, "Clear Avoid", 338, -92, 120, function()
        Addon:ConfirmClearPlayerData("Clear all players marked Avoid? This cannot be undone.", function()
            Addon:ClearPlayerDataByRating("Bad")
            Addon:RefreshPlayerHistoryWindow()
        end)
    end, STATUS_BACKDROP_COLORS.Abandoned)
    button(nil, "Clear Neutral", 466, -92, 120, function()
        Addon:ConfirmClearPlayerData("Clear all players marked Neutral? This cannot be undone.", function()
            Addon:ClearPlayerDataByRating("Okay")
            Addon:RefreshPlayerHistoryWindow()
        end)
    end, STATUS_BACKDROP_COLORS.Abandoned)

    end

    local headerY = -126
    label("Player", 22, headerY)
    label("Role", 156, headerY)
    label("Class", 224, headerY)
    label("Instance", 318, headerY)
    label("Status", 466, headerY)
    label("Reason", 530, headerY)
    label("Runs", 690, headerY)
    label("Date", 750, headerY)

    local PLAYER_HISTORY_VISIBLE_ROWS = 16
    local PLAYER_HISTORY_ROW_HEIGHT = 28
    local tableTop = -146
    local maxOffset = math.max(0, (math.ceil(#historyRows / PLAYER_HISTORY_VISIBLE_ROWS) - 1) * PLAYER_HISTORY_VISIBLE_ROWS)
    self.dataToolPlayerHistoryOffset = math.max(0, math.min(maxOffset, math.floor((self.dataToolPlayerHistoryOffset or 0) / PLAYER_HISTORY_VISIBLE_ROWS) * PLAYER_HISTORY_VISIBLE_ROWS))
    local offset = self.dataToolPlayerHistoryOffset

    if #historyRows == 0 then
        local emptyText = #playerData == 0
            and "No players rated yet. Use Add Player to save your first player."
            or "No players match the current filters -- try Search/Show/Status/Class/Instance above."
        text(emptyText, 22, tableTop, "GameFontHighlight", 860)
    end

    local function selectPlayer(key, name)
        Addon.dataToolSelectedPlayerKey = key
        Addon.dataToolSelectedPlayerName = name
        Addon.dataToolSelectedPlayerClass = nil
        Addon.dataToolSelectedPlayerRole = nil
        Addon.dataToolSelectedPlayerRace = nil
        Addon.dataToolSelectedPlayerFaction = nil
        Addon.dataToolSelectedPlayerRealm = nil
        Addon.dataToolSelectedPlayerNotes = nil
        Addon.dataToolSelectedPlayerRating = nil
        Addon.dataToolSelectedPlayerIsGuild = nil
        Addon.dataToolSelectedPlayerIsFrequent = nil
        Addon:RefreshPlayerHistoryWindow()
    end

    local pageRows = {}
    for i = 1, PLAYER_HISTORY_VISIBLE_ROWS do
        pageRows[i] = historyRows[offset + i]
    end

    for i, row in ipairs(pageRows) do
        local rowY = tableTop - ((i - 1) * PLAYER_HISTORY_ROW_HEIGHT)
        local rowBg = remember(CreateFrame("Frame", nil, editor.content, "BackdropTemplate"))
        rowBg:SetSize(936, PLAYER_HISTORY_ROW_HEIGHT - 1)
        rowBg:SetPoint("TOPLEFT", 18, rowY + 3)
        rowBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        rowBg.ledgerIndex = i
        table.insert(editor.ledgerHistoryRows, rowBg)
        local isSelected = row and self.dataToolSelectedPlayerKey == row.key
        rowBg.ledgerSelected = isSelected
        if isSelected then
            rowBg:SetBackdropColor(0.10, 0.22, 0.38, 0.95)
        elseif i % 2 == 0 then
            rowBg:SetBackdropColor(0.10, 0.10, 0.10, 0.9)
        else
            rowBg:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
        end
        if row then
            rowBg:EnableMouse(true)
            rowBg:SetScript("OnMouseUp", function() selectPlayer(row.key, row.displayName) end)
            rowBg:SetScript("OnEnter", function()
                GameTooltip:SetOwner(rowBg, "ANCHOR_TOPRIGHT")
                GameTooltip:SetText(row.displayName)
                GameTooltip:AddLine(row.instanceName or "No recorded runs", 1, 1, 1, true)
                GameTooltip:AddLine(row.reason or "No reason given", .85, .85, .85, true)
                GameTooltip:Show()
            end)
            rowBg:SetScript("OnLeave", function() GameTooltip:Hide() end)
            local roleText = remember(rowBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
            roleText:SetPoint("LEFT", 156 - 18, 0)
            roleText:SetWidth(64)
            roleText:SetJustifyH("LEFT")
            roleText:SetTextColor(0.95, 0.95, 0.95)
            roleText:SetText(row.role)

            local classText = remember(rowBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
            classText:SetPoint("LEFT", 224 - 18, 0)
            classText:SetWidth(90)
            classText:SetJustifyH("LEFT")
            if row.class and CLASS_COLORS[row.class] then
                classText:SetText(CLASS_COLORS[row.class] .. ClassDisplayName(row.class) .. "|r")
            else
                classText:SetTextColor(0.6, 0.6, 0.6)
                classText:SetText("-")
            end

            local instanceText = remember(rowBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
            instanceText:SetPoint("LEFT", 318 - 18, 0)
            instanceText:SetWidth(140)
            instanceText:SetJustifyH("LEFT")
            instanceText:SetTextColor(0.95, 0.95, 0.95)
            instanceText:SetText(row.instanceName)

            local statusText = remember(rowBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
            statusText:SetPoint("LEFT", 466 - 18, 0)
            statusText:SetWidth(56)
            statusText:SetJustifyH("LEFT")
            statusText:SetText(GetRatingMeta(row.status).color .. GetRatingMeta(row.status).label .. "|r")

            local reasonText = remember(rowBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
            reasonText:SetPoint("LEFT", 530 - 18, 0)
            reasonText:SetWidth(150)
            reasonText:SetJustifyH("LEFT")
            reasonText:SetTextColor(0.85, 0.85, 0.85)
            reasonText:SetText(row.reason)

            local groupedText = remember(rowBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
            groupedText:SetPoint("LEFT", 690 - 18, 0)
            groupedText:SetWidth(50)
            groupedText:SetJustifyH("LEFT")
            groupedText:SetTextColor(0.95, 0.95, 0.95)
            groupedText:SetText(tostring(row.groupCount or 0))

            local dateText = remember(rowBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
            dateText:SetPoint("LEFT", 750 - 18, 0)
            dateText:SetWidth(70)
            dateText:SetJustifyH("LEFT")
            dateText:SetTextColor(0.95, 0.95, 0.95)
            dateText:SetText(row.dateText)

            if isSelected and row.runID then
                -- Widened 56 -> 80: MenuPolish.lua's shared button() decorator clamps every
                -- skinned button's label to (button width - 12) with word-wrap off, so "Remove" at
                -- the old 56px width was always going to truncate -- per user report 2026-10-01
                -- ("the Remove Button text is hidden").
                local removeBtn = remember(Addon:CreatePlainButton(rowBg, "Remove", 80, PLAYER_HISTORY_ROW_HEIGHT - 4))
                removeBtn:SetPoint("LEFT", 826 - 18, 0)
                removeBtn:SetScript("OnClick", function()
                    Addon:RemoveDataToolPlayerRunAppearance(row.key, row.runID)
                    Addon:RefreshPlayerHistoryWindow()
                end)
                ApplyButtonColor(removeBtn, STATUS_BACKDROP_COLORS.Abandoned)
            end
        end
    end

    -- True merged-cell look for the Player column: one background block + one vertically-centered
    -- name label spanning every contiguous row that belongs to the same player on this page.
    local idx = 1
    while idx <= PLAYER_HISTORY_VISIBLE_ROWS do
        local row = pageRows[idx]
        if not row then
            idx = idx + 1
        else
            local groupStart = idx
            local groupEnd = idx
            while pageRows[groupEnd + 1] and pageRows[groupEnd + 1].key == row.key do
                groupEnd = groupEnd + 1
            end
            local groupTopY = tableTop - ((groupStart - 1) * PLAYER_HISTORY_ROW_HEIGHT)
            local groupHeight = (groupEnd - groupStart + 1) * PLAYER_HISTORY_ROW_HEIGHT - 1
            local mergedCell = remember(CreateFrame("Frame", nil, editor.content, "BackdropTemplate"))
            mergedCell:SetSize(132, groupHeight)
            mergedCell:SetPoint("TOPLEFT", 18, groupTopY + 3)
            mergedCell:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            mergedCell.ledgerSelected = self.dataToolSelectedPlayerKey == row.key
            table.insert(editor.ledgerNameCells, mergedCell)
            local isSelectedGroup = self.dataToolSelectedPlayerKey == row.key
            local ratingMeta = GetRatingMeta(row.status)
            if isSelectedGroup then
                mergedCell:SetBackdropColor(0.12, 0.26, 0.44, 0.97)
                mergedCell:SetBackdropBorderColor(0.4, 0.75, 1, 0.9)
            else
                local bg = ratingMeta.bg
                mergedCell:SetBackdropColor(bg[1], bg[2], bg[3], 0.97)
                local border = ratingMeta.border
                mergedCell:SetBackdropBorderColor(border[1], border[2], border[3], 0.8)
            end
            mergedCell:EnableMouse(true)
            mergedCell:SetScript("OnMouseUp", function() selectPlayer(row.key, row.displayName) end)
            local statusIcon = remember(mergedCell:CreateTexture(nil, "OVERLAY"))
            statusIcon:SetSize(14, 14)
            statusIcon:SetPoint("LEFT", 6, 0)
            statusIcon:SetTexture(ratingMeta.icon)
            local nameText = remember(mergedCell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
            nameText:SetPoint("LEFT", statusIcon, "RIGHT", 4, 0)
            nameText:SetPoint("RIGHT", -4, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetTextColor(1, 1, 1)
            nameText:SetText((CLASS_COLORS[row.class] or "|cfff0ece2") .. row.displayName .. "|r")
            idx = groupEnd + 1
        end
    end

    -- Page navigation -- First/Prev/Next/Last, per user request 2026-09-30 ("scrolling causes the
    -- game to freeze while it loads, could we look to add pages instead of the scroll... could you
    -- have it show the arrows for next and previous and last"). Deliberately NO mouse-wheel handler
    -- here (see this function's header comment) -- that per-notch full-refresh was the freeze.
    local totalPages = math.max(1, math.ceil(#historyRows / PLAYER_HISTORY_VISIBLE_ROWS))
    local currentPage = math.floor(offset / PLAYER_HISTORY_VISIBLE_ROWS) + 1
    local pagerY = tableTop - (PLAYER_HISTORY_VISIBLE_ROWS * PLAYER_HISTORY_ROW_HEIGHT) - 10
    local firstBtn = button(nil, "|< First", 22, pagerY, 80, function()
        Addon.dataToolPlayerHistoryOffset = 0
        Addon:RefreshPlayerHistoryWindow()
    end)
    local prevBtn = button(nil, "< Prev", 106, pagerY, 80, function()
        Addon.dataToolPlayerHistoryOffset = math.max(0, (Addon.dataToolPlayerHistoryOffset or 0) - PLAYER_HISTORY_VISIBLE_ROWS)
        Addon:RefreshPlayerHistoryWindow()
    end)
    local nextBtn = button(nil, "Next >", 190, pagerY, 80, function()
        Addon.dataToolPlayerHistoryOffset = math.min(maxOffset, (Addon.dataToolPlayerHistoryOffset or 0) + PLAYER_HISTORY_VISIBLE_ROWS)
        Addon:RefreshPlayerHistoryWindow()
    end)
    local lastBtn = button(nil, "Last >|", 274, pagerY, 80, function()
        Addon.dataToolPlayerHistoryOffset = maxOffset
        Addon:RefreshPlayerHistoryWindow()
    end)
    if offset <= 0 then
        firstBtn:Disable()
        prevBtn:Disable()
    end
    if offset >= maxOffset then
        nextBtn:Disable()
        lastBtn:Disable()
    end
    text(string.format("Page %d of %d  \194\183  %d entr%s", currentPage, totalPages, #historyRows, #historyRows == 1 and "y" or "ies"), 364, pagerY + 4, "GameFontDisableSmall", 260)

    local updatePlayerButton = button(nil, "Update Player", 634, pagerY, 140, function()
        if not Addon.dataToolSelectedPlayerKey and filteredPlayers[1] then
            Addon.dataToolSelectedPlayerKey = filteredPlayers[1].key
            Addon.dataToolSelectedPlayerName = filteredPlayers[1].profile.name or filteredPlayers[1].key
        end
        Addon:OpenUpdatePlayerForm()
    end)
    if #filteredPlayers == 0 then
        updatePlayerButton:Disable()
    end
end

-- ============================================================================================
-- Standalone "Add Player Reputation" window, per user follow-up request ("can this add player
-- button open a separate menu to the player data menu"). A genuinely separate frame from Manage
-- Data/Data Tools -- not another mode sharing that window -- built once and refreshed in place
-- (unlike Data Tools, which rebuilds its whole content every refresh) so its EditBoxes are never
-- torn down and recreated, which is exactly the mechanism behind the "dropdown clears the text
-- fields" bug fixed in the Data Tools Player tab. Saving still goes through the shared
-- SaveDataToolPlayer (sourceEditor = this window) so there's one save/duplicate-key/persistence
-- code path, not two.
-- ============================================================================================
function Addon:CreateAddPlayerWindow()
    if self.addPlayerWindow then
        return
    end

    local frame = CreateFrame("Frame", "MPlusLedgerAddPlayerWindow", UIParent, "BackdropTemplate")
    frame:SetSize(560, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    frame:SetBackdropColor(Addon:GetTableBackgroundColor(0.97))
    frame:SetBackdropBorderColor(self:GetThemeBorderColor(true, 1))
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- Never had ESC handling at all before 2026-10-01 -- see Addon:CloseAllWindows for why that
    -- mattered (ESC did nothing here, not even close this one window).
    EnableEscHandler(frame, function()
        Addon:CloseAllWindows()
    end)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Add Player Reputation")

    local close = self:CreatePlainButton(frame, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetScript("OnClick", function()
        Addon:ReturnToMainMenu()
    end)

    frame.menus = {}
    -- Click-outside-to-close catcher, per user request 2026-10-01 ("these should close when the
    -- cursor leaves the box or selection field... stay open until you select one or click the
    -- button again"). Covers the whole window, one level below every menu (each menu sets its own
    -- level above this when it opens) -- a click anywhere that isn't the open menu itself reaches
    -- this instead and closes everything. Kept local to this window rather than reusing the Stats
    -- Hub dropdown's shared full-screen catcher: that one runs at FULLSCREEN_DIALOG strata, a tier
    -- above this window's own DIALOG strata, so showing it here would bury this window's menus
    -- under it instead of just catching outside clicks.
    local clickCatcher = CreateFrame("Button", nil, frame)
    clickCatcher:SetAllPoints(frame)
    clickCatcher:EnableMouse(true)
    clickCatcher:Hide()
    local function hideMenus()
        for _, m in ipairs(frame.menus) do
            m:Hide()
        end
        clickCatcher:Hide()
    end
    clickCatcher:SetScript("OnClick", hideMenus)
    -- Cursor-leave auto-close, delayed and re-checked against IsMouseOver so hovering a child
    -- option button (which re-fires OnLeave on the parent-to-child mouse-focus transition) doesn't
    -- close the menu before you can click it -- same fix already applied to Stats Hub's dropdowns.
    local function closeOnLeave(menu, anchor)
        menu:SetScript("OnLeave", function()
            C_Timer.After(0.15, function()
                if menu:IsShown() and not menu:IsMouseOver() and not (anchor and anchor:IsMouseOver()) then
                    menu:Hide()
                    local anyShown = false
                    for _, m in ipairs(frame.menus) do
                        if m:IsShown() then anyShown = true; break end
                    end
                    if not anyShown then clickCatcher:Hide() end
                end
            end)
        end)
    end
    local function label(text, x, y)
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetText(text)
        return fs
    end
    local function editBox(key, x, y, width)
        local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        box:SetSize(width, 24)
        box:SetPoint("TOPLEFT", x, y)
        box:SetAutoFocus(false)
        box:SetTextInsets(4, 4, 0, 0)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        frame[key] = box
        return box
    end
    local function dropdown(key, x, y, width, getOptions, onPick)
        local btn = self:CreatePlainButton(frame, "", width, 24)
        btn:SetPoint("TOPLEFT", x, y)
        local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        menu:SetSize(width, 30)
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        menu:SetFrameLevel(frame:GetFrameLevel() + 30)
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        menu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
        menu:EnableMouse(true)
        menu:Hide()
        table.insert(frame.menus, menu)
        closeOnLeave(menu, btn)
        btn:SetScript("OnClick", function()
            if menu:IsShown() then
                menu:Hide()
                clickCatcher:Hide()
            else
                hideMenus()
                Addon:RefreshSimpleDropdown(menu, getOptions(), onPick)
                menu:Show()
                clickCatcher:SetFrameLevel(math.max(1, menu:GetFrameLevel() - 1))
                clickCatcher:Show()
            end
        end)
        frame[key .. "Button"] = btn
        frame[key .. "Menu"] = menu
        return btn
    end
    -- Realm: type-ahead, not a pure pick-only dropdown -- per user request 2026-10-01 ("make this
    -- a dropdown box and have all the realms listed"). No addon can enumerate every realm in the
    -- game (that's server-side data), so GetKnownRealmNames offers the player's own realm plus
    -- every realm this addon has actually seen -- clicking in shows that full list immediately,
    -- typing filters it live, and picking one still just fills the text box, so a realm that
    -- genuinely isn't in the list yet can still be typed by hand.
    local function realmField(key, x, y, width)
        local box = editBox(key, x, y, width)
        local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        menu:SetSize(width, 30)
        menu:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
        menu:SetFrameLevel(frame:GetFrameLevel() + 30)
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        menu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
        menu:EnableMouse(true)
        menu:Hide()
        table.insert(frame.menus, menu)
        closeOnLeave(menu, box)
        local function showSuggestions()
            -- Only while the box actually has focus -- RefreshAddPlayerWindow/
            -- RefreshUpdatePlayerWindow call box:SetText(...) on every refresh (e.g. after any
            -- other dropdown pick) to keep the displayed value in sync, which also fires
            -- OnTextChanged; without this check the suggestion menu would pop open uninvited every
            -- single time, not just while the user is actually typing or has clicked in.
            if not box:HasFocus() then
                return
            end
            local query = strtrim(box:GetText() or ""):lower()
            local filtered = {}
            for _, name in ipairs(Addon:GetKnownRealmNames()) do
                if query == "" or tostring(name):lower():find(query, 1, true) then
                    table.insert(filtered, { text = name, value = name })
                    if #filtered >= 12 then break end
                end
            end
            if #filtered > 0 then
                hideMenus()
                Addon:RefreshSimpleDropdown(menu, filtered, function(value)
                    box:SetText(value)
                    menu:Hide()
                    clickCatcher:Hide()
                end)
                menu:Show()
                clickCatcher:SetFrameLevel(math.max(1, menu:GetFrameLevel() - 1))
                clickCatcher:Show()
            else
                menu:Hide()
            end
        end
        box:SetScript("OnEditFocusGained", showSuggestions)
        box:HookScript("OnTextChanged", showSuggestions)
        frame[key .. "Menu"] = menu
        return box
    end

    -- Each box syncs into its state variable on every keystroke -- this window updates the whole
    -- form's display (RefreshAddPlayerWindow) after every dropdown pick, and without this sync a
    -- typed-but-uncommitted name/realm/notes would get overwritten right back to blank the moment
    -- any dropdown was touched (the exact bug just fixed in the Data Tools Player tab).
    editBox("playerNameBox", 22, -56, 240)
    frame.playerNameBox:SetScript("OnTextChanged", function(self)
        Addon.addPlayerFormName = self:GetText()
    end)
    label("Player name", 22, -40)
    realmField("playerRealmBox", 296, -56, 240)
    frame.playerRealmBox:HookScript("OnTextChanged", function(self)
        Addon.addPlayerFormRealm = self:GetText()
    end)
    label("Realm", 296, -40)

    dropdown("playerClass", 22, -104, 200, function()
        local options = { { text = "Unknown Class", value = "" } }
        for className in pairs(CLASS_COLORS) do
            table.insert(options, { text = CLASS_COLORS[className] .. ClassDisplayName(className) .. "|r", value = className, backdrop = CLASS_BACKDROP_COLORS[className] })
        end
        table.sort(options, function(a, b) return tostring(a.value) < tostring(b.value) end)
        return options
    end, function(value)
        Addon.addPlayerFormClass = value
        Addon:RefreshAddPlayerWindow()
    end)
    label("Class", 22, -88)

    dropdown("playerRole", 236, -104, 150, function()
        return {
            { text = "Tank", value = "TANK" },
            { text = "Heals", value = "HEALER" },
            { text = "DPS", value = "DAMAGER" },
            { text = "None", value = "NONE" },
        }
    end, function(value)
        Addon.addPlayerFormRole = value
        Addon:RefreshAddPlayerWindow()
    end)
    label("Role", 236, -88)

    dropdown("playerRace", 22, -152, 200, function()
        local options = { { text = "Unknown Race", value = "" } }
        for _, raceName in ipairs(RACE_OPTIONS) do
            table.insert(options, { text = raceName, value = raceName })
        end
        return options
    end, function(value)
        Addon.addPlayerFormRace = value
        -- Auto-pick the Faction this race actually belongs to -- per user request 2026-10-01
        -- ("if the race... Human is selected, can the Faction auto select Alliance"). Only when
        -- RACE_FACTION actually has an answer -- Pandaren/Dracthyr/Earthen are both-faction races,
        -- so the user's own existing Faction pick is left alone for those.
        local faction = RACE_FACTION[value]
        if faction then
            Addon.addPlayerFormFaction = faction
        end
        Addon:RefreshAddPlayerWindow()
    end)
    label("Race", 22, -136)

    dropdown("playerFaction", 236, -152, 150, function()
        return {
            { text = "Unknown Faction", value = "" },
            { text = "|cff3388ffAlliance|r", value = "Alliance", backdrop = { 0.05, 0.18, 0.38 } },
            { text = "|cffcc3333Horde|r", value = "Horde", backdrop = { 0.32, 0.05, 0.05 } },
        }
    end, function(value)
        Addon.addPlayerFormFaction = value
        Addon:RefreshAddPlayerWindow()
    end)
    label("Faction", 236, -136)

    dropdown("playerRating", 22, -200, 200, function()
        return {
            { text = GetRatingMeta("Good").color .. GetRatingMeta("Good").label .. "|r", value = "Good", backdrop = { 0.02, 0.36, 0.08 } },
            { text = GetRatingMeta("Okay").color .. GetRatingMeta("Okay").label .. "|r", value = "Okay", backdrop = { 0.42, 0.34, 0.04 } },
            { text = GetRatingMeta("Bad").color .. GetRatingMeta("Bad").label .. "|r", value = "Bad", backdrop = { 0.32, 0.02, 0.02 } },
        }
    end, function(value)
        Addon.addPlayerFormRating = value
        Addon:RefreshAddPlayerWindow()
    end)
    label("Rating", 22, -184)

    label("Notes", 22, -232)
    editBox("playerNotesBox", 22, -248, 514)
    frame.playerNotesBox:SetScript("OnTextChanged", function(self)
        Addon.addPlayerFormNotes = self:GetText()
    end)

    frame.guildCheck = self:CreateCheckButton(frame, "Guild Member", function()
        return Addon.addPlayerFormIsGuild or false
    end, function(value)
        Addon.addPlayerFormIsGuild = value
    end)
    frame.guildCheck:SetPoint("TOPLEFT", 22, -288)

    frame.frequentCheck = self:CreateCheckButton(frame, "Frequent Player", function()
        return Addon.addPlayerFormIsFrequent or false
    end, function(value)
        Addon.addPlayerFormIsFrequent = value
    end)
    frame.frequentCheck:SetPoint("TOPLEFT", 296, -288)

    local save = self:CreatePlainButton(frame, "Save Player", 150, 26)
    save:SetPoint("BOTTOMLEFT", 22, 18)
    save:SetScript("OnClick", function()
        Addon:SaveDataToolPlayer(false, frame)
        frame:Hide()
    end)

    local cancel = self:CreatePlainButton(frame, "Cancel", 120, 26)
    cancel:SetPoint("LEFT", save, "RIGHT", 10, 0)
    cancel:SetScript("OnClick", function()
        frame:Hide()
    end)

    self.addPlayerWindow = frame
end

-- Sets each field's displayed text/dropdown label from current state -- called once when the
-- window opens and again after every dropdown pick (dropdowns don't self-update their own button
-- label the way EditBoxes show their own typed text).
function Addon:RefreshAddPlayerWindow()
    local frame = self.addPlayerWindow
    if not frame then
        return
    end
    frame.playerNameBox:SetText(self.addPlayerFormName or "")
    frame.playerRealmBox:SetText(self.addPlayerFormRealm or (GetRealmName and GetRealmName() or ""))
    frame.playerNotesBox:SetText(self.addPlayerFormNotes or "")

    local classValue = self.addPlayerFormClass or ""
    frame.playerClassButton:SetText(classValue ~= "" and ((CLASS_COLORS[classValue] or "|cffffffff") .. ClassDisplayName(classValue) .. "|r") or "Select Class")
    local roleValue = self.addPlayerFormRole or "NONE"
    frame.playerRoleButton:SetText(GetRoleLabel(roleValue))
    local raceValue = self.addPlayerFormRace or ""
    frame.playerRaceButton:SetText(raceValue ~= "" and raceValue or "Select Race")
    local factionValue = self.addPlayerFormFaction or ""
    frame.playerFactionButton:SetText(factionValue ~= "" and factionValue or "Select Faction")
    local ratingValue = self.addPlayerFormRating or "Okay"
    frame.playerRatingButton:SetText("Rating: " .. GetRatingMeta(ratingValue).label)

    frame.guildCheck:Refresh()
    frame.frequentCheck:Refresh()
end

-- New 2026-09-05, per user request for a dedicated "Add Player Reputation" entry point rather than
-- having to open Manage Data -> Player tab and know that typing a new name there is how you add
-- someone. Per a follow-up request, this opens a genuinely SEPARATE window from Manage Data/Data
-- Tools, not another mode inside it.
function Addon:OpenAddPlayerForm()
    -- These are this window's OWN state fields (addPlayerForm*), separate from the Data Tools
    -- Player tab's dataToolSelectedPlayer* fields -- found in review 2026-09-06: they used to be
    -- the very same fields, so opening this "separate" window while Data Tools' Player tab had a
    -- real player selected would silently wipe that selection out from under it. Since
    -- RefreshAllDisplays() refreshes Data Tools whenever it's shown (on any death, roster update,
    -- run end, etc.), that tab would then auto-select a DIFFERENT player, and the next unrelated
    -- Save there would overwrite the wrong person's saved profile. Full separation fixes this.
    self.addPlayerFormName = ""
    self.addPlayerFormClass = nil
    self.addPlayerFormRole = nil
    self.addPlayerFormRace = nil
    self.addPlayerFormFaction = nil
    self.addPlayerFormRealm = nil
    self.addPlayerFormNotes = nil
    self.addPlayerFormRating = nil
    self.addPlayerFormIsGuild = nil
    self.addPlayerFormIsFrequent = nil
    self:CreateAddPlayerWindow()
    self:RefreshAddPlayerWindow()
    self:BringWindowToFront(self.addPlayerWindow)
end

-- ============================================================================================
-- Standalone "Update Player" window, new 2026-09-06 per user request ("add a separate menu to
-- update player reputation... why i want this, is because i want to see more player name on the
-- list") -- the inline edit form that used to live at the bottom of the Player Menu tab (taking up
-- roughly half the panel's vertical space) moved here, freeing that space for more visible rows
-- (PLAYER_HISTORY_VISIBLE_ROWS 10 -> 20). Unlike the Add Player window, this one deliberately
-- reuses the SAME self.dataToolSelectedPlayer* fields the old inline form used (not a separate
-- addPlayerForm*-style namespace) -- there's no risk of the two clashing the way Add Player vs.
-- Data Tools did, because this window and the Player Menu list it opens from are showing/editing
-- the exact same selection, never two different ones at once.
-- ============================================================================================
function Addon:CreateUpdatePlayerWindow()
    if self.updatePlayerWindow then
        return
    end

    local frame = CreateFrame("Frame", "MPlusLedgerUpdatePlayerWindow", UIParent, "BackdropTemplate")
    frame:SetSize(560, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    frame:SetBackdropColor(Addon:GetTableBackgroundColor(0.97))
    frame:SetBackdropBorderColor(self:GetThemeBorderColor(true, 1))
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- Never had ESC handling at all before 2026-10-01 -- see Addon:CloseAllWindows for why that
    -- mattered (ESC did nothing here, not even close this one window).
    EnableEscHandler(frame, function()
        Addon:CloseAllWindows()
    end)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Update Player Reputation")

    local close = self:CreatePlainButton(frame, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetScript("OnClick", function()
        Addon:ReturnToMainMenu()
    end)

    frame.menus = {}
    -- Click-outside-to-close catcher + cursor-leave auto-close -- same fix, same reasoning as
    -- CreateAddPlayerWindow's identical copy of this helper set (see its own comments for why a
    -- local catcher instead of reusing the Stats Hub shared one).
    local clickCatcher = CreateFrame("Button", nil, frame)
    clickCatcher:SetAllPoints(frame)
    clickCatcher:EnableMouse(true)
    clickCatcher:Hide()
    local function hideMenus()
        for _, m in ipairs(frame.menus) do
            m:Hide()
        end
        clickCatcher:Hide()
    end
    clickCatcher:SetScript("OnClick", hideMenus)
    local function closeOnLeave(menu, anchor)
        menu:SetScript("OnLeave", function()
            C_Timer.After(0.15, function()
                if menu:IsShown() and not menu:IsMouseOver() and not (anchor and anchor:IsMouseOver()) then
                    menu:Hide()
                    local anyShown = false
                    for _, m in ipairs(frame.menus) do
                        if m:IsShown() then anyShown = true; break end
                    end
                    if not anyShown then clickCatcher:Hide() end
                end
            end)
        end)
    end
    local function label(text, x, y)
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetText(text)
        return fs
    end
    local function editBox(key, x, y, width)
        local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        box:SetSize(width, 24)
        box:SetPoint("TOPLEFT", x, y)
        box:SetAutoFocus(false)
        box:SetTextInsets(4, 4, 0, 0)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        frame[key] = box
        return box
    end
    local function dropdown(key, x, y, width, getOptions, onPick)
        local btn = self:CreatePlainButton(frame, "", width, 24)
        btn:SetPoint("TOPLEFT", x, y)
        local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        menu:SetSize(width, 30)
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        menu:SetFrameLevel(frame:GetFrameLevel() + 30)
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        menu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
        menu:EnableMouse(true)
        menu:Hide()
        table.insert(frame.menus, menu)
        closeOnLeave(menu, btn)
        btn:SetScript("OnClick", function()
            if menu:IsShown() then
                menu:Hide()
                clickCatcher:Hide()
            else
                hideMenus()
                Addon:RefreshSimpleDropdown(menu, getOptions(), onPick)
                menu:Show()
                clickCatcher:SetFrameLevel(math.max(1, menu:GetFrameLevel() - 1))
                clickCatcher:Show()
            end
        end)
        frame[key .. "Button"] = btn
        frame[key .. "Menu"] = menu
        return btn
    end
    -- Realm type-ahead -- same as CreateAddPlayerWindow's realmField (see its own comments).
    local function realmField(key, x, y, width)
        local box = editBox(key, x, y, width)
        local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        menu:SetSize(width, 30)
        menu:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
        menu:SetFrameLevel(frame:GetFrameLevel() + 30)
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        menu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
        menu:EnableMouse(true)
        menu:Hide()
        table.insert(frame.menus, menu)
        closeOnLeave(menu, box)
        local function showSuggestions()
            -- Only while the box actually has focus -- RefreshAddPlayerWindow/
            -- RefreshUpdatePlayerWindow call box:SetText(...) on every refresh (e.g. after any
            -- other dropdown pick) to keep the displayed value in sync, which also fires
            -- OnTextChanged; without this check the suggestion menu would pop open uninvited every
            -- single time, not just while the user is actually typing or has clicked in.
            if not box:HasFocus() then
                return
            end
            local query = strtrim(box:GetText() or ""):lower()
            local filtered = {}
            for _, name in ipairs(Addon:GetKnownRealmNames()) do
                if query == "" or tostring(name):lower():find(query, 1, true) then
                    table.insert(filtered, { text = name, value = name })
                    if #filtered >= 12 then break end
                end
            end
            if #filtered > 0 then
                hideMenus()
                Addon:RefreshSimpleDropdown(menu, filtered, function(value)
                    box:SetText(value)
                    menu:Hide()
                    clickCatcher:Hide()
                end)
                menu:Show()
                clickCatcher:SetFrameLevel(math.max(1, menu:GetFrameLevel() - 1))
                clickCatcher:Show()
            else
                menu:Hide()
            end
        end
        box:SetScript("OnEditFocusGained", showSuggestions)
        box:HookScript("OnTextChanged", showSuggestions)
        frame[key .. "Menu"] = menu
        return box
    end

    -- Same live-sync-while-typing pattern as Add Player -- picking any dropdown below calls
    -- RefreshUpdatePlayerWindow(), which would otherwise rebuild these boxes from a stale value
    -- and silently discard anything typed but not yet saved.
    editBox("playerNameBox", 22, -56, 240)
    frame.playerNameBox:SetScript("OnTextChanged", function(self)
        Addon.dataToolSelectedPlayerName = self:GetText()
    end)
    label("Player name", 22, -40)
    realmField("playerRealmBox", 296, -56, 240)
    frame.playerRealmBox:HookScript("OnTextChanged", function(self)
        Addon.dataToolSelectedPlayerRealm = self:GetText()
    end)
    label("Realm", 296, -40)

    dropdown("playerClass", 22, -104, 200, function()
        local options = { { text = "Unknown Class", value = "" } }
        for className in pairs(CLASS_COLORS) do
            table.insert(options, { text = CLASS_COLORS[className] .. ClassDisplayName(className) .. "|r", value = className, backdrop = CLASS_BACKDROP_COLORS[className] })
        end
        table.sort(options, function(a, b) return tostring(a.value) < tostring(b.value) end)
        return options
    end, function(value)
        Addon.dataToolSelectedPlayerClass = value
        Addon:RefreshUpdatePlayerWindow()
    end)
    label("Class", 22, -88)

    dropdown("playerRole", 236, -104, 150, function()
        return {
            { text = "Tank", value = "TANK" },
            { text = "Heals", value = "HEALER" },
            { text = "DPS", value = "DAMAGER" },
            { text = "None", value = "NONE" },
        }
    end, function(value)
        Addon.dataToolSelectedPlayerRole = value
        Addon:RefreshUpdatePlayerWindow()
    end)
    label("Role", 236, -88)

    dropdown("playerRace", 22, -152, 200, function()
        local options = { { text = "Unknown Race", value = "" } }
        for _, raceName in ipairs(RACE_OPTIONS) do
            table.insert(options, { text = raceName, value = raceName })
        end
        return options
    end, function(value)
        Addon.dataToolSelectedPlayerRace = value
        -- Auto-pick the Faction this race actually belongs to -- same as Add Player (see its own
        -- comment); Pandaren/Dracthyr/Earthen leave the existing Faction pick untouched.
        local faction = RACE_FACTION[value]
        if faction then
            Addon.dataToolSelectedPlayerFaction = faction
        end
        Addon:RefreshUpdatePlayerWindow()
    end)
    label("Race", 22, -136)

    dropdown("playerFaction", 236, -152, 150, function()
        return {
            { text = "Unknown Faction", value = "" },
            { text = "|cff3388ffAlliance|r", value = "Alliance", backdrop = { 0.05, 0.18, 0.38 } },
            { text = "|cffcc3333Horde|r", value = "Horde", backdrop = { 0.32, 0.05, 0.05 } },
        }
    end, function(value)
        Addon.dataToolSelectedPlayerFaction = value
        Addon:RefreshUpdatePlayerWindow()
    end)
    label("Faction", 236, -136)

    dropdown("playerRating", 22, -200, 200, function()
        return {
            { text = GetRatingMeta("Good").color .. GetRatingMeta("Good").label .. "|r", value = "Good", backdrop = { 0.02, 0.36, 0.08 } },
            { text = GetRatingMeta("Okay").color .. GetRatingMeta("Okay").label .. "|r", value = "Okay", backdrop = { 0.42, 0.34, 0.04 } },
            { text = GetRatingMeta("Bad").color .. GetRatingMeta("Bad").label .. "|r", value = "Bad", backdrop = { 0.32, 0.02, 0.02 } },
        }
    end, function(value)
        Addon.dataToolSelectedPlayerRating = value
        Addon:RefreshUpdatePlayerWindow()
    end)
    label("Rating", 22, -184)

    label("Notes", 22, -232)
    editBox("playerNotesBox", 22, -248, 514)
    frame.playerNotesBox:SetScript("OnTextChanged", function(self)
        Addon.dataToolSelectedPlayerNotes = self:GetText()
    end)

    frame.guildCheck = self:CreateCheckButton(frame, "Guild Member", function()
        return Addon.dataToolSelectedPlayerIsGuild or false
    end, function(value)
        Addon.dataToolSelectedPlayerIsGuild = value
    end)
    frame.guildCheck:SetPoint("TOPLEFT", 22, -288)

    frame.frequentCheck = self:CreateCheckButton(frame, "Frequent Player", function()
        return Addon.dataToolSelectedPlayerIsFrequent or false
    end, function(value)
        Addon.dataToolSelectedPlayerIsFrequent = value
    end)
    frame.frequentCheck:SetPoint("TOPLEFT", 296, -288)

    local save = self:CreatePlainButton(frame, "Save Player", 130, 26)
    save:SetPoint("BOTTOMLEFT", 22, 18)
    save:SetScript("OnClick", function()
        Addon:SaveDataToolPlayer(false, frame)
        Addon.dataToolPlayerHistoryOffset = 0
        frame:Hide()
    end)

    local delete = self:CreatePlainButton(frame, "Delete Player", 130, 26)
    delete:SetPoint("LEFT", save, "RIGHT", 10, 0)
    delete:SetScript("OnClick", function()
        Addon:DeleteDataToolPlayer()
        Addon.dataToolPlayerHistoryOffset = 0
        frame:Hide()
    end)
    ApplyButtonColor(delete, STATUS_BACKDROP_COLORS.Abandoned)
    frame.deleteButton = delete

    local cancel = self:CreatePlainButton(frame, "Cancel", 120, 26)
    cancel:SetPoint("LEFT", delete, "RIGHT", 10, 0)
    cancel:SetScript("OnClick", function()
        frame:Hide()
    end)

    self.updatePlayerWindow = frame
end

-- Sets each field's displayed text/dropdown label from current state -- called once when the
-- window opens and again after every dropdown pick. Mirrors the old inline form's exact pre-fill
-- fallback chain (dataToolSelectedPlayerX -> most-recently-seen run member's value -> the saved
-- profile's own value), just relocated here.
function Addon:RefreshUpdatePlayerWindow()
    local frame = self.updatePlayerWindow
    if not frame then
        return
    end

    local member = self:FindMostRecentMember(self.dataToolSelectedPlayerName)
    local selectedKey = self.dataToolSelectedPlayerKey or GetPlayerProfileKey((member and member.name) or self.dataToolSelectedPlayerName)
    local profile = selectedKey and self.db.playerRatings and self.db.playerRatings[selectedKey]

    frame.playerNameBox:SetText(self.dataToolSelectedPlayerName or "")

    local qualifiedName = (profile and profile.name and profile.realm and (profile.name .. "-" .. profile.realm)) or (member and member.name) or self.dataToolSelectedPlayerName
    local _, realm = GetPlayerRealmName(qualifiedName)
    frame.playerRealmBox:SetText(self.dataToolSelectedPlayerRealm or (profile and profile.realm) or realm or "")

    frame.playerNotesBox:SetText(self.dataToolSelectedPlayerNotes or (profile and profile.notes) or "")

    local classValue = self.dataToolSelectedPlayerClass
    if classValue == nil then
        classValue = (member and member.class) or (profile and profile.class) or ""
    end
    frame.playerClassButton:SetText(classValue ~= "" and ((CLASS_COLORS[classValue] or "|cffffffff") .. ClassDisplayName(classValue) .. "|r") or "Select Class")

    local roleValue = self.dataToolSelectedPlayerRole or (member and member.role) or (profile and profile.role) or "NONE"
    frame.playerRoleButton:SetText(GetRoleLabel(roleValue))

    local raceValue = self.dataToolSelectedPlayerRace
    if raceValue == nil then
        raceValue = (profile and profile.race) or ""
    end
    frame.playerRaceButton:SetText(raceValue ~= "" and raceValue or "Select Race")

    local factionValue = self.dataToolSelectedPlayerFaction
    if factionValue == nil then
        factionValue = (profile and profile.faction) or ""
    end
    frame.playerFactionButton:SetText(factionValue ~= "" and factionValue or "Select Faction")

    local ratingValue = self.dataToolSelectedPlayerRating or (profile and profile.rating) or "Okay"
    self.dataToolSelectedPlayerRating = ratingValue
    frame.playerRatingButton:SetText("Rating: " .. GetRatingMeta(ratingValue).label)

    frame.guildCheck:Refresh()
    frame.frequentCheck:Refresh()

    -- Matches the old inline form's own safeguard (it only ever CREATED the Delete button when a
    -- real saved profile existed) -- this window is built once and reused, so disabling rather
    -- than not-creating it is the equivalent here. Deleting a nonexistent profile is harmless
    -- either way (DeleteDataToolPlayer no-ops), but it would still print a misleading "Deleted
    -- saved player" message with nothing actually behind it.
    if profile then
        frame.deleteButton:Enable()
    else
        frame.deleteButton:Disable()
    end
end

-- Deliberately does NOT reset dataToolSelectedPlayer* the way OpenAddPlayerForm resets its own
-- fields -- this window is meant to open already pre-filled with whichever player is currently
-- selected (the button that calls this already ensures something is selected before calling in).
function Addon:OpenUpdatePlayerForm()
    self:CreateUpdatePlayerWindow()
    self:RefreshUpdatePlayerWindow()
    self:BringWindowToFront(self.updatePlayerWindow)
end

function Addon:RefreshDataToolsWindow()
    local editor = self.dataTools
    if not editor then
        return
    end

    for _, frame in ipairs(editor.dynamicFrames or {}) do
        frame:Hide()
    end
    editor.dynamicFrames = {}
    for _, menu in pairs(editor.menus or {}) do
        menu:Hide()
    end
    editor.menus = {}
    editor:SetFrameLevel(410)
    editor.mode = self.dataToolMode or editor.mode or "hub"

    editor.instanceNameBox = nil
    editor.expansionNameBox = nil
    editor.journalInstanceIDBox = nil
    editor.difficultyButton = nil
    editor.keyLevelBox = nil
    editor.bossIDBox = nil
    editor.bossNameBox = nil
    editor.bossOrderBox = nil
    editor.bossOptionalCheck = nil
    editor.bossFinalCheck = nil
    editor.mobIDBox = nil
    editor.mobNameBox = nil
    editor.playerNameBox = nil
    editor.playerClassButton = nil
    editor.playerRoleButton = nil
    editor.addPlayerNameBox = nil
    editor.addPlayerClassButton = nil
    editor.addPlayerRoleButton = nil

    local function remember(frame)
        table.insert(editor.dynamicFrames, frame)
        return frame
    end
    local function text(line, x, y, template, width)
        local font = remember(editor.content:CreateFontString(nil, "OVERLAY", template or "GameFontDisableSmall"))
        font:SetPoint("TOPLEFT", x, y)
        if width then
            font:SetWidth(width)
            font:SetJustifyH("LEFT")
        end
        font:SetText(line)
        return font
    end
    local function title(line, y)
        return text(line, 22, y, "GameFontNormalLarge", 860)
    end
    local function label(line, x, y)
        return text(line, x, y, "GameFontDisableSmall")
    end
    local function box(key, x, y, width, numeric, value)
        local editBox = remember(CreateFrame("EditBox", nil, editor.content, "InputBoxTemplate"))
        editBox:SetSize(width or 160, 24)
        editBox:SetPoint("TOPLEFT", x, y)
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(4, 4, 0, 0)
        if numeric then
            editBox:SetNumeric(true)
        end
        editBox:SetText(tostring(value or ""))
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        editor[key] = editBox
        return editBox
    end
    -- Type-ahead wrapper around box() -- per user request 2026-09-05 ("context search in all
    -- fields where you need to enter a name or id"). suggestionsFn returns the full candidate name
    -- list fresh on every keystroke (cheap -- these are small in-memory tables, not run scans), so
    -- it stays correct even if the underlying catalog changes while this editor is open.
    -- onTextChanged (new 2026-09-05): fixes a real bug the user reported -- picking a value from
    -- ANY dropdown on this form calls RefreshDataToolsWindow(), which rebuilds every EditBox from
    -- scratch using whatever value it was ORIGINALLY constructed with. A box that only had its own
    -- OnTextChanged wired to suggestion-filtering (not to any state variable) would get recreated
    -- from that stale original value the instant a sibling dropdown was touched, silently discarding
    -- whatever the user had just typed but not yet saved. Callers that need the live text to survive
    -- a refresh now pass onTextChanged to sync it into a state variable on every keystroke.
    -- showAllWhenEmpty (new 2026-10-02, per user request "combine the two bars for instance and
    -- choose existing"): lets a caller fold a separate "Pick Existing X..." dropdown button into
    -- this same field -- clicking in with no text yet shows the first 12 known values immediately
    -- (same list typing would filter), instead of only ever showing suggestions once the user has
    -- already typed something. Opt-in per call site rather than a global behavior change, since
    -- most existing callers (boss name, mob name, etc.) were never paired with a redundant picker
    -- button in the first place.
    local function autocompleteBox(key, x, y, width, value, suggestionsFn, onPick, onTextChanged, showAllWhenEmpty)
        local editBox = box(key, x, y, width, false, value)
        local menuKey = key .. "Suggestions"
        local suggestMenu = remember(CreateFrame("Frame", nil, editor.content, "BackdropTemplate"))
        suggestMenu:SetSize(width or 220, 30)
        suggestMenu:SetFrameLevel(editor:GetFrameLevel() + 30)
        suggestMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        suggestMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
        suggestMenu:EnableMouse(true)
        suggestMenu:Hide()
        editor.menus[menuKey] = suggestMenu
        -- Closes on cursor-leave -- per user report 2026-10-02 ("the dropdown box... should close
        -- the dropdown box once the cursor moves out of the selection field but it does not"). This
        -- suggestion menu never had the close-on-cursor-leave handling the Add/Update Player realm
        -- field and the Stats Hub dropdowns already have (see CreateStatsHubDropdown's own comment
        -- for why the delayed IsMouseOver() recheck, not an immediate hide, is needed -- hiding
        -- immediately on OnLeave would close the menu the instant you tried to hover an option to
        -- click it, since OnLeave also fires on the background-to-child-button mouse transition).
        suggestMenu:SetScript("OnLeave", function(self)
            C_Timer.After(0.15, function()
                if self:IsShown() and not self:IsMouseOver() then
                    self:Hide()
                end
            end)
        end)

        editBox:SetScript("OnTextChanged", function(self)
            if onTextChanged then
                onTextChanged(self:GetText() or "")
            end
            if not self:HasFocus() then suggestMenu:Hide(); return end
            local query = strtrim(self:GetText() or ""):lower()
            if query == "" and not showAllWhenEmpty then
                suggestMenu:Hide()
                return
            end
            local filtered = {}
            for _, name in ipairs(suggestionsFn()) do
                if query == "" or tostring(name):lower():find(query, 1, true) then
                    table.insert(filtered, { text = name, value = name })
                    if #filtered >= 12 then
                        break
                    end
                end
            end
            if #filtered > 0 then
                editor:HideMenus()
                Addon:RefreshSimpleDropdown(suggestMenu, filtered, function(pickedValue)
                    editBox:SetText(pickedValue)
                    suggestMenu:Hide()
                    if onPick then
                        onPick(pickedValue)
                    end
                end)
                suggestMenu:ClearAllPoints()
                suggestMenu:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -2)
                suggestMenu:Show()
            else
                suggestMenu:Hide()
            end
        end)
        if showAllWhenEmpty then
            editBox:HookScript("OnEditFocusGained", function(self)
                local handler = self:GetScript("OnTextChanged")
                if handler then
                    handler(self)
                end
            end)
        end
        return editBox
    end
    local function button(key, line, x, y, width, onClick, backdrop)
        local btn = remember(Addon:CreatePlainButton(editor.content, line, width or 130, 24))
        btn:SetPoint("TOPLEFT", x, y)
        if backdrop then
            ApplyButtonColor(btn, backdrop)
        end
        if key then
            editor[key] = btn
        end
        if onClick then
            btn:SetScript("OnClick", onClick)
        end
        return btn
    end
    local function menu(key, anchor, width, options, onPick)
        local drop = remember(CreateFrame("Frame", nil, editor.content, "BackdropTemplate"))
        drop:SetSize(width or 220, 30)
        drop:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        drop:SetFrameLevel(editor:GetFrameLevel() + 30)
        drop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        drop:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
        drop:EnableMouse(true)
        -- Closes on cursor-leave -- per user report 2026-10-02 ("Can you check all dropdown boxes
        -- as well as this seems to be a persistent issue?"). This button+menu builder is
        -- duplicated almost verbatim across several windows in this file (Run Editor, Manage Runs,
        -- ...), each missing the same close-on-cursor-leave handling -- see CreateStatsHubDropdown's
        -- own comment for why a delayed IsMouseOver() recheck, not an immediate hide, is required.
        drop:SetScript("OnLeave", CloseDropdownOnLeave)
        editor[key] = drop
        editor.menus[key] = drop
        Addon:RefreshSimpleDropdown(drop, options, onPick)
        drop:Hide()
        return drop
    end
    function editor:HideMenus()
        for _, drop in pairs(self.menus or {}) do
            drop:Hide()
        end
    end
    local function dropdown(menuKey, buttonKey, line, x, y, width, options, onPick)
        local btn = button(buttonKey, line, x, y, width)
        local drop = menu(menuKey, btn, width, options, onPick)
        btn:SetScript("OnClick", function()
            if drop:IsShown() then
                drop:Hide()
            else
                editor:HideMenus()
                drop:Show()
            end
        end)
        return btn
    end
    local function checkButton(key, line, x, y, width, getter, setter)
        local btn = remember(Addon:CreateCheckButton(editor.content, line, getter, setter))
        btn:SetPoint("TOPLEFT", x, y)
        btn:SetWidth(width or 260)
        if key then
            editor[key] = btn
        end
        return btn
    end
    local function check(key, line, x, y, checked)
        local btn = button(key, "", x, y, 142)
        btn.checked = checked and true or false
        btn.Refresh = function(self)
            self:SetText((self.checked and "|cff00ff00X|r " or "|cff777777-|r ") .. line)
        end
        btn:SetScript("OnClick", function(self)
            self.checked = not self.checked
            self:Refresh()
        end)
        btn:Refresh()
        return btn
    end

    local mode = editor.mode
    for navMode, btn in pairs(editor.navButtons or {}) do
        if navMode == mode then
            btn:SetBackdropColor(0.10, 0.24, 0.42, 0.95)
        else
            btn:SetBackdropColor(0.45, 0.02, 0.02, 0.85)
        end
    end

    local run = self:GetDataToolSelectedRun()
    local function runText()
        if not run then
            return "Select Run"
        end
        return self:GetRunOptionText(run)
    end
    local function addRunFilters(y)
        if self.dataToolRunFilterSeasonOnly == nil then
            self.dataToolRunFilterSeasonOnly = true
        end
        checkButton("runSeasonOnlyCheck", "Show Current Mythic+ Season", 22, y, 260, function()
            return Addon.dataToolRunFilterSeasonOnly == true
        end, function(value)
            Addon.dataToolRunFilterSeasonOnly = value and true or false
            Addon:RefreshDataToolsWindow()
        end)
        local expansionLabel = self.dataToolRunFilterExpansionName and self.dataToolRunFilterExpansionName ~= "" and self.dataToolRunFilterExpansionName or "All Expansions"
        dropdown("runExpansionFilterMenu", "runExpansionFilterButton", expansionLabel, 306, y, 240, self:GetExpansionFilterOptions(), function(value)
            Addon.dataToolRunFilterExpansionName = value ~= "" and value or nil
            Addon.dataToolRunFilterInstanceName = nil
            Addon:RefreshDataToolsWindow()
        end)
        local instanceLabel = self.dataToolRunFilterInstanceName and self.dataToolRunFilterInstanceName ~= "" and self.dataToolRunFilterInstanceName or "All Instances"
        dropdown("runInstanceFilterMenu", "runInstanceFilterButton", instanceLabel, 570, y, 260, self:GetInstanceFilterOptions(self.dataToolRunFilterExpansionName), function(value)
            Addon.dataToolRunFilterInstanceName = value ~= "" and value or nil
            Addon:RefreshDataToolsWindow()
        end)
    end
    local function addRunSelector(y)
        local runOptions = self:SelectFirstFilteredRun("dataToolRunFilter", "dataToolSelectedRunID")
        run = runOptions[1] and self:GetDataToolSelectedRun() or nil
        dropdown("runMenu", "runButton", runText(), 22, y, 660, runOptions, function(value)
            Addon.dataToolSelectedRunID = value
            Addon.debugSelectedRunID = value
            Addon.dataToolSelectedBossID = nil
            Addon.dataToolSelectedMobID = nil
            Addon.dataToolSelectedPlayerName = nil
            Addon.dataToolSelectedPlayerKey = nil
            Addon.dataToolSelectedDifficulty = nil
            Addon:RefreshDataToolsWindow()
        end)
    end

    if mode == "hub" then
        title("Choose a data tool", -20)
        text("Player: correct a player's name, class, or role on a selected run.", 22, -70, "GameFontHighlight", 860)
        text("Run: pick an existing run and edit its status, difficulty, key level, and links.", 22, -104, "GameFontHighlight", 860)
        text("Create Run: add a manual run, then fill in players, bosses, repairs, and timing.", 22, -138, "GameFontHighlight", 860)
        return
    end

    if mode == "instanceData" then
        title("Instance Data", -20)
        local expansionName = self.dataToolSelectedExpansionName or (run and self:GetRunExpansionText(run)) or ""
        dropdown("expansionMenu", "expansionButton", expansionName ~= "" and expansionName or "Select Expansion", 22, -64, 260, self:GetDataToolExpansionOptions(), function(value)
            Addon.dataToolSelectedExpansionName = value
            Addon.dataToolSelectedInstanceName = nil
            Addon.dataToolSelectedMobID = nil
            Addon.dataToolSelectedBossID = nil
            Addon:RefreshDataToolsWindow()
        end)
        local instanceOptions = self:GetDataToolInstancesForExpansion(expansionName)
        dropdown("instanceMenu", "instanceButton", self.dataToolSelectedInstanceName or "Select Instance", 306, -64, 360, instanceOptions, function(value)
            Addon:SelectDataToolInstance(value)
            Addon.dataToolSelectedMobID = nil
            Addon.dataToolSelectedBossID = nil
            Addon:RefreshDataToolsWindow()
        end)
        if expansionName == "" then
            text("Select an expansion first. The instance list will only show instances linked to that expansion.", 22, -112, "GameFontHighlight", 860)
            return
        end
        if not self.dataToolSelectedInstanceName then
            text("Select an instance to view its captured mobs and bosses.", 22, -112, "GameFontHighlight", 860)
            dropdown("seasonMenu", "seasonButton", self.dataToolSelectedSeasonName or "Assign Season", 22, -152, 260, self:GetDataToolSeasonOptions(), function(value)
                Addon.dataToolSelectedSeasonName = value
                Addon:RefreshDataToolsWindow()
            end)
            dropdown("manualInstanceMenu", "manualInstanceButton", self.dataToolManualInstanceName or "Manual Instance Link", 306, -152, 260, self:GetDataToolInstanceOptions(), function(value)
                Addon.dataToolManualInstanceName = value
                Addon:RefreshDataToolsWindow()
            end)
            button(nil, "Link Expansion", 590, -152, 130, function()
                Addon:LinkInstanceToExpansion(Addon.dataToolManualInstanceName, expansionName)
                Addon:RefreshDataToolsWindow()
            end)
            button(nil, "Link M+ Season", 730, -152, 130, function()
                Addon:LinkInstanceToSeason(Addon.dataToolManualInstanceName, Addon.dataToolSelectedSeasonName)
                Addon:RefreshDataToolsWindow()
            end)
            return
        end

        local instanceName = self.dataToolSelectedInstanceName
        local catalog = self.db and self.db.instanceCatalog and self.db.instanceCatalog[instanceName]
        local metadata = self.db and self.db.dungeonMetadata and self.db.dungeonMetadata[instanceName]
        text(string.format("Instance: %s", instanceName), 22, -112, "GameFontHighlight", 860)
        text(string.format("Expansion: %s", expansionName), 22, -142, "GameFontHighlight", 860)
        text(string.format("Adventure Guide ID: %s%s", tostring((catalog and catalog.journalInstanceID) or (metadata and metadata.journalInstanceID) or "not found"), catalog and catalog.verify and " | |cffffff00Verify|r" or ""), 22, -172, "GameFontHighlight", 860)
        dropdown("seasonMenu", "seasonButton", self.dataToolSelectedSeasonName or "Assign Season", 22, -204, 260, self:GetDataToolSeasonOptions(), function(value)
            Addon.dataToolSelectedSeasonName = value
            Addon:RefreshDataToolsWindow()
        end)
        button(nil, "Link Season", 306, -204, 120, function()
            Addon:LinkInstanceToSeason(instanceName, Addon.dataToolSelectedSeasonName)
            Addon:RefreshDataToolsWindow()
        end)
        dropdown("manualInstanceMenu", "manualInstanceButton", self.dataToolManualInstanceName or "Manual Instance Link", 450, -204, 260, self:GetDataToolInstanceOptions(), function(value)
            Addon.dataToolManualInstanceName = value
            Addon:RefreshDataToolsWindow()
        end)
        button(nil, "Link Expansion", 726, -204, 130, function()
            Addon:LinkInstanceToExpansion(Addon.dataToolManualInstanceName or instanceName, expansionName)
            Addon:RefreshDataToolsWindow()
        end)
        button(nil, "Link M+ Season", 726, -236, 130, function()
            Addon:LinkInstanceToSeason(Addon.dataToolManualInstanceName or instanceName, Addon.dataToolSelectedSeasonName)
            Addon:RefreshDataToolsWindow()
        end)

        local mobOptions = self:GetDataToolCatalogOptions(self.db and self.db.npcCatalog, "npcID", expansionName, instanceName)
        local bossOptions = self:GetDataToolCatalogOptions(self.db and self.db.bossCatalog, "bossID", expansionName, instanceName)
        dropdown("mobMenu", "mobButton", self.dataToolSelectedMobID and ("Mob " .. tostring(self.dataToolSelectedMobID)) or "Select Mob", 22, -252, 360, mobOptions, function(value)
            Addon.dataToolSelectedMobID = value
            Addon:RefreshDataToolsWindow()
        end)
        dropdown("bossMenu", "bossButton", self.dataToolSelectedBossID and ("Boss " .. tostring(self.dataToolSelectedBossID)) or "Select Boss", 406, -252, 360, bossOptions, function(value)
            Addon.dataToolSelectedBossID = value
            Addon:RefreshDataToolsWindow()
        end)
        local mob = self.dataToolSelectedMobID and self.db and self.db.npcCatalog and self.db.npcCatalog[tostring(self.dataToolSelectedMobID)]
        if mob then
            text(string.format("Mob ID: %s | Name: %s | Level: %s%s", tostring(mob.npcID), tostring(mob.name or "not captured"), tostring(mob.level or "not captured"), mob.verify and " | |cffffff00Verify|r" or ""), 22, -302, "GameFontHighlight", 860)
        end
        local boss = self.dataToolSelectedBossID and self.db and self.db.bossCatalog and self.db.bossCatalog[tostring(self.dataToolSelectedBossID)]
        if boss then
            text(string.format("Boss ID: %s | Name: %s | Level: %s | Health: %s%s", tostring(boss.bossID), tostring(boss.name or "not captured"), tostring(boss.level or "not captured"), tostring(boss.health or "not captured"), boss.verify and " | |cffffff00Verify|r" or ""), 22, -336, "GameFontHighlight", 860)
        end
        button(nil, "Find Guide ID", 22, -392, 120, function()
            local selectedRun = Addon:GetDataToolSelectedRun()
            if selectedRun then
                Addon:CatalogCurrentInstance(selectedRun)
                Addon:RefreshDataToolsWindow()
            end
        end)
        return
    end

    if mode == "unassigned" then
        title("Assign Mobs & Bosses", -20)
        local allMobOptions = self:GetDataToolCatalogOptionsAll(self.db and self.db.npcCatalog, "npcID")
        local allBossOptions = self:GetDataToolCatalogOptionsAll(self.db and self.db.bossCatalog, "bossID")
        dropdown("mobMenu", "mobButton", self.dataToolSelectedMobID and ("Mob " .. tostring(self.dataToolSelectedMobID)) or "Select Mob", 22, -64, 360, allMobOptions, function(value)
            Addon.dataToolSelectedMobID = value
            Addon.dataToolSelectedBossID = nil
            Addon:RefreshDataToolsWindow()
        end)
        dropdown("bossMenu", "bossButton", self.dataToolSelectedBossID and ("Boss " .. tostring(self.dataToolSelectedBossID)) or "Select Boss", 406, -64, 360, allBossOptions, function(value)
            Addon.dataToolSelectedBossID = value
            Addon.dataToolSelectedMobID = nil
            Addon:RefreshDataToolsWindow()
        end)

        local selectedMob = self.dataToolSelectedMobID and self.db and self.db.npcCatalog and self.db.npcCatalog[tostring(self.dataToolSelectedMobID)]
        local selectedBoss = self.dataToolSelectedBossID and self.db and self.db.bossCatalog and self.db.bossCatalog[tostring(self.dataToolSelectedBossID)]
        local selectedInfo = selectedMob or selectedBoss

        -- Infer the type selector from the entry's current assignment the first time it's picked
        -- (until the user changes it), so re-opening an already-assigned entry doesn't start on
        -- an empty "Select Type" with none of its current fields visible.
        if selectedInfo and not self.dataToolUnassignedType then
            if selectedInfo.expansionName == "Open World" then
                self.dataToolUnassignedType = "openworld"
            elseif selectedInfo.expansionName == "Delve" then
                self.dataToolUnassignedType = "delve"
            elseif not IsPlaceholderExpansionName(selectedInfo.expansionName) and selectedInfo.instanceName and selectedInfo.instanceName ~= "" then
                local catalogExpansion = self.db.expansionCatalog and self.db.expansionCatalog[selectedInfo.expansionName]
                if catalogExpansion and catalogExpansion.raids and catalogExpansion.raids[selectedInfo.instanceName] then
                    self.dataToolUnassignedType = "raid"
                else
                    self.dataToolUnassignedType = "dungeon"
                end
            end
        end

        local assignType = self.dataToolUnassignedType
        local typeLabel = "Select Type"
        for _, option in ipairs(ASSIGNMENT_TYPE_OPTIONS) do
            if option.value == assignType then
                typeLabel = option.text
                break
            end
        end
        dropdown("assignTypeMenu", "assignTypeButton", typeLabel, 22, -116, 180, ASSIGNMENT_TYPE_OPTIONS, function(value)
            Addon.dataToolUnassignedType = value
            Addon:RefreshDataToolsWindow()
        end)

        if assignType == "openworld" then
            text("No expansion or instance needed. Open World keeps the creature out of dungeon views, but still saves it here for later review.", 218, -114, "GameFontHighlight", 660)
        elseif assignType == "delve" then
            label("Delve name", 218, -100)
            autocompleteBox("unassignedDelveNameBox", 218, -118, 300, selectedInfo and selectedInfo.expansionName == "Delve" and selectedInfo.instanceName or "", function() return Addon:GetKnownDelveNames() end)
        elseif assignType == "dungeon" or assignType == "raid" then
            dropdown("expansionMenu", "expansionButton", self.dataToolSelectedExpansionName or "Assign Expansion", 218, -116, 220, self:GetDataToolExpansionOptions(), function(value)
                Addon.dataToolSelectedExpansionName = value
                Addon:RefreshDataToolsWindow()
            end)
            local instanceOptions = self:GetDataToolInstancesForExpansionKind(self.dataToolSelectedExpansionName, assignType == "raid" and "raids" or "dungeons")
            dropdown("instanceMenu", "instanceButton", self.dataToolSelectedInstanceName or "Assign Instance", 452, -116, 300, instanceOptions, function(value)
                Addon.dataToolSelectedInstanceName = value
                Addon:RefreshDataToolsWindow()
            end)
        else
            text("Pick a type to continue: Dungeon, Raid, Delve, or Open World.", 218, -120, "GameFontHighlight", 660)
        end

        if selectedInfo then
            local currentlyAt = (not IsPlaceholderExpansionName(selectedInfo.expansionName) and selectedInfo.instanceName and selectedInfo.instanceName ~= "") and selectedInfo.instanceName
                or (selectedInfo.expansionName == "Open World" and "Open World")
                or "not assigned to a dungeon yet"
            text("Currently mapped to: " .. currentlyAt, 22, -148, "GameFontHighlight", 860)
        end
        label("Name", 22, -168)
        autocompleteBox("unassignedNameBox", 22, -186, 360, (selectedMob and selectedMob.name) or (selectedBoss and selectedBoss.name), function() return selectedMob and Addon:GetKnownMobNames() or Addon:GetKnownBossNames() end)
        button(nil, "Save Assignment", 22, -238, 150, function()
            local saveType = Addon.dataToolUnassignedType
            if not saveType then
                Print("Pick a type first: Dungeon, Raid, Delve, or Open World.")
                return
            end

            local expansionName, instanceName
            if saveType == "openworld" then
                expansionName, instanceName = "Open World", nil
            elseif saveType == "delve" then
                local delveName = strtrim(editor.unassignedDelveNameBox and editor.unassignedDelveNameBox:GetText() or "")
                if delveName == "" then
                    Print("Enter a Delve name.")
                    return
                end
                expansionName, instanceName = "Delve", delveName
            else
                expansionName = Addon.dataToolSelectedExpansionName
                instanceName = Addon.dataToolSelectedInstanceName
                if not expansionName or expansionName == "" or not instanceName or instanceName == "" then
                    Print("Select an expansion and instance.")
                    return
                end
            end

            local name = strtrim(editor.unassignedNameBox and editor.unassignedNameBox:GetText() or "")
            if Addon.dataToolSelectedMobID and Addon.db.npcCatalog then
                local mob = Addon.db.npcCatalog[tostring(Addon.dataToolSelectedMobID)]
                if mob then
                    mob.name = name ~= "" and name or mob.name
                    mob.expansionName = expansionName
                    mob.instanceName = instanceName
                    mob.verify = not mob.name or not mob.level or not mob.drops or #mob.drops == 0
                end
            elseif Addon.dataToolSelectedBossID and Addon.db.bossCatalog then
                local boss = Addon.db.bossCatalog[tostring(Addon.dataToolSelectedBossID)]
                if boss then
                    boss.name = name ~= "" and name or boss.name
                    boss.expansionName = expansionName
                    boss.instanceName = instanceName
                    boss.verify = not boss.name or not boss.level or not boss.health or not boss.drops or #boss.drops == 0
                end
            end
            Print("Saved assignment.")
            Addon:RefreshDataToolsWindow()
        end)
        text("Pick Dungeon, Raid, Delve, or Open World above, then Save Assignment. Delve has no in-game catalog to pick from yet, so its location is a free-text name.", 22, -290, "GameFontHighlight", 860)
        local listFrame = remember(CreateFrame("Frame", nil, editor.content, "BackdropTemplate"))
        listFrame:SetPoint("TOPLEFT", 22, -334)
        listFrame:SetSize(860, 210)
        listFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        listFrame:SetBackdropColor(0.30, 0.30, 0.30, 0.95)
        listFrame:SetBackdropBorderColor(0.9, 0.10, 0.10, 0.95)
        local listText = remember(listFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        listText:SetPoint("TOPLEFT", 12, -10)
        listText:SetPoint("BOTTOMRIGHT", -12, 10)
        listText:SetJustifyH("LEFT")
        listText:SetJustifyV("TOP")
        listText:SetWordWrap(true)
        listText:SetText(self:GetUnassignedCatalogText())
        return
    end

    if mode == "instance" or mode == "expansion" then
        title(mode == "instance" and "Instance Menu" or "Expansion Menu", -20)
        dropdown("instanceMenu", "instanceButton", self.dataToolSelectedInstanceName or (run and run.instanceName) or "Select Instance", 22, -64, 360, self:GetDataToolInstanceOptions(), function(value)
            Addon:SelectDataToolInstance(value)
            Addon:RefreshDataToolsWindow()
        end)
        local expansionValue = self.dataToolSelectedExpansionName or (run and run.expansionName) or ""
        if mode == "expansion" then
            dropdown("expansionMenu", "expansionButton", expansionValue ~= "" and expansionValue or "Select Expansion", 406, -64, 260, self:GetDataToolExpansionOptions(), function(value)
                Addon.dataToolSelectedExpansionName = value
                Addon:RefreshDataToolsWindow()
            end)
        end
        local metadata = self.db and self.db.dungeonMetadata and run and self.db.dungeonMetadata[run.instanceName or ""]
        label("Instance name", 22, -118)
        autocompleteBox("instanceNameBox", 22, -136, 320, run and run.instanceName, function() return Addon:GetKnownInstanceNames() end)
        label("Expansion", 366, -118)
        autocompleteBox("expansionNameBox", 366, -136, 250, self.dataToolSelectedExpansionName or (metadata and metadata.expansionName) or (run and run.expansionName), function() return Addon:GetKnownExpansionNames() end)
        label("Guide ID (optional)", 640, -118)
        box("journalInstanceIDBox", 640, -136, 110, true, (metadata and metadata.journalInstanceID) or (run and run.journalInstanceID))
        button(nil, mode == "instance" and "Save Instance" or "Link Instance", 22, -188, 130, function()
            if editor.expansionNameBox and editor.expansionNameBox:GetText() ~= "" then
                Addon.dataToolSelectedExpansionName = editor.expansionNameBox:GetText()
            end
            Addon:SaveDataToolRunBasics()
            Addon:RefreshDataToolsWindow()
        end)
        button(nil, "Open Guide", 166, -188, 110, function()
            Addon:SaveDataToolRunBasics(true)
            Addon:OpenAdventureGuideForRun(run)
        end)
        text("Boss and mob contents have their own pages so the long lists are not crushed into one screen.", 22, -240, "GameFontHighlight", 860)
        return
    end

    if mode == "create" then
        title("Create a manual run", -20)
        text("Choose an instance, then add the run details.", 22, -46, "GameFontHighlightSmall", 500)

        -- The full Journal/season dungeon catalogue (same source All Runs and the dungeon browser
        -- already use), not just GetDataToolInstanceOptions' "dungeons you've already recorded a
        -- run for" -- per user request 2026-10-02 ("there will always be a dungeon list and new
        -- dungeons will be added when we do updates"). Computed once per refresh and reused by the
        -- instance field below and the art panel, rather than re-querying per keystroke.
        local dungeonCatalogue = self:GetLedgerDungeonCatalogue()

        -- Picking an instance now fills in Expansion and Guide ID too -- per user request
        -- ("the Expansion that should be filled in automatically... Guide ID should be filled in
        -- automatically as well"). A dungeon genuinely can't be in two expansions under the exact
        -- same catalogue name here (the catalogue is keyed by name, one expansion per key) -- if a
        -- real dungeon needs two separate entries for that (an old and a revamped version sharing a
        -- name), that's a catalogue-naming fix, not something guessable from here; flag any dungeon
        -- that picks the wrong expansion so the catalogue entry can be split and named to match.
        local function applyDungeonCatalogueSelection(name)
            Addon.dataToolSelectedInstanceName = name
            local entry = dungeonCatalogue[name]
            Addon.dataToolSelectedJournalInstanceID = entry and entry.journalInstanceID or nil
            if entry then Addon.dataToolSelectedExpansionName = entry.expansion end
            Addon:RefreshDataToolsWindow()
        end

        label("Instance name", 22, -64)
        -- Combines the old free-text box and the separate "Pick Existing Instance..." dropdown
        -- button into one field -- per user request 2026-10-02 ("combine the two bars for instance
        -- and choose existing"). showAllWhenEmpty=true means clicking in with nothing typed yet
        -- shows the first 12 dungeons immediately, the same list typing narrows further.
        autocompleteBox("instanceNameBox", 22, -82, 500, self.dataToolSelectedInstanceName or "", function()
            local names = {}
            for name, entry in pairs(dungeonCatalogue) do
                local expansion = Addon.dataToolSelectedExpansionName
                if not expansion or expansion == "" or entry.expansion == expansion then table.insert(names, name) end
            end
            table.sort(names, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
            return names
        end, applyDungeonCatalogueSelection, function(typedText)
            Addon.dataToolSelectedInstanceName = typedText
            local entry = dungeonCatalogue[typedText]
            Addon.dataToolSelectedJournalInstanceID = entry and entry.journalInstanceID or nil
        end, true)

        label("Difficulty", 22, -130)
        local bucket = self.dataToolSelectedDifficulty or "normal"
        local config = DIFFICULTY_BUCKETS[bucket] or DIFFICULTY_BUCKETS.normal
        dropdown("difficultyMenu", "difficultyButton", config.color .. config.label .. "|r", 22, -148, 200, self:GetDebugDifficultyOptions(), function(value)
            Addon.dataToolSelectedDifficulty = value
            Addon:RefreshDataToolsWindow()
        end)
        ApplyButtonColor(editor.difficultyButton, config.backdrop)
        label("Key level", 240, -130)
        box("keyLevelBox", 240, -148, 80, true, bucket == "mythicPlus" and 2 or "")
        if bucket ~= "mythicPlus" then
            editor.keyLevelBox:Hide()
        end

        label("Expansion", 22, -192)
        -- Auto-filled above on instance pick, but still a live autocomplete field -- not locked --
        -- so a dungeon the catalogue has no data for yet (or one genuinely needing a manual
        -- override) can still be set by hand.
        autocompleteBox("expansionNameBox", 22, -210, 300, self.dataToolSelectedExpansionName or "", function() return Addon:GetKnownExpansionNames() end, function(value)
            Addon.dataToolSelectedExpansionName = value
            local entry = dungeonCatalogue[Addon.dataToolSelectedInstanceName or ""]
            if entry and entry.expansion ~= value then
                Addon.dataToolSelectedInstanceName = nil
                Addon.dataToolSelectedJournalInstanceID = nil
            end
            Addon:RefreshDataToolsWindow()
        end, function(typedText)
            Addon.dataToolSelectedExpansionName = typedText
        end, true)
        label("Guide ID (optional)", 340, -192)
        box("journalInstanceIDBox", 340, -210, 140, true, self.dataToolSelectedJournalInstanceID)
        -- Plain box(), not autocompleteBox() (an ID isn't meaningfully text-searchable), so it has
        -- no built-in onTextChanged sync -- without this, picking Difficulty (which also calls
        -- RefreshDataToolsWindow) would rebuild this box from the last catalogue-selected value and
        -- silently discard a Guide ID the user had just hand-typed over it but not yet submitted,
        -- same bug class autocompleteBox's own onTextChanged exists to prevent.
        editor.journalInstanceIDBox:HookScript("OnTextChanged", function(self)
            Addon.dataToolSelectedJournalInstanceID = tonumber(self:GetText() or "")
        end)

        button(nil, "Cancel", 22, -262, 100, function()
            Addon.dataToolSelectedInstanceName = nil
            Addon.dataToolSelectedExpansionName = nil
            Addon.dataToolSelectedJournalInstanceID = nil
            Addon.dataToolMode = "run"
            Addon:RefreshDataToolsWindow()
        end)
        button("createRunButton", "Create Run", 132, -262, 140, function()
            Addon:CreateDebugRunFromDataTools()
            Addon.dataToolSelectedInstanceName = nil
            Addon.dataToolSelectedExpansionName = nil
            Addon.dataToolSelectedJournalInstanceID = nil
            Addon.dataToolMode = "run"
            Addon:RefreshDataToolsWindow()
        end)
        text("Manual entries remain separate from Blizzard score and vault data. Add timing and party details after creating the run.", 22, -312, "GameFontHighlight", 500)

        -- No art panel built here -- UI/MockupLayouts.lua's dataLayout() already draws the art box
        -- for "create" mode (the two-panel layout from the approved mockup) and resizes/repositions
        -- every field above to fit it; see that file for the dynamic per-dungeon art/name/
        -- description wiring (added alongside this to replace its old fixed placeholder image).
        return
    end

    if mode == "run" then
        addRunFilters(-64)
        addRunSelector(-104)
    else
        addRunSelector(-64)
    end
    if not run then
        title("Select a run first", -20)
        return
    end

    if mode == "run" then
        title("Edit Run", -20)
        text(self:GetDebugRunDetails(run), 22, -144, "GameFontHighlight", 860)
        label("Instance name", 22, -244)
        autocompleteBox("instanceNameBox", 22, -262, 320, run.instanceName, function() return Addon:GetKnownInstanceNames() end)
        label("Difficulty", 366, -244)
        local bucket = self.dataToolSelectedDifficulty or self:GetDifficultyBucket(run)
        local config = DIFFICULTY_BUCKETS[bucket] or DIFFICULTY_BUCKETS.normal
        dropdown("difficultyMenu", "difficultyButton", config.color .. config.label .. "|r", 366, -262, 150, self:GetDebugDifficultyOptions(), function(value)
            Addon.dataToolSelectedDifficulty = value
            Addon:RefreshDataToolsWindow()
        end)
        ApplyButtonColor(editor.difficultyButton, config.backdrop)
        label("M+ key", 540, -244)
        box("keyLevelBox", 540, -262, 56, true, bucket == "mythicPlus" and (self:GetRunKeyLevel(run) > 0 and self:GetRunKeyLevel(run) or 2) or "")
        if bucket ~= "mythicPlus" then
            editor.keyLevelBox:Hide()
        end
        label("Expansion", 22, -306)
        autocompleteBox("expansionNameBox", 22, -324, 260, run.expansionName, function() return Addon:GetKnownExpansionNames() end)
        label("Guide ID (optional)", 306, -306)
        box("journalInstanceIDBox", 306, -324, 110, true, run.journalInstanceID)
        local currentDuration = GetRunDuration(run)
        label("Run Time", 440, -306)
        box("runTimeMinutesBox", 440, -324, 52, true, math.floor(currentDuration / 60))
        label("min", 496, -328)
        box("runTimeSecondsBox", 532, -324, 52, true, currentDuration % 60)
        label("sec", 588, -328)
        -- Labeled "Timed" not "Completed" -- per user request 2026-10-02 ("maybe changed the name
        -- Completed to Timed? thoughts on this") -- matches Blizzard's own Mythic+ terminology (a
        -- key is "Timed" or it isn't) and reads less ambiguous sitting right next to "Overtime",
        -- which is also technically a completion. The underlying status VALUE stays "Completed"
        -- (SetRunStatusDebug, STATUS_BACKDROP_COLORS, saved run data) -- only this button's label
        -- changed, to avoid a data migration for something that's purely a display question.
        button(nil, "Timed", 22, -380, 110, function() Addon.debugSelectedRunID = run.id; Addon:SetRunStatusDebug("Completed"); Addon:RefreshDataToolsWindow() end, STATUS_BACKDROP_COLORS.Completed)
        button(nil, "Overtime", 146, -380, 100, function() Addon.debugSelectedRunID = run.id; Addon:SetRunStatusDebug("CompletedOvertime"); Addon:RefreshDataToolsWindow() end, STATUS_BACKDROP_COLORS.CompletedOvertime)
        button(nil, "Abandoned", 260, -380, 100, function() Addon.debugSelectedRunID = run.id; Addon:SetRunStatusDebug("Abandoned"); Addon:RefreshDataToolsWindow() end, STATUS_BACKDROP_COLORS.Abandoned)
        button(nil, "Active", 374, -380, 90, function() Addon.debugSelectedRunID = run.id; Addon:SetRunStatusDebug("Active"); Addon:RefreshDataToolsWindow() end, STATUS_BACKDROP_COLORS.Active)
        button(nil, "Save Run", 22, -432, 110, function() Addon:SaveDataToolRunBasics(); Addon:RefreshDataToolsWindow() end)
        button(nil, "Run Editor", 146, -432, 110, function() Addon:ToggleDebugEditorWindow(run) end)
        button(nil, "Delete Run", 270, -432, 110, function()
            Addon:DeleteRun(run, "manual delete")
            Addon:RefreshDataToolsWindow()
        end, STATUS_BACKDROP_COLORS.Abandoned)

        label("Add player: choose a saved player, or enter name and realm", 22, -472)
        -- "Known Player" lists everyone already saved in playerRatings (a cheap, fixed-size read,
        -- not a run-history scan) minus anyone already on this run's roster, so picking a name just
        -- fills the box below. If nobody's saved yet, this only ever offers "Manual Entry" -- the
        -- name box is always there regardless, for someone not saved/logged yet.
        local knownPlayerOptions = { { text = "Manual Entry", value = "" } }
        do
            local candidateNames, seenName = {}, {}
            for _, savedProfile in pairs(self.db.playerRatings or {}) do
                local candidateName = savedProfile.name
                if candidateName and candidateName ~= "" and not seenName[candidateName] then
                    local alreadyOnRun = false
                    for _, existingMember in ipairs(run.members or {}) do
                        if NormalizePlayerName(existingMember.name) == NormalizePlayerName(candidateName) then
                            alreadyOnRun = true
                            break
                        end
                    end
                    if not alreadyOnRun then
                        seenName[candidateName] = true
                        table.insert(candidateNames, candidateName)
                    end
                end
            end
            table.sort(candidateNames, function(a, b) return string.lower(a) < string.lower(b) end)
            for _, candidateName in ipairs(candidateNames) do
                table.insert(knownPlayerOptions, { text = candidateName, value = candidateName })
            end
        end
        -- Realm matters: the same name can exist on a different (connected) realm. Picking a
        -- Known Player fills both boxes from their saved profile; the realm box otherwise defaults
        -- to your own realm (the common case), editable for anyone typed in manually.
        dropdown("addPlayerKnownMenu", "addPlayerKnownButton", "Known: " .. ((self.dataToolAddPlayerName and self.dataToolAddPlayerName ~= "") and self.dataToolAddPlayerName or "Manual Entry"), 22, -490, 170, knownPlayerOptions, function(value)
            if value ~= "" then
                Addon.dataToolAddPlayerName = value
                for _, savedProfile in pairs(Addon.db.playerRatings or {}) do
                    if savedProfile.name == value then
                        Addon.dataToolAddPlayerRealm = savedProfile.realm
                        break
                    end
                end
            end
            Addon:RefreshDataToolsWindow()
        end)
        -- Re-anchor on its own button click too (browsing the full list), since the type-ahead
        -- handler below moves this same menu frame to sit under the name box while searching.
        if editor.addPlayerKnownButton and editor.addPlayerKnownMenu then
            local knownMenu, knownButton = editor.addPlayerKnownMenu, editor.addPlayerKnownButton
            knownButton:SetScript("OnClick", function()
                if knownMenu:IsShown() then
                    knownMenu:Hide()
                else
                    if editor.HideMenus then
                        editor:HideMenus()
                    end
                    knownMenu:ClearAllPoints()
                    knownMenu:SetPoint("TOPLEFT", knownButton, "BOTTOMLEFT", 0, -2)
                    knownMenu:Show()
                end
            end)
        end
        box("addPlayerNameBox", 202, -490, 130, false, self.dataToolAddPlayerName or "")
        if editor.addPlayerNameBox then
            -- Type-ahead search: typing here filters the Known Player list down to substring
            -- matches and pops it open under that button, instead of only being browsable via a
            -- full static list -- per user request 2026-09-05 ("can I context search the player").
            editor.addPlayerNameBox:SetScript("OnTextChanged", function(editBox)
                Addon.dataToolAddPlayerName = editBox:GetText()
                local query = strtrim(editBox:GetText() or ""):lower()
                if query == "" or not editor.addPlayerKnownMenu then
                    if editor.addPlayerKnownMenu then
                        editor.addPlayerKnownMenu:Hide()
                    end
                    return
                end
                local filtered = {}
                for _, option in ipairs(knownPlayerOptions) do
                    if option.value ~= "" and tostring(option.text):lower():find(query, 1, true) then
                        table.insert(filtered, option)
                    end
                end
                if #filtered > 0 then
                    if editor.HideMenus then
                        editor:HideMenus()
                    end
                    Addon:RefreshSimpleDropdown(editor.addPlayerKnownMenu, filtered, function(value)
                        Addon.dataToolAddPlayerName = value
                        for _, savedProfile in pairs(Addon.db.playerRatings or {}) do
                            if savedProfile.name == value then
                                Addon.dataToolAddPlayerRealm = savedProfile.realm
                                break
                            end
                        end
                        Addon:RefreshDataToolsWindow()
                    end)
                    -- Anchor under the name box being typed in, not the Known Player button --
                    -- restored to its normal spot by the button's own OnClick handler above.
                    editor.addPlayerKnownMenu:ClearAllPoints()
                    editor.addPlayerKnownMenu:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -2)
                    editor.addPlayerKnownMenu:Show()
                else
                    editor.addPlayerKnownMenu:Hide()
                end
            end)
        end
        box("addPlayerRealmBox", 342, -490, 110, false, self.dataToolAddPlayerRealm or (GetRealmName and GetRealmName() or ""))
        if editor.addPlayerRealmBox then
            editor.addPlayerRealmBox:SetScript("OnTextChanged", function(editBox)
                Addon.dataToolAddPlayerRealm = editBox:GetText()
            end)
        end
        local addClassOptions = { { text = "Unknown Class", value = "" } }
        for className in pairs(CLASS_COLORS) do
            table.insert(addClassOptions, { text = CLASS_COLORS[className] .. ClassDisplayName(className) .. "|r", value = className, backdrop = CLASS_BACKDROP_COLORS[className] })
        end
        table.sort(addClassOptions, function(a, b) return tostring(a.value) < tostring(b.value) end)
        local addClassValue = self.dataToolAddPlayerClass
        dropdown("addPlayerClassMenu", "addPlayerClassButton", addClassValue and addClassValue ~= "" and ((CLASS_COLORS[addClassValue] or "|cffffffff") .. ClassDisplayName(addClassValue) .. "|r") or "Select Class", 462, -490, 130, addClassOptions, function(value)
            Addon.dataToolAddPlayerClass = value
            Addon:RefreshDataToolsWindow()
        end)
        local addRoleOptions = {
            { text = "Tank", value = "TANK" },
            { text = "Heals", value = "HEALER" },
            { text = "DPS", value = "DAMAGER" },
            { text = "None", value = "NONE" },
        }
        dropdown("addPlayerRoleMenu", "addPlayerRoleButton", GetRoleLabel(self.dataToolAddPlayerRole or "NONE"), 602, -490, 90, addRoleOptions, function(value)
            Addon.dataToolAddPlayerRole = value
            Addon:RefreshDataToolsWindow()
        end)
        button(nil, "Add Player", 702, -490, 110, function()
            Addon:AddDataToolRunMember()
            Addon:RefreshDataToolsWindow()
        end)
        return
    end

    if mode == "boss" then
        title("Boss Menu", -20)
        local bossOptions = self:GetDebugBossOptions(run)
        if #bossOptions == 0 then
            text(string.format("%s has no bosses mapped yet -- enter a Boss ID and name below, then Save Boss.", run and run.instanceName or "This dungeon"), 22, -92, "GameFontHighlight", 860)
        end
        if #bossOptions > 0 and not self.dataToolSelectedBossID then
            self.dataToolSelectedBossID = bossOptions[1].value
        end
        local bossLine = "Select Boss"
        for _, option in ipairs(bossOptions) do
            if tonumber(option.value) == tonumber(self.dataToolSelectedBossID) then
                bossLine = option.text
                break
            end
        end
        dropdown("bossMenu", "bossButton", bossLine, 22, -118, 520, bossOptions, function(value)
            Addon.dataToolSelectedBossID = value
            Addon:RefreshDataToolsWindow()
        end)
        local bossID = self.dataToolSelectedBossID
        label("Boss ID", 22, -164)
        box("bossIDBox", 22, -182, 90, true, bossID)
        label("Boss name", 136, -164)
        autocompleteBox("bossNameBox", 136, -182, 380, bossID and self:GetBossName(run, bossID) or "", function() return Addon:GetKnownBossNames() end)
        local selectedOrder = ""
        for index, id in ipairs(self:GetOrderedBossIDs(run)) do
            if tonumber(id) == tonumber(bossID) then
                selectedOrder = tostring(index)
            end
        end
        label("Order", 540, -164)
        box("bossOrderBox", 540, -182, 52, true, selectedOrder)
        local bossInfo = self:GetDungeonBossInfo(run)
        check("bossOptionalCheck", "Optional boss", 22, -226, self:IsBossOptional(run, bossID))
        check("bossFinalCheck", "Final boss", 180, -226, bossInfo and bossID and (bossInfo.final[bossID] or bossInfo.final[self:GetBossName(run, bossID)]))

        -- Kill timing for THIS run's actual kill of the selected boss, if it happened -- per user
        -- request 2026-09-05: pull time (trash/travel since the previous boss died) is only split
        -- out from fight time for encounters tracked live since ENCOUNTER_START tracking shipped;
        -- older kills and manual debug-menu entries only have the lumped total.
        if bossID and run then
            local matchedSegment = nil
            for _, segment in ipairs(self:GetBossSegmentTimings(run)) do
                if tonumber(segment.bossID) == tonumber(bossID) then
                    matchedSegment = segment
                end
            end
            if matchedSegment then
                local timingText
                if matchedSegment.pullSeconds and matchedSegment.fightSeconds then
                    timingText = string.format("Pull: %s  |  Fight: %s  |  Killed at %s into the run", FormatDuration(matchedSegment.pullSeconds), FormatDuration(matchedSegment.fightSeconds), FormatDuration(matchedSegment.cumulativeSeconds))
                else
                    timingText = string.format("Time since previous boss: %s  |  Killed at %s into the run", FormatDuration(matchedSegment.segmentSeconds), FormatDuration(matchedSegment.cumulativeSeconds))
                end
                text(timingText, 22, -256, "GameFontHighlight", 860)
            end
        end

        local bossCatalogEntry = bossID and self.db.bossCatalog and self.db.bossCatalog[tostring(bossID)]
        label("Level", 22, -294)
        box("bossLevelBox", 22, -312, 70, true, bossCatalogEntry and bossCatalogEntry.level or "")
        label("Max Health", 106, -294)
        box("bossHealthBox", 106, -312, 130, true, bossCatalogEntry and bossCatalogEntry.health or "")
        label("Drops (comma-separated item names)", 250, -294)
        box("bossDropsBox", 250, -312, 410, false, bossCatalogEntry and bossCatalogEntry.drops and table.concat(bossCatalogEntry.drops, ", ") or "")
        if bossCatalogEntry and bossCatalogEntry.verify then
            text("|cffffff00Verify|r -- missing level, health, or drops. Level/health auto-fill next time this boss is killed; drops need to be entered here.", 22, -344, "GameFontHighlight", 860)
        end

        button(nil, "Save Boss", 22, -386, 110, function() Addon:SaveDataToolBoss(); Addon:RefreshDataToolsWindow() end)
        return
    end

    if mode == "mob" then
        title("Mob Menu", -20)
        local mobOptions = self:GetDataToolMobOptions(run)
        if #mobOptions > 0 and not self.dataToolSelectedMobID then
            self.dataToolSelectedMobID = mobOptions[1].value
        end
        dropdown("mobMenu", "mobButton", self.dataToolSelectedMobID and ("Mob " .. tostring(self.dataToolSelectedMobID)) or "Select Recorded Mob", 22, -118, 360, mobOptions, function(value)
            Addon.dataToolSelectedMobID = value
            Addon:RefreshDataToolsWindow()
        end)
        local mobInfo = run and run.mobKills and self.dataToolSelectedMobID and run.mobKills[self.dataToolSelectedMobID]
        label("Mob ID", 22, -164)
        box("mobIDBox", 22, -182, 110, true, self.dataToolSelectedMobID)
        label("Mob name", 156, -164)
        autocompleteBox("mobNameBox", 156, -182, 360, (self.db.mobNameOverrides and self.dataToolSelectedMobID and self.db.mobNameOverrides[self.dataToolSelectedMobID]) or (mobInfo and mobInfo.name), function() return Addon:GetKnownMobNames() end)
        button(nil, "Save Mob", 22, -234, 110, function() Addon:SaveDataToolMob(); Addon:RefreshDataToolsWindow() end)
        text("Recorded mobs without a known name can be selected here once the run has seen their ID.", 22, -286, "GameFontHighlight", 860)
        return
    end
end

function Addon:RefreshDebugEditPanel()
    if self.dataTools and self.dataTools:IsShown() then
        self:RefreshDataToolsWindow()
    end

    if self.debugEditor and self.debugEditor:IsShown() then
        self:RefreshDebugEditorWindow()
    end

    local panel = self.window and self.window.debugEditPanel
    if not panel then
        return
    end

    local run = self:GetDebugSelectedRun()
    if run then
        panel.label:SetText(string.format(
            "Editing: %s | %s | %s",
            self:GetRunCode(run) or tostring(run.id or "?"),
            run.instanceName or "Unknown run",
            self:GetRunDisplayStatus(run)
        ))
        panel.detail:SetText(self:GetDebugRunDetails(run))
    else
        panel.label:SetText("Editing: no run selected")
        panel.detail:SetText("Select a run to edit.")
    end
    panel:Show()
end

function Addon:HandleDataToolsEscape()
    local editor = self.dataTools
    if not editor or not editor:IsShown() then
        return false
    end

    for _, menu in pairs(editor.menus or {}) do
        if menu and menu:IsShown() then
            menu:Hide()
            return true
        end
    end

    for _, key in ipairs({ "runMenu", "difficultyMenu", "bossMenu", "mobMenu", "playerMenu", "instanceMenu", "expansionMenu", "seasonMenu", "manualInstanceMenu", "playerClassMenu", "playerRoleMenu", "playerRatingMenu", "runExpansionFilterMenu", "runInstanceFilterMenu" }) do
        if editor[key] and editor[key]:IsShown() then
            editor[key]:Hide()
            return true
        end
    end

    -- ESC with no open dropdown left to close exits the addon completely, not just this window --
    -- see Addon:CloseAllWindows for the full reasoning.
    self:CloseAllWindows()
    return true
end

function Addon:HandleDebugEditorEscape()
    local editor = self.debugEditor
    if not editor or not editor:IsShown() then
        return false
    end

    if editor.playerMenu and editor.playerMenu:IsShown() then
        editor.playerMenu:Hide()
        return true
    end
    if editor.bossMenu and editor.bossMenu:IsShown() then
        editor.bossMenu:Hide()
        return true
    end
    if editor.difficultyMenu and editor.difficultyMenu:IsShown() then
        editor.difficultyMenu:Hide()
        return true
    end

    self:CloseAllWindows()
    return true
end

function Addon:HandleMainWindowEscape()
    if self:HandleDataToolsEscape() then
        return
    end

    if self:HandleDebugEditorEscape() then
        return
    end

    if self.selectedDungeonName then
        self:ClearSelectedDungeon()
    else
        self:CloseAllWindows()
    end
end

function Addon:CreateWindow()
    if self:IsUiLocked() then
        self:MarkUiDirty()
        return
    end

    if self.window then
        return
    end

    local frame = CreateFrame("Frame", "MPlusLedgerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(MainLayoutConst.WINDOW_WIDTH, MainLayoutConst.WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(200)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    -- Every other window (Mob Browser, Manage Data, Stats hub) sets this solid black -- the main
    -- window, the most-used surface in the addon, never did, leaving it visibly lighter/more
    -- transparent than everything else. Found during the UI consistency pass, 2026-09-01.
    frame:SetBackdropColor(0, 0, 0, 1.00)
    frame:Hide()
    -- Mirrors CreateStatsHubWindow's own OnShow/OnHide pair (see that function's comments) -- per
    -- user request 2026-09-30, M+ Summary (Stats Hub) is now the addon's main screen and this
    -- window is the secondary "view all runs" drill-down, reachable from it via a button. Closing
    -- this window returns to Stats Hub the same way closing Stats Hub already returns here.
    frame:SetScript("OnShow", function()
        if Addon.statsHubWindow then
            Addon.statsHubWindow:Hide()
        end
    end)
    frame:SetScript("OnHide", function()
        if Addon.ledgerSwitchingWindows then return end
        local returnTo = frame.returnToStatsHub
        frame.returnToStatsHub = nil
        if returnTo then
            returnTo:Show()
        end
    end)
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 1 then
            self.elapsed = 0
            if Addon:GetCurrentRun() then
                Addon:RefreshAllDisplays()
            end
        end
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        Addon:ScrollList(delta > 0 and -1 or 1)
    end)
    EnableEscHandler(frame, function()
        Addon:HandleMainWindowEscape()
    end)
    frame.listOffset = 0
    frame.currentListTotal = 0

    -- Circular-masked portrait icon + gold ring, matching the Stats hub's treatment (the same
    -- Texture:SetMask trick Blizzard's own portrait frames use) -- was a plain square icon before.
    local emblemRing = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    emblemRing:SetSize(64, 64)
    emblemRing:SetPoint("TOPLEFT", 15, -14)
    emblemRing:SetColorTexture(self:GetThemeBorderColor(true, 0.9))
    frame.emblemRing = emblemRing

    local emblem = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    emblem:SetSize(58, 58)
    emblem:SetPoint("CENTER", emblemRing, "CENTER", 0, 0)
    emblem:SetTexture("Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider")
    emblem:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    frame.emblem = emblem

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -22)
    title:SetText("M+ Ledger")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
    subtitle:SetText("Recent dungeon status, deaths, gold looted, and repair costs")

    local close = self:CreatePlainButton(frame, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -18, -18)
    close:SetScript("OnClick", function()
        Addon:ReturnToMainMenu()
    end)

    local repair = self:CreatePlainButton(frame, "Record Repair", 130, 24)
    repair:SetSize(130, 24)
    repair:SetPoint("TOPLEFT", 96, -62)
    repair:SetText("Record Repair")
    repair:SetScript("OnClick", function()
        Addon:ManualRecordRepair()
    end)

    local endRun = self:CreatePlainButton(frame, "End Run", 100, 24)
    endRun:SetSize(100, 24)
    endRun:SetPoint("LEFT", repair, "RIGHT", 10, 0)
    endRun:SetText("End Run")
    endRun:SetScript("OnClick", function()
        Addon:EndRun("manual")
    end)
    endRun:Hide()

    local status = self:CreatePlainButton(frame, "Status", 100, 24)
    status:SetSize(100, 24)
    status:SetPoint("LEFT", repair, "RIGHT", 10, 0)
    status:SetText("Status")
    status:SetScript("OnClick", function()
        Addon:PrintStatus()
    end)


    local share = self:CreatePlainButton(frame, "Share", 100, 24)
    share:SetSize(100, 24)
    share:SetPoint("LEFT", status, "RIGHT", 10, 0)
    share:SetText("Share")
    share:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    share:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            Addon:ShareRunToGroup(Addon.selectedRunForShare)
        else
            Addon:ShareRun(Addon.selectedRunForShare)
        end
    end)
    frame.shareButton = share

    local dataTools = self:CreatePlainButton(frame, "Manage Data", 110, 24)
    dataTools:SetPoint("LEFT", share, "RIGHT", 10, 0)
    dataTools:SetScript("OnClick", function()
        Addon:ToggleDataToolsWindow()
    end)
    dataTools:Hide()
    frame.dataToolsButton = dataTools

    -- Mob/Boss Browser button removed 2026-09-05 per user request ("The Mob / boss Browser can
    -- also go") -- its underlying window/toggle functions are left in place but unreachable from
    -- the UI now, same treatment as the Data Tools tabs removed alongside it.

    -- Season Overview, Progress, M+ Stats, and Trends all live in one tabbed "Stats & Progress"
    -- window now -- a single button opens it, rather than one button per tab.
    local statsHub = self:CreatePlainButton(frame, "Stats & Progress", 150, 24)
    statsHub:SetPoint("LEFT", dataTools, "RIGHT", 10, 0)
    statsHub:SetScript("OnClick", function()
        Addon:ToggleStatsHubWindow()
    end)
    frame.statsHubButton = statsHub

    -- New 2026-09-05 per user request: a dedicated, obvious entry point for adding a brand new
    -- player's reputation (name/race/faction/class/role/realm/rating/note), rather than only the
    -- implicit "type a new name in the Player tab" flow.
    local addPlayer = self:CreatePlainButton(frame, "Add Player", 130, 24)
    addPlayer:SetPoint("LEFT", statsHub, "RIGHT", 10, 0)
    addPlayer:SetScript("OnClick", function()
        Addon:OpenAddPlayerForm()
    end)
    frame.addPlayerButton = addPlayer

    local summary = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    summary:SetSize(MainLayoutConst.PANEL_WIDTH, 166)
    summary:SetPoint("TOP", 0, -100)
    summary:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    summary:SetBackdropColor(0.05, 0.05, 0.05, 0.68)
    frame.summaryPanel = summary

    local summaryTitle = summary:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    summaryTitle:SetPoint("TOPLEFT", 14, -12)
    summaryTitle:SetPoint("RIGHT", -14, 0)
    summaryTitle:SetJustifyH("LEFT")
    frame.summaryTitle = summaryTitle

    local summaryStatus = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summaryStatus:SetPoint("TOPLEFT", summaryTitle, "BOTTOMLEFT", 0, -5)
    summaryStatus:SetPoint("RIGHT", -14, 0)
    summaryStatus:SetJustifyH("LEFT")
    frame.summaryStatus = summaryStatus

    local function createStatBox(label, x)
        local box = CreateFrame("Frame", nil, summary, "BackdropTemplate")
        box:SetSize(178, 34)
        box:SetPoint("BOTTOMLEFT", x, 10)
        box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        box:SetBackdropColor(0.12, 0.11, 0.09, 0.75)
        box.label = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        box.label:SetPoint("LEFT", 8, 0)
        box.label:SetText(label)
        box.value = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        box.value:SetPoint("RIGHT", -8, 0)
        box.value:SetJustifyH("RIGHT")
        return box
    end

    frame.playerDeathBox = createStatBox("Your Deaths", 14)
    frame.partyDeathBox = createStatBox("Party Deaths", 204)
    frame.repairBox = createStatBox("Your Repairs", 394)
    frame.runBox = createStatBox("Status", 584)
    frame.playerDeathBox:Hide()
    frame.partyDeathBox:Hide()
    frame.repairBox:Hide()
    frame.runBox:Hide()

    frame.difficultyCards = {}
    for index, key in ipairs(DIFFICULTY_BUCKET_ORDER) do
        local config = DIFFICULTY_BUCKETS[key]
        local column = index - 1
        local card = CreateFrame("Frame", nil, summary, "BackdropTemplate")
        card:SetSize(156, 82)
        card:SetPoint("TOPLEFT", 14 + (column * 162), -58)
        card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        card:SetBackdropColor(0.10, 0.09, 0.08, 0.72)
        card.label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.label:SetPoint("TOPLEFT", 8, -5)
        card.label:SetWidth(140)
        card.label:SetJustifyH("LEFT")
        card.label:SetText(config.color .. config.label .. "|r")
        card.label:Show()
        card.value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        card.value:SetPoint("TOPLEFT", card.label, "BOTTOMLEFT", 0, -1)
        card.value:SetPoint("RIGHT", -8, 0)
        card.value:SetJustifyH("LEFT")
        card.value:SetJustifyV("TOP")
        card.value:SetHeight(58)
        card.value:SetWordWrap(true)
        frame.difficultyCards[key] = card
    end

    local listTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", 40, -290)
    listTitle:SetText("Recent Dungeons")
    frame.listTitle = listTitle

    local viewButton = self:CreatePlainButton(frame, "Filter: Current Season", 170, 22)
    viewButton:SetPoint("TOPRIGHT", -308, -286)
    viewButton:SetScript("OnClick", function()
        if not Addon.window or not Addon.window.viewMenu then
            return
        end
        Addon:RefreshSimpleDropdown(Addon.window.viewMenu, Addon:GetMainViewOptions(), function(value)
            Addon.db.mainView = value or "currentSeason"
            if Addon.window then
                Addon.window.listOffset = 0
            end
            Addon:RefreshWindow()
        end)
        if Addon.window.viewMenu:IsShown() then
            Addon.window.viewMenu:Hide()
        else
            if Addon.window.sortMenu then
                Addon.window.sortMenu:Hide()
            end
            Addon.window.viewMenu:Show()
        end
    end)
    frame.viewButton = viewButton

    local sortButton = self:CreatePlainButton(frame, "Sort: Highest Key", 170, 22)
    sortButton:SetPoint("TOPRIGHT", -132, -286)
    sortButton:SetScript("OnClick", function()
        if not Addon.window or not Addon.window.sortMenu then
            return
        end
        Addon:RefreshSimpleDropdown(Addon.window.sortMenu, Addon:GetMainSortOptions(), function(value)
            Addon.db.mainSort = value or "recent"
            if Addon.window then
                Addon.window.listOffset = 0
            end
            Addon:RefreshWindow()
        end)
        if Addon.window.sortMenu:IsShown() then
            Addon.window.sortMenu:Hide()
        else
            if Addon.window.viewMenu then
                Addon.window.viewMenu:Hide()
            end
            Addon.window.sortMenu:Show()
        end
    end)
    frame.sortButton = sortButton

    local viewMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    viewMenu:SetSize(190, 30)
    viewMenu:SetPoint("TOPLEFT", viewButton, "BOTTOMLEFT", 0, -2)
    viewMenu:SetFrameLevel(frame:GetFrameLevel() + 20)
    viewMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    viewMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.94)
    viewMenu:EnableMouse(true)
    viewMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    viewMenu:Hide()
    frame.viewMenu = viewMenu

    local sortMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sortMenu:SetSize(190, 30)
    sortMenu:SetPoint("TOPLEFT", sortButton, "BOTTOMLEFT", 0, -2)
    sortMenu:SetFrameLevel(frame:GetFrameLevel() + 20)
    sortMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    sortMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.94)
    sortMenu:EnableMouse(true)
    sortMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    sortMenu:Hide()
    frame.sortMenu = sortMenu

    local progressButton = self:CreatePlainButton(frame, "Progress", 100, 22)
    progressButton:SetPoint("TOPRIGHT", -132, -286)
    progressButton:SetScript("OnClick", function()
        Addon:ToggleStatsHubWindow("progress", Addon.selectedDungeonName)
    end)
    progressButton:Hide()
    frame.progressButton = progressButton

    local back = self:CreatePlainButton(frame, "Back", 70, 22)
    back:SetPoint("TOPRIGHT", -52, -286)
    back:SetScript("OnClick", function()
        Addon:ClearSelectedDungeon()
    end)
    back:Hide()
    frame.backButton = back

    local scrollUp = self:CreatePlainButton(frame, "^", 24, 22)
    scrollUp:SetPoint("TOPRIGHT", -24, -286)
    scrollUp:SetScript("OnClick", function()
        Addon:ScrollList(-1)
    end)
    scrollUp:Hide()
    frame.scrollUpButton = scrollUp

    local scrollDown = self:CreatePlainButton(frame, "v", 24, 22)
    scrollDown:SetPoint("BOTTOMRIGHT", -24, 34)
    scrollDown:SetScript("OnClick", function()
        Addon:ScrollList(1)
    end)
    scrollDown:Hide()
    frame.scrollDownButton = scrollDown

    frame.rows = {}
    for index = 1, MainLayoutConst.MAIN_VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        row:SetSize(MainLayoutConst.ROW_WIDTH, 42)
        row:SetPoint("TOP", -20, -292 - ((index - 1) * 44))
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        row:SetBackdropColor(0.08, 0.08, 0.08, index % 2 == 0 and 0.52 or 0.72)
        row:EnableMouse(true)
        row:SetScript("OnMouseUp", function(self)
            if self.runID then
                Addon.selectedRunForShare = Addon:GetRun(self.runID)
            elseif self.dungeonName then
                local runs = Addon:GetRunsForDungeon(self.dungeonName, 1)
                if runs and runs[1] then
                    Addon.debugSelectedRunID = runs[1].id
                    Addon.selectedRunForShare = runs[1]
                end
                Addon:SelectDungeon(self.dungeonName)
            end
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            Addon:ScrollList(delta > 0 and -1 or 1)
        end)
        -- Expansion/season/current-pool detail on hover, dungeon cards only (self.cardSummary is
        -- only ever set in that render path, not the individual-run detail view) -- see
        -- GetDungeonCardTooltipLines for why this moved off the card's visible title text.
        row:SetScript("OnEnter", function(self)
            local lines = self.cardSummary and Addon:GetDungeonCardTooltipLines(self.cardSummary)
            if not lines then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(self.dungeonName or "")
            for _, line in ipairs(lines) do
                GameTooltip:AddLine(line[1], line[2], line[3], line[4])
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(54, 54)
        row.icon:SetPoint("TOPLEFT", 9, -6)
        row.icon:SetTexture("Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider")
        row.icon:SetTexCoord(0.16, 0.84, 0.16, 0.84)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, 0)
        row.name:SetWidth(270)
        row.name:SetJustifyH("LEFT")
        row.name:SetHeight(18)
        row.name:SetWordWrap(false)

        row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.status:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.status:SetWidth(270)
        row.status:SetJustifyH("LEFT")
        row.status:SetJustifyV("TOP")
        row.status:SetHeight(44)
        row.status:SetWordWrap(true)

        row.playerDeaths = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.playerDeaths:SetPoint("LEFT", 410, 0)
        row.playerDeaths:SetWidth(100)
        row.playerDeaths:SetJustifyH("LEFT")

        row.partyDeaths = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.partyDeaths:SetPoint("LEFT", 530, 0)
        row.partyDeaths:SetWidth(112)
        row.partyDeaths:SetJustifyH("LEFT")

        row.repairs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.repairs:SetPoint("LEFT", 660, 0)
        row.repairs:SetWidth(190)
        row.repairs:SetJustifyH("LEFT")

        row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.detail:SetPoint("LEFT", 410, 0)
        row.detail:SetWidth(380)
        row.detail:SetJustifyH("LEFT")
        row.detail:SetWordWrap(false)
        row.detail:Hide()

        row.roleHeaders = {}
        row.roleColumns = {}
        local roleConfig = {
            { key = "dps", label = "DPS", x = 315, width = 185 },
            { key = "tank", label = "TANK", x = 508, width = 150 },
            { key = "heals", label = "HEALS", x = 666, width = 145 },
        }
        for _, config in ipairs(roleConfig) do
            local header = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetPoint("TOPLEFT", config.x, -8)
            header:SetWidth(config.width)
            header:SetJustifyH("LEFT")
            header:SetText(config.label)
            header:Hide()
            row.roleHeaders[config.key] = header

            local column = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            column:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
            column:SetWidth(config.width)
            column:SetHeight(80)
            column:SetJustifyH("LEFT")
            column:SetJustifyV("TOP")
            column:SetWordWrap(true)
            column:Hide()
            row.roleColumns[config.key] = column
        end

        row.skull = row:CreateTexture(nil, "ARTWORK")
        row.skull:SetSize(24, 24)
        row.skull:SetPoint("RIGHT", -12, 0)
        row.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        row.skull:Hide()

        row.runCode = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.runCode:SetPoint("BOTTOMRIGHT", -12, 8)
        row.runCode:SetWidth(130)
        row.runCode:SetJustifyH("RIGHT")
        row.runCode:SetWordWrap(false)
        row.runCode:Hide()

        row.shareButton = self:CreatePlainButton(row, "Share", 58, 20)
        row.shareButton:SetPoint("BOTTOMRIGHT", row.runCode, "TOPRIGHT", 0, 4)
        row.shareButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.shareButton:SetScript("OnClick", function(self, mouseButton)
            local run = Addon:GetRun(self:GetParent().runID)
            if not run then
                Print("No run found for this share button.")
                return
            end
            Addon.selectedRunForShare = run
            if mouseButton == "RightButton" then
                Addon:ShareRunToGroup(run)
            else
                Addon:ShareRun(run)
            end
        end)
        row.shareButton:Hide()

        row.editButton = self:CreatePlainButton(row, "Edit", 58, 20)
        row.editButton:SetPoint("RIGHT", row.shareButton, "LEFT", -8, 0)
        row.editButton:SetScript("OnClick", function(self)
            local run = Addon:GetRun(self:GetParent().runID)
            if not run then
                Print("No run found for this edit button.")
                return
            end
            Addon:OpenDataToolsMenu("run", run)
        end)
        row.editButton:Hide()

        row.guideButton = self:CreatePlainButton(row, "Guide", 58, 20)
        row.guideButton:SetPoint("RIGHT", row.editButton, "LEFT", -8, 0)
        row.guideButton:SetScript("OnClick", function(self)
            local run = Addon:GetRun(self:GetParent().runID)
            Addon:OpenAdventureGuideForRun(run)
        end)
        row.guideButton:Hide()

        row.statusRibbon = CreateFrame("Frame", nil, row, "BackdropTemplate")
        row.statusRibbon:SetSize(98, 18)
        row.statusRibbon:SetPoint("TOPLEFT", row.status, "BOTTOMLEFT", 0, -2)
        row.statusRibbon:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        row.statusRibbon:SetBackdropBorderColor(self:GetThemeBorderColor(true, 0.9))
        row.statusRibbon.completedFill = row.statusRibbon:CreateTexture(nil, "ARTWORK")
        row.statusRibbon.completedFill:SetPoint("LEFT", 1, 0)
        row.statusRibbon.completedFill:SetHeight(10)
        row.statusRibbon.completedFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.statusRibbon.completedFill:SetVertexColor(0.02, 0.72, 0.12, 0.88)
        row.statusRibbon.failedFill = row.statusRibbon:CreateTexture(nil, "ARTWORK")
        row.statusRibbon.failedFill:SetPoint("RIGHT", -1, 0)
        row.statusRibbon.failedFill:SetHeight(10)
        row.statusRibbon.failedFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.statusRibbon.failedFill:SetVertexColor(0.78, 0.05, 0.05, 0.88)
        row.statusRibbon.text = row.statusRibbon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.statusRibbon.text:SetPoint("CENTER")
        row.statusRibbon:Hide()

        frame.rows[index] = row
    end

    self.window = frame
end

function Addon:CreateTrackerBar()
    if self:IsUiLocked() then
        self:MarkUiDirty()
        return
    end

    if self.trackerBar then
        return
    end

    local tracker = self.db and self.db.tracker or DEFAULTS.tracker
    local bar = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    bar:SetSize(tonumber(tracker.width) or 650, tonumber(tracker.height) or 132)
    bar:SetScale(tonumber(tracker.scale) or 1)
    bar:SetPoint(tracker.point or "TOP", UIParent, tracker.relativePoint or "TOP", tracker.x or 0, tracker.y or -120)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(5)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    bar:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        Addon.db.tracker.point = point
        Addon.db.tracker.relativePoint = relativePoint
        Addon.db.tracker.x = math.floor(x or 0)
        Addon.db.tracker.y = math.floor(y or 0)
    end)
    bar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    bar:SetBackdropColor(0, 0, 0, 0.72)
    bar.elapsed = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 1 then
            self.elapsed = 0
            if Addon:GetCurrentRun() then
                Addon:RefreshTrackerBar()
            end
        end
    end)
    bar:Hide()

    -- Player-resizable, not just the scale slider added earlier -- user clarified 2026-09-10
    -- ("when i mean resize, i mean player resizeable"). SetResizeBounds is the modern (10.0.0+)
    -- replacement for SetMinResize/SetMaxResize (both still work, but this is the one Blizzard
    -- itself now recommends). The title/meta/deaths/interrupts elements below all anchor with a
    -- "RIGHT" point (not a fixed width), so they already stretch to fill whatever width the user
    -- drags to -- height's minimum bound just keeps the frame from shrinking below its content
    -- (title through interrupts, bottom edge ~98px down). Lowered from 120 to 100 (2026-09-16)
    -- when the Enemy Forces bar below `interrupts` was removed -- that used to be the tallest
    -- element and set the old floor.
    bar:SetResizable(true)
    if bar.SetResizeBounds then
        bar:SetResizeBounds(480, 100, 1100, 320)
    end

    local resizer = CreateFrame("Button", nil, bar)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetScript("OnMouseDown", function(self)
        self:GetParent():StartSizing("BOTTOMRIGHT")
    end)
    resizer:SetScript("OnMouseUp", function(self)
        local frame = self:GetParent()
        frame:StopMovingOrSizing()
        Addon.db.tracker.width = math.floor(frame:GetWidth())
        Addon.db.tracker.height = math.floor(frame:GetHeight())
    end)
    bar.resizer = resizer

    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("RIGHT", -12, 0)
    title:SetJustifyH("LEFT")
    bar.title = title

    local meta = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    meta:SetPoint("TOPLEFT", 12, -31)
    meta:SetPoint("RIGHT", -12, 0)
    meta:SetJustifyH("LEFT")
    bar.meta = meta

    local deaths = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    deaths:SetPoint("TOPLEFT", 12, -52)
    deaths:SetPoint("RIGHT", -12, 0)
    deaths:SetJustifyH("LEFT")
    deaths:SetJustifyV("TOP")
    deaths:SetWordWrap(true)
    deaths:SetHeight(24)
    bar.deaths = deaths

    local interrupts = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    interrupts:SetPoint("TOPLEFT", 12, -74)
    interrupts:SetPoint("RIGHT", -12, 0)
    interrupts:SetJustifyH("LEFT")
    interrupts:SetJustifyV("TOP")
    interrupts:SetWordWrap(true)
    interrupts:SetHeight(24)
    bar.interrupts = interrupts

    self.trackerBar = bar
end

function Addon:RefreshTrackerBar()
    -- Deliberately NOT gated behind IsUiLocked()/InCombatLockdown() -- found 2026-09-01: the
    -- 1-second OnUpdate ticker below (see CreateTrackerBar) was calling this every tick, but this
    -- early return made it silently no-op for the entire duration of combat, which in an M+ run
    -- is nearly the whole dungeon -- exactly matching the user's report ("it did once then
    -- stopped") and the live screenshots showing the bar's timer/enemy-forces% frozen minutes
    -- behind the real value while a third-party addon (unaffected by this) tracked it correctly.
    -- Combat-lockdown restrictions apply to secure/protected frames and specific protected API
    -- calls -- not to :SetText()/:SetWidth()/:Show() on an ordinary custom frame like this bar
    -- (created via plain CreateFrame, no secure template), so this was never actually necessary.
    if not self.db or not self.db.tracker or not self.db.tracker.shown then
        if self.trackerBar then
            self.trackerBar:Hide()
        end
        return
    end

    self:CreateTrackerBar()
    if self.trackerBar then
        -- Only set explicitly when arcane -- classic mode is left with the bar's original
        -- untouched default border (no explicit tint was ever set here before this theme system
        -- existed), so opting out of the new theme doesn't change anything about the bar's
        -- existing look.
        if self.db and self.db.uiTheme == "arcane" then
            self.trackerBar:SetBackdropBorderColor(self:GetThemeBorderColor(true, 0.9))
        else
            self.trackerBar:SetBackdropBorderColor(1, 1, 1, 1)
        end
    end

    local run = self:GetCurrentRun()
    if not run then
        self.trackerBar.title:SetText("M+ Ledger")
        self.trackerBar.meta:SetText("No active dungeon run. The bar will update when a run starts.")
        self.trackerBar.deaths:SetText("Deaths: waiting for party data")
        self.trackerBar.interrupts:SetText("Interrupts: waiting for party data")
        self.trackerBar:Show()
        return
    end

    local timeText = FormatDuration(GetRunDuration(run))
    if self:IsMythicPlusRun(run) then
        local limit = self:GetMythicPlusTimeLimit(run)
        if limit then
            local remaining = limit - GetRunDuration(run)
            if remaining >= 0 then
                timeText = string.format("%s / %s (|cff33ff33-%s|r)", FormatDuration(GetRunDuration(run)), FormatDuration(limit), FormatDuration(remaining))
            else
                timeText = string.format("%s / %s (|cffff3333+%s over|r)", FormatDuration(GetRunDuration(run)), FormatDuration(limit), FormatDuration(-remaining))
            end
        end
    end

    self.trackerBar.title:SetText(run.instanceName or "Current Instance")
    self.trackerBar.meta:SetText(string.format(
        "Players: %d | Party deaths: %d | Gold: %s | Repairs: %s | Time: %s",
        GetMemberCount(run),
        self:GetRunDeathTotal(run),
        FormatMoney(run.goldLooted or 0),
        FormatMoneyIcons(run.repairCost or 0),
        timeText
    ))
    self.trackerBar.deaths:SetText("Deaths: " .. self:GetDeathSummary(run))
    self.trackerBar.interrupts:SetText("Interrupts: " .. self:GetInterruptSummary(run))

    self.trackerBar:Show()
end

function Addon:ShowTrackerBar()
    self.db.tracker = self.db.tracker or CopyDefaults({}, DEFAULTS.tracker)
    self.db.tracker.shown = true
    self:RefreshTrackerBar()
    Print("Tracker bar shown.")
end

function Addon:HideTrackerBar()
    self.db.tracker = self.db.tracker or CopyDefaults({}, DEFAULTS.tracker)
    self.db.tracker.shown = false
    if self.trackerBar then
        self.trackerBar:Hide()
    end
    Print("Tracker bar hidden.")
end

function Addon:ToggleTrackerBar()
    self.db.tracker = self.db.tracker or CopyDefaults({}, DEFAULTS.tracker)
    if self.db.tracker.shown then
        self:HideTrackerBar()
    else
        self:ShowTrackerBar()
    end
end

function Addon:RefreshAllDisplays()
    if self.window then
        self:RefreshWindow()
    end
    if self.dataTools and self.dataTools:IsShown() then
        self:RefreshDataToolsWindow()
    end
    if self.trackerBar then
        self:RefreshTrackerBar()
    end
    -- Needed so a live UI theme toggle (Settings -> "Use new Arcane UI theme") repaints the
    -- Mythic+ Stats dungeon tiles, and swaps Season Overview's completion bar/donut chart,
    -- immediately instead of only on the next tab switch.
    if self.statsHubWindow and self.statsHubWindow:IsShown() then
        if self.statsHubWindow.activeTab == "mplus" then
            self:RefreshMythicPlusStatsTabData()
        elseif self.statsHubWindow.activeTab == "season" then
            self:RefreshSeasonTabContent()
        end
    end
end

function Addon:RestorePersistentDisplayOptions()
    if not self.db then
        return
    end

    self.db.tracker = self.db.tracker or CopyDefaults({}, DEFAULTS.tracker)
    self.db.minimap = CopyDefaults(self.db.minimap, DEFAULTS.minimap)

    self:RefreshMinimapButton()
    if self.db.tracker.shown then
        self:RefreshTrackerBar()
    elseif self.trackerBar then
        self.trackerBar:Hide()
    end
end

function Addon:RestorePersistentDisplayOptionsDelayed(source)
    self:RestorePersistentDisplayOptions()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            Addon:RestorePersistentDisplayOptions()
        end)
        C_Timer.After(2, function()
            Addon:RestorePersistentDisplayOptions()
            Debug("Display restored after " .. tostring(source or "delayed restore"))
        end)
    end
end

function Addon:RefreshDifficultyCards(difficulties)
    if not self.window or not self.window.difficultyCards then
        return
    end

    for _, key in ipairs(DIFFICULTY_BUCKET_ORDER) do
        local card = self.window.difficultyCards[key]
        local info = difficulties and difficulties[key]
        local config = DIFFICULTY_BUCKETS[key] or { label = key, color = "|cffffffff" }
        local backdrop = config.backdrop or { 0.10, 0.09, 0.08 }
        local opacity = math.max(0, math.min(0.70, tonumber(self.db and self.db.overallDifficultyOpacity) or DEFAULTS.overallDifficultyOpacity))
        if card then
            card:SetBackdropColor(backdrop[1] or 0.10, backdrop[2] or 0.09, backdrop[3] or 0.08, opacity)
            card:SetBackdropBorderColor(backdrop[1] or 0.9, backdrop[2] or 0.75, backdrop[3] or 0.25, 0.95)
        end
        if card and card.label then
            card.label:SetText(config.color .. config.label .. "|r")
            card.label:Show()
        end
        if card and info then
            local incompleteLabel = key == "mythicPlus" and "Abandoned" or "Left"
            local overtimeText = (tonumber(info.completedOvertime) or 0) > 0 and (" |cff99cc33OT " .. tostring(info.completedOvertime) .. "|r") or ""
            card.value:SetText(string.format("%d runs\n|cff00ff00Completed %d|r%s\n|cffff5555%s %d|r\nYou %d | Party %d\n%s", info.runs or 0, info.completed or 0, overtimeText, incompleteLabel, info.abandoned or 0, info.playerDeaths or 0, info.partyDeaths or 0, FormatMoneyIcons(info.repairCost or 0)))
        elseif card then
            local incompleteLabel = key == "mythicPlus" and "Abandoned" or "Left"
            card.value:SetText("0 runs\n|cff00ff00Completed 0|r\n|cffff5555" .. incompleteLabel .. " 0|r\nYou 0 | Party 0\n" .. FormatMoneyIcons(0))
        end
    end
end

function Addon:GetBrowserRunDuration(run)
    return GetRunDuration(run)
end

function Addon:RefreshWindow()
    if self:IsUiLocked() then
        self:MarkUiDirty()
        return
    end

    if not self.window then
        return
    end

    local runCardOpacity = math.max(0.25, math.min(0.95, tonumber(self.db and self.db.runCardOpacity) or DEFAULTS.runCardOpacity))
    local focusRun = self:GetDebugSelectedRun() or self:GetCurrentRun() or self:GetLastRun()
    self.selectedRunForShare = focusRun
    self:RefreshDebugEditPanel()
    if self.window.dataToolsButton then
        self.window.dataToolsButton:Show()
    end

    if self.selectedDungeonName then
        local dungeon = self:GetDungeonSummary(self.selectedDungeonName)
        local best = dungeon.bestRun
        local selectedKind = self:GetRunKind(best or self.selectedDungeonName)
        self.window.summaryTitle:SetText(self.selectedDungeonName)
        self.window.summaryStatus:SetText(string.format(
            "%s totals: %d run%s | Your deaths: %d | Party deaths: %d | Repairs: %s | %s",
            selectedKind,
            dungeon.runs,
            dungeon.runs == 1 and "" or "s",
            dungeon.playerDeaths or 0,
            dungeon.partyDeaths or 0,
            FormatMoneyIcons(dungeon.repairCost or 0),
            self:GetCompletionText(dungeon.completed, dungeon.abandoned)
        ))
        self.window.playerDeathBox.label:SetText("Your Deaths")
        self.window.playerDeathBox.value:SetText(tostring(dungeon.playerDeaths or 0))
        self.window.partyDeathBox.label:SetText("Party Deaths")
        self.window.partyDeathBox.value:SetText(tostring(dungeon.partyDeaths or 0))
        self.window.repairBox.label:SetText("Repairs")
        self.window.repairBox.value:SetText(FormatMoneyIcons(dungeon.repairCost or 0))
        self.window.runBox.label:SetText("Best Run (on-time)")
        self.window.runBox.value:SetText(best and string.format("%s (+%d)", FormatDuration(GetRunDuration(best)), self:GetRunKeyLevel(best)) or "-")
        self:RefreshDifficultyCards(dungeon.difficulties)

        self.window.listTitle:SetText("Runs - " .. self.selectedDungeonName)
        self.window.backButton:Show()
        if self.window.progressButton then
            self.window.progressButton:Show()
        end
        if self.window.sortButton then
            self.window.sortButton:Hide()
        end
        if self.window.viewButton then
            self.window.viewButton:Hide()
        end
        if self.window.viewMenu then
            self.window.viewMenu:Hide()
        end
        if self.window.sortMenu then
            self.window.sortMenu:Hide()
        end
        if self.window.sortMenu then
            self.window.sortMenu:Hide()
        end

        local runs = self:GetRunsForDungeon(self.selectedDungeonName, math.max(1, #(self.db.runOrder or {})))
        self:SetListOffset(self.window.listOffset or 0, #runs)
        self:UpdateScrollButtons(#runs)
        if not self:GetRun(self.debugSelectedRunID) then
            self.selectedRunForShare = runs[1] or focusRun
        end
        for index, row in ipairs(self.window.rows) do
            local visibleIndex = index
            local run = runs[(self.window.listOffset or 0) + visibleIndex]
            if run and visibleIndex <= MainLayoutConst.DETAIL_VISIBLE_ROWS then
                row:Show()
                row:ClearAllPoints()
                row:SetPoint("TOP", -10, MainLayoutConst.DETAIL_ROW_START_Y - ((visibleIndex - 1) * MainLayoutConst.DETAIL_ROW_SPACING))
                row:SetSize(MainLayoutConst.DETAIL_ROW_WIDTH, MainLayoutConst.DETAIL_ROW_HEIGHT)
                row.dungeonName = nil
                row.runID = run.id
                self:SetRowIcon(row, self:GetDungeonIcon(run), 54, run.instanceName)
                row.icon:Show()
                row.icon:ClearAllPoints()
                row.icon:SetPoint("TOPLEFT", 9, -10)
                row.name:ClearAllPoints()
                row.name:Show()
                row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, 0)
                row.name:SetWidth(320)
                row.name:SetHeight(18)
                row.name:SetWordWrap(false)
                row.name:SetText((run.startedAtText or ("Run " .. tostring(run.id or index))) .. " - " .. self:GetDungeonDisplayName(run))
                row.status:ClearAllPoints()
                row.status:Show()
                row.status:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
                row.status:SetWidth(320)
                row.status:SetHeight(72)
                row.status:SetWordWrap(true)
                -- Expansion + season line added 2026-09-30 per user request ("add the Expansion on
                -- the run and the season that dungeon was in if it was in a season") -- reuses the
                -- same GetRunExpansionText/GetDungeonSeasonTagsText this session already built for
                -- the main window's dungeon cards, so a run's expansion/season provenance reads the
                -- same way everywhere in the addon.
                local expansionText = self:GetRunExpansionText(run)
                local seasonTags = self:GetDungeonSeasonTagsText(run.instanceName)
                local expansionLine = expansionText and expansionText ~= "Unknown Expansion" and expansionText or nil
                if expansionLine and seasonTags then
                    expansionLine = expansionLine .. " -- " .. seasonTags
                end
                row.status:SetText(string.format(
                    "%s | %s | %s\nBosses: %s\nRepairs: %s%s",
                    self:GetRunDisplayStatus(run),
                    FormatDuration(GetRunDuration(run)),
                    self:GetDifficultyText(run),
                    self:FormatBossProgress(run),
                    FormatMoneyIcons(run.repairCost or 0),
                    expansionLine and ("\n|cff888888" .. expansionLine .. "|r") or ""
                ))
                row.playerDeaths:Hide()
                row.partyDeaths:Hide()
                row.repairs:Hide()
                row.detail:Hide()
                local dpsWidth = 180
                local tankWidth = 140
                local healsWidth = 135
                row.roleHeaders.dps:ClearAllPoints()
                row.roleHeaders.tank:ClearAllPoints()
                row.roleHeaders.heals:ClearAllPoints()
                row.roleHeaders.dps:SetPoint("TOPLEFT", 384, -12)
                row.roleHeaders.tank:SetPoint("TOPLEFT", row.roleHeaders.dps, "TOPRIGHT", 8, 0)
                row.roleHeaders.heals:SetPoint("TOPLEFT", row.roleHeaders.tank, "TOPRIGHT", 8, 0)
                row.roleHeaders.dps:SetWidth(dpsWidth)
                row.roleHeaders.tank:SetWidth(tankWidth)
                row.roleHeaders.heals:SetWidth(healsWidth)
                row.roleColumns.dps:SetWidth(dpsWidth)
                row.roleColumns.tank:SetWidth(tankWidth)
                row.roleColumns.heals:SetWidth(healsWidth)
                row.roleColumns.dps:SetHeight(84)
                row.roleColumns.tank:SetHeight(84)
                row.roleColumns.heals:SetHeight(84)
                row.roleHeaders.dps:Show()
                row.roleHeaders.tank:Show()
                row.roleHeaders.heals:Show()
                row.roleColumns.dps:SetText(self:GetRoleColumnText(run, "DAMAGER"))
                row.roleColumns.tank:SetText(self:GetRoleColumnText(run, "TANK"))
                row.roleColumns.heals:SetText(self:GetRoleColumnText(run, "HEALER"))
                row.roleColumns.dps:Show()
                row.roleColumns.tank:Show()
                row.roleColumns.heals:Show()
                local runStatus = self:GetRunStatus(run)
                local difficultyColor = self:GetDifficultyBackdropColor(run)
                row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
                row:SetBackdropColor(difficultyColor[1] or 0.08, difficultyColor[2] or 0.08, difficultyColor[3] or 0.08, math.min(0.42, math.max(0.22, runCardOpacity - 0.40)))
                row:SetBackdropBorderColor(math.min((difficultyColor[1] or 0.45) + 0.35, 1), math.min((difficultyColor[2] or 0.02) + 0.35, 1), math.min((difficultyColor[3] or 0.02) + 0.35, 1), 0.98)
                if runStatus == "Abandoned" and run.leftWithoutCompletion and self:IsMythicPlusRun(run) then
                    row.skull:Show()
                else
                    row.skull:Hide()
                end
                if row.statusRibbon then
                    local color = STATUS_BACKDROP_COLORS[runStatus] or STATUS_BACKDROP_COLORS.Active
                    row.statusRibbon.text:SetText(self:GetRunDisplayStatus(run))
                    -- Width now fits the actual text -- was a fixed 98px, too narrow for
                    -- "Completed / Overtime" (per user report/screenshot 2026-09-30: the text ran
                    -- past the pill's own background). Measured after setting the text, with
                    -- padding, so any future status string self-sizes correctly too.
                    local textWidth = row.statusRibbon.text:GetStringWidth() or 0
                    row.statusRibbon:ClearAllPoints()
                    row.statusRibbon:SetSize(math.max(98, textWidth + 20), 18)
                    row.statusRibbon:SetPoint("TOPLEFT", row.status, "BOTTOMLEFT", 0, -2)
                    row.statusRibbon:SetBackdropColor(color[1] or 0.02, color[2] or 0.15, color[3] or 0.45, 0.88)
                    if row.statusRibbon.completedFill then
                        row.statusRibbon.completedFill:Hide()
                    end
                    if row.statusRibbon.failedFill then
                        row.statusRibbon.failedFill:Hide()
                    end
                    row.statusRibbon.text:Show()
                    row.statusRibbon:Show()
                end
                row.runCode:SetText(self:GetRunCode(run) or "")
                row.runCode:Show()
                row.shareButton:Show()
                row.editButton:Show()
                local metadata = self.db and self.db.dungeonMetadata and self.db.dungeonMetadata[run.instanceName or ""]
                if row.guideButton and ((metadata and metadata.journalInstanceID) or run.journalInstanceID) then
                    row.guideButton:Show()
                elseif row.guideButton then
                    row.guideButton:Hide()
                end
            else
                if row.roleHeaders then
                    row.roleHeaders.dps:Hide()
                    row.roleHeaders.tank:Hide()
                    row.roleHeaders.heals:Hide()
                    row.roleColumns.dps:Hide()
                    row.roleColumns.tank:Hide()
                    row.roleColumns.heals:Hide()
                end
                if row.runCode then
                    row.runCode:Hide()
                end
                if row.shareButton then
                    row.shareButton:Hide()
                end
                if row.editButton then
                    row.editButton:Hide()
                end
                if row.guideButton then
                    row.guideButton:Hide()
                end
                if row.statusRibbon then
                    row.statusRibbon:Hide()
                end
                row:Hide()
            end
        end
        return
    end

    local overall = self:GetOverallSummary()
    self.window.summaryTitle:SetText("M+ Ledger Overall")
    self.window.summaryStatus:SetText(string.format(
        "Overall: Your deaths %d | Repairs %s | Party deaths %d | Completed %d | Failed %d",
        overall.playerDeaths or 0,
        FormatMoneyIcons(overall.repairCost or 0),
        overall.partyDeaths or 0,
        overall.completed or 0,
        overall.abandoned or 0
    ))
    self.window.playerDeathBox.label:SetText("Your Deaths")
    self.window.playerDeathBox.value:SetText(tostring(overall.playerDeaths or 0))
    self.window.partyDeathBox.label:SetText("Party Deaths")
    self.window.partyDeathBox.value:SetText(tostring(overall.partyDeaths or 0))
    self.window.repairBox.label:SetText("Repairs")
    self.window.repairBox.value:SetText(FormatMoneyIcons(overall.repairCost or 0))
    self.window.runBox.label:SetText("Runs")
    self.window.runBox.value:SetText(string.format("%d / %d", overall.completed or 0, overall.abandoned or 0))
    self:RefreshDifficultyCards(overall.difficulties)

    self.window.listTitle:SetText("Dungeons - " .. self:GetCompletionText(overall.completed, overall.abandoned))
    self.window.backButton:Hide()
    if self.window.progressButton then
        self.window.progressButton:Hide()
    end
    if self.window.viewButton then
        self.window.viewButton:SetText("Filter: " .. self:GetMainViewLabel())
        self.window.viewButton:Show()
    end
    if self.window.sortButton then
        self.window.sortButton:SetText("Sort: " .. self:GetMainSortLabel())
        self.window.sortButton:Show()
    end

    -- Raised 50 -> 500 2026-09-30 per user report ("Masaria Caverns" missing from the "Mythic+
    -- Season" grouped view, showing "Midnight Season 1" dungeons that aren't there): this cap
    -- limits how many DISTINCT dungeon names even become candidates for ANY filter mode (Current
    -- Season, Expansion, Mythic+ Season, All Dungeons), keyed purely by recency of last touch --
    -- so a dungeon last run a month ago (Maisara Caverns: 2026-09-01) silently never appears in
    -- ANY view once 50 OTHER distinct dungeons have been touched more recently, regardless of
    -- whether the season/expansion grouping logic itself is correct (verified separately -- it
    -- is). The scan loop below already walks every run in runOrder regardless of this cap (no
    -- early break) to keep existing summaries' stats updated, so raising it doesn't change how
    -- much work the loop does -- it only allows more DISTINCT dungeons to become visible at all.
    local summaries = self:GetRecentDungeonSummaries(500)
    local displayItems = self:BuildMainDisplayItems(summaries)
    self:SetListOffset(self.window.listOffset or 0, #displayItems)
    self:UpdateScrollButtons(#displayItems)
    local layoutY = MainLayoutConst.MAIN_CARD_Y
    local layoutColumn = 0
    local function hideMainRow(row)
        if row.roleHeaders then
            row.roleHeaders.dps:Hide()
            row.roleHeaders.tank:Hide()
            row.roleHeaders.heals:Hide()
            row.roleColumns.dps:Hide()
            row.roleColumns.tank:Hide()
            row.roleColumns.heals:Hide()
        end
        if row.runCode then row.runCode:Hide() end
        if row.shareButton then row.shareButton:Hide() end
        if row.editButton then row.editButton:Hide() end
        if row.guideButton then row.guideButton:Hide() end
        if row.statusRibbon then row.statusRibbon:Hide() end
        row:Hide()
    end
    local reachedMainListBottom = false
    for index, row in ipairs(self.window.rows) do
        local item = displayItems[(self.window.listOffset or 0) + index]
        local summary = item and item.summary
        if reachedMainListBottom then
            hideMainRow(row)
        elseif item and item.kind == "banner" and index <= MainLayoutConst.MAIN_VISIBLE_ROWS then
            if layoutColumn > 0 then
                layoutY = layoutY - MainLayoutConst.MAIN_CARD_HEIGHT - MainLayoutConst.MAIN_CARD_V_SPACING
                layoutColumn = 0
            end
            if (layoutY - 24) < MainLayoutConst.MAIN_LIST_BOTTOM_Y then
                hideMainRow(row)
                reachedMainListBottom = true
            else
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.window, "TOPLEFT", MainLayoutConst.MAIN_CARD_X, layoutY)
            row:SetSize((MainLayoutConst.MAIN_CARD_WIDTH * MainLayoutConst.MAIN_GRID_COLUMNS) + (MainLayoutConst.MAIN_CARD_H_SPACING * (MainLayoutConst.MAIN_GRID_COLUMNS - 1)), 24)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
            row:SetBackdropColor(0.10, 0.08, 0.02, 0.88)
            row:SetBackdropBorderColor(self:GetThemeBorderColor(true, 0.98))
            row.dungeonName = nil
            row.cardSummary = nil
            row.runID = nil
            row.icon:Hide()
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", 12, 0)
            row.name:SetWidth(900)
            row.name:SetHeight(18)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)
            row.name:SetText(item.text or "Unknown")
            row.name:Show()
            row.status:Hide()
            row.detail:Hide()
            row.playerDeaths:Hide()
            row.partyDeaths:Hide()
            row.repairs:Hide()
            row.skull:Hide()
            if row.runCode then row.runCode:Hide() end
            if row.shareButton then row.shareButton:Hide() end
            if row.editButton then row.editButton:Hide() end
            if row.guideButton then row.guideButton:Hide() end
            if row.statusRibbon then row.statusRibbon:Hide() end
            layoutY = layoutY - 34
            layoutColumn = 0
            end
        elseif summary and index <= MainLayoutConst.MAIN_VISIBLE_ROWS then
            if (layoutY - MainLayoutConst.MAIN_CARD_HEIGHT) < MainLayoutConst.MAIN_LIST_BOTTOM_Y then
                hideMainRow(row)
                reachedMainListBottom = true
            else
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.window, "TOPLEFT", MainLayoutConst.MAIN_CARD_X + (layoutColumn * (MainLayoutConst.MAIN_CARD_WIDTH + MainLayoutConst.MAIN_CARD_H_SPACING)), layoutY)
            row:SetSize(MainLayoutConst.MAIN_CARD_WIDTH, MainLayoutConst.MAIN_CARD_HEIGHT)
            row.dungeonName = summary.name
            row.cardSummary = summary
            row.runID = nil
            self:SetRowIcon(row, self:GetDungeonIcon(summary.latestRun or summary.name), 62, summary.name)
            row.icon:Show()
            if row.statusRibbon then
                local completed = tonumber(summary.completed) or 0
                local failed = tonumber(summary.abandoned) or 0
                local total = completed + failed
                local barWidth = MainLayoutConst.MAIN_CARD_WIDTH - 4
                local completedWidth = total > 0 and math.floor((completed / total) * barWidth + 0.5) or 0
                local failedWidth = math.max(0, barWidth - completedWidth)
                row.statusRibbon:ClearAllPoints()
                row.statusRibbon:SetSize(MainLayoutConst.MAIN_CARD_WIDTH - 2, 13)
                row.statusRibbon:SetPoint("TOPLEFT", 1, -1)
                row.statusRibbon:SetBackdropColor(Addon:GetTableBackgroundColor(0.86))
                if row.statusRibbon.completedFill then
                    if completed > 0 then
                        row.statusRibbon.completedFill:SetWidth(math.max(completedWidth, 1))
                        row.statusRibbon.completedFill:Show()
                    else
                        row.statusRibbon.completedFill:Hide()
                    end
                end
                if row.statusRibbon.failedFill then
                    if failed > 0 then
                        row.statusRibbon.failedFill:SetWidth(math.max(failedWidth, 1))
                        row.statusRibbon.failedFill:Show()
                    else
                        row.statusRibbon.failedFill:Hide()
                    end
                end
                row.statusRibbon.text:Hide()
                row.statusRibbon:Show()
            end
            row.icon:ClearAllPoints()
            row.icon:SetPoint("TOPLEFT", 8, -24)
            row.name:ClearAllPoints()
            row.name:Show()
            row.name:SetJustifyH("LEFT")
            row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
            row.name:SetWidth(MainLayoutConst.MAIN_CARD_WIDTH - 84)
            row.name:SetHeight(32)
            row.name:SetWordWrap(true)
            row.name:SetText(self:GetDungeonCardTitleText(summary))
            row.status:ClearAllPoints()
            row.status:Show()
            row.status:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
            row.status:SetWidth(MainLayoutConst.MAIN_CARD_WIDTH - 84)
            row.status:SetHeight(14)
            row.status:SetWordWrap(false)
            row.status:SetText(self:GetCompactCompletionText(summary.completed, summary.abandoned, "F"))
            row.detail:Hide()
            if row.roleHeaders then
                row.roleHeaders.dps:Hide()
                row.roleHeaders.tank:Hide()
                row.roleHeaders.heals:Hide()
                row.roleColumns.dps:Hide()
                row.roleColumns.tank:Hide()
                row.roleColumns.heals:Hide()
            end
            row.playerDeaths:Show()
            row.partyDeaths:Show()
            row.repairs:Show()
            row.skull:Hide()
            if row.runCode then
                row.runCode:Hide()
            end
            if row.shareButton then
                row.shareButton:Hide()
            end
            if row.editButton then
                row.editButton:Hide()
            end
            if row.guideButton then
                row.guideButton:Hide()
            end
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = summary.active and 14 or 10, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
            row:SetBackdropColor(0.08, 0.08, 0.08, runCardOpacity)
            -- "Active" (currently running) always wins as the clearest possible signal, even over
            -- a custom per-dungeon color -- otherwise a customized dungeon's card would lose its
            -- one most important state indicator.
            local dungeonColor = not summary.active and self:GetDungeonColor(summary.name)
            if summary.active then
                row:SetBackdropBorderColor(0.12, 0.48, 1.0, 1.0)
            elseif dungeonColor then
                row:SetBackdropBorderColor(dungeonColor[1], dungeonColor[2], dungeonColor[3], 1.0)
            else
                row:SetBackdropBorderColor(self:GetThemeBorderColor(true, 0.9))
            end
            row.playerDeaths:ClearAllPoints()
            row.playerDeaths:SetPoint("TOPLEFT", 8, -86)
            row.playerDeaths:SetWidth(MainLayoutConst.MAIN_CARD_WIDTH - 16)
            row.playerDeaths:SetText(string.format("%s | Runs %d", self:GetRunKind(summary.latestRun or summary.name), summary.runs or 0))
            row.partyDeaths:ClearAllPoints()
            row.partyDeaths:SetPoint("TOPLEFT", row.playerDeaths, "BOTTOMLEFT", 0, -1)
            row.partyDeaths:SetWidth(MainLayoutConst.MAIN_CARD_WIDTH - 16)
            row.partyDeaths:SetText(self:GetCompactDifficultyText(summary.difficulties))
            row.repairs:ClearAllPoints()
            row.repairs:SetPoint("TOPLEFT", row.partyDeaths, "BOTTOMLEFT", 0, -1)
            row.repairs:SetWidth(MainLayoutConst.MAIN_CARD_WIDTH - 16)
            row.repairs:SetHeight(34)
            row.repairs:SetJustifyV("TOP")
            row.repairs:SetText(string.format("Deaths: you %d / party %d\nRepairs: %s", summary.playerDeaths or 0, summary.partyDeaths or 0, FormatMoneyIcons(summary.repairCost or 0)))
            layoutColumn = layoutColumn + 1
            if layoutColumn >= MainLayoutConst.MAIN_GRID_COLUMNS then
                layoutColumn = 0
                layoutY = layoutY - MainLayoutConst.MAIN_CARD_HEIGHT - MainLayoutConst.MAIN_CARD_V_SPACING
            end
            end
        else
            hideMainRow(row)
        end
    end

    if self.scrollFadeActive then
        self.scrollFadeActive = false
        for _, row in ipairs(self.window.rows) do
            if row:IsShown() and UIFrameFadeIn then
                row:SetAlpha(0.35)
                UIFrameFadeIn(row, 0.16, 0.35, 1)
            end
        end
    end
end


function Addon:ToggleWindow()
    if self:IsUiLocked() then
        self:MarkUiDirty()
        Print("Window will update after combat ends.")
        return
    end

    self:CreateWindow()
    if not self.window then
        Print("Window will open after combat ends.")
        return
    end

    if self.window:IsShown() then
        self.window:Hide()
    else
        -- Set unconditionally on every open, mirroring ToggleStatsHubWindow's own
        -- returnToWindow = self.window (see that function) -- so closing this window (ESC/X)
        -- always returns to Stats Hub, the same simple "always go back to the other one" rule
        -- Stats Hub already uses in reverse.
        self.window.returnToStatsHub = self.statsHubWindow
        self:RefreshAllDisplays()
        self.window:Show()
    end
end

function Addon:FindRunForRepairSearch(value)
    value = strtrim(tostring(value or ""))
    if value == "" then
        return self:GetRepairTargetRun() or self.selectedRunForShare or self:GetLastRun()
    end

    local byCode = self:FindRunByCode(value)
    if byCode then
        return byCode
    end

    local byID = self:GetRun(value)
    if byID then
        return byID
    end

    for _, runID in ipairs(self.db and self.db.runOrder or {}) do
        local run = self:GetRun(runID)
        if run and tostring(run.id or "") == value then
            return run
        end
    end
    return nil
end

function Addon:GetRepairWindowRunText(run)
    run = run or self.repairWindowSelectedRun or self:GetRepairTargetRun() or self.selectedRunForShare or self:GetLastRun()
    if not run then
        return "Select Run"
    end
    return self:GetRunOptionText(run)
end

function Addon:CreateRepairWindow()
    if self.repairWindow then
        return
    end

    local frame = CreateFrame("Frame", "MPlusLedgerRepairFrame", UIParent, "BackdropTemplate")
    frame:SetSize(760, 365)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(430)
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    EnableEscHandler(frame, function()
        Addon:CloseAllWindows()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0, 0, 0, 1.00)

    -- Portrait icon, matching the rest of the addon's windows (UI consistency pass, 2026-09-01).
    local portraitRing = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    portraitRing:SetSize(50, 50)
    portraitRing:SetPoint("TOPLEFT", 9, -7)
    portraitRing:SetColorTexture(self:GetThemeBorderColor(true, 0.9))
    local portrait = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    portrait:SetSize(44, 44)
    portrait:SetPoint("CENTER", portraitRing, "CENTER", 0, 0)
    portrait:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    portrait:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Record Repair")

    local close = self:CreatePlainButton(frame, "X", 28, 24)
    close:SetPoint("TOPRIGHT", -18, -18)
    close:SetScript("OnClick", function()
        Addon:ReturnToMainMenu()
    end)

    -- Shortened to match the approved mockup's "Current season only" label (was "Show Current
    -- Mythic+ Season") -- per user request 2026-10-02 ("it should look like this as well").
    frame.seasonOnlyCheck = self:CreateCheckButton(frame, "Current season only", function()
        return Addon.repairRunFilterSeasonOnly == true
    end, function(value)
        Addon.repairRunFilterSeasonOnly = value and true or false
        Addon:RefreshRepairWindow()
    end)
    frame.seasonOnlyCheck:SetPoint("TOPLEFT", 34, -58)

    local expansionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    expansionLabel:SetPoint("TOPLEFT", 34, -92)
    expansionLabel:SetText("Expansion")
    frame.expansionButton = self:CreatePlainButton(frame, "All Expansions", 220, 24)
    frame.expansionButton:SetPoint("TOPLEFT", 34, -110)
    frame.expansionMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.expansionMenu:SetSize(220, 30)
    frame.expansionMenu:SetPoint("TOPLEFT", frame.expansionButton, "BOTTOMLEFT", 0, -2)
    frame.expansionMenu:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.expansionMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame.expansionMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    frame.expansionMenu:EnableMouse(true)
    frame.expansionMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    frame.expansionMenu:Hide()

    local instanceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    instanceLabel:SetPoint("TOPLEFT", 276, -92)
    instanceLabel:SetText("Instance")
    frame.instanceButton = self:CreatePlainButton(frame, "All Instances", 260, 24)
    frame.instanceButton:SetPoint("TOPLEFT", 276, -110)
    frame.instanceMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.instanceMenu:SetSize(260, 30)
    frame.instanceMenu:SetPoint("TOPLEFT", frame.instanceButton, "BOTTOMLEFT", 0, -2)
    frame.instanceMenu:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.instanceMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame.instanceMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    frame.instanceMenu:EnableMouse(true)
    frame.instanceMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    frame.instanceMenu:Hide()

    local runLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    runLabel:SetPoint("TOPLEFT", 34, -146)
    runLabel:SetText("Run")

    frame.runButton = self:CreatePlainButton(frame, "Select Run", 560, 24)
    frame.runButton:SetPoint("TOPLEFT", 34, -164)
    frame.runMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.runMenu:SetSize(560, 30)
    frame.runMenu:SetPoint("TOPLEFT", frame.runButton, "BOTTOMLEFT", 0, -2)
    frame.runMenu:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.runMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame.runMenu:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    frame.runMenu:EnableMouse(true)
    frame.runMenu:SetScript("OnLeave", CloseDropdownOnLeave)
    frame.runMenu:Hide()

    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchLabel:SetPoint("TOPLEFT", 34, -200)
    searchLabel:SetText("Run code or ID")
    frame.searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.searchBox:SetSize(240, 24)
    frame.searchBox:SetPoint("TOPLEFT", 34, -218)
    frame.searchBox:SetAutoFocus(false)
    frame.searchBox:SetTextInsets(4, 4, 0, 0)

    local search = self:CreatePlainButton(frame, "Search", 80, 24)
    search:SetPoint("LEFT", frame.searchBox, "RIGHT", 12, 0)

    local function moneyBox(label, icon, x)
        local font = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        font:SetPoint("TOPLEFT", x, -254)
        font:SetText(label .. " " .. icon)
        local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        editBox:SetSize(70, 24)
        editBox:SetPoint("TOPLEFT", x, -272)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(true)
        editBox:SetTextInsets(4, 4, 0, 0)
        return editBox
    end
    frame.goldBox = moneyBox("Gold", "|TInterface\\MoneyFrame\\UI-GoldIcon:13:13:0:0|t", 34)
    frame.silverBox = moneyBox("Silver", "|TInterface\\MoneyFrame\\UI-SilverIcon:13:13:0:0|t", 116)
    frame.copperBox = moneyBox("Copper", "|TInterface\\MoneyFrame\\UI-CopperIcon:13:13:0:0|t", 198)

    local fields = { frame.searchBox, frame.goldBox, frame.silverBox, frame.copperBox }
    local function focusNext(current)
        for index, editBox in ipairs(fields) do
            if editBox == current then
                fields[(index % #fields) + 1]:SetFocus()
                return
            end
        end
    end
    for _, editBox in ipairs(fields) do
        editBox:SetScript("OnTabPressed", function(self)
            focusNext(self)
        end)
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
    end

    frame.validation = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.validation:SetPoint("BOTTOMLEFT",34,22); frame.validation:SetWidth(540); frame.validation:SetJustifyH("LEFT")
    frame.validation:SetText("Select a run, then enter the repair cost to add to it.")
    local save = self:CreatePlainButton(frame, "Add repair cost", 125, 26)
    save:SetPoint("BOTTOMRIGHT", -34, 30)
    save:SetScript("OnClick", function()
        local run = Addon.repairWindowSelectedRun or Addon:FindRunForRepairSearch(frame.searchBox:GetText())
        if not run then
            frame.validation:SetText("|cffff8888Select a run or enter a valid run code first.|r")
            return
        end
        local cost = ((tonumber(frame.goldBox:GetText() or "") or 0) * 10000) + ((tonumber(frame.silverBox:GetText() or "") or 0) * 100) + (tonumber(frame.copperBox:GetText() or "") or 0)
        if cost <= 0 then
            frame.validation:SetText("|cffff8888Enter a repair amount greater than zero.|r")
            return
        end
        Addon:RecordRepairCost(cost, "manual repair window", run)
        frame.goldBox:SetText("")
        frame.silverBox:SetText("")
        frame.copperBox:SetText("")
        frame:Hide()
    end)

    search:SetScript("OnClick", function()
        local run = Addon:FindRunForRepairSearch(frame.searchBox:GetText())
        if run then
            Addon.repairWindowSelectedRun = run
            Addon.repairWindowSelectedRunID = run.id
            frame.runButton:SetText(Addon:GetRepairWindowRunText(run))
            frame.validation:SetText("Selected: " .. tostring(run.instanceName or "run") .. ". Enter the repair cost below.")
        else
            frame.validation:SetText("|cffff8888No matching run. Check the code or choose a run above.|r")
        end
    end)

    frame.expansionButton:SetScript("OnClick", function()
        if frame.expansionMenu:IsShown() then
            frame.expansionMenu:Hide()
        else
            frame.instanceMenu:Hide()
            frame.runMenu:Hide()
            frame.expansionMenu:Show()
        end
    end)

    frame.instanceButton:SetScript("OnClick", function()
        if frame.instanceMenu:IsShown() then
            frame.instanceMenu:Hide()
        else
            frame.expansionMenu:Hide()
            frame.runMenu:Hide()
            frame.instanceMenu:Show()
        end
    end)

    frame.runButton:SetScript("OnClick", function()
        if frame.runMenu:IsShown() then
            frame.runMenu:Hide()
        else
            frame.expansionMenu:Hide()
            frame.instanceMenu:Hide()
            frame.runMenu:Show()
        end
    end)

    frame.searchBox:SetScript("OnEnterPressed", function() search:GetScript("OnClick")(); frame.searchBox:ClearFocus() end)
    self.repairWindow = frame
    frame:Hide()
end

function Addon:RefreshRepairWindow()
    local frame = self.repairWindow
    if not frame then
        return
    end
    if self.repairRunFilterSeasonOnly == nil then
        self.repairRunFilterSeasonOnly = true
    end
    if frame.seasonOnlyCheck then
        frame.seasonOnlyCheck:Refresh()
    end
    local runOptions = self:SelectFirstFilteredRun("repairRunFilter", "repairWindowSelectedRunID")
    if self.repairWindowSelectedRunID then
        self.repairWindowSelectedRun = self:GetRun(self.repairWindowSelectedRunID)
    else
        self.repairWindowSelectedRun = nil
    end
    if frame.expansionButton then
        frame.expansionButton:SetText(self.repairRunFilterExpansionName and self.repairRunFilterExpansionName ~= "" and self.repairRunFilterExpansionName or "All Expansions")
    end
    if frame.instanceButton then
        frame.instanceButton:SetText(self.repairRunFilterInstanceName and self.repairRunFilterInstanceName ~= "" and self.repairRunFilterInstanceName or "All Instances")
    end
    self:RefreshSimpleDropdown(frame.expansionMenu, self:GetExpansionFilterOptions(), function(value)
        Addon.repairRunFilterExpansionName = value ~= "" and value or nil
        Addon.repairRunFilterInstanceName = nil
        Addon:RefreshRepairWindow()
    end)
    self:RefreshSimpleDropdown(frame.instanceMenu, self:GetInstanceFilterOptions(self.repairRunFilterExpansionName), function(value)
        Addon.repairRunFilterInstanceName = value ~= "" and value or nil
        Addon:RefreshRepairWindow()
    end)
    frame.runButton:SetText(self.repairWindowSelectedRun and self:GetRepairWindowRunText(self.repairWindowSelectedRun) or "Select Run")
    self:RefreshSimpleDropdown(frame.runMenu, runOptions, function(value)
        Addon.repairWindowSelectedRun = Addon:GetRun(value)
        Addon.repairWindowSelectedRunID = value
        frame.runButton:SetText(Addon:GetRepairWindowRunText(Addon.repairWindowSelectedRun))
    end)
    frame.expansionMenu:Hide()
    frame.instanceMenu:Hide()
    frame.runMenu:Hide()
end

function Addon:OpenRepairWindow()
    self:CreateRepairWindow()
    self.repairWindowSelectedRun = self:GetRepairTargetRun() or self.selectedRunForShare or self:GetLastRun()
    self.repairWindowSelectedRunID = self.repairWindowSelectedRun and self.repairWindowSelectedRun.id or nil
    if self.repairWindowSelectedRun then
        -- No longer pre-filters by the current run's expansion (UI/MockupLayouts.lua's "Dungeon"
        -- field now hides the separate Expansion picker that used to let a player clear this --
        -- per user request 2026-10-02, matching the mockup's single unfiltered Dungeon dropdown).
        -- Auto-setting this with no visible way to reset it would otherwise silently trap the
        -- Dungeon list to whichever expansion happened to be open when this window was first used.
        self.repairRunFilterInstanceName = self.repairRunFilterInstanceName or self.repairWindowSelectedRun.instanceName
    end
    self:RefreshRepairWindow()
    self.repairWindow:SetFrameLevel(430)
    self.repairWindow:Show()
end

function Addon:ManualRecordRepair(amountText)
    if not amountText or strtrim(tostring(amountText)) == "" then
        self:OpenRepairWindow()
        return
    end

    local amountOnly, runCode = self:ExtractTrailingRunCode(amountText)
    local targetRun = self:GetEditableRun(runCode)
    if not targetRun then
        Print("No current, selected, or coded run to repair.")
        return
    end

    local cost = ParseMoneyAmount(amountOnly)
    if cost <= 0 and GetRepairAllCost then
        cost = GetRepairAllCost() or self.pendingRepairCost or 0
    end

    if cost <= 0 then
        Print("No repair cost found. Open a repair merchant first, or use /dl repair 492g40s82c H-A7K9Q-0012.")
        return
    end

    self:RecordRepairCost(cost, "manual", targetRun)
end

function Addon:GetGroupShareChannel()
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    if IsInGroup and IsInGroup() then
        return "PARTY"
    end
    return nil
end

function Addon:GetShareTargetOption(value)
    value = value or (self.db and self.db.shareTarget) or DEFAULTS.shareTarget
    for _, option in ipairs(SHARE_TARGET_OPTIONS) do
        if option.value == value then
            return option
        end
    end
    return SHARE_TARGET_OPTIONS[3]
end

function Addon:GetShareTargetLabel()
    return self:GetShareTargetOption().text or "Guild Chat"
end

function Addon:GetNamedChatChannel(name)
    if not name or not GetChannelName then
        return nil
    end
    local id = GetChannelName(name)
    if id and tonumber(id) and tonumber(id) > 0 then
        return tostring(id)
    end
    return nil
end

function Addon:ShareRunToConfiguredTarget(run)
    run = run or self:GetCurrentRun() or self:GetLastRun()
    local text = self:GetRunShareText(run)
    if not text then
        Print("No run to share yet.")
        return
    end

    local deathText = self:GetRunDeathShareText(run)
    local option = self:GetShareTargetOption()
    local channel = option.channel
    local channelNumber
    if option.namedChannel then
        channelNumber = self:GetNamedChatChannel(option.namedChannel)
        channel = channelNumber and "CHANNEL" or nil
    end
    if not channel or not SendChatMessage then
        Print("That chat target is not available, so I opened the share text in chat instead.")
        self:ShareRun(run, true)
        return
    end

    SendChatMessage(text, channel, nil, channelNumber)
    if deathText and deathText ~= "" then
        SendChatMessage(deathText, channel, nil, channelNumber)
    end
    Print("Shared run stats to " .. (option.text or "chat") .. ".")
end

function Addon:ShareRunToGroup(run)
    run = run or self:GetCurrentRun() or self:GetLastRun()
    local text = self:GetRunShareText(run)
    if not text then
        Print("No run to share yet.")
        return
    end

    local channel = self:GetGroupShareChannel()
    if not channel or not SendChatMessage then
        Print("You are not in a group, so I opened the share text in chat instead.")
        self:ShareRun(run)
        return
    end

    SendChatMessage(text, channel)
    SendChatMessage(self:GetRunDeathShareText(run), channel)
    Print("Shared run stats to group.")
end

function Addon:ShareRun(run, forceCurrentChat)
    run = run or self:GetCurrentRun() or self:GetLastRun()
    local text = self:GetRunShareText(run)
    if not text then
        Print("No run to share yet.")
        return
    end
    if not forceCurrentChat and self.db and self.db.shareUseCurrentChat == false then
        self:ShareRunToConfiguredTarget(run)
        return
    end
    local deathText = self:GetRunDeathShareText(run)
    if deathText and deathText ~= "" then
        text = text .. "; " .. deathText
    end

    local editBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() or nil
    if editBox and editBox:IsShown() then
        editBox:Insert(text)
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat(text, SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
    else
        Print(text)
    end
end

function Addon:PrintStatus()
    local run = self:GetCurrentRun() or self:GetLastRun()
    if not run then
        Print("No dungeon run recorded yet.")
        return
    end

    local text = self:GetRunLine(run):gsub("\n", " | ")
    Print(text)
end

function Addon:GetBossEditRun(runCode)
    local run = self:GetEditableRun(runCode)
    if run then
        return run
    end
    if runCode and runCode ~= "" then
        return nil
    end
    if self.selectedDungeonName then
        return { instanceName = self.selectedDungeonName, killedBosses = {} }
    end
    return nil
end

function Addon:FindBossID(run, token)
    local bossInfo = self:GetDungeonBossInfo(run)
    if not bossInfo or not bossInfo.bosses then
        return nil
    end

    token = tostring(token or "")
    local numericID = tonumber(token)
    if numericID and bossInfo.bosses[numericID] then
        return numericID
    end

    local wanted = string.lower(token)
    for bossID in pairs(bossInfo.bosses) do
        if string.lower(self:GetBossName(run, bossID)) == wanted then
            return bossID
        end
    end

    return nil
end

function Addon:SetBossOptional(token, optional)
    local run = self:GetBossEditRun()
    if not run then
        Print("No dungeon selected yet.")
        return
    end

    local bossID = self:FindBossID(run, token)
    if not bossID then
        Print("Boss not found for " .. tostring(run.instanceName or "this dungeon") .. ". Use /dl bosses to see known boss IDs.")
        return
    end

    self.db.bossOverrides = self.db.bossOverrides or {}
    self.db.bossOverrides[run.instanceName] = self.db.bossOverrides[run.instanceName] or {}
    self.db.bossOverrides[run.instanceName][bossID] = optional and true or false
    Print(string.format(
        "%s is now %s for %s.",
        self:GetBossName(run, bossID),
        optional and "optional" or "required",
        run.instanceName or "this dungeon"
    ))
    self:RefreshAllDisplays()
end

function Addon:SetBossKilled(token, killed, runCode)
    local run = self:GetBossEditRun(runCode)
    if not run then
        Print("No dungeon selected yet.")
        return
    end

    local bossID = self:FindBossID(run, token)
    if not bossID then
        Print("Boss not found for " .. tostring(run.instanceName or "this dungeon") .. ". Use /dl bosses to see known boss IDs.")
        return
    end

    run.killedBosses = run.killedBosses or {}
    run.bossKills = run.bossKills or {}
    run.bossKillLog = run.bossKillLog or {}
    if killed then
        local alreadyKilled = run.killedBosses[bossID]
        run.killedBosses[bossID] = true
        run.encounters = run.encounters or {}
        if not alreadyKilled then
            local killedAt = time()
            local killedAtText = date("%Y-%m-%d %H:%M:%S", killedAt)
            local killTime = GetRunElapsedAt(run, killedAt)
            table.insert(run.encounters, {
                time = killedAt,
                timeText = killedAtText,
                killTime = killTime,
                encounterID = bossID,
                encounterName = self:GetBossName(run, bossID),
                encounterKey = bossID,
                manual = true,
            })
            run.bossKills[bossID] = {
                bossID = bossID,
                encounterID = bossID,
                encounterKey = bossID,
                name = self:GetBossName(run, bossID),
                count = ((run.bossKills[bossID] and run.bossKills[bossID].count) or 0) + 1,
                lastKilledAt = killedAt,
                lastKilledAtText = killedAtText,
                lastKillTime = killTime,
                manual = true,
            }
            table.insert(run.bossKillLog, {
                time = killedAt,
                timeText = killedAtText,
                killTime = killTime,
                bossID = bossID,
                encounterID = bossID,
                encounterKey = bossID,
                name = self:GetBossName(run, bossID),
                source = "debug menu",
                manual = true,
            })
        end
        Print(string.format("Marked %s killed for %s (%s).", self:GetBossName(run, bossID), run.instanceName or "this dungeon", self:GetRunCode(run) or "no code"))
        if self:HaveAllRequiredBossesDied(run) or self:IsFinalBoss(run, bossID, self:GetBossName(run, bossID)) then
            self:MarkRunCompleted(run, "manual boss checklist")
        else
            self:RefreshAllDisplays()
        end
    else
        run.killedBosses[bossID] = nil
        run.bossKills[bossID] = nil
        if run.bossKillLog then
            for index = #run.bossKillLog, 1, -1 do
                local bossKill = run.bossKillLog[index]
                if bossKill and (tonumber(bossKill.bossID) == bossID or tonumber(bossKill.encounterKey) == bossID or tonumber(bossKill.encounterID) == bossID) then
                    table.remove(run.bossKillLog, index)
                end
            end
        end
        if run.encounters then
            for index = #run.encounters, 1, -1 do
                local encounter = run.encounters[index]
                if encounter and (tonumber(encounter.encounterKey) == bossID or tonumber(encounter.encounterID) == bossID) then
                    table.remove(run.encounters, index)
                end
            end
        end
        Print(string.format("Reset %s for %s (%s).", self:GetBossName(run, bossID), run.instanceName or "this dungeon", self:GetRunCode(run) or "no code"))
        self:RefreshAllDisplays()
    end
end

function Addon:PrintBossStatus()
    local run = self:GetBossEditRun()
    if not run then
        Print("No dungeon selected yet.")
        return
    end

    local bossInfo = self:GetDungeonBossInfo(run)
    if not bossInfo or not bossInfo.bosses then
        Print("No boss checklist is mapped for " .. tostring(run.instanceName or "this dungeon") .. " yet.")
        return
    end

    local bossIDs = {}
    for bossID in pairs(bossInfo.bosses) do
        table.insert(bossIDs, bossID)
    end
    table.sort(bossIDs)

    Print("Bosses for " .. tostring(run.instanceName or "this dungeon") .. ":")
    run.killedBosses = run.killedBosses or {}
    for _, bossID in ipairs(bossIDs) do
        local killed = run.killedBosses[bossID] and "killed" or "not killed"
        local required = self:IsBossOptional(run, bossID) and "optional" or "required"
        Print(string.format("%d - %s | %s | %s", bossID, self:GetBossName(run, bossID), required, killed))
    end
end

function Addon:PrintBossSplits(runCode)
    local run = self:GetEditableRun(runCode)
    if not run then
        Print("No current, selected, or coded run to show splits for.")
        return
    end

    local segments = self:GetBossSegmentTimings(run)
    if #segments == 0 then
        Print("No boss kills recorded yet for " .. tostring(run.instanceName or "this run") .. ".")
        return
    end

    Print(string.format("Boss splits for %s (%s):", tostring(run.instanceName or "this run"), self:GetRunCode(run) or "no code"))
    for index, segment in ipairs(segments) do
        local detail
        if segment.pullSeconds and segment.fightSeconds then
            detail = string.format("%s pull + %s fight = %s", FormatDuration(segment.pullSeconds), FormatDuration(segment.fightSeconds), FormatDuration(segment.segmentSeconds))
        else
            detail = FormatDuration(segment.segmentSeconds)
        end
        Print(string.format("%d. %s -- %s (at %s)", index, segment.bossName, detail, FormatDuration(segment.cumulativeSeconds)))
    end
end

function Addon:PrintDebugLog()
    local log = self.db and self.db.debugLog or {}
    if #log == 0 then
        Print("Debug log is empty.")
        return
    end

    local startIndex = math.max(1, #log - 19)
    Print("Last " .. tostring(#log - startIndex + 1) .. " debug line(s):")
    for index = startIndex, #log do
        local entry = log[index]
        Print(string.format("%s - %s", tostring(entry.timeText or "?"), tostring(entry.message or "")))
    end
end

function Addon:PrintHelp()
    Print("|cffffcc00Windows|r")
    Print("/dl - show or hide the run window")
    Print("/dl stats - open the Stats & Progress hub (Season / Progress / M+ Stats / Trends tabs)")
    Print("/dl season, /dl progress, /dl mplus (aliases: /dl vault, /dl score, /dl mythicplus), /dl trends, /dl pacing - open the Stats & Progress hub directly on that tab")
    Print("/dl manage (aliases: /dl data, /dl managedata) - open Manage Data, to fix a misdetected boss/dungeon, correct a player's name, or edit any saved run by hand")
    Print("/dl settings - open M+ Ledger settings")
    Print("|cffffcc00Current run|r")
    Print("/dl status - print current or last run")
    Print("/dl scan - re-check whether you're in a tracked dungeon/raid right now")
    Print("/dl share - insert the selected/current run summary into your current chat")
    Print("/dl share group - post the selected/current run summary to party/raid/instance chat")
    Print("/dl members - print the recorded party members")
    Print("/dl end - end the active run")
    Print("/dl bosses - print the boss checklist (required/optional/killed) for the current or selected dungeon")
    Print("/dl splits [H-A7K9Q-0012] - print boss-to-boss split times (start-to-first-kill, then gap between each following kill) for the current, selected, or a specific run")
    Print("/dl boss optional|required 2094 - mark a boss optional or required for that dungeon")
    Print("|cffffcc00Editing saved runs|r")
    Print("/dl runtime 32 0 [H-A7K9Q-0012] - set a run's time to 32m 00s")
    Print("/dl delete [H-A7K9Q-0012] - delete the selected/current/last run, or a specific one")
    Print("|cffffcc00Display|r")
    Print("/dl bar, /dl bar hide, /dl bar toggle - show/hide/toggle the live tracker bar")
    Print("/dl minimap, /dl minimap show, /dl minimap hide - toggle/show/hide the minimap button")
    Print("/dl backfillplayers - re-check run history for grouped players who don't have a Player Menu entry yet")
    Print("/dl backfilldeaths - re-check run history for death counts left stale by a since-fixed player-removal bug")
    Print("/dl duplicates - list saved players whose name appears under more than one realm (possible duplicates)")
    Print("/dl mergeduplicates - re-run the merge for the specific duplicate players already confirmed as the same person")
    Print("/dl theme - toggle the new Arcane UI theme (experimental) on/off -- /reload after toggling to fully apply it")
    Print("|cffffcc00Reference catalog & troubleshooting|r")
    Print("/dl catalog - build/update the full expansion/dungeon/raid/boss reference catalog")
    Print("/dl icons - save Blizzard dungeon and raid icon data (used by /dl catalog)")
    Print("/dl debug, /dl fulldebug - toggle debug messages / verbose debug messages")
    Print("/dl debuglog - print the last saved debug lines")
    Print("/dl chatlog - print the last saved chat lines for the current or last run")
end

function Addon:HandleSlash(input)
    input = string.lower(strtrim(input or ""))

    if input == "" then
        -- M+ Summary (Stats Hub) is now the addon's main entry point per user request 2026-09-30 --
        -- the old main window (recent runs/repairs/deaths) is the secondary "view all runs" screen,
        -- reachable from here via its own button (see BuildMythicPlusStatsTabContent).
        self:ToggleStatsHubWindow("mplus")
    elseif input == "status" then
        self:PrintStatus()
    elseif input == "scan" then
        self:CheckInstanceState("manual scan")
        Print("Scan complete.")
    elseif input == "share" then
        self:ShareRun(self.selectedRunForShare)
    elseif input == "share group" then
        self:ShareRunToGroup(self.selectedRunForShare)
    elseif input == "members" then
        self:PrintMembers()
    elseif input == "bar" then
        self:ShowTrackerBar()
    elseif input == "bar hide" then
        self:HideTrackerBar()
    elseif input == "bar toggle" then
        self:ToggleTrackerBar()
    elseif input == "settings" or input == "options" then
        self:OpenSettings()
    elseif input == "stats" or input == "statshub" then
        self:ToggleStatsHubWindow()
    elseif input == "mplus" or input == "mythicplus" or input == "vault" or input == "score" then
        self:ToggleStatsHubWindow("mplus")
    elseif input == "season" or input == "seasonoverview" or input == "overview" then
        self:ToggleStatsHubWindow("season")
    elseif input == "progress" then
        self:ToggleStatsHubWindow("progress", self.progressDungeonName)
    elseif input == "trends" then
        self:ToggleStatsHubWindow("trends")
    elseif input == "pacing" or input == "bosspacing" then
        self:ToggleStatsHubWindow("pacing")
    elseif input == "manage" or input == "managedata" or input == "data" then
        self:ToggleDataToolsWindow()
    elseif input == "minimap" then
        self.db.minimap.shown = not (self.db.minimap.shown and self.minimapButton)
        self:RefreshMinimapButton()
        Print("Minimap button is now " .. (self.db.minimap.shown and "shown" or "hidden") .. ".")
    elseif input == "minimap show" then
        self.db.minimap.shown = true
        self:RefreshMinimapButton()
        Print("Minimap button is now shown.")
    elseif input == "minimap hide" then
        self.db.minimap.shown = false
        self:RefreshMinimapButton()
        Print("Minimap button is now hidden.")
    elseif input == "end" then
        self:EndRun("slash")
    elseif input:match("^runtime%s+") then
        local rest = input:match("^runtime%s+(.+)$")
        local code, minutes, seconds = rest:match("^([%w]%-[%w][%w][%w][%w][%w]%-[%w]+)%s+(%d+)%s+(%d+)$")
        if code then
            self:SetRunTimeOverride(code, minutes, seconds)
        else
            minutes, seconds = rest:match("^(%d+)%s+(%d+)$")
            if not minutes then
                minutes, seconds = rest:match("^(%d+)%s*m%s*(%d*)%s*s?$")
            end
            self:SetRunTimeOverride(nil, minutes, seconds)
        end
    elseif input == "delete" then
        self:DeleteRun(self:GetEditableRun(), "slash delete")
    elseif input:match("^delete%s+") then
        local token = input:match("^delete%s+(.+)$")
        local run = self:FindRunByCode(token) or self:GetRun(token)
        if run then
            self:DeleteRun(run, "slash delete")
        else
            Print("Run not found: " .. tostring(token))
        end
    elseif input == "bosses" then
        self:PrintBossStatus()
    elseif input == "splits" then
        self:PrintBossSplits()
    elseif input:match("^splits%s+") then
        self:PrintBossSplits(input:match("^splits%s+(.+)$"))
    elseif input:match("^boss%s+optional%s+") then
        self:SetBossOptional(input:match("^boss%s+optional%s+(.+)$"), true)
    elseif input:match("^boss%s+required%s+") then
        self:SetBossOptional(input:match("^boss%s+required%s+(.+)$"), false)
    elseif input == "icons" or input == "icons dump" then
        self:DumpInstanceIcons()
    elseif input == "catalog" then
        self:BuildExpansionCatalog()
    elseif input == "testapplicant" then
        self:PreviewApplicantAlert()
    elseif input == "debug" then
        self.db.debug = not self.db.debug
        Print("Debug is now " .. (self.db.debug and "on" or "off") .. ".")
        self:RefreshAllDisplays()
    elseif input == "fulldebug" or input == "debug full" then
        self.db.fullDebug = not self.db.fullDebug
        Print("Full debug is now " .. (self.db.fullDebug and "on" or "off") .. ".")
    elseif input == "debuglog" or input == "log" then
        self:PrintDebugLog()
    elseif input == "chatlog" or input == "chat log" then
        self:PrintRunChatLog()
    elseif input == "backfillplayers" then
        self:BackfillGroupedPlayersFromHistory(true)
    elseif input == "backfilldeaths" then
        self:BackfillDeathCountConsistency(true)
    elseif input == "duplicates" or input == "duplicateplayers" then
        self:FindDuplicatePlayerNames()
    elseif input == "mergeduplicates" then
        self:MergeKnownDuplicatePlayers()
        Print("Duplicate-player merge check complete.")
    elseif input == "theme" then
        self.db.uiTheme = (self.db.uiTheme == "arcane") and "classic" or "arcane"
        self:RefreshSettingsPanel()
        self:RefreshAllDisplays()
        Print("UI theme is now " .. self.db.uiTheme .. ". Type /reload to fully apply it to windows already open this session.")
    else
        self:PrintHelp()
    end
end

function Addon:RegisterSlashCommands()
    SLASH_MPLUSLEDGERCMD1 = "/dl"
    SLASH_MPLUSLEDGERCMD2 = "/mplusledger"
    SlashCmdList.MPLUSLEDGERCMD = function(input)
        Addon:HandleSlash(input)
    end
end

local LIVE_EVENT_GROUPS = {
    deaths = {
        "PLAYER_DEAD",
        "CHAT_MSG_SYSTEM",
        "CHAT_MSG_RAID_BOSS_EMOTE",
        "CHAT_MSG_MONSTER_EMOTE",
        "PLAYER_ALIVE",
        "PLAYER_UNGHOST",
    },
    repairs = {
        "CHAT_MSG_MONEY",
        "CHAT_MSG_SYSTEM",
        "MERCHANT_SHOW",
        "MERCHANT_CLOSED",
        "PLAYER_MONEY",
    },
    roster = {
        "GROUP_ROSTER_UPDATE",
        "PLAYER_ROLES_ASSIGNED",
    },
    rewards = {
        "LFG_COMPLETION_REWARD",
        "CHALLENGE_MODE_START",
        "CHALLENGE_MODE_COMPLETED",
        "CHALLENGE_MODE_RESET",
        "SCENARIO_COMPLETED",
        "SCENARIO_CRITERIA_UPDATE",
        "CHAT_MSG_LOOT",
    },
    bosses = {
        "ENCOUNTER_START",
        "ENCOUNTER_END",
        "BOSS_KILL",
    },
    -- Self-built loot database: correlates each looted item to its real source creature(s) via
    -- GetLootSourceInfo, independent of the per-run item log CHAT_MSG_LOOT already feeds. Confirmed
    -- unaffected by patch 12.0 (checked warcraft.wiki.gg's 12.0.0 API-changes page before adding).
    loot = {
        "LOOT_OPENED",
    },
    -- Cross-party Mythic+ sync (roadmap item 3): CHAT_MSG_ADDON carries the addon-message payload
    -- for MPlusLedgerMP. Registering it through this same group means it automatically gets the
    -- same restricted-registration retry (IsChatEventRegistrationRestricted/skippedChatEvents)
    -- every other CHAT_MSG_* event here already has, without writing that logic a second time.
    partySync = {
        "CHAT_MSG_ADDON",
    },
    -- COMBAT_LOG_EVENT_UNFILTERED was removed for addons in patch 12.0 (Midnight); attempting to
    -- register it now triggers Blizzard's forbidden-action popup rather than silently no-opping.
    -- Mob-kill tracking moved to PARTY_KILL/UNIT_DIED/PLAYER_TARGET_DIED (see eventFrame setup
    -- near the bottom of this file), which are registered independently of this group, so this
    -- group is intentionally left empty rather than removed (keeps /dl live mobs from erroring).
    mobs = {
    },
    chat = {
        "CHAT_MSG_SYSTEM",
        "CHAT_MSG_RAID_BOSS_EMOTE",
        "CHAT_MSG_MONSTER_EMOTE",
        "CHAT_MSG_MONSTER_SAY",
        "CHAT_MSG_MONSTER_YELL",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_LOOT",
        "CHAT_MSG_MONEY",
    },
    -- 2026-09-04: warn as soon as a Bad-rated player *applies* to a Premade Groups listing, not
    -- just once they've already joined the party. Fires whenever the applicant list changes (new
    -- application, status change, etc.) -- verified against Blizzard's own event docs.
    lfgApplicants = {
        "LFG_LIST_APPLICANT_LIST_UPDATED",
        "LFG_LIST_APPLICANT_UPDATED",
        "LFG_LIST_ACTIVE_ENTRY_UPDATE",
    },
}

local RUN_CHAT_EVENTS = {
    CHAT_MSG_SYSTEM = true,
    CHAT_MSG_RAID_BOSS_EMOTE = true,
    CHAT_MSG_MONSTER_EMOTE = true,
    CHAT_MSG_MONSTER_SAY = true,
    CHAT_MSG_MONSTER_YELL = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_INSTANCE_CHAT = true,
    CHAT_MSG_INSTANCE_CHAT_LEADER = true,
    CHAT_MSG_LOOT = true,
    CHAT_MSG_MONEY = true,
}

-- Patch 12.0.5 added a "Chat" addon restriction (Enum.AddOnRestrictionType.Chat) that activates
-- on communication-restricted maps (Delves appear to qualify). IsEventValid() doesn't catch this
-- -- the event name is perfectly valid, registering for it is just temporarily forbidden -- so it
-- needs its own check.
function Addon:IsChatEventRegistrationRestricted()
    if not C_RestrictedActions or not C_RestrictedActions.GetAddOnRestrictionState then
        return false
    end
    if not Enum or not Enum.AddOnRestrictionType or not Enum.AddOnRestrictionType.Chat then
        return false
    end
    local ok, state = pcall(C_RestrictedActions.GetAddOnRestrictionState, Enum.AddOnRestrictionType.Chat)
    if not ok or state == nil then
        return false
    end
    local activeState = Enum.AddOnRestrictionState and Enum.AddOnRestrictionState.Active
    return activeState ~= nil and state == activeState
end

function Addon:RetrySkippedChatEvents()
    if not self.skippedChatEvents or #self.skippedChatEvents == 0 then
        return
    end
    if self:IsChatEventRegistrationRestricted() then
        return
    end
    local pending = self.skippedChatEvents
    self.skippedChatEvents = {}
    for _, eventName in ipairs(pending) do
        local ok, err = pcall(self.eventFrame.RegisterEvent, self.eventFrame, eventName)
        if ok then
            Debug("Retried and registered previously chat-restricted event " .. tostring(eventName))
        else
            Debug("Retry failed to register event " .. tostring(eventName) .. ": " .. tostring(err))
        end
    end
end

function Addon:RegisterEventList(groupName, events)
    if not self.eventFrame then
        return
    end

    self.liveEventGroups = self.liveEventGroups or {}
    if self.liveEventGroups[groupName] then
        Print("Live " .. groupName .. " tracking is already enabled.")
        return
    end

    for _, eventName in ipairs(events or {}) do
        if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(eventName) then
            Debug("Skipping invalid/unavailable event " .. tostring(eventName) .. " for group " .. tostring(groupName))
        elseif tostring(eventName):match("^CHAT_MSG_") and self:IsChatEventRegistrationRestricted() then
            Debug("Skipping " .. tostring(eventName) .. " for group " .. tostring(groupName) .. " -- chat restriction currently active, will retry later")
            self.skippedChatEvents = self.skippedChatEvents or {}
            table.insert(self.skippedChatEvents, eventName)
        else
            local ok, err = pcall(self.eventFrame.RegisterEvent, self.eventFrame, eventName)
            if not ok then
                Debug("Failed to register event " .. tostring(eventName) .. " for group " .. tostring(groupName) .. ": " .. tostring(err))
            end
        end
    end
    self.liveEventGroups[groupName] = true
    Debug("Live event group registered: " .. tostring(groupName))
    if not self.suppressLiveEventMessages then
        Print("Live " .. groupName .. " tracking enabled for this session.")
    end
end

function Addon:RegisterGameplayEvents()
    for name, events in pairs(LIVE_EVENT_GROUPS) do
        self:RegisterEventList(name, events)
    end
end

function Addon:OnLoaded()
    -- Saved data lived in InstanceLedgerDB before the 2026-10-08 rename to MPlusLedgerDB. Carry it
    -- over once, then drop the old variable so it isn't written out a second time on logout.
    if MPlusLedgerDB == nil and InstanceLedgerDB ~= nil then
        MPlusLedgerDB = InstanceLedgerDB
    end
    InstanceLedgerDB = nil
    MPlusLedgerDB = CopyDefaults(MPlusLedgerDB, DEFAULTS)
    self.db = MPlusLedgerDB
    if self.db.mainSort == "expansion" or self.db.mainSort == "season" then
        self.db.mainView = self.db.mainSort
        self.db.mainSort = "highestKey"
    elseif self.db.mainSort == "difficulty" or self.db.mainSort == "partyDeaths" or self.db.mainSort == "playerDeaths" or self.db.mainSort == "bestTime" or self.db.mainSort == "completed" then
        self.db.mainSort = "highestKey"
    end
    self.db.mainView = self.db.mainView or "currentSeason"
    if (self.db.lastRepairWindow or 0) ~= 300 then
        self.db.lastRepairWindow = 300
    end
    if self.db.seasonSortDefaultVersion ~= "0.1.105" then
        self.db.mainView = self.db.mainView or "currentSeason"
        self.db.mainSort = self.db.mainSort or "highestKey"
        self.db.seasonSortDefaultVersion = "0.1.105"
    end
    self.lastKnownMoney = GetMoney and GetMoney() or nil
    self.db.tracker = self.db.tracker or CopyDefaults({}, DEFAULTS.tracker)
    -- One-time height fixup for the Enemy Forces bar's removal (2026-09-16): DEFAULTS.tracker only
    -- applies to a brand-new install, so an existing user's saved tracker.height would otherwise
    -- stay at the old 132 forever, leaving a blank gap where that bar used to be. Only touches it
    -- if it's still exactly the old default -- if the user ever manually resized the bar, their
    -- own choice is left alone rather than silently overwritten.
    if self.db.tracker.height == 132 then
        self.db.tracker.height = 108
    end
    self.db.minimap = CopyDefaults(self.db.minimap, DEFAULTS.minimap)
    if self.db.displayRecoveryVersion ~= ADDON_VERSION then
        self.db.displayRecoveryVersion = ADDON_VERSION
        self.db.minimap.shown = true
        self.db.tracker.shown = true
    end
    self:HookRepairs()
    self:HookChatRepairMessages()
    self:RegisterSlashCommands()
    self:RegisterMythicPlusSyncPrefix()
    self:InitInterruptTracking()
    self:CreateSettingsPanel()
    self:ReconcileSavedCompletions()
    self:CleanupContaminatedCustomBossMaps()
    self:FixZiekketNameTypo()
    self:PruneBloatedDebugLogEntries()
    self:BackfillGroupedPlayersFromHistory()
    self:BackfillDeathCountConsistency()
    self:MergeKnownDuplicatePlayers()
    self.db.liveEvents = true
    self.suppressLiveEventMessages = true
    self:RegisterGameplayEvents()
    self.suppressLiveEventMessages = false
    Print("Safe live dungeon tracking loaded automatically.")
    Print("Loaded v" .. ADDON_VERSION .. ". Type /dl to open, or /dl minimap to show the minimap button.")
    self:RestorePersistentDisplayOptionsDelayed("addon load")
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            Addon:RestorePersistentDisplayOptionsDelayed("auto scan")
            Addon:QueueInstanceScan("auto scan")
        end)
        C_Timer.After(5, function()
            Addon:PollForMissedDeaths()
        end)
    end
end

-- Closing every ledger window when a Blizzard panel opens -- per user request 2026-10-01 ("when
-- we open a blizzard menu like achievements, dungeon finder, settings menu etc. the addon closes
-- out completely as well"). ShowUIPanel is the shared entry point almost every stock Blizzard
-- panel calls to display itself (Achievements, Dungeon/Raid Finder, Character, Collections,
-- Encounter Journal, Guild, Auction House, Mail...), so one hook covers all of them without
-- listing every frame by name; it's part of UIParent.lua, loaded with the base UI, so this is safe
-- to hook at file-load time rather than waiting for an event.
if type(ShowUIPanel) == "function" then
    hooksecurefunc("ShowUIPanel", function()
        Addon:CloseAllWindows()
    end)
end

local eventFrame = CreateFrame("Frame")
Addon.eventFrame = eventFrame
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pcall(eventFrame.RegisterEvent, eventFrame, "ADDON_RESTRICTION_STATE_CHANGED")

-- PARTY_KILL/UNIT_DIED/PLAYER_TARGET_DIED are registered from RegisterDeathSignalEvents() (called
-- during OnLoaded, in response to ADDON_LOADED) rather than here at raw file-parse time -- PursuitLog
-- (same folder, confirmed working on this patch) registers them from its init function, not at file
-- load, and registering too early may silently no-op for some events.
function Addon:RegisterDeathSignalEvents()
    if self.deathSignalEventsRegistered then
        return
    end
    self.deathSignalEventsRegistered = true
    for _, eventName in ipairs({ "PARTY_KILL", "UNIT_DIED", "PLAYER_TARGET_DIED" }) do
        local ok, err = pcall(self.eventFrame.RegisterEvent, self.eventFrame, eventName)
        if ok then
            Debug("Registered death-signal event " .. eventName)
        else
            Debug("Failed to register death-signal event " .. eventName .. ": " .. tostring(err))
        end
    end
end

-- Patch 12.0 (Midnight) removed COMBAT_LOG_EVENT_UNFILTERED for addons and replaced it with
-- PARTY_KILL / UNIT_DIED / PLAYER_TARGET_DIED. Their exact argument signatures aren't fully
-- documented, so scan every argument for whichever one looks like a unit GUID (or resolves a
-- unit token like "target" into one). All three events can fire for the same death, so dedup by
-- GUID for a short window.
--
-- CORRECTION (2026-09-01): this used to cite PursuitLog (same project folder) as "proven working"
-- precedent for this exact GUID-scanning technique. That was misleading -- checked PursuitLog's
-- own Tracking.lua directly: its ExtractGUID is structurally identical to this and has NO
-- issecretvalue() guard at all, but PursuitLog is a rare-spawn/pet farming tracker, used almost
-- exclusively in open-world content, never inside an active Mythic+ run. Per Blizzard's own patch
-- notes, Secret Value restrictions on unit GUIDs apply specifically during a boss encounter or
-- Mythic+ run -- the one context PursuitLog's code has essentially never been exercised in. Its
-- working track record was never actually evidence this technique survives the restricted
-- context M+ Ledger specifically needs it for; see RecordMobKillByName below for the real
-- fallback once GUIDs are confirmed unreadable there (found live, v0.1.168).
local recentMobDeathGUIDs = {}
-- Name-keyed sibling for the no-GUID-available fallback (RecordMobKillByName) -- without a GUID
-- there's nothing to key recentMobDeathGUIDs by, but PARTY_KILL/UNIT_DIED/PLAYER_TARGET_DIED can
-- still all fire for the same single kill, so this needs its own dedup or one kill triple-counts.
local recentMobDeathNames = {}

-- IsSecret/SafeUnitGUID are defined near GetNPCIDFromGUID, early in the file, since
-- GetGroupRoster's own UnitGUID() capture needs them too -- see that definition for why.
local function ExtractDeathGUID(source, ...)
    -- Found 2026-09-04: PARTY_KILL's payload is (attackerGUID, targetGUID) -- verified against
    -- Blizzard's 12.0 API-change notes -- so arg 1 is always the unit that landed the kill, never
    -- the one that died. Skipping straight to arg 2 for this one event stops a party member's own
    -- GUID (now matchable below, see the regex note) from ever being picked up as "the unit that
    -- died" every time they get a killing blow on a mob.
    local startIndex = (source == "PARTY_KILL") and 2 or 1
    for i = startIndex, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" and not IsSecret(v) then
            -- This pattern used to require 5 consecutive decimal segments before matching, which
            -- only a Creature/Vehicle-style GUID ("Creature-0-1465-0-2105-448-000043F59F", 7
            -- segments) has. A Player GUID ("Player-3721-0C49FB85", verified against Blizzard's own
            -- UnitGUID docs) has just 3 segments and never matched -- so a raw player GUID handed
            -- back by PARTY_KILL/UNIT_DIED (confirmed via Blizzard's 12.0 API-change notes: both
            -- events hand back raw unitGUID strings, not unit tokens) was silently discarded every
            -- time, and the "target" fallback below deliberately excludes players -- so another
            -- party member's death had no path to ever be identified. Loosened to the shortest
            -- prefix every WoW GUID type shares (Type-decimalSegment-), which still rejects anything
            -- that isn't GUID-shaped.
            if v:match("^%a+%-%d+%-") then
                return v
            elseif UnitExists(v) then
                return SafeUnitGUID(v)
            end
        end
    end
    return nil
end

-- Must be called synchronously from the event handler: "target" can move on to a new unit
-- almost immediately, so resolving the name later (e.g. from a deferred callback) usually fails.
--
-- Found 2026-09-04 (Mob & Boss Browser showing no models): this required SafeUnitGUID("target") to
-- equal the death event's own guid before trusting "target" -- but SafeUnitGUID("target") returns
-- nil whenever UnitGUID("target") itself is a Secret Value, which is confirmed to happen for
-- hostile units throughout an active M+ run (this addon's primary use case). guid here comes from
-- the death event's raw args, which are NOT secret even when the live UnitGUID() call is -- so
-- nil == guid was false every single time during M+, silently skipping name/model capture for
-- every trash mob. Now only rejects when the live GUID is actually readable AND disagrees --
-- a secret live GUID can't disprove the match, so it's trusted the same way the rest of this file
-- already trusts "target" being the unit that just died (see ExtractDeathGUID's own target
-- fallback above).
local function IsLikelyStillTargetedUnit(guid)
    if not guid or IsSecret(guid) or not UnitExists("target") then
        return false
    end
    local liveGuid = SafeUnitGUID("target")
    return not liveGuid or liveGuid == guid
end

local function ResolveNameIfTarget(guid)
    if IsLikelyStillTargetedUnit(guid) then
        -- UnitName("target") can be a Secret Value during an active key; callers string-process the
        -- name (StripWowText/GetPlayerProfileKey), so return nil and let them use the roster name.
        local name = UnitName("target")
        if name and not IsSecret(name) then
            return name
        end
    end
    return nil
end

-- Same "target" window as ResolveNameIfTarget, used to capture a Mob & Boss Browser model preview
-- for trash mobs (bosses get theirs from the boss1-8 tokens in GetEncounterNPCIDs instead).
local function CaptureDisplayIDIfTarget(guid)
    if IsLikelyStillTargetedUnit(guid) then
        return Addon:CaptureUnitDisplayID("target")
    end
    return nil
end

local function FindGroupUnitToken(guid)
    if not guid or IsSecret(guid) then
        return nil
    end
    if SafeUnitGUID("player") == guid then
        return "player"
    end
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local unit = "raid" .. index
            if SafeUnitGUID(unit) == guid then
                return unit
            end
        end
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            local unit = "party" .. index
            if SafeUnitGUID(unit) == guid then
                return unit
            end
        end
    end
    return nil
end

-- Best-effort killer attribution: there's no combat log to read who landed the final blow
-- (removed for addons in patch 12.0), so this takes whatever the dying member was targeting at
-- the moment of death as a guess. Works well against a single mob, unreliable in AOE pulls or
-- if they'd already switched targets -- "(if possible)" per the addon's own mission statement.
local function GetLikelyKillerForUnit(guid)
    local unit = FindGroupUnitToken(guid)
    if not unit then
        return nil, nil
    end
    local targetUnit = unit .. "target"
    if not UnitExists(targetUnit) or UnitIsPlayer(targetUnit) then
        return nil, nil
    end
    -- pcall-wrapped, not called directly -- found during the 2026-09-04 full-file audit: every
    -- call site of this function is OUTSIDE any pcall, so an unguarded UnitName() throwing here
    -- (confirmed possible during M+ this session) would abort the entire death-recording call
    -- before RecordMemberDeathByGUID/ByName ever ran -- losing the whole death record, not just
    -- this best-effort "who killed them" guess.
    local nameOk, killerName = pcall(UnitName, targetUnit)
    if not nameOk or IsSecret(killerName) then
        killerName = nil
    end
    local killerNPCID = GetNPCIDFromGUID(SafeUnitGUID(targetUnit))
    return killerName, killerNPCID
end

function Addon:HandleUnitDeathSignal(source, ...)
    local argCount = select("#", ...)
    -- v0.1.165 diagnostic: v0.1.160 stopped the Secret Value crash, but a live test (2026-09-01,
    -- v0.1.164) showed guid=nil on every firing with no error at all -- ExtractDeathGUID found
    -- nothing usable AND the "target" fallback also came up empty. The old log line only recorded
    -- argCount/firstArgType, which can't distinguish "wrongly judged secret" from "genuinely not a
    -- GUID-shaped string" from "target already cleared by the time this ran." Dump all three.
    local dumpOk, dump = pcall(function(...)
        local parts = {}
        for i = 1, argCount do
            local v = select(i, ...)
            local vType = type(v)
            if vType == "string" then
                if IsSecret(v) then
                    parts[i] = string.format("[%d]=<secret>", i)
                else
                    parts[i] = string.format("[%d]=%q", i, v)
                end
            else
                parts[i] = string.format("[%d]=%s(%s)", i, tostring(v), vType)
            end
        end
        return table.concat(parts, ", ")
    end, ...)
    local targetExists = UnitExists("target")
    FullDebug(source .. ": args=[" .. (dumpOk and dump or ("<dump error: " .. tostring(dump) .. ">"))
        .. "] target(exists=" .. tostring(targetExists) .. ",isPlayer=" .. tostring(targetExists and UnitIsPlayer("target")) .. ")")
    local ok, guid, name, displayID = pcall(function(...)
        local extractedGuid = ExtractDeathGUID(source, ...)
        if not extractedGuid and UnitExists("target") and not UnitIsPlayer("target") then
            -- PARTY_KILL/UNIT_DIED don't reliably hand back a usable GUID argument on this
            -- patch (confirmed via debug logging: consistently nil), but the dead unit is
            -- almost always still your current target for a moment after it dies, the same
            -- fallback PLAYER_TARGET_DIED already uses successfully.
            extractedGuid = SafeUnitGUID("target")
        end
        return extractedGuid, ResolveNameIfTarget(extractedGuid), CaptureDisplayIDIfTarget(extractedGuid)
    end, ...)
    if not ok then
        Debug(source .. ": error reading event args (argCount=" .. tostring(argCount) .. "): " .. tostring(guid))
        return
    end
    FullDebug(source .. ": argCount=" .. tostring(argCount) .. " guid=" .. tostring(guid) .. " name=" .. tostring(name))
    if not guid then
        -- Confirmed 2026-09-01 via live debug dump: UnitGUID("target") itself can be a genuine
        -- Secret Value during an active M+ run, not just the raw PARTY_KILL/UNIT_DIED event args
        -- -- there is no way to recover a GUID at all in that case, for any unit, by any method.
        -- Without a GUID there's no npcID to key the normal mobKills table by (GetNPCIDFromGUID
        -- parses it out of the GUID string), so fall back to tracking by name if the target's name
        -- is actually readable -- names don't appear to carry the same Secret Value protection.
        -- Same "still very likely the unit that just died" assumption the GUID fallback above
        -- already relies on (this runs synchronously from the event, no deferred callback), just
        -- with no GUID left to double-check identity against.
        -- Found via code review 2026-09-05: this used to gate name resolution behind
        -- `not UnitIsPlayer("target")`, so a dying PARTY MEMBER never got a name fallback at all
        -- here -- only mobs did. Tried resolving the name for a player target too and recording a
        -- member death when it matched the roster -- but a live test (2026-09-05, Ruby Life
        -- Pools) showed deaths going missing for some players while others got an inflated count,
        -- which is exactly what this change would cause: PARTY_KILL/UNIT_DIED fire for ANY unit's
        -- death, not necessarily your current target (unlike PLAYER_TARGET_DIED, which specifically
        -- means "your target just died"). A healer keeping a teammate targeted to heal them, with
        -- some OTHER unit dying elsewhere at the same moment its GUID happens to be unreadable,
        -- would misattribute that death to whoever they had targeted -- inflating that person's
        -- count while the real death (elsewhere) goes unrecorded. Restricted to PLAYER_TARGET_DIED
        -- only, where "target" being the dead unit is actually guaranteed, not just assumed --
        -- narrower than hoped, but the only case this fallback can be trusted for a player.
        local targetName = nil
        if UnitExists("target") then
            local nameOk, rawName = pcall(UnitName, "target")
            if not nameOk then
                FullDebug(source .. ": UnitName(target) errored: " .. tostring(rawName))
            elseif not rawName then
                FullDebug(source .. ": UnitName(target) returned nil/false")
            elseif IsSecret(rawName) then
                FullDebug(source .. ": UnitName(target) is itself a secret value")
            else
                targetName = rawName
            end
        end
        FullDebug(source .. ": guid unavailable, name fallback = " .. tostring(targetName))
        if targetName then
            local normalizedTargetName = string.lower(StripWowText(targetName))
            local nowName = GetTime and GetTime() or time()
            if recentMobDeathNames[normalizedTargetName] and (nowName - recentMobDeathNames[normalizedTargetName]) < 1 then
                return
            end
            local fallbackRun = self:GetCurrentRun()
            local member = (source == "PLAYER_TARGET_DIED") and fallbackRun and self:GetMemberByName(fallbackRun, targetName)
            if member then
                recentMobDeathNames[normalizedTargetName] = nowName
                local killerName, killerNPCID = GetLikelyKillerForUnit(member.guid)
                self:RecordMemberDeathByName(targetName, source, killerName, killerNPCID)
            elseif not UnitIsPlayer("target") then
                recentMobDeathNames[normalizedTargetName] = nowName
                local fallbackDisplayID = self:CaptureUnitDisplayID("target")
                self:RecordMobKillByName(targetName, source, fallbackDisplayID)
            end
        end
        return
    end
    local now = GetTime and GetTime() or time()
    if recentMobDeathGUIDs[guid] and (now - recentMobDeathGUIDs[guid]) < 1 then
        return
    end
    recentMobDeathGUIDs[guid] = now

    local run = self:GetCurrentRun()
    if run and self:GetMemberByGUID(run, guid) then
        local killerName, killerNPCID = GetLikelyKillerForUnit(guid)
        self:RecordMemberDeathByGUID(guid, name, source, killerName, killerNPCID)
    elseif run and name and self:GetMemberByName(run, name) then
        local member = self:GetMemberByName(run, name)
        local killerName, killerNPCID = member and GetLikelyKillerForUnit(member.guid)
        self:RecordMemberDeathByName(name, source, killerName, killerNPCID)
    else
        self:RecordMobKillByGUID(guid, name, source, displayID)
    end
end

-- Mob-side counterpart to Addon:UpdateUnitHealthWatchers (players), per user follow-up question
-- ("is this able to track mob deaths?"). Same RegisterUnitEvent("UNIT_HEALTH", ...) technique,
-- watching nameplate1-40 instead of party/raid tokens -- unlike party members, nameplate tokens
-- are always valid strings regardless of what's currently occupying them, so this only needs
-- registering once (not re-registered on roster change the way the player watcher is).
--
-- Deliberately best-effort, not exhaustive: a nameplate only exists for a mob that's currently
-- on-screen, in range, and not hidden by the player's own nameplate visibility settings --
-- unlike party/raid tokens, which always exist for the whole group regardless of visibility. A
-- mob that dies off-screen, out of range, or before its nameplate ever renders won't be caught
-- here. Complements the existing UNIT_DIED/PARTY_KILL mob-kill path above, doesn't replace it --
-- shares the same recentMobDeathGUIDs throttle so the two can't double-count the same kill.
local NAMEPLATE_HEALTH_WATCHER_FRAMES = {}
function Addon:UpdateNameplateHealthWatchers()
    if self.nameplateHealthWatchersRegistered then
        return
    end
    self.nameplateHealthWatchersRegistered = true

    local units = {}
    for i = 1, 40 do
        table.insert(units, "nameplate" .. i)
    end

    local frameIndex = 1
    for i = 1, #units, 4 do
        local chunk = {}
        for j = i, math.min(i + 3, #units) do
            table.insert(chunk, units[j])
        end
        local watcherFrame = NAMEPLATE_HEALTH_WATCHER_FRAMES[frameIndex]
        if not watcherFrame then
            watcherFrame = CreateFrame("Frame")
            watcherFrame:SetScript("OnEvent", function(_, _, unit)
                Addon:CheckNameplateForMissedMobKill(unit)
            end)
            NAMEPLATE_HEALTH_WATCHER_FRAMES[frameIndex] = watcherFrame
        end
        local ok, err = pcall(watcherFrame.RegisterUnitEvent, watcherFrame, "UNIT_HEALTH", unpack(chunk))
        if not ok then
            Debug("UpdateNameplateHealthWatchers: RegisterUnitEvent failed: " .. tostring(err))
        end
        frameIndex = frameIndex + 1
    end
end

function Addon:CheckNameplateForMissedMobKill(unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then
        return
    end
    if not UnitIsDeadOrGhost(unit) then
        return
    end
    local guid = SafeUnitGUID(unit)
    if not guid then
        -- Was a silent return with zero logging -- confirmed live 2026-09-10 that this path fails
        -- exactly like the PARTY_KILL/UNIT_DIED one does (nameplate GUIDs are secret-valued too,
        -- not just "target"'s). Found via this exact log line, THEN found the log line itself was
        -- crowding out other diagnostics: UNIT_HEALTH fires repeatedly per nameplate while a mob
        -- sits dead before its nameplate despawns, so this was logging many times per single kill
        -- -- 55+ entries in one short session, enough to roll a manually-run /dl scenario dump
        -- (needed for a since-closed Enemy Forces investigation -- that feature was removed
        -- 2026-09-16) out of the debugLog's
        -- 600-entry cap before it could be read. Throttled to once per nameplate token per 5s --
        -- still proves the failure happens, without dominating the log.
        self.recentNameplateGuidFailureLogAt = self.recentNameplateGuidFailureLogAt or {}
        local nowLog = GetTime and GetTime() or time()
        if not self.recentNameplateGuidFailureLogAt[unit] or (nowLog - self.recentNameplateGuidFailureLogAt[unit]) >= 5 then
            self.recentNameplateGuidFailureLogAt[unit] = nowLog
            FullDebug("CheckNameplateForMissedMobKill: guid unavailable for " .. tostring(unit))
        end
        return
    end
    local now = GetTime and GetTime() or time()
    if recentMobDeathGUIDs[guid] and (now - recentMobDeathGUIDs[guid]) < 1 then
        return
    end
    recentMobDeathGUIDs[guid] = now

    local run = self:GetCurrentRun()
    if run and self:GetMemberByGUID(run, guid) then
        -- A player's nameplate (PvP, or a party member's own) -- not this watcher's concern, the
        -- player-side UpdateUnitHealthWatchers already covers them via party/raid tokens.
        return
    end
    local nameOk, name = pcall(UnitName, unit)
    if not nameOk or IsSecret(name) then
        name = nil
    end
    local displayID = self:CaptureUnitDisplayID(unit)
    self:RecordMobKillByGUID(guid, name, "nameplate health watcher (instant)", displayID)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    -- Patch 12.0 can deliver CHAT_MSG_* payloads as Secret Values on communication-restricted
    -- maps; string operations on those throw/are forbidden, so bail before touching the message.
    if type(event) == "string" and event:match("^CHAT_MSG_") and issecretvalue and issecretvalue((...)) then
        return
    end

    if RUN_CHAT_EVENTS[event] then
        Addon:RecordRunChatEvent(event, ...)
    end

    if MPlusLedgerDB and MPlusLedgerDB.fullDebug then
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" or event == "LFG_COMPLETION_REWARD" or event == "PLAYER_REGEN_ENABLED" then
            FullDebug("Event: " .. tostring(event))
        end
    end

    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName == ADDON_NAME then
            -- pcall-wrapped as of v0.1.265: found live (2026-09-10) that a totally separate class
            -- of failure -- Core.lua hitting Lua's hard 200-local-per-chunk compile limit as the
            -- file grew -- made the WHOLE FILE fail to load, with zero visible error and nothing
            -- in this addon's own debugLog (since Debug() itself never got a chance to run). A
            -- syntax error like that can't be caught by a pcall here (the file never parses far
            -- enough to reach this line at all), but a RUNTIME error inside OnLoaded() itself
            -- would previously have silently aborted every one of its later steps (minimap button,
            -- slash commands, event registration, etc.) the exact same invisible way. This at least
            -- turns that second failure mode into a loud, visible chat error instead of "nothing
            -- happens and there's no clue why."
            local ok, err = pcall(Addon.OnLoaded, Addon)
            if not ok then
                Print("|cffff3333M+ Ledger failed to load: " .. tostring(err) .. "|r")
            end
            FullDebug("Loaded full debug mode. ADDON_NAME=" .. tostring(ADDON_NAME) .. " VERSION=" .. tostring(ADDON_VERSION))
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        Debug("Queued automatic instance scan for " .. tostring(event))
        Addon:RestorePersistentDisplayOptionsDelayed(event)
        Addon:QueueInstanceScan(event)
        Addon:RegisterDeathSignalEvents()
        Addon:UpdateUnitHealthWatchers()
        Addon:UpdateNameplateHealthWatchers()
        -- The ESC game menu and the modern Settings panel don't reliably go through ShowUIPanel
        -- (see that hook, above), so they get their own direct OnShow hooks instead -- attempted
        -- on every PLAYER_ENTERING_WORLD until both are found, since SettingsPanel in particular
        -- can be a load-on-demand frame that doesn't exist yet on the very first login/reload.
        if not Addon.blizzardPanelCloseHooksDone then
            local allHooked = true
            for _, frameName in ipairs({ "GameMenuFrame", "SettingsPanel" }) do
                local panelFrame = _G[frameName]
                if panelFrame and panelFrame.HookScript and not panelFrame.ledgerCloseHooked then
                    panelFrame.ledgerCloseHooked = true
                    panelFrame:HookScript("OnShow", function()
                        Addon:CloseAllWindows()
                    end)
                elseif not panelFrame then
                    allHooked = false
                end
            end
            Addon.blizzardPanelCloseHooksDone = allHooked
        end
    elseif event == "PLAYER_DEAD" then
        Addon:RecordDeath()
    elseif event == "PARTY_KILL" or event == "UNIT_DIED" then
        Addon:HandleUnitDeathSignal(event, ...)
    elseif event == "PLAYER_TARGET_DIED" then
        Addon:HandleUnitDeathSignal(event, "target")
    elseif event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_RAID_BOSS_EMOTE" or event == "CHAT_MSG_MONSTER_EMOTE" then
        Addon:RecordRepairCostFromMessage(..., "repair cost chat event")
        if event == "CHAT_MSG_SYSTEM" then
            Addon:HandleSystemTimerMessage(...)
        end
        Debug("Death chat event " .. tostring(event) .. ": " .. tostring((...)))
        Addon:HandleSystemDeathMessage(...)
    elseif event == "CHAT_MSG_MONEY" then
        if not Addon:RecordRepairCostFromMessage(..., "repair cost money event") then
            Addon:RecordMoneyLoot(...)
        end
    elseif event == "CHAT_MSG_LOOT" then
        Addon:RecordItemLoot(...)
    elseif event == "LOOT_OPENED" then
        Addon:RecordLootDrops()
    elseif event == "CHAT_MSG_ADDON" then
        Addon:HandleMythicPlusSyncMessage(...)
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        Addon.deathPending = false
    elseif event == "MERCHANT_SHOW" then
        Addon.repairMerchantOpen = true
        Addon:CaptureRepairQuote()
        Addon:QueueMerchantOpenRepairCheck()
    elseif event == "MERCHANT_CLOSED" then
        Addon:CheckRepairQuoteSettled()
        Addon.repairMerchantOpen = false
        Addon.merchantMoneySnapshot = nil
        Addon.pendingRepairCost = 0
        Addon.pendingRepairAt = nil
    elseif event == "PLAYER_MONEY" then
        Addon:HandleMoneyChanged()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        Addon:UpdateGroupRoster(event)
        Addon:UpdateUnitHealthWatchers()
    elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED" or event == "LFG_LIST_APPLICANT_UPDATED" or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        Addon:CheckLFGApplicantsForRatedPlayers()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Addon:FlushDeferredUi()
        Addon:RetrySkippedChatEvents()
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        Addon:RetrySkippedChatEvents()
    elseif event == "CHALLENGE_MODE_START" then
        Addon:MarkRunTimerStarted(event)
        Addon:QueueChallengeModeRefresh(event)
        Addon:QueueRosterRefresh(event)
    elseif event == "SCENARIO_COMPLETED" then
        Addon:HandleScenarioCompletedEvent(event)
    elseif event == "SCENARIO_CRITERIA_UPDATE" then
        Addon:CheckScenarioCriteriaCompletion(event)
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        Addon:RecordEncounterStart(encounterID, encounterName)
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, endStatus = ...
        Addon:RecordEncounterEnd(encounterID, encounterName, endStatus)
    elseif event == "BOSS_KILL" then
        local encounterID, encounterName = ...
        Addon:RecordBossKill(encounterID, encounterName)
    elseif event == "LFG_COMPLETION_REWARD" or event == "CHALLENGE_MODE_COMPLETED" then
        Addon:RefreshChallengeModeInfo(event)
        Addon:MarkCurrentRunCompleted(event)
    elseif event == "CHALLENGE_MODE_RESET" then
        Addon:HandleChallengeModeReset(event)
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local addonName, blockedAction, arg3, arg4 = ...
        local message = string.format(
            "%s addon=%s action=%s extra=%s %s",
            tostring(event),
            tostring(addonName or "unknown"),
            tostring(blockedAction or "unknown"),
            tostring(arg3 or ""),
            tostring(arg4 or "")
        )
        Debug(message)
        Print(message)
    end
end)
