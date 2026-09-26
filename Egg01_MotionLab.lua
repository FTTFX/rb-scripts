-- Egg01 Motion Lab v3.2 — วัดวิ่ง / CF / สลับ MoveTo↔CF(+10%) ทุก 1 วิ
-- ลำดับ: 1) วัดวิ่ง  2) ใช้ CF  3) สลับ1วิ = MoveTo 1s แล้ว CF@MoveTo+10% 1s วน

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
    realSpeed = nil,   -- studs/s จากวัดวิ่งจริง
    wsAtMeasure = nil,
    boost = 1.0,       -- 1.0 = เท่าจริง | 1.1 = +10%
    clip = false, clipConn = nil, clipParts = {},
    wantClip = false,
}
_G.EGG01_MOTION_LAB = S

local logBox
local MEASURE_DIST = 80 -- studs วิ่งวัด
local ALT_SEC = 1       -- สลับโหมดทุกกี่วินาที
local ALT_CF_MULT = 1.1 -- CF = ความเร็ว MoveTo × 1.1

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
    return Vector3.new(xz.X, floorY(xz) + 3.2, xz.Z)
end

local function flatLook(r)
    local look = r.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.1 then return Vector3.new(0, 0, -1) end
    return flat.Unit
end

local function refreshBoostLabel()
    if S.boostBtn then
        local pct = math.floor((S.boost - 1) * 100 + 0.5)
        S.boostBtn.Text = string.format("+%d%%", pct)
    end
end

local function cfCap()
    if not S.realSpeed then return nil end
    return S.realSpeed * S.boost
end

-- ① วัดความเร็ววิ่งจริงด้วย MoveTo (ไม่ใช้ CFrame)
local function measureRun()
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end
    S.run = true
    local start = r.Position
    local dir = flatLook(r)
    local dest = surfaceOf(start + dir * MEASURE_DIST)
    local ws = h.WalkSpeed
    say(string.format("=== วัดวิ่ง MoveTo d=%d WS=%.1f ===", MEASURE_DIST, ws))

    task.spawn(function()
        h:MoveTo(dest)
        local t0 = os.clock()
        local last = start
        local traveled = 0
        local samples, sumInst = 0, 0
        local maxInst = 0
        local warmed = false

        while S.run do
            h, r = hr()
            if not h or not r or h.Health <= 0 then say("ตัวเปลี่ยน/ตาย"); break end
            local flatPos = Vector3.new(r.Position.X, start.Y, r.Position.Z)
            local flatDest = Vector3.new(dest.X, start.Y, dest.Z)
            local rem = (flatDest - flatPos).Magnitude
            if rem <= 4 then break end

            local dt = RunS.Heartbeat:Wait()
            if dt <= 0 then dt = 1 / 60 end
            h, r = hr()
            if not r then break end
            local now = r.Position
            local step = Vector3.new(now.X - last.X, 0, now.Z - last.Z).Magnitude
            last = now
            -- ข้ามช่วงเร่งต้นทาง ~0.15s
            if os.clock() - t0 > 0.15 then
                warmed = true
                traveled = traveled + step
                local inst = step / dt
                if inst > maxInst then maxInst = inst end
                samples = samples + 1
                sumInst = sumInst + inst
            end
            -- timeout กันค้าง
            if os.clock() - t0 > 12 then say("วัด timeout"); break end
        end

        pcall(function()
            h = select(1, hr())
            r = select(2, hr())
            if h and r then
                h:MoveTo(r.Position)
                h:Move(Vector3.zero)
                r.AssemblyLinearVelocity = Vector3.zero
            end
        end)

        local elapsed = os.clock() - t0
        local avgInst = samples > 0 and (sumInst / samples) or 0
        -- ใช้ avg จากช่วง warmed เป็นความเร็วจริง (กันเร่ง/เบรกปลายทาง)
        local measured = avgInst
        if measured < 1 then
            -- fallback: ระยะรวม / เวลา
            local endP = select(2, hr())
            local d = endP and Vector3.new(endP.Position.X - start.X, 0, endP.Position.Z - start.Z).Magnitude or 0
            measured = elapsed > 0 and (d / elapsed) or 0
        end

        S.realSpeed = measured
        S.wsAtMeasure = ws
        S.boost = 1.0
        refreshBoostLabel()
        say(string.format(
            "วิ่งจริง avg=%.1f max=%.1f WS=%.1f (%.2fs n=%d)",
            measured, maxInst, ws, elapsed, samples
        ))
        say(string.format("ตั้ง CF base=%.1f boost=0%% → กด「ใช้ CF」หรือ「+%%」ก่อน", measured))
        S.run = false
    end)
