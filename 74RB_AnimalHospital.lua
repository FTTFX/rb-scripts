-- 74RB_AnimalHospital.lua — ESP ทะลุกำแพง + เดินเร็ว + Noclip  (v1.0)
-- ESP: ผี🔴 (Skinwalker) | ปลอม🟠 (Fake doctor) | คนไข้🟢 | เพื่อน🔵  + ชื่อ+ระยะ ทะลุกำแพง
-- Speed: บังคับ WalkSpeed ทุก frame | Noclip: ทะลุกำแพงเดินผ่านได้
local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local VIM     = game:GetService("VirtualInputManager")
local LP      = Players.LocalPlayer

-- กดเลข 1-9 เลือก slot hotbar (เกมดู slot ที่เลือก ไม่ใช่ EquipTool)
local SLOT_KEYS = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
    Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}
local function pressSlot(n)
    local k = SLOT_KEYS[n]; if not k then return end
    pcall(function()
        VIM:SendKeyEvent(true, k, false, game); task.wait(0.05)
        VIM:SendKeyEvent(false, k, false, game)
    end)
end

-- ===== Single-Instance Guard =====
if _G.AH74_CONNS then for _, c in pairs(_G.AH74_CONNS) do pcall(function() c:Disconnect() end) end end
if _G.AH74_ESP  then for _, e in pairs(_G.AH74_ESP)  do pcall(function() e:Destroy() end) end end
_G.AH74_CONNS, _G.AH74_ESP = {}, {}
_G.AH74_GEN = (_G.AH74_GEN or 0) + 1   -- กัน loop เก่าทำงานซ้อนตอนรันใหม่
local MYGEN = _G.AH74_GEN
local CONNS, ESP = _G.AH74_CONNS, _G.AH74_ESP
local function bind(s, f) CONNS[#CONNS+1] = s:Connect(f) end
pcall(function() ((gethui and gethui()) or LP.PlayerGui):FindFirstChild("AH74GUI"):Destroy() end)

-- ===== State =====
local ESP_ON, RUN_ON, NOCLIP_ON, AUTO_ON = true, false, false, false
local SPEED = 50

-- prompt การรักษา/เช็คอิน/quest (จาก spy) — ยิงตัวที่ enabled อยู่ เกมจะไล่สเต็ปเอง
-- สเต็ปปลอดภัย (ยิงมั่วได้ ไม่ทำคนไข้ตาย): เช็คอิน + วินิจฉัย เท่านั้น
-- *** ไม่รวมเก็บยา/Apply Treatment *** เพราะให้ยาผิด = คนไข้ตาย → จัดการแยกแบบ match ชื่อ
local SAFE_ACTS = {
    ["Stamp Forms"]=true, ["Take Photo"]=true, ["Register"]=true, ["Print Badge"]=true,
    ["Take"]=true, ["Talk"]=true, ["Take DNA Sample"]=true, ["Analyze Sample"]=true,
    ["Process Results"]=true,
}
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local fireAcc = 0
local function partPos(inst)
    if not inst then return nil end
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

-- ===== Auto รักษา (match ชื่อยา ไม่ฆ่าคนไข้) =====
local function tpTo(pos)
    local r = hrp()
    if r and pos then r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
end
-- หา ProximityPrompt ที่ ActionText ตรงชื่อยา (จุดเก็บยา)
local function findPickup(medName)
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == medName then return p end
    end
end
-- หา Tool ชื่อตรงยา (ที่ถืออยู่ใน Backpack/ตัว)
local function findTool(medName)
    local bp = LP:FindFirstChild("Backpack")
    if bp then local t = bp:FindFirstChild(medName); if t and t:IsA("Tool") then return t end end
    if LP.Character then local t = LP.Character:FindFirstChild(medName); if t and t:IsA("Tool") then return t end end
end
-- เป็น "ยา" ไหม = มีจุดเก็บ (ProximityPrompt ActionText ตรงชื่อ)
local function isMedicine(name) return findPickup(name) ~= nil end
-- Tool ทั้งหมดที่ถืออยู่ (Backpack+ตัว)
local function heldTools()
    local out = {}
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then out[#out+1] = t end end end
    if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do if t:IsA("Tool") then out[#out+1] = t end end end
    return out
end
-- หาจุดทิ้งยา (Trash Item)
local function trashPrompt()
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == "Trash Item" then return p end
    end
end
-- ทิ้ง Tool 1 ชิ้น: equip → วาปไปถังขยะ → fire
local function discardTool(tool)
    local h = hum()
    local tp = trashPrompt()
    if not (h and tp and tp.Parent) then return end
    pcall(function() h:EquipTool(tool) end); task.wait(0.2)
    tpTo(partPos(tp.Parent)); task.wait(0.3)
    pcall(fp, tp, 0); task.wait(0.35)
end
-- เคลียร์ยาที่ "ไม่ใช่" ของคนไข้นี้ออก (กัน slot เต็ม → เก็บยาถูกไม่ได้)
local function cleanInventory(needed)
    for _, t in ipairs(heldTools()) do
        if isMedicine(t.Name) and not needed[t.Name] then
            discardTool(t)
        end
    end
end
-- หา Report ของห้อง (TV.Screen.UI.Report)
local function getReport(room)
    local r = room:FindFirstChild("Minigame")
    r = r and r:FindFirstChild("TV"); r = r and r:FindFirstChild("Screen")
    r = r and r:FindFirstChild("UI"); r = r and r:FindFirstChild("Report")
    return r
end
-- เลข TREATMENT ปัจจุบัน (X จาก 'TREATMENT: X/Y')
local function treatCount(room)
    local rep = getReport(room)
    local tt = rep and rep:FindFirstChild("treatment")
    if tt and tt:IsA("TextLabel") then
        local a = tt.Text:match("(%d+)%s*/")
        return tonumber(a) or 0
    end
    return 0
end
-- ห้องนี้รักษาเสร็จ/กำลังฟื้นแล้วหรือยัง → ข้าม ไม่วาปซ้ำ
local function roomDone(room)
    local rep = getReport(room)
    if not rep then return true end                  -- ไม่มีจอ = ไม่ต้องทำ
    local healing = rep:FindFirstChild("Healing")
    if healing and healing:IsA("GuiObject") and healing.Visible then return true end
    local tt = rep:FindFirstChild("treatment")
    if tt and tt:IsA("TextLabel") then
        local a, b = tt.Text:match("(%d+)%s*/%s*(%d+)")
        a, b = tonumber(a), tonumber(b)
        if a and b and b > 0 and a >= b then return true end   -- 2/2 = เสร็จ
    end
    return false
end
-- อ่าน "ยาที่ต้องใช้" ของห้อง จาก TV.Screen.UI.Report.inv (populate หลังวินิจฉัย)
local function requiredMeds(room)
    local inv = getReport(room)
    inv = inv and inv:FindFirstChild("inv")
    if not inv then return {} end
    local meds = {}
    for _, fr in ipairs(inv:GetChildren()) do
        if fr:IsA("GuiObject") then
            local nm = fr:FindFirstChild("name")
            meds[#meds+1] = (nm and nm:IsA("TextLabel") and nm.Text ~= "") and nm.Text or fr.Name
        end
    end
    return meds
end
-- ทำหนึ่งห้องที่วินิจฉัยเสร็จ: เก็บยาที่ถูก → ไปเตียง → equip+apply ทีละชนิด
local function treatRoom(room)
    if roomDone(room) then return false end          -- เสร็จ/ฟื้นแล้ว → ไม่วาปซ้ำ
    local meds = requiredMeds(room)
    if #meds == 0 then return false end
    local needed = {}
    for _, m in ipairs(meds) do needed[m] = true end
    -- 0) ทิ้งยาเก่า/ผิดที่ไม่ใช่ของคนไข้นี้ก่อน (กัน slot เต็ม → ให้ยาผิด → ตาย)
    cleanInventory(needed)
    -- 1) เก็บยาที่ยังไม่มี
    for _, m in ipairs(meds) do
        if not findTool(m) then
            local pp = findPickup(m)
            if pp and pp.Parent then
                tpTo(partPos(pp.Parent)); task.wait(0.35)
                pcall(fp, pp, 0); task.wait(0.45)
            end
        end
    end
    -- กันตาย: ถ้ายังถือยาไม่ครบทุกชนิด → ห้าม Apply (รอบหน้าค่อยลองใหม่)
    for _, m in ipairs(meds) do
        if not findTool(m) then return false end
    end
    -- 2) ไปเตียง แล้วให้ยาทีละชนิด (equip ให้ตรงก่อนกด)
    local bed = room:FindFirstChild("Minigame")
    bed = bed and bed:FindFirstChild("Bed"); bed = bed and bed:FindFirstChild("InBed")
    local bedPP = bed and bed:FindFirstChild("PP")
    if not bedPP then return false end
    tpTo(partPos(bed)); task.wait(0.35)
    -- ให้ยาตามลำดับที่จอบอก ทีละตัว — เลือก slot จนเจอยาชื่อตรงเป๊ะค่อยกด
    -- ถ้าหายาตัวนั้นไม่เจอ = ยกเลิก (ไม่กดมั่ว); ถ้ากดแล้ว TREATMENT ไม่เพิ่ม = หยุด
    local given = {}
    for _, m in ipairs(meds) do
        if roomDone(room) then break end
        if not given[m] then
            -- หา slot ที่ถือยา m พอดี
            local picked = false
            for slot = 1, 9 do
                pressSlot(slot); task.wait(0.22)
                local held = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
                if held and held.Name == m then picked = true; break end
            end
            if not picked then return false end          -- ไม่เจอยาตัวนี้ → เลิก ไม่เสี่ยง
            local before = treatCount(room)
            pcall(fp, bedPP, 0); task.wait(0.6)            -- ให้ยา m
            given[m] = true
            if treatCount(room) <= before then return false end  -- ไม่คืบ = ผิด หยุดทันที
        end
    end
    return true
end

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

    -- Auto: ยิงสเต็ป "ปลอดภัย" (เช็คอิน+วินิจฉัย) ทุก 0.6s — ส่วนให้ยาทำใน loop แยก
    if AUTO_ON and fp then
        fireAcc += dt
        if fireAcc >= 0.6 then
            fireAcc = 0
            for _, p in ipairs(workspace:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Enabled and SAFE_ACTS[p.ActionText] then
                    pcall(fp, p, 0)   -- ยิงทุกตัวที่ enabled (เกม gate ลำดับเอง)
                end
            end
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
    autoB.Text = "AUTO รักษา: " .. (AUTO_ON and "ON" or "OFF")
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if AUTO_ON and not fp then autoB.Text = "ไม่มี fireproximityprompt" end
end)

-- loop ให้ยา (match ชื่อ) แยกจาก Heartbeat — มี wait ระหว่างสเต็ป
task.spawn(function()
    while _G.AH74_GEN == MYGEN do
        if AUTO_ON and fp then
            local med = workspace:FindFirstChild("Rooms")
            med = med and med:FindFirstChild("Medical")
            if med then
                for _, room in ipairs(med:GetChildren()) do
                    if not (AUTO_ON and _G.AH74_GEN == MYGEN) then break end
                    pcall(treatRoom, room)   -- treatRoom เช็คเองว่าห้องมียาที่ต้องให้ไหม
                end
            end
        end
        task.wait(1)
    end
end)

btn("CLOSE", 10, 248, 170, 22, Color3.fromRGB(120,30,30)).MouseButton1Click:Connect(function()
    RUN_ON, NOCLIP_ON, ESP_ON, AUTO_ON = false, false, false, false
    local h = hum(); if h then h.WalkSpeed = 16 end
    local c = LP.Character
    if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
    for m, e in pairs(ESP) do pcall(function() e:Destroy() end) end
    for _, conn in pairs(CONNS) do pcall(function() conn:Disconnect() end) end
    _G.AH74_CONNS, _G.AH74_ESP = nil, nil
    _G.AH74_GEN = (_G.AH74_GEN or 0) + 1   -- หยุด treat loop
    gui:Destroy()
end)

print("[74RB AnimalHospital v2.0] ESP + Speed + Noclip + AUTO รักษา(match ยา) พร้อม")
