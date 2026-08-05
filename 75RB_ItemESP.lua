-- 75RB_ItemESP.lua v2.1 — ESP คริสตัล (เกมเหมืองแร่) + โหมด universal สำรอง
-- v2.12: เลิกทำท่าตกตอนบิน/วาป — ปิดสถานะ Freefall/FallingDown/Ragdoll ของ Humanoid
--        ตอนบิน (ยืนลอยนิ่งแบบ 74) แล้วคืนตอนปิดบิน
-- v2.11: วาป-แล้ว-เก็บเลย — ถึงก้อนรอ 0.4 วิ (ให้ server รับตำแหน่ง) แล้วยิง fp ซ้ำจนก้อนหาย
-- v2.10: กรองบ้านเพื่อนแบบชัวร์ (จาก HomeSpy) — ก้อนบ้านชื่อ 'Handle' ใต้ Things.Plots
--        และไม่มี prompt → กรอง: ไม่อยู่ใต้ Plots + ต้องมี ProximityPrompt เปิด (เก็บได้จริง)
-- v2.9: TOP5 กดได้ — แตะแถวไหนวาปบินไปลอยเหนือก้อนนั้นเลย (เปิดบินอัตโนมัติ)
--       + ตัดของวางบ้านเพื่อน (Placed_*) ออกจากการสแกนทั้งหมด
-- v2.8: ระบบโชค ☘ — ค่าโชคไม่อยู่ใน attr ต้องแกะจากป้าย CrystalHover ('Luck: +6.0%')
--       โชว์ ☘% ในป้าย ESP + ปุ่มเรียงวน 3 โหมด แพงสุด/ใกล้สุด/โชคสุด + TOP5 ตามโหมดเรียง
-- v2.7: บินเปลี่ยนเป็นแกนแบบ 74RB แท้ — ตรึงตำแหน่งด้วย CFrame ทุกเฟรม (แรงโน้มถ่วง/
--       แรงผลักทำอะไรไม่ได้ ลอยนิ่งสนิท) แต่บังคับเองด้วยจอย + ▲▼ | ทะลุกำแพงในตัว
-- v2.6: ปุ่ม "บิน" — บินทะลุกำแพงแบบ 74RB: จอยบังคับทิศ + ปุ่ม ▲▼ ขึ้นลง + noclip
-- v2.5: สแกนหาของห่วย — เลิกพึ่งโฟลเดอร์ Things.Crystals อย่างเดียว กวาดทั้ง workspace
--       ทุกรอบ (ก้อนอยู่โฟลเดอร์ไหนก็เจอ) + สถานะโชว์จำนวนแยกรายเทียร์ (เห็นว่าหลุดตรงไหน)
-- v2.4: สแกนกว้างขึ้น — หาโฟลเดอร์ Crystals ใหม่ทุกรอบ (เกมสร้างใหม่/วาร์ปโซนแล้วตัวเก่าชี้ที่ว่าง)
--       + ค้นทั้ง workspace หาของที่มี attr Tier (ไม่จำกัดแค่ Things.Crystals ชั้นแรก)
-- v2.3: ปุ่ม "โชว์: TOP5" — ติดป้ายเฉพาะ 5 ก้อนแพงสุดในแมพ (จอสะอาด)
-- v2.2: ระยะเก็บซิงก์กับ Assist อัตโนมัติ (_G.AS75_RANGE) — ปรับที่ Assist ที่เดียวพอ
-- v2.1: ก้อนใน "ระยะเก็บ" (ยิง fp ถึง) → สว่าง + ✅ หน้าชื่อ | ปุ่มปรับระยะเก็บ −/+
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

local V = "2.12"
local Players = game:GetService("Players")
local RunSvc  = game:GetService("RunService")
local LP      = Players.LocalPlayer
local MARKS   = _G.IESP75_MARKS

-- ==================== Config / State ====================
local MAX_SHOW   = 150            -- ป้ายพร้อมกันสูงสุด (กันเลค/จอแตก)
local TIER_ON    = { [1]=false, [2]=false, [3]=false, [4]=true, [5]=true, [6]=true }
local GIANT_ONLY = false          -- true = โชว์เฉพาะ SizeClass ~= Small
local SORT_MODE  = "val"          -- "val" แพงสุด | "dist" ใกล้สุด | "luck" โชคสุด
local REACH      = 25             -- ระยะเก็บ (ยิง fp ถึง) — ก้อนในระยะนี้สว่าง+✅
local TOP5_ONLY  = false          -- true = ติดป้ายเฉพาะ 5 ก้อนแพงสุด
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

