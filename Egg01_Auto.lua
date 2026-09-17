-- Egg01_Auto.lua v1.2 — ถือไข่ → เดินเข้าหา HOME ทีละช่วง → ทิ้ง → รอ → เก็บ → ถึงบ้านจบ
-- v1.2: เลิกวาป CFrame / VIM / PivotTo (BAC) — ใช้ Humanoid:MoveTo อย่างเดียว
-- วิธีใช้: ยืนจุดเกิด → HOME → START → ไปขโมยไข่เอง → ถือแล้วระบบเดิน+ทิ้ง+เก็บ
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
local fsig = firesignal or (getgenv and getgenv().firesignal)

local HOME = nil
local running = false
local carrying = false
local carryUid = nil
local hopStuds = 140
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
bar.Size = UDim2.new(0, 290, 0, 34)
bar.Position = UDim2.new(1, -298, 0, 8)
bar.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
bar.BackgroundTransparency = 0.15
bar.BorderSizePixel = 0

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 440, 0, 180)
box.Position = UDim2.new(0, 8, 1, -188)
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.15
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
status.Size = UDim2.new(0, 290, 0, 22)
status.Position = UDim2.new(1, -298, 0, 44)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 230, 120)
status.Font = Enum.Font.GothamBold
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Right
status.Text = "IDLE"

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    OUT[#OUT + 1] = ("[%5.1f] %s"):format(os.clock() - T0, s)
    if #OUT > 100 then table.remove(OUT, 1) end
    redraw()
end
local function setStatus(s) status.Text = s end

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

local function hrp()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end
local function hum()
    return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
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
        if d:IsA("RemoteEvent") and d.Name:find(substr, 1, true) then
            return d
        end
    end
    return nil
end

local function syncCarry()
    carrying = PG:FindFirstChild("DropHeldEgg") ~= nil
    return carrying
end

local function bindCarry()
    local re = findRemote("FieldEggCarry")
    if re then
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
    table.insert(_G.EGG01AUTO_CONNS, PG.ChildAdded:Connect(function(ch)
        if ch.Name == "DropHeldEgg" then carrying = true L("ถือไข่แล้ว") end
    end))
    table.insert(_G.EGG01AUTO_CONNS, PG.ChildRemoved:Connect(function(ch)
        if ch.Name == "DropHeldEgg" then carrying = false L("วาง/ทิ้งไข่แล้ว") end
    end))
    syncCarry()
    L("ถือตอนนี้: " .. (carrying and "YES" or "no"))
end
bindCarry()

local function flatDist(a, b)
    if not a or not b then return 1e9 end
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function nearHome()
    local r = hrp()
    if not r or not HOME then return false, -1 end
    local d = flatDist(r.Position, HOME)
    return d <= homeRadius, d
end

-- เดินไปจุด (ไม่วาป)
local function walkTo(dest, timeout)
    local h = hum()
    local r = hrp()
    if not h or not r or not dest then return false end
    local target = Vector3.new(dest.X, r.Position.Y, dest.Z)
    L("เดิน → " .. posStr(target))
    h:MoveTo(target)
    local t0 = os.clock()
    timeout = timeout or 12
    while running and os.clock() - t0 < timeout do
        r = hrp()
        if not r then break end
        if flatDist(r.Position, target) < 8 then
            return true
        end
        -- MoveTo หลุดบ้าง ย้ำ
        if (os.clock() - t0) % 2 < 0.1 then
            h:MoveTo(target)
        end
        task.wait(0.15)
    end
    r = hrp()
    return r and flatDist(r.Position, target) < 20
end

local function hopWalkTowardHome()
    local r = hrp()
    if not r or not HOME then return false, -1 end
    local me = r.Position
    local flat = Vector3.new(HOME.X - me.X, 0, HOME.Z - me.Z)
    local dist = flat.Magnitude
    if dist <= homeRadius then return false, dist end
    local step = math.min(hopStuds, math.max(40, dist - homeRadius * 0.4))
    local dest = me + flat.Unit * step
    setStatus(("เดิน hop %.0f d=%.0f"):format(step, dist))
    walkTo(dest, 15)
    r = hrp()
    return true, r and flatDist(r.Position, HOME) or dist
end

local function getDropButton()
    local g = PG:FindFirstChild("DropHeldEgg")
    if not g then return nil end
    return g:FindFirstChild("Button", true) or g:FindFirstChildWhichIsA("GuiButton", true)
end

-- DROP เบา: firesignal / getconnections เท่านั้น — ไม่กดเมาส์จำลอง
local function doDrop()
    syncCarry()
    local btn = getDropButton()
    if not btn then
        L("❌ ไม่มีปุ่มทิ้ง")
        return false
    end
    L("DROP @" .. posStr(hrp() and hrp().Position))
    pcall(function()
        if fsig then fsig(btn.Activated) end
    end)
    pcall(function()
        if fsig then fsig(btn.MouseButton1Click) end
    end)
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(btn.Activated)) do
                pcall(function()
                    if c.Function then c:Fire() else c:Fire() end
                end)
            end
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                pcall(function() c:Fire() end)
            end
        end
    end)
    local t0 = os.clock()
    while os.clock() - t0 < 2 do
        syncCarry()
        if not carrying then L("DROP OK"); return true end
        task.wait(0.1)
    end
    syncCarry()
    return not carrying
end

