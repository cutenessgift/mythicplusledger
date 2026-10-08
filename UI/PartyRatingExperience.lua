-- Approved Rate Your Party mockup; storage and star callbacks remain in Core.lua.
local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local regions={US={'AMERICAS',{1,.76,.24}},OCE={'OCEANIC',{.05,.86,1}},EU={'EUROPE',{.73,.52,1}},KR={'KOREA',{.55,.85,.55}},TW={'TAIWAN',{1,.57,.35}},CN={'CHINA',{1,.48,.55}}}
local oceanic={amanthul=true,barthilas=true,caelestrasz=true,dathremar=true,dreadmaul=true,frostmourne=true,gundrak=true,jubeithos=true,khazgoroth=true,saurfang=true,thaurissan=true}
local regionIDs={[1]='US',[2]='KR',[3]='EU',[4]='TW',[5]='CN'}
local function regionFor(realm)
 if not realm or realm=='' then return 'UNKNOWN',{.65,.68,.72} end
 local id
 if GetCurrentRegion then local ok,value=pcall(GetCurrentRegion);if ok then id=regionIDs[value] end end
 if id=='US' and oceanic[realm:lower():gsub('[%s%p]','')] then id='OCE' end
 local entry=regions[id];return entry and entry[1] or 'UNKNOWN',entry and entry[2] or {.65,.68,.72}
end
A.GetPartyRatingRegion=regionFor
local function at(f,parent,x,y,w,h)
 f:ClearAllPoints();f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);if w then f:SetWidth(w) end;if h then f:SetHeight(h) end
end
local function text(parent,value,size)
 local t=S.Label(parent,value,size or 12,{.91,.92,.94});t:SetWordWrap(false);return t
end
local function colored(value,c)
 return string.format('|cff%02x%02x%02x%s|r',math.floor(c[1]*255),math.floor(c[2]*255),math.floor(c[3]*255),value or '')
