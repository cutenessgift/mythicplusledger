-- Custom pacing targets (user request 2026-10-08): a target time per boss for its "Travel & pulls"
-- and "Boss fight" stages, saved per dungeon in db.pacingTargets[dungeon][bossKey] =
-- {name, position, pull, fight}. Keyed by boss name, not kill order, so a target follows its boss in
-- dungeons where the order can change. The tracker draws them as red flags and shows how far ahead
-- of or behind the plan the run is; Boss Pacing is where they're set.
local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local red={1,.33,.31};local gold=S.colors.gold;local muted={.62,.66,.68}
-- Off by default (Settings > Tracker > "Use custom target flags", user request 2026-10-08). While
-- off, the tracker keeps its Best flag and every target control here stays hidden.
function A:IsPacingTargetsEnabled() return self.db and self.db.tracker and self.db.tracker.useTargets==true or false end

local function bossKey(name) return (tostring(name or ''):lower():gsub('[%s%p]','')) end
local function clock(v) v=math.max(0,math.floor((v or 0)+.5));return string.format('%d:%02d',math.floor(v/60),v%60) end
-- "5:30", "5.30", "330" (seconds) -> seconds; nil for blank or unreadable.
local function parseClock(text)
 text=strtrim(text or '');if text=='' then return nil end
 local m,s=text:match('^(%d+)[:%.](%d%d?)$')
 if m then return tonumber(m)*60+tonumber(s) end
 return tonumber(text)
end

function A:GetPacingTargets(dungeon)
 local all=self.db and self.db.pacingTargets
 return dungeon and all and all[dungeon] or nil
end
function A:GetPacingTarget(dungeon,bossName)
 local plan=self:GetPacingTargets(dungeon)
 return plan and bossName and plan[bossKey(bossName)] or nil
end
-- pull/fight in seconds; both nil clears that boss.
function A:SetPacingTarget(dungeon,bossName,position,pull,fight)
 if not self.db or not dungeon or not bossName then return end
 self.db.pacingTargets=self.db.pacingTargets or {}
 local plan=self.db.pacingTargets[dungeon] or {};self.db.pacingTargets[dungeon]=plan
 if pull==nil and fight==nil then plan[bossKey(bossName)]=nil
 else plan[bossKey(bossName)]={name=bossName,position=position,pull=pull and math.floor(pull+.5),fight=fight and math.floor(fight+.5)} end
 if not next(plan) then self.db.pacingTargets[dungeon]=nil end
end
function A:ClearPacingTargets(dungeon)
 if self.db and self.db.pacingTargets and dungeon then self.db.pacingTargets[dungeon]=nil end
end

-- For a live run: the target for the stage now running (the boss being fought, else the next
-- planned boss not yet killed) and the drift so far (seconds; positive = behind plan), from the
-- bosses already killed that have a target. nil when the dungeon has no targets.
function A:GetTrackerTargetState(run,segments)
 if not self:IsPacingTargetsEnabled() then return nil end
 local plan=run and self:GetPacingTargets(run.instanceName)
 if not plan or not next(plan) then return nil end
 local killed,drift={},0
 for _,s in ipairs(segments or {}) do
  killed[bossKey(s.bossName)]=true
  local t=plan[bossKey(s.bossName)]
  if t then
   if s.pullSeconds and s.fightSeconds then
    if t.pull then drift=drift+(s.pullSeconds-t.pull) end
    if t.fight then drift=drift+(s.fightSeconds-t.fight) end
   elseif t.pull and t.fight then
    drift=drift+((s.segmentSeconds or 0)-(t.pull+t.fight))
   end
  end
 end
 local current
 local encounter=run.pendingEncounterStartID
 local catalog=encounter and self.db.bossCatalog and self.db.bossCatalog[tostring(encounter)]
 if catalog and catalog.name then current=plan[bossKey(catalog.name)] end
 if not current then
  for _,t in pairs(plan) do
   if not killed[bossKey(t.name)] and (not current or (t.position or 99)<(current.position or 99)) then current=t end
  end
 end
 return {current=current,drift=drift}
