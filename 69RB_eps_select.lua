-- 69RB_eps_select.lua  v1.0.0
-- EPS AimLock + เลือกเป้าเอง
-- [P] = เปิด/ปิดล็อค  |  คลิกชื่อ = เลือกเป้า  |  AUTO = ล็อคอัตโนมัติใน FOV

-- ==================== Single-Instance Guard ====================
if _G.EPS69_CONNS then
    for _, c in pairs(_G.EPS69_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.EPS69_GUI  then pcall(function() _G.EPS69_GUI:Destroy() end) end
if _G.EPS69_DRAW then pcall(function() _G.EPS69_DRAW:Remove() end) end
_G.EPS69_CONNS = {}

local V = "1.0.0"

local Players = game:GetService("Players")
local RunSvc  = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Cam     = workspace.CurrentCamera
local LP      = Players.LocalPlayer

-- ==================== Config ====================
local CFG = {
    Smooth      = 0.35,   -- 0=instant, 0.9=smooth มาก
    Sensitivity = 100,    -- pixels/radian
    AimPart     = "Head", -- "Head" | "HumanoidRootPart" | "UpperTorso"
    MaxDist     = 1000,
    Key         = Enum.KeyCode.P,
    FOVRadius   = 180,    -- px radius วงกลม auto-select
}

-- ==================== State ====================
local enabled  = false
local target   = nil    -- Player object (MANUAL mode)
local autoMode = false  -- true = auto-pick nearest ใน FOV

-- ==================== GUI ====================
local sg = Instance.new("ScreenGui")
sg.Name = "EPS69"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = LP.PlayerGui
_G.EPS69_GUI = sg

local panel = Instance.new("Frame")
panel.Size     = UDim2.new(0, 185, 0, 310)
panel.Position = UDim2.new(0, 10, 0.5, -155)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Active    = true
panel.Draggable = true
panel.Parent    = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
do local s = Instance.new("UIStroke", panel)
    s.Color = Color3.fromRGB(55, 55, 80); s.Thickness = 1 end

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size  = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size  = UDim2.new(1, -8, 1, 0)
titleLbl.Position = UDim2.new(0, 8, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = Color3.fromRGB(160, 160, 255)
titleLbl.Text  = "EPS AimLock v" .. V
titleLbl.TextScaled = true
titleLbl.Font  = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

-- Status
local statusLbl = Instance.new("TextLabel")
statusLbl.Size  = UDim2.new(1, -12, 0, 20)
statusLbl.Position = UDim2.new(0, 6, 0, 36)
statusLbl.BackgroundTransparency = 1
statusLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
statusLbl.Text  = "OFF  [P]"
statusLbl.TextScaled = true
statusLbl.Font  = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = panel

-- Mode button (MANUAL / AUTO toggle)
local modeBtn = Instance.new("TextButton")
modeBtn.Size   = UDim2.new(1, -12, 0, 24)
modeBtn.Position = UDim2.new(0, 6, 0, 60)
modeBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 90)
modeBtn.TextColor3 = Color3.fromRGB(110, 170, 255)
modeBtn.Text   = "Mode: MANUAL"
modeBtn.TextScaled = true
modeBtn.Font   = Enum.Font.GothamBold
modeBtn.BorderSizePixel = 0
modeBtn.Parent = panel
Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 5)

-- List header
local listHdr = Instance.new("TextLabel")
listHdr.Size  = UDim2.new(1, -12, 0, 16)
listHdr.Position = UDim2.new(0, 6, 0, 88)
listHdr.BackgroundTransparency = 1
listHdr.TextColor3 = Color3.fromRGB(80, 80, 110)
listHdr.Text  = "Target List:"
listHdr.TextScaled = true
listHdr.Font  = Enum.Font.Gotham
listHdr.TextXAlignment = Enum.TextXAlignment.Left
listHdr.Parent = panel

-- Scrolling player list
local scroll = Instance.new("ScrollingFrame")
scroll.Size   = UDim2.new(1, -12, 0, 175)
scroll.Position = UDim2.new(0, 6, 0, 108)
scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
scroll.BackgroundTransparency = 0.2
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 100)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 5)
Instance.new("UIListLayout", scroll).Padding  = UDim.new(0, 2)
Instance.new("UIPadding",    scroll).PaddingAll = UDim.new(0, 3)

-- Footer hint
local hintLbl = Instance.new("TextLabel")
hintLbl.Size  = UDim2.new(1, -12, 0, 18)
hintLbl.Position = UDim2.new(0, 6, 1, -22)
hintLbl.BackgroundTransparency = 1
hintLbl.TextColor3 = Color3.fromRGB(55, 55, 75)
hintLbl.Text  = "[P] toggle  |  drag to move"
hintLbl.TextScaled = true
hintLbl.Font  = Enum.Font.Gotham
hintLbl.Parent = panel

-- ==================== Helpers ====================
local function isAlive(p)
    if not p or not p.Character then return false end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function getAimPos(p)
    if not p or not p.Character then return nil end
    local part = p.Character:FindFirstChild(CFG.AimPart)
               or p.Character:FindFirstChild("HumanoidRootPart")
    return part and part.Position
end

local function screenCenter()
    local v = Cam.ViewportSize
    return Vector2.new(v.X * 0.5, v.Y * 0.5)
end

local function inFOV(worldPos)
    local sp, vis = Cam:WorldToScreenPoint(worldPos)
    if not vis then return false, nil end
    local s2 = Vector2.new(sp.X, sp.Y)
    return (s2 - screenCenter()).Magnitude <= CFG.FOVRadius, s2
