-- Egg01_Auto.lua v1.1 — ถือไข่ → วาปทีละช่วง → ทิ้ง → รอ 2วิ → เก็บ → ถึง HOME จบ
-- v1.1: ตรวจถือไข่จาก PG.DropHeldEgg (ไม่พึ่งแค่ RE) + DROP หลายวิธี + บังคับกด HOME ก่อน
-- วิธีใช้: ยืนจุดเกิด → กด HOME → START → ไปขโมยไข่เอง → ถือแล้วระบบทำต่อ
if _G.EGG01AUTO_GUI then pcall(function() _G.EGG01AUTO_GUI:Destroy() end) end
if _G.EGG01AUTO_CONNS then
    for _, c in pairs(_G.EGG01AUTO_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.EGG01AUTO_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local fsig = firesignal or (getgenv and getgenv().firesignal)

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

-- ★ ถือไข่ = มี PG.DropHeldEgg (ชัวร์สุดจาก spy)
local function syncCarry()
    local g = PG:FindFirstChild("DropHeldEgg")
    carrying = g ~= nil
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
                L("RE: CARRY on")
            elseif tbl.IsCarrying == false then
                carrying = false
                L("RE: CARRY off")
            end
        end))
        L("ฟัง FieldEggCarry ✅")
    else
        L("⚠ ไม่เจอ FieldEggCarry — ใช้แค่ DropHeldEgg GUI")
    end
    table.insert(_G.EGG01AUTO_CONNS, PG.ChildAdded:Connect(function(ch)
        if ch.Name == "DropHeldEgg" then
            carrying = true
            L("GUI: DropHeldEgg โผล่ = ถือไข่")
        end
    end))
    table.insert(_G.EGG01AUTO_CONNS, PG.ChildRemoved:Connect(function(ch)
        if ch.Name == "DropHeldEgg" then
            carrying = false
            L("GUI: DropHeldEgg หาย = ไม่ถือ")
        end
    end))
    syncCarry()
    L("ถือไข่ตอนนี้: " .. (carrying and "YES ✅" or "NO"))
end
bindCarry()

local function fireGuiButton(btn)
    if not btn then return false end
    local ok = false
    pcall(function()
        if fsig then fsig(btn.Activated); ok = true end
    end)
    pcall(function()
        if fsig then fsig(btn.MouseButton1Click); ok = true end
    end)
    pcall(function()
        if getconnections then
            for _, sigName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
                local sig = btn[sigName]
                if sig then
                    for _, c in ipairs(getconnections(sig)) do
                        pcall(function()
                            if c.Function then c.Function() end
                            c:Fire()
                        end)
                        ok = true
                    end
                end
            end
        end
    end)
    -- คลิกพิกัดปุ่ม
    pcall(function()
        local p = btn.AbsolutePosition
        local s = btn.AbsoluteSize
        local x = p.X + s.X / 2
        local y = p.Y + s.Y / 2 + 36 -- inset ประมาณ
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
        ok = true
    end)
    return ok
end

local function warpTo(pos)
    local r = hrp()
    if not r or not pos then return false end
    local dest = Vector3.new(pos.X, r.Position.Y, pos.Z)
    local cf = CFrame.new(dest)
    for _ = 1, 4 do
        pcall(function() r.CFrame = cf end)
        pcall(function()
            if r.Parent and r.Parent.PrimaryPart then
                r.Parent:PivotTo(cf)
            end
        end)
        r.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.06)
    end
    local now = hrp()
    local d = now and (Vector3.new(now.Position.X, 0, now.Position.Z) - Vector3.new(dest.X, 0, dest.Z)).Magnitude or 999
    L(("วาปถึง %s err=%.0f"):format(posStr(dest), d))
    return d < 40
end

