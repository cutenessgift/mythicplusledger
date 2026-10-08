local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
local cyan,amber={.15,.78,.88},{.96,.67,.24}
local green,red,muted={.45,.90,.45},{1,.35,.33},{.62,.66,.68}
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local function safe(v) return not (issecretvalue and issecretvalue(v)) end
local function seconds(v) v=math.max(0,math.floor(v or 0));return string.format('%d:%02d',math.floor(v/60),v%60) end
local function options()
 A.db.tracker=A.db.tracker or {};return A.db.tracker
end
local panels=setmetatable({},{__mode='k'})
local function watch(panel)
 if not panel or panels[panel] then return end
 panels[panel]=true
 panel:HookScript('OnShow',function() A:RefreshTrackerBar() end)
 panel:HookScript('OnHide',function() C_Timer.After(0,function() A:RefreshTrackerBar() end) end)
end
local function blocked()
 if options().hideWithMenus==false then return false end
 for p in pairs(panels) do if p:IsVisible() then return true end end
 return false
end
if type(ShowUIPanel)=='function' then hooksecurefunc('ShowUIPanel',function(p) watch(p);A:RefreshTrackerBar() end) end
local function label(p,text,x,y,size,color)
 local l=S.Label(p,text,size or 11,color or S.colors.white);l:SetPoint('TOPLEFT',x,y);l:SetWordWrap(false);return l
end
local function icon(p,size,x,y,asset)
 local t=p:CreateTexture(nil,'ARTWORK');t:SetSize(size,size);t:SetPoint('TOPLEFT',x,y)
 if asset then S.ThemeAsset(t,asset) end
 return t
end
local function divider(p,y)
 local line=p:CreateTexture(nil,'ARTWORK');line:SetPoint('TOPLEFT',12,y);line:SetPoint('TOPRIGHT',-12,y);line:SetHeight(1);line:SetColorTexture(1,1,1,.10);return line
