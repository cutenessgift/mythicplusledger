-- Approved run browser, run history and player reputation layouts.
local addonName, ns = ...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local gold=S.colors.gold
local artFiles={['Den of Nalorakk']='DenOfNalorakk',['Altar of Fangs']='AltarOfFangs',["King's Rest"]='KingsRest',["Kings' Rest"]='KingsRest',['Ruby Life Pools']='RubyLifePools',['Voidscar Arena']='VoidscarArena',['The Blinding Vale']='TheBlindingVale',['Murder Row']='MurderRow',['Temple of Sethraliss']='TempleOfSethraliss'}
local function place(f,p,x,y,w,h)
 if not f then return end
 f:ClearAllPoints();f:SetPoint('TOPLEFT',p,'TOPLEFT',x,y)
 if w then f:SetWidth(w) end;if h then f:SetHeight(h) end
end
local function text(p,t,x,y,size,w,color)
 local f=S.Label(p,t,size or 12,color);place(f,p,x,y,w);return f
end
local function money(v)
 v=math.floor(tonumber(v) or 0)
 return GetCoinTextureString and GetCoinTextureString(v) or string.format('%dg %ds %dc',math.floor(v/10000),math.floor(v/100)%100,v%100)
end
local function surface(f)
 if f.SetBackdrop then f:SetBackdrop(nil) end;if not f.LedgerSkinTextures then S.Apply(f,'Card',7) end
end
local function paint(row,name,wide)
 if not row.browserArt then row.browserArt=row:CreateTexture(nil,'BACKGROUND',nil,2) end
 local t=row.browserArt;local file=artFiles[name]
 t:SetTexture(file and (media..'Dungeons\\'..file..'.jpg') or (media..'TempleBackdrop.png'))
 place(t,row,4,-4,row:GetWidth()-8,wide and row:GetHeight()-8 or 83)
 t:SetTexCoord(0,1,.18,.82);t:SetAlpha(wide and .14 or .6);t:Show()
end
local function bar(row)
 if row.browserBar then return row.browserBar end
 local f=CreateFrame('Frame',nil,row);place(f,row,12,-143,220,7)
 local bg=f:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.16,.19,.20,1)
 f.mask=f:CreateMaskTexture();f.mask:SetAllPoints();f.mask:SetTexture(media..'RoundedBarMask.png','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE');bg:AddMaskTexture(f.mask)
 f.fill=f:CreateTexture(nil,'ARTWORK');f.fill:SetPoint('LEFT');f.fill:SetHeight(7);f.fill:SetTexture(media..'BarGradient.png');f.fill:SetVertexColor(.26,.75,.57);f.fill:AddMaskTexture(f.mask)
 row.browserBar=f;return f
end
local function mainHeader(f)
 if f.browserHeader then return end
 for _,r in ipairs({f:GetRegions()}) do
  if r:IsObjectType('FontString') and (r:GetText()=='M+ Ledger' or r:GetText()=='Recent dungeon status, deaths, gold looted, and repair costs') then r:Hide() end
 end
 if f.emblemRing then f.emblemRing:Hide() end
 if f.emblem then f.emblem:Hide() end
 f.mplusLedgerIcon=f:CreateTexture(nil,'OVERLAY');place(f.mplusLedgerIcon,f,27,-19,42,42);S.ThemeAsset(f.mplusLedgerIcon,'runs')
 text(f,'M+ Ledger',82,-25,28,330,gold)
 local positions={['Record Repair']={34,145},['Status']={191,80},['Share']={283,80},['Manage Data']={375,155},['Stats & Progress']={542,145},['Add Player']={699,135}}
 for _,b in ipairs({f:GetChildren()}) do
  local value=b.text and b.text.GetText and b.text:GetText()
  if positions[value] then local v=positions[value];place(b,f,v[1],-76,v[2],28);if value=='Manage Data' then b:SetText('Manage Runs') end end
 end
 f.browserHistory=S.Button(f,'Player History',185,28,function() A:OpenPlayerHistoryWindow() end);place(f.browserHistory,f,846,-76,185,28)
 place(f.summaryPanel,f,34,-119,1012,92);surface(f.summaryPanel)
 f.browserStats={}
 for i,caption in ipairs({'Runs tracked','Completed (includes overtime)','Avg party deaths / run','Repairs'}) do
  local tile=CreateFrame('Frame',nil,f.summaryPanel);place(tile,f.summaryPanel,(i-1)*253,0,253,92)
  local art=tile:CreateTexture(nil,'BACKGROUND');art:SetAllPoints();art:SetTexture(media..'SeasonStat.png')
  tile.value=text(tile,'',4,-15,27,245,gold);tile.value:SetJustifyH('CENTER')
  tile.label=text(tile,caption,4,-55,11,245);tile.label:SetJustifyH('CENTER');f.browserStats[i]=tile
 end
 -- Keep the existing difficulty breakdown available in a compact, optional panel.
 f.browserDifficulty=CreateFrame('Frame',nil,f);surface(f.browserDifficulty);place(f.browserDifficulty,f,34,-252,1012,116);f.browserDifficulty:SetFrameLevel(f:GetFrameLevel()+25);f.browserDifficulty:Hide()
 local n=0
 for _,key in ipairs({'timewalking','normal','heroic','mythic','mythicPlus','follower'}) do
  local card=f.difficultyCards[key]
  if card then card:SetParent(f.browserDifficulty);place(card,f.browserDifficulty,10+n*166,-10,162,96);n=n+1 end
 end
 f.browserDifficultyToggle=S.Button(f,'Difficulty details',140,24,function() f.browserDifficulty:SetShown(not f.browserDifficulty:IsShown()) end);place(f.browserDifficultyToggle,f,466,-226,140,24)
 place(f.viewButton,f,620,-226,195,24);place(f.sortButton,f,827,-226,190,24)
 place(f.listTitle,f,34,-228,420,24)
 place(f.progressButton,f,792,-226,125,24);place(f.backButton,f,929,-226,88,24)
 place(f.scrollUpButton,f,1022,-226,24,24)
 f.browserScope=text(f,'Summary: all tracked history. Filters below apply to dungeon cards.',34,-865,10,925)
 f.browserHeader=true
