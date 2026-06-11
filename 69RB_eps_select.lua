-- 69RB_eps_select.lua  v2.0.0
-- EPS AimLock — แกนเดียวกับ 06 ALL IN Watch mode (hookmetamethod camera override)
-- [E] = เปิด/ปิดล็อค | คลิกชื่อ = เลือกเป้า | AUTO = ล็อคคนใกล้สุดที่มองเห็น
-- เล็งส่วนร่างกายที่ "ไม่โดนกำแพงบัง" อัตโนมัติ (Head → Torso → แขนขา)

-- ==================== Single-Instance Guard ====================
if _G.EPS69_CONNS then
    for _, c in pairs(_G.EPS69_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.EPS69_GUI  then pcall(function() _G.EPS69_GUI:Destroy() end) end
if _G.EPS69_DRAW then pcall(function() _G.EPS69_DRAW:Remove() end) end
_G.EPS69_CONNS = {}
_G.EPS69_AIM_CFRAME = nil   -- รีเซ็ตเป้า (hook เก่ายังอยู่ได้ ไม่ stack)

local V = "2.0.0"

local Players = game:GetService("Players")
local RunSvc  = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local World   = workspace
local LP      = Players.LocalPlayer
local Camera  = workspace.CurrentCamera

local cf_lookAt = CFrame.lookAt
local math_huge = math.huge

-- ==================== Config ====================
local CFG = {
    MaxDist = 500,
    Key     = Enum.KeyCode.E,
    -- ลำดับส่วนที่ลองเล็ง (เจอส่วนแรกที่ไม่โดนบัง = เล็งส่วนนั้น)
    PartsR15 = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso",
                "RightUpperArm", "LeftUpperArm", "RightUpperLeg", "LeftUpperLeg"},
    PartsR6  = {"Head", "Torso", "HumanoidRootPart",
                "Right Arm", "Left Arm", "Right Leg", "Left Leg"},
}

-- ==================== State ====================
local enabled  = false
local target   = nil     -- Player (MANUAL)
local autoMode = false

-- ==================== Camera Hook (แบบ 06 ALL IN) ====================
-- hook ครั้งเดียวต่อ session — รัน script ซ้ำไม่ stack hook
if not _G.EPS69_HOOKED and hookmetamethod then
    local lpName = LP.Name
    local oldNewIndex
    oldNewIndex = hookmetamethod(game, "__newindex", function(t, k, v)
        if _G.EPS69_AIM_CFRAME and k == "CFrame" then
            if t == workspace.CurrentCamera then
                return oldNewIndex(t, k, _G.EPS69_AIM_CFRAME.Rotation + v.Position)
            end
            -- Viewmodel (Workspace.HandModel.<name>.HumanoidRootPart) ให้มือ/ปืนหันตาม
            if t.Name == "HumanoidRootPart" then
                local p1 = t.Parent
                if p1 and p1.Name == lpName then
                    local p2 = p1.Parent
                    if p2 and p2.Name == "HandModel" then
                        return oldNewIndex(t, k, _G.EPS69_AIM_CFRAME.Rotation + v.Position)
                    end
                end
            end
        end
        return oldNewIndex(t, k, v)
    end)
    _G.EPS69_HOOKED = true
end

