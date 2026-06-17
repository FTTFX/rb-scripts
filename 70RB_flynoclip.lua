-- 70RB_flynoclip.lua — Fly + Noclip mini (v1.1, มือถือ/ปุ่มจิ้ม)
-- ปุ่มบนจอ: FLY เปิด/ปิด | ▲ ขึ้น ▼ ลง (กดค้าง) | − + ปรับสปีด
-- เดินแนวราบ = จอยสติ๊กในเกม (ตามกล้องอยู่แล้ว) | ponytail: velocity ล้วน ไม่ spoof state
local Players, RS, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local LP = Players.LocalPlayer

local SPEED, FLY, up, down, bv = 60, false, false, false, nil

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
    bv = Instance.new("BodyVelocity")
    bv.MaxForce, bv.Velocity = Vector3.new(1,1,1)*9e9, Vector3.zero
    bv.Parent = root; _G.FLYNC_BV = bv
    local h = hum(); if h then h.PlatformStand = true end
end
local function stopFly()
    if bv then bv:Destroy(); bv = nil end
    local h = hum(); if h then h.PlatformStand = false end
end

bind(RS.Heartbeat, function()
    if not FLY or not bv then return end
    local root, char = hrp(), LP.Character; if not root then return end
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end   -- noclip
    end
    local h = hum()
    local dir = h and h.MoveDirection or Vector3.zero      -- จอยสติ๊ก (ตามกล้อง)
    if up   then dir = dir + Vector3.new(0,1,0) end
    if down then dir = dir - Vector3.new(0,1,0) end
    bv.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * SPEED
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

local flyB = btn("FLY: OFF", 5, 5, 140, 38)
flyB.MouseButton1Click:Connect(function()
    FLY = not FLY
    flyB.Text = "FLY: " .. (FLY and "ON" or "OFF")
    flyB.BackgroundColor3 = FLY and Color3.fromRGB(40,140,60) or Color3.fromRGB(45,45,55)
    if FLY then startFly() else stopFly() end
end)

local upB   = btn("▲", 5, 48, 67, 50)
local downB = btn("▼", 78, 48, 67, 50)
upB.MouseButton1Down:Connect(function() up = true end);     upB.MouseButton1Up:Connect(function() up = false end)
downB.MouseButton1Down:Connect(function() down = true end); downB.MouseButton1Up:Connect(function() down = false end)

local spdL = btn("speed "..SPEED, 5, 103, 140, 18); spdL.Active = false
local minus = btn("−", 5, 124, 67, 22)
local plus  = btn("+", 78, 124, 67, 22)
minus.MouseButton1Click:Connect(function() SPEED = math.max(10, SPEED-10); spdL.Text = "speed "..SPEED end)
plus.MouseButton1Click:Connect(function() SPEED = SPEED+10; spdL.Text = "speed "..SPEED end)

print("[FlyNoclip v1.1] GUI พร้อม — กดปุ่ม FLY")
