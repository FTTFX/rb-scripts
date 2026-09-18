-- Egg01_SizeEPS.lua v1.1
-- EPS แยกขนาด: จำ AssetScale จาก FieldEggShifted แล้วขโมยเฉพาะไข่ที่ใหญ่พอ
-- SCAN = ลิสต์ไข่ใกล้ตัว+สเกล | START = ยิง Steal เฉพาะ scale >= MinScale

if _G.EGG01_SIZE then
    pcall(function() _G.EGG01_SIZE.gui:Destroy() end)
    if _G.EGG01_SIZE.conns then
        for _, c in ipairs(_G.EGG01_SIZE.conns) do pcall(function() c:Disconnect() end) end
    end
end
_G.EGG01_SIZE = { conns = {} }

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local STEAL_RANGE = 16
local RUN = false
local lines = {}
local eggDB = {} -- [uid] = { scale, cat, area, pos, state, nest, mutN, ver }
local carrying = false
local carryUid = nil

local CFG = {
    minScale = 1.5, -- Gorilla~2.0 / ปกติ~0.9
    onlySlot = true, -- เป้าแค่ไข่ในรัง (Slot) ไม่เอา Dropped คนอื่น
}

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_SizeEPS"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
pcall(function()
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01_SIZE.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 300, 0, 130)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -40, 0, 20)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(230, 230, 230)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 Size EPS v1.1"

local function mkBtn(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 26)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = text
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bClose = mkBtn("X", 264, 4, 28, Color3.fromRGB(120, 45, 45))
local bScan  = mkBtn("SCAN", 10, 32, 58, Color3.fromRGB(50, 100, 180))
local bStart = mkBtn("START", 74, 32, 58, Color3.fromRGB(40, 150, 70))
local bStop  = mkBtn("STOP", 138, 32, 58, Color3.fromRGB(160, 50, 50))
local bCopy  = mkBtn("COPY", 202, 32, 58, Color3.fromRGB(70, 70, 70))

local lb = Instance.new("TextLabel", panel)
lb.Size = UDim2.new(0, 70, 0, 16)
lb.Position = UDim2.new(0, 10, 0, 64)
lb.BackgroundTransparency = 1
lb.TextColor3 = Color3.fromRGB(170, 170, 170)
lb.Font = Enum.Font.Gotham
lb.TextSize = 11
lb.TextXAlignment = Enum.TextXAlignment.Left
lb.Text = "MinScale"

local tMin = Instance.new("TextBox", panel)
tMin.Size = UDim2.new(0, 54, 0, 24)
tMin.Position = UDim2.new(0, 80, 0, 60)
tMin.BackgroundColor3 = Color3.fromRGB(40, 42, 48)
tMin.TextColor3 = Color3.new(1, 1, 1)
tMin.Font = Enum.Font.GothamBold
tMin.TextSize = 12
tMin.Text = tostring(CFG.minScale)
tMin.ClearTextOnFocus = false
tMin.BorderSizePixel = 0
Instance.new("UICorner", tMin).CornerRadius = UDim.new(0, 4)

local lab = Instance.new("TextLabel", panel)
lab.Size = UDim2.new(1, -20, 0, 34)
lab.Position = UDim2.new(0, 10, 0, 90)
lab.BackgroundTransparency = 1
lab.TextColor3 = Color3.fromRGB(255, 220, 100)
lab.Font = Enum.Font.GothamBold
lab.TextSize = 11
lab.TextXAlignment = Enum.TextXAlignment.Left
lab.TextYAlignment = Enum.TextYAlignment.Top
lab.TextWrapped = true
lab.Text = "ฟัง Shifted → SCAN / START (ขโมยเฉพาะไข่ใหญ่)"

local log = Instance.new("TextBox", gui)
log.Size = UDim2.new(0, 300, 0, 170)
log.Position = UDim2.new(0, 12, 0, 150)
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
    if #lines > 90 then table.remove(lines, 1) end
    log.Text = table.concat(lines, "\n")
    lab.Text = msg
