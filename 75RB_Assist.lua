-- 75RB_Assist.lua v1.1 — ระบบช่วยเกมคริสตัล: เก็บอัตโนมัติด้วย fireproximityprompt
-- v1.8: "กดค้างไม่นานพอ" — กดเกินเวลา +0.6 วิก่อนปล่อย (ปล่อยเป๊ะเกินไป engine นับไม่ถึง)
--       + ก้อนที่โดนตัวเก่าตั้ง Hold=0 ทับ → กดยังไงก็ trigger ทันที server เท → ข้ามยาว 10 นาที
-- v1.7: (PickSpy) server จับเวลากดค้าง — fp Hold=0 โดนปัด! → กดค้างจริงด้วย
--       InputHoldBegin → รอครบ HoldDuration → InputHoldEnd (server แยกไม่ออกจากนิ้วกด)
-- v1.6: กรองบ้านเพื่อนชัวร์ (HomeSpy): ไม่อยู่ใต้ Plots + ต้องมี prompt เปิด
-- v1.5: ตัดของวางบ้านเพื่อน (Placed_*) ออก — ไม่ยิง fp ใส่ของตกแต่งคนอื่น
-- v1.4: กวาดทั้ง workspace เสมอ (ก้อนอยู่ path ไหนก็เจอ)
-- v1.3: หาก้อนคริสตัลสดทุกรอบ (ไม่ cache โฟลเดอร์ — วาร์ปโซนแล้วชี้ที่ว่าง) + ค้นลึกทุกชั้น
-- v1.2: ซิงก์ระยะกับ ItemESP ผ่าน _G.AS75_RANGE — ปรับที่ Assist ตัวเดียว ESP ✅ ตามทันที
-- v1.1: ก้อนที่ ❌ พักไว้ 8 วิ (เลิกยิงก้อนเดิมซ้ำ — ไปเก็บก้อนถัดไปแทน)
--       + วัดเพดานระยะอัตโนมัติ: จำ ✅ไกลสุด / ❌ใกล้สุด โชว์ตลอด
-- จากสปาย: เก็บของ = ProximityPrompt ล้วน (ไม่มี remote) → ยิง fp ใส่ก้อนที่ "แพงสุดในระยะ"
-- ฟีเจอร์: AUTO เก็บ ON/OFF | ระยะปรับได้ −/+ (10-500) | เทียร์ขั้นต่ำ T1-T6 | Giant only
--   Hold bypass (ก้อน Mythic ต้องกดค้าง 5 วิ → เราตั้ง Hold=0 เก็บทันที)
--   สถิติ: เก็บกี่ก้อน / มูลค่ารวม / น้ำหนักรวม + ผลยิงล่าสุด (ไว้หาเพดานระยะ)
if _G.AS75_CONNS then
    for _, c in pairs(_G.AS75_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.AS75_GUI then pcall(function() _G.AS75_GUI:Destroy() end) end
_G.AS75_CONNS = {}

local V = "1.8"
local Players = game:GetService("Players")
local RunSvc  = game:GetService("RunService")
local LP      = Players.LocalPlayer
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

-- หาก้อนคริสตัลสดทุกรอบ (เหมือน ItemESP v2.4)
local function getCrystals()
    -- v1.4: กวาดทั้ง workspace เสมอ (เหมือน ItemESP v2.5) — ก้อนอยู่ path ไหนก็เจอ
    -- v1.6 (จาก HomeSpy): ก้อนบ้านเพื่อน = 'Handle' ใต้ Things.Plots + ไม่มี prompt
    -- → กรอง: ไม่อยู่ใต้ Plots + ต้องมี prompt เปิด (เก็บได้จริงเท่านั้น)
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

-- ==================== State ====================
local AUTO_ON   = false
local RANGE     = 25
_G.AS75_RANGE   = RANGE   -- ItemESP อ่านค่านี้ไปวาด ✅
local MIN_TIER  = 4
local GIANT_ONLY = false
local statPick, statVal, statKg = 0, 0, 0
local pending   = nil    -- {inst=, name=, val=, kg=, d=, t=} รอเช็คว่าหายจากแมพ = เก็บสำเร็จ
local pendT     = 0
local FAILED    = {}     -- [inst] = os.clock() หมดโทษ — ก้อนที่ยิงไม่เข้า พัก 8 วิ
local maxOK, minFail = nil, nil   -- วัดเพดานระยะ server

local function myPos()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return r and r.Position
end
local function fmtMoney(v)
    if v >= 1e6 then return ("$%.1fM"):format(v / 1e6) end
    if v >= 1e3 then return ("$%.0fK"):format(v / 1e3) end
    return "$" .. math.floor(v)
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "Assist75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.AS75_GUI = gui

local FULL_H, MIN_H = 250, 32
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 200, 0, FULL_H)
panel.Position = UDim2.new(0, 10, 0.55, 0)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
panel.BorderSizePixel = 0
panel.Active, panel.Draggable = true, true
panel.ClipsDescendants = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -70, 0, 28); title.Position = UDim2.new(0, 8, 0, 2)
title.BackgroundTransparency = 1
title.Text = "Assist v" .. V
title.Font = Enum.Font.GothamBold; title.TextSize = 14
title.TextColor3 = Color3.fromRGB(120, 255, 160)
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

