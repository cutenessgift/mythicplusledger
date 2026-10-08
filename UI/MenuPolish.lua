-- Shared presentation for the remaining ledger windows. No saved run data is changed here.
local _, ns = ...
local A, S = MPlusLedger, ns.LedgerSkin
if not A or not S then return end
local gold=S.colors.gold
local function button(b)
    if b.menuPolish then return end
    b.menuPolish=true
    -- The original red backdrop covers the new nine-slice texture in the game client.
    if b.SetBackdrop then b:SetBackdrop(nil) end
    -- Keep the original backdrop available for selected/status colors beneath the gold border.
    if not b.LedgerSkinTextures then S.Apply(b,'Button',5) end
    local label=b.text or b.Label
    if label then
        label:SetTextColor(1,1,1)
        label:SetWidth(math.max(12,b:GetWidth()-12)); label:SetWordWrap(false)
        local value=label:GetText() or ''
        if value=='X' or value:find('Delete',1,true) or value:find('Clear ',1,true) then
            local red=b:CreateTexture(nil,'BACKGROUND',nil,2)
            red:SetPoint('TOPLEFT',4,-4); red:SetPoint('BOTTOMRIGHT',-4,4)
            red:SetColorTexture(0.43,0.035,0.04,0.95)
        end
    end
    local hi=b:CreateTexture(nil,'HIGHLIGHT')
    hi:SetPoint('TOPLEFT',4,-4); hi:SetPoint('BOTTOMRIGHT',-4,4)
    hi:SetColorTexture(0.78,0.82,0.86,0.12)
    b:HookScript('OnDisable',function(self) if label then label:SetAlpha(0.4) end end)
    b:HookScript('OnEnable',function(self) if label then label:SetAlpha(1) end end)
end
local function input(b)
    if b.menuPolish then return end
    b.menuPolish=true
    for _,region in ipairs({b:GetRegions()}) do
        if region:IsObjectType('Texture') then region:Hide() end
    end
    -- A crisp 1px outline in the theme accent and no fill of its own -- per user request
    -- 2026-10-04: the old 4px Card skin was too thin to read as a field border, and its dark fill
    -- made every input look like a hole cut in the panel. Brightens while the field has focus.
    local outline={}
    for i=1,4 do outline[i]=b:CreateTexture(nil,'BORDER');S.ThemeAccentTexture(outline[i]);outline[i]:SetAlpha(0.55) end
    outline[1]:SetPoint('TOPLEFT');outline[1]:SetPoint('TOPRIGHT');outline[1]:SetHeight(1)
    outline[2]:SetPoint('BOTTOMLEFT');outline[2]:SetPoint('BOTTOMRIGHT');outline[2]:SetHeight(1)
    outline[3]:SetPoint('TOPLEFT');outline[3]:SetPoint('BOTTOMLEFT');outline[3]:SetWidth(1)
    outline[4]:SetPoint('TOPRIGHT');outline[4]:SetPoint('BOTTOMRIGHT');outline[4]:SetWidth(1)
    b.ledgerOutline=outline
    b:SetTextInsets(9,9,0,0)
    b:SetTextColor(1,1,1)
    b:HookScript('OnEditFocusGained',function() for _,t in ipairs(outline) do t:SetAlpha(1) end end)
    b:HookScript('OnEditFocusLost',function() for _,t in ipairs(outline) do t:SetAlpha(0.55) end end)
end
local function surface(f)
    if f.SetBackdrop and f.GetBackdrop and f:GetBackdrop() then
        S.ThemeBackdrop(f,.97)
        f:SetBackdropBorderColor(A:GetThemeBorderColor(false,0.85))
    end