end

local function readCfg()
    local n = tonumber(tMin.Text)
    if n and n > 0 then CFG.minScale = n end
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

local function mutCount(m)
    if typeof(m) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(m) do n = n + 1 end
    return n
end

local function posFromTbl(t)
    if typeof(t.BottomCFrame) == "CFrame" then return t.BottomCFrame.Position end
    if typeof(t.BoundsCFrame) == "CFrame" then return t.BoundsCFrame.Position end
    return nil
end

local function upsertEgg(t)
    if typeof(t) ~= "table" or not t.Uid then return end
    local uid = t.Uid
    local e = eggDB[uid] or {}
    if t.AssetScale ~= nil then e.scale = tonumber(t.AssetScale) or e.scale end
    if t.AssetCategory then e.cat = t.AssetCategory end
    if t.AreaId then e.area = t.AreaId end
    if t.State then e.state = t.State end
    if t.NestId then e.nest = t.NestId end
    if t.Version then e.ver = t.Version end
    e.mutN = mutCount(t.Mutations)
    local p = posFromTbl(t)
    if p then e.pos = p end
    e.t = os.clock()
    eggDB[uid] = e
end

local function promptPart(pp)
    local p = pp.Parent
    if not p then return nil end
    if p:IsA("BasePart") then return p end
    return p:FindFirstChildWhichIsA("BasePart", true)
end

-- วัดขนาดจากโมเดลใกล้ prompt (ไข่ในรังเห็นสเกลชัดก่อน Shifted)
local function probeVisualScale(anchor)
    if not anchor then return nil, "no-part" end
    local bestVol, bestMax, src = 0, 0, nil
    local origin = anchor.Position
    -- ไล่ parent ขึ้นหา Model แล้ววัดลูก
    local roots = { anchor }
    local p = anchor.Parent
    for _ = 1, 6 do
        if not p or p == workspace then break end
        roots[#roots + 1] = p
        if p:IsA("Model") then break end
        p = p.Parent
    end
    -- + สแกน part ใกล้ๆ 12 studs
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and not d:IsA("Terrain") then
            local nm = d.Name:lower()
            local near = (d.Position - origin).Magnitude <= 14
            local eggish = nm:find("egg") or nm:find("nest") or nm:find("slot") or nm:find("carry")
            if near and (eggish or (d.Position - origin).Magnitude <= 6) then
                local s = d.Size
                local mx = math.max(s.X, s.Y, s.Z)
                local vol = s.X * s.Y * s.Z
                if mx > 1.2 and vol > bestVol then
                    bestVol, bestMax, src = vol, mx, d
                end
            end
        end
    end
    -- attribute / NumberValue บนสาย parent
    for _, root in ipairs(roots) do
        for _, key in ipairs({ "AssetScale", "NestScale", "Scale", "EggScale", "SizeScale" }) do
            local ok, v = pcall(function() return root:GetAttribute(key) end)
            if ok and tonumber(v) then
                return tonumber(v), "attr:" .. key
            end
        end
        for _, ch in ipairs(root:GetDescendants()) do
            if ch:IsA("NumberValue") or ch:IsA("NumberConstraint") then
                local nl = ch.Name:lower()
                if nl:find("scale") and tonumber(ch.Value) then
                    return tonumber(ch.Value), "nv:" .. ch.Name
                end
            end
        end
    end
    if bestMax > 0 then
        -- แปลง max stud → ประมาณ AssetScale (Walrus~4 / Bounds~7)
        local approx = bestMax / 1.8
        return approx, string.format("visMax=%.1f", bestMax)
    end
    return nil, "none"
end

local function matchEggAt(worldPos, maxD)
    maxD = maxD or 55
    local best, bestD, bestUid
    for uid, e in pairs(eggDB) do
        if e.pos and e.scale then
            local skip = CFG.onlySlot and e.state == "Carried"
            if not skip then
                local d = (e.pos - worldPos).Magnitude
                if d <= maxD and (not bestD or d < bestD) then
                    best, bestD, bestUid = e, d, uid
                end
            end
        end
    end
    return best, bestD, bestUid
end

local function resolveScale(part)
    local egg, md, uid = matchEggAt(part.Position, 55)
    if egg and egg.scale then
        return egg.scale, egg, uid, md, "db"
    end
    local vis, how = probeVisualScale(part)
    if vis then
        return vis, { scale = vis, cat = "?", area = "?", state = "vis" }, nil, nil, how
    end
    return nil, nil, nil, nil, "unk"
end

local function listStealNear(radius)
    radius = radius or 120
    local r = hrp()
    if not r then return {} end
    local out = {}
    local seen = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local a = tostring(d.ActionText):lower()
            if a:find("steal") then
                local part = promptPart(d)
                if part then
                    local key = string.format("%.0f_%.0f_%.0f", part.Position.X, part.Position.Y, part.Position.Z)
                    if not seen[key] then
                        seen[key] = true
                        local dd = (part.Position - r.Position).Magnitude
                        if dd <= radius then
                            local scale, egg, uid, md, src = resolveScale(part)
                            out[#out + 1] = {
                                pp = d, part = part, dist = dd,
                                egg = egg, matchD = md, uid = uid,
                                scale = scale, src = src,
                            }
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local sa, sb = a.scale or -1, b.scale or -1
        if sa ~= sb then return sa > sb end
        return a.dist < b.dist
    end)
    return out
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

