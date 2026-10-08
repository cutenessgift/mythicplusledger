-- ============================================================================================
-- MPlusLedgerPieChart -- reusable donut/pie chart widget, built 2026-09-06 for the "arcane" UI
-- theme (see Core.lua's Addon:GetTheme()). This file is a SEPARATE load chunk from Core.lua (see
-- the .toc -- it's listed before Core.lua), so it does NOT have access to any of Core.lua's
-- `local` helpers/state; it only touches the WoW API and its own internals, and exposes itself as
-- the single global `MPlusLedgerPieChart`. That's deliberate: a reusable widget shouldn't need
-- to know anything about the addon that happens to be using it.
--
-- Technique: a pooled set of pre-rotated wedge textures (NOT a "sweep mask" -- WoW's plain
-- Texture blending can't erase/subtract an arbitrary angular region from an already-drawn shape,
-- that's a special native effect specific to the Cooldown widget's swipe, not something reusable
-- here), tinted per-category via SetVertexColor and allocated via the Largest Remainder Method so
-- the wedge count always sums exactly to WEDGE_COUNT regardless of rounding.
--
-- Wedge art (Textures/PieChart/pie_wedge.png) is a full square, transparent everywhere except one
-- WEDGE_ANGLE_DEG-wide sector (plus a small overlap) centered on "up" (12 o'clock) -- so every
-- wedge instance rotates around the texture's own default (center) pivot with no custom pivot
-- math needed, and slot k sits at `(k-1) * WEDGE_ANGLE_DEG` clockwise from 12 o'clock.
-- ============================================================================================

local PIE_ADDON_NAME = ...
local TEXTURE_PATH = "Interface\\AddOns\\" .. PIE_ADDON_NAME .. "\\Textures\\PieChart\\"
local WEDGE_TEXTURE = TEXTURE_PATH .. "pie_wedge.png"
local CENTER_TEXTURE = TEXTURE_PATH .. "pie_center.png"
local OUTLINE_TEXTURE = TEXTURE_PATH .. "pie_outline.png"

-- Must match gen_pie_textures.py's WEDGE_COUNT -- the art's wedge angular width is baked in.
local WEDGE_COUNT = 30
local WEDGE_ANGLE_DEG = 360 / WEDGE_COUNT

-- math.atan2 is standard in Lua 5.1 and used by plenty of real addons (minimap/compass addons
-- computing angles), but its presence in WoW's Lua sandbox hasn't been confirmed against a live
-- client from here -- this falls back to a manually quadrant-corrected math.atan (which IS
-- guaranteed present) rather than risk a hard "attempt to call a nil value" error if it's missing.
local Atan2 = math.atan2 or function(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 then
        return math.atan(y / x) - math.pi
    elseif y > 0 then
        return math.pi / 2
    elseif y < 0 then
        return -math.pi / 2
    end
    return 0
end

-- Largest Remainder Method (Hamilton's apportionment method): guarantees the returned counts
-- always sum to exactly `totalWedges`, no matter how the input percentages round. Each category's
-- exact fractional share is floored, then whatever's left over goes one-by-one to whichever
-- category has the largest fractional remainder (ties broken by original value, deterministic).
local function AllocateWedges(categories, totalWedges)
    local floors, remainders, valueSum = {}, {}, 0
    for _, cat in ipairs(categories) do
        valueSum = valueSum + math.max(0, cat.value or 0)
    end
    if valueSum <= 0 then
        for i in ipairs(categories) do
            floors[i] = 0
        end
        return floors
    end

    local assigned = 0
    for i, cat in ipairs(categories) do
        local exact = (math.max(0, cat.value or 0) / valueSum) * totalWedges
        floors[i] = math.floor(exact)
        remainders[i] = exact - floors[i]
        assigned = assigned + floors[i]
    end

    local order = {}
    for i in ipairs(categories) do
        table.insert(order, i)
    end
    table.sort(order, function(a, b)
        if remainders[a] ~= remainders[b] then
            return remainders[a] > remainders[b]
        end
        return (categories[a].value or 0) > (categories[b].value or 0)
    end)

    local leftover = totalWedges - assigned
    for k = 1, leftover do
        local i = order[k]
        if not i then
            break
        end
        floors[i] = floors[i] + 1
    end

    return floors
end

local MPlusLedgerPieChart = {}
MPlusLedgerPieChart.__index = MPlusLedgerPieChart
_G.MPlusLedgerPieChart = MPlusLedgerPieChart

-- opts: radius (px, default 80), innerRadiusRatio (0-1, donut hole size relative to radius,
-- default 0.55; pass 0 for a solid pie with no hole), showOutline (default true).
function MPlusLedgerPieChart.New(parent, opts)
    opts = opts or {}
    local radius = opts.radius or 80
    local innerRadiusRatio = opts.innerRadiusRatio
    if innerRadiusRatio == nil then
        innerRadiusRatio = 0.55
    end

    local chart = setmetatable({}, MPlusLedgerPieChart)
    chart.radius = radius
    chart.innerRadiusRatio = innerRadiusRatio
    chart.slices = {} -- filled by SetData: { {startDeg,endDeg,label,value,percent,color}, ... }

    local frame = CreateFrame("Button", nil, parent)
    frame:SetSize(radius * 2, radius * 2)
    frame:EnableMouse(true)
    chart.frame = frame

    if opts.showOutline ~= false then
        local outline = frame:CreateTexture(nil, "BACKGROUND")
        outline:SetAllPoints(frame)
        outline:SetTexture(OUTLINE_TEXTURE)
        outline:SetVertexColor(1, 1, 1, 0.55)
        chart.outline = outline
    end

    -- Wedge pool, created once, reused for every SetData call -- never destroyed/recreated.
    -- Sublevels alternate 0/1 so every wedge differs from BOTH its immediate neighbors, which is
    -- all that matters: only adjacent wedges actually overlap (the art's small angular overlap on
    -- each edge), so this is enough to keep that overlap direction consistent and flicker-free.
    chart.wedgePool = {}
    for index = 1, WEDGE_COUNT do
        local sublevel = (index % 2 == 0) and 1 or 0
        local wedge = frame:CreateTexture(nil, "ARTWORK", nil, sublevel)
        wedge:SetSize(radius * 2, radius * 2)
        wedge:SetPoint("CENTER", frame, "CENTER")
        wedge:SetTexture(WEDGE_TEXTURE)
        wedge:Hide()
        chart.wedgePool[index] = wedge
    end

    -- Donut hole cover -- a separate, UNROTATED overlay above the wedges, not a mask applied to
    -- them. Sized to 0 (hidden) for a solid pie when innerRadiusRatio is 0.
    local center = frame:CreateTexture(nil, "OVERLAY")
    center:SetPoint("CENTER", frame, "CENTER")
    local centerDiameter = radius * 2 * innerRadiusRatio
    center:SetSize(math.max(1, centerDiameter), math.max(1, centerDiameter))
    center:SetTexture(CENTER_TEXTURE)
    if innerRadiusRatio <= 0 then
        center:Hide()
    end
    chart.center = center
    chart.centerColor = opts.centerColor -- optional {r,g,b,a}; caller can match its own panel bg
    if chart.centerColor then
        center:SetVertexColor(unpack(chart.centerColor))
    end

    frame:SetScript("OnEnter", function()
        chart:StartHoverPoll()
    end)
    frame:SetScript("OnLeave", function()
        chart:StopHoverPoll()
        GameTooltip:Hide()
    end)

    return chart
end

-- categories: { {label=, value=, color={r,g,b}}, ... }. Values don't need to sum to 100 -- they're
-- normalized internally. A category with value <= 0 (or whose rounded share is 0 wedges) simply
-- shows no wedges; it's still recorded in self.slices with a 0-degree range so hover math never
-- has to special-case it.
function MPlusLedgerPieChart:SetData(categories)
    self.slices = {}
    local counts = AllocateWedges(categories, WEDGE_COUNT)

    local valueSum = 0
    for _, cat in ipairs(categories) do
        valueSum = valueSum + math.max(0, cat.value or 0)
    end

    local slot = 0 -- next wedge-pool index to hand out, 0-based
    for i, cat in ipairs(categories) do
        local count = counts[i] or 0
        local startDeg = slot * WEDGE_ANGLE_DEG
        local endDeg = (slot + count) * WEDGE_ANGLE_DEG
        table.insert(self.slices, {
            label = cat.label,
            value = cat.value or 0,
            percent = valueSum > 0 and ((cat.value or 0) / valueSum * 100) or 0,
            color = cat.color or { 1, 1, 1 },
            startDeg = startDeg,
            endDeg = endDeg,
        })

        for k = 1, count do
            slot = slot + 1
            local wedge = self.wedgePool[slot]
            if wedge then
                wedge:SetVertexColor(cat.color[1] or 1, cat.color[2] or 1, cat.color[3] or 1, 1)
                -- Slot (slot-1) sits at (slot-1)*WEDGE_ANGLE_DEG clockwise from 12 o'clock, matching
                -- how pie_wedge.png was authored (centered on "up" at rotation 0). NOTE: WoW's
                -- SetRotation sign convention for "clockwise" hasn't been confirmed live -- if
                -- wedges render mirrored (counter-clockwise order), flip this to a positive angle.
                wedge:SetRotation(-math.rad((slot - 1) * WEDGE_ANGLE_DEG))
                wedge:Show()
            end
        end
    end

    -- Hide any pool members left over from a previous SetData with more total wedges used
    -- (shouldn't happen since counts always sum to WEDGE_COUNT, but a category list that sums to
    -- 0 leaves the whole pool unused -- this is what actually hides them in that case).
    for index = slot + 1, WEDGE_COUNT do
        self.wedgePool[index]:Hide()
    end
end

function MPlusLedgerPieChart:Show()
    self.frame:Show()
end

function MPlusLedgerPieChart:Hide()
    self.frame:Hide()
    self:StopHoverPoll()
end

function MPlusLedgerPieChart:IsShown()
    return self.frame:IsShown()
end

-- ---------------------------------------------------------------------------------------------
-- Hover/tooltip: wedges are pooled Texture regions with no hitbox of their own, and even as
-- Buttons a rectangular hit-rect wouldn't match a wedge's actual triangular shape reliably. The
-- only robust option is angle-based hit detection on this ONE parent frame, polled only while the
-- mouse is actually over the chart (OnEnter/OnLeave gate the OnUpdate, not running it constantly).
-- ---------------------------------------------------------------------------------------------

function MPlusLedgerPieChart:StartHoverPoll()
    self.frame:SetScript("OnUpdate", function()
        self:UpdateHover()
    end)
end

function MPlusLedgerPieChart:StopHoverPoll()
    self.frame:SetScript("OnUpdate", nil)
end

function MPlusLedgerPieChart:UpdateHover()
    local cx, cy = self.frame:GetCenter()
    if not cx then
        GameTooltip:Hide()
        return
    end

    local scale = UIParent:GetEffectiveScale()
    local px, py = GetCursorPosition()
    px, py = px / scale, py / scale
    local dx, dy = px - cx, py - cy
    local distance = math.sqrt(dx * dx + dy * dy)

    local innerRadius = self.radius * self.innerRadiusRatio
    if distance < innerRadius or distance > self.radius then
        GameTooltip:Hide()
        return
    end

    -- WoW frame coordinates are y-up (standard Cartesian), so atan2(dy,dx) is the standard math
    -- angle (0 = east/3 o'clock, increasing counter-clockwise). Converting to "degrees clockwise
    -- from 12 o'clock" (matching the wedge slot numbering above) is `90 - angle`, normalized to
    -- [0, 360). Verified by hand at all four cardinal points, not just assumed.
    local mathAngleDeg = math.deg(Atan2(dy, dx))
    local clockwiseFromUp = (90 - mathAngleDeg) % 360

    for _, slice in ipairs(self.slices) do
        if clockwiseFromUp >= slice.startDeg and clockwiseFromUp < slice.endDeg then
            GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
            GameTooltip:SetText(slice.label)
            GameTooltip:AddLine(string.format("%.0f%% (%s)", slice.percent, tostring(slice.value)), 0.8, 0.8, 0.8)
            GameTooltip:Show()
            return
        end
    end
    GameTooltip:Hide()
end