end

-- ② CFrame ที่ความเร็ว = realSpeed * boost
local function cfWalk(goal, label)
    local h, r = hr()
    if not h or not r then return false, "ไม่มีตัว" end
    local base = S.realSpeed
    if not base or base < 1 then return false, "ยังไม่วัดวิ่ง — กด「วัดวิ่ง」ก่อน" end

    local speed = base * S.boost
    local dest = goal
    local dist = (dest - r.Position).Magnitude
    local eta = dist / speed
    local snap = 0
    local maxInst = 0
    local t0 = os.clock()
    local stutter = 0 -- เฟรมที่ drift/ดึง

    say(string.format(
        "%s CF → (%.0f,%.0f,%.0f) d=%.0f base=%.1f ×%.0f%% =%.1f eta=%.1fs",
        label or "CF", dest.X, dest.Y, dest.Z, dist, base, (S.boost - 1) * 100, speed, eta
    ))

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
        local step = math.min(rem, speed * dt)
        local dir = remain.Unit
        local target = r.Position + dir * step
        target = Vector3.new(target.X, floorY(target) + 3.2, target.Z)

        local before = r.Position
        r.CFrame = CFrame.new(target, target + Vector3.new(dir.X, 0, dir.Z))
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero

        h, r = hr()
        if r then
            local moved = (r.Position - before).Magnitude
            local drift = (r.Position - target).Magnitude
            if drift > 4 then snap = snap + 1; stutter = stutter + 1 end
            local inst = moved / math.max(dt, 1 / 240)
            if inst > maxInst then maxInst = inst end
            traveled = traveled + moved
            if step > 0.5 and moved < step * 0.35 then
                snap = snap + 1
                stutter = stutter + 1
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
    local ok = err <= 6 and snap == 0
    return ok, string.format(
        "%s done %.2fs err=%.1f snap=%d stutter=%d avg=%.1f max=%.1f (cap=%.1f)",
        label or "CF", elapsed, err, snap, stutter, avg, maxInst, speed
    )
end

local function goCf(destXZ, tag)
    if not S.realSpeed then say("กด「วัดวิ่ง」ก่อน"); return end
    local useClip = S.wantClip == true
    if useClip then setClip(true) end
    S.run = true
    local dest = surfaceOf(destXZ)
    say(string.format("=== %s CF boost=+%.0f%% cap=%.1f clip=%s ===",
        tag or "GO", (S.boost - 1) * 100, cfCap(), tostring(useClip)))

    task.spawn(function()
        local ok, msg = cfWalk(dest, tag or "GO")
        say(msg)
        if ok then
            say("ผ่าน — ไม่กระตุก")
        else
            say("กระตุก/ดึง — ลด boost หรือใช้เท่าจริง")
        end
        if useClip then setClip(false) end
        S.run = false
    end)
end

