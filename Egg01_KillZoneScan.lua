-- Egg01 KillZone Scan v1.0 — หาจุดที่ทำให้ HP=0 / ตกแมพ / Kill part
-- สแกน: (1) ส่วนชื่อ Kill/Void/Damage (2) เรย์พื้นเป็นตาราง — ไม่มีพื้น=void
-- (3) เฝ้า HP แล้วจำพิกัดตอนเลือดลดฉับพลัน

if _G.EGG01_KILLZONE then
    _G.EGG01_KILLZONE.run = false
    pcall(function()
        if _G.EGG01_KILLZONE.hpConn then _G.EGG01_KILLZONE.hpConn:Disconnect() end
    end)
    pcall(function() _G.EGG01_KILLZONE.gui:Destroy() end)
    pcall(function()
        if _G.EGG01_KILLZONE.folder then _G.EGG01_KILLZONE.folder:Destroy() end
    end)
end

local Players = game:GetService("Players")
local RunS = game:GetService("RunService")
local LP = Players.LocalPlayer

local S = {
    run = false, gui = nil, lines = {}, hits = {},
    hpConn = nil, folder = nil, watch = false,
}
_G.EGG01_KILLZONE = S

local logBox
-- รัศมีสแกนรอบตัว (studs) / ช่องตาราง
local RADIUS = 400
local STEP = 25
local VOID_Y = -50 -- ต่ำกว่านี้ถือว่า void ถ้าไม่มีพื้น

local BAD_NAME = {
    kill = true, death = true, die = true, void = true, damage = true,
    deadly = true, lava = true, pit = true, fall = true, border = true,
    barrier = true, outofbounds = true, oob = true, reset = true,
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

local function clearMarks()
    if S.folder then pcall(function() S.folder:Destroy() end) end
    S.folder = Instance.new("Folder")
    S.folder.Name = "Egg01_KillMarks"
    S.folder.Parent = workspace
end

local function markAt(pos, color, label)
    local p = Instance.new("Part")
    p.Name = label or "KZ"
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.Size = Vector3.new(STEP * 0.85, 1.2, STEP * 0.85)
    p.Position = pos + Vector3.new(0, 1, 0)
    p.Color = color
    p.Material = Enum.Material.Neon
    p.Transparency = 0.35
    p.Parent = S.folder

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 28)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Parent = p
    local t = Instance.new("TextLabel", bb)
    t.Size = UDim2.new(1, 0, 1, 0)
    t.BackgroundTransparency = 1
    t.Text = label or "?"
    t.TextColor3 = Color3.new(1, 1, 1)
    t.TextStrokeTransparency = 0.4
    t.Font = Enum.Font.GothamBold
    t.TextSize = 11
    return p
end

local function nameBad(n)
    n = string.lower(tostring(n or ""))
    for k in pairs(BAD_NAME) do
        if string.find(n, k, 1, true) then return true end
    end
    return false
end

