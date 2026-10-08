-- Shared presentation and Season comparison table. Loaded after Overview.lua.
local addonName, ns = ...
local A, S = MPlusLedger, ns.LedgerSkin
if not A or not S then return end
local gold, ink, muted = {0.78,0.82,0.86}, {0.93,0.92,0.88}, {0.66,0.70,0.73}
local media='Interface\\AddOns\\'..addonName..'\\MPlusLedgerSkin\\Media\\'
local unpack=unpack
local function text(p,t,size,x,y,color)
    local f=S.Label(p,t,size,color or ink); f:SetPoint('TOPLEFT',x,y); return f
end
local function place(f,p,x,y,w,h)
    f:ClearAllPoints(); f:SetPoint('TOPLEFT',p,'TOPLEFT',x,y)
    if w then f:SetWidth(w) end; if h then f:SetHeight(h) end
end
local function skin(f,style)
    if f.SetBackdrop then f:SetBackdrop(nil) end
    if f.LedgerSkinTextures then return end
    S.Apply(f,style or 'Card',7)
    local dark=f:CreateTexture(nil,'BACKGROUND',nil,1)
    dark:SetPoint('TOPLEFT',3,-3); dark:SetPoint('BOTTOMRIGHT',-3,3)
    dark:SetColorTexture(0.025,0.038,0.044,0.95)
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame('Frame',nil,parent); f:SetSize(w,h); f:SetPoint('TOPLEFT',x,y); skin(f); return f
end
local function button(b)
    if not b or b.rethemed then return end
    skin(b,'Button'); b.rethemed=true; b:SetHeight(30)
    if b.text then b.text:SetFont(STANDARD_TEXT_FONT,12,''); b.text:SetTextColor(unpack(gold)) end
    local hover=b:CreateTexture(nil,'HIGHLIGHT')
    hover:SetPoint('TOPLEFT',3,-3); hover:SetPoint('BOTTOMRIGHT',-3,3)
    hover:SetColorTexture(0.78,0.82,0.86,0.10)
end
local function menu(m)
    if not m then return end
    skin(m)
    m:HookScript('OnShow',function(self)
        for _,child in ipairs({self:GetChildren()}) do
            if child:IsObjectType('Button') then button(child); child:SetHeight(24) end
        end
    end)
end
local function heading(p,title,description)
    local art=p:CreateTexture(nil,'BACKGROUND',nil,2)
    art:SetPoint('TOPLEFT',0,0); art:SetSize(1052,32)
    art:SetTexture(media..'BannerArt.png'); art:SetAlpha(0.22)
    text(p,title,23,0,0,gold)
    local note=text(p,description,11,270,-10,muted); note:SetWidth(775)
end
local function chartTheme(p,top)
    local chart=p.chartFrame or (p.scrollFrame and p.scrollFrame:GetParent())
    if not chart then return end
    skin(chart); chart:ClearAllPoints()
    chart:SetPoint('TOPLEFT',p,'TOPLEFT',0,-top); chart:SetPoint('BOTTOMRIGHT',p,'BOTTOMRIGHT',0,24)
    if p.help then
        place(p.help,p,2,-622,1048,26); p.help:SetFont(STANDARD_TEXT_FONT,10,'')
        p.help:SetTextColor(unpack(muted))
    end
