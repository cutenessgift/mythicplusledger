-- Final chart presentation pass; existing query/filter and tooltip behavior retained.
local addonName,ns=...
local A,S=MPlusLedger,ns.LedgerSkin
if not A or not S then return end
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local function label(p,t,x,y,w,size)
 local f=S.Label(p,t,size or 12);f:SetPoint('TOPLEFT',x,y);f:SetWidth(w);return f
end
local function decorateProgress(p)
 if p.ledgerPages and p.stats:IsShown() then p.ledgerPages.frame:Hide() end
 if not p.keyStrip then
  p.keyStrip=p.scrollContent:CreateTexture(nil,'BACKGROUND',nil,1)
  p.keyStrip:SetPoint('BOTTOMLEFT',0,44);p.keyStrip:SetPoint('BOTTOMRIGHT',0,44);p.keyStrip:SetHeight(48);p.keyStrip:SetColorTexture(.26,.13,.36,.18)
 end
 p.keyStrip:SetShown(not p.stats:IsShown())
end
local oldProgress=A.RefreshProgressTabContent
function A:RefreshProgressTabContent(...)
 oldProgress(self,...)
 local p=self.progressTabPanel;if not p then return end
 decorateProgress(p)
 if p.ledgerPages and p.stats:IsShown() then p.ledgerPages.frame:Hide() end
 p.scatterXLabel:SetText('Run date  ·  Bottom strip: key level  ·  D: party deaths')
 if self.progressChartView~='bosssplits' and not p.stats:IsShown() then
  p.legend:SetText('|cff4dc49aCompleted|r   |cffe5b64cOvertime|r   |cffdc666bAbandoned|r   |cffdc8ff5Bottom strip: key level|r   White outline: best run')
  for _,col in ipairs(p.columns) do
   if col.run then
    local status=self:GetRunStatus(col.run);local c=status=='Completed' and {.20,.68,.51} or status=='CompletedOvertime' and {.90,.68,.25} or {.80,.32,.35}
    col.bar:SetTexture(media..'BarGradient.png');col.bar:SetVertexColor(unpack(c))
   end
  end
 end
end
local oldTrends=A.RefreshTrendsTabContent
function A:RefreshTrendsTabContent(...)
 oldTrends(self,...)
 local p=self.trendsTabPanel;if not p then return end
 local mode=self.trendsViewMode or 'perrun';local dungeon=self.db.trendsDungeonFilter
 if dungeon=='' then dungeon=nil end
 -- The section renderer uses two fixed zones; restore their full clipping area.
 if mode=='sections' then p.scrollContent:SetHeight(406) end
 local selected=self:GetTrendData(self.db.trendsLookback or 25,dungeon)
 local limit=self.db.trendsLookback or 25;local n=#selected.points
 local scope=dungeon or 'All dungeons'
 local selection=limit>=999999 and string.format('All %d matching runs',n)
  or (n<limit and string.format('Only %d matching runs available · up to %d requested',n,limit)
  or string.format('Latest %d matching runs',n))
 p.help:SetText(scope..' · '..selection..'. Oldest to newest; hover for details.')
 local breakdownView=mode=='mobboss' or (mode=='sections' and not dungeon)
 if p.deathGrid then for _,g in ipairs(p.deathGrid) do g.line:Hide();g.tick:Hide() end end
 if not p.detailCards then
  p.detailCards={}
  for i,title in ipairs({'Between bosses','During boss fights'}) do
   local card=CreateFrame('Frame',nil,p.breakdownSurface);card:SetSize(480,132);card:SetPoint('TOPLEFT',540,-60-(i-1)*155);S.Apply(card,'Card',8)
   card.title=label(card,title,22,-18,430,19)
   card.value=label(card,'',22,-51,430,29);card.value:SetTextColor(i==1 and .47 or .95,i==1 and .84 or .70,i==1 and .93 or .32)
   card.detail=label(card,'',22,-96,430,11);p.detailCards[i]=card
  end
 end
 for _,card in ipairs(p.detailCards) do card:SetShown(breakdownView) end
 if breakdownView then
  -- Larger pie (radius 110, set in Core.lua) centred in the left half of the panel, legend
  -- centred underneath -- user request 2026-10-04 ("too small please centre it").
  p.mobBossChart.frame:ClearAllPoints();p.mobBossChart.frame:SetPoint('TOP',p.breakdownSurface,'TOPLEFT',257,-40)
  p.mobBossLegend:ClearAllPoints();p.mobBossLegend:SetPoint('TOP',p.mobBossChart.frame,'BOTTOM',0,-14);p.mobBossLegend:SetWidth(440);p.mobBossLegend:SetHeight(80);p.mobBossLegend:SetJustifyH('CENTER')
  local d=self:GetTrendDeathBreakdown(self.db.trendsLookback or 25,dungeon);local total=d.mobDeaths+d.bossDeaths
  for i,card in ipairs(p.detailCards) do
   local value=i==1 and d.mobDeaths or d.bossDeaths
   card.value:SetText(string.format('%d deaths  ·  %.0f%%',value,total>0 and value*100/total or 0))
   card.detail:SetText(i==1 and 'Deaths during travel and trash pulls.' or 'Deaths recorded while a boss fight was active.')
  end
 elseif mode=='perrun' then
  local d=selected
  -- Use the actual viewport, with room for date labels and tallest-bar labels.
  local height=p.scrollFrame:GetHeight()
  if not height or height<100 then height=406 end
  p.scrollContent:SetHeight(height)
  local plotHeight=math.max(1,height-68)
  if not p.deathGrid then
   p.deathGrid={}
   for i=1,4 do
    local line=p.scrollContent:CreateTexture(nil,'BACKGROUND');line:SetHeight(1);line:SetColorTexture(.6,.66,.68,.18)
    local tick=p.scrollFrame:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
    p.deathGrid[i]={line=line,tick=tick}
   end
  end
  local maximum=1;for _,point in ipairs(d.points) do maximum=math.max(maximum,point.partyDeaths) end
  local count=math.min(4,maximum)
  if #d.points>0 then for i=1,count do
   local g=p.deathGrid[i];local value=math.ceil(maximum*i/count);local y=40+plotHeight*value/maximum
   g.line:ClearAllPoints();g.line:SetPoint('BOTTOMLEFT',p.scrollContent,'BOTTOMLEFT',0,y);g.line:SetPoint('BOTTOMRIGHT',p.scrollContent,'BOTTOMRIGHT',0,y)
   g.tick:ClearAllPoints();g.tick:SetPoint('BOTTOMLEFT',p.scrollFrame,'BOTTOMLEFT',2,y+2);g.tick:SetText(tostring(value))
   g.line:Show();g.tick:Show()
  end end

  for i,col in ipairs(p.columns) do
   local point=(p.ledgerPagePoints or d.points)[i]
   if point then
    col:SetHeight(height)
    col.bar:SetHeight(math.max(2,plotHeight*point.partyDeaths/maximum))
    col.yourDeathsLabel:SetText(tostring(point.partyDeaths));col.yourDeathsLabel:SetTextColor(.93,.92,.88)
    col.bar:SetTexture(media..'BarGradient.png');col.bar:SetVertexColor(.78,.32,.37)
    if point.partyDeaths==0 then col.bar:SetVertexColor(.25,.72,.55) end
   end
  end
  p.legend:SetText(selection..'\nBar height and labels: party deaths. Hover for your deaths and run details.')
 end
end
