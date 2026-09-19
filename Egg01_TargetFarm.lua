-- Egg01 Target Farm v1.18
-- ทางไกล = HOP เดินทาง | หลุดมือ = กันกระแทก+HOP เก็บ | Steal แล้วพุ่งกลับทันที

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

local S = { gui = nil, conns = {}, run = false, home = nil, carrying = false, eggArea = nil, lastCarryPos = nil, heldUid = nil, heldCat = nil, skipUids = {}, focusZone = nil, zoneIdx = 1, recovering = false }
_G.EGG01_TARGET_FARM = S

local MIN_SCALE = 1
local ZONE_CHOICES = { "ALL", "Forest", "Lake", "Desert", "Snow" }
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
local RARITY_SHORT = { Common = "Com", Uncommon = "Unc", Rare = "Rare", Epic = "Epi", Legendary = "Leg", Mythic = "Myt", Cosmic = "Cos", Secret = "Sec", Eternal = "Ete", Divine = "Div" }
local selectedRarities = {}
for _, rarity in ipairs(RARITY_ORDER) do selectedRarities[rarity] = rarity ~= "Common" and rarity ~= "Uncommon" and rarity ~= "Rare" end
local selectedZones = {}
for _, z in ipairs(ZONE_CHOICES) do if z ~= "ALL" then selectedZones[z] = true end end
local SCALE_CHOICES = { 0.1, 0.5, 1, 1.5, 2, 3, 5, 10 }
local HOME_R, STEAL_R, APPROACH_R, RECOVER_R, MATCH_R = 110, 16, 7, 180, 18
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
                if item.Name:find(name, 1, true) then
                    if not className or item:IsA(className) then return item end
                    if item:IsA("RemoteEvent") or item:IsA("UnreliableRemoteEvent") or item:IsA("RemoteFunction") then
                        return item
                    end
                end
            end
        end
    end
end

-- ถือไข่จริงไหม: RE หรือ GUI DropHeldEgg (ตอนไม่มี FieldEggCarry)
local function guiShowsCarry()
    local g = PG:FindFirstChild("DropHeldEgg")
    if g then return true end
    for _, c in ipairs(PG:GetChildren()) do
        if c.Name:find("DropHeld", 1, true) or c.Name:find("HeldEgg", 1, true) then
            return true
        end
    end
    return false
end

local function isHolding()
    if S.carrying then return true end
    if guiShowsCarry() then
        S.carrying = true
        return true
    end
    return false
end

local function markHolding(why)
    if S.carrying then return end
    S.carrying = true
    local _, r = humRoot()
    if r then S.lastCarryPos = r.Position end
    say(why or "ถือไข่แล้ว — วิ่งกลับทันที")
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
title.Text = "Egg01 Target Farm v1.18"

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

