-- Egg01 Egg Status Spy v2.0
-- คอก: สแกน + ESP บนหัว ($ / mut)

if _G.EGG01_EGG_STATUS_SPY then
    pcall(function()
        for _, bb in pairs(_G.EGG01_EGG_STATUS_SPY.esp or {}) do
            pcall(function() bb:Destroy() end)
        end
    end)
    pcall(function() _G.EGG01_EGG_STATUS_SPY.gui:Destroy() end)
    for _, c in ipairs(_G.EGG01_EGG_STATUS_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
    _G.EGG01_EGG_STATUS_SPY.espToken = (_G.EGG01_EGG_STATUS_SPY.espToken or 0) + 1
end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local S = { gui = nil, lines = {}, conns = {}, esp = {}, espOn = true, espToken = 0 }
_G.EGG01_EGG_STATUS_SPY = S

local ME = tostring(LP.UserId)
local box
local ESP_TAG = "Egg01_PenESP"
local ESP_MAX_D = 120
local ESP_REFRESH = 1.25

local TIERS = {
    "Rainbow", "Divine", "Diamond", "Golden", "Gold", "Silver", "Bronze",
    "Shiny", "Galaxy", "Neon", "Dark", "Crystal", "Normal",
}
local TIER_TH = {
    Rainbow = "รุ้ง", Divine = "ดีไวน์", Diamond = "เพชร", Golden = "ทอง", Gold = "ทอง",
    Silver = "เงิน", Bronze = "ทองแดง", Shiny = "ไชน์", Galaxy = "กาแล็กซี",
    Neon = "นีออน", Dark = "ดาร์ก", Crystal = "คริสตัล", Normal = "ปกติ",
}
local TIER_COLOR = {
    Rainbow = Color3.fromRGB(255, 120, 220),
    Divine = Color3.fromRGB(255, 230, 120),
    Diamond = Color3.fromRGB(140, 220, 255),
    Golden = Color3.fromRGB(255, 200, 60),
    Gold = Color3.fromRGB(255, 200, 60),
    Silver = Color3.fromRGB(200, 210, 230),
    Bronze = Color3.fromRGB(200, 140, 80),
    Normal = Color3.fromRGB(210, 235, 210),
}

local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 180 then table.remove(S.lines, 1) end
    if box then box.Text = table.concat(S.lines, "\n") end
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function instPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local ok, piv = pcall(function() return inst:GetPivot() end)
    if ok and piv then return piv.Position end
    local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local function adorneePart(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function collectTexts(root)
    local texts, seen = {}, {}
    if not root then return texts end
    for _, d in ipairs(root:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" then
            local t = d.Text:gsub("%s+", " "):match("^%s*(.-)%s*$")
            if t and #t > 0 and not seen[t] then
                seen[t] = true
                texts[#texts + 1] = t
            end
        end
    end
    return texts
end

local function parseTier(blob)
    local low = blob:lower()
    for _, t in ipairs(TIERS) do
        if low:find(t:lower(), 1, true) then
            return t, TIER_TH[t] or t
        end
    end
    return "Normal", "ปกติ"
end

local function parseMut(blob)
    local low = blob:lower()
    local mut
    if low:find("scrambled", 1, true) then mut = "Scrambled"
    elseif low:find("disabled", 1, true) then mut = "Disabled"
    elseif low:find("mutation", 1, true) then mut = "Mutation"
    end
    local chance = blob:match("(%d+)%s*%%%s*[Ss]uccess")
    return mut, chance
end

local function parseRarity(blob)
    local s = tostring(blob or "")
    for _, r in ipairs({ "Eternal", "Divine", "Cosmic", "Secret", "Mythic", "Legendary", "Epic", "Rare" }) do
        if s:find(r, 1, true) then return r end
    end
end

local function parseIncome(blob)
    return tostring(blob or ""):match("%$[%d%.]+[KMBT]?/s")
end

local function parseName(blob, tier)
    local s = blob
    for _, t in ipairs(TIERS) do
        s = s:gsub("^%s*" .. t .. "%s*%+?%s*", "")
        s = s:gsub("%s*" .. t .. "%s*%+?%s*", " ")
    end
    s = s:gsub("%s*%+?%s*Scrambled%s+Mutation%s*", " ")
    s = s:gsub("%s*Scrambled%s+Mutation%s*", " ")
    s = s:gsub("%s*Mutation%s*", " ")
    s = s:gsub("%s*Disabled%s*", " ")
    s = s:gsub("%s*%$[%d%.]+[KMBT]?/s.*$", "")
    s = s:gsub("%s*%|%s*.*$", "")
    s = s:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if s == "" or s:lower() == (tier or ""):lower() then return "?" end
    return s
end

local function isPetBlob(blob)
    return tostring(blob):find("%$[%d%.]+[KMBT]?/s") ~= nil
        or tostring(blob):find("%d%.[%d]+[KMBT]/s") ~= nil
end

local function mineAssets()
    local folder = workspace:FindFirstChild("ClientRenderedAssets")
    local out = {}
    if not folder then return out end
    local prefix = ME .. "_"
    local root = hr()
    for _, m in ipairs(folder:GetChildren()) do
        if m.Name:sub(1, #prefix) == prefix then
            local texts = collectTexts(m)
            local blob = table.concat(texts, " | ")
            local tier, tierTh = parseTier(blob)
            local mut, chance = parseMut(blob)
            local name = parseName(blob, tier)
            local p = instPos(m)
            local d = (root and p) and (p - root.Position).Magnitude or 99999
            out[#out + 1] = {
                name = name, tier = tier, tierTh = tierTh,
                mut = mut, chance = chance, blob = blob,
                d = d, p = p, pet = isPetBlob(blob),
            }
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local function nearbyMutPrompts(maxD)
    local root = hr()
    local rows = {}
    if not root then return rows end
    maxD = maxD or 55
    local ok, desc = pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return rows end
    for _, x in ipairs(desc) do
        if x:IsA("ProximityPrompt") then
            local act = tostring(x.ActionText or "")
            local al = act:lower()
            if al:find("mutation", 1, true) or al:find("apply", 1, true) then
                local part = x.Parent and (x.Parent:IsA("BasePart") and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart", true))
                local p = part and part.Position
                local d = p and (p - root.Position).Magnitude or 99999
                if d <= maxD then
                    rows[#rows + 1] = {
                        d = d, en = x.Enabled,
                        act = act, obj = tostring(x.ObjectText or ""),
                        p = p,
                    }
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    return rows
end

local function mineAssetsNear(maxD)
    local folder = workspace:FindFirstChild("ClientRenderedAssets")
    local out = {}
    if not folder then return out end
    local prefix = ME .. "_"
    local root = hr()
    if not root then return out end
    for _, m in ipairs(folder:GetChildren()) do
        if m.Name:sub(1, #prefix) == prefix then
            local p = instPos(m)
            local d = p and (p - root.Position).Magnitude or 99999
            if d <= (maxD or 60) then
                local texts = collectTexts(m)
                local blob = table.concat(texts, " | ")
                local tier, tierTh = parseTier(blob)
                local mut, chance = parseMut(blob)
                local name = parseName(blob, tier)
                local income = parseIncome(blob)
                local rarity = parseRarity(blob)
                out[#out + 1] = {
                    name = name, tier = tier, tierTh = tierTh,
                    mut = mut, chance = chance, blob = blob,
                    income = income, rarity = rarity,
                    d = d, p = p, model = m,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local function enrichWithPrompts(assets, prompts)
    local byModel = {}
    for _, a in ipairs(assets) do
        byModel[a.model] = {
            d = a.d, en = nil, obj = "-",
            asset = a, mut = a.mut, chance = a.chance,
        }
    end
    for _, pr in ipairs(prompts) do
        local best, bestD
        for _, a in ipairs(assets) do
            if a.p and pr.p then
                local d = (a.p - pr.p).Magnitude
                if d <= 25 and (not bestD or d < bestD) then
                    best, bestD = a, d
                end
            end
        end
        local mutP, chanceP = parseMut(pr.obj or "")
        if best and byModel[best.model] then
            local cur = byModel[best.model]
            if not cur.en or pr.en == true then cur.en = pr.en end
            if pr.obj and pr.obj ~= "" then cur.obj = pr.obj end
            if mutP then cur.mut = mutP end
            if chanceP then cur.chance = chanceP end
        end
    end
    local rows = {}
    for _, r in pairs(byModel) do rows[#rows + 1] = r end
    table.sort(rows, function(a, b) return a.d < b.d end)
    return rows
end

local function scanIncubators()
    return enrichWithPrompts(mineAssetsNear(100), nearbyMutPrompts(80))
end

local function clearEsp()
    for _, bb in pairs(S.esp) do
        pcall(function() bb:Destroy() end)
    end
    S.esp = {}
    -- ล้างค้างจากรอบก่อน
    for _, d in ipairs(workspace:GetDescendants()) do
        if d.Name == ESP_TAG then pcall(function() d:Destroy() end) end
    end
end

local function espColor(tier, mut)
    if mut == "Scrambled" then return Color3.fromRGB(120, 255, 200) end
    if mut == "Disabled" then return Color3.fromRGB(180, 100, 100) end
    return TIER_COLOR[tier] or Color3.fromRGB(210, 235, 210)
end

local function makeEspLabel(part)
    local bb = Instance.new("BillboardGui")
    bb.Name = ESP_TAG
    bb.Size = UDim2.new(0, 160, 0, 48)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 220
    bb.LightInfluence = 0
    bb.Adornee = part
    bb.Parent = part

    local tl = Instance.new("TextLabel", bb)
    tl.Name = "L"
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundColor3 = Color3.new(0, 0, 0)
    tl.BackgroundTransparency = 0.35
    tl.TextColor3 = Color3.fromRGB(220, 255, 220)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 12
    tl.TextWrapped = true
    tl.TextStrokeTransparency = 0.4
    Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 4)
    return bb, tl
end

local function refreshEsp()
    if not S.espOn then return end
    local assets = mineAssetsNear(ESP_MAX_D)
    local rows = enrichWithPrompts(assets, nearbyMutPrompts(ESP_MAX_D))
    local alive = {}

    for _, r in ipairs(rows) do
        local a = r.asset
        if a and a.model then
            local part = adorneePart(a.model)
            if part then
                alive[a.model] = true
                local bb = S.esp[a.model]
                local tl
                if not bb or not bb.Parent then
                    bb, tl = makeEspLabel(part)
                    S.esp[a.model] = bb
                else
                    if bb.Adornee ~= part then bb.Adornee = part; bb.Parent = part end
                    tl = bb:FindFirstChild("L")
                end
                if tl then
                    local mutLine = "-"
                    if r.mut then
                        mutLine = r.mut
                        if r.chance then mutLine = mutLine .. " " .. r.chance .. "%" end
                        if r.en == true then mutLine = mutLine .. " READY"
                        elseif r.en == false then mutLine = mutLine .. " OFF" end
                    end
                    tl.Text = string.format("%s\n%s  %s\n%s",
                        a.name or "?",
                        tostring(a.income or "-"),
                        tostring(a.rarity or ""),
                        mutLine
                    )
                    tl.TextColor3 = espColor(a.tier, r.mut)
                end
            end
        end
    end

    for model, bb in pairs(S.esp) do
        if not alive[model] then
            pcall(function() bb:Destroy() end)
            S.esp[model] = nil
        end
    end
end

local function startEspLoop()
    S.espToken = (S.espToken or 0) + 1
    local token = S.espToken
    task.spawn(function()
        while S.espOn and S.espToken == token and S.gui and S.gui.Parent do
            pcall(refreshEsp)
            task.wait(ESP_REFRESH)
        end
    end)
end

local function setEsp(on)
    S.espOn = on and true or false
    if not S.espOn then
        clearEsp()
    else
        startEspLoop()
    end
end

local function scanEggs()
    S.lines = {}
    say("=== Egg Status Spy v2.0 — คอก + ESP ===")
    say("UserId=" .. ME)

    say("สแกนคอก (≤100 studs)...")
    local okInc, incs = pcall(scanIncubators)
    if not okInc then
        say("คอก error: " .. tostring(incs))
        incs = {}
    end
    say(string.format("--- ของเราในคอก: %d ---", #incs))
    if #incs == 0 then
        say("(ไม่เจอ ClientRenderedAssets ของเราใน 100 studs)")
    end
    for i, r in ipairs(incs) do
        local a = r.asset
        local status = r.en == true and "READY" or (r.en == false and "DISABLED" or (r.obj == "-" and "-" or "?"))
        if a then
            say(string.format(
                "#%d [%s] %s | rar=%s | %s | mut=%s %%=%s | mutPrompt=%s | d=%.0f",
                i, a.tierTh, a.name,
                tostring(a.rarity or "-"), tostring(a.income or "-"),
                tostring(r.mut or "-"), tostring(r.chance or "-"),
                status, r.d
            ))
            if a.blob ~= "" then say("    " .. a.blob) end
        else
            say(string.format("#%d (prompt เปล่า) %s | %q | d=%.0f", i, status, tostring(r.obj), r.d))
        end
    end
    say("ESP=" .. (S.espOn and "ON" or "OFF") .. " | บนหัว = ชื่อ / $ / mut")
    say("=== DONE ===")
end

local function scanPets()
    S.lines = {}
    say("=== สัตว์ในคอกของเรา (มี $/s) ===")
    local pets = mineAssets()
    local n = 0
    local byTier = {}
    for _, a in ipairs(pets) do
        if a.pet then
            n = n + 1
            byTier[a.tier] = (byTier[a.tier] or 0) + 1
            say(string.format("#%d [%s] %s | d=%.0f", n, a.tierTh, a.name, a.d))
            say("    " .. a.blob)
        end
    end
    local parts = {}
    for _, t in ipairs(TIERS) do
        if byTier[t] then parts[#parts + 1] = (TIER_TH[t] or t) .. "=" .. byTier[t] end
    end
    say("รวมสัตว์=" .. n .. (#parts > 0 and (" | " .. table.concat(parts, " | ")) or ""))
    say("=== DONE ===")
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_EggStatusSpy"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1030
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui

local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 640, 0, 360)
f.Position = UDim2.new(0, 12, 0.18, 0)
f.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 Egg Status Spy v2.0 — ESP คอก"
title.TextColor3 = Color3.fromRGB(160, 230, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local function btn(tx, x, col)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, 72, 0, 28)
    b.Position = UDim2.new(0, x, 0, 36)
    b.Text = tx
    b.BackgroundColor3 = col
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bEggs = btn("EGGS", 10, Color3.fromRGB(45, 110, 170))
local bPets = btn("PETS", 88, Color3.fromRGB(90, 70, 140))
local bEsp = btn("ESP ON", 166, Color3.fromRGB(40, 130, 90))
local bClear = btn("CLEAR", 244, Color3.fromRGB(70, 70, 75))
local bCopy = btn("COPY", 322, Color3.fromRGB(70, 70, 75))
local bClose = btn("X", 556, Color3.fromRGB(145, 50, 65))

box = Instance.new("TextBox", f)
box.Size = UDim2.new(1, -16, 0, 280)
box.Position = UDim2.new(0, 8, 0, 72)
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(190, 245, 200)
box.Font = Enum.Font.Code
box.TextSize = 11
box.TextEditable = false
box.MultiLine = true
box.ClearTextOnFocus = false
box.TextWrapped = false
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.Text = "EGGS = สแกนคอก\nESP = ป้ายบนหัว ชื่อ / $ / mut"

local function syncEspBtn()
    bEsp.Text = S.espOn and "ESP ON" or "ESP OFF"
    bEsp.BackgroundColor3 = S.espOn and Color3.fromRGB(40, 130, 90) or Color3.fromRGB(90, 70, 70)
end

bEggs.MouseButton1Click:Connect(scanEggs)
bPets.MouseButton1Click:Connect(scanPets)
bEsp.MouseButton1Click:Connect(function()
    setEsp(not S.espOn)
    syncEspBtn()
end)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Status Spy v2.0 ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bClose.MouseButton1Click:Connect(function()
    S.espOn = false
    S.espToken = (S.espToken or 0) + 1
    clearEsp()
    gui:Destroy()
    _G.EGG01_EGG_STATUS_SPY = nil
end)

say("v2.0 พร้อม — ESP เปิดอัตโนมัติบนหัวคอก")
setEsp(true)
syncEspBtn()
