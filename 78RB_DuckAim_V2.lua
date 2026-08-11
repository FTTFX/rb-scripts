-- 78RB_DuckAim_V2.lua v1.0 — ยิงรีโมตล้วน สไตล์ 27.txt (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- แนวทางใหม่: ไม่ล็อกกล้อง ไม่คลิก — ยิง remote ตรงไปที่ "ตำแหน่งเป็ด" เหมือนซอมบี้ (27.txt)
--   เกมเป็ดใช้ 2 remote/นัด (พิสูจน์แล้วจาก DuckSpy):
--     AIM : FireServer(Vector3 origin, Vector3 dir, number aimCtr, number timestamp)
--     FIRE: FireServer(number fireCtr)          ← คนละ counter กับ AIM ห่างกันคงที่ (offset)
--   วิธี: ยิงมือ 1 นัดให้ "เรียนปืน" (จำ remote + origin + counter ทั้งคู่ + offset)
--         จากนั้นกด "เปิด" → ทุกจังหวะ: เลือกเป็ดใกล้สุด, dir=(เป็ด−origin).Unit,
--         aimCtr+1 / fireCtr+1 (เดินคู่กัน = รักษา offset), ยิง AIM แล้ว FIRE
-- GUI: ปุ่มเดียว เปิด/ปิด (คีย์ J)  |  เรียนปืนอัตโนมัติจากนัดที่ยิงมือ
if _G.DV2_GUI then pcall(function() _G.DV2_GUI:Destroy() end) end
if _G.DV2_CONNS then
    for _, c in ipairs(_G.DV2_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.DV2_CONNS = {}
_G.DV2_GEN = (_G.DV2_GEN or 0) + 1
local MY_GEN = _G.DV2_GEN

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = workspace
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ค่าที่เรียนได้ เก็บใน _G (hook เขียน ใช้ร่วมทุก gen กันโหลดซ้ำแล้ว hook เก่าเป็นตัว active)
-- _G.DV2_AIM   = remote เล็ง (RemoteEvent)
-- _G.DV2_FIRE  = remote ยืนยันนัด
-- _G.DV2_ORIGIN= Vector3 origin ที่เกมใช้ (คงที่ ~799,68,x)
-- _G.DV2_AIMCTR / _G.DV2_FIRECTR = counter ล่าสุดของแต่ละ remote
-- _G.DV2_OFFSET = aimCtr − fireCtr (คงที่)
_G.DV2_AIMCTR  = _G.DV2_AIMCTR or 0
_G.DV2_FIRECTR = _G.DV2_FIRECTR or 0

local RUN_ON = false
-- สไตล์ 27.txt: ยิงรัวทุก Heartbeat กระจายใส่เป็ดหลายตัว/tick ไม่พักรีโหลด
local FIRE_DELAY = 0.03  -- วิ/tick (เร็วสุด — ปรับด้วย −/+)
local MAX_TARGETS = 8    -- ยิงกี่ตัว/tick (เป็ดใกล้สุด N ตัว)

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DuckAimV2"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.DV2_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 230, 0, 168); frame.Position = UDim2.new(0, 8, 0.35, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.18
frame.Active = true; frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -8, 0, 18); title.Position = UDim2.new(0, 4, 0, 4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(255, 200, 120)
title.Text = "🦆 DuckAim V2 (ยิงรีโมต)"; title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -8, 0, 34); status.Position = UDim2.new(0, 4, 0, 22)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(180, 255, 180)
status.TextSize = 11; status.Font = Enum.Font.Code; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.TextYAlignment = Enum.TextYAlignment.Top
local function setStatus(s) status.Text = s end

local gunLbl = Instance.new("TextLabel", frame)
gunLbl.Size = UDim2.new(1, -8, 0, 14); gunLbl.Position = UDim2.new(0, 4, 0, 56)
gunLbl.BackgroundTransparency = 1; gunLbl.TextColor3 = Color3.fromRGB(140, 220, 255)
gunLbl.TextSize = 11; gunLbl.Font = Enum.Font.Code
gunLbl.TextXAlignment = Enum.TextXAlignment.Left
gunLbl.Text = "ปืน: ยังไม่รู้ — ยิงมือ 1 นัด"
local function setGun()
    gunLbl.Text = ("ปืน:%s%s A%d/F%d off=%s"):format(
        _G.DV2_AIM and "เล็ง✓" or "เล็ง✗", _G.DV2_FIRE and " ยิง✓" or " ยิง✗",
        _G.DV2_AIMCTR or 0, _G.DV2_FIRECTR or 0,
        _G.DV2_OFFSET ~= nil and tostring(_G.DV2_OFFSET) or "?")
end

-- ตัวนับ "ฆ่าไปกี่ตัว" สดๆ จาก leaderstats.DucksKilled — โชว์ว่ายิงรีโมตได้ผลจริงไหม
local function ducksKilled()
    local ls = LP:FindFirstChild("leaderstats")
    if not ls then return nil end
    local d = ls:FindFirstChild("DucksKilled") or ls:FindFirstChild("Ducks")
    return d and d.Value or nil
end
local killBase = ducksKilled()
task.spawn(function()
    while _G.DV2_GEN == MY_GEN do
        local now = ducksKilled()
        if now then
            if not killBase then killBase = now end
            title.Text = ("🦆 DuckAim V2  ฆ่า +%d"):format(now - killBase)
        end
        task.wait(0.4)
    end
end)

-- ปุ่มหลัก เปิด/ปิด (ปุ่มเดียว)
local mainB = Instance.new("TextButton", frame)
mainB.Size = UDim2.new(1, -8, 0, 34); mainB.Position = UDim2.new(0, 4, 0, 74)
mainB.Text = "เปิดยิงรีโมต: OFF (คีย์ J)"; mainB.Font = Enum.Font.GothamBold; mainB.TextSize = 14
mainB.BackgroundColor3 = Color3.fromRGB(190, 60, 60); mainB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", mainB).CornerRadius = UDim.new(0, 6)

-- แถวปรับหน่วงยิง −/+
local rMinus = Instance.new("TextButton", frame)
rMinus.Size = UDim2.new(0, 32, 0, 26); rMinus.Position = UDim2.new(0, 4, 0, 114)
rMinus.BackgroundColor3 = Color3.fromRGB(120, 50, 50); rMinus.TextColor3 = Color3.new(1,1,1)
rMinus.Font = Enum.Font.GothamBold; rMinus.TextSize = 18; rMinus.Text = "−"
local rLbl = Instance.new("TextLabel", frame)
rLbl.Size = UDim2.new(0, 150, 0, 26); rLbl.Position = UDim2.new(0, 40, 0, 114)
rLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 45); rLbl.TextColor3 = Color3.fromRGB(255, 230, 150)
rLbl.Font = Enum.Font.Code; rLbl.TextSize = 13
rLbl.Text = ("tick %.2fวิ ×%dตัว"):format(FIRE_DELAY, MAX_TARGETS)
Instance.new("UICorner", rLbl).CornerRadius = UDim.new(0, 5)
local rPlus = Instance.new("TextButton", frame)
rPlus.Size = UDim2.new(0, 32, 0, 26); rPlus.Position = UDim2.new(0, 194, 0, 114)
rPlus.BackgroundColor3 = Color3.fromRGB(50, 120, 50); rPlus.TextColor3 = Color3.new(1,1,1)
rPlus.Font = Enum.Font.GothamBold; rPlus.TextSize = 18; rPlus.Text = "+"