-- หา "ก้อนคริสตัลทุกก้อน" สดๆ ทุกรอบ (อย่า cache โฟลเดอร์ — เกมสร้างใหม่/วาร์ปโซนแล้วชี้ที่ว่าง)
-- หลัก: Things.Crystals | สำรอง: ค้นทั้ง workspace หา BasePart ที่มี attr Tier+CrystalName
-- v2.5: กวาดทั้ง workspace ทุกรอบ — ก้อนอยู่โฟลเดอร์ไหน/โซนไหนก็เจอ (เกมย้าย path ได้)
-- v2.10 (จาก HomeSpy): ก้อนบ้านเพื่อนชื่อ "Handle" อยู่ใต้ Things.Plots.Slots.<ชื่อ>.PlacedCrystals
-- และ "ไม่มี ProximityPrompt" (เก็บไม่ได้ 0/8) ส่วนก้อนป่ามี prompt 1465/1467
-- → กรอง 2 ชั้น: ไม่อยู่ใต้ Plots + ต้องมี prompt เปิดอยู่ (= เก็บได้จริงเท่านั้น)
local function getCrystals()
    local out = {}
    for _, c in ipairs(workspace:GetDescendants()) do
        if c:IsA("BasePart") and c:GetAttribute("CrystalName") and c:GetAttribute("Tier")
            and not c:FindFirstAncestor("Plots") then
            local pp = c:FindFirstChildOfClass("ProximityPrompt")
            if pp and pp.Enabled then
                out[#out + 1] = c
            end
        end
    end
    return out
end
local CRYSTAL_GAME = #getCrystals() > 0 or (workspace:FindFirstChild("Things") ~= nil)

-- ค่าโชคไม่มีใน Attributes — อยู่เป็นข้อความในป้าย CrystalHover ('Luck: +6.0%')
-- แกะตัวเลขจาก TextLabel แล้ว cache ต่อก้อน (weak key — ก้อนหายแล้ว entry หายเอง)
local LUCK_CACHE = setmetatable({}, { __mode = "k" })
local function getLuck(c)
    local v = LUCK_CACHE[c]
    if v ~= nil then return v end
    v = 0
    local hover = c:FindFirstChild("CrystalHover")
    if hover then
        for _, l in ipairs(hover:GetDescendants()) do
            if l:IsA("TextLabel") then
                local n = l.Text:match("Luck:%s*%+?([%d%.]+)%%")
                if n then v = tonumber(n) or 0 break end
            end
        end
    end
    LUCK_CACHE[c] = v
    return v
end
local function fmtLuck(v)
    if v <= 0 then return "" end
    return " ☘" .. (v >= 1 and ("%.0f%%"):format(v) or ("%.2f%%"):format(v))
end

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
    local tierCount = { 0, 0, 0, 0, 0, 0 }   -- นับทั้งหมดก่อนกรอง (ดีบัก: เกมมีจริงกี่ก้อน)
    for _, c in ipairs(getCrystals()) do
        local tier = c:GetAttribute("Tier")
        if tier and tierCount[tier] then tierCount[tier] += 1 end
        if tier and TIER_ON[tier] then
            local sz = c:GetAttribute("SizeClassName") or "?"
            if not GIANT_ONLY or sz ~= "Small" then
                local p = partPos(c)
                if p then
                    list[#list + 1] = {
                        inst = c,
                        d = mp and (p - mp).Magnitude or 1e9,
                        luck = getLuck(c),
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
    if SORT_MODE == "luck" then
        table.sort(list, function(a, b) return a.luck > b.luck end)
    elseif SORT_MODE == "val" or TOP5_ONLY then
        table.sort(list, function(a, b) return a.val > b.val end)
    else
        table.sort(list, function(a, b) return a.d < b.d end)
    end
    local keep = {}
    for i = 1, math.min(TOP5_ONLY and 5 or MAX_SHOW, #list) do
        local e = list[i]
        keep[e.inst] = true
        local szTag = (e.sz ~= "Small") and ("[" .. e.sz .. "] ") or ""
        addMark(e.inst, ("%s%s %s%s %dm"):format(szTag, e.name, fmtMoney(e.val),
            fmtLuck(e.luck), math.floor(e.d)), e.col)
    end
    for inst in pairs(MARKS) do
        if not keep[inst] or not inst.Parent then removeMark(inst) end
    end
    if statusLbl then
        local total = 0
        for _, n in ipairs(tierCount) do total += n end
        statusLbl.Text = ("โชว์ %d/%d | ทั้งแมพ %d (T456: %d/%d/%d)"):format(
            math.min(TOP5_ONLY and 5 or MAX_SHOW, #list), #list, total,
            tierCount[4], tierCount[5], tierCount[6])
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
    if CRYSTAL_GAME then scanCrystals() else scanUniversal() end
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "ItemESP75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.IESP75_GUI = gui

local FULL_H, MIN_H = 336, 32
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
local SORT_ORDER = { "val", "dist", "luck" }
local SORT_LABEL = { val = "เรียง: แพงสุด", dist = "เรียง: ใกล้สุด", luck = "เรียง: ☘โชคสุด" }
sortB.MouseButton1Click:Connect(function()
    for i, m in ipairs(SORT_ORDER) do
        if m == SORT_MODE then
            SORT_MODE = SORT_ORDER[i % #SORT_ORDER + 1]
            break
        end
    end
    sortB.Text = SORT_LABEL[SORT_MODE]
    sortB.BackgroundColor3 = SORT_MODE == "luck" and Color3.fromRGB(40, 130, 70)
        or Color3.fromRGB(40, 90, 150)
    scan()
end)

local rescanB = Instance.new("TextButton", panel)
rescanB.Size = UDim2.new(0, 86, 0, 28); rescanB.Position = UDim2.new(0, 6, 0, 122)
rescanB.Text = "RESCAN"; rescanB.Font = Enum.Font.GothamBold; rescanB.TextSize = 13
rescanB.BackgroundColor3 = Color3.fromRGB(40, 130, 70); rescanB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", rescanB).CornerRadius = UDim.new(0, 5)
rescanB.MouseButton1Click:Connect(scan)

-- ระยะเก็บ − [25] + (ก้อนในระยะนี้ = ✅ สว่าง)
local reachL = Instance.new("TextLabel", panel)
reachL.Size = UDim2.new(0, 38, 0, 28); reachL.Position = UDim2.new(0, 124, 0, 122)
reachL.BackgroundTransparency = 1
reachL.Text = "✅25"
reachL.Font = Enum.Font.GothamBold; reachL.TextSize = 12
reachL.TextColor3 = Color3.fromRGB(120, 255, 160)
local function reachBtn(txt, x, delta)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 24, 0, 28); b.Position = UDim2.new(0, x, 0, 122)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 15
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 65); b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function()
        REACH = math.clamp(REACH + delta, 5, 300)
        reachL.Text = "✅" .. REACH
        if _G.AS75_RANGE then _G.AS75_RANGE = REACH end   -- ซิงก์กลับไป Assist ด้วย
    end)
end
reachBtn("−", 98, -5)
reachBtn("+", 162, 5)

-- ปุ่ม TOP5 only
local top5B = Instance.new("TextButton", panel)
top5B.Size = UDim2.new(0, 178, 0, 26); top5B.Position = UDim2.new(0, 6, 0, 154)
top5B.Text = "โชว์: ทั้งหมด (กด=TOP5)"; top5B.Font = Enum.Font.GothamBold; top5B.TextSize = 12
top5B.BackgroundColor3 = Color3.fromRGB(30, 30, 42); top5B.TextColor3 = Color3.fromRGB(110, 110, 125)
Instance.new("UICorner", top5B).CornerRadius = UDim.new(0, 5)
top5B.MouseButton1Click:Connect(function()
    TOP5_ONLY = not TOP5_ONLY
    top5B.Text = TOP5_ONLY and "โชว์: TOP5 แพงสุดเท่านั้น" or "โชว์: ทั้งหมด (กด=TOP5)"
    top5B.BackgroundColor3 = TOP5_ONLY and Color3.fromRGB(150, 110, 30) or Color3.fromRGB(30, 30, 42)
    top5B.TextColor3 = TOP5_ONLY and Color3.new(1, 1, 1) or Color3.fromRGB(110, 110, 125)
    scan()
end)

statusLbl = Instance.new("TextLabel", panel)
statusLbl.Size = UDim2.new(1, -12, 0, 16); statusLbl.Position = UDim2.new(0, 6, 0, 184)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "..."
statusLbl.Font = Enum.Font.Gotham; statusLbl.TextSize = 11
statusLbl.TextColor3 = Color3.fromRGB(130, 130, 150)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

-- TOP5 แบบกดได้ (v2.9) — แตะแถวไหน = เปิดบิน + วาปไปลอยเหนือก้อนนั้น
local warpTo   -- forward — นิยามจริงอยู่โซนบินด้านล่าง
local topHead = Instance.new("TextLabel", panel)
topHead.Size = UDim2.new(1, -12, 0, 13); topHead.Position = UDim2.new(0, 6, 0, 202)
topHead.BackgroundTransparency = 1
topHead.Text = "TOP5 แพง (แตะ = วาปไป):"
topHead.Font = Enum.Font.GothamBold; topHead.TextSize = 10
topHead.TextColor3 = Color3.fromRGB(255, 200, 90)
topHead.TextXAlignment = Enum.TextXAlignment.Left

local topRows, topTargets = {}, {}   -- Instance ยัด field เองไม่ได้ — เก็บ target แยกตาราง
for i = 1, 5 do
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(1, -12, 0, 15)
    b.Position = UDim2.new(0, 6, 0, 216 + (i - 1) * 16)
    b.Text = ""
    b.Font = Enum.Font.Code; b.TextSize = 10
    b.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    b.TextColor3 = Color3.fromRGB(190, 220, 190)
    b.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    topRows[i] = b
    b.MouseButton1Click:Connect(function()
        local t = topTargets[i]
        if t and t.Parent and warpTo then
            warpTo(t)
            b.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
            task.delay(0.6, function() b.BackgroundColor3 = Color3.fromRGB(8, 8, 12) end)
        end
    end)
end

-- ==================== บิน + ทะลุกำแพง (แบบ 74RB) ====================
-- จอย/WASD บังคับทิศ (อ่าน Humanoid.MoveDirection — ใช้ได้ทั้งมือถือ/คอม)
-- กดค้าง ▲/▼ = ขึ้น/ลง | noclip อัตโนมัติตอนบิน | ความเร็ว 60
local FLY_ON, UPIN = false, 0
local FLY_SPEED = 60
local FLY_POS = nil        -- ตำแหน่งตรึงแบบ 74RB — เขียน CFrame ทับทุกเฟรม

local flyB = Instance.new("TextButton", panel)
flyB.Size = UDim2.new(0, 86, 0, 28); flyB.Position = UDim2.new(0, 6, 0, 300)
flyB.Text = "บิน: OFF"; flyB.Font = Enum.Font.GothamBold; flyB.TextSize = 13
flyB.BackgroundColor3 = Color3.fromRGB(30, 30, 42); flyB.TextColor3 = Color3.fromRGB(110, 110, 125)
Instance.new("UICorner", flyB).CornerRadius = UDim.new(0, 5)

local function holdBtn(txt, x)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 42, 0, 28); b.Position = UDim2.new(0, x, 0, 300)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 15
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 65); b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local upB, downB = holdBtn("▲", 98), holdBtn("▼", 146)
upB.MouseButton1Down:Connect(function() UPIN = 1 end)
upB.MouseButton1Up:Connect(function() UPIN = 0 end)
downB.MouseButton1Down:Connect(function() UPIN = -1 end)
downB.MouseButton1Up:Connect(function() UPIN = 0 end)

