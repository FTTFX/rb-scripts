-- 78RB_DuckAim.lua v2.1 — เลือกเกณฑ์เป้าได้ (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v2.1: ปุ่ม TARGET สลับเกณฑ์: ใกล้สุด / ไม่มีอะไรบัง (raycast เช็คสิ่งกีดขวาง — ค่าเริ่มต้น) /
--   คะแนนเยอะสุด (อ่าน attribute/Value ตัวเลขบนโมเดลเป็ด) — ใช้ทั้ง SILENT และ AIM กล้อง
-- จาก DuckSpy log ยืนยันแล้ว:
--   เป้า: workspace.Ume.DuckController_Client_N (เป็ดบินระนาบ X~258 เกิด-หายตลอด)
--   ยิง:  <remote ชื่อสุ่ม>:FireServer(Vector3 จุดยิง, Vector3 ทิศทาง, number, number timestamp)
--         → เซิร์ฟเวอร์คิดผลจาก "ทิศทาง" ที่ client ส่ง = สลับทิศให้พุ่งเข้าเป็ดก่อนส่งได้ (Silent Aim)
-- ปุ่ม: SILENT (ยิงตรงไหนก็โดนเป็ด) | AIM (ล็อคกล้อง) | STOP | ✕
-- remote ชื่อสุ่มต่อเซสชัน — จับจากลายเซ็น args (V3, V3, num, num) ไม่อิงชื่อ
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

local SILENT_ON = true -- เปิดมาก็พร้อมใช้เลย
local AIM_ON = false
local SMOOTH = 0.35
local MAX_LOCK_ANGLE = 60

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
local silentB = mkbtn("SILENT: ON (ยิงตรงไหนก็โดน)", 48, Color3.fromRGB(60, 170, 90))
local aimB    = mkbtn("AIM: OFF (ล็อคกล้องที่เป็ด)", 78, Color3.fromRGB(190, 60, 60))
local targetB = mkbtn("TARGET: ไม่มีอะไรบัง", 108, Color3.fromRGB(60, 110, 180))
local stopB   = mkbtn("STOP", 138, Color3.fromRGB(150, 60, 30))
local closeB  = mkbtn("✕ ปิด", 168, Color3.fromRGB(90, 40, 40))
frame.Size = UDim2.new(0, 250, 0, 200)

setStatus("[DuckAim78] SILENT พร้อม — ยิงได้เลย กระสุนวิ่งเข้าเป็ดเอง")

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
        if m:IsA("Model") and m.Name:find("DuckController") then
            local p = duckPos(m)
            if p then out[#out + 1] = { model = m, pos = p } end
        end
    end
    return out
end

-- ==================== เกณฑ์เลือกเป้า (v2.1): ใกล้สุด / ไม่มีอะไรบัง / คะแนนเยอะสุด ====================
local TARGET_MODES = { "ใกล้สุด", "ไม่มีอะไรบัง", "คะแนนเยอะสุด" }
local targetModeIdx = 2 -- ค่าเริ่มต้น: ตัวที่มองเห็นไม่มีอะไรบัง (ใกล้สุดในกลุ่มนั้น)

-- ยิง ray จากจุดยิงไปเป็ด — เจอสิ่งอื่นขวางก่อนถึง = โดนบัง
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function duckVisible(origin, d)
    local char = LP.Character
    local f = duckFolder()
    rayParams.FilterDescendantsInstances = { char, f } -- ไม่นับตัวเรา/เป็ดตัวอื่นเป็นสิ่งบัง
    local dir = d.pos - origin
    local hit = workspace:Raycast(origin, dir, rayParams)
    return hit == nil -- ทะลุถึงเป้า (เป็ดถูก exclude ไปแล้ว ไม่เจออะไร = โล่ง)
end

-- อ่าน "คะแนน" ของเป็ด: attribute ตัวเลข หรือ ValueBase ลูก (ไม่รู้ชื่อจริง เลยเอาค่าตัวเลขมากสุดที่เจอ)
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
        -- เอาเฉพาะตัวที่มองเห็นโล่งๆ แล้วเลือกตัวใกล้สุดในนั้น — ไม่มีตัวโล่งเลยค่อยตกไปใกล้สุดปกติ
        local best, bestDist = nil, math.huge
        for _, d in ipairs(ducks) do
            if duckVisible(origin, d) then
                local dist = (d.pos - origin).Magnitude
                if dist < bestDist then best, bestDist = d, dist end
            end
        end
        if best then return best end
    end

    -- ใกล้สุด (และ fallback ของโหมดไม่มีอะไรบัง)
    local best, bestDist = nil, math.huge
    for _, d in ipairs(ducks) do
        local dist = (d.pos - origin).Magnitude
        if dist < bestDist then best, bestDist = d, dist end
    end
    return best
end

local function bestDuckForShot(origin, dir)
    return pickDuck(origin)
end

-- เป้าสำหรับล็อคกล้อง — ใช้เกณฑ์เดียวกับ SILENT (ตามโหมด TARGET)
local function bestDuckOnScreen()
    return pickDuck(Camera.CFrame.Position)
end

-- ==================== SILENT AIM: ดักคำสั่งยิง สลับทิศทางก่อนส่ง ====================
-- ลายเซ็นจาก log: FireServer(Vector3 origin, Vector3 dir, number, number) — ไม่อิงชื่อ remote (ชื่อสุ่ม)
if hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if _G.DA78_GEN == MY_GEN and SILENT_ON and getnamecallmethod() == "FireServer" then
            local args = { ... }
            if #args >= 4
                and typeof(args[1]) == "Vector3"
                and typeof(args[2]) == "Vector3"
                and typeof(args[3]) == "number"
                and typeof(args[4]) == "number" then
                local duck = bestDuckForShot(args[1], args[2])
                if duck then
                    args[2] = (duck.pos - args[1]).Unit
                    setStatus(("[DuckAim78] 🎯 ยิงเข้า: %s"):format(duck.model.Name))
                    return old(self, unpack(args))
                end
            end
        end
        return old(self, ...)
    end)
else
    setStatus("[DuckAim78] ❌ executor ไม่มี hookmetamethod — SILENT ใช้ไม่ได้ (AIM กล้องยังใช้ได้)")
    SILENT_ON = false
    silentB.Text = "SILENT: ใช้ไม่ได้ (no hook)"
end

-- ==================== AIM กล้อง (เสริม — เผื่ออยากเห็นภาพล็อคเป้า) ====================
local aimConn
local function aimStart()
    AIM_ON = true
    aimConn = RunService.RenderStepped:Connect(function()
        if not AIM_ON or _G.DA78_GEN ~= MY_GEN then return end
        local d = bestDuckOnScreen()
        if d and d.model.Parent then
            local p = duckPos(d.model)
            if p then
                local camCF = Camera.CFrame
                Camera.CFrame = camCF:Lerp(CFrame.new(camCF.Position, p), SMOOTH)
            end
        end
    end)
    table.insert(_G.DA78_CONNS, aimConn)
end
local function aimStop()
    AIM_ON = false
    if aimConn then aimConn:Disconnect() aimConn = nil end
end

-- ==================== Buttons ====================
targetB.MouseButton1Click:Connect(function()
    targetModeIdx = targetModeIdx % #TARGET_MODES + 1
    targetB.Text = "TARGET: " .. TARGET_MODES[targetModeIdx]
end)
silentB.MouseButton1Click:Connect(function()
    SILENT_ON = not SILENT_ON
    silentB.Text = SILENT_ON and "SILENT: ON (ยิงตรงไหนก็โดน)" or "SILENT: OFF"
end)
aimB.MouseButton1Click:Connect(function()
    if AIM_ON then
        aimStop()
        aimB.Text = "AIM: OFF (ล็อคกล้องที่เป็ด)"
    else
        aimStart()
        aimB.Text = "AIM: ON (กล้องตามเป็ด)"
    end
end)
stopB.MouseButton1Click:Connect(function()
    SILENT_ON = false
    silentB.Text = "SILENT: OFF"
    aimStop()
    aimB.Text = "AIM: OFF (ล็อคกล้องที่เป็ด)"
    setStatus("[DuckAim78] หยุดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    SILENT_ON = false
    aimStop()
    for _, c in ipairs(_G.DA78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DA78_CONNS = {}
    gui:Destroy(); _G.DA78_GUI = nil
end)

warn("[DuckAim78] v2.0 loaded")
