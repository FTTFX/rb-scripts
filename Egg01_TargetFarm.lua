-- Egg01 Target Farm v1.3
-- เลือก MinScale + Zone -> เดินไป Steal -> Drop/เก็บกลับ HOME (หนึ่งไข่ต่อรอบ)
-- Re-upload: same v1.3 behavior

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
local SCALE_CHOICES = { 0.1, 0.5, 1, 1.5, 2, 3, 5, 10 }
local ZONE_CHOICES = { "ALL", "Forest", "Lake", "Desert", "Snow" }
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
local RARITY_SHORT = { Common = "Com", Uncommon = "Unc", Rare = "Rare", Epic = "Epi", Legendary = "Leg", Mythic = "Myt", Cosmic = "Cos", Secret = "Sec", Eternal = "Ete", Divine = "Div" }
local selectedRarities = {}
for _, rarity in ipairs(RARITY_ORDER) do selectedRarities[rarity] = rarity ~= "Common" and rarity ~= "Uncommon" and rarity ~= "Rare" end
local HOME_R, STEAL_R, APPROACH_R, RECOVER_R = 60, 16, 7, 100
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
title.Text = "Egg01 Target Farm v1.3"

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

local scaleLabel = Instance.new("TextLabel", panel)
scaleLabel.Size = UDim2.new(0, 75, 0, 16)
scaleLabel.Position = UDim2.new(0, 10, 0, 69)
scaleLabel.BackgroundTransparency = 1
scaleLabel.TextColor3 = Color3.fromRGB(175, 175, 175)
scaleLabel.Font = Enum.Font.Gotham
scaleLabel.TextSize = 10
scaleLabel.TextXAlignment = Enum.TextXAlignment.Left
scaleLabel.Text = "MinScale"

local zoneLabel = scaleLabel:Clone()
zoneLabel.Position = UDim2.new(0, 92, 0, 69)
zoneLabel.Size = UDim2.new(0, 160, 0, 16)
zoneLabel.Text = "Zone"
zoneLabel.Parent = panel

local bScale = button("1.0 ▼", 10, 84, 74, Color3.fromRGB(40, 43, 49))
local bZone = button("ALL ▼", 92, 84, 150, Color3.fromRGB(40, 43, 49))
local bRarity = button("E+ ▼", 250, 84, 72, Color3.fromRGB(110, 70, 170))

local scaleMenu = Instance.new("Frame", gui)
scaleMenu.Size = UDim2.new(0, 74, 0, 0)
scaleMenu.Position = UDim2.new(0, 22, 0, 172)
scaleMenu.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
scaleMenu.BorderSizePixel = 0
scaleMenu.Visible = false
scaleMenu.ZIndex = 20
Instance.new("UICorner", scaleMenu).CornerRadius = UDim.new(0, 5)

local zoneMenu = Instance.new("Frame", gui)
zoneMenu.Size = UDim2.new(0, 150, 0, 0)
zoneMenu.Position = UDim2.new(0, 104, 0, 172)
zoneMenu.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
zoneMenu.BorderSizePixel = 0
zoneMenu.Visible = false
zoneMenu.ZIndex = 20
Instance.new("UICorner", zoneMenu).CornerRadius = UDim.new(0, 5)

local rarityMenu = Instance.new("Frame", gui)
rarityMenu.Size = UDim2.new(0, 130, 0, 0)
rarityMenu.Position = UDim2.new(0, 254, 0, 172)
rarityMenu.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
rarityMenu.BorderSizePixel = 0
rarityMenu.Visible = false
rarityMenu.ZIndex = 20
Instance.new("UICorner", rarityMenu).CornerRadius = UDim.new(0, 5)

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
    ZONE = tostring(ZONE or "ALL"):upper()
end

local function zoneAllowed(area)
    if ZONE == "ALL" then return true end
    local want = tostring(area or ""):upper()
    for token in ZONE:gmatch("[^,]+") do
        if want == token then return true end
    end
    return false
end

