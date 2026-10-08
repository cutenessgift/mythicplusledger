-- Navigation and bounded chart pages; summaries still cover the full filter.
local _,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
function A:GetLedgerChartPage(kind,points,size,panel)
 local key=kind=='progress' and tostring(self.progressDungeonName)..':'..tostring(self.progressSeasonFilterMode) or tostring(self.db.trendsDungeonFilter)..':'..tostring(self.db.trendsLookback)
 local state=panel.ledgerPages
 if not state then
  state={page=1};panel.ledgerPages=state
  local f=CreateFrame('Frame',nil,panel);f:SetPoint('TOPRIGHT',0,-40);f:SetSize(310,28);state.frame=f
  state.text=S.Label(f,'',11);state.text:SetPoint('CENTER');state.text:SetWidth(235);state.text:SetJustifyH('CENTER')
  local function move(delta)
   state.page=math.max(1,math.min(state.pages,state.page+delta))
   if kind=='progress' then A:RefreshProgressTabContent() else A:RefreshTrendsTabContent() end
  end
  state.prev=S.Button(f,'<',28,26,function() move(-1) end);state.prev:SetPoint('LEFT')
  state.next=S.Button(f,'>',28,26,function() move(1) end);state.next:SetPoint('RIGHT')
 end
 if state.key~=key then state.key=key;state.page=1 end
 state.pages=math.max(1,math.ceil(#points/size));state.page=math.min(state.pages,state.page)
 local first=(state.page-1)*size+1;local last=math.min(#points,first+size-1);local page={}
 for i=first,last do page[#page+1]=points[i] end
 state.text:SetText(string.format('%d–%d of %d runs',#points>0 and first or 0,last,#points))
 state.prev:SetEnabled(state.page>1);state.next:SetEnabled(state.page<state.pages);state.frame:SetShown(#points>size)
 panel.ledgerPagePoints=page
 return page
end
for _,method in ipairs({'RenderProgressDurationView','RenderProgressBossSplitsView'}) do
 local old=A[method]
 A[method]=function(self,p,runs,...)
  return old(self,p,self:GetLedgerChartPage('progress',runs,25,p),...)
 end
end
local oldTrends=A.RefreshTrendsTabContent
function A:RefreshTrendsTabContent(...)
 oldTrends(self,...)
 local p=self.trendsTabPanel
 if p and p.ledgerPages and (self.trendsViewMode or 'perrun')~='perrun' then p.ledgerPages.frame:Hide() end
 local filter=self.db.trendsLookback or 25
 local dungeon=self.db.trendsDungeonFilter;if dungeon=='' then dungeon=nil end
 local d=self:GetTrendData(filter,dungeon)
 if self.statsHubWindow then self.statsHubWindow.subtitle:SetText(string.format('Trends · %d matching runs · %s',#d.points,filter>=999999 and 'All runs' or ('Last '..filter))) end
end
local function notice(message)
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffcf70M+ Ledger:|r '..message) end
end
function A:OpenAllRunsWindow()
 if self:IsUiLocked() then
  self.pendingAllRunsOpen=true;self:MarkUiDirty()
  notice('All Runs will open when combat ends.')
  return
 end
 self.pendingAllRunsOpen=nil
 local switching=self.ledgerSwitchingWindows;self.ledgerSwitchingWindows=true
 local ok,err=pcall(function()
  self:CreateWindow()
  assert(self.window,'All Runs window was not created')
  self.selectedDungeonName=nil;self.window.listOffset=0
  self.window.returnToStatsHub=self.statsHubWindow
  -- Show the destination before refreshing so a render failure cannot look like an ignored click.
  self:BringWindowToFront(self.window)
  self:RefreshWindow()
 end)
 self.ledgerSwitchingWindows=switching
 if not ok then
  self.lastAllRunsOpenError=tostring(err)
  notice('All Runs could not finish opening: '..tostring(err))
  if geterrorhandler then geterrorhandler()(err) end
 else self.lastAllRunsOpenError=nil end
end
local oldFlush=A.FlushDeferredUi
function A:FlushDeferredUi(...)
 if not self:IsUiLocked() and self.pendingAllRunsOpen then self:OpenAllRunsWindow() end
 return oldFlush(self,...)
end
local oldCreate=A.CreateStatsHubWindow
function A:CreateStatsHubWindow(...)
 oldCreate(self,...)
 local f=self.statsHubWindow
 if f and f.viewAllRunsButton then
  local b=f.viewAllRunsButton
  b:EnableMouse(true);b:Enable();b:RegisterForClicks('LeftButtonUp')
  b:SetFrameLevel(f:GetFrameLevel()+100)
  b:SetScript('OnClick',function() A:OpenAllRunsWindow() end)
 end
end
local oldAdd=A.OpenAddPlayerForm
function A:OpenAddPlayerForm(...)
 local origin=self.playerHistoryWindow and self.playerHistoryWindow:IsShown() and self.playerHistoryWindow or self.window
 oldAdd(self,...)
 local f=self.addPlayerWindow
 if f then
  f.ledgerReturnWindow=origin
  if not f.ledgerReturnHook then
   f.ledgerReturnHook=true
   f:HookScript('OnHide',function(w)
    if A.ledgerSwitchingWindows then return end
    local target=w.ledgerReturnWindow;w.ledgerReturnWindow=nil
    if target then A:BringWindowToFront(target) end
   end)
  end
 end
end
