-- Egg01_UidStealTest.lua v1.0
-- ทดสอบขโมยไข่ด้วย UID/current Remote ทีละวิธี (ไม่สแปม)

if _G.EGG01_UID_STEAL then
    pcall(function() _G.EGG01_UID_STEAL.gui:Destroy() end)
    if _G.EGG01_UID_STEAL.conns then
        for _, c in ipairs(_G.EGG01_UID_STEAL.conns) do
            pcall(function() c:Disconnect() end)
        end
    end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local S = { gui = nil, conns = {}, target = nil, busy = false }
_G.EGG01_UID_STEAL = S

local MAX_TEST_DISTANCE = 16
local lines = {}
local boundEvents = {}

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function posOf(row)
    if typeof(row) ~= "table" then return nil end
    for _, key in ipairs({ "BottomCFrame", "BoundsCFrame", "CFrame", "Position" }) do
        local value = row[key]
        if typeof(value) == "CFrame" then return value.Position end
        if typeof(value) == "Vector3" then return value end
    end
    return nil
end

local function short(inst)
    if not inst then return "nil" end
    local ok, name = pcall(function() return inst:GetFullName() end)
    return ok and name:gsub("^ReplicatedStorage", "RS") or inst.Name
end

local function compact(value, depth)
    depth = depth or 0
    local kind = typeof(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "Instance" then return "<" .. value.ClassName .. ":" .. short(value) .. ">" end
    if kind ~= "table" then return tostring(value) end
    if depth >= 1 then return "{...}" end
    local out, n = {}, 0
    for k, v in pairs(value) do
        n = n + 1
        if n > 14 then out[#out + 1] = "..." break end
        out[#out + 1] = tostring(k) .. "=" .. compact(v, depth + 1)
    end
    table.sort(out)
    return "{" .. table.concat(out, ",") .. "}"
end

local function isNamed(inst, wanted)
    return inst.Name == wanted
        or inst.Name:sub(-#wanted) == wanted
        or inst.Name:find(wanted, 1, true) ~= nil
end

local function findRemote(wanted, className)
    local packages = RS:FindFirstChild("Packages")
    local networking = packages and packages:FindFirstChild("Networking")
    local roots = networking and { networking } or { RS }
    for _, root in ipairs(roots) do
        for _, item in ipairs(root:GetDescendants()) do
            if isNamed(item, wanted) and (not className or item:IsA(className)) then
                return item
            end
        end
    end
    if networking then
        for _, item in ipairs(RS:GetDescendants()) do
            if isNamed(item, wanted) and (not className or item:IsA(className)) then
                return item
            end
        end
    end
    return nil
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_UidStealTest"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1002
gui.IgnoreGuiInset = true
pcall(function()
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 430, 0, 170)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -50, 0, 24)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 UID Steal Test v1.0"

local function button(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w, 0, 30)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = text
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bClose = button("X", 392, 4, 30, Color3.fromRGB(130, 45, 45))
local bScan = button("SCAN NEAREST", 10, 36, 98, Color3.fromRGB(50, 105, 180))
local bUid = button("1 UID TABLE", 116, 36, 94, Color3.fromRGB(45, 145, 75))
local bFull = button("2 FULL ROW", 218, 36, 94, Color3.fromRGB(155, 105, 40))
local bCmds = button("3 EGGCMDS", 320, 36, 100, Color3.fromRGB(140, 65, 155))
local bPrompt = button("PROMPT BASE", 10, 74, 98, Color3.fromRGB(55, 110, 135))
local bCopy = button("COPY LOG", 116, 74, 94, Color3.fromRGB(75, 75, 82))
local bClear = button("CLEAR", 218, 74, 94, Color3.fromRGB(75, 75, 82))

local status = Instance.new("TextLabel", panel)
status.Size = UDim2.new(1, -20, 0, 56)
status.Position = UDim2.new(0, 10, 0, 110)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 220, 105)
status.Font = Enum.Font.GothamBold
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "ยืนใกล้ไข่จริงไม่เกิน 16 studs → SCAN → กดทดสอบทีละปุ่ม"

local logBox = Instance.new("TextBox", gui)
logBox.Size = UDim2.new(0, 430, 0, 280)
logBox.Position = UDim2.new(0, 12, 0, 190)
logBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
logBox.BackgroundTransparency = 0.22
logBox.BorderSizePixel = 0
logBox.TextColor3 = Color3.fromRGB(185, 240, 190)
logBox.Font = Enum.Font.Code
logBox.TextSize = 11
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.ClearTextOnFocus = false
logBox.TextEditable = false
logBox.MultiLine = true
logBox.TextWrapped = false
logBox.Text = ""
Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 6)

local function say(message)
    message = tostring(message)
    lines[#lines + 1] = message
    if #lines > 180 then table.remove(lines, 1) end
    logBox.Text = table.concat(lines, "\n")
    status.Text = message
end

local function requestSnapshot()
    local rf = findRemote("AskFieldEggSnapshot", "RemoteFunction")
    if not rf then return nil, "ไม่พบ AskFieldEggSnapshot" end
    local ok, result = pcall(function() return rf:InvokeServer() end)
    if not ok then return nil, tostring(result) end
    if typeof(result) ~= "table" then return nil, "snapshot=" .. typeof(result) end
    local records = result.Records or result.records or result
    if typeof(records) ~= "table" then return nil, "snapshot ไม่มี Records" end
    return records, short(rf)
end

local function recordByUid(records, uid)
    if not records then return nil end
    if typeof(records[uid]) == "table" then return records[uid] end
    for key, row in pairs(records) do
        if typeof(row) == "table" and tostring(row.Uid or key) == tostring(uid) then
            return row
        end
    end
    return nil
end

local function scanNearest()
    local root = hrp()
    if not root then say("ไม่พบ HumanoidRootPart") return false end
    local records, source = requestSnapshot()
    if not records then say("SCAN error: " .. tostring(source)) return false end
    local best
    local count = 0
    for key, row in pairs(records) do
        if typeof(row) == "table" then
            local pos = posOf(row)
            local uid = row.Uid or key
            if pos and uid ~= nil then
                count = count + 1
                local distance = (pos - root.Position).Magnitude
                if not best or distance < best.distance then
                    best = { uid = uid, row = row, pos = pos, distance = distance }
                end
            end
        end
    end
    if not best then say("SCAN ไม่พบ record ที่มี UID+ตำแหน่ง") return false end
    S.target = best
    say(string.format("SCAN eggs=%d via=%s", count, source))
    say(string.format("TARGET %s sc=%s uid=%s", tostring(best.row.AssetCategory or "?"),
        tostring(best.row.AssetScale or "?"), tostring(best.uid)))
    say(string.format("POS %.1f,%.1f,%.1f dist=%.1f state=%s", best.pos.X, best.pos.Y, best.pos.Z,
        best.distance, tostring(best.row.State or "?")))
    if best.distance > MAX_TEST_DISTANCE then
        say(string.format("ไกลเกิน %.0f — เข้าใกล้ไข่แล้ว SCAN ใหม่", MAX_TEST_DISTANCE))
    end
    return true
end

local function targetReady()
    if S.busy then say("กำลังรอผลครั้งก่อน") return nil end
    if not S.target and not scanNearest() then return nil end
    local root = hrp()
    if not root then say("ไม่พบ HumanoidRootPart") return nil end
    local distance = (S.target.pos - root.Position).Magnitude
    S.target.distance = distance
    if distance > MAX_TEST_DISTANCE then
        say(string.format("ไม่ยิง: เป้าห่าง %.1f > %.0f studs — เข้าใกล้แล้ว SCAN", distance, MAX_TEST_DISTANCE))
        return nil
    end
    return S.target
end

local function inspectAfter(target, label, ok, result)
    task.wait(0.85)
    local records, err = requestSnapshot()
    local after = records and recordByUid(records, target.uid) or nil
    local stateBefore = tostring(target.row.State or "?")
    local stateAfter = after and tostring(after.State or "?") or "MISSING"
    say(string.format("RESULT %s call=%s return=%s", label, ok and "OK" or "ERROR", compact(result)))
    say(string.format("VERIFY uid=%s before=%s after=%s snapshot=%s", tostring(target.uid),
        stateBefore, stateAfter, records and "OK" or tostring(err)))
    if after then
        local p = posOf(after)
        if p then say(string.format("AFTER pos=%.1f,%.1f,%.1f", p.X, p.Y, p.Z)) end
    end
    S.busy = false
end

local function invokeCarry(label, payloadBuilder)
    local target = targetReady()
    if not target then return end
    local rf = findRemote("AskFieldEggCarry", "RemoteFunction")
    if not rf then
        say("ไม่พบ RF AskFieldEggCarry — วิธีนี้ใช้ไม่ได้ใน server นี้")
        return
    end
    local payload = payloadBuilder(target)
    S.busy = true
    say(string.format("CALL %s via=%s dist=%.1f", label, short(rf), target.distance))
    say("PAYLOAD " .. compact(payload))
    task.spawn(function()
        local ok, result = pcall(function() return rf:InvokeServer(payload) end)
        inspectAfter(target, label, ok, result)
    end)
end

local function findEggCmds()
    for _, item in ipairs(RS:GetDescendants()) do
        if item:IsA("ModuleScript") and item.Name == "EggCmds" then
            local ok, module = pcall(require, item)
            if ok and typeof(module) == "table" and typeof(module.RequestCarryAreaEgg) == "function" then
                return module, "require " .. short(item)
            end
        end
    end
    if getgc then
        local ok, objects = pcall(getgc, true)
        if ok and typeof(objects) == "table" then
            for _, object in ipairs(objects) do
                if typeof(object) == "table" and typeof(rawget(object, "RequestCarryAreaEgg")) == "function" then
                    return object, "getgc table"
                end
            end
        end
    end
    return nil, "ไม่พบ EggCmds.RequestCarryAreaEgg"
end

local function nearestPrompt(target)
    local best, bestDistance
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("ProximityPrompt") then
            local action = string.lower(tostring(item.ActionText))
            if action:find("steal", 1, true) or item.Name:find("CarryAreaEgg", 1, true) then
                local parent = item.Parent
                local part = parent and (parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart", true))
                if part then
                    local distance = (part.Position - target.pos).Magnitude
                    if not bestDistance or distance < bestDistance then
                        best, bestDistance = item, distance
                    end
                end
            end
        end
    end
    return best, bestDistance
end

local function bindEvent(item)
    if boundEvents[item] then return end
    local interesting = item.Name:find("FieldEggCarry", 1, true)
        or item.Name:find("FieldEggShifted", 1, true)
    if not interesting then return end
    local isEvent = item:IsA("RemoteEvent") or item:IsA("UnreliableRemoteEvent")
    if not isEvent then return end
    boundEvents[item] = true
    S.conns[#S.conns + 1] = item.OnClientEvent:Connect(function(...)
        local values = {}
        for i = 1, math.min(select("#", ...), 4) do
            values[#values + 1] = compact(select(i, ...))
        end
        say("EVENT " .. short(item) .. " ← " .. table.concat(values, ", "))
    end)
    say("LISTEN " .. short(item))
end

for _, item in ipairs(RS:GetDescendants()) do bindEvent(item) end
S.conns[#S.conns + 1] = RS.DescendantAdded:Connect(bindEvent)

bScan.MouseButton1Click:Connect(scanNearest)

bUid.MouseButton1Click:Connect(function()
    invokeCarry("UID_TABLE", function(target)
        return { Uid = target.uid }
    end)
end)

bFull.MouseButton1Click:Connect(function()
    invokeCarry("FULL_ROW", function(target)
        local payload = {}
        for key, value in pairs(target.row) do payload[key] = value end
        payload.Uid = target.uid
        return payload
    end)
end)

bCmds.MouseButton1Click:Connect(function()
    local target = targetReady()
    if not target then return end
    local cmds, source = findEggCmds()
    if not cmds then say(source) return end
    S.busy = true
    say(string.format("CALL EGGCMDS uid=%s dist=%.1f via=%s", tostring(target.uid), target.distance, source))
    task.spawn(function()
        local ok, result = pcall(cmds.RequestCarryAreaEgg, target.uid)
        inspectAfter(target, "EGGCMDS", ok, result)
    end)
end)

bPrompt.MouseButton1Click:Connect(function()
    local target = targetReady()
    if not target then return end
    local prompt, matchDistance = nearestPrompt(target)
    if not prompt then say("ไม่พบ Prompt Steal ที่จับกับเป้า") return end
    if not fp then say("executor ไม่มี fireproximityprompt") return end
    local oldHold = prompt.HoldDuration
    say(string.format("PROMPT %s eggMatch=%.1f hold=%.2f", short(prompt), matchDistance or -1, oldHold))
    S.busy = true
    local ok, result = pcall(function()
        prompt.HoldDuration = 0
        fp(prompt)
        task.wait(0.05)
        prompt.HoldDuration = oldHold
        return true
    end)
    task.spawn(function() inspectAfter(target, "PROMPT_BASE", ok, result) end)
end)

bCopy.MouseButton1Click:Connect(function()
    local text = "=== Egg01 UID Steal Test v1.0 ===\n" .. table.concat(lines, "\n")
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, text) bCopy.Text = "COPIED" else say("ไม่มี setclipboard") end
    task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY LOG" end end)
end)

bClear.MouseButton1Click:Connect(function()
    table.clear(lines)
    logBox.Text = ""
    say("ล้าง log แล้ว")
end)

bClose.MouseButton1Click:Connect(function()
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)

say("UID Test พร้อม — ยืนใกล้ไข่ ≤24 → SCAN")
say("กดทีละวิธีและรอ RESULT/VERIFY ก่อนกดวิธีต่อไป")
