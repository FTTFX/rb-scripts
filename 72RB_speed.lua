-- 72RB_speed.lua — Run Speed + Jump + Win Farm (v1.5)
-- v1.5: WIN FARM ยิงทุก WinBlock ทุก stage พร้อมกัน (อันท้ายๆคะแนนเยอะ) firetouchinterest
-- v1.4: WIN FARM = firetouchinterest แผ่น Structure.*.WinBlock* (spy ยืนยัน win=touch ไม่มี remote)
-- v1.3: JUMP impulse ปรับความสูงได้ (default 30) + ดับเบิล/มัลติจัม (กด space กลางอากาศ) เหมือน 06RB
local Players, RS, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local LP = Players.LocalPlayer

local RUN, SPEED = false, 50
local INFJ, lastJump, JUMP_VAL = false, 0, 30
local WIN, WIN_CD, lastWinFire = false, 1.0, 0
local fti = firetouchinterest
local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

local winPads
local function getWinPads()
    if winPads and winPads[1] and winPads[1].Parent then return winPads end
    winPads = {}
    local root = workspace:FindFirstChild("Structure") or workspace
    for _, v in ipairs(root:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("winblock") then winPads[#winPads+1] = v end
    end
    return winPads
end

-- single-instance guard
if _G.RBSPD_CONNS then for _, c in pairs(_G.RBSPD_CONNS) do pcall(function() c:Disconnect() end) end end
_G.RBSPD_CONNS = {}
local CONNS = _G.RBSPD_CONNS
local function bind(s, f) local c = s:Connect(f); CONNS[#CONNS+1] = c end
pcall(function() ((gethui and gethui()) or LP.PlayerGui):FindFirstChild("RBSPDGUI"):Destroy() end)

-- บังคับ WalkSpeed ทุก frame (กันเกม reset + respawn)
bind(RS.Heartbeat, function()
    if RUN then local h = hum(); if h then h.WalkSpeed = SPEED end end
    if WIN and fti then
        local now = os.clock()
        if now - lastWinFire >= WIN_CD then
            lastWinFire = now
            local root = hrp()
            if root then
                for _, pad in ipairs(getWinPads()) do pcall(fti, root, pad, 0); pcall(fti, root, pad, 1) end
            end
        end
    end
end)

-- JUMP: อัด velocity ขึ้นทุกครั้งที่กด space (กลางอากาศก็ได้ = ดับเบิล/มัลติจัม), สูงตาม JUMP_VAL
bind(UIS.JumpRequest, function()
    if not INFJ then return end
    local h, root = hum(), hrp()
    if not h or not root then return end
    local now = os.clock()
    if now - lastJump > 0.1 then
        lastJump = now
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(v.X, JUMP_VAL, v.Z)
        h:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "RBSPDGUI", false, 9999
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0,190,0,316), UDim2.new(0,20,0.5,-158)
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

local jumpB = btn("JUMP: OFF", 10, 124, 170, 32)
jumpB.MouseButton1Click:Connect(function()
    INFJ = not INFJ
    jumpB.Text = "JUMP: " .. (INFJ and "ON" or "OFF")
    jumpB.BackgroundColor3 = INFJ and Color3.fromRGB(40,120,160) or Color3.fromRGB(45,45,58)
end)

local jValL = btn(tostring(JUMP_VAL), 10, 162, 90, 32); jValL.Active = false
local jMinus = btn("−", 106, 162, 36, 32)
local jPlus  = btn("+", 144, 162, 36, 32)
jMinus.MouseButton1Click:Connect(function()
    JUMP_VAL = math.max(10, JUMP_VAL - 10); jValL.Text = tostring(JUMP_VAL)
end)
jPlus.MouseButton1Click:Connect(function()
    JUMP_VAL = JUMP_VAL + 10; jValL.Text = tostring(JUMP_VAL)
end)

local winB = btn("WIN FARM: OFF", 10, 202, 170, 32)
winB.MouseButton1Click:Connect(function()
    if not fti then winB.Text = "ไม่รองรับ fti"; return end
    local n = #getWinPads()
    if not WIN and n == 0 then winB.Text = "ไม่เจอแผ่น win"; return end
    WIN = not WIN
    lastWinFire = 0
    winB.Text = WIN and ("WIN FARM: ON ("..n..")") or "WIN FARM: OFF"
    winB.BackgroundColor3 = WIN and Color3.fromRGB(150,40,150) or Color3.fromRGB(45,45,58)
end)

local cdL = btn(("%.1fs"):format(WIN_CD), 10, 240, 90, 32); cdL.Active = false
local cdMinus = btn("−", 106, 240, 36, 32)
local cdPlus  = btn("+", 144, 240, 36, 32)
cdMinus.MouseButton1Click:Connect(function()
    WIN_CD = math.max(0.2, WIN_CD - 0.2); cdL.Text = ("%.1fs"):format(WIN_CD)
end)
cdPlus.MouseButton1Click:Connect(function()
    WIN_CD = WIN_CD + 0.2; cdL.Text = ("%.1fs"):format(WIN_CD)
end)

local closeB = btn("CLOSE", 10, 280, 170, 24, Color3.fromRGB(120,30,30))
closeB.MouseButton1Click:Connect(function()
    RUN, WIN, INFJ = false, false, false
    local h = hum(); if h then h.WalkSpeed = 16 end
    for _, c in pairs(CONNS) do pcall(function() c:Disconnect() end) end
    _G.RBSPD_CONNS = nil
    gui:Destroy()
end)

print("[72RB Run Speed + Jump + WinFarm v1.5] พร้อม")
