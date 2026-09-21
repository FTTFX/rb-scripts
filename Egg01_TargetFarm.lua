-- Egg01 Target Farm v3.5
-- ฐาน=ลู่วิ่ง | ลู่วิ่ง→Rift(+30)→ไข่ | กลับผ่าน Rift(+30)→ลู่วิ่ง | ไข่หลุด=เก็บทันที | เบรกตาม MOTION_BRAKE
-- ยิง Steal แล้ววิ่งกลับทันที; Carry event ใช้ตรวจไข่หลุดเมื่อมี

if _G.EGG01_TARGET_FARM then
    _G.EGG01_TARGET_FARM.run = false
    pcall(function()
        if _G.EGG01_TARGET_FARM.clipConn then _G.EGG01_TARGET_FARM.clipConn:Disconnect() end
    end)
    pcall(function() _G.EGG01_TARGET_FARM.gui:Destroy() end)
    if _G.EGG01_TARGET_FARM.conns then
        for _, c in ipairs(_G.EGG01_TARGET_FARM.conns) do pcall(function() c:Disconnect() end) end
    end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local S = { gui = nil, conns = {}, run = false, carrying = false, eggArea = nil, carryAvailable = false, carryConn = nil, shiftConn = nil, lastCarryScan = 0, lastShiftScan = 0, hopUsed = false, impactHopUsed = false, lastReturnDist = nil, returnPaused = false, dropBrakeUsed = false, skipped = {}, carriedUid = nil, expectedUid = nil, carryVerified = false, carryMismatchUid = nil, droppedPos = nil, carryLostAt = 0, returning = false, needRecover = false, tread = nil, rift = nil, clipConn = nil, clipParts = {} }
_G.EGG01_TARGET_FARM = S

local MIN_SCALE, ZONE = 1, "ALL"
local SCALE_CHOICES = { 0.1, 0.5, 1, 1.5, 2, 3, 5, 10 }
local ZONE_CHOICES = { "ALL", "Forest", "Lake", "Desert", "Snow" }
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
local RARITY_SHORT = { Common = "Com", Uncommon = "Unc", Rare = "Rare", Epic = "Epi", Legendary = "Leg", Mythic = "Myt", Cosmic = "Cos", Secret = "Sec", Eternal = "Ete", Divine = "Div" }
local RARITY_VALUE, RARITY_POINTS, SCALE_SQUARED_POINTS = {}, 100000, 10000
local selectedRarities = {}
for i, rarity in ipairs(RARITY_ORDER) do
    RARITY_VALUE[rarity] = i
    selectedRarities[rarity] = rarity ~= "Common" and rarity ~= "Uncommon" and rarity ~= "Rare"
end
local STEAL_R, APPROACH_R, RECOVER_R, PROMPT_EXACT_R, RIFT_R, TREAD_R, RIFT_DEPTH = 16, 5, 100, 30, 18, 12, 30
local BRAKE_SECS = 0.12
local FALLBACK_RIFT = Vector3.new(534.0, 71.0, -340.0)
local lines = {}
local brakePulse

local function humRoot()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function setClip(on)
    if not on then
        if S.clipConn then pcall(function() S.clipConn:Disconnect() end); S.clipConn = nil end
        for part, was in pairs(S.clipParts) do
            if part and part.Parent then pcall(function() part.CanCollide = was end) end
        end
        S.clipParts = {}
        return
    end
    if S.clipConn then return end
    local function apply(ch)
        if not ch then return end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then
                if S.clipParts[p] == nil then S.clipParts[p] = p.CanCollide end
                p.CanCollide = false
            end
        end
    end
    apply(LP.Character)
    S.clipConn = RunS.Stepped:Connect(function() apply(LP.Character) end)
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
title.Text = "Egg01 Target Farm v3.5"

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

local bScan = button("SCAN", 10, 35, 58, Color3.fromRGB(55, 105, 165))
local bStart = button("START", 75, 35, 58, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 140, 35, 52, Color3.fromRGB(165, 50, 55))
local bCopy = button("COPY", 200, 35, 58, Color3.fromRGB(70, 70, 75))
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
status.Text = "ลู่วิ่ง→Rift(+30)→ไข่ | หลุด=เก็บทันที | เบรกแม่น"

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

