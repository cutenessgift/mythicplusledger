-- Presentation-only Overview replacement. Loaded after Core.lua.
local addonName, ns = ...
local media = "Interface\\AddOns\\" .. addonName .. "\\MPlusLedgerSkin\\Media\\"
local Addon, Skin = MPlusLedger, ns.LedgerSkin
if not Addon or not Skin then return end
local dungeonArt = {
    ["Den of Nalorakk"] = "DenOfNalorakk", ["Altar of Fangs"] = "AltarOfFangs",
    ["Kings' Rest"] = "KingsRest", ["Kings\226\128\153 Rest"] = "KingsRest",
    ["Ruby Life Pools"] = "RubyLifePools", ["Voidscar Arena"] = "VoidscarArena",
    ["The Blinding Vale"] = "TheBlindingVale", ["Murder Row"] = "MurderRow",
    ["Temple of Sethraliss"] = "TempleOfSethraliss",
}
-- Stored textures are 2:1 (verified against the actual installed .png files -- 1024x512 each,
-- 2026-10-01; the "3:1" this comment used to claim was the ORIGINAL ChatGPT-generated source
-- resolution before export, not what actually ended up on disk, and was cropping every dungeon
-- card/banner against the wrong aspect ratio as a result). UV cropping restores proportions at
-- every display size rather than stretching, using a true centered crop (no fixed off-center
-- bias) so the same math works regardless of which axis ends up clipped.
local function cropArt(texture, width, height, sourceAspect)
    local aspect = width / height
    if aspect >= sourceAspect then
        local fraction = sourceAspect / aspect
        texture:SetTexCoord(0, 1, (1-fraction)/2, (1+fraction)/2)
    else
        local fraction = aspect / sourceAspect
        texture:SetTexCoord((1-fraction)/2, (1+fraction)/2, 0, 1)
    end
end
local function setDungeonArt(texture, name, width, height)
    local image = Addon:GetLedgerDungeonArtPath(name)
    if image then
        texture:SetTexture(image)
        Addon:CropLedgerDungeonArt(texture,image,width,height)
        texture:Show()
    else texture:Hide() end
end
local gold, white, muted = {0.78,0.82,0.86}, {0.92,0.92,0.88}, {0.66,0.70,0.72}
local function label(parent, text, size, x, y, color)
    local f = Skin.Label(parent, text, size, color or white)
    f:SetPoint('TOPLEFT', x, y)
    return f
end
local function surface(parent, width, height, x, y, style)
    local f = CreateFrame('Frame', nil, parent)
    f:SetSize(width,height); f:SetPoint('TOPLEFT',x,y)
    Skin.Apply(f,style or 'Card',8)
    -- Solid readable center, preserving the generated gold edge.
    local shade = f:CreateTexture(nil,'BACKGROUND',nil,1)
    shade:SetPoint('TOPLEFT',4,-4); shade:SetPoint('BOTTOMRIGHT',-4,4)
    Skin.ThemeBackground(shade,1)
    return f
end
local function tooltip(owner, title, text)
    GameTooltip:SetOwner(owner,'ANCHOR_TOP')
    GameTooltip:SetText(title)
    GameTooltip:AddLine(text,0.85,0.87,0.89,true)
    GameTooltip:Show()
end
local function hideTooltip() GameTooltip:Hide() end
-- Clicking the score / vault cards opens Blizzard's own panels (user request 2026-10-08). Both
-- live in load-on-demand Blizzard addons, so load them first; pcall'd so a renamed frame or API in
-- a future patch just does nothing instead of erroring.
local function loadBlizzard(name)
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,name) elseif LoadAddOn then pcall(LoadAddOn,name) end
end
local function openGreatVault()
    loadBlizzard('Blizzard_WeeklyRewards')
    local f=WeeklyRewardsFrame
    if not f then return end
    if f:IsShown() then HideUIPanel(f) else ShowUIPanel(f);f:Raise() end
