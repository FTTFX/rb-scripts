-- Egg01 Target Farm v3.11 (ยิงไข่แบบ RiftFarm / MOTION_BRAKE)
-- HOME→Rift→ไข่→Rift→HOME | ไม่เจอ=ลู่วิ่งใกล้ HOME | เดิน MoveTo ธรรมดา (ไม่ดัน velocity) | noclip
-- v3.11: rarity เป็นหลัก — Div/Ete ชนะทุกเงื่อนไข ระยะเป็นรอง (DIST_POINTS=40)

if _G.EGG01_TARGET_FARM then
    _G.EGG01_TARGET_FARM.run = false
    pcall(function()
        if _G.EGG01_TARGET_FARM.clipConn then _G.EGG01_TARGET_FARM.clipConn:Disconnect() end
    end)
    pcall(function() _G.EGG01_TARGET_FARM.gui:Destroy() end)
    if _G.EGG01_TARGET_FARM.conns then
        for _, c in ipairs(_G.EGG01_TARGET_FARM.conns) do pcall(function() c:Disconnect() end) end
    end
    if _G.EGG01_TARGET_FARM.eggConns then
        for _, c in ipairs(_G.EGG01_TARGET_FARM.eggConns) do pcall(function() c:Disconnect() end) end
    end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local S = { gui = nil, conns = {}, run = false, home = nil, carrying = false, eggArea = nil, carryAvailable = false, carryConn = nil, shiftConn = nil, lastCarryScan = 0, lastShiftScan = 0, hopUsed = false, impactHopUsed = false, lastReturnDist = nil, returnPaused = false, dropBrakeUsed = false, skipped = {}, carriedUid = nil, expectedUid = nil, carryVerified = false, carryMismatchUid = nil, droppedPos = nil, carryLostAt = 0, returning = false, tread = nil, rift = nil, clipConn = nil, clipParts = {}, stealGraceUntil = 0, eggDB = {}, eggConns = {} }
_G.EGG01_TARGET_FARM = S

local MIN_SCALE, ZONE = 1, "ALL"
local SCALE_CHOICES = { 0.1, 0.5, 1, 1.5, 2, 3, 5, 10 }
local ZONE_CHOICES = { "ALL", "Forest", "Lake", "Desert", "Snow" }
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
local RARITY_SHORT = { Common = "Com", Uncommon = "Unc", Rare = "Rare", Epic = "Epi", Legendary = "Leg", Mythic = "Myt", Cosmic = "Cos", Secret = "Sec", Eternal = "Ete", Divine = "Div" }
local RARITY_VALUE, RARITY_POINTS, SCALE_SQUARED_POINTS, DIST_POINTS = {}, 100000, 10000, 40
local selectedRarities = {}
for i, rarity in ipairs(RARITY_ORDER) do
    RARITY_VALUE[rarity] = i
    selectedRarities[rarity] = rarity == "Cosmic" or rarity == "Secret" or rarity == "Eternal" or rarity == "Divine"
end
local HOME_R, STEAL_R, APPROACH_R, RECOVER_R, PROMPT_EXACT_R, RIFT_R, TREAD_R, RIFT_DEPTH = 60, 16, 5, 100, 18, 6, 12, -8
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