local autoB = Instance.new("TextButton", panel)
autoB.Size = UDim2.new(0, 188, 0, 32); autoB.Position = UDim2.new(0, 6, 0, 32)
autoB.Text = "AUTO เก็บ: OFF"; autoB.Font = Enum.Font.GothamBold; autoB.TextSize = 14
autoB.BackgroundColor3 = Color3.fromRGB(40, 60, 40); autoB.TextColor3 = Color3.fromRGB(150, 150, 150)
Instance.new("UICorner", autoB).CornerRadius = UDim.new(0, 5)
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    autoB.Text = "AUTO เก็บ: " .. (AUTO_ON and "ON" or "OFF")
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(30, 120, 30) or Color3.fromRGB(40, 60, 40)
    autoB.TextColor3 = AUTO_ON and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)
end)

-- ระยะ − [50] +
local rangeL = Instance.new("TextLabel", panel)
rangeL.Size = UDim2.new(0, 90, 0, 26); rangeL.Position = UDim2.new(0, 40, 0, 68)
rangeL.BackgroundTransparency = 1
rangeL.Text = "ระยะ 25"
rangeL.Font = Enum.Font.GothamBold; rangeL.TextSize = 13
rangeL.TextColor3 = Color3.fromRGB(200, 200, 220)
local function rbtn(txt, x, delta)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 30, 0, 26); b.Position = UDim2.new(0, x, 0, 68)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 16
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 65); b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function()
        RANGE = math.clamp(RANGE + delta, 10, 500)
        rangeL.Text = "ระยะ " .. RANGE
        _G.AS75_RANGE = RANGE
    end)
end
rbtn("−", 6, -10)
rbtn("+", 134, 10)

-- เทียร์ขั้นต่ำ + Giant
local tierB = Instance.new("TextButton", panel)
tierB.Size = UDim2.new(0, 92, 0, 26); tierB.Position = UDim2.new(0, 6, 0, 98)
tierB.Text = "เทียร์ ≥ T4"; tierB.Font = Enum.Font.GothamBold; tierB.TextSize = 12
tierB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); tierB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", tierB).CornerRadius = UDim.new(0, 5)
tierB.MouseButton1Click:Connect(function()
    MIN_TIER = MIN_TIER % 6 + 1
    tierB.Text = "เทียร์ ≥ T" .. MIN_TIER
end)