end

-- "+0:23 behind target" / "0:41 ahead of target" / "On target", coloured.
function A:FormatTargetDrift(drift)
 if not drift then return '' end
 if drift>=1 then return '|cffff5a54+'..clock(drift)..'|r behind target' end
 if drift<=-1 then return '|cff73e673'..clock(-drift)..'|r ahead of target' end
 return '|cffd8dde0On target|r'
end

---------------------------------------------------------------------------------------------------
-- Boss Pacing: target controls. Wraps BossPacingView.lua's refresh (loaded earlier).
---------------------------------------------------------------------------------------------------
local function tip(f,title,text)
 f:HookScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText(title,1,1,1);GameTooltip:AddLine(text,nil,nil,nil,true);GameTooltip:Show() end)
 f:HookScript('OnLeave',function() GameTooltip:Hide() end)
end
local function label(p,text,x,y,w,size,color)
 local l=S.Label(p,text,size or 11,color);l:SetPoint('TOPLEFT',x,y);if w then l:SetWidth(w) end;l:SetWordWrap(false);return l
end

-- Best = fastest recorded pull and fastest fight for that boss (each on its own).
local function bestFor(dungeon,position)
 local history=A:GetBossPacingRunHistory(dungeon,position,50) or {points={}}
 local pull,fight
 for _,v in ipairs(history.points) do
  if v.avgPull and v.avgFight then
   pull=math.min(pull or math.huge,v.avgPull);fight=math.min(fight or math.huge,v.avgFight)
  end
 end
 return pull,fight
end

local editor
local function openEditor(dungeon,point,host)
 if not editor then
  -- Parented to the Boss Pacing panel and lifted well above it: as a separate UIParent frame it
  -- opened behind the stats window (same strata, lower level) and looked like nothing happened.
  local f=CreateFrame('Frame',nil,host);editor=f;f:SetSize(300,170);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetToplevel(true);f:SetClampedToScreen(true)
  f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag('LeftButton');f:SetScript('OnDragStart',f.StartMoving);f:SetScript('OnDragStop',f.StopMovingOrSizing)
  S.Apply(f,'Window',12)
  f.title=label(f,'',16,-14,268,14,S.colors.white)
  local function box(y,text)
   label(f,text,16,y-5,150,11)
   local e=CreateFrame('EditBox',nil,f,'InputBoxTemplate');e:SetSize(70,22);e:SetPoint('TOPLEFT',190,y);e:SetAutoFocus(false);e:SetMaxLetters(6)
   e:SetScript('OnEscapePressed',function(s) s:ClearFocus() end);return e
  end
  f.pull=box(-46,'Travel & pulls (m:ss)');f.fight=box(-76,'Boss fight (m:ss)')
  f.pull:SetScript('OnTabPressed',function() f.fight:SetFocus() end);f.fight:SetScript('OnTabPressed',function() f.pull:SetFocus() end)
  f.save=S.Button(f,'Save',80,26,function()
   local pull,fight=parseClock(f.pull:GetText()),parseClock(f.fight:GetText())
   f:Hide();A:SetPacingTarget(f.dungeon,f.point.bossName,f.point.position,pull,fight)
   A:RefreshBossPacingTabContent();if A.RefreshTrackerBar then A:RefreshTrackerBar() end
  end);f.save:SetPoint('BOTTOMRIGHT',-14,14)
  f.clear=S.Button(f,'Clear',80,26,function()
   f:Hide();A:SetPacingTarget(f.dungeon,f.point.bossName,f.point.position,nil,nil)
   A:RefreshBossPacingTabContent();if A.RefreshTrackerBar then A:RefreshTrackerBar() end
  end);f.clear:SetPoint('RIGHT',f.save,'LEFT',-8,0)
  f.cancel=S.Button(f,'Cancel',80,26,function() f:Hide() end);f.cancel:SetPoint('RIGHT',f.clear,'LEFT',-8,0)
  -- Matching plain buttons (user request 2026-10-08): the theme's automatic Cancel/Save icons
  -- squeezed "Cancel" to "Can...", so no icons and slightly smaller text on all three.
  for _,b in ipairs({f.cancel,f.clear,f.save}) do
   b.ledgerNoAutoIcon=true;if b.menuAssetIcon then b.menuAssetIcon:Hide() end
   b.Label:SetFont(STANDARD_TEXT_FONT,11,'');b.Label:ClearAllPoints();b.Label:SetPoint('CENTER');b.Label:SetJustifyH('CENTER')
  end
  f.pull:SetScript('OnEnterPressed',function() f.save:Click() end);f.fight:SetScript('OnEnterPressed',function() f.save:Click() end)
 end
 local t=A:GetPacingTarget(dungeon,point.bossName)
 editor.dungeon=dungeon;editor.point=point
 editor.title:SetText('Target · '..(point.bossName or 'Boss'))
 editor.pull:SetText(t and t.pull and clock(t.pull) or '');editor.fight:SetText(t and t.fight and clock(t.fight) or '')
 editor:SetFrameLevel(host:GetFrameLevel()+200);editor:ClearAllPoints();editor:SetPoint('CENTER',host,'CENTER');editor:Show();editor:Raise();editor.pull:SetFocus()
