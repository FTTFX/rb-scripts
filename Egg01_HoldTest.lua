-- Egg01_HoldTest.lua v1.1 — ใกล้ไข่แล้วลองข้าม Hold ได้ไหม?
-- v1.1: ดัมพ์ table จาก RE FieldEggCarry + ปุ่ม STEAL0 + ลอง RF ด้วย table
-- วิธีใช้: ยืนใกล้ไข่ (เห็นปุ่ม Steal) → กด TEST หรือ STEAL0
-- สำเร็จ = RE FieldEggCarry / FieldEggShifted
if _G.EGG01HT_GUI then pcall(function() _G.EGG01HT_GUI:Destroy() end) end
if _G.EGG01HT_CONNS then
    for _, c in pairs(_G.EGG01HT_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.EGG01HT_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT, T0 = {}, os.clock()
local carryHit = 0

local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local fsig = firesignal or (getgenv and getgenv().firesignal)

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01HoldTest"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.EGG01HT_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 680, 0, 340); box.Position = UDim2.new(0, 8, 0.22, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.12
box.TextColor3 = Color3.fromRGB(255, 230, 170); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    OUT[#OUT + 1] = ("[%5.2f] %s"):format(os.clock() - T0, s)
    if #OUT > 400 then table.remove(OUT, 1) end
    redraw()
end

local lastCarryTbl = nil
local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "table" then
        if depth > 3 then return "{...}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n += 1
            if n > 16 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. ser(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "Instance" then
        return "<" .. v.ClassName .. ":" .. v.Name .. ">"
    elseif t == "string" then
        return '"' .. (v:len() > 60 and v:sub(1, 60) .. "…" or v) .. '"'
    elseif t == "Vector3" then
        return ("V3(%.1f,%.1f,%.1f)"):format(v.X, v.Y, v.Z)
    end
    return tostring(v)
end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.22, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local testB  = hbtn("TEST", 8, 80, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 94, 70, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 170, 70)
local closeB = hbtn("✕", 246, 34, Color3.fromRGB(150, 40, 40))

local function hrp()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end

local function short(inst)
    local ok, f = pcall(function() return inst:GetFullName() end)
    return ok and f:gsub("^Workspace%.", "WS.") or "?"
end

-- หา Steal prompt ใกล้สุด
local function nearestSteal(maxDist)
    maxDist = maxDist or 25
    local r = hrp()
    if not r then return nil, nil end
    local best, bestD, bestPp
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local act = tostring(d.ActionText):lower()
            local par = d.Parent
            local nameHit = par and (par.Name:find("CarryAreaEgg") or par.Name:find("Egg") or act:find("steal"))
            if nameHit or act:find("steal") then
                local part = par and (par:IsA("BasePart") and par
                    or par:FindFirstChildWhichIsA("BasePart", true))
                if part then
                    local dist = (part.Position - r.Position).Magnitude
                    if dist <= maxDist and (not bestD or dist < bestD) then
                        best, bestD, bestPp = part, dist, d
                    end
                end
            end
        end
    end
    return bestPp, bestD
end

local function lookingLikeCarry()
    local char = LP.Character
    if not char then return false, "no char" end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then
            local n = t.Name:lower()
            if n:find("egg") or n:find("carry") then
                return true, "Tool:" .. t.Name
            end
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("egg") then
                return true, "Bag:" .. t.Name
            end
        end
    end
    return false, "ไม่ถือไข่"
end

-- ดัก RE ขากลับ FieldEggCarry
task.spawn(function()
    local net = RS:FindFirstChild("Packages")
    net = net and net:FindFirstChild("Networking")
    if not net then L("⚠ ไม่เจอ RS.Packages.Networking") return end
    for _, d in ipairs(net:GetDescendants()) do
        if d:IsA("RemoteEvent") and (d.Name:find("FieldEgg") or d.Name:find("EggCarry") or d.Name == "FieldEggCarry") then
            table.insert(_G.EGG01HT_CONNS, d.OnClientEvent:Connect(function(...)
                carryHit += 1
                local n = select("#", ...)
                local parts = {}
                for i = 1, math.min(n, 6) do
                    local v = select(i, ...)
                    if typeof(v) == "table" then
                        lastCarryTbl = v
                        parts[i] = ser(v)
                    else
                        parts[i] = typeof(v) == "Instance" and ("<" .. v.ClassName .. ":" .. v.Name .. ">") or tostring(v)
                    end
                end
                L(("← RE %s(%s)"):format(d.Name, table.concat(parts, ", ")))
            end))
            L("ฟัง ← " .. short(d))
        end
    end
end)

local function tryMethod(label, fn)
    local beforeHit = carryHit
    local beforeCarry = lookingLikeCarry()
    L("── ลอง: " .. label)
    local ok, err = pcall(fn)
    if not ok then L("  ❌ error: " .. tostring(err)) return false end
    task.wait(0.55)
    local afterCarry, why = lookingLikeCarry()
    local gotRE = carryHit > beforeHit
    if (afterCarry and not beforeCarry) or gotRE then
        L(("  ✅ สำเร็จ (%s%s)"):format(why, gotRE and " +RE" or ""))
        return true
    end
    L(("  ❌ ไม่เข้า (%s, RE+%d)"):format(why, carryHit - beforeHit))
    return false
end

local function runTests()
    local pp, dist = nearestSteal(30)
    if not pp then
        L("❌ ไม่เจอ Steal prompt ใน 30 studs — ยืนใกล้ไข่ก่อน")
        return
    end
    L(("เป้า: act='%s' hold=%.2f max=%d dist=%.1f"):format(
        tostring(pp.ActionText), pp.HoldDuration, pp.MaxActivationDistance, dist or -1))
    L("path: " .. short(pp))
    L("fp=" .. (fp and "✅" or "❌") .. " firesignal=" .. (fsig and "✅" or "❌"))

    local origHold = pp.HoldDuration

    -- 1) Hold=0 + fireproximityprompt
    if fp then
        tryMethod("Hold=0 + fireproximityprompt", function()
            pp.HoldDuration = 0
            fp(pp)
            task.wait(0.05)
            pp.HoldDuration = origHold
        end)
        if lookingLikeCarry() then L("จบ — ได้ตั้งแต่วิธี 1"); return end
    else
        L("ข้าม fp (executor ไม่มี fireproximityprompt)")
    end

    -- 2) fireproximityprompt แบบปกติ (ไม่แตะ Hold)
    if fp then
        tryMethod("fp ปกติ (Hold เดิม " .. string.format("%.1f", origHold) .. ")", function()
            fp(pp)
        end)
        if lookingLikeCarry() then L("จบ — ได้จาก fp ปกติ"); return end
    end

    -- 3) firesignal Triggered
    if fsig then
        tryMethod("firesignal(Triggered)", function()
            fsig(pp.Triggered, pp, LP)
        end)
        if lookingLikeCarry() then L("จบ — ได้จาก firesignal"); return end
    end

    -- 4) InputHoldBegin → รอ 0 → InputHoldEnd (ไม่ค้าง)
    tryMethod("InputHold 0 วิ (ไม่ค้าง)", function()
        pp:InputHoldBegin()
        task.wait(0)
        pp:InputHoldEnd()
    end)
    if lookingLikeCarry() then L("จบ — ได้จาก InputHold 0"); return end

    -- 5) InputHoldBegin → รอครบ Hold จริง (baseline ว่า prompt ใช้ได้)
    tryMethod(("InputHold ค้างครบ %.1f วิ (baseline)"):format(origHold), function()
        pp:InputHoldBegin()
        task.wait(origHold + 0.05)
        pp:InputHoldEnd()
    end)
    if lookingLikeCarry() then
        L("สรุป: ต้องค้างครบ Hold — ข้าม Hold ไม่ได้ (server เช็คเวลา)")
        return
    end

    -- 6) ลอง RF AskFieldEggCarry เปล่า / ส่ง prompt parent
    local rf
    pcall(function()
        rf = RS.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggCarry", true)
            or RS.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
    end)
    if not rf then
        for _, d in ipairs(RS:GetDescendants()) do
            if d:IsA("RemoteFunction") and d.Name == "AskFieldEggCarry" then
                rf = d; break
            end
        end
    end
    if rf then
        tryMethod("AskFieldEggCarry()", function()
            rf:InvokeServer()
        end)
        if lookingLikeCarry() then return end
        tryMethod("AskFieldEggCarry(prompt.Parent)", function()
            rf:InvokeServer(pp.Parent)
        end)
        if lookingLikeCarry() then return end
        tryMethod("AskFieldEggCarry(prompt)", function()
            rf:InvokeServer(pp)
        end)
        if lastCarryTbl then
            tryMethod("AskFieldEggCarry(lastCarryTbl จาก RE)", function()
                rf:InvokeServer(lastCarryTbl)
            end)
        else
            L("ยังไม่มี lastCarryTbl จาก RE — ลอง fp ก่อนรอบหน้า")
        end
    else
        L("ไม่เจอ AskFieldEggCarry")
    end

    L("=== จบทุกวิธี — ส่ง COPY มาได้ ===")