-- ==================== Raycast params ====================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function setIgnore(targetChar)
    local list = {}
    if LP.Character then list[1] = LP.Character end
    if targetChar   then list[#list+1] = targetChar end
    rayParams.FilterDescendantsInstances = list
end

-- ==================== Helpers ====================
local function isAlive(p)
    if not p or not p.Character then return false end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

-- หา "ส่วนที่มองเห็น" (ไม่โดนกำแพงบัง) ตามลำดับ priority
-- คืน part ที่เห็น หรือ nil ถ้าโดนบังหมดทุกส่วน
local function getVisiblePart(char, fromPos)
    local parts = char:FindFirstChild("UpperTorso") and CFG.PartsR15 or CFG.PartsR6
    setIgnore(char)
    for i = 1, #parts do
        local part = char:FindFirstChild(parts[i])
        if part then
            local hit = World:Raycast(fromPos, part.Position - fromPos, rayParams)
            if not hit then return part end
        end
    end
    return nil
end

-- AUTO: คนใกล้สุดที่มีส่วนมองเห็นได้
local function getAutoTarget(fromPos)
    local best, bestPart, bestD = nil, nil, math_huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isAlive(p) then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (root.Position - fromPos).Magnitude
                if d <= CFG.MaxDist and d < bestD then
                    local part = getVisiblePart(p.Character, fromPos)
                    if part then best, bestPart, bestD = p, part, d end
                end
            end
        end
    end
    return best, bestPart
end

-- ==================== GUI ====================
local sg = Instance.new("ScreenGui")
sg.Name = "EPS69"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = LP.PlayerGui
_G.EPS69_GUI = sg

local panel = Instance.new("Frame")
panel.Size     = UDim2.new(0, 185, 0, 320)
panel.Position = UDim2.new(0, 10, 0.5, -160)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Active    = true
panel.Draggable = true
panel.Parent    = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
do local s = Instance.new("UIStroke", panel)
    s.Color = Color3.fromRGB(55, 55, 80); s.Thickness = 1 end

local titleBar = Instance.new("Frame")
titleBar.Size  = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size  = UDim2.new(1, -8, 1, 0)
titleLbl.Position = UDim2.new(0, 8, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = Color3.fromRGB(160, 160, 255)
titleLbl.Text  = "EPS Lock v" .. V
titleLbl.TextScaled = true
titleLbl.Font  = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

-- ปุ่ม ON/OFF ใหญ่ (คลิกได้ + กด E ได้)
local togBtn = Instance.new("TextButton")
togBtn.Size   = UDim2.new(1, -12, 0, 30)
togBtn.Position = UDim2.new(0, 6, 0, 34)
togBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
togBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
togBtn.Text   = "Lock OFF [E]"
togBtn.TextScaled = true
togBtn.Font   = Enum.Font.GothamBold
togBtn.BorderSizePixel = 0
togBtn.Parent = panel
Instance.new("UICorner", togBtn).CornerRadius = UDim.new(0, 5)

-- ปุ่ม Mode
local modeBtn = Instance.new("TextButton")
modeBtn.Size   = UDim2.new(1, -12, 0, 24)
modeBtn.Position = UDim2.new(0, 6, 0, 68)
modeBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 90)
modeBtn.TextColor3 = Color3.fromRGB(110, 170, 255)
modeBtn.Text   = "Mode: MANUAL"
modeBtn.TextScaled = true
modeBtn.Font   = Enum.Font.GothamBold
modeBtn.BorderSizePixel = 0
modeBtn.Parent = panel
Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 5)

-- สถานะเป้า (เล็งส่วนไหนอยู่)
local aimLbl = Instance.new("TextLabel")
aimLbl.Size  = UDim2.new(1, -12, 0, 16)
aimLbl.Position = UDim2.new(0, 6, 0, 95)
aimLbl.BackgroundTransparency = 1
aimLbl.TextColor3 = Color3.fromRGB(80, 80, 110)
aimLbl.Text  = "aim: -"
aimLbl.TextScaled = true
aimLbl.Font  = Enum.Font.Gotham
aimLbl.TextXAlignment = Enum.TextXAlignment.Left
aimLbl.Parent = panel

-- รายชื่อ
local scroll = Instance.new("ScrollingFrame")
scroll.Size   = UDim2.new(1, -12, 0, 178)
scroll.Position = UDim2.new(0, 6, 0, 113)
scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
scroll.BackgroundTransparency = 0.2
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 5)
Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 2)

local hintLbl = Instance.new("TextLabel")
hintLbl.Size  = UDim2.new(1, -12, 0, 16)
hintLbl.Position = UDim2.new(0, 6, 1, -20)
hintLbl.BackgroundTransparency = 1
hintLbl.TextColor3 = Color3.fromRGB(55, 55, 75)
hintLbl.Text  = "คลิกชื่อ=เลือก | คลิกซ้ำ=ยกเลิก"
hintLbl.TextScaled = true
hintLbl.Font  = Enum.Font.Gotham
hintLbl.Parent = panel

-- ==================== Status ====================
local function updateStatus()
    if enabled then
        local tName = autoMode and "AUTO" or (target and target.Name or "เลือกเป้าก่อน!")
        togBtn.Text = "Lock ON [E] → " .. tName
        togBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
        togBtn.TextColor3 = Color3.fromRGB(220, 255, 220)
    else
        togBtn.Text = "Lock OFF [E]"
        togBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
        togBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        aimLbl.Text = "aim: -"
    end
end

local function toggle()
    enabled = not enabled
    if not enabled then _G.EPS69_AIM_CFRAME = nil end
    updateStatus()
end

togBtn.MouseButton1Click:Connect(toggle)

-- ==================== Player List ====================
local pBtns = {}

