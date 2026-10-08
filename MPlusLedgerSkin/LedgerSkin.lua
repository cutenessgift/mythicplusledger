-- Load before the files that construct your addon UI.
local addonName, ns = ...
local Skin = {}
ns.LedgerSkin = Skin
local media = 'Interface\\AddOns\\' .. addonName .. '\\MPlusLedgerSkin\\Media\\'
local styles = {
    Window = { source = 80, edge = 32 },
    Card = { source = 24, edge = 12 },
    Button = { source = 24, edge = 10 },
    Feature = { source = 24, edge = 12 },
}
Skin.colors = {
    text = {0.93, 0.91, 0.85}, muted = {0.65, 0.68, 0.70},
    gold = {0.78, 0.82, 0.86}, purple = {0.70, 0.53, 0.94},
    -- Button labels and window/section headings: plain white in every theme (user request
    -- 2026-10-04) -- the theme accent is kept for borders, icons and small highlights only.
    white = {1, 1, 1},
}

-- Nine regions keep the border thickness and corner artwork fixed on resize.
-- Minimum dimensions: twice edge. Intended to be called once per frame.
--
-- Was a hard assert() on a repeat call -- changed to a safe no-op (returns the existing textures)
-- per a live error report 2026-10-01: '...LedgerSkin.lua:20: LedgerSkin.Apply: frame already
-- styled', thrown from inside a RefreshWindow/RefreshPlayerHistoryWindow-style refresh chain.
-- Several integration files guard their OWN Apply calls correctly (`if not
-- frame.LedgerSkinTextures then Skin.Apply(...) end`), but with this many separate files each
-- independently wrapping the same handful of Core.lua refresh functions, a caller that forgets
-- that guard is a when-not-if across a codebase this size -- and since Lua errors abort the rest
-- of whatever function was running, ONE unguarded re-Apply call was silently aborting the back
-- half of an entire decoration pass, leaving that window partially styled AND partially wired up
-- (exactly the "looks right but doesn't respond to clicks" reports). This widget library has no
-- way to enforce every caller's discipline, so the library itself is now safe to call twice
-- instead of relying on it.
function Skin.Apply(frame, styleName, edge)
    if frame.LedgerSkinTextures then
        return frame.LedgerSkinTextures
    end
    local spec = assert(styles[styleName], 'Unknown LedgerSkin style')
    edge = edge or spec.edge
    local uv = {0, spec.source / 512, 1 - spec.source / 512, 1}
    local textures = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local t = frame:CreateTexture(nil, 'BACKGROUND')
            t:SetTexture(media .. styleName .. '.png')
            t:SetTexCoord(uv[col], uv[col + 1], uv[row], uv[row + 1])
            -- Horizontal anchoring on the appropriate edge or across the center.
            local left = col == 3 and 'RIGHT' or 'LEFT'
            local x = col == 1 and 0 or (col == 2 and edge or -edge)
            local top = row == 3 and 'BOTTOM' or 'TOP'
            local y = row == 1 and 0 or (row == 2 and -edge or edge)
            t:SetPoint('TOPLEFT', frame, top .. left, x, y)
            if col == 2 then
                t:SetPoint('TOPRIGHT', frame, top .. 'RIGHT', -edge, y)
            else
                t:SetWidth(edge)
            end
            if row == 2 then
                t:SetPoint('BOTTOMLEFT', frame, 'BOTTOM' .. left, x, edge)
            else
                t:SetHeight(edge)
            end
            textures[#textures + 1] = t
        end
    end
    frame.LedgerSkinStyle = styleName
    frame.LedgerSkinTextures = textures
    return textures
end

function Skin.Label(parent, text, size, color)
    local label = parent:CreateFontString(nil, 'OVERLAY')
    label:SetFont(STANDARD_TEXT_FONT, size or 14, '')
    label:SetText(text)
    label:SetJustifyH('LEFT')
    color = color or Skin.colors.text
    label:SetTextColor(color[1], color[2], color[3])
    return label
end

function Skin.Button(parent, text, width, height, onClick)
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(width or 150, height or 36)
    local parts = Skin.Apply(button, 'Button')
    local label = Skin.Label(button, text, 14, Skin.colors.white)
    label:SetPoint('CENTER')
    label:SetWidth(math.max(18, (width or 150) - 16))
    label:SetJustifyH('CENTER')
    button.Label = label
    local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetPoint('TOPLEFT', 6, -6)
    highlight:SetPoint('BOTTOMRIGHT', -6, 6)
    highlight:SetColorTexture(0.78, 0.82, 0.86, 0.10)
    local function tint(value)
        for _, t in ipairs(parts) do t:SetVertexColor(value, value, value) end
    end
    button:SetScript('OnMouseDown', function(self)
        if self:IsEnabled() then tint(0.72) end
    end)
    button:SetScript('OnMouseUp', function(self)
        tint(self:IsEnabled() and 1 or 0.45)
    end)
    button:SetScript('OnLeave', function(self)
        tint(self:IsEnabled() and 1 or 0.45)
    end)
    button:SetScript('OnDisable', function() tint(0.45); label:SetAlpha(0.45) end)
    button:SetScript('OnEnable', function() tint(1); label:SetAlpha(1) end)
    if onClick then button:SetScript('OnClick', onClick) end
    return button
end

-- Native color textures stay crisp at any size. Input is an ordinary 0..1 value.
function Skin.Progress(parent, width, height, value)
    local bar = CreateFrame('Frame', nil, parent)
    bar:SetSize(width or 240, height or 8)
    local track = bar:CreateTexture(nil, 'BACKGROUND')
    track:SetAllPoints()
    track:SetColorTexture(0.20, 0.21, 0.22, 1)
    local fill = bar:CreateTexture(nil, 'ARTWORK')
    fill:SetPoint('TOPLEFT')
    fill:SetPoint('BOTTOMLEFT')
    local c = Skin.colors.purple
    fill:SetColorTexture(c[1], c[2], c[3], 1)
    function bar:SetValue(fraction)
        self.value = math.max(0, math.min(1, fraction or 0))
        fill:SetWidth(math.max(0.01, self:GetWidth() * self.value))
        fill:SetShown(self.value > 0)
    end
    bar:SetScript('OnSizeChanged', function(self) self:SetValue(self.value) end)
    bar:SetValue(value)
    return bar
end

function Skin.Tab(parent, text, width, onClick)
    local tab = CreateFrame('Button', nil, parent)
    tab:SetSize(width or 130, 34)
    local label = Skin.Label(tab, text, 15)
    label:SetPoint('CENTER')
    local underline = tab:CreateTexture(nil, 'ARTWORK')
    underline:SetHeight(2)
    underline:SetPoint('BOTTOMLEFT', 8, 0)
    underline:SetPoint('BOTTOMRIGHT', -8, 0)
    underline:SetColorTexture(0.78, 0.82, 0.86, 1)
    function tab:SetSelected(selected)
        underline:SetShown(selected)
        local c = selected and Skin.colors.gold or Skin.colors.muted
        label:SetTextColor(c[1], c[2], c[3])
    end
    tab:SetSelected(false)
    if onClick then tab:SetScript('OnClick', onClick) end
    return tab
end
