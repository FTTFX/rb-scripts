-- 77RB_HouseClean_AutoFly.lua v1.9 — บิน+จับ+วางของอัตโนมัติ (เกม "ล้างบ้านขำๆ")
-- v1.9: หาสล็อตเป้าหมายไว้ก่อนจับของเลย (ไม่ต้องรอจับก่อนค่อยหา) แล้วตัดเวลารอ 0.35s เปล่าๆ หลังจับออก
--   (ให้ระยะทางบินไปสล็อตกินเวลาแทน ไม่ต้องหยุดรอเฉยๆ) ทำให้แต่ละชิ้นเร็วขึ้นโดยยังปลอดภัยเท่าเดิม
-- v1.8: ความเร็ว 200 เร็วไปจนวางของไม่ผ่าน (ตำแหน่งอาจยังไม่ซิงก์ขึ้นเซิร์ฟเวอร์ตอนยิง remote) — ลดเหลือ 100
--   และเพิ่ม task.wait(0.15) หลังบินถึงก่อนยิง remote ทุกครั้ง ให้ตำแหน่งนิ่ง/ซิงก์ก่อน
-- v1.7: เพิ่มความเร็วบิน FLY_SPEED 60 → 200 ตามที่ขอ
-- อ้างอิงผลจาก 77RB_HouseClean_NetSpy.lua ที่ยืนยันแล้ว:
--   จับของ:  RemoteEvent:FireServer("pickupItem", <Part ของที่จะจับ>)
--   วางของ:  RemoteEvent:FireServer("placeCarried", <Part สล็อตที่จะวาง>, <Part ของที่ถือ>)
--   โครงสร้าง: workspace.House_<N>.Items (ของกระจาย) / workspace.House_<N>.Slots (จุดวาง)
-- v1.1: v1.0 เดาสล็อตแบบ "ชื่อขึ้นต้นด้วย" (prefix match) แล้วพบว่าหยิบ/วางผิดจุดบ่อย เพราะของหลายชิ้น
--   ตั้งชื่อ Part ซ้ำกันแบบ generic (เช่น "Model") ทำให้ prefix match จับคู่มั่ว
-- v1.2: ลองอ่านไฟไฮไลต์สีฟ้า (Highlight → Ghost ใน workspace.Camera.SortingGhosts) แทนการเดาชื่อ
--   แต่จาก NetSpy log ล่าสุดพบว่า Ghost หลายอันไฮไลต์ค้างพร้อมกันได้ (ไม่ได้ผูกกับของที่ถืออยู่ตัวเดียว)
--   ทำให้ "หยิบไฮไลต์ตัวแรกที่เจอ" ยังคงสุ่มผิดได้เหมือนเดิม
-- v1.3: กลับมาใช้ชื่อ แต่เปลี่ยนจาก prefix match เป็น**เทียบชื่อตรงตัวเป๊ะ** — ชื่อ Ghost ที่ NetSpy ดักได้
--   ("CouchHomeGhost", "BookHomeGhost", "Hanging Lights VarHomeGhost") ยืนยันแพทเทิร์นสล็อตชัดเจนว่า =
--   <ชื่อของ>Home เป๊ะทุกตัว ไม่มีข้อยกเว้น เพราะงั้นใช้ slotsFolder:FindFirstChild(item.Name.."Home")
--   ตรงๆ แม่นกว่าทั้ง prefix-guess (v1.0) และการอ่านไฮไลต์ที่กำกวม (v1.2)
--   เพิ่มดักข้อความ "มือเต็ม" ตรงๆ จาก popup ในเกม เพื่อหยุด AUTO ทันทีถ้าของค้างมือ
-- v1.4: เจอบั๊ก "สำเร็จ 0 ทั้งที่จับคู่ถูกทุกตัว" เพราะ cache instance Cash ไว้ตัวเดียวตอนเริ่ม ถ้า leaderstats
--   โดนสร้างใหม่ระหว่างรัน (เช่น respawn) reference จะค้าง เช็คเงินไม่ขึ้นตลอด ทั้งที่วางสำเร็จจริง
--   แก้เป็นค้นหา leaderstats.Cash ใหม่สดๆ ทุกครั้งที่เช็ค แทนการ cache ไว้ล่วงหน้า
-- v1.5: เจอว่าของชื่อเดียวกัน (เช่น "Book") มี attribute PairId/RoomName/RoomId ต่างกันตามห้องที่อยู่
--   (Book ห้อง Office PairId=66, ห้อง Hallway PairId=43) แปลว่าสล็อตชื่อ "<ชื่อของ>Home" อาจมีซ้ำกันได้
--   หลายจุดคนละห้อง — ถ้าใช้ FindFirstChild ตัวเดียวจะได้จุดแรกที่เจอเสมอ ผิดห้องได้ถ้าของมาจากห้องอื่น
--   แก้เป็นหาโดย GetDescendants ทั้งหมดที่ชื่อตรง แล้วถ้าเจอมากกว่า 1 จุด เทียบ PairId ก่อน (แม่นสุด)
--   ตกไป RoomId ถ้าไม่มี PairId ตรง ก่อนจะ fallback ไปจุดแรกที่เจอ
-- v1.6: ผู้ใช้ขอให้บินไปตาม "จุดเรืองแสง" (Ghost) ที่เห็นจริงบนจอ แทนตำแหน่ง Slot ที่คำนวณเอง
--   เพิ่ม getGhostPosition() ดึงตำแหน่งจริงจาก workspace.Camera.SortingGhosts.<ชื่อสล็อต>Ghost มาบินไปแทน
--   remote ยังคงยิงด้วย Slot instance ที่จับคู่ถูกจาก v1.5 เหมือนเดิม (แค่เปลี่ยนจุดที่บินไปให้ตรงตาเห็น)
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
local FLY_SPEED = 100
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

