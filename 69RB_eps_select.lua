-- 69RB_eps_select.lua  v2.3.1
-- [,] = เป้าก่อนหน้า | [.] = เป้าถัดไป | [E] = เปิด/ปิดล็อค
-- EPS AimLock — แกนเดียวกับ 06 ALL IN Watch mode (hookmetamethod camera override)
-- ESP ทุกคน (แดง=คนอื่น เขียว=เป้าที่เลือก) | คลิกชื่อ = เลือกเป้า | AUTO = ใกล้สุดที่เห็น
-- เล็งส่วนร่างกายที่ "ไม่โดนกำแพงบัง" อัตโนมัติ (Head → Torso → แขนขา)

-- ==================== Single-Instance Guard ====================
if _G.EPS69_CONNS then
    for _, c in pairs(_G.EPS69_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.EPS69_HLS then
    for _, hl in pairs(_G.EPS69_HLS) do pcall(function() hl:Destroy() end) end
end
if _G.EPS69_GUI  then pcall(function() _G.EPS69_GUI:Destroy() end) end
if _G.EPS69_DRAW then pcall(function() _G.EPS69_DRAW:Remove() end) end
_G.EPS69_CONNS = {}
_G.EPS69_HLS   = {}
_G.EPS69_AIM_CFRAME = nil   -- รีเซ็ตเป้า (hook เก่ายังอยู่ได้ ไม่ stack)

local V = "2.3.1"

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

-- ==================== ESP (Highlight ทุกคน) ====================
local HLS = _G.EPS69_HLS

local function colorHL(p)
    local hl = HLS[p]
    if not hl then return end
    -- บังคับทะลุกำแพงซ้ำทุกรอบ กันเกม/script อื่น override
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled   = true
    if target == p then
        hl.FillColor    = Color3.fromRGB(40, 255, 90)    -- เป้าที่เลือก = เขียว
        hl.OutlineColor = Color3.fromRGB(180, 255, 200)
    else
        hl.FillColor    = Color3.fromRGB(255, 40, 40)    -- คนอื่น = แดง
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    end
end

local function addHL(p)
    local char = p.Character
    if not char then return end
    local hl = HLS[p]
    if hl and hl.Parent == char then colorHL(p) return end
    if hl then pcall(function() hl:Destroy() end) end
    hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    HLS[p] = hl
    colorHL(p)
end

local function removeHL(p)
    local hl = HLS[p]
    if hl then pcall(function() hl:Destroy() end) HLS[p] = nil end
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
panel.Size     = UDim2.new(0, 185, 0, 352)
panel.Position = UDim2.new(0, 10, 0.5, -176)
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

-- ปุ่ม STOP ฉุกเฉิน — ปิด 69 + ปิด 06 ALL IN ด้วย
local stopBtn = Instance.new("TextButton")
stopBtn.Size   = UDim2.new(1, -12, 0, 28)
stopBtn.Position = UDim2.new(0, 6, 0, 95)
stopBtn.BackgroundColor3 = Color3.fromRGB(140, 25, 25)
stopBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
stopBtn.Text   = "■ STOP ปิดทุกอย่าง (รวม 06)"
stopBtn.TextScaled = true
stopBtn.Font   = Enum.Font.GothamBold
stopBtn.BorderSizePixel = 0
stopBtn.Parent = panel
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 5)

-- สถานะเป้า (เล็งส่วนไหนอยู่)
local aimLbl = Instance.new("TextLabel")
aimLbl.Size  = UDim2.new(1, -12, 0, 16)
aimLbl.Position = UDim2.new(0, 6, 0, 127)
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
scroll.Position = UDim2.new(0, 6, 0, 145)
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
hintLbl.Text  = "คลิกชื่อ=เลือก | [,]=ก่อนหน้า [.]=ถัดไป"
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

togBtn.Activated:Connect(toggle)

-- ==================== Player List ====================
local pBtns = {}

local function rebuildList()
    for _, b in pairs(pBtns) do b:Destroy() end
    pBtns = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            addHL(p)   -- ESP ทุกคน + สีตามเป้าที่เลือก
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

            btn.Activated:Connect(function()
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

-- STOP: ปิด 69 + ฆ่า 06 ALL IN ทั้งตัว (camera lock, shoot, speed, ESP)
stopBtn.Activated:Connect(function()
    enabled = false
    target  = nil
    _G.EPS69_AIM_CFRAME = nil
    -- ฆ่า 06 ALL IN ถ้ารันอยู่
    _G.RB06_AIM_CFRAME = nil
    if _G.RB06_CONNS then
        for _, c in pairs(_G.RB06_CONNS) do pcall(function() c:Disconnect() end) end
        _G.RB06_CONNS = nil
    end
    for _, hl in pairs(_G.RB06_HL or {}) do pcall(function() hl:Destroy() end) end
    _G.RB06_HL = nil
    if _G.RB06_BV then pcall(function() _G.RB06_BV:Destroy() end) _G.RB06_BV = nil end
    local g06 = LP.PlayerGui:FindFirstChild("HLGUI")
    if g06 then g06:Destroy() end
    rebuildList()
    updateStatus()
    stopBtn.Text = "✓ ปิดหมดแล้ว"
    task.delay(1.5, function() stopBtn.Text = "■ STOP ปิดทุกอย่าง (รวม 06)" end)
end)

modeBtn.Activated:Connect(function()
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
    removeHL(p)
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
                addHL(p)   -- ซ่อม ESP หลัง respawn + อัปสี
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

-- ==================== Target Cycle [,] [.] ====================
local function cycleTarget(dir)
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then list[#list+1] = p end
    end
    if #list == 0 then return end
    if autoMode then
        autoMode = false
        modeBtn.Text = "Mode: MANUAL"
        modeBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 90)
        modeBtn.TextColor3 = Color3.fromRGB(110, 170, 255)
    end
    local idx = 0
    for i, p in ipairs(list) do
        if p == target then idx = i break end
    end
    idx = idx + dir
    if idx < 1 then idx = #list elseif idx > #list then idx = 1 end
    target = list[idx]
    rebuildList()
    updateStatus()
end

-- ==================== Keys (IsKeyDown polling) ====================
-- [E] = toggle lock | [,] = เป้าก่อนหน้า | [.] = เป้าถัดไป
local keyWas = {}
local function pollKey(kc, fn)
    local isDown = UIS:IsKeyDown(kc)
    if isDown and not keyWas[kc] then fn() end
    keyWas[kc] = isDown
end

table.insert(_G.EPS69_CONNS, RunSvc.RenderStepped:Connect(function()
    pollKey(CFG.Key, toggle)
    pollKey(Enum.KeyCode.Comma,  function() cycleTarget(-1) end)
    pollKey(Enum.KeyCode.Period, function() cycleTarget(1)  end)
end))

updateStatus()
print("[EPS69] v" .. V .. " loaded | hook=" .. tostring(_G.EPS69_HOOKED == true)
    .. " | [E] หรือคลิกปุ่ม Lock | เล็งส่วนที่ไม่โดนกำแพงบัง")
