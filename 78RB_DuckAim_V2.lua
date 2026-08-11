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

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DuckAimV2"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.DV2_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 230, 0, 150); frame.Position = UDim2.new(0, 8, 0.35, 0)
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

local closeB = Instance.new("TextButton", frame)
closeB.Size = UDim2.new(1, -8, 0, 20); closeB.Position = UDim2.new(0, 4, 0, 128)
closeB.Text = "✕ ปิดหน้าต่าง"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 12
closeB.BackgroundColor3 = Color3.fromRGB(90, 40, 40); closeB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)

setStatus("[V2] กด J หรือปุ่ม เปิด — ถือปืนไว้แล้วปล่อยให้เล็ง+ยิงเอง")

-- ==================== ตัวนับ ฆ่า/วิ ====================
local killStat, killStatName = nil, "?"
local function findKillStat()
    if killStat and killStat.Parent then return killStat end
    killStat = nil
    for _, root in ipairs({ LP:FindFirstChild("leaderstats"), LP }) do
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

-- เลือกเป็ดใกล้สุดที่ "โล่ง + ยังไม่เพิ่งยิง" (บอสมาก่อน)
local function pickDuck(origin)
    local boss = findBoss()
    if boss and not recentlyShot(boss.model) then return boss end
    local f = duckFolder(); if not f then return nil end
    local list = {}
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and isLiveDuck(m) and not recentlyShot(m) then
            local p = duckPos(m)
            if p and duckVisible(origin, p, m) then
                list[#list + 1] = { model = m, pos = p, dist = (p - origin).Magnitude }
            end
        end
    end
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
        local origin = Camera.CFrame.Position
        local d = pickDuck(origin)
        if not d then setStatus("[V2] ไม่เจอเป้าโล่ง — รอเป็ด"); return end
        local p = duckPos(d.model)
        if not p then return end
        local canFire = os.clock() - (_G.DV2_LASTFIRE or 0) >= FIRE_DELAY
        aimCameraAt(p, canFire and AIM_SNAP) -- ถึงจังหวะยิง = snap เป๊ะ / ไม่ถึง = ตามนุ่มๆ
        if not canFire then return end
        _G.DV2_LASTFIRE = os.clock()
        doTap()
        markShot(d.model)
        setStatus(("[V2] 🎯 %s"):format(d.model.Name))
    end)
    table.insert(_G.DV2_CONNS, conn)
end
local function toggle()
    if RUN_ON then runStop() else runStart() end
end

-- ==================== ปุ่ม/คีย์ ====================
mainB.MouseButton1Click:Connect(toggle)
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
    if input.KeyCode == Enum.KeyCode.J then toggle() end
end))

warn("[DuckAimV2] v2.0 loaded — โหมดคลิกล้วน กด J")
