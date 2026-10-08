local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
local function text(p,value,x,y,size)
 local l=S.Label(p,value,size or 12);l:SetPoint('TOPLEFT',x,y);l:SetWidth(540);l:SetWordWrap(true);return l
end
local function page(title,description)
 local p=CreateFrame('Frame');p.name=title;p.checkButtons={}
 local bg=p:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();S.ThemeBackground(bg,.98)
 local scroll=CreateFrame('ScrollFrame',nil,p,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',12,-12);scroll:SetPoint('BOTTOMRIGHT',-30,12)
 local content=CreateFrame('Frame',nil,scroll);content:SetSize(600,760);scroll:SetScrollChild(content);p.content=content
 scroll:SetScript('OnSizeChanged',function(_,w) content:SetWidth(math.max(580,w)) end)
 text(content,'M+ Ledger  /  '..title,12,-12,22);text(content,description,12,-48,12)
 p:SetScript('OnShow',function() for _,b in ipairs(p.checkButtons) do b:Refresh() end end)
 return p,content
end
-- Hover description for every option (user request 2026-10-08), in place of the extra lines of
-- help text the pages used to carry.
local function tip(f,title,description)
 f:HookScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(title,1,1,1)
  GameTooltip:AddLine(description,nil,nil,nil,true);GameTooltip:Show()
 end)
 f:HookScript('OnLeave',function() GameTooltip:Hide() end)
