-- Egg01 Motion Lab v4.1 — MoveTo+CF ครอป / MoveTo+velocity+10%
-- ปุ่ม: HOME | GO ครอป | VEL+10% | STOP | COPY

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
-- เป้าความเร็ว = WalkSpeed × 1.1 (ไม่ยึด base ต้นทางที่ต่ำ)
local HOLD_MULT = 1.1
local VEL_MULT = 1.1

local function say(m)
    S.lines[#S.lines + 1] = tostring(m)
    if #S.lines > 20 then table.remove(S.lines, 1) end
    if logBox then logBox.Text = table.concat(S.lines, "\n") end
    warn("[MotionLab] " .. tostring(m))
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
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

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

--[[
  MoveTo + CF crop:
  1) สั่ง MoveTo(เป้า) ตามปกติ
  2) ทุก Heartbeat:
     - ถ้าความเร็วในแนวเป้า < hold → CF ดันไปข้างหน้าให้ครบ hold*dt
     - ถ้าปลิวออกแนว (ด้านข้าง/ถอย) → CF ดึงกลับบนเส้นทาง
     - ล้าง velocity แนวตั้ง/ด้านข้างที่เกิน
]]
local function hybridGo(destXZ, tag)
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end

    local dest = surfaceOf(destXZ)
    S.run = true
    say(string.format("=== %s MoveTo+CF crop → (%.0f,%.0f,%.0f) ===",
        tag or "HYB", dest.X, dest.Y, dest.Z))

    task.spawn(function()
        local start = r.Position
        local dist0 = flat(dest - start).Magnitude
        local hold = nil -- ตั้งหลังอุ่นเครื่อง 0.25s
        local snap, correct = 0, 0
        local t0 = os.clock()
        local last = start
        local warmSum, warmN = 0, 0

        h:MoveTo(dest)

        while S.run do
            h, r = hr()
            if not h or not r or h.Health <= 0 then say("ตัวเปลี่ยน/ตาย"); break end

            local flatRem = flat(dest - r.Position)
            local rem = flatRem.Magnitude
            if rem <= 3 then break end

            local dt = RunS.Heartbeat:Wait()
            if dt <= 0 then dt = 1 / 60 end

            h, r = hr()
            if not h or not r then break end

            -- วัดความเร็วจริงช่วงต้น → เป็น hold
            local moved = flat(r.Position - last).Magnitude
            last = r.Position
            local elapsed = os.clock() - t0
            if elapsed < 0.35 then
                if elapsed > 0.08 then
                    warmSum = warmSum + (moved / dt)
                    warmN = warmN + 1
                end
                h:MoveTo(dest)
            else
                if not hold then
                    hold = math.max(8, h.WalkSpeed * HOLD_MULT)
                    say(string.format("hold=%.1f (=WS×%.0f%%) WS=%.1f", hold, HOLD_MULT * 100, h.WalkSpeed))
                end

                local dir = flatRem.Unit
                local along = flat(r.AssemblyLinearVelocity):Dot(dir)
                local need = hold * dt
                local ideal = Vector3.new(
                    r.Position.X + dir.X * need,
                    floorY(r.Position) + 3.2,
                    r.Position.Z + dir.Z * need
                )

                local pathDir = flat(dest - start)
                local toMe = flat(r.Position - start)
                local pathLen = pathDir.Magnitude
                local lateral = 0
                if pathLen > 1 then
                    local u = pathDir.Unit
                    lateral = (toMe - u * toMe:Dot(u)).Magnitude
                end

                local slow = along < hold * 0.85
                local blown = lateral > 4 or along < -5

                if slow or blown then
                    local before = r.Position
                    -- ถ้าปลิว: ดึงกลับบนเส้นทางก่อน แล้วดันหน้า
                    if blown and pathLen > 1 then
                        local u = pathDir.Unit
                        local alongDist = math.clamp(toMe:Dot(u), 0, pathLen)
                        local onPath = start + u * alongDist
                        ideal = Vector3.new(onPath.X, floorY(onPath) + 3.2, onPath.Z) + u * need
                        ideal = Vector3.new(ideal.X, floorY(ideal) + 3.2, ideal.Z)
                    end
                    r.CFrame = CFrame.new(ideal, ideal + dir)
                    r.AssemblyLinearVelocity = dir * hold
                    r.AssemblyAngularVelocity = Vector3.zero
                    correct = correct + 1
                    local drift = (r.Position - before).Magnitude
                    if drift > hold * dt * 2.5 then snap = snap + 1 end
                else
                    -- ความเร็วโอเค — ยัง MoveTo อย่างเดียว แต่กัน Y ลอย/จมเล็กน้อย
                    local fy = floorY(r.Position) + 3.2
                    if math.abs(r.Position.Y - fy) > 2.5 then
                        r.CFrame = CFrame.new(r.Position.X, fy, r.Position.Z)
                            * (r.CFrame - r.CFrame.Position)
                        correct = correct + 1
                    end
                end

                -- รีเฟรช MoveTo เป็นระยะ
                if correct % 15 == 1 then
                    h:MoveTo(dest)
                end
            end
        end

        h, r = hr()
        if h and r then
            h:MoveTo(r.Position)
            h:Move(Vector3.zero)
            r.AssemblyLinearVelocity = Vector3.zero
        end
        local final = r and r.Position or dest
        local err = flat(final - dest).Magnitude
        say(string.format(
            "%s จบ %.1fs err=%.1f correct=%d snap=%d hold=%s",
            tag or "HYB", os.clock() - t0, err, correct, snap,
            hold and string.format("%.1f", hold) or "?"
        ))
        if err <= 5 and snap == 0 then
            say("ผ่าน — ความเร็วไม่ตก / ไม่ปลิวชัด")
        else
            say("เช็ก err/snap — อาจโดนดึงหรือเป้าไกล")
        end
        S.run = false
    end)
