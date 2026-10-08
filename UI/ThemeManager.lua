-- Asset themes are independent of the existing difficulty/class/chat colour settings.
local addonName, ns = ...
local A, S, assets = MPlusLedger, ns.LedgerSkin, ns.LedgerThemeAssets
if not A or not S or not assets then return end
local base = 'Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local bindings = setmetatable({}, {__mode='k'})
local framed = setmetatable({}, {__mode='k'})
local accentLabels = setmetatable({}, {__mode='k'})
local accents = {gold={.94,.77,.40}, silver={.78,.82,.86}, neutral={.76,.73,.63}, garnet={.78,.34,.46}, midnight={.66,.46,.94}, garnetsilver={.83,.85,.88}}
local function theme()
 local value = A.db and A.db.assetTheme
 return assets[value] and value or 'gold'
end
local function paint(t, binding)
 local p = theme(); local source=assets[p][binding.name] and p or 'silver'
 local uv = assets[source][binding.name]
 if not uv then return end
 t:SetTexture(base..'Themes\\'..source..'\\'..binding.name..'.png')
 -- A theme without its own copy of this icon borrows Silver's, recoloured to the theme accent so
 -- it doesn't show up as a stray silver icon (e.g. Manage Runs / Boss Pacing in Garnet). Proper
 -- per-theme art replaces this automatically once the file exists in ThemeAssets.lua.
 if source~=p then
  local c=accents[p];t:SetDesaturated(true);t:SetVertexColor(c[1],c[2],c[3])
 else
  t:SetDesaturated(false);t:SetVertexColor(1,1,1)
 end
 local crop = binding.crop
 if crop then
  local w,h=uv[2]-uv[1],uv[4]-uv[3]
  t:SetTexCoord(uv[1]+w*crop[1],uv[1]+w*crop[2],uv[3]+h*crop[3],uv[3]+h*crop[4])
 else t:SetTexCoord(unpack(uv)) end
end
local accentTextures=setmetatable({}, {__mode='k'})
local backgrounds=setmetatable({}, {__mode='k'})
local backdrops=setmetatable({}, {__mode='k'})
local surfaces={gold={.025,.055,.065},silver={.025,.055,.065},neutral={.045,.048,.044},garnet={.035,.009,.015},midnight={.018,.010,.035},garnetsilver={.032,.010,.016}}
local ornaments=setmetatable({}, {__mode='k'})
local metals=setmetatable({}, {__mode='k'})
function S.ThemeMetal(texture)
 metals[texture]=true;texture:SetDesaturated(true);texture:SetVertexColor(unpack(accents[theme()]))
end
function S.ThemeOrnament(texture)
 ornaments[texture]=true
 local c=accents[theme()];texture:SetDesaturated(true);texture:SetVertexColor(c[1]*.52,c[2]*.52,c[3]*.52);texture:SetAlpha(.45)
end
function S.ThemeText(label)
 accentLabels[label]=true;label:SetTextColor(unpack(accents[theme()]))
end
function S.ThemeAccentTexture(texture)
 accentTextures[texture]=true;texture:SetColorTexture(unpack(accents[theme()]))
end
function S.ThemeBackground(texture,alpha)
 backgrounds[texture]=alpha or 1;local c=surfaces[theme()];texture:SetColorTexture(c[1],c[2],c[3],alpha or 1)
end
function S.ThemeBackdrop(frame,alpha)
 backdrops[frame]=alpha or 1;local c=surfaces[theme()];frame:SetBackdropColor(c[1],c[2],c[3],alpha or 1)
end
function S.GetAssetAccent(key) return accents[key or theme()] or accents.gold end
function S.GetAssetTheme() return theme() end
function S.ThemeAsset(t, name, crop)
 if not assets[theme()][name] and not assets.silver[name] then return end
 local binding={name=name,crop=crop}; bindings[t]=binding; paint(t,binding)
