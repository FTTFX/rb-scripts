-- 75RB_ItemESP.lua v2.0 — ESP คริสตัล (เกมเหมืองแร่) + โหมด universal สำรอง
-- v2.0: อ่าน Attributes ของเกมตรงๆ (CrystalName/TierName/Tier/Value/WeightKg/SizeClass/TierColor)
--   ป้าย: "[Giant] Diamond $36.4M 31m" สีตามเทียร์ | กรองรายเทียร์ T1-T6 | ปุ่ม Giant only
--   โชว์สูงสุด 150 ก้อน เลือกโหมด: ใกล้สุด / แพงสุด (กันจอแตก — ทั้งแมพมี ~2000 ก้อน)
-- ถ้าไม่ใช่เกมคริสตัล → fallback สแกน Tool/ProximityPrompt แบบ v1.0 (กลุ่มตามชื่อ)

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
_G.IESP75_MARKS = {}

local V = "2.0"
local Players = game:GetService("Players")
local RunSvc  = game:GetService("RunService")
local LP      = Players.LocalPlayer
local MARKS   = _G.IESP75_MARKS

-- ==================== Config / State ====================
local MAX_SHOW   = 150            -- ป้ายพร้อมกันสูงสุด (กันเลค/จอแตก)
local TIER_ON    = { [1]=false, [2]=false, [3]=false, [4]=true, [5]=true, [6]=true }
local GIANT_ONLY = false          -- true = โชว์เฉพาะ SizeClass ~= Small
local SORT_VALUE = true           -- true = แพงสุดก่อน | false = ใกล้สุดก่อน
local TIER_NAMES = { "T1 Common", "T2", "T3", "T4", "T5 Legend", "T6 Mythic" }

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
local function fmtMoney(v)
    if v >= 1e6 then return ("$%.1fM"):format(v / 1e6) end
    if v >= 1e3 then return ("$%.0fK"):format(v / 1e3) end
    return "$" .. math.floor(v)
end

-- โฟลเดอร์คริสตัลของเกมนี้ (nil = ไม่ใช่เกมนี้ → โหมด universal)
local CRYSTALS = workspace:FindFirstChild("Things")
CRYSTALS = CRYSTALS and CRYSTALS:FindFirstChild("Crystals")

