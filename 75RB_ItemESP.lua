-- 75RB_ItemESP.lua v1.0 — ESP เน้นไอเทม (universal ใช้ได้ทุกเกม)
-- สแกนหา: Tool ตกพื้น / ของที่มี ProximityPrompt (เก็บได้) → จัดกลุ่มตามชื่อ
-- กดชื่อกลุ่ม = เปิด/ปิด ESP ชนิดนั้น | ALL ON/OFF | RESCAN | พับจอ [—]
-- ป้ายชื่อ+ระยะลอยเหนือของ + Highlight ทะลุกำแพง | อัปเดตระยะสด

-- ==================== Single-Instance Guard ====================
if _G.IESP75_CONNS then
    for _, c in pairs(_G.IESP75_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.IESP75_MARKS then
    for _, m in pairs(_G.IESP75_MARKS) do
        pcall(function() if m.hl then m.hl:Destroy() end end)
        pcall(function() if m.tag then m.tag:Destroy() end end)
    end
end
if _G.IESP75_GUI then pcall(function() _G.IESP75_GUI:Destroy() end) end
_G.IESP75_CONNS = {}
_G.IESP75_MARKS = {}   -- [Instance] = {hl=Highlight, tag=BillboardGui, name=ชื่อกลุ่ม}

local V = "1.0"
local Players = game:GetService("Players")
local RunSvc  = game:GetService("RunService")
local LP      = Players.LocalPlayer

-- ==================== Config / State ====================
local MAX_DIST  = 2000          -- ไม่โชว์ของไกลกว่านี้ (ปรับได้ในโค้ด)
local GROUP_ON  = {}            -- [ชื่อกลุ่ม] = true/false (default true ตอนเจอครั้งแรก)
local GROUPS    = {}            -- [ชื่อกลุ่ม] = {count=n, insts={...}}
local ORDER     = {}            -- ชื่อกลุ่มเรียงตามลำดับเจอ
local MARKS     = _G.IESP75_MARKS

-- สีสุ่มคงที่ต่อชื่อ (ชื่อเดียวกัน = สีเดียวกันทุกครั้ง)
local function groupColor(name)
    local h = 0
    for i = 1, #name do h = (h * 31 + name:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.85, 1)
end

local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local p = (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")))
        or inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local function myPos()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return r and r.Position
end

-- ตัวนี้เป็น "ไอเทม" ไหม + ชื่อกลุ่มอะไร
-- 1) Tool ที่อยู่ใน Workspace (ตกพื้น) → ชื่อ Tool
-- 2) มี ProximityPrompt → ใช้ ActionText ถ้ามี ไม่งั้นชื่อ Parent
local function itemInfo(inst)
    if inst:IsA("Tool") and inst:IsDescendantOf(workspace) then
        return inst, inst.Name
    end
    if inst:IsA("ProximityPrompt") and inst.Enabled and inst.Parent then
        local holder = inst.Parent
        -- ข้าม prompt บนตัวผู้เล่น/NPC (มี Humanoid) — เอาเฉพาะ "ของ"
        local m = holder:FindFirstAncestorOfClass("Model")
        while m do
            if m:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(m) then return nil end
            m = m:FindFirstAncestorOfClass("Model")
        end
        local label = (inst.ActionText ~= "" and inst.ActionText)
            or (inst.ObjectText ~= "" and inst.ObjectText) or holder.Name
        local target = (holder:IsA("BasePart") and holder.Parent and holder.Parent:IsA("Model")
            and holder.Parent) or holder
        return target, label
    end
    return nil
end

