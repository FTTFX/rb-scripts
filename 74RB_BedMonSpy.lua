-- 74RB_BedMonSpy.lua v2.1 — สปายผีใต้เตียง (MonsterBed): โดนจับแล้ว "การกด" ทำงานผ่านอะไรกันแน่?
-- v2.1: ปุ่ม "พับ" (ย่อ/กางกล่อง log) + "RESCAN" (ล้างจอ + dump สถานะปัจจุบันใหม่) — ผู้ใช้ขอ
-- v2.2: พับ = ซ่อนหมดเหลือปุ่มจิ๋ว "สปาย" + โดนจับแล้วกางเอง (ผู้ใช้: รกจอตอนตามหาผีเตียง)
-- v2.5: ดัก "จุดยืนส่งน้ำเชื่อม" — ถือ Maple Syrup ใกล้ MonsterBed = log ตำแหน่ง/ระยะ/พิกัดแกนเตียง
--       ทุก 0.7s + วินาทีน้ำเชื่อมหายจากมือ (ส่งสำเร็จ) จับพิกัดเป๊ะ (ผู้ใช้: ต้องยืนถูกจุดถึงส่งได้)
-- v1.0 พิสูจน์แล้ว: สัญญาณจับ = Humanoid.PlatformStand=true — แต่ไม่ได้ดัก prompt/remote ต่อการกด
-- v2.0 อุดช่อง: + ProximityPrompt โผล่ใหม่ทุกที่ (บนตัวเรา/เตียง/workspace)
--              + ProximityPromptService.PromptShown/Triggered (จับ prompt ดิ้นที่อาจซ่อนอยู่)
--              + remote ทุกตัวที่ยิงตอนช่วงโดนจับ (ดูว่ากด E 1 ที = ยิงอะไร)
--              + attr เปลี่ยนบน MonsterBed
-- วิธีใช้: รัน → ปิด "หนีผีใต้เตียง" ใน main ก่อน (ให้กดมือ จะได้เห็น mapping กด→ผล)
--          → ให้โดนจับ → กด E มือถือๆ → หลุดแล้วกด COPY เอาผลมาให้ดู

if _G.BEDMONSPY_CONNS then
    for _, c in pairs(_G.BEDMONSPY_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.BEDMONSPY_CONNS = {}
local CONNS = _G.BEDMONSPY_CONNS

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local OUT, LINES = {}, {}
local T0 = os.clock()
local GRABBED = false   -- ช่วงโดนจับ = log ละเอียด

local gui = Instance.new("ScreenGui")
gui.Name = "BedMonSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 560, 0, 340); box.Position = UDim2.new(0, 8, 0.28, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(255, 200, 120); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[BedMonSpy v2.0] พร้อม — ปิดหนีอัตโนมัติใน main แล้วไปโดนจับ"

-- v2.1: แถวปุ่ม COPY | RESCAN | พับ (อยู่เหนือกล่อง log — พับแล้วปุ่มยังอยู่ให้กดกลับ)
local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.28, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 14
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local copyB = hbtn("COPY", 8, 90)
table.insert(CONNS, copyB.MouseButton1Click:Connect(function()
    pcall(setclipboard, table.concat(OUT, "\n"))
    copyB.Text = "คัดลอกแล้ว!"
    task.delay(1.2, function() copyB.Text = "COPY" end)
end))
local rescanB = hbtn("RESCAN", 104, 90, Color3.fromRGB(40, 130, 70))
local foldB = hbtn("พับ", 200, 60, Color3.fromRGB(90, 70, 40))
-- v2.4: ปุ่มปิดจริง (ผู้ใช้: รกจอ) — disconnect ทุกตัวดัก + ลบ GUI ทิ้งทั้งหมด
local closeB = hbtn("✕", 266, 34, Color3.fromRGB(150, 40, 40))
table.insert(CONNS, closeB.MouseButton1Click:Connect(function()
    for _, c in pairs(CONNS) do pcall(function() c:Disconnect() end) end
    _G.BEDMONSPY_CONNS = {}
    gui:Destroy()
end))

local function add(s)
    s = ("[%.1fs]%s %s"):format(os.clock() - T0, GRABBED and "🆘" or "", s)
    OUT[#OUT + 1] = s; LINES[#LINES + 1] = s
    while #LINES > 22 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
    print("[BedMonSpy]", s)
end

local function ser(v)
    if typeof(v) == "Instance" then return "<" .. v.ClassName .. ":" .. v.Name .. ">" end
    if typeof(v) == "Vector3" then return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z) end
    if type(v) == "table" then
        local t = {} for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. tostring(x) end
        return "{" .. table.concat(t, ",") .. "}"
    end
    return tostring(v)
end

-- 1) remote ทุกตัวที่ยิง (ตัด sanity spam) — ช่วงโดนจับจะเห็นว่ากด E 1 ที ยิงอะไรบ้าง
pcall(function()
    local hooked
    hooked = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance"
           and not self.Name:find("PlayerLostSanity") then
            local a = {...}; local s = {}
            for i = 1, #a do s[i] = ser(a[i]) end
            add(("→ ยิง %s(%s)"):format(self.Name, table.concat(s, ", ")))
        end
        return hooked(self, ...)
    end))
