-- Egg01 Egg Status Spy v6.1
-- ไข่คอก: อ่านง่าย — ชื่อ / สี(คุณภาพ) / rar / sc / mut / prompt

if _G.EGG01_EGG_STATUS_SPY then
    pcall(function()
        for _, bb in pairs(_G.EGG01_EGG_STATUS_SPY.esp or {}) do pcall(function() bb:Destroy() end) end
    end)
    pcall(function() _G.EGG01_EGG_STATUS_SPY.gui:Destroy() end)
    for _, c in ipairs(_G.EGG01_EGG_STATUS_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
    _G.EGG01_EGG_STATUS_SPY.espToken = (_G.EGG01_EGG_STATUS_SPY.espToken or 0) + 1
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local S = { gui = nil, lines = {}, conns = {}, esp = {}, espOn = false, espToken = 0 }
_G.EGG01_EGG_STATUS_SPY = S

local ME = tostring(LP.UserId)
local box
local ESP_TAG = "Egg01_PlacedEggESP"

local RARITY_RANK = {
    common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5,
    mythic = 6, cosmic = 7, secret = 8, eternal = 9, divine = 10,
}
local RARITY_COLOR = {
    Common = Color3.fromRGB(190, 195, 205), Uncommon = Color3.fromRGB(75, 205, 105),
    Rare = Color3.fromRGB(65, 135, 255), Epic = Color3.fromRGB(178, 78, 235),
    Legendary = Color3.fromRGB(255, 196, 35), Mythic = Color3.fromRGB(245, 70, 95),
    Cosmic = Color3.fromRGB(55, 220, 235), Secret = Color3.fromRGB(230, 65, 205),
    Eternal = Color3.fromRGB(45, 220, 175), Divine = Color3.fromRGB(245, 238, 255),
}

-- คุณภาพสีไข่ (เงิน/ทอง/รุ้ง) — จาก Mutations / ItemData / ColorIndex
local QUALITY_TH = {
    Rainbow = "รุ้ง", Divine = "ดีไวน์", Diamond = "เพชร",
    Golden = "ทอง", Gold = "ทอง", Silver = "เงิน", Bronze = "ทองแดง",
    Shiny = "ไชน์", Galaxy = "กาแล็กซี", Neon = "นีออน",
    Dark = "ดาร์ก", Crystal = "คริสตัล", Normal = "ปกติ",
}
local QUALITY_COLOR = {
    Rainbow = Color3.fromRGB(255, 120, 220), Golden = Color3.fromRGB(255, 200, 60),
    Gold = Color3.fromRGB(255, 200, 60), Silver = Color3.fromRGB(200, 210, 230),
    Diamond = Color3.fromRGB(140, 220, 255), Neon = Color3.fromRGB(80, 255, 180),
    Normal = Color3.fromRGB(210, 235, 210),
}
-- AssetColorIndex ที่เจอบ่อย (1=ปกติ เป็นค่าเริ่ม)
local COLOR_INDEX_QUALITY = {
    [1] = "Normal", [2] = "Silver", [3] = "Golden", [4] = "Rainbow",
    [5] = "Diamond", [6] = "Galaxy",
}

local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 200 then table.remove(S.lines, 1) end
    if box then box.Text = table.concat(S.lines, "\n") end
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function instPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, piv = pcall(function() return inst:GetPivot() end)
        if ok and piv then return piv.Position end
        if inst.PrimaryPart then return inst.PrimaryPart.Position end
        local p = inst:FindFirstChildWhichIsA("BasePart", true)
        return p and p.Position
    end
    local p = inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local function adorneePart(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    return model.PrimaryPart or model:FindFirstChild("Hitbox") or model:FindFirstChildWhichIsA("BasePart", true)
end

local function cleanRarity(v)
    local w = tostring(v or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if not RARITY_RANK[w] then return nil end
    return w:sub(1, 1):upper() .. w:sub(2)
end

local rarityByCategory = {}
local function mapRarities()
    rarityByCategory = {}
    pcall(function()
        if not getgc then return end
        for _, obj in ipairs(getgc(true)) do
            if typeof(obj) == "table" then
                local cat = rawget(obj, "AssetCategory") or rawget(obj, "Category")
                local cfg = rawget(obj, "Config")
                if cat and typeof(cfg) == "table" then
                    local rar = cfg.Rarity
                    local id = typeof(rar) == "table" and (rar._id or rar.Id or rar.Name) or rar
                    local cleaned = cleanRarity(id)
                    if cleaned then rarityByCategory[tostring(cat)] = cleaned end
                end
            end
        end
    end)
end

local function fmtMoney(n)
    n = tonumber(n)
    if not n then return "-" end
    local abs, suf = math.abs(n), ""
    if abs >= 1e12 then n, suf = n / 1e12, "T"
    elseif abs >= 1e9 then n, suf = n / 1e9, "B"
    elseif abs >= 1e6 then n, suf = n / 1e6, "M"
    elseif abs >= 1e3 then n, suf = n / 1e3, "K" end
    if suf == "" then return string.format("$%.0f/s", n) end
    local s = string.format("%.1f", n):gsub("%.0$", "")
    return "$" .. s .. suf .. "/s"
end

local function mutText(mut)
    if typeof(mut) ~= "table" then return tostring(mut or "-") end
    if #mut == 0 then
        local parts = {}
        for k, v in pairs(mut) do
            if typeof(v) == "table" then
                parts[#parts + 1] = tostring(v.Name or v.Id or k)
            elseif typeof(k) == "number" then
                parts[#parts + 1] = tostring(v)
            else
                parts[#parts + 1] = tostring(k)
            end
            if #parts >= 4 then break end
        end
        return #parts > 0 and table.concat(parts, ",") or "-"
    end
    local parts = {}
    for i, m in ipairs(mut) do
        if typeof(m) == "table" then
            parts[#parts + 1] = tostring(m.Name or m.Id or m.Type or m.Mutation or "?")
        else
            parts[#parts + 1] = tostring(m)
        end
        if #parts >= 4 then break end
    end
    return table.concat(parts, ",")
end

local function parseQuality(rec, mutStr)
    local blob = (mutStr or "") .. " "
    if rec then
        blob = blob .. tostring(rec.Quality or rec.Tier or rec.Variant or "") .. " "
        if typeof(rec.ItemData) == "table" then
            local id = rec.ItemData
            blob = blob .. tostring(id.Quality or id.Tier or id.Variant or id.Name or "") .. " "
        end
        if typeof(rec.Mutations) == "table" then
            blob = blob .. mutText(rec.Mutations) .. " "
        end
    end
    local low = blob:lower()
    for _, q in ipairs({ "Rainbow", "Divine", "Diamond", "Golden", "Gold", "Silver", "Bronze", "Galaxy", "Neon", "Crystal", "Shiny" }) do
        if low:find(q:lower(), 1, true) then
            return q, QUALITY_TH[q] or q
        end
    end
    local idx = rec and tonumber(rec.AssetColorIndex)
    if idx and COLOR_INDEX_QUALITY[idx] then
        local q = COLOR_INDEX_QUALITY[idx]
        return q, QUALITY_TH[q] or q
    end
    return "Normal", "ปกติ"
end

local function findRF(pathHint, name)
    local pkg = RS:FindFirstChild("Packages")
    local net = pkg and pkg:FindFirstChild("Networking")
    if not net then return nil end
    local exact
    for _, d in ipairs(net:GetDescendants()) do
        if d:IsA("RemoteFunction") then
            local n = d.Name
            if pathHint and n:find(pathHint, 1, true) and n:find(name, 1, true) then
                return d
            end
            if n == name or n:sub(-#name - 1) == "/" .. name then
                exact = exact or d
            end
        end
    end
    return exact
end

local function listOurEggs()
    local folder = workspace:FindFirstChild("PlacedEggRenders")
    local out = {}
    if not folder then return out end
    local prefix = ME .. "_"
    local root = hr()
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m.Name:sub(1, #prefix) == prefix then
            local p = instPos(m)
            local d = (root and p) and (p - root.Position).Magnitude or 99999
            out[#out + 1] = {
                model = m,
                uid = m.Name:sub(#prefix + 1),
                full = m.Name,
                p = p,
                d = d,
            }
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local function promptsNear(pos, maxGap)
    local rows = {}
    if not pos then return rows end
    for _, ch in ipairs(workspace:GetChildren()) do
        if ch.Name == "SmartPromptPart" and ch:IsA("BasePart") then
            local gap = (ch.Position - pos).Magnitude
            if gap <= maxGap then
                local pp = ch:FindFirstChildWhichIsA("ProximityPrompt")
                if pp then
                    rows[#rows + 1] = {
                        gap = gap, en = pp.Enabled,
                        status = pp.Enabled and "READY" or "DISABLED",
                        act = tostring(pp.ActionText or ""),
                        obj = tostring(pp.ObjectText or ""),
                    }
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.gap < b.gap end)
    return rows
end

local function bestPrompt(prompts)
    local mut, hatch, skip
    for _, pr in ipairs(prompts) do
        local al = (pr.act .. " " .. pr.obj):lower()
        if al:find("mutation", 1, true) or al:find("apply", 1, true) or al:find("scrambl", 1, true) then
            if not mut or pr.gap < mut.gap then mut = pr end
        elseif al:find("hatch", 1, true) then
            if not hatch or pr.gap < hatch.gap then hatch = pr end
        elseif al:find("skip", 1, true) or al:find("growth", 1, true) then
            if not skip or pr.gap < skip.gap then skip = pr end
        end
    end
    local pr = mut or hatch or skip
    if not pr then return "-", nil end
    local kind = mut and "Mut" or (hatch and "Hatch" or "Growth")
    return kind .. ":" .. pr.status, pr
end

local function pullPenRecords()
    local rf = findRF("PenRoster", "AskLiveSnapshot")
    if not rf then return {}, "ไม่มี PenRoster/AskLiveSnapshot" end
    local ok, res = pcall(function() return rf:InvokeServer() end)
    if not ok or typeof(res) ~= "table" then return {}, tostring(res) end
    local byUid = {}
    for _, plot in pairs(res) do
        if typeof(plot) == "table" and tostring(plot.OwnerUserId) == ME and typeof(plot.Records) == "table" then
            for uid, row in pairs(plot.Records) do
                if typeof(row) == "table" then
                    local id = tostring(row.UID or row.Uid or uid)
                    byUid[id] = row
                end
            end
        end
    end
    return byUid, nil
end

local function pullEggWorldRecords()
    local rf = findRF("EggWorld", "AskLiveSnapshot")
    if not rf then return {} end
    local ok, res = pcall(function() return rf:InvokeServer() end)
    if not ok or typeof(res) ~= "table" then return {} end
    local byUid = {}
    for _, plot in pairs(res) do
        if typeof(plot) == "table" and tostring(plot.OwnerUserId) == ME and typeof(plot.Records) == "table" then
            for uid, row in pairs(plot.Records) do
                if typeof(row) == "table" then
                    local id = tostring(row.UID or row.Uid or uid)
                    byUid[id] = row
                end
            end
        end
    end
    return byUid
end

local function askEggRecord(uid)
    local rf = findRF("EggWorld", "AskEggRecord") or findRF(nil, "AskEggRecord")
    if not rf then return nil end
    local ok, res = pcall(function() return rf:InvokeServer(uid) end)
    if ok and typeof(res) == "table" then return res end
    return nil
end

local function mergeRow(a, b)
    if not a then return b end
    if not b then return a end
    local out = {}
    for k, v in pairs(a) do out[k] = v end
    for k, v in pairs(b) do
        if out[k] == nil or out[k] == "" then out[k] = v end
        if k == "Mutations" and (not out[k] or (typeof(out[k]) == "table" and #out[k] == 0)) then
            out[k] = v
        end
        if k == "MoneyPerSecond" and (not out[k] or out[k] == 0) then out[k] = v end
        if k == "AssetCategory" and (not out[k] or out[k] == "?") then out[k] = v end
    end
    return out
end

local function buildRows()
    mapRarities()
    local pen, penErr = pullPenRecords()
    local world = pullEggWorldRecords()
    local eggs = listOurEggs()
    local rows = {}
    for _, e in ipairs(eggs) do
        local rec = mergeRow(pen[e.uid], world[e.uid])
        rec = mergeRow(rec, askEggRecord(e.uid))
        local cat = rec and tostring(rec.AssetCategory or rec.AssetName or "?") or "?"
        local rar = rarityByCategory[cat]
        local mut = rec and mutText(rec.Mutations) or "-"
        local money = rec and (rec.MoneyPerSecond or rec.moneyPerSecond) or nil
        -- ItemData may nest income
        if not money and rec and typeof(rec.ItemData) == "table" then
            money = rec.ItemData.MoneyPerSecond or rec.ItemData.Income
            if cat == "?" then cat = tostring(rec.ItemData.AssetCategory or rec.ItemData.Name or cat) end
            if mut == "-" then mut = mutText(rec.ItemData.Mutations) end
        end
        local pps = e.p and promptsNear(e.p, 12) or {}
        local prompt, pr = bestPrompt(pps)
        if pr and (pr.obj:lower():find("scrambl", 1, true)) and mut == "-" then
            mut = "Scrambled"
            local ch = pr.obj:match("(%d+)%s*%%")
            if ch then mut = mut .. " " .. ch .. "%" end
        end
        local qEn, qTh = parseQuality(rec, mut)
        rows[#rows + 1] = {
            d = e.d, uid = e.uid, model = e.model, p = e.p,
            name = cat, rar = rar or "-", mut = mut,
            money = money, moneyS = fmtMoney(money),
            scale = rec and tonumber(rec.AssetScale) or 0,
            color = rec and rec.AssetColorIndex,
            quality = qEn, qualityTh = qTh,
            prompt = prompt, promptRaw = pr,
            rec = rec,
        }
    end
    return rows, penErr
end

local function clearEsp()
    for _, bb in pairs(S.esp) do pcall(function() bb:Destroy() end) end
    S.esp = {}
end

local function makeEsp(part)
    local bb = Instance.new("BillboardGui")
    bb.Name = ESP_TAG
    bb.Size = UDim2.new(0, 168, 0, 58)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 200
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

local function refreshEsp(rows)
    if not S.espOn then return end
    rows = rows or select(1, buildRows())
    local alive = {}
    for _, r in ipairs(rows) do
        local part = adorneePart(r.model)
        if part then
            alive[r.uid] = true
            local bb = S.esp[r.uid]
            local tl
            if not bb or not bb.Parent then
                bb, tl = makeEsp(part)
                S.esp[r.uid] = bb
            else
                tl = bb:FindFirstChild("L")
            end
            if tl then
                tl.Text = string.format("%s\n[%s] %s  sc=%.2f\n%s · %s",
                    r.name, r.qualityTh, r.rar, r.scale, r.mut, r.prompt)
                local col = QUALITY_COLOR[r.quality] or RARITY_COLOR[r.rar]
                if r.prompt:find("READY", 1, true) then col = Color3.fromRGB(80, 255, 140)
                elseif r.prompt:find("DISABLED", 1, true) then col = Color3.fromRGB(255, 140, 140) end
                tl.TextColor3 = col or Color3.fromRGB(210, 235, 210)
            end
        end
    end
    for uid, bb in pairs(S.esp) do
        if not alive[uid] then
            pcall(function() bb:Destroy() end)
            S.esp[uid] = nil
        end
    end
end

local function startEspLoop()
    S.espToken = (S.espToken or 0) + 1
    local token = S.espToken
    task.spawn(function()
        while S.espOn and S.espToken == token and S.gui and S.gui.Parent do
            pcall(function() refreshEsp() end)
            task.wait(1.5)
        end
    end)
end

local function setEsp(on)
    S.espOn = on and true or false
    if not S.espOn then clearEsp() else startEspLoop() end
end

local function scan()
    S.lines = {}
    say("=== Egg Spy v6.1 — อ่านง่าย ===")
    say("UserId=" .. ME)
    local rows, err = buildRows()
    if err then say("PenRoster: " .. tostring(err)) end
    say(string.format("--- ไข่ %d ฟอง | ESP=%s ---", #rows, S.espOn and "ON" or "OFF"))
    say("")
    for i, r in ipairs(rows) do
        -- แถวหลักอ่านง่าย
        say(string.format("#%d  %s", i, r.name))
        say(string.format("    สี=%s | rar=%s | sc=%.2f", r.qualityTh, r.rar, r.scale))
        say(string.format("    mut=%s | %s | d=%.0f", r.mut, r.prompt, r.d))
    end
    say("")
    say("=== DONE ===")
    if S.espOn then refreshEsp(rows) end
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
title.Text = "Egg01 Spy v6.1 — สี/sc/mut อ่านง่าย"
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
local bEsp = btn("ESP OFF", 88, Color3.fromRGB(90, 70, 70))
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
box.Text = "EGGS = ชื่อ · สี(คุณภาพ) · rar · sc · mut · prompt\nESP = ป้ายบนหัว"

local function syncEspBtn()
    bEsp.Text = S.espOn and "ESP ON" or "ESP OFF"
    bEsp.BackgroundColor3 = S.espOn and Color3.fromRGB(40, 130, 90) or Color3.fromRGB(90, 70, 70)
end

bEggs.MouseButton1Click:Connect(scan)
bEsp.MouseButton1Click:Connect(function()
    setEsp(not S.espOn)
    syncEspBtn()
end)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Spy v6.1 ===\n" .. table.concat(S.lines, "\n"))
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

say("v6.1 — กด EGGS (สี + sc อ่านง่าย)")
syncEspBtn()
