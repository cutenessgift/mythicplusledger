-- Final M+ Ledger art/layout pass, after the shared menu and browser modules.
local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local gold=S.colors.gold
local artwork={['Den of Nalorakk']='DenOfNalorakk',['Altar of Fangs']='AltarOfFangs',["Kings' Rest"]='KingsRest',["King's Rest"]='KingsRest',['Ruby Life Pools']='RubyLifePools',['Voidscar Arena']='VoidscarArena',['The Blinding Vale']='TheBlindingVale',['Murder Row']='MurderRow',['Temple of Sethraliss']='TempleOfSethraliss'}
-- Shared dungeon-art pack; landscape textures keep their 2:1 proportions.
artwork["Magisters' Terrace"]="MagistersTerrace"
artwork["Maisara Caverns"]="MaisaraCaverns"
artwork["Nexus-Point Xenas"]="NexusPointXenas"
artwork["Windrunner Spire"]="WindrunnerSpire"
artwork["Algeth'ar Academy"]="AlgetharAcademy"
artwork["Pit of Saron"]="PitOfSaron"
artwork["Seat of the Triumvirate"]="SeatOfTriumvirate"
artwork["Skyreach"]="Skyreach"
artwork["The Underrot"]="TheUnderrot"
artwork["Iron Docks"]="IronDocks"
artwork["Sanguine Depths"]="SanguineDepths"
artwork["The Stonecore"]="TheStonecore"
artwork["Uldaman: Legacy of Tyr"]="UldamanLegacyOfTyr"
artwork["Ara-Kara, City of Echoes"]="AraKara"
artwork["City of Threads"]="CityOfThreads"
artwork["The Stonevault"]="TheStonevault"
artwork["The Dawnbreaker"]="TheDawnbreaker"
artwork["Mists of Tirna Scithe"]="MistsOfTirnaScithe"
artwork["The Necrotic Wake"]="TheNecroticWake"
artwork["Siege of Boralus"]="SiegeOfBoralus"
artwork["Grim Batol"]="GrimBatol"
artwork["Operation: Floodgate"]="OperationFloodgate"
artwork["Priory of the Sacred Flame"]="PrioryOfSacredFlame"
artwork["Eco-Dome Al'dani"]="EcoDomeAldani"
artwork["Halls of Atonement"]="HallsOfAtonement"
artwork["Tazavesh: Streets of Wonder"]="TazaveshStreets"
artwork["Tazavesh: So'leah's Gambit"]="TazaveshGambit"

local function place(f,p,x,y,w,h)
 f:ClearAllPoints();f:SetPoint('TOPLEFT',p,'TOPLEFT',x,y);if w then f:SetWidth(w) end;if h then f:SetHeight(h) end
end
local function text(p,value,x,y,w,size)
 local t=S.Label(p,value,size or 12);place(t,p,x,y,w);t:SetWordWrap(false);return t
end
local function dark(f)
 if f.SetBackdrop then f:SetBackdrop(nil) end
 if not f.LedgerSkinTextures then S.Apply(f,'Window',10) end
 S.Apply(f,'Window',10)
 S.ThemeBackground(f.LedgerSkinTextures[5],1)
end
local function picture(t,name)
 local image=A:GetLedgerDungeonArtPath(name)
 t:SetTexture(image or media..'TempleBackdrop.png')
 if image then A:CropLedgerDungeonArt(t,image,t:GetWidth(),t:GetHeight())
 else t:SetTexCoord(0,1,.20,.80) end
end
local function rule(p,x,y,h)
 local t=p:CreateTexture(nil,'ARTWORK');t:SetColorTexture(.70,.54,.24,.5);place(t,p,x,y,1,h);return t
end
local function money(value)
 return GetCoinTextureString and GetCoinTextureString(math.floor(tonumber(value) or 0)) or tostring(value or 0)
