-- Egg01 Egg Status Spy v3.3
-- Prompt Apply Mutation จับคู่ตำแหน่งไข่ (ไม่ใช่ระยะจากตัวเรา)
-- ไข่ = มี prompt READY/DISABLED ใกล้ asset + ESP

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
local ESP_TAG = "Egg01_MutEggESP"
local MATCH_D = 28
local ESP_REFRESH = 1.0

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
    Rainbow = Color3.fromRGB(255, 120, 220), Golden = Color3.fromRGB(255, 200, 60),
    Gold = Color3.fromRGB(255, 200, 60), Silver = Color3.fromRGB(200, 210, 230),
    Normal = Color3.fromRGB(210, 235, 210),
}

local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 180 then table.remove(S.lines, 1) end
    if box then box.Text = table.concat(S.lines, "\n") end
end

local function pathOf(x)
    local ok, s = pcall(function() return x:GetFullName() end)
    return ok and s:gsub("^Workspace%.", "WS.") or tostring(x)
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
        or tostring(blob or ""):match("(%d+)%s*%%")
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

-- แบบ v1.1: สแกน Apply Mutation ทั้ง workspace (SmartPromptPart)
local function nearbyMutPrompts()
    local root = hr()
    local rows = {}
    for _, x in ipairs(workspace:GetDescendants()) do
        if x:IsA("ProximityPrompt") then
            local act = tostring(x.ActionText or "")
            local al = act:lower()
            if al:find("mutation", 1, true) or al:find("apply", 1, true) then
                local part = x.Parent and (x.Parent:IsA("BasePart") and x.Parent
                    or x.Parent:FindFirstChildWhichIsA("BasePart", true))
                local p = part and part.Position
                local d = (root and p) and (p - root.Position).Magnitude or 99999
                rows[#rows + 1] = {
                    prompt = x, part = part, p = p, d = d,
                    en = x.Enabled, act = act, obj = tostring(x.ObjectText or ""),
                    path = pathOf(x),
                }
            end
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    return rows
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
            local p = instPos(m)
            local d = (root and p) and (p - root.Position).Magnitude or 99999
            out[#out + 1] = {
                name = parseName(blob, tier), tier = tier, tierTh = tierTh,
                mut = mut, chance = chance, blob = blob,
                income = parseIncome(blob), rarity = parseRarity(blob),
                d = d, p = p, model = m, path = pathOf(m),
            }
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

-- หา Prompt ในโมเดลไข่เอง (บางทีอยู่ใต้ ClientRenderedAssets)
local function promptInsideModel(model)
    if not model then return nil end
    for _, x in ipairs(model:GetDescendants()) do
        if x:IsA("ProximityPrompt") then
            local act = tostring(x.ActionText or ""):lower()
            if act:find("mutation", 1, true) or act:find("apply", 1, true) then
                local part = x.Parent and (x.Parent:IsA("BasePart") and x.Parent
                    or x.Parent:FindFirstChildWhichIsA("BasePart", true))
                return {
                    d = 0, en = x.Enabled, obj = tostring(x.ObjectText or ""),
                    act = tostring(x.ActionText or ""), prompt = x, part = part,
                    path = pathOf(x),
                }
            end
        end
    end
end

local function nearestPrompt(asset, prompts)
    if not asset.p then return nil, 99999 end
    local best, bestD
    for _, pr in ipairs(prompts) do
        if pr.p then
            local d = (pr.p - asset.p).Magnitude
            if not bestD or d < bestD then
                best, bestD = pr, d
            end
        end
    end
    return best, bestD or 99999
end

local function matchPrompt(asset, prompts)
    local inside = promptInsideModel(asset.model)
    if inside then return inside end
    local best, bestD = nearestPrompt(asset, prompts)
    if best and bestD <= MATCH_D then
        return {
            d = bestD, en = best.en, obj = best.obj, act = best.act,
            prompt = best.prompt, part = best.part, path = best.path,
        }
    end
    return nil
end