local function rebuildList()
    for _, b in pairs(pBtns) do b:Destroy() end
    pBtns = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local sel   = (target == p)
            local alive = isAlive(p)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -6, 0, 26)
            btn.BackgroundColor3 = sel and Color3.fromRGB(25, 65, 35) or Color3.fromRGB(20, 20, 30)
            btn.TextColor3 = sel and Color3.fromRGB(60, 230, 100)
                or (alive and Color3.fromRGB(165, 165, 185) or Color3.fromRGB(110, 70, 70))
            btn.Text = (sel and "► " or "  ") .. (alive and "● " or "○ ") .. p.Name
            btn.TextScaled = true
            btn.Font = sel and Enum.Font.GothamBold or Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.BorderSizePixel = 0
            btn.Parent = scroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

            btn.MouseButton1Click:Connect(function()
                if autoMode then
                    autoMode = false
                    modeBtn.Text = "Mode: MANUAL"
                    modeBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 90)
                    modeBtn.TextColor3 = Color3.fromRGB(110, 170, 255)
                end
                target = (target == p) and nil or p
                rebuildList()
                updateStatus()
            end)
            pBtns[p] = btn
        end
    end
end
rebuildList()

modeBtn.MouseButton1Click:Connect(function()
    autoMode = not autoMode
    if autoMode then
        target = nil
        modeBtn.Text = "Mode: AUTO (ใกล้สุด+เห็นตัว)"
        modeBtn.BackgroundColor3 = Color3.fromRGB(55, 35, 80)
        modeBtn.TextColor3 = Color3.fromRGB(190, 140, 255)
    else
        modeBtn.Text = "Mode: MANUAL"
        modeBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 90)
        modeBtn.TextColor3 = Color3.fromRGB(110, 170, 255)
    end
    rebuildList()
    updateStatus()
end)

table.insert(_G.EPS69_CONNS, Players.PlayerAdded:Connect(rebuildList))
table.insert(_G.EPS69_CONNS, Players.PlayerRemoving:Connect(function(p)
    if target == p then target = nil end
    rebuildList()
    updateStatus()
end))

-- ==================== Main Loop ====================
local lastListRefresh = 0
local lastAimPartName = nil

table.insert(_G.EPS69_CONNS, RunSvc.RenderStepped:Connect(function(dt)
    -- refresh list สี/สถานะทุก 0.5s
    lastListRefresh += dt
    if lastListRefresh >= 0.5 then
        lastListRefresh = 0
        for p, btn in pairs(pBtns) do
            if p and p.Parent then
                local sel, alive = (target == p), isAlive(p)
                btn.Text = (sel and "► " or "  ") .. (alive and "● " or "○ ") .. p.Name
                btn.TextColor3 = sel and Color3.fromRGB(60, 230, 100)
                    or (alive and Color3.fromRGB(165, 165, 185) or Color3.fromRGB(110, 70, 70))
            end
        end
    end

    if not enabled then return end

    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then _G.EPS69_AIM_CFRAME = nil return end
    local fromPos = myRoot.Position

    -- หาเป้า + ส่วนที่มองเห็น
    local tPlayer, tPart
    if autoMode then
        tPlayer, tPart = getAutoTarget(fromPos)
    else
        tPlayer = target
        if tPlayer and isAlive(tPlayer) then
            local d = (tPlayer.Character.HumanoidRootPart.Position - fromPos).Magnitude
            if d <= CFG.MaxDist then
                tPart = getVisiblePart(tPlayer.Character, fromPos)
                -- โดนบังหมดทุกส่วน → ล็อคหัวไว้ก่อน (รอโผล่)
                if not tPart then tPart = tPlayer.Character:FindFirstChild("Head") end
            end
        end
    end

    if tPlayer and tPart then
        _G.EPS69_AIM_CFRAME = cf_lookAt(Camera.CFrame.Position, tPart.Position)
        if tPart.Name ~= lastAimPartName then
            lastAimPartName = tPart.Name
            aimLbl.Text = "aim: " .. tPart.Name
        end
    else
        _G.EPS69_AIM_CFRAME = nil
        if lastAimPartName then lastAimPartName = nil aimLbl.Text = "aim: -" end
    end
end))

-- ==================== Key Toggle (IsKeyDown polling) ====================
local keyWasDown = false
table.insert(_G.EPS69_CONNS, RunSvc.RenderStepped:Connect(function()
    local isDown = UIS:IsKeyDown(CFG.Key)
    if isDown and not keyWasDown then toggle() end
    keyWasDown = isDown
end))

updateStatus()
print("[EPS69] v" .. V .. " loaded | hook=" .. tostring(_G.EPS69_HOOKED == true)
    .. " | [E] หรือคลิกปุ่ม Lock | เล็งส่วนที่ไม่โดนกำแพงบัง")
