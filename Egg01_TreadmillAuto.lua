-- Egg01 Treadmill Auto v1.0 SIMPLE
-- หาเครื่องวิ่งใกล้สุด -> เดินไป -> วิ่งบนเครื่อง

if _G.EGG01_TREADMILL then
    _G.EGG01_TREADMILL.run = false
    pcall(function() _G.EGG01_TREADMILL.gui:Destroy() end)
end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local S = { run = false, gui = nil }
_G.EGG01_TREADMILL = S

local function parts()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function getSpeed()
    local stats = LP:FindFirstChild("leaderstats")
    local v = stats and stats:FindFirstChild("Speed")
    return v and tonumber(v.Value) or nil
end

local function nearestTreadmill()
    local _, root = parts()
    if not root then return nil end
    local best, bestD
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("BasePart") and item.Name == "TreadmillBottom" then
            local d = (item.Position - root.Position).Magnitude
            if not bestD or d < bestD then best, bestD = item, d end
        end
    end
    return best, bestD
end

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_TreadmillAuto"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1003
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 300, 0, 112)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -45, 0, 24)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 Treadmill Auto"

local function button(text, x, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 70, 0, 28)
    b.Position = UDim2.new(0, x, 0, 34)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = text
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bStart = button("START", 10, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 88, Color3.fromRGB(165, 50, 55))
local bClose = button("X", 220, Color3.fromRGB(125, 45, 45))
bClose.Size = UDim2.new(0, 30, 0, 24)
bClose.Position = UDim2.new(1, -38, 0, 3)

local status = Instance.new("TextLabel", panel)
status.Size = UDim2.new(1, -20, 0, 42)
status.Position = UDim2.new(0, 10, 0, 68)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(140, 235, 160)
status.Font = Enum.Font.GothamBold
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "กำลังรอเริ่ม…"

local function say(text)
    status.Text = tostring(text)
end

local function start()
    if S.run then return end
    local bottom, distance = nearestTreadmill()
    if not bottom then say("ไม่พบ TreadmillBottom") return end
    S.run = true
    bStart.Text = "..."
    task.spawn(function()
        local hum, root = parts()
        local target = bottom.CFrame:PointToWorldSpace(Vector3.new(0, bottom.Size.Y * 0.5 + 2.5, 0))
        say(string.format("เจอเครื่อง d=%.0f — กำลังไป", distance or -1))
        local timeout = os.clock() + 35
        while S.run and os.clock() < timeout do
            hum, root = parts()
            if not hum or not root or hum.Health <= 0 then break end
            local goal = Vector3.new(target.X, root.Position.Y, target.Z)
            local d = (goal - root.Position).Magnitude
            if d <= 5 then break end
            hum:MoveTo(goal)
            say(string.format("กำลังไปเครื่องวิ่ง d=%.0f", d))
            task.wait(0.35)
        end
        if not S.run then return end
        hum, root = parts()
        if not hum or not root or (Vector3.new(target.X, root.Position.Y, target.Z) - root.Position).Magnitude > 6 then
            say("ไปเครื่องวิ่งไม่สำเร็จ")
            S.run = false
            bStart.Text = "START"
            return
        end
        local before = getSpeed()
        local untilAt = os.clock() + 45
        local n = 0
        say("ถึงเครื่องแล้ว — เริ่มวิ่ง | Speed=" .. tostring(before or "?"))
        while S.run and os.clock() < untilAt do
            hum, root = parts()
            if not hum or not root or not bottom.Parent or hum.Health <= 0 then break end
            local offset = Vector3.new(math.sin(n) * 1.2, bottom.Size.Y * 0.5 + 2.5, math.cos(n) * 1.2)
            local step = bottom.CFrame:PointToWorldSpace(offset)
            hum:MoveTo(Vector3.new(step.X, root.Position.Y, step.Z))
            n = n + math.pi * 0.5
            if n % 20 < 2 then say("วิ่งบนเครื่อง | Speed=" .. tostring(getSpeed() or "?")) end
            task.wait(0.18)
        end
        say(string.format("จบ | Speed %s → %s", tostring(before or "?"), tostring(getSpeed() or "?")))
        S.run = false
        bStart.Text = "START"
    end)
end

bStart.MouseButton1Click:Connect(start)
bStop.MouseButton1Click:Connect(function() S.run = false; bStart.Text = "START"; say("STOP") end)
bClose.MouseButton1Click:Connect(function() S.run = false; gui:Destroy(); _G.EGG01_TREADMILL = nil end)

say("โหลดแล้ว — เริ่มหาเครื่องวิ่งอัตโนมัติ")
task.delay(1, start)
