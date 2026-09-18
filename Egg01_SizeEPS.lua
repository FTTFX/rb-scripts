-- Egg01_SizeEPS.lua v2.1 SAFE
-- Rebuilt from verified field-egg data only.
-- Source: AskFieldEggSnapshot / FieldEggShifted -> BottomCFrame/BoundsCFrame + AssetScale.
-- Rarity: one-to-one spatial assignment from displayed Odds to field eggs; guides always end at egg positions.

if _G.EGG01_SIZE then
 pcall(function() _G.EGG01_SIZE.destroy() end)
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local CFG = { minScale = 1, minRarity = "Epic", maxLines = 18, maxMatch = 60, maxRarityMatch = 160, fireRange = 16, maxMode = false }
local RUN, GUIDE, carrying = false, false, false
local eggDB, targets, conns, lines = {}, {}, {}, {}
local guideFolder, rootAttachment

local RARITY_RANK = {
 common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5,
 mythic = 6, cosmic = 7, secret = 8, eternal = 9, divine = 10,
}

local function rarRank(value)
 return RARITY_RANK[tostring(value or ""):lower()] or 0
end

local function cleanRarity(value)
 local word = tostring(value or ""):gsub("<.->", ""):match("([A-Za-z]+)")
 if not word or rarRank(word) == 0 then return nil end
 return word:sub(1, 1):upper() .. word:sub(2):lower()
end

local function hrp()
 local c = LP.Character
 return c and c:FindFirstChild("HumanoidRootPart")
end

local function findNet(name)
 local pkg = RS:FindFirstChild("Packages")
 local net = pkg and pkg:FindFirstChild("Networking")
 if not net then return nil end
 local fallback
 for _, d in ipairs(net:GetDescendants()) do
 if d.Name == name then return d end
 if not fallback and d.Name:find(name, 1, true) then fallback = d end
 end
 return fallback
end

local function promptPart(pp)
 local p = pp and pp.Parent
 if not p then return nil end
 if p:IsA("BasePart") then return p end
 if p:IsA("Attachment") and p.Parent and p.Parent:IsA("BasePart") then return p.Parent end
 local ancestor = p:FindFirstAncestorWhichIsA("BasePart")
 if ancestor then return ancestor end
 return p:FindFirstChildWhichIsA("BasePart", true)
end

local function posFromRow(row)
 if typeof(row.BottomCFrame) == "CFrame" then return row.BottomCFrame.Position end
 if typeof(row.BoundsCFrame) == "CFrame" then return row.BoundsCFrame.Position end
 return nil
end

local function upsert(row, uidHint)
 if typeof(row) ~= "table" then return false end
 local uid = row.Uid or uidHint
 if not uid then return false end
 local e = eggDB[uid] or { uid = uid }
 if row.AssetScale ~= nil then e.scale = tonumber(row.AssetScale) or e.scale end
 if row.AssetCategory then e.cat = row.AssetCategory end
 if row.AreaId then e.area = row.AreaId end
 if row.State then e.state = row.State end
 if row.NestId then e.nest = row.NestId end
 local pos = posFromRow(row)
 if pos then e.pos = pos end
 e.updated = os.clock()
 eggDB[uid] = e
 return true
end

local function ingest(value)
 if typeof(value) ~= "table" then return 0 end
 local n = 0
 local records = value.Records or value.records
 if typeof(records) == "table" then
 for k, row in pairs(records) do
 if upsert(row, typeof(k) == "string" and k or nil) then n = n + 1 end
 end
 return n
 end
 if value[1] then
 for _, row in ipairs(value) do
 if typeof(row) == "table" and (row.Records or row.records) then
 n = n + ingest(row)
 elseif upsert(row) then
 n = n + 1
 end
 end
 return n
 end
 if upsert(value) then return 1 end
 for k, row in pairs(value) do
 if upsert(row, typeof(k) == "string" and k or nil) then n = n + 1 end
 end
 return n