local closeB = Instance.new("TextButton", frame)
closeB.Size = UDim2.new(1, -8, 0, 22); closeB.Position = UDim2.new(0, 4, 0, 144)
closeB.Text = "✕ ปิดหน้าต่าง"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 12
closeB.BackgroundColor3 = Color3.fromRGB(90, 40, 40); closeB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)

setStatus("[V2] ยิงมือใส่เป็ด 1 นัด ให้จำปืน แล้วกด เปิด (J)")

-- ==================== หาเป็ด (เหมือน DuckAim หลัก) ====================
local function duckFolder() return workspace:FindFirstChild("Ume") end
local function duckPos(m)
    local p = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end
local function isLiveDuck(m)
    local n = m.Name
    return n:find("Duck") ~= nil and not n:find("Landed")
end
local function findBoss()
    local f = duckFolder(); if not f then return nil end
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and m.Name:find("BossController") then
            local p = duckPos(m)
            if p then return { model = m, pos = p } end
        end
    end
    return nil
end
-- v1.3: เช็ค "ไม่มีอะไรบัง" — เรย์จากกล้องถึงเป็ด ถ้าไปโดนอย่างอื่นก่อน (ต้นไม้/พื้น) = เสียนัดเปล่า
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
local function duckVisible(origin, duckPosV, duckModel)
    losParams.FilterDescendantsInstances = { LP.Character, duckModel }
    local res = workspace:Raycast(origin, duckPosV - origin, losParams)
    return res == nil -- ไม่โดนอะไรระหว่างทาง = โล่ง ยิงโดนแน่