end
local function init(f)
 if f.instanceArt and f.instanceArt.ready then return f.instanceArt end
 -- A failed refresh may leave a partial table. Only reuse a fully built header.
 if f.instanceArt and f.instanceArt.hero then f.instanceArt.hero:Hide() end
 local ui={};f.instanceArt=ui
 dark(f)
 -- Core owns the circular-masked emblem. Atlas cropping it here is invalid in WoW.
 -- A framed hero only for the selected dungeon, above its summary and run rows.
 ui.hero=CreateFrame('Frame',nil,f);place(ui.hero,f,34,-110,1012,124);dark(ui.hero)
 ui.heroArt=ui.hero:CreateTexture(nil,'BACKGROUND',nil,1);place(ui.heroArt,ui.hero,5,-5,1002,114);ui.heroArt:SetAlpha(.7)
 ui.heroShade=ui.hero:CreateTexture(nil,'BACKGROUND',nil,2);ui.heroShade:SetAllPoints(ui.heroArt);ui.heroShade:SetColorTexture(.005,.017,.023,.30)
 ui.title=text(ui.hero,'',22,-31,755,29);S.ThemeText(ui.title)
 ui.caption=text(ui.hero,'Your recorded runs, party history, and repair costs',24,-79,720,12)
 ui.breadcrumb=text(ui.hero,'ALL RUNS  /  DUNGEON HISTORY',24,-12,700,10);ui.breadcrumb:SetTextColor(.75,.75,.66)
 -- Four values share one quiet panel, with fine dividers instead of four ornate tiles.
 for i,tile in ipairs(f.browserStats) do
  for _,r in ipairs({tile:GetRegions()}) do if r:IsObjectType('Texture') and r~=tile.menuMetricIcon then r:Hide() end end
  if i>1 then rule(tile,0,-12,60) end
 end
 ui.hero:Hide()
 ui.ready=true
 return ui
end
local function card(row,self)
 local d=row.cardSummary;dark(row)
 row.browserArt:SetAlpha(.60);place(row.browserArt,row,5,-5,234,89);picture(row.browserArt,d.name)
 if not row.artNameShade then
  row.artNameShade=row:CreateTexture(nil,'BACKGROUND',nil,2);row.artNameShade:SetColorTexture(.005,.016,.018,.91);place(row.artNameShade,row,5,-76,234,29)
  row.artRuns=text(row,'',12,-113,220,11);row.artRunsValue=text(row,'',190,-113,42,11);row.artRunsValue:SetJustifyH('RIGHT')
  row.artComplete=text(row,'Completed',12,-134,78,11);row.artPercent=text(row,'',197,-134,35,11);row.artPercent:SetJustifyH('RIGHT')
  row.artAction=S.Button(row,'View runs',112,22,function() local click=row:GetScript('OnMouseUp');if click then click(row,'LeftButton') end end);place(row.artAction,row,66,-208,112,22)
  row.artKeyPlate=CreateFrame('Frame',nil,row);place(row.artKeyPlate,row,191,-7,44,32);dark(row.artKeyPlate)
  row.artKey=text(row.artKeyPlate,'',3,-6,38,15);row.artKey:SetJustifyH('CENTER');S.ThemeText(row.artKey)
 end
 row.artNameShade:Show();row.artRuns:Show();row.artRunsValue:Show();row.artComplete:Show();row.artPercent:Show();row.artAction:Show();row.artKeyPlate:Show()
 place(row.name,row,12,-83,220,18);row.name:SetFont(STANDARD_TEXT_FONT,14,'')
 row.status:Hide();row.browserKey:Hide();row.browserView:Hide()
 row.artRuns:SetText('Runs');row.artRunsValue:SetText(tostring(d.runs or 0))
 local fraction=(d.runs or 0)>0 and (d.completed or 0)/d.runs or 0
 row.artPercent:SetText(string.format('%.0f%%',fraction*100))
 place(row.browserBar,row,89,-136,104,7);row.browserBar.fill:SetWidth(math.max(.01,104*math.min(1,fraction)))
 for i,t in ipairs(row.ledgerIcons or {}) do place(t,row,12,-152-(i-1)*17,13,13) end
 for i,field in ipairs({'playerDeaths','partyDeaths','repairs'}) do place(row[field],row,31,-152-(i-1)*17,201,15);row[field]:SetFont(STANDARD_TEXT_FONT,11,'') end
 row.artKey:SetText(d.active and '*' or ((tonumber(d.currentSeasonHighestKey) or 0)>0 and '+'..d.currentSeasonHighestKey or '—'))
