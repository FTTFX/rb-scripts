-- Egg01_StealRangeSpy.lua v1.3
-- วัดระยะที่ steal (fireproximityprompt) สำเร็จ
-- START → เดินเข้าใกล้เอง → สคริปต์ยิง prompt ถี่ๆ → ได้ไข่แล้วล็อกระยะ

if _G.EGG01_RANGE then
    pcall(function() _G.EGG01_RANGE.gui:Destroy() end)
    if _G.EGG01_RANGE.conns then
        for _, c in ipairs(_G.EGG01_RANGE.conns) do pcall(function() c:Disconnect() end) end
    end
end
_G.EGG01_RANGE = { conns = {} }

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local RUN = false
local carrying = false
local eggArea = nil
local lines = {}
local lastPrompt = nil
local lastDist = nil
local lastMax = nil
local gotOnce = false
local dumpedShift = false
local carryUid = nil
local fireCount = 0

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_StealRange"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
pcall(function()
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01_RANGE.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 300, 0, 110)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -40, 0, 22)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(230, 230, 230)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 StealRange Spy"

local function mkBtn(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bClose = mkBtn("X", 264, 4, 28, Color3.fromRGB(120, 45, 45))
local bStart = mkBtn("START", 10, 36, 70, Color3.fromRGB(40, 150, 70))
local bStop  = mkBtn("STOP", 86, 36, 70, Color3.fromRGB(160, 50, 50))
local bCopy  = mkBtn("COPY", 162, 36, 70, Color3.fromRGB(70, 70, 70))

local lab = Instance.new("TextLabel", panel)
lab.Size = UDim2.new(1, -20, 0, 36)
lab.Position = UDim2.new(0, 10, 0, 70)
lab.BackgroundTransparency = 1
lab.TextColor3 = Color3.fromRGB(255, 220, 100)
lab.Font = Enum.Font.GothamBold
lab.TextSize = 12
lab.TextXAlignment = Enum.TextXAlignment.Left
lab.TextYAlignment = Enum.TextYAlignment.Top
lab.TextWrapped = true
lab.Text = "กด START → เดินเข้าใกล้ไข่เอง"

local log = Instance.new("TextBox", gui)
log.Size = UDim2.new(0, 300, 0, 160)
log.Position = UDim2.new(0, 12, 0, 130)
log.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
log.BackgroundTransparency = 0.3
log.TextColor3 = Color3.fromRGB(180, 240, 180)
log.Font = Enum.Font.Code
log.TextSize = 11
log.TextXAlignment = Enum.TextXAlignment.Left
log.TextYAlignment = Enum.TextYAlignment.Top
log.ClearTextOnFocus = false
log.TextEditable = false
log.MultiLine = true
log.TextWrapped = true
log.Text = ""
Instance.new("UICorner", log).CornerRadius = UDim.new(0, 6)

local function say(msg)
    lines[#lines + 1] = msg
    if #lines > 80 then table.remove(lines, 1) end
    log.Text = table.concat(lines, "\n")
    lab.Text = msg
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
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

local function promptPart(pp)
    local p = pp.Parent
    if not p then return nil end
    if p:IsA("BasePart") then return p end
    return p:FindFirstChildWhichIsA("BasePart", true)
end

-- หา Steal prompt ใกล้สุด
local function nearestSteal(maxScan)
    maxScan = maxScan or 200
    local r = hrp()
    if not r then return nil end
    local best, bestD, bestPart
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local a = tostring(d.ActionText):lower()
            local n = (d.Parent and d.Parent.Name or ""):lower()
            if a:find("steal") or n:find("carryareaegg") or n:find("fieldegg") then
                local part = promptPart(d)
                if part then
                    local dd = (part.Position - r.Position).Magnitude
                    if dd <= maxScan and (not bestD or dd < bestD) then
                        best, bestD, bestPart = d, dd, part
                    end
                end
            end
        end
    end
    return best, bestD, bestPart
end

local function tryFire(pp)
    if not pp or not fp then return false end
    local old = pp.HoldDuration
    local ok = pcall(function()
        pp.HoldDuration = 0
        fp(pp)
    end)
    pcall(function() pp.HoldDuration = old end)
    return ok
end

local function dumpTbl(prefix, t)
    if typeof(t) ~= "table" then
        say(prefix .. " " .. tostring(t))
        return
    end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    say(prefix .. " keys=" .. #keys)
    for _, k in ipairs(keys) do
        local v = t[k]
        local tv = typeof(v)
        if tv == "table" then
            local n = 0
            for _ in pairs(v) do n = n + 1 end
            say(string.format("  %s = {%d}", tostring(k), n))
        elseif tv == "Vector3" then
            say(string.format("  %s = (%.2f, %.2f, %.2f)", tostring(k), v.X, v.Y, v.Z))
        elseif tv == "CFrame" then
            local p = v.Position
            say(string.format("  %s = pos(%.0f,%.0f,%.0f)", tostring(k), p.X, p.Y, p.Z))
        else
            local s = tostring(v)
            if #s > 80 then s = s:sub(1, 77) .. "..." end
            say(string.format("  %s = %s", tostring(k), s))
        end
    end
end

-- FieldEggCarry + FieldEggShifted (ดูขนาด/คุณภาพ)
do
    local re = findNet("FieldEggCarry")
    if re and re:IsA("RemoteEvent") then
        table.insert(_G.EGG01_RANGE.conns, re.OnClientEvent:Connect(function(t)
            if typeof(t) ~= "table" then return end
            if t.IsCarrying == true then
                carrying = true
                carryUid = t.Uid
                if t.AreaId then eggArea = t.AreaId end
                if RUN and not gotOnce then
                    gotOnce = true
                    dumpedShift = false -- รอ Shifted ของ Uid นี้
                    local pp, d, part = nearestSteal(250)
                    local dist = lastDist or d
                    local maxA = lastMax or (pp and pp.MaxActivationDistance)
                    say(string.format("✅ ได้ไข่! dist=%.1f | MaxAct=%.1f | โซน=%s | fire#%d",
                        dist or -1, maxA or -1, tostring(eggArea or t.AreaId or "?"), fireCount))
                    say(string.format("   ชนิด=%s Uid=%s (รอ Shifted เฉพาะ Uid นี้)",
                        tostring(t.AssetCategory or "?"), tostring(carryUid or "?"):sub(1, 12)))
                    dumpTbl("📦 FieldEggCarry", t)
                    if part then
                        local r = hrp()
                        if r then
                            say(string.format("   egg@ %.0f,%.0f,%.0f  me@ %.0f,%.0f,%.0f",
                                part.Position.X, part.Position.Y, part.Position.Z,
                                r.Position.X, r.Position.Y, r.Position.Z))
                        end
                    end
                    if pp then
                        say(string.format("   prompt='%s' parent=%s",
                            tostring(pp.ActionText), pp.Parent and pp.Parent.Name or "?"))
                    end
                    RUN = false
                    bStart.Text = "START"
                    lab.Text = string.format("✅ ระยะ ≈ %.1f | %s", dist or -1, tostring(t.AssetCategory or "?"))
                else
                    say("server: ถือไข่แล้ว โซน=" .. tostring(eggArea or "?"))
                end
            elseif t.IsCarrying == false then
                carrying = false
                say("server: ไม่ถือไข่")
            end
        end))
        say("ฟัง FieldEggCarry ✅")
    else
        say("⚠ ไม่เจอ FieldEggCarry")
    end

    local sh = findNet("FieldEggShifted")
    if sh and sh:IsA("RemoteEvent") then
        table.insert(_G.EGG01_RANGE.conns, sh.OnClientEvent:Connect(function(t)
            if typeof(t) ~= "table" then return end
            if not gotOnce or dumpedShift then return end
            if not carryUid or t.Uid ~= carryUid then return end -- กันไข่คนละใบ
            local st = tostring(t.State or "")
            if st ~= "Carried" and st ~= "Dropped" then return end
            dumpedShift = true
            say(string.format("📥 Shifted State=%s Scale=%.3f Mut=%s | %s",
                st,
                tonumber(t.AssetScale) or -1,
                typeof(t.Mutations) == "table" and "table" or tostring(t.Mutations),
                tostring(t.AssetCategory or "?")))
            dumpTbl("📦 FieldEggShifted", t)
        end))
        say("ฟัง FieldEggShifted ✅")
    end
end

if not fp then
    say("⚠ ไม่มี fireproximityprompt — จะวัดแค่ตอนคุณกด E เอง")
end

local function loop()
    fireCount = 0
    gotOnce = false
    dumpedShift = false
    carryUid = nil
    lastPrompt, lastDist, lastMax = nil, nil, nil
    say("START — เดินเข้าใกล้ไข่ (ยิง remote ถี่ๆ)")
    local tLog = 0
    while RUN do
        if carrying and not gotOnce then
            -- เผื่อ event มาก่อน loop เห็น
            task.wait(0.1)
        end
        local pp, d, part = nearestSteal(250)
        if pp and d then
            lastPrompt, lastDist, lastMax = pp, d, pp.MaxActivationDistance
            lab.Text = string.format("ใกล้สุด %.1f | MaxAct=%.1f | fire#%d",
                d, pp.MaxActivationDistance, fireCount)
            if fp then
                tryFire(pp)
                fireCount = fireCount + 1
            end
            if os.clock() - tLog > 1.2 then
                tLog = os.clock()
                say(string.format("… dist=%.1f MaxAct=%.1f parent=%s",
                    d, pp.MaxActivationDistance, pp.Parent and pp.Parent.Name or "?"))
            end
        else
            lab.Text = "ไม่เจอ Steal prompt ใน 250 studs — เข้าใกล้ไข่"
        end
        task.wait(0.25)
    end
end

bStart.MouseButton1Click:Connect(function()
    if RUN then return end
    if carrying then
        say("ถือไข่อยู่แล้ว — ทิ้งไข่ก่อนแล้วกด START ใหม่")
        return
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
    local t = "=== Egg01 StealRange Spy ===\n" .. table.concat(lines, "\n")
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, t) end
    bCopy.Text = "OK"
    task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)

bClose.MouseButton1Click:Connect(function()
    RUN = false
    for _, c in ipairs(_G.EGG01_RANGE.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    _G.EGG01_RANGE = nil
end)

say("Egg01 StealRange Spy v1.3")
say("START → เดินเข้าใกล้ไข่เอง → ได้ไข่แล้วล็อกระยะ")