end

local function getAutoTarget()
    local best, bestDist = nil, math.huge
    local camPos = Cam.CFrame.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isAlive(p) then
            local pos = getAimPos(p)
            if pos and (pos - camPos).Magnitude <= CFG.MaxDist then
                local ok, s2 = inFOV(pos)
                if ok then
                    local d = (s2 - screenCenter()).Magnitude
                    if d < bestDist then bestDist = d; best = p end
                end
            end
        end
    end
    return best
end

-- ==================== Status display ====================
local function updateStatus()
    if not enabled then
        statusLbl.Text       = "OFF  [" .. CFG.Key.Name .. "]"
        statusLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
        titleLbl.TextColor3  = Color3.fromRGB(160, 160, 255)
    else
        local tName = autoMode and "AUTO" or (target and target.Name or "none")
        statusLbl.Text       = "ON  → " .. tName
        statusLbl.TextColor3 = Color3.fromRGB(60, 255, 110)
        titleLbl.TextColor3  = Color3.fromRGB(60, 255, 110)
    end
end

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
            btn.Size   = UDim2.new(1, 0, 0, 26)
            btn.BackgroundColor3 = sel
                and Color3.fromRGB(25, 65, 35)
                or  Color3.fromRGB(20, 20, 30)
            btn.BackgroundTransparency = 0.05
            btn.TextColor3 = sel  and Color3.fromRGB(60, 230, 100)
                or (alive and Color3.fromRGB(165, 165, 185)
                           or  Color3.fromRGB(110, 70,  70))
            btn.Text  = (sel and "► " or "  ") .. (alive and "● " or "○ ") .. p.Name
            btn.TextScaled = true
            btn.Font  = sel and Enum.Font.GothamBold or Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.BorderSizePixel = 0
            btn.Parent = scroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

            btn.MouseButton1Click:Connect(function()
                -- ออกจาก AUTO เมื่อคลิกชื่อ
                if autoMode then
                    autoMode = false
                    modeBtn.Text = "Mode: MANUAL"
                    modeBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 90)
                    modeBtn.TextColor3 = Color3.fromRGB(110, 170, 255)
                end
                -- คลิกซ้ำ = deselect
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
        modeBtn.Text = ("AUTO [FOV %dpx]"):format(CFG.FOVRadius)
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

table.insert(_G.EPS69_CONNS, Players.PlayerAdded:Connect(function()
    rebuildList()
end))
table.insert(_G.EPS69_CONNS, Players.PlayerRemoving:Connect(function(p)
    if target == p then target = nil end
    rebuildList()
    updateStatus()
end))

-- ==================== Aim Loop ====================
local lastRefresh = 0

table.insert(_G.EPS69_CONNS, RunSvc.RenderStepped:Connect(function(dt)
    -- อัป UI list ทุก 0.5s (HP / สี)
    lastRefresh += dt
    if lastRefresh >= 0.5 then
        lastRefresh = 0
        for p, btn in pairs(pBtns) do
            if p and p.Parent then
                local sel   = (target == p)
                local alive = isAlive(p)
                btn.Text = (sel and "► " or "  ") .. (alive and "● " or "○ ") .. p.Name
                btn.TextColor3 = sel and Color3.fromRGB(60, 230, 100)
                    or (alive and Color3.fromRGB(165, 165, 185) or Color3.fromRGB(110, 70, 70))
                btn.BackgroundColor3 = sel and Color3.fromRGB(25, 65, 35) or Color3.fromRGB(20, 20, 30)
            end
        end
    end

    if not enabled then return end

    local tPlayer = autoMode and getAutoTarget() or target
    if not tPlayer or not isAlive(tPlayer) then return end

    local tPos = getAimPos(tPlayer)
    if not tPos then return end

    local look = Cam.CFrame.LookVector
    local toT  = (tPos - Cam.CFrame.Position).Unit

    -- Yaw / Pitch delta
    local dYaw = math.atan2(-toT.X, -toT.Z) - math.atan2(-look.X, -look.Z)
    if dYaw >  math.pi then dYaw -= 2 * math.pi end
    if dYaw < -math.pi then dYaw += 2 * math.pi end

    local dPitch = math.asin(math.clamp(toT.Y, -1, 1))
                 - math.asin(math.clamp(look.Y, -1, 1))

    local smooth = 1 - CFG.Smooth
    local dx =  dYaw   * CFG.Sensitivity * smooth
    local dy = -dPitch * CFG.Sensitivity * smooth

    if mousemoverel then mousemoverel(dx, dy) end
end))

-- ==================== Key Toggle ====================
table.insert(_G.EPS69_CONNS, UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == CFG.Key then
        enabled = not enabled
        updateStatus()
    end
end))

-- ==================== FOV Circle (Drawing API) ====================
if Drawing then
    local fov = Drawing.new("Circle")
    fov.Thickness    = 1
    fov.NumSides     = 60
    fov.Radius       = CFG.FOVRadius
    fov.Filled       = false
    fov.Color        = Color3.fromRGB(220, 220, 220)
    fov.Transparency = 1
    fov.Visible      = false
    _G.EPS69_DRAW    = fov

    table.insert(_G.EPS69_CONNS, RunSvc.RenderStepped:Connect(function()
        local v = Cam.ViewportSize
        fov.Position = Vector2.new(v.X * 0.5, v.Y * 0.5)
        fov.Visible  = enabled and autoMode
    end))
end

updateStatus()
print("[EPS69] AimLock v" .. V .. " loaded | [P] toggle | click name to pick target")