end

--[[
  MoveTo + velocity @ WS+10%:
  ทุกเฟรมบังคับ AssemblyLinearVelocity = dir * (WalkSpeed*1.1)
  ไม่ใช้ CFrame ย้ายตำแหน่ง
]]
local function velBoostGo(destXZ, tag)
    local h, r = hr()
    if not h or not r then say("ไม่มีตัว"); return end

    local dest = surfaceOf(destXZ)
    S.run = true
    say(string.format("=== %s MoveTo+VEL@WS+%.0f%% → (%.0f,%.0f,%.0f) ===",
        tag or "VEL", (VEL_MULT - 1) * 100, dest.X, dest.Y, dest.Z))

    task.spawn(function()
        local pushN, snap = 0, 0
        local t0 = os.clock()
        local last = r.Position
        local traveled = 0
        local targetSpd = math.max(8, h.WalkSpeed * VEL_MULT)
        say(string.format("vel=%.1f (=WS×%.0f%%) WS=%.1f", targetSpd, VEL_MULT * 100, h.WalkSpeed))

        h:MoveTo(dest)

        while S.run do
            h, r = hr()
            if not h or not r or h.Health <= 0 then say("ตัวเปลี่ยน/ตาย"); break end

            local flatRem = flat(dest - r.Position)
            local rem = flatRem.Magnitude
            if rem <= 3 then break end

            local dt = RunS.Heartbeat:Wait()
            if dt <= 0 then dt = 1 / 60 end

            h, r = hr()
            if not h or not r then break end

            -- อัปเดตตาม WS ปัจจุบัน (อาจเปลี่ยนตอนถือไข่)
            targetSpd = math.max(8, h.WalkSpeed * VEL_MULT)

            local moved = flat(r.Position - last).Magnitude
            traveled = traveled + moved
            last = r.Position

            local dir = flatRem.Unit
            local vy = r.AssemblyLinearVelocity.Y
            r.AssemblyLinearVelocity = Vector3.new(dir.X * targetSpd, vy, dir.Z * targetSpd)
            pushN = pushN + 1

            if pushN % 20 == 1 then
                h:MoveTo(dest)
            end

            local expect = targetSpd * dt * 0.35
            if moved < expect and rem > 10 then
                snap = snap + 1
            end
            local along = flat(r.AssemblyLinearVelocity):Dot(dir)
            if along < targetSpd * 0.4 then
                r.AssemblyLinearVelocity = dir * targetSpd
            end
        end

        h, r = hr()
        if h and r then
            h:MoveTo(r.Position)
            h:Move(Vector3.zero)
            r.AssemblyLinearVelocity = Vector3.zero
        end
        local final = r and r.Position or dest
        local err = flat(final - dest).Magnitude
        local elapsed = os.clock() - t0
        local avg = elapsed > 0 and (traveled / elapsed) or 0
        say(string.format(
            "%s จบ %.1fs err=%.1f push=%d snap=%d avg=%.1f (cap=%.1f)",
            tag or "VEL", elapsed, err, pushN, snap, avg, targetSpd
        ))
        if err <= 5 and snap < 8 then
            say("ผ่าน — MoveTo+VEL@WS+10% ใช้ได้")
        else
            say("มี snap/err — เซิร์ฟอาจตัด velocity")
        end
        S.run = false
    end)
