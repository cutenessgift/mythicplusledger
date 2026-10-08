-- All Runs reference layout. Data and interaction remain native WoW widgets.
local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local gold=S.colors.gold
-- Shared catalogue of installed dungeon backgrounds.
local art={
 ["Ahn'kahet: The Old Kingdom"]="AhnkahetTheOldKingdom",
 ["Ahn’kahet: The Old Kingdom"]="AhnkahetTheOldKingdom",
 ["Algeth'ar Academy"]="AlgetharAcademy",
 ["Algeth’ar Academy"]="AlgetharAcademy",
 ["Altar of Fangs"]="AltarOfFangs",
 ["Ara-Kara, City of Echoes"]="AraKara",
 ["Assault on Violet Hold"]="AssaultonVioletHold",
 ["Atal'Dazar"]="AtalDazar",
 ["Atal’Dazar"]="AtalDazar",
 ["Auchenai Crypts"]="AuchenaiCrypts",
 ["Auchindoun"]="Auchindoun",
 ["Azjol-Nerub"]="AzjolNerub",
 ["Black Rook Hold"]="BlackRookHold",
 ["Blackfathom Deeps"]="BlackfathomDeeps",
 ["Blackrock Caverns"]="BlackrockCaverns",
 ["Blackrock Depths"]="BlackrockDepths",
 ["Bloodmaul Slag Mines"]="BloodmaulSlagMines",
 ["Brackenhide Hollow"]="BrackenhideHollow",
 ["Cathedral of Eternal Night"]="CathedralofEternalNight",
 ["Cinderbrew Meadery"]="CinderbrewMeadery",
 ["City of Threads"]="CityOfThreads",
 ["Court of Stars"]="CourtofStars",
 ["Darkflame Cleft"]="DarkflameCleft",
 ["Darkheart Thicket"]="DarkheartThicket",
 ["Dawn of the Infinite"]="DawnoftheInfinite",
 ["Dawn of the Infinite: Galakrond's Fall"]="DawnoftheInfinite",
 ["Dawn of the Infinite: Galakrond’s Fall"]="DawnoftheInfinite",
 ["Dawn of the Infinite: Murozond's Rise"]="DawnoftheInfinite",
 ["Dawn of the Infinite: Murozond’s Rise"]="DawnoftheInfinite",
 ["De Other Side"]="DeOtherSide",
 ["Deadmines"]="Deadmines",
 ["Den of Nalorakk"]="DenOfNalorakk",
 ["Dire Maul - Capital Gardens"]="DireMaulCapitalGardens",
 ["Dire Maul - Gordok Commons"]="DireMaulGordokCommons",
 ["Dire Maul - Warpwood Quarter"]="DireMaulWarpwoodQuarter",
 ["Dire Maul – Capital Gardens"]="DireMaulCapitalGardens",
 ["Dire Maul – Gordok Commons"]="DireMaulGordokCommons",
 ["Dire Maul – Warpwood Quarter"]="DireMaulWarpwoodQuarter",
 ["Drak'Tharon Keep"]="DrakTharonKeep",
 ["Drak’Tharon Keep"]="DrakTharonKeep",
 ["Eco-Dome Al'dani"]="EcoDomeAldani",
 ["Eco-Dome Al’dani"]="EcoDomeAldani",
 ["End Time"]="EndTime",
 ["Eye of Azshara"]="EyeofAzshara",
 ["Freehold"]="Freehold",
 ["Gate of the Setting Sun"]="GateoftheSettingSun",
 ["Gnomeregan"]="Gnomeregan",
 ["Grim Batol"]="GrimBatol",
 ["Grimrail Depot"]="GrimrailDepot",
 ["Gundrak"]="Gundrak",
 ["Halls of Atonement"]="HallsOfAtonement",
 ["Halls of Infusion"]="HallsofInfusion",
 ["Halls of Lightning"]="HallsofLightning",
 ["Halls of Origination"]="HallsofOrigination",
 ["Halls of Reflection"]="HallsofReflection",
 ["Halls of Stone"]="HallsofStone",
 ["Halls of Valor"]="HallsofValor",
 ["Hellfire Ramparts"]="HellfireRamparts",
 ["Hour of Twilight"]="HourofTwilight",
 ["Iron Docks"]="IronDocks",
 ["King's Rest"]="KingsRest",
 ["Kings' Rest"]="KingsRest",
 ["Kings’ Rest"]="KingsRest",
 ["King’s Rest"]="KingsRest",
 ["Lost City of the Tol'vir"]="LostCityoftheTolvir",
 ["Lost City of the Tol’vir"]="LostCityoftheTolvir",
 ["Lower Blackrock Spire"]="LowerBlackrockSpire",
 ["Magisters' Terrace"]="MagistersTerrace",
 ["Magisters’ Terrace"]="MagistersTerrace",
 ["Maisara Caverns"]="MaisaraCaverns",
 ["Mana-Tombs"]="ManaTombs",
 ["Maraudon"]="Maraudon",
 ["Maw of Souls"]="MawofSouls",
 ["Mists of Tirna Scithe"]="MistsOfTirnaScithe",
 ["Mogu'shan Palace"]="MogushanPalace",
 ["Mogu’shan Palace"]="MogushanPalace",
 ["Murder Row"]="MurderRow",
 ["Neltharion's Lair"]="NeltharionsLair",
 ["Neltharion’s Lair"]="NeltharionsLair",
 ["Neltharus"]="Neltharus",
 ["Nexus-Point Xenas"]="NexusPointXenas",
 ["Old Hillsbrad Foothills"]="OldHillsbradFoothills",
 ["Operation: Floodgate"]="OperationFloodgate",
 ["Operation: Mechagon"]="OperationMechagon",
 ["Operation: Mechagon - Junkyard"]="OperationMechagon",
 ["Operation: Mechagon - Workshop"]="OperationMechagonWorkshop",
 ["Operation: Mechagon – Junkyard"]="OperationMechagon",
 ["Operation: Mechagon – Workshop"]="OperationMechagonWorkshop",
 ["Pit of Saron"]="PitOfSaron",
 ["Plaguefall"]="Plaguefall",
 ["Priory of the Sacred Flame"]="PrioryOfSacredFlame",
 ["Ragefire Chasm"]="RagefireChasm",
 ["Razorfen Downs"]="RazorfenDowns",
 ["Razorfen Kraul"]="RazorfenKraul",
 ["Return to Karazhan"]="ReturntoKarazhan",
 ["Return to Karazhan: Lower"]="ReturntoKarazhan",
 ["Return to Karazhan: Upper"]="ReturntoKarazhan",
 ["Ruby Life Pools"]="RubyLifePools",
 ["Sanguine Depths"]="SanguineDepths",
 ["Scarlet Halls"]="ScarletHalls",
 ["Scarlet Monastery"]="ScarletMonastery",
 ["Scholomance"]="Scholomance",
 ["Seat of the Triumvirate"]="SeatOfTriumvirate",
 ["Sethekk Halls"]="SethekkHalls",
 ["Shado-Pan Monastery"]="ShadoPanMonastery",
 ["Shadow Labyrinth"]="ShadowLabyrinth",
 ["Shadowfang Keep"]="ShadowfangKeep",
 ["Shadowmoon Burial Grounds"]="ShadowmoonBurialGrounds",
 ["Shrine of the Storm"]="ShrineoftheStorm",
 ["Siege of Boralus"]="SiegeOfBoralus",
 ["Siege of Niuzao Temple"]="SiegeofNiuzaoTemple",
 ["Skyreach"]="Skyreach",
 ["Spires of Ascension"]="SpiresofAscension",
 ["Stormstout Brewery"]="StormstoutBrewery",
 ["Stratholme - Main Gate"]="StratholmeMainGate",
 ["Stratholme - Service Entrance"]="StratholmeServiceEntrance",
 ["Stratholme – Main Gate"]="StratholmeMainGate",
 ["Stratholme – Service Entrance"]="StratholmeServiceEntrance",
 ["Tazavesh, the Veiled Market"]="TazaveshStreets",
 ["Tazavesh: So'leah's Gambit"]="TazaveshGambit",
 ["Tazavesh: So’leah’s Gambit"]="TazaveshGambit",
 ["Tazavesh: Streets of Wonder"]="TazaveshStreets",
 ["Temple of Sethraliss"]="TempleOfSethraliss",
 ["Temple of the Jade Serpent"]="TempleoftheJadeSerpent",
 ["The Arcatraz"]="TheArcatraz",
 ["The Arcway"]="TheArcway",
 ["The Azure Vault"]="TheAzureVault",
 ["The Black Morass"]="TheBlackMorass",
 ["The Blinding Vale"]="TheBlindingVale",
 ["The Blood Furnace"]="TheBloodFurnace",
 ["The Botanica"]="TheBotanica",
 ["The Culling of Stratholme"]="TheCullingofStratholme",
 ["The Dawnbreaker"]="TheDawnbreaker",
 ["The Deadmines"]="Deadmines",
 ["The Everbloom"]="TheEverbloom",
 ["The Forge of Souls"]="TheForgeofSouls",
 ["The MOTHERLODE!!"]="TheMOTHERLODE",
 ["The Mechanar"]="TheMechanar",
 ["The Necrotic Wake"]="TheNecroticWake",
 ["The Nexus"]="TheNexus",
 ["The Nokhud Offensive"]="TheNokhudOffensive",
 ["The Oculus"]="TheOculus",
 ["The Rookery"]="TheRookery",
 ["The Shattered Halls"]="TheShatteredHalls",
 ["The Slave Pens"]="TheSlavePens",
 ["The Steamvault"]="TheSteamvault",
 ["The Stockade"]="TheStockade",
 ["The Stonecore"]="TheStonecore",
 ["The Stonevault"]="TheStonevault",
 ["The Temple of Atal'hakkar"]="TheTempleofAtalhakkar",
 ["The Temple of Atal’hakkar"]="TheTempleofAtalhakkar",
 ["The Underbog"]="TheUnderbog",
 ["The Underrot"]="TheUnderrot",
 ["The Violet Hold"]="TheVioletHold",
 ["The Vortex Pinnacle"]="TheVortexPinnacle",
 ["Theater of Pain"]="TheaterofPain",
 ["Throne of the Tides"]="ThroneoftheTides",
 ["Tol Dagor"]="TolDagor",
 ["Trial of the Champion"]="TrialoftheChampion",
 ["Uldaman"]="Uldaman",
 ["Uldaman: Legacy of Tyr"]="UldamanLegacyOfTyr",
 ["Upper Blackrock Spire"]="UpperBlackrockSpire",
 ["Utgarde Keep"]="UtgardeKeep",
 ["Utgarde Pinnacle"]="UtgardePinnacle",
 ["Vault of the Wardens"]="VaultoftheWardens",
 ["Voidscar Arena"]="VoidscarArena",
 ["Wailing Caverns"]="WailingCaverns",
 ["Waycrest Manor"]="WaycrestManor",
 ["Well of Eternity"]="WellofEternity",
 ["Windrunner Spire"]="WindrunnerSpire",
 ["Zul'Aman"]="ZulAman",
 ["Zul'Farrak"]="ZulFarrak",
 ["Zul'Gurub"]="ZulGurub",
 ["Zul’Aman"]="ZulAman",
 ["Zul’Farrak"]="ZulFarrak",
 ["Zul’Gurub"]="ZulGurub",
}
-- Padded wide textures use only the visible upper part of the canvas. 340/512 rows since the art
-- was halved to 1024x512 (2026-10-08): row 341 is a half-blended edge row that showed as a dark line.
local paddedArt={
 ["AhnkahetTheOldKingdom"]=0.6640625,
 ["AssaultonVioletHold"]=0.6640625,
 ["AtalDazar"]=0.6640625,
 ["AuchenaiCrypts"]=0.6640625,
 ["Auchindoun"]=0.6640625,
 ["AzjolNerub"]=0.6640625,
 ["BlackRookHold"]=0.6640625,
 ["BlackfathomDeeps"]=0.6640625,
 ["BlackrockCaverns"]=0.6640625,
 ["BlackrockDepths"]=0.6640625,
 ["BloodmaulSlagMines"]=0.6640625,
 ["BrackenhideHollow"]=0.6640625,
 ["CathedralofEternalNight"]=0.6640625,
 ["CinderbrewMeadery"]=0.6640625,
 ["CourtofStars"]=0.6640625,
 ["DarkflameCleft"]=0.6640625,
 ["DarkheartThicket"]=0.6640625,
 ["DawnoftheInfinite"]=0.6640625,
 ["DeOtherSide"]=0.6640625,
 ["Deadmines"]=0.6640625,
 ["DireMaulCapitalGardens"]=0.6640625,
 ["DireMaulGordokCommons"]=0.6640625,
 ["DireMaulWarpwoodQuarter"]=0.6640625,
 ["DrakTharonKeep"]=0.6640625,
 ["EndTime"]=0.6640625,
 ["EyeofAzshara"]=0.6640625,
 ["Freehold"]=0.6640625,
 ["GateoftheSettingSun"]=0.6640625,
 ["Gnomeregan"]=0.6640625,
 ["GrimrailDepot"]=0.6640625,
 ["Gundrak"]=0.6640625,
 ["HallsofInfusion"]=0.6640625,
 ["HallsofLightning"]=0.6640625,
 ["HallsofOrigination"]=0.6640625,
 ["HallsofReflection"]=0.6640625,
 ["HallsofStone"]=0.6640625,
 ["HallsofValor"]=0.6640625,
 ["HellfireRamparts"]=0.6640625,
 ["HourofTwilight"]=0.6640625,
 ["LostCityoftheTolvir"]=0.6640625,
 ["LowerBlackrockSpire"]=0.6640625,
 ["ManaTombs"]=0.6640625,
 ["Maraudon"]=0.6640625,
 ["MawofSouls"]=0.6640625,
 ["MogushanPalace"]=0.6640625,
 ["NeltharionsLair"]=0.6640625,
 ["Neltharus"]=0.6640625,
 ["OldHillsbradFoothills"]=0.6640625,
 ["OperationMechagon"]=0.6640625,
 ["OperationMechagonWorkshop"]=0.6640625,
 ["Plaguefall"]=0.6640625,
 ["RagefireChasm"]=0.6640625,
 ["RazorfenDowns"]=0.6640625,
 ["RazorfenKraul"]=0.6640625,
 ["ReturntoKarazhan"]=0.6640625,
 ["ScarletHalls"]=0.6640625,
 ["ScarletMonastery"]=0.6640625,
 ["Scholomance"]=0.6640625,
 ["SethekkHalls"]=0.6640625,
 ["ShadoPanMonastery"]=0.6640625,
 ["ShadowLabyrinth"]=0.6640625,
 ["ShadowfangKeep"]=0.6640625,
 ["ShadowmoonBurialGrounds"]=0.6640625,
 ["ShrineoftheStorm"]=0.6640625,
 ["SiegeofNiuzaoTemple"]=0.6640625,
 ["SpiresofAscension"]=0.6640625,
 ["StormstoutBrewery"]=0.6640625,
 ["StratholmeMainGate"]=0.6640625,
 ["StratholmeServiceEntrance"]=0.6640625,
 ["TempleoftheJadeSerpent"]=0.6640625,
 ["TheArcatraz"]=0.6640625,
 ["TheArcway"]=0.6640625,
 ["TheAzureVault"]=0.6640625,
 ["TheBlackMorass"]=0.6640625,
 ["TheBloodFurnace"]=0.6640625,
 ["TheBotanica"]=0.6640625,
 ["TheCullingofStratholme"]=0.6640625,
 ["TheEverbloom"]=0.6640625,
 ["TheForgeofSouls"]=0.6640625,
 ["TheMOTHERLODE"]=0.6640625,
 ["TheMechanar"]=0.6640625,
 ["TheNexus"]=0.6640625,
 ["TheNokhudOffensive"]=0.6640625,
 ["TheOculus"]=0.6640625,
 ["TheRookery"]=0.6640625,
 ["TheShatteredHalls"]=0.6640625,
 ["TheSlavePens"]=0.6640625,
 ["TheSteamvault"]=0.6640625,
 ["TheStockade"]=0.6640625,
 ["TheTempleofAtalhakkar"]=0.6640625,
 ["TheUnderbog"]=0.6640625,
 ["TheVioletHold"]=0.6640625,
 ["TheVortexPinnacle"]=0.6640625,
 ["TheaterofPain"]=0.6640625,
 ["ThroneoftheTides"]=0.6640625,
 ["TolDagor"]=0.6640625,
 ["TrialoftheChampion"]=0.6640625,
 ["Uldaman"]=0.6640625,
 ["UpperBlackrockSpire"]=0.6640625,
 ["UtgardeKeep"]=0.6640625,
 ["UtgardePinnacle"]=0.6640625,
 ["VaultoftheWardens"]=0.6640625,
 ["WailingCaverns"]=0.6640625,
 ["WaycrestManor"]=0.6640625,
 ["WellofEternity"]=0.6640625,
 ["ZulAman"]=0.6640625,
 ["ZulFarrak"]=0.6640625,
 ["ZulGurub"]=0.6640625,
}
-- Shared lookup so other windows (Manage Runs' dungeon preview) use the same generated art pack.
function A:GetLedgerDungeonArtPath(name)
 local file=name and art[name]
 return file and (media..'Dungeons\\'..file..'.jpg') or nil
end
-- Blizzard's Adventure Guide lore images (the fallback for dungeons outside the art pack) keep the
-- actual picture inside a baked-in frame in the top-left of the texture; the rest is empty padding.
-- Measured from an in-game screenshot 2026-10-08 (user report: Ahn'kahet showed a small framed
-- picture instead of filling the banner). Left, right, top, bottom of the picture inside that frame.
local JOURNAL_ART={.052,.711,.081,.571}
-- Fills a w x h texture with dungeon art, cropping to keep proportions. Both the bundled pack and
-- Blizzard's lore textures are 2:1 overall; lore images are first cut down to their framed picture.
function A:CropLedgerDungeonArt(t,image,w,h)
 local l,r,top,b=0,1,0,1
 w=math.max(1,tonumber(w) or 1);h=math.max(1,tonumber(h) or 1)
 if type(image)=='string' and image:find('MPlusLedgerSkin',1,true) then
  local file=image:match('Dungeons\\([^\\]+)%.jpg$')
  b=paddedArt[file] or 1
 else l,r,top,b=unpack(JOURNAL_ART) end
 local sourceRatio=(r-l)*2/(b-top);local ratio=w/h
 if ratio<sourceRatio then local span=(r-l)*ratio/sourceRatio;local c=(l+r)/2;l,r=c-span/2,c+span/2
 else local span=(b-top)*sourceRatio/ratio;local c=(top+b)/2;top,b=c-span/2,c+span/2 end
 t:SetTexCoord(l,r,top,b)
end

local function place(f,p,x,y,w,h)
 f:ClearAllPoints();f:SetPoint('TOPLEFT',p,'TOPLEFT',x,y);if w then f:SetWidth(w) end;if h then f:SetHeight(h) end
end
local function label(p,v,x,y,w,size,color)
 local t=S.Label(p,v,size or 11,color);place(t,p,x,y,w);t:SetWordWrap(false);return t
end
local function panel(p,x,y,w,h)
 local f=CreateFrame('Frame',nil,p);place(f,p,x,y,w,h);S.Apply(f,'Window',8);f.LedgerSkinTextures[5]:SetVertexColor(.20,.34,.33);return f
end
local function button(p,v,x,y,w,fn)
 local b=CreateFrame('Button',nil,p);place(b,p,x,y,w,34)
 S.Apply(b,'Button',6)
 -- Dark fill behind the label (user request 2026-10-08: "make the buttons have a darker colour");
 -- its own texture, so theme changes that re-skin the button leave it in place.
 local fill=b:CreateTexture(nil,'BACKGROUND',nil,-8);fill:SetPoint('TOPLEFT',3,-3);fill:SetPoint('BOTTOMRIGHT',-3,3);fill:SetColorTexture(0,0,0,.55)
 b.Label=label(b,v,5,-8,w-10,11,S.colors.white);b.Label:ClearAllPoints();b.Label:SetPoint('CENTER');b.Label:SetJustifyH('CENTER')
 local hover=b:CreateTexture(nil,'HIGHLIGHT');hover:SetAllPoints();hover:SetColorTexture(.78,.82,.86,.12)
 if fn then b:SetScript('OnClick',fn) end
 local icon=({['Record Repair']='coins',['Manage Runs']='List',['Main Menu']='Book',['Player History']='party'})[v]
 if icon then
  local t=b:CreateTexture(nil,'OVERLAY');b.menuAssetIcon=t;t:SetSize(16,16);t:SetPoint('LEFT',10,0)
  if icon=='coins' or icon=='party' then t:SetTexture(media..'GoldIcons.png');if icon=='coins' then t:SetTexCoord(.25,.5,.5,.8) else t:SetTexCoord(.75,1,.18,.48) end
  elseif icon=='List' then t:SetTexture(media..'BrowserElements\\List.png') else t:SetTexture(media..'MenuIcons\\'..icon..'.png') end
  b.Label:ClearAllPoints();b.Label:SetPoint('LEFT',27,0);b.Label:SetWidth(w-33);b.Label:SetFont(STANDARD_TEXT_FONT,11,'')
 end
 return b
end
-- Flush card footer (the "View runs" strip) -- per user request 2026-10-01 ("replicate the
-- background of the View Runs section"). The shared button() helper applies a full Card skin
-- (its own gold border on all four sides), which reads as a separate nested box floating inside
-- the card; the reference mockup's footer is just a flat band flush with the card's own edges, with
-- a thin divider line above it, not a second bordered button. No LedgerSkinTextures here at all.
local function cardFooter(c,v,x,y,w,h,fn)
 local b=CreateFrame('Button',nil,c);place(b,c,x,y,w,h)
 local divider=b:CreateTexture(nil,'ARTWORK');divider:SetColorTexture(.55,.43,.22,.5);divider:SetHeight(1)
 divider:SetPoint('TOPLEFT',0,0);divider:SetPoint('TOPRIGHT',0,0)
 local fill=b:CreateTexture(nil,'BACKGROUND');fill:SetColorTexture(.03,.045,.05,.92)
 fill:SetPoint('TOPLEFT',0,-1);fill:SetPoint('BOTTOMRIGHT',0,0)
 b.Label=label(b,v,0,0,w,11,gold);b.Label:ClearAllPoints();b.Label:SetPoint('CENTER');b.Label:SetJustifyH('CENTER')
 local hover=b:CreateTexture(nil,'HIGHLIGHT');hover:SetAllPoints();hover:SetColorTexture(.78,.82,.86,.12)
 if fn then b:SetScript('OnClick',fn) end
 return b
end
local function goldIcon(p,key,x,y,size)
 local uv=key=='party' and {.75,1,.18,.48} or key=='skull' and {.5,.75,.18,.48} or key=='coins' and {.25,.5,.5,.8} or {0,.25,.18,.48}
 local t=p:CreateTexture(nil,'ARTWORK');place(t,p,x,y,size,size);t:SetTexture(media..'GoldIcons.png');t:SetTexCoord(unpack(uv));return t
end
function A:GetReferenceDungeonGroups(ui)
 local byName={};local total={runs=0,completed=0,abandoned=0,partyDeaths=0,unassigned=0}
 local query=(ui.query or ''):lower();local catalogue=self:GetLedgerDungeonCatalogue()
 local function seed(name,group,entry)
  if not group or not name:lower():find(query,1,true) then return end
  local key=group..'\031'..name
  if not byName[key] then byName[key]={name=name,group=group,runs=0,completed=0,abandoned=0,partyDeaths=0,repairCost=0,latestAt=0,highestKey=0,image=entry and entry.image} end
  return byName[key]
 end
 for name,entry in pairs(catalogue) do
  if ui.group=='season' then
   for season in pairs(entry.seasons) do seed(name,season,entry) end
  -- No 'Other dungeons' fallback -- per user report 2026-10-01 ("Other Dungeons and Current
  -- Season... should not be visible while... Group by... Expansion"). A nil entry.expansion here
  -- means DungeonCatalogue.lua's own resolution pass already tried and failed to place this
  -- dungeon in a real expansion; seed() already no-ops on a falsy group, so this just stops
  -- manufacturing a fake catch-all bucket for it instead of fixing the underlying data.
  elseif ui.difficulty~='mythicPlus' or next(entry.seasons) then
   seed(name,entry.expansion,entry)
   -- A card per version of dungeons listed under two expansions (e.g. Classic and Mists of
   -- Pandaria Scholomance). Mythic+ view keeps just the one in rotation.
   if ui.difficulty~='mythicPlus' and #self:GetJournalVersions(name)>1 then
    for _,version in ipairs(self:GetJournalVersions(name)) do seed(name,version.expansion,entry) end
   end
  end
 end
 for _,id in ipairs(self.db.runOrder or {}) do
  local r=self:GetRun(id)
  if r and self:IsMPlusLedgerRun(r) and (ui.difficulty=='all' or self:GetDifficultyBucket(r)==ui.difficulty) and tostring(r.instanceName or ''):lower():find(query,1,true) then
   local name=r.instanceName or 'Unnamed dungeon';local entry=catalogue[name];local group
   if ui.group=='season' then
    if self:GetDifficultyBucket(r)=='mythicPlus' then
     group=self:LedgerSeasonName(r.mythicPlusSeasonName or r.mythicPlusSeason or r.seasonName)
     -- A dungeon's current membership must never relabel an older recorded run.
    end
   else
    group=entry and entry.expansion
    -- Multi-version dungeons: the run's own version (difficulty or instance) picks the card.
    if #self:GetJournalVersions(name)>1 then group=self:GetRunExpansionText(r) end
    if not group then
     -- Catalogue had nothing for this one -- fall back to resolving straight from the run
     -- itself (same real Journal-lookup-first logic GetRunExpansionText always uses), same as
     -- DungeonCatalogue.lua's own resolution pass. Still no fake bucket if even that comes up
     -- empty; seed() skips a nil group.
     local resolved=self:GetRunExpansionText(r)
     if resolved and resolved~='Unknown Expansion' and resolved~='Current Season' and not tostring(resolved):match('^Patch ') then group=resolved end
    end
   end
   local d=seed(name,group,entry)
   if d then
    local status=self:GetRunStatus(r);local done=status=='Completed' or status=='CompletedOvertime'
    d.runs=d.runs+1;d.completed=d.completed+(done and 1 or 0);d.abandoned=d.abandoned+(status=='Abandoned' and 1 or 0)
    d.partyDeaths=d.partyDeaths+(self:GetRunDeathTotal(r) or 0);d.repairCost=d.repairCost+(r.repairCost or 0)
    if (r.startedAt or 0)>=d.latestAt then d.latestRun=r;d.latestAt=r.startedAt or 0 end
    if self:GetDifficultyBucket(r)=='mythicPlus' then d.highestKey=math.max(d.highestKey,tonumber(r.keyLevel or r.challengeLevel) or 0) end
    total.runs=total.runs+1;total.completed=total.completed+(done and 1 or 0);total.abandoned=total.abandoned+(status=='Abandoned' and 1 or 0);total.partyDeaths=total.partyDeaths+(self:GetRunDeathTotal(r) or 0)
   elseif ui.group=='season' and self:GetDifficultyBucket(r)=='mythicPlus' then total.unassigned=total.unassigned+1 end
  end
 end
 local groups,order={},{}
 for _,d in pairs(byName) do
  if not groups[d.group] then groups[d.group]={};order[#order+1]=d.group end
  groups[d.group][#groups[d.group]+1]=d
 end
 local ranks={};for i,name in ipairs(self:GetLedgerSeasonNames()) do ranks[name]=i;if ui.group=='season' and query=='' and not groups[name] then groups[name]={};order[#order+1]=name end end
 -- Expansion release order, not alphabetical -- per user report 2026-10-01 ("these should be
 -- sorted by expansion release not by name"). Reuses Data Tools' own canonical expansion list
 -- (GetDataToolExpansionOptions, already most-recent-first: Midnight, The War Within, Dragonflight,
 -- ... Classic) as the single source of truth instead of a second hardcoded ranking that could
 -- drift out of sync with it.
 local expansionRanks={}
 for i,option in ipairs(self:GetDataToolExpansionOptions() or {}) do expansionRanks[option.value]=i end
 table.sort(order,function(a,b)
  if ui.group=='season' then
   local ar,br=ranks[a] or 999,ranks[b] or 999;if ar~=br then return ar<br end
  else
   local ar,br=expansionRanks[a] or 999,expansionRanks[b] or 999;if ar~=br then return ar<br end
  end
  return a>b
 end)
 for _,g in pairs(groups) do
  table.sort(g,function(a,b)
   local mode=ui.sort or 'recent';local av,bv
   if mode=='name' then return a.name<b.name
   elseif mode=='runs' then av,bv=a.runs,b.runs
   elseif mode=='deaths' then av,bv=a.partyDeaths,b.partyDeaths
   else av,bv=a.latestAt,b.latestAt end
   if av==bv then return a.name<b.name end;return av>bv
  end)
 end
 return order,groups,total
end
local function dropdown(ui,title,x,y,w,options,field)
 local menu=panel(ui,x,y-38,w,#options*34+10);menu:SetFrameLevel(ui:GetFrameLevel()+30);menu:Hide()
 -- Closes on cursor-leave -- per user report 2026-10-02 ("Can you check all dropdown boxes as
 -- well as this seems to be a persistent issue?"); this Group-by/Sort-by dropdown never had any
 -- close-on-cursor-leave or click-outside handling at all, same gap found across several other
 -- dropdown builders in Core.lua. Delayed and re-checked against IsMouseOver(), not hidden
 -- immediately, since OnLeave also fires on the background-to-child-option mouse transition.
 menu:EnableMouse(true)
 menu:SetScript('OnLeave',function(self)
  C_Timer.After(0.15,function() if self:IsShown() and not self:IsMouseOver() then self:Hide() end end)
 end)
 local b=button(ui,title,x,y,w,function() menu:SetShown(not menu:IsShown()) end)
 for i,o in ipairs(options) do
  local key,value=o[1],o[2]
  button(menu,value,5,-5-(i-1)*34,w-10,function() ui[field]=key;b.Label:SetText(value..'  v');menu:Hide();ui.scroll:SetVerticalScroll(0);A:RefreshWindow() end):SetHeight(30)
 end
 ui:HookScript('OnHide',function() menu:Hide() end)
 return b
end
local function build(f)
 -- f (self.window) still carries its original UI-DialogBox-Background-Dark backdrop from
 -- CreateWindow -- that's a plain square, not shaped like this skinned panel's rounded/filigreed
 -- border, so it was peeking out at the edges behind this panel's own art the whole time -- per
 -- user report 2026-10-01 ("there looks to be a dark background behind the Instance Ledger...
 -- the background is lighter than the instance ledger menu" in the Stats Hub, which has no such
 -- leftover backdrop on its own outer frame). Same cleanup MenuPolish.lua's window() already does
 -- for every OTHER reskinned window.
 if f.SetBackdrop then f:SetBackdrop(nil) end
 local ui=panel(f,8,-8,1064,884);ui:SetFrameLevel(f:GetFrameLevel()+60);ui:EnableMouse(true);f.allRunsReference=ui
 ui.difficulty='mythicPlus';ui.group='season';ui.sort='recent';ui.cards={};ui.headers={};ui.collapsed={}
 local emblem=goldIcon(ui,'sun',14,-5,48);emblem:SetTexture(media..'BrowserElements\\Compass.png');emblem:SetTexCoord(0,1,0,1);label(ui,'M+ Ledger',72,-8,245,23,gold);label(ui,'A L L   R U N S',74,-35,240,9)
 local function existing(key)
  return function() local b=f[key];local fn=b and b:GetScript('OnClick');if fn then fn(b) end end
 end
 -- Retain established action handlers, including their validation and return behavior.
 local repair
 for _,b in ipairs({f:GetChildren()}) do local t=b.text or b.Label;if t and t.GetText and t:GetText()=='Record Repair' then repair=b end end
 button(ui,'Main Menu',320,-12,125,existing('statsHubButton'))
 button(ui,'Manage Runs',469,-12,135,existing('dataToolsButton'))
 button(ui,'Record Repair',612,-12,135,function() local fn=repair and repair:GetScript('OnClick');if fn then fn(repair) end end)
 button(ui,'Player History',755,-12,155,function() A:OpenPlayerHistoryWindow() end)
 local close=button(ui,'X',1008,-13,30,function() f:Hide() end);close.LedgerSkinTextures[5]:SetColorTexture(.34,.025,.025,1)
 ui.summary={}
 for i,title in ipairs({'Runs','Completed','Left','Party deaths'}) do
  local x=18+(i-1)*84;ui.summary[i]=label(ui,'',x,-72,82,22,gold);ui.summary[i]:SetJustifyH('CENTER')
  label(ui,title,x,-103,82,10):SetJustifyH('CENTER')
 end
 -- One Difficulty dropdown, Mythic+ by default (user request 2026-10-08) -- was a row of seven
 -- buttons. ui.filters stays as an empty table so the old selected-state loop is a no-op.
 ui.filters={}
 label(ui,'Difficulty',370,-74,70,10)
 dropdown(ui,'Mythic+  v',445,-63,190,{{'all','All difficulties'},{'normal','Normal'},{'heroic','Heroic'},{'mythic','Mythic'},{'mythicPlus','Mythic+'},{'timewalking','Timewalking'},{'follower','Follower'}},'difficulty')
 local search=CreateFrame('EditBox',nil,ui);place(search,ui,370,-106,225,34);search:SetAutoFocus(false);search:SetFontObject(GameFontHighlightSmall);search:SetTextInsets(30,10,0,0);S.Apply(search,'Card',5)
 ui.searchBox=search
 local searchIcon=search:CreateTexture(nil,'OVERLAY');searchIcon:SetSize(14,14);searchIcon:SetPoint('LEFT',9,0);S.ThemeAsset(searchIcon,'search');search.menuSearchIcon=searchIcon
 -- A simple inset outline is readable even when ornamental chrome is subtle.
 for _,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do
  local edge=search:CreateTexture(nil,'OVERLAY');S.ThemeAccentTexture(edge)
  if side=='TOP' or side=='BOTTOM' then edge:SetHeight(1);edge:SetPoint(side..'LEFT',2,side=='TOP' and -2 or 2);edge:SetPoint(side..'RIGHT',-2,side=='TOP' and -2 or 2)
  else edge:SetWidth(1);edge:SetPoint('TOP'..side,side=='LEFT' and 2 or -2,-2);edge:SetPoint('BOTTOM'..side,side=='LEFT' and 2 or -2,2) end
 end
 local hint=label(search,'Search dungeon...',30,-11,184,10);search:SetScript('OnTextChanged',function(self) ui.query=self:GetText();hint:SetShown(ui.query=='');ui.scroll:SetVerticalScroll(0);A:RefreshWindow() end);search:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
 label(ui,'Group by',610,-117,58,10)
 -- Defaults: M+ Season grouping, Recent sort (user request 2026-10-08).
 dropdown(ui,'M+ Season  v',668,-106,130,{{'expansion','Expansion'},{'season','M+ Season'}},'group')
 label(ui,'Sort by',815,-117,50,10)
 dropdown(ui,'Recent  v',867,-106,160,{{'recent','Recent'},{'name','Name'},{'runs','Most runs'},{'deaths','Party deaths'}},'sort')
 for _,y in ipairs({-55,-154}) do local line=ui:CreateTexture(nil,'ARTWORK');place(line,ui,8,y,1048,1);line:SetColorTexture(.55,.43,.22,.75) end
 for i=1,4 do local line=ui:CreateTexture(nil,'ARTWORK');place(line,ui,14+i*84,-70,1,51);line:SetColorTexture(.55,.43,.22,.65) end
 ui.scroll=CreateFrame('ScrollFrame',nil,ui);place(ui.scroll,ui,15,-158,1034,688);ui.scroll:SetClipsChildren(true)
 ui.content=CreateFrame('Frame',nil,ui.scroll);ui.content:SetSize(1020,688);ui.scroll:SetScrollChild(ui.content)
 ui.scroll:EnableMouseWheel(true);ui.scroll:SetScript('OnMouseWheel',function(self,delta) self:SetVerticalScroll(math.max(0,math.min(math.max(0,ui.content:GetHeight()-688),self:GetVerticalScroll()-delta*70))) end)
 -- Flat, like the "View runs" footer -- per user report 2026-10-01 ("there are some weird boxes
 -- at the bottom of the menu"). The shared button() helper gives these their own full Card-skinned
 -- gold border, which (at this small size, floating alone in open space below the grid rather than
 -- in a button row) reads as two stray boxes rather than part of the themed layout.
 ui.up=cardFooter(ui,'Up',885,-850,65,28,function() ui.scroll:GetScript('OnMouseWheel')(ui.scroll,4) end)
 ui.down=cardFooter(ui,'Down',958,-850,65,28,function() ui.scroll:GetScript('OnMouseWheel')(ui.scroll,-4) end)
 ui.note=label(ui,'Completion includes overtime. Repairs shown in gold. Scroll for more dungeons.',20,-861,840,10)
 ui.empty=label(ui.content,'No dungeons match these filters.',20,-25,900,16)
 return ui
end
local function card(ui,index)
 local c=ui.cards[index];if c then return c end
 c=panel(ui.content,0,0,246,234);ui.cards[index]=c
 -- panel()'s default teal-gray tint (.20,.34,.33) reads as its own distinct lighter band behind
 -- the Runs/Deaths/Repairs stats, against the near-black footer below it -- per user report
 -- 2026-10-01 ("remove the background behind the stats on the dungeon cards"). Darkened to match
 -- the footer's own near-black fill so the stats area and the footer read as one continuous dark
 -- zone instead of two visibly different shades.
 c.LedgerSkinTextures[5]:SetVertexColor(.08,.10,.11)
 c.art=c:CreateTexture(nil,'ARTWORK');place(c.art,c,4,-4,238,130)
 local shade=c:CreateTexture(nil,'ARTWORK',nil,1);place(shade,c,4,-64,238,70);shade:SetTexture(media..'BrowserElements\\TitleFade.png');c.shade=shade
 c.name=label(c,'',12,-112,222,14,gold)
 c.runs=label(c,'',9,-143,43,21,gold);c.runsLabel=label(c,'Runs',9,-173,43,10)
 c.ring=c:CreateTexture(nil,'ARTWORK');c.ring:SetTexture(media..'BrowserElements\\Completion.png');c.ring:SetSize(46,46)
 -- Completion pie inside the ring (user request 2026-10-08): the theme's ornamental meter frame
 -- covers the ring's own progress arc, so the share completed shows as a pie in the frame's open
 -- centre instead. CompletionPie.png uses Completion.png's 8x16 one-frame-per-percent layout;
 -- built by tools/make_completion_pie.py.
 c.pie=c:CreateTexture(nil,'ARTWORK',nil,3);c.pie:SetTexture(media..'BrowserElements\\CompletionPie.png');c.pie:SetVertexColor(.22,.66,.44)
 c.percent=label(c,'',64,-157,38,10);c.percent:SetJustifyH('CENTER');c.completeLabel=label(c,'Completed',55,-188,64,9)
 c.percent:SetShadowColor(0,0,0,1);c.percent:SetShadowOffset(1,-1)
 c.deathIcon=goldIcon(c,'skull',124,-147,16);c.deaths=label(c,'',145,-149,37,11);c.deathsLabel=label(c,'Deaths',124,-173,52,10)
 c.repairIcon=goldIcon(c,'coins',184,-147,16);c.repairs=label(c,'',200,-149,39,10);c.repairsLabel=label(c,'Repairs',184,-173,51,10)
 -- Plain outlined text, no frame at all -- per user report 2026-10-01 ("that Key badge removal
 -- look horrible, please remove the border as well"). Dropping just the center fill (previous
 -- attempt) still left the gold ornamental border floating as its own awkward little box over the
 -- art; a font OUTLINE keeps the number readable against any background without needing a box
 -- around it at all.
 c.key=CreateFrame('Frame',nil,c);place(c.key,c,200,-6,38,27)
 c.key.text=label(c.key,'',2,-6,34,12,gold);c.key.text:SetJustifyH('CENTER')
 c.key.text:SetFont(STANDARD_TEXT_FONT,14,'OUTLINE')
 c.deathIcon:SetTexture(media..'BrowserElements\\Skull.png');c.deathIcon:SetTexCoord(0,1,0,1)
 c.repairIcon:SetTexture(media..'BrowserElements\\Wrench.png');c.repairIcon:SetTexCoord(0,1,0,1)
 S.ThemeAsset(c.deathIcon,'deaths-silver');S.ThemeAsset(c.repairIcon,'repair-silver')
 c.action=cardFooter(c,'View runs >',3,-208,240,23,function() A.selectedDungeonName=c.data.name;A.window.listOffset=0;A:RefreshWindow() end)
 return c
end
-- Keep the two renderers mutually exclusive, including legacy rows outside the viewport.
local function legacyVisibility(f,visible)
 if visible then
  for object,shown in pairs(f.referenceHidden or {}) do object:SetShown(shown) end
  f.referenceHidden=nil
  return
 end
 f.referenceHidden=f.referenceHidden or {}
 local protected={}
 for _,t in ipairs(f.LedgerSkinTextures or {}) do protected[t]=true end
 if f.ledgerSurface then protected[f.ledgerSurface]=true end
 for _,object in ipairs({f:GetChildren()}) do
  if object~=f.allRunsReference then
   if f.referenceHidden[object]==nil then f.referenceHidden[object]=object:IsShown() end
   object:Hide()
  end
 end
 for _,object in ipairs({f:GetRegions()}) do
  if not protected[object] then
   if f.referenceHidden[object]==nil then f.referenceHidden[object]=object:IsShown() end
   object:Hide()
  end
 end
end
local old=A.RefreshWindow
function A:RefreshWindow(...)
 if self:IsUiLocked() or not self.window then return end
 -- All Runs is self-contained. Only dungeon detail needs the legacy renderer.
 if self.selectedDungeonName then
  if self.window.allRunsReference then self.window.allRunsReference:Hide() end
  legacyVisibility(self.window,true)
  return old(self,...)
 end
 local f=self.window;local ui=f.allRunsReference or build(f)
 legacyVisibility(f,false)
 ui:SetShown(not self.selectedDungeonName);if self.selectedDungeonName then return end
 local order,groups,total=self:GetReferenceDungeonGroups(ui)
 ui.note:SetText(total.unassigned>0 and (total.unassigned..' M+ runs await season confirmation in Manage Runs. Repairs shown in gold.') or 'Completion includes overtime. Repairs shown in gold. Scroll for more dungeons.')
 for i,value in ipairs({total.runs,total.completed,total.abandoned,total.partyDeaths}) do ui.summary[i]:SetText(tostring(value)) end
 -- Persistent gold fill for the selected filter, not just text color -- per user report
 -- 2026-10-01 ("hard to see what you have selected... as soon as i remove the mouse the hover
 -- effect is gone"). The gold tint they saw was the button's own HIGHLIGHT texture, which WoW
 -- only draws while the mouse is actually over it -- it was never a real selected-state indicator.
 -- No new art needed for this: the same Card skin's own center fill (LedgerSkinTextures[5]) just
 -- gets tinted gold instead of near-black when selected, so it reads as "on" with the mouse
 -- anywhere else on screen.
 for key,b in pairs(ui.filters) do
  local selected=key==ui.difficulty;b.ledgerSelected=selected
  b.Label:SetTextColor(unpack(selected and S.colors.white or {.70,.71,.69}))
  -- Selected = a soft wash of the theme accent; unselected = no fill at all.
  local a=S.GetAssetAccent()
  if selected then b.LedgerSkinTextures[5]:SetColorTexture(a[1],a[2],a[3],.22) else b.LedgerSkinTextures[5]:SetColorTexture(0,0,0,0) end
 end
 local y,index=0,0
 for j,name in ipairs(order) do
  local h=ui.headers[j]
  if not h then
   h=CreateFrame('Button',nil,ui.content);h:SetSize(1020,48);h.title=label(h,'',12,-9,640,24,gold);h.count=label(h,'',650,-21,350,10);h.count:SetJustifyH('RIGHT')
   local rule=h:CreateTexture(nil,'BACKGROUND');place(rule,h,12,-43,996,1);rule:SetColorTexture(.6,.47,.2,.8)
   h:SetScript('OnClick',function(self) ui.collapsed[self.group]=not ui.collapsed[self.group];A:RefreshWindow() end);ui.headers[j]=h
  end
  h.group=name;place(h,ui.content,0,-y);h:Show();h.title:SetText(name)
  local g=groups[name];local runs=0;for _,d in ipairs(g) do runs=runs+d.runs end
  h.count:SetText(#g==0 and 'Dungeon roster awaiting confirmation' or string.format('%d DUNGEONS  ·  %d RUNS  %s',#g,runs,ui.collapsed[name] and '+' or '−'));y=y+49
  if not ui.collapsed[name] then
   local columns=math.max(1,math.min(4,#g));local width=columns<=2 and 400 or (1020-(columns-1)*10)/columns
   for i,d in ipairs(g) do
    index=index+1;local c=card(ui,index);c.data=d;place(c,ui.content,((i-1)%columns)*(width+10),-y-math.floor((i-1)/columns)*244,width,234);c:Show()
    place(c.art,c,4,-4,width-8,130);local file=art[d.name]
    local image=file and media..'Dungeons\\'..file..'.jpg' or d.image
    if image then
     c.art:SetTexture(image);A:CropLedgerDungeonArt(c.art,image,width-8,130)
    else c.art:SetColorTexture(.015,.045,.05,1) end
    place(c.key,c,width-46,-6,38,27);c.key.text:SetText('+'..d.highestKey);c.key:SetShown(ui.difficulty=='mythicPlus' and d.highestKey>0 and A.db.decorativeKeyBadges~=false)
    c.shade:SetWidth(width-8)
    local ringX=width*.34;local deathsX=width*.52;local repairsX=width*.77
    place(c.percent,c,ringX-19,-157,38);place(c.completeLabel,c,ringX-28,-188,64)
    place(c.deathIcon,c,deathsX,-147,16,16);place(c.deaths,c,deathsX+19,-149,width*.20-19);place(c.deathsLabel,c,deathsX,-173,60)
    place(c.repairIcon,c,repairsX,-147,16,16);place(c.repairs,c,repairsX+18,-149,width*.23-24);place(c.repairsLabel,c,repairsX,-173,60)
    c.name:SetText(d.name);c.name:SetWidth(width-24);c.runs:SetText(tostring(d.runs));c.deaths:SetText(tostring(d.partyDeaths));c.repairs:SetText(tostring(math.floor(d.repairCost/10000)))
    local fraction=d.runs>0 and d.completed/d.runs or 0;local pct=math.floor(fraction*100+.5);c.percent:SetText(pct..'%')
    place(c.ring,c,ringX-23,-139,46,46)
    local col,row=pct%8,math.floor(pct/8);c.ring:SetTexCoord(col/8,(col+1)/8,row/16,(row+1)/16)
    -- 26px pie centred in the 46px ring: fits inside every theme's meter-frame opening.
    c.pie:SetTexCoord(col/8,(col+1)/8,row/16,(row+1)/16);place(c.pie,c,ringX-13,-149,26,26)
    if width>=390 then
     ringX=width*.25;place(c.ring,c,ringX-23,-139,46,46);place(c.percent,c,ringX-19,-157,38);place(c.pie,c,ringX-13,-149,26,26)
     place(c.completeLabel,c,ringX+28,-157,65)
    end
    c.action:SetWidth(width-6)
    c.action.Label:SetWidth(width-16)
   end
   y=y+math.ceil(#g/columns)*244
  end
 end
 for i=index+1,#ui.cards do ui.cards[i]:Hide() end
 for i=#order+1,#ui.headers do ui.headers[i]:Hide() end
 ui.empty:SetShown(#order==0);ui.content:SetHeight(math.max(688,y));ui.scroll:SetVerticalScroll(math.min(ui.scroll:GetVerticalScroll(),math.max(0,y-688)))
 ui.up:SetShown(y>688);ui.down:SetShown(y>688)
end
