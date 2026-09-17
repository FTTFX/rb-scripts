-- Egg01_Auto.lua v1.0 — Steal An Egg: ถือไข่แล้ววาร์ปทีละช่วง → ทิ้ง → รอ → เก็บ → ถึงบ้านจบ
-- วิธีใช้:
--   1) ยืนจุดเกิด → กด START (จำ HOME)
--   2) ไปขโมยไข่เอง
--   3) พอถือไข่ ระบบวาร์ปเข้าหา HOME ทีละก้าว → DROP → รอ 2วิ → Steal อัตโนมัติ → ซ้ำ
--   4) ใกล้ HOME แล้วถือไข่ = จบ (วางคอกเอง)
if _G.EGG01AUTO_GUI then pcall(function() _G.EGG01AUTO_GUI:Destroy() end) end
if _G.EGG01AUTO_CONNS then
    for _, c in pairs(_G.EGG01AUTO_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.EGG01AUTO_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local HOME = nil
local running = false
local carrying = false
local carryUid = nil
local hopStuds = 160
local dropWait = 2.0
local homeRadius = 55
local OUT, T0 = {}, os.clock()

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01Auto"; gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01AUTO_GUI = gui

local bar = Instance.new("Frame", gui)
bar.Size = UDim2.new(0, 360, 0, 34)
bar.Position = UDim2.new(1, -368, 0, 8)
bar.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
bar.BackgroundTransparency = 0.15
bar.BorderSizePixel = 0

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 420, 0, 160)
box.Position = UDim2.new(0, 8, 1, -168)
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(200, 255, 200)
box.TextSize = 12
box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true
box.MultiLine = true
box.ClearTextOnFocus = false
box.TextEditable = false
box.Active = false

local status = Instance.new("TextLabel", gui)
status.Size = UDim2.new(0, 360, 0, 22)
status.Position = UDim2.new(1, -368, 0, 44)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 230, 120)
status.Font = Enum.Font.GothamBold
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Right
status.Text = "IDLE"

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    OUT[#OUT + 1] = ("[%5.1f] %s"):format(os.clock() - T0, s)
    if #OUT > 80 then table.remove(OUT, 1) end
    redraw()
end
local function setStatus(s)
    status.Text = s
end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", bar)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, 3)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.BackgroundColor3 = col or Color3.fromRGB(40, 100, 60)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    return b
end
local startB = hbtn("START", 4, 70, Color3.fromRGB(40, 140, 70))
local stopB  = hbtn("STOP", 76, 60, Color3.fromRGB(140, 50, 50))
local homeB  = hbtn("HOME", 138, 56, Color3.fromRGB(60, 90, 140))
local copyB  = hbtn("COPY", 196, 56)
local closeB = hbtn("✕", 254, 28, Color3.fromRGB(120, 40, 40))
bar.Size = UDim2.new(0, 290, 0, 34)
bar.Position = UDim2.new(1, -298, 0, 8)
status.Size = UDim2.new(0, 290, 0, 22)
status.Position = UDim2.new(1, -298, 0, 44)

local function hrp()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end
local function posStr(p)
    if not p then return "?" end
    return ("%.0f,%.0f,%.0f"):format(p.X, p.Y, p.Z)
end

local function findRemote(substr)
    local net = RS:FindFirstChild("Packages")
    net = net and net:FindFirstChild("Networking")
    if not net then return nil end
    for _, d in ipairs(net:GetDescendants()) do
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Name:find(substr, 1, true) then
            return d
        end
    end
    return nil
end

-- carry state
local function bindCarry()
    local re = findRemote("FieldEggCarry")
    if not re then L("⚠ ไม่เจอ FieldEggCarry") return end
    table.insert(_G.EGG01AUTO_CONNS, re.OnClientEvent:Connect(function(tbl)
        if typeof(tbl) ~= "table" then return end
        if tbl.IsCarrying == true then
            carrying = true
            carryUid = tbl.Uid
        elseif tbl.IsCarrying == false then
            carrying = false
        end
    end))
    L("ฟัง FieldEggCarry ✅")
end
bindCarry()

local function warpTo(pos)
    local r = hrp()
    if not r or not pos then return false end
    local dest = Vector3.new(pos.X, r.Position.Y, pos.Z)
    for _ = 1, 3 do
        r.CFrame = CFrame.new(dest)
        r.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.05)
    end
    return true
end

local function hopTowardHome()
    local r = hrp()
    if not r or not HOME then return false end
    local me = r.Position
    local to = HOME - me
    local flat = Vector3.new(to.X, 0, to.Z)
    local dist = flat.Magnitude
    if dist <= homeRadius then
        return false, dist
    end
    local step = math.min(hopStuds, dist - (homeRadius * 0.5))
    if step < 20 then step = dist end
    local dir = flat.Unit
    local dest = me + dir * step
    L(("วาป hop %.0f studs → %s (เหลือ %.0f)"):format(step, posStr(dest), dist - step))
    warpTo(dest)
    return true, (HOME - hrp().Position).Magnitude
end

local function doDrop()
    local dropGui = PG:FindFirstChild("DropHeldEgg")
    local btn = dropGui and (dropGui:FindFirstChild("Button", true)
        or dropGui:FindFirstChildWhichIsA("GuiButton", true))
    if not btn then
        L("❌ ไม่มีปุ่ม DropHeldEgg")
        return false
    end
    local r = hrp()
    L("DROP @" .. posStr(r and r.Position))
    pcall(function()
        if firesignal then firesignal(btn.Activated) end
    end)
    pcall(function() btn.Activated:Fire() end)
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(btn.Activated)) do
                pcall(function() c:Fire() end)
            end
        end
    end)
    -- รอ carry off
    local t0 = os.clock()
    while carrying and os.clock() - t0 < 2 do task.wait(0.05) end
    return not carrying
