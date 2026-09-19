-- Egg01 Attack Spy v1.0: observe manual attacks only; never sends a remote.
if _G.EGG01_ATTACK_SPY then
    _G.EGG01_ATTACK_SPY.on = false
    pcall(function() _G.EGG01_ATTACK_SPY.gui:Destroy() end)
    for _, c in ipairs(_G.EGG01_ATTACK_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
end
local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local S = { gui = nil, conns = {}, on = true, lines = {} }
_G.EGG01_ATTACK_SPY = S
local function interesting(s)
    s = tostring(s):lower()
    for _, k in ipairs({ "attack", "hit", "damage", "combat", "weapon", "bat", "swing", "knock", "pvp" }) do
        if s:find(k, 1, true) then return true end
    end
    return false
end
local function path(v)
    local ok, p = pcall(function() return v:GetFullName() end)
    return ok and p:gsub("^ReplicatedStorage%.", "RS."):gsub("^Workspace%.", "WS.") or tostring(v)
end
local function show(v, depth)
    depth = depth or 0
    if typeof(v) == "Instance" then return "<" .. v.ClassName .. ":" .. path(v) .. ">" end
    if typeof(v) == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z) end
    if typeof(v) == "CFrame" then return string.format("CF(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z) end
    if typeof(v) == "table" then
        if depth > 1 then return "{...}" end
        local out, n = {}, 0
        for k, x in pairs(v) do n += 1; if n > 7 then out[#out + 1] = "..." break end; out[#out + 1] = tostring(k) .. "=" .. show(x, depth + 1) end
        return "{" .. table.concat(out, ",") .. "}"
    end
    return tostring(v)
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "Egg01_AttackSpy", false, 1020
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui
local box = Instance.new("TextBox", gui)
box.Size, box.Position = UDim2.new(0, 650, 0, 350), UDim2.new(0, 12, .2, 0)
box.BackgroundColor3, box.BackgroundTransparency, box.TextColor3 = Color3.new(0, 0, 0), .15, Color3.fromRGB(190, 245, 190)
box.TextSize, box.Font, box.TextEditable, box.ClearTextOnFocus = 11, Enum.Font.Code, false, false
box.MultiLine, box.TextWrapped, box.TextXAlignment, box.TextYAlignment = true, false, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
local function log(m)
    if not S.on then return end
    S.lines[#S.lines + 1] = string.format("[%6.2f] %s", os.clock(), tostring(m))
    if #S.lines > 220 then table.remove(S.lines, 1) end
    box.Text, box.CursorPosition = table.concat(S.lines, "\n"), #table.concat(S.lines, "\n") + 1
end
local function button(text, x, w, color)
    local b = Instance.new("TextButton", gui)
    b.Size, b.Position, b.BackgroundColor3 = UDim2.new(0, w, 0, 30), UDim2.new(0, x, .2, -34), color
    b.Text, b.TextColor3, b.Font, b.TextSize = text, Color3.new(1, 1, 1), Enum.Font.GothamBold, 12
    return b
end
local bList = button("LIST", 12, 70, Color3.fromRGB(50, 105, 165))
local bStart = button("START", 88, 70, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 164, 70, Color3.fromRGB(165, 50, 50))
local bClear = button("CLEAR", 240, 70, Color3.fromRGB(80, 80, 80))
local bCopy = button("COPY", 316, 70, Color3.fromRGB(80, 80, 80))
local bClose = button("X", 392, 38, Color3.fromRGB(130, 45, 45))
local function list()
    local all, hit = 0, 0
    log("=== COMBAT REMOTES ===")
    for _, root in ipairs({ RS, workspace }) do
        for _, v in ipairs(root:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("UnreliableRemoteEvent") then
                all += 1
                if interesting(v.Name) or interesting(path(v)) then hit += 1; log("★ [" .. v.ClassName .. "] " .. path(v)) end
            end
        end
    end
    log(string.format("remote=%d combat-name=%d | ถือไม้ กด START แล้วตีด้วยมือ 3 ครั้ง", all, hit))
end
local function watchTool(x)
    if x:IsA("Tool") then S.conns[#S.conns + 1] = x.Activated:Connect(function() log("⚔ Tool.Activated " .. x.Name) end) end
end
local function watchChar(c)
    for _, x in ipairs(c:GetChildren()) do watchTool(x) end
    S.conns[#S.conns + 1] = c.ChildAdded:Connect(watchTool)
end
if LP.Character then watchChar(LP.Character) end
S.conns[#S.conns + 1] = LP.CharacterAdded:Connect(watchChar)
if not _G.EGG01_ATTACK_SPY_HOOK and hookmetamethod and getnamecallmethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if _G.EGG01_ATTACK_SPY and _G.EGG01_ATTACK_SPY.on and (method == "FireServer" or method == "InvokeServer") then
            local args, out = { ... }, {}
            for i = 1, math.min(select("#", ...), 8) do out[i] = show(args[i]) end
            local mark = (interesting(self.Name) or interesting(path(self))) and "★ " or ""
            log(mark .. method .. " " .. path(self) .. "(" .. table.concat(out, ", ") .. ")")
        end
        return old(self, ...)
    end)
    _G.EGG01_ATTACK_SPY_HOOK = true
end
bList.MouseButton1Click:Connect(list)
bStart.MouseButton1Click:Connect(function() S.on = true; log("SPY ON — ตีเพื่อนที่ยินยอมให้ทดสอบ 3 ครั้ง") end)
bStop.MouseButton1Click:Connect(function() S.on = false end)
bClear.MouseButton1Click:Connect(function() S.lines, box.Text = {}, "" end)
bCopy.MouseButton1Click:Connect(function() local c = setclipboard or toclipboard; if c then pcall(c, "=== Egg01 Attack Spy v1.0 ===\n" .. table.concat(S.lines, "\n")) end; bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end) end)
bClose.MouseButton1Click:Connect(function() S.on = false; for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end; gui:Destroy(); _G.EGG01_ATTACK_SPY = nil end)
log("LIST → ถือไม้ → START → ตีเพื่อนที่ยินยอม 3 ครั้ง → COPY")