-- (1) สแกน Instance ชื่อน่าสงสัย + TouchTransmitter ใกล้ทาง
local function scanNamed(origin)
    local n = 0
    local list = {}
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("BasePart") and nameBad(inst.Name) then
            local d = (inst.Position - origin).Magnitude
            if d <= RADIUS * 1.5 then
                n = n + 1
                list[#list + 1] = { p = inst.Position, d = d, name = inst.Name, kind = "NAME" }
                if n <= 40 then
                    markAt(inst.Position, Color3.fromRGB(220, 40, 40), "KILL:" .. inst.Name)
                end
            end
        elseif inst:IsA("BasePart") and (nameBad(inst.Parent and inst.Parent.Name) or nameBad(inst:GetFullName())) then
            local d = (inst.Position - origin).Magnitude
            if d <= RADIUS and n < 60 then
                n = n + 1
                list[#list + 1] = { p = inst.Position, d = d, name = inst:GetFullName(), kind = "PATH" }
            end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    return list
end

-- (2) เรย์ลงพื้นเป็นตาราง — ไม่โดน = VOID / ขอบแมพ
local function scanVoidGrid(origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if LP.Character then params.FilterDescendantsInstances = { LP.Character, S.folder } end

    local voids = {}
    local edges = {} -- มีพื้นแต่ Y ต่ำกว่า origin มาก หรืออยู่ขอบ (เพื่อนบ้านเป็น void)

    local half = math.floor(RADIUS / STEP)
    local grid = {} -- [ix][iz] = hitY or false

    for ix = -half, half do
        grid[ix] = {}
        for iz = -half, half do
            local x = origin.X + ix * STEP
            local z = origin.Z + iz * STEP
            local from = Vector3.new(x, origin.Y + 80, z)
            local hit = workspace:Raycast(from, Vector3.new(0, -400, 0), params)
            if hit then
                grid[ix][iz] = hit.Position.Y
            else
                grid[ix][iz] = false
                voids[#voids + 1] = Vector3.new(x, origin.Y, z)
            end
        end
    end

    -- ขอบ: ช่องที่มีพื้น แต่ข้างๆ เป็น void
    for ix = -half, half do
        for iz = -half, half do
            local y = grid[ix][iz]
            if y then
                local nearVoid = false
                for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                    local nx, nz = ix + o[1], iz + o[2]
                    if grid[nx] and grid[nx][nz] == false then
                        nearVoid = true
                        break
                    end
                end
                if nearVoid or y < VOID_Y then
                    edges[#edges + 1] = Vector3.new(origin.X + ix * STEP, y, origin.Z + iz * STEP)
                end
            end
        end
    end

    -- มาร์ค void (แดงอ่อน) จำกัดจำนวน
    local shown = 0
    for _, v in ipairs(voids) do
        if shown >= 80 then break end
        markAt(v, Color3.fromRGB(180, 30, 80), "VOID")
        shown = shown + 1
    end
    shown = 0
    for _, e in ipairs(edges) do
        if shown >= 60 then break end
        markAt(e, Color3.fromRGB(255, 160, 40), "EDGE")
        shown = shown + 1
    end

    return voids, edges
end

local function runScan()
    local h, r = hr()
    if not r then say("ไม่มีตัว"); return end
    S.run = true
    clearMarks()
    S.hits = {}
    local origin = r.Position
    say(string.format("=== SCAN r=%d step=%d @ (%.0f,%.0f,%.0f) ===",
        RADIUS, STEP, origin.X, origin.Y, origin.Z))

    task.spawn(function()
        local named = scanNamed(origin)
        say(string.format("ชื่อ Kill/Void ใกล้ๆ: %d", #named))
        for i = 1, math.min(8, #named) do
            local x = named[i]
            say(string.format("  #%d %s d=%.0f (%.0f,%.0f,%.0f)",
                i, x.name, x.d, x.p.X, x.p.Y, x.p.Z))
            S.hits[#S.hits + 1] = x
        end

        local voids, edges = scanVoidGrid(origin)
        say(string.format("VOID ช่องไม่มีพื้น: %d | EDGE ขอบตกได้: %d", #voids, #edges))
        -- ขอบใกล้ตัวสุด 5 จุด
        table.sort(edges, function(a, b)
            return (a - origin).Magnitude < (b - origin).Magnitude
        end)
        for i = 1, math.min(5, #edges) do
            local e = edges[i]
            say(string.format("  EDGE#%d d=%.0f (%.0f,%.0f,%.0f)",
                i, (e - origin).Magnitude, e.X, e.Y, e.Z))
            S.hits[#S.hits + 1] = { p = e, d = (e - origin).Magnitude, name = "EDGE", kind = "EDGE" }
        end
        say("มาร์ค: แดง=KILLชื่อ | ส้ม=EDGE | ม่วง=VOID — กด CLEAR ลบ")
        S.run = false
    end)
end

local function setWatch(on)
    if S.hpConn then pcall(function() S.hpConn:Disconnect() end); S.hpConn = nil end
    S.watch = on and true or false
    if not on then say("WATCH HP=OFF"); return end
    say("WATCH HP=ON — เลือดลด/ตายจะจำพิกัด")
    local lastHp = nil
    local function bind(hum)
        if not hum then return end
        lastHp = hum.Health
        S.hpConn = hum.HealthChanged:Connect(function(hp)
            local _, r = hr()
            if not r then return end
            if lastHp and hp < lastHp - 5 then
                say(string.format("⚠ HP %.0f→%.0f @ (%.0f,%.0f,%.0f)",
                    lastHp, hp, r.Position.X, r.Position.Y, r.Position.Z))
                markAt(r.Position, Color3.fromRGB(255, 0, 0), string.format("HP%.0f", hp))
                S.hits[#S.hits + 1] = {
                    p = r.Position, d = 0, name = "HP_DROP", kind = "WATCH",
                }
            end
            if hp <= 0 then
                say(string.format("☠ HP=0 @ (%.0f,%.0f,%.0f)",
                    r.Position.X, r.Position.Y, r.Position.Z))
                markAt(r.Position, Color3.fromRGB(255, 255, 0), "HP0")
            end
            lastHp = hp
        end)
    end
    local h = select(1, hr())
    bind(h)
    LP.CharacterAdded:Connect(function(ch)
        task.wait(0.5)
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
f.Size = UDim2.new(0, 460, 0, 300)
f.Position = UDim2.new(0, 12, 0.35, 0)
f.BackgroundColor3 = Color3.fromRGB(30, 22, 28)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -12, 0, 24)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 KillZone Scan v1 — VOID/EDGE/Kill"
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
    b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bScan = button("SCAN", 10, 34, 70, Color3.fromRGB(160, 50, 60))
local bWatch = button("WATCH HP", 86, 34, 88, Color3.fromRGB(120, 70, 40))
local bClear = button("CLEAR", 180, 34, 64, Color3.fromRGB(70, 70, 80))
local bCopy = button("COPY", 250, 34, 64, Color3.fromRGB(75, 75, 80))
local bX = button("X", 320, 34, 40, Color3.fromRGB(90, 40, 40))

local hint = Instance.new("TextLabel", f)
hint.Size = UDim2.new(1, -16, 0, 36)
hint.Position = UDim2.new(0, 10, 0, 66)
hint.BackgroundTransparency = 1
hint.Text = "ยืนใกล้คอก/ทางวิ่ง → SCAN | ม่วง=ไม่มีพื้น ส้ม=ขอบตก แดง=ชื่อKill\nWATCH HP = จำพิกัดตอนเลือดลด/ตาย"
hint.TextColor3 = Color3.fromRGB(210, 190, 200)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top

logBox = Instance.new("TextLabel", f)
logBox.Size = UDim2.new(1, -16, 0, 180)
logBox.Position = UDim2.new(0, 8, 0, 108)
logBox.BackgroundColor3 = Color3.new(0, 0, 0)
logBox.BackgroundTransparency = 0.2
logBox.TextColor3 = Color3.fromRGB(255, 200, 200)
logBox.Font = Enum.Font.Code
logBox.TextSize = 10
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.TextWrapped = true
logBox.ClipsDescendants = true

bScan.MouseButton1Click:Connect(function()
    if S.run then say("กำลังสแกน"); return end
    runScan()
end)

bWatch.MouseButton1Click:Connect(function()
    setWatch(not S.watch)
    bWatch.Text = S.watch and "WATCH ON" or "WATCH HP"
    bWatch.BackgroundColor3 = S.watch and Color3.fromRGB(40, 130, 70) or Color3.fromRGB(120, 70, 40)
end)

bClear.MouseButton1Click:Connect(function()
    clearMarks()
    say("ลบมาร์คแล้ว")
end)

bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then
        pcall(c, "=== Egg01 KillZone Scan ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)

bX.MouseButton1Click:Connect(function()
    S.run = false
    setWatch(false)
    clearMarks()
    pcall(function() gui:Destroy() end)
end)

say("v1 ยืนจุดที่สงสัย (ขอบคอกในรูป) → SCAN")
say("หรือเปิด WATCH HP แล้ววิ่งทางเดิม ดูพิกัดตอนตาย")
