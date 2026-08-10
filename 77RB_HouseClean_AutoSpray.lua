-- 77RB_HouseClean_AutoSpray.lua v2.1 — ฉีดด้านที่มีคราบจริงจาก Decal.Face (เกม "ล้างบ้านขำๆ")
-- v2.1: หลายจุดฉีดครบแต่คะแนนไม่ขึ้น เพราะฉีด Front/Top ตายตัว คราบอยู่ด้านอื่น → อ่าน Decal.Face
--   ของคราบที่ยังไม่โปร่งใส แล้วฉีดเฉพาะด้านนั้นเป๊ะๆ (ไม่เจอ Decal ค่อย fallback Front/Top)
-- v2.0: batch 8→20 จุด/ชุด, ช่วงยิง 0.12→0.05 วิ, บิน 100→180, ตัดเวลารอหลังบิน/จบด้านลงเกือบหมด
--   รวมแล้วต่อด้านเร็วขึ้น ~4-5 เท่า (พักกันเตือนยังมี: ทุก 60 ชุด พัก 1.5 วิ)
-- v1.9: SPRAY เช็ค dirtVisible ซ้ำก่อนฉีดทุกจุด (จุดที่สะอาดระหว่างรอบถูกข้ามทันที) — ไม่วนจาก 0
--   + status โชว์ตัวเลข "ล้างแล้ว" จริงจาก HUD แทนเลขรอบ
-- v1.8: GUIDE บอกเหลือ 291 จุดทั้งที่จริงเหลือ 2 — โฟลเดอร์ Dirt มี Part ที่ล้างแล้ว/สำรอง (โปร่งใส)
--   ค้างเป็นร้อย → กรอง dirtVisible: นับเฉพาะ Part/Decal ที่ยังไม่โปร่งใส (ทั้ง GUIDE และ SPRAY)
-- v1.7: เพิ่มปุ่ม GUIDE — เส้น Beam 3 เส้นชี้ไปจุดสกปรกที่ใกล้ที่สุด 3 จุด (เขียว=ใกล้สุด,
--   เหลือง=รอง, ฟ้า=ที่สาม) รีเฟรชเป้าทุก 0.5 วิ + status โชว์จำนวนจุดสกปรกที่เหลือ
-- v1.6: จำ remote ที่เรียนรู้ถูกไว้ใน _G.RB77_REMOTE ข้ามรอบ/ข้ามสคริปต์ (ใช้ร่วมกับ AutoFly77) เหมือนกัน
-- v1.5: เจอ popup "คุณไม่ได้พักเลย!" จากการฉีดต่อเนื่องไม่มีหยุดเลย — เพิ่มระบบพักสั้นๆ (2.5s) ทุก 25 ครั้งที่ยิง reportSpray
-- v1.4: ความเร็ว 200 เร็วไปจนอาจยิง remote ก่อนตำแหน่งซิงก์ขึ้นเซิร์ฟเวอร์ — ลดเหลือ 100 + รอ 0.15s ก่อนยิงทุกครั้ง
-- v1.3: เจอว่า House_1.Dirt.Part เป็น Part ตัวเดียวที่เกม "รียูส" แทนคราบใหม่ไปเรื่อยๆ (ตำแหน่งขยับทุกรอบงาน)
--   ไม่ใช่มีคราบสกปรกหลายก้อนวางอยู่ในโลกให้ไล่หา — ระบบจำ "ล้างเสร็จแล้ว" แบบ v1.1/v1.2 (จำตาม Instance)
--   เลยผิดตั้งแต่ต้น เพราะ Instance เดิมถูกเอามาใช้กับคราบใหม่ตลอด ทำให้ข้ามคราบใหม่ทั้งที่ยังไม่เคยล้าง
--   รื้อใหม่: วนฉีดตามตำแหน่งปัจจุบันของ Part ไปเรื่อยๆไม่จำกัดรอบ (ไม่จำ instance อีกต่อไป) แล้วอ่านความ
--   คืบหน้าจริงจาก HUD เกม ("วัตถุที่ล้างแล้ว: X/Y") มาโชว์ + หยุดอัตโนมัติเมื่อ X ถึง Y (ล้างครบจริงตามเกม)
-- v1.2: เพิ่มความเร็วบิน FLY_SPEED 60 → 200 ตามที่ขอ
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

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local SPRAY_ON = false
local FLY_SPEED = 180 -- v2.0: 100→180
local learnedRemote = _G.RB77_REMOTE -- จำ remote ที่เรียนรู้ถูกไว้แล้วข้ามรอบ (ตัวเดียวกับ AutoFly77)

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
local guideB = mkbtn("GUIDE: OFF (เส้นชี้จุดสกปรก 3 จุด)", 78, Color3.fromRGB(30, 150, 150))
local stopB  = mkbtn("STOP", 108, Color3.fromRGB(150, 60, 30))
local closeB = mkbtn("✕ ปิด", 138, Color3.fromRGB(90, 40, 40))
frame.Size = UDim2.new(0, 260, 0, 170)

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
        _G.RB77_REMOTE = learnedRemote
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
                    _G.RB77_REMOTE = learnedRemote
                    setStatus("[AutoSpray77] ✅ เรียนรู้ remote จากการเล่นจริง: " .. self:GetFullName())
                end
            end
        end
        return old(self, ...)
    end)
