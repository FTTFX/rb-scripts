-- Egg01_MoveSpy.lua v1.0
-- ทดสอบกลับ HOME 3 แบบ พร้อมวัดการเคลื่อนที่จริง

if _G.EGG01_MOVE_SPY then
    _G.EGG01_MOVE_SPY.stop = true
    pcall(function() _G.EGG01_MOVE_SPY.gui:Destroy() end)
    if _G.EGG01_MOVE_SPY.conns then
        for _, c in ipairs(_G.EGG01_MOVE_SPY.conns) do
            pcall(function() c:Disconnect() end)
        end
    end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local S = {
    gui = nil,
    conns = {},
    stop = false,
    running = false,
    runId = 0,
    home = nil,
}
_G.EGG01_MOVE_SPY = S

local ARRIVE_R = 7
local MIN_START_D = 20
local TIMEOUT = 45
local SAMPLE_DT = 0.10
local LOG_DT = 0.50
local BOOST_SPEED = 32
local HOP_STEP = 14
local HOP_DELAY = 0.10
local lines = {}
local carrying = "?" -- ไม่เดาจาก GUI; รอ FieldEggCarry ยืนยัน

local function charParts()
    local c = LP.Character
    if not c then return nil, nil end
    return c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

local function flatDist(a, b)
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_MoveSpy"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1001
gui.IgnoreGuiInset = true
pcall(function()
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 390, 0, 160)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
panel.BackgroundTransparency = 0.10
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -50, 0, 24)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 Move Spy v1.0"

local function mkBtn(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 30)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bClose = mkBtn("X", 352, 4, 30, Color3.fromRGB(130, 45, 45))
local bHome = mkBtn("SET HOME", 10, 36, 82, Color3.fromRGB(45, 100, 180))
local bStop = mkBtn("STOP", 298, 36, 82, Color3.fromRGB(165, 50, 50))
local bNormal = mkBtn("1 NORMAL", 10, 74, 116, Color3.fromRGB(55, 115, 180))
local bSpeed = mkBtn("2 SPEED 32", 137, 74, 116, Color3.fromRGB(45, 145, 75))
local bHop = mkBtn("3 HOP 14", 264, 74, 116, Color3.fromRGB(180, 125, 35))
local bCopy = mkBtn("COPY LOG", 103, 36, 82, Color3.fromRGB(75, 75, 82))
local bClear = mkBtn("CLEAR", 196, 36, 91, Color3.fromRGB(75, 75, 82))

local status = Instance.new("TextLabel", panel)
status.Size = UDim2.new(1, -20, 0, 44)
status.Position = UDim2.new(0, 10, 0, 111)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 220, 105)
status.Font = Enum.Font.GothamBold
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "ยืนในบ้านแล้วกด SET HOME จากนั้นออกไปไกลกว่า 20 studs"

local logBox = Instance.new("TextBox", gui)
logBox.Size = UDim2.new(0, 390, 0, 250)
logBox.Position = UDim2.new(0, 12, 0, 180)
logBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
logBox.BackgroundTransparency = 0.25
logBox.BorderSizePixel = 0
logBox.TextColor3 = Color3.fromRGB(185, 240, 190)
logBox.Font = Enum.Font.Code
logBox.TextSize = 11
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.ClearTextOnFocus = false
logBox.TextEditable = false
logBox.MultiLine = true
logBox.TextWrapped = false
logBox.Text = ""
Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 6)

