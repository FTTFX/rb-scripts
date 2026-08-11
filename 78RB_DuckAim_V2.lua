-- 78RB_DuckAim_V2.lua v2.0 — โหมดคลิกล้วน: ล็อกกล้องใส่เป็ด + แตะยิงให้ปืนเกมยิงเอง (เกม "ยิงเป็ด" 78)
-- แนวคิด (สรุปจากการสปายทั้งหมด):
--   • ปืนเกมนี้ไม่ใช่ Tool มาตรฐาน + เซิร์ฟเวอร์คุม fire rate/แม็ก/รีโหลดเอง
--   • ยิงรีโมตเองทำ counter แซง = นัดถูกทิ้ง → สู้ปล่อยปืนเกมยิงเองไม่ได้
--   • วิธีนี้: เล็งกล้องใส่เป็ดใกล้สุด (snap เป๊ะ) แล้ว "แตะจอ" (VIM) ให้ปืนยิง — เกมจัดการแม็ก/
--     รีโหลดเอง ไม่ต้องตั้งค่า อัปปืนแล้วเร็วตามทันที
--   • แตะห่างตาม "หน่วงยิง" (ไม่ถี่จนแย่งจอ) — ปรับด้วย −/+
-- GUI: ปุ่มเดียว เปิด/ปิด (คีย์ J) + −/+ หน่วงยิง + หัวหน้าต่างโชว์ ฆ่า/วิ
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
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local mouse = LP:GetMouse()

local RUN_ON = false
local FIRE_DELAY = 0.45  -- วิ/แตะ (ห่างพอไม่แย่งจอ — เกมจะยิงตาม fire rate ปืนเอง) ปรับ −/+
local AIM_SNAP = true    -- snap กล้องเป๊ะตอนแตะ (ปืนยิงตามกล้อง)

-- บิน + วาปบ้าน
local FLY_ON, FLY_SPEED = false, 200
local upHeld, downHeld = false, false
local flyBV, flyConn
local HOME = nil -- จุดบ้าน (จำตอนสปอว์น)
local function hrp() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function humo() local c = LP.Character return c and c:FindFirstChildOfClass("Humanoid") end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DuckAimV2"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.DV2_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 230, 0, 280); frame.Position = UDim2.new(0, 8, 0.28, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.18
frame.Active = true; frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -8, 0, 20); title.Position = UDim2.new(0, 4, 0, 4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(255, 200, 120)
title.Text = "🦆 DuckAim V2 (คลิก)"; title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -8, 0, 30); status.Position = UDim2.new(0, 4, 0, 24)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(180, 255, 180)
status.TextSize = 11; status.Font = Enum.Font.Code; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.TextYAlignment = Enum.TextYAlignment.Top
local function setStatus(s) status.Text = s end

-- บรรทัดดีบัก (หาบัค) — โชว์สถานะลูปสดๆ
local dbg = Instance.new("TextLabel", frame)
dbg.Size = UDim2.new(1, -8, 0, 28); dbg.Position = UDim2.new(0, 4, 0, 248)
dbg.BackgroundColor3 = Color3.fromRGB(20, 20, 30); dbg.BackgroundTransparency = 0.2
dbg.TextColor3 = Color3.fromRGB(120, 230, 255); dbg.TextSize = 10; dbg.Font = Enum.Font.Code
dbg.TextXAlignment = Enum.TextXAlignment.Left; dbg.TextWrapped = true
dbg.Text = "dbg: (ยังไม่เปิด)"
local function setDbg(s) dbg.Text = "dbg: " .. s end

local mainB = Instance.new("TextButton", frame)
mainB.Size = UDim2.new(1, -8, 0, 34); mainB.Position = UDim2.new(0, 4, 0, 58)
mainB.Text = "เปิด: OFF (คีย์ J)"; mainB.Font = Enum.Font.GothamBold; mainB.TextSize = 14
mainB.BackgroundColor3 = Color3.fromRGB(190, 60, 60); mainB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", mainB).CornerRadius = UDim.new(0, 6)

