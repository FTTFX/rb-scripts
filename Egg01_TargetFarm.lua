-- Egg01 Target Farm v1.0
-- เลือก MinScale + Zone -> เดินไป Steal -> Drop/เก็บกลับ HOME (หนึ่งไข่ต่อรอบ)

if _G.EGG01_TARGET_FARM then
    _G.EGG01_TARGET_FARM.run = false
    pcall(function() _G.EGG01_TARGET_FARM.gui:Destroy() end)
    if _G.EGG01_TARGET_FARM.conns then
        for _, c in ipairs(_G.EGG01_TARGET_FARM.conns) do pcall(function() c:Disconnect() end) end
    end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local S = { gui = nil, conns = {}, run = false, home = nil, carrying = false, eggArea = nil }
_G.EGG01_TARGET_FARM = S

local MIN_SCALE, ZONE = 1, "ALL"
local HOME_R, STEAL_R, STEP = 60, 16, 140
local lines = {}

local function humRoot()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function dist2(a, b)
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function posOf(row)
    for _, key in ipairs({ "BottomCFrame", "BoundsCFrame", "CFrame", "Position" }) do
        local v = row[key]
        if typeof(v) == "CFrame" then return v.Position end
        if typeof(v) == "Vector3" then return v end
    end
end

local function findNet(name, className)
    local packages = RS:FindFirstChild("Packages")
    local networking = packages and packages:FindFirstChild("Networking")
    for _, root in ipairs({ networking, RS }) do
        if root then
            for _, item in ipairs(root:GetDescendants()) do
                if item.Name:find(name, 1, true) and (not className or item:IsA(className)) then return item end
            end
        end
    end
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_TargetFarm"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1005
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 335, 0, 158)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -45, 0, 24)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 Target Farm v1.0"