end
local function slices(frame, name)
 local parts=frame.LedgerSkinTextures
 if not parts then return end
 -- These regions were constructed for the original 512px skin atlas. Full-canvas
 -- generated artwork has different margins and cannot be substituted into them.
 local style=frame.LedgerSkinStyle or framed[frame] or 'Button'
 local palette=theme();local accent=accents[palette]
 -- ONE flat surface colour per theme, for windows, cards, buttons and fields alike -- per user
 -- request 2026-10-04: the old code painted a second, darker centre (multiplied by the accent) on
 -- top of this one, which read as a lighter "border band" around a darker panel in every theme
 -- but Gold, and gave buttons a separate coloured box behind their icon and text.
 -- The surface is inset to the middle of the drawn border line: the shared border art has a
 -- transparent margin outside that line (~36% of a corner horizontally, ~25% vertically, measured
 -- from Themes\gold\panel-border.png with the texcoords below), and the old 2px inset let the
 -- background show outside the border.
 local edge=parts[1]:GetWidth() or 0
 local ix,iy=math.floor(edge*.36+.5),math.floor(edge*.25+.5)
 if not frame.ledgerSurface then frame.ledgerSurface=frame:CreateTexture(nil,'BACKGROUND',nil,-8) end
 frame.ledgerSurface:ClearAllPoints()
 frame.ledgerSurface:SetPoint('TOPLEFT',ix,-iy)
 frame.ledgerSurface:SetPoint('BOTTOMRIGHT',-ix,iy)
 local fill=surfaces[palette]
 frame.ledgerSurface:SetColorTexture(fill[1],fill[2],fill[3],1)
 -- Independent source coordinates preserve decorative corners as the frame resizes. Every theme
 -- shares the same geometry; only the tint changes.
 local xuv={0,.18,.82,1};local yuv={0,.28,.72,1}
 local light=style=='Button' and (name=='button-pressed' and .70 or (name=='button-hover' and 1 or .88)) or 1
 for r=1,3 do for c=1,3 do
  local index=(r-1)*3+c;local t=parts[index];bindings[t]=nil
  if index==5 then
   -- Centre stays transparent (the surface above shows through) unless a menu deliberately
   -- coloured it afterwards, e.g. the Timed/Overtime/Abandoned status buttons -- those survive
   -- every refresh because this only resets on a theme change.
   if frame.ledgerPaintedTheme~=palette then t:SetColorTexture(0,0,0,0) end
   t:SetDesaturated(false);t:SetVertexColor(1,1,1)
  else
   t:SetTexture(base..'Themes\\gold\\panel-border.png')
   t:SetTexCoord(xuv[c],xuv[c+1],yuv[r],yuv[r+1])
   if palette=='gold' then t:SetDesaturated(false);t:SetVertexColor(light,light,light)
   else t:SetDesaturated(true);t:SetVertexColor(accent[1]*light,accent[2]*light,accent[3]*light) end
  end
 end end
 frame.ledgerPaintedTheme=palette
end
local function buttonState(f)
 local state=not f:IsEnabled() and 'normal' or (f.ledgerThemePressed and 'pressed' or (f:IsMouseOver() and 'hover' or 'normal'))
 slices(f,f.ledgerThemeDropdown and 'dropdown-field' or ('button-'..state))
end
local oldApply=S.Apply
local oldLabel=S.Label
function S.Label(parent,text,size,color)
 local label=oldLabel(parent,text,size,color)
 if color==S.colors.gold then accentLabels[label]=true;label:SetTextColor(unpack(accents[theme()])) end
 return label
end
function S.Apply(frame, style, edge)
 local parts=oldApply(frame,style,edge)
 if not framed[frame] then
  framed[frame]=frame.LedgerSkinStyle or style
  if style=='Button' then
   for _,event in ipairs({'OnEnter','OnLeave','OnEnable','OnDisable'}) do frame:HookScript(event,buttonState) end
   frame:HookScript('OnMouseDown',function(f) f.ledgerThemePressed=true;buttonState(f) end)
   frame:HookScript('OnMouseUp',function(f) f.ledgerThemePressed=false;buttonState(f) end)
   frame:HookScript('OnLeave',function(f) f.ledgerThemePressed=false;buttonState(f) end)
  end
 end
 slices(frame,style=='Button' and 'button-normal' or 'panel-border')
 -- Keep the original dark teal center and any opacity/tint set by its menu.
 return parts
