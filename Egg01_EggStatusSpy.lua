-- Egg01 Egg Status Spy v5.3 — ขั้น3c: PenRoster.AskLiveSnapshot + AskEggRecord(uid)

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

local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 320 then table.remove(S.lines, 1) end
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

local function findNet(name, className)
    local pkg = RS:FindFirstChild("Packages")
    local net = pkg and pkg:FindFirstChild("Networking")
    local exact, fuzzy
    for _, root in ipairs({ net, RS }) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if className and not d:IsA(className) then
                    -- skip
                else
                    local n = d.Name
                    if n == name or n:sub(-#name - 1) == "/" .. name then
                        exact = exact or d
                    elseif n:find(name, 1, true) then
                        fuzzy = fuzzy or d
                    end
                end
            end
        end
    end
    return exact or fuzzy
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
            out[#out + 1] = { model = m, uid = m.Name:sub(#prefix + 1), full = m.Name, p = p, d = d }
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

local function shortVal(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "table" then
        if depth >= 2 then return "{…}" end
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "table#" .. n
    elseif t == "CFrame" then
        local p = v.Position
        return string.format("CF(%.0f,%.0f,%.0f)", p.X, p.Y, p.Z)
    elseif t == "Vector3" then
        return string.format("V3(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
    elseif t == "string" then
        return (#v > 80) and (v:sub(1, 80) .. "…") or v
    end
    return tostring(v)
end

local function dumpTable(row, indent, limit, acc)
    acc = acc or { n = 0, lines = {} }
    indent = indent or ""
    if acc.n >= (limit or 60) then return acc end
    if typeof(row) ~= "table" then
        acc.n = acc.n + 1
        acc.lines[#acc.lines + 1] = indent .. shortVal(row)
        return acc
    end
    local keys = {}
    for k in pairs(row) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        if acc.n >= (limit or 60) then break end
        local v = row[k]
        if typeof(v) == "table" then
            local n = 0
            for _ in pairs(v) do n = n + 1 end
            acc.n = acc.n + 1
            acc.lines[#acc.lines + 1] = indent .. tostring(k) .. " = table#" .. n
            if n > 0 and n <= 12 and #indent < 6 then
                dumpTable(v, indent .. "  ", limit, acc)
            elseif n > 0 and #indent < 4 then
                -- sample first few
                local i = 0
                for k2, v2 in pairs(v) do
                    i = i + 1
                    if i > 3 or acc.n >= limit then break end
                    acc.n = acc.n + 1
                    if typeof(v2) == "table" then
                        acc.lines[#acc.lines + 1] = indent .. "  [" .. tostring(k2) .. "] = table"
                        dumpTable(v2, indent .. "    ", limit, acc)
                    else
                        acc.lines[#acc.lines + 1] = indent .. "  [" .. tostring(k2) .. "] = " .. shortVal(v2)
                    end
                end
            end
        else
            acc.n = acc.n + 1
            acc.lines[#acc.lines + 1] = indent .. tostring(k) .. " = " .. shortVal(v)
        end
    end
    return acc
end

local INTEREST = {
    "uid", "Uid", "UID", "id", "Id", "_id",
    "name", "Name", "AssetCategory", "AssetName", "Category", "DisplayName",
    "rarity", "Rarity", "AssetScale", "Scale", "State", "state",
    "Mutation", "Mutations", "mut", "Income", "income", "Money", "Earnings",
    "PerSecond", "Cash", "Value", "Tier", "Quality", "Color", "AssetColorIndex",
}

local function pickFields(row)
    if typeof(row) ~= "table" then return {} end
    local out = {}
    for _, k in ipairs(INTEREST) do
        local v = row[k]
        if v ~= nil then
            if typeof(v) == "table" then
                local parts = {}
                for i, m in ipairs(v) do
                    if typeof(m) == "table" then
                        parts[#parts + 1] = tostring(m.Name or m.Id or m.Type or "?")
                    else
                        parts[#parts + 1] = tostring(m)
                    end
                    if #parts >= 4 then break end
                end
                if #parts == 0 then
                    for kk, vv in pairs(v) do
                        parts[#parts + 1] = tostring(kk) .. "=" .. shortVal(vv)
                        if #parts >= 4 then break end
                    end
                end
                out[#out + 1] = k .. "={" .. table.concat(parts, ",") .. "}"
            else
                out[#out + 1] = k .. "=" .. shortVal(v)
            end
        end
    end
    return out
end

local function indexByUid(root, into, path)
    into = into or {}
    if typeof(root) ~= "table" then return into end
    local uid = root.Uid or root.uid or root.UID or root.Id or root.id
    if typeof(uid) == "string" and #uid >= 8 then
        into[uid] = { row = root, path = path or "?" }
        local short = uid:match("([%w%-]+)$")
        if short then into[short] = into[short] or into[uid] end
    end
    -- also key if dictionary keyed by uid
    for k, v in pairs(root) do
        if typeof(k) == "string" and #k >= 8 and typeof(v) == "table" then
            if k:find("-") or #k >= 20 or k:find(ME, 1, true) then
                into[k] = { row = v, path = (path or "") .. "/" .. k }
            end
        end
        if typeof(v) == "table" and (path or ""):len() < 40 then
            indexByUid(v, into, (path or "") .. "/" .. tostring(k))
        end
    end
    return into
end

local function invokeRF(name, payload)
    local rf = findNet(name, "RemoteFunction") or findNet(name)
    if not rf or not rf:IsA("RemoteFunction") then return nil, "ไม่มี " .. name end
    local ok, res = pcall(function()
        if payload == nil then return rf:InvokeServer() end
        return rf:InvokeServer(payload)
    end)
    if not ok then return nil, tostring(res), rf.Name end
    return res, nil, rf.Name
end

local function matchEgg(uid, index)
    return index[uid] or index[ME .. "_" .. uid]
end

local function scan()
    S.lines = {}
    say("=== Egg Spy v5.3 — PenRoster + EggRecord ===")
    say("UserId=" .. ME)

    local eggs = listOurEggs()
    say(string.format("PlacedEggRenders=%d", #eggs))

    -- 1) PenRoster AskLiveSnapshot
    say("… RF/PenRoster/AskLiveSnapshot")
    local pen, penErr, penName = invokeRF("AskLiveSnapshot")
    -- อาจชน EggWorld AskLiveSnapshot — หาตัว PenRoster โดยตรง
    do
        local pkg = RS:FindFirstChild("Packages")
        local net = pkg and pkg:FindFirstChild("Networking")
        if net then
            for _, d in ipairs(net:GetDescendants()) do
                if d:IsA("RemoteFunction") and d.Name:find("PenRoster", 1, true) and d.Name:find("AskLiveSnapshot", 1, true) then
                    local ok, res = pcall(function() return d:InvokeServer() end)
                    say("PenRoster RF=" .. d.Name .. " ok=" .. tostring(ok) .. " typ=" .. typeof(res))
                    if ok then pen, penErr, penName = res, nil, d.Name end
                    break
                end
            end
        end
    end
    if penErr and not pen then say("PenRoster err: " .. tostring(penErr)) end

    local penIndex = {}
    if typeof(pen) == "table" then
        say("--- dump PenRoster snapshot (ย่อ) ---")
        local acc = dumpTable(pen, "", 50)
        for _, ln in ipairs(acc.lines) do say("  " .. ln) end
        penIndex = indexByUid(pen)
        local n = 0
        for _ in pairs(penIndex) do n = n + 1 end
        say("PenRoster uid-index≈" .. n)
    end

    -- 2) EggWorld AskLiveSnapshot แยก
    say("… RF/EggWorld/AskLiveSnapshot")
    do
        local pkg = RS:FindFirstChild("Packages")
        local net = pkg and pkg:FindFirstChild("Networking")
        if net then
            for _, d in ipairs(net:GetDescendants()) do
                if d:IsA("RemoteFunction") and d.Name:find("EggWorld", 1, true) and d.Name:find("AskLiveSnapshot", 1, true) then
                    local ok, res = pcall(function() return d:InvokeServer() end)
                    say("EggWorld Live ok=" .. tostring(ok) .. " typ=" .. typeof(res))
                    if ok and typeof(res) == "table" then
                        local acc = dumpTable(res, "", 30)
                        for _, ln in ipairs(acc.lines) do say("  " .. ln) end
                        local idx = indexByUid(res)
                        local n = 0
                        for _ in pairs(idx) do n = n + 1 end
                        say("EggWorld uid-index≈" .. n)
                        for k, v in pairs(idx) do penIndex[k] = penIndex[k] or v end
                    end
                    break
                end
            end
        end
    end

    -- 3) AskEggRecord ต่อ uid
    say("--- AskEggRecord(uid string) ---")
    local eggRf
    do
        local pkg = RS:FindFirstChild("Packages")
        local net = pkg and pkg:FindFirstChild("Networking")
        if net then
            for _, d in ipairs(net:GetDescendants()) do
                if d:IsA("RemoteFunction") and d.Name:find("AskEggRecord", 1, true) then
                    eggRf = d
                    say("RF=" .. d.Name)
                    break
                end
            end
        end
    end

    local recordHits = 0
    for i, e in ipairs(eggs) do
        local rec, recHow
        if eggRf then
            for _, payload in ipairs({ e.uid, e.full, ME .. "_" .. e.uid }) do
                local ok, res = pcall(function() return eggRf:InvokeServer(payload) end)
                if ok and res ~= nil then
                    rec, recHow = res, "str:" .. tostring(payload):sub(1, 20)
                    break
                end
            end
            -- ลอง table
            if not rec then
                for _, payload in ipairs({
                    { Uid = e.uid }, { uid = e.uid }, { Id = e.uid },
                }) do
                    local ok, res = pcall(function() return eggRf:InvokeServer(payload) end)
                    if ok and typeof(res) == "table" then
                        rec, recHow = res, "table"
                        break
                    end
                end
            end
        end

        local fromPen = matchEgg(e.uid, penIndex)
        local pps = e.p and promptsNear(e.p, 12) or {}
        local prompt = "-"
        for _, pr in ipairs(pps) do
            local al = pr.act:lower()
            if al:find("hatch", 1, true) or al:find("growth", 1, true) or al:find("mut", 1, true) then
                prompt = pr.status .. " " .. pr.act
                break
            end
        end

        say(string.format("#%d d=%.0f uid=%s | prompt=%s", i, e.d, e.uid:sub(1, 12), prompt))
        if fromPen then
            local fields = pickFields(fromPen.row)
            say("    pen[" .. tostring(fromPen.path) .. "]: " .. (#fields > 0 and table.concat(fields, " | ") or dumpTable(fromPen.row, "", 8).lines[1] or "?"))
            if #fields > 0 then recordHits = recordHits + 1 end
        else
            say("    pen: -")
        end
        if rec then
            recordHits = recordHits + 1
            if typeof(rec) == "table" then
                local fields = pickFields(rec)
                say("    record[" .. tostring(recHow) .. "]: " .. (#fields > 0 and table.concat(fields, " | ") or "table"))
                if #fields == 0 then
                    local acc = dumpTable(rec, "      ", 15)
                    for _, ln in ipairs(acc.lines) do say(ln) end
                end
            else
                say("    record[" .. tostring(recHow) .. "]: " .. shortVal(rec))
            end
        else
            say("    record: -")
        end
    end

    say(string.format("--- hits ที่มีฟิลด์น่าสนใจ ≈%d / eggs=%d ---", recordHits, #eggs))
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
f.Size = UDim2.new(0, 680, 0, 400)
f.Position = UDim2.new(0, 12, 0.14, 0)
f.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 Spy v5.3 — PenRoster / EggRecord"
title.TextColor3 = Color3.fromRGB(160, 230, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local function btn(tx, x, col)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, 80, 0, 28)
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

local bGo = btn("SCAN", 10, Color3.fromRGB(45, 110, 170))
local bClear = btn("CLEAR", 96, Color3.fromRGB(70, 70, 75))
local bCopy = btn("COPY", 182, Color3.fromRGB(70, 70, 75))
local bClose = btn("X", 596, Color3.fromRGB(145, 50, 65))

box = Instance.new("TextBox", f)
box.Size = UDim2.new(1, -16, 0, 320)
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
box.Text = "SCAN = PenRoster.AskLiveSnapshot + AskEggRecord(uid)"

bGo.MouseButton1Click:Connect(scan)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Spy v5.3 ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bClose.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_EGG_STATUS_SPY = nil
end)

say("v5.3 — กด SCAN (PenRoster + EggRecord)")
