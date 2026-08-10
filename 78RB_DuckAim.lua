-- 78RB_DuckAim.lua v3.0 — Auto Aim กล้องอย่างเดียว + คีย์ลัด L (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v3.0: ถอด SILENT ออกทั้งระบบ — ตัวดัก FireServer ไปโดนคำสั่งรีโหลดกระสุนด้วย (ลายเซ็น args ชนกัน)
--   ทำให้รีโหลดไม่ได้ เหลือ AIM ล็อคกล้องอย่างเดียว ปลอดภัยไม่แตะ remote ใดๆ + กด L เปิด/ปิด AIM
-- เป้า = ทุกโมเดลในโฟลเดอร์ workspace.Ume (เป็ดปกติ DuckController_Client_N + บอสชื่ออื่น)
-- ปุ่ม: AIM (คีย์ลัด L) | TARGET (ใกล้สุด/ไม่มีอะไรบัง/คะแนนเยอะสุด) | STOP | ✕
if _G.DA78_GUI then pcall(function() _G.DA78_GUI:Destroy() end) end
if _G.DA78_CONNS then
    for _, c in ipairs(_G.DA78_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.DA78_CONNS = {}
_G.DA78_GEN = (_G.DA78_GEN or 0) + 1
local MY_GEN = _G.DA78_GEN

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local AIM_ON = false
local SMOOTH = 0.35

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DuckAim78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.DA78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 250, 0, 200); frame.Position = UDim2.new(0, 8, 0.3, 0)
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
local aimB    = mkbtn("AIM: OFF (คีย์ลัด L)", 48, Color3.fromRGB(190, 60, 60))
local targetB = mkbtn("TARGET: ไม่มีอะไรบัง", 78, Color3.fromRGB(60, 110, 180))
local stopB   = mkbtn("STOP", 108, Color3.fromRGB(150, 60, 30))
local closeB  = mkbtn("✕ ปิด", 138, Color3.fromRGB(90, 40, 40))
frame.Size = UDim2.new(0, 250, 0, 170)

setStatus("[DuckAim78] พร้อม — กด L หรือปุ่ม AIM เพื่อล็อคกล้องที่เป็ด")

-- ==================== หาเป็ด ====================
local function duckFolder()
    return workspace:FindFirstChild("Ume")
end

local function duckPos(m)
    local p = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end

local function allDucks()
    local out = {}
    local f = duckFolder()
    if not f then return out end
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") then
            local p = duckPos(m)
            if p then out[#out + 1] = { model = m, pos = p } end
        end
    end
    return out
end

-- ==================== เกณฑ์เลือกเป้า: ใกล้สุด / ไม่มีอะไรบัง / คะแนนเยอะสุด ====================
local TARGET_MODES = { "ใกล้สุด", "ไม่มีอะไรบัง", "คะแนนเยอะสุด" }
local targetModeIdx = 2

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function duckVisible(origin, d)
    rayParams.FilterDescendantsInstances = { LP.Character, duckFolder() }
    local hit = workspace:Raycast(origin, d.pos - origin, rayParams)
    return hit == nil
end

local function duckScore(d)
    local best = 0
    for _, v in pairs(d.model:GetAttributes()) do
        if type(v) == "number" and v > best then best = v end
    end
    for _, c in ipairs(d.model:GetDescendants()) do
        if (c:IsA("IntValue") or c:IsA("NumberValue")) and c.Value > best then best = c.Value end
    end
    return best
end

local function pickDuck(origin)
    local ducks = allDucks()
    if #ducks == 0 then return nil end
    local mode = TARGET_MODES[targetModeIdx]

    if mode == "คะแนนเยอะสุด" then
        local best, bestScore = nil, -1
        for _, d in ipairs(ducks) do
            local s = duckScore(d)
            if s > bestScore then best, bestScore = d, s end
        end
        return best
    end

    if mode == "ไม่มีอะไรบัง" then
        local best, bestDist = nil, math.huge
        for _, d in ipairs(ducks) do
            if duckVisible(origin, d) then
                local dist = (d.pos - origin).Magnitude
                if dist < bestDist then best, bestDist = d, dist end
            end
        end
        if best then return best end
    end

    local best, bestDist = nil, math.huge
    for _, d in ipairs(ducks) do
        local dist = (d.pos - origin).Magnitude
        if dist < bestDist then best, bestDist = d, dist end
    end
    return best
end

-- ==================== ลูปล็อคกล้อง ====================
local aimConn
local function aimStop()
    AIM_ON = false
    if aimConn then aimConn:Disconnect() aimConn = nil end
    aimB.Text = "AIM: OFF (คีย์ลัด L)"
end
local function aimStart()
    AIM_ON = true
    aimB.Text = "AIM: ON (กล้องตามเป็ด — กด L ปิด)"
    aimConn = RunService.RenderStepped:Connect(function()
        if not AIM_ON or _G.DA78_GEN ~= MY_GEN then return end
        local d = pickDuck(Camera.CFrame.Position)
        if d and d.model.Parent then
            local p = duckPos(d.model)
            if p then
                local camCF = Camera.CFrame
                Camera.CFrame = camCF:Lerp(CFrame.new(camCF.Position, p), SMOOTH)
                setStatus(("[DuckAim78] 🎯 ล็อค: %s"):format(d.model.Name))
            end
        else
            setStatus("[DuckAim78] ไม่เจอเป้า — รอเป็ดโผล่")
        end
    end)
    table.insert(_G.DA78_CONNS, aimConn)
end
local function aimToggle()
    if AIM_ON then aimStop() else aimStart() end
end

-- คีย์ลัด L
table.insert(_G.DA78_CONNS, UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.L and _G.DA78_GEN == MY_GEN then
        aimToggle()
    end
end))

-- ==================== Buttons ====================
aimB.MouseButton1Click:Connect(aimToggle)
targetB.MouseButton1Click:Connect(function()
    targetModeIdx = targetModeIdx % #TARGET_MODES + 1
    targetB.Text = "TARGET: " .. TARGET_MODES[targetModeIdx]
end)
stopB.MouseButton1Click:Connect(function()
    aimStop()
    setStatus("[DuckAim78] หยุดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    aimStop()
    for _, c in ipairs(_G.DA78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DA78_CONNS = {}
    gui:Destroy(); _G.DA78_GUI = nil
end)

warn("[DuckAim78] v3.0 loaded")
