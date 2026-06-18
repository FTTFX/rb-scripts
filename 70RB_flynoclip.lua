-- 70RB_flynoclip.lua — Fly + Noclip + AutoFarm + WinFarm (v2.5)
-- v2.5: + ปุ่ม CLOSE (ปิดทุกอย่าง + คืน CanCollide + ลบ GUI)
-- v2.4: WIN ใช้ MoveTo เดินจริง (server-side physics) + noclip ทะลุกำแพง
--       วิธีใช้ WIN: บินไปแผ่น → SET POS → กลับมายืนที่ไหนก็ได้ → WIN ON
local Players, RS, VIM = game:GetService("Players"), game:GetService("RunService"), game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

local SPEED, FLY, bv = 60, false, nil
local FARM, RUNSPD = false, 50
local FARM_DUR = 0.3
local KEYS = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
local farmIdx, farmTimer = 1, 0

local WIN, winPos, WIN_CD = false, nil, 3.0
local winPhase, winTimer = 0, 0   -- phase: 0=รอ 1=เดินไปแผ่น 2=ยืนบนแผ่น 3=เดินออก
local awayPos = Vector3.zero

local function pressKey(kc, on) pcall(function() VIM:SendKeyEvent(on, kc, false, game) end) end
local function releaseAll() for _, k in pairs(KEYS) do pressKey(k, false) end end

-- single-instance guard
if _G.FLYNC then for _, c in pairs(_G.FLYNC) do pcall(function() c:Disconnect() end) end end
if _G.FLYNC_BV then pcall(function() _G.FLYNC_BV:Destroy() end) end
if _G.FLYNC_RELEASE then pcall(_G.FLYNC_RELEASE) end
pcall(function() (gethui and gethui() or LP.PlayerGui).FLYNCGUI:Destroy() end)
_G.FLYNC, _G.FLYNC_RELEASE = {}, releaseAll
local function bind(s, f) local c = s:Connect(f); _G.FLYNC[#_G.FLYNC+1] = c end

local function hrp() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end

local function startFly()
    local root = hrp(); if not root then FLY = false; return end
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

bind(LP.CharacterRemoving, function() bv = nil end)
bind(LP.CharacterAdded, function()
    RS.Heartbeat:Wait()
    if FLY then startFly() end
end)

bind(RS.Heartbeat, function(dt)
    -- FLY
    if FLY then
        local char = LP.Character
        if char and bv then
            for _, p in pairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            local h = hum()
            local mag = h and h.MoveDirection.Magnitude or 0
            local dir = workspace.CurrentCamera.CFrame.LookVector * mag
            bv.Velocity = (mag > 0 and dir.Unit or Vector3.zero) * SPEED
        end
    end

    -- FARM
    if FARM and not FLY then
        local h = hum(); if not h then return end
        h.WalkSpeed = RUNSPD
        farmTimer = farmTimer + dt
        if farmTimer >= FARM_DUR then
            pressKey(KEYS[farmIdx], false)
            farmIdx = farmIdx % 4 + 1
            pressKey(KEYS[farmIdx], true)
            farmTimer = 0
        end
    end

    -- WIN: เดินจริงผ่าน MoveTo + noclip (server ต้องการ physics touch)
    if WIN and winPos then
        local h, root = hum(), hrp()
        if not h or not root then return end

        -- noclip ทุก frame ให้เดินทะลุกำแพงได้
        local char = LP.Character
        if char then
            for _, p in pairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end

        winTimer = winTimer + dt
        local padV = winPos.Position

        if winPhase == 0 then                          -- รอ cooldown
            if winTimer >= WIN_CD then
                h:MoveTo(padV)
                winPhase, winTimer = 1, 0
            end

        elseif winPhase == 1 then                      -- เดินไปแผ่น
            if (root.Position - padV).Magnitude < 5 then
                winPhase, winTimer = 2, 0              -- ถึงแล้ว → ยืนรอ
            elseif winTimer > 12 then                  -- timeout ถ้าไปไม่ถึง
                h:MoveTo(padV)                         -- MoveTo reset (8s timeout ของ Roblox)
                winTimer = 0
            end

        elseif winPhase == 2 then                      -- ยืนบนแผ่น 0.5วิ
            if winTimer >= 0.5 then
                h:MoveTo(awayPos)
                winPhase, winTimer = 3, 0
            end

        elseif winPhase == 3 then                      -- เดินออกจากแผ่น
            if (root.Position - awayPos).Magnitude < 8 then
                winPhase, winTimer = 0, 0
            elseif winTimer > 12 then
                h:MoveTo(awayPos)                      -- MoveTo reset
                winTimer = 0
            end
        end
    end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "FLYNCGUI", false
gui.Parent = gethui and gethui() or LP:WaitForChild("PlayerGui")

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0,150,0,336), UDim2.new(0,20,0.5,-168)
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
    if FARM then
        farmIdx, farmTimer = 1, 0; pressKey(KEYS[farmIdx], true)
    else
        releaseAll()
    end
end)

