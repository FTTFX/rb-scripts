-- Egg01 Egg Intercept v1.0
-- ไล่ตีเป้าที่เลือก; หลังฟาดจะตรวจ Steal prompt ใกล้จุดเป้า ถ้าไข่ตก -> เก็บ -> กลับ HOME
if _G.EGG01_EGG_INTERCEPT then _G.EGG01_EGG_INTERCEPT.run = false; pcall(function() _G.EGG01_EGG_INTERCEPT.gui:Destroy() end) end
local Players = game:GetService("Players")
local LP, PG = Players.LocalPlayer, Players.LocalPlayer:WaitForChild("PlayerGui")
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local S = { gui = nil, run = false, home = nil, target = nil, lastHit = 0, scanUntil = 0, hitPos = nil, lines = {} }
_G.EGG01_EGG_INTERCEPT = S
local HIT_R, STEAL_R, DROP_R, HIT_CD = 9, 7, 45, .85
local function parts(p)
    local c = (p or LP).Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end
local function bat()
    local c = LP.Character
    if c then for _, x in ipairs(c:GetChildren()) do if x:IsA("Tool") and x.Name:lower():find("bat", 1, true) then return x end end end
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "Egg01_EggIntercept", false, 1022
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui
local panel = Instance.new("Frame", gui)
panel.Size, panel.Position = UDim2.new(0, 430, 0, 150), UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = Color3.fromRGB(20, 23, 28), .08, 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local title = Instance.new("TextLabel", panel)
title.Size, title.Position, title.BackgroundTransparency = UDim2.new(1, -45, 0, 27), UDim2.new(0, 10, 0, 4), 1
title.Text, title.TextColor3, title.Font, title.TextSize, title.TextXAlignment = "Egg01 Egg Intercept v1.0", Color3.new(1, 1, 1), Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left
local function button(text, x, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size, b.Position, b.BackgroundColor3, b.BorderSizePixel = UDim2.new(0, w, 0, 29), UDim2.new(0, x, 0, 37), color, 0
    b.Text, b.TextColor3, b.Font, b.TextSize = text, Color3.new(1, 1, 1), Enum.Font.GothamBold, 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local bHome, bNext, bStart = button("HOME", 10, 62, Color3.fromRGB(50, 105, 180)), button("NEXT", 79, 62, Color3.fromRGB(55, 105, 165)), button("START", 148, 68, Color3.fromRGB(35, 145, 75))
local bStop, bCopy, bClose = button("STOP", 223, 60, Color3.fromRGB(165, 50, 50)), button("COPY", 290, 60, Color3.fromRGB(75, 75, 80)), button("X", 385, 32, Color3.fromRGB(125, 45, 45))
local info = Instance.new("TextLabel", panel)
info.Size, info.Position, info.BackgroundTransparency = UDim2.new(1, -20, 0, 67), UDim2.new(0, 10, 0, 76), 1
info.TextColor3, info.Font, info.TextSize, info.TextWrapped, info.TextXAlignment, info.TextYAlignment = Color3.fromRGB(150, 235, 165), Enum.Font.GothamBold, 11, true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
local function say(x) S.lines[#S.lines + 1] = tostring(x); if #S.lines > 100 then table.remove(S.lines, 1) end; info.Text = tostring(x) end
local function players()
    local out = {}; for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then out[#out + 1] = p end end; table.sort(out, function(a,b) return a.Name < b.Name end); return out
end
local function nextTarget()
    local list = players(); if #list == 0 then S.target = nil; say("ไม่มีผู้เล่นอื่น") return end
    local n = 0; for i,p in ipairs(list) do if p == S.target then n = i break end end; S.target = list[n % #list + 1]
    say("เป้า: " .. S.target.Name .. " | ตั้ง HOME ถือ Bat แล้ว START")
end
local function posOfPrompt(pp)
    local p = pp.Parent
    local part = p and (p:IsA("BasePart") and p or p:FindFirstChildWhichIsA("BasePart", true))
    return part and part.Position
end
local function droppedPrompt(anchor)
    local best, bestD
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled and tostring(pp.ActionText):lower():find("steal", 1, true) then
            local pos = posOfPrompt(pp)
            if pos then local d = (pos - anchor).Magnitude; if d <= DROP_R and (not bestD or d < bestD) then best, bestD = { pp = pp, pos = pos }, d end end
        end
    end
    return best, bestD
end
local function walk(pos, radius, limit)
    local untilAt = os.clock() + limit
    while S.run and os.clock() < untilAt do
        local h, r = parts(); if not h or not r then return false end
        local goal = Vector3.new(pos.X, r.Position.Y, pos.Z)
        if (goal - r.Position).Magnitude <= radius then return true end
        h:MoveTo(goal); task.wait(.15)
    end
    return false
end
local function takeAndHome(egg, d)
    say(string.format("ไข่ตก d=%.1f — หยุดตี/ไปเก็บ", d))
    if not walk(egg.pos, STEAL_R, 10) then say("ไปถึงไข่ไม่สำเร็จ") return false end
    local old = egg.pp.HoldDuration; pcall(function() egg.pp.HoldDuration = 0; fp(egg.pp) end); pcall(function() egg.pp.HoldDuration = old end)
    say("กด Steal แล้ว — วิ่ง HOME")
    if S.home then return walk(S.home, 60, 120) end
end
local function start()
    if S.run then return end
    if not fp then say("executor ไม่มี fireproximityprompt") return end
    if not S.home then say("กด HOME ที่ฐานก่อน") return end
    if not S.target then nextTarget() end
    if not bat() then say("ถือ Bat ก่อน") return end
    S.run, S.lastHit, S.scanUntil, S.hitPos = true, 0, 0, nil; bStart.Text = "..."
    task.spawn(function()
        say("ไล่ " .. S.target.Name .. " — รอไข่ตกหลังตี")
        while S.run do
            local h, r = parts(); local eh, er = parts(S.target); local tool = bat()
            if not h or not r or not eh or not er or not tool then say("ตัวละคร/เป้าหาย หรือ Bat หลุด") break end
            if os.clock() < S.scanUntil and S.hitPos then
                local egg, d = droppedPrompt(S.hitPos)
                if egg then takeAndHome(egg, d); break end
            end
            local d = (er.Position - r.Position).Magnitude
            h:MoveTo(Vector3.new(er.Position.X, r.Position.Y, er.Position.Z))
            if d <= HIT_R and os.clock() - S.lastHit >= HIT_CD then
                S.lastHit, S.hitPos, S.scanUntil = os.clock(), er.Position, os.clock() + 3
                pcall(function() tool:Activate() end)
                say(string.format("ตี %s d=%.1f — เฝ้าไข่ตก 3s", S.target.Name, d))
            end
            task.wait(.12)
        end
        S.run = false; bStart.Text = "START"
    end)
end
bHome.MouseButton1Click:Connect(function() local _,r=parts(); if r then S.home=r.Position; say("HOME ตั้งแล้ว") end end)
bNext.MouseButton1Click:Connect(nextTarget)
bStart.MouseButton1Click:Connect(start)
bStop.MouseButton1Click:Connect(function() S.run=false; say("STOP") end)
bCopy.MouseButton1Click:Connect(function() local c=setclipboard or toclipboard; if c then pcall(c,"=== Egg01 Egg Intercept v1.0 ===\n"..table.concat(S.lines,"\n")) end; bCopy.Text="OK"; task.delay(1,function() if bCopy.Parent then bCopy.Text="COPY" end end) end)
bClose.MouseButton1Click:Connect(function() S.run=false; gui:Destroy(); _G.EGG01_EGG_INTERCEPT=nil end)
nextTarget()