-- ==================== Markers ====================
local function addMark(inst, text, col)
    local m = MARKS[inst]
    if m then
        m.text = text
        return
    end
    local adornP = inst:IsA("BasePart") and inst
        or (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")))
        or inst:FindFirstChildWhichIsA("BasePart", true)
    if not adornP then return end

    local hl = Instance.new("Highlight")
    hl.Adornee = (inst:IsA("Model") or inst:IsA("Tool")) and inst or adornP
    hl.FillColor = col; hl.FillTransparency = 0.6
    hl.OutlineColor = col; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = adornP

    local tag = Instance.new("BillboardGui")
    tag.Adornee = adornP
    tag.Size = UDim2.new(0, 190, 0, 15)
    tag.StudsOffset = Vector3.new(0, 3, 0)
    tag.AlwaysOnTop = true
    tag.Parent = adornP
    local lbl = Instance.new("TextLabel", tag)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = col
    lbl.TextStrokeTransparency = 0.2
    lbl.Text = text

    MARKS[inst] = { hl = hl, tag = tag, lbl = lbl, text = text }
end

local function removeMark(inst)
    local m = MARKS[inst]
    if not m then return end
    pcall(function() m.hl:Destroy() end)
    pcall(function() m.tag:Destroy() end)
    MARKS[inst] = nil
end

-- ==================== Crystal scan ====================
local statusLbl   -- forward

local function scanCrystals()
    local mp = myPos()
    local list = {}
    for _, c in ipairs(CRYSTALS:GetChildren()) do
        local tier = c:GetAttribute("Tier")
        if tier and TIER_ON[tier] then
            local sz = c:GetAttribute("SizeClassName") or "?"
            if not GIANT_ONLY or sz ~= "Small" then
                local p = partPos(c)
                if p then
                    list[#list + 1] = {
                        inst = c,
                        d = mp and (p - mp).Magnitude or 1e9,
                        val = c:GetAttribute("Value") or 0,
                        name = c:GetAttribute("CrystalName") or c.Name,
                        sz = sz,
                        col = Color3.fromRGB(
                            c:GetAttribute("TierColorR") or 255,
                            c:GetAttribute("TierColorG") or 255,
                            c:GetAttribute("TierColorB") or 255),
                    }
                end
            end
        end
    end
    if SORT_VALUE then
        table.sort(list, function(a, b) return a.val > b.val end)
    else
        table.sort(list, function(a, b) return a.d < b.d end)
    end
    local keep = {}
    for i = 1, math.min(MAX_SHOW, #list) do
        local e = list[i]
        keep[e.inst] = true
        local szTag = (e.sz ~= "Small") and ("[" .. e.sz .. "] ") or ""
        addMark(e.inst, ("%s%s %s %dm"):format(szTag, e.name, fmtMoney(e.val), math.floor(e.d)), e.col)
    end
    for inst in pairs(MARKS) do
        if not keep[inst] or not inst.Parent then removeMark(inst) end
    end
    if statusLbl then
        statusLbl.Text = ("โชว์ %d/%d ก้อน | %s"):format(
            math.min(MAX_SHOW, #list), #list, SORT_VALUE and "แพงสุดก่อน" or "ใกล้สุดก่อน")
    end
end

-- ==================== Universal fallback scan (v1.0) ====================
local function groupColor(name)
    local h = 0
    for i = 1, #name do h = (h * 31 + name:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.85, 1)
end

local function scanUniversal()
    local mp = myPos()
    local keep = {}
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if n >= MAX_SHOW then break end
        local target, label
        if d:IsA("Tool") then
            target, label = d, d.Name
        elseif d:IsA("ProximityPrompt") and d.Enabled and d.Parent then
            local holder = d.Parent
            local skip = false
            local m2 = holder:FindFirstAncestorOfClass("Model")
            while m2 do
                if m2:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(m2) then skip = true break end
                m2 = m2:FindFirstAncestorOfClass("Model")
            end
            if not skip then
                label = (d.ActionText ~= "" and d.ActionText) or holder.Name
                target = (holder:IsA("BasePart") and holder.Parent and holder.Parent:IsA("Model")
                    and holder.Parent) or holder
            end
        end
        if target and not keep[target] then
            keep[target] = true
            n += 1
            local p = partPos(target)
            local dStr = (p and mp) and (" " .. math.floor((p - mp).Magnitude) .. "m") or ""
            addMark(target, label .. dStr, groupColor(label))
        end
    end
    for inst in pairs(MARKS) do
        if not keep[inst] or not inst.Parent then removeMark(inst) end
    end
    if statusLbl then statusLbl.Text = "universal: " .. n .. " ชิ้น" end
end

local function scan()
    if CRYSTALS and CRYSTALS.Parent then scanCrystals() else scanUniversal() end
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "ItemESP75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.IESP75_GUI = gui

local FULL_H, MIN_H = 258, 32
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

-- ปุ่มเทียร์ T1-T6 (2 แถว x 3)
local tierBtns = {}
local function tierBtnStyle(t)
    local b = tierBtns[t]
    if not b then return end
    b.BackgroundColor3 = TIER_ON[t] and Color3.fromRGB(35, 95, 55) or Color3.fromRGB(30, 30, 42)
    b.TextColor3 = TIER_ON[t] and Color3.new(1, 1, 1) or Color3.fromRGB(110, 110, 125)
end
for t = 1, 6 do
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 57, 0, 26)
    b.Position = UDim2.new(0, 6 + ((t - 1) % 3) * 60, 0, 32 + math.floor((t - 1) / 3) * 29)
    b.Text = TIER_NAMES[t]; b.Font = Enum.Font.GothamBold; b.TextSize = 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    tierBtns[t] = b
    tierBtnStyle(t)
    b.MouseButton1Click:Connect(function()
        TIER_ON[t] = not TIER_ON[t]
        tierBtnStyle(t)
        scan()
    end)
end

local giantB = Instance.new("TextButton", panel)
giantB.Size = UDim2.new(0, 86, 0, 26); giantB.Position = UDim2.new(0, 6, 0, 92)
giantB.Text = "Giant only: OFF"; giantB.Font = Enum.Font.GothamBold; giantB.TextSize = 10
giantB.BackgroundColor3 = Color3.fromRGB(30, 30, 42); giantB.TextColor3 = Color3.fromRGB(110, 110, 125)
Instance.new("UICorner", giantB).CornerRadius = UDim.new(0, 5)
giantB.MouseButton1Click:Connect(function()
    GIANT_ONLY = not GIANT_ONLY
    giantB.Text = "Giant only: " .. (GIANT_ONLY and "ON" or "OFF")
    giantB.BackgroundColor3 = GIANT_ONLY and Color3.fromRGB(150, 110, 30) or Color3.fromRGB(30, 30, 42)
    giantB.TextColor3 = GIANT_ONLY and Color3.new(1, 1, 1) or Color3.fromRGB(110, 110, 125)
    scan()
end)

local sortB = Instance.new("TextButton", panel)
sortB.Size = UDim2.new(0, 86, 0, 26); sortB.Position = UDim2.new(0, 98, 0, 92)
sortB.Text = "เรียง: แพงสุด"; sortB.Font = Enum.Font.GothamBold; sortB.TextSize = 10
sortB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); sortB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", sortB).CornerRadius = UDim.new(0, 5)
sortB.MouseButton1Click:Connect(function()
    SORT_VALUE = not SORT_VALUE
    sortB.Text = SORT_VALUE and "เรียง: แพงสุด" or "เรียง: ใกล้สุด"
    scan()
end)

local rescanB = Instance.new("TextButton", panel)
rescanB.Size = UDim2.new(0, 178, 0, 28); rescanB.Position = UDim2.new(0, 6, 0, 122)
rescanB.Text = "RESCAN"; rescanB.Font = Enum.Font.GothamBold; rescanB.TextSize = 13
rescanB.BackgroundColor3 = Color3.fromRGB(40, 130, 70); rescanB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", rescanB).CornerRadius = UDim.new(0, 5)
rescanB.MouseButton1Click:Connect(scan)

statusLbl = Instance.new("TextLabel", panel)
statusLbl.Size = UDim2.new(1, -12, 0, 16); statusLbl.Position = UDim2.new(0, 6, 0, 154)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "..."
statusLbl.Font = Enum.Font.Gotham; statusLbl.TextSize = 11
statusLbl.TextColor3 = Color3.fromRGB(130, 130, 150)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Top 5 แพงสุดที่กำลังโชว์ (ป้ายในจอ)
local topBox = Instance.new("TextLabel", panel)
topBox.Size = UDim2.new(1, -12, 0, 76); topBox.Position = UDim2.new(0, 6, 0, 172)
topBox.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
topBox.Text = ""
topBox.Font = Enum.Font.Code; topBox.TextSize = 10
topBox.TextColor3 = Color3.fromRGB(190, 220, 190)
topBox.TextXAlignment = Enum.TextXAlignment.Left
topBox.TextYAlignment = Enum.TextYAlignment.Top
topBox.TextWrapped = true
Instance.new("UICorner", topBox).CornerRadius = UDim.new(0, 5)

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

-- ==================== Live loop ====================
-- อัปเดตระยะบนป้ายทุก 0.5s | สแกนใหม่ทุก 3s (ของ spawn/โดนเก็บ) | อัป Top5 ทุก 3s
local accTag, accScan = 0, 0
table.insert(_G.IESP75_CONNS, RunSvc.Heartbeat:Connect(function(dt)
    accTag += dt; accScan += dt
    if accTag >= 0.5 then
        accTag = 0
        local mp = myPos()
        for inst, m in pairs(MARKS) do
            if not inst.Parent then
                removeMark(inst)
            elseif mp then
                local p = partPos(inst)
                if p then
                    m.lbl.Text = m.text:gsub(" %d+m$", "") .. " " .. math.floor((p - mp).Magnitude) .. "m"
                end
            end
        end
    end
    if accScan >= 3 then
        accScan = 0
        scan()
        -- Top 5 แพงสุดในแมพ (ตามเทียร์ที่เปิด)
        if CRYSTALS and CRYSTALS.Parent then
            local best = {}
            for _, c in ipairs(CRYSTALS:GetChildren()) do
                local t2 = c:GetAttribute("Tier")
                if t2 and TIER_ON[t2] then
                    best[#best + 1] = { v = c:GetAttribute("Value") or 0,
                        n = c:GetAttribute("CrystalName") or "?", s = c:GetAttribute("SizeClassName") or "" }
                end
            end
            table.sort(best, function(a, b) return a.v > b.v end)
            local lines = {}
            for i = 1, math.min(5, #best) do
                local e = best[i]
                lines[#lines + 1] = ("%d. %s%s %s"):format(i,
                    e.s ~= "Small" and ("[" .. e.s .. "] ") or "", e.n, fmtMoney(e.v))
            end
            topBox.Text = " TOP5:\n " .. table.concat(lines, "\n ")
        end
    end
end))

scan()
print("[75RB ItemESP v" .. V .. "] โหมด: " .. (CRYSTALS and "Crystal" or "Universal")
    .. " | เปิดเทียร์ 4-6 อยู่ กดปุ่ม T1-T6 ปรับได้")