end

local function nearestSteal(maxDist)
    maxDist = maxDist or 25
    local r = hrp()
    if not r then return nil end
    local best, bestD
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local act = tostring(d.ActionText):lower()
            local par = d.Parent
            if act:find("steal") or (par and par.Name:find("CarryAreaEgg")) then
                local part = par and (par:IsA("BasePart") and par
                    or par:FindFirstChildWhichIsA("BasePart", true))
                if part then
                    local dist = (part.Position - r.Position).Magnitude
                    if dist <= maxDist and (not bestD or dist < bestD) then
                        best, bestD = d, dist
                    end
                end
            end
        end
    end
    return best, bestD
end

local function doSteal()
    if not fp then
        L("❌ ไม่มี fireproximityprompt")
        return false
    end
    local t0 = os.clock()
    while running and not carrying and os.clock() - t0 < 8 do
        local pp, dist = nearestSteal(30)
        if pp then
            local orig = pp.HoldDuration
            pp.HoldDuration = 0
            L(("STEAL d=%.0f"):format(dist or -1))
            pcall(fp, pp)
            task.wait(0.05)
            pp.HoldDuration = orig
        end
        task.wait(0.25)
    end
    return carrying
end

local function nearHome()
    local r = hrp()
    if not r or not HOME then return false, -1 end
    local d = (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(HOME.X, 0, HOME.Z)).Magnitude
    return d <= homeRadius, d
end

local function mainLoop()
    setStatus("รอถือไข่…")
    L("รอคุณขโมยไข่เอง…")
    while running and not carrying do
        task.wait(0.2)
    end
    if not running then return end
    L("ถือไข่แล้ว — เริ่ม hop → HOME @" .. posStr(HOME))

    while running do
        local atHome, dHome = nearHome()
        if atHome and carrying then
            setStatus("จบ ✅ ที่บ้าน")
            L(("ถึงจุดเกิด (d=%.0f) — จบลูป วางคอกเองได้"):format(dHome))
            running = false
            startB.Text = "START"
            break
        end

        setStatus(("วาป→บ้าน d=%.0f"):format(dHome or -1))
        local hopped = hopTowardHome()
        task.wait(0.15)

        atHome, dHome = nearHome()
        if atHome and carrying then
            setStatus("จบ ✅ ที่บ้าน")
            L("ถึงจุดเกิดหลังวาป — จบลูป")
            running = false
            startB.Text = "START"
            break
        end

        if not carrying then
            setStatus("รอถือไข่…")
            while running and not carrying do task.wait(0.2) end
            if not running then break end
        end

        setStatus("DROP")
        if not doDrop() then
            L("DROP ไม่สำเร็จ — รอ 1วิ ลองต่อ")
            task.wait(1)
        end

        setStatus(("รอ %.1fs"):format(dropWait))
        L(("นับถอยหลัง %.1f วิ…"):format(dropWait))
        local w0 = os.clock()
        while running and os.clock() - w0 < dropWait do
            setStatus(("รอ %.1fs"):format(math.max(0, dropWait - (os.clock() - w0))))
            task.wait(0.1)
        end
        if not running then break end

        setStatus("STEAL")
        if not doSteal() then
            L("เก็บไม่ทัน — ขยายรัศมี / รอ")
            task.wait(0.5)
            doSteal()
        end
        if carrying then
            L("เก็บสำเร็จ uid=" .. tostring(carryUid))
        else
            L("⚠ ยังไม่ถือ — จะวาปต่อถ้าเริ่มถือได้")
            while running and not carrying do task.wait(0.25) end
        end
    end
    if not running and status.Text:find("จบ") == nil then
        setStatus("หยุด")
    end
end

homeB.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then return end
    HOME = r.Position
    L("🏠 HOME = " .. posStr(HOME))
end)

startB.MouseButton1Click:Connect(function()
    if running then return end
    local r = hrp()
    if not r then return end
    if not HOME then
        HOME = r.Position
        L("🏠 AUTO HOME (จุดกด START) = " .. posStr(HOME))
    end
    running = true
    startB.Text = "…"
    T0 = os.clock()
    task.spawn(mainLoop)
end)

stopB.MouseButton1Click:Connect(function()
    running = false
    startB.Text = "START"
    setStatus("หยุด")
    L("STOP")
end)

copyB.MouseButton1Click:Connect(function()
    local text = ("=== Egg01 Auto ===\nTime: %s\nHome: %s\n\n%s")
        :format(os.date("%Y-%m-%d %H:%M:%S"), posStr(HOME), table.concat(OUT, "\n"))
    local clip = setclipboard or toclipboard
    local ok = clip and pcall(clip, text)
    copyB.Text = ok and "OK!" or "?"
    task.delay(1, function() if copyB.Parent then copyB.Text = "COPY" end end)
end)

closeB.MouseButton1Click:Connect(function()
    running = false
    if _G.EGG01AUTO_CONNS then
        for _, c in pairs(_G.EGG01AUTO_CONNS) do pcall(function() c:Disconnect() end) end
    end
    gui:Destroy(); _G.EGG01AUTO_GUI = nil
end)

L("Egg01 Auto v1.0 | hop=" .. hopStuds .. " wait=" .. dropWait .. "s")
L("ยืนจุดเกิด → START → ไปขโมยไข่เอง → ถือแล้วระบบทำต่อ")
setStatus("IDLE — กด START ที่จุดเกิด")
