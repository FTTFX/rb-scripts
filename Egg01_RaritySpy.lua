-- Egg01_RaritySpy.lua v1.1
-- หาแหล่ง "Legendary" / rarity ของไข่หรือสัตว์
-- วิธี: ยืนใกล้ไข่หรือสัตว์ที่มีป้าย Legendary → SCAN / DUMP → COPY

if _G.EGG01_RAR then
    pcall(function() _G.EGG01_RAR.gui:Destroy() end)
    if _G.EGG01_RAR.conns then
        for _, c in ipairs(_G.EGG01_RAR.conns) do pcall(function() c:Disconnect() end) end
    end
end
_G.EGG01_RAR = { conns = {} }

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local RARITY_WORDS = {
    "common", "uncommon", "rare", "epic", "legendary", "mythic",
    "cosmic", "secret", "eternal", "divine", "leg",
}

local lines = {}
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_RaritySpy"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
pcall(function()
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01_RAR.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 300, 0, 100)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -40, 0, 20)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 Rarity Spy v1.1"

local function mkBtn(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bClose = mkBtn("X", 264, 4, 28, Color3.fromRGB(120, 45, 45))
local bScan  = mkBtn("SCAN", 10, 36, 70, Color3.fromRGB(50, 100, 180))
local bRF    = mkBtn("RF", 86, 36, 70, Color3.fromRGB(100, 70, 140))
local bCopy  = mkBtn("COPY", 162, 36, 70, Color3.fromRGB(70, 70, 70))

local lab = Instance.new("TextLabel", panel)
lab.Size = UDim2.new(1, -20, 0, 24)
lab.Position = UDim2.new(0, 10, 0, 70)
lab.BackgroundTransparency = 1
lab.TextColor3 = Color3.fromRGB(255, 220, 100)
lab.Font = Enum.Font.GothamBold
lab.TextSize = 11
lab.TextXAlignment = Enum.TextXAlignment.Left
lab.Text = "ยืนใกล้ไข่/สัตว์ที่มีป้าย Legendary → SCAN"

local log = Instance.new("TextBox", gui)
log.Size = UDim2.new(0, 300, 0, 200)
log.Position = UDim2.new(0, 12, 0, 120)
log.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
log.BackgroundTransparency = 0.3
log.TextColor3 = Color3.fromRGB(180, 240, 180)
log.Font = Enum.Font.Code
log.TextSize = 11
log.TextXAlignment = Enum.TextXAlignment.Left
log.TextYAlignment = Enum.TextYAlignment.Top
log.ClearTextOnFocus = false
log.TextEditable = false
log.MultiLine = true
log.TextWrapped = true
log.Text = ""
Instance.new("UICorner", log).CornerRadius = UDim.new(0, 6)

local function say(msg)
    lines[#lines + 1] = msg
    if #lines > 120 then table.remove(lines, 1) end
    log.Text = table.concat(lines, "\n")
    lab.Text = msg
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isRarityText(s)
    if not s or s == "" then return false end
    local low = tostring(s):lower()
    for _, w in ipairs(RARITY_WORDS) do
        if low == w or low:find(w, 1, true) then return true end
    end
    return false
end

local function short(inst)
    local parts = {}
    local p = inst
    for _ = 1, 6 do
        if not p or p == game then break end
        table.insert(parts, 1, p.Name)
        p = p.Parent
    end
    return table.concat(parts, ".")
end

local function dumpAttrs(inst, prefix)
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if not ok or not attrs then return end
    for k, v in pairs(attrs) do
        local ks, vs = tostring(k), tostring(v)
        local hit = isRarityText(ks) or isRarityText(vs)
            or ks:lower():find("rar") or ks:lower():find("tier")
            or ks:lower():find("quality") or ks:lower():find("income")
        if hit then
            say(string.format("%s attr %s=%s @ %s", prefix, ks, vs, short(inst)))
        end
    end
end

local function findNet(namePart)
    local pkg = RS:FindFirstChild("Packages")
    local net = pkg and pkg:FindFirstChild("Networking")
    if not net then return nil end
    for _, d in ipairs(net:GetDescendants()) do
        if d.Name:find(namePart, 1, true) then return d end
    end
    return nil
end

local function shallowDump(t, prefix, depth)
    depth = depth or 0
    if depth > 2 or typeof(t) ~= "table" then return end
    local n = 0
    for k, v in pairs(t) do
        n = n + 1
        if n > 40 then say(prefix .. " …"); break end
        local ks = tostring(k)
        local tv = typeof(v)
        local hit = isRarityText(ks) or isRarityText(tostring(v))
            or ks:lower():find("rar") or ks:lower():find("tier")
            or ks:lower():find("quality") or ks:lower():find("income")
            or ks:lower():find("scale") or ks:lower():find("category")
        if hit or depth == 0 then
            if tv == "table" then
                say(string.format("%s %s = {table}", prefix, ks))
                if hit or depth < 1 then shallowDump(v, prefix .. "  ", depth + 1) end
            else
                local s = tostring(v)
                if #s > 60 then s = s:sub(1, 57) .. "..." end
                say(string.format("%s %s = %s", prefix, ks, s))
            end
        end
    end
end

bScan.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then say("ไม่มีตัวละคร"); return end
    say("── SCAN rarity รอบตัว 80 studs ──")
    local hits = 0

    -- Billboard / TextLabel ใน workspace
    for _, d in ipairs(workspace:GetDescendants()) do
        local txt
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            txt = d.Text
        elseif d:IsA("StringValue") then
            txt = d.Value
        end
        if txt and isRarityText(txt) then
            local part = d:FindFirstAncestorWhichIsA("BasePart")
                or d:FindFirstAncestorWhichIsA("Model")
            local pos
            if part and part:IsA("BasePart") then pos = part.Position
            elseif part and part:IsA("Model") then
                local pp = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart", true)
                pos = pp and pp.Position
            end
            local dist = pos and (pos - r.Position).Magnitude or 9999
            if dist <= 80 then
                hits = hits + 1
                if hits <= 25 then
                    say(string.format("UI d=%.0f '%s' @ %s", dist, tostring(txt):sub(1, 40), short(d)))
                end
            end
        end
        if d:IsA("BillboardGui") or d:IsA("Model") or d:IsA("BasePart") then
            local pos
            if d:IsA("BasePart") then pos = d.Position
            elseif d:IsA("Model") then
                local pp = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)
                pos = pp and pp.Position
            elseif d:IsA("BillboardGui") then
                local ad = d.Adornee or d.Parent
                if ad and ad:IsA("BasePart") then pos = ad.Position end
            end
            if pos and (pos - r.Position).Magnitude <= 40 then
                dumpAttrs(d, "  ")
            end
        end
    end

    -- PlayerGui
    for _, d in ipairs(PG:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
            if isRarityText(d.Text) then
                hits = hits + 1
                if hits <= 35 then
                    say(string.format("PG '%s' @ %s", tostring(d.Text):sub(1, 40), short(d)))
                end
            end
        end
    end

    say(string.format("── จบ SCAN hits≈%d ──", hits))
end)

bRF.MouseButton1Click:Connect(function()
    say("── ลอง RF rarity / snapshot ──")

    -- ตัวเดาหลักจาก log
    local rfShow = findNet("AskFieldEggRarityShows")
    if rfShow and rfShow:IsA("RemoteFunction") then
        local ok, res = pcall(function() return rfShow:InvokeServer() end)
        say(string.format("RF AskFieldEggRarityShows() → %s %s", tostring(ok), typeof(res)))
        if ok and typeof(res) == "table" then
            local n = 0
            for k, v in pairs(res) do
                n = n + 1
                if n <= 25 then
                    if typeof(v) == "table" then
                        say(string.format("  [%s] = {table}", tostring(k)))
                        shallowDump(v, "    ", 0)
                    else
                        say(string.format("  [%s] = %s", tostring(k), tostring(v)))
                    end
                end
            end
            -- ถ้าเป็น array ของ record
            if res[1] then
                say("  -- row[1] keys --")
                shallowDump(res[1], "  ", 0)
                for i, row in ipairs(res) do
                    if i > 12 then break end
                    if typeof(row) == "table" then
                        say(string.format("  #%d cat=%s rar=%s scale=%s area=%s uid=%s",
                            i,
                            tostring(row.AssetCategory or row.Category or row.Name or "?"),
                            tostring(row.Rarity or row.Tier or row.Quality or row.RarityId or "?"),
                            tostring(row.AssetScale or row.Scale or "?"),
                            tostring(row.AreaId or "?"),
                            tostring(row.Uid or "?"):sub(1, 10)))
                    end
                end
            end
        elseif not ok then
            say("  err: " .. tostring(res))
        end
    else
        say("⚠ ไม่เจอ AskFieldEggRarityShows")
    end

    local snap = findNet("AskFieldEggSnapshot")
    if snap and snap:IsA("RemoteFunction") then
        local ok, res = pcall(function() return snap:InvokeServer() end)
        say(string.format("RF AskFieldEggSnapshot → %s %s", tostring(ok), typeof(res)))
        if ok and typeof(res) == "table" then
            local rec = res.Records or res.records or res
            local i = 0
            if typeof(rec) == "table" then
                for uid, row in pairs(rec) do
                    if typeof(row) == "table" then
                        i = i + 1
                        if i <= 15 then
                            local keys = {}
                            for k in pairs(row) do keys[#keys + 1] = tostring(k) end
                            table.sort(keys)
                            say(string.format("  Rec %s keys=%s", tostring(uid):sub(1, 10), table.concat(keys, ",")))
                            say(string.format("    cat=%s rar=%s scale=%s state=%s",
                                tostring(row.AssetCategory or "?"),
                                tostring(row.Rarity or row.Tier or row.Quality or row.RarityId or "?"),
                                tostring(row.AssetScale or "?"),
                                tostring(row.State or "?")))
                        end
                    end
                end
                say("  Records count≈" .. i)
            end
        end
    end

    for _, name in ipairs({ "AskEggRecord", "AskLiveSnapshot" }) do
        local rf = findNet(name)
        if rf and rf:IsA("RemoteFunction") then
            local ok, res = pcall(function() return rf:InvokeServer() end)
            say(string.format("RF %s → %s %s", name, tostring(ok), ok and typeof(res) or tostring(res)))
            if ok and typeof(res) == "table" and res[1] then
                local keys = {}
                for k in pairs(res[1]) do keys[#keys + 1] = tostring(k) end
                table.sort(keys)
                say("  [1] keys=" .. table.concat(keys, ","))
                shallowDump(res[1], "  ", 0)
            end
        end
    end
end)

-- ฟัง RE FieldEggRaritiesShown
do
    local re = findNet("FieldEggRaritiesShown")
    if re and re:IsA("RemoteEvent") then
        table.insert(_G.EGG01_RAR.conns, re.OnClientEvent:Connect(function(...)
            local args = { ... }
            say("← FieldEggRaritiesShown args=" .. #args)
            for i, a in ipairs(args) do
                if typeof(a) == "table" then
                    say(string.format("  arg%d = table", i))
                    shallowDump(a, "    ", 0)
                    if a[1] then
                        for j, row in ipairs(a) do
                            if j > 10 then break end
                            if typeof(row) == "table" then
                                say(string.format("    #%d %s", j, tostring(row.Rarity or row.AssetCategory or row.Uid or "?")))
                                shallowDump(row, "      ", 0)
                            end
                        end
                    end
                else
                    say(string.format("  arg%d = %s", i, tostring(a):sub(1, 80)))
                end
            end
        end))
        say("ฟัง FieldEggRaritiesShown ✅")
    else
        say("⚠ ไม่เจอ FieldEggRaritiesShown")
    end
end

bCopy.MouseButton1Click:Connect(function()
    local t = "=== Egg01 Rarity Spy ===\n" .. table.concat(lines, "\n")
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, t) end
    bCopy.Text = "OK"
    task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)

bClose.MouseButton1Click:Connect(function()
    for _, c in ipairs(_G.EGG01_RAR.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    _G.EGG01_RAR = nil
end)

say("Rarity Spy v1.1 — เจอ AskFieldEggRarityShows / FieldEggRaritiesShown")
say("กด RF ดัมพ์ rarity | เดินใกล้ไข่ดู RE")