end
-- x/width let two checkboxes share a row. The hit rect covers the label too, so hovering or
-- clicking the text works as well as the box.
local function check(p,y,label,description,getter,setter,x,width)
 x=x or 12;width=width or 490
 local b=CreateFrame('CheckButton',nil,p.content,'UICheckButtonTemplate');b:SetPoint('TOPLEFT',x,-y);b:SetSize(26,26)
 local l=text(p.content,label,x+34,-y-5,12);l:SetWidth(width)
 b:SetHitRectInsets(0,-width,0,0)
 function b:Refresh() self:SetChecked(getter() and true or false) end
 b:SetScript('OnClick',function(f) setter(f:GetChecked() and true or false);f:Refresh() end)
 tip(b,label,description)
 p.checkButtons[#p.checkButtons+1]=b;return b
end
local function slider(p,y,title,description,min,max,step,getter,setter,suffix)
 local l=text(p.content,title,14,-y,12)
 local s=CreateFrame('Slider',nil,p.content,'OptionsSliderTemplate');s:SetPoint('TOPLEFT',20,-y-28);s:SetSize(470,18);s:SetMinMaxValues(min,max);s:SetValueStep(step);s:SetObeyStepOnDrag(true)
 if s.Low then s.Low:SetText(tostring(min)) end;if s.High then s.High:SetText(tostring(max)) end
 local updating=false
 function s:Refresh() updating=true;self:SetValue(getter());l:SetText(title..'  '..tostring(getter())..(suffix or ''));updating=false end
 s:SetScript('OnValueChanged',function(_,v) if updating then return end;v=math.floor(v/step+.5)*step;setter(v);l:SetText(title..'  '..v..(suffix or '')) end)
 tip(s,title,description)
 p.checkButtons[#p.checkButtons+1]=s;return s
end
-- Labelled Blizzard dropdown of radio choices; options = { {text, value}, ... }.
local function choice(p,y,title,description,options,getter,setter)
 text(p.content,title,14,-y,12)
 local d=CreateFrame('DropdownButton',nil,p.content,'WowStyle1DropdownTemplate');d:SetPoint('TOPLEFT',14,-y-24);d:SetWidth(280)
 d:SetupMenu(function(_,root)
  for _,o in ipairs(options) do root:CreateRadio(o[1],function() return getter()==o[2] end,function() setter(o[2]) end) end
 end)
 function d:Refresh() self:GenerateMenu() end
 tip(d,title,description)
 p.checkButtons[#p.checkButtons+1]=d;return d
end
local function section(c,title,y)
 local line=c:CreateTexture(nil,'ARTWORK');line:SetPoint('TOPLEFT',14,-y-25);line:SetSize(510,1);line:SetColorTexture(.35,.42,.43,.55)
 text(c,title,14,-y,15)
end
local function db() return A.db end
local function tracker() A.db.tracker=A.db.tracker or {};return A.db.tracker end
local function trackerOption(p,y,key,title,description,default,x,width)
 check(p,y,title,description,function() local v=tracker()[key];if v==nil then return default end;return v end,function(v) tracker()[key]=v;A:RefreshTrackerBar() end,x,width)
end
local function dbOption(p,y,key,title,description,default)
 check(p,y,title,description,function() local v=db()[key];if v==nil then return default end;return v end,function(v) db()[key]=v end)
end
local function register(parent,p)
 Settings.RegisterCanvasLayoutSubcategory(parent,p,p.name);A.settingsSubPanels[#A.settingsSubPanels+1]=p
end

-- Removed 2026-10-08 at the user's request: the Colours page (themes set the look now) and the
-- classic/Arcane "Interface style" toggle. Their saved values are left in place.
function A:CreateAssetThemeSettings()
 if self.assetThemePanel or not self.settingsCategory then return end
 local p,c=page('Themes','Choose a finish for your buttons, frames and icons. Changes save automatically.')
 self.assetThemePanel=p;register(self.settingsCategory,p);c:SetHeight(520)
 section(c,'Theme finish',94);p.choices={}
 local palettes={gold={.94,.77,.40},silver={.78,.82,.86},neutral={.76,.73,.63},garnet={.78,.34,.46},midnight={.66,.46,.94},garnetsilver={.83,.85,.88}}
 for i,key in ipairs({'gold','silver','neutral','garnet','midnight','garnetsilver'}) do
  local title=key=='garnetsilver' and 'Garnet + Silver' or key=='midnight' and 'Midnight Violet' or key:sub(1,1):upper()..key:sub(2)
  local b=S.Button(c,title,160,118,function() A:SetAssetTheme(key) end);b:SetPoint('TOPLEFT',14+((i-1)%3)*174,-137-math.floor((i-1)/3)*132)
  b.ledgerNoAutoIcon=true;b.Label:ClearAllPoints();b.Label:SetPoint('TOP',0,-14)
  local icon=b:CreateTexture(nil,'ARTWORK');icon:SetSize(40,40);icon:SetPoint('TOP',0,-40)
  icon:SetTexture('Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\Themes\\'..key..'\\progress.png')
  b.state=S.Label(b,'',11);b.state:SetPoint('BOTTOM',0,12)
  b.previewColor=palettes[key];p.choices[key]=b
  tip(b,title..' theme','Uses the '..title..' finish for buttons, frames and icons across the addon.')
 end
 function p:UpdateSelection()
  for key,b in pairs(self.choices) do
   b.state:SetText((db().assetTheme or 'gold')==key and 'Selected' or 'Choose theme')
   b.Label:SetTextColor(unpack(b.previewColor))
   for index,t in ipairs(b.LedgerSkinTextures or {}) do if index~=5 then t:SetDesaturated(true);t:SetVertexColor(unpack(b.previewColor)) end end
  end
 end
 p:HookScript('OnShow',function() p:UpdateSelection() end)
 section(c,'Dungeon cards',424)
 check(p,467,'Show highest key level','Shows "+N", your highest recorded key, on Mythic+ dungeon cards in All Runs.',function() return db().decorativeKeyBadges~=false end,function(v) db().decorativeKeyBadges=v;A:RefreshAllDisplays() end)
 p:UpdateSelection()
end

-- Condensed 2026-10-08 (user request): 5 pages -> 4. The tracker on/off moved to Tracker, the
-- post-dungeon review to Sharing & reputation, the two debug boxes became one choice, and
-- "Prepare Share text" + "Share destination" became one "When I click Share" choice.
function A:CreateSettingsPanel()
 if self.settingsPanel then return end
 local p,c=page('General','Your runs, players and display preferences. Changes save automatically.');self.settingsPanel=p;self.settingsSubPanels={}
 local open=S.Button(c,'Open ledger',160,32,function() if SettingsPanel then SettingsPanel:Hide() end;A:ToggleWindow() end);open:SetPoint('TOPLEFT',14,-92)
 tip(open,'Open ledger','Closes Settings and opens the M+ Ledger window.')
 check(p,145,'Show minimap button','Shows the M+ Ledger button on your minimap. Click it to open the ledger.',function() return db().minimap.shown end,function(v) db().minimap.shown=v;A:RefreshMinimapButton() end)
 check(p,182,'Track raid runs as well as dungeons','Also records raids as runs. When off, only dungeons are tracked.',function() return db().trackRaids~=false end,function(v) db().trackRaids=v end)
 choice(p,230,'Debug messages','Prints extra messages to chat for troubleshooting. Normal shows key events; Verbose shows everything and is noisy. Leave Off for normal play.',
  {{'Off','off'},{'Normal','normal'},{'Verbose','verbose'}},
  function() return db().fullDebug and 'verbose' or (db().debug and 'normal' or 'off') end,
  function(v) db().debug=v~='off';db().fullDebug=v=='verbose' end)
 text(c,'Your run history and player reputation are kept when you change any setting or theme.',14,-310,11)
 local category=Settings.RegisterCanvasLayoutCategory(p,'M+ Ledger');Settings.RegisterAddOnCategory(category);self.settingsCategory=category

 local tp,tc=page('Tracker','Display, movement and comparisons for your live dungeon tracker.');register(category,tp);tc:SetHeight(800)
 trackerOption(tp,95,'shown','Enable live tracker','Shows the live tracker during runs: timer, splits, enemy forces, deaths and interrupts.',true)
 trackerOption(tp,132,'locked','Lock tracker position','Stops the tracker being moved or resized. The lock icon on the tracker does the same.',false)
 trackerOption(tp,169,'hideIdle','Hide when no run is active','Hides the tracker outside a run instead of showing it idle.',false)
 trackerOption(tp,206,'hideWithMenus','Hide while Blizzard menus are open','Hides the tracker while windows like the Group Finder, character sheet or map are open.',true)
 section(tc,'Show on tracker',250)
 trackerOption(tp,290,'showSplits','Split timing bars','Shows the Travel & pulls and Boss fight bars with your Best and Average marks.',true,12,220)
 trackerOption(tp,290,'showForces','Enemy forces','Shows the enemy forces bar and percentage. Needs split timing bars on.',true,292,220)
 trackerOption(tp,327,'showDeaths','Party deaths','Shows the party\'s total deaths this run.',true,12,220)
 trackerOption(tp,327,'showInterrupts','Interrupts','Shows interrupts your client saw. Some can be missed, so treat it as a minimum.',true,292,220)
 slider(tp,377,'Tracker scale','Size of the tracker.',70,200,5,function() return math.floor((tracker().scale or 1)*100+.5) end,function(v) tracker().scale=v/100;A:RefreshTrackerBar() end,'%')
 slider(tp,457,'Tracker opacity','How see-through the tracker is. Lower is more transparent.',30,100,5,function() return math.floor((tracker().opacity or 1)*100+.5) end,function(v) tracker().opacity=v/100;A:RefreshTrackerBar() end,'%')
 section(tc,'Split comparison',541)
 trackerOption(tp,581,'sameKey','Only compare runs at the same key level','When on, Best and Average only use past runs at this key level. When off, every key level of the dungeon counts.',true)
 -- Opt-in (user request 2026-10-08): off by default. On, the tracker swaps the Best flag for red
 -- target flags and Boss Pacing shows the controls for setting them.
 check(tp,618,'Use custom target flags','Swaps the Best flag on the tracker for your own red target flags, set per boss in Boss Pacing (Travel & pulls and Boss fight). Also shows how far ahead of or behind your targets the run is. Only one flag shows at a time.',
  function() return tracker().useTargets==true end,
  function(v) tracker().useTargets=v;A:RefreshTrackerBar();if A.pacingTabPanel and A.pacingTabPanel:IsVisible() then A:RefreshBossPacingTabContent() end end)
 slider(tp,658,'Past runs to average','How many of your most recent completed runs of this dungeon this season set the Average and Best marks. Lower follows your recent form; higher is steadier.',5,50,5,function() return tracker().lookback or 15 end,function(v) tracker().lookback=v;A.trackerBenchKey=nil;A:RefreshTrackerBar() end)
 local reset=S.Button(tc,'Reset tracker position',220,30,function() local o=tracker();o.point='TOP';o.relativePoint='TOP';o.x=0;o.y=-120;if A.trackerBar then A.trackerBar:ClearAllPoints();A.trackerBar:SetPoint('TOP',UIParent,'TOP',0,-120) end end);reset:SetPoint('TOPLEFT',14,-742)
 tip(reset,'Reset tracker position','Moves the tracker back to the top centre of your screen.')

 local cp=page('Sharing & reputation','Player reputation and what gets shared. No messages are sent by changing a setting.');register(category,cp)
 check(cp,95,'Rate your party after a dungeon','When a run ends, opens Rate Your Party so you can give the other players stars and a note.',function() return db().hidePostDungeonReputation==false end,function(v) db().hidePostDungeonReputation=not v end)
 dbOption(cp,132,'showApplicantAlertPopup','Show the applicant reputation panel','When someone applies to your group, shows their history with you, Mythic+ score and best keys. Closes by itself once your party is full.',true)
 dbOption(cp,169,'hideApplicantsUnlessLeader',"Hide applicant reputation when I'm not the group leader","When you're in someone else's group, the applicant reputation panel stays closed.",false)
 dbOption(cp,206,'broadcastPlayerReports','Report players who join to party / raid chat','When someone joins your group, posts your saved rating and notes about them in party or raid chat, where the whole group sees it.',false)
 dbOption(cp,243,'broadcastPlayerReportsOnApply','Report applicants to party / raid chat','When someone applies, posts your saved rating of them in party or raid chat. When off, only you see it.',false)
 local shareOptions={{'Put it in my chat box','CHATBOX'}}
 for _,value in ipairs({'SAY','YELL','GUILD','OFFICER','GUILD_DISCORD','PARTY','RAID','INSTANCE_CHAT','GENERAL','TRADE','LOCALDEFENSE','SERVICES'}) do
  shareOptions[#shareOptions+1]={'Send to '..A:GetShareTargetOption(value).text,value}
 end
 choice(cp,291,'When I click Share','What a run\'s Share button does: put the text in your chat box to edit and send yourself, or send it straight to a channel.',shareOptions,
  function() return db().shareUseCurrentChat~=false and 'CHATBOX' or (db().shareTarget or 'GUILD') end,
  function(v) if v=='CHATBOX' then db().shareUseCurrentChat=true else db().shareUseCurrentChat=false;db().shareTarget=v end end)
 self:CreateAssetThemeSettings()
end
-- Public naming only; the addon folder name is kept for SavedVariables continuity.
SLASH_MPLUSLEDGER1='/mledger'
SlashCmdList.MPLUSLEDGER=function(input) input=(input or ''):lower():match('^%s*(.-)%s*$');if input=='test' then A:ToggleTestPreview() elseif input=='test off' then A:ToggleTestPreview(true) elseif input=='settings' then A:OpenSettings() elseif input=='setup' then A:ShowWelcome() else A:ToggleWindow() end end
