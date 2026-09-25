-- Egg01 Motion Lab v2.0 — เทสเดินใต้พื้น (noclip + MoveTo)
-- ห้าม CFrame ย้ายตัว — ดู Egg01_NO_CFRAME.md

if _G.EGG01_MOTION_LAB then
    _G.EGG01_MOTION_LAB.run = false
    pcall(function()
        if _G.EGG01_MOTION_LAB.clipConn then _G.EGG01_MOTION_LAB.clipConn:Disconnect() end
    end)
    pcall(function() _G.EGG01_MOTION_LAB.gui:Destroy() end)
end

local Players = game:GetService("Players")
local RunS = game:GetService("RunService")
local LP = Players.LocalPlayer

local S = {
    run = false, gui = nil, lines = {},
    home = nil, underY = nil,
    clip = false, clipConn = nil, clipParts = {},
}
_G.EGG01_MOTION_LAB = S

local logBox
local DEPTH = 12 -- studs ใต้พื้น (ปรับได้ในกล่อง)

local function say(m)
    S.lines[#S.lines + 1] = tostring(m)
    if #S.lines > 22 then table.remove(S.lines, 1) end
    if logBox then logBox.Text = table.concat(S.lines, "\n") end
    warn("[MotionLab] " .. tostring(m))
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function brake()
    local h, r = hr()
    if not h or not r then return end
    h:MoveTo(r.Position)
    h:Move(Vector3.zero)
    for _ = 1, 3 do
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        RunS.Heartbeat:Wait()
    end
end

local function setClip(on)
    S.clip = on and true or false
    if not on then
        if S.clipConn then pcall(function() S.clipConn:Disconnect() end); S.clipConn = nil end
        for part, was in pairs(S.clipParts) do
            if part and part.Parent then pcall(function() part.CanCollide = was end) end
        end
        S.clipParts = {}
        return
    end
    if S.clipConn then return end
    local function apply(ch)
        if not ch then return end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then
                if S.clipParts[p] == nil then S.clipParts[p] = p.CanCollide end
                p.CanCollide = false
            end
        end
    end
    apply(LP.Character)
    S.clipConn = RunS.Stepped:Connect(function()
        if S.clip then apply(LP.Character) end
    end)
end

-- หา Y พื้นด้วย raycast ลง
local function floorY(pos)
    local origin = pos + Vector3.new(0, 5, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if LP.Character then params.FilterDescendantsInstances = { LP.Character } end
    local hit = workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
    if hit then return hit.Position.Y end
    return pos.Y - 3
end

local function underPos(xz, depth)
    depth = depth or DEPTH
    local fy = floorY(xz)
    return Vector3.new(xz.X, fy - depth, xz.Z)
end

local function walkTo(goal, rad, lim, label)
    local h, r = hr()
    if not h or not r then return false, "ไม่มีตัว" end
    local t0 = os.clock()
    lim = lim or 40
    rad = rad or 4
    local path, rollback, peak, last, prevD = 0, 0, 0, r.Position, (goal - r.Position).Magnitude
    local snapUp = 0 -- นับครั้งที่เซิร์ฟดัน Y ขึ้นแรง
    local minY, maxY = r.Position.Y, r.Position.Y

    while S.run and os.clock() - t0 < lim do
        h, r = hr()
        if not h or not r or h.Health <= 0 then return false, "ตัวเปลี่ยน/ตาย" end
        local d = (goal - r.Position).Magnitude
        local dXZ = (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude
        minY = math.min(minY, r.Position.Y)
        maxY = math.max(maxY, r.Position.Y)
        if d <= rad or dXZ <= rad then
            brake()
            return true, string.format(
                "%s OK %.1fs path=%.0f peak=%.0f Y=%.0f..%.0f snapUp=%d",
                label or "ถึง", os.clock() - t0, path, peak, minY, maxY, snapUp
            )
        end
        h:MoveTo(goal)
        local moved = (r.Position - last).Magnitude
        path = path + moved
        peak = math.max(peak, r.AssemblyLinearVelocity.Magnitude)
        if r.Position.Y > last.Y + 2.5 and last.Y < (S.underY or last.Y) + 1 then
            snapUp = snapUp + 1
        end
        if d > prevD + 10 then rollback = rollback + (d - prevD) end
        prevD, last = d, r.Position
        task.wait(0.08)
    end
    brake()
    return false, string.format("%s TIMEOUT path=%.0f Y=%.0f..%.0f snapUp=%d", label or "?", path, minY, maxY, snapUp)
end

-- โหมด: ดำลงใต้จุดปัจจุบัน
local function digDown()
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end
    local depth = math.clamp(tonumber(S.depthBox and S.depthBox.Text) or DEPTH, 4, 40)
    setClip(true)
    local goal = underPos(r.Position, depth)
    S.underY = goal.Y
    say(string.format("DIG depth=%d → (%.0f,%.0f,%.0f) clip=ON", depth, goal.X, goal.Y, goal.Z))
    S.run = true
    task.spawn(function()
        local ok, msg = walkTo(goal, 3, 25, "DIG")
        say(msg)
        local _, root = hr()
        if root then
            local fy = floorY(root.Position)
            say(string.format("Y=%.1f floor=%.1f Δ=%.1f clip=%s",
                root.Position.Y, fy, fy - root.Position.Y, tostring(S.clip)))
        end
        S.run = false
    end)
end

-- โหมด: เดินใต้พื้นไป HOME (คง Y ใต้ดิน)
local function walkUnderHome()
    if not S.home then say("กด HOME ก่อน"); return end
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end
    local depth = math.clamp(tonumber(S.depthBox and S.depthBox.Text) or DEPTH, 4, 40)
    setClip(true)
    local goal = underPos(S.home, depth)
    S.underY = goal.Y
    say(string.format("UNDER→HOME depth=%d dXZ=%.0f", depth, (Vector3.new(S.home.X, 0, S.home.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude))
    S.run = true
    task.spawn(function()
        -- ถ้ายังอยู่บนดิน ให้ดำก่อน
        local fy = floorY(r.Position)
        if r.Position.Y > fy - depth * 0.5 then
            local digGoal = underPos(r.Position, depth)
            local ok1, m1 = walkTo(digGoal, 3, 20, "DIG-first")
            say(m1)
            if not ok1 or not S.run then S.run = false; return end
        end
        local ok, msg = walkTo(goal, 5, 50, "UNDER-HOME")
        say(msg)
        local _, root = hr()
        if root then
            say(string.format("จบ Y=%.1f floor=%.1f Δ=%.1f clip=%s",
                root.Position.Y, floorY(root.Position), floorY(root.Position) - root.Position.Y, tostring(S.clip)))
        end
        S.run = false
    end)
end

-- โหมด: ขึ้นผิว (MoveTo เหนือพื้น)
local function surface()
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end
    local fy = floorY(r.Position)
    local goal = Vector3.new(r.Position.X, fy + 4, r.Position.Z)
    say(string.format("SURFACE → Y=%.0f (clip ยัง%s)", goal.Y, S.clip and "ON" or "OFF"))
    S.run = true
    task.spawn(function()
        local ok, msg = walkTo(goal, 3, 20, "SURFACE")
        say(msg)
        setClip(false)
        say("clip=OFF")
        S.run = false
    end)
end

-- เทียบ: เดินผิวไป HOME (ควบคุม)
local function walkSurfaceHome()
    if not S.home then say("กด HOME ก่อน"); return end
    local h, r = hr()
    if not h or not r then return end
    setClip(false)
    local goal = Vector3.new(S.home.X, r.Position.Y, S.home.Z)
    say("SURFACE→HOME (ควบคุม ไม่ใต้ดิน)")
    S.run = true
    task.spawn(function()
        local ok, msg = walkTo(goal, 5, 45, "SURF-HOME")
        say(msg)
        S.run = false
    end)
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_MotionLab"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1025
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui

local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 520, 0, 280)
f.Position = UDim2.new(0, 12, 0.42, 0)
f.BackgroundColor3 = Color3.fromRGB(23, 31, 45)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 Motion Lab v2.0 — ใต้พื้น (noclip+MoveTo ห้าม CFrame)"
title.TextColor3 = Color3.fromRGB(180, 220, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local function button(t, x, w, c)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, 34)
    b.Text = t
    b.BackgroundColor3 = c
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bHome = button("HOME", 10, 52, Color3.fromRGB(45, 105, 165))
local bDig = button("DIG", 66, 48, Color3.fromRGB(90, 70, 140))
local bUnder = button("UNDER→HOME", 118, 90, Color3.fromRGB(35, 145, 75))
local bSurf = button("SURFACE", 212, 70, Color3.fromRGB(70, 120, 90))
local bCtrl = button("SURF→HOME", 286, 78, Color3.fromRGB(70, 115, 160))
local bClip = button("CLIP", 368, 48, Color3.fromRGB(100, 90, 50))
local bStop = button("STOP", 420, 48, Color3.fromRGB(165, 50, 55))
local bCopy = button("COPY", 472, 40, Color3.fromRGB(75, 75, 80))

S.depthBox = Instance.new("TextBox", f)
S.depthBox.Size = UDim2.new(0, 44, 0, 28)
S.depthBox.Position = UDim2.new(0, 10, 0, 66)
S.depthBox.Text = tostring(DEPTH)
S.depthBox.PlaceholderText = "depth"
S.depthBox.BackgroundColor3 = Color3.fromRGB(55, 70, 85)
S.depthBox.TextColor3 = Color3.new(1, 1, 1)
S.depthBox.Font = Enum.Font.GothamBold
S.depthBox.TextSize = 12
S.depthBox.ClearTextOnFocus = false
Instance.new("UICorner", S.depthBox).CornerRadius = UDim.new(0, 5)

local depthLbl = Instance.new("TextLabel", f)
depthLbl.Size = UDim2.new(0, 120, 0, 28)
depthLbl.Position = UDim2.new(0, 58, 0, 66)
depthLbl.BackgroundTransparency = 1
depthLbl.Text = "depth (studs ใต้พื้น)"
depthLbl.TextColor3 = Color3.fromRGB(180, 200, 220)
depthLbl.Font = Enum.Font.Gotham
depthLbl.TextSize = 11
depthLbl.TextXAlignment = Enum.TextXAlignment.Left

logBox = Instance.new("TextLabel", f)
logBox.Size = UDim2.new(1, -16, 0, 168)
logBox.Position = UDim2.new(0, 8, 0, 100)
logBox.BackgroundColor3 = Color3.new(0, 0, 0)
logBox.BackgroundTransparency = 0.2
logBox.TextColor3 = Color3.fromRGB(180, 245, 190)
logBox.Font = Enum.Font.Code
logBox.TextSize = 10
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.TextWrapped = true
logBox.ClipsDescendants = true

bHome.MouseButton1Click:Connect(function()
    local _, r = hr()
    if r then
        S.home = r.Position
        say(string.format("HOME=(%.0f,%.0f,%.0f)", r.Position.X, r.Position.Y, r.Position.Z))
    end
end)

bDig.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    digDown()
end)

bUnder.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    walkUnderHome()
end)

bSurf.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    surface()
end)

bCtrl.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    walkSurfaceHome()
end)

bClip.MouseButton1Click:Connect(function()
    setClip(not S.clip)
    bClip.BackgroundColor3 = S.clip and Color3.fromRGB(40, 130, 90) or Color3.fromRGB(100, 90, 50)
    bClip.Text = S.clip and "CLIP ON" or "CLIP"
    say("clip=" .. tostring(S.clip))
end)

bStop.MouseButton1Click:Connect(function()
    S.run = false
    brake()
    say("STOP")
end)

bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then
        pcall(c, "=== Egg01 Motion Lab v2.0 UNDER ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)

say("v2.0 ใต้พื้น — HOME → DIG / UNDER→HOME / SURFACE")
say("ไม่ใช้ CFrame | ดู snapUp + ΔY ว่าเซิร์ฟดันขึ้นไหม")