end
local function cardIcons(row)
 if row.ledgerIcons then return end
 row.ledgerIcons={}
 for i,uv in ipairs({{.5,.75,.18,.48},{.75,1,.18,.48},{.25,.5,.50,.80}}) do
  local t=row:CreateTexture(nil,'ARTWORK');t:SetTexture(media..'GoldIcons.png');t:SetTexCoord(unpack(uv));place(t,row,12,-157-(i-1)*18,15,15);row.ledgerIcons[i]=t
 end
end
local function dungeonCard(row)
 local d=row.cardSummary;surface(row);paint(row,d.name,false);cardIcons(row)
 for _,t in ipairs(row.ledgerIcons) do t:Show() end
 row.icon:Hide();row.statusRibbon:Hide()
 place(row.name,row,12,-91,220,23);row.name:SetFont(STANDARD_TEXT_FONT,15,'');row.name:SetText(d.name);S.ThemeText(row.name);row.name:SetWordWrap(false)
 place(row.status,row,12,-119,220,18);row.status:SetFont(STANDARD_TEXT_FONT,11,'')
 local total=tonumber(d.runs) or 0;local done=tonumber(d.completed) or 0
 row.status:SetText(string.format('%d runs   ·   Completed %.0f%%',total,total>0 and done*100/total or 0))
 local f=bar(row);f:Show();f.fill:SetWidth(math.max(.01,220*math.min(1,total>0 and done/total or 0)));f.fill:SetShown(done>0)
 place(row.playerDeaths,row,33,-159,199,15);row.playerDeaths:SetText('Your deaths: '..(d.playerDeaths or 0))
 place(row.partyDeaths,row,33,-177,199,15);row.partyDeaths:SetText('Party deaths: '..(d.partyDeaths or 0))
 place(row.repairs,row,33,-195,199,16);row.repairs:SetText('Repairs: '..money(d.repairCost));row.repairs:SetFont(STANDARD_TEXT_FONT,11,'')
 if not row.browserKey then row.browserKey=text(row,'',177,-13,17,55,gold);row.browserKey:SetJustifyH('RIGHT') end
 local key=tonumber(d.currentSeasonHighestKey) or 0;row.browserKey:SetText(key>0 and '+'..key or '');row.browserKey:Show()
 if not row.browserView then row.browserView=text(row,'View runs  >',128,-217,11,105,gold);row.browserView:SetJustifyH('RIGHT') end
 row.browserView:Show()
 if d.active then row.browserKey:SetText('Active') end
end
local function runCard(row,self)
 local run=self:GetRun(row.runID);if not run then return end
 surface(row);paint(row,run.instanceName,true)
 place(row.icon,row,14,-16,50,50)
 place(row.name,row,78,-16,550,20);row.name:SetFont(STANDARD_TEXT_FONT,15,'');S.ThemeText(row.name)
 place(row.status,row,78,-44,315,88);row.status:SetFont(STANDARD_TEXT_FONT,11,'')
 local positions={tank=424,heals=612,dps=800}
 for key,x in pairs(positions) do
  place(row.roleHeaders[key],row,x,-48,176,16);row.roleHeaders[key]:SetTextColor(unpack(gold))
  place(row.roleColumns[key],row,x,-71,176,63);row.roleColumns[key]:SetFont(STANDARD_TEXT_FONT,11,'')
 end
 place(row.statusRibbon,row,78,-133,math.max(105,row.statusRibbon:GetWidth()),19)
 place(row.guideButton,row,684,-132,85,22);place(row.editButton,row,780,-132,85,22);place(row.shareButton,row,876,-132,85,22)
 place(row.runCode,row,787,-18,190,18)
 row.skull:ClearAllPoints();row.skull:SetPoint('TOPRIGHT',-15,-44)