end

-- คืนลิสต์เป็ด "เรียงจากใกล้สุด + ไม่มีอะไรบัง" (บอสแทรกหัวแถว)
local FILTER_LOS = true -- เปิด/ปิดกรองตัวที่ถูกบัง
local function closestDucks(origin)
    local list = {}
    local f = duckFolder(); if not f then return list end
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and isLiveDuck(m) then
            local p = duckPos(m)
            if p and (not FILTER_LOS or duckVisible(origin, p, m)) then
                list[#list + 1] = { model = m, pos = p, dist = (p - origin).Magnitude }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local boss = findBoss()
    if boss then table.insert(list, 1, boss) end
    return list
end

-- ==================== HOOK เรียนปืน (อ่านอย่างเดียว ไม่แก้ค่า) ====================
local hookOK, hookErr = pcall(function()
    if not (hookmetamethod and getnamecallmethod) then
        error("executor ไม่มี hookmetamethod")
    end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local a = table.pack(...)
        local rself = self
        pcall(function()
            if getnamecallmethod() ~= "FireServer" then return end
            if _G.DV2_SELFFIRE then return end -- ข้ามนัดที่ "เรายิงเอง" ไม่เอามาเรียนซ้ำ
            -- AIM: (Vector3, Vector3, number, number)
            if a.n >= 4 and typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3"
                and typeof(a[3]) == "number" and typeof(a[4]) == "number" then
                _G.DV2_AIM = rself
                _G.DV2_ORIGIN = a[1]
                _G.DV2_AIMCTR = math.max(_G.DV2_AIMCTR or 0, a[3])
                _G.DV2_LASTAIM = a[3]
            -- FIRE: (number เดียว)
            elseif a.n == 1 and typeof(a[1]) == "number" then
                _G.DV2_FIRE = rself
                _G.DV2_FIRECTR = math.max(_G.DV2_FIRECTR or 0, a[1])
                if _G.DV2_LASTAIM then
                    _G.DV2_OFFSET = _G.DV2_LASTAIM - a[1] -- offset = aim − fire (คงที่)
                    _G.DV2_LASTAIM = nil
                end
            end
        end)
        return old(rself, ...)
    end)
end)
if hookOK then
    setStatus("[V2] ✅ hook พร้อม — ยิงมือ 1 นัดให้จำปืน")
else
    setStatus("[V2] ❌ hook ไม่ติด: " .. tostring(hookErr))
end

-- รีเฟรชบรรทัดปืนตลอด
task.spawn(function()
    while _G.DV2_GEN == MY_GEN do
        pcall(setGun)
        task.wait(0.3)
    end
end)

-- ==================== ยิง 1 นัด (AIM + FIRE) แบบ 27.txt ====================
local function serverNow()
    local t = 0
    pcall(function() t = Workspace:GetServerTimeNow() end)
    if t == 0 then pcall(function() t = os.clock() end) end
    return t
end

-- ยิงรีโมตตรงไปที่ตำแหน่งเป้า — เดิน counter คู่กัน (+1 ทั้งคู่) รักษา offset ที่เรียนมา
-- v1.2: สปายพิสูจน์ origin = กล้องสดๆ / dir = ทิศกล้อง → ใช้กล้องสด ณ ตอนยิง (ไม่ใช้ค่าเก่า!)
--   dir = (ตำแหน่งเป็ด − กล้อง).Unit ชี้ตรงตัวเป็ด เซิร์ฟเวอร์ยิงเรย์จากกล้องโดนเป็ดพอดี
local function fireAt(targetPos)
    local aim, fire = _G.DV2_AIM, _G.DV2_FIRE
    if not (aim and fire) then return false end
    local origin = Camera.CFrame.Position -- กล้องสดๆ (ไม่ใช้ _G.DV2_ORIGIN เก่า)
    local dir = (targetPos - origin)
    if dir.Magnitude > 0 then dir = dir.Unit else dir = Vector3.new(0, 0, -1) end

    -- เดิน counter (ค่าที่เรียนมาคือค่าล่าสุดที่ยิงมือ → นัดต่อไปคือ +1)
    local aimCtr = (_G.DV2_AIMCTR or 0) + 1
    local fireCtr = (_G.DV2_FIRECTR or 0) + 1
    _G.DV2_AIMCTR = aimCtr
    _G.DV2_FIRECTR = fireCtr

    _G.DV2_SELFFIRE = true -- กัน hook เรียน counter จากนัดของเราเอง
    local ok = pcall(function()
        aim:FireServer(origin, dir, aimCtr, serverNow())
        fire:FireServer(fireCtr)
    end)
    _G.DV2_SELFFIRE = false
    return ok
