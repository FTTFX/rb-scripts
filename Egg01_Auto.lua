-- Egg01_Auto.lua v2.8
-- ทิ้งเมื่อออกจากโซนสีที่ขโมย | ใกล้เขตปลอดภัย/HOME = วิ่งเข้าบ้านเลยไม่ทิ้ง
-- โซนแรก: วาปสั้นทีละก้าวออกนอก GuardAreas แล้วทิ้งทันที (BV ทำให้หลุดไข่)

if _G.EGG01_V2 then
    pcall(function() _G.EGG01_V2.gui:Destroy() end)
    if _G.EGG01_V2.conns then
        for _, c in ipairs(_G.EGG01_V2.conns) do pcall(function() c:Disconnect() end) end
    end
end
_G.EGG01_V2 = { conns = {} }

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local HOME = nil
local RUN = false
local HOP = 140
local WAIT_DROP = 2
local HOME_R = 60
local START_AWAY = 120
local EXIT_HOP = 50 -- วาปทีละก้าวออกโซนแรก (สั้น กัน BAC+หลุดไข่)
local EXIT_PAD = 40
local lines = {}
local carrying = false
local carryUid = nil
local eggArea = nil -- โซนสีที่ขโมยมา (Forest/Snow/Desert/…) ต้องออกก่อนทิ้ง
local firstExitDone = false -- ออกโซนแรกเสร็จแล้ว
local firstDropPending = false -- พ้นโซนแล้วต้องทิ้งทันที 1 ครั้ง


-- ===== GUI ง่ายๆ =====
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_V2"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
pcall(function()
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01_V2.gui = gui

local function btn(text, x, color)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, 64, 0, 30)
    b.Position = UDim2.new(0, x, 0, 10)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Text = text
    b.BorderSizePixel = 0
    return b
end

local bHome  = btn("HOME", 10, Color3.fromRGB(50, 100, 180))
local bStart = btn("START", 80, Color3.fromRGB(40, 150, 70))
local bStop  = btn("STOP", 150, Color3.fromRGB(160, 50, 50))
local bCopy  = btn("COPY", 220, Color3.fromRGB(70, 70, 70))
local bClose = btn("X", 290, Color3.fromRGB(100, 40, 40))

local lab = Instance.new("TextLabel", gui)
lab.Size = UDim2.new(0, 340, 0, 22)
lab.Position = UDim2.new(0, 10, 0, 44)
lab.BackgroundTransparency = 1
lab.TextColor3 = Color3.fromRGB(255, 220, 100)
lab.Font = Enum.Font.GothamBold
lab.TextSize = 13
lab.TextXAlignment = Enum.TextXAlignment.Left
lab.Text = "พร้อม — กด HOME ที่จุดเกิด"

local log = Instance.new("TextBox", gui)
log.Size = UDim2.new(0, 400, 0, 150)
log.Position = UDim2.new(0, 10, 1, -160)
log.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
log.BackgroundTransparency = 0.25
log.TextColor3 = Color3.fromRGB(200, 255, 200)
log.Font = Enum.Font.Code
log.TextSize = 12
log.TextXAlignment = Enum.TextXAlignment.Left
log.TextYAlignment = Enum.TextYAlignment.Top
log.ClearTextOnFocus = false
log.TextEditable = false
log.MultiLine = true
log.TextWrapped = true
log.Text = ""

