-- 78RB_Fly.lua v1.0 — บิน + NOCLIP ทะลุกำแพง (ไฟล์อิสระ ใช้ได้ทุกเกม)
-- FLY: บินตามทิศที่บังคับ (จอยมือถือ/WASD) + ปุ่ม ขึ้น/ลง | NOCLIP: ปิดการชน เดิน/บินทะลุกำแพง
-- คีย์ลัด (PC): F = บิน, N = noclip, Space = ขึ้น, Shift = ลง | มือถือ: ใช้ปุ่มบนจอ
if _G.FLY78_CONNS then
    for _, c in ipairs(_G.FLY78_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.FLY78_GUI then pcall(function() _G.FLY78_GUI:Destroy() end) end
if _G.FLY78_BV then pcall(function() _G.FLY78_BV:Destroy() end) end
_G.FLY78_CONNS = {}
_G.FLY78_GEN = (_G.FLY78_GEN or 0) + 1
local MY_GEN = _G.FLY78_GEN

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== STATE ====================
local FLY_ON, NOCLIP_ON = false, false
local upHeld, downHeld = false, false
local SPEED = 60
local flyBV, flyConn, noclipConn

local function char() return LP.Character end
local function hrp()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "Fly78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.FLY78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 210, 0, 230); frame.Position = UDim2.new(0, 8, 0.55, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.2
frame.Active = true; frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -8, 0, 20); title.Position = UDim2.new(0, 4, 0, 4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(150, 220, 255)
title.Text = "🕊️ บิน + ทะลุกำแพง"; title.Font = Enum.Font.GothamBold; title.TextSize = 13

local function mkbtn(txt, y, w, x, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local flyB    = mkbtn("บิน: OFF (F)", 28, 202, 4, Color3.fromRGB(190, 60, 60))
local noclipB = mkbtn("NOCLIP: OFF (N)", 62, 202, 4, Color3.fromRGB(190, 60, 60))
local upB     = mkbtn("▲ ขึ้น", 96, 99, 4, Color3.fromRGB(60, 110, 180))
local downB   = mkbtn("▼ ลง", 96, 99, 107, Color3.fromRGB(60, 110, 180))
-- แถวความเร็ว
local spdMinus = mkbtn("−", 130, 46, 4, Color3.fromRGB(120, 60, 60))
local spdLbl   = Instance.new("TextLabel", frame)
spdLbl.Size = UDim2.new(0, 106, 0, 30); spdLbl.Position = UDim2.new(0, 52, 0, 130)
spdLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 40); spdLbl.TextColor3 = Color3.fromRGB(255, 230, 150)
spdLbl.Font = Enum.Font.Code; spdLbl.TextSize = 13; spdLbl.Text = " speed " .. SPEED
Instance.new("UICorner", spdLbl).CornerRadius = UDim.new(0, 6)
local spdPlus  = mkbtn("+", 130, 46, 160, Color3.fromRGB(60, 120, 60))
local stopB    = mkbtn("STOP", 164, 202, 4, Color3.fromRGB(150, 90, 40))
local closeB   = mkbtn("✕ ปิด", 198, 202, 4, Color3.fromRGB(90, 40, 40))

-- ==================== FLY ====================
local function startFly()
    local root = hrp()
    if not root then return end
    if flyBV then pcall(function() flyBV:Destroy() end) end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1, 1, 1) * 9e9
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = root
    _G.FLY78_BV = flyBV
    FLY_ON = true
    flyB.Text = "บิน: ON (F)"; flyB.BackgroundColor3 = Color3.fromRGB(60, 170, 90)

    flyConn = RunService.RenderStepped:Connect(function()
        if not FLY_ON or _G.FLY78_GEN ~= MY_GEN then return end
        local root2 = hrp()
        if not root2 then return end
        if flyBV.Parent ~= root2 then -- เกิดใหม่/รีสปอว์น → ต่อ BV ใหม่
            pcall(function() flyBV:Destroy() end)
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(1, 1, 1) * 9e9
            flyBV.Parent = root2
            _G.FLY78_BV = flyBV
        end
        local h = hum()
        local dir = Vector3.zero
        if h then dir = dir + h.MoveDirection end -- ทิศจากจอย/WASD (world space แนวราบ)
        if upHeld then dir = dir + Vector3.new(0, 1, 0) end
        if downHeld then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        flyBV.Velocity = dir * SPEED
    end)
    table.insert(_G.FLY78_CONNS, flyConn)
end

local function stopFly()
    FLY_ON = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then pcall(function() flyBV:Destroy() end); flyBV = nil; _G.FLY78_BV = nil end
    flyB.Text = "บิน: OFF (F)"; flyB.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
end

local function flyToggle()
    if FLY_ON then stopFly() else startFly() end
end

-- ==================== NOCLIP ====================
local function startNoclip()
    NOCLIP_ON = true
    noclipB.Text = "NOCLIP: ON (N)"; noclipB.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
    noclipConn = RunService.Stepped:Connect(function()
        if not NOCLIP_ON or _G.FLY78_GEN ~= MY_GEN then return end
        local c = char()
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
    table.insert(_G.FLY78_CONNS, noclipConn)
end

local function stopNoclip()
    NOCLIP_ON = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    noclipB.Text = "NOCLIP: OFF (N)"; noclipB.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
end

local function noclipToggle()
    if NOCLIP_ON then stopNoclip() else startNoclip() end
end

-- ==================== ปุ่ม/คีย์ ====================
flyB.MouseButton1Click:Connect(flyToggle)
noclipB.MouseButton1Click:Connect(noclipToggle)

-- ขึ้น/ลง = กดค้าง (รองรับทั้งเมาส์และนิ้ว)
upB.MouseButton1Down:Connect(function() upHeld = true end)
upB.MouseButton1Up:Connect(function() upHeld = false end)
downB.MouseButton1Down:Connect(function() downHeld = true end)
downB.MouseButton1Up:Connect(function() downHeld = false end)

spdMinus.MouseButton1Click:Connect(function()
    SPEED = math.max(10, SPEED - 10); spdLbl.Text = "speed " .. SPEED
end)
spdPlus.MouseButton1Click:Connect(function()
    SPEED = math.min(500, SPEED + 10); spdLbl.Text = "speed " .. SPEED
end)

stopB.MouseButton1Click:Connect(function()
    stopFly(); stopNoclip()
end)
closeB.MouseButton1Click:Connect(function()
    stopFly(); stopNoclip()
    for _, c in ipairs(_G.FLY78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.FLY78_CONNS = {}
    gui:Destroy(); _G.FLY78_GUI = nil
end)

table.insert(_G.FLY78_CONNS, UIS.InputBegan:Connect(function(input, processed)
    if _G.FLY78_GEN ~= MY_GEN then return end
    if input.KeyCode == Enum.KeyCode.F then flyToggle()
    elseif input.KeyCode == Enum.KeyCode.N then noclipToggle()
    elseif input.KeyCode == Enum.KeyCode.Space then upHeld = true
    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.LeftControl then downHeld = true
    end
end))
table.insert(_G.FLY78_CONNS, UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then upHeld = false
    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.LeftControl then downHeld = false
    end
end))

-- ต่อ noclip/fly ใหม่เมื่อเกิดใหม่ (รีสปอว์น)
table.insert(_G.FLY78_CONNS, LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if _G.FLY78_GEN ~= MY_GEN then return end
    if FLY_ON then stopFly(); startFly() end
end))

warn("[Fly78] v1.0 loaded — F บิน / N ทะลุกำแพง / จอย+ปุ่มขึ้นลง บังคับทิศ")
