-- Egg01_Auto.lua v2.0 — เขียนใหม่ทั้งหมด
-- ลูป: คุณขโมยไข่เอง → เดินเข้าหา HOME ทีละช่วง → ทิ้ง → รอ 2วิ → เก็บ → ซ้ำจนถึงบ้าน
-- ไม่วาป (กัน BAC)
--
-- ใช้: ยืนจุดเกิด → กด HOME → START → ไปขโมยไข่ให้ห่างบ้าน
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
local lines = {}

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

-- ถือไข่ไหม = มีปุ่มทิ้งโชว์
local function isCarry()
    local g = PG:FindFirstChild("DropHeldEgg")
    if not g then return false end
    local b = g:FindFirstChildWhichIsA("GuiButton", true)
    if not b then return false end
    if not b.Visible then return false end
    if b.AbsoluteSize.X < 5 then return false end
    return true
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

-- ฟัง carry จาก server (เสริม)
do
    local re = findNet("FieldEggCarry")
    if re and re:IsA("RemoteEvent") then
        table.insert(_G.EGG01_V2.conns, re.OnClientEvent:Connect(function(t)
            if typeof(t) == "table" and t.IsCarrying == false then
                -- ไม่บังคับ false จาก RE อย่างเดียว ใช้ GUI เป็นหลัก
            end
        end))
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
    -- รอหลุด หรือให้ผู้ใช้กดเอง
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

local function loop()
    say("รอถือไข่…")
    while RUN and not isCarry() do task.wait(0.25) end
    if not RUN then return end

    -- ต้องห่างบ้านก่อน
    while RUN do
        local r = hrp()
        if not r or not HOME then break end
        local d = dist2(r.Position, HOME)
        if isCarry() and d > HOME_R + 40 then
            say(string.format("ห่างบ้าน %.0f — เริ่มกลับ", d))
            break
        end
        lab.Text = string.format("ไปขโมยไข่… ถือ=%s d=%.0f", isCarry() and "Y" or "N", d)
        task.wait(0.3)
    end
    if not RUN then return end

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

            if hopHome() then
                if isCarry() then
                    say("ถึงบ้านแล้ว — จบ")
                    break
                end
            end

            r = hrp()
            d = r and HOME and dist2(r.Position, HOME) or 9999
            if isCarry() and d > HOME_R then
                local h = hum()
                if h and r then h:MoveTo(r.Position) end
                task.wait(0.2)
                if doDrop() then
                    say(string.format("รอ %.0f วิ…", WAIT_DROP))
                    task.wait(WAIT_DROP)
                    if RUN then doSteal() end
                else
                    say("ทิ้งไม่สำเร็จ — หยุด")
                    break
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
    RUN = true
    bStart.Text = "..."
    task.spawn(loop)
end)

bStop.MouseButton1Click:Connect(function()
    RUN = false
    bStart.Text = "START"
    say("หยุด")
end)

bCopy.MouseButton1Click:Connect(function()
    local t = "=== Egg01 Auto v2 ===\n" .. table.concat(lines, "\n")
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

say("Egg01 Auto v2.0 พร้อม")
say("1) HOME ที่จุดเกิด  2) START  3) ไปขโมยไข่")
