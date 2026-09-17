-- Egg01_ZoneSpy.lua v1.1 — spy โซนมอน: ทิ้งในโซนแล้วไข่วาปกลับ nest ไหม?
-- v1.1: แก้ชื่อ remote จริง `RE/EggWorld/FieldEggCarry` (เมื่อก่อน match ไม่ติด)
-- วิธีใช้:
--   1) ขโมยไข่ก่อน (ต้องเห็น 🎒 CARRY) → NEST จับเอง
--   2) ออกนอกโซนมอน → DROP / ปุ่มทิ้งเกม
--   3) ดู SAFE_DROP vs NEST_RECALL → COPY
if _G.EGG01ZS_GUI then pcall(function() _G.EGG01ZS_GUI:Destroy() end) end
if _G.EGG01ZS_CONNS then
    for _, c in pairs(_G.EGG01ZS_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.EGG01ZS_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local OUT, T0 = {}, os.clock()
local PAUSED = false
local MAXLINES = 450

local carry = {
    on = false,
    uid = nil,
    area = nil,
    nestCf = nil,   -- BottomCFrame ตอน Carried แรก
    nestPos = nil,
}
local lastDrop = nil -- { pos, t, uid }
local homePos = nil

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01ZoneSpy"; gui.ResetOnSpawn = false
gui.DisplayOrder = 55
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01ZS_GUI = gui

local bar = Instance.new("Frame", gui)
bar.Size = UDim2.new(0, 460, 0, 34)
bar.Position = UDim2.new(1, -468, 0, 8)
bar.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
bar.BackgroundTransparency = 0.15
bar.BorderSizePixel = 0

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 560, 0, 240)
box.Position = UDim2.new(0, 8, 1, -248)
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.18
box.TextColor3 = Color3.fromRGB(220, 230, 255)
box.TextSize = 11
box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true
box.MultiLine = true
box.ClearTextOnFocus = false
box.TextEditable = false
box.Active = false

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    if PAUSED then return end
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > MAXLINES then table.remove(OUT, 1) end
    redraw()
end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", bar)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, 3)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BackgroundColor3 = col or Color3.fromRGB(50, 80, 140)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    return b
end
local markH = hbtn("HOME", 4, 48, Color3.fromRGB(40, 120, 70))
local markN = hbtn("NEST", 54, 48, Color3.fromRGB(120, 90, 40))
local dropB = hbtn("DROP", 104, 48, Color3.fromRGB(140, 60, 40))
local scanB = hbtn("ZONES", 154, 56, Color3.fromRGB(60, 90, 130))
local clearB = hbtn("CLR", 212, 40, Color3.fromRGB(80, 60, 40))
local copyB = hbtn("COPY", 254, 52)
local pauseB = hbtn("PAUSE", 308, 52, Color3.fromRGB(90, 90, 40))
local closeB = hbtn("✕", 362, 28, Color3.fromRGB(150, 40, 40))
bar.Size = UDim2.new(0, 398, 0, 34)
bar.Position = UDim2.new(1, -406, 0, 8)

local function hrp()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end
local function posStr(p)
    if not p then return "?" end
    return ("%.0f,%.0f,%.0f"):format(p.X, p.Y, p.Z)
end
local function dist(a, b)
    if not a or not b then return -1 end
    return (a - b).Magnitude
end

