-- 72RB_speed.lua — Run Speed (v1.0)
-- เริ่มใหม่: เอาเฉพาะความเร็ววิ่งก่อน (ยังไม่มี fly / noclip)
local Players, RS = game:GetService("Players"), game:GetService("RunService")
local LP = Players.LocalPlayer

local RUN, SPEED = false, 50
local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end

-- single-instance guard
if _G.RBSPD_CONNS then for _, c in pairs(_G.RBSPD_CONNS) do pcall(function() c:Disconnect() end) end end
_G.RBSPD_CONNS = {}
local CONNS = _G.RBSPD_CONNS
local function bind(s, f) local c = s:Connect(f); CONNS[#CONNS+1] = c end
pcall(function() ((gethui and gethui()) or LP.PlayerGui):FindFirstChild("RBSPDGUI"):Destroy() end)

-- บังคับ WalkSpeed ทุก frame (กันเกม reset + respawn)
bind(RS.Heartbeat, function()
    if RUN then local h = hum(); if h then h.WalkSpeed = SPEED end end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "RBSPDGUI", false, 9999
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0,190,0,150), UDim2.new(0,20,0.5,-75)
f.BackgroundColor3, f.BackgroundTransparency = Color3.fromRGB(18,18,24), 0.1
f.BorderSizePixel, f.Active, f.Draggable = 0, true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", f).Color = Color3.fromRGB(90,120,255)

local title = Instance.new("TextLabel", f)
title.Size, title.Position = UDim2.new(1,-12,0,26), UDim2.new(0,8,0,4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(150,180,255)
title.Text, title.Font, title.TextSize = "RUN SPEED", Enum.Font.GothamBold, 16
title.TextXAlignment = Enum.TextXAlignment.Left

local function btn(txt, x, y, w, h, col)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0,w,0,h), UDim2.new(0,x,0,y)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3 = col or Color3.fromRGB(45,45,58)
    b.TextColor3, b.BorderSizePixel = Color3.fromRGB(255,255,255), 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    Instance.new("UIPadding", b).PaddingTop = UDim.new(0,4)
    return b
end

local runB = btn("RUN: OFF", 10, 36, 170, 38)
runB.MouseButton1Click:Connect(function()
    RUN = not RUN
    runB.Text = "RUN: " .. (RUN and "ON" or "OFF")
    runB.BackgroundColor3 = RUN and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if not RUN then local h = hum(); if h then h.WalkSpeed = 16 end end  -- คืนค่าปกติ
end)

local spdL = btn(tostring(SPEED), 10, 82, 90, 36); spdL.Active = false
local minus = btn("−", 106, 82, 36, 36)
local plus  = btn("+", 144, 82, 36, 36)
minus.MouseButton1Click:Connect(function()
    SPEED = math.max(16, SPEED - 10); spdL.Text = tostring(SPEED)
end)
plus.MouseButton1Click:Connect(function()
    SPEED = SPEED + 10; spdL.Text = tostring(SPEED)
end)

local closeB = btn("CLOSE", 10, 122, 170, 24, Color3.fromRGB(120,30,30))
closeB.MouseButton1Click:Connect(function()
    RUN = false
    local h = hum(); if h then h.WalkSpeed = 16 end
    for _, c in pairs(CONNS) do pcall(function() c:Disconnect() end) end
    _G.RBSPD_CONNS = nil
    gui:Destroy()
end)

print("[72RB Run Speed v1.0] พร้อม")