local function button(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = text
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bHome = button("HOME", 10, 35, 58, Color3.fromRGB(50, 100, 180))
local bScan = button("SCAN", 75, 35, 58, Color3.fromRGB(55, 105, 165))
local bStart = button("START", 140, 35, 58, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 205, 35, 52, Color3.fromRGB(165, 50, 55))
local bCopy = button("COPY", 264, 35, 58, Color3.fromRGB(70, 70, 75))
local bClose = button("X", 296, 4, 30, Color3.fromRGB(125, 45, 45))

local function field(label, x, width, default, hint)
    local lb = Instance.new("TextLabel", panel)
    lb.Size = UDim2.new(0, width, 0, 16)
    lb.Position = UDim2.new(0, x, 0, 69)
    lb.BackgroundTransparency = 1
    lb.TextColor3 = Color3.fromRGB(175, 175, 175)
    lb.Font = Enum.Font.Gotham
    lb.TextSize = 10
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.Text = label
    local box = Instance.new("TextBox", panel)
    box.Size = UDim2.new(0, width, 0, 24)
    box.Position = UDim2.new(0, x, 0, 84)
    box.BackgroundColor3 = Color3.fromRGB(40, 43, 49)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.PlaceholderText = hint or ""
    box.PlaceholderColor3 = Color3.fromRGB(150, 155, 165)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 12
    box.Text = default
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    return box
end

local tScale = field("MinScale", 10, 70, "1", "1")
local tZone = field("Zone (ALL / Forest,Desert)", 90, 150, "ALL", "ALL")

local status = Instance.new("TextLabel", panel)
status.Size = UDim2.new(1, -20, 0, 37)
status.Position = UDim2.new(0, 10, 0, 116)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(140, 235, 160)
status.Font = Enum.Font.GothamBold
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "HOME ที่ฐาน → ตั้ง MinScale/Zone → START"

local function say(message)
    lines[#lines + 1] = tostring(message)
    if #lines > 100 then table.remove(lines, 1) end
    status.Text = tostring(message)
end

local function readConfig()
    local n = tonumber(tScale.Text)
    if n and n >= 0 then MIN_SCALE = n end
    ZONE = tostring(tZone.Text or "ALL"):upper():gsub("%s+", "")
    if ZONE == "" then ZONE = "ALL" end
end

local function zoneAllowed(area)
    if ZONE == "ALL" then return true end
    local want = tostring(area or ""):upper()
    for token in ZONE:gmatch("[^,]+") do
        if want == token then return true end
    end
    return false
end

local function getPrompts()
    local out = {}
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("ProximityPrompt") and item.Enabled and tostring(item.ActionText):lower():find("steal", 1, true) then
            local p = item.Parent
            local part = p and (p:IsA("BasePart") and p or p:FindFirstChildWhichIsA("BasePart", true))
            if part then out[#out + 1] = { pp = item, pos = part.Position } end
        end
    end
    return out
end

local function chooseTarget()
    readConfig()
    local rf = findNet("AskFieldEggSnapshot", "RemoteFunction")
    if not rf then say("ไม่พบ AskFieldEggSnapshot") return nil end
    local ok, result = pcall(function() return rf:InvokeServer() end)
    if not ok or typeof(result) ~= "table" then say("Snapshot error: " .. tostring(result)) return nil end
    local records = result.Records or result.records or result
    local _, root = humRoot()
    if typeof(records) ~= "table" or not root then return nil end
    local prompts = getPrompts()
    local best
    for key, row in pairs(records) do
        if typeof(row) == "table" then
            local pos, scale, area = posOf(row), tonumber(row.AssetScale), row.AreaId
            if pos and scale and scale >= MIN_SCALE and row.State ~= "Carried" and zoneAllowed(area) then
                local pp, ppD
                for _, p in ipairs(prompts) do
                    local d = (p.pos - pos).Magnitude
                    if d <= 60 and (not ppD or d < ppD) then pp, ppD = p, d end
                end
                if pp then
                    local dist = (pp.pos - root.Position).Magnitude
                    if not best or dist < best.dist then
                        best = { uid = row.Uid or key, cat = row.AssetCategory or "?", scale = scale, area = area or "?", pos = pp.pos, pp = pp.pp, dist = dist, match = ppD }
                    end
                end
            end
        end
    end
    if best then
        say(string.format("TARGET %s sc=%.2f zone=%s d=%.0f", best.cat, best.scale, best.area, best.dist))
    else
        say(string.format("ไม่มีไข่ sc>=%.2f zone=%s ที่จับกับ Steal", MIN_SCALE, ZONE))
    end
    return best
end

local function walkTo(pos, radius, limit)
    local started = os.clock()
    while S.run and os.clock() - started < limit do
        local h, r = humRoot()
        if not h or not r or h.Health <= 0 then return false end
        local goal = Vector3.new(pos.X, r.Position.Y, pos.Z)
        if (goal - r.Position).Magnitude <= radius then return true end
        h:MoveTo(goal)
        task.wait(0.3)
    end
    return false
end

local function fireSteal(prompt)
    if not fp or not prompt then return false end
    local old = prompt.HoldDuration
    local ok = pcall(function() prompt.HoldDuration = 0 fp(prompt) end)
    pcall(function() prompt.HoldDuration = old end)
    return ok
end

local function guardArea(area)
    local objects = workspace:FindFirstChild("__OBJECTS")
    local areas = objects and objects:FindFirstChild("Areas")
    local guards = areas and areas:FindFirstChild("GuardAreas")
    if not guards then return nil end
    local want = tostring(area or ""):lower()
    for _, item in ipairs(guards:GetChildren()) do
        if item.Name:lower() == want then return item end
    end
end

local function outsideGuard()
    local _, r = humRoot()
    local guard = r and guardArea(S.eggArea)
    if not guard then return true end
    local ok, cf, size = pcall(function() return guard:GetBoundingBox() end)
    if not ok then return false end
    local p = cf:PointToObjectSpace(r.Position)
    return math.abs(p.X) > size.X * 0.5 + 16 or math.abs(p.Z) > size.Z * 0.5 + 16
end

local function dropHeld()
    local holder = PG:FindFirstChild("DropHeldEgg")
    local b = holder and holder:FindFirstChildWhichIsA("GuiButton", true)
    if not b or not getconnections then return false end
    for _, sig in ipairs({ b.Activated, b.MouseButton1Click }) do
        for _, con in ipairs(getconnections(sig)) do pcall(function() con:Fire() end) end
    end
    return true
end

local function pickNearby()
    local _, r = humRoot()
    if not r then return false end
    local best, bestD
    for _, p in ipairs(getPrompts()) do
        local d = (p.pos - r.Position).Magnitude
        if d <= STEAL_R and (not bestD or d < bestD) then best, bestD = p.pp, d end
    end
    if best then fireSteal(best) return true end
    return false
end

local function returnHome()
    while S.run and S.carrying do
        local _, r = humRoot()
        if not r or not S.home then return false end
        if dist2(r.Position, S.home) <= HOME_R then
            walkTo(S.home, HOME_R, 20)
            return true
        end
        local flat = Vector3.new(S.home.X - r.Position.X, 0, S.home.Z - r.Position.Z)
        if flat.Magnitude < 1 then return true end
        local nextPos = r.Position + flat.Unit * math.min(STEP, flat.Magnitude)
        say(string.format("กลับบ้าน d=%.0f", dist2(r.Position, S.home)))
        walkTo(nextPos, 8, 22)
        if S.carrying and outsideGuard() and dist2(r.Position, S.home) > HOME_R * 4 then
            say("พ้นโซนมอน — ทิ้ง/เก็บ")
            if dropHeld() then
                S.carrying = false
                task.wait(2)
                local untilAt = os.clock() + 8
                while S.run and not S.carrying and os.clock() < untilAt do pickNearby() task.wait(0.4) end
            end
        end
        task.wait(0.1)
    end
    return false
end

local function runOne()
    if S.run then return end
    if not fp then say("executor ไม่มี fireproximityprompt") return end
    if not S.home then
        local _, r = humRoot()
        if not r then say("ไม่มีตัวละคร") return end
        S.home = r.Position
        say("HOME อัตโนมัติแล้ว")
    end
    local target = chooseTarget()
    if not target then return end
    S.run, S.carrying, S.eggArea = true, false, target.area
    bStart.Text = "..."
    task.spawn(function()
        say("ไปหา " .. target.cat)
        if not walkTo(target.pos, STEAL_R, 80) then say("ไปถึงไข่ไม่สำเร็จ") S.run = false end
        if S.run then
            say("ยิง Steal")
            fireSteal(target.pp)
            local deadline = os.clock() + 5
            while S.run and not S.carrying and os.clock() < deadline do task.wait(0.2) end
            if not S.carrying then say("Steal ไม่สำเร็จ/เป้าย้าย") S.run = false end
        end
        if S.run and S.carrying then
            say("ได้ไข่แล้ว — กลับบ้าน")
            if returnHome() then say("ถึง HOME — วางเข้าคอกเอง") else say("กลับบ้านไม่สำเร็จ") end
        end
        S.run = false
        bStart.Text = "START"
    end)
end

local carry = findNet("FieldEggCarry")
if carry and (carry:IsA("RemoteEvent") or carry:IsA("UnreliableRemoteEvent")) then
    S.conns[#S.conns + 1] = carry.OnClientEvent:Connect(function(row)
        if typeof(row) == "table" and row.IsCarrying ~= nil then
            S.carrying = row.IsCarrying == true
            if row.AreaId then S.eggArea = row.AreaId end
        end
    end)
end

bHome.MouseButton1Click:Connect(function()
    local _, r = humRoot()
    if r then S.home = r.Position; say("HOME ตั้งแล้ว") else say("ไม่มีตัวละคร") end
end)
bScan.MouseButton1Click:Connect(chooseTarget)
bStart.MouseButton1Click:Connect(runOne)
bStop.MouseButton1Click:Connect(function() S.run = false; bStart.Text = "START"; say("STOP") end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, "=== Egg01 Target Farm v1.0 ===\n" .. table.concat(lines, "\n")) end
    bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)
bClose.MouseButton1Click:Connect(function()
    S.run = false
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.EGG01_TARGET_FARM = nil
end)

say("HOME ที่ฐาน → MinScale/Zone → SCAN หรือ START")
