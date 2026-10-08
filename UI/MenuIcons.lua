-- Consistent small menu assets. Existing callbacks, filters and editable values are retained.
local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local goldUV={swords={.25,.5,.18,.48},skull={.5,.75,.18,.48},party={.75,1,.18,.48},hourglass={0,.25,.50,.80},coins={.25,.5,.50,.80},wrench={.5,.75,.50,.80},shield={.75,1,.50,.80}}
local function texture(t,key)
 local uv=goldUV[key]
 t:SetTexture(media..(uv and 'GoldIcons.png' or ('MenuIcons\\'..key..'.png')))
 t:SetTexCoord(unpack(uv or {0,1,0,1}));t:SetVertexColor(1,1,1)
end
local function symbol(parent,key,size,x,y)
 local t=parent:CreateTexture(nil,'OVERLAY');texture(t,key);t:SetSize(size,size);t:SetPoint('LEFT',parent,'LEFT',x or 8,y or 0);return t
end
local exact={['Main Menu']='Book',['M+ Stats']='Chart',['Overview']='Book',['Season']='hourglass',['Trends']='Chart',['Boss Pacing']='swords',['X']='Close',['Search']='Search',['Save']='Save',['Save Run']='Save',['Add repair cost']='Save',['Delete Run']='Delete',['Remove']='Delete',['Cancel']='Back',['Back']='Back',['Guide']='Book',['Run Editor']='Edit',['Edit']='Edit',['Create Run']='Book',['Create New Run']='Book',['Add Player']='AddPlayer',['Update Player']='Edit',['Player History']='party',['Player Reputation History']='party',['Manage player data']='wrench',['Manage Data']='wrench',['Manage Runs']='wrench',['Record Repair']='coins',['Stats & Progress']='Chart',['Progress']='Chart',['All Runs']='Book',['View All Runs']='Book',['Share']='Share',['Status']='shield',['Completed']='Check',['Timed']='Check',['Overtime']='hourglass',['Abandoned']='Close',['Active']='swords',['Difficulty details']='Filter',['Details']='Details'}
local function keyFor(value)
 if exact[value] then return exact[value] end
 if value:find('^Save ') then return 'Save' end
 if value:find('^Clear ') or value:find('^Delete ') then return 'Delete' end
 if value:find('^Sort:') then return 'Sort' end
 for _,prefix in ipairs({'Filter:','Show:','Status:','Class:','Instance:','View:','Last ','All Expansions','All Instances','All Bosses'}) do if value:sub(1,#prefix)==prefix then return 'Filter' end end
end
local function button(b,forced)
 local label=b.Label or b.text
 if type(label)~='table' and type(label)~='userdata' then return end
 if not label.GetText then return end
 local value=label:GetText() or '';local key=forced or keyFor(value)
 if not key or (b:GetWidth()<70 and value~='X') then
  if b.menuAssetIcon then
   b.menuAssetIcon:Hide();label:Show();label:ClearAllPoints();label:SetPoint('CENTER');label:SetWidth(math.max(12,b:GetWidth()-16))
  end
  return
 end
 if not b.menuAssetIcon then
  b.menuAssetIcon=symbol(b,key,16)
  b:HookScript('OnDisable',function(f) f.menuAssetIcon:SetAlpha(.35) end)
  b:HookScript('OnEnable',function(f) f.menuAssetIcon:SetAlpha(1) end)
 end
 local t=b.menuAssetIcon;texture(t,key);t:Show();t:SetAlpha(b:IsEnabled() and 1 or .35)
 t:SetSize(math.min(18,b:GetHeight()-8),math.min(18,b:GetHeight()-8))
 t:ClearAllPoints()
 if value=='X' then t:SetPoint('CENTER');label:Hide()
 else
  t:SetPoint('LEFT',8,0);label:ClearAllPoints();label:SetPoint('LEFT',30,0);label:SetPoint('RIGHT',-8,0);label:SetJustifyH('CENTER');label:SetWordWrap(false)
 end
end
-- seen: visited-frame guard, same fix and same reasoning as MenuPolish.lua's own walk() -- per
-- live error report 2026-10-01 ("stack overflow" from RefreshPlayerHistoryWindow's decoration
-- pass). This file has its own separate walk() that recurses the same frame tree the same way, so
-- it's vulnerable to the exact same cycle regardless of which file's pass actually hits it first.
local function walk(f,depth,seen)
 if not f or depth>7 then return end
 seen = seen or {}
 if seen[f] then return end
 seen[f] = true
 if f:IsObjectType('Button') then button(f) end
 for _,c in ipairs({f:GetChildren()}) do if c:IsShown() then walk(c,depth+1,seen) end end
end
local filterFields={'viewButton','sortButton','runExpansionFilterButton','runInstanceFilterButton','createInstanceButton','createExpansionButton','expansionButton','instanceButton','difficultyButton','addPlayerKnownButton','addPlayerClassButton','addPlayerRoleButton','dungeonButton','viewModeButton','filterButton','lookbackButton','bossButton','instanceFilterButton'}
local function decorate(f)
 if not f then return end
 walk(f,0)
 -- Root cause of the reported infinite-refresh freeze (2026-10-01, "everything i click... it
 -- freezes" + stack overflow through this exact search box): SetTextInsets was called
 -- UNGUARDED, every single time decorate() ran -- which is every single RefreshPlayerHistoryWindow
 -- call, which is every click on ANY button in that window, not just typing. Changing an EditBox's
 -- text insets makes WoW reflow its displayed text, which fires OnTextChanged as a side effect --
 -- and this search box's OnTextChanged handler (Core.lua) calls Addon:RefreshPlayerHistoryWindow()
 -- on every keystroke by design (live search-as-you-type). That refresh runs decorate() again,
 -- which called SetTextInsets again, which fired OnTextChanged again -- an unbounded loop with no
 -- exit condition, freezing the client until Lua's own call-stack limit aborted it. Guarded the
 -- same way menuSearchIcon already was right above it, so the insets (and the icon) only get set
 -- once, the first time this search box is ever decorated.
 if f.searchBox and not f.searchBox.menuSearchIcon then
  f.searchBox.menuSearchIcon=symbol(f.searchBox,'Search',15,8,0)
  f.searchBox:SetTextInsets(29,9,0,0)
 end
 for _,key in ipairs(filterFields) do if f[key] then button(f[key],key=='sortButton' and 'Sort' or 'Filter') end end
end
local function wrap(method,field,after)
 local old=A[method];if not old then return end
 A[method]=function(self,...)
  local result=old(self,...);local f=self[field]
  if not self:IsUiLocked() then decorate(f);if f and after then after(f,self) end end
  return result
 end
end
local function browser(f)
 for i,tile in ipairs(f.browserStats or {}) do
  if not tile.menuMetricIcon then tile.menuMetricIcon=symbol(tile,({'swords','shield','skull','coins'})[i],24,12,7) end
  -- Keep long repair totals within the remaining space.
  tile.value:ClearAllPoints();tile.value:SetPoint('TOPLEFT',40,-15);tile.value:SetWidth(205)
 end
 for _,row in ipairs(f.rows or {}) do
  if row.runID then
   for role,header in pairs(row.roleHeaders or {}) do
    row.menuRoles=row.menuRoles or {}
    local t=row.menuRoles[role]
    if not t then t=symbol(row,role=='tank' and 'shield' or role=='heals' and 'Healer' or 'swords',14);row.menuRoles[role]=t end
    t:ClearAllPoints();t:SetPoint('RIGHT',header,'LEFT',-4,0);t:SetShown(row:IsShown())
   end
  elseif row.menuRoles then for _,t in pairs(row.menuRoles) do t:Hide() end end
 end
end
local function forms(f)
 if f.runLayout then
  for _,r in ipairs(f.runLayout.partyRows or {}) do
   -- r.role used to be a FontString showing "Tank"/"Healer"/"DPS" text, with this function adding
   -- its own small icon next to it -- MockupLayouts.lua's party-list redesign (2026-10-02) replaced
   -- that with r.roleIcon (a Texture it already colors/positions itself), so there's no FontString
   -- here anymore to read text from, and no need for a second redundant icon either. Guarded
   -- instead of removed from the wrap list, since Core.lua's OWN (unused-but-still-reachable)
   -- renderer still builds the old r.role FontString shape if MockupLayouts.lua is ever disabled.
   if r.role and r.role.GetText then
    local value=r.role:GetText() or '';local key=({Tank='shield',Healer='Healer',DPS='swords',TANK='shield',HEALER='Healer',DAMAGER='swords'})[value]
    if key then
     if not r.menuRoleIcon then r.menuRoleIcon=symbol(f.runLayout,key,14) end
     texture(r.menuRoleIcon,key);r.menuRoleIcon:ClearAllPoints();r.menuRoleIcon:SetPoint('RIGHT',r.role,'LEFT',-4,0);r.menuRoleIcon:Show()
    elseif r.menuRoleIcon then r.menuRoleIcon:Hide() end
   end
  end
 end
end
for _,entry in ipairs({{'CreateWindow','window',browser},{'RefreshWindow','window',browser},{'CreateDataToolsWindow','dataTools',forms},{'RefreshDataToolsWindow','dataTools',forms},{'CreateRepairWindow','repairWindow'},{'RefreshRepairWindow','repairWindow'},{'CreatePlayerHistoryWindow','playerHistoryWindow'},{'RefreshPlayerHistoryWindow','playerHistoryWindow'},{'CreateAddPlayerWindow','addPlayerWindow'},{'RefreshAddPlayerWindow','addPlayerWindow'},{'CreateUpdatePlayerWindow','updatePlayerWindow'},{'RefreshUpdatePlayerWindow','updatePlayerWindow'},{'CreateDebugEditorWindow','debugEditor'},{'RefreshDebugEditorWindow','debugEditor'},{'CreateStatsHubWindow','statsHubWindow'},{'RefreshProgressTabContent','progressTabPanel'},{'RefreshTrendsTabContent','trendsTabPanel'}}) do wrap(unpack(entry)) end
local function pacing(f,self)
 local h=f.horizontalPacing;if not h then return end
 local catalog=self.db and self.db.bossCatalog or {}
 for _,row in ipairs(h.rows) do
  if row:IsShown() and row.point then
   if not row.menuPortraitFrame then
    local frame=CreateFrame('Frame',nil,row);frame:SetSize(40,40);frame:SetPoint('TOPLEFT',7,-10);S.Apply(frame,'Card',4)
    row.menuPortraitFrame=frame;row.menuPortrait=symbol(frame,'skull',32,4,0)
   end
   local t=row.menuPortrait;texture(t,'skull');local display
   for _,boss in pairs(catalog) do
    if boss.name==row.point.bossName and boss.instanceName==self.pacingDungeonName and tonumber(boss.displayID) and tonumber(boss.displayID)>0 then display=tonumber(boss.displayID);break end
   end
   if display and SetPortraitTextureFromCreatureDisplayID then
    t:SetTexCoord(0,1,0,1)
    local ok=pcall(SetPortraitTextureFromCreatureDisplayID,t,display)
    if not ok then texture(t,'skull') end
   end
   row.name:ClearAllPoints();row.name:SetPoint('TOPLEFT',54,-10);row.name:SetWidth(197)
   row.detail:ClearAllPoints();row.detail:SetPoint('TOPLEFT',54,-32);row.detail:SetWidth(197)
  end
 end
end
wrap('RefreshBossPacingTabContent','pacingTabPanel',pacing)

wrap('RefreshSeasonTabContent','seasonTabPanel',function(f)
 for key,name in pairs({runs='swords',completion='shield',highestKeyRun='swords',highestKeyCompleted='Check',avgDeaths='skull'}) do
  local tile=f.kpis and f.kpis[key]
  if tile and not tile.menuMetricIcon then tile.menuMetricIcon=symbol(tile,name,24,10,8) end
 end
end)

wrap('RefreshMythicPlusStatsTabData','mplusTabPanel')
