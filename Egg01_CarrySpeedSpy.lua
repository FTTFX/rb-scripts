-- Egg01 Carry Speed Spy v1.0 -- read-only speed comparison; never writes WalkSpeed
if _G.EGG01_CARRY_SPEED_SPY then
    _G.EGG01_CARRY_SPEED_SPY.stop = true
    pcall(function() _G.EGG01_CARRY_SPEED_SPY.gui:Destroy() end)
    for _, c in ipairs(_G.EGG01_CARRY_SPEED_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
end

local Players, RunService, RS = game:GetService("Players"), game:GetService("RunService"), game:GetService("ReplicatedStorage")
local LP, PG = Players.LocalPlayer, Players.LocalPlayer:WaitForChild("PlayerGui")
local S = { gui = nil, conns = {}, home = nil, running = false, stop = false, carry = "?", carryConnected = false }
_G.EGG01_CARRY_SPEED_SPY = S
local lines = {}
local function parts()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end
local function distance(a, b)
    local x, z = a.X - b.X, a.Z - b.Z
    return math.sqrt(x * x + z * z)
end
local function findNet(name)
    local pkg = RS:FindFirstChild("Packages")
    local net = pkg and pkg:FindFirstChild("Networking")
    if net then for _, v in ipairs(net:GetDescendants()) do if v.Name:find(name, 1, true) then return v end end end
end

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "Egg01_CarrySpeedSpy", false, 1010
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui
local panel = Instance.new("Frame", gui)
panel.Size, panel.Position = UDim2.new(0, 390, 0, 150), UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = Color3.fromRGB(20, 23, 28), .08, 0
panel.Active, panel.Draggable = true, true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local title = Instance.new("TextLabel", panel)
title.Size, title.Position, title.BackgroundTransparency = UDim2.new(1, -48, 0, 26), UDim2.new(0, 10, 0, 4), 1
title.Text, title.TextColor3, title.Font, title.TextSize, title.TextXAlignment = "Egg01 Carry Speed Spy v1.0", Color3.new(1, 1, 1), Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left
local function button(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size, b.Position, b.BackgroundColor3, b.BorderSizePixel = UDim2.new(0, w, 0, 29), UDim2.new(0, x, 0, y), color, 0
    b.Text, b.TextColor3, b.Font, b.TextSize = text, Color3.new(1, 1, 1), Enum.Font.GothamBold, 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local bHome = button("SET HOME", 10, 36, 75, Color3.fromRGB(48, 100, 180))
local bBase = button("1 BASELINE", 92, 36, 84, Color3.fromRGB(55, 115, 180))
local bCarry = button("2 CARRY", 183, 36, 75, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 265, 36, 55, Color3.fromRGB(165, 50, 50))
local bCopy = button("COPY", 327, 36, 53, Color3.fromRGB(70, 70, 75))
local bClose = button("X", 350, 4, 30, Color3.fromRGB(125, 45, 45))
local status = Instance.new("TextLabel", panel)
status.Size, status.Position, status.BackgroundTransparency = UDim2.new(1, -20, 0, 69), UDim2.new(0, 10, 0, 75), 1
status.Text = "SET HOME ในฐาน → ออกไปไกล → BASELINE\nแล้วถือไข่จริงด้วยมือ → CARRY เพื่อเทียบ (ไม่แก้ WalkSpeed)"
status.TextColor3, status.Font, status.TextSize, status.TextWrapped = Color3.fromRGB(145, 235, 165), Enum.Font.GothamBold, 11, true
status.TextXAlignment, status.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
local function say(msg)
    lines[#lines + 1] = tostring(msg)
    if #lines > 120 then table.remove(lines, 1) end
    status.Text = tostring(msg)
end
local function connectCarry()
    if S.carryConnected then return true end
    local re = findNet("FieldEggCarry")
    if not re or not (re:IsA("RemoteEvent") or re:IsA("UnreliableRemoteEvent")) then return false end
    S.carryConnected = true
    S.conns[#S.conns + 1] = re.OnClientEvent:Connect(function(row)
        if typeof(row) == "table" and row.IsCarrying ~= nil then S.carry = row.IsCarrying and "Y" or "N" end
    end)
    say("ฟัง FieldEggCarry ✅")
    return true
end
local function run(label)
    if S.running then say("กำลังทดสอบอยู่") return end
    if not S.home then say("กด SET HOME ในฐานก่อน") return end
    local h, r = parts()
    if not h or not r then say("ไม่พบตัวละคร") return end
    local startD = distance(r.Position, S.home)
    if startD < 30 then say("ออกจาก HOME อย่างน้อย 30 studs ก่อน") return end
    S.stop, S.running = false, true
    local started, lastAt, lastPos, path, peak, wsMin, wsMax = os.clock(), os.clock(), r.Position, 0, 0, h.WalkSpeed, h.WalkSpeed
    local lastReport = -1
    say(string.format("=== %s === start=%.1f WS=%.1f carry=%s | ไม่บังคับความเร็ว", label, startD, h.WalkSpeed, S.carry))
    task.spawn(function()
        local result = "timeout"
        while S.running and not S.stop and os.clock() - started < 90 do
            local hn, rn = parts()
            if hn ~= h or not rn or h.Health <= 0 then result = "character-changed" break end
            local d = distance(rn.Position, S.home)
            if d <= 7 then result = "arrived" break end
            h:MoveTo(Vector3.new(S.home.X, rn.Position.Y, S.home.Z))
            RunService.Heartbeat:Wait()
            local now = os.clock()
            if now - lastAt >= .10 then
                local moved, dt = distance(rn.Position, lastPos), math.max(now - lastAt, .001)
                local v = moved / dt
                path, peak = path + moved, math.max(peak, v)
                wsMin, wsMax = math.min(wsMin, h.WalkSpeed), math.max(wsMax, h.WalkSpeed)
                if now - started - lastReport >= .5 then
                    local vel = rn.AssemblyLinearVelocity
                    say(string.format("%s t=%.1f d=%.0f actual=%.1f phys=%.1f WS=%.1f carry=%s", label, now-started, d, v, Vector3.new(vel.X, 0, vel.Z).Magnitude, h.WalkSpeed, S.carry))
                    lastReport = now - started
                end
                lastAt, lastPos = now, rn.Position
            end
        end
        local elapsed = math.max(os.clock() - started, .001)
        local _, endRoot = parts()
        say(string.format("END %s %s | avg=%.1f peak=%.1f WS[min/max]=%.1f/%.1f remain=%.1f carry=%s", label, result, path/elapsed, peak, wsMin, wsMax, endRoot and distance(endRoot.Position, S.home) or -1, S.carry))
        S.running = false
    end)
end
task.spawn(function()
    local deadline = os.clock() + 20
    while gui.Parent and not S.stop and os.clock() < deadline and not S.carryConnected do connectCarry(); task.wait(1) end
    if not S.carryConnected then lines[#lines + 1] = "ไม่พบ FieldEggCarry: ยังวัดความเร็วได้ แต่ยืนยันสถานะถือไม่ได้" end
end)
bHome.MouseButton1Click:Connect(function() local _, r = parts(); if r then S.home = r.Position; say("HOME ตั้งแล้ว — ออกไปไกลแล้วกด BASELINE") end end)
bBase.MouseButton1Click:Connect(function() run("BASELINE") end)
bCarry.MouseButton1Click:Connect(function() run("CARRY") end)
bStop.MouseButton1Click:Connect(function() S.stop, S.running = true, false; say("STOP") end)
bCopy.MouseButton1Click:Connect(function() local c = setclipboard or toclipboard; if c then pcall(c, "=== Egg01 Carry Speed Spy v1.0 ===\n" .. table.concat(lines, "\n")) end; bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end) end)
bClose.MouseButton1Click:Connect(function() S.stop = true; for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end; gui:Destroy(); _G.EGG01_CARRY_SPEED_SPY = nil end)