end)

-- 2) ปุ่มที่กดจริง (ดู mapping กด → remote/prompt)
local MOVE_KEY = { W = true, A = true, S = true, D = true, Space = true, LeftShift = true,
    One = true, Two = true, Three = true, Four = true, Five = true }   -- v2.3: กรองปุ่มเดิน/slot ตอนยังไม่โดนจับ
table.insert(CONNS, UIS.InputBegan:Connect(function(inp, gpe)
    if inp.UserInputType == Enum.UserInputType.Keyboard then
        if not GRABBED and MOVE_KEY[inp.KeyCode.Name] then return end
        add("⌨️ กด " .. inp.KeyCode.Name .. (gpe and " (GUI ดูด)" or ""))
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
        add("🖱️ คลิก" .. (gpe and " (GUI ดูด)" or ""))
    end
end))

-- v2.3: prompt ประจำเกมที่รู้จักแล้ว (เช็คอิน/ประตู/ของ) — สแปม log ตอนยังไม่โดนจับ
--       ช่วงโดนจับ (🆘) log ทุกตัวเหมือนเดิม เพราะ prompt ดิ้นอาจชื่ออะไรก็ได้
local KNOWN_PROMPT = {
    ["Stamp Forms"] = true, Inspect = true, Take = true, Talk = true, Open = true,
    ["Clean Slime"] = true, ["Apply Treatment"] = true, ["Buy Gun"] = true, Coffee = true,
}
-- 3) ★ใหม่ v2.0: ProximityPrompt โผล่ที่ไหนก็ตาม (ตัวเรา/เตียง/workspace) — รุ่นเก่าไม่ได้ดักเลย
table.insert(CONNS, workspace.DescendantAdded:Connect(function(d)
    if d:IsA("ProximityPrompt") and (GRABBED or not KNOWN_PROMPT[d.ActionText]) then
        local path = d.Parent and d.Parent:GetFullName() or "?"
        add(("➕ prompt ใหม่ '%s' Key=%s Hold=%.1f @ %s"):format(
            d.ActionText, tostring(d.KeyboardKeyCode), d.HoldDuration, path))
        table.insert(CONNS, d:GetPropertyChangedSignal("ActionText"):Connect(function()
            add(("✏️ prompt เปลี่ยน '%s' @ %s"):format(d.ActionText, path))
        end))
    end
end))

-- 4) ★ใหม่ v2.0: ระบบ prompt กลางของ Roblox — เห็นแม้ prompt สร้างก่อนเรารัน spy
table.insert(CONNS, PPS.PromptShown:Connect(function(pp)
    if not GRABBED and KNOWN_PROMPT[pp.ActionText] then return end   -- v2.3: กรองสแปมตอนยังไม่โดนจับ
    add(("👁️ PromptShown '%s' Key=%s Hold=%.1f @ %s"):format(
        pp.ActionText, tostring(pp.KeyboardKeyCode), pp.HoldDuration,
        pp.Parent and pp.Parent:GetFullName() or "?"))
end))
table.insert(CONNS, PPS.PromptTriggered:Connect(function(pp)
    add(("✅ PromptTriggered '%s' @ %s"):format(pp.ActionText,
        pp.Parent and pp.Parent:GetFullName() or "?"))
end))
-- กดค้าง (HoldDuration>0): เริ่มกด/ปล่อยกลางคัน — ดูว่าปุ่มดิ้นเป็นแบบ hold ไหม
table.insert(CONNS, PPS.PromptButtonHoldBegan:Connect(function(pp)
    add(("⏬ HoldBegan '%s' Hold=%.1f"):format(pp.ActionText, pp.HoldDuration))
end))
table.insert(CONNS, PPS.PromptButtonHoldEnded:Connect(function(pp)
    add(("⏫ HoldEnded '%s'"):format(pp.ActionText))
end))