local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "table" then
        if depth > 2 then return "{...}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n += 1
            if n > 12 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. ser(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "Instance" then
        return "<" .. v.ClassName .. ":" .. v.Name .. ">"
    elseif t == "CFrame" then
        return ("CF(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "Vector3" then
        return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "string" then
        return '"' .. (v:len() > 50 and v:sub(1, 50) .. "…" or v) .. '"'
    end
    return tostring(v)
end

local function short(inst)
    local ok, f = pcall(function() return inst:GetFullName() end)
    if not ok then return "?" end
    return f:gsub("^ReplicatedStorage%.", "RS."):gsub("^Workspace%.", "WS.")
        :gsub("^Players%.[^%.]+%.PlayerGui%.", "PG.")
end

-- วิเคราะห์หลัง drop: ไข่อยู่ใกล้จุดทิ้ง หรือกลับ nest
local function judgeEggPos(eggPos, state)
    local r = hrp()
    local my = r and r.Position
    local dNest = dist(eggPos, carry.nestPos)
    local dDrop = lastDrop and dist(eggPos, lastDrop.pos) or -1
    local dMe = dist(eggPos, my)

    if state == "Dropped" and dNest >= 0 and dNest < 25 then
        L(("⛔ NEST_RECALL egg@%s nestDist=%.0f dropDist=%.0f — ทิ้งในโซนมอน/ยังไม่ออก"):format(
            posStr(eggPos), dNest, dDrop))
        if lastDrop then
            L(("   dropPlayer@%s | nest@%s | area=%s"):format(
                posStr(lastDrop.pos), posStr(carry.nestPos), tostring(carry.area)))
        end
        return "NEST_RECALL"
    end
    if state == "Dropped" and dDrop >= 0 and dDrop < 40 then
        L(("✅ SAFE_DROP egg@%s dropDist=%.0f nestDist=%.0f meDist=%.0f"):format(
            posStr(eggPos), dDrop, dNest, dMe))
        if lastDrop then
            L(("   SAFE point player@%s area=%s uid=%s"):format(
                posStr(lastDrop.pos), tostring(carry.area), tostring(carry.uid)))
        end
        return "SAFE_DROP"
    end
    L(("❓ egg state=%s @%s nestDist=%.0f dropDist=%.0f"):format(
        tostring(state), posStr(eggPos), dNest, dDrop))
    return "UNKNOWN"
end

local function onCarry(tbl)
    if typeof(tbl) ~= "table" then return end
    if tbl.IsCarrying == true then
        carry.on = true
        carry.uid = tbl.Uid or carry.uid
        carry.area = tbl.AreaId or carry.area
        local r = hrp()
        L(("🎒 CARRY on uid=%s area=%s me@%s speedMul=%s"):format(
            tostring(carry.uid), tostring(carry.area), posStr(r and r.Position),
            tostring(tbl.SpeedMultiplier)))
    elseif tbl.IsCarrying == false then
        carry.on = false
        local r = hrp()
        lastDrop = { pos = r and r.Position, t = os.clock(), uid = carry.uid }
        L(("📥 CARRY off me@%s (รอ FieldEggShifted ตัดสิน SAFE/RECALL)"):format(posStr(lastDrop.pos)))
    end
end

local function onShifted(tbl)
    if typeof(tbl) ~= "table" then return end
    local state = tbl.State
    local bottom = tbl.BottomCFrame or tbl.BoundsCFrame
    local eggPos = typeof(bottom) == "CFrame" and bottom.Position
        or (typeof(bottom) == "Vector3" and bottom)

    if state == "Carried" then
        carry.on = true
        carry.uid = tbl.Uid or carry.uid
        carry.area = tbl.AreaId or carry.area
        if eggPos and not carry.nestPos then
            -- ตำแหน่ง nest ตอนยกครั้งแรก (ใกล้ nest จริง)
            carry.nestCf = bottom
            carry.nestPos = eggPos
            L(("📌 auto NEST from first Carried @%s area=%s nestId=%s"):format(
                posStr(eggPos), tostring(tbl.AreaId), tostring(tbl.NestId)))
        end
    elseif state == "Dropped" and eggPos then
        task.defer(function()
            task.wait(0.15)
            judgeEggPos(eggPos, "Dropped")
        end)
    else
        L(("← Shifted state=%s uid=%s @%s"):format(
            tostring(state), tostring(tbl.Uid), posStr(eggPos)))
    end
end

-- ฟัง RE
task.spawn(function()
    local net = RS:FindFirstChild("Packages")
    net = net and net:FindFirstChild("Networking")
    if not net then L("❌ ไม่เจอ Networking") return end

    local function bind(d)
        local nm = d.Name
        local path = short(d)
        if nm:find("FieldEggCarry", 1, true) or path:find("FieldEggCarry", 1, true) then
            table.insert(_G.EGG01ZS_CONNS, d.OnClientEvent:Connect(function(a, ...)
                if typeof(a) == "table" then onCarry(a)
                else L(("← Carry(%s)"):format(ser(a))) end
            end))
            L("ฟัง Carry ← " .. path)
        elseif nm:find("FieldEggShifted", 1, true) or path:find("FieldEggShifted", 1, true) then
            table.insert(_G.EGG01ZS_CONNS, d.OnClientEvent:Connect(function(a, ...)
                if typeof(a) == "table" then onShifted(a)
                else L(("← Shifted(%s)"):format(ser(a))) end
            end))
            L("ฟัง Shifted ← " .. path)
        elseif nm:find("Guard", 1, true) or nm:find("Zone", 1, true)
            or nm:find("FieldEggGone", 1, true) or nm:find("FieldEggBatch", 1, true) then
            table.insert(_G.EGG01ZS_CONNS, d.OnClientEvent:Connect(function(...)
                local n = select("#", ...)
                local parts = {}
                for i = 1, math.min(n, 4) do parts[i] = ser(select(i, ...)) end
                L(("← %s(%s)"):format(nm, table.concat(parts, ", ")))
            end))
        end
    end

    for _, d in ipairs(net:GetDescendants()) do
        if d:IsA("RemoteEvent") then bind(d) end
    end
    table.insert(_G.EGG01ZS_CONNS, net.DescendantAdded:Connect(function(d)
        if d:IsA("RemoteEvent") then task.defer(bind, d) end
    end))
end)

-- กด DropHeldEgg ของเกม
local function hookDropGui()
    local dropGui = PG:FindFirstChild("DropHeldEgg")
    local btn = dropGui and (dropGui:FindFirstChild("Button", true) or dropGui:FindFirstChildWhichIsA("GuiButton", true))
    if btn then
        table.insert(_G.EGG01ZS_CONNS, btn.Activated:Connect(function()
            local r = hrp()
            lastDrop = { pos = r and r.Position, t = os.clock(), uid = carry.uid }
            L(("🖱 DropHeldEgg @%s nestDist=%.0f area=%s"):format(
                posStr(lastDrop.pos), dist(lastDrop.pos, carry.nestPos), tostring(carry.area)))
        end))
        L("hook PG.DropHeldEgg.Button ✅")
    else
        L("⚠ ยังไม่เจอ DropHeldEgg — ถือไข่ก่อนจะมีปุ่ม")
        table.insert(_G.EGG01ZS_CONNS, PG.ChildAdded:Connect(function(ch)
            if ch.Name == "DropHeldEgg" then
                task.wait(0.1)
                hookDropGui()
            end
        end))
    end
end
hookDropGui()

-- สแกนโซนใน workspace
local function scanZones()
    local r = hrp()
    L("=== SCAN zones/areas ใกล้ตัว ===")
    local keys = { "zone", "area", "biome", "forest", "guard", "nest", "territory", "safe" }
    local hits = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Folder") or d:IsA("Model") then
            local nl = d.Name:lower()
            local hit = false
            for _, k in ipairs(keys) do
                if nl:find(k, 1, true) then hit = true break end
            end
            if hit then
                local part = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true)
                local p = part and part.Position
                local dd = r and p and (p - r.Position).Magnitude or 99999
                if dd < 400 then
                    hits[#hits + 1] = { d = d, dist = dd, part = part }
                end
            end
        end
    end
    table.sort(hits, function(a, b) return a.dist < b.dist end)
    for i, h in ipairs(hits) do
        if i > 30 then L("...") break end
        L(("  %s d=%.0f @%s %s"):format(
            h.d.ClassName, h.dist, posStr(h.part and h.part.Position), short(h.d)))
    end
    L("=== รวม " .. #hits .. " (รัศมี 400) | me@" .. posStr(r and r.Position) .. " ===")
    if carry.nestPos then L("nest@" .. posStr(carry.nestPos) .. " area=" .. tostring(carry.area)) end
    if homePos then L("home@" .. posStr(homePos)) end
end

local function fireDrop()
    local dropGui = PG:FindFirstChild("DropHeldEgg")
    local btn = dropGui and (dropGui:FindFirstChild("Button", true) or dropGui:FindFirstChildWhichIsA("GuiButton", true))
    local r = hrp()
    lastDrop = { pos = r and r.Position, t = os.clock(), uid = carry.uid }
    L(("DROP btn @%s nestDist=%.0f"):format(posStr(lastDrop.pos), dist(lastDrop.pos, carry.nestPos)))
    if btn then
        pcall(function()
            if firesignal then firesignal(btn.Activated) end
            btn.Activated:Fire()
        end)
        pcall(function()
            if getconnections then
                for _, c in ipairs(getconnections(btn.Activated)) do
                    pcall(function() c:Fire() end)
                end
            end
        end)
    else
        L("❌ ไม่มีปุ่ม DropHeldEgg (ถือไข่อยู่ไหม?)")
    end
end

markH.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then return end
    homePos = r.Position
    L("🏠 HOME mark @" .. posStr(homePos))
end)
markN.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then return end
    carry.nestPos = r.Position
    L("📌 NEST mark (มือ) @" .. posStr(carry.nestPos))
end)
dropB.MouseButton1Click:Connect(fireDrop)
scanB.MouseButton1Click:Connect(scanZones)
clearB.MouseButton1Click:Connect(function() OUT = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = ("=== Egg01 ZoneSpy ===\nTime: %s\nPlaceId: %s\nHome: %s\nNest: %s\nArea: %s\n\n%s")
        :format(os.date("%Y-%m-%d %H:%M:%S"), tostring(game.PlaceId),
            posStr(homePos), posStr(carry.nestPos), tostring(carry.area),
            table.concat(OUT, "\n"))
    local clip = setclipboard or toclipboard
    local ok = clip and pcall(clip, text)
    pcall(function() if writefile then writefile("Egg01_zone_log.txt", text) end end)
    copyB.Text = ok and "OK!" or "?"
    task.delay(1.2, function() if copyB.Parent then copyB.Text = "COPY" end end)
end)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
end)
closeB.MouseButton1Click:Connect(function()
    if _G.EGG01ZS_CONNS then
        for _, c in pairs(_G.EGG01ZS_CONNS) do pcall(function() c:Disconnect() end) end
    end
    gui:Destroy(); _G.EGG01ZS_GUI = nil
end)

L("Egg01 ZoneSpy v1.1")
L("สำคัญ: ขโมยไข่ให้ขึ้น 🎒 CARRY ก่อน แล้วค่อย DROP")
L("steal → ออกนอกโซน → DROP → ดู SAFE/RECALL | HOME/NEST/ZONES")
