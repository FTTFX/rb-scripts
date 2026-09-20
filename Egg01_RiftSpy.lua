-- Egg01 Rift Spy v1.3
-- อ่านอย่างเดียว: ไม่ FireServer, ไม่กด Prompt, ไม่ขยับตัวละคร

if _G.EGG01_RIFT_SPY then
    _G.EGG01_RIFT_SPY.run = false
    pcall(function() _G.EGG01_RIFT_SPY.gui:Destroy() end)
    for _, c in ipairs(_G.EGG01_RIFT_SPY.watchConns or {}) do pcall(function() c:Disconnect() end) end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local S = { gui = nil, run = false, watchConns = {}, seen = {}, remoteBound = {}, buttonBound = {}, lastRiftClick = 0 }
_G.EGG01_RIFT_SPY = S
local lines = {}
local KEYWORDS = { "rift", "portal" }
local logBox

local function now() return string.format("[%.2f] ", os.clock()) end
local function say(text)
    local line = now() .. text
    lines[#lines + 1] = line
    if #lines > 120 then table.remove(lines, 1) end
    if logBox then logBox.Text = table.concat(lines, "\n") end
    warn("[Egg01 Rift Spy] " .. text)
end

local function pathOf(inst)
    local ok, path = pcall(function() return inst:GetFullName() end)
    return ok and path:gsub("^ReplicatedStorage", "RS") or tostring(inst)
end

local function hasKey(value)
    local text = tostring(value):lower()
    for _, key in ipairs(KEYWORDS) do if text:find(key, 1, true) then return true end end
    return false
end

local function compact(value, depth)
    depth = depth or 0
    local kind = typeof(value)
    if kind == "string" then return value end
    if kind == "Instance" then return "<" .. value.ClassName .. ":" .. pathOf(value) .. ">" end
    if kind ~= "table" then return tostring(value) end
    if depth >= 1 then return "{...}" end
    local out, n = {}, 0
    for k, v in pairs(value) do
        n = n + 1
        if n > 10 then out[#out + 1] = "..." break end
        out[#out + 1] = tostring(k) .. "=" .. compact(v, depth + 1)
    end
    table.sort(out)
    return "{" .. table.concat(out, ",") .. "}"
end

local function argsHaveKey(...)
    for i = 1, select("#", ...) do
        if hasKey(compact(select(i, ...))) then return true end
    end
    return false
end

local function positionOf(inst)
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, pivot = pcall(function() return inst:GetPivot() end)
        return ok and pivot.Position or nil
    end
    local part = inst:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function attrsOf(inst)
    local attrs = inst:GetAttributes()
    local out = {}
    for k, v in pairs(attrs) do out[#out + 1] = k .. "=" .. compact(v) end
    table.sort(out)
    return #out > 0 and (" attrs=" .. table.concat(out, ",")) or ""
end

local function logRiftInstance(inst, source)
    if not inst or not inst.Parent then return end
    local path = pathOf(inst)
    if not hasKey(inst.Name) then return end -- v1.0 log ลูก UI ทุกชิ้นเพราะ parent มีคำว่า Rift
    local key = source .. ":" .. path
    if S.seen[key] then return end
    S.seen[key] = true
    local pos = positionOf(inst)
    local ptext = pos and string.format(" pos=(%.0f,%.0f,%.0f)", pos.X, pos.Y, pos.Z) or ""
    say(string.format("RIFT OBJ %s <%s>%s%s", path, inst.ClassName, ptext, attrsOf(inst)))
    for _, prompt in ipairs(inst:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            say(string.format("RIFT PROMPT action=%q object=%q hold=%.1f path=%s", prompt.ActionText, prompt.ObjectText, prompt.HoldDuration, pathOf(prompt)))
        end
    end
end

local function bindRiftButton(inst)
    if S.buttonBound[inst] or not (inst:IsA("TextButton") or inst:IsA("ImageButton")) then return end
    if not hasKey(pathOf(inst)) then return end
    S.buttonBound[inst] = true
    S.watchConns[#S.watchConns + 1] = inst.Activated:Connect(function()
        S.lastRiftClick = os.clock()
        say(string.format("RIFT UI CLICK name=%q text=%q path=%s", inst.Name, inst:IsA("TextButton") and inst.Text or "", pathOf(inst)))
    end)
end

local function scanTree(root, source)
    local count = 0
    for _, inst in ipairs(root:GetDescendants()) do
        local before = #lines
        logRiftInstance(inst, source)
        if #lines > before then count = count + 1 end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") then
            if hasKey(inst.Text) then
                local key = source .. ":ui:" .. pathOf(inst) .. ":" .. inst.Text
                if not S.seen[key] then
                    S.seen[key] = true
                    say("RIFT UI text=" .. string.format("%q", inst.Text) .. " path=" .. pathOf(inst))
                    count = count + 1
                end
            end
        end
        bindRiftButton(inst)
    end
    return count
end

local function bindRemote(remote)
    if S.remoteBound[remote] then return end
    if not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then return end
    S.remoteBound[remote] = true
    S.watchConns[#S.watchConns + 1] = remote.OnClientEvent:Connect(function(...)
        if hasKey(pathOf(remote)) or argsHaveKey(...) then
            local values = {}
            for i = 1, math.min(5, select("#", ...)) do values[#values + 1] = compact(select(i, ...)) end
            say("RIFT REMOTE " .. pathOf(remote) .. " ← " .. table.concat(values, " | "))
        end
    end)
end

local function readRiftState()
    local remote, candidates = nil, 0
    for _, inst in ipairs(RS:GetDescendants()) do
        if inst.Name == "AskState" then
            candidates = candidates + 1
            local path = pathOf(inst)
            if hasKey(path) then remote = inst break end
        end
    end
    if not remote then say("ไม่พบ AskState ของ Rift (AskState ทั้งหมด=" .. candidates .. ")") return end
    say("RIFT STATE CALL " .. pathOf(remote) .. " <" .. remote.ClassName .. ">")
    local ok, result = pcall(function() return remote:InvokeServer() end)
    if ok then
        say("RIFT STATE ← " .. compact(result))
    else
        say("RIFT STATE error: " .. tostring(result))
    end
end

local function scanAll()
    local world = scanTree(workspace, "WS")
    local repl = scanTree(RS, "RS")
    local ui = scanTree(PG, "UI")
    for _, inst in ipairs(RS:GetDescendants()) do bindRemote(inst) end
    say(string.format("SCAN Rift objects=%d | RS=%d | UI=%d | remotes=%d", world, repl, ui, #S.watchConns))
end

local function stopWatch()
    S.run = false
    for _, c in ipairs(S.watchConns) do pcall(function() c:Disconnect() end) end
    S.watchConns, S.remoteBound, S.buttonBound = {}, {}, {}
end

-- Hook นี้อ่าน FireServer/InvokeServer เท่านั้น และเขียน log เฉพาะ Rift หรือหลังคลิก Rift 2 วินาที
_G.EGG01_RIFT_HOOK_LOG = function(remote, method, ...)
    local active = _G.EGG01_RIFT_SPY
    if not active or not active.run then return end
    if method ~= "FireServer" and method ~= "InvokeServer" then return end
    local nearClick = os.clock() - (active.lastRiftClick or 0) <= 2
    if not nearClick and not hasKey(pathOf(remote)) and not argsHaveKey(...) then return end
    local values = {}
    for i = 1, math.min(6, select("#", ...)) do values[#values + 1] = compact(select(i, ...)) end
    say("RIFT OUT " .. method .. " " .. pathOf(remote) .. " → " .. table.concat(values, " | "))
end

if hookmetamethod and getnamecallmethod and not _G.EGG01_RIFT_SPY_HOOKED then
    _G.EGG01_RIFT_SPY_HOOKED = true
    local oldNamecall
    local wrap = newcclosure or function(fn) return fn end
    oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent")) then
            pcall(_G.EGG01_RIFT_HOOK_LOG, self, method, ...)
        end
        return oldNamecall(self, ...)
    end))
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_RiftSpy"; gui.ResetOnSpawn = false; gui.DisplayOrder = 1012
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 470, 0, 300); panel.Position = UDim2.new(0, 12, 0.35, 0)
panel.BackgroundColor3 = Color3.fromRGB(17, 20, 28); panel.BackgroundTransparency = 0.08; panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -42, 0, 28); title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1; title.Text = "Egg01 Rift Spy v1.3 — READ ONLY"; title.TextColor3 = Color3.fromRGB(210, 175, 255)
title.Font = Enum.Font.GothamBold; title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left

local function button(text, x, color)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 70, 0, 28); b.Position = UDim2.new(0, x, 0, 37)
    b.BackgroundColor3 = color; b.BorderSizePixel = 0; b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bScan = button("STATE", 10, Color3.fromRGB(48, 98, 170))
local bStart = button("START", 87, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 164, Color3.fromRGB(165, 50, 55))
local bClear = button("CLEAR", 241, Color3.fromRGB(75, 75, 80))
local bCopy = button("COPY", 318, Color3.fromRGB(75, 75, 80))
local bClose = button("X", 396, Color3.fromRGB(125, 45, 45))

logBox = Instance.new("TextLabel", panel)
logBox.Size = UDim2.new(1, -16, 0, 218); logBox.Position = UDim2.new(0, 8, 0, 74)
logBox.BackgroundColor3 = Color3.fromRGB(5, 8, 12); logBox.BackgroundTransparency = 0.15; logBox.BorderSizePixel = 0
logBox.TextColor3 = Color3.fromRGB(175, 245, 185); logBox.Font = Enum.Font.Code; logBox.TextSize = 10
logBox.TextXAlignment = Enum.TextXAlignment.Left; logBox.TextYAlignment = Enum.TextYAlignment.Top; logBox.TextWrapped = false
Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 5)

bScan.MouseButton1Click:Connect(function() scanAll(); readRiftState() end)
bStart.MouseButton1Click:Connect(function()
    if S.run then return end
    S.run = true; bStart.Text = "ON"
    scanAll()
    S.watchConns[#S.watchConns + 1] = workspace.DescendantAdded:Connect(function(inst) logRiftInstance(inst, "WS+") end)
    S.watchConns[#S.watchConns + 1] = RS.DescendantAdded:Connect(function(inst) logRiftInstance(inst, "RS+"); bindRemote(inst) end)
    S.watchConns[#S.watchConns + 1] = PG.DescendantAdded:Connect(function(inst)
        bindRiftButton(inst)
        if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and hasKey(inst.Text) then
            say("RIFT UI+ text=" .. string.format("%q", inst.Text) .. " path=" .. pathOf(inst))
        end
    end)
    S.watchConns[#S.watchConns + 1] = PPS.PromptShown:Connect(function(prompt)
        say(string.format("PROMPT SHOWN action=%q object=%q path=%s", prompt.ActionText, prompt.ObjectText, pathOf(prompt)))
    end)
    S.watchConns[#S.watchConns + 1] = PPS.PromptTriggered:Connect(function(prompt, player)
        say(string.format("PROMPT TRIGGERED by=%s action=%q object=%q path=%s", player and player.Name or "?", prompt.ActionText, prompt.ObjectText, pathOf(prompt)))
    end)
    task.spawn(function()
        while S.run do task.wait(4); if S.run then scanAll() end end
    end)
    say("WATCH ON — ไม่กด/ไม่ยิง Remote/ไม่ขยับตัว")
end)
bStop.MouseButton1Click:Connect(function() stopWatch(); bStart.Text = "START"; say("WATCH OFF") end)
bClear.MouseButton1Click:Connect(function() lines = {}; S.seen = {}; logBox.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then pcall(clip, "=== Egg01 Rift Spy v1.3 ===\n" .. table.concat(lines, "\n")) end
    bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)
bClose.MouseButton1Click:Connect(function() stopWatch(); gui:Destroy(); _G.EGG01_RIFT_SPY = nil end)

say("พร้อม — กด STATE อ่าน Rift state | START แล้วกด Refresh/REROLL เอง 1 ครั้ง")