end

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_SizeEPS"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 330, 0, 164)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -50, 0, 22)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 Field Egg EPS v2.1 SAFE"

local function button(text, x, w, color)
 local b = Instance.new("TextButton", panel)
 b.Size = UDim2.new(0, w, 0, 28)
 b.Position = UDim2.new(0, x, 0, 34)
 b.BackgroundColor3 = color
 b.TextColor3 = Color3.new(1, 1, 1)
 b.Font = Enum.Font.GothamBold
 b.TextSize = 11
 b.Text = text
 b.BorderSizePixel = 0
 Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
 return b
end

local bScan = button("SCAN", 10, 50, Color3.fromRGB(45, 100, 185))
local bMode = button("NEAR", 64, 50, Color3.fromRGB(65, 90, 125))
local bGuide = button("GUIDE", 118, 55, Color3.fromRGB(165, 125, 25))
local bStart = button("START", 177, 50, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 231, 44, Color3.fromRGB(165, 50, 55))
local bCopy = button("COPY", 279, 41, Color3.fromRGB(70, 70, 75))

local bClose = Instance.new("TextButton", panel)
bClose.Size = UDim2.new(0, 30, 0, 24)
bClose.Position = UDim2.new(1, -38, 0, 3)
bClose.BackgroundColor3 = Color3.fromRGB(125, 45, 45)
bClose.TextColor3 = Color3.new(1, 1, 1)
bClose.Font = Enum.Font.GothamBold
bClose.Text = "X"
bClose.BorderSizePixel = 0
Instance.new("UICorner", bClose).CornerRadius = UDim.new(0, 5)

local minLabel = Instance.new("TextLabel", panel)
minLabel.Size = UDim2.new(0, 62, 0, 16)
minLabel.Position = UDim2.new(0, 10, 0, 68)
minLabel.BackgroundTransparency = 1
minLabel.TextColor3 = Color3.fromRGB(175, 175, 175)
minLabel.Font = Enum.Font.Gotham
minLabel.TextSize = 10
minLabel.TextXAlignment = Enum.TextXAlignment.Left
minLabel.Text = "MinScale"

local tMin = Instance.new("TextBox", panel)
tMin.Size = UDim2.new(0, 55, 0, 22)
tMin.Position = UDim2.new(0, 10, 0, 84)
tMin.BackgroundColor3 = Color3.fromRGB(40, 43, 49)
tMin.TextColor3 = Color3.new(1, 1, 1)
tMin.Font = Enum.Font.GothamBold
tMin.TextSize = 12
tMin.Text = "1"
tMin.ClearTextOnFocus = false
tMin.BorderSizePixel = 0
Instance.new("UICorner", tMin).CornerRadius = UDim.new(0, 4)

local warning = Instance.new("TextLabel", panel)
warning.Size = UDim2.new(0, 154, 0, 38)
warning.Position = UDim2.new(0, 166, 0, 69)
warning.BackgroundTransparency = 1
warning.TextColor3 = Color3.fromRGB(255, 190, 80)
warning.Font = Enum.Font.GothamBold
warning.TextSize = 10
warning.TextWrapped = true
warning.TextXAlignment = Enum.TextXAlignment.Left
warning.TextYAlignment = Enum.TextYAlignment.Top
warning.Text = "ปลายเส้น=ไข่จริงเท่านั้น\nrarity map 1:1 ตามระยะ"

local rarLabel = minLabel:Clone()
rarLabel.Position = UDim2.new(0, 76, 0, 68)
rarLabel.Text = "MinRarity"
rarLabel.Parent = panel

local tRar = tMin:Clone()
tRar.Size = UDim2.new(0, 80, 0, 22)
tRar.Position = UDim2.new(0, 76, 0, 84)
tRar.Text = "Epic"
tRar.Parent = panel

