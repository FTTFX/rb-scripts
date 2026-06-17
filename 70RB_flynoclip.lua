-- 70RB_flynoclip.lua — Fly + Noclip + AutoFarm-run mini (v1.3, มือถือ/ปุ่มจิ้ม)
-- v1.3: ▲▼ เปลี่ยนเป็นแตะเปิด/ปิด (กดค้างไม่ติดเพราะกรอบ Draggable แย่งทัช)
-- FLY: เปิดบิน+ทะลุ | ▲▼ ขึ้นลง | FARM: วิ่งสะสม speed | MODE: หน้า-ถอย / วงกลมเล็ก
-- − + : ปรับ (FLY=สปีดบิน, FARM=ความถี่วิ่ง) | ponytail: Humanoid:Move วิ่งจริง ไม่วาร์ป
local Players, RS, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local LP = Players.LocalPlayer

local SPEED, FLY, up, down, bv = 60, false, false, false, nil
local FARM, MODE, RATE, ang, flipT, fwd = false, 1, 0.5, 0, 0, 1   -- MODE 1=หน้า-ถอย 2=วงกลม

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
    -- FLY + noclip
    if FLY and bv then
        local root, char = hrp(), LP.Character
        if root then
            for _, p in pairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            local h = hum()
            local dir = h and h.MoveDirection or Vector3.zero
            if up   then dir = dir + Vector3.new(0,1,0) end
            if down then dir = dir - Vector3.new(0,1,0) end
            bv.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * SPEED
        end
    end
    -- FARM: วิ่งสะสม speed (ไม่ทำตอนบิน)
    if FARM and not FLY then
        local root, h = hrp(), hum(); if not (root and h) then return end
        if MODE == 1 then            -- หน้า-ถอย: สลับทุก (0.3/RATE) วิ
            flipT = flipT + 1/60
            if flipT >= 0.3 / RATE then flipT = 0; fwd = -fwd end
            h:Move(root.CFrame.LookVector * fwd, false)
        else                          -- วงกลมเล็กเร็ว: หมุนทิศทุกเฟรม
            ang = ang + 0.35 * RATE
            h:Move(Vector3.new(math.cos(ang), 0, math.sin(ang)), false)
        end
    end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "FLYNCGUI", false
gui.Parent = gethui and gethui() or LP:WaitForChild("PlayerGui")

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0,150,0,235), UDim2.new(0,20,0.5,-117)
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

-- แตะเปิด/แตะปิด (กดค้างไม่ติดเพราะกรอบ Draggable แย่งทัช)
local upB   = btn("▲", 5, 46, 67, 44)
local downB = btn("▼", 78, 46, 67, 44)
local OFFC, ONC = Color3.fromRGB(45,45,55), Color3.fromRGB(40,120,150)
upB.MouseButton1Click:Connect(function()
    up = not up; down = false
    upB.BackgroundColor3, downB.BackgroundColor3 = up and ONC or OFFC, OFFC
end)
downB.MouseButton1Click:Connect(function()
    down = not down; up = false
    downB.BackgroundColor3, upB.BackgroundColor3 = down and ONC or OFFC, OFFC
end)

local farmB = btn("FARM: OFF", 5, 95, 140, 36)
farmB.MouseButton1Click:Connect(function()
    FARM = not FARM
    farmB.Text = "FARM: " .. (FARM and "ON" or "OFF")
    farmB.BackgroundColor3 = FARM and Color3.fromRGB(140,90,40) or Color3.fromRGB(45,45,55)
    if FARM then local h = hum(); if h then h.AutoRotate = false end
    else local h = hum(); if h then h.AutoRotate = true end end
end)

local modeB = btn("MODE: หน้า-ถอย", 5, 136, 140, 30)
modeB.MouseButton1Click:Connect(function()
    MODE = MODE == 1 and 2 or 1
    modeB.Text = "MODE: " .. (MODE == 1 and "หน้า-ถอย" or "วงกลม")
end)

local function rateTxt() return FLY and ("speed "..SPEED) or ("rate x"..string.format("%.1f", RATE)) end
local spdL = btn(rateTxt(), 5, 171, 140, 18); spdL.Active = false
local minus = btn("−", 5, 191, 67, 36)
local plus  = btn("+", 78, 191, 67, 36)
local function refresh() spdL.Text = rateTxt() end
minus.MouseButton1Click:Connect(function()
    if FLY then SPEED = math.max(10, SPEED-10) else RATE = math.max(0.1, RATE-0.1) end; refresh()
end)
plus.MouseButton1Click:Connect(function()
    if FLY then SPEED = SPEED+10 else RATE = math.min(3, RATE+0.1) end; refresh()
end)

print("[FlyNoclip+Farm v1.3] พร้อม")
