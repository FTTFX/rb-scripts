-- Egg01 KillZone Scan v2.0 — ESP จุดตาย + เส้นอันตราย (ข้ามเส้นนี้เสี่ยงตาย)
-- จากเทส: ตายที่ Z≈-450..-455 → วาดกำแพง ESP ตามแนว Z
-- WATCH HP จำจุดตายเพิ่ม → อัปเดตเส้นอัตโนมัติ

if _G.EGG01_KILLZONE then
    _G.EGG01_KILLZONE.run = false
    _G.EGG01_KILLZONE.watch = false
    pcall(function()
        if _G.EGG01_KILLZONE.hpConn then _G.EGG01_KILLZONE.hpConn:Disconnect() end
        if _G.EGG01_KILLZONE.warnConn then _G.EGG01_KILLZONE.warnConn:Disconnect() end
    end)
    pcall(function() _G.EGG01_KILLZONE.gui:Destroy() end)
    pcall(function()
        if _G.EGG01_KILLZONE.folder then _G.EGG01_KILLZONE.folder:Destroy() end
        if _G.EGG01_KILLZONE.espFolder then _G.EGG01_KILLZONE.espFolder:Destroy() end
    end)
end

local Players = game:GetService("Players")
local RunS = game:GetService("RunService")
local LP = Players.LocalPlayer

local S = {
    run = false, gui = nil, lines = {},
    hpConn = nil, warnConn = nil,
    folder = nil, espFolder = nil,
    watch = false,
    deaths = {}, -- {Vector3, ...} จุด HP=0
    killLine = nil, -- { axis="Z"|"X", value=number, lo=number, hi=number }
}
_G.EGG01_KILLZONE = S

local logBox
local RADIUS = 400
local STEP = 25
local WARN_DIST = 50 -- ใกล้เส้นนี้กี่ studs เตือน

-- จุดตายจากเทสรอบก่อน (seed)
local SEED_DEATHS = {
    Vector3.new(819, 71, -455),
    Vector3.new(566, 71, -450),
}

local function say(m)
    S.lines[#S.lines + 1] = tostring(m)
    if #S.lines > 28 then table.remove(S.lines, 1) end
    if logBox then logBox.Text = table.concat(S.lines, "\n") end
    warn("[KillZone] " .. tostring(m))
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function ensureFolders()
    if not S.folder or not S.folder.Parent then
        S.folder = Instance.new("Folder")
        S.folder.Name = "Egg01_KillMarks"
        S.folder.Parent = workspace
    end
    if not S.espFolder or not S.espFolder.Parent then
        S.espFolder = Instance.new("Folder")
        S.espFolder.Name = "Egg01_KillESP"
        S.espFolder.Parent = workspace
    end
end

local function clearScanMarks()
    if S.folder then pcall(function() S.folder:Destroy() end) end
    S.folder = Instance.new("Folder")
    S.folder.Name = "Egg01_KillMarks"
    S.folder.Parent = workspace
end

local function clearESP()
    if S.espFolder then pcall(function() S.espFolder:Destroy() end) end
    S.espFolder = Instance.new("Folder")
    S.espFolder.Name = "Egg01_KillESP"
    S.espFolder.Parent = workspace
end

local function markAt(parent, pos, color, label, size)
    size = size or Vector3.new(8, 2, 8)
    local p = Instance.new("Part")
    p.Name = label or "KZ"
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.Size = size
    p.Position = pos + Vector3.new(0, size.Y * 0.5, 0)
    p.Color = color
    p.Material = Enum.Material.Neon
    p.Transparency = 0.4
    p.Parent = parent

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 160, 0, 36)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2000
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.Parent = p
    local t = Instance.new("TextLabel", bb)
    t.Size = UDim2.new(1, 0, 1, 0)
    t.BackgroundTransparency = 0.35
    t.BackgroundColor3 = Color3.new(0, 0, 0)
    t.Text = label or "?"
    t.TextColor3 = Color3.fromRGB(255, 80, 80)
    t.TextStrokeTransparency = 0.3
    t.Font = Enum.Font.GothamBold
    t.TextSize = 12
    Instance.new("UICorner", t).CornerRadius = UDim.new(0, 4)
    return p
end

