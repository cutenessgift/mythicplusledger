-- Read-only catalogue: journal dungeons persist independently of recorded runs.
local _,ns=...
local A=MPlusLedger
-- Dungeon rotations confirmed by the user, 2026-10-01. Never used to infer a run date.
local confirmedRotations={
 ["The War Within Season 1"]={
  {"Ara-Kara, City of Echoes","The War Within"},
  {"City of Threads","The War Within"},
  {"The Stonevault","The War Within"},
  {"The Dawnbreaker","The War Within"},
  {"Mists of Tirna Scithe","Shadowlands"},
  {"The Necrotic Wake","Shadowlands"},
  {"Siege of Boralus","Battle for Azeroth"},
  {"Grim Batol","Cataclysm"},
 },
 ["The War Within Season 2"]={
  {"Operation: Floodgate","The War Within"},
  {"Cinderbrew Meadery","The War Within"},
  {"Darkflame Cleft","The War Within"},
  {"The Rookery","The War Within"},
  {"Priory of the Sacred Flame","The War Within"},
  {"The MOTHERLODE!!","Battle for Azeroth"},
  {"Theater of Pain","Shadowlands"},
  {"Operation: Mechagon - Workshop","Battle for Azeroth"},
 },
 ["The War Within Season 3"]={
  {"Eco-Dome Al'dani","The War Within"},
  {"Ara-Kara, City of Echoes","The War Within"},
  {"The Dawnbreaker","The War Within"},
  {"Operation: Floodgate","The War Within"},
  {"Priory of the Sacred Flame","The War Within"},
  {"Halls of Atonement","Shadowlands"},
  {"Tazavesh: Streets of Wonder","Shadowlands"},
  {"Tazavesh: So'leah's Gambit","Shadowlands"},
 },
 ["Midnight Season 1"]={
  {"Magisters' Terrace","Midnight"},
  {"Windrunner Spire","Midnight"},
  {"Maisara Caverns","Midnight"},
  {"Nexus-Point Xenas","Midnight"},
  {"Algeth'ar Academy","Dragonflight"},
  {"Pit of Saron","Wrath of the Lich King"},
  {"Seat of the Triumvirate","Legion"},
  {"Skyreach","Warlords of Draenor"},
 },
}