local function say(msg)
    lines[#lines + 1] = msg
    if #lines > 60 then table.remove(lines, 1) end
    log.Text = table.concat(lines, "\n")
    lab.Text = msg
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function dist2(a, b)
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

-- ถือไข่ = FieldEggCarry จาก server เท่านั้น (GUI DropHeldEgg ค้างได้ ไม่ใช้)
local function isCarry()
    return carrying == true
end

local function findNet(namePart)
    local pkg = RS:FindFirstChild("Packages")
    local net = pkg and pkg:FindFirstChild("Networking")
    if not net then return nil end
    for _, d in ipairs(net:GetDescendants()) do
        if d.Name:find(namePart, 1, true) then return d end
    end
    return nil
end

do
    local re = findNet("FieldEggCarry")
    if re and re:IsA("RemoteEvent") then
        table.insert(_G.EGG01_V2.conns, re.OnClientEvent:Connect(function(t)
            if typeof(t) ~= "table" then return end
            if t.IsCarrying == true then
                carrying = true
                carryUid = t.Uid
                if t.AreaId then eggArea = t.AreaId end
                say("server: ถือไข่แล้ว โซน=" .. tostring(eggArea or "?"))
            elseif t.IsCarrying == false then
                carrying = false
                carryUid = nil
                say("server: ไม่ถือไข่")
            end
        end))
        say("ฟัง FieldEggCarry ✅")
    else
        say("⚠ ไม่เจอ FieldEggCarry — ขโมยไข่หลังกด START เท่านั้น")
    end
end

local function walkTo(pos, sec)
    local h, r = hum(), hrp()
    if not h or not r then return false end
    local goal = Vector3.new(pos.X, r.Position.Y, pos.Z)
    say(string.format("เดิน → %.0f,%.0f,%.0f", goal.X, goal.Y, goal.Z))
    h:MoveTo(goal)
    local t0 = os.clock()
    while RUN and os.clock() - t0 < (sec or 12) do
        r = hrp()
        if not r then break end
        if dist2(r.Position, goal) < 10 then return true end
        if os.clock() - t0 > 2 and math.floor(os.clock() - t0) % 2 == 0 then
            h:MoveTo(goal)
        end
        task.wait(0.2)
    end
    return false
end

local function hopHome()
    local r = hrp()
    if not r or not HOME then return false end
    local d = dist2(r.Position, HOME)
    if d <= HOME_R then return true end
    local flat = Vector3.new(HOME.X - r.Position.X, 0, HOME.Z - r.Position.Z)
    local step = math.min(HOP, math.max(50, d - HOME_R * 0.5))
    local dest = r.Position + flat.Unit * step
    walkTo(dest, 14)
    return false
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
    local want = tostring(areaName):lower()
    local hit = guards:FindFirstChild(areaName)
    if hit then return hit end
    for _, c in ipairs(guards:GetChildren()) do
        local n = c.Name:lower()
        if n == want or n:find(want, 1, true) or want:find(n, 1, true) then
            return c
        end
    end
    return nil
end

local function getSafeZone()
    local areas = workspace:FindFirstChild("__OBJECTS")
    areas = areas and areas:FindFirstChild("Areas")
    local eggBounds = areas and areas:FindFirstChild("EggCarryBounds")
    local safe = eggBounds and eggBounds:FindFirstChild("SafeZone")
    if safe and safe:IsA("BasePart") then return safe end
    return nil
end

local function inSafeZone()
    local r = hrp()
    local safe = getSafeZone()
    if not r or not safe then return false end
    return inBox(safe.CFrame, safe.Size + Vector3.new(10, 40, 10), r.Position)
end

-- ทิ้งได้เมื่อออกจากโซนสีที่ขโมยไข่มาแล้วเท่านั้น
-- padXZ ใหญ่ = ต้องออกไกลกว่า (กันยืนขอบแล้วเซิร์ฟดึงกลับ)
local function isDropSafe(padXZ)
    padXZ = padXZ or 16
    local r = hrp()
    if not r then return false, "no-hrp" end
    if not eggArea then
        return true, "no-AreaId"
    end
    local biome = findGuardBiome(eggArea)
    if not biome then
        say("⚠ ไม่เจอ GuardAreas." .. tostring(eggArea) .. " — ใช้ระยะบ้านสำรอง")
        if HOME and dist2(r.Position, HOME) < 250 then return true, "nearHome" end
        return false, "no-biome-model"
    end
    local ok, cf, size = pcall(function()
        return biome:GetBoundingBox()
    end)
    if not ok or not cf then return false, "bbox-fail" end
    local big = size + Vector3.new(padXZ, 60, padXZ)
    if inBox(cf, big, r.Position) then
        return false, "ยังในโซนสี " .. biome.Name
    end
    return true, "ออกจากโซน " .. biome.Name
end

-- ใกล้บ้าน/อยู่ในเขตปลอดภัย = รอบสุดท้าย วิ่งเข้า HOME เลย ไม่ทิ้ง
local function isFinalStretch()
    local r = hrp()
    if not r or not HOME then return false end
    if inSafeZone() then return true, "เขตปลอดภัย" end
    if dist2(r.Position, HOME) <= math.max(HOME_R * 2.5, 150) then
        return true, "ใกล้ HOME"
    end
    return false
end

-- จุดนอก GuardAreas ทิศบ้าน (เผื่อขอบ)
local function exitPosOutsideBiome()
    local r = hrp()
    if not r or not HOME or not eggArea then return nil end
    local biome = findGuardBiome(eggArea)
    if not biome then return nil end
    local ok, cf, size = pcall(function()
        return biome:GetBoundingBox()
    end)
    if not ok or not cf then return nil end
    local flat = Vector3.new(HOME.X - r.Position.X, 0, HOME.Z - r.Position.Z)
    if flat.Magnitude < 1 then return nil end
    local dir = flat.Unit
    local pad = size + Vector3.new(EXIT_PAD, 60, EXIT_PAD)
    local pos = r.Position
    for _ = 1, 80 do
        pos = pos + dir * 20
        if not inBox(cf, pad, pos) then
            return Vector3.new(pos.X, r.Position.Y + 3, pos.Z) + dir * 25
        end
    end
    local half = math.max(size.X, size.Z) * 0.5 + EXIT_PAD + 40
    local c = cf.Position
    return Vector3.new(c.X, r.Position.Y + 3, c.Z) + dir * half
end

-- โซนแรก: วาปสั้นทีละก้าวออกนอกสีโซน (ไม่ใช้ BV — จาก log ทำให้หลุดไข่)
local function exitFirstZone()
    local r, h = hrp(), hum()
    if not r or not h or not HOME or not eggArea then return false end
    if isDropSafe(EXIT_PAD) then
        firstExitDone = true
        firstDropPending = true
        return true
    end
    local dest = exitPosOutsideBiome()
    if not dest then
        say("⚠ หาจุดออกโซน " .. tostring(eggArea) .. " ไม่ได้")
        return false
    end
    local startPos = r.Position
    local need = (Vector3.new(dest.X, 0, dest.Z) - Vector3.new(startPos.X, 0, startPos.Z)).Magnitude
    say(string.format("โซนแรก — วาปสั้นออก %s ~%.0f studs แล้วทิ้ง", tostring(eggArea), need))

    local flat = Vector3.new(dest.X - startPos.X, 0, dest.Z - startPos.Z)
    if flat.Magnitude < 1 then return false end
    local dir = flat.Unit
    local total = flat.Magnitude
    local stepped = 0
    local y = startPos.Y + 2

    while RUN and isCarry() and stepped < total do
        stepped = math.min(stepped + EXIT_HOP, total)
        local p = Vector3.new(startPos.X, y, startPos.Z) + dir * stepped
        r = hrp()
        if not r then break end
        pcall(function()
            r.CFrame = CFrame.new(p)
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.12)
        if isDropSafe(EXIT_PAD) then
            -- ก้าวสุดท้ายนอกโซนแล้ว
            stepped = total
            break
        end
    end

    -- หยุดนิ่งซิงค์
    r = hrp()
    if r then
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
        end)
    end
    task.wait(0.4)

    local moved = 0
    r = hrp()
    if r then
        moved = (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(startPos.X, 0, startPos.Z)).Magnitude
    end

    if not isCarry() then
        say(string.format("วาป %.0f studs แล้วหลุดไข่ — รอเก็บแล้วลองใหม่", moved))
        return false
    end

    local ok = isDropSafe(20)
    say(string.format("วาปจบ: %.0f studs%s", moved, ok and " ✓พ้นโซน→ทิ้ง" or " ✗ยังในโซน"))

    if ok then
        firstExitDone = true
        firstDropPending = true
        return true
    end
    return false
