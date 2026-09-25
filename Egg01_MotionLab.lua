-- Egg01 Motion Lab v2.1 — เทสใต้พื้นด้วย CFrame (ตามแผนภาพ)
-- ขั้น: ลงใต้พื้น → เลื่อน 1→2 ใต้ดิน → โผล่ผิว
-- หมายเหตุ: โหมดนี้ใช้ CFrame จงใจเพื่อเทสเท่านั้น — อย่าใส่ในฟาร์มหลัก

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
    home = nil, mark1 = nil,
    clip = false, clipConn = nil, clipParts = {},
}
_G.EGG01_MOTION_LAB = S

local logBox
local DEPTH = 12
local STEP = 18 -- studs ต่อท่อน CFrame ใต้ดิน
local STEP_WAIT = 0.05

local function say(m)
    S.lines[#S.lines + 1] = tostring(m)
    if #S.lines > 24 then table.remove(S.lines, 1) end
    if logBox then logBox.Text = table.concat(S.lines, "\n") end
    warn("[MotionLab] " .. tostring(m))
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
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

local function floorY(pos)
    local origin = pos + Vector3.new(0, 8, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if LP.Character then params.FilterDescendantsInstances = { LP.Character } end
    local hit = workspace:Raycast(origin, Vector3.new(0, -120, 0), params)
    if hit then return hit.Position.Y end
    return pos.Y - 3
end

local function underOf(xz, depth)
    depth = depth or DEPTH
    local fy = floorY(xz)
    return Vector3.new(xz.X, fy - depth, xz.Z)
end

local function surfaceOf(xz)
    local fy = floorY(xz)
    return Vector3.new(xz.X, fy + 4, xz.Z)
end

-- CFrame ย้ายทีละท่อน (ไม่กระโดดระยะไกลทีเดียว — ดูว่าเซิร์ฟดึงกลับไหม)
local function cfGo(goal, label)
    local h, r = hr()
    if not h or not r then return false, "ไม่มีตัว" end
    local start = r.Position
    local dist = (goal - start).Magnitude
    local steps = math.max(1, math.ceil(dist / STEP))
    local snap = 0
    local t0 = os.clock()
    say(string.format("%s CFrame → (%.0f,%.0f,%.0f) d=%.0f steps=%d", label or "CF", goal.X, goal.Y, goal.Z, dist, steps))

    for i = 1, steps do
        if not S.run then return false, "STOP" end
        h, r = hr()
        if not h or not r or h.Health <= 0 then return false, "ตัวเปลี่ยน/ตาย" end
        local alpha = i / steps
        local target = start:Lerp(goal, alpha)
        local before = r.Position
        r.CFrame = CFrame.new(target) * (r.CFrame - r.CFrame.Position)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        task.wait(STEP_WAIT)
        h, r = hr()
        if r then
            local drift = (r.Position - target).Magnitude
            if drift > 6 then snap = snap + 1 end
            -- เซิร์ฟดันขึ้นจากใต้ดิน
            if target.Y < floorY(target) - 4 and r.Position.Y > target.Y + 5 then
                snap = snap + 1
            end
        end
    end
    -- snap ท้ายให้ตรงเป้า
    h, r = hr()
    if r then
        r.CFrame = CFrame.new(goal) * (r.CFrame - r.CFrame.Position)
        r.AssemblyLinearVelocity = Vector3.zero
    end
    task.wait(0.08)
    h, r = hr()
    local final = r and r.Position or goal
    local err = (final - goal).Magnitude
    return err <= 8, string.format(
        "%s done %.2fs err=%.1f snap=%d Y=%.1f",
        label or "CF", os.clock() - t0, err, snap, final.Y
    )
end

--[[
  แผนภาพ:
    บนดิน ──↓── ① ใต้พื้น ════→ ② ใต้พื้น ──↑── บนดิน (เป้า)
]]
local function runTunnelTo(destXZ, tag)
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end
    local depth = math.clamp(tonumber(S.depthBox and S.depthBox.Text) or DEPTH, 4, 40)
    local step = math.clamp(tonumber(S.stepBox and S.stepBox.Text) or STEP, 4, 60)

    -- อัปเดตค่าจากกล่อง
    STEP = step

    setClip(true)
    S.run = true
    say(string.format("=== %s CFrame tunnel depth=%d step=%d ===", tag or "TUNNEL", depth, step))

    task.spawn(function()
        local p0 = r.Position
        local under1 = underOf(p0, depth)           -- จุด ① ใต้จุดเริ่ม
        local under2 = underOf(destXZ, depth)       -- จุด ② ใต้เป้า
        local top2 = surfaceOf(destXZ)              -- โผล่ผิวที่เป้า

        -- ↓ ลงใต้พื้น
        local ok1, m1 = cfGo(under1, "① DIG")
        say(m1)
        if not ok1 or not S.run then S.run = false; setClip(false); return end
        S.mark1 = under1

        -- → เลื่อนใต้ดิน ①→②
        local ok2, m2 = cfGo(under2, "①→② UNDER")
        say(m2)
        if not ok2 or not S.run then S.run = false; setClip(false); return end

        -- ↑ โผล่ผิว
        local ok3, m3 = cfGo(top2, "② SURFACE")
        say(m3)

        local _, root = hr()
        if root then
            local fy = floorY(root.Position)
            say(string.format("จบ Y=%.1f floor=%.1f Δ=%.1f | ok=%s/%s/%s",
                root.Position.Y, fy, fy - root.Position.Y,
                tostring(ok1), tostring(ok2), tostring(ok3)))
        end
        setClip(false)
        say("clip=OFF | เทส CFrame เสร็จ — ดู snap/err ว่าเซิร์ฟดึงไหม")
        S.run = false
    end)
end

local function digOnly()
    local h, r = hr()
    if not h or not r then return end
    local depth = math.clamp(tonumber(S.depthBox and S.depthBox.Text) or DEPTH, 4, 40)
    STEP = math.clamp(tonumber(S.stepBox and S.stepBox.Text) or STEP, 4, 60)
    setClip(true)
    S.run = true
    task.spawn(function()
        local ok, msg = cfGo(underOf(r.Position, depth), "DIG-ONLY")
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
f.Size = UDim2.new(0, 540, 0, 300)
f.Position = UDim2.new(0, 12, 0.40, 0)
f.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 Motion Lab v2.1 — CFrame ใต้พื้น (เทส)  ↓①→②↑"
title.TextColor3 = Color3.fromRGB(255, 180, 120)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local function button(t, x, y, w, c)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, y)
    b.Text = t
    b.BackgroundColor3 = c
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bHome = button("HOME", 10, 34, 52, Color3.fromRGB(45, 105, 165))
local bDig = button("① DIG", 66, 34, 58, Color3.fromRGB(120, 70, 140))
local bTunnel = button("↓①→②↑ HOME", 128, 34, 110, Color3.fromRGB(180, 80, 50))
local bFar = button("↓①→②↑ HERE", 242, 34, 100, Color3.fromRGB(160, 90, 40))
local bStop = button("STOP", 346, 34, 52, Color3.fromRGB(165, 50, 55))
local bCopy = button("COPY", 402, 34, 48, Color3.fromRGB(75, 75, 80))
local bClip = button("CLIP", 454, 34, 48, Color3.fromRGB(100, 90, 50))

S.depthBox = Instance.new("TextBox", f)
S.depthBox.Size = UDim2.new(0, 44, 0, 26)
S.depthBox.Position = UDim2.new(0, 10, 0, 68)
S.depthBox.Text = tostring(DEPTH)
S.depthBox.BackgroundColor3 = Color3.fromRGB(55, 70, 85)
S.depthBox.TextColor3 = Color3.new(1, 1, 1)
S.depthBox.Font = Enum.Font.GothamBold
S.depthBox.TextSize = 12
S.depthBox.ClearTextOnFocus = false

S.stepBox = Instance.new("TextBox", f)
S.stepBox.Size = UDim2.new(0, 44, 0, 26)
S.stepBox.Position = UDim2.new(0, 110, 0, 68)
S.stepBox.Text = tostring(STEP)
S.stepBox.BackgroundColor3 = Color3.fromRGB(55, 70, 85)
S.stepBox.TextColor3 = Color3.new(1, 1, 1)
S.stepBox.Font = Enum.Font.GothamBold
S.stepBox.TextSize = 12
S.stepBox.ClearTextOnFocus = false

local hint = Instance.new("TextLabel", f)
hint.Size = UDim2.new(0, 360, 0, 26)
hint.Position = UDim2.new(0, 160, 0, 68)
hint.BackgroundTransparency = 1
hint.Text = "depth | step(studs/ท่อน) — CFrame ทีละท่อน ดู snap/err"
hint.TextColor3 = Color3.fromRGB(200, 190, 210)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left

logBox = Instance.new("TextLabel", f)
logBox.Size = UDim2.new(1, -16, 0, 190)
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
        say(string.format("HOME=(%.0f,%.0f,%.0f) ← จุด② โผล่ที่นี่", r.Position.X, r.Position.Y, r.Position.Z))
    end
end)

bDig.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    digOnly()
end)