-- 5) GUI โผล่ใน PlayerGui (แถบดิ้น/ข้อความ press)
-- v2.3: กรองป้าย prompt มาตรฐาน Roblox + จอปืน (สแปมท่วม log จนอ่านไม่ได้ — ผู้ใช้เจอ)
local GUI_NOISE = {
    PromptFrame = true, InputFrame = true, Frame = true, ProgressBar = true,
    LeftGradient = true, RightGradient = true, ProgressBarImage = true,
    ButtonFrame = true, ButtonImage = true, ButtonTextImage = true,
    charges = true, black = true,
}
local pg = LP:WaitForChild("PlayerGui")
table.insert(CONNS, pg.DescendantAdded:Connect(function(o)
    if (o:IsA("Frame") or o:IsA("ScreenGui") or o:IsA("ImageLabel")) and not GUI_NOISE[o.Name] then
        add("🖼️ GUI โผล่: " .. o.Name .. " (" .. o.ClassName .. ")")
        task.delay(0.2, function()
            for _, d in ipairs(o:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
                    local t = d.Text:lower()
                    if t:find("press") or t:find("struggle") or t:find("escape") or t:find("mash")
                       or t:find("กด") or t:find("ดิ้น") or t:find("หนี") then
                        add(("📢 [%s] \"%s\""):format(d.Name, d.Text))
                    end
                end
            end
        end)
    end
end))

-- 6) สถานะตัวเรา (จับ/หลุด) + attr
local function watchChar(ch)
    local hum = ch:WaitForChild("Humanoid", 5)
    if hum then
        table.insert(CONNS, hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
            GRABBED = hum.PlatformStand
            add("🧍 PlatformStand = " .. tostring(hum.PlatformStand) .. (GRABBED and " ← โดนจับ! กด E มือ" or " ← หลุดแล้ว"))
        end))
    end
    table.insert(CONNS, ch.AttributeChanged:Connect(function(a)
        add(("🏷️ เรา attr %s = %s"):format(a, tostring(ch:GetAttribute(a))))
    end))
end
if LP.Character then watchChar(LP.Character) end
table.insert(CONNS, LP.CharacterAdded:Connect(watchChar))

-- 7) MonsterBed: เจอ/โผล่ใหม่ + attr เปลี่ยน (เตียงอาจนับจำนวนดิ้นเป็น attr)
local function watchBed(b)
    add("🛏️ MonsterBed: " .. b:GetFullName() .. " attr:" .. ser(b:GetAttributes()))
    table.insert(CONNS, b.AttributeChanged:Connect(function(a)
        add(("🛏️ เตียง attr %s = %s"):format(a, tostring(b:GetAttribute(a))))
    end))
end
for _, m in ipairs(workspace:GetDescendants()) do
    if m.Name == "MonsterBed" then watchBed(m) end
end
table.insert(CONNS, workspace.DescendantAdded:Connect(function(o)
    if o.Name == "MonsterBed" then task.defer(watchBed, o) end
end))

-- ===== v2.5: ดักจุดยืนส่งน้ำเชื่อม (ผู้ใช้: ต้องยืนถูกจุดถึงส่งได้ — หาว่าจุดไหน) =====
local function heldSyrup()
    local bp = LP:FindFirstChild("Backpack")
    if LP.Character and LP.Character:FindFirstChild("Maple Syrup") then return true, true end   -- ถือในมือ
    if bp and bp:FindFirstChild("Maple Syrup") then return true, false end                       -- ในกระเป๋า
    return false, false
end
local function bedRef(b) return b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart") end
local function nearestBed(pos)
    local best, bd, bpart
    for _, m in ipairs(workspace:GetDescendants()) do
        if m.Name == "MonsterBed" and m:IsA("Model") then
            local p = bedRef(m)
            if p then
                local d = (p.Position - pos).Magnitude
                if not best or d < bd then best, bd, bpart = m, d, p end
            end
        end
    end
    return best, bd, bpart
