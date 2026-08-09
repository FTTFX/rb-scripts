-- 77RB_HouseClean_AutoFly.lua v1.0 — บิน+จับ+วางของอัตโนมัติ (เกม "ล้างบ้านขำๆ")
-- อ้างอิงผลจาก 77RB_HouseClean_NetSpy.lua v1.0 ที่ยืนยันแล้ว:
--   จับของ:  RemoteEvent:FireServer("pickupItem", <Part ของที่จะจับ>)
--   วางของ:  RemoteEvent:FireServer("placeCarried", <Part สล็อตที่จะวาง>, <Part ของที่ถือ>)
--   คู่ item/slot จับคู่ด้วยชื่อ: item="PictureFrame" ↔ slot="PictureFrameHome" (slot ชื่อขึ้นต้นด้วยชื่อ item)
--   โครงสร้าง: workspace.House_<N>.Items (ของกระจาย) / workspace.House_<N>.Slots (จุดวาง)
-- เพราะ RemoteEvent ที่ใช้จริงชื่อซ้ำกันได้หลายจุด (พาธเต็มไม่ยืนยัน) สคริปต์นี้ "เรียนรู้" ตัวจริงเอง 2 ทาง:
--   1) หาเอง: ถ้าเจอ RemoteEvent ชื่อ "RemoteEvent" ใน ReplicatedStorage แค่ตัวเดียว → ใช้ตัวนั้นเลย
--   2) เรียนรู้จากการเล่นจริง: ถ้าเจอมากกว่า 1 ตัว/หาไม่เจอ →ดัก __namecall รอจนกว่าเกมยิง
--      "pickupItem"/"placeCarried" เอง (ผู้ใช้จับ-วางของเอง 1 ครั้งก่อน) แล้วจำ instance ไว้อัตโนมัติ
-- ปุ่ม: FLY (บินอิสระ WASD+Space/Ctrl) | AUTO (บิน+จับ+วางของทั้งหมดอัตโนมัติ) | STOP | ✕
if _G.AF77_GUI then pcall(function() _G.AF77_GUI:Destroy() end) end
if _G.AF77_CONNS then
    for _, c in ipairs(_G.AF77_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.AF77_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local FLY_ON, AUTO_ON = false, false
local FLY_SPEED = 60
local learnedRemote = nil
local statusText = "รอเริ่ม..."

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFly77"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.AF77_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 260, 0, 150); frame.Position = UDim2.new(0, 8, 0.2, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.2
frame.Active = true; frame.Draggable = true

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -8, 0, 40); status.Position = UDim2.new(0, 4, 0, 4)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(180, 255, 180)
status.TextSize = 12; status.Font = Enum.Font.Code; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.TextYAlignment = Enum.TextYAlignment.Top
local function setStatus(s) statusText = s; status.Text = s end

