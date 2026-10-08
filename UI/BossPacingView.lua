-- Boss overview and individual-run comparison stay visible together.
local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local gold=S.colors.gold;local cyan={.17,.77,.88};local amber={.94,.65,.22}
local art={['Den of Nalorakk']='DenOfNalorakk',['Altar of Fangs']='AltarOfFangs',["Kings' Rest"]='KingsRest',["King's Rest"]='KingsRest',['Ruby Life Pools']='RubyLifePools',['Voidscar Arena']='VoidscarArena',['The Blinding Vale']='TheBlindingVale',['Murder Row']='MurderRow',['Temple of Sethraliss']='TempleOfSethraliss'}
-- Shared dungeon-art pack; landscape textures keep their 2:1 proportions.
art["Magisters' Terrace"]="MagistersTerrace"
art["Maisara Caverns"]="MaisaraCaverns"
art["Nexus-Point Xenas"]="NexusPointXenas"
art["Windrunner Spire"]="WindrunnerSpire"
art["Algeth'ar Academy"]="AlgetharAcademy"
art["Pit of Saron"]="PitOfSaron"
art["Seat of the Triumvirate"]="SeatOfTriumvirate"
art["Skyreach"]="Skyreach"
art["The Underrot"]="TheUnderrot"
art["Iron Docks"]="IronDocks"
art["Sanguine Depths"]="SanguineDepths"
art["The Stonecore"]="TheStonecore"
art["Uldaman: Legacy of Tyr"]="UldamanLegacyOfTyr"
art["Ara-Kara, City of Echoes"]="AraKara"
art["City of Threads"]="CityOfThreads"
art["The Stonevault"]="TheStonevault"
art["The Dawnbreaker"]="TheDawnbreaker"
art["Mists of Tirna Scithe"]="MistsOfTirnaScithe"
art["The Necrotic Wake"]="TheNecroticWake"
art["Siege of Boralus"]="SiegeOfBoralus"
art["Grim Batol"]="GrimBatol"
art["Operation: Floodgate"]="OperationFloodgate"
art["Priory of the Sacred Flame"]="PrioryOfSacredFlame"
art["Eco-Dome Al'dani"]="EcoDomeAldani"
art["Halls of Atonement"]="HallsOfAtonement"
art["Tazavesh: Streets of Wonder"]="TazaveshStreets"
art["Tazavesh: So'leah's Gambit"]="TazaveshGambit"

local function place(f,p,x,y,w,h)
 f:ClearAllPoints();f:SetPoint('TOPLEFT',p,'TOPLEFT',x,y);if w then f:SetWidth(w) end;if h then f:SetHeight(h) end
end
local function label(p,value,x,y,w,size,color)
 local t=S.Label(p,value,size or 11,color);place(t,p,x,y,w);t:SetWordWrap(false);return t
end
local function panel(p,x,y,w,h)
 local f=CreateFrame('Frame',nil,p);place(f,p,x,y,w,h);f:SetFrameLevel(p:GetFrameLevel()+1);S.Apply(f,'Window',9)
 -- Keep the skin artwork instead of replacing its center with a flat dark fill.
 return f
end
local function duration(v)
 if v==nil then return '—' end
 v=math.max(0,math.floor(v+.5));return string.format('%d:%02d',math.floor(v/60),v%60)
end
local function parts(v)
 if v.avgPull~=nil and v.avgFight~=nil then return math.max(0,v.avgPull),math.max(0,v.avgFight),true end
 return math.max(0,v.avgLumped or 0),0,false
end
local portraits={}
local journalImages={}
local function normalized(v)
 return tostring(v or ''):lower():gsub('[%s%p]','')
end
local function usable(displayID)
 return type(displayID)=='number' and displayID>0
