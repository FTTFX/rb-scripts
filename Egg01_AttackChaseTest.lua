-- Egg01 Attack Chase Test v1.4.2
-- ฐาน v1.4 + ถือไม้แบบเงียบ (Humanoid:EquipTool อย่างเดียว — ไม่กดปุ่ม / ไม่ noclip)
if _G.EGG01_ATTACK_CHASE then
    _G.EGG01_ATTACK_CHASE.run = false
    pcall(function() _G.EGG01_ATTACK_CHASE.gui:Destroy() end)
end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local S = { gui = nil, run = false, selected = nil, lastHit = 0, lines = {}, picked = {}, menu = nil, lastEquip = 0 }
_G.EGG01_ATTACK_CHASE = S

local RANGE, COOLDOWN = 9, .85
local EQUIP_EVERY = 0.6

local function mine()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function targetParts(p)
    local c = p and p.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function findBat()
    local c = LP.Character
    if c then
        for _, v in ipairs(c:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower():find("bat", 1, true) then return v, "hand" end
        end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower():find("bat", 1, true) then return v, "bag" end
        end
    end
    return nil
end

-- ถือไม้เงียบ: EquipTool อย่างเดียว ไม่ส่งปุ่ม
local function ensureBat()
    local tool, where = findBat()
    if tool and where == "hand" then return tool end
    if tool and where == "bag" then
        local h = select(1, mine())
        if h then pcall(function() h:EquipTool(tool) end) end
        tool = select(1, findBat())
        if tool and tool.Parent == LP.Character then return tool end
    end
    return nil
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
title.Text, title.TextColor3, title.Font, title.TextSize, title.TextXAlignment =
    "Egg01 Attack Chase Test v1.4.2", Color3.new(1, 1, 1), Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left

local function button(text, x, y, w, color)
    local b = Instance.new("TextButton", panel)
    b.Size, b.Position, b.BackgroundColor3, b.BorderSizePixel = UDim2.new(0, w, 0, 29), UDim2.new(0, x, 0, y), color, 0
    b.Text, b.TextColor3, b.Font, b.TextSize = text, Color3.new(1, 1, 1), Enum.Font.GothamBold, 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bList = button("LIST", 10, 37, 65, Color3.fromRGB(55, 105, 165))
local bStart = button("START", 82, 37, 70, Color3.fromRGB(35, 145, 75))
local bStop = button("STOP", 159, 37, 62, Color3.fromRGB(165, 50, 50))
local bCopy = button("COPY", 228, 37, 62, Color3.fromRGB(75, 75, 80))
local bClear = button("CLEAR", 297, 37, 62, Color3.fromRGB(105, 75, 165))
local bClose = button("X", 365, 4, 32, Color3.fromRGB(125, 45, 45))

local targetLabel = Instance.new("TextLabel", panel)
targetLabel.Size, targetLabel.Position, targetLabel.BackgroundTransparency = UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 74), 1
targetLabel.TextColor3, targetLabel.Font, targetLabel.TextSize, targetLabel.TextXAlignment =
    Color3.fromRGB(255, 220, 105), Enum.Font.GothamBold, 12, Enum.TextXAlignment.Left
targetLabel.Text = "ติ๊กชื่อจาก LIST ก่อน START"
local status = targetLabel:Clone()
status.Position, status.Size, status.TextColor3, status.TextWrapped, status.TextYAlignment =
    UDim2.new(0, 10, 0, 100), UDim2.new(1, -20, 0, 35), Color3.fromRGB(150, 235, 165), true, Enum.TextYAlignment.Top
status.Parent = panel

local menu = Instance.new("ScrollingFrame", gui)
menu.Name, menu.Position, menu.Size, menu.Visible = "TargetList", UDim2.new(0, 12, 0, 162), UDim2.new(0, 280, 0, 250), false
menu.BackgroundColor3, menu.BorderSizePixel, menu.ScrollBarThickness = Color3.fromRGB(35, 39, 48), 0, 5
menu.CanvasSize, menu.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 6)
S.menu = menu

Instance.new("UIListLayout", menu).Padding = UDim.new(0, 2)
local listPad = Instance.new("UIPadding", menu)
listPad.PaddingTop, listPad.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)