local function rarityText()
    local out = {}
    for _, rarity in ipairs(RARITY_ORDER) do if selectedRarities[rarity] then out[#out + 1] = RARITY_SHORT[rarity] end end
    return #out == #RARITY_ORDER and "ALL" or (#out > 0 and table.concat(out, ",") or "NONE")
end

local function chooseTarget(quiet)
    readConfig()
    local rf = findNet("AskFieldEggSnapshot", "RemoteFunction")
    if not rf then
        if not quiet then say("ไม่พบ AskFieldEggSnapshot") end
        return nil
    end
    local ok, result = pcall(function() return rf:InvokeServer() end)
    if not ok or typeof(result) ~= "table" then
        if not quiet then say("Snapshot error: " .. tostring(result)) end
        return nil
    end
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
                local rarityScore = (RARITY_VALUE[rarity] or 0) * RARITY_POINTS
                local scaleScore = scale * scale * SCALE_SQUARED_POINTS
                local score = rarityScore + scaleScore - math.min(dist, 99999)
                if not best or score > best.score or (score == best.score and dist < best.dist) then
                    best = { uid = row.Uid or key, key = targetKey, cat = row.AssetCategory or "?", rar = rarity, scale = scale, area = area or "?", pos = pos, dist = dist, score = score, rarityScore = rarityScore, scaleScore = scaleScore }
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
        if not quiet then
            say(string.format("TARGET %s %s sc=%.2f zone=%s d=%.0f R=%.0f S=%.0f score=%.0f", best.rar, best.cat, best.scale, best.area, best.dist, best.rarityScore, best.scaleScore, best.score))
        end
    elseif not quiet then
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
        local d = (goal - r.Position).Magnitude
        if d <= radius then stopMove(); return true end
        h:MoveTo(goal)
        task.wait(0.12)
    end
    return false
end

local function instPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local ok, piv = pcall(function() return inst:GetPivot() end)
    if ok and piv then return piv.Position end
    local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local function findRift()
    local objs = workspace:FindFirstChild("__OBJECTS")
    local machines = objs and objs:FindFirstChild("Machines")
    local rm = machines and machines:FindFirstChild("RiftMachine")
    if rm then
        local rift = rm:FindFirstChild("Rift")
        local p = instPos(rift) or instPos(rm)
        if p then return Vector3.new(p.X, math.max(p.Y, 70), p.Z), "RiftMachine" end
    end
    return FALLBACK_RIFT, "fallback-rift"
end

local function resolveRift(quiet)
    local pos, src = findRift()
    S.rift = pos
    if not quiet then
        say(string.format("RIFT=%s @%.0f,%.0f,%.0f", tostring(src), pos.X, pos.Y, pos.Z))
    end
    return pos
end

-- จุดลึกใน Rift +30 studs ตามทิศทางเข้า (ไปไข่ / กลับลู่วิ่ง)
local function riftDeepTarget(fromPos, towardPos)
    local rift = resolveRift(true)
    local dir
    if towardPos then
        dir = Vector3.new(towardPos.X - rift.X, 0, towardPos.Z - rift.Z)
    elseif fromPos then
        dir = Vector3.new(rift.X - fromPos.X, 0, rift.Z - fromPos.Z)
    else
        dir = Vector3.new(1, 0, 0)
    end
    if dir.Magnitude < 1 then dir = Vector3.new(1, 0, 0) else dir = dir.Unit end
    local deep = Vector3.new(rift.X + dir.X * RIFT_DEPTH, math.max(rift.Y, 70), rift.Z + dir.Z * RIFT_DEPTH)
    return deep, rift
end

local function stopMove()
    local h, r = humRoot()
    if not h or not r then return end
    h:MoveTo(r.Position)
    h:Move(Vector3.zero)
    for _ = 1, 3 do
        if not r.Parent then break end
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        RunS.Heartbeat:Wait()
    end
end

-- เดินเข้าเป้าแบบชะลอ+เบรก velocity (Egg01_MOTION_BRAKE) — ห้าม CFrame
local function walkSlow(pos, radius, limit, slowNear)
    local started = os.clock()
    local moveHum, oldSpeed, lastBand
    local function restore()
        if moveHum and moveHum.Parent then moveHum.WalkSpeed = oldSpeed end
    end
    while S.run and os.clock() - started < limit do
        local h, r = humRoot()
        if not h or not r or h.Health <= 0 then restore(); return false end
        local goal = Vector3.new(pos.X, r.Position.Y, pos.Z)
        local d = (goal - r.Position).Magnitude
        if d <= radius then
            restore()
            stopMove()
            return true
        end
        if slowNear then
            if not moveHum then moveHum = h; oldSpeed = h.WalkSpeed end
            local band, cap
            if d <= 18 then band, cap = "ละเอียด", 35
            elseif d <= slowNear then band, cap = "ชะลอ", 90
            else band, cap = "ปกติ", oldSpeed end
            h.WalkSpeed = math.min(oldSpeed, cap)
            if band ~= lastBand and band ~= "ปกติ" then
                say(band .. " — เหลือ " .. math.floor(d) .. " studs")
            end
            lastBand = band
        end
        h:MoveTo(goal)
        task.wait(0.04)
    end
    restore()
    return false
end

-- ขั้น1 → Rift ลึก +30 แล้วค่อยไปเป้า
local function goViaRift(dest, radius, limit, destLabel)
    if not dest then return false end
    local _, r = humRoot()
    if not r then return false end
    local deep, rift = riftDeepTarget(r.Position, dest)
    local dDeep = dist2(r.Position, deep)
    if dDeep > RIFT_R then
        say(string.format("ขั้น1 → Rift ลึก+%.0f @%.0f,%.0f,%.0f d=%.0f", RIFT_DEPTH, deep.X, deep.Y, deep.Z, dDeep))
        local lim1 = math.clamp(dDeep / 16 + 40, 50, 320)
        local okR = walkTo(deep, RIFT_R, lim1)
        if not S.run then return false end
        say(okR and ("ถึง Rift ลึกแล้ว → " .. (destLabel or "เป้า")) or ("Rift ไม่สุด → ไป" .. (destLabel or "เป้า") .. "ต่อ"))
    end
    local _, r2 = humRoot()
    local d2 = r2 and dist2(r2.Position, dest) or 9999
    say(string.format("ขั้น2 → %s d=%.0f (เบรกเข้าไข่)", destLabel or "เป้า", d2))
    local lim2 = limit or math.clamp(d2 / 14 + 60, 60, 400)
    -- เข้าไข่ด้วย walkSlow ตาม MOTION_BRAKE (rad~5, slowNear=55)
    return walkSlow(dest, radius or APPROACH_R, lim2, 55)
end

-- ===== ลู่วิ่งรอไข่ (MoveTo เท่านั้น — ห้าม CFrame) =====
local function nearestTreadmill(refPos)
    local _, r = humRoot()
    local ref = refPos
    if not ref and S.tread and S.tread.Parent then ref = S.tread.Position end
    if not ref and r then ref = r.Position end
    if not ref then return nil end
    local best, bestD
    local ok, desc = pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return nil end
    for _, item in ipairs(desc) do
        if item:IsA("BasePart") and item.Name == "TreadmillBottom" then
            local d = (item.Position - ref).Magnitude
            if not bestD or d < bestD then best, bestD = item, d end
        end
    end
    return best, bestD
end

local function treadStandPos(bottom)
    if not bottom then return nil end
    return bottom.CFrame:PointToWorldSpace(Vector3.new(0, bottom.Size.Y * 0.5 + 2.5, 0))
end

local function onTreadmill()
    local _, r = humRoot()
    if not r then return false end
    local bottom = S.tread
    if bottom and bottom.Parent then
        local d = (bottom.Position - r.Position).Magnitude
        if d <= TREAD_R then return true end
    end
    local b, d = nearestTreadmill(r.Position)
    if b and d and d <= TREAD_R then S.tread = b; return true end
    return false
end

local function leaveTreadmill()
    local _, r0 = humRoot()
    local bottom, d = nearestTreadmill(r0 and r0.Position or nil)
    if not bottom or not d or d > 14 then return end
    S.tread = bottom
    if _G.EGG01_TREADMILL then _G.EGG01_TREADMILL.run = false end
    local h, r = humRoot()
    say(string.format("เจอไข่ — กระโดดออกจากลู่วิ่ง d=%.0f", d))
    if h then
        h.Jump = true
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
    task.wait(0.25)
    if h and r then
        local dir = Vector3.new(r.Position.X - bottom.Position.X, 0, r.Position.Z - bottom.Position.Z)
        if dir.Magnitude < 1 then dir = r.CFrame.RightVector else dir = dir.Unit end
        local dest = r.Position + dir * 16
        local t0 = os.clock()
        while S.run and os.clock() - t0 < 6 do
            local hh, rr = humRoot()
            if not hh or not rr then break end
            local g = Vector3.new(dest.X, rr.Position.Y, dest.Z)
            if (g - rr.Position).Magnitude <= 3 then break end
            hh:MoveTo(g)
            task.wait(0.08)
        end
    end
    stopMove()
end

local function returnTreadmill()
    local bottom = S.tread
    if not bottom or not bottom.Parent then
        local _, r = humRoot()
        bottom = select(1, nearestTreadmill(r and r.Position or nil))
    end
    if not bottom then say("ไม่พบเครื่องวิ่ง"); return false end
    S.tread = bottom
    local target = treadStandPos(bottom)
    if not target then return false end
    local _, r = humRoot()
    if not r then return false end
    local dist = (Vector3.new(target.X, r.Position.Y, target.Z) - r.Position).Magnitude
    local lim = math.clamp(dist / 14 + 35, 50, 220)
    say(string.format("กลับลู่วิ่งรอ d=%.0f", dist))
    stopMove()
    local ok = walkSlow(target, 3.5, lim, 55)
    if not ok then
        say("ขึ้นลู่วิ่งไม่สุด — ลองชิดอีกครั้ง")
        ok = walkSlow(target, 4, 25, 40)
    end
    stopMove()
    local _, r2 = humRoot()
    local onPad = r2 and bottom.Parent and (bottom.Position - r2.Position).Magnitude <= TREAD_R
    if onPad then
        S.tread = bottom
        say("อยู่ลู่วิ่งแล้ว — สแกนรอไข่ " .. rarityText())
        return true
    end
    say("ยังไม่ขึ้นลู่วิ่งได้ — จะลองใหม่")
    return false
end

local function jogTreadTick(n)
    local bottom = S.tread
    if not bottom or not bottom.Parent then return n end
    local h, r = humRoot()
    if not h or not r then return n end
    local offset = Vector3.new(math.sin(n) * 1.2, bottom.Size.Y * 0.5 + 2.5, math.cos(n) * 1.2)
    local step = bottom.CFrame:PointToWorldSpace(offset)
    h:MoveTo(Vector3.new(step.X, r.Position.Y, step.Z))
    return n + math.pi * 0.5
end

-- สแกนเงียบบนลู่วิ่งจนกว่าจะเจอไข่ตามที่ติ๊ก
local function waitEggOnTread()
    local n, lastSay, lastMount = 0, 0, 0
    if not onTreadmill() then
        returnTreadmill()
    end
    while S.run do
        local target = chooseTarget(true)
        if target then
            say(string.format("TARGET %s %s sc=%.2f zone=%s d=%.0f", target.rar, target.cat, target.scale, target.area, target.dist))
            return target
        end
        if onTreadmill() then
            n = jogTreadTick(n)
            if os.clock() - lastSay >= 20 then
                say("ลู่วิ่งรอไข่ | " .. rarityText() .. " sc>=" .. tostring(MIN_SCALE) .. " zone=" .. tostring(ZONE))
                lastSay = os.clock()
            end
            task.wait(0.45)
        else
            if os.clock() - lastMount >= 3 then
                say("ยังไม่บนลู่วิ่ง — วิ่งขึ้นใหม่ (เบรก)")
                returnTreadmill()
                lastMount = os.clock()
            end
            task.wait(1)
        end
    end
    return nil
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

-- HOP14 ได้เพียงครั้งเดียวต่อรอบ — MoveTo เท่านั้น (ห้าม CFrame)
local function hopOnceToward(pos, radius)
    if S.hopUsed then return false end
    local h, r = humRoot()
    if not h or not r then return false end
    local flat = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z)
    if flat.Magnitude <= radius then return false end
    local step = math.min(14, flat.Magnitude - radius)
    local dest = r.Position + flat.Unit * step
    S.hopUsed = true
    h:MoveTo(Vector3.new(dest.X, r.Position.Y, dest.Z))
    task.wait(0.12)
    stopMove()
    return true