local function hopTowardHome()
    local r = hrp()
    if not r or not HOME then return false, -1 end
    local me = r.Position
    local flat = Vector3.new(HOME.X - me.X, 0, HOME.Z - me.Z)
    local dist = flat.Magnitude
    if dist <= homeRadius then return false, dist end
    local step = math.min(hopStuds, math.max(30, dist - homeRadius * 0.4))
    local dest = me + flat.Unit * step
    L(("hop %.0f → %s (บ้านเหลือ %.0f)"):format(step, posStr(dest), dist - step))
    warpTo(dest)
    local r2 = hrp()
    local left = r2 and (Vector3.new(HOME.X - r2.Position.X, 0, HOME.Z - r2.Position.Z)).Magnitude or dist
    return true, left
end

local function getDropButton()
    local dropGui = PG:FindFirstChild("DropHeldEgg")
    if not dropGui then return nil end
    return dropGui:FindFirstChild("Button", true)
        or dropGui:FindFirstChildWhichIsA("GuiButton", true)
end

local function doDrop()
    syncCarry()
    local btn = getDropButton()
    if not btn then
        L("❌ ไม่มี DropHeldEgg — ไม่ได้ถือไข่?")
        return false
    end
    L("DROP @" .. posStr(hrp() and hrp().Position))
    fireGuiButton(btn)
    local t0 = os.clock()
    while os.clock() - t0 < 2.5 do
        syncCarry()
        if not carrying then
            L("DROP สำเร็จ")
            return true
        end
        task.wait(0.1)
    end
    -- ลองอีกรอบ
    L("DROP ยังไม่หลุด — ลองอีกรอบ")
    fireGuiButton(getDropButton())
    task.wait(0.8)
    syncCarry()
    return not carrying
end

local function nearestSteal(maxDist)
    maxDist = maxDist or 35
    local r = hrp()
    if not r then return nil end
    local best, bestD
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local act = tostring(d.ActionText):lower()
            local par = d.Parent
            if act:find("steal") or (par and tostring(par.Name):find("CarryAreaEgg")) then
                local part = par:IsA("BasePart") and par or par:FindFirstChildWhichIsA("BasePart", true)
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
    local t0 = os.clock()
    while running and os.clock() - t0 < 10 do
        syncCarry()
        if carrying then return true end
        local pp, dist = nearestSteal(40)
        if pp then
            L(("STEAL d=%.0f hold0+fp"):format(dist or -1))
            local orig = pp.HoldDuration
            pcall(function() pp.HoldDuration = 0 end)
            if fp then
                pcall(fp, pp)
            end
            if fsig then
                pcall(fsig, pp.Triggered, pp, LP)
            end
            pcall(function() pp:InputHoldBegin() end)
            task.wait(0.05)
            pcall(function() pp:InputHoldEnd() end)
            pcall(function() pp.HoldDuration = orig end)
        else
            L("ไม่เจอ Steal prompt ใกล้ๆ")
        end
        task.wait(0.3)
        syncCarry()
    end
    return carrying
end

local function nearHome()
    local r = hrp()
    if not r or not HOME then return false, -1 end
    local d = (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(HOME.X, 0, HOME.Z)).Magnitude
    return d <= homeRadius, d
end

local function waitCarry(msg)
    setStatus(msg or "รอถือไข่…")
    L(msg or "รอถือไข่… (ดูปุ่มทิ้งกลางจอ)")
    while running do
        syncCarry()
        if carrying then
            L("ตรวจถือไข่แล้ว ✅")
            return true
        end
        setStatus("รอถือไข่… GUI=" .. (PG:FindFirstChild("DropHeldEgg") and "มี" or "ไม่มี"))
        task.wait(0.2)
    end
    return false
end

