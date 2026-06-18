-- 72RB_speed.lua — Run Speed + Jump + Auto Win (v2.0)
-- v2.0: AUTO WIN วิ่งไปเป้าเอง (Humanoid:Move world-space หันให้เอง ไม่ต้องเล็งกล้อง) → ใกล้แผ่นค่อย MoveTo เก็บ
-- v1.9: วิ่งด้วยปุ่ม W (ต้องเล็งกล้องเอง)
-- v1.7: + ปุ่ม ST เลือก stage/แผ่น (วนทุก WinBlock ใต้ Structure)
-- v1.5: ยิงทุก WinBlock ด้วย firetouchinterest (ไม่ขึ้น = เกมไม่ได้เช็คแค่ touch)
-- v1.3: JUMP impulse ปรับความสูงได้ (default 30) + ดับเบิล/มัลติจัม (กด space กลางอากาศ) เหมือน 06RB
local Players, RS, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local LP = Players.LocalPlayer

local RUN, SPEED = false, 50
local INFJ, lastJump, JUMP_VAL = false, 0, 30
local WIN, WIN_CD, lastWinFire = false, 1.0, 0
local fti = firetouchinterest
local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

local blocks = {}
local BIDX = 0          -- 0 = auto (spy/แผ่นแรก), >0 = เลือกเอง
local function refreshBlocks()
    blocks = {}
    local root = workspace:FindFirstChild("Structure") or workspace
    for _, v in ipairs(root:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("winblock") then blocks[#blocks+1] = v end
    end
    table.sort(blocks, function(a, b)   -- เรียงตามเลข stage แล้วชื่อแผ่น
        local na = tonumber((a.Parent and a.Parent.Name or ""):match("%d+")) or 0
        local nb = tonumber((b.Parent and b.Parent.Name or ""):match("%d+")) or 0
        if na ~= nb then return na < nb end
        return a.Name < b.Name
    end)
    return blocks
end
local function winTarget()
    if BIDX > 0 and blocks[BIDX] and blocks[BIDX].Parent then return blocks[BIDX] end
    if _G.WINSPY and _G.WINSPY.pad and _G.WINSPY.pad.Parent then return _G.WINSPY.pad end
    refreshBlocks(); return blocks[1]
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
    if WIN then
        local root, h, pad = hrp(), hum(), winTarget()
        if root and h and pad then
            local char = LP.Character           -- noclip ทะลุคีย์ที่ขวาง (พื้นยังยืนได้)
            if char then for _, p in pairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
            h.WalkSpeed = math.max(SPEED, 120)
            local to = pad.Position - root.Position
            if to.Magnitude < 20 then
                h:MoveTo(pad.Position)          -- ใกล้แผ่นเป้า → เดินเข้าเก็บคะแนน → วาปกลับ → วนเอง
            else
                local dir = Vector3.new(to.X, 0, to.Z)
                if dir.Magnitude > 0 then h:Move(dir.Unit, false) end  -- วิ่งไปเป้าเอง หันให้เอง ไม่ต้องเล็งกล้อง
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
f.Size, f.Position = UDim2.new(0,190,0,354), UDim2.new(0,20,0.5,-177)
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

local winB = btn("AUTO WIN: OFF", 10, 202, 170, 32)
local function unclip()
    local char = LP.Character
    if char then for _, p in pairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
end
winB.MouseButton1Click:Connect(function()
    if not WIN and not winTarget() then winB.Text = "ไม่เจอแผ่น"; return end
    WIN = not WIN
    if not WIN then unclip() end
    winB.Text = "AUTO WIN: " .. (WIN and "ON" or "OFF")
    winB.BackgroundColor3 = WIN and Color3.fromRGB(150,40,150) or Color3.fromRGB(45,45,58)
end)

-- STAGE selector: กดวนไปทุก WinBlock ใต้ Structure (0=auto ใช้ spy)
local stB = btn("ST: auto >", 10, 240, 170, 32)
local function stLabel()
    if BIDX == 0 then return "ST: auto >" end
    local b = blocks[BIDX]
    return b and ("ST: "..(b.Parent and b.Parent.Name or "?").."/"..b.Name.." >") or "ST: ?"
end
stB.MouseButton1Click:Connect(function()
    refreshBlocks()
    if #blocks == 0 then stB.Text = "ไม่เจอแผ่น"; return end
    BIDX = BIDX + 1
    if BIDX > #blocks then BIDX = 0 end   -- วนกลับ auto
    stB.Text = stLabel()
end)

local cdL = btn(("%.1fs"):format(WIN_CD), 10, 278, 90, 32); cdL.Active = false
local cdMinus = btn("−", 106, 278, 36, 32)
local cdPlus  = btn("+", 144, 278, 36, 32)
cdMinus.MouseButton1Click:Connect(function()
    WIN_CD = math.max(0.2, WIN_CD - 0.2); cdL.Text = ("%.1fs"):format(WIN_CD)
end)
cdPlus.MouseButton1Click:Connect(function()
    WIN_CD = WIN_CD + 0.2; cdL.Text = ("%.1fs"):format(WIN_CD)
end)

local closeB = btn("CLOSE", 10, 318, 170, 24, Color3.fromRGB(120,30,30))
closeB.MouseButton1Click:Connect(function()
    RUN, WIN, INFJ = false, false, false
    unclip()
    local h = hum(); if h then h.WalkSpeed = 16 end
    for _, c in pairs(CONNS) do pcall(function() c:Disconnect() end) end
    _G.RBSPD_CONNS = nil
    gui:Destroy()
end)

print("[72RB Run Speed + Jump + AutoWin v2.0] พร้อม")