end
local function memberSlots(row)
 if row.artMembers then return end
 row.artMembers={}
 for i,x in ipairs({361,486,611,693,775}) do
  local p=CreateFrame('Frame',nil,row);place(p,row,x,-47,i<3 and 119 or 78,60)
  local border=CreateFrame('Frame',nil,p);place(border,p,0,0,27,27);dark(border)
  local icon=border:CreateTexture(nil,'ARTWORK');place(icon,border,3,-3,21,21)
  local name=text(p,'',0,-30,i<3 and 117 or 77,10)
  local deaths=text(p,'',0,-46,i<3 and 117 or 77,10);deaths:SetTextColor(.68,.72,.72)
  row.artMembers[i]={frame=p,icon=icon,name=name,deaths=deaths}
 end
 row.artMore=text(row,'',361,-122,487,9);row.artMore:SetTextColor(.68,.72,.72)
 row.artRules={}
 for _,x in ipairs({347,477,602,863}) do row.artRules[#row.artRules+1]=rule(row,x,-12,115) end
end
local function history(row,self)
 local run=self:GetRun(row.runID);if not run then return end
 dark(row);row.browserArt:Hide();row.icon:Hide();row.status:Hide();row.statusRibbon:Hide();row.skull:Hide()
 if not row.artRunImage then
  row.artRunFrame=CreateFrame('Frame',nil,row);place(row.artRunFrame,row,10,-11,128,120);dark(row.artRunFrame)
  row.artRunImage=row.artRunFrame:CreateTexture(nil,'ARTWORK');place(row.artRunImage,row.artRunFrame,4,-4,120,112)
  row.artKeyLevel=text(row,'',152,-40,74,30);S.ThemeText(row.artKeyLevel)
  row.artOutcome=text(row,'',230,-51,111,11)
  row.artDuration=text(row,'',152,-88,186,12)
  row.artExtra=text(row,'',152,-111,186,9);row.artExtra:SetTextColor(.68,.72,.72)
 end
 row.artRunFrame:Show();row.artKeyLevel:Show();row.artOutcome:Show();row.artDuration:Show();row.artExtra:Show()
 picture(row.artRunImage,run.instanceName)
 place(row.name,row,152,-18,188,17);row.name:SetFont(STANDARD_TEXT_FONT,11,'');row.name:SetText(run.startedAtText or 'Recorded run');row.name:SetTextColor(.77,.79,.76)
 local key=self:GetRunKeyLevel(run) or 0;row.artKeyLevel:SetText(key>0 and '+'..key or 'Run')
 local status=self:GetRunStatus(run)
 local states={Completed={'Completed',.25,.83,.62},CompletedOvertime={'Overtime',.95,.72,.3},Abandoned={'Abandoned',.9,.36,.4},Active={'Active',.4,.7,1}}
 local state=states[status] or {self:GetRunDisplayStatus(run),.8,.8,.8};row.artOutcome:SetText(state[1]);row.artOutcome:SetTextColor(state[2],state[3],state[4])
 local seconds=math.max(0,math.floor(self:GetBrowserRunDuration(run)));row.artDuration:SetText(string.format('Duration: %d:%02d',math.floor(seconds/60),seconds%60))
 row.artExtra:SetText('Repairs: '..money(run.repairCost))
 memberSlots(row)
 for _,t in ipairs(row.artRules) do t:Show() end
 row.artMore:Show()
 local positions={tank=374,heals=499,dps=624}
 for role,x in pairs(positions) do place(row.roleHeaders[role],row,x,-18,100,16);row.roleHeaders[role]:SetFont(STANDARD_TEXT_FONT,11,'');row.roleColumns[role]:Hide() end
 local tanks,heals,dps={},{},{}
 for _,m in ipairs(run.members or {}) do local group=m.role=='TANK' and tanks or (m.role=='HEALER' and heals or dps);group[#group+1]=m end
 local members={tanks[1] or false,heals[1] or false,dps[1] or false,dps[2] or false,dps[3] or false}
 for i,slot in ipairs(row.artMembers) do
  local m=members[i];slot.frame:Show()
  if m then
   local uv=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[m.class or '']
   if uv then slot.icon:SetTexture('Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes');slot.icon:SetTexCoord(unpack(uv))
   else slot.icon:SetTexture(media..'GoldIcons.png');slot.icon:SetTexCoord(.75,1,.18,.48) end
   slot.name:SetText(m.name or 'Unknown');local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class or ''];slot.name:SetTextColor(color and color.r or .9,color and color.g or .9,color and color.b or .86)
   local deaths=self:GetMemberDeathCount(run,m) or 0;slot.deaths:SetText(tostring(deaths)..(deaths==1 and ' death' or ' deaths'))
  else slot.icon:SetTexture(nil);slot.name:SetText('—');slot.deaths:SetText('') end
 end
 local extra=math.max(0,#tanks-1)+math.max(0,#heals-1)+math.max(0,#dps-3)
 row.artMore:SetText(extra>0 and ('+'..extra..' more players · Edit for the full roster') or '')
 for i,key in ipairs({'guideButton','editButton','shareButton'}) do place(row[key],row,880,-13-(i-1)*31,119,26) end
 place(row.runCode,row,874,-114,128,15);row.runCode:SetFont(STANDARD_TEXT_FONT,9,'');row.runCode:SetJustifyH('CENTER')
end
local old=A.RefreshWindow
function A:RefreshWindow(...)
 old(self,...);if self:IsUiLocked() or not self.window then return end
 local f=self.window;local ui=init(f);dark(f.summaryPanel)
 local detail=self.selectedDungeonName~=nil
 ui.hero:SetShown(detail)
 place(f.summaryPanel,f,34,detail and -246 or -119,1012,82)
 for i,tile in ipairs(f.browserStats) do tile:SetHeight(82);place(tile.label,tile,4,-54,245,16) end
 f.browserDifficultyToggle:SetShown(not detail)
 if detail then
  picture(ui.heroArt,self.selectedDungeonName);ui.title:SetText(self.selectedDungeonName)
  place(f.backButton,ui.hero,850,-14,140,25);place(f.progressButton,ui.hero,850,-78,140,28)
  f.listTitle:Hide();f.browserDifficulty:Hide()
  local d=self:GetDungeonSummary(self.selectedDungeonName)
  f.browserStats[3].value:SetText(tostring(d.playerDeaths or 0));f.browserStats[3].label:SetText('Your deaths')
  f.browserStats[4].value:SetText(tostring(d.partyDeaths or 0));f.browserStats[4].value:SetFont(STANDARD_TEXT_FONT,27,'');f.browserStats[4].label:SetText('Party deaths')
  if f.browserStats[4].menuMetricIcon then f.browserStats[4].menuMetricIcon:SetTexture(media..'GoldIcons.png');f.browserStats[4].menuMetricIcon:SetTexCoord(.75,1,.18,.48) end
 else
  f.browserStats[3].label:SetText('Avg party deaths / run');f.browserStats[4].label:SetText('Repairs')
  if f.browserStats[4].menuMetricIcon then f.browserStats[4].menuMetricIcon:SetTexture(media..'GoldIcons.png');f.browserStats[4].menuMetricIcon:SetTexCoord(.25,.5,.50,.80) end
 end
 for _,row in ipairs(f.rows) do
  for _,key in ipairs({'artNameShade','artRuns','artRunsValue','artComplete','artPercent','artAction','artKeyPlate','artRunFrame','artKeyLevel','artOutcome','artDuration','artExtra','artMore'}) do if row[key] then row[key]:Hide() end end
  for _,slot in ipairs(row.artMembers or {}) do slot.frame:Hide() end
  for _,t in ipairs(row.artRules or {}) do t:Hide() end
  if row:IsShown() then
   if row.runID then history(row,self) elseif row.cardSummary then card(row,self) end
  end
 end
end
