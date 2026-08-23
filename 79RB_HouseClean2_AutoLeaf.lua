-- 79RB_HouseClean2_AutoLeaf.lua v1.0 — ฟาร์มใบไม้อัตโนมัติ (ล้างบ้านขำๆ ภาค 2 "นอกบ้าน")
-- จาก NetSpy: เก็บใบ = CollectLeaf:FireServer(<id ตัวเลข>) / เทกระเป๋า = EmptyBackpack:FireServer()
-- ไม่รู้ว่า id อยู่ไหนใน WS.Leaves.Leaf → ปุ่ม DUMP โชว์โครงสร้าง+Attributes ของใบ 3 ใบแรก
-- ปุ่ม AUTO: หา id จากใบทุกใบ (ลอง Attribute ทุกตัวที่เป็นเลข, IntValue/NumberValue ลูก, ชื่อที่เป็นเลข)
--   → ยิง CollectLeaf ทีละใบ ทุก LEAF_DELAY วิ → ยิง EmptyBackpack ทุก EMPTY_EVERY ใบ
if _G.LF79_GUI then pcall(function() _G.LF79_GUI:Destroy() end) end
_G.LF79_GEN = (_G.LF79_GEN or 0) + 1
local GEN = _G.LF79_GEN

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local LEAF_DELAY = 0.03  -- หน่วงระหว่างชุด (วิ)
local BURST = 50         -- ยิงกี่ id ต่อชุด (50×0.03 → กวาดครบ ~13k id ใน ~8 วิ/จุด)
local NEAREST_MODE = false -- v1.7: ปิด — ทดสอบจริงโดนแค่ 6/56 (id ไม่ใช่ลำดับโฟลเดอร์) ใช้กวาดเต็มแบบ v1.4
local NEAR_SPREAD = 3     -- ยิงเผื่อ index ข้างเคียง ±กี่ตัว
local WORKERS = 10        -- v1.8: แบ่งยิงขนานกี่สาย (แต่ละสายรับช่วง id ตัวเอง)
local EMPTY_EVERY = 20   -- เทกระเป๋าทุกๆ กี่ใบ
local AUTO_ON = false

-- ==================== หา remote ====================
local function findRemote(name)
    for _, svc in ipairs({ RS, workspace }) do
        local r = svc:FindFirstChild(name, true)
        if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    end
    return nil
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoLeaf79"; gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647; gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.LF79_GUI = gui

local fr = Instance.new("Frame", gui)
fr.Size = UDim2.new(0, 300, 0, 330); fr.Position = UDim2.new(0, 8, 0.35, 0)
fr.BackgroundColor3 = Color3.new(0, 0, 0); fr.BackgroundTransparency = 0.1
fr.Active = true; fr.Draggable = true
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", fr); stk.Color = Color3.fromRGB(120, 220, 100); stk.Thickness = 2

local status = Instance.new("TextLabel", fr)
status.Size = UDim2.new(1, -8, 0, 36); status.Position = UDim2.new(0, 4, 0, 4)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(180, 255, 180)
status.TextSize = 12; status.Font = Enum.Font.GothamBold; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.Text = "🍂 AutoLeaf พร้อม"