local function nearestSteal(maxDist)
    maxDist = maxDist or 35
    local r = hrp()
    if not r then return nil end
    local best, bestD
    -- สแกนเฉพาะใต้โฟลเดอร์ที่เกี่ยวกับไข่ ถ้าเจอ — ลด GetDescendants ทั้งแมพ
    local roots = {}
    local slots = workspace:FindFirstChild("AreaEggSlotsClient")
    if slots then roots[#roots + 1] = slots end
    local objs = workspace:FindFirstChild("__OBJECTS")
    if objs then roots[#roots + 1] = objs end
    if #roots == 0 then roots[1] = workspace end

    local function consider(d)
        if not d:IsA("ProximityPrompt") or not d.Enabled then return end
        local act = tostring(d.ActionText):lower()
        local par = d.Parent
        if not (act:find("steal") or (par and tostring(par.Name):find("CarryAreaEgg"))) then return end
        local part = par:IsA("BasePart") and par or par:FindFirstChildWhichIsA("BasePart", true)
        if not part then return end
        local dist = (part.Position - r.Position).Magnitude
        if dist <= maxDist and (not bestD or dist < bestD) then
            best, bestD = d, dist
        end
    end

    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            consider(d)
        end
    end
    -- fallback: SmartPromptPart ใกล้ๆ
    if not best then
        for _, d in ipairs(workspace:GetChildren()) do
            if d.Name:find("SmartPrompt") or d.Name:find("Carry") then
                for _, x in ipairs(d:GetDescendants()) do consider(x) end
            end
        end
    end
    return best, bestD
end

local function doSteal()
    if not fp then
        L("ไม่มี fp — เก็บมือเอง")
        return false
    end
    local t0 = os.clock()
    while running and os.clock() - t0 < 10 do
        syncCarry()
        if carrying then return true end
        local pp, dist = nearestSteal(40)
        if pp then
            L(("STEAL d=%.0f"):format(dist or -1))
            local orig = pp.HoldDuration
            pcall(function() pp.HoldDuration = 0 end)
            pcall(fp, pp)
            pcall(function() pp.HoldDuration = orig end)
        end
        task.wait(0.35)
    end
    syncCarry()
    return carrying
end

local function waitCarry(msg)
    setStatus(msg or "รอถือไข่…")
    L(msg or "รอถือไข่…")
    while running do
        syncCarry()
        if carrying then L("ถือไข่ ✅"); return true end
        setStatus("รอถือไข่…")
        task.wait(0.25)
    end
    return false
end

local function mainLoop()
    if not waitCarry() then return end
    L("เริ่มเดิน → HOME @" .. posStr(HOME))

    while running do
        syncCarry()
        local atHome, dHome = nearHome()
        L(("carry=%s homeDist=%.0f"):format(tostring(carrying), dHome or -1))

        if atHome and carrying then
            setStatus("จบ ✅ ที่บ้าน")
            L("ถึงจุดเกิด — จบ (วางคอกเอง)")
            break
        end

        if not carrying then
            if not waitCarry("รอถือไข่…") then break end
        end

        hopWalkTowardHome()
        task.wait(0.2)
        syncCarry()

        atHome, dHome = nearHome()
        if atHome and carrying then
            setStatus("จบ ✅ ที่บ้าน")
            L("ถึงบ้าน — จบ")
            break
        end

        if carrying then
            setStatus("DROP")
            hum():MoveTo(hrp().Position) -- หยุดเดินก่อนทิ้ง
            task.wait(0.1)
            if not doDrop() then
                L("DROP ไม่สำเร็จ — รอคุณทิ้งมือ หรือลองต่อ")
                task.wait(1)
            end
        end

        if not running then break end
        local w0 = os.clock()
        while running and os.clock() - w0 < dropWait do
            setStatus(("รอ %.1f"):format(dropWait - (os.clock() - w0)))
            task.wait(0.1)
        end
        if not running then break end

        syncCarry()
        if not carrying then
            setStatus("STEAL")
            if not doSteal() then
                L("เก็บออโต้ไม่ได้ — รอคุณเก็บ")
                waitCarry("รอถือไข่หลังทิ้ง…")
            end
        end
    end

    running = false
    startB.Text = "START"
    if status.Text:find("จบ") == nil then setStatus("หยุด") end
end

homeB.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then return end
    HOME = r.Position
    L("🏠 HOME = " .. posStr(HOME))
    setStatus("HOME OK — กด START")
end)

startB.MouseButton1Click:Connect(function()
    if running then return end
    if not HOME then
        L("❌ กด HOME ที่จุดเกิดก่อน")
        setStatus("ต้อง HOME ก่อน")
        return
    end
    syncCarry()
    running = true
    startB.Text = "…"
    T0 = os.clock()
    L("START v1.2 walk-only (ไม่วาป)")
    task.spawn(mainLoop)
end)

stopB.MouseButton1Click:Connect(function()
    running = false
    startB.Text = "START"
    setStatus("หยุด")
    local h = hum()
    if h and hrp() then pcall(function() h:MoveTo(hrp().Position) end) end
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

task.spawn(function()
    while gui.Parent do
        if not running then
            syncCarry()
            setStatus(("IDLE | HOME=%s | ถือ=%s"):format(HOME and "OK" or "?", carrying and "YES" or "no"))
        end
        task.wait(0.6)
    end
end)

L("Egg01 Auto v1.2 | เดินอย่างเดียว ไม่วาป")
L("รีจอยก่อน → HOME → START → ขโมยไข่เอง")
setStatus("กด HOME ที่จุดเกิด")
