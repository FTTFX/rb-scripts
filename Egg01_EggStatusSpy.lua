-- Egg01 Egg Status Spy v5.1 — ขั้น3: ชื่อ/$/mut/READY จาก Snapshot+Prompt+dump
-- ไข่ = PlacedEggRenders.{UserId}_*

if _G.EGG01_EGG_STATUS_SPY then
    pcall(function() _G.EGG01_EGG_STATUS_SPY.gui:Destroy() end)
    for _, c in ipairs(_G.EGG01_EGG_STATUS_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local S = { gui = nil, lines = {}, conns = {} }
_G.EGG01_EGG_STATUS_SPY = S

local ME = tostring(LP.UserId)
local box
local PROMPT_GAP = 14

local RARITY_RANK = {
    common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5,
    mythic = 6, cosmic = 7, secret = 8, eternal = 9, divine = 10,
}

local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 260 then table.remove(S.lines, 1) end
    if box then box.Text = table.concat(S.lines, "\n") end
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function pathOf(x)
    local ok, s = pcall(function() return x:GetFullName() end)
    return ok and s:gsub("^Workspace%.", "WS.") or tostring(x)
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

local function cleanRarity(v)
    local w = tostring(v or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if not RARITY_RANK[w] then return nil end
    return w:sub(1, 1):upper() .. w:sub(2)
end

local function findNet(name)
    local pkg = RS:FindFirstChild("Packages")
    local net = pkg and pkg:FindFirstChild("Networking")
    local exact, fuzzy
    for _, root in ipairs({ net, RS }) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                local n = d.Name
                if n == name or n:sub(-#name - 1) == "/" .. name then
                    exact = exact or d
                elseif n:find(name, 1, true) then
                    fuzzy = fuzzy or d
                end
            end
        end
    end
    return exact or fuzzy
end

local function mutText(mut)
    if typeof(mut) ~= "table" or #mut == 0 then return "-" end
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

local function dumpRowBrief(row)
    local keys = {}
    for k, v in pairs(row) do
        local t = typeof(v)
        if t ~= "table" and t ~= "CFrame" and t ~= "Vector3" and t ~= "Instance" then
            keys[#keys + 1] = tostring(k) .. "=" .. tostring(v)
        elseif t == "table" and (k == "Mutations" or k == "mutations") then
            keys[#keys + 1] = "Mutations=" .. mutText(v)
        end
    end
    table.sort(keys)
    return table.concat(keys, ", ")
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

local function posOfRow(row)
    for _, k in ipairs({ "BottomCFrame", "BoundsCFrame", "CFrame", "Position" }) do
        local v = row[k]
        if typeof(v) == "CFrame" then return v.Position end
        if typeof(v) == "Vector3" then return v end
    end
end

local function pullSnapshot()
    local rf = findNet("AskFieldEggSnapshot")
    if not rf or not rf:IsA("RemoteFunction") then return {}, "ไม่มี AskFieldEggSnapshot" end
    local ok, result = pcall(function() return rf:InvokeServer() end)
    if not ok or typeof(result) ~= "table" then return {}, tostring(result) end
    local records = result.Records or result.records or result
    if typeof(records) ~= "table" then return {}, "records ว่าง" end
    local byUid, n = {}, 0
    for k, row in pairs(records) do
        if typeof(row) == "table" then
            local uid = tostring(row.Uid or k)
            local cat = tostring(row.AssetCategory or row.AssetName or "?")
            byUid[uid] = {
                uid = uid,
                cat = cat,
                rar = rarityByCategory[cat],
                scale = tonumber(row.AssetScale) or 0,
                state = tostring(row.State or "?"),
                mut = mutText(row.Mutations),
                nest = tostring(row.NestId or "-"),
                area = tostring(row.AreaId or "?"),
                color = row.AssetColorIndex,
                pos = posOfRow(row),
                brief = dumpRowBrief(row),
                raw = row,
            }
            -- index แบบสั้นด้วย
            local short = uid:match("([%w%-]+)$") or uid
            if short ~= uid then byUid[short] = byUid[short] or byUid[uid] end
            n = n + 1
        end
    end
    return byUid, nil, n
end

local function matchSnap(eggUid, byUid, eggPos)
    -- ตรง uid / ชื่อเต็ม / บางส่วน
    local full = ME .. "_" .. eggUid
    local hit = byUid[eggUid] or byUid[full]
    if hit then return hit, "uid" end
    for uid, row in pairs(byUid) do
        if typeof(uid) == "string" and (uid:find(eggUid, 1, true) or eggUid:find(uid, 1, true)) then
            return row, "uid-fuzzy"
        end
    end
    -- ตำแหน่งใกล้
    if eggPos then
        local best, bestD
        for _, row in pairs(byUid) do
            if row.pos and row.uid then
                local d = (row.pos - eggPos).Magnitude
                if d <= 8 and (not bestD or d < bestD) then
                    best, bestD = row, d
                end
            end
        end
        if best then return best, string.format("pos:%.1f", bestD) end
    end
    return nil, nil
end

local function deepDumpModel(model, limit)
    local lines = {}
    local n = 0
    local function add(s)
        n = n + 1
        if n <= limit then lines[#lines + 1] = s end
    end
    pcall(function()
        for k, v in pairs(model:GetAttributes()) do
            add("attr." .. tostring(k) .. "=" .. tostring(v))
        end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("StringValue") or d:IsA("NumberValue") or d:IsA("IntValue") or d:IsA("BoolValue")
                or d:IsA("ObjectValue") then
                add(d.ClassName .. ":" .. d.Name .. "=" .. tostring(d.Value))
            end
            local attrs = d:GetAttributes()
            for k, v in pairs(attrs) do
                add(d.Name .. ".attr." .. tostring(k) .. "=" .. tostring(v))
            end
            if n >= limit then break end
        end
    end)
    return lines, n
end

local function billboardsNear(pos, rad)
    local texts, seen = {}, {}
    if not pos then return texts end
    pcall(function()
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LP.Character then params.FilterDescendantsInstances = { LP.Character } end
        local parts = workspace:GetPartBoundsInRadius(pos, rad, params)
        local hosts = {}
        for _, part in ipairs(parts) do
            local m = part:FindFirstAncestorWhichIsA("Model") or part
            hosts[m] = true
        end
        for host in pairs(hosts) do
            for _, d in ipairs(host:GetDescendants()) do
                if d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                    for _, t in ipairs(d:GetDescendants()) do
                        if (t:IsA("TextLabel") or t:IsA("TextButton")) and t.Text ~= "" then
                            local s = t.Text:gsub("%s+", " "):match("^%s*(.-)%s*$")
                            if s and not seen[s] then
                                seen[s] = true
                                texts[#texts + 1] = s
                            end
                        end
                    end
                end
            end
        end
    end)
    return texts
end

local function promptsNear(pos, maxGap)
    local rows, seen = {}, {}
    if not pos then return rows end
    pcall(function()
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LP.Character then params.FilterDescendantsInstances = { LP.Character } end
        local parts = workspace:GetPartBoundsInRadius(pos, maxGap, params)
        for _, part in ipairs(parts) do
            local function take(pp, adornee)
                if not pp or seen[pp] then return end
                seen[pp] = true
                local ap = adornee and adornee:IsA("BasePart") and adornee.Position or pos
                rows[#rows + 1] = {
                    en = pp.Enabled,
                    status = pp.Enabled and "READY" or "DISABLED",
                    act = tostring(pp.ActionText or ""),
                    obj = tostring(pp.ObjectText or ""),
                    gap = (ap - pos).Magnitude,
                }
            end
            for _, ch in ipairs(part:GetChildren()) do
                if ch:IsA("ProximityPrompt") then take(ch, part) end
            end
        end
    end)
    for _, ch in ipairs(workspace:GetChildren()) do
        if ch.Name == "SmartPromptPart" and ch:IsA("BasePart") then
            local gap = (ch.Position - pos).Magnitude
            if gap <= maxGap then
                local pp = ch:FindFirstChildWhichIsA("ProximityPrompt")
                if pp and not seen[pp] then
                    seen[pp] = true
                    rows[#rows + 1] = {
                        en = pp.Enabled,
                        status = pp.Enabled and "READY" or "DISABLED",
                        act = tostring(pp.ActionText or ""),
                        obj = tostring(pp.ObjectText or ""),
                        gap = gap,
                    }
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.gap < b.gap end)
    return rows
end

local function classifyPrompts(prompts)
    local mut, hatch, skip, other = nil, nil, nil, nil
    for _, pr in ipairs(prompts) do
        local al = (pr.act .. " " .. pr.obj):lower()
        if al:find("mutation", 1, true) or al:find("apply", 1, true) or al:find("scrambl", 1, true) then
            if not mut or pr.gap < mut.gap then mut = pr end
        elseif al:find("hatch", 1, true) then
            if not hatch or pr.gap < hatch.gap then hatch = pr end
        elseif al:find("skip", 1, true) or al:find("growth", 1, true) then
            if not skip or pr.gap < skip.gap then skip = pr end
        else
            if not other or pr.gap < other.gap then other = pr end
        end
    end
    return mut, hatch, skip, other
end

local function parseIncome(blob)
    return tostring(blob or ""):match("%$[%d%.]+[KMBT]?/s")
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

local function scanEggs()
    S.lines = {}
    say("=== Egg Spy v5.1 — ชื่อ/$/mut/READY ===")
    say("UserId=" .. ME)
    mapRarities()
    say("…ดึง AskFieldEggSnapshot")
    local byUid, err, nSnap = pullSnapshot()
    if err then say("Snapshot: " .. tostring(err)) else say("Snapshot records=" .. tostring(nSnap)) end

    local eggs = listOurEggs()
    say(string.format("--- PlacedEggRenders ของเรา: %d ---", #eggs))

    local matched = 0
    for i, e in ipairs(eggs) do
        local snap, how = matchSnap(e.uid, byUid, e.p)
        local prompts = e.p and promptsNear(e.p, PROMPT_GAP) or {}
        local mutP, hatchP, skipP = classifyPrompts(prompts)
        local nearTxt = billboardsNear(e.p, 10)
        local incomeFromBb = nil
        for _, t in ipairs(nearTxt) do
            incomeFromBb = incomeFromBb or parseIncome(t)
        end

        local name = snap and snap.cat or "?"
        local rar = snap and snap.rar or "-"
        local mut = snap and snap.mut or "-"
        local income = incomeFromBb or "-"
        local ready = "-"

        if mutP then
            ready = mutP.status
            local m2 = mutP.obj:match("(%w+)")
            if mutP.obj ~= "" then
                local low = mutP.obj:lower()
                if low:find("scrambl", 1, true) then mut = "Scrambled" end
                local ch = mutP.obj:match("(%d+)%s*%%")
                if ch then mut = mut .. " " .. ch .. "%" end
                if mut == "-" then mut = mutP.obj end
            end
        elseif hatchP then
            ready = "Hatch:" .. hatchP.status
        elseif skipP then
            ready = "Growth:" .. skipP.status
        end

        if snap then matched = matched + 1 end

        say(string.format(
            "#%d d=%.0f | name=%s | rar=%s | $=%s | mut=%s | prompt=%s | uid=%s",
            i, e.d, name, tostring(rar), tostring(income), tostring(mut), ready, e.uid:sub(1, 12)
        ))
        if snap then
            say(string.format("    snap[%s] st=%s sc=%.2f nest=%s area=%s color=%s",
                tostring(how), snap.state, snap.scale, snap.nest, snap.area, tostring(snap.color)))
        else
            say("    snap: (ไม่เจอ UID ใน Field Snapshot)")
        end
        if #nearTxt > 0 then say("    nearBB: " .. table.concat(nearTxt, " || ")) end
        if mutP then say(string.format("    mutPP: %s act=%q obj=%q gap=%.1f", mutP.status, mutP.act, mutP.obj, mutP.gap)) end
        if hatchP then say(string.format("    hatchPP: %s %q gap=%.1f", hatchP.status, hatchP.act, hatchP.gap)) end
        if skipP then say(string.format("    growthPP: %s %q gap=%.1f", skipP.status, skipP.act, skipP.gap)) end
    end

    say(string.format("--- matched Snapshot %d/%d ---", matched, #eggs))

    -- dump ลึกไข่ใบแรกที่ใกล้สุด
    if eggs[1] then
        say("--- DEEP ไข่ใกล้สุด #" .. eggs[1].uid:sub(1, 12) .. " ---")
        local lines, total = deepDumpModel(eggs[1].model, 40)
        say("deep entries≈" .. tostring(total) .. " (โชว์ " .. #lines .. ")")
        for _, ln in ipairs(lines) do say("  " .. ln) end
        if #lines == 0 then say("  (ไม่มี attr/Value บนโมเดล)") end
    end

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
f.Size = UDim2.new(0, 660, 0, 380)
f.Position = UDim2.new(0, 12, 0.16, 0)
f.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 Spy v5.1 — ชื่อ/$/mut/READY"
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
local bClear = btn("CLEAR", 88, Color3.fromRGB(70, 70, 75))
local bCopy = btn("COPY", 166, Color3.fromRGB(70, 70, 75))
local bClose = btn("X", 576, Color3.fromRGB(145, 50, 65))

box = Instance.new("TextBox", f)
box.Size = UDim2.new(1, -16, 0, 300)
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
box.Text = "EGGS = PlacedEgg + Snapshot + Prompt\nหา name / $ / mut / READY|DISABLED"

bEggs.MouseButton1Click:Connect(scanEggs)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Spy v5.1 ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bClose.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_EGG_STATUS_SPY = nil
end)

say("v5.1 — กด EGGS (Snapshot + Prompt + DEEP)")