local scf = Instance.new("ScrollingFrame", fr)
scf.Size = UDim2.new(1, -8, 1, -116); scf.Position = UDim2.new(0, 4, 0, 74)
scf.BackgroundColor3 = Color3.fromRGB(12, 18, 12); scf.BorderSizePixel = 0; scf.ScrollBarThickness = 6
scf.CanvasSize = UDim2.new(0, 0, 0, 0); scf.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scf).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel", scf)
lbl.Size = UDim2.new(1, -8, 0, 0); lbl.Position = UDim2.new(0, 4, 0, 4)
lbl.AutomaticSize = Enum.AutomaticSize.Y; lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Code; lbl.TextSize = 11; lbl.TextColor3 = Color3.fromRGB(190, 255, 190)
lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.TextWrapped = true; lbl.Text = ""
local out = {}
local function say(s)
    out[#out + 1] = tostring(s)
    if #out > 300 then table.remove(out, 1) end
    lbl.Text = table.concat(out, "\n")
end

local function mkbtn(txt, x, y, w, col)
    local b = Instance.new("TextButton", fr)
    b.Size = UDim2.new(0, w, 0, 26); b.Position = UDim2.new(0, x, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local autoB  = mkbtn("▶ AUTO", 4, 42, 76, Color3.fromRGB(40, 130, 60))
local dumpB  = mkbtn("DUMP", 84, 42, 60, Color3.fromRGB(60, 90, 150))
local emptyB = mkbtn("เทถุง", 148, 42, 56, Color3.fromRGB(150, 110, 40))
local copyB  = mkbtn("📋", 208, 42, 40, Color3.fromRGB(60, 60, 60))
local closeB = mkbtn("✕", 252, 42, 40, Color3.fromRGB(140, 45, 45))

-- แถวล่าง: ปรับหน่วง
local dlyB = mkbtn(("หน่วง %.2f"):format(LEAF_DELAY), 4, 296, 96, Color3.fromRGB(70, 70, 110))
dlyB.MouseButton1Click:Connect(function()
    local steps = { 0.03, 0.05, 0.10, 0.20 }
    for i, v in ipairs(steps) do
        if math.abs(v - LEAF_DELAY) < 0.001 then LEAF_DELAY = steps[i % #steps + 1]; break end
    end
    dlyB.Text = ("หน่วง %.2f"):format(LEAF_DELAY)
end)
local burstB = mkbtn(("ชุด %d"):format(BURST), 104, 296, 70, Color3.fromRGB(70, 110, 70))
burstB.MouseButton1Click:Connect(function()
    local steps = { 25, 50, 100, 200 }
    for i, v in ipairs(steps) do
        if v == BURST then BURST = steps[i % #steps + 1]; break end
    end
    burstB.Text = ("ชุด %d"):format(BURST)
end)

copyB.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.LF79_GEN = _G.LF79_GEN + 1; gui:Destroy(); _G.LF79_GUI = nil
end)

-- ==================== หา id ของใบ ====================
-- คืน id ตัวเลข + แหล่งที่เจอ (ไว้ debug)
local function leafId(inst)
    -- 1) Attribute ที่เป็นตัวเลข
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do
            if type(v) == "number" then return v, "attr:" .. k end
        end
    end
    -- 2) ลูกที่เป็น IntValue/NumberValue/StringValue ตัวเลข
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA("IntValue") or c:IsA("NumberValue") then return c.Value, "child:" .. c.Name end
        if c:IsA("StringValue") and tonumber(c.Value) then return tonumber(c.Value), "childS:" .. c.Name end
    end
    -- 3) ชื่อตัวเองเป็นเลข
    if tonumber(inst.Name) then return tonumber(inst.Name), "name" end
    return nil, nil
end