-- ==================== Markers ====================
local function addMark(inst, name)
    if MARKS[inst] then return end
    local adornP = inst:IsA("BasePart") and inst
        or (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")))
        or inst:FindFirstChildWhichIsA("BasePart", true)
    if not adornP then return end
    local col = groupColor(name)

    local hl = Instance.new("Highlight")
    hl.Adornee = (inst:IsA("Model") or inst:IsA("Tool")) and inst or adornP
    hl.FillColor = col; hl.FillTransparency = 0.55
    hl.OutlineColor = col; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = adornP

    local tag = Instance.new("BillboardGui")
    tag.Adornee = adornP
    tag.Size = UDim2.new(0, 150, 0, 16)
    tag.StudsOffset = Vector3.new(0, 2.2, 0)
    tag.AlwaysOnTop = true
    tag.MaxDistance = MAX_DIST
    tag.Parent = adornP
    local lbl = Instance.new("TextLabel", tag)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = col
    lbl.TextStrokeTransparency = 0.2
    lbl.Text = name

    MARKS[inst] = { hl = hl, tag = tag, name = name, adorn = adornP }
end

local function removeMark(inst)
    local m = MARKS[inst]
    if not m then return end
    pcall(function() m.hl:Destroy() end)
    pcall(function() m.tag:Destroy() end)
    MARKS[inst] = nil
end

local function setGroupVisible(name, on)
    for inst, m in pairs(MARKS) do
        if m.name == name then
            m.hl.Enabled = on
            m.tag.Enabled = on
        end
    end
end

-- ==================== Scan ====================
local rebuildList   -- forward (GUI สร้างทีหลัง)

local function scan()
    GROUPS, ORDER = {}, {}
    local seen = {}   -- [Instance] = ชื่อกลุ่ม (ของรอบนี้)
    for _, d in ipairs(workspace:GetDescendants()) do
        local ok, target, label = pcall(itemInfo, d)
        if ok and target and not seen[target] then
            seen[target] = label
            local g = GROUPS[label]
            if not g then
                g = { count = 0, insts = {} }
                GROUPS[label] = g
                ORDER[#ORDER + 1] = label
                if GROUP_ON[label] == nil then GROUP_ON[label] = true end
            end
            g.count += 1
            g.insts[#g.insts + 1] = target
        end
    end
    -- ลบ mark ของที่หายไปแล้ว / เพิ่ม mark ของใหม่
    for inst in pairs(MARKS) do
        if not seen[inst] or not inst.Parent then removeMark(inst) end
    end
    for inst, label in pairs(seen) do
        addMark(inst, label)
    end
    for name, on in pairs(GROUP_ON) do setGroupVisible(name, on) end
    if rebuildList then rebuildList() end
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "ItemESP75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.IESP75_GUI = gui

local FULL_H, MIN_H = 330, 32
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 190, 0, FULL_H)
panel.Position = UDim2.new(1, -200, 0.5, -FULL_H / 2)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
panel.BorderSizePixel = 0
panel.Active, panel.Draggable = true, true
panel.ClipsDescendants = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -70, 0, 28)
title.Position = UDim2.new(0, 8, 0, 2)
title.BackgroundTransparency = 1
title.Text = "ItemESP v" .. V
title.Font = Enum.Font.GothamBold; title.TextSize = 14
title.TextColor3 = Color3.fromRGB(255, 200, 90)
title.TextXAlignment = Enum.TextXAlignment.Left

local foldB = Instance.new("TextButton", panel)
foldB.Size = UDim2.new(0, 28, 0, 24); foldB.Position = UDim2.new(1, -62, 0, 4)
foldB.Text = "—"; foldB.Font = Enum.Font.GothamBold; foldB.TextSize = 14
foldB.BackgroundColor3 = Color3.fromRGB(50, 50, 70); foldB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", foldB).CornerRadius = UDim.new(0, 5)

local closeB = Instance.new("TextButton", panel)
closeB.Size = UDim2.new(0, 28, 0, 24); closeB.Position = UDim2.new(1, -32, 0, 4)
closeB.Text = "✕"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 14
closeB.BackgroundColor3 = Color3.fromRGB(140, 30, 30); closeB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)

local rescanB = Instance.new("TextButton", panel)
rescanB.Size = UDim2.new(0, 86, 0, 26); rescanB.Position = UDim2.new(0, 6, 0, 32)
rescanB.Text = "RESCAN"; rescanB.Font = Enum.Font.GothamBold; rescanB.TextSize = 13
rescanB.BackgroundColor3 = Color3.fromRGB(40, 130, 70); rescanB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", rescanB).CornerRadius = UDim.new(0, 5)