local durL = btn("0.3s", 5, 87, 60, 26); durL.Active = false
local durM = btn("−", 68, 87, 34, 26)
local durP = btn("+", 106, 87, 34, 26)
durM.MouseButton1Click:Connect(function()
    FARM_DUR = math.max(0.1, FARM_DUR - 0.1)
    durL.Text = ("%.1fs"):format(FARM_DUR)
end)
durP.MouseButton1Click:Connect(function()
    FARM_DUR = FARM_DUR + 0.1
    durL.Text = ("%.1fs"):format(FARM_DUR)
end)

local spdL = btn("fly 60", 5, 118, 140, 18); spdL.Active = false
local minus = btn("−", 5, 140, 67, 36)
local plus  = btn("+", 78, 140, 67, 36)
minus.MouseButton1Click:Connect(function()
    if FLY then SPEED = math.max(10, SPEED-50) else RUNSPD = math.max(10, RUNSPD-50) end
    spdL.Text = (FLY and "fly " or "run ") .. (FLY and SPEED or RUNSPD)
end)
plus.MouseButton1Click:Connect(function()
    if FLY then SPEED = SPEED+50 else RUNSPD = RUNSPD+50 end
    spdL.Text = (FLY and "fly " or "run ") .. (FLY and SPEED or RUNSPD)
end)

local div = Instance.new("Frame", f)
div.Size, div.Position = UDim2.new(1,-10,0,1), UDim2.new(0,5,0,182)
div.BackgroundColor3, div.BorderSizePixel = Color3.fromRGB(80,80,100), 0

local setB = btn("SET POS", 5, 189, 140, 30)
setB.BackgroundColor3 = Color3.fromRGB(60,60,80)
setB.MouseButton1Click:Connect(function()
    local root = hrp()
    if root then
        winPos = root.CFrame
        setB.Text = "SET ✓"
        setB.BackgroundColor3 = Color3.fromRGB(80,80,160)
    end
end)

local winB = btn("WIN: OFF", 5, 224, 140, 36)
winB.MouseButton1Click:Connect(function()
    if not winPos then setB.Text = "SET ก่อน!"; return end
    WIN = not WIN
    if WIN then
        -- ปิด FLY — BV ขัด MoveTo
        if FLY then
            FLY = false; stopFly()
            flyB.Text = "FLY: OFF"
            flyB.BackgroundColor3 = Color3.fromRGB(45,45,55)
        end
        -- บันทึก awayPos = ที่ยืนอยู่ตอนนี้ (จุดออก)
        local root = hrp()
        awayPos = root and root.Position or (winPos.Position + Vector3.new(40,0,0))
        winPhase, winTimer = 0, 0
    end
    winB.Text = "WIN: " .. (WIN and "ON" or "OFF")
    winB.BackgroundColor3 = WIN and Color3.fromRGB(160,40,160) or Color3.fromRGB(45,45,55)
end)

local cdL = btn(("%.1fs"):format(WIN_CD), 5, 265, 60, 26); cdL.Active = false
local cdM = btn("−", 68, 265, 34, 26)
local cdP = btn("+", 106, 265, 34, 26)
cdM.MouseButton1Click:Connect(function()
    WIN_CD = math.max(0.5, WIN_CD - 0.5)
    cdL.Text = ("%.1fs"):format(WIN_CD)
end)
cdP.MouseButton1Click:Connect(function()
    WIN_CD = WIN_CD + 0.5
    cdL.Text = ("%.1fs"):format(WIN_CD)
end)

local closeB = btn("CLOSE", 5, 300, 140, 30)
closeB.BackgroundColor3 = Color3.fromRGB(120,30,30)
closeB.MouseButton1Click:Connect(function()
    FLY, FARM, WIN = false, false, false
    releaseAll()
    if bv then bv:Destroy(); bv = nil end
    local char = LP.Character
    if char then for _, p in pairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
    for _, c in pairs(_G.FLYNC) do pcall(function() c:Disconnect() end) end
    _G.FLYNC, _G.FLYNC_BV, _G.FLYNC_RELEASE = nil, nil, nil
    gui:Destroy()
end)

print("[FlyNoclip+Farm+Win v2.5] พร้อม")