end

local function setAll(dungeon,source)
 local data=A:GetBossPacingData(dungeon,15)
 for _,v in ipairs(data.points or {}) do
  local pull,fight
  if source=='best' then pull,fight=bestFor(dungeon,v.position) else pull,fight=v.avgPull,v.avgFight end
  if pull and fight then A:SetPacingTarget(dungeon,v.bossName,v.position,pull,fight) end
 end
end
local function useRun(dungeon,runID)
 local run=runID and A:GetRun(runID);if not run then return end
 for index,s in ipairs(A:GetBossSegmentTimings(run)) do
  if s.pullSeconds and s.fightSeconds then A:SetPacingTarget(dungeon,s.bossName,index,s.pullSeconds,s.fightSeconds) end
 end
end
local function after() A:RefreshBossPacingTabContent();if A.RefreshTrackerBar then A:RefreshTrackerBar() end end

local function build(u)
 u.targets={buttons={}}
 u.targets.title=label(u,'Targets',630,-81,120,10,gold)
 local x=630
 for _,e in ipairs({
  {'Use my best','Sets every boss to your fastest recorded travel & pulls and fastest fight, each on its own.',function() setAll(A.pacingDungeonName,'best');after() end},
  {'Use my average','Sets every boss to your average travel & pulls and fight times (recent runs this season).',function() setAll(A.pacingDungeonName,'average');after() end},
  {'Clear','Removes all targets for this dungeon.',function() A:ClearPacingTargets(A.pacingDungeonName);after() end},
 }) do
  local w=e[1]=='Clear' and 76 or e[1]=='Use my best' and 132 or 172
  local b=S.Button(u,e[1],w,27,e[3]);b:SetPoint('TOPLEFT',x,-95);tip(b,e[1],e[2]);x=x+w+8;u.targets.buttons[#u.targets.buttons+1]=b
 end
 -- Per-boss target line + Edit, in the compare panel's header.
 u.compareTitle:SetWidth(620)
 u.targets.boss=label(u.compare,'',600,-12,200,10,red);u.targets.boss:SetJustifyH('RIGHT')
 u.targets.edit=S.Button(u.compare,'Edit target',122,22,function() if u.targets.point then openEditor(A.pacingDungeonName,u.targets.point,u) end end)
 u.targets.edit:SetPoint('TOPLEFT',u.compare,'TOPLEFT',810,-7)
 tip(u.targets.edit,'Edit target','Set the travel & pulls and boss fight target for this boss. The tracker shows them as red flags.')
 -- "Use" per run row: copy that run's splits as targets for every boss.
 for _,row in ipairs(u.runRows) do
  row.fight:SetWidth(60)
  row.useRun=S.Button(row,'Use',46,17,function() if row.point then useRun(A.pacingDungeonName,row.point.runID);after() end end)
  row.useRun:SetPoint('TOPRIGHT',row,'TOPRIGHT',-2,-1)
  tip(row.useRun,'Use this run','Sets every boss\'s targets to this run\'s travel & pulls and fight times.')
 end
 u.targets.built=true
end

local function marker(row,name)
 local t=row[name]
 if not t then t=row:CreateTexture(nil,'OVERLAY');t:SetColorTexture(unpack(red));t:SetSize(2,25);row[name]=t end
 return t
end

local old=A.RefreshBossPacingTabContent
function A:RefreshBossPacingTabContent(...)
 old(self,...)
 local p=self.pacingTabPanel;local u=p and p.pacingRedesign;if not u then return end
 if not u.targets then build(u) end
 local on=self:IsPacingTargetsEnabled()
 u.targets.title:SetShown(on);for _,b in ipairs(u.targets.buttons) do b:SetShown(on) end
 u.targets.boss:SetShown(on);u.targets.edit:SetShown(false)
 if not on then
  for _,row in ipairs(u.rows) do if row.targetPullTick then row.targetPullTick:Hide();row.targetTotalTick:Hide() end end
  for _,row in ipairs(u.runRows) do row.useRun:Hide() end
  if editor then editor:Hide() end
  return
 end
 local dungeon=self.pacingDungeonName
 -- Red ticks on each boss's average bar: end of the pull target and end of the whole target.
 local maximum
 for _,row in ipairs(u.rows) do
  if row:IsShown() and row.point then
   local t=self:GetPacingTarget(dungeon,row.point.bossName)
   if not maximum then
    -- Same scale the bars use: the ticks' 0:00 and last labels.
    maximum=300;local data=self:GetBossPacingData(dungeon,15)
    for _,v in ipairs(data.points or {}) do maximum=math.max(maximum,(v.avgPull or v.avgLumped or 0)+(v.avgFight or 0)) end
    maximum=math.max(300,math.ceil(maximum/300)*300)
   end
   local pullTick,totalTick=marker(row,'targetPullTick'),marker(row,'targetTotalTick')
   if t and t.pull and t.fight then
    pullTick:ClearAllPoints();pullTick:SetPoint('TOPLEFT',row,'TOPLEFT',220+682*math.min(1,t.pull/maximum),-10);pullTick:Show()
    totalTick:ClearAllPoints();totalTick:SetPoint('TOPLEFT',row,'TOPLEFT',220+682*math.min(1,(t.pull+t.fight)/maximum),-10);totalTick:Show()
   else pullTick:Hide();totalTick:Hide() end
  end
 end
 -- Selected boss: show its target in the compare header.
 local selected
 for _,row in ipairs(u.rows) do if row:IsShown() and row.highlight:IsShown() then selected=row.point end end
 u.targets.point=selected
 -- An open editor follows the boss selection (user request 2026-10-08); another dungeon closes it.
 if editor and editor:IsShown() then
  if editor.dungeon~=dungeon or not selected then editor:Hide()
  elseif bossKey(editor.point and editor.point.bossName)~=bossKey(selected.bossName) then openEditor(dungeon,selected,u) end
 end
 local t=selected and self:GetPacingTarget(dungeon,selected.bossName)
 u.targets.boss:SetText(t and ('Target  '..(t.pull and clock(t.pull) or '—')..' · '..(t.fight and clock(t.fight) or '—')) or (selected and '|cff9ea6a9No target|r' or ''))
 u.targets.edit:SetShown(selected~=nil)
 for _,row in ipairs(u.runRows) do row.useRun:SetShown(row:IsShown() and row.point and row.point.runID~=nil and row.point.avgPull~=nil) end
end