-- ไข่ = ของเราที่จับคู่ Prompt ได้ (READY/DISABLED)
local function scanEggRows()
    local assets = mineAssets()
    local prompts = nearbyMutPrompts()
    local usedPr, rows, gaps = {}, {}, {}

    for _, a in ipairs(assets) do
        local pr = matchPrompt(a, prompts)
        local _, nearGap = nearestPrompt(a, prompts)
        gaps[#gaps + 1] = { name = a.name, d = a.d, gap = pr and (pr.d or 0) or nearGap }
        if pr then
            usedPr[pr.prompt or pr] = true
            local mutP, chanceP = parseMut(pr.obj)
            rows[#rows + 1] = {
                asset = a, model = a.model, p = a.p, d = a.d,
                status = pr.en and "READY" or "DISABLED",
                en = pr.en, obj = pr.obj, act = pr.act,
                mut = mutP or a.mut, chance = chanceP or a.chance,
                prompt = pr.prompt, part = pr.part, gap = pr.d,
            }
        end
    end

    for _, pr in ipairs(prompts) do
        if pr.d <= 60 and not usedPr[pr.prompt] then
            local mutP, chanceP = parseMut(pr.obj)
            rows[#rows + 1] = {
                asset = nil, model = pr.part, p = pr.p, d = pr.d,
                status = pr.en and "READY" or "DISABLED",
                en = pr.en, obj = pr.obj, act = pr.act,
                mut = mutP, chance = chanceP,
                prompt = pr.prompt, part = pr.part, gap = 0,
                orphan = true,
            }
            usedPr[pr.prompt] = true
        end
    end

    table.sort(rows, function(a, b) return a.d < b.d end)
    table.sort(gaps, function(a, b) return a.gap < b.gap end)
    return rows, prompts, assets, gaps
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
    if row.status == "DISABLED" then return Color3.fromRGB(255, 110, 110) end
    local a = row.asset
    return (a and TIER_COLOR[a.tier]) or Color3.fromRGB(210, 235, 210)
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
    local rows = scanEggRows()
    local alive = {}
    for _, r in ipairs(rows) do
        local part = adorneePart(r.model) or r.part
        if part then
            local key = tostring(r.prompt or part)
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
                local name = a and a.name or "(prompt)"
                local income = a and a.income or "-"
                local rar = a and a.rarity or ""
                local mutLine = tostring(r.mut or "-")
                if r.chance then mutLine = mutLine .. " " .. r.chance .. "%" end
                tl.Text = string.format("%s\n%s  %s\n%s · %s",
                    name, tostring(income), tostring(rar), mutLine, r.status)
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

local function scanMine()
    S.lines = {}
    say("=== Egg Status Spy v3.3 — Prompt ใกล้ไข่ ===")
    say("UserId=" .. ME)

    local okS, err = pcall(function()
        local rows, prompts, assets, gaps = scanEggRows()
        local nR, nD = 0, 0
        for _, r in ipairs(rows) do
            if r.status == "READY" then nR = nR + 1 else nD = nD + 1 end
        end
        local nearestPr = prompts[1] and prompts[1].d or -1
        say(string.format("--- ไข่: %d | READY=%d DISABLED=%d | assets=%d prompts=%d | promptใกล้สุด=%.0f ---",
            #rows, nR, nD, #assets, #prompts, nearestPr))

        if #rows == 0 then
            say("⚠ ไม่มี Prompt ติดไข่ในคอก — เกมสตรีม SmartPromptPart เมื่อยืนใกล้ตู้ฟัก")
            say("--- ระยะ Prompt↔ไข่เรา (ใกล้สุดก่อน) ---")
            for i = 1, math.min(10, #gaps) do
                local g = gaps[i]
                say(string.format("  %s | asset_d=%.0f | prompt_gap=%.0f", g.name, g.d, g.gap))
            end
        end
        for i, r in ipairs(rows) do
            local a = r.asset
            if a then
                say(string.format(
                    "#%d [%s] %s | rar=%s | %s | mut=%s %%=%s | prompt=%s | d=%.0f gap=%.1f",
                    i, a.tierTh, a.name,
                    tostring(a.rarity or "-"), tostring(a.income or "-"),
                    tostring(r.mut or "-"), tostring(r.chance or "-"),
                    r.status, r.d, r.gap or 0
                ))
                if a.blob ~= "" then say("    " .. a.blob) end
                if r.obj ~= "" then say("    obj=" .. r.obj) end
            else
                say(string.format("#%d (orphan) prompt=%s | %q | d=%.0f", i, r.status, tostring(r.obj), r.d))
            end
        end

        say("--- Mutation prompts ใกล้ตัว (อ้างอิง) ---")
        local shown = 0
        for _, pr in ipairs(prompts) do
            if pr.d <= 120 then
                shown = shown + 1
                say(string.format("  d=%.0f en=%s %q | %q", pr.d, tostring(pr.en), pr.act, pr.obj))
                if shown >= 12 then break end
            end
        end
        if shown == 0 then
            say(string.format("  (ไม่มี prompt ≤120 — ใกล้สุด d=%.0f obj=%q)", nearestPr, prompts[1] and prompts[1].obj or "-"))
        end
    end)
    if not okS then say("error: " .. tostring(err)) end

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
title.Text = "Egg01 Egg Spy v3.3 — ยืนใกล้คอกแล้ว MINE"
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

local bScan = btn("MINE", 10, Color3.fromRGB(45, 110, 170))
local bEsp = btn("ESP ON", 88, Color3.fromRGB(40, 130, 90))
local bClear = btn("CLEAR", 166, Color3.fromRGB(70, 70, 75))
local bCopy = btn("COPY", 244, Color3.fromRGB(70, 70, 75))
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
box.Text = "MINE = ไข่ที่มี Apply Mutation\nREADY=เขียว DISABLED=แดง"

local function syncEspBtn()
    bEsp.Text = S.espOn and "ESP ON" or "ESP OFF"
    bEsp.BackgroundColor3 = S.espOn and Color3.fromRGB(40, 130, 90) or Color3.fromRGB(90, 70, 70)
end

bScan.MouseButton1Click:Connect(scanMine)
bEsp.MouseButton1Click:Connect(function()
    setEsp(not S.espOn)
    syncEspBtn()
end)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Spy v3.3 ===\n" .. table.concat(S.lines, "\n"))
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

say("v3.3 — Prompt สตรีมเมื่อใกล้ตู้ · ยืนในคอกแล้วกด MINE")
-- จับ SmartPromptPart ที่สตรีมเข้ามาใกล้คอก
S.conns[#S.conns + 1] = workspace.DescendantAdded:Connect(function(x)
    if not S.espOn then return end
    if x:IsA("ProximityPrompt") then
        local act = tostring(x.ActionText or ""):lower()
        if act:find("mutation", 1, true) or act:find("apply", 1, true) then
            task.defer(function() pcall(refreshEsp) end)
        end
    end
end)
setEsp(true)
syncEspBtn()
