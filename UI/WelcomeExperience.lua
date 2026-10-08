-- First-run welcome and one-click setup (user request 2026-10-08). A fresh install has no
-- Adventure Guide catalog (expansions, bosses, raid list, dungeon versions) until /dl catalog has
-- been run, which a new player would never know to do. This shows once per login until setup is
-- done; anyone who already has a catalog is marked done without seeing it. /mledger setup reopens it.
local _,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local white,muted={1,1,1},{.72,.76,.78}

local function hasCatalog(db)
 return db and db.iconDumps and db.iconDumps.encounterJournal and #db.iconDumps.encounterJournal>0
end

local function create()
 local f=CreateFrame('Frame',nil,UIParent);f:SetSize(440,286);f:SetPoint('CENTER',0,80)
 f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',f.StartMoving);f:SetScript('OnDragStop',f.StopMovingOrSizing);S.Apply(f,'Window',12)
 local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-4,-4)
 f.title=S.Label(f,'Welcome to M+ Ledger',18,white);f.title:SetPoint('TOPLEFT',20,-18)
 f.body=S.Label(f,'',12,white);f.body:SetPoint('TOPLEFT',20,-52);f.body:SetWidth(400);f.body:SetJustifyH('LEFT');f.body:SetJustifyV('TOP');f.body:SetWordWrap(true)
 f.note=S.Label(f,'',10,muted);f.note:SetPoint('BOTTOMLEFT',20,58);f.note:SetWidth(400);f.note:SetJustifyH('LEFT');f.note:SetWordWrap(true)
 f.primary=S.Button(f,'',170,32);f.primary:SetPoint('BOTTOMRIGHT',-20,16)
 f.secondary=S.Button(f,'',110,32);f.secondary:SetPoint('RIGHT',f.primary,'LEFT',-10,0)
 return f
end

local function setButton(b,text,onClick) b.Label:SetText(text);b:SetScript('OnClick',onClick);b:Show() end

local function showDone(f)
 f.title:SetText('M+ Ledger is ready')
 f.body:SetText('Setup is complete. Your runs, deaths, repairs and Mythic+ progress are recorded automatically from now on.\n\nOpen the ledger with the minimap button or /mledger. Use /mledger test to preview the live tracker and applicant panels.')
 f.note:SetText('Settings: Esc > Options > AddOns > M+ Ledger.')
 setButton(f.primary,'Open M+ Ledger',function() f:Hide();A:ToggleWindow() end)
 setButton(f.secondary,'Close',function() f:Hide() end)
end

local function runSetup(f)
 if InCombatLockdown() then
  f.note:SetText('|cffff6b6bSetup can\'t run in combat. Try again once combat ends.|r');return
 end
 local ok,err=pcall(A.BuildExpansionCatalog,A)
 A.journalVersionCache=nil;A.ledgerJournalCatalogue=nil
 if not ok or not hasCatalog(A.db) then
  f.note:SetText('|cffff6b6bSetup didn\'t finish'..(err and (': '..tostring(err)) or '')..'. Try again, or type /dl catalog.|r');return
 end
 A.db.setupComplete=true
 if A.RefreshAllDisplays then pcall(A.RefreshAllDisplays,A) end
 showDone(f)
end

function A:ShowWelcome()
 self.welcomeFrame=self.welcomeFrame or create()
 local f=self.welcomeFrame
 f.title:SetText('Welcome to M+ Ledger')
 f.body:SetText('M+ Ledger records your Mythic+ and dungeon runs: timers and splits, party deaths, repairs, and your own reputation notes on the players you group with.\n\nOne quick setup step reads the in-game Adventure Guide so every dungeon, boss and expansion is sorted correctly. It takes a moment and only needs doing once.')
 f.note:SetText('You can run it again any time with /mledger setup.')
 setButton(f.primary,'Run setup',function() runSetup(f) end)
 setButton(f.secondary,'Later',function() f:Hide() end)
 f:Show();f:Raise()
end

local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent',function()
 -- Short delay so the welcome doesn't compete with the login screen fade and other addons.
 C_Timer.After(4,function()
  local db=A.db;if not db or db.setupComplete then return end
  if hasCatalog(db) then db.setupComplete=true;return end
  A:ShowWelcome()
 end)
end)
