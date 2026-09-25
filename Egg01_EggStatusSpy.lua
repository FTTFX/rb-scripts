-- Egg01 Egg Status Spy v1.0
-- สแกนสถานะไข่ที่ฝาก/ในฟาร์ม: Disabled / Success Chance / Mutation / State จาก Snapshot+Prompt+Slot

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

local box
local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 200 then table.remove(S.lines, 1) end
    if box then box.Text = table.concat(S.lines, "\n") end
    warn("[EggStatusSpy] " .. tostring(x))
end

local function pathOf(x)
    local ok, s = pcall(function() return x:GetFullName() end)
    return ok and s:gsub("^Workspace%.", "WS."):gsub("^ReplicatedStorage%.", "RS.") or tostring(x)
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function posOf(row)
    for _, k in ipairs({ "BottomCFrame", "BoundsCFrame", "CFrame", "Position" }) do
        local v = row[k]
        if typeof(v) == "CFrame" then return v.Position end
        if typeof(v) == "Vector3" then return v end
    end
end

local function findNet(name, className)
    local networking = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Networking")
    local roots = {}
    if networking then roots[#roots + 1] = networking end
    roots[#roots + 1] = RS
    for _, root in ipairs(roots) do
        for _, item in ipairs(root:GetDescendants()) do
            if item.Name == name or item.Name:find(name, 1, true) then
                if not className or item.ClassName == className then return item end
            end
        end
    end
end

local STATUS_KEYS = { "disabled", "success", "chance", "mutation", "mutat", "parasite", "hatch", "claim", "slot", "ready", "cooldown", "timer" }

local function looksStatus(s)
    s = tostring(s or ""):lower()
    if s == "" then return false end
    for _, k in ipairs(STATUS_KEYS) do
        if s:find(k, 1, true) then return true end
    end
    return false
end

local function attrsOf(inst)
    local out = {}
    pcall(function()
        for k, v in pairs(inst:GetAttributes()) do
            out[#out + 1] = tostring(k) .. "=" .. tostring(v)
        end
    end)
    table.sort(out)
    return #out > 0 and table.concat(out, ", ") or "-"
end

local function scanPrompts()
    local root = hr()
    local rows = {}
    for _, x in ipairs(workspace:GetDescendants()) do
        if x:IsA("ProximityPrompt") then
            local act = tostring(x.ActionText or "")
            local obj = tostring(x.ObjectText or "")
            local nameL = (x.Name .. " " .. act .. " " .. obj):lower()
            local eggish = nameL:find("egg", 1, true) or looksStatus(act) or looksStatus(obj)
            if eggish then
                local part = x.Parent and (x.Parent:IsA("BasePart") and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart", true))
                local p = part and part.Position
                local d = (root and p) and (p - root.Position).Magnitude or 99999
                rows[#rows + 1] = {
                    pp = x, d = d, p = p,
                    act = act, obj = obj,
                    en = x.Enabled,
                    hold = x.HoldDuration,
                    path = pathOf(x),
                }
            end
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    return rows
end

local function scanBillboards(maxN)
    local root = hr()
    local rows = {}
    for _, x in ipairs(workspace:GetDescendants()) do
        if x:IsA("BillboardGui") or x:IsA("SurfaceGui") then
            local texts = {}
            for _, d in ipairs(x:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
                    if looksStatus(d.Text) or tostring(d.Text):lower():find("egg", 1, true) then
                        texts[#texts + 1] = d.Text
                    end
                end
            end
            if #texts > 0 then
                local adornee = x.Adornee or x.Parent
                local p
                if adornee and adornee:IsA("BasePart") then p = adornee.Position
                elseif adornee and adornee:IsA("Model") then
                    local ok, piv = pcall(function() return adornee:GetPivot() end)
                    p = ok and piv and piv.Position
                end
                local d = (root and p) and (p - root.Position).Magnitude or 99999
                rows[#rows + 1] = { d = d, texts = texts, path = pathOf(x) }
            end
        end
    end
    table.sort(rows, function(a, b) return a.d < b.d end)
    if maxN and #rows > maxN then
        local cut = {}
        for i = 1, maxN do cut[i] = rows[i] end
        return cut
    end
    return rows
end

local function scanSlots()
    local found = {}
    local function dig(root, label)
        if not root then return end
        for _, x in ipairs(root:GetDescendants()) do
            local n = x.Name:lower()
            if n:find("slot", 1, true) or n:find("egg", 1, true) then
                local interesting = looksStatus(x.Name) or x:IsA("ProximityPrompt") or x:GetAttribute("State") ~= nil
                local attr = attrsOf(x)
                if interesting or (attr ~= "-" and (attr:lower():find("state") or attr:lower():find("mutat") or attr:lower():find("success"))) then
                    found[#found + 1] = string.format("%s %s | %s | attrs=%s", label, x.ClassName, pathOf(x), attr)
                end
            end
        end
    end
    dig(workspace:FindFirstChild("AreaEggSlotsClient"), "AreaEggSlotsClient")
    local objs = workspace:FindFirstChild("__OBJECTS")
    dig(objs and objs:FindFirstChild("Areas"), "Areas")
    dig(workspace:FindFirstChild("ClientRenderedAssets"), "ClientRenderedAssets")
    return found
end

local function dumpSnapshot()
    local rf = findNet("AskFieldEggSnapshot", "RemoteFunction") or findNet("AskFieldEggSnapshot")
    if not rf or not rf:IsA("RemoteFunction") then
        say("ไม่พบ AskFieldEggSnapshot")
        return
    end
    local ok, result = pcall(function() return rf:InvokeServer() end)
    if not ok or typeof(result) ~= "table" then
        say("Snapshot error: " .. tostring(result))
        return
    end
    local records = result.Records or result.records or result
    if typeof(records) ~= "table" then
        say("Snapshot.Records type=" .. typeof(records))
        return
    end
    local byState, list, uidMe = {}, {}, tostring(LP.UserId)
    local total = 0
    for id, row in pairs(records) do
        if typeof(row) == "table" then
            total = total + 1
            local st = tostring(row.State or "?")
            byState[st] = (byState[st] or 0) + 1
            local uid = tostring(row.Uid or id)
            local mine = uid:find(uidMe, 1, true) ~= nil or tostring(row.OwnerUserId or "") == uidMe
                or tostring(row.UserId or "") == uidMe
            local mut = row.Mutations
            local mutS = typeof(mut) == "table" and ("#" .. tostring(#mut)) or tostring(mut)
            local p = posOf(row)
            list[#list + 1] = {
                mine = mine,
                st = st,
                cat = tostring(row.AssetCategory or "?"),
                scale = tonumber(row.AssetScale) or 0,
                mut = mutS,
                para = tostring(row.HasParasite),
                uid = uid:sub(1, 12),
                nest = tostring(row.NestId or "-"),
                p = p,
            }
        end
    end
    say(string.format("=== SNAPSHOT total=%d ===", total))
    local keys = {}
    for k in pairs(byState) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        say(string.format("  State %-14s = %d", k, byState[k]))
    end
    table.sort(list, function(a, b)
        if a.mine ~= b.mine then return a.mine end
        return a.st < b.st
    end)
    local shown, mineN = 0, 0
    for _, e in ipairs(list) do
        if e.mine then mineN = mineN + 1 end
        if shown < 40 and (e.mine or e.st == "Slot" or e.st == "Dropped" or e.st == "Claimed") then
            shown = shown + 1
            local posS = e.p and string.format("%.0f,%.0f,%.0f", e.p.X, e.p.Y, e.p.Z) or "-"
            say(string.format("%s %-10s %-14s sc=%.2f mut=%s para=%s nest=%s @%s uid=%s…",
                e.mine and "ME" or "  ", e.st, e.cat, e.scale, e.mut, e.para, e.nest, posS, e.uid))
        end
    end
    say(string.format("แสดง %d แถว | ของเรา(เดาจาก UserId ใน UID)=%d", shown, mineN))
end

local function scanAll()
    S.lines = {}
    say("=== Egg Status Spy v1.0 ===")
    say("JobId=" .. tostring(game.JobId):sub(1, 8) .. "… UserId=" .. tostring(LP.UserId))

    say("--- PROMPTS (Egg / Disabled / Mutation / Success) ---")
    local pps = scanPrompts()
    local nShow = math.min(25, #pps)
    for i = 1, nShow do
        local v = pps[i]
        say(string.format("#%d d=%.0f en=%s hold=%.1f act=%q obj=%q",
            i, v.d, tostring(v.en), v.hold or 0, v.act, v.obj))
        if looksStatus(v.obj) or looksStatus(v.act) then
            say("    ★ STATUS " .. tostring(v.obj ~= "" and v.obj or v.act))
        end
        say("    " .. v.path)
    end
    say("prompts=" .. #pps)

    say("--- BILLBOARDS / SURFACE (status text) ---")
    local bbs = scanBillboards(20)
    for i, v in ipairs(bbs) do
        say(string.format("BB#%d d=%.0f | %s", i, v.d, table.concat(v.texts, " | ")))
        say("    " .. v.path)
    end
    if #bbs == 0 then say("(ไม่เจอ Billboard สถานะใกล้ๆ)") end

    say("--- SLOTS / CLIENT ASSETS ---")
    local slots = scanSlots()
    for i = 1, math.min(30, #slots) do say(slots[i]) end
    say("slot-ish nodes=" .. #slots)

    dumpSnapshot()
    say("=== DONE — กด COPY ส่งมาได้ ===")
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
title.Text = "Egg01 Egg Status Spy v1.0 — ฝากไข่ติดสถานะอะไร"
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

local bScan = btn("SCAN", 10, Color3.fromRGB(45, 110, 170))
local bSnap = btn("SNAP", 88, Color3.fromRGB(55, 120, 90))
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
box.Text = "ยืนใกล้ไข่ในคอก → SCAN\nดู Disabled / Success Chance / Mutation / State"

bScan.MouseButton1Click:Connect(scanAll)
bSnap.MouseButton1Click:Connect(function()
    S.lines = {}
    dumpSnapshot()
end)
bClear.MouseButton1Click:Connect(function()
    S.lines = {}
    box.Text = ""
end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Status Spy v1.0 ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bClose.MouseButton1Click:Connect(function()
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    _G.EGG01_EGG_STATUS_SPY = nil
end)

say("พร้อม — SCAN = prompt+billboard+slot+snapshot | SNAP = เฉพาะ snapshot")