end

-- GUI ปุ่มน้อย
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_MotionLab"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1025
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui

local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 480, 0, 260)
f.Position = UDim2.new(0, 12, 0.42, 0)
f.BackgroundColor3 = Color3.fromRGB(22, 30, 38)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -12, 0, 24)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "MotionLab v4.2 — เป้า WS×110% (ครอป / VEL)"
title.TextColor3 = Color3.fromRGB(130, 220, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local function button(t, x, y, w, c)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, w, 0, 30)
    b.Position = UDim2.new(0, x, 0, y)
    b.Text = t
    b.BackgroundColor3 = c
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bHome = button("HOME", 10, 34, 64, Color3.fromRGB(45, 105, 165))
local bGo = button("GO ครอป", 80, 34, 78, Color3.fromRGB(40, 140, 95))
local bVel = button("VEL+10%", 164, 34, 78, Color3.fromRGB(160, 100, 40))
local bStop = button("STOP", 248, 34, 64, Color3.fromRGB(165, 50, 55))
local bCopy = button("COPY", 318, 34, 64, Color3.fromRGB(75, 75, 80))

local hint = Instance.new("TextLabel", f)
hint.Size = UDim2.new(1, -16, 0, 22)
hint.Position = UDim2.new(0, 10, 0, 68)
hint.BackgroundTransparency = 1
hint.Text = "HOME → GOครอป / VEL+10% = เป้า WalkSpeed×1.1"
hint.TextColor3 = Color3.fromRGB(180, 200, 210)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left

logBox = Instance.new("TextLabel", f)
logBox.Size = UDim2.new(1, -16, 0, 155)
logBox.Position = UDim2.new(0, 8, 0, 94)
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

bGo.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    if not S.home then say("กด HOME ที่เป้าก่อน"); return end
    hybridGo(S.home, "→HOME")
end)

bVel.MouseButton1Click:Connect(function()
    if S.run then say("กำลังวิ่ง"); return end
    if not S.home then say("กด HOME ที่เป้าก่อน"); return end
    velBoostGo(S.home, "VEL→HOME")
end)

bStop.MouseButton1Click:Connect(function()
    S.run = false
    local h, r = hr()
    if h and r then
        pcall(function()
            h:MoveTo(r.Position)
            h:Move(Vector3.zero)
            r.AssemblyLinearVelocity = Vector3.zero
        end)
    end
    say("STOP")
end)

bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then
        pcall(c, "=== MotionLab v4.2 WS×110% ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)

say("v4.2 เป้า = WalkSpeed × 1.1")
say("HOME → VEL+10% หรือ GO ครอป")
