-- Egg01 Egg Status Spy v3.1
-- ไข่ในคอก = มี Apply Mutation Prompt เท่านั้น (READY / DISABLED)
-- ไม่เกาะสัตว์ฟักแล้วที่ไม่มี prompt

if _G.EGG01_EGG_STATUS_SPY then
    pcall(function()
        for _, bb in pairs(_G.EGG01_EGG_STATUS_SPY.esp or {}) do pcall(function() bb:Destroy() end) end
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
local ESP_TAG = "Egg01_IncubatorESP"
local SCAN_D = 100
local ESP_REFRESH = 1.2

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
    Normal = Color3.fromRGB(210, 235, 210),
}

local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 160 then table.remove(S.lines, 1) end
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
        if low:find(t:lower(), 1, true) then return t, TIER_TH[t] or t end
    end
    return "Normal", "ปกติ"
end

local function parseMut(blob)
    local low = tostring(blob or ""):lower()
    local mut
    if low:find("scrambled", 1, true) then mut = "Scrambled"
    elseif low:find("disabled", 1, true) then mut = "Disabled"
    elseif low:find("mutation", 1, true) then mut = "Mutation"
    end
    local chance = tostring(blob or ""):match("(%d+)%s*%%%s*[Ss]uccess")
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

-- Prompt Apply Mutation ใกล้ตัว = ไข่จริง
local function mutationPrompts(maxD)
    local root = hr()
    local rows = {}
    if not root then return rows end
    local ok, desc = pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return rows end
    for _, x in ipairs(desc) do
        if x:IsA("ProximityPrompt") then
            local act = tostring(x.ActionText or ""):lower()
            local obj = tostring(x.ObjectText or ""):lower()
            if act:find("mutation", 1, true) or act:find("apply", 1, true)
                or obj:find("scrambl", 1, true) or obj:find("mutation", 1, true) then
                local part = x.Parent and (x.Parent:IsA("BasePart") and x.Parent
                    or x.Parent:FindFirstChildWhichIsA("BasePart", true))
                local p = part and part.Position
                local d = p and (p - root.Position).Magnitude or 99999
                if d <= (maxD or SCAN_D) then
                    rows[#rows + 1] = {
                        prompt = x, part = part, p = p, d = d,
                        en = x.Enabled,
                        status = x.Enabled and "READY" or "DISABLED",
                        act = tostring(x.ActionText or ""),
                        obj = tostring(x.ObjectText or ""),
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
            if d <= (maxD or SCAN_D) then
                local texts = collectTexts(m)
                local blob = table.concat(texts, " | ")
                local tier, tierTh = parseTier(blob)
                out[#out + 1] = {
                    model = m, p = p, d = d, blob = blob,
                    name = parseName(blob, tier),
                    tier = tier, tierTh = tierTh,
                    mut = select(1, parseMut(blob)),
                    chance = select(2, parseMut(blob)),
                    income = parseIncome(blob),
                    rarity = parseRarity(blob),
                }
            end
        end
    end
    return out
end

-- จับคู่ prompt ↔ asset ของเรา — คืนเฉพาะที่มี prompt (ไข่)
local function scanEggsOnly()
    local prompts = mutationPrompts(SCAN_D + 20)
    local assets = mineAssetsNear(SCAN_D + 20)
    local usedAsset, rows = {}, {}

    for _, pr in ipairs(prompts) do
        local best, bestD
        for _, a in ipairs(assets) do
            if a.p and pr.p and not usedAsset[a.model] then
                local d = (a.p - pr.p).Magnitude
                if d <= 25 and (not bestD or d < bestD) then
                    best, bestD = a, d
                end
            end
        end
        local mutP, chanceP = parseMut(pr.obj)
        if best then
            usedAsset[best.model] = true
            rows[#rows + 1] = {
                d = pr.d, status = pr.status, en = pr.en,
                obj = pr.obj, act = pr.act, prompt = pr.prompt,
                gap = bestD,
                mut = mutP or best.mut, chance = chanceP or best.chance,
                asset = best, model = best.model, p = best.p or pr.p,
            }
        else
            -- prompt ไม่มีชื่อคู่ ยังนับเป็นไข่
            rows[#rows + 1] = {
                d = pr.d, status = pr.status, en = pr.en,
                obj = pr.obj, act = pr.act, prompt = pr.prompt,
                gap = 0, mut = mutP, chance = chanceP,
                asset = nil, model = pr.part, p = pr.p,
            }
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    return rows
end

local function clearEsp()
    for _, bb in pairs(S.esp) do pcall(function() bb:Destroy() end) end
    S.esp = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d.Name == ESP_TAG then pcall(function() d:Destroy() end) end
    end
end

local function espColor(row)
    if row.status == "READY" then return Color3.fromRGB(80, 255, 140) end
    if row.status == "DISABLED" then return Color3.fromRGB(255, 120, 120) end
    local a = row.asset
    if a and a.mut == "Scrambled" then return Color3.fromRGB(120, 255, 200) end
    if a then return TIER_COLOR[a.tier] or Color3.fromRGB(210, 235, 210) end
    return Color3.fromRGB(200, 220, 255)
end

local function makeEsp(part)
    local bb = Instance.new("BillboardGui")
    bb.Name = ESP_TAG
    bb.Size = UDim2.new(0, 170, 0, 52)
    bb.StudsOffset = Vector3.new(0, 3.4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 180
    bb.LightInfluence = 0
    bb.Adornee = part
    bb.Parent = part

    local tl = Instance.new("TextLabel", bb)
    tl.Name = "L"
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundColor3 = Color3.new(0, 0, 0)
    tl.BackgroundTransparency = 0.32
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 12
    tl.TextWrapped = true
    tl.TextStrokeTransparency = 0.4
    Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 4)
    return bb, tl
end

local function refreshEsp()
    if not S.espOn then return end
    local rows = scanEggsOnly()
    local alive = {}

    for _, r in ipairs(rows) do
        local part = adorneePart(r.model) or (r.prompt and r.prompt.Parent
            and (r.prompt.Parent:IsA("BasePart") and r.prompt.Parent
                or r.prompt.Parent:FindFirstChildWhichIsA("BasePart", true)))
        if part then
            local key = r.model or part
            alive[key] = true
            local bb = S.esp[key]
            local tl
            if not bb or not bb.Parent then
                bb, tl = makeEsp(part)
                S.esp[key] = bb
            else
                if bb.Adornee ~= part then bb.Adornee = part; bb.Parent = part end
                tl = bb:FindFirstChild("L")
            end
            if tl then
                local a = r.asset
                local name = a and a.name or "?"
                local income = a and a.income or "-"
                local rar = a and a.rarity or ""
                local mutLine = tostring(r.mut or "-")
                if r.chance then mutLine = mutLine .. " " .. r.chance .. "%" end
                tl.Text = string.format("%s\n%s  %s\n%s · %s",
                    name, tostring(income), tostring(rar),
                    mutLine, r.status)
                tl.TextColor3 = espColor(r)
            end
        end
    end

    for key, bb in pairs(S.esp) do
        if not alive[key] then
            pcall(function() bb:Destroy() end)
            S.esp[key] = nil
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
    if not S.espOn then clearEsp() else startEspLoop() end
end

local function scanEggs()
    S.lines = {}
    say("=== Egg Status Spy v3.1 — ไข่ = Mutation Prompt ===")
    say("UserId=" .. ME)
    local ok, rows = pcall(scanEggsOnly)
    if not ok then
        say("error: " .. tostring(rows))
        say("=== DONE ===")
        return
    end
    local nR, nD = 0, 0
    for _, r in ipairs(rows) do
        if r.status == "READY" then nR = nR + 1 elseif r.status == "DISABLED" then nD = nD + 1 end
    end
    say(string.format("--- ไข่ (มี Prompt): %d | READY=%d DISABLED=%d ---", #rows, nR, nD))
    if #rows == 0 then say("(ไม่เจอ Apply Mutation ในระยะ)") end
    for i, r in ipairs(rows) do
        local a = r.asset
        if a then
            say(string.format(
                "#%d [%s] %s | rar=%s | %s | mut=%s %%=%s | prompt=%s | d=%.0f",
                i, a.tierTh, a.name,
                tostring(a.rarity or "-"), tostring(a.income or "-"),
                tostring(r.mut or "-"), tostring(r.chance or "-"),
                r.status, r.d
            ))
            if a.blob ~= "" then say("    " .. a.blob) end
            if r.obj ~= "" then say("    obj=" .. r.obj) end
        else
            say(string.format("#%d (ไม่มีชื่อ) prompt=%s | %q | d=%.0f", i, r.status, tostring(r.obj), r.d))
        end
    end
    say("ESP=" .. (S.espOn and "ON" or "OFF"))
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
f.Size = UDim2.new(0, 620, 0, 340)
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
title.Text = "Egg01 Egg Spy v3.1 — Prompt READY/DISABLED เท่านั้น"
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
local bEsp = btn("ESP ON", 88, Color3.fromRGB(40, 130, 90))
local bClear = btn("CLEAR", 166, Color3.fromRGB(70, 70, 75))
local bCopy = btn("COPY", 244, Color3.fromRGB(70, 70, 75))
local bClose = btn("X", 536, Color3.fromRGB(145, 50, 65))

box = Instance.new("TextBox", f)
box.Size = UDim2.new(1, -16, 0, 260)
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
box.Text = "ไข่ = มี Apply Mutation\nREADY=เขียว DISABLED=แดง"

local function syncEspBtn()
    bEsp.Text = S.espOn and "ESP ON" or "ESP OFF"
    bEsp.BackgroundColor3 = S.espOn and Color3.fromRGB(40, 130, 90) or Color3.fromRGB(90, 70, 70)
end

bEggs.MouseButton1Click:Connect(scanEggs)
bEsp.MouseButton1Click:Connect(function()
    setEsp(not S.espOn)
    syncEspBtn()
end)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Spy v3.1 ===\n" .. table.concat(S.lines, "\n"))
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

say("v3.1 — ไข่ = Mutation Prompt (READY/DISABLED) เท่านั้น")
setEsp(true)
syncEspBtn()