local function mainLoop()
    if not waitCarry() then return end
    L("เริ่มลูป → HOME @" .. posStr(HOME))

    while running do
        syncCarry()
        local atHome, dHome = nearHome()
        L(("สถานะ carry=%s homeDist=%.0f"):format(tostring(carrying), dHome or -1))

        if atHome and carrying then
            setStatus("จบ ✅ ที่บ้าน")
            L("ถึงจุดเกิด — จบ วางคอกเองได้")
            running = false
            startB.Text = "START"
            break
        end

        if not carrying then
            if not waitCarry("หลุดไข่ — รอถือใหม่…") then break end
        end

        setStatus(("วาป d=%.0f"):format(dHome or -1))
        hopTowardHome()
        task.wait(0.2)
        syncCarry()

        atHome, dHome = nearHome()
        if atHome and carrying then
            setStatus("จบ ✅ ที่บ้าน")
            L("ถึงบ้านหลังวาป — จบ")
            running = false
            startB.Text = "START"
            break
        end

        if not carrying then
            L("หลังวาปไม่ถือไข่แล้ว — ข้าม DROP ไป STEAL")
        else
            setStatus("DROP")
            if not doDrop() then
                L("DROP ล้มเหลว")
                task.wait(1)
                syncCarry()
                if carrying then
                    -- ยังถืออยู่ ลองต่อรอบหน้า
                end
            end
        end

        if not running then break end
        L(("รอ %.1f วิ…"):format(dropWait))
        local w0 = os.clock()
        while running and os.clock() - w0 < dropWait do
            setStatus(("รอ %.1f"):format(dropWait - (os.clock() - w0)))
            task.wait(0.1)
        end
        if not running then break end

        syncCarry()
        if not carrying then
            setStatus("STEAL")
            if doSteal() then
                L("เก็บสำเร็จ")
            else
                L("⚠ เก็บไม่ได้ — รอคุณเก็บมือ หรือขยับใกล้ไข่")
                waitCarry("รอถือไข่หลังทิ้ง…")
            end
        end
    end
    if status.Text:find("จบ") == nil then setStatus("หยุด") end
    startB.Text = "START"
end

homeB.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then return end
    HOME = r.Position
    L("🏠 HOME = " .. posStr(HOME))
    setStatus("HOME ตั้งแล้ว — กด START")
end)

startB.MouseButton1Click:Connect(function()
    if running then return end
    syncCarry()
    if not HOME then
        L("❌ กด HOME ที่จุดเกิดก่อน แล้วค่อย START")
        setStatus("ต้องกด HOME ก่อน")
        return
    end
    local _, d = nearHome()
    if carrying and d and d <= homeRadius then
        L("⚠ คุณถือไข่และอยู่บ้านแล้ว — ไม่ต้องรัน / หรือไปขโมยก่อน")
        setStatus("อยู่บ้านแล้ว")
        return
    end
    running = true
    startB.Text = "…"
    T0 = os.clock()
    L(("START home=%s carry=%s fp=%s"):format(posStr(HOME), tostring(carrying), fp and "yes" or "NO"))
    task.spawn(mainLoop)
end)

stopB.MouseButton1Click:Connect(function()
    running = false
    startB.Text = "START"
    setStatus("หยุด")
    L("STOP")
end)

copyB.MouseButton1Click:Connect(function()
    local text = ("=== Egg01 Auto ===\nTime: %s\nHome: %s\nCarry: %s\n\n%s")
        :format(os.date("%Y-%m-%d %H:%M:%S"), posStr(HOME), tostring(syncCarry()), table.concat(OUT, "\n"))
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

-- โชว์สถานะถือไข่ตลอด
task.spawn(function()
    while gui.Parent do
        if not running then
            syncCarry()
            setStatus(("IDLE | HOME=%s | ถือ=%s"):format(HOME and "OK" or "?", carrying and "YES" or "no"))
        end
        task.wait(0.5)
    end
end)

L("Egg01 Auto v1.1 | hop=" .. hopStuds .. " wait=" .. dropWait)
L("1) ยืนจุดเกิด กด HOME  2) START  3) ไปขโมยไข่เอง")
setStatus("กด HOME ที่จุดเกิดก่อน")