end
local function openMythicPlusTab()
    loadBlizzard('Blizzard_ChallengesUI')
    if PVEFrame_ShowFrame then pcall(PVEFrame_ShowFrame,'ChallengesFrame') end
    if PVEFrame then PVEFrame:Raise() end
end
local function clickable(f,onClick,title,hint)
    f:EnableMouse(true)
    f:SetScript('OnMouseUp',function(_,button) if button=='LeftButton' then onClick() end end)
    if title then
        f:SetScript('OnEnter',function(self) tooltip(self,title,hint) end)
        f:SetScript('OnLeave',hideTooltip)
    end
end
-- In-game Mythic+ rating color tiers (White/Green/Blue/Purple/Orange), per user request
-- 2026-10-01 ("could this be coloured to what the player score tier range is"). Mapped onto
-- Blizzard's own ITEM_QUALITY_COLORS table (Common/Uncommon/Rare/Epic/Legendary) so the colors
-- match what players already associate with those tiers, rather than inventing new ones.
local SCORE_TIER_THRESHOLDS = { 480, 960, 1600, 2400 }
local SCORE_TIER_FALLBACK = { {1,1,1}, {0.12,1,0}, {0,0.44,0.87}, {0.64,0.21,0.93}, {1,0.5,0} }
local function scoreTierColor(score)
    score = tonumber(score) or 0
    local quality = 5
    for i, threshold in ipairs(SCORE_TIER_THRESHOLDS) do
        if score < threshold then
            quality = i
            break
        end
    end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then
        return c.r, c.g, c.b
    end
    local fallback = SCORE_TIER_FALLBACK[quality]
    return fallback[1], fallback[2], fallback[3]
end
local function duration(run)
    local start = run.timerStartedAt or run.challengeStartedAt or run.timingStartedAt or run.startedAt
    local seconds = tonumber(run.durationOverride) or (start and run.endedAt and math.max(0,run.endedAt-start)) or tonumber(run.duration) or 0
    return string.format('%d:%02d',math.floor(seconds/60),math.floor(seconds%60))
end