end
local function iconButton(p,file,tip,onClick)
 local b=CreateFrame('Button',nil,p);b:SetSize(18,18)
 b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints();b.icon:SetTexture(file)
 local hl=b:CreateTexture(nil,'HIGHLIGHT');hl:SetAllPoints();hl:SetColorTexture(1,1,1,.18)
 b.tip=tip;b:SetScript('OnClick',onClick)
 b:SetScript('OnEnter',function(f) GameTooltip:SetOwner(f,'ANCHOR_TOP');GameTooltip:SetText(f.tip);GameTooltip:Show() end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 return b
end

-- One timing split ("Travel & pulls" / "Boss fight"): title, bar, current time, a pennant flag at
-- the best time with its label above, and a tick + label for the average below. 38px tall --
-- compact version of the approved tracker_bar.png mockup (user request 2026-10-04: same
-- information, but in the small footprint of the original tracker).
local function buildSplit(parent,title,color,asset)
 local f=CreateFrame('Frame',nil,parent);f:SetHeight(38)
 icon(f,13,0,0,asset)
 f.title=label(f,title,17,0,11,color)
 f.track=CreateFrame('StatusBar',nil,f);f.track:SetPoint('TOPLEFT',0,-17);f.track:SetPoint('TOPRIGHT',-38,-17);f.track:SetHeight(7)
 f.track:SetStatusBarTexture(media..'BarGradient.png');f.track:SetStatusBarColor(unpack(color))
 local bg=f.track:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(1,1,1,.08)
 f.current=label(f,'--',0,0,11,color);f.current:ClearAllPoints();f.current:SetPoint('LEFT',f.track,'RIGHT',6,0)
 -- Pennant made from native texture strips: sharp at every UI scale, no font glyph dependency.
 f.flag=CreateFrame('Frame',nil,f.track);f.flag:SetSize(9,14)
 local pole=f.flag:CreateTexture(nil,'OVERLAY');pole:SetPoint('BOTTOMLEFT');pole:SetSize(1,14);pole:SetColorTexture(1,1,1,.9)
 for row=0,6 do local stripe=f.flag:CreateTexture(nil,'OVERLAY');stripe:SetPoint('TOPLEFT',1,-row);stripe:SetSize(7-row,1);stripe:SetColorTexture(unpack(color)) end
 -- Red pennant for a custom target (PacingTargets.lua), same shape as the best flag.
 f.targetFlag=CreateFrame('Frame',nil,f.track);f.targetFlag:SetSize(9,14)
 local targetPole=f.targetFlag:CreateTexture(nil,'OVERLAY');targetPole:SetPoint('BOTTOMLEFT');targetPole:SetSize(1,14);targetPole:SetColorTexture(1,.9,.9,.95)
 for row=0,6 do local stripe=f.targetFlag:CreateTexture(nil,'OVERLAY');stripe:SetPoint('TOPLEFT',1,-row);stripe:SetSize(7-row,1);stripe:SetColorTexture(unpack(red)) end
 f.color=color
 f.best=label(f,'',0,0,9,{.80,.84,.88})
 f.averageTick=f.track:CreateTexture(nil,'OVERLAY');f.averageTick:SetSize(1,5);f.averageTick:SetColorTexture(.75,.80,.82,1)
 f.average=label(f,'',0,0,9,muted)
 -- targetMode (Settings > Tracker > "Use custom target flags"): the red target flag replaces the
 -- best flag -- the two never show together -- and the label shows the target ("No target" when
 -- this boss has none). Off: best flag and label as before.
 function f:Update(value,average,best,target,targetMode)
  if not targetMode then target=nil end
  local maximum=math.max(value or 0,(average or 0)*1.2,(best or 0)*1.2,(target or 0)*1.2,60)
  local width=self.track:GetWidth()
  self.track:SetMinMaxValues(0,maximum);self.track:SetValue(value or 0)
  self.current:SetText(value and seconds(value) or '--')
  self.current:SetTextColor(unpack((target and value and value>target) and red or self.color))
  local flagX=best and width*best/maximum or 0
  self.flag:ClearAllPoints();self.flag:SetPoint('BOTTOMLEFT',self.track,'TOPLEFT',flagX,-3);self.flag:SetShown(best~=nil and not targetMode)
  local targetX=target and width*target/maximum or 0
  self.targetFlag:ClearAllPoints();self.targetFlag:SetPoint('BOTTOMLEFT',self.track,'TOPLEFT',targetX,-3);self.targetFlag:SetShown(target~=nil)
  -- The label sits above the flag's tip (11px over the bar), centred on it -- it used to overlap
  -- the pennant (user report 2026-10-08) -- but never over the split title or past the bar's end.
  -- With a target set it shows the target (red); otherwise the best time.
  local labelX=target and targetX or (targetMode and 0 or flagX)
  if target then self.best:SetText('Target '..seconds(target));self.best:SetTextColor(unpack(red))
  elseif targetMode then self.best:SetText('No target');self.best:SetTextColor(unpack(muted))
  else self.best:SetText(best and ('Best '..seconds(best)) or 'Best --');self.best:SetTextColor(.80,.84,.88) end
  local bestWidth=self.best:GetStringWidth()
  self.best:ClearAllPoints();self.best:SetPoint('BOTTOMLEFT',self.track,'TOPLEFT',math.max(self.title:GetStringWidth()+26,math.min(width-bestWidth,labelX+4-bestWidth/2)),12)
  self.averageTick:ClearAllPoints();self.averageTick:SetPoint('TOP',self.track,'BOTTOMLEFT',average and width*average/maximum or 0,0);self.averageTick:SetShown(average~=nil)
  self.average:SetText(average and ('Average '..seconds(average)) or 'No matching history')
  self.average:ClearAllPoints()
  local avgX=average and width*average/maximum or 0
  self.average:SetPoint('TOPLEFT',self.track,'BOTTOMLEFT',math.max(0,math.min(width-self.average:GetStringWidth(),avgX-self.average:GetStringWidth()/2)),-5)
 end
 return f
end

-- Builds the compact tracker contents on any frame: the live bar and the /test preview share it so
-- the preview always looks exactly like the real thing.
--   header   : logo, "M+ Ledger", dungeon + key, settings/lock (or close) buttons
--   timer    : elapsed / limit, time remaining (green) or overtime (red)
--   splits   : Travel & pulls | Boss fight, each with best flag and average tick
--   forces   : Enemy forces % bar | Bosses n / total
--   summary  : Deaths total | Interrupts total (hover for the per-player breakdown)
local function buildTracker(b,closeInstead)
 b.ledgerTracker=true
 b.logo=icon(b,16,10,-7);b.logo:SetTexture('Interface\\Icons\\Achievement_ChallengeMode_Gold');b.logo:SetTexCoord(.08,.92,.08,.92)
 b.brand=label(b,'M+ Ledger',31,-9,12);S.ThemeText(b.brand)
 b.dungeon=label(b,'',0,0,12);b.dungeon:ClearAllPoints();b.dungeon:SetPoint('LEFT',b.brand,'RIGHT',8,0);b.dungeon:SetPoint('RIGHT',b,'RIGHT',-60,0);b.dungeon:SetJustifyH('LEFT')
 if closeInstead then
  b.close=iconButton(b,'Interface\\Buttons\\UI-StopButton','Close preview',function() b:Hide() end);b.close:SetPoint('TOPRIGHT',-10,-6)
 else
  b.settings=iconButton(b,'Interface\\Buttons\\UI-OptionsButton','M+ Ledger options',function() A:OpenSettings() end);b.settings:SetPoint('TOPRIGHT',-10,-6)
  b.lock=iconButton(b,'Interface\\Buttons\\LockButton-Locked-Up','Lock position',function() options().locked=not options().locked;A:RefreshTrackerBar() end);b.lock:SetPoint('RIGHT',b.settings,'LEFT',-6,0)
 end
 b.rule1=divider(b,-29)
 b.clock=icon(b,14,10,-36);b.clock:SetTexture('Interface\\Icons\\Spell_Holy_BorrowedTime');b.clock:SetTexCoord(.08,.92,.08,.92)
 b.timer=label(b,'',30,-34,15)
 b.remaining=label(b,'',0,0,12,green);b.remaining:ClearAllPoints();b.remaining:SetPoint('TOPRIGHT',-12,-37)
 -- "+0:23 behind target" when the dungeon has custom targets (PacingTargets.lua).
 b.targetDrift=label(b,'',0,0,11);b.targetDrift:ClearAllPoints();b.targetDrift:SetPoint('RIGHT',b.remaining,'LEFT',-14,0)
 b.rule2=divider(b,-57)
 b.pull=buildSplit(b,'Travel & pulls',cyan,'travel');b.fight=buildSplit(b,'Boss fight',amber,'boss-fights')
 b.rule3=divider(b,-106)
 b.forcesLabel=label(b,'',12,-112,11)
 b.forces=CreateFrame('StatusBar',nil,b);b.forces:SetHeight(6);b.forces:SetStatusBarTexture(media..'BarGradient.png');b.forces:SetStatusBarColor(unpack(cyan));b.forces:SetMinMaxValues(0,100)
 local forcesBg=b.forces:CreateTexture(nil,'BACKGROUND');forcesBg:SetAllPoints();forcesBg:SetColorTexture(1,1,1,.08)
 b.bosses=label(b,'',0,0,11);b.bosses:ClearAllPoints();b.bosses:SetPoint('TOPRIGHT',-12,-112)
 b.forces:SetPoint('LEFT',b.forcesLabel,'RIGHT',8,0);b.forces:SetPoint('RIGHT',b.bosses,'LEFT',-12,0)
 b.summary=CreateFrame('Frame',nil,b);b.summary:SetHeight(16);b.summary:EnableMouse(true)
 b.deathIcon=icon(b.summary,12,0,-1,'deaths-silver')
 b.deathText=label(b.summary,'',16,0,11)
 b.kickIcon=icon(b.summary,12,0,-1);b.kickIcon:SetTexture('Interface\\Icons\\Ability_Kick');b.kickIcon:SetTexCoord(.08,.92,.08,.92)
 b.kickText=label(b.summary,'',0,0,11)
 b.summary:SetScript('OnEnter',function(f)
  if not f.deathDetail then return end
  GameTooltip:SetOwner(f,'ANCHOR_BOTTOM');GameTooltip:SetText('Party breakdown')
  GameTooltip:AddLine('Deaths: '..f.deathDetail,1,1,1,true)
  GameTooltip:AddLine('Interrupts (observed; may be partial): '..f.kickDetail,.8,.85,.88,true)
  GameTooltip:Show()
 end)
 b.summary:SetScript('OnLeave',function() GameTooltip:Hide() end)
end

-- data: dungeon, keyLevel, elapsed, limit, pull/pullAvg/pullBest, fight/fightAvg/fightBest,
-- forces (0-100 or nil), bossesDone, bossesTotal, deaths, interrupts, deathDetail, kickDetail,
-- showSplits, showForces, showDeaths, showInterrupts, idleText (when there is no run).
local function paintTracker(b,data)
 local width=b:GetWidth()
 if data.idleText then
  b.dungeon:SetText('|cffa0a8ac·|r  '..data.idleText)
  for _,k in ipairs({'rule1','clock','timer','remaining','targetDrift','rule2','pull','fight','rule3','forcesLabel','forces','bosses','summary'}) do b[k]:Hide() end
  b:SetHeight(30)
  return
 end
 b.dungeon:SetText((data.dungeon or 'Current run')..((data.keyLevel or 0)>0 and ('  ·  +'..data.keyLevel) or ''))
 b.rule1:Show();b.clock:Show();b.timer:Show();b.remaining:Show()
 b.timer:SetText(seconds(data.elapsed)..(data.limit and ('  |cff9aa3a8/ '..seconds(data.limit)..'|r') or ''))
 if data.limit then
  local over=data.elapsed>data.limit
  b.remaining:SetText(seconds(math.abs(data.limit-data.elapsed))..(over and ' overtime' or ' remaining'))
  b.remaining:SetTextColor(unpack(over and red or green))
 else b.remaining:SetText('') end
 b.targetDrift:SetText(data.targetDrift and A:FormatTargetDrift(data.targetDrift) or '');b.targetDrift:Show()
 local y=-57
 local splits=data.showSplits~=false
 b.rule2:SetShown(splits);b.pull:SetShown(splits);b.fight:SetShown(splits)
 if splits then
  local half=(width-24-20)/2
  b.pull:ClearAllPoints();b.pull:SetPoint('TOPLEFT',12,y-7);b.pull:SetWidth(half)
  b.fight:ClearAllPoints();b.fight:SetPoint('TOPLEFT',12+half+20,y-7);b.fight:SetWidth(half)
  b.pull:Update(data.pull,data.pullAvg,data.pullBest,data.pullTarget,data.targetMode)
  b.fight:Update(data.fight,data.fightAvg,data.fightBest,data.fightTarget,data.targetMode)
  y=y-49
 end
 local forces=data.showForces~=false
 b.rule3:SetShown(forces);b.forcesLabel:SetShown(forces);b.forces:SetShown(forces);b.bosses:SetShown(forces)
 if forces then
  b.rule3:ClearAllPoints();b.rule3:SetPoint('TOPLEFT',12,y);b.rule3:SetPoint('TOPRIGHT',-12,y)
  b.forcesLabel:ClearAllPoints();b.forcesLabel:SetPoint('TOPLEFT',12,y-6)
  b.forcesLabel:SetText(data.forces and string.format('Enemy forces  |cff27c7e0%.0f%%|r',data.forces) or 'Enemy forces  |cff9aa3a8--|r')
  b.forces:SetValue(data.forces or 0)
  b.bosses:ClearAllPoints();b.bosses:SetPoint('TOPRIGHT',-12,y-6)
  b.bosses:SetText('Bosses  |cfff5ab3d'..(data.bossesDone or 0)..(data.bossesTotal and data.bossesTotal>0 and (' / '..data.bossesTotal) or '')..'|r')
  y=y-20
 end
 local showDeaths,showKicks=data.showDeaths~=false,data.showInterrupts~=false
 b.summary:SetShown(showDeaths or showKicks)
 if showDeaths or showKicks then
  b.summary:ClearAllPoints();b.summary:SetPoint('TOPLEFT',12,y-4);b.summary:SetPoint('TOPRIGHT',-12,y-4)
  b.deathIcon:SetShown(showDeaths);b.deathText:SetShown(showDeaths)
  b.deathText:SetText('Deaths  |cffff5a54'..(data.deaths or 0)..'|r')
  local x=showDeaths and 110 or 0
  b.kickIcon:SetShown(showKicks);b.kickText:SetShown(showKicks)
  b.kickIcon:ClearAllPoints();b.kickIcon:SetPoint('TOPLEFT',x,-1)
  b.kickText:ClearAllPoints();b.kickText:SetPoint('TOPLEFT',x+16,0)
  b.kickText:SetText('Interrupts  |cfff5c84a'..(data.interrupts or 0)..'|r  |cff9aa3a8observed|r')
  b.summary.deathDetail=data.deathDetail;b.summary.kickDetail=data.kickDetail
  y=y-20
 end
 b:SetHeight(-y+8)
end

local function partyTotals(run)
 local deaths,kicks=0,0
 for _,m in ipairs(run and run.members or {}) do
  deaths=deaths+(tonumber(A:GetMemberDeathCount(run,m)) or 0)
  kicks=kicks+(tonumber(A:GetMemberInterruptCount(run,m)) or 0)
 end
 return deaths,kicks
end

function A:GetTrackerBenchmarks(run,position)
 local opt=options();local key=tostring(run.id)..':'..position..':'..tostring(opt.sameKey~=false)..':'..tostring(opt.lookback or 15)..':'..tostring(#(self.db.runOrder or {}))
 if self.trackerBenchKey==key then return self.trackerBench end
 local result={n=0,pull=0,fight=0}
 for _,id in ipairs(self.db.runOrder or {}) do
  local r=self:GetRun(id)
  if r and r~=run and r.instanceName==run.instanceName and self:IsMythicPlusRun(r) and self:RunMatchesCurrentSeason(r) and (opt.sameKey==false or self:GetRunKeyLevel(r)==self:GetRunKeyLevel(run)) then
   local status=self:GetRunStatus(r)
   if status=='Completed' or status=='CompletedOvertime' then
    local segment=self:GetBossSegmentTimings(r)[position]
    if segment and segment.pullSeconds and segment.fightSeconds then
     result.n=result.n+1;result.pull=result.pull+segment.pullSeconds;result.fight=result.fight+segment.fightSeconds
     result.bestPull=math.min(result.bestPull or math.huge,segment.pullSeconds);result.bestFight=math.min(result.bestFight or math.huge,segment.fightSeconds)
     if result.n>=(opt.lookback or 15) then break end
    end
   end
  end
 end
 if result.n>0 then result.pull=result.pull/result.n;result.fight=result.fight/result.n else result.pull=nil;result.fight=nil end
 self.trackerBenchKey=key;self.trackerBench=result;return result
end
function A:GetTrackerForces()
 if not C_ScenarioInfo or not C_ScenarioInfo.GetScenarioStepInfo then return nil end
 local ok,step=pcall(C_ScenarioInfo.GetScenarioStepInfo)
 if not ok or not step or not safe(step.numCriteria) then return nil end
 for i=1,math.min(30,step.numCriteria or 0) do
  local success,c=pcall(C_ScenarioInfo.GetCriteriaInfo,i)
  if success and c and safe(c.isWeightedProgress) and c.isWeightedProgress and safe(c.quantity) and type(c.quantity)=='number' then
   -- Weighted criteria quantity is already a percentage, not quantity / totalQuantity.
   return math.max(0,math.min(100,c.quantity))
  end
 end
end
-- Total bosses in the current key: every scenario criterion except the weighted enemy-forces one.
function A:GetTrackerBossTotal()
 if not C_ScenarioInfo or not C_ScenarioInfo.GetScenarioStepInfo then return nil end
 local ok,step=pcall(C_ScenarioInfo.GetScenarioStepInfo)
 if not ok or not step or not safe(step.numCriteria) then return nil end
 local total=0
 for i=1,math.min(30,step.numCriteria or 0) do
  local success,c=pcall(C_ScenarioInfo.GetCriteriaInfo,i)
  if success and c and safe(c.isWeightedProgress) and not c.isWeightedProgress then total=total+1 end
 end
 return total>0 and total or nil
end

local oldCreate=A.CreateTrackerBar
function A:CreateTrackerBar()
 oldCreate(self)
 local b=self.trackerBar;if not b or b.experience then return end
 b.experience=true;b:SetClampedToScreen(true);b:SetScript('OnUpdate',nil);b:SetFrameStrata('LOW');b:SetFrameLevel(5);b:SetBackdrop(nil);S.Apply(b,'Window',12)
 b:SetScript('OnDragStart',function(f) if not options().locked then f:StartMoving() end end)
 b.resizer:SetScript('OnMouseDown',function(f) if not options().locked then f:GetParent():StartSizing('RIGHT') end end)
 -- Core.lua's original one-line text fields are replaced by the compact layout below.
 for _,k in ipairs({'title','meta','deaths','interrupts'}) do if b[k] then b[k]:Hide() end end
 buildTracker(b)
 b:SetResizeBounds(380,30,760,220)
end
function A:RefreshTrackerBar()
 if not self.db then return end
 for _,name in ipairs({'GameMenuFrame','SettingsPanel','AchievementFrame','PVEFrame','CharacterFrame','CollectionsJournal','EncounterJournal','WorldMapFrame','SpellBookFrame','PlayerSpellsFrame'}) do watch(_G[name]) end
 local opt=options();local run=self:GetCurrentRun()
 if not opt.shown or blocked() or (not run and opt.hideIdle==true) then if self.trackerBar then self.trackerBar:Hide() end;return end
 self:CreateTrackerBar();local b=self.trackerBar;if not b or not b.ledgerTracker then return end
 -- Default 440 wide (was 540); old saved widths above the new compact range are clamped.
 b:SetScale(opt.scale or 1);b:SetAlpha(opt.opacity or 1);b:SetWidth(math.max(380,math.min(760,opt.width or 440)))
 b.lock.icon:SetTexture(opt.locked and 'Interface\\Buttons\\LockButton-Locked-Up' or 'Interface\\Buttons\\LockButton-Unlocked-Up')
 b.lock.tip=opt.locked and 'Unlock position' or 'Lock position'
 b.resizer:SetShown(not opt.locked and run~=nil)
 if not run then paintTracker(b,{idleText='Waiting for a run'});b:Show();return end
 local elapsed=math.max(0,time()-(run.timerStartedAt or run.challengeStartedAt or run.timingStartedAt or run.startedAt or time()))
 local limit=self:IsMythicPlusRun(run) and self:GetMythicPlusTimeLimit(run) or nil
 local segments=self:GetBossSegmentTimings(run);local position=#segments+1;local prior=segments[#segments];local previous=prior and prior.cumulativeSeconds or 0
 local start=run.pendingEncounterStartTime
 local bench=self:GetTrackerBenchmarks(run,position)
 local deaths,kicks=partyTotals(run)
 local pullNow=math.max(0,(start or elapsed)-previous);local fightNow=start and math.max(0,elapsed-start) or nil
 -- Custom targets (PacingTargets.lua): this stage's red flags, and drift = finished bosses vs plan
 -- plus any overrun in the stage still running (time under target isn't banked until it's done).
 local state=self.GetTrackerTargetState and self:GetTrackerTargetState(run,segments)
 local target=state and state.current;local drift=state and state.drift
 if drift and target then
  if target.pull and pullNow>target.pull then drift=drift+(pullNow-target.pull) end
  if target.fight and fightNow and fightNow>target.fight then drift=drift+(fightNow-target.fight) end
 end
 paintTracker(b,{
  dungeon=run.instanceName,keyLevel=self:GetRunKeyLevel(run) or 0,elapsed=elapsed,limit=limit,
  pull=pullNow,pullAvg=bench.pull,pullBest=bench.bestPull,
  fight=fightNow,fightAvg=bench.fight,fightBest=bench.bestFight,
  pullTarget=target and target.pull,fightTarget=target and target.fight,targetDrift=drift,targetMode=opt.useTargets==true,
  forces=self:IsMythicPlusRun(run) and self:GetTrackerForces() or nil,bossesDone=#segments,bossesTotal=self:GetTrackerBossTotal(),
  deaths=deaths,interrupts=kicks,deathDetail=self:GetDeathSummary(run),kickDetail=self:GetInterruptSummary(run),
  showSplits=opt.showSplits,showForces=opt.showForces~=false and opt.showSplits~=false,showDeaths=opt.showDeaths,showInterrupts=opt.showInterrupts,
 })
 b:Show()
end
local events=CreateFrame('Frame');events:RegisterEvent('ADDON_LOADED');events:RegisterEvent('PLAYER_ENTERING_WORLD');events:RegisterEvent('PLAYER_REGEN_ENABLED');events:RegisterEvent('SCENARIO_CRITERIA_UPDATE')
events:SetScript('OnEvent',function() if A.db then A:RefreshTrackerBar() end end)
-- A hidden tracker cannot run its own OnUpdate; this lightweight driver restores it after menus close.
local elapsed=0
events:SetScript('OnUpdate',function(_,dt) elapsed=elapsed+dt;if elapsed>=1 then elapsed=0;if A.db and A.db.tracker and A.db.tracker.shown then A:RefreshTrackerBar() end end end)


-- Isolated snapshot: never swaps the live run, tracker or SavedVariables. Uses the exact same
-- compact layout as the live bar, filled from your most recent finished run.
function A:ShowTrackerPreview()
 if not self.db then return end
 local run
 for _,id in ipairs(self.db.runOrder or {}) do
  local candidate=self:GetRun(id)
  if candidate and candidate~=self:GetCurrentRun() and (candidate.endedAt or candidate.completedAt) then
   if not run or (candidate.endedAt or candidate.completedAt)>(run.endedAt or run.completedAt) then run=candidate end
  end
 end
 local b=self.trackerPreview
 if not b then
  b=CreateFrame('Frame',nil,UIParent);self.trackerPreview=b;b:SetSize(440,150);b:SetPoint('TOP',0,-100);b:SetFrameStrata('DIALOG');b:SetClampedToScreen(true)
  b:SetMovable(true);b:EnableMouse(true);b:RegisterForDrag('LeftButton');b:SetScript('OnDragStart',b.StartMoving);b:SetScript('OnDragStop',b.StopMovingOrSizing)
  S.Apply(b,'Window',12)
  buildTracker(b,true)
 end
 -- No finished run yet (fresh install): show a made-up example run instead of an empty bar, so
 -- the preview still shows what the tracker looks like (user request 2026-10-08).
 if not run then
  local opt=options()
  paintTracker(b,{
   dungeon='TEST · Example: Voidscar Arena',keyLevel=10,elapsed=1467,limit=1800,
   pull=329,pullAvg=352,pullBest=301,fight=371,fightAvg=388,fightBest=344,
   pullTarget=315,fightTarget=360,targetDrift=opt.useTargets==true and 25 or nil,targetMode=opt.useTargets==true,
   forces=100,bossesDone=3,bossesTotal=3,deaths=4,interrupts=17,
   deathDetail='ExampleTank 1, ExampleHealer 1, ExampleDamage 2',kickDetail='ExampleTank 6, ExampleDamage 7, ExampleFriend 4',
   showSplits=opt.showSplits,showForces=opt.showForces~=false and opt.showSplits~=false,showDeaths=opt.showDeaths,showInterrupts=opt.showInterrupts,
  })
  b:Show();return
 end
 local segments=self:GetBossSegmentTimings(run)
 local index=math.max(1,#segments);local segment=segments[index]
 local bench=self:GetTrackerBenchmarks(run,index)
 local pull=segment and segment.pullSeconds;local fight=segment and segment.fightSeconds
 -- With no other matching run, best and average fall back to this run's own split.
 local reference=bench.n==0 and pull~=nil and fight~=nil
 local start=run.timerStartedAt or run.challengeStartedAt or run.timingStartedAt or run.startedAt
 local finish=run.endedAt or run.completedAt
 local duration=tonumber(run.duration) or (start and finish and math.max(0,finish-start)) or 0
 -- Summary helpers can initialize member tables: give them a copy, never the saved run.
 local copy=CopyTable(run)
 local deaths,kicks=partyTotals(copy)
 local opt=options()
 -- Targets for the last boss of that run, and how the whole run compared with the plan.
 local previewTarget=segment and self.GetPacingTarget and self:GetPacingTarget(run.instanceName,segment.bossName)
 local previewState=self.GetTrackerTargetState and self:GetTrackerTargetState(copy,segments)
 paintTracker(b,{
  dungeon='TEST · '..(run.instanceName or 'Last run'),keyLevel=self:GetRunKeyLevel(run) or 0,elapsed=duration,
  limit=self:IsMythicPlusRun(run) and self:GetMythicPlusTimeLimit(run) or nil,
  pull=pull,pullAvg=reference and pull or bench.pull,pullBest=reference and pull or bench.bestPull,
  fight=fight,fightAvg=reference and fight or bench.fight,fightBest=reference and fight or bench.bestFight,
  forces=nil,bossesDone=#segments,
  pullTarget=previewTarget and previewTarget.pull,fightTarget=previewTarget and previewTarget.fight,
  targetDrift=previewState and previewState.drift,targetMode=opt.useTargets==true,
  deaths=deaths,interrupts=kicks,deathDetail=self:GetDeathSummary(copy),kickDetail=self:GetInterruptSummary(copy),
  showSplits=opt.showSplits,showForces=opt.showForces~=false and opt.showSplits~=false,showDeaths=opt.showDeaths,showInterrupts=opt.showInterrupts,
 })
 b:Show()
end
-- End-of-dungeon "Rate Your Party" popup with a made-up party (user request 2026-10-08). Shown in
-- preview mode, so Save only closes it and nothing reaches Player History.
function A:PreviewRatingPopup()
 self:PromptPlayerRatings({id='test-preview',instanceName='Voidscar Arena',members={
  {name='ExampleTank-Illidan',class='PALADIN',role='TANK',race='Human',faction='Alliance'},
  {name='ExampleHealer-Barthilas',class='PRIEST',role='HEALER',race='Draenei',faction='Alliance'},
  {name='ExampleDamage-Frostmourne',class='MAGE',role='DAMAGER',race='Gnome',faction='Alliance'},
  {name='ExampleFriend-Area52',class='DRUID',role='DAMAGER',race='Night Elf',faction='Alliance'},
 }},true)
end
function A:ToggleTestPreview(forceClose)
 local rating=self.ratingPopup and self.ratingPopup.preview and self.ratingPopup
 local open=(self.trackerPreview and self.trackerPreview:IsShown()) or (self.previewApplicantPanel and self.previewApplicantPanel:IsShown()) or (rating and rating:IsShown())
 if forceClose or open then
  if self.trackerPreview then self.trackerPreview:Hide() end
  if self.previewApplicantPanel then self.previewApplicantPanel:Hide() end
  if rating then rating:Hide() end
  return
 end
 self:ShowTrackerPreview();self:PreviewApplicantAlert()
 self.previewApplicantPanel:ClearAllPoints();self.previewApplicantPanel:SetPoint('TOP',self.trackerPreview,'BOTTOM',0,-12)
 -- Beside the tracker + applicant column rather than centred on top of them.
 self:PreviewRatingPopup()
 if self.ratingPopup then
  self.ratingPopup:ClearAllPoints();self.ratingPopup:SetPoint('TOPLEFT',self.trackerPreview,'TOPRIGHT',16,0);self.ratingPopup:SetClampedToScreen(true)
 end
end
