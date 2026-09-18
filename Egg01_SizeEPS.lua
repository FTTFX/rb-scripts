-- Egg01_SizeEPS.lua v1.7
-- EPS แยกขนาด + เส้นนำสายตาไป ★ ใกล้สุด
-- SCAN | GUIDE | START (ยิงเมื่อใกล้ ≤16)

if _G.EGG01_SIZE then
    pcall(function() _G.EGG01_SIZE.gui:Destroy() end)
    if _G.EGG01_SIZE.clearGuide then pcall(_G.EGG01_SIZE.clearGuide) end
    if _G.EGG01_SIZE.conns then
        for _, c in ipairs(_G.EGG01_SIZE.conns) do pcall(function() c:Disconnect() end) end
    end
end
_G.EGG01_SIZE = { conns = {} }

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local STEAL_RANGE = 16
local RUN = false
local GUIDE = false
local lines = {}
local eggDB = {} -- [uid] = { scale, cat, area, pos, state, nest, mutN, ver, rar }
local carrying = false
local carryUid = nil
local oddsByUid = {}

local RARITY_RANK = {
    common = 1, uncommon = 2, rare = 3, epic = 4,
    legendary = 5, mythic = 6, cosmic = 7, secret = 8,
    eternal = 9, divine = 10,
}

local RARITY_ORDER = {
    "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine",
}

local CFG = {
    minScale = 1.0,
    onlySlot = true,
    guideMax = false,
    rarOn = {
        Epic = false,
        Legendary = true,
        Mythic = true,
        Cosmic = true,
        Secret = true,
        Eternal = true,
        Divine = true,
    },
}

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_SizeEPS"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
pcall(function()
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01_SIZE.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 320, 0, 178)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -40, 0, 20)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(230, 230, 230)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 Size EPS v1.8"

local function mkBtn(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 26)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = text
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bClose  = mkBtn("X", 264, 4, 28, Color3.fromRGB(120, 45, 45))
local bScan   = mkBtn("SCAN", 10, 32, 48, Color3.fromRGB(50, 100, 180))
local bMode   = mkBtn("NEAR", 62, 32, 48, Color3.fromRGB(60, 90, 120))
local bGuide  = mkBtn("GUIDE", 114, 32, 48, Color3.fromRGB(90, 90, 90))
local bStart  = mkBtn("START", 166, 32, 48, Color3.fromRGB(40, 150, 70))
local bStop   = mkBtn("STOP", 218, 32, 40, Color3.fromRGB(160, 50, 50))
local bCopy   = mkBtn("COPY", 262, 32, 30, Color3.fromRGB(70, 70, 70))

local function mkField(label, x, y, w, def)
    local lb = Instance.new("TextLabel", panel)
    lb.Size = UDim2.new(0, 70, 0, 14)
    lb.Position = UDim2.new(0, x, 0, y)
    lb.BackgroundTransparency = 1
    lb.TextColor3 = Color3.fromRGB(170, 170, 170)
    lb.Font = Enum.Font.Gotham
    lb.TextSize = 10
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.Text = label
    local tb = Instance.new("TextBox", panel)
    tb.Size = UDim2.new(0, w, 0, 22)
    tb.Position = UDim2.new(0, x, 0, y + 14)
    tb.BackgroundColor3 = Color3.fromRGB(40, 42, 48)
    tb.TextColor3 = Color3.new(1, 1, 1)
    tb.Font = Enum.Font.GothamBold
    tb.TextSize = 11
    tb.Text = tostring(def)
    tb.ClearTextOnFocus = false
    tb.BorderSizePixel = 0
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
    return tb
end

local tMin = mkField("MinScale", 10, 62, 50, CFG.minScale)

local rarLb = Instance.new("TextLabel", panel)
rarLb.Size = UDim2.new(0, 60, 0, 14)
rarLb.Position = UDim2.new(0, 70, 0, 62)
rarLb.BackgroundTransparency = 1
rarLb.TextColor3 = Color3.fromRGB(170, 170, 170)
rarLb.Font = Enum.Font.Gotham
rarLb.TextSize = 10
rarLb.TextXAlignment = Enum.TextXAlignment.Left
rarLb.Text = "Rarity"

local rarBtns = {}
local RAR_COLORS = {
    Epic = Color3.fromRGB(140, 60, 180),
    Legendary = Color3.fromRGB(180, 140, 40),
    Mythic = Color3.fromRGB(180, 50, 50),
    Cosmic = Color3.fromRGB(40, 100, 180),
    Secret = Color3.fromRGB(120, 40, 140),
    Eternal = Color3.fromRGB(40, 140, 140),
    Divine = Color3.fromRGB(200, 200, 220),
}
local RAR_SHORT = {
    Epic = "Epc", Legendary = "Leg", Mythic = "Myt",
    Cosmic = "Cos", Secret = "Sec", Eternal = "Ete", Divine = "Div",
}