end
local oldRefresh=A.RefreshWindow
function A:RefreshWindow(...)
 oldRefresh(self,...)
 if self:IsUiLocked() or not self.window then return end
 local f=self.window;mainHeader(f)
 f.summaryTitle:Hide();f.summaryStatus:Hide()
 for _,k in ipairs({'playerDeathBox','partyDeathBox','repairBox','runBox'}) do f[k]:Hide() end
 local d=self.selectedDungeonName and self:GetDungeonSummary(self.selectedDungeonName) or self:GetOverallSummary()
 local count=d.runs or 0
 local values={count,string.format('%.0f%%',count>0 and (d.completed or 0)*100/count or 0),string.format('%.1f',count>0 and (d.partyDeaths or 0)/count or 0),money(d.repairCost)}
 for i,t in ipairs(f.browserStats) do t.value:SetText(values[i]);if i==4 then t.value:SetFont(STANDARD_TEXT_FONT,17,'') end end
 f.browserStats[2].value:SetTextColor(.37,.83,.60)
 f.browserScope:SetText(self.selectedDungeonName and 'Summary: tracked history for this dungeon. Select a run to share or edit it.' or 'Summary: all tracked history. Filters above apply to dungeon cards.')
 local visible=0
 for _,row in ipairs(f.rows) do
  for _,t in ipairs(row.ledgerIcons or {}) do t:Hide() end
  for _,key in ipairs({'browserArt','browserBar','browserKey','browserView'}) do if row[key] then row[key]:Hide() end end
  if row:IsShown() then
   visible=visible+1
   if row.runID then runCard(row,self)
   elseif row.cardSummary then dungeonCard(row)
   else row:SetBackdropColor(.035,.055,.06,1);S.ThemeText(row.name) end
  end
 end
 -- Count the actually rendered items; expansion headings consume grid space too.
 local offset=f.listOffset or 0;local total=f.currentListTotal or 0
 f.scrollUpButton:SetShown(offset>0);f.scrollDownButton:SetShown(offset+visible<total)
 f.scrollUpButton:SetAlpha(1);f.scrollDownButton:SetAlpha(1)
end
-- One-item scrolling guarantees grouped headings cannot skip or strand entries.
local oldOffset=A.SetListOffset
function A:SetListOffset(offset,total)
 if self.selectedDungeonName then return oldOffset(self,offset,total) end
 if self.window then self.window.listOffset=math.max(0,math.min(math.max(0,(total or 0)-1),math.floor(tonumber(offset) or 0))) end
end
function A:ScrollList(delta)
 if not self.window then return end
 self:SetListOffset((self.window.listOffset or 0)+(tonumber(delta) or 0),self.window.currentListTotal or 0)
 self.scrollFadeActive=true;self:RefreshWindow()
end
local oldHistory=A.RefreshPlayerHistoryWindow
function A:RefreshPlayerHistoryWindow(...)
 oldHistory(self,...)
 local f=self.playerHistoryWindow;if not f then return end
 if not f.browserHistoryHeader then
  for _,r in ipairs({f:GetRegions()}) do if r:IsObjectType('FontString') and r:GetText()=='Player Reputation History' then r:Hide() end end
  f.browserHistoryHeader=text(f,'Player Reputation',34,-20,25,600,gold)
  f.browserAdd=S.Button(f,'Add Player',130,26,function() A:OpenAddPlayerForm() end);place(f.browserAdd,f,818,-20,130,26)
 end
 for _,row in ipairs(f.ledgerHistoryRows or {}) do
  if row.ledgerSelected then row:SetBackdropColor(.16,.14,.075,1)
  elseif row.ledgerIndex%2==0 then row:SetBackdropColor(.047,.074,.082,1)
  else row:SetBackdropColor(.028,.047,.055,1) end
 end
 for _,cell in ipairs(f.ledgerNameCells or {}) do
  cell:SetBackdropColor(cell.ledgerSelected and .16 or .035,cell.ledgerSelected and .14 or .055,cell.ledgerSelected and .075 or .063,1)
  cell:SetBackdropBorderColor(A:GetThemeBorderColor(false,cell.ledgerSelected and .9 or .20))
 end
end
