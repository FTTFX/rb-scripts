-- 79RB_Warp.lua v1.2 — บันทึกจุดและใช้แรงผลักความเร็วสูงกลับไปยังจุดที่บันทึก
-- คีย์ลัด (PC): P = บันทึกจุด, O = กลับจุด | มือถือ: ใช้ปุ่มบนจอ

if _G.WARP79_CONNS then
    for _, conn in ipairs(_G.WARP79_CONNS) do
        pcall(function() conn:Disconnect() end)
    end
end
if _G.WARP79_GUI then
    pcall(function() _G.WARP79_GUI:Destroy() end)
end
if _G.WARP79_PUSH then
    pcall(function() _G.WARP79_PUSH.conn:Disconnect() end)
    pcall(function() _G.WARP79_PUSH.mover:Destroy() end)
end

_G.WARP79_CONNS = {}
_G.WARP79_PUSH = nil
_G.WARP79_GEN = (_G.WARP79_GEN or 0) + 1
local MY_GEN = _G.WARP79_GEN

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local savedCFrame
local PUSH_SPEED = 250
local STOP_DISTANCE = 3

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local gui = Instance.new("ScreenGui")
gui.Name = "Warp79"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not gui.Parent then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
_G.WARP79_GUI = gui

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Parent = gui
frame.Size = UDim2.fromOffset(220, 148)
frame.Position = UDim2.new(0, 10, 0.5, -74)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
frame.BackgroundTransparency = 0.1
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 9)

local title = Instance.new("TextLabel")
title.Parent = frame
title.Size = UDim2.new(1, -34, 0, 27)
title.Position = UDim2.fromOffset(8, 3)
title.BackgroundTransparency = 1
title.Text = "📍 บันทึกจุดผลัก"
title.TextColor3 = Color3.fromRGB(150, 220, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = Instance.new("TextButton")
closeButton.Parent = frame
closeButton.Size = UDim2.fromOffset(26, 24)
closeButton.Position = UDim2.new(1, -29, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(115, 45, 45)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 13
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)

local function makeButton(text, y, color)
    local button = Instance.new("TextButton")
    button.Parent = frame
    button.Size = UDim2.new(1, -12, 0, 34)
    button.Position = UDim2.fromOffset(6, y)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
    return button
end

local saveButton = makeButton("บันทึกจุดนี้ (P)", 34, Color3.fromRGB(45, 125, 75))
local warpButton = makeButton("ผลักกลับจุดที่บันทึก (O)", 72, Color3.fromRGB(55, 100, 165))

local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = frame
statusLabel.Size = UDim2.new(1, -12, 0, 30)
statusLabel.Position = UDim2.fromOffset(6, 112)
statusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
statusLabel.Text = "ยังไม่ได้บันทึกจุด"
statusLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 6)

local function setStatus(text, color)
    statusLabel.Text = text
    statusLabel.TextColor3 = color or Color3.fromRGB(210, 210, 220)
end

local function savePoint()
    local root = getRoot()
    if not root then
        setStatus("ไม่พบตัวละคร", Color3.fromRGB(255, 120, 120))
        return
    end

    savedCFrame = root.CFrame
    local position = savedCFrame.Position
    setStatus(
        string.format("บันทึกแล้ว: %.0f, %.0f, %.0f", position.X, position.Y, position.Z),
        Color3.fromRGB(135, 255, 165)
    )
end

local function stopPush(message, color)
    local push = _G.WARP79_PUSH
    if push then
        pcall(function() push.conn:Disconnect() end)
        pcall(function() push.mover:Destroy() end)
        _G.WARP79_PUSH = nil
    end

    if message then
        setStatus(message, color)
    end
end

local function warpToPoint()
    if not savedCFrame then
        setStatus("กรุณาบันทึกจุดก่อน", Color3.fromRGB(255, 190, 100))
        return
    end

    local root = getRoot()
    if not root then
        setStatus("ไม่พบตัวละคร", Color3.fromRGB(255, 120, 120))
        return
    end

    stopPush()
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    local mover = Instance.new("BodyVelocity")
    mover.Name = "Warp79Push"
    mover.MaxForce = Vector3.new(1000000, 1000000, 1000000)
    mover.P = 15000
    mover.Parent = root

    local startedAt = os.clock()
    local startDistance = (savedCFrame.Position - root.Position).Magnitude
    local timeout = math.max(3, startDistance / PUSH_SPEED * 3)
    setStatus("กำลังผลักกลับไปยังจุดบันทึก...", Color3.fromRGB(135, 210, 255))

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if _G.WARP79_GEN ~= MY_GEN or not root.Parent then
            stopPush()
            return
        end

        local offset = savedCFrame.Position - root.Position
        local distance = offset.Magnitude
        if distance <= STOP_DISTANCE then
            root.AssemblyLinearVelocity = Vector3.zero
            stopPush("ถึงจุดบันทึกแล้ว", Color3.fromRGB(135, 255, 165))
            return
        end

        if os.clock() - startedAt >= timeout then
            stopPush("หยุดแล้ว: อาจติดสิ่งกีดขวาง", Color3.fromRGB(255, 190, 100))
            return
        end

        local speed = math.min(PUSH_SPEED, math.max(12, distance * 3))
        mover.Velocity = offset.Unit * speed
    end)

    _G.WARP79_PUSH = {
        conn = conn,
        mover = mover,
    }
    table.insert(_G.WARP79_CONNS, conn)
end

table.insert(_G.WARP79_CONNS, saveButton.MouseButton1Click:Connect(savePoint))
table.insert(_G.WARP79_CONNS, warpButton.MouseButton1Click:Connect(warpToPoint))

table.insert(_G.WARP79_CONNS, UserInputService.InputBegan:Connect(function(input, processed)
    if processed or _G.WARP79_GEN ~= MY_GEN then
        return
    end

    if input.KeyCode == Enum.KeyCode.P then
        savePoint()
    elseif input.KeyCode == Enum.KeyCode.O then
        warpToPoint()
    end
end))

table.insert(_G.WARP79_CONNS, closeButton.MouseButton1Click:Connect(function()
    stopPush()
    for _, conn in ipairs(_G.WARP79_CONNS) do
        pcall(function() conn:Disconnect() end)
    end
    _G.WARP79_CONNS = {}
    gui:Destroy()
    _G.WARP79_GUI = nil
end))

warn("[Warp79] v1.2 loaded — P บันทึกจุด / O ผลักกลับจุด (Speed 250)")