end
local function kpis(p,keys)
    local width=(1052-(#keys-1)*10)/#keys
    for i,key in ipairs(keys) do
        local f=p.kpis[key]; skin(f); place(f,p,(i-1)*(width+10),-82,width,64)
        local art=f:CreateTexture(nil,'BACKGROUND',nil,2); art:SetAllPoints(); art:SetTexture(media..'SeasonStat.png')
        place(f.value,f,0,-8,width,28); f.value:SetJustifyH('CENTER')
        place(f.label,f,0,-42,width,18); f.label:SetJustifyH('CENTER')
        f.value:SetFont(STANDARD_TEXT_FONT,key=='bestRun' and 16 or 22,''); f.value:SetTextColor(unpack(gold))
        f.label:SetTextColor(unpack(muted)); f.label:SetFont(STANDARD_TEXT_FONT,11,'')
    end
end
local oldProgress=A.BuildProgressTabContent
function A:BuildProgressTabContent(p)
    oldProgress(self,p)
    heading(p,'Dungeon Progress','Compare your recorded runs, completion times and key levels')
    place(p.dungeonLabel,p,0,-40,280,30); button(p.dungeonLabel)
    button(p.viewButton); button(p.instanceFilterButton); menu(p.dungeonMenu)
    kpis(p,{'runs','completion','avgDeaths','bestRun','deathTimeLost'})
    place(p.stats,p,16,-100,1000,34)
    place(p.legend,p,8,-154,1036,30); p.legend:SetFont(STANDARD_TEXT_FONT,11,'')
    chartTheme(p,190)
end
local oldTrends=A.BuildTrendsTabContent
function A:BuildTrendsTabContent(p)
    oldTrends(self,p)
    heading(p,'Trends','Explore deaths over time, by encounter, or by dungeon section')
    place(p.lookbackButton,p,0,-40,130,30); button(p.lookbackButton)
    button(p.dungeonButton); button(p.viewButton); menu(p.dungeonMenu)
    kpis(p,{'runs','totalDeaths','avgDeaths','deathFree'})
    place(p.legend,p,8,-154,1036,30); p.legend:SetWordWrap(true); p.legend:SetFont(STANDARD_TEXT_FONT,11,'')
    chartTheme(p,190)
    -- Keep the alternative breakdown view in a real panel with the same footprint.
    p.breakdownSurface=panel(p,0,-190,1052,426)
    p.breakdownSurface:SetFrameLevel(math.max(0,p:GetFrameLevel()))
    p.mobBossChart.frame:SetParent(p.breakdownSurface)
    place(p.mobBossChart.frame,p.breakdownSurface,44,-82)
    p.mobBossLegend:SetParent(p.breakdownSurface)
    place(p.mobBossLegend,p.breakdownSurface,185,-90,810,260)
    p.breakdownSurface:Hide()
end
local oldTrendsRefresh=A.RefreshTrendsTabContent
function A:RefreshTrendsTabContent(...)
    oldTrendsRefresh(self,...)
    local p=self.trendsTabPanel
    if p and p.breakdownSurface then
        local mode=self.trendsViewMode or 'perrun'
        local filter=self.db.trendsDungeonFilter
        if mode=='mobboss' then
            p.legend:SetText('Party deaths during boss fights compared with deaths between bosses. Counts use the selected runs.')
        elseif mode=='sections' and filter and filter~='' then
            p.legend:SetText('Top: deaths between bosses. Bottom: deaths during boss fights. Each section uses its own scale; hover for details.')
        else
            p.legend:SetText('Bar height: party deaths. Red label: your deaths. Runs are ordered oldest to newest; hover for details.')
        end
        p.breakdownSurface:SetShown(mode=='mobboss' or (mode=='sections' and (not filter or filter=='')))
    end
end
local oldPacing=A.BuildBossPacingTabContent
function A:BuildBossPacingTabContent(p)
    oldPacing(self,p)
    heading(p,'Boss Pacing','Separate travel and pulls from boss fights; compare average and best times')
    place(p.dungeonButton,p,0,-40,260,30); button(p.dungeonButton)
    button(p.bossButton); menu(p.dungeonMenu); menu(p.bossMenu)
    p.summarySurface=panel(p,0,-82,1052,46)
    -- Parent the summary text to the surface so it renders above its background.
    p.stats:SetParent(p.summarySurface); place(p.stats,p.summarySurface,14,-13,1024,28)
    p.stats:SetFont(STANDARD_TEXT_FONT,13,''); p.stats:SetTextColor(unpack(ink))
    place(p.legend,p,8,-138,1036,30); p.legend:SetWordWrap(true); p.legend:SetFont(STANDARD_TEXT_FONT,11,'')
    chartTheme(p,176)
end

local colors={{0.16,0.68,0.52},{0.88,0.69,0.22},{0.80,0.31,0.34},{0.34,0.39,0.43}}
local function makeBar(p,x,y,w,h)
    local f=CreateFrame('Frame',nil,p); f:SetSize(w,h); f:SetPoint('TOPLEFT',x,y)
    local bg=f:CreateTexture(nil,'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0.14,0.17,0.18,1)
    f.mask=f:CreateMaskTexture(); f.mask:SetAllPoints(f)
    f.mask:SetTexture(media..'RoundedBarMask.png','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
    bg:AddMaskTexture(f.mask)
    f.parts={}
    for i=1,4 do
        local part=f:CreateTexture(nil,'ARTWORK'); part:SetHeight(h); part:SetTexture(media..'BarGradient.png'); part:SetVertexColor(unpack(colors[i])); part:AddMaskTexture(f.mask)
        local count=f:CreateFontString(nil,'OVERLAY'); count:SetFont(STANDARD_TEXT_FONT,11,''); count:SetPoint('CENTER',part,'CENTER')
        count:SetTextColor(i==2 and 0.08 or 1,i==2 and 0.08 or 1,i==2 and 0.08 or 1)
        f.parts[i]={fill=part,count=count}
    end
    function f:Update(values,total)
        local x=0
        for i,part in ipairs(self.parts) do
            local value=values[i] or 0; local width=total>0 and self:GetWidth()*value/total or 0
            part.fill:ClearAllPoints(); part.fill:SetPoint('TOPLEFT',x,0); part.fill:SetWidth(math.max(0.01,width))
            part.fill:SetShown(width>0); part.count:SetText(tostring(value)); part.count:SetShown(width>=20)
            x=x+width
        end
    end
    return f
end
function A:BuildSeasonTabContent(p)
    self.seasonTabPanel=p; p.rows={}; p.kpis={}
    local names={'Runs tracked','Completed','Highest attempted','Highest completed','Avg deaths / run'}
    for i,name in ipairs(names) do
        local f=CreateFrame('Frame',nil,p); place(f,p,(i-1)*212.4,0,202.4,86)
        f.art=f:CreateTexture(nil,'BACKGROUND'); f.art:SetAllPoints(); f.art:SetTexture(media..'SeasonStat.png')
        f.value=text(f,'--',29,0,-10,i==2 and {0.26,0.85,0.64} or gold)
        f.value:SetWidth(202.4); f.value:SetJustifyH('CENTER')
        f.caption=text(f,name,12,0,-48,ink); f.caption:SetWidth(202.4); f.caption:SetJustifyH('CENTER')
        if i==2 then
            f.detail=text(f,'Includes overtime',10,0,-67,muted); f.detail:SetWidth(202.4); f.detail:SetJustifyH('CENTER')
        end
        p.kpis[i]=f
    end
    p.outcomes=panel(p,0,-98,1052,76)
    text(p.outcomes,'Run outcomes',18,16,-17,gold)
    p.totalBar=makeBar(p.outcomes,188,-15,844,20)
    p.legendItems={}
    for i,name in ipairs({'Timed','Overtime','Abandoned'}) do
        local x=200+(i-1)*218
        local dot=p.outcomes:CreateTexture(nil,'ARTWORK'); dot:SetTexture(media..'LegendDot.png')
        dot:SetSize(12,12); dot:SetPoint('TOPLEFT',x,-46); dot:SetVertexColor(unpack(colors[i]))
        p.legendItems[i]={dot=dot,label=text(p.outcomes,name,11,x+19,-45,ink),name=name}
    end
    p.totalLegend=text(p.outcomes,'',10,866,-45,muted)
    p.sort=S.Button(p,'Sort: Most runs',178,28,function()
        local modes={runs='key',key='name',name='runs'}
        A.db.seasonTabSortMode=modes[A.db.seasonTabSortMode or 'runs'] or 'runs'
        A:RefreshSeasonTabContent()
    end); p.sort:SetPoint('TOPRIGHT',0,-185)
    p.table=panel(p,0,-182,1052,433)
    text(p.table,'Dungeon performance',22,14,-10,gold)
    text(p.table,'Tracked runs this season',11,270,-18,muted)
    p.sort:SetParent(p.table); p.sort:ClearAllPoints(); p.sort:SetPoint('TOPRIGHT',-12,-8)
    text(p.table,'Dungeon',12,14,-55,gold); text(p.table,'Runs',12,283,-55,gold)
    text(p.table,'Run outcomes',12,352,-55,ink)
    for i,name in ipairs({'Timed','Overtime','Abandoned'}) do
        local x=495+(i-1)*103
        local dot=p.table:CreateTexture(nil,'ARTWORK'); dot:SetTexture(media..'LegendDot.png')
        dot:SetSize(10,10); dot:SetPoint('TOPLEFT',x,-56); dot:SetVertexColor(unpack(colors[i]))
        text(p.table,name,9,x+15,-55,ink)
    end
    text(p.table,'Highest attempted',12,833,-55,gold)
    p.scroll=CreateFrame('ScrollFrame',nil,p.table); p.scroll:SetPoint('TOPLEFT',6,-81); p.scroll:SetSize(1040,346)
    p.content=CreateFrame('Frame',nil,p.scroll); p.content:SetSize(1040,346); p.scroll:SetScrollChild(p.content)
    p.scroll:EnableMouseWheel(true)
    p.scroll:SetScript('OnMouseWheel',function(f,d)
        f:SetVerticalScroll(math.max(0,math.min(math.max(0,p.content:GetHeight()-346),f:GetVerticalScroll()-d*43)))
    end)
    text(p,'Source: M+ Ledger tracked history   |   Click a dungeon to open Progress   |   Scroll for more rows',10,2,-629,muted)
end
function A:RefreshSeasonTabContent()
    local p=self.seasonTabPanel; if not p then return end
    local d=self:GetSeasonOverviewData(); local mode=self.db.seasonTabSortMode or 'runs'
    p.kpis[1].value:SetText(d.totalRuns)
    p.kpis[2].value:SetText(string.format('%.0f%%',d.completionPct))
    p.kpis[2].detail:SetText(string.format('%d of %d · includes overtime',d.completed or (d.onTime+d.overtime),d.totalRuns))
    p.kpis[3].value:SetText(d.highestKeyRun>0 and '+'..d.highestKeyRun or '--')
    p.kpis[4].value:SetText(d.highestKeyCompleted>0 and '+'..d.highestKeyCompleted or '--')
    p.kpis[5].value:SetText(string.format('%.1f',d.avgDeaths))
    local other=math.max(0,d.totalRuns-d.onTime-d.overtime-d.abandoned)
    p.totalBar:Update({d.onTime,d.overtime,d.abandoned,other},d.totalRuns)
    local counts={d.onTime,d.overtime,d.abandoned}
    for i,item in ipairs(p.legendItems) do
        item.label:SetText(string.format('%s: %d (%.0f%%)',item.name,counts[i],d.totalRuns>0 and counts[i]*100/d.totalRuns or 0))
    end
    p.totalLegend:SetText(other>0 and ('Active / other: '..other) or '')
    p.sort.Label:SetText(({runs='Sort: Most runs',key='Sort: Highest key',name='Sort: A-Z'})[mode] or 'Sort: Most runs')
    table.sort(d.dungeons,function(a,b)
        if mode=='runs' and a.runs~=b.runs then return a.runs>b.runs end
        if mode=='key' and a.highestKey~=b.highestKey then return a.highestKey>b.highestKey end
        return a.name<b.name
    end)
    p.content:SetHeight(math.max(346,#d.dungeons*43))
    p.scroll:SetVerticalScroll(math.min(p.scroll:GetVerticalScroll(),math.max(0,p.content:GetHeight()-346)))
    for i,e in ipairs(d.dungeons) do
        local row=p.rows[i]
        if not row then
            row=CreateFrame('Button',nil,p.content); row:SetSize(1040,43); row:SetPoint('TOPLEFT',0,-(i-1)*43)
            row.icon=row:CreateTexture(nil,'ARTWORK'); row.icon:SetPoint('LEFT',8,0)
            row.name=text(row,'',12,48,-13); row.name:SetWidth(226)
            row.runs=text(row,'',13,281,-13)
            row.bar=makeBar(row,345,-11,455,21)
            row.key=text(row,'',14,865,-13,gold); text(row,'View >',12,976,-13,gold)
            local line=row:CreateTexture(nil,'BACKGROUND'); line:SetHeight(1); line:SetPoint('BOTTOMLEFT'); line:SetPoint('BOTTOMRIGHT'); line:SetColorTexture(0.46,0.38,0.22,0.3)
            local hi=row:CreateTexture(nil,'HIGHLIGHT'); hi:SetAllPoints(); hi:SetColorTexture(0.78,0.82,0.86,0.07)
            row:SetScript('OnClick',function(f) if f.entry then A:OpenProgressForDungeon(f.entry.name) end end)
            row:SetScript('OnEnter',function(f)
                local r=f.entry; if not r then return end
                GameTooltip:SetOwner(f,'ANCHOR_TOP'); GameTooltip:SetText(r.name)
                GameTooltip:AddLine(string.format('Timed %d | Overtime %d | Abandoned %d | Total %d',r.onTime,r.overtime,r.abandoned,r.runs),1,1,1,true)
                GameTooltip:AddLine('Bars show the outcome proportions within each dungeon. Gray = active / other.',0.7,0.7,0.7,true); GameTooltip:Show()
            end)
            row:SetScript('OnLeave',function() GameTooltip:Hide() end); p.rows[i]=row
        end
        row.entry=e; row.name:SetText(e.name); self:SetRowIcon(row,self:GetDungeonIcon(e.name),28,e.name)
        row.runs:SetText(e.runs); row.key:SetText(e.highestKey>0 and '+'..e.highestKey or '--')
        row.bar:Update({e.onTime,e.overtime,e.abandoned,math.max(0,e.runs-e.onTime-e.overtime-e.abandoned)},e.runs)
        row:Show()
    end
    for i=#d.dungeons+1,#p.rows do p.rows[i]:Hide() end
    if self.statsHubWindow then self.statsHubWindow.subtitle:SetText('Season overview - '..tostring(d.seasonLabel)) end
end

-- Keep guidance specific to the visible pacing view and short enough to wrap cleanly.
local previousPacingRefresh=A.RefreshBossPacingTabContent
function A:RefreshBossPacingTabContent(...)
    previousPacingRefresh(self,...)
    local p=self.pacingTabPanel
    if p then
        p.legend:SetText('|cff79d8edTravel / pulls|r: time between bosses.   |cffffbb59Boss fight|r: encounter time.   Gray: older runs without a split.')
        if p.help then p.help:SetText('All Bosses compares averages. Select a boss for individual runs. Hover a bar for timing details; scroll for more runs.') end
    end
end