local function zoneList()
    local out = {}
    for _, z in ipairs(ZONE_CHOICES) do
        if z ~= "ALL" then out[#out + 1] = z end
    end
    return out
end

local function zoneText()
    local names = zoneList()
    local on = {}
    for _, z in ipairs(names) do
        if selectedZones[z] then on[#on + 1] = z end
    end
    if #names == 0 or #on == #names then return "ALL" end
    if #on == 0 then return "NONE" end
    if #on <= 2 then return table.concat(on, ",") end
    return tostring(#on) .. "Z"
end

-- โซนที่ติ๊ก ตามลำดับในเมนู (A→Z ตาม ZONE_CHOICES)
local function zonesOn()
    local out = {}
    for _, z in ipairs(zoneList()) do
        if selectedZones[z] then out[#out + 1] = z end
    end
    return out
end

local function zoneAllowed(area)
    local a = tostring(area or "")
    if zoneText() == "ALL" then return true end
    return selectedZones[a] == true
end

local function readConfig()
end

local function advanceZone(order, why)
    order = order or zonesOn()
    if #order == 0 then
        S.focusZone, S.zoneIdx = nil, 1
        return nil
    end
    S.zoneIdx = (S.zoneIdx or 1) + 1
    if S.zoneIdx > #order then
        S.focusZone = nil
        say((why or "หมดโซน") .. " — จบคิวไล่โซน")
        return nil
    end
    S.focusZone = order[S.zoneIdx]
    say(string.format("ไล่โซนถัดไป (%d/%d): %s", S.zoneIdx, #order, S.focusZone))
    return S.focusZone
end

local function ensureFocusZone()
    local order = zonesOn()
    if #order == 0 then return nil, order end
    if S.focusZone then
        for i, z in ipairs(order) do
            if z == S.focusZone then
                S.zoneIdx = i
                return S.focusZone, order
            end
        end
    end
    S.zoneIdx = 1
    S.focusZone = order[1]
    say(string.format("เริ่มไล่โซน (1/%d): %s", #order, S.focusZone))
    return S.focusZone, order
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

local function isStealPrompt(pp)
    if not pp or not pp:IsA("ProximityPrompt") or not pp.Enabled then return false end
    local act = tostring(pp.ActionText):lower()
    local obj = tostring(pp.ObjectText):lower()
    if act:find("steal", 1, true) or act:find("ขโมย", 1, true) then return true end
    if obj:find("steal", 1, true) or obj:find("ขโมย", 1, true) then return true end
    local par = pp.Parent
    if par and (par.Name:find("CarryAreaEgg", 1, true) or par.Name:find("SmartPrompt", 1, true)) then
        return true
    end
    return false
end

local function getPrompts()
    local out = {}
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("ProximityPrompt") and isStealPrompt(item) then
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
    local foundZones = { ALL = true }
    for _, row in pairs(records) do
        if typeof(row) == "table" and row.AreaId then foundZones[tostring(row.AreaId)] = true end
    end
    ZONE_CHOICES = { "ALL" }
    for area in pairs(foundZones) do
        if area ~= "ALL" then
            ZONE_CHOICES[#ZONE_CHOICES + 1] = area
            if selectedZones[area] == nil then selectedZones[area] = true end
        end
    end
    table.sort(ZONE_CHOICES, function(a, b) if a == "ALL" then return true elseif b == "ALL" then return false else return a < b end end)

    local focus, order = ensureFocusZone()
    if not focus then
        say("ไม่ได้ติ๊กโซนไว้")
        return nil
    end

    -- ไล่โซนปัจจุบันก่อน — ไม่มีเป้าค่อยขยับโซนถัดไป
    for _ = 1, math.max(1, #order) do
        local best, eligible, positioned = nil, 0, 0
        for key, row in pairs(records) do
            if typeof(row) == "table" then
                local pos, scale, area = posOf(row), tonumber(row.AssetScale), row.AreaId
                local areaStr = tostring(area or "")
                local rarity = rarityMap[tostring(row.AssetCategory or "")]
                local uid = tostring(row.Uid or key)
                if pos then positioned = positioned + 1 end
                if pos and scale and scale >= MIN_SCALE and row.State ~= "Carried"
                    and areaStr == focus
                    and rarity and selectedRarities[rarity] and not S.skipUids[uid] then
                    eligible = eligible + 1
                    local dist = (pos - root.Position).Magnitude
                    if not best or dist < best.dist then
                        best = { uid = uid, cat = row.AssetCategory or "?", rar = rarity, scale = scale, area = areaStr, pos = pos, dist = dist }
                    end
                end
            end
        end
        if best then
            say(string.format("TARGET %s %s sc=%.2f zone=%s [%d/%d] d=%.0f", best.rar, best.cat, best.scale, best.area, S.zoneIdx, #order, best.dist))
            return best
        end
        say(string.format("โซน %s ไม่มีเป้า (rarMap=%d) — ข้าม", focus, categoryCount))
        focus = advanceZone(order, "โซนว่าง")
        if not focus then return nil end
    end
    return nil
end

local function walkTo(pos, radius, limit)
    local started = os.clock()
    while S.run and os.clock() - started < limit do
        local h, r = humRoot()
        if not h or not r or h.Health <= 0 then return false end
        local goal = Vector3.new(pos.X, r.Position.Y, pos.Z)
        if (goal - r.Position).Magnitude <= radius then return true end
        h:MoveTo(goal)
        task.wait(0.12)
    end
    return false
end

-- HOP เดินทางไกล — ไม่ตัด velocity แบบกันกระแทก (คนละอย่างกับตอนหลุดมือ)
local function travelHop(pos, radius, limit)
    local untilAt = os.clock() + limit
    while S.run and os.clock() < untilAt do
        local h, r = humRoot()
        if not h or not r then return false end
        local flat = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z)
        if flat.Magnitude <= radius then
            if h then h:MoveTo(r.Position) end
            return true
        end
        local step = math.min(14, flat.Magnitude)
        local dest = r.Position + flat.Unit * step
        r.CFrame = CFrame.new(dest.X, r.Position.Y, dest.Z) * (r.CFrame - r.CFrame.Position)
        task.wait(0.05)
    end
    return false
end

local function goTo(pos, radius, limit)
    local _, r = humRoot()
    if not r then return false end
    local d = dist2(r.Position, pos)
    if d > 90 then
        return travelHop(pos, radius, limit or math.max(25, d / 12))
    end
    return walkTo(pos, radius, limit or 20)
end

local function stopMove()
    local h, r = humRoot()
    if h and r then
        h:MoveTo(r.Position)
        h:Move(Vector3.zero)
    end
end

local function fireSteal(prompt)
    if not prompt then return false end
    local oldHold = prompt.HoldDuration
    local oldMax = prompt.MaxActivationDistance
    local ok = false
    pcall(function()
        prompt.HoldDuration = 0
        if oldMax < 20 then prompt.MaxActivationDistance = 20 end
    end)
    if fp then ok = pcall(fp, prompt) end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(0.02)
        prompt:InputHoldEnd()
    end)
    if fp then pcall(fp, prompt) end
    pcall(function()
        prompt.HoldDuration = oldHold
        prompt.MaxActivationDistance = oldMax
    end)
    return ok
end

local function dashHomeNow()
    local h, r = humRoot()
    if not h or not r or not S.home then return end
    local d = dist2(r.Position, S.home)
    if d > 90 then
        -- พุ่งก้าวแรกทันที
        local flat = Vector3.new(S.home.X - r.Position.X, 0, S.home.Z - r.Position.Z)
        if flat.Magnitude > 1 then
            local dest = r.Position + flat.Unit * math.min(14, flat.Magnitude)
            r.CFrame = CFrame.new(dest.X, r.Position.Y, dest.Z) * (r.CFrame - r.CFrame.Position)
        end
    end
    h:MoveTo(Vector3.new(S.home.X, r.Position.Y, S.home.Z))
end

local function setFarmSpeed(on)
    local h = select(1, humRoot())
    if not h then return end
    if on then
        if not S.baseSpeed then S.baseSpeed = h.WalkSpeed end
        h.WalkSpeed = math.max(S.baseSpeed or 16, 28)
    elseif S.baseSpeed then
        h.WalkSpeed = S.baseSpeed
        S.baseSpeed = nil
    end
end

-- จับ Prompt ที่ใกล้พิกัดไข่เป้าที่สุดเท่านั้น (ไม่สนว่าใกล้ผู้เล่น) — กันยิงไข่ผิดกอง
local function promptAtTarget(target)
    if not target or not target.pos then return nil end
    local bestPp, bestPos, bestD
    for _, p in ipairs(getPrompts()) do
        local eggMatch = (p.pos - target.pos).Magnitude
        if eggMatch <= MATCH_R and (not bestD or eggMatch < bestD) then
            bestPp, bestPos, bestD = p.pp, p.pos, eggMatch
        end
    end
    return bestPp, bestD, bestPos
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

-- Prompt ใกล้พิกัดไข่ที่ถือ/ตก — ไม่ใช้ระยะจากผู้เล่น (กันเก็บไข่ผิด)
local function promptNearPos(pos, maxDist)
    if not pos then return nil end
    maxDist = maxDist or 90
    local best, bestD
    for _, p in ipairs(getPrompts()) do
        local d = (p.pos - pos).Magnitude
        if d <= maxDist and (not bestD or d < bestD) then
            best, bestD = p, d
        end
    end
    return best, bestD
end

local function posOfHeldUid()
    if not S.heldUid then return nil end
    local rf = findNet("AskFieldEggSnapshot", "RemoteFunction")
    if not rf then return nil end
    local ok, result = pcall(function() return rf:InvokeServer() end)
    if not ok or typeof(result) ~= "table" then return nil end
    local records = result.Records or result.records or result
    if typeof(records) ~= "table" then return nil end
    local want = tostring(S.heldUid)
    for key, row in pairs(records) do
        if typeof(row) == "table" and tostring(row.Uid or key) == want then
            return posOf(row)
        end
    end
    return nil
end

-- ยืนยันก่อนยิง: Prompt นี้ยังใกล้เป้าสุด และผู้เล่นอยู่ในระยะ Steal
local function promptReadyToFire(target, prompt)
    local _, root = humRoot()
    if not root or not prompt or not prompt.Parent then return false, nil end
    local bestPp, matchD, bestPos = promptAtTarget(target)
    if not bestPp or bestPp ~= prompt then return false, matchD end
    if not matchD or matchD > MATCH_R then return false, matchD end
    local pos = bestPos
    if not pos then
        local part = prompt.Parent
        local bp = part:IsA("BasePart") and part or part:FindFirstChildWhichIsA("BasePart", true)
        if not bp then return false, matchD end
        pos = bp.Position
    end
    return (pos - root.Position).Magnitude <= STEAL_R, matchD
end

-- กันกระแทกสั้นๆ ระหว่าง HOP (ไม่บล็อครอนาน)
local function killKnockback()
    local h, r = humRoot()
    if not r then return end
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
    if h then
        pcall(function()
            h.PlatformStand = false
            local st = h:GetState()
            if st == Enum.HumanoidStateType.Flying
                or st == Enum.HumanoidStateType.Freefall
                or st == Enum.HumanoidStateType.Physics then
                h:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end
end

-- HOP หาไข่เร็ว — ใช้เฉพาะตอนหลุดมือ
local function hopTo(pos, radius, limit)
    local untilAt = os.clock() + limit
    while S.run and os.clock() < untilAt do
        local h, r = humRoot()
        if not h or not r then return false end
        killKnockback()
        local flat = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z)
        if flat.Magnitude <= radius then
            stopMove()
            killKnockback()
            return true
        end
        local step = math.min(14, math.max(flat.Magnitude - radius, 0))
        if step < 0.5 then step = flat.Magnitude end
        local dest = r.Position + flat.Unit * step
        local y = dest.Y
        if typeof(pos) == "Vector3" and math.abs(r.Position.Y - pos.Y) > 10 then
            y = r.Position.Y + math.clamp(pos.Y - r.Position.Y, -6, 6)
        end
        r.CFrame = CFrame.new(dest.X, y, dest.Z) * (r.CFrame - r.CFrame.Position)
        task.wait(0.05)
    end
    return false
end

local function recoverDroppedEgg()
    if S.recovering then
        local waitUntil = os.clock() + 16
        while S.recovering and not S.carrying and os.clock() < waitUntil do
            if not S.run then return false end
            task.wait(0.08)
        end
        return S.carrying == true
    end
    S.recovering = true
    local ok = false
    local _, root = humRoot()
    if root then
        local label = S.heldCat and tostring(S.heldCat) or "ไข่ที่ถือ"
        -- HOP ทันทีไปจุดถือล่าสุด — ไม่รอ antiBurst / snapshot (ช้า)
        killKnockback()
        local goal = S.lastCarryPos or root.Position
        local egg, matchD = promptNearPos(goal, 90)
        if egg then goal = egg.pos end
        say(string.format("หลุดมือ — HOP %s ทันที d=%.0f", label, (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude))

        -- ระหว่าง HOP อัปเดตเป้าเป็นครั้งคราว — ห้าม Invoke snapshot ทุกเฟรม (ช้ามาก)
        local hopUntil, lastSnap = os.clock() + 18, 0
        local arrived = false
        while S.run and os.clock() < hopUntil do
            killKnockback()
            if os.clock() - lastSnap >= 0.55 then
                local snap = posOfHeldUid()
                if snap then goal = snap end
                lastSnap = os.clock()
            end
            egg, matchD = promptNearPos(goal, 90)
            if egg then goal = egg.pos end

            local h, r = humRoot()
            if not h or not r then break end
            local flat = Vector3.new(goal.X - r.Position.X, 0, goal.Z - r.Position.Z)
            if egg and matchD and matchD <= 35 and flat.Magnitude <= STEAL_R + 4 then
                say(string.format("ยิง Steal ไข่ที่ถูกทันที match=%.1f", matchD))
                fireSteal(egg.pp)
                local deadline, lastFire = os.clock() + 3.5, 0
                while S.run and not S.carrying and os.clock() < deadline do
                    if os.clock() - lastFire >= 0.45 then
                        fireSteal(egg.pp)
                        lastFire = os.clock()
                    end
                    task.wait(0.08)
                end
                if S.carrying then
                    say("เก็บไข่ที่ถูกคืนแล้ว — วิ่งต่อ")
                    ok = true
                end
                break
            end
            if flat.Magnitude <= APPROACH_R then
                arrived = true
                stopMove()
                break
            end
            local step = math.min(14, flat.Magnitude)
            local dest = r.Position + flat.Unit * step
            r.CFrame = CFrame.new(dest.X, r.Position.Y, dest.Z) * (r.CFrame - r.CFrame.Position)
            task.wait(0.05)
        end

        if not ok and S.run then
            local pollUntil, lastSnap2 = os.clock() + 2.0, 0
            while S.run and not S.carrying and os.clock() < pollUntil do
                killKnockback()
                local g2 = S.lastCarryPos or goal
                if os.clock() - lastSnap2 >= 0.5 then
                    g2 = posOfHeldUid() or g2
                    lastSnap2 = os.clock()
                end
                egg, matchD = promptNearPos(g2, 90)
                if egg and matchD and matchD <= 40 then
                    local _, r2 = humRoot()
                    if r2 and (egg.pos - r2.Position).Magnitude > STEAL_R then
                        hopTo(egg.pos, APPROACH_R, 2.5)
                    end
                    say(string.format("ยิง Steal ไข่ที่ถูก match=%.1f", matchD))
                    fireSteal(egg.pp)
                    local deadline, lastFire = os.clock() + 3, 0
                    while S.run and not S.carrying and os.clock() < deadline do
                        if os.clock() - lastFire >= 0.4 then
                            fireSteal(egg.pp)
                            lastFire = os.clock()
                        end
                        task.wait(0.08)
                    end
                    break
                end
                hopTo(g2, APPROACH_R, 1.5)
                task.wait(0.1)
            end
            if S.carrying then
                say("เก็บไข่ที่ถูกคืนแล้ว — วิ่งต่อ")
                ok = true
            elseif not S.carrying then
                say(arrived and "เก็บไข่คืนไม่สำเร็จ" or "HOP/Prompt ไข่ที่ถูกไม่ทัน")
            end
        end
    end
    S.recovering = false
    return ok
end

local function returnHome()
    local deadline, lastReport = os.clock() + 180, 0
    while S.run and os.clock() < deadline do
        local h, r = humRoot()
        if not h or not r or not S.home then return false end
        if isHolding() then
            S.lastCarryPos = r.Position
        elseif not recoverDroppedEgg() then
            return false
        end
        h, r = humRoot()
        if not h or not r then return false end
        if not isHolding() then
            task.wait(0.05)
        else
            local d = dist2(r.Position, S.home)
            if d <= HOME_R then stopMove(); return true end
            -- ไกล = HOP เดินทาง (ไว) / ใกล้ = MoveTo
            if d > 90 then
                local flat = Vector3.new(S.home.X - r.Position.X, 0, S.home.Z - r.Position.Z)
                local step = math.min(14, flat.Magnitude)
                local dest = r.Position + flat.Unit * step
                r.CFrame = CFrame.new(dest.X, r.Position.Y, dest.Z) * (r.CFrame - r.CFrame.Position)
                task.wait(0.05)
            else
                h:MoveTo(Vector3.new(S.home.X, r.Position.Y, S.home.Z))
                task.wait(0.12)
            end
            if os.clock() - lastReport >= 1 then
                say(string.format("%s HOME d=%.0f", d > 90 and "HOP" or "วิ่ง", d))
                lastReport = os.clock()
            end
        end
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
    S.run, S.carrying, S.eggArea, S.skipUids = true, false, nil, {}
    S.focusZone, S.zoneIdx = nil, 1
    setFarmSpeed(true)
    bStart.Text = "..."
    task.spawn(function()
        local attempts = 0
        while S.run and attempts < 40 do
            attempts = attempts + 1
            local target = chooseTarget()
            if not target then
                say("ไม่มีเป้าเหลือ / จบคิวโซน — หยุด")
                break
            end
            S.eggArea = target.area
            S.carrying = false
            S.heldUid = tostring(target.uid)
            S.heldCat = tostring(target.cat)

            local function skipTarget(reason)
                S.skipUids[tostring(target.uid)] = true
                say(reason .. " — ข้าม รีสแกน")
            end

            local td = target.dist or 0
            say(string.format("ไปหา %s @%s%s", target.cat, tostring(target.area), td > 90 and " (HOP ทางไกล)" or ""))
            if not goTo(target.pos, math.max(STEAL_R, MATCH_R), math.max(40, (td / 10) + 20)) then
                skipTarget("ไปถึงไข่ไม่สำเร็จ")
            else
                local prompt, matchD, promptPos = promptAtTarget(target)
                if not prompt or not matchD then
                    skipTarget("ถึงตำแหน่งไข่ แต่ยังไม่เจอ Prompt Steal — เป้าอาจย้าย")
                elseif matchD > MATCH_R then
                    skipTarget(string.format("Prompt ไกลเป้าเกิน (match=%.1f)", matchD))
                else
                    say(string.format("เจอ Prompt ไข่เป้า match=%.1f — เข้าใกล้", matchD))
                    local goal = promptPos or target.pos
                    local ppPart = prompt.Parent and (prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart", true))
                    if ppPart then goal = ppPart.Position end
                    goTo(goal, APPROACH_R, 10)
                    prompt, matchD, promptPos = promptAtTarget(target)
                    if not prompt or not matchD or matchD > MATCH_R then
                        skipTarget("Prompt หาย/ไม่ตรงเป้าหลังเข้าใกล้")
                    else
                        target.pp = prompt
                        local ready, readyMatch = promptReadyToFire(target, prompt)
                        if not ready and promptPos then
                            goTo(promptPos, APPROACH_R, 6)
                            prompt, matchD, promptPos = promptAtTarget(target)
                            target.pp = prompt
                            ready, readyMatch = promptReadyToFire(target, prompt)
                        end
                        if not prompt or not ready then
                            skipTarget("Prompt ไม่ตรงไข่เป้า / ยังไม่ถึงระยะ Steal")
                        elseif S.run and not S.skipUids[tostring(target.uid)] then
                            say(string.format("ยิง Steal (match=%.1f)", readyMatch or matchD))
                            S.heldUid = tostring(target.uid)
                            S.heldCat = tostring(target.cat)
                            fireSteal(target.pp)
                            markHolding("Steal — พุ่งกลับทันที")
                            dashHomeNow()
                            say("ได้ไข่แล้ว — HOP/วิ่งกลับ")
                            task.spawn(function()
                                task.wait(0.15)
                                if S.run then
                                    local pp2 = select(1, promptAtTarget(target))
                                    if pp2 and not guiShowsCarry() then fireSteal(pp2) end
                                    dashHomeNow()
                                end
                            end)
                            if returnHome() then
                                say("ถึง HOME — วางเข้าคอกเอง")
                            else
                                say("กลับบ้านไม่สำเร็จ")
                            end
                            task.wait(0.2)
                        end
                    end
                end
            end
            task.wait(0.15)
        end
        setFarmSpeed(false)
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

local function rebuildZoneMenu()
    zoneMenu:ClearAllChildren()
    local names = zoneList()
    local h = (#names + 1) * 23
    zoneMenu.Size = UDim2.new(0, 160, 0, math.min(h, 280))
    local choices = { "ALL" }
    for _, z in ipairs(names) do choices[#choices + 1] = z end
    for i, zone in ipairs(choices) do
        local b = Instance.new("TextButton", zoneMenu)
        b.Size = UDim2.new(1, 0, 0, 21)
        b.Position = UDim2.new(0, 0, 0, (i - 1) * 23 + 1)
        b.BackgroundColor3 = Color3.fromRGB(45, 49, 58)
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        local active = zone == "ALL" and zoneText() == "ALL" or selectedZones[zone]
        b.Text = (active and "✓ " or "") .. zone
        b.ZIndex = 21
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.MouseButton1Click:Connect(function()
            if zone == "ALL" then
                local turnOn = zoneText() ~= "ALL"
                for _, name in ipairs(names) do selectedZones[name] = turnOn end
            else
                selectedZones[zone] = not selectedZones[zone]
            end
            bZone.Text = zoneText() .. " ▼"
            rebuildZoneMenu()
            say("Zone = " .. zoneText())
        end)
    end
end

bScale.MouseButton1Click:Connect(function()
    zoneMenu.Visible = false
    rarityMenu.Visible = false
    rebuildMenu(scaleMenu, SCALE_CHOICES, function(value)
        MIN_SCALE = value
        bScale.Text = string.format("%.1f ▼", value)
        say("MinScale = " .. value)
    end)
    scaleMenu.Visible = not scaleMenu.Visible
end)

bZone.MouseButton1Click:Connect(function()
    scaleMenu.Visible = false
    rarityMenu.Visible = false
    rebuildZoneMenu()
    zoneMenu.Visible = not zoneMenu.Visible
end)

bRarity.MouseButton1Click:Connect(function()
    scaleMenu.Visible = false
    zoneMenu.Visible = false
    rebuildRarityMenu()
    rarityMenu.Visible = not rarityMenu.Visible
end)

local function bindCarryRemote(carry)
    if not carry then return false end
    if not (carry:IsA("RemoteEvent") or carry:IsA("UnreliableRemoteEvent")) then return false end
    S.conns[#S.conns + 1] = carry.OnClientEvent:Connect(function(row)
        if typeof(row) == "table" and row.IsCarrying ~= nil then
            local was = S.carrying
            S.carrying = row.IsCarrying == true
            if row.AreaId then S.eggArea = row.AreaId end
            if S.carrying then
                local _, r = humRoot()
                if r then S.lastCarryPos = r.Position end
                if row.Uid ~= nil then S.heldUid = tostring(row.Uid) end
                if row.AssetCategory then S.heldCat = tostring(row.AssetCategory) end
                say("server: ถือไข่แล้ว" .. (S.heldCat and (" " .. S.heldCat) or "") .. " — วิ่งกลับได้")
            elseif was and S.run then
                say("โดนหลุดมือ — กันกระแทก + HOP ไปไข่ที่ถูก")
                if not S.recovering then
                    task.spawn(function()
                        recoverDroppedEgg()
                    end)
                end
            end
        end
    end)
    return true
end

-- FieldEggCarry: หาครั้งเดียว + พยายามอีกไม่กี่ครั้งแบบเงียบ (ไม่สแปม)
local carry = findNet("FieldEggCarry")
if bindCarryRemote(carry) then
    lines[#lines + 1] = "ฟัง FieldEggCarry ✅"
else
    lines[#lines + 1] = "ใช้ DropHeldEgg สำรอง (ยังไม่เจอ FieldEggCarry)"
    task.spawn(function()
        for _ = 1, 8 do
            task.wait(1)
            if bindCarryRemote(findNet("FieldEggCarry")) then
                say("ฟัง FieldEggCarry ✅")
                return
            end
        end
    end)
end

S.conns[#S.conns + 1] = PG.ChildAdded:Connect(function(ch)
    if S.run and (ch.Name:find("DropHeld", 1, true) or ch.Name == "DropHeldEgg") then
        markHolding("ถือไข่แล้ว — วิ่ง")
    end
end)

bHome.MouseButton1Click:Connect(function()
    local _, r = humRoot()
    if r then S.home = r.Position; say("HOME ตั้งแล้ว") else say("ไม่มีตัวละคร") end
end)
bScan.MouseButton1Click:Connect(chooseTarget)
bStart.MouseButton1Click:Connect(runOne)
bStop.MouseButton1Click:Connect(function()
    S.run = false
    S.recovering = false
    setFarmSpeed(false)
    bStart.Text = "START"
    say("STOP")
end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, "=== Egg01 Target Farm v1.18 ===\n" .. table.concat(lines, "\n")) end
    bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)
bClose.MouseButton1Click:Connect(function()
    S.run = false
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.EGG01_TARGET_FARM = nil
end)

say("HOME ที่ฐาน → เลือก Scale/Zone/Rarity จากปุ่ม → SCAN หรือ START")