end
task.spawn(function()
    local hadSyrup, lastLog = false, 0
    while gui.Parent do
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if r then
            local has, equipped = heldSyrup()
            local bed, d, bpart = nearestBed(r.Position)
            if has and bed and d and d < 40 then
                if os.clock() - lastLog > 0.7 then
                    lastLog = os.clock()
                    -- แกนเตียง = พิกัดเราใน object space ของเตียง (บอกฝั่ง/หัวท้ายชัดกว่าพิกัดโลก)
                    local rel = bpart.CFrame:PointToObjectSpace(r.Position)
                    add(("🍁 syrup%s ห่างเตียง %.1f | โลก(%.1f,%.1f,%.1f) | แกนเตียง(%.1f,%.1f,%.1f)"):format(
                        equipped and "(ถือ)" or "(กระเป๋า)", d,
                        r.Position.X, r.Position.Y, r.Position.Z, rel.X, rel.Y, rel.Z))
                end
                hadSyrup = true
            elseif hadSyrup and not has then
                -- น้ำเชื่อมเพิ่งหายจากมือ = ส่งสำเร็จ → จับพิกัดวินาทีนั้นเป๊ะๆ
                hadSyrup = false
                if bed and d then
                    local rel = bpart.CFrame:PointToObjectSpace(r.Position)
                    add(("✅🍁 น้ำเชื่อมหาย! ห่างเตียง %.1f | โลก(%.1f,%.1f,%.1f) | แกนเตียง(%.1f,%.1f,%.1f) ← จุดยืนที่ใช้ได้"):format(
                        d, r.Position.X, r.Position.Y, r.Position.Z, rel.X, rel.Y, rel.Z))
                else
                    add("✅🍁 น้ำเชื่อมหายจากมือ (ไม่มีเตียงใกล้ — โดนทิ้ง/ใช้ที่อื่น)")
                end
            elseif not has then
                hadSyrup = false
            end
        end
        task.wait(0.15)
    end
end)

-- v2.2: พับ = ซ่อนทั้งหมด (กล่อง+ปุ่ม COPY/RESCAN) เหลือปุ่มจิ๋วปุ่มเดียว (ผู้ใช้: รกจอ ระหว่างตามหาผีเตียง)
--       โดนจับเมื่อไหร่ = กางเองอัตโนมัติ (จะได้ไม่พลาดช่วงสำคัญ)
local function setFold(hide)
    box.Visible = not hide
    copyB.Visible = not hide
    rescanB.Visible = not hide
    foldB.Size = hide and UDim2.new(0, 60, 0, 24) or UDim2.new(0, 60, 0, 30)
    foldB.BackgroundTransparency = hide and 0.4 or 0
    foldB.Text = hide and "สปาย" or "พับ"
end
table.insert(CONNS, foldB.MouseButton1Click:Connect(function()
    setFold(box.Visible)
end))
-- โดนจับ → กางอัตโนมัติ (จับจาก GRABBED ใน watchChar ไม่ได้ตรงๆ — poll เบาๆ แทน)
task.spawn(function()
    local wasGrabbed = false
    while gui.Parent do
        if GRABBED and not wasGrabbed and not box.Visible then setFold(false) end
        wasGrabbed = GRABBED
        task.wait(0.2)
    end
end)
table.insert(CONNS, rescanB.MouseButton1Click:Connect(function()
    LINES = {}   -- ล้างจอ (OUT เก็บประวัติเต็มไว้ให้ COPY เหมือนเดิม)
    add("===== RESCAN =====")
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    add("🧍 PlatformStand=" .. tostring(h and h.PlatformStand) .. " GRABBED=" .. tostring(GRABBED))
    local n = 0
    for _, m in ipairs(workspace:GetDescendants()) do
        if m.Name == "MonsterBed" then
            n += 1
            add("🛏️ " .. m:GetFullName() .. " attr:" .. ser(m:GetAttributes()))
        end
    end
    if n == 0 then add("🛏️ ไม่พบ MonsterBed ตอนนี้") end
    -- prompt ที่เปิดอยู่รอบตัว 40 studs (ดูว่ามีปุ่มดิ้น/ปุ่มแปลกใกล้เราไหม)
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if r then
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.Enabled and p.Parent then
                local pp = p.Parent:FindFirstChildWhichIsA("BasePart", true) or (p.Parent:IsA("BasePart") and p.Parent)
                local pos = pp and pp.Position
                if pos and (pos - r.Position).Magnitude < 40 then
                    add(("🔘 '%s' Hold=%.1f @ %s"):format(p.ActionText, p.HoldDuration, p.Parent:GetFullName()))
                end
            end
        end
    end
end))

add("v2.5 เริ่มดัก — ถือน้ำเชื่อมใกล้เตียง = log จุดยืนทุก 0.7s, ส่งติด = ✅🍁 พิกัดเป๊ะ | โดนจับจอกางเอง")