local function dbCount()
    local n, big = 0, 0
    readCfg()
    for _, e in pairs(eggDB) do
        n = n + 1
        if e.scale and e.scale >= CFG.minScale then big = big + 1 end
    end
    return n, big
end

-- remotes
do
    local sh = findNet("FieldEggShifted")
    if sh and sh:IsA("RemoteEvent") then
        table.insert(_G.EGG01_SIZE.conns, sh.OnClientEvent:Connect(function(t)
            upsertEgg(t)
        end))
        say("ฟัง FieldEggShifted ✅ (สะสมสเกล)")
    else
        say("⚠ ไม่เจอ FieldEggShifted")
    end

    local re = findNet("FieldEggCarry")
    if re and re:IsA("RemoteEvent") then
        table.insert(_G.EGG01_SIZE.conns, re.OnClientEvent:Connect(function(t)
            if typeof(t) ~= "table" then return end
            if t.IsCarrying == true then
                carrying = true
                carryUid = t.Uid
                local e = eggDB[t.Uid]
                local sc = e and e.scale
                say(string.format("✅ ถือไข่ %s scale=%s โซน=%s",
                    tostring(t.AssetCategory or "?"),
                    sc and string.format("%.3f", sc) or "?",
                    tostring(t.AreaId or "?")))
                if sc and sc < CFG.minScale then
                    say(string.format("⚠ เล็กกว่า MinScale %.2f — ทิ้งเองหรือรอ Auto", CFG.minScale))
                end
            elseif t.IsCarrying == false then
                carrying = false
                carryUid = nil
                say("server: ไม่ถือไข่")
            end
        end))
        say("ฟัง FieldEggCarry ✅")
    end

    local batch = findNet("FieldEggBatchShifted")
    if batch and batch:IsA("RemoteEvent") then
        table.insert(_G.EGG01_SIZE.conns, batch.OnClientEvent:Connect(function(t)
            if typeof(t) == "table" then
                if t[1] then
                    for _, row in ipairs(t) do upsertEgg(row) end
                else
                    upsertEgg(t)
                end
            end
        end))
        say("ฟัง FieldEggBatchShifted ✅")
    end
end