end
-- seen: per-top-level-call visited set, keyed by frame identity -- per live error report
-- 2026-10-01 ("stack overflow" from this exact function, 4 times, triggered by
-- RefreshPlayerHistoryWindow). The depth>6 cap alone should make deep-but-acyclic recursion here
-- impossible to overflow the Lua stack with (Player Reputation's own widget tree never nests more
-- than 3-4 levels), so a real overflow means some frame's :GetChildren() chain cycles back to one
-- of its own ancestors (e.g. from a :SetParent() elsewhere in these files reparenting something
-- into its own descendant) -- walk() would then recurse the SAME subtree forever regardless of
-- the depth counter, since depth only measures how far down THIS call chain has gone, not whether
-- it's revisiting the same frames. Tracking visited frames makes a cycle terminate immediately
-- (second visit is a no-op) instead of recursing until the stack gives out, regardless of what's
-- actually causing the cycle.
local function walk(f,depth,seen)
    if not f or depth>6 then return end
    seen = seen or {}
    if seen[f] then return end
    seen[f] = true
    if f:IsObjectType('EditBox') then input(f)
    elseif f:IsObjectType('Button') and (f.text or f.Label) then button(f)
    else surface(f) end
    for _,r in ipairs({f:GetRegions()}) do
        if r:IsObjectType('FontString') and not r.menuPolish then
            r.menuPolish=true
            local red,green,blue=r:GetTextColor()
            if math.abs(red-green)<0.05 and math.abs(green-blue)<0.05 and red<0.7 then
                r:SetTextColor(0.72,0.76,0.78)
            -- Blizzard's yellow heading font (GameFontNormal*) -> white headings in every theme.
            elseif red>0.9 and green>0.85 and blue<0.2 then r:SetTextColor(1,1,1) end
        end
    end
    for _,child in ipairs({f:GetChildren()}) do
        if child:IsShown() then walk(child,depth+1,seen) end
    end
end
local function window(f)
    if not f then return end
    if not f.menuWindowPolish then
        f.menuWindowPolish=true
        f:SetBackdrop(nil)
        if not f.LedgerSkinTextures then S.Apply(f,'Window',20) end
        -- The old cyan portrait square was decorative, not the icon itself.
        for _,r in ipairs({f:GetRegions()}) do
            if r:IsObjectType('Texture') and r:GetWidth()==50 and r:GetHeight()==50 then r:SetAlpha(0) end
        end
    end
    walk(f,0)
end
local function wrap(name,field,after)
    local old=A[name]
    if not old then return end
    A[name]=function(self,...)
        local result=old(self,...)
        local f=self[field]
        window(f)
        if f and after then after(f,self) end
        return result
    end
end
local function tools(f,self)
    if f.saveAllButton then f.saveAllButton:SetShown(f.mode~='run' and f.mode~='create') end
    if f.footer then f.footer:SetText('Choose a run to edit, or create a manual entry. Use the save button on the form.') end
    for mode,b in pairs(f.navButtons or {}) do
        if not b.menuSelected then
            b.menuSelected=b:CreateTexture(nil,'OVERLAY'); S.ThemeAccentTexture(b.menuSelected)
            b.menuSelected:SetHeight(2); b.menuSelected:SetPoint('BOTTOMLEFT',5,0); b.menuSelected:SetPoint('BOTTOMRIGHT',-5,0)
        end
        b.menuSelected:SetShown(mode==f.mode)
    end
end
wrap('CreateWindow','window')
wrap('RefreshWindow','window')
wrap('CreateDataToolsWindow','dataTools',tools)
wrap('RefreshDataToolsWindow','dataTools',tools)
wrap('CreateRepairWindow','repairWindow')
wrap('RefreshRepairWindow','repairWindow')
-- CreatePlayerHistoryWindow deliberately NOT wrapped here -- per user report 2026-10-01 (Player
-- Reputation looking right but not responding to clicks, every time it opens). It's only ever
-- called from OpenPlayerHistoryWindow, always immediately followed by RefreshPlayerHistoryWindow
-- (also wrapped, below) -- so decorating both meant window(f)/walk(f,0) ran the FULL recursive
-- tree-walk over this window's entire widget set TWICE on every single open, back to back. Beyond
-- the wasted work, the first pass's own OnHide/OnShow side effects (CreatePlayerHistoryWindow's
-- initial frame:Hide() call fires the window's OnHide script, which shows the OLD main window) were
-- firing WHILE the window was still being put together, before BringWindowToFront had set
-- ledgerSwitchingWindows -- a real, reproducible-every-time source of exactly this kind of
-- intermittent "looks right, nothing responds" state. The Refresh-wrap's own window(f) call below
-- already re-skins the chrome and walks every widget regardless of which function triggered it, so
-- decorating twice was never actually necessary.
wrap('RefreshPlayerHistoryWindow','playerHistoryWindow')
wrap('CreateAddPlayerWindow','addPlayerWindow')
wrap('RefreshAddPlayerWindow','addPlayerWindow')
wrap('CreateUpdatePlayerWindow','updatePlayerWindow')
wrap('RefreshUpdatePlayerWindow','updatePlayerWindow')
wrap('CreateDebugEditorWindow','debugEditor')
wrap('RefreshDebugEditorWindow','debugEditor')
-- Dropdowns are populated after their window; style new options before display.
local oldDropdown=A.RefreshSimpleDropdown
function A:RefreshSimpleDropdown(menu,...)
    oldDropdown(self,menu,...)
    walk(menu,0)
end