local function say(msg)
    msg = tostring(msg)
    lines[#lines + 1] = msg
    if #lines > 180 then table.remove(lines, 1) end
    logBox.Text = table.concat(lines, "\n")
    logBox.CursorPosition = #logBox.Text + 1
    status.Text = msg
end

local function findNet(namePart)
    local packages = RS:FindFirstChild("Packages")
    local networking = packages and packages:FindFirstChild("Networking")
    if not networking then return nil end
    for _, item in ipairs(networking:GetDescendants()) do
        if item.Name:find(namePart, 1, true) then return item end
    end
    return nil
end

do
    local carryEvent = findNet("FieldEggCarry")
    if carryEvent and carryEvent:IsA("RemoteEvent") then
        S.conns[#S.conns + 1] = carryEvent.OnClientEvent:Connect(function(data)
            if typeof(data) ~= "table" then return end
            if data.IsCarrying == true then
                carrying = "Y"
                say("CARRY Y uid=" .. tostring(data.Uid or "?") .. " area=" .. tostring(data.AreaId or "?"))
            elseif data.IsCarrying == false then
                carrying = "N"
                say("CARRY N")
            end
        end)
        say("ฟัง FieldEggCarry ✅ (carry เริ่มต้น=? จนกว่า server ส่ง event)")
    else
        say("ไม่พบ FieldEggCarry — carry=?")
    end
end

local function playerSpeedInfo()
    local found = {}
    for k, v in pairs(LP:GetAttributes()) do
        local low = string.lower(tostring(k))
        if string.find(low, "speed", 1, true) or string.find(low, "move", 1, true) then
            found[#found + 1] = tostring(k) .. "=" .. tostring(v)
        end
    end
    local stats = LP:FindFirstChild("leaderstats")
    if stats then
        for _, v in ipairs(stats:GetChildren()) do
            local low = string.lower(v.Name)
            if string.find(low, "speed", 1, true) and v:IsA("ValueBase") then
                found[#found + 1] = "leaderstats." .. v.Name .. "=" .. tostring(v.Value)
            end
        end
    end
    return #found > 0 and table.concat(found, ", ") or "ไม่พบ Speed attribute/leaderstat"
end

local function restore(h, oldSpeed)
    if h and h.Parent then
        pcall(function()
            h.WalkSpeed = oldSpeed
            h:Move(Vector3.zero, false)
        end)
    end
end

local function finishRun(h, oldSpeed, mode, why, metrics)
    restore(h, oldSpeed)
    S.running = false
    local elapsed = math.max(os.clock() - metrics.t0, 0.001)
    local straightDone = math.max(metrics.startD - metrics.lastD, 0)
    say(string.format(
        "END %s result=%s time=%.2fs remain=%.1f path=%.1f avg=%.1f peak=%.1f back=%d wsChanges=%d",
        mode, why, elapsed, metrics.lastD, metrics.path,
        metrics.path / elapsed, metrics.peak, metrics.back, metrics.wsChanges
    ))
    say(string.format(
        "SUMMARY start=%.1f progress=%.1f directAvg=%.1f finalWS=%.1f restored=%.1f",
        metrics.startD, straightDone, straightDone / elapsed,
        metrics.lastWS, oldSpeed
    ))
end

local function runTest(mode)
    if S.running then
        say("มีการทดสอบอยู่ — กด STOP ก่อน")
        return
    end
    if not S.home then
        say("ยังไม่มี HOME — ยืนในบ้านแล้วกด SET HOME")
        return
    end
    local h, r = charParts()
    if not h or not r or h.Health <= 0 then
        say("ไม่พบ Humanoid/HumanoidRootPart")
        return
    end
    local startD = flatDist(r.Position, S.home)
    if startD < MIN_START_D then
        say(string.format("ใกล้ HOME เกินไป d=%.1f — ออกไปอย่างน้อย %d studs", startD, MIN_START_D))
        return
    end

    S.stop = false
    S.running = true
    S.runId = S.runId + 1
    local myId = S.runId
    local oldSpeed = h.WalkSpeed
    local requestedSpeed = oldSpeed
    if mode == "SPEED32" then
        requestedSpeed = BOOST_SPEED
        h.WalkSpeed = BOOST_SPEED
    end

    local metrics = {
        t0 = os.clock(),
        startD = startD,
        lastD = startD,
        path = 0,
        peak = 0,
        back = 0,
        wsChanges = 0,
        lastWS = h.WalkSpeed,
    }
    local lastPos = r.Position
    local lastAt = os.clock()
    local lastLog = -LOG_DT
    local lastMove = -1
    local lastHop = -1
    local lastState = h:GetState().Name

    say(string.format("=== TEST %d %s ===", myId, mode))
    say(string.format(
        "START pos=(%.1f,%.1f,%.1f) home=(%.1f,%.1f,%.1f) d=%.1f WS=%.1f targetWS=%.1f carry=%s",
        r.Position.X, r.Position.Y, r.Position.Z,
        S.home.X, S.home.Y, S.home.Z, startD, oldSpeed, requestedSpeed, carrying
    ))
    say("PLAYER " .. playerSpeedInfo())

    task.spawn(function()
        local result = "unknown"
        while S.running and not S.stop and S.runId == myId do
            local now = os.clock()
            if now - metrics.t0 >= TIMEOUT then
                result = "timeout"
                break
            end

            local hNow, rNow = charParts()
            if hNow ~= h or rNow ~= r or h.Health <= 0 then
                result = "character-changed"
                break
            end

            local pos = r.Position
            local d = flatDist(pos, S.home)
            if d <= ARRIVE_R then
                metrics.lastD = d
                result = "arrived"
                break
            end

            if mode == "NORMAL" or mode == "SPEED32" then
                if now - lastMove >= 0.40 then
                    h:MoveTo(Vector3.new(S.home.X, pos.Y, S.home.Z))
                    lastMove = now
                end
            elseif mode == "HOP14" and now - lastHop >= HOP_DELAY then
                local flat = Vector3.new(S.home.X - pos.X, 0, S.home.Z - pos.Z)
                if flat.Magnitude > 0.01 then
                    local step = math.min(HOP_STEP, math.max(flat.Magnitude - ARRIVE_R * 0.5, 0))
                    local dir = flat.Unit
                    local dest = pos + dir * step
                    local rotation = r.CFrame - r.CFrame.Position
                    h:Move(dir, false)
                    r.CFrame = CFrame.new(dest) * rotation
                    lastHop = now
                end
            end

            RunService.Heartbeat:Wait()
            now = os.clock()
            if now - lastAt >= SAMPLE_DT then
                local newPos = r.Position
                local dt = math.max(now - lastAt, 0.001)
                local moved = flatDist(newPos, lastPos)
                local sampledSpeed = moved / dt
                local newD = flatDist(newPos, S.home)
                metrics.path = metrics.path + moved
                metrics.peak = math.max(metrics.peak, sampledSpeed)
                if newD - metrics.lastD > 2 then
                    metrics.back = metrics.back + 1
                end
                if math.abs(h.WalkSpeed - metrics.lastWS) > 0.01 then
                    metrics.wsChanges = metrics.wsChanges + 1
                    say(string.format("CHANGE t=%.2f WalkSpeed %.1f→%.1f", now - metrics.t0, metrics.lastWS, h.WalkSpeed))
                    metrics.lastWS = h.WalkSpeed
                end
                local stateName = h:GetState().Name
                if stateName ~= lastState then
                    say(string.format("STATE t=%.2f %s→%s", now - metrics.t0, lastState, stateName))
                    lastState = stateName
                end
                if now - metrics.t0 - lastLog >= LOG_DT then
                    local velocity = r.AssemblyLinearVelocity
                    local horizontalVel = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
                    say(string.format(
                        "SAMPLE t=%.2f d=%.1f ds=%.1f v=%.1f physV=%.1f WS=%.1f state=%s carry=%s",
                        now - metrics.t0, newD, moved, sampledSpeed,
                        horizontalVel, h.WalkSpeed, stateName, carrying
                    ))
                    lastLog = now - metrics.t0
                end
                lastPos = newPos
                lastAt = now
                metrics.lastD = newD
            end
        end

        if result == "unknown" then
            result = S.stop and "stopped" or "cancelled"
        end
        finishRun(h, oldSpeed, mode, result, metrics)
    end)
end

bHome.MouseButton1Click:Connect(function()
    if S.running then
        say("หยุดการทดสอบก่อนเปลี่ยน HOME")
        return
    end
    local _, r = charParts()
    if not r then
        say("ไม่พบ HumanoidRootPart")
        return
    end
    S.home = r.Position
    say(string.format("HOME=(%.1f, %.1f, %.1f) — ออกไปแล้วเลือก TEST", S.home.X, S.home.Y, S.home.Z))
end)

bNormal.MouseButton1Click:Connect(function() runTest("NORMAL") end)
bSpeed.MouseButton1Click:Connect(function() runTest("SPEED32") end)
bHop.MouseButton1Click:Connect(function() runTest("HOP14") end)

bStop.MouseButton1Click:Connect(function()
    if S.running then
        S.stop = true
        say("STOP requested")
    else
        say("ไม่มีการทดสอบที่กำลังทำงาน")
    end
end)

bCopy.MouseButton1Click:Connect(function()
    local text = "=== Egg01 Move Spy v1.0 ===\n" .. table.concat(lines, "\n")
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, text)
        bCopy.Text = "COPIED"
    else
        say("executor ไม่มี setclipboard")
    end
    task.delay(1, function()
        if bCopy.Parent then bCopy.Text = "COPY LOG" end
    end)
end)

bClear.MouseButton1Click:Connect(function()
    table.clear(lines)
    logBox.Text = ""
    say("ล้าง log แล้ว")
end)

bClose.MouseButton1Click:Connect(function()
    S.stop = true
    S.running = false
    for _, c in ipairs(S.conns) do
        pcall(function() c:Disconnect() end)
    end
    gui:Destroy()
end)

say("Move Spy พร้อม — SET HOME → ออกไป → กด TEST 1/2/3")
say("แต่ละ TEST คืน WalkSpeed เดิมเมื่อจบหรือ STOP")
