-- 78RB_DuckAim.lua v1.0 — Auto Aim ง่ายๆ (เกม "ยิงเป็ด")
-- ล็อคกล้องไปที่เป้าที่อยู่ใกล้กลางจอที่สุดอัตโนมัติ — ผู้เล่นกดยิงเองตามปกติ
-- ยังไม่รู้โครงสร้างเกมจริง เลยสแกนกว้างไว้ก่อน: โมเดล/Part ชื่อพ้อง duck/เป็ด/bird
-- หรือโมเดลที่มี Humanoid ที่ไม่ใช่ผู้เล่น (NPC) — status โชว์ชื่อเป้าที่ล็อคอยู่เสมอ
-- ปุ่ม: AIM (ล็อคเป้าอัตโนมัติ) | MODE (ทุก NPC ↔ เฉพาะชื่อพ้องเป็ด) | STOP | ✕
if _G.DA78_GUI then pcall(function() _G.DA78_GUI:Destroy() end) end
if _G.DA78_CONNS then
    for _, c in ipairs(_G.DA78_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.DA78_CONNS = {}
_G.DA78_GEN = (_G.DA78_GEN or 0) + 1
local MY_GEN = _G.DA78_GEN

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local AIM_ON = false
local NAME_ONLY = false -- false = เล็งทุก NPC, true = เฉพาะชื่อพ้องเป็ด
local MAX_LOCK_ANGLE = 60 -- องศาจากกลางจอ — ไกลกว่านี้ไม่แย่งล็อค (กันสะบัดกล้อง 180°)
local SMOOTH = 0.35 -- 0..1 ยิ่งมากยิ่งดูดไว (1 = ตึงเป้าทันที)

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DuckAim78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.DA78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 250, 0, 170); frame.Position = UDim2.new(0, 8, 0.3, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.2
frame.Active = true; frame.Draggable = true

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -8, 0, 40); status.Position = UDim2.new(0, 4, 0, 4)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(255, 220, 150)
status.TextSize = 12; status.Font = Enum.Font.Code; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.TextYAlignment = Enum.TextYAlignment.Top
local function setStatus(s) status.Text = s end

local function mkbtn(txt, y, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, -8, 0, 26); b.Position = UDim2.new(0, 4, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local aimB   = mkbtn("AIM: OFF (ล็อคเป้าอัตโนมัติ)", 48, Color3.fromRGB(190, 60, 60))
local modeB  = mkbtn("MODE: ทุก NPC", 78, Color3.fromRGB(60, 110, 180))
local stopB  = mkbtn("STOP", 108, Color3.fromRGB(150, 60, 30))
local closeB = mkbtn("✕ ปิด", 138, Color3.fromRGB(90, 40, 40))

setStatus("[DuckAim78] พร้อม — กด AIM เพื่อล็อคเป้าอัตโนมัติ")

-- ==================== หาเป้า ====================
local NAME_WORDS = { "duck", "เป็ด", "bird", "นก" }

local function nameLooksDuck(n)
    n = n:lower()
    for _, w in ipairs(NAME_WORDS) do
        if n:find(w) then return true end
    end
    return false
end

-- ส่วนที่ใช้เล็งของเป้า 1 ตัว (คืน BasePart หรือ nil)
local function aimPartOf(model)
    if model:IsA("BasePart") then return model end
    return model:FindFirstChild("Head")
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChildWhichIsA("BasePart")
end

-- เป้าที่เข้าเกณฑ์ทั้งหมดใน workspace
local function findTargets()
    local out = {}
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and m ~= LP.Character then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local byName = nameLooksDuck(m.Name)
            if byName or ((not NAME_ONLY) and hum and hum.Health > 0) then
                local p = aimPartOf(m)
                if p then out[#out + 1] = { model = m, part = p } end
            end
        elseif m:IsA("BasePart") and nameLooksDuck(m.Name) and not m:FindFirstAncestorWhichIsA("Model") then
            out[#out + 1] = { model = m, part = m }
        end
    end
    return out
end

-- เลือกเป้าที่ "ใกล้กลางจอสุด" และมองเห็นอยู่หน้ากล้อง
local function bestTarget()
    local best, bestAngle = nil, MAX_LOCK_ANGLE
    local camCF = Camera.CFrame
    for _, t in ipairs(findTargets()) do
        if t.part.Parent then
            local dir = (t.part.Position - camCF.Position)
            if dir.Magnitude > 1 then
                local angle = math.deg(math.acos(math.clamp(camCF.LookVector:Dot(dir.Unit), -1, 1)))
                if angle < bestAngle then best, bestAngle = t, angle end
            end
        end
    end
    return best
end

-- ==================== ลูปเล็ง ====================
local aimConn
local function aimStart()
    AIM_ON = true
    aimConn = RunService.RenderStepped:Connect(function()
        if not AIM_ON or _G.DA78_GEN ~= MY_GEN then return end
        local t = bestTarget()
        if t and t.part.Parent then
            local camCF = Camera.CFrame
            local targetCF = CFrame.new(camCF.Position, t.part.Position)
            Camera.CFrame = camCF:Lerp(targetCF, SMOOTH)
            setStatus(("[DuckAim78] 🎯 ล็อค: %s"):format(t.model.Name))
        else
            setStatus("[DuckAim78] ไม่เจอเป้าในระยะกลางจอ — หันกล้องหาเป้าก่อน")
        end
    end)
    table.insert(_G.DA78_CONNS, aimConn)
end
local function aimStop()
    AIM_ON = false
    if aimConn then aimConn:Disconnect() aimConn = nil end
end

-- ==================== Buttons ====================
aimB.MouseButton1Click:Connect(function()
    if AIM_ON then
        aimStop()
        aimB.Text = "AIM: OFF (ล็อคเป้าอัตโนมัติ)"
        setStatus("[DuckAim78] หยุดเล็งแล้ว")
    else
        aimStart()
        aimB.Text = "AIM: ON (กำลังล็อคเป้า...)"
    end
end)
modeB.MouseButton1Click:Connect(function()
    NAME_ONLY = not NAME_ONLY
    modeB.Text = NAME_ONLY and "MODE: เฉพาะชื่อพ้องเป็ด" or "MODE: ทุก NPC"
end)
stopB.MouseButton1Click:Connect(function()
    aimStop()
    aimB.Text = "AIM: OFF (ล็อคเป้าอัตโนมัติ)"
    setStatus("[DuckAim78] หยุดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    aimStop()
    for _, c in ipairs(_G.DA78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DA78_CONNS = {}
    gui:Destroy(); _G.DA78_GUI = nil
end)

warn("[DuckAim78] loaded")