local function paintRar()
    for name, b in pairs(rarBtns) do
        local on = CFG.rarOn[name]
        b.BackgroundColor3 = on and (RAR_COLORS[name] or Color3.fromRGB(60, 140, 80))
            or Color3.fromRGB(50, 52, 58)
        b.TextTransparency = on and 0 or 0.35
        b.Text = (on and "✓" or "·") .. RAR_SHORT[name]
    end
end

do
    local x, y = 70, 76
    for i, name in ipairs(RARITY_ORDER) do
        local b = Instance.new("TextButton", panel)
        b.Size = UDim2.new(0, 34, 0, 22)
        b.Position = UDim2.new(0, x, 0, y)
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        rarBtns[name] = b
        b.MouseButton1Click:Connect(function()
            CFG.rarOn[name] = not CFG.rarOn[name]
            paintRar()
            local on = {}
            for _, n in ipairs(RARITY_ORDER) do
                if CFG.rarOn[n] then on[#on + 1] = RAR_SHORT[n] end
            end
            if #on == 0 then
                say("Rarity: ปิดหมด — ไม่ชี้เป้า (ติ๊กอย่างน้อย 1)")
            else
                say("Rarity: " .. table.concat(on, ","))
            end
            if GUIDE then updateGuide() end
        end)
        x = x + 36
        if i == 4 then
            x, y = 70, 100
        end
    end
    paintRar()
end

local lab = Instance.new("TextLabel", panel)
lab.Size = UDim2.new(1, -20, 0, 28)
lab.Position = UDim2.new(0, 10, 0, 128)
lab.BackgroundTransparency = 1
lab.TextColor3 = Color3.fromRGB(255, 220, 100)
lab.Font = Enum.Font.GothamBold
lab.TextSize = 11
lab.TextXAlignment = Enum.TextXAlignment.Left
lab.TextYAlignment = Enum.TextYAlignment.Top
lab.TextWrapped = true
lab.Text = "ฟัง Shifted → SCAN / START (ขโมยเฉพาะไข่ใหญ่)"

local log = Instance.new("TextBox", gui)
log.Size = UDim2.new(0, 320, 0, 170)
log.Position = UDim2.new(0, 12, 0, 198)
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
    if #lines > 90 then table.remove(lines, 1) end
    log.Text = table.concat(lines, "\n")
    lab.Text = msg
end

local function rarRank(s)
    if not s or s == "" or s == "-" then return 0 end
    return RARITY_RANK[tostring(s):lower()] or 0
end

local function normUid(u)
    return tostring(u or ""):lower():gsub("%-", "")
end

local function anyRarOn()
    for _, n in ipairs(RARITY_ORDER) do
        if CFG.rarOn[n] then return true end
    end
    return false
end

local function rarAllowed(rar)
    -- ปิดติ๊กหมด = ไม่รับอะไรเลย (ต้องติ๊กอย่างน้อย 1)
    if not anyRarOn() then return false end
    if not rar or rar == "" then return false end
    local key
    for _, n in ipairs(RARITY_ORDER) do
        if n:lower() == tostring(rar):lower() then key = n break end
    end
    if key then return CFG.rarOn[key] == true end
    return false
end

local function readCfg()
    local n = tonumber(tMin.Text)
    if n and n >= 0 then CFG.minScale = n end
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
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

local function mutCount(m)
    if typeof(m) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(m) do n = n + 1 end
    return n
end

local function posFromTbl(t)
    if typeof(t.BottomCFrame) == "CFrame" then return t.BottomCFrame.Position end
    if typeof(t.BoundsCFrame) == "CFrame" then return t.BoundsCFrame.Position end
    return nil
end

local function upsertEgg(t)
    if typeof(t) ~= "table" or not t.Uid then return end
    local uid = t.Uid
    local e = eggDB[uid] or {}
    if t.AssetScale ~= nil then e.scale = tonumber(t.AssetScale) or e.scale end
    if t.NestScale ~= nil then e.nestScale = tonumber(t.NestScale) or e.nestScale end
    if t.AssetCategory then e.cat = t.AssetCategory end
    if t.AreaId then e.area = t.AreaId end
    if t.State then e.state = t.State end
    if t.NestId then e.nest = t.NestId end
    if t.Version then e.ver = t.Version end
    e.mutN = mutCount(t.Mutations)
    local p = posFromTbl(t)
    if p then e.pos = p end
    local o = oddsByUid[normUid(uid)]
    if o then e.rar = o end
    e.t = os.clock()
    eggDB[uid] = e
end

local function syncOdds()
    local rf = findNet("AskFieldEggRarityShows")
    if rf and rf:IsA("RemoteFunction") then
        pcall(function() rf:InvokeServer() end)
        task.wait(0.7)
    end
    local folder = workspace:FindFirstChild("ClientRenderedAssets")
    if not folder then return 0, 0 end

    local function cleanRar(s)
        if not s then return nil end
        s = tostring(s):gsub("<.->", ""):gsub("%s+", "")
        -- เหลือคำแรกที่เป็นตัวอักษร
        local w = s:match("([A-Za-z]+)")
        return w
    end

    local function oddsWorldPos(oddsInst)
        if not oddsInst then return nil end
        local bb = oddsInst:FindFirstAncestorWhichIsA("BillboardGui")
            or (oddsInst:IsA("BillboardGui") and oddsInst)
        if bb then
            if bb.Adornee and bb.Adornee:IsA("BasePart") then
                return bb.Adornee.Position
            end
            if bb.Parent and bb.Parent:IsA("BasePart") then
                return bb.Parent.Position
            end
        end
        local part = oddsInst:FindFirstAncestorWhichIsA("BasePart")
        if part then return part.Position end
        local model = oddsInst:FindFirstAncestorWhichIsA("Model")
        if model then
            local ok, cf = pcall(function() return model:GetBoundingBox() end)
            if ok and cf then return cf.Position end
            local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            if pp then return pp.Position end
        end
        return nil
    end

    local n, matched, withPos = 0, 0, 0
    oddsByUid = {}
    local oddsPos = {}
    for _, asset in ipairs(folder:GetChildren()) do
        local uidPart = asset.Name:match("_(%x+)$")
        local data = asset:FindFirstChild("Data")
        local odds = data and (data:FindFirstChild("Odds") or data:FindFirstChild("Odds", true))
        if not odds then
            odds = asset:FindFirstChild("Odds", true)
        end
        local raw
        if odds then
            if odds:IsA("TextLabel") or odds:IsA("TextButton") or odds:IsA("TextBox") then
                raw = odds.Text
            else
                local tl = odds:FindFirstChildWhichIsA("TextLabel", true)
                    or odds:FindFirstChildWhichIsA("TextButton", true)
                raw = tl and tl.Text
            end
        end
        local rar = cleanRar(raw)
        if rar and rarRank(rar) > 0 then
            n = n + 1
            if uidPart then
                oddsByUid[uidPart:lower()] = rar
            end
            local pos = oddsWorldPos(odds) or oddsWorldPos(data) or oddsWorldPos(asset)
            if not pos then
                local part = asset:FindFirstChildWhichIsA("BasePart", true)
                pos = part and part.Position
            end
            if pos then
                withPos = withPos + 1
                oddsPos[#oddsPos + 1] = { rar = rar, pos = pos, uid = uidPart and uidPart:lower() }
            end
        end
    end

    -- uid ตรง / บางส่วน
    for uid, e in pairs(eggDB) do
        local nu = normUid(uid)
        local o = oddsByUid[nu]
        if not o and #nu >= 8 then
            for ou, rar in pairs(oddsByUid) do
                if ou:sub(1, 8) == nu:sub(1, 8) then
                    o = rar
                    break
                end
            end
        end
        if o then
            e.rar = o
            matched = matched + 1
        end
    end

    -- จับคู่ระยะ (กว้างขึ้น)
    for uid, e in pairs(eggDB) do
        if (not e.rar or e.rar == "") and e.pos then
            local best, bestD
            for _, op in ipairs(oddsPos) do
                local d = (op.pos - e.pos).Magnitude
                if d <= 90 and (not bestD or d < bestD) then
                    best, bestD = op, d
                end
            end
            if best then
                e.rar = best.rar
                matched = matched + 1
            end
        end
    end

    -- จับคู่กับ Steal prompt → ไข่ใกล้ prompt
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local a = tostring(d.ActionText):lower()
            if a:find("steal") then
                local part = d.Parent
                if part and not part:IsA("BasePart") then
                    part = part:FindFirstChildWhichIsA("BasePart", true)
                end
                if part then
                    local bestOp, bestOd
                    for _, op in ipairs(oddsPos) do
                        local dd = (op.pos - part.Position).Magnitude
                        if dd <= 25 and (not bestOd or dd < bestOd) then
                            bestOp, bestOd = op, dd
                        end
                    end
                    if bestOp then
                        local bestEgg, bestEd
                        for _, e in pairs(eggDB) do
                            if e.pos then
                                local ed = (e.pos - part.Position).Magnitude
                                if ed <= 30 and (not bestEd or ed < bestEd) then
                                    bestEgg, bestEd = e, ed
                                end
                            end
                        end
                        if bestEgg and (not bestEgg.rar or bestEgg.rar == "") then
                            bestEgg.rar = bestOp.rar
                            matched = matched + 1
                        end
                    end
                end
            end
        end
    end

    say(string.format("Odds debug: total=%d มีพิกัด=%d จับคู่=%d", n, withPos, matched))
    return n, matched
end

local function ingestSnapshot(res)
    if typeof(res) ~= "table" then return 0 end
    local n = 0
    local rec = res.Records or res.records
    if typeof(rec) == "table" then
        for k, row in pairs(rec) do
            if typeof(row) == "table" then
                if not row.Uid and typeof(k) == "string" then
                    row.Uid = k
                end
                if row.Uid then
                    upsertEgg(row)
                    n = n + 1
                end
            end
        end
        return n
    end
    if res[1] then
        for _, row in ipairs(res) do
            if typeof(row) == "table" and row.Uid then
                upsertEgg(row)
                n = n + 1
            elseif typeof(row) == "table" and row.Records then
                n = n + ingestSnapshot(row)
            end
        end
        return n
    end
    if res.Uid then
        upsertEgg(res)
        return 1
    end
    for _, row in pairs(res) do
        if typeof(row) == "table" and row.Uid then
            upsertEgg(row)
            n = n + 1
        end
    end
    return n
end

local function passesFilter(e)
    if not e or e.state == "Carried" or not e.pos then return false end
    if CFG.minScale > 0 and (not e.scale or e.scale < CFG.minScale) then return false end
    if not rarAllowed(e.rar) then return false end
    return true
end

local function nearestBig(maxScan)
    readCfg()
    local r = hrp()
    if not r then return nil end
    local best, bestD, bestUid
    for uid, e in pairs(eggDB) do
        if passesFilter(e) then
            local d = (e.pos - r.Position).Magnitude
            if (not maxScan or d <= maxScan) and (not bestD or d < bestD) then
                best, bestD, bestUid = e, d, uid
            end
        end
    end
    return best, bestD, bestUid
end

local function biggestEgg()
    readCfg()
    local r = hrp()
    local best, bestD, bestUid
    for uid, e in pairs(eggDB) do
        if passesFilter(e) then
            if not best or (e.scale or 0) > (best.scale or 0) then
                local d = r and (e.pos - r.Position).Magnitude or -1
                best, bestD, bestUid = e, d, uid
            end
        end
    end
    return best, bestD, bestUid
end

-- เป้า GUIDE ตามโหมด — ไม่ fallback ข้าม rarity
local function guideTarget()
    if not anyRarOn() then return nil end
    if CFG.guideMax then
        return biggestEgg()
    end
    return nearestBig()
end

local function paintMode()
    if CFG.guideMax then
        bMode.Text = "MAX"
        bMode.BackgroundColor3 = Color3.fromRGB(160, 90, 40)
    else
        bMode.Text = "NEAR"
        bMode.BackgroundColor3 = Color3.fromRGB(60, 90, 120)
    end
end

local function topBig(n)
    readCfg()
    local arr = {}
    for uid, e in pairs(eggDB) do
        if e.scale or e.rar then
            arr[#arr + 1] = { uid = uid, e = e }
        end
    end
    table.sort(arr, function(a, b)
        local ra, rb = rarRank(a.e.rar), rarRank(b.e.rar)
        if ra ~= rb then return ra > rb end
        return (a.e.scale or 0) > (b.e.scale or 0)
    end)
    local out = {}
    for i = 1, math.min(n or 8, #arr) do out[i] = arr[i] end
    return out
end

-- ===== เส้นนำสายตา (Beam + ป้ายที่เป้า) =====
local guideFolder = Instance.new("Folder")
guideFolder.Name = "Egg01_SizeGuide"
guideFolder.Parent = workspace
local guideA0, guideA1, guideBeam, guidePart, guideBill, guideConn

local function clearGuide()
    GUIDE = false
    if guideConn then pcall(function() guideConn:Disconnect() end) guideConn = nil end
    if guideBeam then pcall(function() guideBeam:Destroy() end) guideBeam = nil end
    if guideA0 then pcall(function() guideA0:Destroy() end) guideA0 = nil end
    if guideA1 then pcall(function() guideA1:Destroy() end) guideA1 = nil end
    if guidePart then pcall(function() guidePart:Destroy() end) guidePart = nil end
    guideBill = nil
    if bGuide and bGuide.Parent then
        bGuide.Text = "GUIDE"
        bGuide.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    end
end
_G.EGG01_SIZE.clearGuide = clearGuide

local function ensureGuideParts()
    if guidePart and guidePart.Parent then return end
    guidePart = Instance.new("Part")
    guidePart.Name = "Egg01_GuideTarget"
    guidePart.Anchored = true
    guidePart.CanCollide = false
    guidePart.CanQuery = false
    guidePart.CanTouch = false
    guidePart.Transparency = 1
    guidePart.Size = Vector3.new(1, 1, 1)
    guidePart.Parent = guideFolder

    guideA1 = Instance.new("Attachment", guidePart)

    local bb = Instance.new("BillboardGui")
    bb.Name = "Tag"
    bb.Size = UDim2.new(0, 160, 0, 44)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Parent = guidePart
    local tl = Instance.new("TextLabel", bb)
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    tl.BackgroundTransparency = 0.35
    tl.TextColor3 = Color3.fromRGB(255, 230, 80)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 14
    tl.TextWrapped = true
    tl.Text = "★"
    Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 6)
    guideBill = tl
end

local function attachBeamToChar()
    local r = hrp()
    if not r then return false end
    if guideA0 and guideA0.Parent == r then return true end
    if guideA0 then pcall(function() guideA0:Destroy() end) end
    guideA0 = Instance.new("Attachment", r)
    if guideBeam then pcall(function() guideBeam:Destroy() end) end
    guideBeam = Instance.new("Beam")
    guideBeam.Attachment0 = guideA0
    guideBeam.Attachment1 = guideA1
    guideBeam.FaceCamera = true
    guideBeam.Width0 = 0.6
    guideBeam.Width1 = 0.35
    guideBeam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
    guideBeam.Transparency = NumberSequence.new(0.15)
    guideBeam.LightEmission = 1
    guideBeam.Segments = 20
    guideBeam.Parent = guidePart
    return true
end

local function updateGuide()
    if not GUIDE then return end
    ensureGuideParts()
    if not attachBeamToChar() then return end
    local nb, nd = guideTarget()
    if not nb or not nb.pos then
        if guideBill then
            guideBill.Text = (not anyRarOn()) and "ติ๊ก rarity ก่อน" or "ไม่มีเป้า"
        end
        if guideBeam then guideBeam.Enabled = false end
        lab.Text = (not anyRarOn()) and "GUIDE — ติ๊ก rarity อย่างน้อย 1" or "GUIDE — ยังไม่มีเป้า"
        return
    end
    if guideBeam then guideBeam.Enabled = true end
    guidePart.CFrame = CFrame.new(nb.pos + Vector3.new(0, 3, 0))
    local mode = CFG.guideMax and "MAX" or "NEAR"
    if guideBill then
        guideBill.Text = string.format("★%s %s\n%s sc=%.2f d=%.0f",
            mode, tostring(nb.cat or "?"), tostring(nb.rar or "?"), nb.scale or 0, nd or -1)
    end
    lab.Text = string.format("GUIDE[%s] → %s %s sc=%.2f ห่าง %.0f",
        mode, tostring(nb.rar or "?"), tostring(nb.cat), nb.scale or 0, nd)
end

local function setGuide(on)
    if on then
        GUIDE = true
        ensureGuideParts()
        attachBeamToChar()
        if guideConn then pcall(function() guideConn:Disconnect() end) end
        guideConn = RunService.RenderStepped:Connect(updateGuide)
        table.insert(_G.EGG01_SIZE.conns, guideConn)
        bGuide.Text = "GUIDE ON"
        bGuide.BackgroundColor3 = Color3.fromRGB(180, 140, 30)
        local nb, nd = guideTarget()
        local mode = CFG.guideMax and "MAX" or "NEAR"
        if nb then
            say(string.format("GUIDE ON [%s] → ★ %s sc=%.3f ห่าง %.0f",
                mode, tostring(nb.cat), nb.scale, nd))
        else
            say("GUIDE ON — ยังไม่มีเป้า กด SCAN")
        end
    else
        clearGuide()
        say("GUIDE OFF")
    end
end

local function promptPart(pp)
    local p = pp.Parent
    if not p then return nil end
    if p:IsA("BasePart") then return p end
    return p:FindFirstChildWhichIsA("BasePart", true)
end

-- วัดขนาดจากโมเดลใกล้ prompt (ไข่ในรังเห็นสเกลชัดก่อน Shifted)
local function probeVisualScale(anchor)
    if not anchor then return nil, "no-part" end
    local bestVol, bestMax, src = 0, 0, nil
    local origin = anchor.Position
    -- ไล่ parent ขึ้นหา Model แล้ววัดลูก
    local roots = { anchor }
    local p = anchor.Parent
    for _ = 1, 6 do
        if not p or p == workspace then break end
        roots[#roots + 1] = p
        if p:IsA("Model") then break end
        p = p.Parent
    end
    -- + สแกน part ใกล้ๆ 12 studs
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and not d:IsA("Terrain") then
            local nm = d.Name:lower()
            local near = (d.Position - origin).Magnitude <= 14
            local eggish = nm:find("egg") or nm:find("nest") or nm:find("slot") or nm:find("carry")
            if near and (eggish or (d.Position - origin).Magnitude <= 6) then
                local s = d.Size
                local mx = math.max(s.X, s.Y, s.Z)
                local vol = s.X * s.Y * s.Z
                if mx > 1.2 and vol > bestVol then
                    bestVol, bestMax, src = vol, mx, d
                end
            end
        end
    end
    -- attribute / NumberValue บนสาย parent
    for _, root in ipairs(roots) do
        for _, key in ipairs({ "AssetScale", "NestScale", "Scale", "EggScale", "SizeScale" }) do
            local ok, v = pcall(function() return root:GetAttribute(key) end)
            if ok and tonumber(v) then
                return tonumber(v), "attr:" .. key
            end
        end
        for _, ch in ipairs(root:GetDescendants()) do
            if ch:IsA("NumberValue") or ch:IsA("NumberConstraint") then
                local nl = ch.Name:lower()
                if nl:find("scale") and tonumber(ch.Value) then
                    return tonumber(ch.Value), "nv:" .. ch.Name
                end
            end
        end
    end
    if bestMax > 0 then
        -- แปลง max stud → ประมาณ AssetScale (Walrus~4 / Bounds~7)
        local approx = bestMax / 1.8
        return approx, string.format("visMax=%.1f", bestMax)
    end
    return nil, "none"
end

local function matchEggAt(worldPos, maxD)
    maxD = maxD or 55
    local best, bestD, bestUid
    for uid, e in pairs(eggDB) do
        if e.pos and e.scale then
            local skip = CFG.onlySlot and e.state == "Carried"
            if not skip then
                local d = (e.pos - worldPos).Magnitude
                if d <= maxD and (not bestD or d < bestD) then
                    best, bestD, bestUid = e, d, uid
                end
            end
        end
    end
    return best, bestD, bestUid
end

local function resolveScale(part)
    local egg, md, uid = matchEggAt(part.Position, 55)
    if egg and egg.scale then
        return egg.scale, egg, uid, md, "db"
    end
    local vis, how = probeVisualScale(part)
    if vis then
        return vis, { scale = vis, cat = "?", area = "?", state = "vis" }, nil, nil, how
    end
    return nil, nil, nil, nil, "unk"
end

local function listStealNear(radius)
    radius = radius or 120
    local r = hrp()
    if not r then return {} end
    local out = {}
    local seen = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local a = tostring(d.ActionText):lower()
            if a:find("steal") then
                local part = promptPart(d)
                if part then
                    local key = string.format("%.0f_%.0f_%.0f", part.Position.X, part.Position.Y, part.Position.Z)
                    if not seen[key] then
                        seen[key] = true
                        local dd = (part.Position - r.Position).Magnitude
                        if dd <= radius then
                            local scale, egg, uid, md, src = resolveScale(part)
                            out[#out + 1] = {
                                pp = d, part = part, dist = dd,
                                egg = egg, matchD = md, uid = uid,
                                scale = scale, src = src,
                            }
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local sa, sb = a.scale or -1, b.scale or -1
        if sa ~= sb then return sa > sb end
        return a.dist < b.dist
    end)
    return out
end

local function tryFire(pp)
    if not pp or not fp then return false end
    local old = pp.HoldDuration
    local ok = pcall(function()
        pp.HoldDuration = 0
        fp(pp)
    end)
    pcall(function() pp.HoldDuration = old end)
    return ok
end

local function dbCount()
    readCfg()
    local n, ok = 0, 0
    for _, e in pairs(eggDB) do
        n = n + 1
        if passesFilter(e) then ok = ok + 1 end
    end
    return n, ok
end

-- remotes
do
    local sh = findNet("FieldEggShifted")
    if sh and sh:IsA("RemoteEvent") then
        table.insert(_G.EGG01_SIZE.conns, sh.OnClientEvent:Connect(function(t)
            upsertEgg(t)
        end))
        say("ฟัง FieldEggShifted ✅ (สะสมสเกล)")
    else
        say("⚠ ไม่เจอ FieldEggShifted")
    end

    local re = findNet("FieldEggCarry")
    if re and re:IsA("RemoteEvent") then
        table.insert(_G.EGG01_SIZE.conns, re.OnClientEvent:Connect(function(t)
            if typeof(t) ~= "table" then return end
            if t.IsCarrying == true then
                carrying = true
                carryUid = t.Uid
                local e = eggDB[t.Uid]
                local sc = e and e.scale
                say(string.format("✅ ถือไข่ %s scale=%s โซน=%s",
                    tostring(t.AssetCategory or "?"),
                    sc and string.format("%.3f", sc) or "?",
                    tostring(t.AreaId or "?")))
                if sc and sc < CFG.minScale then
                    say(string.format("⚠ เล็กกว่า MinScale %.2f — ทิ้งเองหรือรอ Auto", CFG.minScale))
                end
            elseif t.IsCarrying == false then
                carrying = false
                carryUid = nil
                say("server: ไม่ถือไข่")
            end
        end))
        say("ฟัง FieldEggCarry ✅")
    end

    local batch = findNet("FieldEggBatchShifted")
    if batch and batch:IsA("RemoteEvent") then
        table.insert(_G.EGG01_SIZE.conns, batch.OnClientEvent:Connect(function(t)
            if typeof(t) == "table" then
                if t[1] then
                    for _, row in ipairs(t) do upsertEgg(row) end
                else
                    upsertEgg(t)
                end
            end
        end))
        say("ฟัง FieldEggBatchShifted ✅")
    end
end

bScan.MouseButton1Click:Connect(function()
    readCfg()
    -- snapshot ก่อน แล้วค่อย syncOdds จับคู่ rarity
    for _, name in ipairs({ "AskFieldEggSnapshot", "AskLiveSnapshot" }) do
        local rf = findNet(name)
        if rf and rf:IsA("RemoteFunction") then
            local ok, res = pcall(function() return rf:InvokeServer() end)
            if ok and typeof(res) == "table" then
                local got = ingestSnapshot(res)
                say(string.format("RF %s → +%d eggs", name, got))
            else
                say(string.format("RF %s → %s", name, tostring(res)))
            end
        end
    end
    local on, matched = syncOdds()
    local tags = {}
    for _, n in ipairs(RARITY_ORDER) do if CFG.rarOn[n] then tags[#tags+1] = RAR_SHORT[n] end end
    say(string.format("Odds=%d จับคู่ rarity ได้ %d | กรอง=%s",
        on or 0, matched or 0, #tags > 0 and table.concat(tags, ",") or "any"))
    local n, big = dbCount()
    say(string.format("── SCAN db=%d (ผ่าน %d) sc≥%.2f ──", n, big, CFG.minScale))
    say("── Top rarity/scale ──")
    for _, row in ipairs(topBig(10)) do
        local e = row.e
        local mark = passesFilter(e) and "★" or " "
        local r = hrp()
        local dMe = (r and e.pos) and (e.pos - r.Position).Magnitude or -1
        say(string.format("%s %s sc=%.2f %s [%s] d=%.0f",
            mark, tostring(e.rar or "?"), e.scale or -1,
            tostring(e.cat or "?"), tostring(e.area or "?"), dMe))
    end
    if GUIDE then updateGuide() end
    local nb, nd = guideTarget()
    if nb then
        say(string.format("→ GUIDE[%s]: %s %s sc=%.3f ห่าง %.0f",
            CFG.guideMax and "MAX" or "NEAR", tostring(nb.rar or "?"),
            tostring(nb.cat), nb.scale or 0, nd))
    else
        say("→ ยังไม่มีเป้าที่ผ่านฟิลเตอร์ (rar ยัง ? หรือติ๊กไม่ตรง)")
    end
    local list = listStealNear(150)
    if #list == 0 then
        say("ไม่เจอ Steal ใน 150 studs")
        return
    end
    say("── Steal ใกล้ตัว ──")
    local shown = 0
    for _, it in ipairs(list) do
        if shown >= 10 then break end
        shown = shown + 1
        local e = it.egg
        local mark = (e and passesFilter(e)) and "★" or " "
        say(string.format("%s d=%.0f %s sc≈%.2f %s",
            mark, it.dist, tostring(e and e.rar or "?"),
            it.scale or -1, tostring(e and e.cat or "?")))
    end
end)

local function loop()
    readCfg()
    say(string.format("START EPS — ขโมยเฉพาะ scale≥%.2f เมื่อใกล้ ≤%d", CFG.minScale, STEAL_RANGE))
    local nb0, nd0 = nearestBig()
    if nb0 then
        say(string.format("★ เป้าใกล้สุด %s sc=%.3f ห่าง %.0f — เดินเข้าไปให้ ≤%d",
            tostring(nb0.cat), nb0.scale, nd0, STEAL_RANGE))
    else
        say("ยังไม่มีไข่ ≥ MinScale ใน DB")
    end
    local tLog = 0
    while RUN do
        if carrying then
            lab.Text = "ถือไข่แล้ว — ไป Auto กลับบ้าน"
            task.wait(0.4)
        else
            local list = listStealNear(200)
            local target
            for _, it in ipairs(list) do
                if it.dist <= STEAL_RANGE and it.egg and passesFilter(it.egg) then
                    target = it
                    break
                end
            end
            if target then
                say(string.format("ยิง ★ %s sc≈%.2f %s d=%.1f",
                    tostring(target.egg.rar or "?"), target.scale or -1,
                    tostring(target.egg.cat or "?"), target.dist))
                tryFire(target.pp)
            else
                local nb, nd = nearestBig()
                local near
                for _, it in ipairs(list) do
                    if it.dist <= STEAL_RANGE then near = it break end
                end
                if near and near.scale then
                    if nb then
                        lab.Text = string.format("หน้าคุณ≈%.2f เล็ก | ★%s sc=%.2f ห่าง%.0f",
                            near.scale, tostring(nb.cat), nb.scale, nd)
                    else
                        lab.Text = string.format("ข้ามเล็ก ≈%.2f < %.2f", near.scale, CFG.minScale)
                    end
                elseif nb then
                    lab.Text = string.format("★ %s sc=%.2f ห่าง %.0f — เดินเข้า", tostring(nb.cat), nb.scale, nd)
                else
                    lab.Text = string.format("รอไข่ใหญ่… db big=%d", select(2, dbCount()))
                end
            end
            if os.clock() - tLog > 3 then
                tLog = os.clock()
                local nb, nd = nearestBig()
                if nb then
                    say(string.format("… ★ %s sc=%.3f ห่าง %.0f (ยิงเมื่อ ≤%d)",
                        tostring(nb.cat), nb.scale, nd, STEAL_RANGE))
                else
                    say(string.format("… ยังไม่มี ★ (≥%.2f)", CFG.minScale))
                end
            end
        end
        task.wait(0.3)
    end
end

bStart.MouseButton1Click:Connect(function()
    if RUN then return end
    if not fp then say("⚠ ไม่มี fireproximityprompt"); return end
    readCfg()
    task.spawn(function()
        syncOdds()
        if not GUIDE then setGuide(true) end
        RUN = true
        bStart.Text = "..."
        loop()
    end)
end)

bGuide.MouseButton1Click:Connect(function()
    readCfg()
    if not GUIDE then
        task.spawn(function()
            syncOdds()
            setGuide(true)
        end)
    else
        setGuide(false)
    end
end)

bMode.MouseButton1Click:Connect(function()
    CFG.guideMax = not CFG.guideMax
    paintMode()
    say(CFG.guideMax
        and "โหมด MAX = ชี้ไข่ใหญ่สุดในแมพ (ไม่สนระยะ)"
        or "โหมด NEAR = ชี้ ★ ใกล้สุดที่ ≥ MinScale")
    if GUIDE then updateGuide() end
end)

paintMode()

bStop.MouseButton1Click:Connect(function()
    RUN = false
    bStart.Text = "START"
    say("หยุดยิง (GUIDE ยังเปิดอยู่ถ้าเปิดไว้)")
end)

bCopy.MouseButton1Click:Connect(function()
    local t = "=== Egg01 Size EPS ===\n" .. table.concat(lines, "\n")
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, t) end
    bCopy.Text = "OK"
    task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)

bClose.MouseButton1Click:Connect(function()
    RUN = false
    clearGuide()
    pcall(function() guideFolder:Destroy() end)
    for _, c in ipairs(_G.EGG01_SIZE.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    _G.EGG01_SIZE = nil
end)

say("Size EPS v1.8 — ติ๊ก rarity + MinScale | GUIDE เปิดเอง")
say("ติ๊ก Leg/Myt/... → ตามเส้นเหลือง")
task.spawn(function()
    task.wait(0.8)
    pcall(syncOdds)
    if not GUIDE then setGuide(true) end
end)
