-- Egg01_Auto.lua v1.5 — ถือไข่ → เดิน hop → ทิ้ง → รอ → เก็บ → ถึงบ้านจบ
-- v1.5: ถือไข่ = ปุ่ม DropHeldEgg ต้อง Visible จริง (กัน GUI ค้างแล้วคิดว่าถือ)
-- v1.4: DROP + รอมือ
-- v1.3: รอห่างบ้าน
-- v1.2: ไม่วาป
-- วิธีใช้: HOME → START → ไปขโมย | สถานะถือ=YES ต้องเห็นปุ่มทิ้งกลางจอจริง
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
gui.DisplayOrder = 200
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01AUTO_GUI = gui

local bar = Instance.new("Frame", gui)
bar.Name = "Bar"
bar.Size = UDim2.new(0, 300, 0, 36)
bar.Position = UDim2.new(0, 8, 0, 8) -- มุมบนซ้าย กันโดน HUD ขวา
bar.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
bar.BackgroundTransparency = 0.1
bar.BorderSizePixel = 0
bar.ZIndex = 10

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
box.ZIndex = 5

local status = Instance.new("TextLabel", gui)
status.Size = UDim2.new(0, 300, 0, 22)
status.Position = UDim2.new(0, 8, 0, 46)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 230, 120)
status.Font = Enum.Font.GothamBold
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "IDLE"
status.ZIndex = 10

