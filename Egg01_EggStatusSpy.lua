-- Egg01 Egg Status Spy v5.2 — ขั้น3b: หาแหล่งชื่อ/$/mut ของ PlacedEgg (ไม่ใช้ nearBB ทั้งแมพ)
-- จาก v5.1: Snapshot ไม่มี UID ไข่คอก | DEEP=FX อย่างเดียว | Hatch/Skip = READY ได้

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
    if #S.lines > 280 then table.remove(S.lines, 1) end
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

local function promptsNearEgg(pos, maxGap)
    local rows, seen = {}, {}
    if not pos then return rows end
    for _, ch in ipairs(workspace:GetChildren()) do
        if ch.Name == "SmartPromptPart" and ch:IsA("BasePart") then
            local gap = (ch.Position - pos).Magnitude
            if gap <= maxGap then
                local pp = ch:FindFirstChildWhichIsA("ProximityPrompt")
                if pp and not seen[pp] then
                    seen[pp] = true
                    rows[#rows + 1] = {
                        gap = gap,
                        en = pp.Enabled,
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

-- Billboard เฉพาะใต้โมเดลไข่ / Adornee ในไข่ — ไม่กวาดทั้งโลก
local function textsOnEgg(model)
    local texts, seen = {}, {}
    if not model then return texts end
    pcall(function()
        for _, d in ipairs(model:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" then
                local t = d.Text:gsub("%s+", " "):match("^%s*(.-)%s*$")
                if t and not seen[t] then seen[t] = true; texts[#texts + 1] = t end
            end
        end
    end)
    return texts
end

local function listNetInteresting()
    local pkg = RS:FindFirstChild("Packages")
    local net = pkg and pkg:FindFirstChild("Networking")
    local hits = {}
    if not net then return hits end
    local keys = { "Place", "Plot", "Stand", "Hatch", "Mutat", "Scrambl", "Egg", "Asset", "Pen", "Farm", "Incub" }
    for _, d in ipairs(net:GetDescendants()) do
        if d:IsA("RemoteFunction") or d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then
            local n = d.Name
            for _, k in ipairs(keys) do
                if n:find(k, 1, true) then
                    hits[#hits + 1] = d.ClassName .. " " .. n
                    break
                end
            end
        end
    end
    table.sort(hits)
    return hits
end

local function tryInvokeNamed(name)
    local pkg = RS:FindFirstChild("Packages")
    local net = pkg and pkg:FindFirstChild("Networking")
    if not net then return nil, "no net" end
    local rf
    for _, d in ipairs(net:GetDescendants()) do
        if d:IsA("RemoteFunction") and (d.Name == name or d.Name:sub(-#name - 1) == "/" .. name or d.Name:find(name, 1, true)) then
            rf = d
            break
        end
    end
    if not rf then return nil, "no RF" end
    local results = {}
    local payloads = { {}, nil, { Uid = "" }, "" }
    for _, pay in ipairs(payloads) do
        local ok, res = pcall(function()
            if pay == nil then return rf:InvokeServer() end
            return rf:InvokeServer(pay)
        end)
        results[#results + 1] = {
            pay = pay == nil and "nil" or (typeof(pay) == "table" and "{}" or tostring(pay)),
            ok = ok,
            typ = typeof(res),
            preview = ok and (typeof(res) == "table" and ("table#" .. (res.Records and "Records" or tostring((function()
                local n = 0
                for _ in pairs(res) do n = n + 1; if n > 3 then break end end
                return n
            end)()))) or tostring(res):sub(1, 80)) or tostring(res):sub(1, 80),
            name = rf.Name,
            res = ok and res or nil,
        }
        if ok and typeof(res) == "table" then break end
    end
    return results, rf.Name
end

local function tableHasUid(t, uid, depth, seen)
    if depth > 4 or typeof(t) ~= "table" or seen[t] then return false end
    seen[t] = true
    for k, v in pairs(t) do
        if typeof(k) == "string" and (k:find(uid, 1, true) or uid:find(k, 1, true)) then return true end
        if typeof(v) == "string" and (v:find(uid, 1, true) or v == uid) then return true end
        if typeof(v) == "table" and tableHasUid(v, uid, depth + 1, seen) then return true end
    end
    return false
end

local function summarizeHit(t, uid)
    local keys, sample = {}, {}
    for k, v in pairs(t) do
        keys[#keys + 1] = tostring(k)
        local ks = tostring(k):lower()
        if ks:find("name", 1, true) or ks:find("cat", 1, true) or ks:find("rar", 1, true)
            or ks:find("mut", 1, true) or ks:find("income", 1, true) or ks:find("money", 1, true)
            or ks:find("scale", 1, true) or ks:find("state", 1, true) or ks == "uid" then
            sample[#sample + 1] = tostring(k) .. "=" .. tostring(v):sub(1, 60)
        end
        if typeof(v) == "table" and (ks:find("mut", 1, true) or ks == "config") then
            sample[#sample + 1] = tostring(k) .. "={table}"
        end
    end
    table.sort(keys)
    return sample, keys
end

local function searchGcForUid(uid)
    local hits = {}
    if not getgc then return hits, "ไม่มี getgc" end
    local n = 0
    pcall(function()
        for _, obj in ipairs(getgc(true)) do
            if typeof(obj) == "table" then
                local seen = {}
                if tableHasUid(obj, uid, 0, seen) then
                    n = n + 1
                    local sample, keys = summarizeHit(obj, uid)
                    hits[#hits + 1] = { sample = sample, keys = keys, obj = obj }
                    if #hits >= 8 then break end
                end
            end
        end
    end)
    return hits, nil, n
end

local function scanProbe()
    S.lines = {}
    say("=== Egg Spy v5.2 — หา data ไข่คอก ===")
    say("UserId=" .. ME)
    say("ข้อสรุป v5.1: Field Snapshot≠ไข่คอก | nearBB=ป้ายสัตว์ปน | DEEP=FX")

    local eggs = listOurEggs()
    say(string.format("--- PlacedEggRenders: %d ---", #eggs))
    for i, e in ipairs(eggs) do
        local pps = e.p and promptsNearEgg(e.p, 12) or {}
        local texts = textsOnEgg(e.model)
        local promptLine = "-"
        for _, pr in ipairs(pps) do
            local al = (pr.act .. pr.obj):lower()
            if al:find("hatch", 1, true) or al:find("growth", 1, true) or al:find("mut", 1, true) then
                promptLine = pr.status .. " " .. pr.act
                break
            end
        end
        if #pps > 0 and promptLine == "-" then
            promptLine = pps[1].status .. " " .. pps[1].act
        end
        say(string.format("#%d d=%.0f uid=%s | onModelTexts=%d | prompt=%s",
            i, e.d, e.uid:sub(1, 12), #texts, promptLine))
        if #texts > 0 then say("    texts: " .. table.concat(texts, " || ")) end
        for j = 1, math.min(3, #pps) do
            local pr = pps[j]
            say(string.format("    PP gap=%.1f %s act=%q obj=%q", pr.gap, pr.status, pr.act, pr.obj))
        end
    end

    say("--- Networking ที่เกี่ยวกับ Place/Plot/Hatch/Mutat/Egg ---")
    local nets = listNetInteresting()
    for i = 1, math.min(40, #nets) do say("  " .. nets[i]) end
    if #nets > 40 then say("  ... +" .. (#nets - 40)) end
    if #nets == 0 then say("  (ไม่เจอ)") end

    -- ลอง RF ที่น่าจะมี inventory/placed
    local tryNames = {
        "AskPlacedEggSnapshot", "AskPlotEggSnapshot", "AskStandEggSnapshot",
        "AskOwnedEggs", "AskPlayerEggs", "AskEggInventory", "AskPlaceEggSnapshot",
        "AskHatchInfo", "AskEggRecord", "AskLiveSnapshot", "AskPlotSnapshot",
        "AskStandSnapshot", "AskFarmSnapshot", "AskAssetSnapshot",
    }
    say("--- ลอง Invoke RF ที่ชื่อน่าจะเกี่ยว ---")
    for _, name in ipairs(tryNames) do
        local results, rfName = tryInvokeNamed(name)
        if results then
            for _, r in ipairs(results) do
                say(string.format("  %s pay=%s ok=%s typ=%s → %s",
                    tostring(rfName or name), r.pay, tostring(r.ok), r.typ, r.preview))
            end
        end
    end

    -- getgc หา uid ไข่ใกล้สุด
    if eggs[1] then
        local uid = eggs[1].uid
        say("--- getgc ค้น uid ไข่ใกล้สุด " .. uid:sub(1, 12) .. " ---")
        local hits, err = searchGcForUid(uid)
        if err then say(err) end
        say("hits=" .. #hits)
        for i, h in ipairs(hits) do
            say(string.format("  GC#%d keys(%d): %s", i, #h.keys, table.concat(h.keys, ","):sub(1, 120)))
            if #h.sample > 0 then say("    sample: " .. table.concat(h.sample, " | ")) end
        end
        if #hits == 0 then say("  (ไม่เจอ table ที่มี uid นี้ใน getgc)") end

        -- ลองค้น full name ด้วย
        say("--- getgc ค้น full " .. eggs[1].full:sub(1, 24) .. "… ---")
        local hits2 = searchGcForUid(eggs[1].full)
        say("hits=" .. #hits2)
        for i, h in ipairs(hits2) do
            say(string.format("  GC#%d keys(%d): %s", i, #h.keys, table.concat(h.keys, ","):sub(1, 120)))
            if #h.sample > 0 then say("    sample: " .. table.concat(h.sample, " | ")) end
        end
    end

    say("=== DONE — ส่งล็อกมา เพื่อชี้แหล่งชื่อ/$/mut ===")
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
title.Text = "Egg01 Spy v5.2 — หา data ไข่คอก"
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

local bProbe = btn("PROBE", 10, Color3.fromRGB(45, 110, 170))
local bClear = btn("CLEAR", 96, Color3.fromRGB(70, 70, 75))
local bCopy = btn("COPY", 182, Color3.fromRGB(70, 70, 75))
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
box.Text = "PROBE = Networking + getgc(uid)\nหาแหล่งชื่อ/$/mut ของไข่คอก"

bProbe.MouseButton1Click:Connect(scanProbe)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Spy v5.2 ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bClose.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_EGG_STATUS_SPY = nil
end)

say("v5.2 — กด PROBE (ไม่กวาด nearBB ทั้งแมพ)")