local allB = Instance.new("TextButton", panel)
allB.Size = UDim2.new(0, 86, 0, 26); allB.Position = UDim2.new(0, 98, 0, 32)
allB.Text = "ALL ON/OFF"; allB.Font = Enum.Font.GothamBold; allB.TextSize = 12
allB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); allB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", allB).CornerRadius = UDim.new(0, 5)

local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size = UDim2.new(1, -12, 0, FULL_H - 70)
scroll.Position = UDim2.new(0, 6, 0, 64)
scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 5)
Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 2)

local gBtns = {}
rebuildList = function()
    for _, b in pairs(gBtns) do b:Destroy() end
    gBtns = {}
    local mp = myPos()
    for _, name in ipairs(ORDER) do
        local g = GROUPS[name]
        if g and g.count > 0 then
            local on = GROUP_ON[name]
            -- ระยะใกล้สุดของกลุ่ม (ไว้เรียง)
            local nd
            if mp then
                for _, inst in ipairs(g.insts) do
                    local p = partPos(inst)
                    local d = p and (p - mp).Magnitude
                    if d and (not nd or d < nd) then nd = d end
                end
            end
            local b = Instance.new("TextButton", scroll)
            b.Size = UDim2.new(1, -6, 0, 26)
            b.LayoutOrder = nd and math.floor(nd) or 99999
            b.BackgroundColor3 = on and Color3.fromRGB(25, 55, 35) or Color3.fromRGB(22, 22, 30)
            b.TextColor3 = on and groupColor(name) or Color3.fromRGB(100, 100, 115)
            b.Text = ("%s %s x%d%s"):format(on and "●" or "○", name, g.count,
                nd and (" " .. math.floor(nd) .. "m") or "")
            b.Font = Enum.Font.GothamBold; b.TextSize = 12
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.TextTruncate = Enum.TextTruncate.AtEnd
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
            b.MouseButton1Click:Connect(function()
                GROUP_ON[name] = not GROUP_ON[name]
                setGroupVisible(name, GROUP_ON[name])
                rebuildList()
            end)
            gBtns[name] = b
        end
    end
end

local folded = false
foldB.MouseButton1Click:Connect(function()
    folded = not folded
    panel.Size = UDim2.new(0, 190, 0, folded and MIN_H or FULL_H)
end)
closeB.MouseButton1Click:Connect(function()
    for _, c in pairs(_G.IESP75_CONNS) do pcall(function() c:Disconnect() end) end
    for inst in pairs(MARKS) do removeMark(inst) end
    gui:Destroy()
    _G.IESP75_GUI, _G.IESP75_CONNS = nil, {}
end)
rescanB.MouseButton1Click:Connect(scan)
local allState = true
allB.MouseButton1Click:Connect(function()
    allState = not allState
    for name in pairs(GROUP_ON) do
        GROUP_ON[name] = allState
        setGroupVisible(name, allState)
    end
    rebuildList()
end)

-- ==================== Live loop ====================
-- อัปเดตระยะบนป้าย + เก็บกวาด mark ของที่โดนเก็บไป (ทุก 0.5s)
-- สแกนใหม่อัตโนมัติทุก 5s (ของ spawn ใหม่)
local accTag, accScan = 0, 0
table.insert(_G.IESP75_CONNS, RunSvc.Heartbeat:Connect(function(dt)
    accTag += dt; accScan += dt
    if accTag >= 0.5 then
        accTag = 0
        local mp = myPos()
        for inst, m in pairs(MARKS) do
            if not inst.Parent or not inst:IsDescendantOf(workspace) then
                removeMark(inst)
            elseif mp and m.tag.Enabled then
                local p = partPos(inst)
                local lbl = m.tag:FindFirstChildOfClass("TextLabel")
                if lbl and p then
                    lbl.Text = ("%s %dm"):format(m.name, math.floor((p - mp).Magnitude))
                end
            end
        end
    end
    if accScan >= 5 then
        accScan = 0
        scan()
    end
end))

scan()
print("[75RB ItemESP v" .. V .. "] เจอ " .. #ORDER .. " ชนิด — กดชื่อในลิสต์เพื่อเปิด/ปิดรายชนิด")
