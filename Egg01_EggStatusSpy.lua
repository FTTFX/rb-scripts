-- Egg01 Egg Status Spy v1.2
-- เฉพาะไข่ของเรา (ตัดสัตว์ $/s) + คุณภาพเงิน/ทอง/รุ้ง + Mutation

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

-- ลำดับคุณภาพที่เจอบ่อย (ยาวก่อน กัน match บางส่วนผิด)
local TIERS = {
    "Rainbow", "Divine", "Diamond", "Golden", "Gold", "Silver", "Bronze",
    "Shiny", "Galaxy", "Neon", "Dark", "Crystal", "Normal",
}
local TIER_TH = {
    Rainbow = "รุ้ง", Divine = "ดีไวน์", Diamond = "เพชร", Golden = "ทอง", Gold = "ทอง",
    Silver = "เงิน", Bronze = "ทองแดง", Shiny = "ไชน์", Galaxy = "กาแล็กซี",
    Neon = "นีออน", Dark = "ดาร์ก", Crystal = "คริสตัล", Normal = "ปกติ",
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

local function parseName(blob, tier, mut)
    local s = blob
    for _, t in ipairs(TIERS) do
        s = s:gsub("^%s*" .. t .. "%s*%+?%s*", "")
        s = s:gsub("%s*" .. t .. "%s*%+?%s*", " ")
    end
    s = s:gsub("%s*%+?%s*Scrambled%s+Mutation%s*", " ")
    s = s:gsub("%s*Scrambled%s+Mutation%s*", " ")
    s = s:gsub("%s*Mutation%s*", " ")
    s = s:gsub("%s*Disabled%s*", " ")
    -- ตัดรายได้ / rarity ท้ายป้ายสัตว์
    s = s:gsub("%s*%$[%d%.]+[KMBT]?/s.*$", "")
    s = s:gsub("%s*%|%s*.*$", "")
    s = s:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if s == "" or s:lower() == (tier or ""):lower() then return "?" end
    return s
end

local function isPetBlob(blob)
    -- สัตว์ในคอกมีรายได้ $x/s — ไข่ไม่มี
    return tostring(blob):find("%$[%d%.]+[KMBT]?/s") ~= nil
        or tostring(blob):find("%d%.[%d]+[KMBT]/s") ~= nil
end

local function isEggBlob(blob, name)
    local low = (tostring(blob) .. " " .. tostring(name or "")):lower()
    if isPetBlob(blob) then return false end
    if low:find("egg", 1, true) then return true end
    -- ไม่มีรายได้ + มี mutation/disabled → น่าจะไข่
    if low:find("scrambl", 1, true) or low:find("mutat", 1, true) or low:find("disabled", 1, true) then
        return true
    end
    return false
end

local function findNet(name, className)
    local networking = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Networking")
    local roots = { networking, RS }
    for _, root in ipairs(roots) do
        if root then
            for _, item in ipairs(root:GetDescendants()) do
                if item.Name == name or item.Name:find(name, 1, true) then
                    if not className or item.ClassName == className then return item end
                end
            end
        end
    end
end

local function posOf(row)
    for _, k in ipairs({ "BottomCFrame", "BoundsCFrame", "CFrame", "Position" }) do
        local v = row[k]
        if typeof(v) == "CFrame" then return v.Position end
        if typeof(v) == "Vector3" then return v end
    end
end

local function mineAssets(eggsOnly)
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
            local name = parseName(blob, tier, mut)
            if eggsOnly and not isEggBlob(blob, name) then
                -- skip pets
            else
                local p = instPos(m)
                local d = (root and p) and (p - root.Position).Magnitude or 99999
                out[#out + 1] = {
                    id = m.Name:sub(#prefix + 1, #prefix + 8),
                    name = name,
                    tier = tier,
                    tierTh = tierTh,
                    mut = mut,
                    chance = chance,
                    blob = blob,
                    d = d,
                    p = p,
                    path = pathOf(m),
                    model = m,
                    pet = isPetBlob(blob),
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local function snapshotMyEggs()
    local rf = findNet("AskFieldEggSnapshot", "RemoteFunction") or findNet("AskFieldEggSnapshot")
    if not rf or not rf:IsA("RemoteFunction") then return nil, "ไม่มี AskFieldEggSnapshot" end
    local ok, result = pcall(function() return rf:InvokeServer() end)
    if not ok or typeof(result) ~= "table" then return nil, tostring(result) end
    local records = result.Records or result.records or result
    if typeof(records) ~= "table" then return nil, "records ว่าง" end
    local list, root = {}, hr()
    for id, row in pairs(records) do
        if typeof(row) == "table" then
            local uid = tostring(row.Uid or id)
            if uid:find(ME, 1, true) then
                local mut = row.Mutations
                local mutS = typeof(mut) == "table" and ("#" .. tostring(#mut)) or tostring(mut)
                local p = posOf(row)
                local d = (root and p) and (p - root.Position).Magnitude or 99999
                list[#list + 1] = {
                    cat = tostring(row.AssetCategory or "?"),
                    st = tostring(row.State or "?"),
                    scale = tonumber(row.AssetScale) or 0,
                    mut = mutS,
                    nest = tostring(row.NestId or "-"),
                    d = d,
                    p = p,
                    uid = uid,
                }
            end
        end
    end
    table.sort(list, function(a, b) return a.nest < b.nest end)
    return list
end

local function nearbyMutPrompts()
    local root = hr()
    local rows = {}
    for _, x in ipairs(workspace:GetDescendants()) do
        if x:IsA("ProximityPrompt") then
            local act = tostring(x.ActionText or "")
            local obj = tostring(x.ObjectText or "")
            local al, ol = act:lower(), obj:lower()
            -- เฉพาะ prompt ไข่ / mutation บนไข่ (ไม่โชว์ CLAIM กลุ่ม)
            if al:find("mutation", 1, true) or ol:find("egg", 1, true) or (al:find("steal", 1, true) and ol:find("egg", 1, true)) then
                local part = x.Parent and (x.Parent:IsA("BasePart") and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart", true))
                local p = part and part.Position
                local d = (root and p) and (p - root.Position).Magnitude or 99999
                rows[#rows + 1] = {
                    d = d, en = x.Enabled,
                    act = act, obj = obj,
                    p = p,
                }
            end
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    return rows
end

local function matchPrompt(asset, prompts)
    if not asset.p then return nil end
    local best
    for _, pr in ipairs(prompts) do
        if pr.p then
            local d = (pr.p - asset.p).Magnitude
            if d <= 12 and (not best or d < best.d) then
                best = { d = d, en = pr.en, obj = pr.obj, act = pr.act }
            end
        end
    end
    return best
end

local function mineFirstAreaSlots()
    local folder = workspace:FindFirstChild("AreaEggSlotsClient")
    local out = {}
    if not folder then return out end
    local key = "FirstAreaEgg_" .. ME
    local root = hr()
    for _, m in ipairs(folder:GetChildren()) do
        if m.Name:find(key, 1, true) then
            local slot = m.Name:match("Slot_%d+") or "?"
            local texts = collectTexts(m)
            local p = instPos(m)
            local d = (root and p) and (p - root.Position).Magnitude or 99999
            out[#out + 1] = {
                slot = slot,
                texts = texts,
                d = d,
                p = p,
                name = m.Name,
            }
        end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

local function scanEggs()
    S.lines = {}
    say("=== Egg Status Spy v1.2 — ไข่ของเราเท่านั้น ===")
    say("UserId=" .. ME)

    local eggsSnap, err = snapshotMyEggs()
    say("--- Snapshot ไข่ (FirstArea / ของเรา) ---")
    if not eggsSnap then
        say("Snapshot: " .. tostring(err))
    elseif #eggsSnap == 0 then
        say("(ไม่มีไข่ใน Snapshot ที่ผูก UserId)")
    else
        for i, e in ipairs(eggsSnap) do
            local posS = e.p and string.format("%.0f,%.0f,%.0f", e.p.X, e.p.Y, e.p.Z) or "-"
            say(string.format("#%d %s | %s sc=%.2f mut=%s nest=%s d=%.0f @%s",
                i, e.st, e.cat, e.scale, e.mut, e.nest, e.d, posS))
        end
        say("รวมไข่ snapshot = " .. #eggsSnap)
    end

    local slots = mineFirstAreaSlots()
    say(string.format("--- AreaEggSlotsClient ของเรา: %d ---", #slots))
    for _, s in ipairs(slots) do
        local matched
        if eggsSnap and s.p then
            for _, e in ipairs(eggsSnap) do
                if e.p and (e.p - s.p).Magnitude < 8 then matched = e; break end
            end
        end
        if matched then
            say(string.format("  %s → %s sc=%.2f mut=%s d=%.0f",
                s.slot, matched.cat, matched.scale, matched.mut, s.d))
        else
            local extra = #s.texts > 0 and (" | " .. table.concat(s.texts, " / ")) or " (ว่าง/ไม่มีป้าย)"
            say(string.format("  %s d=%.0f%s", s.slot, s.d, extra))
        end
    end

    local eggAssets = mineAssets(true)
    say(string.format("--- ClientRendered แบบไข่ (ไม่มี $/s): %d ---", #eggAssets))
    if #eggAssets == 0 then
        say("(ไม่มี — ของในคอกส่วนใหญ่เป็นสัตว์ฟักแล้ว มีรายได้)")
    end
    local prompts = nearbyMutPrompts()
    local byTier = {}
    for i, a in ipairs(eggAssets) do
        local pr = matchPrompt(a, prompts)
        local mutS = a.mut or "-"
        local chance = a.chance or "-"
        if pr and (pr.obj:lower():find("scrambl") or pr.obj:lower():find("success")) then
            mutS = a.mut or select(1, parseMut(pr.obj)) or mutS
            chance = a.chance or pr.obj:match("(%d+)%s*%%") or chance
        end
        local enS = pr and (pr.en and "READY" or "DISABLED") or "?"
        say(string.format("#%d [%s] %s | mut=%s chance=%s | %s | d=%.0f",
            i, a.tierTh, a.name, tostring(mutS), tostring(chance), enS, a.d))
        if a.blob ~= "" then say("    " .. a.blob) end
        byTier[a.tier] = (byTier[a.tier] or 0) + 1
    end
    local parts = {}
    for _, t in ipairs(TIERS) do
        if byTier[t] then parts[#parts + 1] = (TIER_TH[t] or t) .. "=" .. byTier[t] end
    end
    if #parts > 0 then say("สรุปคุณภาพไข่: " .. table.concat(parts, " | ")) end

    say("=== DONE ===")
end

local function scanPets()
    S.lines = {}
    say("=== สัตว์ในคอกของเรา (มี $/s) ===")
    local pets = mineAssets(false)
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
    say("รวมสัตว์=" .. n .. ( #parts > 0 and (" | " .. table.concat(parts, " | ")) or ""))
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
title.Text = "Egg01 Egg Status Spy v1.2 — ไข่เท่านั้น + เงิน/ทอง/รุ้ง"
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
box.Text = "EGGS = ไข่ของเราเท่านั้น (ตัดสัตว์ $/s)\nPETS = สัตว์ในคอก"

bEggs.MouseButton1Click:Connect(scanEggs)
bPets.MouseButton1Click:Connect(scanPets)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Status Spy v1.2 ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bClose.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_EGG_STATUS_SPY = nil
end)

say("v1.2 พร้อม — กด EGGS")
