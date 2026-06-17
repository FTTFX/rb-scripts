-- 70RB_flynoclip.lua — Fly + Noclip + AutoFarm (v2.0, มือถือ/ปุ่มจิ้ม)
-- v2.0: บินตามกล้อง (เงยขึ้น=ขึ้น, กดหน้า=ไปหน้า) | step speed x5 | FARM วงกลม Humanoid:Move
local Players, RS = game:GetService("Players"), game:GetService("RunService")
local LP = Players.LocalPlayer

local SPEED, FLY, bv = 60, false, nil
local FARM, RUNSPD, ang = false, 50, 0

-- single-instance guard
if _G.FLYNC then for _, c in pairs(_G.FLYNC) do pcall(function() c:Disconnect() end) end end
if _G.FLYNC_BV then pcall(function() _G.FLYNC_BV:Destroy() end) end
pcall(function() (gethui and gethui() or LP.PlayerGui).FLYNCGUI:Destroy() end)
_G.FLYNC = {}
local function bind(s, f) local c = s:Connect(f); _G.FLYNC[#_G.FLYNC+1] = c end

local function hrp() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end

local function startFly()
    local root = hrp(); if not root then FLY = false; return end
    for _, p in pairs(LP.Character:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    bv = Instance.new("BodyVelocity")
    bv.MaxForce, bv.Velocity = Vector3.new(1,1,1)*9e9, Vector3.zero
    bv.Parent = root; _G.FLYNC_BV = bv
end
local function stopFly()
    if bv then bv:Destroy(); bv = nil end
    local char = LP.Character
    if char then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

bind(RS.Heartbeat, function()
    if FLY and bv then
        local h = hum()
        local mag = h and h.MoveDirection.Magnitude or 0
        -- บินตามทิศกล้อง: เงยกล้องขึ้น=บินขึ้น, กดจอยหน้า=บินหน้า
        local dir = workspace.CurrentCamera.CFrame.LookVector * mag
        bv.Velocity = (mag > 0 and dir.Unit or Vector3.zero) * SPEED
    end
    if FARM and not FLY then
        local h = hum(); if not h then return end
        ang = ang + 0.04   -- ponytail: ~2.3°/frame, ปรับถ้าวงแน่น/กว้างเกิน
        h.WalkSpeed = RUNSPD
        h:Move(Vector3.new(math.sin(ang), 0, math.cos(ang)), false)
    end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "FLYNCGUI", false
gui.Parent = gethui and gethui() or LP:WaitForChild("PlayerGui")

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0,150,0,150), UDim2.new(0,20,0.5,-75)
f.BackgroundColor3, f.BackgroundTransparency = Color3.fromRGB(20,20,25), 0.25
f.Active, f.Draggable = true, true
Instance.new("UICorner", f)

local function btn(txt, x, y, w, h)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0,w,0,h), UDim2.new(0,x,0,y)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(45,45,55), Color3.fromRGB(255,255,255)
    Instance.new("UICorner", b)
    return b
end

local flyB = btn("FLY: OFF", 5, 5, 140, 36)
flyB.MouseButton1Click:Connect(function()
    FLY = not FLY
    flyB.Text = "FLY: " .. (FLY and "ON" or "OFF")
    flyB.BackgroundColor3 = FLY and Color3.fromRGB(40,140,60) or Color3.fromRGB(45,45,55)
    if FLY then startFly() else stopFly() end
end)

local farmB = btn("FARM: OFF", 5, 46, 140, 36)
farmB.MouseButton1Click:Connect(function()
    FARM = not FARM
    farmB.Text = "FARM: " .. (FARM and "ON" or "OFF")
    farmB.BackgroundColor3 = FARM and Color3.fromRGB(140,90,40) or Color3.fromRGB(45,45,55)
end)

local spdL = btn("fly 60", 5, 87, 140, 18); spdL.Active = false
local minus = btn("−", 5, 109, 67, 36)
local plus  = btn("+", 78, 109, 67, 36)
minus.MouseButton1Click:Connect(function()
    if FLY then SPEED = math.max(10, SPEED-50) else RUNSPD = math.max(10, RUNSPD-50) end
    spdL.Text = (FLY and "fly " or "run ") .. (FLY and SPEED or RUNSPD)
end)
plus.MouseButton1Click:Connect(function()
    if FLY then SPEED = SPEED+50 else RUNSPD = RUNSPD+50 end
    spdL.Text = (FLY and "fly " or "run ") .. (FLY and SPEED or RUNSPD)
end)

print("[FlyNoclip+Farm v2.0] พร้อม")