end

local function doDrop()
    if not isCarry() then return true end
    local g = PG:FindFirstChild("DropHeldEgg")
    local b = g and g:FindFirstChildWhichIsA("GuiButton", true)
    say("ทิ้งไข่…")
    if b and getconnections then
        for _, sig in ipairs({ b.Activated, b.MouseButton1Click }) do
            pcall(function()
                for _, c in ipairs(getconnections(sig)) do
                    pcall(function()
                        if c.Function then c.Function() end
                    end)
                end
            end)
        end
    end
    if b and firesignal then
        pcall(function() firesignal(b.Activated) end)
    end
    local t0 = os.clock()
    while RUN and os.clock() - t0 < 15 do
        if not isCarry() then
            say("ทิ้งแล้ว ✅")
            return true
        end
        lab.Text = string.format("กดปุ่มทิ้งกลางจอ! (%.0f)", 15 - (os.clock() - t0))
        task.wait(0.2)
    end
    return not isCarry()
end

local function doSteal()
    if isCarry() then return true end
    if not fp then
        say("ไม่มี fireproximityprompt — เก็บมือ")
        local t0 = os.clock()
        while RUN and os.clock() - t0 < 20 do
            if isCarry() then return true end
            task.wait(0.3)
        end
        return isCarry()
    end
    local t0 = os.clock()
    while RUN and os.clock() - t0 < 12 do
        if isCarry() then return true end
        local r = hrp()
        if r then
            local best, bestD
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local a = tostring(d.ActionText):lower()
                    if a:find("steal") then
                        local p = d.Parent
                        local part = p and (p:IsA("BasePart") and p or p:FindFirstChildWhichIsA("BasePart", true))
                        if part then
                            local dd = (part.Position - r.Position).Magnitude
                            if dd < 35 and (not bestD or dd < bestD) then
                                best, bestD = d, dd
                            end
                        end
                    end
                end
            end
            if best then
                say(string.format("เก็บไข่ d=%.0f", bestD))
                local old = best.HoldDuration
                best.HoldDuration = 0
                pcall(fp, best)
                best.HoldDuration = old
            end
        end
        task.wait(0.4)
    end
    return isCarry()