local giantB = Instance.new("TextButton", panel)
giantB.Size = UDim2.new(0, 92, 0, 26); giantB.Position = UDim2.new(0, 102, 0, 98)
giantB.Text = "Giant: OFF"; giantB.Font = Enum.Font.GothamBold; giantB.TextSize = 12
giantB.BackgroundColor3 = Color3.fromRGB(30, 30, 42); giantB.TextColor3 = Color3.fromRGB(110, 110, 125)
Instance.new("UICorner", giantB).CornerRadius = UDim.new(0, 5)
giantB.MouseButton1Click:Connect(function()
    GIANT_ONLY = not GIANT_ONLY
    giantB.Text = "Giant: " .. (GIANT_ONLY and "ON" or "OFF")
    giantB.BackgroundColor3 = GIANT_ONLY and Color3.fromRGB(150, 110, 30) or Color3.fromRGB(30, 30, 42)
    giantB.TextColor3 = GIANT_ONLY and Color3.new(1, 1, 1) or Color3.fromRGB(110, 110, 125)
end)

local statL = Instance.new("TextLabel", panel)
statL.Size = UDim2.new(1, -12, 0, 60); statL.Position = UDim2.new(0, 6, 0, 130)
statL.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
statL.Text = " เก็บ 0 ก้อน | $0 | 0kg"
statL.Font = Enum.Font.Code; statL.TextSize = 11
statL.TextColor3 = Color3.fromRGB(190, 220, 190)
statL.TextXAlignment = Enum.TextXAlignment.Left
statL.TextYAlignment = Enum.TextYAlignment.Top
statL.TextWrapped = true
Instance.new("UICorner", statL).CornerRadius = UDim.new(0, 5)

local lastL = Instance.new("TextLabel", panel)
lastL.Size = UDim2.new(1, -12, 0, 48); lastL.Position = UDim2.new(0, 6, 0, 196)
lastL.BackgroundTransparency = 1
lastL.Text = "ล่าสุด: -"
lastL.Font = Enum.Font.Gotham; lastL.TextSize = 10
lastL.TextColor3 = Color3.fromRGB(130, 130, 150)
lastL.TextXAlignment = Enum.TextXAlignment.Left
lastL.TextYAlignment = Enum.TextYAlignment.Top
lastL.TextWrapped = true

local folded = false
foldB.MouseButton1Click:Connect(function()
    folded = not folded
    panel.Size = UDim2.new(0, 200, 0, folded and MIN_H or FULL_H)
end)
closeB.MouseButton1Click:Connect(function()
    for _, c in pairs(_G.AS75_CONNS) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.AS75_GUI, _G.AS75_CONNS = nil, {}
end)

local function updStat()
    statL.Text = (" เก็บ %d ก้อน | %s | %.1fkg"):format(statPick, fmtMoney(statVal), statKg)
end