function Addon:BuildMythicPlusStatsTabContent(panel)
    self.mplusTabPanel = panel
    panel.overviewRebuilt = true
    panel.sortMode = 1
    panel.score = surface(panel,310,126,0,0)
    local scoreArt=panel.score:CreateTexture(nil,'BACKGROUND',nil,2)
    scoreArt:SetPoint('TOPLEFT',4,-4); scoreArt:SetPoint('BOTTOMRIGHT',-4,4)
    scoreArt:SetTexture(media..'ScoreOrnaments.png');Skin.ThemeOrnament(scoreArt)
    cropArt(scoreArt,302,118,2) -- ScoreOrnaments.png is 1024x512 (2:1) on disk, not 2.5
    local scoreTitle=label(panel.score,'MYTHIC+ SCORE',14,0,-20,gold)
    scoreTitle:SetWidth(310); scoreTitle:SetJustifyH('CENTER')
    panel.scoreValue=label(panel.score,'--',44,0,-47,gold)
    panel.scoreValue:SetWidth(310); panel.scoreValue:SetJustifyH('CENTER')
    clickable(panel.score,openMythicPlusTab,'Mythic+ Score','Click to open the Mythic+ Dungeons tab.')
    panel.vault=surface(panel,730,126,322,0)
    clickable(panel.vault,openGreatVault,'Weekly Vault','Click to open the Great Vault.')
    local vaultArt=panel.vault:CreateTexture(nil,'BACKGROUND',nil,2)
    vaultArt:SetPoint('TOPLEFT',4,-4);vaultArt:SetPoint('BOTTOMRIGHT',-4,4)
    vaultArt:SetTexture(media..'ScoreOrnaments.png');Skin.ThemeOrnament(vaultArt)
    local chest=panel.vault:CreateTexture(nil,'ARTWORK')
    chest:SetSize(48,48); chest:SetPoint('TOPLEFT',16,-9)
    chest:SetTexture(media..'VaultChestAlpha.png');Skin.ThemeMetal(chest)
    label(panel.vault,'Weekly Vault',22,76,-12,gold)
    panel.vaultHint=label(panel.vault,'Waiting for weekly rewards data',11,76,-40,muted)
    panel.vaultCount=label(panel.vault,'-- / 8 runs',16,578,-17)
    -- One continuous track, below the milestone plaques in draw order.
    panel.vaultRail=panel.vault:CreateTexture(nil,'ARTWORK',nil,-2)
    panel.vaultRail:SetPoint('TOPLEFT',145,-79); panel.vaultRail:SetSize(505,10)
    panel.vaultRail:SetColorTexture(0.26,0.27,0.25,1)
    local railInner=panel.vault:CreateTexture(nil,'ARTWORK',nil,-1)
    railInner:SetPoint('TOPLEFT',146,-81); railInner:SetSize(503,6)
    railInner:SetColorTexture(0.065,0.083,0.09,1)
    panel.vaultFill=panel.vault:CreateTexture(nil,'ARTWORK')
    panel.vaultFill:SetPoint('TOPLEFT',146,-81); panel.vaultFill:SetHeight(6)
    Skin.ThemeAccentTexture(panel.vaultFill); panel.vaultFill:Hide()
    panel.vaultNodes={}
    for i,x in ipairs({145,397.5,650}) do
        local node=CreateFrame('Frame',nil,panel.vault)
        node:SetSize(100,68); node:SetPoint('TOPLEFT',x-50,-58)
        node:EnableMouse(true)
        node.icon=node:CreateTexture(nil,'ARTWORK',nil,2)
        node.icon:SetSize(52,52); node.icon:SetPoint('TOP',0,0)
        node.value=label(node,'--',12,0,-50,white)
        node.value:SetWidth(100); node.value:SetJustifyH('CENTER')
        node:SetScript('OnEnter',function(f) tooltip(f,'Weekly Vault',(f.detailText or 'Waiting for data')..'\n\n|cff9aa3a8Click to open the Great Vault.|r') end)
        node:SetScript('OnMouseUp',function(_,button) if button=='LeftButton' then openGreatVault() end end)
        node:SetScript('OnLeave',hideTooltip)
        panel.vaultNodes[i]=node
    end
    panel.target = surface(panel,1052,68,0,-138,'Feature')
    local bannerArt = panel.target:CreateTexture(nil,'BACKGROUND',nil,2)
    bannerArt:SetPoint('TOPLEFT',4,-4); bannerArt:SetPoint('BOTTOMRIGHT',-4,4)
    bannerArt:SetAlpha(0.85); panel.target.art=bannerArt
    panel.target.icon=panel.target:CreateTexture(nil,'ARTWORK')
    panel.target.icon:SetPoint('TOPLEFT',12,-10); panel.target.icon:SetSize(48,48)
    label(panel.target,'NEXT TARGET',10,74,-10,gold)
    panel.target.name=label(panel.target,'Waiting for dungeon data',19,74,-25)
    panel.target.reason=label(panel.target,'',11,74,-48,muted)
    panel.target.action=Skin.Button(panel.target,'View progress >',146,32,function()
        if panel.target.dungeonName then Addon:OpenProgressForDungeon(panel.target.dungeonName) end
    end)
    panel.target.action:SetPoint('RIGHT',-14,0)
    label(panel,'Season Dungeons',21,0,-220,gold)
    label(panel,'Best timed / run statistics: tracked history',11,218,-227,muted)
    panel.sort=Skin.Button(panel,'Sort: Lowest score',172,28,function()
        panel.sortMode=panel.sortMode%3+1
        Addon:RefreshMythicPlusStatsTabData()
    end)
    panel.sort:SetPoint('TOPRIGHT',0,-215)
    -- Scroll only when the pool exceeds the normal eight dungeons.
    panel.scroll=CreateFrame('ScrollFrame',nil,panel)
    panel.scroll:SetPoint('TOPLEFT',0,-254); panel.scroll:SetSize(1052,294)
    panel.grid=CreateFrame('Frame',nil,panel.scroll)
    panel.grid:SetSize(1052,294); panel.scroll:SetScrollChild(panel.grid)
    panel.scroll:EnableMouseWheel(true)
    panel.scroll:SetScript('OnMouseWheel',function(f,delta)
        local max=math.max(0,panel.grid:GetHeight()-f:GetHeight())
        f:SetVerticalScroll(math.max(0,math.min(max,f:GetVerticalScroll()-delta*52)))
    end)
    panel.empty=label(panel.grid,'Dungeon data is not available yet. Open the Mythic+ window, then return here.',14,16,-24,muted)
    panel.cards={}
    panel.affixes=surface(panel,1052,56,0,-562)
    label(panel.affixes,"This Week's Affixes",15,14,-19,gold)
    panel.affixTiles={}
    for i=1,6 do
        local tile=CreateFrame('Frame',nil,panel.affixes)
        tile:SetSize(112,42); tile:SetPoint('LEFT',184+(i-1)*124,0); tile:EnableMouse(true)
        tile.icon=tile:CreateTexture(nil,'ARTWORK'); tile.icon:SetSize(26,26); tile.icon:SetPoint('LEFT')
        tile.name=label(tile,'',10,32,-8); tile.name:SetWidth(80); tile.name:SetHeight(30)
        tile:SetScript('OnEnter',function(f)
            if f.affix then tooltip(f,f.affix.name,(f.affix.description or '')..'\n'..(f.affix.known and f.affix.known.note or '')) end
        end)
        tile:SetScript('OnLeave',hideTooltip); tile:Hide(); panel.affixTiles[i]=tile
    end
    -- Widened 76 -> 110: Skin.Button clamps its label to (width - 16) with word-wrap off, so
    -- "Details" at the old 76px width always truncated to "Det..." -- per user report 2026-10-01
    -- ("The Details box button for the Weekly Affixes has the same issues as the Remove Button").
    panel.details=Skin.Button(panel.affixes,'Details',110,26,function(button)
        tooltip(button,'This week: addon assessment',panel.assessment or 'Affix information unavailable.')
    end)
    panel.details:SetPoint('RIGHT',-10,0); panel.details:HookScript('OnLeave',hideTooltip)
    panel.footer=label(panel,'Score & vault: Blizzard   |   Run statistics: M+ Ledger tracked history',10,2,-631,muted)
