-- 77RB_HouseClean_AutoSpray.lua v1.1 — ฉีดทำความสะอาดจุดสกปรกอัตโนมัติ (เกม "ล้างบ้านขำๆ")
-- v1.1: จำจุดที่ล้างครบแล้ว (ยิง reportSurfaceComplete สำเร็จ) ไว้ใน _G ข้ามรอบ SPRAY ได้ — กด SPRAY ใหม่
--   จะข้ามจุด/ด้านที่ทำเสร็จไปแล้วอัตโนมัติ ไปต่อจากจุดที่ยังไม่เสร็จเลย ไม่ต้องเริ่มใหม่ทั้งหมด
-- อ้างอิงผลจาก 77RB_HouseClean_NetSpy.lua v1.0 ที่ยืนยันแล้ว (การฉีดล้างคราบสกปรก):
--   RemoteEvent:FireServer("reportSpray", {รายการจุดที่โดนสเปรย์ {p=Part, pos=V3, f="ชื่อด้าน"}, ...}, ทิศทางฉีด)
--   RemoteEvent:FireServer("reportWashProgress", <Part>, "ชื่อด้าน", ความคืบหน้า 0..1)
--   RemoteEvent:FireServer("reportSurfaceComplete", <Part>, "ชื่อด้าน")   -- ยิงตอนล้างด้านนั้นครบ (ฝั่ง client เป็นคนสั่ง)
--   ได้เงินทีละนิดทุกครั้งที่ reportSpray โดนจุดใหม่ๆ + ได้ก้อนใหญ่ตอน reportSurfaceComplete (เห็น Δ+12.73 ในทดสอบจริง)
--   คราบสกปรกอยู่ใน workspace.House_<N>.Dirt (มี Part ลูกหลายชิ้น แต่ละชิ้น = จุดสกปรก 1 จุด มีได้หลายด้าน เช่น Front/Top)
-- วิธีทำงาน: เพราะไม่รู้สูตรคำนวณ coverage ฝั่งเซิร์ฟเวอร์ตรงๆ สคริปต์นี้จำลองพฤติกรรมเดียวกับตอนเล่นจริง คือ
--   ไล่ยิงจุดสเปรย์เป็นตาราง (grid) ครอบคลุมทั้งพื้นผิวของ Part แต่ละด้าน (คำนวณจาก Part.Size/CFrame จริง ไม่เดา)
--   ทีละ ~8 จุดต่อครั้ง (เหมือน pattern จริงที่ดักได้) พร้อมรายงานความคืบหน้าเพิ่มขึ้นเรื่อยๆ จนครบ 100% แล้วยิง surfaceComplete
-- ปุ่ม: SPRAY (เริ่ม/หยุด) | STOP | ✕
if _G.SPR77_GUI then pcall(function() _G.SPR77_GUI:Destroy() end) end
if _G.SPR77_CONNS then
    for _, c in ipairs(_G.SPR77_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.SPR77_CONNS = {}
_G.SPR77_DONE = _G.SPR77_DONE or setmetatable({}, { __mode = "k" }) -- [part][faceName] = true (จำข้ามรอบ SPRAY)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local SPRAY_ON = false
local FLY_SPEED = 60
local learnedRemote = nil

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoSpray77"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.SPR77_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 260, 0, 140); frame.Position = UDim2.new(0, 8, 0.45, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.2
frame.Active = true; frame.Draggable = true

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -8, 0, 40); status.Position = UDim2.new(0, 4, 0, 4)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(180, 220, 255)
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
local sprayB = mkbtn("SPRAY: OFF (ฉีดล้างคราบทั้งหมด)", 48, Color3.fromRGB(40, 130, 190))
local stopB  = mkbtn("STOP", 78, Color3.fromRGB(150, 60, 30))
local closeB = mkbtn("✕ ปิด", 108, Color3.fromRGB(90, 40, 40))

setStatus("[AutoSpray77] พร้อม — กด SPRAY เพื่อไล่ล้างคราบสกปรกทั้งหมด")

-- ==================== หา RemoteEvent ที่ใช้จริง (ตัวเดียวกับ pickupItem/placeCarried) ====================
local function tryAutoFindRemote()
    local candidates = {}
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") and d.Name == "RemoteEvent" then
            candidates[#candidates + 1] = d
        end
    end
    if #candidates == 1 then
        learnedRemote = candidates[1]
        setStatus("[AutoSpray77] เจอ RemoteEvent อัตโนมัติ: " .. learnedRemote:GetFullName())
        return true
    end
    return false
end

local function hookLearn()
    if not hookmetamethod then
        setStatus("[AutoSpray77] ❌ ไม่มี hookmetamethod — เรียนรู้ remote อัตโนมัติไม่ได้")
        return
    end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not learnedRemote then
            local method = getnamecallmethod()
            if method == "FireServer" then
                local args = { ... }
                if args[1] == "reportSpray" or args[1] == "pickupItem" or args[1] == "placeCarried" then
                    learnedRemote = self
                    setStatus("[AutoSpray77] ✅ เรียนรู้ remote จากการเล่นจริง: " .. self:GetFullName())
                end
            end
        end
        return old(self, ...)
    end)
