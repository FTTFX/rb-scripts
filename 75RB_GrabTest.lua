-- 75RB_GrabTest.lua v1.0 — ลอง "ยิงรีโมตให้ของเข้าตัว" 5 แบบ + สปายในตัว
-- เป้าหมาย: หาวิธีเก็บที่ไม่ต้องกดค้าง 4-5 วิ/ก้อน (ตอนนี้ยิงตรงได้บ้างไม่ได้บ้าง)
-- 5 แบบที่ลอง (เว้นจังหวะ 1 วิ กัน server throttle):
--   1) CrystalHoldComplete:FireServer(ก้อน)                  ← แบบที่เคยเข้า
--   2) CrystalDroppedPickup:FireServer(ก้อน)                  ← remote ของก้อนตกพื้น
--   3) CrystalHoldComplete:FireServer(ก้อน, true)             ← เผื่อมี arg ที่ 2
--   4) CrystalHoldComplete:FireServer(prompt)                 ← ส่ง prompt แทนก้อน
--   5) InputHoldBegin/End จริง (ตัวเทียบ — รู้อยู่แล้วว่าเข้า)
-- สปาย: ดัก Inventory.Crystals.ChildAdded (ของเข้าจริง) + log remote ที่ยิงออก + ระยะ/prompt
-- วิธีใช้: ยืนใกล้ก้อน (ไม่ต้องกดอะไร) → กด "ทดสอบ 5 แบบ" → COPY ส่งผล
if _G.GT75_GUI then pcall(function() _G.GT75_GUI:Destroy() end) end
if _G.GT75_CONNS then
    for _, c in pairs(_G.GT75_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.GT75_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT, T0 = {}, os.clock()
local BOX
local Rem = RS:FindFirstChild("Remotes")
local pickR = Rem and Rem:FindFirstChild("CrystalHoldComplete")
local dropR = Rem and Rem:FindFirstChild("CrystalDroppedPickup")

local function L(s)
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > 300 then table.remove(OUT, 1) end
    if BOX then BOX.Text = table.concat(OUT, "\n") end
end

local function invFolder()
    local pd = LP:FindFirstChild("PlayerData")
    local inv = pd and pd:FindFirstChild("Inventory")
    return inv and inv:FindFirstChild("Crystals")
end
local function bagN()
    local f = invFolder()
    return f and #f:GetChildren() or -1
end
local function myPos()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return r and r.Position
end

-- สปาย: ของเข้ากระเป๋าเมื่อไหร่
task.spawn(function()
    local f = invFolder()
    if not f then L("❌ ไม่เจอ Inventory.Crystals") return end
    table.insert(_G.GT75_CONNS, f.ChildAdded:Connect(function(c)
        task.wait(0.05)
        L(("   📦 เข้ากระเป๋า: %s %.1fkg (รวม %d ก้อน)"):format(
            tostring(c:GetAttribute("CrystalName") or c.Name),
            c:GetAttribute("WeightKg") or 0, bagN()))
    end))
end)

-- หาก้อนใกล้สุดที่ยังไม่โดนเก็บ
local function nearestCrystal()
    local mp = myPos()
    if not mp then return nil end
    local best, bd
    for _, c in ipairs(workspace:GetDescendants()) do
        if c:IsA("BasePart") and c:GetAttribute("CrystalName")
            and not c:FindFirstAncestor("Plots") then
            local d = (c.Position - mp).Magnitude
            if not bd or d < bd then best, bd = c, d end
        end
    end
    return best, bd
end

local function runTests()
    local c, d = nearestCrystal()
    if not c then L("❌ ไม่เจอก้อนใกล้ตัว") return end
    local pp = c:FindFirstChildOfClass("ProximityPrompt")
    L("")
    L(("===== ทดสอบกับ: %s %.1fkg $%s | ห่าง %.1f | Max=%s Hold=%s ====="):format(
        c:GetAttribute("CrystalName"), c:GetAttribute("WeightKg") or 0,
        tostring(c:GetAttribute("Value")), d,
        pp and tostring(pp.MaxActivationDistance) or "ไม่มี prompt",
        pp and tostring(pp.HoldDuration) or "-"))

    local tests = {
        { "1) HoldComplete(ก้อน)", function()
            if pickR then pickR:FireServer(c) end
        end },
        { "2) DroppedPickup(ก้อน)", function()
            if dropR then dropR:FireServer(c) end
        end },
        { "3) HoldComplete(ก้อน, true)", function()
            if pickR then pickR:FireServer(c, true) end
        end },
        { "4) HoldComplete(prompt)", function()
            if pickR and pp then pickR:FireServer(pp) end
        end },
        { "5) InputHold จริง (ตัวเทียบ)", function()
            if pp then
                pp:InputHoldBegin()
                task.wait(pp.HoldDuration + 0.5)
                pp:InputHoldEnd()
            end
        end },
    }

    for _, t in ipairs(tests) do
        if not c.Parent then L("   (ก้อนหายแล้ว — จบการทดสอบ)") return end
        local n0 = bagN()
        L("▶ " .. t[1])
        local ok, err = pcall(t[2])
        if not ok then L("   💥 " .. tostring(err)) end
        -- รอผล 2 วิ (ของเข้าช้ากว่าคำสั่งได้ถึง ~1 วิ)
        local got = false
        for _ = 1, 20 do
            task.wait(0.1)
            if bagN() > n0 then got = true break end
        end
        L(("   %s"):format(got and "✅ เข้า!" or "❌ ไม่เข้า"))
        if got then
            L("   → วิธีนี้ใช้ได้! เอาไปใส่ AutoFarm ได้เลย")
            return
        end
        task.wait(1)   -- เว้นจังหวะ กัน server throttle
    end
    L("=== ครบ 5 แบบ ===")
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "GrabTest75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.GT75_GUI = gui

local box = Instance.new("TextBox", gui)
BOX = box
box.Size = UDim2.new(0, 640, 0, 280); box.Position = UDim2.new(0, 8, 0.34, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(190, 255, 200); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Bottom
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.34, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local runB   = hbtn("ทดสอบ 5 แบบ", 8, 110, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 122, 66, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 192, 66)
local hideB  = hbtn("ซ่อน", 262, 56, Color3.fromRGB(50, 50, 70))
local closeB = hbtn("✕", 322, 34, Color3.fromRGB(150, 40, 40))

runB.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ok, err = pcall(runTests)
        if not ok then L("💥 ERROR: " .. tostring(err)) end
    end)
end)
clearB.MouseButton1Click:Connect(function() OUT = {}; box.Text = "" end)
hideB.MouseButton1Click:Connect(function()
    box.Visible = not box.Visible
    hideB.Text = box.Visible and "ซ่อน" or "โชว์"
end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_grab_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function()
    for _, c in pairs(_G.GT75_CONNS) do pcall(function() c:Disconnect() end) end
    _G.GT75_CONNS = {}
    gui:Destroy(); _G.GT75_GUI = nil
end)

L("[GrabTest v1.0] ยืนใกล้ก้อน (ไม่ต้องกดอะไร) → กด 'ทดสอบ 5 แบบ'")
L(("remote: HoldComplete=%s DroppedPickup=%s | กระเป๋าตอนนี้ %d ก้อน"):format(
    tostring(pickR ~= nil), tostring(dropR ~= nil), bagN()))