end

-- Green outline marking the best dungeon to run (highest combined on-time %, key level, and
-- fewest deaths/run) -- restored 2026-10-01 per user request, originally built into the old
-- (now-dead) Core.lua card grid. Skin.Apply cards use nine texture regions, not a BackdropTemplate,
-- so SetBackdropBorderColor doesn't apply here -- four thin colored strips laid over the card's
-- edge do the same job.
local function cardBorder(card)
    if card.bestBorder then return card.bestBorder end
    local b={}
    for _,key in ipairs({'top','bottom','left','right'}) do
        local t=card:CreateTexture(nil,'OVERLAY')
        t:SetColorTexture(0.25,0.92,0.38,0.95)
        t:Hide()
        b[key]=t
    end
    b.top:SetPoint('TOPLEFT',3,-3); b.top:SetPoint('TOPRIGHT',-3,-3); b.top:SetHeight(2)
    b.bottom:SetPoint('BOTTOMLEFT',3,3); b.bottom:SetPoint('BOTTOMRIGHT',-3,3); b.bottom:SetHeight(2)
    b.left:SetPoint('TOPLEFT',3,-3); b.left:SetPoint('BOTTOMLEFT',3,3); b.left:SetWidth(2)
    b.right:SetPoint('TOPRIGHT',-3,-3); b.right:SetPoint('BOTTOMRIGHT',-3,3); b.right:SetWidth(2)
    card.bestBorder=b
    return b
