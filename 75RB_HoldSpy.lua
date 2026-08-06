-- 75RB_HoldSpy.lua v1.0 — สปาย "แหวนโหลด" (การกดค้าง) ว่าทำไมบางทีไม่จบ/ของไม่เข้า
-- จับตั้งแต่แหวนเริ่มเดิน → ทุก 0.1 วิ เก็บ: ระยะ / ตัวยืนพื้นไหม / ความเร็ว / สถานะ Humanoid /
--   prompt ยังเปิดอยู่ไหม / มองเห็นก้อนไหม  → พอแหวนจบ (สำเร็จ/ถูกยกเลิก) พิมพ์ไทม์ไลน์ให้ดู
-- จะได้รู้ว่า "ตอนแหวนขาด" อะไรเปลี่ยนไปกันแน่ (ขยับ? ลอย? หลุดระยะ? โดนบัง?)
-- วิธีใช้: รัน → กดเก็บมือ 2-3 ก้อน (หรือปล่อยบอททำงาน) → COPY ส่งผล
if _G.HSPY75B_GUI then pcall(function() _G.HSPY75B_GUI:Destroy() end) end
if _G.HSPY75B_CONNS then
    for _, c in pairs(_G.HSPY75B_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.HSPY75B_CONNS = {}

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local OUT, T0 = {}, os.clock()
local BOX
local watching = nil     -- {pp=, t0=, samples={}}

local function L(s)
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > 300 then table.remove(OUT, 1) end
    if BOX then BOX.Text = table.concat(OUT, "\n") end
end

local function bagN()
    local pd = LP:FindFirstChild("PlayerData")
    local inv = pd and pd:FindFirstChild("Inventory")
    inv = inv and inv:FindFirstChild("Crystals")
    return inv and #inv:GetChildren() or -1
end

-- เก็บสภาพ ณ วินาทีนั้น
local function sample(pp)
    local holder = pp.Parent
    local char = LP.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local d = (r and holder and holder:IsA("BasePart"))
        and (holder.Position - r.Position).Magnitude or -1
    -- ยืนพื้นไหม (ยิง ray ลง 6 studs)
    local onGround = false
    if r then
        local par = RaycastParams.new()
        par.FilterType = Enum.RaycastFilterType.Exclude
        par.FilterDescendantsInstances = { char }
        onGround = workspace:Raycast(r.Position, Vector3.new(0, -6, 0), par) ~= nil
    end
    -- มองเห็นก้อนไหม
    local see = true
    if r and holder and holder:IsA("BasePart") then
        local par2 = RaycastParams.new()
        par2.FilterType = Enum.RaycastFilterType.Exclude
        par2.FilterDescendantsInstances = { char, holder }
        see = workspace:Raycast(r.Position, holder.Position - r.Position, par2) == nil
    end
    return {
        d = d, ground = onGround, see = see,
        vel = r and r.AssemblyLinearVelocity.Magnitude or -1,
        state = h and tostring(h:GetState()):gsub("Enum.HumanoidStateType%.", "") or "?",
        en = pp.Enabled, max = pp.MaxActivationDistance,
        bag = bagN(),
    }
end
local function fmtS(s)
    return ("ห่าง%.1f %s %s vel%.0f %s max%d ถุง%d"):format(
        s.d, s.ground and "ยืนพื้น" or "ลอย", s.see and "เห็น" or "โดนบัง",
        s.vel, s.state, s.max, s.bag)
end

-- ==================== ดักแหวนโหลด ====================
table.insert(_G.HSPY75B_CONNS, PPS.PromptButtonHoldBegan:Connect(function(pp, plr)
    if plr ~= LP then return end
    local holder = pp.Parent
    local nm = holder and (holder:GetAttribute("CrystalName") or holder.Name) or "?"
    watching = { pp = pp, t0 = os.clock(), nm = nm, hold = pp.HoldDuration, trig = false, samples = {} }
    L(("🔵 แหวนเริ่ม: %s (ต้องกด %.1f วิ) | %s"):format(nm, pp.HoldDuration, fmtS(sample(pp))))
    task.spawn(function()
        local w = watching
        while watching == w and os.clock() - w.t0 < w.hold + 6 do
            w.samples[#w.samples + 1] = { t = os.clock() - w.t0, s = sample(pp) }
            task.wait(0.1)
        end
    end)
end))

table.insert(_G.HSPY75B_CONNS, PPS.PromptTriggered:Connect(function(pp, plr)
    if plr ~= LP then return end
    if watching and watching.pp == pp then
        watching.trig = true
        L(("⚡ แหวนเต็ม! (กดไป %.2f วิ) — ครบเวลา"):format(os.clock() - watching.t0))
    else
        L("⚡ TRIGGER (ไม่มีแหวนนำ = สคริปต์ยิง)")
    end
end))

table.insert(_G.HSPY75B_CONNS, PPS.PromptButtonHoldEnded:Connect(function(pp, plr)
    if plr ~= LP then return end
    local w = watching
    if not w or w.pp ~= pp then return end
    watching = nil
    local dt = os.clock() - w.t0
    local done = w.trig
    L(("%s แหวนจบที่ %.2f/%.1f วิ — %s"):format(done and "✅" or "❌", dt, w.hold,
        done and "ครบ (รอของเข้า)" or "**ถูกยกเลิกก่อนครบ**"))
    -- ไทม์ไลน์: โชว์เฉพาะตอนที่ค่าเปลี่ยน (เห็นว่าอะไรพังตอนไหน)
    local last
    for _, e in ipairs(w.samples) do
        local s = e.s
        local key = ("%s|%s|%d|%s"):format(tostring(s.ground), tostring(s.see), s.max, s.state)
        if key ~= last then
            L(("    +%.1f วิ | %s"):format(e.t, fmtS(s)))
            last = key
        end
    end
    -- เฝ้าดูต่อว่าของเข้าไหมใน 5 วิ
    local n0 = bagN()
    task.spawn(function()
        for i = 1, 50 do
            task.wait(0.1)
            if bagN() > n0 then
                L(("    📦 ของเข้ากระเป๋าใน %.1f วิหลังปล่อย"):format(i * 0.1))
                return
            end
        end
        L("    🚫 ครบ 5 วิแล้วของไม่เข้า")
    end)
end))

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "HoldSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.HSPY75B_GUI = gui

local box = Instance.new("TextBox", gui)
BOX = box
box.Size = UDim2.new(0, 660, 0, 300); box.Position = UDim2.new(0, 8, 0.32, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(255, 230, 190); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Bottom
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.32, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local clearB = hbtn("CLEAR", 8, 70, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 84, 70)
local hideB  = hbtn("ซ่อน", 158, 60, Color3.fromRGB(50, 50, 70))
local closeB = hbtn("✕", 222, 34, Color3.fromRGB(150, 40, 40))

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
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_hold_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function()
    for _, c in pairs(_G.HSPY75B_CONNS) do pcall(function() c:Disconnect() end) end
    _G.HSPY75B_CONNS = {}
    gui:Destroy(); _G.HSPY75B_GUI = nil
end)

L("[HoldSpy v1.0] เฝ้าดูแหวนโหลด — ปล่อยบอททำงาน หรือกดเก็บมือ แล้ว COPY")
L("จะบอก: แหวนครบไหม / ถูกยกเลิกตอนไหน / ตอนนั้นลอยหรือยืนพื้น / โดนบังไหม / ของเข้าเมื่อไหร่")