local status = Instance.new("TextLabel", panel)
status.Size = UDim2.new(1, -20, 0, 25)
status.Position = UDim2.new(0, 10, 0, 134)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(130, 235, 150)
status.Font = Enum.Font.GothamBold
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "กด SCAN"

local log = Instance.new("TextBox", gui)
log.Size = UDim2.new(0, 330, 0, 175)
log.Position = UDim2.new(0, 12, 0, 186)
log.BackgroundColor3 = Color3.new(0, 0, 0)
log.BackgroundTransparency = 0.28
log.TextColor3 = Color3.fromRGB(175, 240, 180)
log.Font = Enum.Font.Code
log.TextSize = 11
log.TextXAlignment = Enum.TextXAlignment.Left
log.TextYAlignment = Enum.TextYAlignment.Top
log.TextEditable = false
log.ClearTextOnFocus = false
log.MultiLine = true
log.TextWrapped = true
Instance.new("UICorner", log).CornerRadius = UDim.new(0, 6)

local function say(msg)
 lines[#lines + 1] = tostring(msg)
 if #lines > 100 then table.remove(lines, 1) end
 log.Text = table.concat(lines, "\n")
 status.Text = tostring(msg)
end

local function readCfg()
 local n = tonumber(tMin.Text)
 if n and n >= 0 then CFG.minScale = n end
 local rr = tostring(tRar.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
 CFG.minRarity = rr == "" and "Any" or rr
end

local function requestFieldSnapshot()
 local rf = findNet("AskFieldEggSnapshot")
 if not rf or not rf:IsA("RemoteFunction") then
 say("ไม่เจอ AskFieldEggSnapshot")
 return 0
 end
 local ok, res = pcall(function() return rf:InvokeServer() end)
 if not ok or typeof(res) ~= "table" then
 say("Snapshot error: " .. tostring(res))
 return 0
 end
 local n = ingest(res)
 say(string.format("Field snapshot +%d records", n))
 return n
end

local function oddsText(inst)
 if not inst then return nil end
 if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then return inst.Text end
 local label = inst:FindFirstChildWhichIsA("TextLabel", true) or inst:FindFirstChildWhichIsA("TextButton", true)
 return label and label.Text or nil
end

local function oddsPosition(asset, odds)
 local bb = odds and odds:FindFirstAncestorWhichIsA("BillboardGui")
 if bb and bb.Adornee then
 if bb.Adornee:IsA("BasePart") then return bb.Adornee.Position end
 if bb.Adornee:IsA("Model") then
 local p = bb.Adornee.PrimaryPart or bb.Adornee:FindFirstChildWhichIsA("BasePart", true)
 if p then return p.Position end
 end
 end
 local part = asset and asset:FindFirstChildWhichIsA("BasePart", true)
 return part and part.Position or nil
end

local function mapRarities()
 for _, e in pairs(eggDB) do e.rar = nil; e.rarDist = nil end
 local rf = findNet("AskFieldEggRarityShows")
 if rf and rf:IsA("RemoteFunction") then
 pcall(function() rf:InvokeServer() end)
 task.wait(0.65)
 end
 local folder = workspace:FindFirstChild("ClientRenderedAssets")
 if not folder then say("rarity map: ไม่มี ClientRenderedAssets"); return 0 end
 local oddsRows, eggs = {}, {}
 for _, asset in ipairs(folder:GetChildren()) do
 local data = asset:FindFirstChild("Data")
 local odds = data and (data:FindFirstChild("Odds") or data:FindFirstChild("Odds", true))
 local rar = cleanRarity(oddsText(odds))
 local pos = oddsPosition(asset, odds)
 if rar and pos then oddsRows[#oddsRows + 1] = { rar = rar, pos = pos, asset = asset.Name } end
 end
 for uid, e in pairs(eggDB) do
 if e.pos and e.scale and e.state ~= "Carried" then eggs[#eggs + 1] = { uid = uid, e = e } end
 end
 local candidates = {}
 for oi, odds in ipairs(oddsRows) do
 for ei, row in ipairs(eggs) do
 local d = (odds.pos - row.e.pos).Magnitude
 if d <= CFG.maxRarityMatch then candidates[#candidates + 1] = { oi = oi, ei = ei, d = d } end
 end
 end
 table.sort(candidates, function(a, b) return a.d < b.d end)
 local usedO, usedE, count, totalD, maxD = {}, {}, 0, 0, 0
 for _, pair in ipairs(candidates) do
 if not usedO[pair.oi] and not usedE[pair.ei] then
 usedO[pair.oi], usedE[pair.ei] = true, true
 local odds, egg = oddsRows[pair.oi], eggs[pair.ei].e
 egg.rar, egg.rarDist = odds.rar, pair.d
 count, totalD, maxD = count + 1, totalD + pair.d, math.max(maxD, pair.d)
 end
 end
 say(string.format("rarity map 1:1 Odds=%d eggs=%d matched=%d avg=%.0f max=%.0f",
 #oddsRows, #eggs, count, count > 0 and totalD / count or 0, maxD))
 return count
end

local function stealPrompts()
 local out, seen = {}, {}
 for _, d in ipairs(workspace:GetDescendants()) do
 if d:IsA("ProximityPrompt") and d.Enabled and tostring(d.ActionText):lower():find("steal", 1, true) then
 local part = promptPart(d)
 if part then
 local key = string.format("%.1f/%.1f/%.1f", part.Position.X, part.Position.Y, part.Position.Z)
 if not seen[key] then
 seen[key] = true
 out[#out + 1] = { pp = d, part = part, pos = part.Position }
 end
 end
 end
 end
 return out
end

local function countMap(t)
 local n = 0
 for _ in pairs(t) do n = n + 1 end
 return n
end

local function rebuildTargets()
 readCfg()
 local prompts = stealPrompts()
 local eggs = {}
 for uid, e in pairs(eggDB) do
 if e.pos and e.scale and e.state ~= "Carried" then eggs[#eggs + 1] = { uid = uid, e = e } end
 end
 local pairsList = {}
 for pi, p in ipairs(prompts) do
 for ei, row in ipairs(eggs) do
 local d = (p.pos - row.e.pos).Magnitude
 if d <= CFG.maxMatch then pairsList[#pairsList + 1] = { pi = pi, ei = ei, d = d } end
 end
 end
 table.sort(pairsList, function(a, b) return a.d < b.d end)
 local usedP, usedE, matches = {}, {}, {}
 for _, pair in ipairs(pairsList) do
 if not usedP[pair.pi] and not usedE[pair.ei] then
 usedP[pair.pi], usedE[pair.ei] = true, true
 matches[pair.ei] = { prompt = prompts[pair.pi], matchD = pair.d }
 end
 end
 targets = {}
 local needRank = rarRank(CFG.minRarity)
 for ei, row in ipairs(eggs) do
 local e, match = row.e, matches[ei]
 local rarityOk = needRank == 0 or rarRank(e.rar) >= needRank
 if e.scale >= CFG.minScale and rarityOk then
 targets[#targets + 1] = {
 uid = row.uid, cat = e.cat or "?", scale = e.scale, rar = e.rar, rarDist = e.rarDist, area = e.area or "?",
 pos = match and match.prompt.pos or e.pos, eggPos = e.pos,
 pp = match and match.prompt.pp or nil, matchD = match and match.matchD or nil,
 }
 end
 end
 local r = hrp()
 for _, t in ipairs(targets) do t.dist = r and (t.pos - r.Position).Magnitude or math.huge end
 table.sort(targets, function(a, b)
 if CFG.maxMode and a.scale ~= b.scale then return a.scale > b.scale end
 return a.dist < b.dist
 end)
 say(string.format("ไข่จริง=%d Prompt=%d จับคู่=%d ผ่าน sc>=%.2f rar>=%s: %d",
 #eggs, #prompts, countMap(matches), CFG.minScale, CFG.minRarity, #targets))
 return targets
end

local function clearGuideVisuals()
 if guideFolder then pcall(function() guideFolder:Destroy() end) end
 guideFolder, rootAttachment = nil, nil
end

local function drawGuides()
 clearGuideVisuals()
 if not GUIDE then return end
 local r = hrp()
 if not r then say("ไม่มี HumanoidRootPart"); return end
 guideFolder = Instance.new("Folder", workspace)
 guideFolder.Name = "Egg01_FieldEggGuide"
 rootAttachment = Instance.new("Attachment", r)
 local count = math.min(CFG.maxLines, #targets)
 for i = 1, count do
 local t = targets[i]
 local part = Instance.new("Part", guideFolder)
 part.Name = "Egg_" .. i
 part.Anchored = true
 part.CanCollide = false
 part.CanQuery = false
 part.CanTouch = false
 part.Transparency = 1
 part.Size = Vector3.new(1, 1, 1)
 part.CFrame = CFrame.new(t.pos + Vector3.new(0, 3, 0))
 local a1 = Instance.new("Attachment", part)
 local beam = Instance.new("Beam", part)
 beam.Attachment0 = rootAttachment
 beam.Attachment1 = a1
 beam.FaceCamera = true
 beam.Width0 = i == 1 and 0.55 or 0.20
 beam.Width1 = i == 1 and 0.30 or 0.10
 beam.Color = ColorSequence.new(i == 1 and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(90, 220, 255))
 beam.Transparency = NumberSequence.new(i == 1 and 0.08 or 0.35)
 beam.LightEmission = 1
 beam.Segments = 12
 local bb = Instance.new("BillboardGui", part)
 bb.Size = UDim2.new(0, 145, 0, 34)
 bb.StudsOffset = Vector3.new(0, 2, 0)
 bb.AlwaysOnTop = true
 bb.MaxDistance = 1200
 local tl = Instance.new("TextLabel", bb)
 tl.Size = UDim2.new(1, 0, 1, 0)
 tl.BackgroundColor3 = Color3.new(0, 0, 0)
 tl.BackgroundTransparency = 0.3
 tl.TextColor3 = i == 1 and Color3.fromRGB(255, 230, 70) or Color3.fromRGB(130, 235, 255)
 tl.Font = Enum.Font.GothamBold
 tl.TextSize = 11
 tl.TextWrapped = true
 tl.Text = string.format("ไข่ %s %s sc=%.2f\nd=%.0f %s", tostring(t.rar or "?"), t.cat, t.scale, t.dist, t.pp and "Steal" or "snapshot")
 end
 bGuide.Text = GUIDE and ("GUIDE " .. count) or "GUIDE"
 if count > 0 then
 local t = targets[1]
 status.Text = string.format("%s → ไข่ %s %s sc=%.2f ห่าง %.0f", CFG.maxMode and "MAX" or "NEAR", tostring(t.rar or "?"), t.cat, t.scale, t.dist)
 else
 status.Text = "ไม่มีไข่จริงที่ผ่าน MinScale"
 end
end

local function scan()
 requestFieldSnapshot()
 mapRarities()
 rebuildTargets()
 if GUIDE then drawGuides() end
 for i = 1, math.min(8, #targets) do
 local t = targets[i]
 say(string.format("#%d %s %s sc=%.2f d=%.0f prompt=%s eggMatch=%s rarMatch=%s",
 i, tostring(t.rar or "?"), t.cat, t.scale, t.dist, t.pp and "Y" or "N",
 t.matchD and string.format("%.1f", t.matchD) or "-", t.rarDist and string.format("%.1f", t.rarDist) or "-"))
 end
end

local function tryFire(pp)
 if not pp or not fp then return false end
 local old = pp.HoldDuration
 local ok = pcall(function() pp.HoldDuration = 0 fp(pp) end)
 pcall(function() pp.HoldDuration = old end)
 return ok
end

local function runLoop()
 say(string.format("START sc>=%.2f rar>=%s ยิงเมื่อ <=%d", CFG.minScale, CFG.minRarity, CFG.fireRange))
 local lastRefresh = 0
 while RUN do
 if carrying then
 status.Text = "ถือไข่แล้ว — หยุดยิงชั่วคราว"
 else
 if os.clock() - lastRefresh > 2 then
 lastRefresh = os.clock()
 rebuildTargets()
 if GUIDE then drawGuides() end
 end
 local r = hrp()
 local fired
 if r then
 for _, t in ipairs(targets) do
 local d = (t.pos - r.Position).Magnitude
 if t.pp and d <= CFG.fireRange then
 say(string.format("ยิงไข่ %s sc=%.2f d=%.1f", t.cat, t.scale, d))
 tryFire(t.pp)
 fired = true
 break
 end
 end
 end
 if not fired then task.wait(0.25) end
 end
 task.wait(0.1)
 end
end

local function connectRemote(name, className, fn)
 local remote = findNet(name)
 if remote and remote:IsA(className) then
 conns[#conns + 1] = remote.OnClientEvent:Connect(fn)
 return true
 end
 return false
end

connectRemote("FieldEggShifted", "RemoteEvent", function(row) upsert(row) end)
connectRemote("FieldEggBatchShifted", "RemoteEvent", function(value) ingest(value) end)
connectRemote("FieldEggGone", "RemoteEvent", function(row)
 local uid = typeof(row) == "table" and row.Uid or row
 if uid then eggDB[uid] = nil end
end)
connectRemote("FieldEggCarry", "RemoteEvent", function(row)
 if typeof(row) == "table" and row.IsCarrying ~= nil then carrying = row.IsCarrying == true end
end)

bScan.MouseButton1Click:Connect(function() task.spawn(scan) end)
bMode.MouseButton1Click:Connect(function()
 CFG.maxMode = not CFG.maxMode
 bMode.Text = CFG.maxMode and "MAX" or "NEAR"
 rebuildTargets()
 if GUIDE then drawGuides() end
end)
bGuide.MouseButton1Click:Connect(function()
 GUIDE = not GUIDE
 if GUIDE then
 rebuildTargets()
 drawGuides()
 else
 clearGuideVisuals()
 bGuide.Text = "GUIDE"
 status.Text = "GUIDE OFF"
 end
end)
bStart.MouseButton1Click:Connect(function()
 if RUN then return end
 if not fp then say("executor ไม่มี fireproximityprompt"); return end
 readCfg()
 requestFieldSnapshot()
 mapRarities()
 rebuildTargets()
 RUN = true
 bStart.Text = "..."
 task.spawn(runLoop)
end)
bStop.MouseButton1Click:Connect(function()
 RUN = false
 bStart.Text = "START"
 say("STOP")
end)
bCopy.MouseButton1Click:Connect(function()
 local clip = setclipboard or toclipboard
 if clip then pcall(clip, "=== Egg01 Field Egg EPS v2.1 ===\n" .. table.concat(lines, "\n")) end
 bCopy.Text = "OK"
 task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)

local function destroy()
 RUN, GUIDE = false, false
 clearGuideVisuals()
 for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
 pcall(function() gui:Destroy() end)
 _G.EGG01_SIZE = nil
end
_G.EGG01_SIZE = { gui = gui, destroy = destroy }
bClose.MouseButton1Click:Connect(destroy)

say("v2.1 SAFE — ปลายเส้นชี้เฉพาะไข่จาก FieldEggSnapshot")
say("Rarity map 1:1 จาก Odds→ไข่; ไม่ใช้ตำแหน่งมอนเป็นปลายเส้น")
task.spawn(scan)
