-- Egg01 Attack Chase Test v1.3
-- AUTO ไล่ตีคนที่ไม่ใช่เพื่อน; SKIP FRIEND ✓ คือไม่ตี Roblox Friends
if _G.EGG01_ATTACK_CHASE then
    _G.EGG01_ATTACK_CHASE.run = false
    pcall(function() _G.EGG01_ATTACK_CHASE.gui:Destroy() end)
end
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local S = { gui = nil, run = false, selected = nil, lastHit = 0, lines = {}, skipFriends = true, friendCache = {} }
_G.EGG01_ATTACK_CHASE = S
local RANGE, COOLDOWN = 9, .85
local function mine()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end
local function targetParts(p)
    local c = p and p.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end
local function bat()
    local c = LP.Character
    if not c then return nil end
    for _, v in ipairs(c:GetChildren()) do if v:IsA("Tool") and v.Name:lower():find("bat", 1, true) then return v end end
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "Egg01_AttackChaseTest", false, 1021
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui
local panel = Instance.new("Frame", gui)
panel.Size, panel.Position = UDim2.new(0, 410, 0, 145), UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = Color3.fromRGB(20, 23, 28), .08, 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local title = Instance.new("TextLabel", panel)
title.Size, title.Position, title.BackgroundTransparency = UDim2.new(1, -45, 0, 27), UDim2.new(0, 10, 0, 4), 1
title.Text, title.TextColor3, title.Font, title.TextSize, title.TextXAlignment = "Egg01 Attack Chase Test v1.3", Color3.new(1, 1, 1), Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left
local function button(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size, b.Position, b.BackgroundColor3, b.BorderSizePixel = UDim2.new(0, w, 0, 29), UDim2.new(0, x, 0, y), color, 0
    b.Text, b.TextColor3, b.Font, b.TextSize = text, Color3.new(1, 1, 1), Enum.Font.GothamBold, 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local bNext = button("NEXT", 10, 37, 65, Color3.fromRGB(55, 105, 165))
local bStart = button("START", 82, 37, 70, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 159, 37, 62, Color3.fromRGB(165, 50, 50))
local bCopy = button("COPY", 228, 37, 62, Color3.fromRGB(75, 75, 80))
local bFriends = button("SKIP FRIEND ✓", 297, 37, 100, Color3.fromRGB(105, 75, 165))
local bClose = button("X", 365, 4, 32, Color3.fromRGB(125, 45, 45))
local targetLabel = Instance.new("TextLabel", panel)
targetLabel.Size, targetLabel.Position, targetLabel.BackgroundTransparency = UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 74), 1
targetLabel.TextColor3, targetLabel.Font, targetLabel.TextSize, targetLabel.TextXAlignment = Color3.fromRGB(255, 220, 105), Enum.Font.GothamBold, 12, Enum.TextXAlignment.Left
local status = targetLabel:Clone(); status.Position = UDim2.new(0, 10, 0, 100); status.Size = UDim2.new(1, -20, 0, 35); status.TextColor3 = Color3.fromRGB(150, 235, 165); status.TextWrapped = true; status.TextYAlignment = Enum.TextYAlignment.Top; status.Parent = panel
local function say(t)
    S.lines[#S.lines + 1] = tostring(t); if #S.lines > 80 then table.remove(S.lines, 1) end; status.Text = tostring(t)
end
local function isFriend(p)
    local cached = S.friendCache[p.UserId]
    if cached ~= nil then return cached end
    local ok, result = pcall(function() return LP:IsFriendsWith(p.UserId) end)
    local value = ok and result == true
    S.friendCache[p.UserId] = value
    return value
end
local function candidates()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and (not S.skipFriends or not isFriend(p)) then out[#out + 1] = p end
    end
    table.sort(out, function(a, b) return a.Name < b.Name end)
    return out
end
local function nearestCandidate(from)
    local best, bestD
    for _, p in ipairs(candidates()) do
        local h, r = targetParts(p)
        if h and r and h.Health > 0 then
            local d = (r.Position - from).Magnitude
            if not bestD or d < bestD then best, bestD = p, d end
        end
    end
    return best, bestD
end
local function chooseNext()
    local list = candidates()
    if #list == 0 then S.selected = nil; targetLabel.Text = "ไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์"; return end
    local i = 0
    for n, p in ipairs(list) do if p == S.selected then i = n break end end
    S.selected = list[i % #list + 1]
    targetLabel.Text = "TARGET: " .. S.selected.Name .. " (UserId " .. S.selected.UserId .. ")"
    say("เลือก " .. S.selected.Name)
end
local function run()
    if S.run then return end
    local h, r = mine()
    local tool = bat()
    if not h or not r then say("ไม่พบตัวละครเรา") return end
    if not tool then say("ถือ Bat ก่อน แล้วค่อย START") return end
    local first = nearestCandidate(r.Position)
    if not first then say(S.skipFriends and "ไม่มีคนที่ไม่ใช่เพื่อนในเซิร์ฟเวอร์" or "ไม่มีผู้เล่นอื่นในเซิร์ฟเวอร์") return end
    S.run, S.lastHit = true, 0
    bStart.Text = "AUTO"
    task.spawn(function()
        say("AUTO ON | " .. (S.skipFriends and "ไม่ตีเพื่อน" or "ตีทุกคน") .. " | ระยะตี " .. RANGE)
        while S.run do
            local mh, mr = mine(); tool = bat()
            if not mh or not mr then say("ไม่พบตัวละครเรา") break end
            if not tool then say("Bat หลุดมือ") break end
            local nextTarget = nearestCandidate(mr.Position)
            if not nextTarget then
                S.selected = nil
                targetLabel.Text = S.skipFriends and "ไม่มีคนที่ไม่ใช่เพื่อนที่มีตัวละคร" or "ไม่มีผู้เล่นอื่นที่มีตัวละคร"
                task.wait(.5)
                continue
            end
            if nextTarget ~= S.selected then
                S.selected = nextTarget
                targetLabel.Text = "TARGET: " .. nextTarget.Name .. " (UserId " .. nextTarget.UserId .. ")"
                say("เป้าใหม่: " .. nextTarget.Name)
            end
            local eh, er = targetParts(S.selected)
            if not eh or not er or eh.Health <= 0 then task.wait(.12); continue end
            local d = (er.Position - mr.Position).Magnitude
            -- อัปเดตจุดวิ่งทุก loop แม้อยู่ในระยะตี: ไม่ยืนหยุดก่อนฟาด
            mh:MoveTo(Vector3.new(er.Position.X, mr.Position.Y, er.Position.Z))
            if d <= RANGE and os.clock() - S.lastHit >= COOLDOWN then
                local ok, err = pcall(function() tool:Activate() end)
                S.lastHit = os.clock()
                say(ok and string.format("Bat:Activate → %s d=%.1f", S.selected.Name, d) or "Activate error: " .. tostring(err))
            end
            task.wait(.12)
        end
        S.run = false; bStart.Text = "START"
    end)
end
bNext.MouseButton1Click:Connect(chooseNext)
bStart.MouseButton1Click:Connect(run)
bStop.MouseButton1Click:Connect(function() S.run = false; say("STOP") end)
bFriends.MouseButton1Click:Connect(function()
    S.skipFriends = not S.skipFriends
    bFriends.Text = S.skipFriends and "SKIP FRIEND ✓" or "SKIP FRIEND ✗"
    bFriends.BackgroundColor3 = S.skipFriends and Color3.fromRGB(105, 75, 165) or Color3.fromRGB(105, 65, 65)
    say(S.skipFriends and "โหมด: ไม่ตีเพื่อน" or "โหมด: ตีทุกคน")
end)
bCopy.MouseButton1Click:Connect(function() local c = setclipboard or toclipboard; if c then pcall(c, "=== Egg01 Attack Chase Test v1.3 ===\n" .. table.concat(S.lines, "\n")) end; bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end) end)
bClose.MouseButton1Click:Connect(function() S.run = false; gui:Destroy(); _G.EGG01_ATTACK_CHASE = nil end)
chooseNext()
