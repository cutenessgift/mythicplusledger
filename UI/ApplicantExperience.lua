-- Compact applicant reputation panel -- per user request 2026-10-04: same information as the
-- approved applicant_rep.png mockup, but in roughly the footprint of the original panel
-- (applicant_rep_org.png): small icon buttons instead of large text buttons, one card per
-- application, white header, Blizzard close button, coloured M+ score, and the extra details
-- Blizzard's own applicant tooltip shows (level + spec, best key in this dungeon, best run).
local _,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
local E={};ns.ApplicantElements=E
local white={1,1,1};local muted={.64,.69,.72};local danger={1,.22,.24}
local badges={Good={'Trusted',{.38,.87,.43},'status-trusted'},Bad={'Avoid',danger,'status-avoid'},Okay={'Neutral',{.82,.77,.56},'status-neutral'}}
local noHistory={'No history',muted,'status-nohistory'}
local roleNames={TANK='Tank',HEALER='Healer',DAMAGER='Damage'}
local roleAtlas={TANK='roleicon-tiny-tank',HEALER='roleicon-tiny-healer',DAMAGER='roleicon-tiny-dps'}
local regionNames={US='American',OCE='Oceanic',EU='European'}
local WIDTH=500
local MEMBER_HEIGHT=50
local function label(p,value,x,y,w,size,color)
 local t=S.Label(p,value,size or 11,color or white);t:SetPoint('TOPLEFT',x,y);if w then t:SetWidth(w) end;t:SetJustifyH('LEFT');t:SetWordWrap(false);return t
end
function E.Outline(p,width)
 local edges={}
 for i=1,4 do edges[i]=p:CreateTexture(nil,'OVERLAY');edges[i]:SetColorTexture(1,1,1,1) end
 edges[1]:SetPoint('TOPLEFT');edges[1]:SetPoint('TOPRIGHT');edges[1]:SetHeight(width)
 edges[2]:SetPoint('BOTTOMLEFT');edges[2]:SetPoint('BOTTOMRIGHT');edges[2]:SetHeight(width)
 edges[3]:SetPoint('TOPLEFT');edges[3]:SetPoint('BOTTOMLEFT');edges[3]:SetWidth(width)
 edges[4]:SetPoint('TOPRIGHT');edges[4]:SetPoint('BOTTOMRIGHT');edges[4]:SetWidth(width)
 return edges
end
local function colorEdges(edges,color,alpha,width)
 for i,t in ipairs(edges) do
  t:SetVertexColor(color[1],color[2],color[3],alpha or 1)
  if width then if i<=2 then t:SetHeight(width) else t:SetWidth(width) end end
 end
end
-- Small status pill: optional themed icon + text. 18px tall (was 25px boxes).
function E.Badge(p)
 local b=CreateFrame('Frame',nil,p);b:SetSize(84,18)
 b.bg=b:CreateTexture(nil,'BACKGROUND');b.bg:SetAllPoints();b.edges=E.Outline(b,1)
 b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(13,13);b.icon:SetPoint('LEFT',4,0)
 b.text=S.Label(b,'',10);b.text:SetJustifyH('CENTER')
 function b:Update(value,color,asset)
  self.text:SetText(value);self.text:SetTextColor(unpack(color))
  self.bg:SetColorTexture(color[1]*.14,color[2]*.14,color[3]*.14,.9);colorEdges(self.edges,color,.8)
  self.text:ClearAllPoints()
  if asset then
   S.ThemeAsset(self.icon,asset);self.icon:Show();self.text:SetPoint('LEFT',20,0)
   self:SetWidth(self.text:GetStringWidth()+28)
  else
   self.icon:Hide();self.text:SetPoint('CENTER')
   self:SetWidth(self.text:GetStringWidth()+16)
  end
 end
 return b