end
function A:GetPacingPortrait(dungeon,name)
 if not dungeon or not name then return nil end
 local key=normalized(name);local cache=portraits[dungeon] or {};portraits[dungeon]=cache
 local images=journalImages[dungeon] or {};journalImages[dungeon]=images
 if cache[key] then return cache[key],images[key] end
 -- Do not cache misses: Journal data may be unavailable on the first refresh.
 if self.LoadEncounterJournalForIconDump then self:LoadEncounterJournalForIconDump() end
 local tier=EJ_GetCurrentTier and EJ_GetCurrentTier()
 local id=self.FindJournalInstanceByName and self:FindJournalInstanceByName(dungeon)
 if id and EJ_GetEncounterInfoByIndex and EJ_GetCreatureInfo then
  for i=1,30 do
   local ok,boss,_,encounter=pcall(EJ_GetEncounterInfoByIndex,i,id)
   if not ok or not boss then break end
   for creature=1,10 do
    local success,creatureID,creatureName,_,displayID,iconImage=pcall(EJ_GetCreatureInfo,creature,encounter)
    if not success or not creatureID then break end
    if iconImage and iconImage~=0 and iconImage~='' then
     images[normalized(creatureName)]=iconImage
     if not images[normalized(boss)] then images[normalized(boss)]=iconImage end
    end
    if usable(displayID) then
     cache[normalized(creatureName)]=displayID
     if not cache[normalized(boss)] then cache[normalized(boss)]=displayID end
    end
   end
  end
 end
 if tier and EJ_SelectTier then pcall(EJ_SelectTier,tier) end
 if cache[key] then return cache[key],images[key] end
 -- Recorded model display IDs are distinct from NPC and encounter IDs.
 for _,boss in pairs(self.db and self.db.bossCatalog or {}) do
  local displayID=tonumber(boss.displayID)
  if normalized(boss.instanceName)==normalized(dungeon) and normalized(boss.name)==key and usable(displayID) then
   cache[key]=displayID;return displayID,images[key]
  end
 end
 return nil,images[key]
end
-- Adventure Guide boss image for this boss: from the pacing lookup, else from the dungeon
-- catalogue's journal ID (MockupLayouts.lua's GetLedgerJournalDetails) -- the second route still
-- works when FindJournalInstanceByName can't resolve the dungeon name.
local function guideImage(dungeon,name)
 local displayID,image=A:GetPacingPortrait(dungeon,name)
 if image then return image,displayID end
 local entry=A.GetLedgerDungeonCatalogue and A:GetLedgerDungeonCatalogue()[dungeon]
 local details=entry and A.GetLedgerJournalDetails and A:GetLedgerJournalDetails(entry.journalInstanceID)
 for _,boss in ipairs(details and details.bosses or {}) do
  if normalized(boss.name)==normalized(name) and boss.icon then return boss.icon,displayID end
 end
 return nil,displayID
end
-- Guide boss images first (the cut-out boss renders the in-game guide uses, no circular crop --
-- user request 2026-10-04 "remove the circles"); the round model portrait only when the guide has
-- no image. Leave unavailable portraits empty, never substitute a skull or unrelated icon.
local function portrait(t,dungeon,name)
 local image,displayID=guideImage(dungeon,name)
 t:SetTexCoord(0,1,0,1)
 if image then t:SetTexture(image);t:Show();return end
 t:SetTexture(nil);t:Hide()
 if displayID and SetPortraitTextureFromCreatureDisplayID and pcall(SetPortraitTextureFromCreatureDisplayID,t,displayID) then t:Show() end
end
local function bar(p,x,y,w,h)
 local f=CreateFrame('Frame',nil,p);place(f,p,x,y,w,h);f.parts={};f.labels={}
 for i=1,2 do
  local t=f:CreateTexture(nil,'ARTWORK');t:SetTexture(media..'BarGradient.png');t:SetHeight(h);f.parts[i]=t
  local l=label(f,'',0,-2,w,10);l:SetJustifyH('CENTER');l:SetTextColor(.015,.055,.06);f.labels[i]=l
 end
 function f:Update(v,maximum)
  local a,b,split=parts(v);local offset=0
  for i,value in ipairs({a,b}) do
   local width=w*value/maximum;local t=self.parts[i];place(t,self,offset,0,math.max(.01,width),h);t:SetShown(value>0)
   if not split then t:SetVertexColor(.45,.5,.53) else t:SetVertexColor(unpack(i==1 and cyan or amber)) end
   place(self.labels[i],self,offset,-2,math.max(.01,width));self.labels[i]:SetText(duration(value));self.labels[i]:SetShown(width>38 and value>0);offset=offset+width
  end
 end
 return f
