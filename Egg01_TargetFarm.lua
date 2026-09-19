-- Egg01 Target Farm v2.2
-- เลือก MinScale + Zone -> เดินไป Steal -> Drop/เก็บกลับ HOME (หนึ่งไข่ต่อรอบ)
-- ยิง Steal แล้ววิ่งกลับทันที; Carry event ใช้ตรวจไข่หลุดเมื่อมี

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

local S = { gui = nil, conns = {}, run = false, home = nil, carrying = false, eggArea = nil, carryAvailable = false, carryConn = nil, shiftConn = nil, lastCarryScan = 0, lastShiftScan = 0, hopUsed = false, skipped = {}, carriedUid = nil, droppedPos = nil, carryLostAt = 0, returning = false }
_G.EGG01_TARGET_FARM = S

local MIN_SCALE, ZONE = 1, "ALL"
local SCALE_CHOICES = { 0.1, 0.5, 1, 1.5, 2, 3, 5, 10 }
local ZONE_CHOICES = { "ALL", "Forest", "Lake", "Desert", "Snow" }
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
local RARITY_SHORT = { Common = "Com", Uncommon = "Unc", Rare = "Rare", Epic = "Epi", Legendary = "Leg", Mythic = "Myt", Cosmic = "Cos", Secret = "Sec", Eternal = "Ete", Divine = "Div" }
local RARITY_VALUE, BALANCED_RARITY_STUDS = {}, 400 -- หนึ่งขั้น rarity มีค่าน้ำหนักเท่าระยะ 400 studs
local selectedRarities = {}
for i, rarity in ipairs(RARITY_ORDER) do
    RARITY_VALUE[rarity] = i
    selectedRarities[rarity] = rarity ~= "Common" and rarity ~= "Uncommon" and rarity ~= "Rare"
end
local HOME_R, STEAL_R, APPROACH_R, RECOVER_R, PROMPT_EXACT_R = 60, 16, 7, 100, 30
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
title.Text = "Egg01 Target Farm v2.2"

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
status.Text = "BALANCED: rarity สำคัญ + ระยะ → START"

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
    local best, eligible, positioned, skipped = nil, 0, 0, 0
    local foundZones = { ALL = true }
    for key, row in pairs(records) do
        if typeof(row) == "table" then
            local pos, scale, area = posOf(row), tonumber(row.AssetScale), row.AreaId
            if area then foundZones[tostring(area)] = true end
            local rarity = rarityMap[tostring(row.AssetCategory or "")]
            local targetKey = tostring(row.Uid or key)
            local blockedUntil = S.skipped[targetKey]
            if blockedUntil and blockedUntil <= os.clock() then S.skipped[targetKey] = nil; blockedUntil = nil end
            if pos and scale and scale >= MIN_SCALE and row.State ~= "Carried" and zoneAllowed(area) and rarity and selectedRarities[rarity] and not blockedUntil then
                eligible = eligible + 1
                local dist = (pos - root.Position).Magnitude
                local score = (RARITY_VALUE[rarity] or 0) * BALANCED_RARITY_STUDS - dist
                if not best or score > best.score or (score == best.score and dist < best.dist) then
                    best = { uid = row.Uid or key, key = targetKey, cat = row.AssetCategory or "?", rar = rarity, scale = scale, area = area or "?", pos = pos, dist = dist, score = score }
                end
            elseif pos and scale and blockedUntil then
                skipped = skipped + 1
            end
            if pos then positioned = positioned + 1 end
        end
    end
    ZONE_CHOICES = { "ALL" }
    for area in pairs(foundZones) do if area ~= "ALL" then ZONE_CHOICES[#ZONE_CHOICES + 1] = area end end
    table.sort(ZONE_CHOICES, function(a, b) if a == "ALL" then return true elseif b == "ALL" then return false else return a < b end end)
    if best then
        say(string.format("TARGET %s %s sc=%.2f zone=%s d=%.0f score=%.0f", best.rar, best.cat, best.scale, best.area, best.dist, best.score))
    else
        say(string.format("ไม่เจอเป้า | pos=%d rarMap=%d ผ่าน=%d พัก=%d sc>=%.2f zone=%s", positioned, categoryCount, eligible, skipped, MIN_SCALE, ZONE))
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

local function promptAtTarget(target, matchRadius, requireNearby)
    local _, root = humRoot()
    if not root then return nil end
    local best, bestD
    for _, p in ipairs(getPrompts()) do
        local eggMatch = (p.pos - target.pos).Magnitude
        local playerDist = (p.pos - root.Position).Magnitude
        if eggMatch <= (matchRadius or 60) and (not requireNearby or playerDist <= STEAL_R) and (not bestD or eggMatch < bestD) then
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

-- HOP14 ได้เพียงครั้งเดียวต่อรอบ จากนั้นกลับไปใช้เดินปกติทั้งหมด
local function hopOnceToward(pos, radius)
    if S.hopUsed then return false end
    local h, r = humRoot()
    if not h or not r then return false end
    local flat = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z)
    if flat.Magnitude <= radius then return false end
    local step = math.min(14, flat.Magnitude - radius)
    local dest = r.Position + flat.Unit * step
    S.hopUsed = true
    h:Move(flat.Unit, false)
    r.CFrame = CFrame.new(dest.X, r.Position.Y, dest.Z) * (r.CFrame - r.CFrame.Position)
    task.wait(0.10)
    stopMove()
    return true