end
-- Icon-only action button with tooltip (the original panel's ✓ / ✗ / > style).
function E.Action(p,texture,tip,click)
 local b=CreateFrame('Button',nil,p);b:SetSize(24,22)
 b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(18,18);b.icon:SetPoint('CENTER');b.icon:SetTexture(texture)
 local glow=b:CreateTexture(nil,'HIGHLIGHT');glow:SetAllPoints();glow:SetColorTexture(1,1,1,.14)
 b.tip=tip
 b:SetScript('OnEnter',function(f) GameTooltip:SetOwner(f,'ANCHOR_TOP');GameTooltip:SetText(f.tip);GameTooltip:Show() end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 b:SetScript('OnClick',click);return b
end
local function scoreColor(score)
 if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and score and score>0 then
  local ok,c=pcall(C_ChallengeMode.GetDungeonScoreRarityColor,score)
  if ok and c and c.GenerateHexColor then return c:GenerateHexColor() end
 end
 return 'ffffffff'
end
local function keyText(best)
 if not best or not best.level or best.level<=0 then return nil end
 local color=best.timed==false and 'ff9aa3a8' or 'ffffffff'
 return '|c'..color..'+'..best.level..'|r '..(best.map or '')
end
local function memberBlock(card)
 local b=CreateFrame('Frame',nil,card);b:SetSize(WIDTH-32,MEMBER_HEIGHT)
 b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',0,-1);b.icon:SetSize(15,15)
 b.name=label(b,'',20,0,nil,13)
 b.badge=E.Badge(b);b.badge:SetPoint('TOPRIGHT',0,0)
 -- Region of the applicant's realm ("American" / "Oceanic" / "European") in its region colour,
 -- right-aligned directly under the history badge (user request 2026-10-08).
 b.region=label(b,'',0,0,nil,10);b.region:ClearAllPoints();b.region:SetPoint('TOPRIGHT',b.badge,'BOTTOMRIGHT',0,-3);b.region:SetJustifyH('RIGHT')
 b.role=label(b,'',0,0,nil,10,muted);b.role:ClearAllPoints();b.role:SetPoint('LEFT',b.name,'RIGHT',8,0);b.role:SetPoint('RIGHT',b.badge,'LEFT',-8,0)
 b.stats=label(b,'',20,-18,WIDTH-56,11)
 -- "Best run" sits on its own line directly under "Best here" (user request 2026-10-04); the
 -- hidden measure string gives the x offset where "Best here" starts in the stats line.
 b.bestRun=label(b,'',20,-33,nil,11)
 b.measure=label(b,'',0,0,nil,11);b.measure:Hide()
 b.history=label(b,'',20,-33,WIDTH-56,10,muted)
 b:EnableMouse(true)
 b:SetScript('OnEnter',function(f) if f.detail and f.detail~='' then GameTooltip:SetOwner(f,'ANCHOR_RIGHT');GameTooltip:SetText(f.detail,1,1,1,1,true);GameTooltip:Show() end end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 return b
end
function E.Card(parent)
 local c=CreateFrame('Frame',nil,parent);c:SetWidth(WIDTH-16)
 -- Outline only, no separate dark fill (user request 2026-10-04): the panel surface shows through.
 c.edges=E.Outline(c,1);c.members={}
 c.heading=label(c,'',10,-7,300,12)
 c.warning=E.Badge(c);c.warning:SetPoint('TOPRIGHT',-8,-6)
 c.message=label(c,'',10,0,WIDTH-130,10,muted)
 c.pass=E.Action(c,'Interface\\ChatFrame\\ChatFrameExpandArrow','Pass -- hide this card; the application stays in Group Finder',function() if c.entry then A:ResolveApplicantAlert(c.entry,'notsure') end end)
 c.decline=E.Action(c,'Interface\\RaidFrame\\ReadyCheck-NotReady','Decline',function() if c.entry then A:ResolveApplicantAlert(c.entry,'avoid') end end)
 c.accept=E.Action(c,'Interface\\RaidFrame\\ReadyCheck-Ready','Invite',function() if c.entry then A:ResolveApplicantAlert(c.entry,'accept') end end)
 c.pass:SetPoint('BOTTOMRIGHT',-6,5);c.decline:SetPoint('RIGHT',c.pass,'LEFT',-4,0);c.accept:SetPoint('RIGHT',c.decline,'LEFT',-4,0)
 function c:Update(entry)
  self.entry=entry;local n=#entry.members;local grouped=n>1;local top=grouped and 26 or 7;local avoid=0
  self.heading:SetShown(grouped);self.heading:SetText('Group application  ·  '..n..' players')
  local y=top
  for i,member in ipairs(entry.members) do
   local b=self.members[i];if not b then b=memberBlock(self);self.members[i]=b end
   b:ClearAllPoints();b:SetPoint('TOPLEFT',10,-y);b:Show()
   local rating,count,note=A:GetApplicantReputation(member,entry.preview)
   if rating=='Bad' then avoid=avoid+1 end
   local meta=badges[rating] or noHistory;b.badge:Update(meta[1],meta[2],meta[3])
   -- Player part in class colour, "-Realm" in the realm's region colour (US red, Oceanic green,
   -- Europe yellow) -- restored per user request 2026-10-08 after the compact redesign dropped it.
   local player,embedded=strsplit('-',member.name or 'Unknown player',2)
   local realm=(embedded and embedded~='' and embedded) or member.realm
   local nameText=player
   if realm and realm~='' then
    local region,rr,rg,rb=A.GetServerRegionColor(realm)
    nameText=nameText..format('|cff%02x%02x%02x-%s|r',rr*255,rg*255,rb*255,realm)
    b.region:SetText(regionNames[region] or region);b.region:SetTextColor(rr,rg,rb);b.region:Show()
   else
    b.region:Hide()
   end
   b.name:SetText(nameText)
   local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class or ''];b.name:SetTextColor(color and color.r or 1,color and color.g or 1,color and color.b or 1)
   local class=(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[member.class or '']) or member.class or ''
   -- "Level 90 Balance Druid" when Blizzard supplied it, otherwise the role and class.
   local who=((member.level and member.level>0) and ('Level '..member.level..' ') or '')..((member.spec and member.spec~='') and (member.spec..' ') or '')..class
   b.role:SetText((roleNames[member.role] or 'Role unknown')..'  ·  '..who)
   local atlas=roleAtlas[member.role];if atlas then b.icon:SetAtlas(atlas);b.icon:Show() else b.icon:Hide() end
   local score=member.dungeonScore and member.dungeonScore>0 and math.floor(member.dungeonScore) or nil
   local parts={'iLvl '..(member.ilvl and member.ilvl>0 and math.floor(member.ilvl) or '--'),'M+ |c'..scoreColor(score)..(score or '--')..'|r'}
   local here,best=keyText(member.bestHere),keyText(member.bestRun)
   local separator='   |cff5f676b·|r   '
   local prefix=table.concat(parts,separator)..separator
   -- Only "Best run" and no "Best here": it takes the "Best here" slot on the stats line instead.
   local inline=best and not here
   if here then parts[#parts+1]='Best here '..here elseif inline then parts[#parts+1]='Best run '..best end
   b.stats:SetText(table.concat(parts,separator))
   local secondLine=best and not inline
   if secondLine then
    b.measure:SetText(prefix)
    b.bestRun:SetText('Best run  '..best)
    b.bestRun:ClearAllPoints();b.bestRun:SetPoint('TOPLEFT',20+b.measure:GetStringWidth(),-33)
   end
   b.bestRun:SetShown(secondLine)
   local height=secondLine and MEMBER_HEIGHT+15 or MEMBER_HEIGHT
   b:SetHeight(height)
   b.history:ClearAllPoints();b.history:SetPoint('TOPLEFT',20,secondLine and -48 or -33)
   local history=count and count>0 and (count..(count==1 and ' run together' or ' runs together')) or 'No recorded runs together'
   if note and note~='' then history='Your note: '..note end
   b.history:SetText(history);b.history:SetTextColor(unpack(rating=='Bad' and {1,.55,.55} or muted))
   b.detail=(member.name or '')..'\n'..history
   y=y+height
  end
  for i=n+1,#self.members do self.members[i]:Hide() end
  -- Any Avoid player marks the whole application: 2px red border + "n Avoid player" badge.
  self.hasAvoid=avoid>0
  if self.hasAvoid then colorEdges(self.edges,danger,1,2) else colorEdges(self.edges,S.GetAssetAccent(),.45,1) end
  self.warning:SetShown(grouped and avoid>0);self.warning:Update(avoid..' Avoid '..(avoid==1 and 'player' or 'players'),danger,'status-avoid')
  self:SetHeight(y+28)
  self.message:ClearAllPoints();self.message:SetPoint('BOTTOMLEFT',10,9)
  self.message:SetText('|cffc8cdd0Message:|r '..(entry.comment and entry.comment~='' and entry.comment or 'No message'))
  self.accept.tip=grouped and 'Invite group' or 'Invite'
 end
 return c
end
local MAX_LIST_HEIGHT=380
function A:CreateApplicantAlertPanel(preview)
 local key=preview and 'previewApplicantPanel' or 'applicantAlertPanel'
 if self[key] then return end
 local f=CreateFrame('Frame',nil,UIParent);self[key]=f
 f:SetSize(WIDTH,200);f:SetPoint('TOP',0,-130);f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',f.StartMoving);f:SetScript('OnDragStop',f.StopMovingOrSizing);S.Apply(f,'Window',12)
 f.title=label(f,preview and 'Applicant reputation  |cff9aa3a8· PREVIEW|r' or 'Applicant reputation',14,-12,380,15,white)
 local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-4,-4);close:SetScript('OnClick',function() f:Hide() end)
 f.count=label(f,'',14,-32,300,11)
 f.order=label(f,'Newest first',0,0,100,10,muted);f.order:ClearAllPoints();f.order:SetPoint('TOPRIGHT',-14,-33);f.order:SetJustifyH('RIGHT')
 local scroll=CreateFrame('ScrollFrame',nil,f);scroll:SetPoint('TOPLEFT',8,-50);scroll:SetPoint('BOTTOMRIGHT',-8,22)
 scroll:EnableMouseWheel(true)
 local content=CreateFrame('Frame',nil,scroll);content:SetSize(WIDTH-16,1);scroll:SetScrollChild(content)
 scroll:SetScript('OnMouseWheel',function(s,d) s:SetVerticalScroll(math.max(0,math.min(math.max(0,content:GetHeight()-s:GetHeight()),s:GetVerticalScroll()-d*40))) end)
 f.scrollFrame=scroll;f.scrollContent=content;f.rows={}
 f.footer=label(f,'',14,0,WIDTH-28,9,muted);f.footer:ClearAllPoints();f.footer:SetPoint('BOTTOMLEFT',14,8)
 f.preview=preview
 -- While open, re-check against Blizzard's live list every 2s so cancelled applications vanish
 -- even if no LFG event reached us (user report 2026-10-04).
 if not preview then
  local elapsed=0
  f:SetScript('OnUpdate',function(_,dt) elapsed=elapsed+dt;if elapsed>=2 then elapsed=0;A:PruneApplicantAlertsNow() end end)
 end
 f:Hide()
end
function A:RefreshApplicantAlertPanel(preview)
 local f=preview and self.previewApplicantPanel or self.applicantAlertPanel
 if not f then return end
 local pending=(preview and self.previewApplicantAlerts or self.pendingApplicantAlerts) or {}
 if #pending==0 then f:Hide();return end
 local offset,players,anyAvoid=0,0,false
 for i=1,#pending do
  local entry=pending[#pending-i+1];players=players+#entry.members
  local card=f.rows[i];if not card then card=E.Card(f.scrollContent);f.rows[i]=card end
  card:ClearAllPoints();card:SetPoint('TOPLEFT',0,-offset);card:Update(entry);card:Show();offset=offset+card:GetHeight()+6
  anyAvoid=anyAvoid or card.hasAvoid
 end
 for i=#pending+1,#f.rows do f.rows[i]:Hide();f.rows[i].entry=nil end
 f.count:SetText(#pending..(#pending==1 and ' application' or ' applications')..'  ·  '..players..(players==1 and ' player' or ' players'))
 f.footer:SetText(preview and 'Preview only: buttons dismiss examples.' or (anyAvoid and '|cffff6b6bRed border: this application includes an Avoid player.|r' or 'Pass hides the card; the application stays in Group Finder.'))
 f.scrollContent:SetHeight(math.max(1,offset))
 -- Grow with the content up to MAX_LIST_HEIGHT, then scroll.
 local listHeight=math.min(MAX_LIST_HEIGHT,math.max(60,offset-6))
 f:SetHeight(50+listHeight+24)
 local maxScroll=math.max(0,offset-listHeight);f.scrollFrame:SetVerticalScroll(math.min(f.scrollFrame:GetVerticalScroll(),maxScroll))
 f:Show()
end
function A:RefreshApplicantThemes()
 -- Do not reopen a deliberately dismissed window when changing themes.
 for _,preview in ipairs({false,true}) do
  local f=preview and self.previewApplicantPanel or self.applicantAlertPanel
  if f and f:IsShown() then self:RefreshApplicantAlertPanel(preview) end
 end
end

-- Spec, level and best keys for one applicant member -- the same data Blizzard's applicant
-- tooltip shows ("Level 90 Balance Druid", "Best for Dungeon 12 Temple of Sethraliss",
-- "Best Run 13 Voidscar Arena"). Every call is pcall'd and secret values are dropped, so a
-- missing API or a restricted value simply leaves that detail off the card.
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function readBest(info)
 if type(info)~='table' then return nil end
 local level,map=info.bestRunLevel,info.mapName
 if not plain(level) or not plain(map) or not level or level<=0 then return nil end
 return {level=level,map=map,timed=plain(info.finishedSuccess) and info.finishedSuccess or nil}
end
function A:GetApplicantExtras(applicantID,memberIndex,classToken,level,specID)
 local extras={}
 if plain(level) and tonumber(level) and tonumber(level)>0 then extras.level=tonumber(level) end
 if plain(specID) and tonumber(specID) and GetSpecializationInfoByID then
  local ok,_,specName,_,_,_,specClass=pcall(GetSpecializationInfoByID,tonumber(specID))
  -- Cross-checked against the applicant's own class so a shifted return order can't mislabel.
  if ok and plain(specName) and specName and (not classToken or not specClass or specClass==classToken) then extras.spec=specName end
 end
 if C_LFGList then
  if C_LFGList.GetApplicantDungeonScoreForListing and C_LFGList.GetActiveEntryInfo then
   local okEntry,entryInfo=pcall(C_LFGList.GetActiveEntryInfo)
   local activityID=okEntry and type(entryInfo)=='table' and ((entryInfo.activityIDs and entryInfo.activityIDs[1]) or entryInfo.activityID)
   if plain(activityID) and activityID then
    local ok,info=pcall(C_LFGList.GetApplicantDungeonScoreForListing,applicantID,memberIndex,activityID)
    if ok then extras.bestHere=readBest(info) end
   end
  end
  if C_LFGList.GetApplicantBestDungeonScore then
   local ok,info=pcall(C_LFGList.GetApplicantBestDungeonScore,applicantID,memberIndex)
   if ok then extras.bestRun=readBest(info) end
  end
 end
 return extras
end

function A:PreviewApplicantAlert()
 self:CreateApplicantAlertPanel(true)
 -- Stored oldest-first, matching the live queue; render newest-first.
 self.previewApplicantAlerts={
  {preview=true,applicantID='test-group',members={
   {name='ExampleDamage-Frostmourne',role='DAMAGER',class='MAGE',spec='Frost',level=90,rating='Bad',ilvl=305,dungeonScore=2600,notes='Left a previous run early',bestHere={level=11,map='Temple of Sethraliss',timed=true},bestRun={level=12,map='Murder Row',timed=true}},
   {name='ExampleFriend-Area52',role='DAMAGER',class='DRUID',spec='Balance',level=90,ilvl=300,dungeonScore=2300,bestHere={level=10,map='Temple of Sethraliss',timed=false},bestRun={level=11,map='Altar of Fangs',timed=true}}},comment='We are applying together.'},
  {preview=true,applicantID='test-healer',members={{name='ExampleHealer-Barthilas',role='HEALER',class='PRIEST',spec='Discipline',level=90,ilvl=295,dungeonScore=2100,bestRun={level=10,map='Kings\' Rest',timed=true}}},comment='Ready when you are.'},
  {preview=true,applicantID='test-tank',members={{name='ExampleTank-Illidan',role='TANK',class='PALADIN',spec='Protection',level=90,rating='Good',groupCount=5,ilvl=300,dungeonScore=2400,bestHere={level=12,map='Temple of Sethraliss',timed=true},bestRun={level=13,map='Voidscar Arena',timed=true}}},comment='Happy to help with the route.'}
 }
 self:RefreshApplicantAlertPanel(true)
end

-- Group-state rules for the live panel (user request 2026-10-08):
--  * Settings > Sharing & reputation > "Hide applicant reputation when I'm not the group leader"
--    (off by default): in someone else's group, new applicants aren't shown and an open panel closes.
--  * Always: once the party is full (5) the group is formed, so the panel closes and its cards clear.
--    (A delisted group already clears through PruneApplicantAlertsNow.)
local function notLeader()
 return A.db and A.db.hideApplicantsUnlessLeader==true and IsInGroup() and not UnitIsGroupLeader('player')
end
local function partyFull()
 return IsInGroup() and not IsInRaid() and GetNumGroupMembers()>=5
end
local queue=A.QueueApplicantAlert
function A:QueueApplicantAlert(...)
 if notLeader() or partyFull() then return end
 return queue(self,...)
end
local function closeIfDone()
 if not (notLeader() or partyFull()) then return end
 if A.pendingApplicantAlerts and #A.pendingApplicantAlerts>0 then
  A.pendingApplicantAlerts={}
  A:RefreshApplicantAlertPanel()
 elseif A.applicantAlertPanel then
  A.applicantAlertPanel:Hide()
 end
end
local groupEvents=CreateFrame('Frame')
for _,e in ipairs({'GROUP_ROSTER_UPDATE','PARTY_LEADER_CHANGED','GROUP_JOINED'}) do groupEvents:RegisterEvent(e) end
groupEvents:SetScript('OnEvent',closeIfDone)