end
local function tooltip(row)
 row:SetScript('OnEnter',function(f)
  local v=f.point;if not v then return end
  local a,b,split=parts(v);GameTooltip:SetOwner(f,'ANCHOR_TOP');GameTooltip:SetText(v.bossName or 'Recorded run')
  if v.tooltipSubtitle then GameTooltip:AddLine(v.tooltipSubtitle,1,1,1) end
  if split then GameTooltip:AddLine('Travel / pulls: '..duration(a),unpack(cyan));GameTooltip:AddLine('Boss fight: '..duration(b),unpack(amber))
  else GameTooltip:AddLine('Total: '..duration(a)..' · split unavailable',.7,.75,.77) end
  GameTooltip:Show()
 end)
 row:SetScript('OnLeave',function() GameTooltip:Hide() end)
end
local function build(p)
 local u=panel(p,0,0,1052,615);u:SetFrameLevel(p:GetFrameLevel()+20);u:EnableMouse(true);p.pacingRedesign=u;u.rows={};u.runRows={};u.page=1
 u.hero=panel(u,3,-3,1046,74)
 local t=u.hero:CreateTexture(nil,'BACKGROUND',nil,1);place(t,u.hero,5,-4,1036,66);t:SetAlpha(.6);u.heroArt=t
 u.title=label(u.hero,'Boss Pacing',18,-13,460,25,S.colors.white);u.dungeon=label(u.hero,'',570,-18,440,21,gold);u.dungeon:SetJustifyH('RIGHT')
 label(u.hero,'Travel, pulls and boss fights · current season',20,-47,900,11)
 -- No sidebar: the stats window's own tabs stay at the top for every view, including this one
 -- (user request 2026-10-04 "the menus are on the side instead of the top"). Content uses the
 -- full width the sidebar used to take.
 label(u,'Dungeon',10,-80,340,10,gold)
 p.dungeonButton:SetParent(u);place(p.dungeonButton,u,10,-95,370,27)
 p.bossButton:Hide()
 label(u,'Click a boss below to compare its runs.',402,-104,640,11)
 for _,menu in ipairs({p.dungeonMenu,p.bossMenu}) do if menu then menu:SetParent(u);menu:SetFrameLevel(u:GetFrameLevel()+80) end end
 u.sample=label(u,'',10,-128,1030,10);u.sample:SetJustifyH('CENTER')
 u.averages={}
 for i,title in ipairs({'Travel & pulls','Boss fights'}) do
  local c=panel(u,10+(i-1)*518,-146,506,53)
  label(c,title,50,-9,215,14,gold);label(c,'AVERAGE PER RECORDED SPLIT',50,-31,230,8)
  local icon=c:CreateTexture(nil,'ARTWORK');icon:SetTexture(media..'GoldIcons.png');icon:SetTexCoord(i==1 and 0 or .25,i==1 and .25 or .5,i==1 and .5 or .18,i==1 and .8 or .48);place(icon,c,11,-10,30,30)
  u.averages[i]=label(c,'',350,-12,140,26,i==1 and cyan or amber);u.averages[i]:SetJustifyH('RIGHT')
 end
 u.chart=panel(u,3,-207,1046,226)
 u.scroll=CreateFrame('ScrollFrame',nil,u.chart);place(u.scroll,u.chart,7,-7,1032,172)
 u.content=CreateFrame('Frame',nil,u.scroll);u.content:SetSize(1032,172);u.scroll:SetScrollChild(u.content)
 u.scroll:EnableMouseWheel(true);u.scroll:SetScript('OnMouseWheel',function(f,d) f:SetVerticalScroll(math.max(0,math.min(math.max(0,u.content:GetHeight()-172),f:GetVerticalScroll()-d*43))) end)
 u.ticks={};u.grid={}
 for i=0,5 do
  u.ticks[i+1]=label(u.chart,'',227+i*136,-184,64,9)
  local line=u.content:CreateTexture(nil,'BACKGROUND');line:SetColorTexture(.4,.48,.46,.16);place(line,u.content,220+i*136,0,1,172);u.grid[#u.grid+1]=line
 end
 label(u.chart,'Travel & pulls',306,-207,150,10,cyan);label(u.chart,'Boss fights',501,-207,110,10,amber)
 u.chartHint=label(u.chart,'',12,-207,278,9)
 u.empty=label(u.chart,'No completed runs with recorded boss timings yet.',32,-65,820,15)
 u.compare=panel(u,3,-441,1046,170)
 u.compareTitle=label(u.compare,'',14,-10,675,14,gold)
 u.previous=S.Button(u.compare,'<',26,22,function() u.page=math.max(1,u.page-1);A:RefreshBossPacingTabContent() end);place(u.previous,u.compare,942,-7,26,22)
 u.next=S.Button(u.compare,'>',26,22,function() u.page=math.min(u.pages or 1,u.page+1);A:RefreshBossPacingTabContent() end);place(u.next,u.compare,1005,-7,26,22)
 u.pageLabel=label(u.compare,'',971,-13,32,9);u.pageLabel:SetJustifyH('CENTER')
 for _,e in ipairs({{'#',13},{'Key',41},{'Total',101},{'Run timing',170},{'Travel / pulls',815},{'Boss fight',936}}) do label(u.compare,e[1],e[2],-35,112,10) end
 u.compareEmpty=label(u.compare,'Select a boss with recorded runs to compare.',18,-77,840,12)
 label(u.compare,'Oldest to newest · Gray means no travel/fight split was recorded.',14,-152,864,9)
 for i=1,5 do
  local row=CreateFrame('Button',nil,u.compare);place(row,u.compare,8,-51-(i-1)*19,1027,19);tooltip(row)
  row.index=label(row,'',4,-2,25,10);row.key=label(row,'',34,-2,53,10);row.total=label(row,'',93,-2,64,10)
  row.bar=bar(row,164,-1,621,15);row.pull=label(row,'',807,-2,115,10,cyan);row.fight=label(row,'',928,-2,96,10,amber);u.runRows[i]=row
 end
 return u
end
local old=A.RefreshBossPacingTabContent
function A:RefreshBossPacingTabContent(...)
 if self:IsUiLocked() then return end
 old(self,...)
 local p=self.pacingTabPanel;if not p then return end
 if p.horizontalPacing then p.horizontalPacing:Hide() end
 local u=p.pacingRedesign or build(p);u:Show()
 p.bossButton:Hide();if p.bossMenu then p.bossMenu:Hide() end
 local dungeon=self.pacingDungeonName;local data=self:GetBossPacingData(dungeon,15)
 local image=A:GetLedgerDungeonArtPath(dungeon);u.heroArt:SetTexture(image or media..'TempleBackdrop.png')
 if image then A:CropLedgerDungeonArt(u.heroArt,image,u.heroArt:GetWidth(),u.heroArt:GetHeight()) else u.heroArt:SetTexCoord(0,1,.25,.65) end
 u.dungeon:SetText(dungeon or 'Choose a dungeon')
 u.sample:SetText(string.format('Average across %d completed runs · most recent 15 this season · includes overtime',data.runCount or 0))
 local pull,fight,n=0,0,0;local maximum=0;local selected
 for _,v in ipairs(data.points) do
  local a,b,split=parts(v);maximum=math.max(maximum,a+b)
  if split then local count=v.splitSampleCount or v.sampleCount or 1;pull=pull+a*count;fight=fight+b*count;n=n+count end
  if v.position==self.pacingBossPosition then selected=v end
 end
 selected=selected or data.points[1]
 u.averages[1]:SetText(n>0 and duration(pull/n) or '—');u.averages[2]:SetText(n>0 and duration(fight/n) or '—')
 maximum=math.max(300,math.ceil(maximum/300)*300)
 for i,t in ipairs(u.ticks) do t:SetText(duration(maximum*(i-1)/5)) end
 u.empty:SetShown(#data.points==0);u.content:SetHeight(math.max(172,#data.points*43));u.scroll:SetVerticalScroll(math.min(u.scroll:GetVerticalScroll(),math.max(0,u.content:GetHeight()-172)))
 for _,line in ipairs(u.grid) do line:SetHeight(u.content:GetHeight()) end
 u.chartHint:SetText(#data.points>4 and 'Scroll for more bosses · click to compare' or 'Click a boss to compare individual runs')
 for i,v in ipairs(data.points) do
  local row=u.rows[i]
  if not row then
   row=CreateFrame('Button',nil,u.content);place(row,u.content,0,-(i-1)*43,1028,43);tooltip(row)
   row.highlight=row:CreateTexture(nil,'BACKGROUND');row.highlight:SetAllPoints();row.highlight:SetColorTexture(.5,.37,.1,.14)
   -- Guide boss images are 2:1 cut-outs; shown as-is, no ring/frame over them.
   row.icon=row:CreateTexture(nil,'ARTWORK');place(row.icon,row,4,-5,66,33)
   row.name=label(row,'',76,-7,138,11,S.colors.white);row.name:SetWordWrap(true);row.name:SetHeight(31)
   row.bar=bar(row,220,-12,682,21);row.total=label(row,'',918,-15,97,12)
   row:SetScript('OnClick',function(f) if f.point then A:RefreshBossPacingTabContent(A.pacingDungeonName,f.point.position) end end)
   u.rows[i]=row
  end
  row.point=v;row.name:SetText(v.bossName);portrait(row.icon,dungeon,v.bossName);row.bar:Update(v,maximum);local a,b=parts(v);row.total:SetText(duration(a+b));row.highlight:SetShown(selected==v);row:Show()
 end
 for i=#data.points+1,#u.rows do u.rows[i]:Hide() end
 local history=selected and self:GetBossPacingRunHistory(dungeon,selected.position,15) or {points={}}
 local key=tostring(dungeon)..':'..tostring(selected and selected.position)
 if u.selection~=key then u.selection=key;u.page=1 end
 u.pages=math.max(1,math.ceil(#history.points/5));u.page=math.min(u.page,u.pages);u.pageLabel:SetText(u.page..'/'..u.pages);u.previous:SetEnabled(u.page>1);u.next:SetEnabled(u.page<u.pages)
 u.compareTitle:SetText('Compare individual runs — '..(selected and selected.bossName or 'No boss selected'))
 u.compareEmpty:SetShown(#history.points==0)
 local runMax=1;for _,v in ipairs(history.points) do local a,b=parts(v);runMax=math.max(runMax,a+b) end
 for i,row in ipairs(u.runRows) do
  local index=(u.page-1)*5+i;local v=history.points[index];row:SetShown(v~=nil);row.point=v
  if v then
   local a,b,split=parts(v);row.index:SetText(index);row.key:SetText(v.keyLevel and ('+'..v.keyLevel) or '—');row.total:SetText(duration(a+b));row.bar:Update(v,runMax);row.pull:SetText(split and duration(a) or '—');row.fight:SetText(split and duration(b) or '—')
  end
 end
 if p.help then p.help:SetText('Select a boss to compare its runs below. Hover for dates and exact times. Averages use recorded splits only.') end
end
-- (The old sidebar hid the horizontal tabs while Boss Pacing was open; removed 2026-10-04 so the
-- top tabs show on every view.)
