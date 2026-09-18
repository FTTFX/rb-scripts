-- Egg01_WarpSpy.lua v1.0
-- เทสวาปหลายแบบเพื่อออกนอกโซนสี (GuardAreas) — log วิธี / เวลา / ระยะ / ถือไข่ / ในโซน?
-- ใช้: กด HOME(ทิศบ้าน) → ขโมยไข่ → TEST_ALL หรือ NEXT → COPY ส่งมา
if _G.EGG01WS_GUI then pcall(function() _G.EGG01WS_GUI:Destroy() end) end
if _G.EGG01WS_CONNS then
    for _, c in ipairs(_G.EGG01WS_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.EGG01WS_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local OUT, T0 = {}, os.clock()
local PAUSED = false
local BUSY = false
local HOME = nil
local carrying = false
local eggArea = nil
local methodIdx = 1

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01WarpSpy"
gui.ResetOnSpawn = false
gui.DisplayOrder = 90
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01WS_GUI = gui

local bar = Instance.new("Frame", gui)
bar.Size = UDim2.new(0, 520, 0, 34)
bar.Position = UDim2.new(1, -528, 0, 8)
bar.BackgroundColor3 = Color3.fromRGB(20, 35, 30)
bar.BackgroundTransparency = 0.12
bar.BorderSizePixel = 0

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 620, 0, 280)
box.Position = UDim2.new(0, 8, 1, -288)
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.18
box.TextColor3 = Color3.fromRGB(200, 255, 220)
box.TextSize = 11
box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true
box.MultiLine = true
box.ClearTextOnFocus = false
box.TextEditable = false

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    if PAUSED then return end
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > 500 then table.remove(OUT, 1) end
    redraw()
end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", bar)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, 3)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 70)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    return b
end

local bHome = hbtn("HOME", 4, 52, Color3.fromRGB(60, 100, 160))
local bAll = hbtn("TEST_ALL", 60, 72, Color3.fromRGB(30, 120, 70))
local bNext = hbtn("NEXT", 136, 52, Color3.fromRGB(30, 110, 100))
local bCopy = hbtn("COPY", 192, 52, Color3.fromRGB(90, 70, 140))
local bClr = hbtn("CLR", 248, 40, Color3.fromRGB(80, 50, 50))
local bPause = hbtn("PAUSE", 292, 56, Color3.fromRGB(90, 90, 50))

local function char()
    return LP.Character