local netCache = {}
local function findNet(name, className)
    if netCache[name] then return netCache[name] end
    local packages = RS:FindFirstChild("Packages")
    local networking = packages and packages:FindFirstChild("Networking")
    local exact, fuzzy
    for _, root in ipairs({ networking, RS }) do
        if root then
            for _, item in ipairs(root:GetDescendants()) do
                if className and not item:IsA(className) then
                    -- skip
                else
                    local n = item.Name
                    -- ตรงชื่อ / ลงท้าย /Name — กัน AskFieldEggCarry มาแทน FieldEggCarry
                    local isExact = (n == name) or (n:sub(-#name - 1) == "/" .. name)
                    local isFuzzy = (not isExact) and n:find(name, 1, true)
                        and not n:find("Ask" .. name, 1, true)
                        and not n:find("AskField", 1, true)
                    if isExact then
                        exact = exact or item
                    elseif isFuzzy then
                        fuzzy = fuzzy or item
                    end
                end
            end
        end
    end
    local hit = exact or fuzzy
    netCache[name] = hit -- ponytail: nil ก็แคช — remote ไม่หายไปกลางเซสชัน; ถ้าเกมสร้างช้า ให้ลบแคชตอน inject ช้า
    return hit
end

-- FieldEggCarry ต้องเป็น RE (อย่าไปจับ AskFieldEggCarry RF)
local function findCarryEvent()
    local packages = RS:FindFirstChild("Packages")
    local networking = packages and packages:FindFirstChild("Networking")
    if not networking then return nil end
    for _, item in ipairs(networking:GetDescendants()) do
        if item:IsA("RemoteEvent") or item:IsA("UnreliableRemoteEvent") then
            local n = item.Name
            if n == "FieldEggCarry" or n:find("/FieldEggCarry", 1, true)
                or (n:find("FieldEggCarry", 1, true) and not n:find("Ask", 1, true)) then
                return item
            end
        end
    end
    return findNet("FieldEggCarry", "RemoteEvent") or findNet("FieldEggCarry", "UnreliableRemoteEvent")
end

local function tryAskCarry(uid)
    if not uid then return false end
    local rf = findNet("AskFieldEggCarry", "RemoteFunction")
    if not rf then return false end
    local ok = pcall(function() return rf:InvokeServer({ Uid = tostring(uid) }) end)
    return ok
end

-- ทิ้งไข่ที่ถือผิดฟอง (ไม่ข้ามเป้า)
local function tryDropHeld()
    local rf = findNet("AskFieldEggDrop", "RemoteFunction")
        or findNet("AskFieldEggDrop")
    if rf then
        if rf:IsA("RemoteFunction") then
            pcall(function() rf:InvokeServer({}) end)
        elseif rf:IsA("RemoteEvent") or rf:IsA("UnreliableRemoteEvent") then
            pcall(function() rf:FireServer({}) end)
        end
    end
    local g = PG:FindFirstChild("DropHeldEgg")
    local b = g and g:FindFirstChildWhichIsA("GuiButton", true)
    if b then
        pcall(function()
            if getconnections then
                for _, sig in ipairs({ b.Activated, b.MouseButton1Click }) do
                    for _, c in ipairs(getconnections(sig)) do
                        pcall(function() if c.Function then c.Function() end end)
                    end
                end
            end
            if firesignal then firesignal(b.Activated) end
        end)
    end
    S.carrying = false
    S.carryVerified = false
    S.carryMismatchUid = nil
    S.returnPaused = false
    S.droppedPos = nil
    task.wait(0.45)
end

-- ===== eggDB realtime (แบบ RiftFarm) — รู้ตำแหน่ง/สถานะไข่ทุกฟอง =====
local function upsertEgg(row, uidHint)
    if typeof(row) ~= "table" then return false end
    local uid = row.Uid or uidHint
    if not uid then return false end
    uid = tostring(uid)
    local e = S.eggDB[uid] or { uid = uid }
    if row.AssetCategory then e.cat = tostring(row.AssetCategory) end
    if row.AreaId then e.area = tostring(row.AreaId) end
    if row.State then e.state = tostring(row.State) end
    local p = posOf(row)
    if p then e.pos = p end
    e.t = os.clock()
    S.eggDB[uid] = e
    return true
end

local function ingestEggs(value)
    if typeof(value) ~= "table" then return 0 end
    local n = 0
    local records = value.Records or value.records
    if typeof(records) == "table" then
        for k, row in pairs(records) do
            if upsertEgg(row, typeof(k) == "string" and k or nil) then n = n + 1 end
        end
        return n
    end
    if value[1] then
        for _, row in ipairs(value) do
            if typeof(row) == "table" and (row.Records or row.records) then n = n + ingestEggs(row)
            elseif upsertEgg(row) then n = n + 1 end
        end
        return n
    end
    if upsertEgg(value) then return 1 end
    for k, row in pairs(value) do
        if upsertEgg(row, typeof(k) == "string" and k or nil) then n = n + 1 end
    end
    return n
end

local function attachEggFeed()
    if #S.eggConns > 0 then return true end
    local function bind(name, fn)
        local e = findNet(name)
        if e and (e:IsA("RemoteEvent") or e:IsA("UnreliableRemoteEvent")) then
            local ok, conn = pcall(function() return e.OnClientEvent:Connect(fn) end)
            if ok and conn then S.eggConns[#S.eggConns + 1] = conn; return true end
        end
        return false
    end
    bind("FieldEggShifted", function(row) upsertEgg(row) end)
    bind("FieldEggBatchShifted", function(v) ingestEggs(v) end)
    bind("FieldEggGone", function(row)
        local uid = typeof(row) == "table" and row.Uid or row
        if uid then S.eggDB[tostring(uid)] = nil end
    end)
    return #S.eggConns > 0
end

-- ไข่ยังอยู่จุดหลุดจริงไหม: มีใน DB + State=Dropped + พิกัดใกล้จุดหลุด
local function eggStillDropped(uid, dropPos)
    if not uid then return false, "ไม่มี UID" end
    local e = S.eggDB[tostring(uid)]
    if not e then return false, "หายจาก DB (ถูกเก็บ/หาย)" end
    if e.state and e.state ~= "Dropped" then return false, "State=" .. e.state end
    if dropPos and e.pos then
        local d = dist2(e.pos, dropPos)
        if d > 25 then return false, string.format("ย้ายไป %.0f studs", d) end
    end
    return true
end

-- ใครอยู่ใกล้จุดไข่ (กันแย่ง/กันเดินทับเพื่อน)
local function nearestPlayerTo(pos, ignoreLP)
    local best, bestD
    for _, pl in ipairs(Players:GetPlayers()) do
        if not ignoreLP or pl ~= LP then
            local c = pl.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r then
                local d = dist2(r.Position, pos)
                if not bestD or d < bestD then best, bestD = pl, d end
            end
        end
    end
    return best, bestD
end

local function lookingLikeCarry()
    local c = LP.Character
    if not c then return false end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") then
            local n = t.Name:lower()
            if n:find("egg", 1, true) or n:find("carry", 1, true) then return true end
        end
    end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Model") then
            local n = d.Name:lower()
            if (n:find("carried", 1, true) or n:find("heldegg", 1, true) or n == "egg") and d:IsDescendantOf(c) then
                if n:find("egg", 1, true) or n:find("carry", 1, true) then return true end
            end
        end
    end
    return false
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
title.Text = "Egg01 Target Farm v3.11 (Rarity-first)"

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
local bRarity = button("Cos,Sec,Ete,Div ▼", 250, 84, 72, Color3.fromRGB(110, 70, 170))

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
status.Text = "กด HOME ที่ฐาน → AUTO | HOME→Rift→ไข่→HOME"

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

local rarityCache = nil -- ponytail: แคช getgc scan — config rarity คงที่ทั้งเซสชัน; ล้างเมื่อไหร่ก็ได้ถ้าเกมอัปเดตกลางเซสชัน
local function mapRarities(records)
    if rarityCache then return rarityCache, rarityCache.n end
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
    rarityCache = found; rarityCache.n = n
    return found, n
end

local promptCache, promptCacheAt = {}, 0
local function getPrompts()
    -- ponytail: แคช 0.5s — GetDescendants ทั้ง workspace ต่อครั้ง; ถ้าไข่เกิดใหม่เร็วกว่า ลดเวลา
    local now = os.clock()
    if now - promptCacheAt < 0.5 then return promptCache end
    local out = {}
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("ProximityPrompt") and item.Enabled and tostring(item.ActionText):lower():find("steal", 1, true) then
            local p = item.Parent
            local part = p and (p:IsA("BasePart") and p or p:FindFirstChildWhichIsA("BasePart", true))
            if part then out[#out + 1] = { pp = item, pos = part.Position } end
        end
    end
    promptCache, promptCacheAt = out, now
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
    for key, row in pairs(records) do
        if typeof(row) == "table" then upsertEgg(row, typeof(key) == "string" and key or nil) end
    end
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
                local score = rarityScore + scaleScore - math.min(dist, 99999) * DIST_POINTS
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

-- เดินแบบ v3.3: MoveTo + ชะลอ WalkSpeed (Egg01_MOTION_BRAKE) — ไม่ดัน velocity
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

local function walkTo(pos, radius, limit, slowNear)
    if not pos then return false end
    local started = os.clock()
    local moveHum, oldSpeed, lastBand
    local function restore()
        if moveHum and moveHum.Parent then moveHum.WalkSpeed = oldSpeed end
    end
    while S.run and os.clock() - started < (limit or 90) do
        local h, r = humRoot()
        if not h or not r or h.Health <= 0 then restore(); return false end
        local goal = Vector3.new(pos.X, r.Position.Y, pos.Z)
        local d = (goal - r.Position).Magnitude
        if d <= (radius or 8) then
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

local function walkSlow(pos, radius, limit, slowNear)
    return walkTo(pos, radius, limit, slowNear or 55)
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

-- จุด Rift ลึก RIFT_DEPTH (-8 = ฝั่งปลอดภัย ก่อนเข้าเส้น)
local function riftDeepTarget(towardPos)
    local rift = resolveRift(true)
    local dir = Vector3.new(1, 0, 0)
    if towardPos then
        local flat = Vector3.new(towardPos.X - rift.X, 0, towardPos.Z - rift.Z)
        if flat.Magnitude >= 1 then dir = flat.Unit end
    end
    return Vector3.new(rift.X + dir.X * RIFT_DEPTH, math.max(rift.Y, 70), rift.Z + dir.Z * RIFT_DEPTH), rift
end

-- HOME/ลู่วิ่ง → Rift ก่อนเส้น → เป้า
local function goViaRift(dest, radius, limit, destLabel)
    if not dest then return false end
    local deep = select(1, riftDeepTarget(dest))
    local _, r = humRoot()
    if not r then return false end
    local dR = dist2(r.Position, deep)
    if dR > RIFT_R then
        say(string.format("ขั้น1 → Rift ลึก%+d @%.0f,%.0f,%.0f d=%.0f", RIFT_DEPTH, deep.X, deep.Y, deep.Z, dR))
        local lim1 = math.clamp(dR / 16 + 40, 50, 320)
        local okR = walkTo(deep, RIFT_R, lim1, 55)
        if not S.run then return false end
        say(okR and ("ถึง Rift ลึกแล้ว → " .. (destLabel or "เป้า")) or ("Rift ไม่สุด → ไปต่อ"))
    end
    local _, r2 = humRoot()
    local d2 = r2 and dist2(r2.Position, dest) or 9999
    say(string.format("ขั้น2 → %s d=%.0f", destLabel or "เป้า", d2))
    local lim2 = limit or math.clamp(d2 / 14 + 60, 60, 400)
    return walkTo(dest, radius or APPROACH_R, lim2, 55)
end

-- ===== ลู่วิ่งรอไข่ (ใกล้ HOME) =====
local function nearestTreadmill(refPos)
    local _, r = humRoot()
    local ref = refPos or S.home or (r and r.Position)
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
    if bottom and bottom.Parent and (bottom.Position - r.Position).Magnitude <= TREAD_R then return true end
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
        walkTo(r.Position + dir * 16, 3, 6, nil)
    end
    stopMove()
end

local function returnTreadmill()
    local bottom = select(1, nearestTreadmill(S.home))
    if not bottom or not bottom.Parent then bottom = select(1, nearestTreadmill()) end
    if not bottom then say("ไม่พบเครื่องวิ่ง"); return false end
    S.tread = bottom
    local target = treadStandPos(bottom)
    if not target then return false end
    local _, r = humRoot()
    local lim = r and math.clamp((target - r.Position).Magnitude / 18 + 25, 45, 200) or 90
    say("ไม่มีเป้า — กลับลู่วิ่งรอ")
    local ok = walkSlow(target, 3.5, lim, 55)
    if ok then say("อยู่ลู่วิ่งแล้ว — สแกนรอไข่ " .. rarityText()) end
    return ok
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

local function waitEggOnTread()
    local n, lastSay, lastMount, lastScan, staleRounds = 0, 0, 0, 0, 0
    if not onTreadmill() then returnTreadmill() end
    while S.run do
        -- ponytail: throttle สแกน 4s — AskFieldEggSnapshot คือ InvokeServer; egg feed จะบอกเมื่อไข่เกิดใหม่เช่นกัน
        if os.clock() - lastScan >= 4 then
            lastScan = os.clock()
            local target = chooseTarget(true)
            if target then
                staleRounds = 0
                say(string.format("TARGET %s %s sc=%.2f zone=%s d=%.0f", target.rar, target.cat, target.scale, target.area, target.dist))
                return target
            end
            -- ไม่เจอ 2 รอบติด = ข้อมูลค้าง → ล้าง eggDB ทั้งก้อน ให้ snapshot/feed เติมใหม่
            staleRounds = staleRounds + 1
            if staleRounds >= 2 then
                staleRounds = 0
                local n0 = 0
                for _ in pairs(S.eggDB) do n0 = n0 + 1 end
                S.eggDB = {}
                promptCacheAt = 0 -- บังคับ rescan Prompt ด้วย
                say(string.format("ล้างข้อมูลไข่ค้าง %d ฟอง — รีเฟรชหาจริง", n0))
            end
        end
        if onTreadmill() then
            n = jogTreadTick(n)
            if os.clock() - lastSay >= 20 then
                say("ลู่วิ่งรอไข่ | " .. rarityText())
                lastSay = os.clock()
            end
            task.wait(0.45)
        else
            if os.clock() - lastMount >= 3 then
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

-- รอยืนยันถือไข่แบบ RiftFarm: มี Carry RE → ต้อง carryVerified (UID ตรง) เท่านั้น
local function waitCarryConfirm(secs, target, dropPos)
    local t = os.clock()
    local lim = secs or 2.0
    while S.run and os.clock() - t < lim do
        if S.carryMismatchUid then return false, "uid-ผิด" end
        if S.carryAvailable then
            if S.carryVerified and S.carrying then return true, "carry-uid" end
        elseif S.carrying then
            return true, "carry"
        end
        task.wait(0.05)
    end
    if S.carryMismatchUid then return false, "uid-ผิด" end
    if S.carryAvailable and S.carryVerified and S.carrying then return true, "carry-uid" end
    if not S.carryAvailable and S.carrying then return true, "carry" end
    return false, S.carryAvailable and "รอ-uid" or "timeout"
end

local function markHolding(why)
    S.carrying = true
    S.droppedPos = nil
    S.returnPaused = false
    S.dropBrakeUsed = false
    S.stealGraceUntil = os.clock() + 2.5
    say("ถือไข่แล้ว (" .. tostring(why or "?") .. ") — วิ่งต่อ")
end

-- ตำแหน่งเดินเข้าใกล้ Prompt ที่ใกล้พิกัดไข่ UID (RiftFarm nearestStealPos)
local function nearestStealPos(eggPos)
    if not eggPos then return nil end
    local best, bestD
    for _, p in ipairs(getPrompts()) do
        local d = (p.pos - eggPos).Magnitude
        if d <= 14 and (not bestD or d < bestD) then best, bestD = p.pos, d end
    end
    return best, bestD
end

-- เลือก Steal ใกล้พิกัดไข่ที่สุดใน 18 studs — ไม่บังคับ gap (ตาม Egg01_MOTION_BRAKE.md)
local function choosePrompt(t)
    local _, me = humRoot()
    local eggPos = (t and (t.eggPos or t.pos)) or nil
    if not me or not eggPos then return nil end
    local cands = {}
    for _, p in ipairs(getPrompts()) do
        local d = (p.pos - eggPos).Magnitude
        if d <= 18 then cands[#cands + 1] = { pp = p.pp, pos = p.pos, d = d } end
    end
    table.sort(cands, function(a, b) return a.d < b.d end)
    local a, b = cands[1], cands[2]
    if a and (a.pos - me.Position).Magnitude <= 16 then
        return a.pp, a.d, b and (b.d - a.d) or math.huge
    end
    local detail = a and string.format("pd=%.2f gap=%s player=%.1f", a.d, b and string.format("%.2f", b.d - a.d) or "-", (a.pos - me.Position).Magnitude)
        or "ไม่มี Prompt ใน 18"
    return nil, nil, nil, detail
end

-- alias เดิมให้โค้ดเก่าเรียกได้
local function promptAtTarget(target, matchRadius, requireNearby)
    local pp, d = choosePrompt(target)
    if not pp then return nil end
    if requireNearby then
        local _, root = humRoot()
        if not root then return nil end
        local part = pp.Parent and (pp.Parent:IsA("BasePart") and pp.Parent or pp.Parent:FindFirstChildWhichIsA("BasePart", true))
        if part and (part.Position - root.Position).Magnitude > STEAL_R then return nil end
    end
    if matchRadius and d and d > matchRadius then return nil end
    return pp, d
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
    local carry = findCarryEvent()
    if not carry then return false end
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
                    if not S.dropBrakeUsed then
                        S.dropBrakeUsed = true
                        stopMove()
                        say("server: ไข่หลุดมือ — เบรกแล้วรอพิกัด")
                    else
                        say("server: ไข่หลุดมือ")
                    end
                else
                    say("server: ไข่หลุดมือ — กำลังกู้")
                end
            end
        end
    end)
    S.conns[#S.conns + 1] = S.carryConn
    lines[#lines + 1] = "ฟัง FieldEggCarry ✅ (" .. tostring(carry.Name) .. ")"
    say("ฟัง FieldEggCarry ✅ " .. tostring(carry.Name))
    return true
end

-- FieldEggCarry บอกสถานะของเรา; FieldEggShifted ระบุตำแหน่งของไข่ใบเดิมเมื่อมันตก
local function attachShiftListener()
    if S.shiftConn then return true end
    local shifted = findNet("FieldEggShifted")
    if not shifted or not (shifted:IsA("RemoteEvent") or shifted:IsA("UnreliableRemoteEvent")) then return false end
    S.shiftConn = shifted.OnClientEvent:Connect(function(row)
        -- เก็บลง eggDB ก่อน (ใช้ร่วมกับ Return Guard)
        upsertEgg(row)
        if typeof(row) ~= "table" or not S.returning or S.carriedUid == nil then return end
        -- เพิ่งกู้/steal สำเร็จ — อย่าให้ Dropped เก่ามาค้างวิ่ง
        if os.clock() < (S.stealGraceUntil or 0) then return end
        if S.carrying or lookingLikeCarry() then return end
        local state = tostring(row.State or "")
        if state ~= "Dropped" or tostring(row.Uid) ~= tostring(S.carriedUid) then return end
        local pos = posOf(row)
        if pos then
            S.droppedPos = pos
            S.carrying = false
            S.returnPaused = true
            if not S.dropBrakeUsed then
                S.dropBrakeUsed = true
                stopMove()
            end
            say(string.format("UID %s หลุดมือ @%.0f,%.0f — กลับไปเก็บ", tostring(S.carriedUid), pos.X, pos.Z))
        end
    end)
    S.conns[#S.conns + 1] = S.shiftConn
    lines[#lines + 1] = "ฟัง FieldEggShifted (Return Guard) ✅"
    return true
end

-- กู้ไข่หลุด v3.10: ตรวจ eggDB ก่อน — ไข่ยัง Dropped อยู่จุดเดิม + เว้นเพื่อนที่จุด → ค่อย RF/Prompt
local function recoverDroppedEgg(dropPos)
    stopMove()
    attachCarryListener()
    attachEggFeed()
    local uid = S.carriedUid or S.expectedUid
    if not dropPos and not uid then return false, "ไม่มีพิกัด/UID" end
    local still, why = eggStillDropped(uid, dropPos)
    if not still then
        say("กู้ไม่ก็ไข่หายแล้ว (" .. tostring(why) .. ") — ไม่ไล่")
        return false, tostring(why)
    end
    -- เพื่อนอยู่ใกล้จุดไข่: รอให้ห่าง (จำกัด 2 รอบ รอรวม ~4 วิ)
    local checkPos = dropPos or (uid and S.eggDB[tostring(uid)] and S.eggDB[tostring(uid)].pos)
    for attempt = 1, 2 do
        if not checkPos then break end
        local pl, pd = nearestPlayerTo(checkPos, true)
        if not pl or not pd or pd > 10 then break end
        say(string.format("เพื่อน %s อยู่ใกล้จุดไข่ %.0f — รอ (%d/2)", pl.Name, pd, attempt))
        local t0 = os.clock()
        while S.run and os.clock() - t0 < 2 do
            local p2, d2 = nearestPlayerTo(checkPos, true)
            if not p2 or not d2 or d2 > 10 then break end
            task.wait(0.1)
        end
        if not S.run then return false, "STOP" end
        still, why = eggStillDropped(uid, dropPos)
        if not still then say("ไข่หายระหว่างรอ (" .. tostring(why) .. ")"); return false, tostring(why) end
    end
    -- ใช้พิกัดสดจาก DB ถ้ามี (แม่นกว่าจุดหลุดเดิม)
    local e = uid and S.eggDB[tostring(uid)]
    local goal = (e and e.pos) or dropPos
    if goal then
        local np = nearestStealPos(goal)
        if np then goal = np end
        if not walkSlow(goal, 5, 28, 55) then
            say('วิ่งไปจุดหลุดไม่ถึง')
            return false, "เดินไม่ถึง"
        end
        stopMove()
        -- ถึงแล้วเช็คอีกรอบ: อาจถูกเก็บระหว่างเดิน
        still, why = eggStillDropped(uid, goal)
        if not still then
            say("ถึงจุดแล้วแต่ไข่หาย (" .. tostring(why) .. ") — เลิก")
            return false, tostring(why)
        end
    end
    S.expectedUid = uid
    S.carryVerified = false
    S.carryMismatchUid = nil
    if uid then
        say('กู้: ลอง RF AskFieldEggCarry')
        tryAskCarry(uid)
        local t0 = os.clock()
        while S.run and os.clock() - t0 < 1.2 do
            if S.carryVerified and S.carrying then
                markHolding('rf-กู้')
                return true, "carry-uid"
            end
            if S.carryMismatchUid then tryDropHeld(); S.expectedUid = uid; break end
            task.wait(0.05)
        end
    end
    local fakeT = { pos = goal or dropPos, eggPos = goal or dropPos, uid = uid }
    local pick, md, gap, detail = choosePrompt(fakeT)
    if not pick and (dropPos or goal) then
        local base = dropPos or goal
        for _, off in ipairs({ Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3) }) do
            if walkSlow(base + off, 2, 2.5, 10) then
                pick, md, gap, detail = choosePrompt(fakeT)
                if pick then break end
            end
        end
    end
    if not pick then
        say('กู้ไม่เจอ Prompt (' .. tostring(detail) .. ')')
        return false, "ไม่มี Prompt"
    end
    local part = pick.Parent and (pick.Parent:IsA('BasePart') and pick.Parent or pick.Parent:FindFirstChildWhichIsA('BasePart', true))
    if part then walkSlow(part.Position, 3.2, 6, 14); stopMove() end
    pick = select(1, choosePrompt(fakeT)) or pick
    say(string.format('กู้ fp Steal pd=%.2f', md or -1))
    fireSteal(pick)
    if uid then tryAskCarry(uid) end
    local ok, why = waitCarryConfirm(2.0, fakeT)
    if ok then markHolding(why); return true end
    if S.carryMismatchUid then tryDropHeld(); say('กู้ได้คนละฟอง — ทิ้ง') end
    return false, "steal ไม่ติด"
end

-- กลับ HOME: ถือถึงวิ่ง | หล่น=ตรวจ eggDB ก่อน ไข่ยังอยู่=กู้ทันที | หาย/กู้ไม่ติด=สแกนเป้าใหม่ ไม่เดินเปล่า
local function returnHome()
    local deadline, lastReport = os.clock() + 180, 0
    S.impactHopUsed, S.lastReturnDist = false, nil
    resolveRift(true)
    attachEggFeed()
    local phase = 'rift'
    local recoveredOnce = false
    while S.run and os.clock() < deadline do
        local h, r = humRoot()
        if not h or not r or not S.home then return false end
        if S.carryMismatchUid then
            say('ระหว่างทาง UID ผิด — ทิ้ง')
            tryDropHeld()
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
        if not S.carrying then
            local dropPos = S.droppedPos
            if dropPos and not recoveredOnce then
                recoveredOnce = true
                say('ไข่หลุด — ตรวจว่ายังอยู่จุดหลุด')
                local ok, why = recoverDroppedEgg(dropPos)
                if ok and S.carrying and (not S.carryAvailable or S.carryVerified) then
                    S.returnPaused = false
                    say('กู้ได้แล้ว — วิ่งกลับต่อ')
                else
                    say('กู้ไม่ได้ (' .. tostring(why) .. ') — ไม่ไล่ กลับ/สแกนใหม่')
                    return false
                end
            else
                say('ไข่หล่นระหว่างทาง — ไม่ไล่เก็บ (แบบ RiftFarm)')
                return false
            end
        end
        h, r = humRoot()
        if not h or not r then return false end
        local dHome = dist2(r.Position, S.home)
        if dHome <= HOME_R then stopMove(); return true end
        local deep = select(1, riftDeepTarget(S.home))
        if phase == 'rift' and deep then
            local dR = dist2(r.Position, deep)
            if dR <= RIFT_R then
                phase = 'home'
                say('ถึง Rift ลึกแล้ว → วิ่งกลับ HOME')
            else
                S.lastReturnDist = dR
                h:MoveTo(Vector3.new(deep.X, r.Position.Y, deep.Z))
                if os.clock() - lastReport >= 1 then
                    say(string.format('วิ่งกลับผ่าน Rift ลึก%+d d=%.0f', RIFT_DEPTH, dR))
                    lastReport = os.clock()
                end
                task.wait(0.15)
            end
        else
            impactHopToward(h, r, S.home, HOME_R, dHome)
            S.lastReturnDist = dHome
            h:MoveTo(Vector3.new(S.home.X, r.Position.Y, S.home.Z))
            if os.clock() - lastReport >= 1 then
                say(string.format('วิ่งกลับ HOME d=%.0f', dHome))
                lastReport = os.clock()
            end
            task.wait(0.15)
        end
    end
    return false
end

-- ยิงไข่แบบ RiftFarm one() / Egg01_MOTION_BRAKE.md
local function stealEggLikeRift(t)
    attachCarryListener()
    attachEggFeed()
    local eggPos = t.pos
    local walkPos = nearestStealPos(eggPos) or eggPos
    say(string.format('เข้าไข่ UID (rad=5 slow=55) @%.0f,%.0f', walkPos.X, walkPos.Z))
    if not walkSlow(walkPos, 5, 22, 55) then
        say('เข้าพิกัดไข่ไม่สำเร็จ')
        return false
    end
    stopMove()
    S.expectedUid, S.carryVerified, S.carryMismatchUid = t.uid, false, nil
    S.carrying = false
    say('ลอง RF AskFieldEggCarry Uid=' .. tostring(t.uid))
    tryAskCarry(t.uid)
    do
        local untilRf = os.clock() + 1.2
        while S.run and os.clock() < untilRf and not S.carryVerified and not S.carryMismatchUid do
            task.wait(0.05)
        end
    end
    if S.carryMismatchUid then
        say('RF ได้คนละฟอง — ทิ้ง')
        tryDropHeld()
        S.expectedUid = t.uid
    end
    if not S.carryVerified then
        local pick, md, gap, detail = choosePrompt(t)
        if not pick then
            for _, off in ipairs({ Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3) }) do
                if walkSlow(eggPos + off, 2, 2.5, 10) then
                    pick, md, gap, detail = choosePrompt(t)
                    if pick then break end
                end
            end
        end
        if pick then
            local part = pick.Parent and (pick.Parent:IsA('BasePart') and pick.Parent or pick.Parent:FindFirstChildWhichIsA('BasePart', true))
            if part then walkSlow(part.Position, 3.2, 6, 14); stopMove() end
            pick, md, gap, detail = choosePrompt(t)
            if pick then
                say(string.format('fp Steal ใกล้ไข่ pd=%.2f gap=%.2f', md or -1, gap or -1))
                fireSteal(pick)
                tryAskCarry(t.uid)
                local untilT = os.clock() + 2
                while S.run and os.clock() < untilT and not S.carryVerified and not S.carryMismatchUid do
                    task.wait(0.05)
                end
            else
                say('ไม่เจอ Prompt หลังเข้าใกล้ (' .. tostring(detail) .. ')')
            end
        else
            say('RF ไม่ติด + ไม่เจอ Prompt (' .. tostring(detail) .. ')')
        end
    end
    if S.carryMismatchUid then
        say('UID ผิดหลัง Steal — ทิ้ง ไม่วิ่งกลับผิดฟอง')
        tryDropHeld()
        return false
    end
    if not S.carryVerified then
        if S.carryAvailable or not S.carrying then
            say('ยังไม่ถือ UID เป้า — ไม่วิ่งกลับ')
            return false
        end
    end
    say('ถือไข่ UID เป้าแล้ว — วิ่งกลับ HOME')
    return true
end

local function farmTarget(target)
    S.carrying, S.eggArea, S.hopUsed = false, target.area, false
    target.eggPos = target.pos
    say('ไปหา ' .. target.cat .. ' | HOME→Rift→ไข่')
    local reachedTarget = goViaRift(target.pos, APPROACH_R, 120, target.cat)
    if not reachedTarget then
        say('ไปถึงไข่ไม่สำเร็จ')
        S.eggDB[tostring(target.uid or "")] = nil -- ล้างเป้าเน่า ไม่ไล่ซ้ำ
        return
    end
    stopMove()
    if not S.run then return end
    if not stealEggLikeRift(target) then
        say('ขโมยไม่สำเร็จ — เป้านี้ค้าง/หาย ล้างแล้วรีสแกน')
        S.expectedUid = nil
        S.eggDB[tostring(target.uid or "")] = nil
        skipTarget(target, 45, "steal ไม่ติด")
        return
    end
    S.carriedUid, S.droppedPos, S.carryLostAt, S.returning, S.returnPaused, S.dropBrakeUsed = target.uid, nil, 0, true, false, false
    S.stealGraceUntil = os.clock() + 2.5
    S.carrying = true
    if returnHome() then
        say('ถึง HOME — รอรอบถัดไป')
    elseif S.run then
        say('กลับบ้านไม่สำเร็จ — scan ใหม่')
    end
    S.returning, S.carriedUid, S.expectedUid, S.droppedPos, S.returnPaused, S.dropBrakeUsed = false, nil, nil, nil, false, false
    S.carryMismatchUid, S.carryVerified = nil, false
end

local function runOne()
    if S.run then return end
    if not fp then say("executor ไม่มี fireproximityprompt") return end
    if not S.home then
        say("ยังไม่ได้ตั้ง HOME — ยืนที่ฐานแล้วกด HOME ก่อน START")
        return
    end
    S.run = true
    bStart.Text = "AUTO"
    say("AUTO ON — HOME→Rift→ไข่→Rift→HOME | ไม่มีเป้า=ลู่วิ่งรอ")
    resolveRift()
    task.spawn(function()
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
            bRarity.Text = rarityText() == "ALL" and "ALL ▼" or rarityText() .. " ▼"
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
    lines[#lines + 1] = "รอ FieldEggCarry (กัน AskFieldEggCarry ปน)…"
    task.spawn(function()
        for _ = 1, 20 do
            if attachCarryListener() then return end
            task.wait(1)
        end
        lines[#lines + 1] = "ไม่พบ FieldEggCarry RE — ใช้ prompt-หาย/visual แทน"
        say("ไม่พบ FieldEggCarry RE — ใช้ prompt/visual ยืนยันถือ")
    end)
end
if not attachShiftListener() then
    lines[#lines + 1] = "ไม่พบ FieldEggShifted — Return Guard รอระหว่างวิ่งกลับ"
end
if not attachEggFeed() then
    lines[#lines + 1] = "รอ eggDB feed (Shifted/Batch/Gone)…"
    task.spawn(function()
        for _ = 1, 20 do
            if attachEggFeed() then
                lines[#lines + 1] = "eggDB feed พร้อม"
                return
            end
            task.wait(1)
        end
        lines[#lines + 1] = "ไม่พบ egg feed — Drop Guard ใช้ Snapshot เท่านั้น"
    end)
end

bHome.MouseButton1Click:Connect(function()
    local _, r = humRoot()
    if r then S.home = r.Position; say("HOME ตั้งแล้ว (ตำแหน่งฐาน)") else say("ไม่มีตัวละคร") end
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
    if clip then pcall(clip, "=== Egg01 Target Farm v3.11 ===\n" .. table.concat(lines, "\n")) end
    bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)
bClose.MouseButton1Click:Connect(function()
    S.run = false
    setClip(false)
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(S.eggConns) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.EGG01_TARGET_FARM = nil
end)

LP.CharacterAdded:Connect(function(ch)
    if not S.gui or not S.gui.Parent then return end
    task.wait(0.5)
    pcall(function() ch:WaitForChild("HumanoidRootPart", 8) end)
    setClip(true)
end)

setClip(true)
say("v3.11 | rarity หลัก: Div ก่อนเสมอ ระยะเป็นรอง | กู้ไข่แม่น")