end
local function setCardBorderShown(card,shown)
    local b=cardBorder(card)
    b.top:SetShown(shown); b.bottom:SetShown(shown); b.left:SetShown(shown); b.right:SetShown(shown)
end
local function newCard(panel,index)
    local col,row=(index-1)%4,math.floor((index-1)/4)
    local card=CreateFrame('Button',nil,panel.grid)
    card:SetSize(255.5,140); card:SetPoint('TOPLEFT',col*265.5,-row*152)
    Skin.Apply(card,'Card',7)
    local bg=card:CreateTexture(nil,'BACKGROUND',nil,1)
    bg:SetPoint('TOPLEFT',3,-3); bg:SetPoint('BOTTOMRIGHT',-3,3)
    bg:SetColorTexture(0.04,0.052,0.057,0.96)
    card.art=card:CreateTexture(nil,'BACKGROUND',nil,2)
    card.art:SetPoint('TOPLEFT',3,-3); card.art:SetPoint('BOTTOMRIGHT',-3,3)
    card.art:SetAlpha(0.60)
    card.icon=card:CreateTexture(nil,'ARTWORK'); card.icon:SetPoint('TOPLEFT',10,-12)
    cardBorder(card)
    card.name=label(card,'',12,76,-12); card.name:SetWidth(169); card.name:SetHeight(18)
    card.name:SetWordWrap(true)
    card.best=label(card,'',14,76,-34,gold)
    card.score=label(card,'',11,76,-56,white)
    card.bar=Skin.Progress(card,233,6,0); card.bar:SetPoint('TOPLEFT',11,-86)
    card.rate=label(card,'',11,11,-100)
    card.deaths=label(card,'',10,11,-118,muted)
    card.action=label(card,'View progress >',10,157,-118,gold)
    local hover=card:CreateTexture(nil,'HIGHLIGHT')
    hover:SetPoint('TOPLEFT',3,-3); hover:SetPoint('BOTTOMRIGHT',-3,3)
    hover:SetColorTexture(0.78,0.82,0.86,0.08)
    card:SetScript('OnClick',function(f) if f.entry then Addon:OpenProgressForDungeon(f.entry.name) end end)
    card:SetScript('OnEnter',function(f)
        if f.tooltip then tooltip(f,f.entry.name,f.tooltip) end
    end)
    card:SetScript('OnLeave',hideTooltip)
    panel.cards[index]=card
    return card
end