bScan.MouseButton1Click:Connect(function()
    readCfg()
    -- ขอ snapshot ถ้ามี
    for _, name in ipairs({ "AskFieldEggSnapshot", "AskLiveSnapshot" }) do
        local rf = findNet(name)
        if rf and rf:IsA("RemoteFunction") then
            local ok, res = pcall(function() return rf:InvokeServer() end)
            say(string.format("RF %s → %s", name, ok and typeof(res) or tostring(res)))
            if ok and typeof(res) == "table" then
                if res[1] then
                    for _, row in ipairs(res) do upsertEgg(row) end
                else
                    upsertEgg(res)
                    for _, row in pairs(res) do
                        if typeof(row) == "table" and row.Uid then upsertEgg(row) end
                    end
                end
            end
        end
    end
    local n, big = dbCount()
    say(string.format("── SCAN db=%d (≥%.2f มี %d) ──", n, CFG.minScale, big))
    local di = 0
    for uid, e in pairs(eggDB) do
        di = di + 1
        if di <= 8 then
            say(string.format("  DB %s sc=%.3f %s [%s] %s @%s",
                tostring(uid):sub(1, 8), e.scale or -1,
                tostring(e.cat or "?"), tostring(e.area or "?"),
                tostring(e.state or "?"),
                e.pos and string.format("%.0f,%.0f", e.pos.X, e.pos.Z) or "?"))
        end
    end
    local list = listStealNear(150)
    if #list == 0 then
        say("ไม่เจอ Steal ใน 150 studs")
        return
    end
    local shown = 0
    for _, it in ipairs(list) do
        if shown >= 12 then break end
        shown = shown + 1
        local sc = it.scale
        if sc then
            local mark = sc >= CFG.minScale and "★" or " "
            say(string.format("%s d=%.0f scale≈%.2f %s (%s)",
                mark, it.dist, sc,
                tostring(it.egg and it.egg.cat or "?"),
                tostring(it.src)))
        else
            say(string.format("  d=%.0f  ไม่รู้สเกล", it.dist))
        end
    end
end)

local function loop()
    readCfg()
    say(string.format("START EPS — ขโมยเฉพาะ scale≥%.2f (ใกล้ ≤%d)", CFG.minScale, STEAL_RANGE))
    local tLog = 0
    while RUN do
        if carrying then
            lab.Text = "ถือไข่แล้ว — หยุด EPS (ไป Auto กลับบ้าน)"
            task.wait(0.4)
        else
            local list = listStealNear(80)
            local target
            for _, it in ipairs(list) do
                if it.dist <= STEAL_RANGE and it.scale and it.scale >= CFG.minScale then
                    target = it
                    break
                end
            end
            if target then
                say(string.format("ยิง ★ scale≈%.2f %s d=%.1f (%s)",
                    target.scale, tostring(target.egg and target.egg.cat or "?"),
                    target.dist, tostring(target.src)))
                tryFire(target.pp)
            else
                local near = list[1]
                if near and near.dist <= STEAL_RANGE then
                    if near.scale then
                        lab.Text = string.format("ข้ามเล็ก ≈%.2f < %.2f", near.scale, CFG.minScale)
                    else
                        lab.Text = string.format("ใกล้ d=%.0f ยังไม่รู้สเกล", near.dist)
                    end
                else
                    local n, big = dbCount()
                    lab.Text = string.format("รอไข่ใหญ่… db=%d big=%d", n, big)
                end
            end
            if os.clock() - tLog > 2.5 then
                tLog = os.clock()
                local n, big = dbCount()
                say(string.format("… db=%d big=%d (≥%.2f)", n, big, CFG.minScale))
            end
        end
        task.wait(0.3)
    end
end

bStart.MouseButton1Click:Connect(function()
    if RUN then return end
    if not fp then say("⚠ ไม่มี fireproximityprompt"); return end
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
    local t = "=== Egg01 Size EPS ===\n" .. table.concat(lines, "\n")
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, t) end
    bCopy.Text = "OK"
    task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)

bClose.MouseButton1Click:Connect(function()
    RUN = false
    for _, c in ipairs(_G.EGG01_SIZE.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    _G.EGG01_SIZE = nil
end)

say("Size EPS — MinScale กรองไข่ใหญ่ (เช่น 1.5 / 2.0)")
say("เดินใกล้รัง → SCAN ดูสเกล → START ยิงเฉพาะ ★")