end
local aliases={Book='runs',List='manage-runs',Chart='progress',Search='search',Share='share',Close='close',Check='status-completed',
 Skull='deaths-silver',Wrench='repair-silver',Compass='runs',Back='navigation-left',
 -- Generated per-theme icons (tools/make_theme_icons.py, 2026-10-04).
 Sort='sort',Filter='filter',Save='save',Edit='edit',Delete='delete',AddPlayer='add-player',Details='details'}
local atlas={['0,0.18']='runs',['0.75,0.5']='status-trusted',['0.25,0.18']='boss-fights',['0.5,0.18']='deaths-silver',['0.75,0.18']='player-history',
 ['0,0.5']='travel',['0.25,0.5']='repair-silver',['0.5,0.5']='repair-silver'}
local tintedIcons={Next=true}
local nav={['<']='navigation-left',['>']='navigation-right',['Up']='navigation-up',['Down']='navigation-down'}
local dropdowns={'sortButton','runExpansionFilterButton','runInstanceFilterButton','createInstanceButton','createExpansionButton','expansionButton','instanceButton','difficultyButton','addPlayerKnownButton','addPlayerClassButton','addPlayerRoleButton','dungeonButton','viewModeButton','filterButton','lookbackButton','bossButton','instanceFilterButton'}
local statuses={Completed='status-completed',Timed='status-completed',Overtime='status-overtime',Abandoned='status-abandoned',Trusted='status-trusted',Avoid='status-avoid',Neutral='status-neutral',['No history']='status-nohistory',['No History']='status-nohistory'}
local actions={['Manage Runs']='manage-runs',['Record Repair']='repair-silver',['All Runs']='runs',['View All Runs']='runs',['Player History']='player-history',['M+ Stats']='progress',['Main Menu']='runs',['Overview']='runs',['Season']='status-overtime',['Trends']='progress',['Boss Pacing']='boss-fights',['Progress']='progress',['Share']='share'}
local function region(t)
 if not t.IsObjectType or not t:IsObjectType('Texture') then return end
 local path=t:GetTexture()
 if type(path)~='string' or path:sub(1,#base):lower()~=base:lower() then return end
 if path:find('\\Themes\\',1,true) then
  if bindings[t] then paint(t,bindings[t]) end
  return
 end
 local name=path:match('([^\\]+)%.png$');local replacement=aliases[name]
 -- Generic MenuIcons with no per-theme artwork yet (Next): recolour the gold original to the
 -- theme accent instead of leaving it gold everywhere.
 if tintedIcons[name] then
  local p=theme()
  if p=='gold' then t:SetDesaturated(false);t:SetVertexColor(1,1,1)
  else local c=accents[p];t:SetDesaturated(true);t:SetVertexColor(c[1],c[2],c[3]) end
  return
 end
 if name=='GoldIcons' then
  local left,top=t:GetTexCoord()
  replacement=atlas[string.format('%.2g,%.2g',left,top)]
 end
 if replacement then S.ThemeAsset(t,replacement) end
end
local function visit(f,seen,depth)
 if not f or seen[f] or depth>18 then return end
 seen[f]=true
 if f.LedgerSkinTextures then S.Apply(f,f.LedgerSkinStyle or framed[f] or 'Card') end
 for _,key in ipairs(dropdowns) do
  local b=f[key]
  if b and b.LedgerSkinTextures then b.ledgerThemeDropdown=true;slices(b,'dropdown-field') end
 end
 for _,t in ipairs({f:GetRegions()}) do region(t) end
 if f:IsObjectType('Button') then
  local label=f.Label or f.text or (f.GetFontString and f:GetFontString())
  local value=label and label.GetText and label:GetText()
  -- ledgerNoAutoIcon: buttons whose label only happens to match (e.g. the "Neutral" theme card).
  local name=not f.ledgerNoAutoIcon and (nav[value] or statuses[value] or actions[value]) or nil
  if name and not f.menuAssetIcon and not nav[value] and f:GetWidth()>=90 then
   f.menuAssetIcon=f:CreateTexture(nil,'OVERLAY');f.menuAssetIcon:SetSize(16,16);f.menuAssetIcon:SetPoint('LEFT',10,0)
   label:ClearAllPoints();label:SetPoint('LEFT',32,0);label:SetPoint('RIGHT',-10,0);label:SetJustifyH('CENTER')
  end
  if name and f.menuAssetIcon then S.ThemeAsset(f.menuAssetIcon,name) end
  if nav[value] and f:GetWidth()<=70 then
   if not f.ledgerNavigation then
    f.ledgerNavigation=f:CreateTexture(nil,'OVERLAY');f.ledgerNavigation:SetSize(18,18);f.ledgerNavigation:SetPoint('CENTER')
   end
   S.ThemeAsset(f.ledgerNavigation,nav[value]);f.ledgerNavigation:Show();label:Hide()
  elseif f.ledgerNavigation then f.ledgerNavigation:Hide() end
 end
 -- Preserve the tested percentage atlas and add the new smooth ornamental rim.
 if f.ring and f.percent and f.completeLabel then
  if not f.ledgerMeterFrame then f.ledgerMeterFrame=f:CreateTexture(nil,'OVERLAY');f.ledgerMeterFrame:SetAllPoints(f.ring) end
  S.ThemeAsset(f.ledgerMeterFrame,'completion-meter-frame')
  if f.key and f.key.ledgerBadge then f.key.ledgerBadge:Hide() end
 end
 if f:IsObjectType('Slider') and ((f.GetName and (f:GetName() or ''):lower():find('scroll')) or f.ledgerThemeScrollbar) then
  local thumb=f:GetThumbTexture()
  if thumb then S.ThemeAsset(thumb,'scrollbar-thumb') end
  if not f.ledgerScrollTrack then f.ledgerScrollTrack=f:CreateTexture(nil,'BACKGROUND');f.ledgerScrollTrack:SetAllPoints() end
  S.ThemeAsset(f.ledgerScrollTrack,'scrollbar-track')
 end
 local scroll=f.ScrollBar or f.scrollBar or f.scrollbar
 if scroll and scroll.IsObjectType and scroll:IsObjectType('Slider') then scroll.ledgerThemeScrollbar=true end
 for _,c in ipairs({f:GetChildren()}) do visit(c,seen,depth+1) end
end
local roots={'window','dataTools','repairWindow','playerHistoryWindow','addPlayerWindow','updatePlayerWindow','debugEditor','statsHubWindow','progressTabPanel','trendsTabPanel','pacingTabPanel','seasonTabPanel','mplusTabPanel','ratingPopup','dungeonColorsWindow','trackerBar','trackerPreview','applicantAlertPanel','previewApplicantPanel','settingsPanel'}
local pending=false
local function refresh()
 pending=false
 if InCombatLockdown and InCombatLockdown() then return end
 local seen={}
 for _,key in ipairs(roots) do local f=A[key];if f then visit(f,seen,0) end end
 for _,p in ipairs(A.settingsSubPanels or {}) do visit(p,seen,0) end
end
local function queue()
 if pending then return end
 pending=true;C_Timer.After(0,refresh)
end
function A:SetAssetTheme(value)
 if not assets[value] or not self.db then return false end
 self.db.assetTheme=value
 local c=accents[value];for i=1,3 do S.colors.gold[i]=c[i] end
 for t,b in pairs(bindings) do paint(t,b) end
 for frame in pairs(framed) do slices(frame) end
 for label in pairs(accentLabels) do label:SetTextColor(unpack(c)) end
 for t in pairs(accentTextures) do S.ThemeAccentTexture(t) end
 for t in pairs(ornaments) do S.ThemeOrnament(t) end
 for t in pairs(metals) do S.ThemeMetal(t) end
 for t,alpha in pairs(backgrounds) do S.ThemeBackground(t,alpha) end
 for frame,alpha in pairs(backdrops) do
  if frame.GetBackdrop and frame:GetBackdrop() then S.ThemeBackdrop(frame,alpha);frame:SetBackdropBorderColor(self:GetThemeBorderColor(false,.85)) end
 end
 if self.statsHubWindow then
  for _,tab in pairs(self.statsHubWindow.tabs or {}) do if tab.underline then S.ThemeAccentTexture(tab.underline) end end
 end
 if self.assetThemePanel then self.assetThemePanel:UpdateSelection() end
 if self.RefreshApplicantThemes then self:RefreshApplicantThemes() end
 queue()
 return true
end
for _,method in ipairs({'CreateWindow','RefreshWindow','CreateDataToolsWindow','RefreshDataToolsWindow','CreateRepairWindow','RefreshRepairWindow','CreatePlayerHistoryWindow','RefreshPlayerHistoryWindow','CreateAddPlayerWindow','RefreshAddPlayerWindow','CreateUpdatePlayerWindow','RefreshUpdatePlayerWindow','CreateStatsHubWindow','RefreshProgressTabContent','RefreshTrendsTabContent','RefreshBossPacingTabContent','RefreshSeasonTabContent','RefreshMythicPlusStatsTabData'}) do
 if type(A[method])=='function' then hooksecurefunc(A,method,queue) end
end
function A:CreateAssetThemeSettings()
 if self.assetThemePanel or not self.settingsCategory or not Settings.RegisterCanvasLayoutSubcategory then return end
 local p=CreateFrame('Frame');self.assetThemePanel=p;p.name='Artwork themes'
 local title=S.Label(p,'M+ Ledger — Artwork themes',22);title:SetPoint('TOPLEFT',20,-20)
 local desc=S.Label(p,'Choose matching buttons, borders and icons. Saved for this account; changes apply immediately.',12);desc:SetPoint('TOPLEFT',20,-58);desc:SetWidth(580);desc:SetWordWrap(true)
 p.choices={}
 local names={gold='Gold',silver='Silver',neutral='Neutral',garnet='Garnet',midnight='Midnight Violet',garnetsilver='Garnet & Silver'}
 for i,key in ipairs({'gold','silver','neutral','garnet','midnight','garnetsilver'}) do
  local b=S.Button(p,names[key],170,38,function() A:SetAssetTheme(key);p:UpdateSelection() end)
  b:SetPoint('TOPLEFT',20+((i-1)%3)*185,-100-math.floor((i-1)/3)*46);p.choices[key]=b
 end
 function p:UpdateSelection()
  for key,b in pairs(self.choices) do b.Label:SetText((theme()==key and '✓ ' or '')..names[key]) end
 end
 local check=CreateFrame('CheckButton',nil,p,'UICheckButtonTemplate');check:SetPoint('TOPLEFT',20,-200)
 local text=S.Label(p,'Decorative highest-key badges on dungeon cards',13);text:SetPoint('LEFT',check,'RIGHT',6,0)
 check:SetScript('OnClick',function(f) if A.db then A.db.decorativeKeyBadges=f:GetChecked() and true or false;queue() end end)
 p:SetScript('OnShow',function() p:UpdateSelection();check:SetChecked(A.db and A.db.decorativeKeyBadges or false) end)
 local note=S.Label(p,'Boss portraits use the creature model first, then official Adventure Guide artwork.\nClass colours, difficulty colours and run data are unchanged.',12);note:SetPoint('TOPLEFT',20,-250);note:SetWidth(580);note:SetWordWrap(true)
 Settings.RegisterCanvasLayoutSubcategory(self.settingsCategory,p,'Artwork themes')
end
if A.CreateSettingsPanel then hooksecurefunc(A,'CreateSettingsPanel',function() A:CreateAssetThemeSettings() end) end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent',function() if A.db then A:SetAssetTheme(theme()) end;A:CreateAssetThemeSettings();queue() end)
SLASH_MPLUSLEDGERTHEME1='/mltheme'
SlashCmdList.MPLUSLEDGERTHEME=function(value)
 value=(value or ''):lower():match('^%s*(.-)%s*$')
 if not A:SetAssetTheme(value) then print('M+ Ledger: /mltheme gold, silver, neutral, garnet, midnight or garnetsilver') end
end