end

-- ใช้พิกัดจาก FieldEggShifted เพื่อไม่เก็บ Prompt ของไข่ฟองข้าง ๆ ผิดใบ
local function stealAtPosition(pos, maxDist, requireNearby)
    local _, root = humRoot()
    if not root or not pos then return nil end
    local best, bestD
    for _, p in ipairs(getPrompts()) do
        local matchD = (p.pos - pos).Magnitude
        local playerD = (p.pos - root.Position).Magnitude
        if matchD <= maxDist and (not requireNearby or playerD <= STEAL_R) and (not bestD or matchD < bestD) then
            best, bestD = p, matchD
        end
    end
    return best, bestD
end

local function skipTarget(target, seconds, reason)
    S.skipped[target.key] = os.clock() + seconds
    say(string.format("พัก %s %ds — %s", target.cat, seconds, reason))
end

-- Networking บางรอบยังไม่ถูกสร้างตอน inject; เรียกซ้ำขณะวิ่งกลับได้
local function attachCarryListener()
    if S.carryConn then return true end
    local carry = findNet("FieldEggCarry")
    if not carry or not (carry:IsA("RemoteEvent") or carry:IsA("UnreliableRemoteEvent")) then return false end
    S.carryAvailable = true
    S.carryConn = carry.OnClientEvent:Connect(function(row)
        if typeof(row) == "table" and row.IsCarrying ~= nil then
            S.carrying = row.IsCarrying == true
            S.carryLostAt = S.carrying and 0 or os.clock()
            if row.AreaId then S.eggArea = row.AreaId end
            if S.carrying then say("server: ถือไข่แล้ว") else say("server: ไข่หลุดมือ — กำลังกู้") end
        end
    end)
    S.conns[#S.conns + 1] = S.carryConn
    lines[#lines + 1] = "ฟัง FieldEggCarry ✅"
    return true
end

-- FieldEggCarry บอกสถานะของเรา; FieldEggShifted ระบุตำแหน่งของไข่ใบเดิมเมื่อมันตก
local function attachShiftListener()
    if S.shiftConn then return true end
    local shifted = findNet("FieldEggShifted")
    if not shifted or not (shifted:IsA("RemoteEvent") or shifted:IsA("UnreliableRemoteEvent")) then return false end
    S.shiftConn = shifted.OnClientEvent:Connect(function(row)
        if typeof(row) ~= "table" or not S.returning or S.carriedUid == nil then return end
        local state = tostring(row.State or "")
        if state ~= "Dropped" or tostring(row.Uid) ~= tostring(S.carriedUid) then return end
        local pos = posOf(row)
        if pos then
            S.droppedPos = pos
            S.carrying = false
            say(string.format("UID %s หลุดมือ @%.0f,%.0f — กลับไปเก็บ", tostring(S.carriedUid), pos.X, pos.Z))
        end
    end)
    S.conns[#S.conns + 1] = S.shiftConn
    lines[#lines + 1] = "ฟัง FieldEggShifted (Return Guard) ✅"
    return true
end

local function recoverDroppedEgg(dropPos)
    stopMove() -- event แจ้งหลุด: หยุดวิ่งก่อน แล้วค่อยหาจุดไข่
    local egg, d = dropPos and stealAtPosition(dropPos, 30, false) or nearestSteal(RECOVER_R)
    if not egg then
        say("ไข่หลุดมือ แต่ไม่เจอ Prompt ของ UID เดิม")
        return false
    end
    local _, root = humRoot()
    local backD = root and (egg.pos - root.Position).Magnitude or d
    say(string.format("ไข่หลุดมือ — กลับไปเก็บ UID เดิม d=%.0f", backD or 0))
    hopOnceToward(egg.pos, APPROACH_R)
    if not walkTo(egg.pos, APPROACH_R, 10) then return false end
    stopMove()
    egg = dropPos and stealAtPosition(dropPos, 30, true) or nearestSteal(STEAL_R)
    if not egg then say("Prompt UID เดิมหายระหว่างกลับไป") return false end
    if not fireSteal(egg.pp) then say("เก็บไข่คืนไม่สำเร็จ") return false end
    S.droppedPos, S.carrying = nil, true -- เดินต่อทันที แม้ Carry event ยังไม่ถูกส่ง
    say("เก็บไข่ UID เดิมแล้ว — วิ่งต่อ")
    return true
end

local function returnHome()
    local deadline, lastReport = os.clock() + 120, 0
    while S.run and os.clock() < deadline do
        local h, r = humRoot()
        if not h or not r or not S.home then return false end
        if not S.carryAvailable and os.clock() - S.lastCarryScan >= 1 then
            S.lastCarryScan = os.clock()
            attachCarryListener() -- ไม่หยุดวิ่งระหว่างค้นหา event
        end
        if not S.shiftConn and os.clock() - S.lastShiftScan >= 1 then
            S.lastShiftScan = os.clock()
            attachShiftListener() -- ไม่หยุดวิ่งระหว่างค้นหา event
        end
        local dropPos = S.droppedPos
        if dropPos then
            if not recoverDroppedEgg(dropPos) then return false end
        elseif not S.carrying then
            -- ถ้ามี Shift listener ให้รอพิกัด UID เดิมก่อน: ห้ามหยิบไข่ใกล้ตัวแบบสุ่ม
            if S.shiftConn then
                if os.clock() - (S.carryLostAt or os.clock()) >= 2 then
                    say("ไข่หลุด แต่ไม่ได้พิกัด UID เดิม — ไม่หยิบไข่อื่น")
                    return false
                end
            elseif not recoverDroppedEgg(nil) then
                return false
            end
        end
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

-- ทำหนึ่งรอบโดยไม่ปิด S.run: ตัว loop ด้านล่างจะเลือกไข่ใหม่เอง
local function farmTarget(target)
    S.carrying, S.eggArea, S.hopUsed = false, target.area, false
    say("ไปหา " .. target.cat)
    -- เข้ากลางพิกัด Snapshot ก่อน เพื่อให้ Prompt รอบไข่สตรีมเข้ามา
    if not walkTo(target.pos, 3, 80) then
        say("ไปถึงไข่ไม่สำเร็จ")
        return
    end
    stopMove() -- ยกเลิก MoveTo เดิมก่อนกด ไม่ให้ตัวละครไหลเลยไข่
    if not S.run then return end

    local prompt, matchD
    for _ = 1, 4 do
        prompt, matchD = promptAtTarget(target, PROMPT_EXACT_R, false)
        if prompt then break end
        task.wait(0.35)
    end
    if not prompt then
        local other, otherD = promptAtTarget(target, 120, false)
        if other then
            say(string.format("เจอ Prompt อื่น match=%.1f แต่ไม่ใช่ %s — ข้าม", otherD, target.cat))
            skipTarget(target, 15, "Prompt ไม่ตรง")
        else
            say("ถึงจุด Snapshot แล้ว แต่ไม่พบ Prompt — ข้าม")
            skipTarget(target, 8, "ไม่พบ Prompt")
        end
        return
    end

    target.pp = prompt
    local ppPart = prompt.Parent and (prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart", true))
    if ppPart then
        say(string.format("Prompt ของ %s match=%.1f — เข้าใกล้", target.cat, matchD))
        if hopOnceToward(ppPart.Position, APPROACH_R) then say("HOP เข้า Prompt ครั้งเดียวแล้ว") end
        if not walkTo(ppPart.Position, APPROACH_R, 8) then
            say("เข้า Prompt ไม่สำเร็จ")
            return
        end
        stopMove()
        prompt = select(1, promptAtTarget(target, PROMPT_EXACT_R, true))
        if not prompt then
            say("Prompt หายระหว่างเข้าใกล้")
            skipTarget(target, 10, "Prompt หาย")
            return
        end
        target.pp = prompt
    end
    if not S.run then return end

    say("ยิง Steal + วิ่งกลับทันที")
    if not fireSteal(target.pp) then
        say("ยิง Steal ไม่สำเร็จ")
        return
    end
    -- บางเซิร์ฟเวอร์ไม่มี FieldEggCarry ฝั่ง client: ออกจากจุดเสี่ยงก่อน
    -- ถ้า event มีและไข่หลุด มันจะเปลี่ยน carrying=false เพื่อเข้า recovery เอง
    S.carrying, S.carriedUid, S.droppedPos, S.carryLostAt, S.returning = true, target.uid, nil, 0, true
    if returnHome() then
        say("ถึง HOME — รอรอบถัดไป")
    elseif S.run then
        say("กลับบ้านไม่สำเร็จ — scan ใหม่")
    end
    S.returning, S.carriedUid, S.droppedPos = false, nil, nil
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
    S.run = true
    bStart.Text = "AUTO"
    say("AUTO ON — scan → เก็บ → กลับบ้าน → รอไข่รี (STOP เพื่อหยุด)")
    task.spawn(function()
        while S.run do
            local target = chooseTarget() -- RF Snapshot ใหม่ทุกครั้ง จึงเห็นไข่ที่เพิ่งรี
            if target then
                farmTarget(target)
                if S.run then task.wait(1) end
            else
                say("ไม่มีเป้า — รอไข่รี แล้ว scan ใหม่")
                task.wait(2)
            end
        end
        bStart.Text = "START"
        say("AUTO OFF")
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

if not attachCarryListener() then
    lines[#lines + 1] = "ไม่พบ FieldEggCarry — จะตรวจผล Steal ไม่ได้"
end
if not attachShiftListener() then
    lines[#lines + 1] = "ไม่พบ FieldEggShifted — Return Guard รอระหว่างวิ่งกลับ"
end

bHome.MouseButton1Click:Connect(function()
    local _, r = humRoot()
    if r then S.home = r.Position; say("HOME ตั้งแล้ว") else say("ไม่มีตัวละคร") end
end)
bScan.MouseButton1Click:Connect(chooseTarget)
bStart.MouseButton1Click:Connect(runOne)
bStop.MouseButton1Click:Connect(function()
    S.run = false
    stopMove()
    bStart.Text = "START"
    say("STOP")
end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, "=== Egg01 Target Farm v2.2 ===\n" .. table.concat(lines, "\n")) end
    bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)
bClose.MouseButton1Click:Connect(function()
    S.run = false
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.EGG01_TARGET_FARM = nil
end)

say("BALANCED: rarity 1 ขั้น = ระยะ 400 studs | Return Guard คุ้มกัน UID ตอนกลับบ้าน")