-- ==================== หาสล็อตเป้าหมายจากชื่อ + PairId/RoomId (กันชื่อซ้ำข้ามห้อง) ====================
-- ยืนยันจาก NetSpy: item มี attribute PairId/RoomName/RoomId (เช่น Book ตัวใน "Office" PairId=66,
-- ตัวใน "Hallway" PairId=43) แปลว่าของชื่อเดียวกันอาจมีสล็อตชื่อ "<ชื่อของ>Home" ซ้ำกันได้หลายห้อง
-- ถ้าเจอสล็อตชื่อตรงมากกว่า 1 จุด ต้องเทียบ PairId ก่อน (แม่นสุด) แล้วค่อย RoomId ถ้าไม่มี PairId ตรง
local function findSlotFor(item, slotsFolder)
    local wantName = item.Name .. "Home"
    local candidates = {}
    for _, s in ipairs(slotsFolder:GetDescendants()) do
        if s.Name == wantName then
            candidates[#candidates + 1] = s
        end
    end
    if #candidates == 0 then return nil end
    if #candidates == 1 then return candidates[1] end

    local pairId = item:GetAttribute("PairId")
    if pairId ~= nil then
        for _, s in ipairs(candidates) do
            if s:GetAttribute("PairId") == pairId then return s end
        end
    end
    local roomId = item:GetAttribute("RoomId")
    if roomId ~= nil then
        for _, s in ipairs(candidates) do
            if s:GetAttribute("RoomId") == roomId then return s end
        end
    end
    return candidates[1]
end

-- ==================== ตำแหน่งจริงของจุดเรืองแสง (Ghost) — บินไปตามที่ตาเห็นจริงบนจอ ====================
-- ยืนยันจาก NetSpy [ARROW]: workspace.Camera.SortingGhosts มี Ghost ชื่อ "<ชื่อสล็อต>Ghost" ต่อสล็อต 1 จุด
local function getGhostPosition(slot)
    local ghostFolder = workspace:FindFirstChild("Camera")
    ghostFolder = ghostFolder and ghostFolder:FindFirstChild("SortingGhosts")
    if not ghostFolder then return nil end
    local ghost = ghostFolder:FindFirstChild(slot.Name .. "Ghost")
    if not ghost then return nil end
    if ghost:IsA("BasePart") then return ghost.Position end
    if ghost:IsA("Model") then
        if ghost.PrimaryPart then return ghost.PrimaryPart.Position end
        local ok, cf = pcall(function() return ghost:GetPivot() end)
        if ok then return cf.Position end
    end
    return nil
end

-- ==================== ดักข้อความ "มือเต็ม!" ตรงๆ จาก popup ในเกม ====================
local HAND_FULL_FLAG = false
local function looksLikeHandFullText(t)
    return t and (t:find("มือเต็ม") ~= nil)
end
local function watchHandFull()
    local function hook(inst)
        if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then return end
        local function check()
            if looksLikeHandFullText(inst.Text) then HAND_FULL_FLAG = true end
        end
        check()
        table.insert(_G.AF77_CONNS, inst:GetPropertyChangedSignal("Text"):Connect(check))
    end
    for _, d in ipairs(LP.PlayerGui:GetDescendants()) do hook(d) end
    table.insert(_G.AF77_CONNS, LP.PlayerGui.DescendantAdded:Connect(hook))
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

    -- ค้นหา Cash ใหม่ทุกครั้ง (ไม่ cache instance ไว้) กัน reference ค้างถ้า leaderstats โดนสร้างใหม่ระหว่างรัน (เช่น respawn)
    local function getCashStat()
        local ls = LP:FindFirstChild("leaderstats")
        return ls and ls:FindFirstChild("Cash")
    end
    local function getCash()
        local c = getCashStat()
        return c and c.Value or 0
    end

    -- สร้างรายการของทั้งหมดไว้แค่ "รู้ว่ามีอะไรบ้าง/มีกี่ชิ้น" — สล็อตเป้าหมายจริงจะอ่านจากไฟไฮไลต์
    -- สดๆ ทีละชิ้นหลังจับ (ไม่ใช้คู่ที่เดาไว้ล่วงหน้า เพราะของหลายชิ้นตั้งชื่อ Part ซ้ำกันแบบ generic)
    local totalItems = 0
    local houseOfItem = {}
    for _, house in ipairs(findHouses()) do
        for _, item in ipairs(house.Items:GetChildren()) do
            totalItems += 1
            houseOfItem[item] = house
        end
    end
    if totalItems == 0 then
        setStatus("[AutoFly77] ไม่พบของที่ต้องเก็บ (อาจวางครบแล้ว) — จบ")
        AUTO_ON = false
        autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
        return
    end
    setStatus(("[AutoFly77] พบของ %d ชิ้น — เริ่มบินเก็บ-วางทีละชิ้น"):format(totalItems))

    HAND_FULL_FLAG = false
    watchHandFull()
    local ABORT_HANDFULL = "[AutoFly77] ⛔ หยุด AUTO เพราะเกมแจ้ง \"มือเต็ม\" — ไปวาง/ทิ้งของที่ถืออยู่เองก่อน แล้วค่อยกด AUTO ใหม่"

    local processed, failed, noSlot = 0, 0, 0
    local i = 0
    for item, house in pairs(houseOfItem) do
        i += 1
        if not AUTO_ON then break end
        if HAND_FULL_FLAG then
            setStatus(ABORT_HANDFULL)
            AUTO_ON = false
            autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
            return
        end
        if item.Parent then
            -- สล็อตเป้าหมาย = <ชื่อของ>Home เป๊ะ (ยืนยันจากชื่อ Ghost ในแผนที่ผ่าน NetSpy [ARROW])
            -- หาไว้ก่อนจับ เพื่อบินตรงไปจุดเดียว (item → slot ในเที่ยวเดียว) แทนที่จะบินไปของก่อนแล้วค่อยบินไปสล็อต
            local slot = findSlotFor(item, house.Slots)

            setStatus(("[AutoFly77] (%d/%d) กำลังบินไปเก็บ: %s"):format(i, totalItems, item.Name))
            local ipos = partPosition(item)
            if ipos then flyTo(ipos, 6) end
            task.wait(0.15) -- รอตำแหน่งซิงก์ขึ้นเซิร์ฟเวอร์ก่อนยิง remote (บินเร็วไปแล้วยิงทันทีอาจถูกปฏิเสธ)
            local ok1 = pcall(function() learnedRemote:FireServer("pickupItem", item) end)

            if not slot or not slot.Parent then
                noSlot += 1
                task.wait(0.1)
                setStatus(("[AutoFly77] ⚠️ %s ไม่มีสล็อต %sHome ในแผนที่ — ข้าม"):format(item.Name, item.Name))
            else
                -- บินไปตามตำแหน่งจุดเรืองแสง (Ghost) ที่เห็นจริงบนจอทันที ระหว่างบินก็ถือว่ารอไฟไฮไลต์อัปเดตไปด้วยในตัว
                -- (ไม่ต้องหยุดรอเฉยๆ 0.35s แบบเดิม เพราะระยะทางบินเองก็กินเวลาพอที่ไฮไลต์จะอัปเดตทันอยู่แล้ว)
                local spos = getGhostPosition(slot) or partPosition(slot)
                if spos then flyTo(spos, 6) end

                if HAND_FULL_FLAG then
                    setStatus(ABORT_HANDFULL)
                    AUTO_ON = false
                    autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
                    return
                end

                setStatus(("[AutoFly77] (%d/%d) กำลังบินไปวาง: %s → %s"):format(i, totalItems, item.Name, slot.Name))
                task.wait(0.15) -- รอตำแหน่งซิงก์ขึ้นเซิร์ฟเวอร์ก่อนยิง remote
                local cashBefore = getCash()
                local ok2 = pcall(function() learnedRemote:FireServer("placeCarried", slot, item) end)
                task.wait(0.4)

                -- เช็คความสำเร็จจากเงินที่เพิ่มขึ้นจริง (แม่นกว่าเช็ค Parent ของ item เพราะบางเกมไม่ลบ item ทิ้ง)
                -- ถ้าหา leaderstats.Cash ไม่เจอเลย ไม่มีทางเช็คได้ ก็ถือว่าสำเร็จตาม remote call แทน
                if ok1 and ok2 and (not getCashStat() or getCash() > cashBefore) then
                    processed += 1
                else
                    failed += 1
                    setStatus(("[AutoFly77] ⚠️ %s วางไม่สำเร็จ"):format(item.Name))
                    task.wait(0.5)
                end
            end
        end
    end

    setStatus(("[AutoFly77] ✅ จบแล้ว! สำเร็จ %d, พลาด %d, ไม่มีสล็อต %d"):format(processed, failed, noSlot))
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
