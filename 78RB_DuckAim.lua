-- 78RB_DuckAim.lua v5.1 — AUTO SHOOT ยิงครบ 2 remote + counter (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.0: DuckSpy พิสูจน์ว่า 1 นัด = 2 remote — A(origin,dir,counter,ts) + B(counter) counter เดินหน้า
--   ทุกนัด (4,5,6,...) v4.0 ยิง remote เดียว+เลขคงที่เลยไม่ติด → เรียนทั้ง 2 remote, counter เดินหน้า
-- v5.1: log ยืนยัน origin ขยับตามตัวผู้เล่นตอนเดิน (831→832→814...) → ใช้ตำแหน่งกล้องปัจจุบันเป็น origin
-- v4.0: เพิ่ม AUTO SHOOT (คีย์ K) — เรียนปืนแบบ "แอบดูไม่แก้ไข": hook __namecall อ่าน args ตอนผู้เล่น
--   ยิงเองจริง 1 นัด เพื่อจำ remote + รูปแบบคำสั่ง (ไม่แก้ค่า ไม่พังการรีโหลดแบบ SILENT เดิม) แล้วยิง
--   ซ้ำเองใส่เป็ดตามโหมด TARGET ทุก 0.12 วิ (อัปเดต timestamp ด้วย GetServerTimeNow กันโดนปฏิเสธ)
-- v3.1: TARGET เพิ่มโหมดที่ 4 เลือดเยอะสุด — อ่าน Humanoid.Health ก่อน ไม่มีค่อยหา attribute/Value
--   ชื่อพ้อง hp/health บนโมเดลเป็ด (บอสเลือดหนา = โดนล็อคก่อน)
-- v3.0: ถอด SILENT ออกทั้งระบบ — ตัวดัก FireServer ไปโดนคำสั่งรีโหลดกระสุนด้วย (ลายเซ็น args ชนกัน)
--   ทำให้รีโหลดไม่ได้ เหลือ AIM ล็อคกล้องอย่างเดียว ปลอดภัยไม่แตะ remote ใดๆ + กด L เปิด/ปิด AIM
-- เป้า = ทุกโมเดลในโฟลเดอร์ workspace.Ume (เป็ดปกติ DuckController_Client_N + บอสชื่ออื่น)
-- ปุ่ม: AIM (คีย์ลัด L) | TARGET (ใกล้สุด/ไม่มีอะไรบัง/คะแนนเยอะสุด) | STOP | ✕
if _G.DA78_GUI then pcall(function() _G.DA78_GUI:Destroy() end) end
if _G.DA78_CONNS then
    for _, c in ipairs(_G.DA78_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.DA78_CONNS = {}
_G.DA78_GEN = (_G.DA78_GEN or 0) + 1
local MY_GEN = _G.DA78_GEN

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local AIM_ON = false
local SMOOTH = 0.35

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DuckAim78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.DA78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 250, 0, 200); frame.Position = UDim2.new(0, 8, 0.3, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.2
frame.Active = true; frame.Draggable = true

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -8, 0, 40); status.Position = UDim2.new(0, 4, 0, 4)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(255, 220, 150)
status.TextSize = 12; status.Font = Enum.Font.Code; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.TextYAlignment = Enum.TextYAlignment.Top
local function setStatus(s) status.Text = s end

local function mkbtn(txt, y, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, -8, 0, 26); b.Position = UDim2.new(0, 4, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local aimB    = mkbtn("AIM: OFF (คีย์ลัด L)", 48, Color3.fromRGB(190, 60, 60))
local shootB  = mkbtn("AUTO SHOOT: OFF (คีย์ K)", 78, Color3.fromRGB(60, 170, 90))
local targetB = mkbtn("TARGET: ไม่มีอะไรบัง", 108, Color3.fromRGB(60, 110, 180))
local stopB   = mkbtn("STOP", 138, Color3.fromRGB(150, 60, 30))
local closeB  = mkbtn("✕ ปิด", 168, Color3.fromRGB(90, 40, 40))
frame.Size = UDim2.new(0, 250, 0, 200)

setStatus("[DuckAim78] พร้อม — ยิงเอง 1 นัดให้จำปืน แล้วกด K ยิงออโต้")

-- ==================== หาเป็ด ====================
local function duckFolder()
    return workspace:FindFirstChild("Ume")
end

local function duckPos(m)
    local p = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end

local function allDucks()
    local out = {}
    local f = duckFolder()
    if not f then return out end
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") then
            local p = duckPos(m)
            if p then out[#out + 1] = { model = m, pos = p } end
        end
    end
    return out
end

-- ==================== เกณฑ์เลือกเป้า: ใกล้สุด / ไม่มีอะไรบัง / คะแนนเยอะสุด ====================
local TARGET_MODES = { "ใกล้สุด", "ไม่มีอะไรบัง", "คะแนนเยอะสุด", "เลือดเยอะสุด" }
local targetModeIdx = 2

-- v3.1: อ่าน HP ของเป็ด — Humanoid.Health ก่อน แล้วค่อย attribute/Value ชื่อพ้อง hp/health/เลือด
local function duckHP(d)
    local hum = d.model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health end
    for k, v in pairs(d.model:GetAttributes()) do
        if type(v) == "number" and k:lower():find("h[pe]") then return v end
    end
    for _, c in ipairs(d.model:GetDescendants()) do
        if (c:IsA("IntValue") or c:IsA("NumberValue")) and c.Name:lower():find("h[pe]") then
            return c.Value
        end
    end
    return 0
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function duckVisible(origin, d)
    rayParams.FilterDescendantsInstances = { LP.Character, duckFolder() }
    local hit = workspace:Raycast(origin, d.pos - origin, rayParams)
    return hit == nil
end

local function duckScore(d)
    local best = 0
    for _, v in pairs(d.model:GetAttributes()) do
        if type(v) == "number" and v > best then best = v end
    end
    for _, c in ipairs(d.model:GetDescendants()) do
        if (c:IsA("IntValue") or c:IsA("NumberValue")) and c.Value > best then best = c.Value end
    end
    return best
end

local function pickDuck(origin)
    local ducks = allDucks()
    if #ducks == 0 then return nil end
    local mode = TARGET_MODES[targetModeIdx]

    if mode == "คะแนนเยอะสุด" then
        local best, bestScore = nil, -1
        for _, d in ipairs(ducks) do
            local s = duckScore(d)
            if s > bestScore then best, bestScore = d, s end
        end
        return best
    end

    if mode == "เลือดเยอะสุด" then
        local best, bestHP = nil, -1
        for _, d in ipairs(ducks) do
            local hp = duckHP(d)
            if hp > bestHP then best, bestHP = d, hp end
        end
        return best
    end

    if mode == "ไม่มีอะไรบัง" then
        local best, bestDist = nil, math.huge
        for _, d in ipairs(ducks) do
            if duckVisible(origin, d) then
                local dist = (d.pos - origin).Magnitude
                if dist < bestDist then best, bestDist = d, dist end
            end
        end
        if best then return best end
    end

    local best, bestDist = nil, math.huge
    for _, d in ipairs(ducks) do
        local dist = (d.pos - origin).Magnitude
        if dist < bestDist then best, bestDist = d, dist end
    end
    return best
end

-- ==================== ลูปล็อคกล้อง ====================
local aimConn
local function aimStop()
    AIM_ON = false
    if aimConn then aimConn:Disconnect() aimConn = nil end
    aimB.Text = "AIM: OFF (คีย์ลัด L)"
end
local function aimStart()
    AIM_ON = true
    aimB.Text = "AIM: ON (กล้องตามเป็ด — กด L ปิด)"
    aimConn = RunService.RenderStepped:Connect(function()
        if not AIM_ON or _G.DA78_GEN ~= MY_GEN then return end
        local d = pickDuck(Camera.CFrame.Position)
        if d and d.model.Parent then
            local p = duckPos(d.model)
            if p then
                local camCF = Camera.CFrame
                Camera.CFrame = camCF:Lerp(CFrame.new(camCF.Position, p), SMOOTH)
                setStatus(("[DuckAim78] 🎯 ล็อค: %s"):format(d.model.Name))
            end
        else
            setStatus("[DuckAim78] ไม่เจอเป้า — รอเป็ดโผล่")
        end
    end)
    table.insert(_G.DA78_CONNS, aimConn)
end
local function aimToggle()
    if AIM_ON then aimStop() else aimStart() end
end

-- ==================== AUTO SHOOT — เรียนปืนแบบ "แอบดูไม่แก้ไข" (ไม่พังการรีโหลด) ====================
-- ต่างจาก SILENT เดิม: hook นี้แค่ "อ่าน" args ตอนผู้เล่นยิงจริง เพื่อจำ remote + รูปแบบคำสั่ง
-- ไม่แก้ค่าใดๆ (return old(self, ...) เดิมทุกครั้ง) → คำสั่งรีโหลด/อื่นๆ ไม่ถูกแตะเลย
-- v5.0 จาก DuckSpy log: ยิง 1 นัด = 2 remote
--   A(aimRemote):  FireServer(Vector3 origin(คงที่ 780,68,104), Vector3 dir(ตามกล้อง), counter, timestamp)
--   B(fireRemote): FireServer(counter)   ← counter เดียวกัน เดินหน้าทุกนัด (4,5,6,...)
local SHOOT_ON = false
local aimRemote, fireRemote          -- 2 remote
local shotOrigin                     -- origin คงที่จากนัดจริง (780,68,104)
local shotCounter = 0                -- ตัวนับนัด — เดินหน้าต่อจากที่เห็นล่าสุด
local FIRE_INTERVAL = 0.5

-- ห่อ pcall กัน executor ที่ hook __namecall ซ้ำแล้ว error จน GUI ไม่ขึ้น
pcall(function()
if hookmetamethod and getnamecallmethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        pcall(function()
            if _G.DA78_GEN ~= MY_GEN or getnamecallmethod() ~= "FireServer" then return end
            local a = table.pack(...)
            -- A: (Vector3, Vector3, number, number) = คำสั่งเล็ง
            if a.n >= 4 and typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3"
                and typeof(a[3]) == "number" and typeof(a[4]) == "number" then
                aimRemote = self
                shotOrigin = a[1]
                if a[3] > shotCounter then shotCounter = a[3] end
                setStatus("[DuckAim78] ✅ จำปืน(เล็ง)แล้ว")
            -- B: (number เดียว) = คำสั่งยืนยันนัด
            elseif a.n == 1 and typeof(a[1]) == "number" then
                fireRemote = self
                if a[1] > shotCounter then shotCounter = a[1] end
            end
        end)
        return old(self, ...) -- ส่งต่อของเดิมเป๊ะ ไม่แตะอะไร
    end)
end
end)

-- ยิง 1 นัดสมบูรณ์: A(origin, dir, counter, serverTime) แล้ว B(counter) — counter เดินหน้า
local function fireShot()
    if not (aimRemote and fireRemote) then return false end
    shotCounter += 1
    local n = shotCounter
    -- v5.1: origin ขยับตามตัวผู้เล่น (log ยืนยัน 831→832→814...) → ใช้ตำแหน่งกล้องปัจจุบัน ไม่ใช่ค่าที่จำ
    local origin = Camera.CFrame.Position
    local dir = Camera.CFrame.LookVector -- ทิศตามกล้อง (AIM ล็อคที่เป็ดแล้ว)
    local ts = os.time()
    local ok, now = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and type(now) == "number" then ts = now end
    pcall(function() aimRemote:FireServer(origin, dir, n, ts) end)
    pcall(function() fireRemote:FireServer(n) end)
    return true
end

local function shootStop()
    SHOOT_ON = false -- ลูปเป็น task.spawn เช็คธงนี้แล้วจบเอง
    shootB.Text = "AUTO SHOOT: OFF (คีย์ K)"
end
local function shootStart()
    if not (aimRemote and fireRemote) then
        setStatus("[DuckAim78] ⚠️ ยังไม่รู้ปืนครบ — ยิงเอง 1 นัดก่อน แล้วค่อยกด K")
        return
    end
    SHOOT_ON = true
    shootB.Text = "AUTO SHOOT: ON (กด K ปิด)"
    if not AIM_ON then aimStart() end -- เปิดล็อคกล้องด้วยเสมอ ให้ทิศกล้องตรงเป้าก่อนยิง
    task.spawn(function()
        while SHOOT_ON and _G.DA78_GEN == MY_GEN do
            local d = pickDuck(Camera.CFrame.Position)
            if d and d.model.Parent then
                local p = duckPos(d.model)
                if p then
                    -- ยิงเมื่อกล้องหันเข้าเป้าใกล้พอแล้ว (< 10°) — กัน dir เพี้ยนตอนกล้องยังหมุน
                    local toD = (p - Camera.CFrame.Position)
                    if toD.Magnitude > 1 then
                        local ang = math.deg(math.acos(math.clamp(
                            Camera.CFrame.LookVector:Dot(toD.Unit), -1, 1)))
                        if ang < 10 then
                            fireShot()
                            setStatus(("[DuckAim78] 🔫 ยิง: %s (นัด %d)"):format(d.model.Name, shotCounter))
                        else
                            setStatus(("[DuckAim78] หมุนกล้องเข้าเป้า %s (%.0f°)"):format(d.model.Name, ang))
                        end
                    end
                end
            end
            task.wait(FIRE_INTERVAL)
        end
    end)
end
local function shootToggle()
    if SHOOT_ON then shootStop() else shootStart() end
end

-- คีย์ลัด L (AIM) / K (AUTO SHOOT)
table.insert(_G.DA78_CONNS, UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if _G.DA78_GEN ~= MY_GEN then return end
    if input.KeyCode == Enum.KeyCode.L then aimToggle()
    elseif input.KeyCode == Enum.KeyCode.K then shootToggle() end
end))

-- ==================== Buttons ====================
aimB.MouseButton1Click:Connect(aimToggle)
shootB.MouseButton1Click:Connect(shootToggle)
targetB.MouseButton1Click:Connect(function()
    targetModeIdx = targetModeIdx % #TARGET_MODES + 1
    targetB.Text = "TARGET: " .. TARGET_MODES[targetModeIdx]
end)
stopB.MouseButton1Click:Connect(function()
    aimStop()
    shootStop()
    setStatus("[DuckAim78] หยุดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    aimStop()
    shootStop()
    for _, c in ipairs(_G.DA78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DA78_CONNS = {}
    gui:Destroy(); _G.DA78_GUI = nil
end)

warn("[DuckAim78] v3.0 loaded")
