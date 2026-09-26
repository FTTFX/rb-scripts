-- Egg01 Motion Lab v3.0 — CFrame บนพื้น ความเร็ว ≤ WalkSpeed จริง
-- ไอเดีย: ย้ายด้วย CFrame แต่ไม่เร็วเกินตัวละคร → ลดโอกาสเซิร์ฟดึงกลับ
-- เทสเท่านั้น — อย่าใส่ในฟาร์มหลักจนกว่าจะผ่าน snap/err

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
    home = nil,
    clip = false, clipConn = nil, clipParts = {},
}
_G.EGG01_MOTION_LAB = S

local logBox
-- mult ≤1 = ไม่เกิน WalkSpeed | 1 = เท่าความเร็วจริง
local SPEED_MULT = 1.0

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
    return pos.Y
end

local function surfaceOf(xz)
    local fy = floorY(xz)
    return Vector3.new(xz.X, fy + 3.2, xz.Z)
end

local function readMult()
    local m = tonumber(S.multBox and S.multBox.Text) or SPEED_MULT
    return math.clamp(m, 0.25, 1.0) -- ห้ามเกิน 1.0 = ไม่เร็วกว่าตัวละคร
end

-- CFrame ตาม Heartbeat ความเร็ว ≤ WalkSpeed * mult
local function cfWalk(goal, label)
    local h, r = hr()
    if not h or not r then return false, "ไม่มีตัว" end

    local ws = math.max(1, h.WalkSpeed)
    local mult = readMult()
    local speed = ws * mult
    local start = r.Position
    -- เป้าเกาะพื้น (Y จากเรย์) ถ้า goal ให้มาแล้วก็ใช้
    local dest = goal
    local dist = (dest - start).Magnitude
    local eta = dist / speed
    local snap = 0
    local maxInst = 0
    local t0 = os.clock()

    say(string.format(
        "%s CF@WS → (%.0f,%.0f,%.0f) d=%.0f WS=%.1f×%.2f=%.1f eta=%.1fs",
        label or "CF", dest.X, dest.Y, dest.Z, dist, ws, mult, speed, eta
    ))

    -- หยุด MoveTo ค้าง
    pcall(function()
        h:MoveTo(r.Position)
        h:Move(Vector3.zero)
    end)

    local traveled = 0
    while S.run do
        h, r = hr()
        if not h or not r or h.Health <= 0 then return false, "ตัวเปลี่ยน/ตาย" end

        local remain = dest - r.Position
        local rem = remain.Magnitude
        if rem <= 2.5 then break end

        local dt = RunS.Heartbeat:Wait()
        if dt <= 0 then dt = 1 / 60 end
        -- เพดานต่อเฟรม = WalkSpeed*mult*dt (ไม่เกินความเร็วจริง)
        local step = math.min(rem, speed * dt)
        local dir = remain.Unit
        local target = r.Position + dir * step
        -- เกาะพื้นระหว่างทาง (กันจม/ลอย)
        target = Vector3.new(target.X, floorY(target) + 3.2, target.Z)

        local before = r.Position
        r.CFrame = CFrame.new(target, target + Vector3.new(dir.X, 0, dir.Z))
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero

        h, r = hr()
        if r then
            local moved = (r.Position - before).Magnitude
            local expect = step
            local drift = (r.Position - target).Magnitude
            if drift > 4 then snap = snap + 1 end
            -- ความเร็ว瞬时 (studs/s) — ถ้าสูงกว่า WS มาก = แปลก
            local inst = moved / math.max(dt, 1 / 240)
            if inst > maxInst then maxInst = inst end
            traveled = traveled + moved
            if expect > 0.5 and moved < expect * 0.35 then
                snap = snap + 1 -- น่าจะถูกเซิร์ฟดึง
            end
        end
    end

    h, r = hr()
    if r and S.run then
        r.CFrame = CFrame.new(dest) * (r.CFrame - r.CFrame.Position)
        r.AssemblyLinearVelocity = Vector3.zero
    end
    task.wait(0.06)
    h, r = hr()
    local final = r and r.Position or dest
    local err = (final - dest).Magnitude
    local elapsed = os.clock() - t0
    local avg = elapsed > 0 and (traveled / elapsed) or 0
    return err <= 6, string.format(
        "%s done %.2fs err=%.1f snap=%d avg=%.1f max=%.1f (cap=%.1f)",
        label or "CF", elapsed, err, snap, avg, maxInst, speed
    )