end
local roleNames={TANK='Tank',HEALER='Healer',DAMAGER='Damage'}
function A:StylePartyRatingPopup()
 local f=self.ratingPopup;if not f or not f.rows then return end
 local count=0;for _,row in ipairs(f.rows) do if row.memberName then count=count+1 end end
 f:SetSize(500,144+math.max(1,math.min(count,4))*96)
 -- Fit smaller screens without clipping either the cards or the footer.
 f:SetScale(math.min(1,(UIParent:GetWidth()-40)/500,(UIParent:GetHeight()-40)/f:GetHeight()))
 if not f.partyDesigned then
  f.partyDesigned=true
  f:SetBackdrop(nil);S.Apply(f,'Window',20)
  f.book=f:CreateTexture(nil,'ARTWORK');f.book:SetSize(32,32);f.book:SetPoint('TOPLEFT',18,-14);S.ThemeAsset(f.book,'runs')
  f.closeParty=S.Button(f,'X',26,26,function() f:Hide() end);f.closeParty:SetPoint('TOPRIGHT',-12,-12)
  f.previewLabel=text(f,'DESIGN PREVIEW',10);f.previewLabel:SetPoint('TOPRIGHT',-56,-24)
  f.regionLegend=text(f,'Server regions:  |cffffc23dAmericas|r  •  |cff0ddbffOceanic|r  •  |cffba85ffEurope|r',10);f.regionLegend:SetPoint('BOTTOM',0,10);f.regionLegend:SetFont(STANDARD_TEXT_FONT,9,'')
  f.separator=f:CreateTexture(nil,'ARTWORK');f.separator:SetColorTexture(.6,.62,.65,.45);f.separator:SetHeight(1);f.separator:SetPoint('BOTTOMLEFT',16,66);f.separator:SetPoint('BOTTOMRIGHT',-16,66)
 end
 f.previewLabel:Hide()
 at(f.partyTitle,f,60,-14,375,26);f.partyTitle:SetFont(STANDARD_TEXT_FONT,20,'');f.partyTitle:SetTextColor(1,1,1)
 f.subtitle:ClearAllPoints();f.subtitle:SetPoint('TOP',0,-40);f.subtitle:SetWidth(450);f.subtitle:SetJustifyH('CENTER')
 f.partyNote:ClearAllPoints();f.partyNote:SetPoint('TOP',0,-58);f.partyNote:SetFont(STANDARD_TEXT_FONT,10,'');f.partyNote:SetText('Rate anyone you played with. Notes are optional.')
 f.scrollFrame:ClearAllPoints();f.scrollFrame:SetPoint('TOPLEFT',16,-78);f.scrollFrame:SetPoint('BOTTOMRIGHT',-16,66)
 f.scrollContent:SetWidth(468);f.scrollContent:SetHeight(math.max(1,count*96))
 if f.scrollFrame.ScrollBar then f.scrollFrame.ScrollBar:SetShown(count>4) end
 f.selectionSummary:ClearAllPoints();f.selectionSummary:SetPoint('BOTTOMLEFT',16,45);f.selectionSummary:SetFont(STANDARD_TEXT_FONT,12,'');f.selectionSummary:SetWidth(240)
 f.partyHint:ClearAllPoints();f.partyHint:SetPoint('BOTTOMLEFT',16,29);f.partyHint:SetFont(STANDARD_TEXT_FONT,10,'')
 f.partySkip:ClearAllPoints();f.partySkip:SetPoint('BOTTOMRIGHT',-132,27);f.partySkip:SetSize(94,30)
 f.saveButton:ClearAllPoints();f.saveButton:SetPoint('BOTTOMRIGHT',-16,27);f.saveButton:SetSize(108,30)
 for _,b in ipairs({f.partySkip,f.saveButton}) do
  b:SetBackdrop(nil);S.Apply(b,'Button',10)
  if b.text then b.text:ClearAllPoints();b.text:SetPoint('CENTER');b.text:SetWidth(b:GetWidth()-24);b.text:SetJustifyH('CENTER');b.text:SetTextColor(1,1,1) end
 end
 if not f.saveButton.partyFill then
  local t=f.saveButton:CreateTexture(nil,'BACKGROUND',nil,7);t:SetPoint('TOPLEFT',7,-7);t:SetPoint('BOTTOMRIGHT',-7,7);t:SetColorTexture(.28,.025,.07,1);f.saveButton.partyFill=t
 end
 for i,row in ipairs(f.rows) do
  at(row,f.scrollContent,0,-(i-1)*96,468,90)
  row:SetBackdropColor(.027,.035,.04,1);row:SetBackdropBorderColor(.42,.44,.46,.8)
  if not row.partyDesigned then
   row.partyDesigned=true
   row.roleRing=row:CreateTexture(nil,'ARTWORK');at(row.roleRing,row,10,-11,38,38);row.roleRing:SetTexture(media..'Themes\\silver\\portrait-ring.png')
   row.roleIcon=row:CreateTexture(nil,'ARTWORK',nil,1);at(row.roleIcon,row,18,-19,22,22)
   row.roleName=text(row,'',9);at(row.roleName,row,4,-53,50);row.roleName:SetJustifyH('CENTER')
   row.realmName=text(row,'',10);at(row.realmName,row,296,-12,158);row.realmName:SetJustifyH('RIGHT')
   row.regionBadge=ns.ApplicantElements.Badge(row);row.regionBadge:SetPoint('TOPRIGHT',-12,-29)
   row.commentLabel:Hide()
   for _,part in ipairs({row.comment:GetRegions()}) do if part:IsObjectType('Texture') then part:Hide() end end
   row.noteFill=row.comment:CreateTexture(nil,'BACKGROUND');row.noteFill:SetAllPoints();row.noteFill:SetColorTexture(.018,.022,.028,1)
   row.noteEdges=ns.ApplicantElements.Outline(row.comment,1)
   for _,edge in ipairs(row.noteEdges) do edge:SetVertexColor(.48,.50,.53,.8) end
  end
  at(row.name,row,58,-11,230);row.name:SetFont(STANDARD_TEXT_FONT,14,'')
  at(row.meta,row,58,-31,290);row.meta:SetFont(STANDARD_TEXT_FONT,10,'')
  for n,star in ipairs(row.stars) do at(star,row,58+(n-1)*25,-49,24,24);star.icon:SetSize(22,22);star.highlight:SetAlpha(.35) end
  at(row.ratingLabel,row,58,-76,158);row.ratingLabel:SetFont(STANDARD_TEXT_FONT,10,'')
  at(row.comment,row,226,-54,228,26);row.placeholder:SetText('Add a note (optional)...')
  row.comment:SetTextInsets(10,10,0,0)
  local m=row.ratingMember
  if m and row.memberName then
   local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class];local cc=c and {c.r,c.g,c.b} or {1,1,1}
   row.name:SetTextColor(unpack(cc))
   local fields={};if m.race and m.race~='' then fields[#fields+1]=m.race end
   if m.faction and m.faction~='' then fields[#fields+1]=colored(m.faction,m.faction=='Alliance' and {.08,.62,1} or (m.faction=='Horde' and {1,.22,.29} or {.7,.7,.7})) end
   if m.class then fields[#fields+1]=colored((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[m.class]) or m.class,cc) end
   row.meta:SetText(table.concat(fields,'  •  '))
   local realm=m.realm or row.memberName:match('^[^-]+%-(.+)$') or (GetRealmName and GetRealmName()) or ''
   local region,rc=regionFor(realm);row.realmName:SetText(realm~='' and realm or 'Unknown realm');row.realmName:SetTextColor(unpack(rc));row.regionBadge:Update(region,rc)
   row.roleName:SetText(roleNames[m.role] or 'Unknown')
   if m.role=='HEALER' then row.roleIcon:SetTexture(media..'MenuIcons\\Healer.png')
   elseif m.role=='TANK' then row.roleIcon:SetTexture(media..'Themes\\silver\\key-level-badge.png');row.roleIcon:SetTexCoord(0,1,0,1)
   else row.roleIcon:SetTexture(media..'Themes\\silver\\boss-fights.png') end
   if m.role~='TANK' then row.roleIcon:SetTexCoord(0,1,0,1) end
   row.roleIcon:SetDesaturated(true)
  end
 end
end
hooksecurefunc(A,'PromptPlayerRatings',function() A:StylePartyRatingPopup() end)

