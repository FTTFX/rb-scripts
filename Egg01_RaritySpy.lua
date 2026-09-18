-- Egg01_RaritySpy.lua v1.4
-- Focused config/GC search for the missing AssetCategory -> rarity relationship.
-- ClientRenderedAssets Odds are NOT trusted because player pets/monsters are mixed in.

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
title.Text = "Egg01 Category Rarity Spy v1.4"

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
local bScan  = mkBtn("CONFIG", 10, 36, 54, Color3.fromRGB(50, 100, 180))
local bOdds  = mkBtn("SHOW", 70, 36, 54, Color3.fromRGB(160, 100, 40))
local bRF    = mkBtn("RF", 130, 36, 54, Color3.fromRGB(100, 70, 140))
local bCopy  = mkBtn("COPY", 190, 36, 54, Color3.fromRGB(70, 70, 70))

local lab = Instance.new("TextLabel", panel)
lab.Size = UDim2.new(1, -20, 0, 24)
lab.Position = UDim2.new(0, 10, 0, 70)
lab.BackgroundTransparency = 1
lab.TextColor3 = Color3.fromRGB(255, 220, 100)
lab.Font = Enum.Font.GothamBold
lab.TextSize = 11
lab.TextXAlignment = Enum.TextXAlignment.Left
lab.Text = "กด CONFIG → รอจบ → COPY"

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
    if #lines > 700 then table.remove(lines, 1) end
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