local seasons={'Midnight Season 2','Midnight Season 1','The War Within Season 3','The War Within Season 2','The War Within Season 1'}
-- User-confirmed rosters for seasons with no live API to read them from (past The War Within
-- seasons) or that haven't gone live yet (Midnight Season 1) -- per user request 2026-10-01 ("why
-- does it say Dungeon roster awaiting confirmation. i gave you the lists"). These are the exact
-- lists the user supplied; add() below seeds a zero-run placeholder card for every one of them so
-- they show up even though nobody has run them yet, same as the current pool loop already does
-- for Midnight Season 2. If any of these ever shows up as a DUPLICATE of a real Journal-sourced
-- card (a punctuation/dash mismatch against Blizzard's exact string), that's a naming fix, not a
-- data fix -- flag which dungeon so the string here can be corrected to match exactly.
local CONFIRMED_SEASON_ROSTERS={
 ['The War Within Season 1']={'Ara-Kara, City of Echoes','City of Threads','The Stonevault','The Dawnbreaker','Mists of Tirna Scithe','The Necrotic Wake','Siege of Boralus','Grim Batol'},
 ['The War Within Season 2']={'Operation: Floodgate','Cinderbrew Meadery','Darkflame Cleft','The Rookery','Priory of the Sacred Flame','The MOTHERLODE!!','Theater of Pain','Operation: Mechagon - Workshop'},
 ['The War Within Season 3']={'Eco-Dome Al\'dani','Ara-Kara, City of Echoes','The Dawnbreaker','Operation: Floodgate','Priory of the Sacred Flame','Halls of Atonement','Tazavesh: Streets of Wonder','Tazavesh: So\'leah\'s Gambit'},
 ['Midnight Season 1']={'Magisters\' Terrace','Windrunner Spire','Maisara Caverns','Nexus-Point Xenas','Algeth\'ar Academy','Pit of Saron','Seat of the Triumvirate','Skyreach'},
}
function A:GetLedgerSeasonNames()
 local current=self:GetCurrentNamedSeasonName();local names,seen={},{}
 local function add(v) if type(v)=='string' and v:match('Season %d+') and not seen[v] then seen[v]=true;names[#names+1]=v end end
 add(current);for _,v in ipairs(seasons) do add(v) end
 for v in pairs(self.db.seasonLinks or {}) do add(v) end
 return names
end
function A:LedgerSeasonName(value)
 if value==self:GetCurrentSeasonName() or value=='Current WoW Season' then return self:GetCurrentNamedSeasonName() end
 if type(value)=='string' and value:match('Season %d+') and not value:find('Unknown',1,true) then return value end
end
-- GetDungeonSummary doesn't track a "most recent run" field (only bestRun, which is only set for
-- an on-time completion) -- this does a direct runOrder scan (newest-first) for the first run
-- matching this instance name, for the expansion-resolution pass below.
function A:GetLedgerLatestRunForDungeon(name)
 for _,id in ipairs(self.db.runOrder or {}) do
  local run=self:GetRun(id)
  if run and run.instanceName==name and self:IsMPlusLedgerRun(run) then return run end
 end
 return nil
end
function A:GetLedgerDungeonCatalogue()
 if not self.ledgerJournalCatalogue then
  if self.LoadEncounterJournalForIconDump then self:LoadEncounterJournalForIconDump() end
  local entries={}
  if EJ_GetNumTiers and EJ_GetTierInfo and EJ_SelectTier and EJ_GetInstanceByIndex then
   local previous=EJ_GetCurrentTier and EJ_GetCurrentTier()
   local ok=pcall(function()
    -- Blizzard's own Encounter Journal returns the bare "Burning Crusade" for this tier (no
   -- "The"), unlike every other expansion name this addon already uses consistently (Data
   -- Tools' own canonical list at GetDataToolExpansionOptions says "The Burning Crusade") --
   -- normalized here, at the one place this tier name is actually read from Blizzard, so every
   -- consumer (both the add() calls below and the direct overwrite further down) gets it fixed
   -- for free instead of needing the same rename repeated at each call site.
   local EJ_EXPANSION_RENAMES={['Burning Crusade']='The Burning Crusade'}
   for tier=1,EJ_GetNumTiers() do
     local expansion=EJ_GetTierInfo(tier)
     expansion=EJ_EXPANSION_RENAMES[expansion] or expansion
     -- The Journal's "Current Season" tab repeats this season's dungeons after their real
     -- expansion tab; reading it last overwrote e.g. Kings' Rest (Battle for Azeroth) with
     -- "Current Season" (user report 2026-10-08). Skip it so each keeps its real expansion.
     if expansion~='Current Season' then
     EJ_SelectTier(tier)
     for i=1,500 do
      local id,name,description,background,button,lore=EJ_GetInstanceByIndex(i,false)
      if not id then break end
      entries[name]={name=name,expansion=expansion,journalInstanceID=id,image=lore or background,description=description}
     end
     end
    end
   end)
   if previous then pcall(EJ_SelectTier,previous) end
   if ok and next(entries) then self.ledgerJournalCatalogue=entries end
  end
 end
 local result={};local raids={}
 for _,entry in ipairs(self.db.iconDumps and self.db.iconDumps.encounterJournal or {}) do if entry.type=='raid' then raids[entry.name]=true end end
 local function add(name,expansion,entry)
  if not name then return end
  local d=result[name] or {name=name,seasons={}};result[name]=d
  if expansion and expansion~='Current Season' and not tostring(expansion):find('Unknown',1,true) then d.expansion=expansion end
  if entry then d.image=entry.image or entry.loreImage or d.image;d.journalInstanceID=entry.journalInstanceID or d.journalInstanceID end
  return d
 end
 for name,d in pairs(self.ledgerJournalCatalogue or {}) do add(name,d.expansion,d) end
 for expansion,buckets in pairs(self.db.expansionCatalog or {}) do
  for name in pairs(buckets.dungeons or {}) do add(name,expansion) end
 end
 for _,entry in ipairs(self.db.iconDumps and self.db.iconDumps.encounterJournal or {}) do
  if entry.type~='raid' then add(entry.name or entry.instanceName,entry.tierName,entry) end
 end
 for name,entry in pairs(self.db.instanceCatalog or {}) do
  if not raids[name] and entry.instanceType~='raid' and entry.type~='raid' then
   local d=add(name,entry.expansionName,entry)
   for season,linked in pairs(entry.seasonLinks or {}) do local s=self:LedgerSeasonName(season);if linked and s then d.seasons[s]=true end end
  end
 end
 -- Journal expansion wins over legacy guesses; explicit manual assignments win over both.
 for name,entry in pairs(self.ledgerJournalCatalogue or {}) do result[name].expansion=entry.expansion end
 for name,entry in pairs(self.db.dungeonMetadata or {}) do
  if result[name] and entry.expansionManual then result[name].expansion=entry.expansionName end
 end
 for season,links in pairs(self.db.seasonLinks or {}) do
  local s=self:LedgerSeasonName(season)
  if s then for name,linked in pairs(links) do if linked then add(name).seasons[s]=true end end end
 end
 for season,entries in pairs(confirmedRotations) do
  for _,d in pairs(result) do d.seasons[season]=nil end
  for _,entry in ipairs(entries) do
   local d=add(entry[1]);d.seasons[season]=true
   d.expansion=entry[2]
  end
 end
 local current=self:GetCurrentNamedSeasonName()
 local pool=self.DumpChallengeDungeonIcons and self:DumpChallengeDungeonIcons() or {}
 if #pool==0 then pool=self:GetMythicPlusPoolEntries() end
 for _,entry in ipairs(pool) do if entry.name and current then add(entry.name).seasons[current]=true end end
 for season,names in pairs(CONFIRMED_SEASON_ROSTERS) do
  for _,name in ipairs(names) do add(name).seasons[season]=true end
 end
 -- Resolve any dungeon still missing a real expansion -- either nil, or the literal "Current
 -- Season" placeholder some instanceCatalog entries were stamped with (add() above already
 -- refuses to accept that string, but the overwrite at line 59 bypasses add() entirely and isn't
 -- guarded the same way) -- per user report 2026-10-01 ("Other Dungeons and Current Season...
 -- should not be visible while... Group by... Expansion... these should be sorted by expansion
 -- release"). Prefers the same reliable resolution GetRunExpansionText already uses (real Journal
 -- lookup first, not a guess) via this dungeon's own most recent tracked run. A dungeon with zero
 -- run history that's still in the CURRENT season's M+ pool falls back to the current expansion,
 -- since nothing else could have put a never-run dungeon in this season's pool. Anything left over
 -- after both of those (no runs, not in the current pool, no real catalog/Journal data at all)
 -- stays nil -- GetReferenceDungeonGroups skips a nil-expansion entry rather than bucketing it
 -- into a fake "Other dungeons" group.
 local currentExpansion
 do
  local version=GetBuildInfo and select(1,GetBuildInfo())
  local major=tostring(version or ''):match('^(%d+)%.')
  if major=='12' then currentExpansion='Midnight' end
 end
 local inCurrentPool={}
 for _,entry in ipairs(pool) do if entry.name then inCurrentPool[entry.name]=true end end
 for name,d in pairs(result) do
  if not d.expansion or d.expansion=='Current Season' or tostring(d.expansion):find('Unknown',1,true) then
   local latestRun=self:GetLedgerLatestRunForDungeon(name)
   local resolved=latestRun and self:GetRunExpansionText(latestRun)
   -- A run stamped "Current Season" just hands the same placeholder back (Voidscar Arena, user
   -- report 2026-10-08: missing from the Midnight section), so it doesn't count as resolved.
   if resolved and resolved~='Unknown Expansion' and resolved~='Current Season' and not tostring(resolved):match('^Patch ') then
    d.expansion=resolved
   elseif (inCurrentPool[name] or (current and d.seasons[current])) and currentExpansion then
    d.expansion=currentExpansion
   else
    d.expansion=nil
   end
  end
 end
 -- Final safety filter, per user report 2026-10-01 ("there are delves in the instance ledger"):
 -- several of the add() calls above (the seasonLinks loop, the expansionCatalog.dungeons loop,
 -- the M+ pool loop) have no instanceType check at all, so a Delve or other non-dungeon instance
 -- that ever picked up a stray seasonLinks/expansionCatalog entry slips back in even though the
 -- self.db.instanceCatalog loop above already tries to exclude raids. Delves and Delve-adjacent
 -- open-world content record instanceType "scenario" or "neighborhood" (confirmed via direct
 -- SavedVariables inspection: Atal'Aman, Collegiate Calamity, Gnarldor Isle, The Ring of Glory,
 -- The Grudge Pit, and Parhelion Plaza are all "scenario"; Founder's Point is "neighborhood") --
 -- none of those are Mythic+ dungeons and none belong in this catalogue. Checked against the
 -- ground-truth record (self.db.instanceCatalog), not against whichever loop happened to add the
 -- name, so it catches every path at once instead of needing a fix per call site.
 local EXCLUDED_CATALOGUE_INSTANCE_TYPES={raid=true,scenario=true,neighborhood=true,pvp=true,arena=true}
 for name in pairs(result) do
  local catalogEntry=self.db.instanceCatalog and self.db.instanceCatalog[name]
  local instanceType=catalogEntry and (catalogEntry.instanceType or catalogEntry.type)
  if instanceType and EXCLUDED_CATALOGUE_INSTANCE_TYPES[instanceType] then
   result[name]=nil
  end
 end
 return result
end
