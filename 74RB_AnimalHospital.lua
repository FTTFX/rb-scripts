-- 74RB_AnimalHospital.lua — ESP ทะลุกำแพง + เดินเร็ว + Noclip  (v1.0)
-- ESP: ผี🔴 (Skinwalker) | ปลอม🟠 (Fake doctor) | คนไข้🟢 | เพื่อน🔵  + ชื่อ+ระยะ ทะลุกำแพง
-- Speed: บังคับ WalkSpeed ทุก frame | Noclip: ทะลุกำแพงเดินผ่านได้
local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local LP      = Players.LocalPlayer

-- ===== Single-Instance Guard =====
if _G.AH74_CONNS then for _, c in pairs(_G.AH74_CONNS) do pcall(function() c:Disconnect() end) end end
if _G.AH74_ESP  then for _, e in pairs(_G.AH74_ESP)  do pcall(function() e:Destroy() end) end end
_G.AH74_CONNS, _G.AH74_ESP = {}, {}
local CONNS, ESP = _G.AH74_CONNS, _G.AH74_ESP
local function bind(s, f) CONNS[#CONNS+1] = s:Connect(f) end
pcall(function() ((gethui and gethui()) or LP.PlayerGui):FindFirstChild("AH74GUI"):Destroy() end)

-- ===== State =====
local ESP_ON, RUN_ON, NOCLIP_ON, AUTO_ON = true, false, false, false
local SPEED = 50

-- prompt การรักษา/เช็คอิน/quest (จาก spy) — ยิงตัวที่ enabled อยู่ เกมจะไล่สเต็ปเอง
local TREAT_ACTS = {
    ["Stamp Forms"]=true, ["Take Photo"]=true, ["Register"]=true, ["Print Badge"]=true,
    ["Take"]=true, ["Talk"]=true, ["Take DNA Sample"]=true, ["Analyze Sample"]=true,
    ["Process Results"]=true, ["Herbs"]=true, ["Apply Treatment"]=true, ["Use Treatment"]=true,
}
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local promptCache, cacheAcc, fireAcc = {}, 99, 0
local function refreshPrompts()
    promptCache = {}
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and TREAT_ACTS[p.ActionText] then promptCache[#promptCache+1] = p end
    end
end
local function partPos(inst)
    if inst:IsA("BasePart") then return inst.Position end
    local b = inst:FindFirstChildWhichIsA("BasePart", true)
    return b and b.Position
end

local COL = {
    ghost   = Color3.fromRGB(255, 40, 40),    -- ผี
    fake    = Color3.fromRGB(255, 140, 0),    -- หมอปลอม
    patient = Color3.fromRGB(60, 255, 90),    -- คนไข้จริง
    mate    = Color3.fromRGB(60, 160, 255),   -- เพื่อนผู้เล่น
}
local LBL = { ghost="ผี", fake="ปลอม", patient="คนไข้", mate="เพื่อน" }

local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- ===== ESP helper: สร้าง/อัปเดต Highlight + ป้ายชื่อ (ทะลุกำแพง) =====
local function applyESP(model, kind, distStr)
    if not model or not model.Parent then return end
    local e = ESP[model]
    if not e or not e.Parent then
        if e then pcall(function() e:Destroy() end) end
        e = Instance.new("Highlight")
        e.FillTransparency = 0.6
        e.OutlineTransparency = 0
        e.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop   -- ทะลุกำแพง
        e.Adornee = model
        e.Parent  = model
        -- ป้ายชื่อลอยเหนือหัว
        local head = model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
        if head then
            local bb = Instance.new("BillboardGui")
            bb.Name = "AH74Tag"; bb.Adornee = head; bb.AlwaysOnTop = true
            bb.Size = UDim2.new(0, 150, 0, 20); bb.StudsOffset = Vector3.new(0, 2.8, 0)
            bb.Parent = e
            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1
            t.Font = Enum.Font.GothamBold; t.TextScaled = true
            t.TextStrokeTransparency = 0.3; t.Parent = bb
        end
        ESP[model] = e
    end
    e.FillColor = COL[kind]; e.OutlineColor = COL[kind]
    local bb = e:FindFirstChild("AH74Tag")
    local t  = bb and bb:FindFirstChildOfClass("TextLabel")
    if t then
        t.Text = ("[%s] %s%s"):format(LBL[kind], model.Name, distStr)
        t.TextColor3 = COL[kind]
    end
end

local function npcKind(m)
    if m:GetAttribute("Skinwalker") then return "ghost" end
    if m:GetAttribute("Fake")       then return "fake"  end
    return "patient"
end

-- ===== ESP refresh loop (re-check attr ทุก 0.5s — ผีเปลี่ยนสภาพกลางเกมก็เห็น) =====
local acc = 0
bind(RS.Heartbeat, function(dt)
    -- Speed (ทุก frame กัน reset/respawn)
    if RUN_ON then local h = hum(); if h then h.WalkSpeed = SPEED end end
    -- Noclip (ทุก frame)
    if NOCLIP_ON then
        local c = LP.Character
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end end
    end

    -- Auto รักษา/quest: ยิง prompt ที่ enabled ใกล้สุด ทุก ~0.6s
    if AUTO_ON and fp then
        cacheAcc += dt
        if cacheAcc >= 2 then cacheAcc = 0; refreshPrompts() end
        fireAcc += dt
        if fireAcc >= 0.6 then
            fireAcc = 0
            local fromPos = hrp() and hrp().Position
            local best, bestD
            for _, p in ipairs(promptCache) do
                if p.Parent and p.Enabled then
                    local pos = partPos(p.Parent)
                    local d = (fromPos and pos) and (pos - fromPos).Magnitude or 0
                    if not best or d < bestD then best, bestD = p, d end
                end
            end
            if best then pcall(fp, best, 0) end
        end
    end

    acc += dt
    if acc < 0.4 then return end
    acc = 0
    if not ESP_ON then return end

    local fromPos = hrp() and hrp().Position
    local wanted = {}

    -- เพื่อนผู้เล่น (ทุกคนทีมเดียว)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local dStr = (fromPos and root) and (" "..math.floor((root.Position-fromPos).Magnitude).."m") or ""
            applyESP(p.Character, "mate", dStr)
            wanted[p.Character] = true
        end
    end

    -- NPC ใน Workspace.NPCs
    local npcs = workspace:FindFirstChild("NPCs")
    if npcs then
        for _, m in ipairs(npcs:GetChildren()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
                local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
                local dStr = (fromPos and root) and (" "..math.floor((root.Position-fromPos).Magnitude).."m") or ""
                applyESP(m, npcKind(m), dStr)
                wanted[m] = true
            end
        end
    end

    -- ลบ ESP ของตัวที่หายไป (ตาย/respawn/ออกห้อง)
    for model, e in pairs(ESP) do
        if not wanted[model] or not model.Parent then
            pcall(function() e:Destroy() end); ESP[model] = nil
        end
    end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AH74GUI", false, 9999
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0,190,0,274), UDim2.new(0,20,0.5,-137)
f.BackgroundColor3, f.BackgroundTransparency = Color3.fromRGB(18,18,24), 0.1
f.BorderSizePixel, f.Active, f.Draggable = 0, true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", f).Color = Color3.fromRGB(90,120,255)

local title = Instance.new("TextLabel", f)
title.Size, title.Position = UDim2.new(1,-12,0,26), UDim2.new(0,8,0,4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(150,180,255)
title.Text, title.Font, title.TextSize = "ANIMAL HOSPITAL 74", Enum.Font.GothamBold, 14
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

local espB = btn("ESP: ON", 10, 36, 170, 36, Color3.fromRGB(40,150,70))
espB.MouseButton1Click:Connect(function()
    ESP_ON = not ESP_ON
    espB.Text = "ESP: " .. (ESP_ON and "ON" or "OFF")
    espB.BackgroundColor3 = ESP_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if not ESP_ON then
        for m, e in pairs(ESP) do pcall(function() e:Destroy() end); ESP[m] = nil end
    end
end)

local runB = btn("RUN: OFF", 10, 80, 170, 36)
runB.MouseButton1Click:Connect(function()
    RUN_ON = not RUN_ON
    runB.Text = "RUN: " .. (RUN_ON and "ON" or "OFF")
    runB.BackgroundColor3 = RUN_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if not RUN_ON then local h = hum(); if h then h.WalkSpeed = 16 end end
end)

local spdL = btn(tostring(SPEED), 10, 122, 90, 34); spdL.Active = false
btn("−", 106, 122, 36, 34).MouseButton1Click:Connect(function()
    SPEED = math.max(16, SPEED - 10); spdL.Text = tostring(SPEED)
end)
btn("+", 144, 122, 36, 34).MouseButton1Click:Connect(function()
    SPEED = SPEED + 10; spdL.Text = tostring(SPEED)
end)

local clipB = btn("NOCLIP: OFF", 10, 164, 170, 36)
clipB.MouseButton1Click:Connect(function()
    NOCLIP_ON = not NOCLIP_ON
    clipB.Text = "NOCLIP: " .. (NOCLIP_ON and "ON" or "OFF")
    clipB.BackgroundColor3 = NOCLIP_ON and Color3.fromRGB(150,40,150) or Color3.fromRGB(45,45,58)
    if not NOCLIP_ON then
        local c = LP.Character
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end end
    end
end)

local autoB = btn("AUTO รักษา: OFF", 10, 206, 170, 36)
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    if AUTO_ON then cacheAcc = 99 end   -- บังคับ refresh prompt รอบแรกทันที
    autoB.Text = "AUTO รักษา: " .. (AUTO_ON and "ON" or "OFF")
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if AUTO_ON and not fp then autoB.Text = "ไม่มี fireproximityprompt" end
end)

btn("CLOSE", 10, 248, 170, 22, Color3.fromRGB(120,30,30)).MouseButton1Click:Connect(function()
    RUN_ON, NOCLIP_ON, ESP_ON, AUTO_ON = false, false, false, false
    local h = hum(); if h then h.WalkSpeed = 16 end
    local c = LP.Character
    if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
    for m, e in pairs(ESP) do pcall(function() e:Destroy() end) end
    for _, conn in pairs(CONNS) do pcall(function() conn:Disconnect() end) end
    _G.AH74_CONNS, _G.AH74_ESP = nil, nil
    gui:Destroy()
end)

print("[74RB AnimalHospital v1.0] ESP ทะลุกำแพง + Speed + Noclip พร้อม")