local function deepDump(value, prefix, depth, seen)
    prefix, depth, seen = prefix or "", depth or 0, seen or {}
    if depth > 5 then say(prefix .. "<max-depth>"); return end
    if typeof(value) ~= "table" then
        local s = tostring(value)
        if #s > 180 then s = s:sub(1, 177) .. "..." end
        say(prefix .. s)
        return
    end
    if seen[value] then say(prefix .. "<cycle>"); return end
    seen[value] = true
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    say(string.format("%s{table keys=%d}", prefix, #keys))
    for i, k in ipairs(keys) do
        if i > 180 then say(prefix .. "  ..."); break end
        local v = value[k]
        local head = prefix .. "  [" .. tostring(k) .. "]="
        if typeof(v) == "table" then
            say(head .. "{table}")
            deepDump(v, prefix .. "    ", depth + 1, seen)
        else
            local s = tostring(v)
            if #s > 180 then s = s:sub(1, 177) .. "..." end
            say(head .. s .. " <" .. typeof(v) .. ">")
        end
    end
end

local function exactRarity(value)
    if typeof(value) ~= "string" then return nil end
    local low = value:lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, word in ipairs(RARITY_WORDS) do
        if low == word and word ~= "leg" then
            return word:sub(1, 1):upper() .. word:sub(2)
        end
    end
    return nil
end

local function findRarityInTable(value, depth, seen)
    if typeof(value) ~= "table" or depth > 3 or seen[value] then return nil end
    seen[value] = true
    for k, v in pairs(value) do
        local key = tostring(k):lower()
        if key:find("rar", 1, true) or key:find("tier", 1, true) or key:find("quality", 1, true) then
            local rarity = exactRarity(v)
            if rarity then return tostring(k) .. "=" .. rarity end
        end
    end
    for k, v in pairs(value) do
        local rarity = exactRarity(v)
        if rarity then return tostring(k) .. "=" .. rarity end
        if typeof(v) == "table" then
            local nested = findRarityInTable(v, depth + 1, seen)
            if nested then return tostring(k) .. "." .. nested end
        end
    end
    return nil
end

local function collectFieldCategories()
    local out, names = {}, {}
    local snap = findNet("AskFieldEggSnapshot")
    if not snap or not snap:IsA("RemoteFunction") then return out, names, "ไม่เจอ AskFieldEggSnapshot" end
    local ok, res = pcall(function() return snap:InvokeServer() end)
    if not ok or typeof(res) ~= "table" then return out, names, tostring(res) end
    local records = res.Records or res.records or res
    if typeof(records) ~= "table" then return out, names, "snapshot ไม่มี Records" end
    for _, row in pairs(records) do
        if typeof(row) == "table" and row.AssetCategory then
            local cat = tostring(row.AssetCategory)
            if not out[cat] then out[cat] = true; names[#names + 1] = cat end
        end
    end
    table.sort(names)
    return out, names
end

local function scanConfigTables()
    say("── CONFIG: หา AssetCategory → rarity โดยตรง ──")
    local categories, names, err = collectFieldCategories()
    if err then say("snapshot error: " .. err); return end
    say(string.format("field categories=%d เช่น %s", #names, table.concat(names, ", ", 1, math.min(8, #names))))

    local hits, scanned, emitted = 0, 0, {}
    local gc = getgc
    if type(gc) == "function" then
        local ok, objects = pcall(gc, true)
        if ok and typeof(objects) == "table" then
            for _, obj in ipairs(objects) do
                if typeof(obj) == "table" then
                    scanned = scanned + 1
                    for _, cat in ipairs(names) do
                        local okGet, row = pcall(rawget, obj, cat)
                        if okGet and row ~= nil then
                            local rarity = exactRarity(row)
                            if not rarity and typeof(row) == "table" then
                                rarity = findRarityInTable(row, 0, {})
                            end
                            local key = cat .. "|" .. tostring(rarity)
                            if rarity and not emitted[key] then
                                emitted[key], hits = true, hits + 1
                                say(string.format("GC HIT cat=%s %s", cat, rarity))
                            end
                        end
                    end
                    local okCat, cat = pcall(function()
                        return rawget(obj, "AssetCategory") or rawget(obj, "Category")
                    end)
                    if okCat and cat and categories[tostring(cat)] then
                        local rarity = findRarityInTable(obj, 0, {})
                        local key = tostring(cat) .. "|record|" .. tostring(rarity)
                        if rarity and not emitted[key] then
                            emitted[key], hits = true, hits + 1
                            say(string.format("GC RECORD cat=%s %s", tostring(cat), rarity))
                        end
                    end
                end
                if hits >= 60 then break end
            end
            say(string.format("getgc tables=%d direct hits=%d", scanned, hits))
        else
            say("getgc error: " .. tostring(objects))
        end
    else
        say("executor ไม่มี getgc")
    end

    local glm = getloadedmodules
    if type(glm) == "function" then
        local ok, modules = pcall(glm)
        local moduleHits = 0
        if ok and typeof(modules) == "table" then
            for _, module in ipairs(modules) do
                local low = module.Name:lower()
                if low:find("egg", 1, true) or low:find("asset", 1, true)
                    or low:find("rar", 1, true) or low:find("animal", 1, true)
                    or low:find("pet", 1, true) or low:find("config", 1, true) then
                    moduleHits = moduleHits + 1
                    if moduleHits <= 35 then say("MODULE " .. short(module)) end
                end
            end
        end
        say("candidate loaded modules=" .. moduleHits)
    else
        say("executor ไม่มี getloadedmodules")
    end
    say("── CONFIG จบ: กด COPY แล้วส่ง log นี้ ──")
end

bScan.MouseButton1Click:Connect(function()
    task.spawn(scanConfigTables)
end)

-- Trigger the server response while FieldEggRaritiesShown listener is active.
bOdds.MouseButton1Click:Connect(function()
    local rfShow = findNet("AskFieldEggRarityShows")
    if not rfShow or not rfShow:IsA("RemoteFunction") then
        say("⚠ ไม่เจอ AskFieldEggRarityShows")
        return
    end
    say("── Invoke AskFieldEggRarityShows ──")
    local ok, res = pcall(function() return rfShow:InvokeServer() end)
    say(string.format("return ok=%s type=%s", tostring(ok), ok and typeof(res) or "error"))
    if ok and typeof(res) == "table" then
        deepDump(res, "  RETURN ", 0, {})
    else
        say("  return=" .. tostring(res))
    end
    say("รอ RE FieldEggRaritiesShown 2 วิ แล้วกด COPY")
    task.wait(2)
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
                    deepDump(a, "    ", 0, {})
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
    local t = "=== Egg01 Category Rarity Spy v1.4 ===\n" .. table.concat(lines, "\n")
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

say("Category Rarity Spy v1.4 — ไม่จับ rarity จากระยะ")
say("กด CONFIG → รอคำว่า CONFIG จบ → COPY ส่ง log")