-- คำนวณเส้นตายจากจุด deaths: ถ้า Z รวมกลุ่ม → เส้นขนานแกน X ที่ Z=median
local function computeKillLine()
    if #S.deaths < 1 then
        S.killLine = nil
        return nil
    end
    local xs, zs = {}, {}
    for _, p in ipairs(S.deaths) do
        xs[#xs + 1] = p.X
        zs[#zs + 1] = p.Z
    end
    table.sort(xs)
    table.sort(zs)
    local function med(t)
        local n = #t
        if n % 2 == 1 then return t[math.ceil(n / 2)] end
        return (t[n / 2] + t[n / 2 + 1]) / 2
    end
    local xSpan = xs[#xs] - xs[1]
    local zSpan = zs[#zs] - zs[1]
    -- แกนที่กระจายน้อยกว่า = เส้นคงที่ (death line)
    if zSpan <= xSpan then
        local z = med(zs)
        local pad = math.max(80, xSpan * 0.3 + 40)
        S.killLine = { axis = "Z", value = z, lo = xs[1] - pad, hi = xs[#xs] + pad, y = S.deaths[1].Y }
    else
        local x = med(xs)
        local pad = math.max(80, zSpan * 0.3 + 40)
        S.killLine = { axis = "X", value = x, lo = zs[1] - pad, hi = zs[#zs] + pad, y = S.deaths[1].Y }
    end
    return S.killLine
end

local function distToKillLine(pos)
    local L = S.killLine
    if not L then return math.huge end
    if L.axis == "Z" then
        return math.abs(pos.Z - L.value)
    end
    return math.abs(pos.X - L.value)
end

-- วาดกำแพง ESP ตามเส้น + จุดตาย
local function redrawESP()
    ensureFolders()
    clearESP()
    computeKillLine()

    for i, p in ipairs(S.deaths) do
        markAt(S.espFolder, p, Color3.fromRGB(255, 30, 30),
            string.format("☠ ตาย#%d\n(%.0f,%.0f,%.0f)", i, p.X, p.Y, p.Z),
            Vector3.new(10, 3, 10))
    end

    local L = S.killLine
    if L then
        local len = math.max(40, L.hi - L.lo)
        local wall
        if L.axis == "Z" then
            wall = Instance.new("Part")
            wall.Size = Vector3.new(len, 40, 2)
            wall.CFrame = CFrame.new((L.lo + L.hi) * 0.5, L.y + 20, L.value)
        else
            wall = Instance.new("Part")
            wall.Size = Vector3.new(2, 40, len)
            wall.CFrame = CFrame.new(L.value, L.y + 20, (L.lo + L.hi) * 0.5)
        end
        wall.Name = "KillLineWall"
        wall.Anchored = true
        wall.CanCollide = false
        wall.CanQuery = false
        wall.Color = Color3.fromRGB(255, 40, 40)
        wall.Material = Enum.Material.Neon
        wall.Transparency = 0.55
        wall.Parent = S.espFolder

        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 220, 0, 48)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 3000
        bb.StudsOffset = Vector3.new(0, 28, 0)
        bb.Parent = wall
        local t = Instance.new("TextLabel", bb)
        t.Size = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 0.25
        t.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
        t.Text = string.format("⚠ เส้นตาย %s=%.0f\nข้ามเส้นนี้เสี่ยง HP=0", L.axis, L.value)
        t.TextColor3 = Color3.fromRGB(255, 200, 200)
        t.Font = Enum.Font.GothamBold
        t.TextSize = 13
        t.TextWrapped = true
        Instance.new("UICorner", t).CornerRadius = UDim.new(0, 6)

        say(string.format("ESP เส้นตาย: %s=%.1f ช่วง %.0f..%.0f (%d จุด)",
            L.axis, L.value, L.lo, L.hi, #S.deaths))
    else
        say("ยังไม่มีจุดตาย — เปิด WATCH หรือใช้ SEED")
    end
end

local function addDeath(pos, src)
    -- ไม่ซ้ำจุดใกล้กัน < 15
    for _, d in ipairs(S.deaths) do
        if (d - pos).Magnitude < 15 then return false end
    end
    S.deaths[#S.deaths + 1] = pos
    say(string.format("+จุดตาย#%d %s (%.0f,%.0f,%.0f)", #S.deaths, src or "", pos.X, pos.Y, pos.Z))
    redrawESP()
    return true
end

local function loadSeeds()
    for _, p in ipairs(SEED_DEATHS) do
        addDeath(p, "SEED")
    end
end

-- เตือนเมื่อใกล้เส้น
local function setWarn(on)
    if S.warnConn then pcall(function() S.warnConn:Disconnect() end); S.warnConn = nil end
    if not on then return end
    local lastSay = 0
    S.warnConn = RunS.Heartbeat:Connect(function()
        if not S.killLine then return end
        local _, r = hr()
        if not r then return end
        local d = distToKillLine(r.Position)
        if d <= WARN_DIST and (os.clock() - lastSay) > 1.2 then
            lastSay = os.clock()
            local L = S.killLine
            local side
            if L.axis == "Z" then
                side = r.Position.Z < L.value and "เหนือเส้น(ปลอดภัยกว่า?)" or "ใต้/ข้ามเส้น(อันตราย)"
            else
                side = r.Position.X < L.value and "ซ้ายเส้น" or "ขวาเส้น"
            end
            say(string.format("⚠ ใกล้เส้นตาย %.0f studs | %s=%.0f | คุณ%s",
                d, L.axis, L.value, side))
        end
    end)
end

-- สแกนตาราง (ย่อ — EDGE ใกล้ตัว)
local function scanVoidGrid(origin)
    ensureFolders()
    clearScanMarks()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excl = { LP.Character, S.folder, S.espFolder }
    params.FilterDescendantsInstances = excl

    local half = math.floor(RADIUS / STEP)
    local grid = {}
    local voids, edges = {}, {}

    for ix = -half, half do
        grid[ix] = {}
        for iz = -half, half do
            local x = origin.X + ix * STEP
            local z = origin.Z + iz * STEP
            local hit = workspace:Raycast(Vector3.new(x, origin.Y + 80, z), Vector3.new(0, -400, 0), params)
            grid[ix][iz] = hit and hit.Position.Y or false
            if not hit then voids[#voids + 1] = Vector3.new(x, origin.Y, z) end
        end
    end
    for ix = -half, half do
        for iz = -half, half do
            if grid[ix][iz] then
                local near = false
                for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                    local nx, nz = ix + o[1], iz + o[2]
                    if grid[nx] and grid[nx][nz] == false then near = true; break end
                end
                if near then
                    edges[#edges + 1] = Vector3.new(origin.X + ix * STEP, grid[ix][iz], origin.Z + iz * STEP)
                end
            end
        end
    end
    local shown = 0
    for _, e in ipairs(edges) do
        if shown >= 40 then break end
        markAt(S.folder, e, Color3.fromRGB(255, 160, 40), "EDGE", Vector3.new(STEP * 0.7, 1.5, STEP * 0.7))
        shown = shown + 1
    end
    return voids, edges
end

local function runScan()
    local _, r = hr()
    if not r then say("ไม่มีตัว"); return end
    S.run = true
    say(string.format("=== SCAN EDGE @ (%.0f,%.0f,%.0f) ===", r.Position.X, r.Position.Y, r.Position.Z))
    task.spawn(function()
        local voids, edges = scanVoidGrid(r.Position)
        say(string.format("VOID=%d EDGE=%d (ส้ม=ขอบตก — แดง ESP=เส้นตายจาก HP)", #voids, #edges))
        table.sort(edges, function(a, b)
            return (a - r.Position).Magnitude < (b - r.Position).Magnitude
        end)
        for i = 1, math.min(5, #edges) do
            local e = edges[i]
            say(string.format("  EDGE#%d d=%.0f (%.0f,%.0f,%.0f)", i, (e - r.Position).Magnitude, e.X, e.Y, e.Z))
        end
        S.run = false
    end)
end

local function setWatch(on)
    if S.hpConn then pcall(function() S.hpConn:Disconnect() end); S.hpConn = nil end
    S.watch = on and true or false
    if not on then say("WATCH HP=OFF"); return end
    say("WATCH HP=ON — ตายแล้วปัก ESP + อัปเดตเส้น")
    local lastHp = nil
    local function bind(hum)
        if not hum then return end
        lastHp = hum.Health
        S.hpConn = hum.HealthChanged:Connect(function(hp)
            local _, r = hr()
            if not r then return end
            if (lastHp and hp <= 0 and lastHp > 0) or (hp <= 0 and lastHp and lastHp > 0) then
                say(string.format("☠ HP=0 @ (%.0f,%.0f,%.0f)", r.Position.X, r.Position.Y, r.Position.Z))
                addDeath(r.Position, "WATCH")
            elseif lastHp and hp < lastHp - 20 and hp > 0 then
                say(string.format("⚠ HP %.0f→%.0f @ (%.0f,%.0f,%.0f)", lastHp, hp, r.Position.X, r.Position.Y, r.Position.Z))
            end
            lastHp = hp
        end)
    end
    bind(select(1, hr()))
    LP.CharacterAdded:Connect(function(ch)
        task.wait(0.4)
        if S.watch then
            if S.hpConn then pcall(function() S.hpConn:Disconnect() end) end
            bind(ch:FindFirstChildOfClass("Humanoid"))
        end
    end)
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_KillZone"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1030
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui

local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 480, 0, 310)
f.Position = UDim2.new(0, 12, 0.32, 0)
f.BackgroundColor3 = Color3.fromRGB(30, 22, 28)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -12, 0, 24)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 KillZone v2 — ESP เส้นตาย / จุด HP=0"
title.TextColor3 = Color3.fromRGB(255, 140, 140)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local function button(t, x, y, w, c)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, y)
    b.Text = t
    b.BackgroundColor3 = c
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bEsp = button("ESP เส้น", 10, 34, 72, Color3.fromRGB(180, 40, 50))
local bWatch = button("WATCH HP", 88, 34, 80, Color3.fromRGB(120, 70, 40))
local bScan = button("SCAN EDGE", 174, 34, 84, Color3.fromRGB(140, 80, 40))
local bClear = button("CLEAR", 264, 34, 56, Color3.fromRGB(70, 70, 80))
local bCopy = button("COPY", 326, 34, 56, Color3.fromRGB(75, 75, 80))
local bX = button("X", 388, 34, 36, Color3.fromRGB(90, 40, 40))

local hint = Instance.new("TextLabel", f)
hint.Size = UDim2.new(1, -16, 0, 40)
hint.Position = UDim2.new(0, 10, 0, 66)
hint.BackgroundTransparency = 1
hint.Text = "ESP เส้น = กำแพงแดงตามจุดตาย (ข้าม = อันตราย) | WATCH เก็บจุดใหม่\nใกล้เส้น <50 studs จะเตือนในล็อก"
hint.TextColor3 = Color3.fromRGB(210, 190, 200)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top

logBox = Instance.new("TextLabel", f)
logBox.Size = UDim2.new(1, -16, 0, 185)
logBox.Position = UDim2.new(0, 8, 0, 110)
logBox.BackgroundColor3 = Color3.new(0, 0, 0)
logBox.BackgroundTransparency = 0.2
logBox.TextColor3 = Color3.fromRGB(255, 200, 200)
logBox.Font = Enum.Font.Code
logBox.TextSize = 10
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.TextWrapped = true
logBox.ClipsDescendants = true

bEsp.MouseButton1Click:Connect(function()
    if #S.deaths == 0 then loadSeeds() else redrawESP() end
    setWarn(true)
end)

bWatch.MouseButton1Click:Connect(function()
    setWatch(not S.watch)
    bWatch.Text = S.watch and "WATCH ON" or "WATCH HP"
    bWatch.BackgroundColor3 = S.watch and Color3.fromRGB(40, 130, 70) or Color3.fromRGB(120, 70, 40)
    if S.watch then setWarn(true) end
end)

bScan.MouseButton1Click:Connect(function()
    if S.run then say("กำลังสแกน"); return end
    runScan()
end)

bClear.MouseButton1Click:Connect(function()
    clearScanMarks()
    clearESP()
    say("ลบมาร์ค/ESP แล้ว (จุดตายในหน่วยความจำยังอยู่ — กด ESP เส้น วาดใหม่)")
end)

bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then
        local extra = {}
        for i, p in ipairs(S.deaths) do
            extra[#extra + 1] = string.format("death#%d (%.1f,%.1f,%.1f)", i, p.X, p.Y, p.Z)
        end
        if S.killLine then
            extra[#extra + 1] = string.format("line %s=%.1f", S.killLine.axis, S.killLine.value)
        end
        pcall(c, "=== Egg01 KillZone v2 ===\n" .. table.concat(S.lines, "\n") .. "\n---\n" .. table.concat(extra, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)

bX.MouseButton1Click:Connect(function()
    S.run = false
    setWatch(false)
    setWarn(false)
    clearScanMarks()
    clearESP()
    pcall(function() gui:Destroy() end)
end)

ensureFolders()
loadSeeds()
setWarn(true)
say("v2 โหลด SEED ตาย 2 จุด → เส้น Z≈-452")
say("กด ESP เส้น ถ้ายังไม่เห็นกำแพง | WATCH เก็บจุดเพิ่ม")