-- ==================== Auto loop ====================
-- ทุก 0.5s: เลือกก้อน "แพงสุด" ในระยะ (ผ่านฟิลเตอร์) → Hold=0 + fp → รอ 1.2s เช็คว่าก้อนหาย
-- ก้อนหาย = เก็บสำเร็จ (นับสถิติ) | ยังอยู่ = ล้มเหลว (โชว์ระยะไว้หาเพดาน)
local acc = 0
table.insert(_G.AS75_CONNS, RunSvc.Heartbeat:Connect(function(dt)
    if not AUTO_ON then return end
    acc += dt
    -- เช็คผลก้อนที่ยิงไปแล้ว
    if pending then
        pendT += dt
        if not pending.inst.Parent then
            statPick += 1; statVal += pending.val; statKg += pending.kg
            updStat()
            if not maxOK or pending.d > maxOK then maxOK = pending.d end
            lastL.Text = ("✅ %s %s @%dm | เพดาน: ✅%s ❌%s"):format(pending.name,
                fmtMoney(pending.val), pending.d, tostring(maxOK), tostring(minFail or "-"))
            pending = nil
        elseif pendT > 1.2 then
            FAILED[pending.inst] = os.clock() + 8
            if not minFail or pending.d < minFail then minFail = pending.d end
            lastL.Text = ("❌ %s @%dm | เพดาน: ✅%s ❌%s"):format(pending.name,
                pending.d, tostring(maxOK or "-"), tostring(minFail))
            pending = nil
        end
        return   -- รอผลก่อนค่อยยิงก้อนถัดไป (กันยิงรัว)
    end
    if acc < 0.5 then return end
    acc = 0
    local mp = myPos()
    if not mp then return end   -- v1.7: ไม่ต้องพึ่ง fp แล้ว (ใช้ InputHoldBegin/End แทน)
    -- ซิงก์สองทาง: ItemESP อาจปรับ _G.AS75_RANGE มา
    if _G.AS75_RANGE and _G.AS75_RANGE ~= RANGE then
        RANGE = _G.AS75_RANGE
        rangeL.Text = "ระยะ " .. RANGE
    end
    local best, bd
    for _, c in ipairs(getCrystals()) do
        local tier = c:GetAttribute("Tier")
        if tier and tier >= MIN_TIER then
            local sz = c:GetAttribute("SizeClassName") or "Small"
            if not GIANT_ONLY or sz ~= "Small" then
                local d = (c.Position - mp).Magnitude
                if d <= RANGE and (not FAILED[c] or os.clock() > FAILED[c]) then
                    local v = c:GetAttribute("Value") or 0
                    if not best or v > (best:GetAttribute("Value") or 0) then best, bd = c, d end
                end
            end
        end
    end
    if not best then return end
    local pp = best:FindFirstChildOfClass("ProximityPrompt")
    if not pp then return end
    -- v1.7 (จาก PickSpy): server จับเวลาช่วงกดค้าง — fp Hold=0 โดนปัดเกือบหมด
    -- → กดค้างแบบถูกกติกาผ่าน InputHoldBegin → รอครบ HoldDuration → InputHoldEnd
    --   engine trigger เองเหมือนนิ้วกดจริง server แยกไม่ออก
    local hold = pp.HoldDuration
    if hold <= 0.05 then
        -- ก้อนที่โดนตัวเก่า (≤v1.6) ตั้ง Hold=0 ทับไว้ — กดค้างยังไง engine ก็ trigger ทันที
        -- server เทตลอด → ข้ามยาวเลย (เดี๋ยวก้อนใหม่ spawn มา Hold ปกติ)
        FAILED[best] = os.clock() + 600
        lastL.Text = ("⚠️ %s Hold=0 (โดนตัวเก่าแก้ค่า) ข้ามถาวร"):format(
            best:GetAttribute("CrystalName") or best.Name)
        return
    end
    pending = {
        inst = best, d = math.floor(bd),
        name = best:GetAttribute("CrystalName") or best.Name,
        val = best:GetAttribute("Value") or 0,
        kg = best:GetAttribute("WeightKg") or 0,
    }
    pendT = -(hold + 1.0)   -- นับ timeout 1.2s "หลัง" กดครบ (ไม่ตัดสินระหว่างยังกดอยู่)
    lastL.Text = ("⏳ กดค้าง %s %.1f วิ..."):format(pending.name, hold)
    task.spawn(function()
        -- v1.7b: กดเกินเวลาไว้ 0.6 วิ — ปล่อยเป๊ะเกิน engine นับไม่ถึงเส้น = ไม่ trigger
        -- (Triggered เด้งเองตอนครบเวลาแม้ยังกดอยู่ — ปล่อยช้าไม่เสียอะไร)
        pcall(function() pp:InputHoldBegin() end)
        task.wait(hold + 0.6)
        pcall(function() pp:InputHoldEnd() end)
    end)
end))

updStat()
print("[75RB Assist v" .. V .. "] โหมดกดค้างจริง (InputHoldBegin/End)"
    .. " | ระยะ prompt จริง ~9-16m — ตั้งระยะ ≤15 ผลดีสุด")