local function mkbtn(txt, y, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, -8, 0, 26); b.Position = UDim2.new(0, 4, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local flyB   = mkbtn("FLY: OFF (บินอิสระ WASD+Space/Ctrl)", 48, Color3.fromRGB(40, 90, 150))
local autoB  = mkbtn("AUTO: OFF (จับ-วางของทั้งหมด)", 78, Color3.fromRGB(40, 130, 70))
local stopB  = mkbtn("STOP ทั้งหมด", 108, Color3.fromRGB(150, 60, 30))
local closeB = mkbtn("✕ ปิด", 138, Color3.fromRGB(90, 40, 40))
frame.Size = UDim2.new(0, 260, 0, 170)

setStatus("[AutoFly77] พร้อม — กด FLY เพื่อบินอิสระ หรือ AUTO เพื่อจับ-วางของอัตโนมัติ")

-- ==================== หา RemoteEvent ที่ใช้จริง ====================
local function tryAutoFindRemote()
    local candidates = {}
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") and d.Name == "RemoteEvent" then
            candidates[#candidates + 1] = d
        end
    end
    if #candidates == 1 then
        learnedRemote = candidates[1]
        setStatus("[AutoFly77] เจอ RemoteEvent อัตโนมัติ: " .. learnedRemote:GetFullName())
        return true
    end
    return false
end

local function hookLearn()
    if not hookmetamethod then
        setStatus("[AutoFly77] ❌ ไม่มี hookmetamethod — เรียนรู้ remote อัตโนมัติไม่ได้")
        return
    end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not learnedRemote then
            local method = getnamecallmethod()
            if method == "FireServer" then
                local args = { ... }
                if args[1] == "pickupItem" or args[1] == "placeCarried" then
                    learnedRemote = self
                    setStatus("[AutoFly77] ✅ เรียนรู้ remote จากการเล่นจริง: " .. self:GetFullName())
                end
            end
        end
        return old(self, ...)
    end)
end

-- ==================== หาห้อง/ของ/สล็อต ====================
local function findHouses()
    local out = {}
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("Model") and c:FindFirstChild("Items") and c:FindFirstChild("Slots") then
            out[#out + 1] = c
        end
    end
    return out
end

local function findSlotFor(item, slotsFolder)
    for _, s in ipairs(slotsFolder:GetChildren()) do
        if s.Name:sub(1, #item.Name) == item.Name then
            return s
        end
    end
    return nil
end

local function partPosition(inst)
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart.Position end
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok then return cf.Position end
    end
    return nil
end

-- ==================== บิน (ย้าย HumanoidRootPart ไปจุดหมายแบบนุ่มๆ) ====================
local function flyTo(targetPos, timeoutSec)
    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local t0 = tick()
    while tick() - t0 < (timeoutSec or 6) do
        if not AUTO_ON then return false end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local cur = hrp.Position
        local dist = (targetPos - cur).Magnitude
        if dist < 4 then return true end
        local dir = (targetPos - cur).Unit
        hrp.CFrame = CFrame.new(cur + dir * math.min(FLY_SPEED * RunService.Heartbeat:Wait(), dist), targetPos)
    end
    return true
end

-- ==================== AUTO: สแกนของทั้งหมดก่อน แล้วบินเก็บ-วางทีละชิ้นจนครบ แล้วจบ ====================
local function scanAllItems()
    local list = {}
    for _, house in ipairs(findHouses()) do
        local itemsF, slotsF = house.Items, house.Slots
        for _, item in ipairs(itemsF:GetChildren()) do
            local slot = findSlotFor(item, slotsF)
            if slot then
                list[#list + 1] = { item = item, slot = slot }
            end
        end
    end
    return list
end

local function runAuto()
    if not learnedRemote then
        if not tryAutoFindRemote() then
            setStatus("[AutoFly77] ⚠️ ยังไม่รู้ remote — ลองจับ-วางของเอง 1 ครั้งก่อน (สคริปต์กำลังดักเรียนรู้อยู่)")
            local t0 = tick()
            while AUTO_ON and not learnedRemote and tick() - t0 < 30 do task.wait(0.5) end
            if not learnedRemote then
                setStatus("[AutoFly77] ❌ หา remote ไม่เจอ ยกเลิก AUTO")
                AUTO_ON = false
                autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
                return
            end
        end
    end

    if #findHouses() == 0 then
        setStatus("[AutoFly77] ❌ ไม่เจอ House ที่มี Items/Slots ใน workspace — ยกเลิก")
        AUTO_ON = false
        autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
        return
    end

    setStatus("[AutoFly77] 🔍 กำลังสแกนหาของทั้งหมด...")
    local queue = scanAllItems()
    if #queue == 0 then
        setStatus("[AutoFly77] ไม่พบของที่ต้องเก็บ (อาจวางครบแล้ว) — จบ")
        AUTO_ON = false
        autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
        return
    end
    setStatus(("[AutoFly77] พบของ %d ชิ้น — เริ่มบินเก็บ-วางทีละชิ้น"):format(#queue))

    local processed, failed = 0, 0
    for i, pair in ipairs(queue) do
        if not AUTO_ON then break end
        local item, slot = pair.item, pair.slot
        if item.Parent and slot.Parent then
            setStatus(("[AutoFly77] (%d/%d) กำลังบินไปเก็บ: %s"):format(i, #queue, item.Name))
            local ipos = partPosition(item)
            if ipos then flyTo(ipos, 6) end
            local ok1 = pcall(function() learnedRemote:FireServer("pickupItem", item) end)
            task.wait(0.3)

            setStatus(("[AutoFly77] (%d/%d) กำลังบินไปวาง: %s"):format(i, #queue, item.Name))
            local spos = partPosition(slot)
            if spos then flyTo(spos, 6) end
            local ok2 = pcall(function() learnedRemote:FireServer("placeCarried", slot, item) end)
            task.wait(0.3)

            if ok1 and ok2 then processed += 1 else failed += 1 end
        else
            failed += 1
        end
    end

    setStatus(("[AutoFly77] ✅ จบแล้ว! เก็บ-วางสำเร็จ %d ชิ้น, พลาด %d ชิ้น"):format(processed, failed))
    AUTO_ON = false
    autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
end

-- ==================== FLY: บินอิสระด้วย WASD + Space/Ctrl ====================
local flyConn
local function startFly()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.Name = "AF77_FlyVel"
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.new()
    bv.Parent = hrp
    flyConn = RunService.Heartbeat:Connect(function()
        if not FLY_ON then return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.new()
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        bv.Velocity = dir * FLY_SPEED
    end)
    table.insert(_G.AF77_CONNS, flyConn)
end
local function stopFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            local bv = hrp:FindFirstChild("AF77_FlyVel")
            if bv then bv:Destroy() end
        end
    end
end

-- ==================== Buttons ====================
flyB.MouseButton1Click:Connect(function()
    FLY_ON = not FLY_ON
    flyB.Text = FLY_ON and "FLY: ON (WASD+Space/Ctrl)" or "FLY: OFF (บินอิสระ WASD+Space/Ctrl)"
    if FLY_ON then startFly() else stopFly() end
end)
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    autoB.Text = AUTO_ON and "AUTO: ON (กำลังทำงาน...)" or "AUTO: OFF (จับ-วางของทั้งหมด)"
    if AUTO_ON then task.spawn(runAuto) end
end)
stopB.MouseButton1Click:Connect(function()
    FLY_ON, AUTO_ON = false, false
    flyB.Text = "FLY: OFF (บินอิสระ WASD+Space/Ctrl)"
    autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
    stopFly()
    setStatus("[AutoFly77] หยุดทั้งหมดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    FLY_ON, AUTO_ON = false, false
    stopFly()
    for _, c in ipairs(_G.AF77_CONNS) do pcall(function() c:Disconnect() end) end
    _G.AF77_CONNS = {}
    gui:Destroy(); _G.AF77_GUI = nil
end)

-- ==================== Setup ====================
hookLearn()
tryAutoFindRemote()
warn("[AutoFly77] loaded")
