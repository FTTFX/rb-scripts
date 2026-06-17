-- 70RB_flynoclip.lua — Fly + Noclip mini (v1.0)
-- F=เปิด/ปิด | WASD=ทิศกล้อง Space=ขึ้น Ctrl=ลง | [ ลดสปีด  ] เพิ่มสปีด
-- ponytail: velocity ล้วน (ไม่ใช่ CFrame warp) + ไม่ spoof state ใดๆ → กันเด้ง/กัน AC จุดชนวน
local Players, RS, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local LP, Cam = Players.LocalPlayer, workspace.CurrentCamera

local SPEED = 60        -- ปรับเริ่มต้นตรงนี้ (หรือกด [ ] ตอนเล่น)
local FLY = false
local bv

-- single-instance guard (_G) — โหลดซ้ำ = ล้างของเก่า
if _G.FLYNC then for _, c in pairs(_G.FLYNC) do pcall(function() c:Disconnect() end) end end
if _G.FLYNC_BV then pcall(function() _G.FLYNC_BV:Destroy() end) end
_G.FLYNC = {}
local function bind(s, f) local c = s:Connect(f); _G.FLYNC[#_G.FLYNC+1] = c end

local function parts() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart"), c end

local function startFly()
    local root = parts(); if not root then FLY = false; return end
    bv = Instance.new("BodyVelocity")
    bv.MaxForce, bv.Velocity = Vector3.new(1,1,1)*9e9, Vector3.zero
    bv.Parent = root; _G.FLYNC_BV = bv
    local h = LP.Character:FindFirstChildOfClass("Humanoid"); if h then h.PlatformStand = true end
end
local function stopFly()
    if bv then bv:Destroy(); bv = nil end
    local c = LP.Character
    local h = c and c:FindFirstChildOfClass("Humanoid"); if h then h.PlatformStand = false end
end

bind(RS.Heartbeat, function()
    if not FLY or not bv then return end
    local root, char = parts(); if not root then return end
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end   -- noclip
    end
    local cf, dir = Cam.CFrame, Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0,1,0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
    bv.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * SPEED
end)

bind(UIS.InputBegan, function(i, gp)
    if gp then return end
    local k = i.KeyCode
    if k == Enum.KeyCode.F then FLY = not FLY; if FLY then startFly() else stopFly() end
    elseif k == Enum.KeyCode.LeftBracket  then SPEED = math.max(10, SPEED - 10)
    elseif k == Enum.KeyCode.RightBracket then SPEED = SPEED + 10 end
end)

print("[FlyNoclip v1.0] F=fly | [ ] ปรับสปีด | สปีด="..SPEED)