end

-- ==================== หาคราบสกปรกทั้งหมด ====================
-- v1.8: โฟลเดอร์ Dirt มี Part ค้างหลายร้อยชิ้น แต่ส่วนใหญ่คือจุดที่ล้างแล้ว/จุดสำรองที่เกมซ่อนไว้
-- (โปร่งใสหมด) — นับเฉพาะจุดที่ "ยังมองเห็นจริง": ตัว Part หรือ Decal/Texture คราบยังไม่โปร่งใส
local function dirtVisible(p)
    if p.Transparency < 0.99 then return true end
    for _, d in ipairs(p:GetDescendants()) do
        if (d:IsA("Decal") or d:IsA("Texture")) and d.Transparency < 0.99 then return true end
    end
    return false
end

local function findDirtParts()
    local out = {}
    for _, house in ipairs(workspace:GetChildren()) do
        if house:IsA("Model") then
            local dirtFolder = house:FindFirstChild("Dirt")
            if dirtFolder then
                for _, p in ipairs(dirtFolder:GetChildren()) do
                    if p:IsA("BasePart") and dirtVisible(p) then out[#out + 1] = p end
                end
            end
        end
    end
    return out
end

-- ==================== GUIDE: เส้นชี้จุดสกปรกใกล้สุด 3 จุด ====================
-- 3 เส้น 3 สี (เขียว=ใกล้สุด เหลือง=รอง ฟ้า=ที่สาม) รีเฟรชเป้าทุก 0.5 วิ ตามจุดที่เหลือจริง
local GUIDE_ON = false
local guideA0, guideConn = nil, nil
local guideBeams = {}

local function guideStop()
    GUIDE_ON = false
    if guideConn then guideConn:Disconnect() guideConn = nil end
    for _, t in ipairs(guideBeams) do
        pcall(function() t.beam:Destroy() end)
        if t.a1 then pcall(function() t.a1:Destroy() end) end
    end
    guideBeams = {}
    if guideA0 then pcall(function() guideA0:Destroy() end) guideA0 = nil end
end

local function guideStart()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    GUIDE_ON = true
    guideA0 = Instance.new("Attachment")
    guideA0.Name = "SPR77_GUIDE"
    guideA0.Parent = hrp
    local colors = { Color3.fromRGB(60, 255, 150), Color3.fromRGB(255, 220, 60), Color3.fromRGB(90, 170, 255) }
    for i = 1, 3 do
        local beam = Instance.new("Beam")
        beam.Name = "SPR77_GUIDE"
        beam.Width0 = 0.35; beam.Width1 = 0.1
        beam.Color = ColorSequence.new(colors[i])
        beam.Transparency = NumberSequence.new(0.15)
        beam.FaceCamera = true
        beam.Attachment0 = guideA0
        beam.Enabled = false
        beam.Parent = guideA0
        guideBeams[i] = { beam = beam, a1 = nil }
    end
    local last = 0
    guideConn = RunService.Heartbeat:Connect(function()
        if not GUIDE_ON then return end
        if tick() - last < 0.5 then return end
        last = tick()
        local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local parts = findDirtParts()
        table.sort(parts, function(a, b)
            return (a.Position - h.Position).Magnitude < (b.Position - h.Position).Magnitude
        end)
        for i = 1, 3 do
            local t = guideBeams[i]
            local p = parts[i]
            if p then
                if t.a1 then pcall(function() t.a1:Destroy() end) end
                local a1 = Instance.new("Attachment")
                a1.Name = "SPR77_GUIDE"
                a1.Parent = p
                t.a1 = a1
                t.beam.Attachment1 = a1
                t.beam.Enabled = true
            else
                t.beam.Enabled = false
            end
        end
        setStatus(("[AutoSpray77] GUIDE: เหลือจุดสกปรก %d จุด (ชี้ %d จุดใกล้สุด)"):format(#parts, math.min(3, #parts)))
    end)
    table.insert(_G.SPR77_CONNS, guideConn)
end

guideB.MouseButton1Click:Connect(function()
    if GUIDE_ON then
        guideStop()
        guideB.Text = "GUIDE: OFF (เส้นชี้จุดสกปรก 3 จุด)"
    else
        guideStart()
        guideB.Text = "GUIDE: ON (เขียว/เหลือง/ฟ้า = ใกล้สุด 3 จุด)"
    end
end)

-- ==================== นิยามด้านของ Part (local offset + แกนตาราง) ====================
local FACES = {
    Front  = { normal = Vector3.new(0, 0, -1), axisA = Vector3.new(1, 0, 0), axisB = Vector3.new(0, 1, 0), sizeA = "X", sizeB = "Y" },
    Back   = { normal = Vector3.new(0, 0, 1),  axisA = Vector3.new(1, 0, 0), axisB = Vector3.new(0, 1, 0), sizeA = "X", sizeB = "Y" },
    Top    = { normal = Vector3.new(0, 1, 0),  axisA = Vector3.new(1, 0, 0), axisB = Vector3.new(0, 0, 1), sizeA = "X", sizeB = "Z" },
    Bottom = { normal = Vector3.new(0, -1, 0), axisA = Vector3.new(1, 0, 0), axisB = Vector3.new(0, 0, 1), sizeA = "X", sizeB = "Z" },
    Left   = { normal = Vector3.new(-1, 0, 0), axisA = Vector3.new(0, 0, 1), axisB = Vector3.new(0, 1, 0), sizeA = "Z", sizeB = "Y" },
    Right  = { normal = Vector3.new(1, 0, 0),  axisA = Vector3.new(0, 0, 1), axisB = Vector3.new(0, 1, 0), sizeA = "Z", sizeB = "Y" },
}
-- ด้านหลักที่พบจริงจากการทดสอบ (ใช้เป็น fallback เมื่ออ่านด้านจาก Decal ไม่ได้)
local ACTIVE_FACES = { "Front", "Top" }

-- v2.1: คราบเป็น Decal/Texture ซึ่งมี .Face บอกด้านที่แปะอยู่ตรงๆ — ฉีดเฉพาะด้านที่มีคราบจริง
-- (เดิมฉีด Front/Top ตายตัว คราบด้านอื่นเลยฉีดครบแต่คะแนนไม่ขึ้น) ไม่เจอ Decal ค่อยใช้ fallback
local function dirtFacesOf(part)
    local seen = {}
    for _, d in ipairs(part:GetDescendants()) do
        if (d:IsA("Decal") or d:IsA("Texture")) and d.Transparency < 0.99 then
            seen[d.Face.Name] = true
        end
    end
    local out = {}
    for f in pairs(seen) do
        if FACES[f] then out[#out + 1] = f end
    end
    if #out == 0 then return ACTIVE_FACES end
    return out
end

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

-- ==================== ระบบพัก (กันข้อความ "คุณไม่ได้พักเลย!" จากการฉีดต่อเนื่องไม่หยุด) ====================
local sprayBurstCount = 0
local SPRAY_BURSTS_BEFORE_REST = 60 -- v2.0: batch ใหญ่ขึ้น จำนวน burst รวมน้อยลง พักถี่เท่าเดิมไม่จำเป็น
local REST_DURATION = 1.5
local function maybeRest()
    sprayBurstCount += 1
    if sprayBurstCount >= SPRAY_BURSTS_BEFORE_REST then
        sprayBurstCount = 0
        setStatus("[AutoSpray77] 💤 พักสักครู่ (กันเกมเตือน 'ไม่ได้พักเลย')...")
        task.wait(REST_DURATION)
    end
end

-- ==================== ฉีดล้าง 1 ด้านของ Part ให้ครบ ====================
local function sprayFace(part, faceName)
    if not part.Parent then return end
    local points = faceGridPoints(part, faceName)
    if #points == 0 then return end

    local normal = part.CFrame:VectorToWorldSpace(FACES[faceName].normal)
    local BATCH = 20 -- v2.0: 8→20 จุดต่อชุด
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
        task.wait(0.05) -- v2.0: 0.12→0.05
        maybeRest()
    end
    pcall(function() learnedRemote:FireServer("reportWashProgress", part, faceName, 1) end)
    task.wait(0.08)
    pcall(function() learnedRemote:FireServer("reportSurfaceComplete", part, faceName) end)
    task.wait(0.08)
end

-- ==================== อ่านความคืบหน้าจริงจาก HUD เกม ("วัตถุที่ล้างแล้ว: X/Y") ====================
local function getGameProgress()
    for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = d.Text
            if t:find("ล้างแล้ว") then
                local done, total = t:match("(%d+)%s*/%s*(%d+)")
                if done and total then return tonumber(done), tonumber(total) end
            end
        end
    end
    return nil, nil
end

-- ==================== SPRAY: ไล่ล้างคราบทั้งหมด ====================
local function runSpray()
    if learnedRemote and not learnedRemote.Parent then
        learnedRemote = nil -- remote ที่จำไว้โดนทำลายไปแล้ว (เช่น เข้าเซิร์ฟเวอร์ใหม่) ต้องหาใหม่
    end
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

    -- Dirt.Part เป็น Part ที่เกม "รียูส" แทนคราบใหม่ไปเรื่อยๆ (ตำแหน่งขยับทุกงาน) ไม่ใช่ลิสต์ตายตัว
    -- เพราะงั้นวนฉีดตามตำแหน่งปัจจุบันของมันไปเรื่อยๆ ไม่จำกัดรอบ จนกว่าเกมจะรายงานว่าล้างครบ หรือผู้ใช้กด STOP
    local rounds = 0
    while SPRAY_ON do
        local dirtParts = findDirtParts()
        if #dirtParts == 0 then
            setStatus("[AutoSpray77] ไม่พบจุดสกปรกตอนนี้ — รอสักครู่...")
            task.wait(1)
        else
            for _, part in ipairs(dirtParts) do
                if not SPRAY_ON then break end
                -- v1.9: เช็คซ้ำก่อนฉีดทุกจุด — จุดที่สะอาดไปแล้วระหว่างรอบ (โปร่งใสแล้ว) ข้ามเลย
                -- ทำให้ SPRAY "เริ่มจากจุดที่ยังไม่สะอาด" เสมอ ไม่วนนับจาก 0 ใหม่
                if part.Parent and dirtVisible(part) then
                    local doneNow = getGameProgress()
                    setStatus(("[AutoSpray77] ฉีด: %s (ล้างแล้ว %s)"):format(part.Name, doneNow or "?"))
                    flyTo(part.Position, 6)
                    task.wait(0.05) -- v2.0: 0.15→0.05
                    for _, faceName in ipairs(dirtFacesOf(part)) do
                        if not SPRAY_ON then break end
                        sprayFace(part, faceName)
                    end
                end
            end
            rounds += 1
        end

        local doneN, totalN = getGameProgress()
        if doneN and totalN then
            setStatus(("[AutoSpray77] ล้างไปแล้ว %d/%d ตามที่เกมนับ (รอบที่ %d)"):format(doneN, totalN, rounds))
            if doneN >= totalN then
                setStatus(("[AutoSpray77] ✅ ล้างครบ %d/%d แล้ว! จบงาน"):format(doneN, totalN))
                break
            end
        end
        task.wait(0.3)
    end
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
    guideStop()
    guideB.Text = "GUIDE: OFF (เส้นชี้จุดสกปรก 3 จุด)"
    setStatus("[AutoSpray77] หยุดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    SPRAY_ON = false
    guideStop()
    for _, c in ipairs(_G.SPR77_CONNS) do pcall(function() c:Disconnect() end) end
    _G.SPR77_CONNS = {}
    gui:Destroy(); _G.SPR77_GUI = nil
end)

-- ==================== Setup ====================
hookLearn()
tryAutoFindRemote()
warn("[AutoSpray77] loaded")