end

-- ตัดเฉพาะแกน "ล็อกตัว" จาก 78RB_Fly: BodyVelocity=0 ชั่วครู่ แล้วลบทันที
-- ไม่เปิด Fly loop/NOCLIP และไม่บังคับความเร็วระหว่างเดิน
brakePulse = function(h, r, reason)
    if not h or not r or not r.Parent then return false end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "Egg01_BrakePulse"
    bv.MaxForce = Vector3.new(1, 1, 1) * 9e9
    bv.Velocity = Vector3.zero
    bv.Parent = r
    task.wait(BRAKE_SECS)
    pcall(function() bv:Destroy() end)
    if h.Parent and r.Parent then
        h.PlatformStand = false
        h.Sit = false
        h:MoveTo(r.Position)
        h:Move(Vector3.zero)
    end
    if reason then say(string.format("เบรกนิ่ง %.2fs — %s", BRAKE_SECS, reason)) end
    return true
end

-- กันโดนตีตอนแบกกลับลู่วิ่ง: เบรกแล้ว MoveTo เป้า (ห้าม CFrame)
local function impactHopToward(h, r, goal, arriveR, curDist)
    if S.impactHopUsed or not goal then return false end
    local state = h:GetState()
    local disrupted = h.PlatformStand
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.PlatformStanding
    local pushedBack = S.lastReturnDist and curDist >= S.lastReturnDist + 12
    if not disrupted and not pushedBack then return false end
    local flat = Vector3.new(goal.X - r.Position.X, 0, goal.Z - r.Position.Z)
    if flat.Magnitude <= (arriveR or TREAD_R) then return false end
    local reason = disrupted and ("state=" .. state.Name) or "ถูกผลักถอย"
    S.impactHopUsed = true
    brakePulse(h, r, "รับแรงกระแทก")
    h.PlatformStand = false
    h.Sit = false
    h:ChangeState(Enum.HumanoidStateType.Running)
    local step = math.min(14, flat.Magnitude - (arriveR or TREAD_R))
    local dest = r.Position + flat.Unit * step
    h:MoveTo(Vector3.new(dest.X, r.Position.Y, dest.Z))
    task.wait(0.10)
    stopMove()
    say("โดนตี/กระแทก (" .. reason .. ") — กู้ครั้งเดียว แล้ววิ่งต่อ")
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
            if S.carrying then S.returnPaused, S.dropBrakeUsed = false, false end
            if S.carrying and S.expectedUid and row.Uid then
                if tostring(row.Uid) == tostring(S.expectedUid) then
                    S.carryVerified = true
                    say("server: ถือ UID เป้าหมายถูกต้อง")
                else
                    S.carryMismatchUid = row.Uid
                    S.carrying = false
                    say("server: UID ที่ถือไม่ตรงเป้า — หยุด")
                end
            elseif S.carrying then
                say("server: ถือไข่แล้ว")
            else
                if S.returning then
                    S.returnPaused = true
                    S.needRecover = true
                    if not S.dropBrakeUsed then
                        S.dropBrakeUsed = true
                        stopMove() -- เบรก velocity ตาม MOTION_BRAKE
                        say("server: ไข่หลุดมือ — เบรกแล้วไปเก็บทันที")
                    else
                        say("server: ไข่หลุดมือ — ไปเก็บทันที")
                    end
                else
                    S.needRecover = true
                    say("server: ไข่หลุดมือ — กำลังกู้")
                end
            end
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
            S.returnPaused = true
            S.needRecover = true
            if not S.dropBrakeUsed then
                S.dropBrakeUsed = true
                stopMove()
            end
            say(string.format("UID %s หลุดมือ @%.0f,%.0f — เก็บทันที", tostring(S.carriedUid), pos.X, pos.Z))
        end
    end)
    S.conns[#S.conns + 1] = S.shiftConn
    lines[#lines + 1] = "ฟัง FieldEggShifted (Return Guard) ✅"
    return true
end

local function recoverDroppedEgg(dropPos)
    stopMove()
    S.needRecover = false
    local egg, d = dropPos and stealAtPosition(dropPos, 40, false) or nearestSteal(RECOVER_R)
    if not egg and dropPos then
        -- ยังไม่มี Prompt — วิ่งเข้าพิกัดหลุดก่อน แล้วสแกนใหม่
        say(string.format("ไข่หลุด — วิ่งเข้าจุดตกทันที @%.0f,%.0f", dropPos.X, dropPos.Z))
        walkSlow(dropPos, 5, 25, 55)
        egg = stealAtPosition(dropPos, 40, false) or nearestSteal(STEAL_R)
    end
    if not egg then
        say("ไข่หลุดมือ แต่ไม่เจอ Prompt ของ UID เดิม")
        return false
    end
    local _, root = humRoot()
    local backD = root and (egg.pos - root.Position).Magnitude or d
    say(string.format("ไข่หลุดมือ — เก็บทันที d=%.0f (เบรกเข้าไข่)", backD or 0))
    if not walkSlow(egg.pos, APPROACH_R, math.max(12, (backD or 20) / 10 + 10), 55) then
        return false
    end
    egg = dropPos and stealAtPosition(dropPos, 40, true) or nearestSteal(STEAL_R)
    if not egg then
        egg = (dropPos and stealAtPosition(dropPos, 40, false)) or nearestSteal(STEAL_R)
    end
    if not egg then say("Prompt UID เดิมหายระหว่างกลับไป") return false end
    local ppPart = egg.pp and egg.pp.Parent and (egg.pp.Parent:IsA("BasePart") and egg.pp.Parent or egg.pp.Parent:FindFirstChildWhichIsA("BasePart", true))
    if ppPart then
        walkSlow(ppPart.Position, 3.2, 10, 14)
        egg = dropPos and stealAtPosition(dropPos, 40, true) or nearestSteal(STEAL_R) or egg
    end
    if not fireSteal(egg.pp) then say("เก็บไข่คืนไม่สำเร็จ") return false end
    S.droppedPos, S.carrying, S.returnPaused, S.dropBrakeUsed, S.needRecover = nil, true, false, false, false
    say("เก็บไข่ UID เดิมแล้ว — วิ่งต่อ")
    return true
end

-- กลับพร้อมไข่: ไข่ → Rift → ลู่วิ่ง
local function returnToTread()
    local deadline, lastReport = os.clock() + 180, 0
    S.impactHopUsed, S.lastReturnDist = false, nil
    resolveRift(true)
    local phase = "rift"
    while S.run and os.clock() < deadline do
        local h, r = humRoot()
        if not h or not r then return false end
        if S.carryMismatchUid then
            say("หยุดกลับลู่วิ่ง: ได้ UID คนละฟอง")
            return false
        end
        if not S.carryAvailable and os.clock() - S.lastCarryScan >= 1 then
            S.lastCarryScan = os.clock()
            attachCarryListener()
        end
        if not S.shiftConn and os.clock() - S.lastShiftScan >= 1 then
            S.lastShiftScan = os.clock()
            attachShiftListener()
        end
        local dropPos = S.droppedPos
        -- ไข่หลุด → ไปเก็บทันที (รอ Shift สั้นมาก ≤0.35s ถ้ายังไม่มีพิกัด)
        if not S.carrying and (dropPos or S.needRecover or S.returnPaused) then
            if not dropPos and S.shiftConn and (os.clock() - (S.carryLostAt or 0)) < 0.35 then
                stopMove()
                task.wait(0.05)
            else
                if not recoverDroppedEgg(dropPos) then
                    if S.shiftConn and not dropPos and (os.clock() - (S.carryLostAt or 0)) < 1.2 then
                        task.wait(0.08)
                    else
                        say("เก็บไข่หลุดไม่สำเร็จ")
                        return false
                    end
                end
            end
        else
            h, r = humRoot()
            if not h or not r then return false end
            if onTreadmill() then
                stopMove()
                return true
            end
            local treadPos = S.tread and S.tread.Parent and treadStandPos(S.tread)
            local deep = select(1, riftDeepTarget(r.Position, treadPos))
            if phase == "rift" and deep then
                local dR = dist2(r.Position, deep)
                if dR <= RIFT_R then
                    phase = "tread"
                    say("ถึง Rift ลึกแล้ว → กลับลู่วิ่ง")
                else
                    S.lastReturnDist = dR
                    h:MoveTo(Vector3.new(deep.X, r.Position.Y, deep.Z))
                    if os.clock() - lastReport >= 1 then
                        say(string.format("วิ่งกลับผ่าน Rift ลึก+%.0f d=%.0f", RIFT_DEPTH, dR))
                        lastReport = os.clock()
                    end
                    task.wait(0.15)
                end
            else
                if returnTreadmill() then return true end
                task.wait(0.5)
            end
        end
    end
    return false
end

-- ทำหนึ่งรอบโดยไม่ปิด S.run: ตัว loop ด้านล่างจะเลือกไข่ใหม่เอง
local function farmTarget(target)
    S.carrying, S.eggArea, S.hopUsed = false, target.area, false
    say("ไปหา " .. target.cat .. " | ลู่วิ่ง→Rift(+30)→ไข่")
    -- ลู่วิ่ง → Rift ลึก → ไข่ (walkSlow เบรกตาม MOTION_BRAKE)
    local reachedTarget = goViaRift(target.pos, APPROACH_R, 120, target.cat)
    if not reachedTarget then
        say("ไปถึงไข่ไม่สำเร็จ")
        return
    end
    stopMove()
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
        say(string.format("Prompt ของ %s match=%.1f — เบรกเข้าใกล้", target.cat, matchD))
        local reachedPrompt = walkSlow(ppPart.Position, 3.2, 12, 14)
        if not reachedPrompt then
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
    S.expectedUid, S.carryVerified, S.carryMismatchUid = target.uid, false, nil
    if not fireSteal(target.pp) then
        say("ยิง Steal ไม่สำเร็จ")
        S.expectedUid = nil
        return
    end
    -- บางเซิร์ฟเวอร์ไม่มี FieldEggCarry ฝั่ง client: ออกจากจุดเสี่ยงก่อน
    -- ถ้า event มีและไข่หลุด มันจะเปลี่ยน carrying=false เพื่อเข้า recovery เอง
    S.carriedUid, S.droppedPos, S.carryLostAt, S.returning, S.returnPaused, S.dropBrakeUsed, S.needRecover = target.uid, nil, 0, true, false, false, false
    -- event อาจตอบทันทีใน fireSteal; อย่าเขียนทับผล UID ไม่ตรง
    if not S.carryMismatchUid then S.carrying = true end
    if returnToTread() then
        say("ถึงลู่วิ่งแล้ว — รอรอบถัดไป")
    elseif S.run then
        say("กลับลู่วิ่งไม่สำเร็จ — scan ใหม่")
    end
    S.returning, S.carriedUid, S.expectedUid, S.droppedPos, S.returnPaused, S.dropBrakeUsed, S.needRecover = false, nil, nil, nil, false, false, false
end

local function runOne()
    if S.run then return end
    if not fp then say("executor ไม่มี fireproximityprompt") return end
    S.run = true
    bStart.Text = "AUTO"
    say("AUTO ON — ลู่วิ่ง→Rift(+30)→ไข่→Rift(+30)→ลู่วิ่ง | หลุด=เก็บทันที")
    resolveRift()
    task.spawn(function()
        if not onTreadmill() then
            say("เปิดมา — ขึ้นลู่วิ่งก่อน")
            returnTreadmill()
        end
        while S.run do
            local target = chooseTarget(true)
            if not target then
                target = waitEggOnTread()
            end
            if not S.run or not target then break end
            leaveTreadmill()
            if not S.run then break end
            farmTarget(target)
            if S.run then task.wait(1) end
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
    if clip then pcall(clip, "=== Egg01 Target Farm v3.5 ===\n" .. table.concat(lines, "\n")) end
    bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)
bClose.MouseButton1Click:Connect(function()
    S.run = false
    setClip(false)
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.EGG01_TARGET_FARM = nil
end)

LP.CharacterAdded:Connect(function(ch)
    if not S.gui or not S.gui.Parent then return end
    task.wait(0.5)
    pcall(function() ch:WaitForChild("HumanoidRootPart", 8) end)
    setClip(true)
end)

setClip(true)
say("v3.5 | Rift+30 | เบรก walkSlow | ไข่หลุด=เก็บทันที | noclip ON")
task.spawn(function()
    local c = LP.Character or LP.CharacterAdded:Wait()
    if c then pcall(function() c:WaitForChild("HumanoidRootPart", 8) end) end
    task.wait(0.4)
    if S.gui and S.gui.Parent then runOne() end
end)