-- ③ สลับ MoveTo 1วิ ↔ CF@(MoveTo+10%) 1วิ จนถึงเป้า
local function runAlt(destXZ, tag)
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end
    local useClip = S.wantClip == true
    if useClip then setClip(true) end
    S.run = true
    local dest = surfaceOf(destXZ)
    local live = S.realSpeed -- อัปเดตจากช่วง MoveTo
    local snapTotal, stutterTotal = 0, 0
    local seg = 0

    say(string.format(
        "=== %s ALT MoveTo↔CF(+%.0f%%) ทุก %.0fs d=%.0f ===",
        tag or "ALT", (ALT_CF_MULT - 1) * 100, ALT_SEC, (dest - r.Position).Magnitude
    ))

    task.spawn(function()
        local tAll = os.clock()
        while S.run do
            h, r = hr()
            if not h or not r or h.Health <= 0 then say("ตัวเปลี่ยน/ตาย"); break end
            local rem0 = (dest - r.Position).Magnitude
            if rem0 <= 3 then break end

            -- —— ช่วง MoveTo ——
            seg = seg + 1
            say(string.format("[%d] MoveTo %.0fs rem=%.0f", seg, ALT_SEC, rem0))
            h:MoveTo(dest)
            local t0 = os.clock()
            local last = r.Position
            local samples, sumInst = 0, 0
            while S.run and (os.clock() - t0) < ALT_SEC do
                local dt = RunS.Heartbeat:Wait()
                if dt <= 0 then dt = 1 / 60 end
                h, r = hr()
                if not h or not r then break end
                if (dest - r.Position).Magnitude <= 3 then break end
                local step = Vector3.new(r.Position.X - last.X, 0, r.Position.Z - last.Z).Magnitude
                last = r.Position
                local inst = step / dt
                samples = samples + 1
                sumInst = sumInst + inst
            end
            if samples > 0 then
                live = sumInst / samples
                S.realSpeed = live
            end
            -- หยุด MoveTo ก่อนสลับ CF
            h, r = hr()
            if h and r then
                h:MoveTo(r.Position)
                h:Move(Vector3.zero)
                r.AssemblyLinearVelocity = Vector3.zero
            end
            if not S.run then break end
            if r and (dest - r.Position).Magnitude <= 3 then break end

            local base = live or S.realSpeed
            if not base or base < 1 then
                say("ยังวัดความเร็ว MoveTo ไม่ได้ — ข้าม CF"); break
            end
            local cfSpeed = base * ALT_CF_MULT

            -- —— ช่วง CF = MoveTo+10% ——
            seg = seg + 1
            say(string.format("[%d] CF@%.1f (+10%% จาก MoveTo %.1f) %.0fs", seg, cfSpeed, base, ALT_SEC))
            local t1 = os.clock()
            local snap, stutter = 0, 0
            while S.run and (os.clock() - t1) < ALT_SEC do
                h, r = hr()
                if not h or not r or h.Health <= 0 then break end
                local remain = dest - r.Position
                local rem = remain.Magnitude
                if rem <= 2.5 then break end
                local dt = RunS.Heartbeat:Wait()
                if dt <= 0 then dt = 1 / 60 end
                local step = math.min(rem, cfSpeed * dt)
                local dir = remain.Unit
                local target = Vector3.new(
                    r.Position.X + dir.X * step,
                    floorY(r.Position) + 3.2,
                    r.Position.Z + dir.Z * step
                )
                local before = r.Position
                r.CFrame = CFrame.new(target, target + Vector3.new(dir.X, 0, dir.Z))
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
                h, r = hr()
                if r then
                    local moved = (r.Position - before).Magnitude
                    local drift = (r.Position - target).Magnitude
                    if drift > 4 then snap = snap + 1; stutter = stutter + 1 end
                    if step > 0.5 and moved < step * 0.35 then
                        snap = snap + 1; stutter = stutter + 1
                    end
                end
            end
            snapTotal = snapTotal + snap
            stutterTotal = stutterTotal + stutter
            if snap > 0 then
                say(string.format("  ⚠ CF snap=%d stutter=%d", snap, stutter))
            end
        end

        h, r = hr()
        local err = r and (r.Position - dest).Magnitude or 999
        say(string.format(
            "ALT จบ %.1fs err=%.1f snap=%d stutter=%d live=%.1f",
            os.clock() - tAll, err, snapTotal, stutterTotal, live or -1
        ))
        if snapTotal == 0 and err <= 6 then
            say("ผ่าน — สลับ MoveTo/CF ไม่กระตุก")
        else
            say("มี snap/err — ดูช่วง CF")
        end
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
f.Size = UDim2.new(0, 560, 0, 340)
f.Position = UDim2.new(0, 12, 0.36, 0)
f.BackgroundColor3 = Color3.fromRGB(24, 32, 40)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -16, 0, 26)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 Motion Lab v3.2 — วัด / CF / สลับ MoveTo↔CF+10% ทุก1วิ"
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

-- แถว1: วัด / CF / +% / HOME
local bMeasure = button("① วัดวิ่ง", 10, 34, 78, Color3.fromRGB(50, 110, 160))
local bCf = button("② ใช้ CF", 92, 34, 72, Color3.fromRGB(40, 140, 95))
local bAlt = button("③ สลับ1วิ", 168, 34, 78, Color3.fromRGB(140, 80, 160))
S.boostBtn = button("+0%", 250, 34, 48, Color3.fromRGB(180, 120, 40))
local bResetBoost = button("=100%", 302, 34, 48, Color3.fromRGB(90, 90, 70))
local bHome = button("HOME", 354, 34, 48, Color3.fromRGB(45, 105, 165))
local bStop = button("STOP", 406, 34, 44, Color3.fromRGB(165, 50, 55))
local bCopy = button("COPY", 454, 34, 44, Color3.fromRGB(75, 75, 80))
local bClip = button("CLIP", 502, 34, 44, Color3.fromRGB(100, 90, 50))