end

-- ปุ่มด่วน: แค่ Hold=0+fp ใกล้สุด
local stealB = hbtn("STEAL0", 286, 80, Color3.fromRGB(160, 90, 30))
stealB.MouseButton1Click:Connect(function()
    task.spawn(function()
        local pp, dist = nearestSteal(30)
        if not pp then L("❌ ไม่เจอ Steal ใกล้ๆ") return end
        local orig = pp.HoldDuration
        L(("STEAL0 dist=%.1f hold→0"):format(dist or -1))
        pp.HoldDuration = 0
        if fp then fp(pp) else L("❌ ไม่มี fp") end
        task.wait(0.1)
        pp.HoldDuration = orig
        task.wait(0.4)
        L(carryHit > 0 and ("✅ RE hit=" .. carryHit) or "❓ ยังไม่เห็น RE")
    end)
end)

testB.MouseButton1Click:Connect(function()
    task.spawn(runTests)
end)
clearB.MouseButton1Click:Connect(function() OUT = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = ("=== Egg01 HoldTest ===\nTime: %s\nPlaceId: %s\n\n%s")
        :format(os.date("%Y-%m-%d %H:%M:%S"), tostring(game.PlaceId), table.concat(OUT, "\n"))
    local clip = setclipboard or toclipboard
    local ok = clip and pcall(clip, text)
    pcall(function() if writefile then writefile("Egg01_hold_log.txt", text) end end)
    copyB.Text = ok and "คัดลอกแล้ว!" or "เซฟ?"
    task.delay(1.4, function() if copyB.Parent then copyB.Text = "COPY" end end)
end)
closeB.MouseButton1Click:Connect(function()
    if _G.EGG01HT_CONNS then
        for _, c in pairs(_G.EGG01HT_CONNS) do pcall(function() c:Disconnect() end) end
    end
    gui:Destroy(); _G.EGG01HT_GUI = nil
end)

L("Egg01 HoldTest v1.0 — ยืนใกล้ไข่ (เห็น Steal) แล้วกด TEST")
L("จะลอง: Hold=0+fp / fp / firesignal / InputHold0 / InputHoldครบ / RF")
