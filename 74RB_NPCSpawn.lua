-- 74RB_NPCSpawn.lua v1.0 — เสก NPC (client-side เห็นคนเดียว) นอนเตียง/นั่ง/ยืน
-- แม่แบบจาก ReplicatedStorage.NPCs (NetDump ยืนยัน) — server ไม่รู้จักตัวที่เสก รักษา/เช็คอินไม่ได้จริง
-- ปุ่ม: เลือกตัว → [นอนเตียงใกล้สุด] [นั่งตรงที่เล็ง] [ยืนตรงที่เล็ง] [ลบทั้งหมด]

if _G.NPCSPAWN_CONNS then
    for _, c in pairs(_G.NPCSPAWN_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.NPCSPAWN_MOBS then
    for _, m in pairs(_G.NPCSPAWN_MOBS) do pcall(function() m:Destroy() end) end
end
_G.NPCSPAWN_CONNS, _G.NPCSPAWN_MOBS = {}, {}
local CONNS, MOBS = _G.NPCSPAWN_CONNS, _G.NPCSPAWN_MOBS

local RSt = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- รวมแม่แบบทั้งหมด
local SRC = {}
local npcs = RSt:FindFirstChild("NPCs")
if npcs then
    for _, folder in ipairs({"UniqueVisitors", "Visitors"}) do
        local f = npcs:FindFirstChild(folder)
        if f then for _, m in ipairs(f:GetChildren()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then SRC[#SRC + 1] = m end
        end end
    end
    local d = npcs:FindFirstChild("Dummy")
    if d then SRC[#SRC + 1] = d end
end
if #SRC == 0 then warn("[NPCSpawn] ไม่เจอแม่แบบ"); return end
local pick = 1

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function spawnAt(cf, pose)
    local src = SRC[pick]
    local m = src:Clone()
    m.Name = src.Name
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
        if p:IsA("Script") or p:IsA("LocalScript") then p:Destroy() end
    end
    local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
    if not r then m:Destroy(); return end
    m.PrimaryPart = r
    if pose == "lie" then
        -- นอนหงาย: หมุนรอบแกน X 90° ยกขึ้นกันจมเตียง
        m:PivotTo(cf * CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
    elseif pose == "sit" then
        local hum = m:FindFirstChildOfClass("Humanoid")
        m:PivotTo(cf * CFrame.new(0, 0.5, 0))
        if hum then pcall(function() hum.Sit = true end) end
    else
        m:PivotTo(cf)
    end
    m.Parent = workspace:FindFirstChild("NPCs") or workspace
    MOBS[#MOBS + 1] = m
end

-- หาเตียงใกล้สุด: part ที่มี PP 'Place Patient' หรือชื่อมี Bed ใต้ Rooms
local function nearestBed()
    local me = hrp()
    if not me then return end
    local best, bd
    local rooms = workspace:FindFirstChild("Rooms")
    if rooms then
        for _, o in ipairs(rooms:GetDescendants()) do
            local isBed = (o:IsA("ProximityPrompt") and o.ActionText == "Place Patient" and o.Parent)
                and o.Parent or (o:IsA("BasePart") and o.Name:lower():find("bed") and o)
            if isBed then
                local p = isBed:IsA("Model") and isBed:GetPivot().Position or isBed.Position
                local d = (p - me.Position).Magnitude
                if not bd or d < bd then best, bd = isBed, d end
            end
        end
    end
    if best then
        local pos = best:IsA("Model") and best:GetPivot().Position or best.Position
        local look = best:IsA("BasePart") and best.CFrame.LookVector or Vector3.new(0, 0, -1)
        return CFrame.lookAt(pos, pos + look)
    end
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "NPCSpawn"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 150, 0, 196); f.Position = UDim2.new(0, 8, 0.62, 0)
f.BackgroundColor3 = Color3.fromRGB(25, 25, 32); f.BackgroundTransparency = 0.15
f.Active = true; f.Draggable = true
local function btn(txt, y, cb)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(1, -8, 0, 26); b.Position = UDim2.new(0, 4, 0, y)
    b.Text = txt; b.TextSize = 13; b.Font = Enum.Font.GothamBold
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 58); b.TextColor3 = Color3.new(1, 1, 1)
    table.insert(CONNS, b.MouseButton1Click:Connect(cb))
    return b
end
local pickB = btn("ตัว: " .. SRC[pick].Name, 4, function() end)
pickB.MouseButton1Click:Connect(function()
    pick = pick % #SRC + 1
    pickB.Text = "ตัว: " .. SRC[pick].Name
end)
btn("🛏 นอนเตียงใกล้สุด", 34, function()
    local cf = nearestBed()
    if cf then spawnAt(cf, "lie") end
end)
btn("🪑 นั่งตรงที่เล็ง", 64, function()
    if Mouse.Hit then spawnAt(CFrame.new(Mouse.Hit.Position + Vector3.new(0, 2, 0)), "sit") end
end)
btn("🧍 ยืนตรงที่เล็ง", 94, function()
    if Mouse.Hit then spawnAt(CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0)), "stand") end
end)
btn("🗑 ลบทั้งหมด", 124, function()
    for _, m in pairs(MOBS) do pcall(function() m:Destroy() end) end
    table.clear(MOBS)
end)
local note = Instance.new("TextLabel", f)
note.Size = UDim2.new(1, -8, 0, 38); note.Position = UDim2.new(0, 4, 0, 154)
note.BackgroundTransparency = 1; note.TextWrapped = true; note.TextSize = 11
note.TextColor3 = Color3.fromRGB(255, 200, 80); note.Font = Enum.Font.Gotham
note.Text = "เห็นคนเดียว (client) — รักษา/เช็คอินไม่ได้จริง"