local function say(t)
    S.lines[#S.lines + 1] = tostring(t)
    if #S.lines > 80 then table.remove(S.lines, 1) end
    status.Text = tostring(t)
end

local function playerList()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then out[#out + 1] = p end end
    table.sort(out, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return out
end

local function chosenList()
    local out = {}
    for _, p in ipairs(playerList()) do if S.picked[p.UserId] then out[#out + 1] = p end end
    return out
end

local function chosenCount()
    local n = 0
    for _ in pairs(S.picked) do n = n + 1 end
    return n
end

local function setTarget(p, why)
    S.selected = p
    targetLabel.Text = "TARGET: " .. p.Name .. " (" .. tostring(p.UserId) .. ")"
    if why then say(why .. p.Name) end
end

local function advanceTarget()
    local list = chosenList()
    if #list == 0 then S.selected = nil; return nil end
    local current = 0
    for i, p in ipairs(list) do if p == S.selected then current = i break end end
    local nextPlayer = list[current % #list + 1]
    setTarget(nextPlayer, "เป้าถัดไป: ")
    return nextPlayer
end

local function renderList()
    for _, ch in ipairs(menu:GetChildren()) do if ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end end
    local list = playerList()
    if #list == 0 then
        local empty = Instance.new("TextLabel", menu)
        empty.Size, empty.BackgroundTransparency, empty.Text = UDim2.new(1, -8, 0, 26), 1, "ไม่มีผู้เล่นอื่น"
        empty.TextColor3, empty.Font, empty.TextSize = Color3.new(1, 1, 1), Enum.Font.Gotham, 12
        return
    end
    for _, p in ipairs(list) do
        local b = Instance.new("TextButton", menu)
        b.Size, b.BackgroundColor3, b.BorderSizePixel = UDim2.new(1, -8, 0, 25), Color3.fromRGB(52, 56, 67), 0
        b.TextColor3, b.Font, b.TextSize, b.TextXAlignment = Color3.new(1, 1, 1), Enum.Font.GothamBold, 12, Enum.TextXAlignment.Left
        local mark = S.picked[p.UserId] and "✓" or "□"
        b.Text = "  " .. mark .. "  " .. p.Name .. "  (" .. tostring(p.UserId) .. ")"
        b.MouseButton1Click:Connect(function()
            S.picked[p.UserId] = not S.picked[p.UserId] or nil
            if S.selected == p and not S.picked[p.UserId] then S.selected = nil end
            renderList()
            say(string.format("เลือกเป้า %d คน", chosenCount()))
        end)
    end
end

local function run()
    if S.run then return end
    if #chosenList() == 0 then say("ติ๊กชื่ออย่างน้อย 1 คนจาก LIST") return end
    local h, r = mine()
    if not h or not r then say("ไม่พบตัวละครเรา") return end
    if not ensureBat() then say("หา Bat ในมือ/กระเป๋าไม่เจอ") return end
    S.run, S.lastHit, S.lastEquip = true, 0, 0
    bStart.Text = "AUTO"
    task.spawn(function()
        say("AUTO ON — ถือไม้เงียบ (EquipTool) | วนตี " .. tostring(#chosenList()) .. " คน")
        while S.run do
            local mh, mr = mine()
            if not mh or not mr then say("ไม่พบตัวละครเรา") break end

            if os.clock() - S.lastEquip >= EQUIP_EVERY then
                S.lastEquip = os.clock()
                ensureBat()
            end
            local tool = ensureBat()
            if not tool then
                say("Bat หลุด — รอ EquipTool")
                task.wait(0.2)
                continue
            end

            local target = S.selected
            local th, tr = targetParts(target)
            if not target or not S.picked[target.UserId] or not th or not tr or th.Health <= 0 then
                target = advanceTarget()
                th, tr = targetParts(target)
                if not target or not th or not tr or th.Health <= 0 then task.wait(.25); continue end
            end
            local d = (tr.Position - mr.Position).Magnitude
            mh:MoveTo(Vector3.new(tr.Position.X, mr.Position.Y, tr.Position.Z))
            if d <= RANGE and os.clock() - S.lastHit >= COOLDOWN then
                local ok, err = pcall(function() tool:Activate() end)
                S.lastHit = os.clock()
                say(ok and string.format("ตี %s d=%.1f → เป้าถัดไป", target.Name, d) or "Activate error: " .. tostring(err))
                advanceTarget()
            end
            task.wait(.12)
        end
        S.run, bStart.Text = false, "START"
    end)
end

bList.MouseButton1Click:Connect(function() renderList(); menu.Visible = not menu.Visible end)
bStart.MouseButton1Click:Connect(run)
bStop.MouseButton1Click:Connect(function() S.run = false; say("STOP") end)
bClear.MouseButton1Click:Connect(function()
    S.picked, S.selected = {}, nil
    renderList()
    targetLabel.Text = "ติ๊กชื่อจาก LIST ก่อน START"
    say("ล้างรายชื่อเป้า")
end)
bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then pcall(c, "=== Egg01 Attack Chase Test v1.4.2 ===\n" .. table.concat(S.lines, "\n")) end
    bCopy.Text = "OK"; task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
end)
bClose.MouseButton1Click:Connect(function() S.run = false; gui:Destroy(); _G.EGG01_ATTACK_CHASE = nil end)
Players.PlayerAdded:Connect(function() if menu.Visible then renderList() end end)
Players.PlayerRemoving:Connect(function(p)
    S.picked[p.UserId] = nil
    if S.selected == p then S.selected = nil end
    if menu.Visible then renderList() end
end)

renderList()
say("v1.4.2 LIST→ติ๊ก→START | ถือไม้เงียบ EquipTool (ไม่กด1/ไม่noclip)")