local homeHoldUntil = 0 -- กัน status ทับข้อความ HOME

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    OUT[#OUT + 1] = ("[%5.1f] %s"):format(os.clock() - T0, s)
    if #OUT > 100 then table.remove(OUT, 1) end
    redraw()
end
local function setStatus(s)
    status.Text = s
end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", bar)
    b.Size = UDim2.new(0, w, 0, 30)
    b.Position = UDim2.new(0, x, 0, 3)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.BackgroundColor3 = col or Color3.fromRGB(40, 100, 60)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Active = true
    b.ZIndex = 11
    return b
end
local startB = hbtn("START", 4, 70, Color3.fromRGB(40, 140, 70))
local stopB  = hbtn("STOP", 76, 56, Color3.fromRGB(140, 50, 50))
local homeB  = hbtn("HOME", 134, 56, Color3.fromRGB(60, 90, 140))
local copyB  = hbtn("COPY", 192, 56)
local closeB = hbtn("✕", 250, 28, Color3.fromRGB(120, 40, 40))
bar.Size = UDim2.new(0, 286, 0, 36)

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
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Name:find(substr, 1, true) then
            return d
        end
    end
    return nil
end

-- ถือไข่จริง = มี DropHeldEgg และปุ่มทิ้งมองเห็น (Enabled+Visible)
local function syncCarry()
    local g = PG:FindFirstChild("DropHeldEgg")
    if not g then
        carrying = false
        return false
    end
    if g:IsA("LayerCollector") and g.Enabled == false then
        carrying = false
        return false
    end
    local btn = g:FindFirstChild("Button", true) or g:FindFirstChildWhichIsA("GuiButton", true)
    if not btn then
        carrying = false
        return false
    end
    if btn.AbsoluteSize.X < 4 or btn.AbsoluteSize.Y < 4 then
        carrying = false
        return false
    end
    local p = btn
    while p and p ~= g do
        if p:IsA("GuiObject") and p.Visible == false then
            carrying = false
            return false
        end
        p = p.Parent
    end
    if btn.Visible == false then
        carrying = false
        return false
    end
    carrying = true
    return true
end

local function bindCarry()
    local re = findRemote("FieldEggCarry")
    if re then
        table.insert(_G.EGG01AUTO_CONNS, re.OnClientEvent:Connect(function(tbl)
            if typeof(tbl) ~= "table" then return end
            if tbl.IsCarrying == true then
                carryUid = tbl.Uid
                task.defer(function()
                    task.wait(0.05)
                    if syncCarry() then L("RE+GUI: ถือไข่ uid=" .. tostring(carryUid)) end
                end)
            elseif tbl.IsCarrying == false then
                carryUid = nil
                carrying = false
                L("RE: ไม่ถือไข่")
            end
        end))
        L("ฟัง FieldEggCarry ✅")
    end
    table.insert(_G.EGG01AUTO_CONNS, PG.ChildAdded:Connect(function(ch)
        if ch.Name == "DropHeldEgg" then
            task.defer(function()
                task.wait(0.1)
                if syncCarry() then L("GUI: ถือไข่ (ปุ่มทิ้งโชว์)") end
            end)
        end
    end))
    table.insert(_G.EGG01AUTO_CONNS, PG.ChildRemoved:Connect(function(ch)
        if ch.Name == "DropHeldEgg" then
            carrying = false
            carryUid = nil
            L("GUI: ไม่ถือไข่")
        end
    end))
    -- ถ้า GUI ค้างแต่ปุ่มซ่อน = ไม่ถือ
    syncCarry()
    L("ถือตอนนี้: " .. (carrying and "YES (ปุ่มทิ้งโชว์)" or "no"))
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

-- DROP: GUI connections + RF AskFieldEggDrop
local function doDrop()
    syncCarry()
    if not carrying then return true end
    local r = hrp()
    L("DROP @" .. posStr(r and r.Position) .. " uid=" .. tostring(carryUid))

    local btn = getDropButton()
    if btn then
        L("  ปุ่ม: " .. btn:GetFullName():gsub("^Players%..-%.PlayerGui%.", "PG."))
        -- วิธีที่เกมมักผูก: Function() ตรงๆ
        pcall(function()
            if getconnections then
                for _, sig in ipairs({ btn.Activated, btn.MouseButton1Click, btn.MouseButton1Down }) do
                    for _, c in ipairs(getconnections(sig)) do
                        pcall(function()
                            if c.Function then c.Function() end
                        end)
                        pcall(function() c:Fire() end)
                    end
                end
            end
        end)
        pcall(function() if fsig then fsig(btn.Activated) end end)
        pcall(function() if fsig then fsig(btn.MouseButton1Click) end end)
        pcall(function()
            if typeof(btn.Activate) == "function" then btn:Activate() end
        end)
    else
        L("  ⚠ ไม่เจอ DropHeldEgg.Button")
    end

    -- RF สำรอง
    local rf = findRemote("AskFieldEggDrop")
    if rf and rf:IsA("RemoteFunction") then
        L("  ลอง AskFieldEggDrop…")
        pcall(function() rf:InvokeServer() end)
        task.wait(0.05)
        pcall(function() rf:InvokeServer(carryUid) end)
        task.wait(0.05)
        pcall(function() rf:InvokeServer({ Uid = carryUid }) end)
    end

    local t0 = os.clock()
    while os.clock() - t0 < 1.5 do
        syncCarry()
        if not carrying then L("DROP OK"); return true end
        task.wait(0.1)
    end

    -- รอผู้ใช้ทิ้งมือ (ห้ามเดินต่อทั้งที่ยังถือ)
    L("DROP ออโต้ไม่ได้ — กดปุ่มทิ้งกลางจอเอง (รอ 20วิ)")
    setStatus("ทิ้งไข่เอง!")
    t0 = os.clock()
    while running and os.clock() - t0 < 20 do
        syncCarry()
        if not carrying then L("DROP มือ OK"); return true end
        setStatus(("ทิ้งเอง! %.0fs"):format(20 - (os.clock() - t0)))
        task.wait(0.2)
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
    -- ต้องถือไข่ และห่างจาก HOME ก่อน (กันกด START ที่บ้านแล้วจบทันที)
    if not waitCarry() then return end

    local _, d0 = nearHome()
    if d0 >= 0 and d0 <= homeRadius then
        setStatus("ไปขโมยไข่ก่อน…")
        L(("อยู่ใกล้ HOME (d=%.0f) — รอให้ห่าง > %.0f แล้วค่อยเดินกลับ"):format(d0, homeRadius + 30))
        while running do
            syncCarry()
            local _, d = nearHome()
            if carrying and d > homeRadius + 30 then
                L(("ห่างบ้านแล้ว d=%.0f — เริ่มเดินกลับ"):format(d))
                break
            end
            setStatus(("ไปขโมย… ถือ=%s d=%.0f"):format(carrying and "Y" or "n", d or -1))
            task.wait(0.3)
        end
        if not running then return end
    end

    if not carrying then
        if not waitCarry("รอถือไข่ห่างบ้าน…") then return end
    end

    L("เริ่มเดินกลับ → HOME @" .. posStr(HOME))

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
            -- ถ้าเก็บไข่แล้วยังอยู่บ้าน ไม่จบจนกว่าจะเคยออกไป
        end

        hopWalkTowardHome()
        task.wait(0.2)
        syncCarry()

        atHome, dHome = nearHome()
        -- ใกล้บ้านแล้วและถือไข่ = จบ (ไม่ทิ้งที่บ้าน)
        if atHome and carrying then
            setStatus("จบ ✅ ที่บ้าน")
            L("ถึงบ้าน — จบ (วางคอกเอง)")
            break
        end

        -- ยังไกล → ต้องทิ้งก่อนค่อยเก็บวิ่งต่อ (ถ้าทิ้งไม่ได้จะหยุดรอ)
        if carrying and dHome > homeRadius then
            setStatus("DROP")
            local h, rr = hum(), hrp()
            if h and rr then pcall(function() h:MoveTo(rr.Position) end) end
            task.wait(0.15)
            if not doDrop() then
                L("ยังถือไข่ — หยุดรอบนี้ รอทิ้งก่อน START ใหม่")
                break
            end

            if not running then break end
            local w0 = os.clock()
            while running and os.clock() - w0 < dropWait do
                setStatus(("รอ %.1f"):format(dropWait - (os.clock() - w0)))
                task.wait(0.1)
            end
            if not running then break end

            setStatus("STEAL")
            if not doSteal() then
                L("เก็บออโต้ไม่ได้ — รอคุณเก็บ")
                waitCarry("รอถือไข่หลังทิ้ง…")
            else
                L("เก็บสำเร็จ")
            end
        end
    end

    running = false
    startB.Text = "START"
    if status.Text:find("จบ") == nil then setStatus("หยุด") end
end

local function markHome()
    local r = hrp()
    if not r then
        L("❌ HOME ไม่ได้ — ไม่มี Character/HRP รอเกิดก่อน")
        setStatus("รอตัวละครก่อน")
        return false
    end
    HOME = Vector3.new(r.Position.X, r.Position.Y, r.Position.Z)
    homeHoldUntil = os.clock() + 3
    L("🏠 HOME = " .. posStr(HOME))
    setStatus("HOME OK @" .. posStr(HOME))
    homeB.Text = "OK!"
    homeB.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
    task.delay(1.2, function()
        if homeB.Parent then
            homeB.Text = "HOME"
            homeB.BackgroundColor3 = Color3.fromRGB(60, 90, 140)
        end
    end)
    return true
end

homeB.MouseButton1Click:Connect(markHome)
homeB.Activated:Connect(markHome)

startB.MouseButton1Click:Connect(function()
    if running then return end
    if not HOME then
        L("ยังไม่มี HOME — ตั้งจากจุดยืนตอนนี้ให้")
        if not markHome() then
            setStatus("ต้องมีตัวละครก่อน")
            return
        end
    end
    syncCarry()
    running = true
    startB.Text = "…"
    T0 = os.clock()
    L("START v1.5b — HOME @" .. posStr(HOME))
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
        if not running and os.clock() > homeHoldUntil then
            syncCarry()
            setStatus(("IDLE | HOME=%s | ถือ=%s"):format(HOME and "OK" or "?", carrying and "YES" or "no"))
        end
        task.wait(0.6)
    end
end)

L("Egg01 Auto v1.5b | ปุ่มมุมบนซ้าย")
L("กด HOME (หรือ START จะจำจุดยืนเป็นบ้าน)")
setStatus("กด HOME ที่จุดเกิด")