local function setFly(on)
    FLY_ON = on
    UPIN = 0
    flyB.Text = "บิน: " .. (FLY_ON and "ON" or "OFF")
    flyB.BackgroundColor3 = FLY_ON and Color3.fromRGB(30, 120, 60) or Color3.fromRGB(30, 30, 42)
    flyB.TextColor3 = FLY_ON and Color3.new(1, 1, 1) or Color3.fromRGB(110, 110, 125)
    local char = LP.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    if FLY_ON then
        FLY_POS = r and r.Position or nil   -- เริ่มตรึงจากจุดที่ยืน
        -- v2.12: ปิดสถานะ "ตก" — Humanoid เห็นตัวลอยแล้วเล่นท่าดิ้น Freefall น่าเกลียด
        -- ปิดทิ้งตอนบิน = ยืนลอยนิ่งๆ แบบ 74 (วาปไกลก็ไม่ทำท่าตก)
        if h then
            h:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            h:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    else
        FLY_POS = nil
        if h then   -- คืนสถานะตกตอนปิด (ไม่งั้นเดินตกเหวแล้วลอยค้างท่ายืน)
            h:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
        if char then   -- คืน CanCollide ตอนปิด
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end
flyB.MouseButton1Click:Connect(function() setFly(not FLY_ON) end)

