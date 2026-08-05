-- 75RB_PickSpy.lua v1.0 — สปายจังหวะเก็บของ: ทำไม fp ยิงแล้ว ❌ หมด (แม้ @23m)?
-- ทฤษฎี: server จับเวลากดค้างจริง (Hold 1-5 วิ) — เราตั้ง Hold=0 ยิงทันทีเลยโดนปัด
-- ดัก: PromptButtonHoldBegan / HoldEnded / PromptTriggered พร้อมเวลา (วัดช่วงกดค้าง)
--      + สแนป prompt (Hold/ระยะ/LoS) + จับตอนก้อน "หายจากแมพ" (=เก็บเข้าจริง)
-- วิธีใช้: รัน → เก็บมือ 1 ก้อน (กด E ค้างปกติ) → เปิด Assist ให้มันยิงพลาด 1 ก้อน
--          → กด COPY วางผลมาเทียบกัน
if _G.PSPY75_GUI then pcall(function() _G.PSPY75_GUI:Destroy() end) end
if _G.PSPY75_CONNS then
    for _, c in pairs(_G.PSPY75_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.PSPY75_CONNS = {}

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local OUT = {}
local T0 = os.clock()
local holdT = {}   -- [prompt] = clock ตอนเริ่มกดค้าง

local box   -- forward
local function L(s)
    OUT[#OUT + 1] = ("[%7.2f] %s"):format(os.clock() - T0, s)
    if #OUT > 300 then table.remove(OUT, 1) end
    if box then box.Text = table.concat(OUT, "\n") end
end
local function myDist(part)
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not r or not part then return -1 end
    return math.floor((part.Position - r.Position).Magnitude)
end
local function pInfo(pp)
    local holder = pp.Parent
    local name = holder and (holder:GetAttribute("CrystalName") or holder.Name) or "?"
    return ("%s @%dm [Hold=%.1f Max=%d LoS=%s En=%s]"):format(
        name, myDist(holder), pp.HoldDuration, pp.MaxActivationDistance,
        tostring(pp.RequiresLineOfSight), tostring(pp.Enabled))
end

-- จังหวะกดค้าง (มือจริงจะมี Began → (1-5 วิ) → Triggered | fp จะไม่มี Began เลย!)
table.insert(_G.PSPY75_CONNS, PPS.PromptButtonHoldBegan:Connect(function(pp)
    holdT[pp] = os.clock()
    L("HOLD เริ่มกด: " .. pInfo(pp))
end))
table.insert(_G.PSPY75_CONNS, PPS.PromptButtonHoldEnded:Connect(function(pp)
    local dt = holdT[pp] and (os.clock() - holdT[pp]) or -1
    L(("HOLD ปล่อย (ค้าง %.2f วิ): %s"):format(dt, pInfo(pp)))
end))
table.insert(_G.PSPY75_CONNS, PPS.PromptTriggered:Connect(function(pp, plr)
    if plr ~= LP then return end
    local dt = holdT[pp] and (os.clock() - holdT[pp]) or -1
    local holder = pp.Parent
    L(("TRIGGER%s: %s"):format(dt >= 0 and (" (หลังกด %.2f วิ)"):format(dt) or " (ไม่มี HOLD ก่อน=fp!)",
        pInfo(pp)))
    -- เฝ้าดูว่าก้อนหายจากแมพใน 3 วิไหม (= server รับ เก็บเข้ากระเป๋าจริง)
    if holder then
        task.spawn(function()
            local nm = holder:GetAttribute("CrystalName") or holder.Name
            for i = 1, 30 do
                if not holder.Parent then
                    L(("  → ✅ '%s' หายจากแมพใน %.1f วิ = เก็บสำเร็จ"):format(nm, i * 0.1))
                    return
                end
                task.wait(0.1)
            end
            L(("  → ❌ '%s' ยังอยู่หลัง 3 วิ = server ไม่รับ"):format(nm))
        end)
    end
end))

-- attr ของตัวเราเปลี่ยนไหมตอนเก็บ (น้ำหนัก/จำนวน อยู่ไหน)
task.spawn(function()
    for _, obj in ipairs({ LP, LP.Character }) do
        if obj then
            table.insert(_G.PSPY75_CONNS, obj.AttributeChanged:Connect(function(k)
                L(("ATTR %s.%s = %s"):format(obj.Name, k, tostring(obj:GetAttribute(k))))
            end))
        end
    end
end)

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "PickSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.PSPY75_GUI = gui

box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 640, 0, 320); box.Position = UDim2.new(0, 8, 0.28, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(255, 230, 170); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Bottom
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.28, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local clearB = hbtn("CLEAR", 8, 70, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 84, 70)
local closeB = hbtn("✕", 158, 34, Color3.fromRGB(150, 40, 40))

clearB.MouseButton1Click:Connect(function() OUT = {}; box.Text = "" end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_pick_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function()
    for _, c in pairs(_G.PSPY75_CONNS) do pcall(function() c:Disconnect() end) end
    _G.PSPY75_CONNS = {}
    gui:Destroy(); _G.PSPY75_GUI = nil
end)

L("[PickSpy v1.0] พร้อม — 1) เก็บมือ 1 ก้อน (กด E ค้างปกติ)")
L("2) เปิด Assist ให้ยิงพลาด 1 ก้อน  3) กด COPY ส่งผล")
