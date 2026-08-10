-- 78RB_DuckAim.lua v5.9 — เก็บปืนใน _G ทุก gen + ข้ามเป็ดที่ยิงแล้ว (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.9: โหลดซ้ำแล้ว executor ไม่ยอม hook __namecall ซ้ำ → hook เก่า (gen เก่า) เป็นตัว active แต่เดิม
--   เช็ค gen เลยข้ามการจับปืนทิ้ง = จับปืนไม่ได้เลย → เก็บ remote ใน _G ไม่เช็ค gen ตอนจับ ทุก gen
--   เขียน/อ่านร่วมกัน + เพิ่ม markShot ข้ามเป็ดที่เพิ่งยิง 2 วิ (ไม่เล็งซ้ำ)
-- 78RB_DuckAim.lua v5.7 — สถานะปืนแยกบรรทัด (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.7: AIM เขียนทับ status ทุกเฟรมจนมองไม่เห็นสถานะเรียนปืน → เพิ่มบรรทัด gunLbl แยก โชว์
--   hook OK/ไม่ติด + เล็ง✓/✗ ยิง✓/✗ + นัดล่าสุด (AIM แตะไม่ได้) + ปุ่มบอกให้แตะบนมือถือ
-- 78RB_DuckAim.lua v5.5 — รายงานผลติดตั้ง hook + ตัด reload มั่ว (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.5: DuckSpy พบว่าไม่มี remote รีโหลด (รีโหลด=อนิเมชั่นฝั่งจอ) → ตัดโค้ดจับ/ยิงรีโหลดออก ยิง 2
--   remote รัวๆ พอ + pcall เดิมกลืน error ตอนติดตั้ง hook เงียบ ทำให้จับปืนไม่ได้แบบไม่รู้สาเหตุ →
--   เปลี่ยนเป็นรายงานสถานะ hook ชัดๆ (✅ พร้อม / ❌ ไม่ติด+เหตุผล) ตอนโหลด
-- 78RB_DuckAim.lua v5.4 — debug โชว์ remote ที่เห็น (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.4: ยิงเองแล้วยังจับปืนไม่ได้ → ตอนยังเรียนไม่ครบ โชว์ทุก FireServer ที่ hook เห็น (ชื่อ+จำนวน+
--   ชนิด args) บน status เพื่อดูว่าลายเซ็นจริงเป็นแบบไหน (เผื่อเกมเปลี่ยน/hook ไม่เห็น)
-- 78RB_DuckAim.lua v5.3 — รีโหลดทันที ยิงรัวไม่สะดุด (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.3: ปืนแม็กน้อย/รีโหลดหลังยิงเลยช้า → แอบเรียน remote รีโหลด (remote ที่เกมยิงเองภายใน 2 วิ
--   หลังยิง ไม่ใช่ aim/fire) แล้วยิงรีโหลดทันทีหลังทุกนัด ข้ามอนิเมชั่น + ลด FIRE_INTERVAL 0.5→0.18
-- 78RB_DuckAim.lua v5.2 — แก้ compile error "..." (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.2: บั๊กตั้งแต่ v5.0 ทำ GUI ไม่ขึ้นเลย — เอา table.pack(...) ไปไว้ใน pcall(function()...) ซึ่งเป็น
--   ฟังก์ชันซ้อนไม่มี vararg → "Cannot use '...' outside of a vararg function" → ย้าย table.pack(...)
--   มาชั้นนอก แล้วให้ closure ของ pcall ใช้ตัวแปร a ที่ capture ไว้แทน
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
-- v5.9: สถานะปืนเก็บใน _G (hook เขียน — ใช้ร่วมทุก gen กันโหลดซ้ำแล้ว hook เก่าจับไม่ได้)
_G.DA78_CTR = _G.DA78_CTR or 0

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

-- v5.7: บรรทัดสถานะปืนแยกต่างหาก — AIM เขียนทับ status ทุกเฟรมจนมองไม่เห็นสถานะเรียนปืน
local gunLbl = Instance.new("TextLabel", frame)
gunLbl.Size = UDim2.new(1, -8, 0, 16); gunLbl.Position = UDim2.new(0, 4, 0, 40)
gunLbl.BackgroundTransparency = 1; gunLbl.TextColor3 = Color3.fromRGB(140, 255, 140)
gunLbl.TextSize = 11; gunLbl.Font = Enum.Font.Code
gunLbl.TextXAlignment = Enum.TextXAlignment.Left
gunLbl.Text = "ปืน: ยังไม่รู้ — ยิงเอง 1 นัด"
-- อ่านสถานะปืนจาก _G (hook เขียนไว้ — ใช้ร่วมทุก gen)
local function setGun()
    gunLbl.Text = ("ปืน: เล็ง%s ยิง%s  นัดล่าสุด %d"):format(
        _G.DA78_AIM and "✓" or "✗", _G.DA78_FIRE and "✓" or "✗", _G.DA78_CTR or 0)
end

local function mkbtn(txt, y, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, -8, 0, 26); b.Position = UDim2.new(0, 4, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local aimB    = mkbtn("AIM: OFF (คีย์ลัด L)", 60, Color3.fromRGB(190, 60, 60))
local shootB  = mkbtn("AUTO SHOOT: OFF (แตะปุ่มนี้ / คีย์ K)", 90, Color3.fromRGB(60, 170, 90))
local targetB = mkbtn("TARGET: ไม่มีอะไรบัง", 120, Color3.fromRGB(60, 110, 180))
local stopB   = mkbtn("STOP", 150, Color3.fromRGB(150, 60, 30))
local closeB  = mkbtn("✕ ปิด", 180, Color3.fromRGB(90, 40, 40))
frame.Size = UDim2.new(0, 250, 0, 214)

setStatus("[DuckAim78] พร้อม — ยิงเอง 1 นัดให้จำปืน แล้วกด K ยิงออโต้")

-- ==================== หาเป็ด ====================
local function duckFolder()
    return workspace:FindFirstChild("Ume")
end

local function duckPos(m)
    local p = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end

-- v5.8: จำเป็ดที่ "เพิ่งยิงไปแล้ว" — ข้ามไม่เล็งซ้ำ 2 วิ (ให้เวลามันร่วง/ตาย) ถ้ายังไม่ตายค่อยกลับมายิง
local shotDucks = {}          -- model -> os.clock() ตอนยิง
local SHOT_SKIP = 2.0
local function markShot(model) if model then shotDucks[model] = os.clock() end end
local function recentlyShot(model)
    local t = shotDucks[model]
    return t ~= nil and (os.clock() - t) < SHOT_SKIP
end

local function allDucks(includeShot)
    local out = {}
    local f = duckFolder()
    if not f then return out end
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and (includeShot or not recentlyShot(m)) then
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
    -- ถ้าตัวที่ยังไม่ได้ยิงหมดแล้ว (เพิ่งยิงทุกตัว) → กลับมาพิจารณาทุกตัว กันค้างไม่มีเป้า
    if #ducks == 0 then ducks = allDucks(true) end
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
-- ปืนเก็บใน _G.DA78_AIM / _G.DA78_FIRE / _G.DA78_ORIGIN / _G.DA78_CTR (hook เขียน ทุก gen ใช้ร่วม)
local FIRE_INTERVAL = 0.18           -- ยิงถี่ (รีโหลดเป็นอนิเมชั่นฝั่งจอ ยิง remote ตรงข้ามได้)
local lastShotClock = 0

-- v5.5: รายงานผลติดตั้ง hook — เดิม pcall กลืน error เงียบ ทำให้ไม่รู้ว่า hook ไม่ติด (เลยจับปืนไม่ได้)
local hookOK, hookErr = pcall(function()
if not (hookmetamethod and getnamecallmethod) then
    error("executor ไม่มี hookmetamethod/getnamecallmethod")
end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        -- ดึง varargs ที่ชั้นนอก (vararg function) ก่อน — ห้ามใช้ ... ในฟังก์ชันซ้อนของ pcall
        local a = table.pack(...)
        local method = self
        pcall(function()
            -- v5.9: เก็บ remote ที่จับได้ไว้ใน _G (ใช้ร่วมทุก gen) และ "ไม่เช็ค gen" ตอนจับ — เพราะ
            -- โหลดซ้ำแล้ว executor ไม่ยอม hook __namecall ซ้ำ hook เก่า (gen เก่า) เลยเป็นตัวเดียวที่ active
            -- ถ้าเช็ค gen มันจะข้ามการจับทิ้ง → ปืนไม่เคยถูกจำ
            if getnamecallmethod() ~= "FireServer" then return end
            -- A: (Vector3, Vector3, number, number) = คำสั่งเล็ง
            if a.n >= 4 and typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3"
                and typeof(a[3]) == "number" and typeof(a[4]) == "number" then
                _G.DA78_AIM = method
                _G.DA78_ORIGIN = a[1]
                _G.DA78_CTR = math.max(_G.DA78_CTR or 0, a[3])
            -- B: (number เดียว) = คำสั่งยืนยันนัด
            elseif a.n == 1 and typeof(a[1]) == "number" then
                _G.DA78_FIRE = method
                _G.DA78_CTR = math.max(_G.DA78_CTR or 0, a[1])
            end
        end)
        return old(self, ...) -- ส่งต่อของเดิมเป๊ะ ไม่แตะอะไร
    end)
end)
if hookOK then
    setStatus("[DuckAim78] ✅ hook พร้อม — ยิงเอง 1 นัดให้จำปืน")
    gunLbl.Text = "ปืน: hook OK — ยิงเอง 1 นัด"
else
    setStatus("[DuckAim78] ❌ hook ไม่ติด")
    gunLbl.Text = "hook ไม่ติด: " .. tostring(hookErr)
end
-- รีเฟรชบรรทัดปืนจาก _G ตลอด (hook เขียน _G ไว้ — ทุก gen ใช้ร่วมกัน)
task.spawn(function()
    while _G.DA78_GEN == MY_GEN do
        if _G.DA78_AIM or _G.DA78_FIRE then pcall(setGun) end
        task.wait(0.3)
    end
end)

-- ยิง 1 นัดสมบูรณ์: A(origin, dir, counter, serverTime) แล้ว B(counter) — counter เดินหน้า
local function fireShot()
    local aR, fR = _G.DA78_AIM, _G.DA78_FIRE
    if not (aR and fR) then return false end
    _G.DA78_CTR = (_G.DA78_CTR or 0) + 1
    local n = _G.DA78_CTR
    local origin = Camera.CFrame.Position -- ขยับตามตัวผู้เล่น
    local dir = Camera.CFrame.LookVector  -- ทิศตามกล้อง (AIM ล็อคที่เป็ดแล้ว)
    local ts = os.time()
    local ok, now = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and type(now) == "number" then ts = now end
    pcall(function() aR:FireServer(origin, dir, n, ts) end)
    pcall(function() fR:FireServer(n) end)
    lastShotClock = os.clock()
    return true
end

local function shootStop()
    SHOOT_ON = false -- ลูปเป็น task.spawn เช็คธงนี้แล้วจบเอง
    shootB.Text = "AUTO SHOOT: OFF (คีย์ K)"
end
local function shootStart()
    if not (_G.DA78_AIM and _G.DA78_FIRE) then
        setStatus(("[DuckAim78] ⚠️ ยังจับปืนไม่ครบ (เล็ง:%s ยิง:%s) — ยิงเองอีกนัด"):format(
            _G.DA78_AIM and "✓" or "✗", _G.DA78_FIRE and "✓" or "✗"))
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
                            markShot(d.model) -- ขึ้นบัญชี "ยิงแล้ว" ข้ามไม่เล็งซ้ำ 2 วิ
                            setStatus(("[DuckAim78] 🔫 ยิง: %s (นัด %d)"):format(d.model.Name, _G.DA78_CTR or 0))
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