function Addon:RefreshMythicPlusStatsTabData()
    local p=self.mplusTabPanel
    if not p or not p.overviewRebuilt then return end
    local score=self:GetOverallMythicPlusScore()
    p.scoreValue:SetText(score and (BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(score+0.5)) or string.format('%.0f',score)) or '--')
    p.scoreValue:SetTextColor(scoreTierColor(score))
    local activities=self:GetWeeklyVaultMythicPlusActivities()
    local progress,nextThreshold,maxThreshold=0,nil,8
    for i=1,3 do
        local a,node=activities[i],p.vaultNodes[i]
        local threshold=a and a.threshold or ({1,4,8})[i]
        threshold=threshold and threshold>0 and threshold or ({1,4,8})[i]
        local count=a and a.progress or 0
        progress=math.max(progress,count); maxThreshold=math.max(maxThreshold,threshold)
        local unlocked=a and count>=threshold
        if a and not unlocked and not nextThreshold then nextThreshold=threshold end
        node.icon:SetTexture(media..(unlocked and 'VaultOpenAlpha.png' or 'VaultLockAlpha.png'));Skin.ThemeMetal(node.icon)
        node.value:SetText(threshold..(threshold==1 and ' run' or ' runs'))
        node.detailText=not a and 'Waiting for data' or (unlocked and ((a.level or 0)>0 and ('Reward at +'..a.level) or 'Reward unlocked') or ('Locked - '..count..'/'..threshold))

    end
    local t1=activities[1] and activities[1].threshold or 1
    local t2=activities[2] and activities[2].threshold or 4
    local t3=activities[3] and activities[3].threshold or 8
    local fill=0
    if progress>t1 then
        if progress<t2 then fill=0.5*(progress-t1)/math.max(1,t2-t1)
        else fill=0.5+0.5*(progress-t2)/math.max(1,t3-t2) end
    end
    fill=math.max(0,math.min(1,fill))
    p.vaultFill:SetWidth(math.max(0.01,503*fill))
    p.vaultFill:SetShown(#activities>0 and fill>0)
    p.vaultCount:SetText(#activities>0 and (progress..' / '..maxThreshold..' runs') or '-- / 8 runs')
    p.vaultHint:SetText(#activities==0 and 'Vault data unavailable - open Weekly Rewards once.' or
        (progress==0 and 'Complete 1 dungeon to unlock your first reward.' or (nextThreshold and ('Complete '..math.max(0,nextThreshold-progress)..' more dungeon(s) for your next reward.') or 'All three reward slots unlocked.')))
    local affixes=self:GetCurrentMythicPlusAffixes()
    for i,tile in ipairs(p.affixTiles) do
        tile.affix=affixes[i]
        if tile.affix then tile.icon:SetTexture(tile.affix.icon); tile.name:SetText(tile.affix.name); tile:Show() else tile:Hide() end
    end
    local verdict,reasons=self:GetMythicPlusWeekAssessment(affixes)
    p.assessment=#affixes==0 and 'Affix data is not available yet.' or ((verdict or '')..'\nMPlusLedger assessment; not an official difficulty rating.\n\n'..table.concat(reasons or {},'\n'))
    local entries=self:GetMythicPlusPoolEntries()
    local target
    for _,e in ipairs(entries) do
        e.summary=self:GetDungeonSummary(e.name)
        e.live=self:GetLiveSeasonBestForMap(e.challengeMapID)
        e.score=e.live and e.live.overallScore
        local s=e.summary
        -- completed includes overtime in GetDungeonSummary: do not double-count it.
        e.timed=math.max(0,(s.completed or 0)-(s.completedOvertime or 0))
        e.total=(s.completed or 0)+(s.abandoned or 0)
        e.rate=e.total>0 and e.timed/e.total or 0
        e.best=s.bestRun and self:GetRunKeyLevel(s.bestRun)>0 and s.bestRun or nil
        if not target or (not e.best and target.best) or
            ((not e.best)==(not target.best) and ((e.score or math.huge)<(target.score or math.huge))) then target=e end
    end
    -- Best dungeon to run: highest combined on-time %, key level, and fewest deaths/run, among
    -- dungeons with at least one completed run -- each metric normalized relative to the other
    -- candidates (there's no fixed universal "good" key level or deaths/run, only relative).
    local bestName
    do
        local candidates={}
        for _,e in ipairs(entries) do
            local s=e.summary
            if e.total>0 and s.runs>0 then
                e.deathsPerRun=s.partyDeaths/s.runs
                e.keyLevelForBest=e.best and self:GetRunKeyLevel(e.best) or 0
                candidates[#candidates+1]=e
            end
        end
        if #candidates>0 then
            local minKey,maxKey=candidates[1].keyLevelForBest,candidates[1].keyLevelForBest
            local minDeaths,maxDeaths=candidates[1].deathsPerRun,candidates[1].deathsPerRun
            for _,c in ipairs(candidates) do
                minKey=math.min(minKey,c.keyLevelForBest); maxKey=math.max(maxKey,c.keyLevelForBest)
                minDeaths=math.min(minDeaths,c.deathsPerRun); maxDeaths=math.max(maxDeaths,c.deathsPerRun)
            end
            local bestScore=-1
            for _,c in ipairs(candidates) do
                local onTimeScore=c.rate
                local keyScore=(maxKey>minKey) and ((c.keyLevelForBest-minKey)/(maxKey-minKey)) or 1
                -- Fewer deaths is better, so this is inverted; equal deaths/run across every
                -- candidate scores full marks here rather than an undefined 0/0.
                local deathScore=(maxDeaths>minDeaths) and (1-((c.deathsPerRun-minDeaths)/(maxDeaths-minDeaths))) or 1
                local score=(onTimeScore+keyScore+deathScore)/3
                if score>bestScore then bestScore=score; bestName=c.name end
            end
        end
    end
    table.sort(entries,function(a,b)
        if p.sortMode==1 then
            if (a.score or math.huge)~=(b.score or math.huge) then return (a.score or math.huge)<(b.score or math.huge) end
        elseif p.sortMode==3 and a.rate~=b.rate then return a.rate>b.rate end
        return a.name<b.name
    end)
    p.sort.Label:SetText(({'Sort: Lowest score','Sort: Dungeon name','Sort: Timed rate'})[p.sortMode])
    p.grid:SetHeight(math.max(294,math.ceil(#entries/4)*152-12))
    p.scroll:SetVerticalScroll(math.min(p.scroll:GetVerticalScroll(),math.max(0,p.grid:GetHeight()-294)))
    p.empty:SetShown(#entries==0)
    for i,e in ipairs(entries) do
        local card=p.cards[i] or newCard(p,i)
        card.entry=e
        setDungeonArt(card.art,e.name,249.5,134)
        self:SetRowIcon(card,self:GetDungeonIcon(e.name),56,e.name)
        card.name:SetText(e.name)
        card.best:SetText(e.best and ('+'..self:GetRunKeyLevel(e.best)..' · '..duration(e.best)) or 'No timed run yet')
        card.score:SetText(e.score and string.format('Season score |cfff0c259%.0f|r',e.score) or 'Season score unavailable')
        card.bar:SetValue(e.rate)
        card.rate:SetText(e.total>0 and string.format('Timed runs: %d%% (%d/%d)',math.floor(e.rate*100+0.5),e.timed,e.total) or 'No finished keys recorded')
        local s=e.summary
        card.deaths:SetText(s.runs>0 and string.format('%.1f deaths/run',s.partyDeaths/s.runs) or 'No tracked runs')
        card.tooltip='Best timed and run statistics use your tracked history, across seasons.\nSeason score comes from Blizzard.\nDeaths average includes all tracked runs for this dungeon.\nClick to open Progress.'
        if e.live and e.live.bestLevel then card.tooltip=card.tooltip..'\nBlizzard season best: +'..e.live.bestLevel..(e.live.bestOverTime and ' (overtime)' or '') end
        local isBest=bestName~=nil and e.name==bestName
        setCardBorderShown(card,isBest)
        if isBest then card.tooltip=card.tooltip..'\n|cff40eb61Best dungeon to run right now|r -- highest on-time %, key level, and fewest deaths/run.' end
        card:Show()
    end
    for i=#entries+1,#p.cards do p.cards[i]:Hide() end
    p.target.dungeonName=target and target.name
    if target then
        setDungeonArt(p.target.art,target.name,1044,60)
        self:SetRowIcon(p.target,self:GetDungeonIcon(target.name),48,target.name)
        p.target.icon:Show(); p.target.name:SetText(target.name)
        p.target.reason:SetText(not target.best and 'No timed Mythic+ completion in tracked history' or (target.score and 'Lowest available season score - a place to improve' or 'Build your tracked history for this dungeon'))
        p.target.action:Enable()
    else
        p.target.art:Hide(); p.target.icon:Hide(); p.target.name:SetText('No dungeon data available')
        p.target.reason:SetText('Open the Mythic+ window, then return to Overview.'); p.target.action:Disable()
    end
    if self.statsHubWindow then self.statsHubWindow.subtitle:SetText('Your Mythic+ overview') end
end