-- วาปไปก้อน (TOP5 กด) — เปิดบินก่อน (จะได้ลอยค้าง ไม่ร่วง) แล้วย้ายจุดตรึงไปเหนือก้อน 6 studs
-- v2.11: ถึงแล้วเก็บเองเลย — รอ 0.4 วิให้ server รับตำแหน่งใหม่ แล้วยิง fp ซ้ำจนก้อนหาย (สูงสุด 6 ครั้ง)
local fpr = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
warpTo = function(inst)
    local p = partPos(inst)
    if not p then return end
    if not FLY_ON then setFly(true) end
    FLY_POS = p + Vector3.new(0, 6, 0)
    if not fpr then return end
    task.spawn(function()
        task.wait(0.4)   -- ให้ replication ตำแหน่งใหม่ไปถึง server ก่อน ไม่งั้นโดนเช็คระยะปัด
        for _ = 1, 6 do
            if not inst.Parent then break end   -- หายจากแมพ = เก็บสำเร็จ
            local pp = inst:FindFirstChildOfClass("ProximityPrompt")
            if not pp then break end
            pp.HoldDuration = 0
            pcall(fpr, pp, 0)
            task.wait(0.5)
        end
    end)
end

-- แกนแบบ 74RB: คำนวณ FLY_POS จากจอย แล้ว "เขียน CFrame ทับ" ทุกเฟรม
-- → แรงโน้มถ่วง/แรงผลัก/ชนอะไรก็ไม่ขยับ (ตำแหน่งเป็นของเรา 100%) + ทะลุกำแพงในตัว
table.insert(_G.IESP75_CONNS, RunSvc.Heartbeat:Connect(function(dt)
    if not FLY_ON then return end
    local char = LP.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    if not r or not h then return end
    if not FLY_POS then FLY_POS = r.Position end
    -- noclip ทะลุกำแพง
    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    -- จอยดันทิศไหน = เลื่อนจุดตรึงทิศนั้น (dt-based ลื่นเท่ากันทุกเครื่อง)
    local mv = h.MoveDirection
    FLY_POS = FLY_POS + Vector3.new(mv.X, 0, mv.Z) * (FLY_SPEED * dt)
        + Vector3.new(0, UPIN * FLY_SPEED * dt, 0)
    r.CFrame = CFrame.new(FLY_POS) * (r.CFrame - r.CFrame.Position)   -- ตรึงตำแหน่ง คงการหัน
    r.AssemblyLinearVelocity = Vector3.zero
end))

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
                    local d = (p - mp).Magnitude
                    -- ซิงก์กับ Assist: ถ้า Assist รันอยู่ ใช้ระยะของมัน (ปรับที่เดียวพอ)
                    local r = _G.AS75_RANGE or REACH
                    if r ~= REACH then REACH = r; reachL.Text = "✅" .. REACH end
                    local inReach = d <= REACH
                    m.lbl.Text = (inReach and "✅" or "") .. m.text:gsub(" %d+m$", "")
                        .. " " .. math.floor(d) .. "m"
                    m.hl.FillTransparency = inReach and 0.1 or 0.6
                    m.tag.StudsOffset = Vector3.new(0, inReach and 4 or 3, 0)
                end
            end
        end
    end
    if accScan >= 3 then
        accScan = 0
        scan()
        -- Top 5 แพงสุดในแมพ (ตามเทียร์ที่เปิด)
        if CRYSTAL_GAME then
            local best = {}
            for _, c in ipairs(getCrystals()) do
                local t2 = c:GetAttribute("Tier")
                if t2 and TIER_ON[t2] then
                    best[#best + 1] = { inst = c, v = c:GetAttribute("Value") or 0, lk = getLuck(c),
                        n = c:GetAttribute("CrystalName") or "?", s = c:GetAttribute("SizeClassName") or "" }
                end
            end
            -- อันดับตามโหมดเรียง: โชคสุด → เรียงโชค | อื่นๆ → เรียงราคา
            if SORT_MODE == "luck" then
                table.sort(best, function(a, b) return a.lk > b.lk end)
            else
                table.sort(best, function(a, b) return a.v > b.v end)
            end
            topHead.Text = (SORT_MODE == "luck" and "TOP5 ☘โชค" or "TOP5 แพง") .. " (แตะ = วาปไป):"
            for i = 1, 5 do
                local e = best[i]
                topTargets[i] = e and e.inst or nil
                topRows[i].Text = e and (" %d. %s%s %s%s"):format(i,
                    e.s ~= "Small" and ("[" .. e.s .. "] ") or "", e.n, fmtMoney(e.v), fmtLuck(e.lk)) or ""
            end
        end
    end
end))

scan()
print("[75RB ItemESP v" .. V .. "] โหมด: " .. (CRYSTAL_GAME and "Crystal" or "Universal")
    .. " | เปิดเทียร์ 4-6 อยู่ กดปุ่ม T1-T6 ปรับได้")