end
local function hrp()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function flat(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function inBox(cf, size, pos, yPad)
    yPad = yPad or 40
    local lp = cf:PointToObjectSpace(pos)
    return math.abs(lp.X) <= size.X * 0.5
        and math.abs(lp.Y) <= size.Y * 0.5 + yPad
        and math.abs(lp.Z) <= size.Z * 0.5
end

local function findGuardBiome(areaName)
    if not areaName then return nil end
    local areas = workspace:FindFirstChild("__OBJECTS")
    areas = areas and areas:FindFirstChild("Areas")
    local guards = areas and areas:FindFirstChild("GuardAreas")
    if not guards then return nil end
    local hit = guards:FindFirstChild(areaName)
    if hit then return hit end
    local want = tostring(areaName):lower()
    for _, c in ipairs(guards:GetChildren()) do
        local n = c.Name:lower()
        if n == want or n:find(want, 1, true) or want:find(n, 1, true) then
            return c
        end
    end
    return nil
end

local function biomeBox()
    local biome = findGuardBiome(eggArea)
    if not biome then return nil end
    local ok, cf, size = pcall(function() return biome:GetBoundingBox() end)
    if not ok then return nil end
    return cf, size, biome.Name
end

local function insideZone(pos, pad)
    pad = pad or 16
    local cf, size = biomeBox()
    if not cf then return false, "no-biome" end
    return inBox(cf, size + Vector3.new(pad, 60, pad), pos), nil
end

local function exitDest(pad)
    pad = pad or 40
    local r = hrp()
    if not r then return nil end
    local cf, size, name = biomeBox()
    if not cf then return nil end
    local aim = HOME or (cf.Position + cf.LookVector * 200)
    local dir = Vector3.new(aim.X - r.Position.X, 0, aim.Z - r.Position.Z)
    if dir.Magnitude < 1 then
        dir = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
        if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
    end
    dir = dir.Unit
    local big = size + Vector3.new(pad, 60, pad)
    local pos = r.Position
    for _ = 1, 100 do
        pos = pos + dir * 20
        if not inBox(cf, big, pos) then
            return Vector3.new(pos.X, r.Position.Y + 3, pos.Z) + dir * 30, name, flat(r.Position, pos)
        end
    end
    local half = math.max(size.X, size.Z) * 0.5 + pad + 50
    local c = cf.Position
    local dest = Vector3.new(c.X, r.Position.Y + 3, c.Z) + dir * half
    return dest, name, flat(r.Position, dest)
end

local function snap(label)
    local r = hrp()
    if not r then
        return { pos = nil, carry = carrying, inZone = nil }
    end
    local inz = insideZone(r.Position, 16)
    return {
        label = label,
        t = os.clock(),
        pos = r.Position,
        carry = carrying,
        inZone = inz,
    }
end

local function reportMethod(name, tStart, before, samples, note)
    local after = samples[#samples]
    local moved0 = (before.pos and after.pos) and flat(before.pos, after.pos) or -1
    local bounced = false
    if #samples >= 2 and before.pos and samples[1].pos and samples[#samples].pos then
        local peak = 0
        for _, s in ipairs(samples) do
            if s.pos then peak = math.max(peak, flat(before.pos, s.pos)) end
        end
        if peak > 20 and moved0 < peak * 0.35 then bounced = true end
    end
    local ms = (os.clock() - tStart) * 1000
    L(string.format(
        "▶ %s | %.0fms | move=%.0f studs | carry %s→%s | zone %s→%s%s%s",
        name,
        ms,
        moved0,
        before.carry and "Y" or "N",
        after.carry and "Y" or "N",
        before.inZone and "IN" or "OUT",
        after.inZone and "IN" or "OUT",
        bounced and " | RUBBERBAND" or "",
        note and (" | " .. note) or ""
    ))
    for i, s in ipairs(samples) do
        if s.pos then
            L(string.format(
                "   t+%.2f pos=%.0f,%.0f,%.0f d=%.0f carry=%s zone=%s",
                s.t - tStart,
                s.pos.X, s.pos.Y, s.pos.Z,
                flat(before.pos, s.pos),
                s.carry and "Y" or "N",
                s.inZone and "IN" or "OUT"
            ))
        end
    end
    local ok = after.pos and (not after.inZone) and after.carry
    if ok then
        L("   ★ SUCCESS ออกโซนแล้วยังถือไข่: " .. name)
    end
    return ok, moved0, bounced
end

-- ===== warp methods =====
local METHODS = {}

METHODS[#METHODS + 1] = {
    name = "CFrame_once",
    run = function(dest)
        local r = hrp()
        if not r then return "no-hrp" end
        r.CFrame = CFrame.new(dest)
        r.AssemblyLinearVelocity = Vector3.zero
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "PivotTo_char",
    run = function(dest)
        local c = char()
        if not c then return "no-char" end
        c:PivotTo(CFrame.new(dest))
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "SetPrimaryPartCFrame",
    run = function(dest)
        local c = char()
        if not c or not c.PrimaryPart then return "no-pp" end
        c:SetPrimaryPartCFrame(CFrame.new(dest))
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "Anchored_CFrame_0.2s",
    run = function(dest)
        local r = hrp()
        if not r then return "no-hrp" end
        local was = r.Anchored
        r.Anchored = true
        r.CFrame = CFrame.new(dest)
        task.wait(0.2)
        r.Anchored = was
        r.AssemblyLinearVelocity = Vector3.zero
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "CFrame_hold_8frames",
    run = function(dest)
        local r = hrp()
        if not r then return "no-hrp" end
        for _ = 1, 8 do
            r = hrp()
            if not r then break end
            r.CFrame = CFrame.new(dest)
            r.AssemblyLinearVelocity = Vector3.zero
            RunService.Heartbeat:Wait()
        end
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "MicroHop_25",
    run = function(dest)
        local r = hrp()
        if not r then return "no-hrp" end
        local start = r.Position
        local flatV = Vector3.new(dest.X - start.X, 0, dest.Z - start.Z)
        local dist = flatV.Magnitude
        if dist < 1 then return "dest-near" end
        local dir = flatV.Unit
        local step, gone = 25, 0
        while gone < dist do
            gone = math.min(gone + step, dist)
            r = hrp()
            if not r then break end
            local p = start + dir * gone + Vector3.new(0, 2, 0)
            r.CFrame = CFrame.new(p)
            r.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.08)
            if not insideZone(r.Position, 40) then break end
        end
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "MicroHop_12",
    run = function(dest)
        local r = hrp()
        if not r then return "no-hrp" end
        local start = r.Position
        local flatV = Vector3.new(dest.X - start.X, 0, dest.Z - start.Z)
        local dist = flatV.Magnitude
        if dist < 1 then return "dest-near" end
        local dir = flatV.Unit
        local step, gone = 12, 0
        while gone < dist do
            gone = math.min(gone + step, dist)
            r = hrp()
            if not r then break end
            local p = start + dir * gone + Vector3.new(0, 2, 0)
            r.CFrame = CFrame.new(p)
            r.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.05)
            if not insideZone(r.Position, 40) then break end
        end
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "Tween_HRP_0.6s",
    run = function(dest)
        local r = hrp()
        if not r then return "no-hrp" end
        local tw = TweenService:Create(r, TweenInfo.new(0.6, Enum.EasingStyle.Linear), { CFrame = CFrame.new(dest) })
        tw:Play()
        tw.Completed:Wait()
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "Tween_HRP_2.0s",
    run = function(dest)
        local r = hrp()
        if not r then return "no-hrp" end
        local tw = TweenService:Create(r, TweenInfo.new(2.0, Enum.EasingStyle.Linear), { CFrame = CFrame.new(dest) })
        tw:Play()
        tw.Completed:Wait()
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "ALV_burst_120_1s",
    run = function(dest)
        local r, h = hrp(), hum()
        if not r or not h then return "no-hrp" end
        local dir = Vector3.new(dest.X - r.Position.X, 0, dest.Z - r.Position.Z)
        if dir.Magnitude < 1 then return "dest-near" end
        dir = dir.Unit
        local t0 = os.clock()
        while os.clock() - t0 < 1 do
            r = hrp()
            if not r then break end
            r.AssemblyLinearVelocity = Vector3.new(dir.X * 120, 0, dir.Z * 120)
            if not insideZone(r.Position, 40) then break end
            RunService.Heartbeat:Wait()
        end
        if r then r.AssemblyLinearVelocity = Vector3.zero end
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "WalkSpeed_40_MoveTo",
    run = function(dest)
        local r, h = hrp(), hum()
        if not r or not h then return "no-hrp" end
        local old = h.WalkSpeed
        h.WalkSpeed = 40
        h:MoveTo(Vector3.new(dest.X, r.Position.Y, dest.Z))
        local t0 = os.clock()
        while os.clock() - t0 < 6 do
            r = hrp()
            if not r then break end
            if flat(r.Position, dest) < 15 then break end
            if not insideZone(r.Position, 40) then break end
            task.wait(0.15)
        end
        h.WalkSpeed = old
        return nil
    end,
}