end

-- ทิ้งทันทีหลังพ้นโซนแรก แล้วเก็บขึ้นใหม่
local function dropThenPick(why)
    say(tostring(why or "ทิ้งได้") .. " — ทิ้งเลย")
    local r, h = hrp(), hum()
    if h and r then h:MoveTo(r.Position) end
    task.wait(0.15)
    if not doDrop() then
        say("ทิ้งไม่สำเร็จ")
        return false
    end
    say(string.format("รอ %.0f วิ…", WAIT_DROP))
    task.wait(WAIT_DROP)
    if not RUN then return true end
    if not doSteal() then
        say("เก็บไข่จุดทิ้ง…")
        local t1 = os.clock()
        while RUN and os.clock() - t1 < 25 and not isCarry() do
            lab.Text = "เก็บไข่จุดทิ้ง…"
            task.wait(0.3)
        end
    end
    return true
end

local function loop()
    carrying = false
    carryUid = nil
    say("รอขโมยไข่ (ต้องเห็น 'server: ถือไข่แล้ว')…")
    while RUN and not isCarry() do
        lab.Text = "รอขโมยไข่…"
        task.wait(0.25)
    end
    if not RUN then return end

    while RUN do
        local r = hrp()
        if not r or not HOME then break end
        local d = dist2(r.Position, HOME)
        if isCarry() and d > START_AWAY then
            say(string.format("ห่างบ้าน %.0f — เริ่มกลับ", d))
            break
        end
        lab.Text = string.format("ไปให้ห่างบ้าน… ถือ=%s d=%.0f (ต้องการ >%.0f)",
            isCarry() and "Y" or "N", d, START_AWAY)
        task.wait(0.3)
    end
    if not RUN then return end
    if not isCarry() then
        say("หลุดไข่ก่อนเริ่ม — หยุด")
        return
    end

    while RUN do
        local r = hrp()
        if r then
            local d = dist2(r.Position, HOME)

            if isCarry() and d <= HOME_R then
                say("ถึงบ้านแล้ว — จบ (วางคอกเอง)")
                break
            end

            if not isCarry() then
                say("รอถือไข่…")
                while RUN and not isCarry() do task.wait(0.25) end
                if not RUN then break end
            end

            -- รอบสุดท้าย: เขตปลอดภัย / ใกล้ HOME → วิ่งเข้าจุดที่บันทึกเลย ไม่ทิ้ง
            local fin, finWhy = isFinalStretch()
            if isCarry() and fin then
                say(tostring(finWhy) .. " — วิ่งเข้าบ้านเลย")
                walkTo(HOME, 20)
                if isCarry() then
                    say("ถึงบ้านแล้ว — จบ (วางคอกเอง)")
                    break
                end
            end

            -- โซนแรก: ผลักช้า → พ้นแล้วทิ้งทันที (ไม่ hop ก่อน)
            fin = isFinalStretch()
            if isCarry() and not firstExitDone and not fin then
                local safe = isDropSafe(20)
                if not safe then
                    exitFirstZone()
                else
                    firstExitDone = true
                    firstDropPending = true
                end
            end

            if firstDropPending and isCarry() then
                task.wait(0.2)
                local safe, why = isDropSafe(16)
                if safe then
                    firstDropPending = false
                    if not dropThenPick(why) then
                        say("ทิ้งรอบแรกไม่สำเร็จ — หยุด")
                        break
                    end
                else
                    say("พ้นโซนแล้วถูกดึงกลับ — ออกใหม่")
                    firstExitDone = false
                    firstDropPending = false
                end
            elseif firstExitDone then
                if hopHome() then
                    if isCarry() then
                        say("ถึงบ้านแล้ว — จบ")
                        break
                    end
                end

                r = hrp()
                d = r and HOME and dist2(r.Position, HOME) or 9999
                fin = isFinalStretch()
                if isCarry() and d > HOME_R and not fin then
                    local safe, why = isDropSafe()
                    if not safe then
                        say(tostring(why) .. " — เดินออกจากสีโซนก่อนค่อยทิ้ง")
                    else
                        if not dropThenPick(why) then
                            say("ทิ้งไม่สำเร็จ — หยุด")
                            break
                        end
                    end
                end
            end
        else
            task.wait(0.5)
        end
    end

    RUN = false
    bStart.Text = "START"