local function allLeaves()
    local res = {}
    local folder = workspace:FindFirstChild("Leaves")
    if folder then
        for _, m in ipairs(folder:GetChildren()) do res[#res + 1] = m end
    end
    return res
end

-- ==================== DUMP ====================
dumpB.MouseButton1Click:Connect(function()
    out = {}; say("===== DUMP ใบไม้ 3 ใบแรก =====")
    local ls = allLeaves()
    say(("WS.Leaves มี %d ชิ้น"):format(#ls))
    for i = 1, math.min(3, #ls) do
        local m = ls[i]
        say(("--- [%d] %s [%s] ---"):format(i, m.Name, m.ClassName))
        local ok, attrs = pcall(function() return m:GetAttributes() end)
        if ok and attrs then
            local n = 0
            for k, v in pairs(attrs) do say(("  attr %s = %s (%s)"):format(k, tostring(v), typeof(v))); n = n + 1 end
            if n == 0 then say("  (ไม่มี attribute)") end
        end
        for _, c in ipairs(m:GetChildren()) do
            local extra = ""
            if c:IsA("ValueBase") then extra = " = " .. tostring(c.Value) end
            say(("  child %s [%s]%s"):format(c.Name, c.ClassName, extra))
            -- attributes ของลูกด้วย
            local ok2, a2 = pcall(function() return c:GetAttributes() end)
            if ok2 and a2 then
                for k, v in pairs(a2) do say(("    attr %s = %s"):format(k, tostring(v))) end
            end
        end
        local id, src = leafId(m)
        say(("  → id ที่เดาได้: %s (จาก %s)"):format(tostring(id), tostring(src)))
    end
    local ce = findRemote("CollectLeaf"); local ee = findRemote("EmptyBackpack")
    say(""); say("CollectLeaf: " .. (ce and ce:GetFullName() or "❌ ไม่เจอ"))
    say("EmptyBackpack: " .. (ee and ee:GetFullName() or "❌ ไม่เจอ"))
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
    say("(📋 ก๊อปแล้ว)")
end)

-- ==================== วาป (ตำแหน่งอย่างเดียว ไม่หมุนกล้อง) ====================
local function myRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function tpTo(pos)
    local root = myRoot(); if not root then return false end
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = (root.CFrame - root.CFrame.Position) + pos
    return true
end
-- หาถังขายใบไม้ (Dumpsters)
local function dumpsterPos()
    local d = workspace:FindFirstChild("Map")
    d = d and d:FindFirstChild("Dumpsters")
    if not d then return nil end
    local p = d:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

-- ==================== เทถุง (v1.7: เกมบังคับต้องอยู่ใกล้ถัง → วาปไปเทแล้ววาปกลับ) ====================
local function doEmpty()
    local ee = findRemote("EmptyBackpack")
    if not (ee and ee:IsA("RemoteEvent")) then return false end
    local dp = dumpsterPos()
    local root = myRoot()
    if dp and root then
        local back = root.Position
        tpTo(dp + Vector3.new(0, 3, 0))
        task.wait(0.25) -- รอตำแหน่งซิงก์ขึ้นเซิร์ฟเวอร์
        ee:FireServer()
        task.wait(0.15)
        tpTo(back)
    else
        ee:FireServer()
    end
    return true
end
emptyB.MouseButton1Click:Connect(function()
    say(doEmpty() and "🗑️ เทกระเป๋าแล้ว" or "❌ ไม่เจอ EmptyBackpack")
end)

-- ==================== AUTO ====================
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    autoB.Text = AUTO_ON and "⏸ หยุด" or "▶ AUTO"
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(150, 60, 40) or Color3.fromRGB(40, 130, 60)
end)

-- v1.1: ใบไม่มี attribute/id ในตัว → id คือ "ลำดับใบ" ฝั่งเซิร์ฟเวอร์ (เลขที่ดักได้ 75..4546
--   อยู่ในช่วง 1..จำนวนใบพอดี) → ยิงไล่เลข 1..จำนวนใบ ตรงๆ แล้วดูจำนวนใบใน WS.Leaves ลดจริงเป็นตัวยืนยัน
task.spawn(function()
    local nextId = 1
    local sinceEmpty = 0
    local startCount = nil
    local leafIdx = 0 -- v1.3: ตัวชี้ใบที่จะวาปไป
    local hitCnt, tryCnt = 0, 0 -- v1.5: สถิติโหมดใกล้สุด
    while _G.LF79_GEN == GEN do
        if AUTO_ON then
            local ce = findRemote("CollectLeaf")
            if not ce then
                status.Text = "❌ ไม่เจอ remote CollectLeaf (กด DUMP ดู)"
                task.wait(1)
            else
                local ls = allLeaves()
                startCount = startCount or #ls
                local maxId = math.max(startCount, #ls)
                if #ls == 0 then
                    status.Text = "🍂 ใบหมดแมพแล้ว! — รอเกิดใหม่..."
                    startCount = nil
                    task.wait(2)
                elseif NEAREST_MODE then
                    -- v1.5: เก็บใบใกล้ตัวสุดทีละใบ — วาปไปใบใกล้สุด แล้วยิง "ลำดับใบในโฟลเดอร์"
                    --   (เดาว่า id = index) + ยิงเผื่อ index ข้างเคียง ±NEAR_SPREAD กันลำดับเคลื่อน
                    local root = myRoot()
                    if root then
                        local best, bi, bd = nil, nil, math.huge
                        for i, m in ipairs(ls) do
                            if m:IsA("BasePart") then
                                local d = (m.Position - root.Position).Magnitude
                                if d < bd then bd = d; best = m; bi = i end
                            end
                        end
                        if best then
                            tpTo(best.Position + Vector3.new(0, 2, 0))
                            task.wait(0.12)
                            -- ยิง index ตัวเอง + เผื่อรอบข้าง
                            for id = math.max(1, bi - NEAR_SPREAD), bi + NEAR_SPREAD do
                                pcall(function() ce:FireServer(id) end)
                            end
                            task.wait(0.12)
                            local gone = best.Parent == nil
                            hitCnt = hitCnt + (gone and 1 or 0)
                            tryCnt = tryCnt + 1
                            sinceEmpty = sinceEmpty + 1
                            if sinceEmpty >= EMPTY_EVERY then doEmpty(); sinceEmpty = 0 end
                            status.Text = ("🎯 ใกล้สุด: โดน %d/%d ครั้ง | ใบเหลือ %d")
                                :format(hitCnt, tryCnt, #allLeaves())
                            if tryCnt >= 15 and hitCnt == 0 then
                                status.Text = "❌ id ไม่ใช่ลำดับโฟลเดอร์ — ปิดโหมดใกล้สุด กลับไปกวาดเต็ม"
                                NEAREST_MODE = false
                                task.wait(1.5)
                            end
                        end
                    end
                else
                    -- v1.4: "ยืนทีละจุด ยิงครบทุก id ค่อยย้าย" — id ไม่ตรงกับใบที่วาปไป
                    --   (v1.3 ยิงข้าม: ยืนใบ A แต่ id ที่ยิงเป็นของใบไกลๆ) → ทุกจุดยิงครบ 1..maxId
                    local before = #ls
                    local lm = ls[1]
                    -- เลือกจุด: ใบที่ใกล้ตัวที่สุด (ลดระยะวาปกระโดดมั่ว)
                    local root = myRoot()
                    if root then
                        local best, bd = nil, math.huge
                        for i = 1, math.min(#ls, 400) do -- เช็คแค่ 400 ตัวแรกพอ (เร็ว)
                            local p = ls[i]:IsA("BasePart") and ls[i].Position or nil
                            if p then
                                local d = (p - root.Position).Magnitude
                                if d > 4 and d < bd then bd = d; best = ls[i] end
                            end
                        end
                        lm = best or lm
                    end
                    local lp2 = lm and (lm:IsA("BasePart") and lm.Position
                        or (lm:IsA("Model") and lm:GetPivot().Position))
                    if lp2 then
                        tpTo(lp2 + Vector3.new(0, 2, 0))
                        task.wait(0.15) -- รอตำแหน่งซิงก์ขึ้นเซิร์ฟเวอร์
                    end
                    -- v1.9: ยิงเรียงทีละ id แบบ v1.4 (เวอร์ชันที่เก็บได้จริง) — ขนานแล้วเซิร์ฟเวอร์ไม่รับ
                    for id = 1, maxId do
                        if not AUTO_ON or _G.LF79_GEN ~= GEN then break end
                        pcall(function() ce:FireServer(id) end)
                        if id % BURST == 0 then
                            if id % (BURST * 10) == 0 then
                                status.Text = ("🍂 จุดนี้ยิง %d/%d | ใบเหลือ %d (เริ่ม %d)")
                                    :format(id, maxId, #allLeaves(), startCount)
                            end
                            task.wait(LEAF_DELAY)
                        end
                    end
                    doEmpty() -- ขายทุกครั้งก่อนย้ายจุด (กันถุงเต็ม)
                    local after = #allLeaves()
                    status.Text = ("✅ จุดนี้เก็บได้ %d ใบ | เหลือ %d — ย้ายจุดถัดไป")
                        :format(math.max(0, before - after), after)
                    task.wait(0.2)
                end
            end
        else
            status.Text = "🍂 AutoLeaf พร้อม (กด AUTO เริ่มฟาร์ม / DUMP ดูโครงสร้างใบ)"
            task.wait(0.3)
        end
    end
end)

warn("[AutoLeaf79] v1.9 loaded — กลับสูตร v1.4 ที่เก็บได้จริง: ยืนทีละจุด ยิงเรียงครบทุก id + วาปขายที่ถัง")
