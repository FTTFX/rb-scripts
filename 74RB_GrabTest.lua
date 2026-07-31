-- 74RB_GrabTest.lua v1.0 — ทดสอบ "เสกของ": ยิง fireproximityprompt ใส่จุดเก็บยาจาก "ระยะไกล"
-- โดยไม่ขยับตัวเลย แล้วเช็คว่าของเข้ามือไหม (Backpack/ตัว)
-- ✓ = server ไม่เช็คระยะ → main เลิกบินไปเก็บยาได้เลย (เร็วขึ้นมหาศาล)
-- ✗ = server เช็คระยะ → ต้องบินไปเก็บเหมือนเดิม
-- วิธีใช้: ยืนที่ไหนก็ได้ "ไกลๆ จากยา" → กดชื่อยา → ดูผล ; ลองทั้งตัวจริง (ปีกยา) และตัวก๊อป (โซน 0,0)

if _G.GRABTEST_GUI then pcall(function() _G.GRABTEST_GUI:Destroy() end) end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

local MEDS = { "Medicine", "Bandages", "Herbs", "Eye Drops", "Cough Syrup", "Maple Syrup", "IV Drops", "Medkit", "Ointment", "Thermo" }

local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local p = (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")))
        or inst:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end
local function heldCount(name)
    local n = 0
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t.Name == name then n += 1 end end end
    if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do if t.Name == name then n += 1 end end end
    return n
end

local gui = Instance.new("ScreenGui")
gui.Name = "GrabTest"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.GRABTEST_GUI = gui

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 240, 0, 320), UDim2.new(0.5, -120, 0.35, -100)
f.BackgroundColor3, f.Active, f.Draggable = Color3.fromRGB(15, 15, 22), true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local res = Instance.new("TextLabel", f)
res.Size, res.Position = UDim2.new(1, -12, 0, 54), UDim2.new(0, 6, 0, 4)
res.BackgroundTransparency = 1; res.TextColor3 = Color3.fromRGB(255, 230, 150)
res.Font, res.TextSize, res.TextWrapped = Enum.Font.Code, 12, true
res.TextXAlignment, res.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
res.Text = "กดชื่อยาเพื่อทดสอบเสกจากระยะไกล\n(ยืนให้ห่างจุดยาก่อนกด)"

local function testGrab(name)
    if not fp then res.Text = "❌ executor ไม่มี fireproximityprompt"; return end
    local me = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local mp = me and me.Position
    -- หา prompt ชื่อนี้ "ไกลสุด" (ทดสอบสุดทาง) + จดระยะ
    local best, bd
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == name and p.Enabled and p.Parent then
            local pos = partPos(p.Parent)
            local d = pos and mp and (pos - mp).Magnitude
            if d and (not best or d > bd) then best, bd = p, d end
        end
    end
    if not best then res.Text = ("'%s' ไม่เจอ prompt เปิดอยู่"):format(name); return end
    local before = heldCount(name)
    local oldHold = best.HoldDuration
    pcall(function() best.HoldDuration = 0 end)
    pcall(fp, best, 0)
    pcall(function() best.HoldDuration = oldHold end)
    res.Text = ("ยิง '%s' ระยะ %.0fm … รอผล"):format(name, bd)
    task.delay(1, function()
        local after = heldCount(name)
        if after > before then
            res.Text = ("✅ เสกได้! '%s' เข้ามือจากระยะ %.0fm\n(server ไม่เช็คระยะ — บอกผมเลย)"):format(name, bd)
        else
            res.Text = ("❌ ไม่เข้า '%s' (ระยะ %.0fm)\nลองยืนใกล้ขึ้น/ยาอื่นดู"):format(name, bd)
        end
    end)
end

for i, name in ipairs(MEDS) do
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, 110, 0, 24)
    b.Position = UDim2.new(0, 6 + ((i - 1) % 2) * 114, 0, 62 + math.floor((i - 1) / 2) * 27)
    b.Text = name; b.Font = Enum.Font.Gotham; b.TextSize = 11
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 60); b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function() testGrab(name) end)
end

local closeB = Instance.new("TextButton", f)
closeB.Size, closeB.Position = UDim2.new(0, 228, 0, 24), UDim2.new(0, 6, 1, -30)
closeB.Text = "CLOSE"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 12
closeB.BackgroundColor3 = Color3.fromRGB(120, 30, 30); closeB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)
closeB.MouseButton1Click:Connect(function() gui:Destroy(); _G.GRABTEST_GUI = nil end)

print("[74RB GrabTest v1.0] พร้อม — ยืนไกลๆ แล้วกดชื่อยา")