end

local function goTo(destXZ, tag)
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end
    local useClip = S.wantClip == true
    if useClip then setClip(true) end
    S.run = true
    local dest = surfaceOf(destXZ)
    say(string.format("=== %s surface CF@WS mult=%.2f clip=%s ===",
        tag or "GO", readMult(), tostring(useClip)))

    task.spawn(function()
        local ok, msg = cfWalk(dest, tag or "GO")
        say(msg)
        say(ok and "ผ่าน (err≤6)" or "ไม่ผ่าน — ดู snap/err")
        if useClip then setClip(false) end
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
f.BackgroundColor3 = Color3.fromRGB(24, 32, 40)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 Motion Lab v3.0 — CFrame ≤ WalkSpeed (พื้น)"
title.TextColor3 = Color3.fromRGB(120, 220, 255)
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
local bGoHome = button("CF→HOME", 66, 34, 80, Color3.fromRGB(40, 130, 100))
local bAhead = button("CF→AHEAD80", 150, 34, 100, Color3.fromRGB(50, 120, 90))
local bStop = button("STOP", 254, 34, 52, Color3.fromRGB(165, 50, 55))
local bCopy = button("COPY", 310, 34, 48, Color3.fromRGB(75, 75, 80))
local bClip = button("CLIP", 362, 34, 48, Color3.fromRGB(100, 90, 50))
local bShowWS = button("WS?", 414, 34, 48, Color3.fromRGB(70, 90, 110))

S.multBox = Instance.new("TextBox", f)
S.multBox.Size = UDim2.new(0, 52, 0, 26)
S.multBox.Position = UDim2.new(0, 10, 0, 68)
S.multBox.Text = "1.0"
S.multBox.BackgroundColor3 = Color3.fromRGB(55, 70, 85)
S.multBox.TextColor3 = Color3.new(1, 1, 1)
S.multBox.Font = Enum.Font.GothamBold
S.multBox.TextSize = 12
S.multBox.ClearTextOnFocus = false

local hint = Instance.new("TextLabel", f)
hint.Size = UDim2.new(0, 460, 0, 26)
hint.Position = UDim2.new(0, 70, 0, 68)
hint.BackgroundTransparency = 1
hint.Text = "mult (0.25–1.0) × WalkSpeed — ห้ามเกิน 1 | Heartbeat CFrame เกาะพื้น"
hint.TextColor3 = Color3.fromRGB(190, 210, 220)
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
        say(string.format("HOME=(%.0f,%.0f,%.0f)", r.Position.X, r.Position.Y, r.Position.Z))
    end
end)

bGoHome.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    if not S.home then say("กด HOME ก่อน"); return end
    goTo(S.home, "→HOME")
end)

bAhead.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    local _, r = hr()
    if not r then return end
    local look = r.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
    goTo(r.Position + flat * 80, "→AHEAD80")
end)

bStop.MouseButton1Click:Connect(function()
    S.run = false
    say("STOP")
end)

bClip.MouseButton1Click:Connect(function()
    S.wantClip = not S.wantClip
    bClip.Text = S.wantClip and "CLIP ON" or "CLIP"
    bClip.BackgroundColor3 = S.wantClip and Color3.fromRGB(40, 130, 90) or Color3.fromRGB(100, 90, 50)
    say("wantClip=" .. tostring(S.wantClip) .. " (เปิดตอนกด CF)")
end)

bShowWS.MouseButton1Click:Connect(function()
    local h, r = hr()
    if h and r then
        say(string.format("WS=%.1f pos=(%.0f,%.0f,%.0f) mult=%.2f → cap=%.1f",
            h.WalkSpeed, r.Position.X, r.Position.Y, r.Position.Z, readMult(), h.WalkSpeed * readMult()))
    end
end)

bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then
        pcall(c, "=== Egg01 Motion Lab v3.0 CF@WS ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)

say("v3.0 CFrame บนพื้น ≤ WalkSpeed")
say("HOME → ไปจุดอื่น → CF→HOME | หรือ CF→AHEAD80")
say("ดู avg/max ต้องไม่เกิน cap | snap สูง = เซิร์ฟดึง")