end

-- ปุ่ม
bHome.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then
        say("ยังไม่มีตัวละคร")
        return
    end
    HOME = r.Position
    say(string.format("HOME = %.0f, %.0f, %.0f", HOME.X, HOME.Y, HOME.Z))
    bHome.Text = "OK!"
    task.delay(1, function() if bHome.Parent then bHome.Text = "HOME" end end)
end)

bStart.MouseButton1Click:Connect(function()
    if RUN then return end
    if not HOME then
        local r = hrp()
        if not r then say("กด HOME ก่อน"); return end
        HOME = r.Position
        say(string.format("HOME อัตโนมัติ = %.0f, %.0f, %.0f", HOME.X, HOME.Y, HOME.Z))
    end
    carrying = false
    carryUid = nil
    eggArea = nil
    firstExitDone = false
    firstDropPending = false
    RUN = true
    bStart.Text = "..."
    say("START — ไปขโมยไข่ใหม่หลังกด")
    task.spawn(loop)
end)

bStop.MouseButton1Click:Connect(function()
    RUN = false
    bStart.Text = "START"
    say("หยุด")
end)

bCopy.MouseButton1Click:Connect(function()
    local t = "=== Egg01 Auto v2.8 ===\n" .. table.concat(lines, "\n")
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, t) end
    bCopy.Text = "OK"
    task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)

bClose.MouseButton1Click:Connect(function()
    RUN = false
    for _, c in ipairs(_G.EGG01_V2.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    _G.EGG01_V2 = nil
end)

say("Egg01 Auto v2.8 พร้อม (วาปสั้นออกโซน+ทิ้ง)")
say("ทิ้งทีละโซนสี | เขตปลอดภัย→วิ่งเข้า HOME เลย")
say("HOME → START → ค่อยขโมยไข่")
