-- Approved mockup layout implementation. Keeps original form fields and save callbacks.
local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local gold=S.colors.gold
local function place(f,p,x,y,w,h)
 if not f then return end
 f:ClearAllPoints();f:SetPoint('TOPLEFT',p,'TOPLEFT',x,y)
 if w then f:SetWidth(w) end;if h then f:SetHeight(h) end
 if f.text and type(f.text)~='string' then f.text:SetWidth(math.max(10,f:GetWidth()-16)) end
end
local function label(p,t,x,y,size,w)
 local f=S.Label(p,t,size or 12);f:SetPoint('TOPLEFT',x,y)
 if w then f:SetWidth(w);f:SetWordWrap(true) end
 return f
end
local function box(p,x,y,w,h)
 local f=CreateFrame('Frame',nil,p);f:SetFrameLevel(math.max(0,p:GetFrameLevel()-1));place(f,p,x,y,w,h);S.Apply(f,'Card',8)
 return f
end
local icons={sun={0,.25,.18,.48},swords={.25,.5,.18,.48},skull={.5,.75,.18,.48},party={.75,1,.18,.48},hourglass={0,.25,.50,.80},coins={.25,.5,.50,.80},wrench={.5,.75,.50,.80},shield={.75,1,.50,.80}}
local function icon(p,key,x,y,size)
 local t=p:CreateTexture(nil,'ARTWORK'); t:SetTexture(media..'GoldIcons.png'); t:SetTexCoord(unpack(icons[key] or icons.sun));t:SetSize(size,size);t:SetPoint('TOPLEFT',x,y);return t
end
-- Role icon for party rows -- shield/swords share GoldIcons.png's sheet (already used by icon()
-- above); Healer has no slot on that sheet, so it's its own dedicated file (MenuIcons\Healer.png,
-- same one MenuIcons.lua's own role-icon code uses for run rosters elsewhere).
local function roleIcon(p,role,x,y,size)
 local t=p:CreateTexture(nil,'ARTWORK');t:SetSize(size,size);t:SetPoint('TOPLEFT',x,y)
 if role=='TANK' then t:SetTexture(media..'GoldIcons.png');t:SetTexCoord(unpack(icons.shield))
 elseif role=='HEALER' then t:SetTexture(media..'MenuIcons\\Healer.png');t:SetTexCoord(0,1,0,1)
 else t:SetTexture(media..'GoldIcons.png');t:SetTexCoord(unpack(icons.swords)) end
 return t
end
-- Blizzard's own class-color table (global, not addon-specific media) -- per user request
-- 2026-10-02 ("needs more styling, like the mockup"), matching the mockup's class-colored party
-- names.
local function classColor(token)
 local c=RAID_CLASS_COLORS and token and RAID_CLASS_COLORS[token]
 if c then return c.r,c.g,c.b end
 return 0.93,0.92,0.88
end
local function art(p,x,y,w,h)
 local t=p:CreateTexture(nil,'BACKGROUND',nil,1);t:SetTexture(media..'TempleBackdrop.png');t:SetPoint('TOPLEFT',x,y);t:SetSize(w,h)
 -- Original painting is 3:1, exported at power-of-two dimensions. Crop rather than stretch.
 local ratio=w/h
 if ratio<3 then local span=ratio/3;t:SetTexCoord(1-span,1,0,1) else local span=3/ratio;t:SetTexCoord(0,1,(1-span)/2,(1+span)/2) end
 return t