METHODS[#METHODS + 1] = {
    name = "CFrame_Yup_then_XZ",
    run = function(dest)
        local r = hrp()
        if not r then return "no-hrp" end
        local up = r.Position + Vector3.new(0, 80, 0)
        r.CFrame = CFrame.new(up)
        task.wait(0.1)
        r = hrp()
        if r then
            r.CFrame = CFrame.new(dest + Vector3.new(0, 5, 0))
            r.AssemblyLinearVelocity = Vector3.zero
        end
        return nil
    end,
}

local function runOne(m)
    if not carrying then
        L("ข้าม " .. m.name .. " — ยังไม่ถือไข่ (ขโมยก่อน)")
        return false
    end
    local dest, bname, need = exitDest(40)
    if not dest then
        L("ข้าม " .. m.name .. " — ไม่เจอจุดออก (AreaId/GuardAreas?)")
        return false
    end
    local before = snap("before")
    L(string.format("=== TEST %s → %s need~%.0f aim=%.0f,%.0f,%.0f ===",
        m.name, tostring(bname or eggArea), need or -1, dest.X, dest.Y, dest.Z))
    local tStart = os.clock()
    local err = m.run(dest)
    if err then
        L("   fail setup: " .. tostring(err))
        return false
    end
    local samples = {}
    local marks = { 0.05, 0.15, 0.35, 0.7 }
    local tMarked = 0
    for _, mks in ipairs(marks) do
        local w = mks - tMarked
        if w > 0 then task.wait(w) end
        tMarked = mks
        samples[#samples + 1] = snap(nil)
        samples[#samples].t = os.clock()
    end
    local ok = reportMethod(m.name, tStart, before, samples, nil)
    return ok
end

local function testAll()
    if BUSY then return end
    BUSY = true
    L("======== TEST_ALL เริ่ม (" .. #METHODS .. " วิธี) ========")
    local winners = {}
    for i, m in ipairs(METHODS) do
        if not carrying then
            L("หยุด TEST_ALL — หลุดไข่ที่วิธี #" .. i)
            break
        end
        methodIdx = i
        local ok = runOne(m)
        if ok then winners[#winners + 1] = m.name end
        task.wait(0.6)
    end
    if #winners > 0 then
        L("★ วิธีที่ได้: " .. table.concat(winners, ", "))
    else
        L("★ ไม่มีวิธีไหนออกโซนแล้วยังถือไข่")
    end
    L("======== TEST_ALL จบ ========")
    BUSY = false
end

local function testNext()
    if BUSY then return end
    BUSY = true
    if methodIdx > #METHODS then methodIdx = 1 end
    local m = METHODS[methodIdx]
    L(string.format("NEXT #%d/%d", methodIdx, #METHODS))
    runOne(m)
    methodIdx = methodIdx + 1
    BUSY = false
end

-- FieldEggCarry
do
    local function findNet(part)
        local pkg = RS:FindFirstChild("Packages")
        local net = pkg and pkg:FindFirstChild("Networking")
        if not net then return nil end
        for _, d in ipairs(net:GetDescendants()) do
            if d.Name:find(part, 1, true) then return d end
        end
        return nil
    end
    local re = findNet("FieldEggCarry")
    if re and re:IsA("RemoteEvent") then
        table.insert(_G.EGG01WS_CONNS, re.OnClientEvent:Connect(function(t)
            if typeof(t) ~= "table" then return end
            if t.IsCarrying == true then
                carrying = true
                if t.AreaId then eggArea = t.AreaId end
                L("server: ถือไข่ โซน=" .. tostring(eggArea or "?"))
            elseif t.IsCarrying == false then
                carrying = false
                L("server: ไม่ถือไข่")
            end
        end))
        L("ฟัง FieldEggCarry ✅")
    else
        L("⚠ ไม่เจอ FieldEggCarry")
    end
end

bHome.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then L("ไม่มีตัว"); return end
    HOME = r.Position
    L(string.format("HOME=%.0f,%.0f,%.0f", HOME.X, HOME.Y, HOME.Z))
end)

bAll.MouseButton1Click:Connect(function()
    task.spawn(testAll)
end)

bNext.MouseButton1Click:Connect(function()
    task.spawn(testNext)
end)

bCopy.MouseButton1Click:Connect(function()
    local t = "=== Egg01 WarpSpy v1.0 ===\n" .. table.concat(OUT, "\n")
    if setclipboard then
        setclipboard(t)
        L("COPY ✅")
    else
        L("ไม่มี setclipboard — เลือกข้อความในกล่อง")
    end
end)

bClr.MouseButton1Click:Connect(function()
    OUT = {}
    T0 = os.clock()
    redraw()
    L("เคลียร์แล้ว")
end)

bPause.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    bPause.Text = PAUSED and "RESUME" or "PAUSE"
end)

L("Egg01 WarpSpy v1.0 — " .. #METHODS .. " วิธี")
L("HOME → ขโมยไข่ → TEST_ALL (หรือ NEXT ทีละอัน) → COPY")
L("เป้า: ออกนอก GuardAreas แล้วยังถือไข่")