bTunnel.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    if not S.home then say("กด HOME ที่เป้าโผล่ก่อน"); return end
    runTunnelTo(S.home, "→HOME")
end)

bFar.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    local _, r = hr()
    if not r then return end
    -- เป้า = เดินหน้า 80 studs ตาม look
    local look = r.CFrame.LookVector
    local dest = r.Position + Vector3.new(look.X, 0, look.Z).Unit * 80
    runTunnelTo(dest, "→AHEAD80")
end)

bStop.MouseButton1Click:Connect(function()
    S.run = false
    say("STOP")
end)

bClip.MouseButton1Click:Connect(function()
    setClip(not S.clip)
    bClip.Text = S.clip and "CLIP ON" or "CLIP"
    bClip.BackgroundColor3 = S.clip and Color3.fromRGB(40, 130, 90) or Color3.fromRGB(100, 90, 50)
    say("clip=" .. tostring(S.clip))
end)

bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then
        pcall(c, "=== Egg01 Motion Lab v2.1 CFrame UNDER ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)

say("v2.1 CFrame ใต้พื้น (เทสเท่านั้น)")
say("HOME ที่จุดโผล่ → ไปจุดเริ่ม → ↓①→②↑ HOME")
say("หรือ ↓①→②↑ HERE = โผล่ข้างหน้า 80 studs")