end
-- Dungeon art (bundled pack or Blizzard's guide images) is cropped by A:CropLedgerDungeonArt in
-- AllRunsReference.lua -- not art()'s math, which is for this file's 3:1 TempleBackdrop placeholder.
local white=S.colors.white
-- Core.lua's legacy portrait: a 50x50 coloured square (OVERLAY 1, anchored TOPLEFT 9,-7) with a
-- masked 44x44 icon centred on it (OVERLAY 2). The old exact GetWidth()==50 test missed them on
-- Record Repair (the "pink square" + coin icon behind the new header, user report 2026-10-04), so
-- this matches on layer + roughly-square size, or the portrait's own anchoring, instead.
local function isLegacyPortrait(f,r)
 if not r:IsObjectType('Texture') or r:GetDrawLayer()~='OVERLAY' then return false end
 local w,h=r:GetSize()
 if w and h and math.abs(w-h)<1 and w>=40 and w<=56 then return true end
 local point,rel,_,x,y=r:GetPoint(1)
 if point=='TOPLEFT' and rel==f and (x or 99)<=12 and (y or -99)>=-10 then return true end
 return point=='CENTER' and rel~=nil and rel~=f and rel.IsObjectType~=nil and rel:IsObjectType('Texture')
end
-- Adventure Guide details for one journal instance: description, lore art and the boss list with
-- each boss's guide portrait (the same cut-out images the in-game guide lists). Cached per ID; every
-- EJ call is pcall'd so a missing/changed API just means "no details", never an error.
local journalCache={}
function A:GetLedgerJournalDetails(journalID)
 journalID=tonumber(journalID)
 if not journalID or journalID<=0 or not EJ_GetInstanceInfo then return nil end
 if journalCache[journalID] then return journalCache[journalID] end
 if self.LoadEncounterJournalForIconDump then pcall(self.LoadEncounterJournalForIconDump,self) end
 -- Failures aren't cached: the journal data may simply not be loaded yet on the first call.
 local ok,name,description,_,_,lore=pcall(EJ_GetInstanceInfo,journalID)
 if not ok or not name then return nil end
 local details={name=name,description=description,lore=lore,bosses={}}
 if EJ_GetEncounterInfoByIndex then
  for i=1,15 do
   local okBoss,bossName,_,encounterID=pcall(EJ_GetEncounterInfoByIndex,i,journalID)
   if not okBoss or not bossName then break end
   local portrait
   if EJ_GetCreatureInfo and encounterID then
    local okCreature,_,_,_,_,iconImage=pcall(EJ_GetCreatureInfo,1,encounterID)
    if okCreature then portrait=iconImage end
   end
   details.bosses[#details.bosses+1]={name=bossName,icon=portrait}
  end
 end
 journalCache[journalID]=details
 return details
end
local function header(f,title,size,iconSize)
 if f.legacyPortrait then f.legacyPortrait:Hide() end
 if f.legacyPortraitRing then f.legacyPortraitRing:Hide() end
 if not f.mockupHeader then
  for _,r in ipairs({f:GetRegions()}) do
   if isLegacyPortrait(f,r) then r:Hide();r:SetAlpha(0) end
   if r:IsObjectType('FontString') and (r:GetText()==title or r:GetText()=='Manage Runs' or r:GetText()=='Record Repair') then r:Hide() end
  end
  iconSize=iconSize or 48
  -- White in every theme (user request 2026-10-04), not the theme accent.
  f.mockupHeader=label(f,title,iconSize+32,-15-(iconSize-(size or 26))/2,size or 26,600);f.mockupHeader:SetTextColor(unpack(white))
  f.mockupHeaderIcon=icon(f,'sun',22,-15,iconSize)
  S.ThemeAsset(f.mockupHeaderIcon,title=='Manage Runs' and 'manage-runs' or 'repair-silver')
 end
end
local function findButton(f,value)
 for _,b in ipairs(f.dynamicFrames or {f:GetChildren()}) do
  if b.text and type(b.text)~='string' and b.text.GetText and b.text:GetText()==value then return b end
 end
end
local function hideLabels(f)
 for _,r in ipairs(f.dynamicFrames or {}) do if r:IsObjectType('FontString') then r:Hide() end end
end
local stepperButton
local function dataLayout(f,self)
 local mode=f.mode or self.dataToolMode
 if f.noRun then f.noRun:Hide() end
 if f.runLayout then f.runLayout:Hide() end;if f.createLayout then f.createLayout:Hide() end
 if f.runPreview then f.runPreview:Hide() end
 if mode~='run' and mode~='create' then return end
 -- Create is compact; Edit retains room for the full party editor.
 local creating=mode=='create'
 f:SetSize(creating and 900 or 1040,creating and 620 or 784);header(f,'Manage Runs')
 f.content:ClearAllPoints();f.content:SetPoint('TOPLEFT',24,-118);f.content:SetPoint('BOTTOMRIGHT',-24,creating and 24 or 78)
 f.content:SetBackdrop(nil)
 if f.content.LedgerSkinTextures then for _,t in ipairs(f.content.LedgerSkinTextures) do t:SetAlpha(0) end end
 if f.footer then f.footer:SetShown(not creating) end
 for _,e in ipairs({{f.navButtons.create,24},{f.navButtons.run,208}}) do
  local b,x=e[1],e[2]
  if b then
   place(b,f,x,-70,172,36)
   if b.mockupSubtitle then b.mockupSubtitle:Hide() end
   if b.text and type(b.text)~='string' then
    b.text:ClearAllPoints();b.text:SetPoint('LEFT',32,0);b.text:SetPoint('RIGHT',-12,0);b.text:SetJustifyH('CENTER')
   end
   if not b.modeFill then b.modeFill=b:CreateTexture(nil,'BACKGROUND',nil,7);b.modeFill:SetPoint('TOPLEFT',5,-5);b.modeFill:SetPoint('BOTTOMRIGHT',-5,5) end
   local selected=b.mode==mode
   b.modeFill:SetColorTexture(selected and .22 or .07,selected and .20 or .07,selected and .24 or .09,1)
  end
 end
 -- The "Player Reputation History" button this used to reposition was removed from Manage Runs
 -- entirely (Core.lua, CreateDataToolsWindow) per user request 2026-10-02.
 if f.saveAllButton then f.saveAllButton:Hide() end
 hideLabels(f)
 if mode=='create' then
  if not f.createLayout then
   local p=CreateFrame('Frame',nil,f.content);p:SetAllPoints();p:SetFrameLevel(f.content:GetFrameLevel()+1);f.createLayout=p
   -- Quiet, distinct surfaces without a third enclosing border.
   for _,e in ipairs({{0,0,442,478},{458,0,394,478}}) do
    local bg=p:CreateTexture(nil,'BACKGROUND');bg:SetPoint('TOPLEFT',e[1],e[2]);bg:SetSize(e[3],e[4]);bg:SetColorTexture(.035,.04,.05,1)
   end
   p.art=p:CreateTexture(nil,'ARTWORK');p.art:SetPoint('TOPLEFT',470,-12);p.art:SetSize(370,180);p.art:Hide()
   p.artFallback=art(p,470,-12,370,180)
   label(p,'Create a manual run',20,-18,22,405):SetTextColor(unpack(white))
   label(p,'Choose an expansion and dungeon to begin.',20,-52,12,405)
   label(p,'Expansion',20,-94,12)
   label(p,'Instance name',20,-170,12)
   label(p,'Difficulty',20,-246,12)
   p.keyLabel=label(p,'Key level',306,-246,12)
   p.artName=label(p,'',478,-204,17,354);p.artName:SetTextColor(unpack(white));p.artName:SetHeight(44)
   p.artExpansion=label(p,'',478,-252,11,354);p.artExpansion:SetTextColor(.66,.70,.72)
   p.artDescription=label(p,'',478,-276,11,354);p.artDescription:SetHeight(140);p.artDescription:SetJustifyV('TOP')
   label(p,'Add timing and party details after creating the run.',20,-394,11,400)
   label(p,'Manual entries remain separate from Blizzard score and vault data.',478,-436,11,354)
  end
  f.createLayout:Show()
  local p=f.createLayout
  local selectedName=self.dataToolSelectedInstanceName
  local entry=selectedName and selectedName~='' and self:GetLedgerDungeonCatalogue()[selectedName]
  local guide=entry and self:GetLedgerJournalDetails(entry.journalInstanceID)
  local image=entry and ((self.GetLedgerDungeonArtPath and self:GetLedgerDungeonArtPath(selectedName)) or entry.image or (guide and guide.lore))
  if image then
   p.art:SetTexture(image);A:CropLedgerDungeonArt(p.art,image,370,180);p.art:Show();p.artFallback:Hide()
  else p.art:Hide();p.artFallback:Show() end
  p.artName:SetText(selectedName and selectedName~='' and selectedName or 'Select an instance')
  p.artExpansion:SetText((entry and entry.expansion) or '')
  p.artDescription:SetText((guide and guide.description and guide.description~='' and guide.description) or (entry and entry.description) or 'Pick a dungeon to see its Adventure Guide details here.')
  local mythicPlus=self.dataToolSelectedDifficulty=='mythicPlus'
  p.keyLabel:SetShown(mythicPlus)
  place(f.expansionNameBox,f.content,20,-116,402,34)
  place(f.instanceNameBox,f.content,20,-192,402,34)
  place(f.difficultyButton,f.content,20,-268,mythicPlus and 266 or 402,34)
  place(f.keyLevelBox,f.content,306,-268,116,34);f.keyLevelBox:SetShown(mythicPlus)
  if f.journalInstanceIDBox then f.journalInstanceIDBox:Hide() end
  for _,field in ipairs({f.expansionNameBox,f.instanceNameBox,f.keyLevelBox}) do
   if not field.manualFill then field.manualFill=field:CreateTexture(nil,'BACKGROUND',nil,7);field.manualFill:SetPoint('TOPLEFT',2,-2);field.manualFill:SetPoint('BOTTOMRIGHT',-2,2) end
   field.manualFill:SetColorTexture(.11,.12,.14,1)
  end
  place(findButton(f,'Cancel'),f.content,20,-338,130,36)
  place(f.createRunButton,f.content,166,-338,256,36)
  return
 end
 local run=self:GetDataToolSelectedRun()
 if not run then
  if not f.noRun then f.noRun=label(f.content,'Choose a run using the filters above.',24,-146,18,850) end
  f.noRun:Show();return
 end
 if f.noRun then f.noRun:Hide() end
 if not f.runLayout then
  local p=CreateFrame('Frame',nil,f.content);p:SetAllPoints();p:SetFrameLevel(f.content:GetFrameLevel()+1);f.runLayout=p
  box(p,0,-110,548,355);box(p,560,-110,432,355)
  icon(p,'wrench',15,-123,26);label(p,'Run Details',50,-125,20):SetTextColor(unpack(white))
  icon(p,'party',575,-123,26);label(p,'Party',610,-125,20):SetTextColor(unpack(white))
  for _,e in ipairs({{'Instance',20,-171},{'Difficulty',20,-212},{'Key level',346,-212},{'Expansion',20,-253},{'Guide ID (optional)',20,-294},{'Duration',20,-335},{'Run status',20,-379}}) do label(p,e[1],e[2],e[3],12) end
  label(p,'min',233,-335);label(p,'sec',354,-335)
  label(p,'Player',578,-169,12);label(p,'Role',803,-169,12);label(p,'Deaths',917,-169,12)
  p.partyRows={}
  for i=1,5 do
   p.partyRows[i]={
    name=label(p,'',578,-197-(i-1)*39,13,215),
    roleIcon=p:CreateTexture(nil,'ARTWORK'),
    deaths=label(p,'',930,-197-(i-1)*39,13,45),
   }
   local t=p.partyRows[i].roleIcon;t:SetSize(18,18);t:SetPoint('TOPLEFT',803,-197-(i-1)*39+1)
   -- - / + either side of the death count (user request 2026-10-08); saves straight away.
   local row=p.partyRows[i];row.deaths:SetJustifyH('CENTER')
   local function adjust(delta) local r=self:GetDataToolSelectedRun();local m=r and r.members and r.members[i];if m then self:AdjustMemberDeathCount(r,m,delta) end end
   row.minus=stepperButton(p,'-',function() adjust(-1) end);row.minus:SetSize(16,16);row.minus:SetPoint('TOPLEFT',920,-197-(i-1)*39)
   row.plus=stepperButton(p,'+',function() adjust(1) end);row.plus:SetSize(16,16);row.plus:SetPoint('TOPLEFT',970,-197-(i-1)*39)
  end
  p.more=label(p,'',578,-402,11,390)
  label(p,'Add player to this run',16,-481,15):SetTextColor(unpack(white))
  label(p,'Name',211,-505,10);label(p,'Realm',357,-505,10)
  -- Labels above the season/expansion/dungeon filters and the run selector -- per user report
  -- 2026-10-02 ("needs to be more user friendly and needs more styling, like the mockup"); these
  -- three controls previously had no labels at all, reading as an unexplained row of boxes.
  -- Parented to the run layout (was f.content) -- per user report 2026-10-04: on f.content they
  -- stayed visible after switching to Create Run, overlapping that form's own labels.
  for _,e in ipairs({{'Current season',16},{'Expansion',312},{'Dungeon',584}}) do label(p,e[1],e[2],-2,10) end
  label(p,'Selected run',16,-49,10);label(p,'Run details',642,-49,10)
 end
 f.runLayout:Show()
 for i,r in ipairs(f.runLayout.partyRows) do
  local m=run.members and run.members[i]
  r.name:SetText(m and (m.name or 'Unknown') or '')
  local cr,cg,cb=classColor(m and m.class)
  r.name:SetTextColor(cr,cg,cb)
  if m and m.role and m.role~='NONE' then
   if m.role=='TANK' then r.roleIcon:SetTexture(media..'GoldIcons.png');r.roleIcon:SetTexCoord(unpack(icons.shield))
   elseif m.role=='HEALER' then r.roleIcon:SetTexture(media..'MenuIcons\\Healer.png');r.roleIcon:SetTexCoord(0,1,0,1)
   else r.roleIcon:SetTexture(media..'GoldIcons.png');r.roleIcon:SetTexCoord(unpack(icons.swords)) end
   r.roleIcon:Show()
  else
   r.roleIcon:Hide()
  end
  local count=m and self:GetMemberDeathCount(run,m) or 0
  r.deaths:SetText(m and tostring(count) or '')
  r.plus:SetShown(m~=nil);r.minus:SetShown(m~=nil);r.minus:SetEnabled(count>0);r.minus:SetAlpha(count>0 and 1 or .35)
 end
 f.runLayout.more:SetText(#(run.members or {})>5 and ('Showing 5 of '..#run.members..' players. Open Run editor to manage the full roster.') or 'Use - / + to correct deaths. Open Run editor to change other party details.')
 place(f.runSeasonOnlyCheck,f.content,16,-20,285,28);place(f.runExpansionFilterButton,f.content,312,-20,260,28);place(f.runInstanceFilterButton,f.content,584,-20,392,28)
 -- Shrunk from the full-width 960 so a "Selected run" preview card (art thumbnail + name + key/
 -- status/duration) fits beside it -- per user report 2026-10-02 ("the image and dungeon details
 -- is missing"); the dropdown alone, even with its "Midnight | Murder Row | Left | H-..." text,
 -- read as plain and gave no visual confirmation of which run was actually selected.
 place(f.runButton,f.content,16,-67,610,30)
 if not f.runPreview then
  local prev=box(f.content,642,-61,350,40);f.runPreview=prev
  prev.art=prev:CreateTexture(nil,'ARTWORK');prev.art:SetPoint('TOPLEFT',5,-5);prev.art:SetSize(30,30)
  prev.name=label(prev,'',44,-6,13,296);prev.detail=label(prev,'',44,-22,10,296)
 end
 local prev=f.runPreview;prev:Show()
 local entry=run.instanceName and self:GetLedgerDungeonCatalogue()[run.instanceName]
 local prevImage=self:GetLedgerDungeonArtPath(run.instanceName) or (entry and entry.image)
 if prevImage then prev.art:SetTexture(prevImage);A:CropLedgerDungeonArt(prev.art,prevImage,30,30);prev.art:Show() else prev.art:Hide() end
 prev.name:SetText(run.instanceName or 'Unknown instance')
 local bucket=self.dataToolSelectedDifficulty or self:GetDifficultyBucket(run)
 local keyLevel=self:GetRunKeyLevel(run)
 prev.detail:SetText(string.format('%s%s  ·  %s',(bucket=='mythicPlus' and keyLevel>0) and ('+'..keyLevel..'  ') or '',self:GetRunStatus(run) or '',self:GetRunOptionText(run) or ''))
 place(f.instanceNameBox,f.content,150,-164,373,30);place(f.difficultyButton,f.content,150,-205,170,30);place(f.keyLevelBox,f.content,423,-205,100,30)
 place(f.expansionNameBox,f.content,150,-246,373,30);place(f.journalInstanceIDBox,f.content,150,-287,170,30)
 place(f.runTimeMinutesBox,f.content,150,-328,75,30);place(f.runTimeSecondsBox,f.content,271,-328,75,30)
 -- Status buttons color-coded to match what they mean -- per user report 2026-10-02 ("need to be
 -- coloured to what they mean"). ApplyButtonColor's SetBackdropColor() call (still made in
 -- Core.lua) stopped having any visible effect once MenuPolish.lua strips every button's raw
 -- backdrop in favor of the skinned nine-slice texture -- tinting LedgerSkinTextures[5] (the
 -- center fill) directly is what actually survives that, same technique AllRunsReference.lua uses
 -- for its own selected-filter highlight. "Completed" relabeled "Timed" (Core.lua) but the
 -- underlying status key is unchanged, so the color lookup still keys on "Completed" here.
 for i,e in ipairs({{'Timed','Completed'},{'Overtime','CompletedOvertime'},{'Abandoned','Abandoned'},{'Active','Active'}}) do
  local b=findButton(f,e[1])
  place(b,f.content,20+(i-1)*129,-405,120,30)
  local c=b and self:GetStatusBackdropColor(e[2])
  if c and b.LedgerSkinTextures and b.LedgerSkinTextures[5] then
   b.LedgerSkinTextures[5]:SetColorTexture(c[1],c[2],c[3],1)
  end
 end
 for _,e in ipairs({{'Save Run',24,180},{'Run Editor',222,150},{'Delete Run',842,170}}) do local b=findButton(f,e[1]);place(b,f,e[2],-695,e[3],34) end
 place(f.addPlayerKnownButton,f.content,16,-525,180,28);place(f.addPlayerNameBox,f.content,211,-525,132,28);place(f.addPlayerRealmBox,f.content,357,-525,132,28)
 place(f.addPlayerClassButton,f.content,503,-525,170,28);place(f.addPlayerRoleButton,f.content,687,-525,120,28);place(findButton(f,'Add Player'),f.content,821,-525,155,28)
 if f.footer then f.footer:Hide() end
end
local oldData=A.RefreshDataToolsWindow
function A:RefreshDataToolsWindow(...)
 oldData(self,...);if self.dataTools then dataLayout(self.dataTools,self) end
end
-- Small stepper pair (+/-) for the Gold/Silver/Copper boxes -- per user request 2026-10-02 ("it
-- should look like this as well", matching a mockup with +/- spinners on each money field). No
-- numeric-spinner template reliably exists across every client version this addon supports, so
-- this is just two tiny plain buttons, consistent with the "^"/"v" scroll arrows already used
-- elsewhere in Core.lua rather than risking an uncertain Blizzard template name.
-- Plain, unskinned (not S.Button -- its nine-slice edge art is sized for much bigger buttons and
-- would look distorted stretched down to 16x13): a 1px theme-accent outline with no dark fill,
-- matching the input fields (user request 2026-10-04).
function stepperButton(parent,glyph,onClick)
 local b=CreateFrame('Button',nil,parent)
 b:SetSize(16,13)
 local edges={}
 for i=1,4 do edges[i]=b:CreateTexture(nil,'BORDER');S.ThemeAccentTexture(edges[i]);edges[i]:SetAlpha(.55) end
 edges[1]:SetPoint('TOPLEFT');edges[1]:SetPoint('TOPRIGHT');edges[1]:SetHeight(1)
 edges[2]:SetPoint('BOTTOMLEFT');edges[2]:SetPoint('BOTTOMRIGHT');edges[2]:SetHeight(1)
 edges[3]:SetPoint('TOPLEFT');edges[3]:SetPoint('BOTTOMLEFT');edges[3]:SetWidth(1)
 edges[4]:SetPoint('TOPRIGHT');edges[4]:SetPoint('BOTTOMRIGHT');edges[4]:SetWidth(1)
 local glyphText=b:CreateFontString(nil,'OVERLAY');glyphText:SetFont(STANDARD_TEXT_FONT,10,'');glyphText:SetPoint('CENTER',0,1);glyphText:SetText(glyph);glyphText:SetTextColor(1,1,1)
 local hover=b:CreateTexture(nil,'HIGHLIGHT');hover:SetAllPoints();hover:SetColorTexture(1,1,1,.12)
 b:SetScript('OnClick',onClick)
 return b
end
local function stepper(box,x,y)
 local up=stepperButton(box:GetParent(),'+',function() box:SetText(tostring((tonumber(box:GetText() or '') or 0)+1)) end)
 local down=stepperButton(box:GetParent(),'-',function() box:SetText(tostring(math.max(0,(tonumber(box:GetText() or '') or 0)-1))) end)
 place(up,box,x,y);place(down,box,x,y-14)
end
-- Themed on/off toggle replacing Blizzard's old UICheckButton (the green "X") -- per user request
-- 2026-10-04 ("the Current Season Only button is old and should be changed"). A normal skinned
-- button with a small outlined box that shows the theme's own check icon when on.
local function seasonToggle(parent,width,isOn,onToggle)
 local b=S.Button(parent,'Current season only',width,28,function() onToggle();parent.ledgerSeasonToggle:Update() end)
 b.Label:ClearAllPoints();b.Label:SetPoint('LEFT',32,0);b.Label:SetPoint('RIGHT',-8,0);b.Label:SetJustifyH('LEFT');b.Label:SetFont(STANDARD_TEXT_FONT,12,'')
 local box=CreateFrame('Frame',nil,b);box:SetSize(14,14);box:SetPoint('LEFT',11,0)
 local edges={}
 for i=1,4 do edges[i]=box:CreateTexture(nil,'BORDER');S.ThemeAccentTexture(edges[i]) end
 edges[1]:SetPoint('TOPLEFT');edges[1]:SetPoint('TOPRIGHT');edges[1]:SetHeight(1)
 edges[2]:SetPoint('BOTTOMLEFT');edges[2]:SetPoint('BOTTOMRIGHT');edges[2]:SetHeight(1)
 edges[3]:SetPoint('TOPLEFT');edges[3]:SetPoint('BOTTOMLEFT');edges[3]:SetWidth(1)
 edges[4]:SetPoint('TOPRIGHT');edges[4]:SetPoint('BOTTOMRIGHT');edges[4]:SetWidth(1)
 local check=box:CreateTexture(nil,'OVERLAY');check:SetPoint('CENTER');check:SetSize(18,18);S.ThemeAsset(check,'status-completed')
 function b:Update() check:SetShown(isOn()) end
 b:Update()
 return b
end
-- Compact Record Repair -- per user request 2026-10-04 ("this is a massive menu for what it is, it
-- can be way smaller, i am thinking a third of the size"): 560x364 (was 960x760), Dungeon and the
-- season toggle share one line, white headings, no dark boxes behind the sections or inputs.
local oldRepair=A.CreateRepairWindow
function A:CreateRepairWindow(...)
 oldRepair(self,...);local f=self.repairWindow;if not f or f.mockupRepair then return end;f.mockupRepair=true
 f:SetSize(560,364);header(f,'Record Repair',20,30)
 for _,r in ipairs({f:GetRegions()}) do if r:IsObjectType('FontString') and r~=f.mockupHeader and r~=f.validation then r:Hide() end end
 local p=CreateFrame('Frame',nil,f);p:SetAllPoints();p:SetFrameLevel(f:GetFrameLevel()+1)
 local function heading(text,x,y) local l=label(p,text,x,y,12);l:SetTextColor(unpack(white));return l end
 heading('Dungeon',22,-56)
 heading('Selected run',22,-110)
 heading('Or find by run code',22,-180)
 heading('Repair cost',22,-236)
 local muted={.66,.70,.72}
 for _,e in ipairs({{'Gold',22},{'Silver',196},{'Copper',370}}) do label(p,e[1],e[2]+60,-238,10):SetTextColor(unpack(muted)) end

 -- Old checkbox stays hidden but keeps its getter/setter role in Core.lua; the new toggle drives
 -- the same repairRunFilterSeasonOnly flag.
 f.seasonOnlyCheck:Hide()
 f.ledgerSeasonToggle=seasonToggle(f,174,function() return A.repairRunFilterSeasonOnly==true end,function()
  A.repairRunFilterSeasonOnly=not (A.repairRunFilterSeasonOnly==true);A:RefreshRepairWindow()
 end)
 place(f.ledgerSeasonToggle,f,364,-72,174,28)
 -- "Dungeon" is just f.instanceButton -- the Expansion filter still exists and still narrows the
 -- Dungeon list, it's just not a second visible control.
 f.expansionButton:Hide()
 place(f.instanceButton,f,22,-72,330,28)
 -- MenuIcons.lua already gave this button its own generic filter-funnel icon (it's in that
 -- file's filterFields list) before this code runs -- replaced with the dynamic per-dungeon icon
 -- below instead of stacking both at the same spot.
 if f.instanceButton.menuAssetIcon then f.instanceButton.menuAssetIcon:Hide() end
 local dungeonIcon=f.instanceButton:CreateTexture(nil,'ARTWORK');dungeonIcon:SetSize(20,20);dungeonIcon:SetPoint('LEFT',8,0);dungeonIcon:Hide()
 f.instanceButton.text:ClearAllPoints();f.instanceButton.text:SetPoint('LEFT',8,0);f.instanceButton.text:SetPoint('RIGHT',-8,0);f.instanceButton.text:SetJustifyH('LEFT');f.instanceButton.text:SetTextColor(1,1,1)
 local function dungeonImage(name)
  local path=A.GetLedgerDungeonArtPath and A:GetLedgerDungeonArtPath(name)
  if path then return path end
  local entry=name and A:GetLedgerDungeonCatalogue()[name]
  return entry and entry.image
 end
 local oldInstanceSetText=f.instanceButton.SetText
 function f.instanceButton:SetText(value)
  oldInstanceSetText(self,value)
  local image=dungeonImage(value)
  if image then
   dungeonIcon:SetTexture(image);A:CropLedgerDungeonArt(dungeonIcon,image,20,20);dungeonIcon:Show()
   self.text:ClearAllPoints();self.text:SetPoint('LEFT',34,0);self.text:SetPoint('RIGHT',-8,0)
  else
   dungeonIcon:Hide()
   self.text:ClearAllPoints();self.text:SetPoint('LEFT',8,0);self.text:SetPoint('RIGHT',-8,0)
  end
 end
 f.instanceButton:SetText(f.instanceButton.text:GetText())

 -- "Selected run" preview card: f.runButton is still the real clickable control (opens the same
 -- run-picker menu), restyled with a thumbnail + name + key/status/date. Hooking SetText catches
 -- every path that changes the selected run (run-code search and the picker both call it).
 place(f.runButton,f,22,-126,516,44)
 f.runButton.text:Hide()
 local runArt=f.runButton:CreateTexture(nil,'ARTWORK');runArt:SetPoint('LEFT',8,0);runArt:SetSize(30,30);runArt:Hide()
 local runName=f.runButton:CreateFontString(nil,'OVERLAY');runName:SetFont(STANDARD_TEXT_FONT,13,'');runName:SetTextColor(1,1,1);runName:SetPoint('TOPLEFT',48,-7);runName:SetPoint('RIGHT',-12,0);runName:SetJustifyH('LEFT')
 local runDetail=f.runButton:CreateFontString(nil,'OVERLAY');runDetail:SetFont(STANDARD_TEXT_FONT,10,'');runDetail:SetTextColor(.72,.76,.78);runDetail:SetPoint('TOPLEFT',48,-25);runDetail:SetPoint('RIGHT',-12,0);runDetail:SetJustifyH('LEFT')
 local oldRunSetText=f.runButton.SetText
 function f.runButton:SetText(value)
  oldRunSetText(self,value)
  local run=A.repairWindowSelectedRun
  if not run then
   runArt:Hide();runName:SetText(value or 'Select Run');runDetail:SetText('Click to choose a run')
   return
  end
  local image=dungeonImage(run.instanceName)
  if image then runArt:SetTexture(image);A:CropLedgerDungeonArt(runArt,image,30,30);runArt:Show() else runArt:Hide() end
  runName:SetText(run.instanceName or 'Unknown instance')
  local bucket=A:GetDifficultyBucket(run);local keyLevel=A:GetRunKeyLevel(run)
  local dateText=run.startedAt and date('%b %d, %Y',run.startedAt) or ''
  runDetail:SetText(string.format('%s%s  ·  %s',(bucket=='mythicPlus' and keyLevel>0) and ('+'..keyLevel..'  ') or '',A:GetRunStatus(run) or '',dateText))
 end
 f.runButton:SetText(f.runButton.text:GetText())

 place(f.searchBox,f,22,-196,390,28)
 if not f.searchBox.mockupHint then
  -- x=29: clears the magnifier icon MenuIcons.lua puts at the left of this box (the old hint at
  -- x=8 sat underneath it).
  local hint=label(f.searchBox,'e.g. ABc123, xY7p9',29,-9,10);hint:SetTextColor(.5,.53,.55)
  f.searchBox:HookScript('OnTextChanged',function(self) hint:SetShown(self:GetText()=='') end)
  f.searchBox:HookScript('OnEditFocusGained',function() hint:Hide() end)
  f.searchBox:HookScript('OnEditFocusLost',function(self) hint:SetShown(self:GetText()=='') end)
  f.searchBox.mockupHint=hint
 end
 place(findButton(f,'Search'),f,424,-196,114,28)

 -- Per column: number box, +/- stepper, coin icon.
 for _,e in ipairs({{f.goldBox,22,'UI-GoldIcon'},{f.silverBox,196,'UI-SilverIcon'},{f.copperBox,370,'UI-CopperIcon'}}) do
  local moneyBox,x,iconFile=e[1],e[2],e[3]
  place(moneyBox,f,x,-252,110,28)
  if not moneyBox.mockupIcon then
   stepper(moneyBox,114,0)
   local t=f:CreateTexture(nil,'ARTWORK');t:SetSize(18,18);t:SetTexture('Interface\\MoneyFrame\\'..iconFile)
   t:SetPoint('LEFT',moneyBox,'RIGHT',24,0)
   moneyBox.mockupIcon=t
  end
 end
 place(f.validation,f,22,-290,516,18);f.validation:SetFont(STANDARD_TEXT_FONT,10,'')
 local save=findButton(f,'Add repair cost');place(save,f,378,-318,160,30)
 local cancel=findButton(f,'Cancel') or S.Button(f,'Cancel',110,30,function() f:Hide() end)
 place(cancel,f,22,-318,110,30)
end
local oldRefreshRepair=A.RefreshRepairWindow
function A:RefreshRepairWindow(...)
 if oldRefreshRepair then oldRefreshRepair(self,...) end
 local f=self.repairWindow
 if f and f.ledgerSeasonToggle then f.seasonOnlyCheck:Hide();f.ledgerSeasonToggle:Update() end
end
-- Share the approved icon language with existing live statistics.
local oldProgress=A.BuildProgressTabContent
function A:BuildProgressTabContent(p)
 oldProgress(self,p)
 for key,name in pairs({runs='swords',completion='shield',avgDeaths='skull',bestRun='hourglass',deathTimeLost='hourglass'}) do local f=p.kpis[key];if f then icon(f,name,10,-17,28) end end
end
local oldTrends=A.BuildTrendsTabContent
function A:BuildTrendsTabContent(p)
 oldTrends(self,p)
 for key,name in pairs({runs='swords',totalDeaths='skull',avgDeaths='party',deathFree='shield'}) do local f=p.kpis[key];if f then icon(f,name,10,-17,28) end end
end
-- Horizontal pacing comparison: all segments use the same seconds scale.
local function duration(n)
 n=math.max(0,math.floor((tonumber(n) or 0)+.5));return string.format('%d:%02d',math.floor(n/60),n%60)
end
local previousPacing=A.RefreshBossPacingTabContent
function A:RefreshBossPacingTabContent(...)
 previousPacing(self,...)
 local p=self.pacingTabPanel;if not p then return end
 local oldChart=p.chartFrame or (p.scrollFrame and p.scrollFrame:GetParent());if oldChart then oldChart:Hide() end
 if not p.horizontalPacing then
  local h=box(p,0,-176,1052,438);h:SetFrameLevel(p:GetFrameLevel()+1);p.horizontalPacing=h;h.rows={}
  label(h,'Boss / run',16,-90,12,235):SetTextColor(unpack(gold))
  label(h,'Travel and pulls',280,-90,12):SetTextColor(.47,.84,.93)
  label(h,'Boss fight',430,-90,12):SetTextColor(1,.73,.35)
  label(h,'Total',967,-90,12):SetTextColor(unpack(gold))
  h.averages={}
  for i,title in ipairs({'Average travel / pulls','Average boss fight'}) do
   local c=box(h,16+(i-1)*510,-10,500,66);icon(c,i==1 and 'swords' or 'hourglass',12,-14,32)
   label(c,title,55,-10,12,410);h.averages[i]=label(c,'',55,-30,22,410)
  end
  h.ticks={}
  for i=0,4 do h.ticks[i+1]=label(h,'',274+i*167.5,-386,10,65) end
  h.empty=label(h,'No pacing data yet. Complete a dungeon to see recorded timings.',24,-95,16,990)
  h.scroll=CreateFrame('ScrollFrame',nil,h);place(h.scroll,h,10,-116,1032,264)
  h.content=CreateFrame('Frame',nil,h.scroll);h.content:SetSize(1032,264);h.scroll:SetScrollChild(h.content)
  h.scroll:EnableMouseWheel(true);h.scroll:SetScript('OnMouseWheel',function(f,d) f:SetVerticalScroll(math.max(0,math.min(math.max(0,h.content:GetHeight()-264),f:GetVerticalScroll()-d*50))) end)
  label(h,'Shared time scale. Gray indicates a total without a recorded travel/fight split.',18,-413,11,1000)
 end
 local h=p.horizontalPacing
 local data={points={}}
 if self.pacingDungeonName then
  if self.pacingBossPosition then data=self:GetBossPacingRunHistory(self.pacingDungeonName,self.pacingBossPosition,15)
  else data=self:GetBossPacingData(self.pacingDungeonName,15) end
 end
 local maximum=1
 for _,v in ipairs(data.points) do local total=(v.avgPull~=nil and v.avgFight~=nil) and (v.avgPull+v.avgFight) or (v.avgLumped or 0);maximum=math.max(maximum,total) end
 local pull,fight,n=0,0,0
 for _,v in ipairs(data.points) do if v.avgPull~=nil and v.avgFight~=nil then pull=pull+v.avgPull;fight=fight+v.avgFight;n=n+1 end end
 h.averages[1]:SetText(n>0 and duration(pull/n) or 'No split data');h.averages[2]:SetText(n>0 and duration(fight/n) or 'No split data')
 for i,t in ipairs(h.ticks) do t:SetText(duration(maximum*(i-1)/4)) end
 h.empty:SetShown(#data.points==0);h.content:SetHeight(math.max(264,#data.points*64))
 h.scroll:SetVerticalScroll(math.min(h.scroll:GetVerticalScroll(),math.max(0,h.content:GetHeight()-264)))
 for i,v in ipairs(data.points) do
  local row=h.rows[i]
  if not row then
   row=CreateFrame('Button',nil,h.content);place(row,h.content,0,-(i-1)*64,1032,62)
   row.name=label(row,'',8,-10,13,235);row.detail=label(row,'',8,-32,10,235)
   row.track=CreateFrame('Frame',nil,row);place(row.track,row,264,-15,670,28)
   row.mask=row.track:CreateMaskTexture();row.mask:SetAllPoints();row.mask:SetTexture(media..'RoundedBarMask.png','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
   row.parts={}
   for j=1,2 do local t=row.track:CreateTexture(nil,'ARTWORK');t:SetHeight(28);t:SetTexture(media..'BarGradient.png');t:AddMaskTexture(row.mask);row.parts[j]=t end
   row.times={label(row.track,'',4,-7,12,100),label(row.track,'',4,-7,12,100)}
   for _,t in ipairs(row.times) do t:SetTextColor(.07,.12,.14);t:SetJustifyH('CENTER') end
   row.total=label(row,'',953,-20,14,75)
   row:SetScript('OnEnter',function(f)
    local q=f.point;GameTooltip:SetOwner(f,'ANCHOR_TOP');GameTooltip:SetText(q.bossName or q.columnLabel or 'Boss timing')
    if q.avgPull~=nil and q.avgFight~=nil then GameTooltip:AddLine('Travel / pulls: '..duration(q.avgPull),.47,.84,.93);GameTooltip:AddLine('Boss fight: '..duration(q.avgFight),1,.73,.35)
    else GameTooltip:AddLine('Recorded total: '..duration(q.avgLumped)..' (split unavailable)',.8,.8,.8) end
    if q.tooltipSubtitle then GameTooltip:AddLine(q.tooltipSubtitle,1,1,1,true) end
    GameTooltip:Show()
   end)
   row:SetScript('OnLeave',function() GameTooltip:Hide() end)
   row:SetScript('OnClick',function(f) if not A.pacingBossPosition and f.point then A:RefreshBossPacingTabContent(A.pacingDungeonName,f.point.position) end end)
   h.rows[i]=row
  end
  row.point=v;row.name:SetText(v.columnLabel or v.bossName or ('Boss '..i))
  row.detail:SetText(self.pacingBossPosition and (v.bossName or '') or ((v.sampleCount or 0)..' recorded kills · click for runs'))
  local split=v.avgPull~=nil and v.avgFight~=nil
  local first=split and v.avgPull or (v.avgLumped or 0);local second=split and v.avgFight or 0
  local a,b=row.parts[1],row.parts[2];local w=670*first/maximum
  a:ClearAllPoints();a:SetPoint('LEFT',row.track,'LEFT',0,0);a:SetWidth(math.max(.01,w));a:SetShown(first>0)
  if split then a:SetVertexColor(.35,.75,.85) else a:SetVertexColor(.42,.47,.50) end
  b:ClearAllPoints();b:SetPoint('LEFT',row.track,'LEFT',w,0);b:SetWidth(math.max(.01,670*second/maximum));b:SetVertexColor(.94,.66,.27);b:SetShown(second>0)
  for j,value in ipairs({first,second}) do local t=row.times[j];local width=670*value/maximum;t:ClearAllPoints();t:SetPoint('LEFT',row.track,'LEFT',j==1 and 0 or w,0);t:SetWidth(math.max(1,width));t:SetText(duration(value));t:SetShown(width>45) end
  row.total:SetText(duration(first+second));row:Show()
 end
 for i=#data.points+1,#h.rows do h.rows[i]:Hide() end
 if p.help then p.help:SetText('Select a boss for individual runs. Hover for split times. Scroll to see more recorded runs.') end
end