end

-- ==================== หาคราบสกปรกทั้งหมด ====================
local function findDirtParts()
    local out = {}
    for _, house in ipairs(workspace:GetChildren()) do
        if house:IsA("Model") then
            local dirtFolder = house:FindFirstChild("Dirt")
            if dirtFolder then
                for _, p in ipairs(dirtFolder:GetChildren()) do
                    if p:IsA("BasePart") then out[#out + 1] = p end
                end
            end
        end
    end
    return out
end

-- ==================== นิยามด้านของ Part (local offset + แกนตาราง) ====================
local FACES = {
    Front  = { normal = Vector3.new(0, 0, -1), axisA = Vector3.new(1, 0, 0), axisB = Vector3.new(0, 1, 0), sizeA = "X", sizeB = "Y" },
    Back   = { normal = Vector3.new(0, 0, 1),  axisA = Vector3.new(1, 0, 0), axisB = Vector3.new(0, 1, 0), sizeA = "X", sizeB = "Y" },
    Top    = { normal = Vector3.new(0, 1, 0),  axisA = Vector3.new(1, 0, 0), axisB = Vector3.new(0, 0, 1), sizeA = "X", sizeB = "Z" },
    Bottom = { normal = Vector3.new(0, -1, 0), axisA = Vector3.new(1, 0, 0), axisB = Vector3.new(0, 0, 1), sizeA = "X", sizeB = "Z" },
    Left   = { normal = Vector3.new(-1, 0, 0), axisA = Vector3.new(0, 0, 1), axisB = Vector3.new(0, 1, 0), sizeA = "Z", sizeB = "Y" },
    Right  = { normal = Vector3.new(1, 0, 0),  axisA = Vector3.new(0, 0, 1), axisB = Vector3.new(0, 1, 0), sizeA = "Z", sizeB = "Y" },
}
-- ด้านหลักที่พบจริงจากการทดสอบ (ล้างเฉพาะด้านนี้ก่อนพอ ลด false-positive กับด้านที่ไม่มีคราบ)
local ACTIVE_FACES = { "Front", "Top" }

local function faceGridPoints(part, faceName)
    local f = FACES[faceName]
    local size = part.Size
    local halfA = size[f.sizeA] / 2
    local halfB = size[f.sizeB] / 2
    local step = 1 -- 1 stud/ช่อง ตรงตาม pattern ที่ดักได้จริง
    local points = {}
    local a = -halfA
    while a <= halfA do
        local b = -halfB
        while b <= halfB do
            local localOffset = f.axisA * a + f.axisB * b + f.normal * (part.Size.Z * 0) -- อยู่บนผิวพอดี (offset เพิ่มได้ถ้าต้องยื่นออกมา)
            local worldPos = part.CFrame:PointToWorldSpace(localOffset)
            points[#points + 1] = worldPos
            b += step
        end
        a += step
    end
    return points
end

-- ==================== บิน (ย้าย HumanoidRootPart ไปจุดหมายแบบนุ่มๆ) ====================
local function flyTo(targetPos, timeoutSec)
    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local t0 = tick()
    while tick() - t0 < (timeoutSec or 6) do
        if not SPRAY_ON then return false end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local cur = hrp.Position
        local dist = (targetPos - cur).Magnitude
        if dist < 6 then return true end
        local dir = (targetPos - cur).Unit
        hrp.CFrame = CFrame.new(cur + dir * math.min(FLY_SPEED * RunService.Heartbeat:Wait(), dist), targetPos)
    end
    return true
end

-- ==================== ฉีดล้าง 1 ด้านของ Part ให้ครบ ====================
local function sprayFace(part, faceName)
    if not part.Parent then return end
    local points = faceGridPoints(part, faceName)
    if #points == 0 then return end

    local normal = part.CFrame:VectorToWorldSpace(FACES[faceName].normal)
    local BATCH = 8
    local total = #points
    local done = 0
    local i = 1
    while i <= total do
        if not SPRAY_ON then return end
        local batch = {}
        for k = i, math.min(i + BATCH - 1, total) do
            batch[#batch + 1] = { p = part, pos = points[k], f = faceName }
        end
        pcall(function() learnedRemote:FireServer("reportSpray", batch, normal) end)
        done += #batch
        i += BATCH
        if done % (BATCH * 5) < BATCH then
            local progress = done / total
            pcall(function() learnedRemote:FireServer("reportWashProgress", part, faceName, progress) end)
            setStatus(("[AutoSpray77] ฉีด %s (%s): %d%%"):format(part.Name, faceName, math.floor(progress * 100)))
        end
        task.wait(0.12)
    end
    pcall(function() learnedRemote:FireServer("reportWashProgress", part, faceName, 1) end)
    task.wait(0.15)
    pcall(function() learnedRemote:FireServer("reportSurfaceComplete", part, faceName) end)
    task.wait(0.2)

    _G.SPR77_DONE[part] = _G.SPR77_DONE[part] or {}
    _G.SPR77_DONE[part][faceName] = true
end

-- ==================== SPRAY: ไล่ล้างคราบทั้งหมด ====================
local function runSpray()
    if not learnedRemote then
        if not tryAutoFindRemote() then
            setStatus("[AutoSpray77] ⚠️ ยังไม่รู้ remote — ลองฉีด/จับของเองก่อน 1 ครั้ง (กำลังดักเรียนรู้อยู่)")
            local t0 = tick()
            while SPRAY_ON and not learnedRemote and tick() - t0 < 30 do task.wait(0.5) end
            if not learnedRemote then
                setStatus("[AutoSpray77] ❌ หา remote ไม่เจอ ยกเลิก SPRAY")
                SPRAY_ON = false
                sprayB.Text = "SPRAY: OFF (ฉีดล้างคราบทั้งหมด)"
                return
            end
        end
    end

    setStatus("[AutoSpray77] 🔍 กำลังสแกนหาคราบสกปรกทั้งหมด...")
    local dirtParts = findDirtParts()
    if #dirtParts == 0 then
        setStatus("[AutoSpray77] ไม่พบคราบสกปรก (House_*.Dirt) — จบ")
        SPRAY_ON = false
        sprayB.Text = "SPRAY: OFF (ฉีดล้างคราบทั้งหมด)"
        return
    end
    setStatus(("[AutoSpray77] พบคราบสกปรก %d จุด — เริ่มฉีดล้างทีละจุด (ข้ามจุดที่เคยล้างเสร็จแล้ว)"):format(#dirtParts))

    local processed, skipped = 0, 0
    for i, part in ipairs(dirtParts) do
        if not SPRAY_ON then break end
        if part.Parent then
            -- เช็คว่าทุกด้านของจุดนี้ล้างเสร็จไปแล้วหรือยัง (จำไว้จากรอบก่อนหน้าใน _G) — ถ้าเสร็จหมดแล้วข้ามไปเลย
            local doneFaces = _G.SPR77_DONE[part]
            local allDone = true
            for _, faceName in ipairs(ACTIVE_FACES) do
                if not (doneFaces and doneFaces[faceName]) then allDone = false break end
            end
            if allDone then
                skipped += 1
            else
                setStatus(("[AutoSpray77] (%d/%d) กำลังบินไปที่: %s"):format(i, #dirtParts, part.Name))
                flyTo(part.Position, 6)
                for _, faceName in ipairs(ACTIVE_FACES) do
                    if not SPRAY_ON then break end
                    if doneFaces and doneFaces[faceName] then
                        -- ด้านนี้ล้างเสร็จแล้ว ข้ามเฉพาะด้านนี้
                    else
                        sprayFace(part, faceName)
                    end
                end
                processed += 1
            end
        end
    end

    setStatus(("[AutoSpray77] ✅ จบแล้ว! ล้างคราบไป %d จุด, ข้ามที่เสร็จแล้ว %d จุด (รวม %d)"):format(processed, skipped, #dirtParts))
    SPRAY_ON = false
    sprayB.Text = "SPRAY: OFF (ฉีดล้างคราบทั้งหมด)"
end

-- ==================== Buttons ====================
sprayB.MouseButton1Click:Connect(function()
    SPRAY_ON = not SPRAY_ON
    sprayB.Text = SPRAY_ON and "SPRAY: ON (กำลังทำงาน...)" or "SPRAY: OFF (ฉีดล้างคราบทั้งหมด)"
    if SPRAY_ON then task.spawn(runSpray) end
end)
stopB.MouseButton1Click:Connect(function()
    SPRAY_ON = false
    sprayB.Text = "SPRAY: OFF (ฉีดล้างคราบทั้งหมด)"
    setStatus("[AutoSpray77] หยุดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    SPRAY_ON = false
    for _, c in ipairs(_G.SPR77_CONNS) do pcall(function() c:Disconnect() end) end
    _G.SPR77_CONNS = {}
    gui:Destroy(); _G.SPR77_GUI = nil
end)

-- ==================== Setup ====================
hookLearn()
tryAutoFindRemote()
warn("[AutoSpray77] loaded")