-- แถวหน่วงยิง −/+
local rMinus = Instance.new("TextButton", frame)
rMinus.Size = UDim2.new(0, 32, 0, 26); rMinus.Position = UDim2.new(0, 4, 0, 98)
rMinus.BackgroundColor3 = Color3.fromRGB(120, 50, 50); rMinus.TextColor3 = Color3.new(1,1,1)
rMinus.Font = Enum.Font.GothamBold; rMinus.TextSize = 18; rMinus.Text = "−"
local rLbl = Instance.new("TextLabel", frame)
rLbl.Size = UDim2.new(0, 150, 0, 26); rLbl.Position = UDim2.new(0, 40, 0, 98)
rLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 45); rLbl.TextColor3 = Color3.fromRGB(255, 230, 150)
rLbl.Font = Enum.Font.Code; rLbl.TextSize = 13
Instance.new("UICorner", rLbl).CornerRadius = UDim.new(0, 5)
local rPlus = Instance.new("TextButton", frame)
rPlus.Size = UDim2.new(0, 32, 0, 26); rPlus.Position = UDim2.new(0, 194, 0, 98)
rPlus.BackgroundColor3 = Color3.fromRGB(50, 120, 50); rPlus.TextColor3 = Color3.new(1,1,1)
rPlus.Font = Enum.Font.GothamBold; rPlus.TextSize = 18; rPlus.Text = "+"
local function refreshRLbl() rLbl.Text = ("หน่วงยิง %.2f วิ"):format(FIRE_DELAY) end
refreshRLbl()

-- แถวบิน + วาปบ้าน
local flyB = Instance.new("TextButton", frame)
flyB.Size = UDim2.new(0, 109, 0, 28); flyB.Position = UDim2.new(0, 4, 0, 128)
flyB.Text = "บิน: OFF (F)"; flyB.Font = Enum.Font.GothamBold; flyB.TextSize = 12
flyB.BackgroundColor3 = Color3.fromRGB(60, 110, 180); flyB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", flyB).CornerRadius = UDim.new(0, 5)
local homeB = Instance.new("TextButton", frame)
homeB.Size = UDim2.new(0, 109, 0, 28); homeB.Position = UDim2.new(0, 117, 0, 128)
homeB.Text = "🏠 บ้าน (B)"; homeB.Font = Enum.Font.GothamBold; homeB.TextSize = 12
homeB.BackgroundColor3 = Color3.fromRGB(150, 110, 50); homeB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", homeB).CornerRadius = UDim.new(0, 5)

-- แถวขึ้น/ลง (บิน)
local upB = Instance.new("TextButton", frame)
upB.Size = UDim2.new(0, 109, 0, 28); upB.Position = UDim2.new(0, 4, 0, 160)
upB.Text = "▲ ขึ้น"; upB.Font = Enum.Font.GothamBold; upB.TextSize = 13
upB.BackgroundColor3 = Color3.fromRGB(70, 90, 130); upB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", upB).CornerRadius = UDim.new(0, 5)
local downB = Instance.new("TextButton", frame)
downB.Size = UDim2.new(0, 109, 0, 28); downB.Position = UDim2.new(0, 117, 0, 160)
downB.Text = "▼ ลง"; downB.Font = Enum.Font.GothamBold; downB.TextSize = 13
downB.BackgroundColor3 = Color3.fromRGB(70, 90, 130); downB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", downB).CornerRadius = UDim.new(0, 5)

-- ปุ่มร้าน (เปิด/ปิด GUI ชื่อ Upgrades จากทุกที่ — ยืนยันด้วย GuiSpy)
local shopB = Instance.new("TextButton", frame)
shopB.Size = UDim2.new(1, -8, 0, 28); shopB.Position = UDim2.new(0, 4, 0, 192)
shopB.Text = "🛒 เปิดร้าน (H)"; shopB.Font = Enum.Font.GothamBold; shopB.TextSize = 14
shopB.BackgroundColor3 = Color3.fromRGB(150, 110, 50); shopB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", shopB).CornerRadius = UDim.new(0, 6)

local closeB = Instance.new("TextButton", frame)
closeB.Size = UDim2.new(1, -8, 0, 20); closeB.Position = UDim2.new(0, 4, 0, 224)
closeB.Text = "✕ ปิดหน้าต่าง"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 12
closeB.BackgroundColor3 = Color3.fromRGB(90, 40, 40); closeB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)

setStatus("[V2] กด J หรือปุ่ม เปิด — ถือปืนไว้แล้วปล่อยให้เล็ง+ยิงเอง")