local hint = Instance.new("TextLabel", f)
hint.Size = UDim2.new(1, -20, 0, 40)
hint.Position = UDim2.new(0, 10, 0, 64)
hint.BackgroundTransparency = 1
hint.Text = "① วัดวิ่ง  ② CF(boost)  ③ สลับ1วิ = MoveTo 1s ↔ CF@(MoveTo+10%) 1s วนถึงเป้า\nHOME=เป้า | ไม่มี HOME = ไปข้างหน้า 80"
hint.TextColor3 = Color3.fromRGB(190, 210, 220)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top

logBox = Instance.new("TextLabel", f)
logBox.Size = UDim2.new(1, -16, 0, 210)
logBox.Position = UDim2.new(0, 8, 0, 108)
logBox.BackgroundColor3 = Color3.new(0, 0, 0)
logBox.BackgroundTransparency = 0.2
logBox.TextColor3 = Color3.fromRGB(180, 245, 190)
logBox.Font = Enum.Font.Code
logBox.TextSize = 10
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.TextWrapped = true
logBox.ClipsDescendants = true

local function destForCf()
    if S.home then return S.home, "→HOME" end
    local _, r = hr()
    if not r then return nil end
    return r.Position + flatLook(r) * 80, "→AHEAD80"
end

bMeasure.MouseButton1Click:Connect(function()
    if S.run then say("กำลังทำงาน"); return end
    measureRun()
end)

bCf.MouseButton1Click:Connect(function()
    if S.run then say("กำลังทำงาน"); return end
    local dest, tag = destForCf()
    if not dest then say("ไม่มีเป้า"); return end
    goCf(dest, tag)
end)

bAlt.MouseButton1Click:Connect(function()
    if S.run then say("กำลังทำงาน"); return end
    local dest, tag = destForCf()
    if not dest then say("ไม่มีเป้า"); return end
    runAlt(dest, "ALT" .. (tag or ""))
end)

S.boostBtn.MouseButton1Click:Connect(function()
    -- +10% ต่อครั้ง สูงสุด +50%
    if S.boost >= 1.5 then
        say("boost สูงสุด +50% แล้ว")
        return
    end
    S.boost = math.min(1.5, math.floor(S.boost * 10 + 1.01) / 10) -- 1.0→1.1→1.2…
    refreshBoostLabel()
    local cap = cfCap()
    if S.realSpeed then
        say(string.format("boost=+%.0f%% → CF cap=%.1f (base=%.1f)", (S.boost - 1) * 100, cap, S.realSpeed))
    else
        say(string.format("boost=+%.0f%% (ยังไม่วัดวิ่ง)", (S.boost - 1) * 100))
    end
end)

bResetBoost.MouseButton1Click:Connect(function()
    S.boost = 1.0
    refreshBoostLabel()
    say("boost=0% (=ความเร็วจริง)")
end)

bHome.MouseButton1Click:Connect(function()
    local _, r = hr()
    if r then
        S.home = r.Position
        say(string.format("HOME=(%.0f,%.0f,%.0f) ← เป้า CF", r.Position.X, r.Position.Y, r.Position.Z))
    end
end)

bStop.MouseButton1Click:Connect(function()
    S.run = false
    say("STOP")
end)

bClip.MouseButton1Click:Connect(function()
    S.wantClip = not S.wantClip
    bClip.Text = S.wantClip and "CLIP ON" or "CLIP"
    bClip.BackgroundColor3 = S.wantClip and Color3.fromRGB(40, 130, 90) or Color3.fromRGB(100, 90, 50)
    say("wantClip=" .. tostring(S.wantClip))
end)

bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then
        pcall(c, "=== Egg01 Motion Lab v3.2 ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)

refreshBoostLabel()
say("v3.2 ③ สลับ1วิ = MoveTo 1s ↔ CF@(ความเร็วMoveTo+10%) 1s")
say("HOME → ไปจุดเริ่ม → ③ | หรือไม่มี HOME = ข้างหน้า 80")