end

-- ==================== ลูปยิง ====================
local function runStop()
    RUN_ON = false
    mainB.Text = "เปิดยิงรีโมต: OFF (คีย์ J)"
    mainB.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
end
local function runStart()
    if not (_G.DV2_AIM and _G.DV2_FIRE) then
        setStatus("[V2] ⚠️ ยังไม่รู้จักปืน — ยิงมือ 1 นัดก่อน แล้วกดใหม่")
        return
    end
    RUN_ON = true
    mainB.Text = "เปิดยิงรีโมต: ON (กด J ปิด)"
    mainB.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
    _G.DV2_RUNID = (_G.DV2_RUNID or 0) + 1
    local myRun = _G.DV2_RUNID
    -- สไตล์ 27.txt: Heartbeat ทุก FIRE_DELAY วิ กระจายยิงเป็ดใกล้สุด MAX_TARGETS ตัวใน tick เดียว
    _G.DV2_LASTFIRE = 0
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not (RUN_ON and _G.DV2_GEN == MY_GEN and _G.DV2_RUNID == myRun) then
            conn:Disconnect(); return
        end
        if os.clock() - (_G.DV2_LASTFIRE or 0) < FIRE_DELAY then return end
        _G.DV2_LASTFIRE = os.clock()
        local origin = Camera.CFrame.Position
        local ducks = closestDucks(origin)
        if #ducks == 0 then setStatus("[V2] ไม่เจอเป้า — รอเป็ด"); return end
        local sent = 0
        for _, d in ipairs(ducks) do
            if sent >= MAX_TARGETS then break end
            if d.model.Parent then
                local p = duckPos(d.model)
                if p and fireAt(p) then sent = sent + 1 end
            end
        end
        setStatus(("[V2] 🔫 กระจาย %d ตัว/tick A%d/F%d"):format(sent, _G.DV2_AIMCTR, _G.DV2_FIRECTR))
    end)
    table.insert(_G.DV2_CONNS, conn)
end
local function toggle()
    if RUN_ON then runStop() else runStart() end
end

-- ==================== ปุ่ม/คีย์ ====================
mainB.MouseButton1Click:Connect(toggle)
-- − ลด/เพิ่ม "จำนวนเป้าต่อ tick" (ยิงกว้างขึ้น = เร็วขึ้น)
local function refreshRLbl() rLbl.Text = ("tick %.2fวิ ×%dตัว"):format(FIRE_DELAY, MAX_TARGETS) end
rMinus.MouseButton1Click:Connect(function()
    MAX_TARGETS = math.clamp(MAX_TARGETS - 1, 1, 30); refreshRLbl()
end)
rPlus.MouseButton1Click:Connect(function()
    MAX_TARGETS = math.clamp(MAX_TARGETS + 1, 1, 30); refreshRLbl()
end)
closeB.MouseButton1Click:Connect(function()
    runStop()
    _G.DV2_GEN = _G.DV2_GEN + 1 -- ปิด hook/ลูปเก่า
    for _, c in ipairs(_G.DV2_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DV2_CONNS = {}
    gui:Destroy(); _G.DV2_GUI = nil
end)

table.insert(_G.DV2_CONNS, UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if _G.DV2_GEN ~= MY_GEN then return end
    if input.KeyCode == Enum.KeyCode.J then toggle() end
end))

warn("[DuckAimV2] v1.0 loaded — ยิงมือ 1 นัดให้จำปืน แล้วกด J")