-- ==================== ตัวนับ ฆ่า/วิ ====================
local killStat, killStatName = nil, "?"
local function findKillStat()
    if killStat and killStat.Parent then return killStat end
    killStat = nil
    local roots = {}
    local ls = LP:FindFirstChild("leaderstats")
    if ls then roots[#roots + 1] = ls end
    roots[#roots + 1] = LP
    for _, root in ipairs(roots) do
        if root then
            for _, v in ipairs(root:GetDescendants()) do
                if (v:IsA("IntValue") or v:IsA("NumberValue")) then
                    local ln = v.Name:lower()
                    if ln:find("duckskilled") or (ln:find("duck") and ln:find("kill")) or ln == "kills" then
                        killStat = v; killStatName = v.Name; return v
                    end
                end
            end
        end
    end
    return nil
end
local killBase, killWindow = nil, {}
task.spawn(function()
    while _G.DV2_GEN == MY_GEN do
        local s = findKillStat()
        local now = s and s.Value or nil
        if now then
            if not killBase then killBase = now end
            local t = os.clock()
            table.insert(killWindow, { t = t, total = now })
            while #killWindow > 1 and (t - killWindow[1].t) > 3 do table.remove(killWindow, 1) end
            local rate = 0
            if #killWindow >= 2 then
                local dt = killWindow[#killWindow].t - killWindow[1].t
                local dk = killWindow[#killWindow].total - killWindow[1].total
                if dt > 0 then rate = dk / dt end
            end
            title.Text = ("🦆 ฆ่า+%d  %.1f/วิ"):format(now - killBase, rate)
        end
        task.wait(0.25)
    end
end)

-- ==================== หาเป็ด ====================
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

-- กัน "จ่อยิงตัวเดิม/ตัวที่ตายแล้ว" — ยิงตัวไหนพักตัวนั้นแป๊บ ไปตัวถัดไป
local shotAt = {}
local SHOT_SKIP = 0.5
local function markShot(m) if m then shotAt[m] = os.clock() end end
local function recentlyShot(m)
    if not m.Parent then shotAt[m] = nil; return false end
    local t = shotAt[m]
    return t ~= nil and (os.clock() - t) < SHOT_SKIP
end

-- เช็ค "ไม่มีอะไรบัง" — เรย์จากกล้องถึงเป็ด ถ้าโดนต้นไม้/พื้นก่อน = ยิงไม่โดน ข้าม
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
local function duckVisible(origin, p, m)
    losParams.FilterDescendantsInstances = { LP.Character, m }
    return workspace:Raycast(origin, p - origin, losParams) == nil
end

-- เลือกเป้า: บอสมาก่อนเสมอ ล็อกจนตาย (ไม่ติดคูลดาวน์/ไม่สลับ) — ไม่มีบอสค่อยเป็ดใกล้สุดที่โล่ง
local function pickDuck(origin)
    local boss = findBoss()
    if boss then boss.isBoss = true; return boss end -- ล็อกบอสไว้ ยิงรัวจนตายค่อยเปลี่ยน
    local f = duckFolder(); if not f then return nil end
    local vis, any = {}, {}
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and isLiveDuck(m) and not recentlyShot(m) then
            local p = duckPos(m)
            if p then
                local e = { model = m, pos = p, dist = (p - origin).Magnitude }
                any[#any + 1] = e
                if duckVisible(origin, p, m) then vis[#vis + 1] = e end
            end
        end
    end
    local list = (#vis > 0) and vis or any -- มีตัวโล่งเอาโล่ง / ไม่มีก็ยิงตัวใกล้สุด
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list[1]
end

-- ==================== แตะยิง (ให้ปืนเกมยิงเอง) ====================
local function getTool()
    local ch = LP.Character
    if not ch then return nil end
    return ch:FindFirstChildWhichIsA("Tool")
end
local function doTap()
    local tool = getTool()
    if tool then pcall(function() tool:Activate() end) end -- เผื่อเป็น Tool
    -- แตะกลางจอ (VIM) — ปืนมือถือยิงจากการแตะจอ (แตะห่างตามหน่วงยิง = ไม่แย่งจอ)
    local vx = math.floor(Camera.ViewportSize.X / 2)
    local vy = math.floor(Camera.ViewportSize.Y / 2)
    pcall(function()
        VIM:SendMouseButtonEvent(vx, vy, 0, true, game, 0)
        VIM:SendMouseButtonEvent(vx, vy, 0, false, game, 0)
    end)
    pcall(function()
        VIM:SendTouchEvent(1, 1, vx, vy)
        VIM:SendTouchEvent(1, 3, vx, vy)
    end)
end
local function aimCameraAt(targetPos, snap)
    local cf = Camera.CFrame
    if snap then
        Camera.CFrame = CFrame.new(cf.Position, targetPos)
    else
        Camera.CFrame = cf:Lerp(CFrame.new(cf.Position, targetPos), 0.6)
    end
end

-- ==================== ลูปหลัก ====================
local function runStop()
    RUN_ON = false
    mainB.Text = "เปิด: OFF (คีย์ J)"
    mainB.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
end
local function runStart()
    RUN_ON = true
    mainB.Text = "เปิด: ON (กด J ปิด)"
    mainB.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
    _G.DV2_RUNID = (_G.DV2_RUNID or 0) + 1
    local myRun = _G.DV2_RUNID
    _G.DV2_LASTFIRE = 0
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not (RUN_ON and _G.DV2_GEN == MY_GEN and _G.DV2_RUNID == myRun) then
            conn:Disconnect(); return
        end
        local ok, err = pcall(function() -- กัน error ในลูปทำให้ทั้งตัวหยุด
            local f = duckFolder()
            local nDuck = 0
            if f then for _, m in ipairs(f:GetChildren()) do if m:IsA("Model") and isLiveDuck(m) then nDuck = nDuck + 1 end end end
            local origin = Camera.CFrame.Position
            local d = pickDuck(origin)
            if not d then setDbg(("รัน✓ เป็ด%d เป้า:ไม่มี"):format(nDuck)); return end
            local p = duckPos(d.model)
            if not p then setDbg("รัน✓ เป้าไม่มีตำแหน่ง"); return end
            local canFire = os.clock() - (_G.DV2_LASTFIRE or 0) >= FIRE_DELAY
            aimCameraAt(p, canFire and AIM_SNAP)
            setDbg(("รัน✓ เป็ด%d เป้า:%s ยิง:%s"):format(nDuck, d.model.Name:gsub("DuckController_Client_",""), canFire and "ได้" or "รอ"))
            if not canFire then return end
            _G.DV2_LASTFIRE = os.clock()
            doTap()
            if not d.isBoss then markShot(d.model) end -- บอสไม่พัก (ล็อกยิงจนตาย) เป็ดปกติพักไปตัวถัดไป
            setStatus(("[V2] %s %s"):format(d.isBoss and "👑 บอส" or "🎯", d.model.Name))
        end)
        if not ok then setDbg("❌ ERROR: " .. tostring(err)) end
    end)
    table.insert(_G.DV2_CONNS, conn)
end
local function toggle()
    if RUN_ON then runStop(); setDbg("กดปิดแล้ว") else setDbg("กดเปิดแล้ว — เริ่มลูป"); runStart() end
end

-- ==================== บิน (ความเร็ว 200) ====================
local function startFly()
    local root = hrp(); if not root then return end
    if flyBV then pcall(function() flyBV:Destroy() end) end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1, 1, 1) * 9e9
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = root
    FLY_ON = true
    flyB.Text = "บิน: ON (F)"; flyB.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
    flyConn = RunService.RenderStepped:Connect(function()
        if not FLY_ON or _G.DV2_GEN ~= MY_GEN then return end
        local root2 = hrp(); if not root2 then return end
        if flyBV.Parent ~= root2 then
            pcall(function() flyBV:Destroy() end)
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(1, 1, 1) * 9e9
            flyBV.Parent = root2
        end
        local h = humo()
        local dir = Vector3.zero
        if h then dir = dir + h.MoveDirection end -- จอย/WASD
        if upHeld then dir = dir + Vector3.new(0, 1, 0) end
        if downHeld then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        flyBV.Velocity = dir * FLY_SPEED
    end)
    table.insert(_G.DV2_CONNS, flyConn)
end
local function stopFly()
    FLY_ON = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then pcall(function() flyBV:Destroy() end); flyBV = nil end
    flyB.Text = "บิน: OFF (F)"; flyB.BackgroundColor3 = Color3.fromRGB(60, 110, 180)
end
local function flyToggle() if FLY_ON then stopFly() else startFly() end end

-- ==================== วาปกลับบ้าน ====================
-- บ้าน = จุดที่ตัวละครสปอว์น (จำอัตโนมัติตอนเกิด) — เผื่อไม่มีก็ใช้ตำแหน่งตอนโหลด
local function warpHome()
    local root = hrp()
    if not root then setStatus("[V2] ไม่เจอตัวละคร"); return end
    if not HOME then setStatus("[V2] ยังไม่รู้จุดบ้าน (รอเกิดใหม่ 1 ครั้ง)"); return end
    root.CFrame = CFrame.new(HOME + Vector3.new(0, 3, 0))
    setStatus("[V2] 🏠 วาปกลับบ้านแล้ว")
end
-- จำจุดบ้านตอนโหลด + ทุกครั้งที่เกิดใหม่ (จุดสปอว์น)
task.spawn(function()
    local root = hrp()
    if root then HOME = root.Position end
end)
table.insert(_G.DV2_CONNS, LP.CharacterAdded:Connect(function(chr)
    local root = chr:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.4) -- รอวาร์ปไปจุดสปอว์นจริงก่อนจำ
    if root and _G.DV2_GEN == MY_GEN then HOME = root.Position end
    if FLY_ON then stopFly(); startFly() end -- ต่อบินใหม่หลังเกิด
end))

-- ==================== ร้าน (เปิด/ปิด GUI ชื่อ Upgrades/Shop จากทุกที่) ====================
local SHOP_OPEN = false
local function shopToggle()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    SHOP_OPEN = not SHOP_OPEN
    for _, sg in ipairs(pg:GetChildren()) do
        if sg:IsA("ScreenGui") and (sg.Name == "Upgrades" or sg.Name == "Shop") then
            pcall(function() sg.Enabled = SHOP_OPEN end)
        end
    end
    shopB.Text = SHOP_OPEN and "🛒 ปิดร้าน (H)" or "🛒 เปิดร้าน (H)"
    shopB.BackgroundColor3 = SHOP_OPEN and Color3.fromRGB(120,70,60) or Color3.fromRGB(150,110,50)
end

-- ==================== ปุ่ม/คีย์ ====================
mainB.MouseButton1Click:Connect(toggle)
flyB.MouseButton1Click:Connect(flyToggle)
homeB.MouseButton1Click:Connect(warpHome)
shopB.MouseButton1Click:Connect(shopToggle)
-- แตะสลับ (มือถือ MouseButton1Down มักไม่ทำงาน — ใช้ Click ชัวร์กว่า) + เริ่มบินให้เอง
local function refreshUpDown()
    upB.BackgroundColor3 = upHeld and Color3.fromRGB(60,170,90) or Color3.fromRGB(70,90,130)
    downB.BackgroundColor3 = downHeld and Color3.fromRGB(60,170,90) or Color3.fromRGB(70,90,130)
    upB.Text = upHeld and "▲ ขึ้น ●" or "▲ ขึ้น"
    downB.Text = downHeld and "▼ ลง ●" or "▼ ลง"
end
upB.MouseButton1Click:Connect(function()
    upHeld = not upHeld; downHeld = false
    if upHeld and not FLY_ON then startFly() end
    refreshUpDown()
end)
downB.MouseButton1Click:Connect(function()
    downHeld = not downHeld; upHeld = false
    if downHeld and not FLY_ON then startFly() end
    refreshUpDown()
end)
rMinus.MouseButton1Click:Connect(function()
    FIRE_DELAY = math.clamp(FIRE_DELAY - 0.05, 0.1, 3); refreshRLbl()
end)
rPlus.MouseButton1Click:Connect(function()
    FIRE_DELAY = math.clamp(FIRE_DELAY + 0.05, 0.1, 3); refreshRLbl()
end)
closeB.MouseButton1Click:Connect(function()
    runStop()
    _G.DV2_GEN = _G.DV2_GEN + 1
    for _, c in ipairs(_G.DV2_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DV2_CONNS = {}
    gui:Destroy(); _G.DV2_GUI = nil
end)
table.insert(_G.DV2_CONNS, UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if _G.DV2_GEN ~= MY_GEN then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.J then toggle()
    elseif k == Enum.KeyCode.F then flyToggle()
    elseif k == Enum.KeyCode.B then warpHome()
    elseif k == Enum.KeyCode.H then shopToggle()
    elseif k == Enum.KeyCode.Space then upHeld = true
    elseif k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.LeftControl then downHeld = true
    end
end))
table.insert(_G.DV2_CONNS, UIS.InputEnded:Connect(function(input)
    local k = input.KeyCode
    if k == Enum.KeyCode.Space then upHeld = false
    elseif k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.LeftControl then downHeld = false
    end
end))

warn("[DuckAimV2] v2.4 loaded — คลิก(J) + บิน200(F) + วาปบ้าน(B)")