local function cleanRarity(value)
    local word = tostring(value or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, rarity in ipairs(RARITY_ORDER) do
        if word == rarity:lower() then return rarity end
    end
end

local function rarityFromConfig(row)
    if typeof(row) ~= "table" then return cleanRarity(row) end
    local config = rawget(row, "Config")
    local rarity = typeof(config) == "table" and rawget(config, "Rarity") or rawget(row, "Rarity")
    if typeof(rarity) == "table" then rarity = rawget(rarity, "_id") or rawget(rarity, "Id") or rawget(rarity, "Name") end
    return cleanRarity(rarity)
end

local function mapRarities(records)
    local categories, found = {}, {}
    for _, row in pairs(records) do
        if typeof(row) == "table" and row.AssetCategory then categories[tostring(row.AssetCategory)] = true end
    end
    if type(getgc) ~= "function" then return found, 0 end
    local ok, objects = pcall(getgc, true)
    if not ok or typeof(objects) ~= "table" then return found, 0 end
    for _, obj in ipairs(objects) do
        if typeof(obj) == "table" then
            local cat = rawget(obj, "AssetCategory") or rawget(obj, "Category")
            if cat and categories[tostring(cat)] then
                local rarity = rarityFromConfig(obj)
                if rarity then found[tostring(cat)] = rarity end
            end
            for category in pairs(categories) do
                if not found[category] then
                    local direct = rawget(obj, category)
                    local rarity = direct and rarityFromConfig(direct)
                    if rarity then found[category] = rarity end
                end
            end
        end
    end
    local n = 0
    for _ in pairs(found) do n = n + 1 end
    return found, n
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
    local rarityMap, categoryCount = mapRarities(records)
    local best, eligible, positioned = nil, 0, 0
    local foundZones = { ALL = true }
    for key, row in pairs(records) do
        if typeof(row) == "table" then
            local pos, scale, area = posOf(row), tonumber(row.AssetScale), row.AreaId
            if area then foundZones[tostring(area)] = true end
            local rarity = rarityMap[tostring(row.AssetCategory or "")]
            if pos and scale and scale >= MIN_SCALE and row.State ~= "Carried" and zoneAllowed(area) and rarity and selectedRarities[rarity] then
                eligible = eligible + 1
                local dist = (pos - root.Position).Magnitude
                if not best or dist < best.dist then
                    best = { uid = row.Uid or key, cat = row.AssetCategory or "?", rar = rarity, scale = scale, area = area or "?", pos = pos, dist = dist }
                end
            end
            if pos then positioned = positioned + 1 end
        end
    end
    ZONE_CHOICES = { "ALL" }
    for area in pairs(foundZones) do if area ~= "ALL" then ZONE_CHOICES[#ZONE_CHOICES + 1] = area end end
    table.sort(ZONE_CHOICES, function(a, b) if a == "ALL" then return true elseif b == "ALL" then return false else return a < b end end)
    if best then
        say(string.format("TARGET %s %s sc=%.2f zone=%s d=%.0f", best.rar, best.cat, best.scale, best.area, best.dist))
    else
        say(string.format("ไม่เจอเป้า | pos=%d rarMap=%d ผ่าน=%d sc>=%.2f zone=%s", positioned, categoryCount, eligible, MIN_SCALE, ZONE))
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

local function stopMove()
    local h, r = humRoot()
    if h and r then
        h:MoveTo(r.Position)
        h:Move(Vector3.zero)
    end
end

local function fireSteal(prompt)
    if not fp or not prompt then return false end
    local old = prompt.HoldDuration
    local ok, err = pcall(function() prompt.HoldDuration = 0 fp(prompt) end)
    pcall(function() prompt.HoldDuration = old end)
    if not ok then say("Steal error: " .. tostring(err)) end
    return ok
end

local function promptAtTarget(target)
    local _, root = humRoot()
    if not root then return nil end
    local best, bestD
    for _, p in ipairs(getPrompts()) do
        local eggMatch = (p.pos - target.pos).Magnitude
        local playerDist = (p.pos - root.Position).Magnitude
        if eggMatch <= 60 and playerDist <= STEAL_R and (not bestD or eggMatch < bestD) then
            best, bestD = p.pp, eggMatch
        end
    end
    return best, bestD
end

local function nearestSteal(maxDist)
    local _, root = humRoot()
    if not root then return nil end
    local best, bestD
    for _, p in ipairs(getPrompts()) do
        local d = (p.pos - root.Position).Magnitude
        if d <= maxDist and (not bestD or d < bestD) then best, bestD = p, d end
    end
    return best, bestD
end

-- HOP 14: ระยะที่ผ่าน MoveSpy แล้ว ใช้เฉพาะตอนตามเก็บไข่ที่หลุดมือ
local function hopTo(pos, radius, limit)
    local untilAt = os.clock() + limit
    while S.run and os.clock() < untilAt do
        local h, r = humRoot()
        if not h or not r then return false end
        local flat = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z)
        if flat.Magnitude <= radius then stopMove(); return true end
        local step = math.min(14, flat.Magnitude - radius)
        local dest = r.Position + flat.Unit * step
        h:Move(flat.Unit, false)
        r.CFrame = CFrame.new(dest.X, r.Position.Y, dest.Z) * (r.CFrame - r.CFrame.Position)
        task.wait(0.10)
    end
    return false
end

local function recoverDroppedEgg()
    local egg, d = nearestSteal(RECOVER_R)
    if not egg then
        say("ไข่หลุดมือ แต่ไม่เจอ Prompt ใกล้ตัว")
        return false
    end
    say(string.format("ไข่หลุดมือ — HOP กลับไป d=%.0f", d))
    if not hopTo(egg.pos, APPROACH_R, 12) then return false end
    egg = select(1, nearestSteal(STEAL_R))
    if not egg then say("Prompt ไข่หายระหว่าง HOP") return false end
    fireSteal(egg.pp)
    local deadline = os.clock() + 4
    while S.run and not S.carrying and os.clock() < deadline do task.wait(0.15) end
    if S.carrying then
        say("เก็บไข่คืนแล้ว — วิ่งต่อ")
        return true
    end
    say("เก็บไข่คืนไม่สำเร็จ")
    return false
end

local function returnHome()
    local deadline, lastReport = os.clock() + 120, 0
    while S.run and os.clock() < deadline do
        local h, r = humRoot()
        if not h or not r or not S.home then return false end
        if not S.carrying and not recoverDroppedEgg() then return false end
        h, r = humRoot()
        if not h or not r then return false end
        local d = dist2(r.Position, S.home)
        if d <= HOME_R then stopMove(); return true end
        -- เดินตรงยาวถึง HOME; ยิง MoveTo ซ้ำเฉพาะเพื่อกันชน/สะดุด
        h:MoveTo(Vector3.new(S.home.X, r.Position.Y, S.home.Z))
        if os.clock() - lastReport >= 1 then
            say(string.format("วิ่งกลับ HOME d=%.0f", d))
            lastReport = os.clock()
        end
        task.wait(0.15)
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
        stopMove() -- ยกเลิก MoveTo เดิมก่อนกด ไม่ให้ตัวละครไหลเลยไข่
        if S.run then
            local prompt, matchD = promptAtTarget(target)
            if not prompt then
                say("ถึงตำแหน่งไข่ แต่ยังไม่เจอ Prompt Steal — เป้าอาจย้าย")
                S.run = false
            else
                target.pp = prompt
                local ppPart = prompt.Parent and (prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart", true))
                if ppPart then
                    say(string.format("เจอ Prompt match=%.1f — เข้าใกล้", matchD))
                    walkTo(ppPart.Position, APPROACH_R, 8)
                    stopMove()
                    prompt = select(1, promptAtTarget(target))
                    if not prompt then
                        say("Prompt หายระหว่างเข้าใกล้")
                        S.run = false
                    else
                        target.pp = prompt
                    end
                end
            end
        end
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

local function rebuildMenu(menu, choices, onPick)
    menu:ClearAllChildren()
    local h = #choices * 24
    menu.Size = UDim2.new(menu.Size.X.Scale, menu.Size.X.Offset, 0, h)
    for i, value in ipairs(choices) do
        local b = Instance.new("TextButton", menu)
        b.Size = UDim2.new(1, 0, 0, 22)
        b.Position = UDim2.new(0, 0, 0, (i - 1) * 24 + 1)
        b.BackgroundColor3 = Color3.fromRGB(45, 49, 58)
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = tostring(value)
        b.ZIndex = 21
        b.MouseButton1Click:Connect(function() onPick(value); menu.Visible = false end)
    end
end

local function rarityText()
    local out = {}
    for _, rarity in ipairs(RARITY_ORDER) do if selectedRarities[rarity] then out[#out + 1] = RARITY_SHORT[rarity] end end
    return #out == #RARITY_ORDER and "ALL" or (#out > 0 and table.concat(out, ",") or "NONE")
end

local function rebuildRarityMenu()
    rarityMenu:ClearAllChildren()
    rarityMenu.Size = UDim2.new(0, 130, 0, (#RARITY_ORDER + 1) * 23)
    local choices = { "ALL" }
    for _, rarity in ipairs(RARITY_ORDER) do choices[#choices + 1] = rarity end
    for i, rarity in ipairs(choices) do
        local b = Instance.new("TextButton", rarityMenu)
        b.Size = UDim2.new(1, 0, 0, 21)
        b.Position = UDim2.new(0, 0, 0, (i - 1) * 23 + 1)
        b.BackgroundColor3 = Color3.fromRGB(45, 49, 58)
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        local active = rarity == "ALL" and rarityText() == "ALL" or selectedRarities[rarity]
        b.Text = (active and "✓ " or "") .. (rarity == "ALL" and "ALL" or RARITY_SHORT[rarity])
        b.ZIndex = 21
        b.MouseButton1Click:Connect(function()
            if rarity == "ALL" then
                local turnOn = rarityText() ~= "ALL"
                for _, name in ipairs(RARITY_ORDER) do selectedRarities[name] = turnOn end
            else
                selectedRarities[rarity] = not selectedRarities[rarity]
            end
            bRarity.Text = rarityText() .. " ▼"
            rebuildRarityMenu()
            say("Rarity = " .. rarityText())
        end)
    end
end

bScale.MouseButton1Click:Connect(function()
    zoneMenu.Visible = false
    rebuildMenu(scaleMenu, SCALE_CHOICES, function(value)
        MIN_SCALE = value
        bScale.Text = string.format("%.1f ▼", value)
        say("MinScale = " .. value)
    end)
    scaleMenu.Visible = not scaleMenu.Visible
end)

bZone.MouseButton1Click:Connect(function()
    scaleMenu.Visible = false
    rebuildMenu(zoneMenu, ZONE_CHOICES, function(value)
        ZONE = value
        bZone.Text = tostring(value) .. " ▼"
        say("Zone = " .. tostring(value))
    end)
    zoneMenu.Visible = not zoneMenu.Visible
end)

bRarity.MouseButton1Click:Connect(function()
    scaleMenu.Visible = false
    zoneMenu.Visible = false
    rebuildRarityMenu()
    rarityMenu.Visible = not rarityMenu.Visible
end)

local carry = findNet("FieldEggCarry")
if carry and (carry:IsA("RemoteEvent") or carry:IsA("UnreliableRemoteEvent")) then
    S.conns[#S.conns + 1] = carry.OnClientEvent:Connect(function(row)
        if typeof(row) == "table" and row.IsCarrying ~= nil then
            S.carrying = row.IsCarrying == true
            if row.AreaId then S.eggArea = row.AreaId end
            if S.carrying then say("server: ถือไข่แล้ว") end
        end
    end)
    lines[#lines + 1] = "ฟัง FieldEggCarry ✅"
else
    lines[#lines + 1] = "ไม่พบ FieldEggCarry — จะตรวจผล Steal ไม่ได้"
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
    if clip then pcall(clip, "=== Egg01 Target Farm v1.3 ===\n" .. table.concat(lines, "\n")) end
    bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)
bClose.MouseButton1Click:Connect(function()
    S.run = false
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.EGG01_TARGET_FARM = nil
end)

say("HOME ที่ฐาน → เลือก Scale/Zone/Rarity จากปุ่ม → SCAN หรือ START")
