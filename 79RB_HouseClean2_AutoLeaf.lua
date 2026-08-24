-- 79RB_HouseClean2_AutoLeaf.lua v3.4 — ฟาร์มใบไม้อัตโนมัติ (ล้างบ้านขำๆ ภาค 2 "นอกบ้าน")
-- จาก 79RB_LeafIdSpy: id ที่ CollectLeaf:FireServer(id) ใช้ = ลำดับใบใน WS.Leaves:GetChildren()
--   "ตอนสแนปนั้นๆ" เป๊ะๆ (448|448, 1987|1987 ตรงกันทุกแถว) — สแนปใหม่ ลำดับเปลี่ยน id ก็เปลี่ยนความหมาย
--   v3.4: doneIds (จำ id ที่เก็บแล้ว) ต้องล้างทุกครั้งที่สแนปใหม่ ไม่งั้นเข้าใจผิดว่าใบใหม่เก็บแล้ว
--   (ต้นเหตุ "หาใบไม่เจอ" ที่ต้องเดินไปกด SNAP เอง) + ค้นหาไม่มีวันตัน (วนสแนปหาทั่วแมพอัตโนมัติ)
--   + วาปขายเฉพาะตอนถุงใกล้เต็ม (ลดความถี่วาป กันบัค) + ยืนยันวาปกลับตำแหน่งเดิมสำเร็จก่อนไปต่อ
if _G.LF79_GUI then pcall(function() _G.LF79_GUI:Destroy() end) end
_G.LF79_GEN = (_G.LF79_GEN or 0) + 1
local GEN = _G.LF79_GEN

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local LEAF_DELAY = 0.03  -- หน่วงหลังยิงแต่ละใบ (วิ)
local EMPTY_EVERY = 70    -- v3.7: สำรองเผื่อเช็ค Gui.Bag.Amount พลาด (ถุงจริงจุ 75 จาก BAGDUMP)
local EMPTY_SEC = 90      -- v3.8: ตัวสำรองฉุกเฉินเท่านั้น (เผื่อลูปหลักพลาดจับถุงเต็ม) ไม่ใช่ตัวขายหลัก
local STAY_RADIUS = 12    -- v3.1: อยู่นิ่งยิงใบในรัศมีนี้ก่อน ค่อยวาปย้าย (กันโดดเป็นกบ)
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
status.TextXAlignment = Enum.TextXAlignment.Left; status.Text = "🍂 AutoLeaf v3.0 พร้อม"

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
local autoB  = mkbtn("▶ AUTO", 4, 42, 62, Color3.fromRGB(40, 130, 60))
local snapB  = mkbtn("SNAP", 70, 42, 48, Color3.fromRGB(60, 90, 150))
local emptyB = mkbtn("เทถุง", 122, 42, 48, Color3.fromRGB(150, 110, 40))
local bagB   = mkbtn("BAG", 174, 42, 42, Color3.fromRGB(120, 80, 150))
local copyB  = mkbtn("📋", 220, 42, 36, Color3.fromRGB(60, 60, 60))
local closeB = mkbtn("✕", 260, 42, 32, Color3.fromRGB(140, 45, 45))

local dlyB = mkbtn(("หน่วง %.2f"):format(LEAF_DELAY), 4, 296, 96, Color3.fromRGB(70, 70, 110))
dlyB.MouseButton1Click:Connect(function()
    local steps = { 0.01, 0.03, 0.05, 0.10 }
    for i, v in ipairs(steps) do
        if math.abs(v - LEAF_DELAY) < 0.001 then LEAF_DELAY = steps[i % #steps + 1]; break end
    end
    dlyB.Text = ("หน่วง %.2f"):format(LEAF_DELAY)
end)

copyB.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.LF79_GEN = _G.LF79_GEN + 1; gui:Destroy(); _G.LF79_GUI = nil
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
local function dumpsterPos()
    local d = workspace:FindFirstChild("Map")
    d = d and d:FindFirstChild("Dumpsters")
    if not d then return nil end
    local p = d:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end
-- v3.6: Dumpster เป็นหลุมมีกำแพงกั้น — วาปลงกลาง +3 ตกค้างในหลุมออกไม่ได้ (บั๊กที่เจอ)
--   แก้: ยืนที่ "ขอบนอก" หลุม เยื้องออกจากจุดเดิมของผู้เล่น (back) + ยกสูงกว่าเดิมมาก กันตกกำแพง
local function dumpsterStandPos(back)
    local dp = dumpsterPos()
    if not dp then return nil end
    local dir = (back - dp)
    if dir.Magnitude < 1 then dir = Vector3.new(0, 0, 1) end
    dir = Vector3.new(dir.X, 0, dir.Z).Unit
    return dp + dir * 8 + Vector3.new(0, 10, 0)
end

-- ==================== เทถุง (v3.4: วาปไปถังอีกครั้ง — เกมเช็คระยะจริง ยิงเปล่าไม่เข้า
--   แต่ลดความถี่ให้วาปเฉพาะตอนถุงใกล้เต็ม (ดู EMPTY_EVERY) + ยืนยันวาปกลับสำเร็จจริงก่อนไปต่อ) ====================
local function doEmpty()
    local ee = findRemote("EmptyBackpack")
    if not (ee and ee:IsA("RemoteEvent")) then return false end
    local root = myRoot()
    local back = root and root.Position
    local standPos = back and dumpsterStandPos(back)
    if standPos and root then
        tpTo(standPos)
        task.wait(0.45)
        ee:FireServer()
        pcall(function()
            local d = workspace:FindFirstChild("Map")
            d = d and d:FindFirstChild("Dumpsters")
            if d and fireproximityprompt then
                for _, pr in ipairs(d:GetDescendants()) do
                    if pr:IsA("ProximityPrompt") then fireproximityprompt(pr) end
                end
            end
        end)
        task.wait(0.3)
        -- v3.4: ยืนยันว่าวาปกลับสำเร็จจริง (กันบัคค้างที่ถัง) — retry ไม่เกิน 5 ครั้ง
        for _ = 1, 5 do
            tpTo(back)
            task.wait(0.1)
            local r2 = myRoot()
            if r2 and (r2.Position - back).Magnitude < 3 then break end
        end
    else
        ee:FireServer()
    end
    return true
end
emptyB.MouseButton1Click:Connect(function() say(doEmpty() and "🗑️ เทกระเป๋าแล้ว" or "❌ ไม่เจอ EmptyBackpack") end)

-- ==================== v3.7: จาก BAGDUMP เจอ path ตรงแล้ว: Gui.Bag.Amount / Gui.Bag.Capacity ====================
local function findBagLabel()
    local pg = LP:FindFirstChild("PlayerGui"); if not pg then return nil end
    local g = pg:FindFirstChild("Gui"); local bag = g and g:FindFirstChild("Bag")
    local amt = bag and bag:FindFirstChild("Amount")
    return amt
end
local function bagCapacity()
    local pg = LP:FindFirstChild("PlayerGui"); if not pg then return nil end
    local g = pg:FindFirstChild("Gui"); local bag = g and g:FindFirstChild("Bag")
    local cap = bag and bag:FindFirstChild("Capacity")
    return cap and tonumber(cap.Text)
end
bagB.MouseButton1Click:Connect(function()
    out = {}; say("===== BAGDUMP: หา label นับใบในถุง =====")
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and tonumber(d.Text) then
                say(("%s = \"%s\""):format(d:GetFullName():gsub("^.-PlayerGui%.", ""), d.Text))
            end
        end
    end
    local lb = findBagLabel()
    say(""); say("เดาได้: " .. (lb and lb:GetFullName() or "❌ ไม่เจอ (ดูลิสต์ด้านบน บอกอันไหนใช่)"))
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
    say("(📋 ก๊อปแล้ว)")
end)

-- ==================== v3.0: สแนป id ครั้งเดียว (ยืนยันจาก LeafIdSpy: id = ลำดับสแนป) ====================
-- snapshot[leafInstance] = id ตายตัว | ไม่ re-fetch GetChildren() อีกหลังจากนี้ (กันลำดับเลื่อน)
local snapshot = {}   -- inst -> id
local snapOrder = {}  -- id -> inst (สำหรับไล่หา / debug)
local snapDone = false
-- v3.4: doneIds มีอายุแค่ 1 สแนป ไม่ persist ข้ามรอบรันแล้ว (ดู doSnapshot ด้านล่าง)
local doneIds = {}

local function doSnapshot()
    snapshot = {}; snapOrder = {}
    -- v3.4: ล้าง doneIds ทุกครั้งที่สแนปใหม่ — id มีความหมายแค่ "ในสแนปนั้นๆ" (ลำดับ ณ ขณะสแนป)
    --   ถ้าไม่ล้าง ใบใหม่ที่ยังไม่เคยเก็บอาจได้เลขซ้ำ id เก่าที่เคยเก็บไปแล้ว → เข้าใจผิดว่าเก็บแล้ว
    --   ทำให้หาใบไม่เจอทั้งที่มีอยู่จริง (ต้นเหตุที่ต้องเดินไปกด SNAP ใหม่เอง)
    for k in pairs(doneIds) do doneIds[k] = nil end
    local folder = workspace:FindFirstChild("Leaves")
    if not folder then say("❌ ไม่เจอ WS.Leaves"); return 0 end
    local kids = folder:GetChildren()
    for i, m in ipairs(kids) do
        snapshot[m] = i
        snapOrder[i] = m
    end
    snapDone = true
    say(("📸 สแนปแล้ว: %d ใบ (id = ลำดับตอนนี้)"):format(#kids))
    return #kids
end

-- v3.4: เอาไฟล์จำ id ข้ามรอบรันออก — id มีความหมายแค่ในสแนปนั้นๆ (ลำดับ ณ ขณะสแนป)
--   ข้ามรอบรัน ลำดับใบเปลี่ยนไปแล้วแน่นอน โหลด id เก่ามาใช้จะยิ่งทำให้พลาด ไม่ใช่ช่วย
snapB.MouseButton1Click:Connect(function() doSnapshot() end)

-- v3.3: ดักจริงว่าใบหายเมื่อไหร่ (ChildRemoved) แทนเช็คทันทีหลังยิง (เร็วเกินไป เซิร์ฟเวอร์ยังไม่ตอบ
--   ทำให้นับ "ไม่โดน" ทั้งที่จริงสำเร็จ → วนยิง id เดิมซ้ำไม่เลิก, สแนปใหม่ถี่ทั้งที่ยังไม่ครบจริง)
local recentFires = {} -- คิว {id, t} ที่เพิ่งยิง ยังไม่ยืนยันผล
local pendingHit = 0
local function noteFire(id)
    recentFires[#recentFires + 1] = { id = id, t = os.clock() }
    if #recentFires > 60 then table.remove(recentFires, 1) end
end
do
    local lf = workspace:FindFirstChild("Leaves")
    if lf then
        lf.ChildRemoved:Connect(function()
            local now = os.clock()
            for i, e in ipairs(recentFires) do
                if now - e.t <= 1.0 then
                    doneIds[e.id] = true
                    pendingHit = pendingHit + 1
                    table.remove(recentFires, i)
                    return
                end
            end
        end)
    end
end

local ce = findRemote("CollectLeaf")
say("CollectLeaf: " .. (ce and ce:GetFullName() or "❌ ไม่เจอ"))
say("กด SNAP ก่อนเริ่ม (หรือ AUTO จะสแนปให้อัตโนมัติครั้งแรก)")

-- ==================== AUTO ====================
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    autoB.Text = AUTO_ON and "⏸ หยุด" or "▶ AUTO"
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(150, 60, 40) or Color3.fromRGB(40, 130, 60)
end)

task.spawn(function()
    local sinceEmpty = 0
    local hit, tryC = 0, 0
    local lastHit, lastBagCount = 0, nil -- v3.5: จับได้จริงว่าถุงเต็ม (ตัวเลขไม่ขยับทั้งที่เก็บเพิ่ม)
    while _G.LF79_GEN == GEN do
        if AUTO_ON then
            local ceR = findRemote("CollectLeaf")
            if not ceR then
                status.Text = "❌ ไม่เจอ remote CollectLeaf"
                task.wait(1)
            else
                if not snapDone then doSnapshot() end
                local root = myRoot()
                if not root then
                    task.wait(0.5)
                else
                    -- หาใบใกล้ตัวสุดที่ "ยังไม่เก็บ" จากสแนป (ไม่ re-fetch GetChildren)
                    local myP = root.Position
                    local best, bestId, bd = nil, nil, math.huge
                    for id, m in pairs(snapOrder) do
                        if not doneIds[id] and m.Parent then
                            local ok, p = pcall(function() return m.Position end)
                            if ok then
                                local d = (p - myP).Magnitude
                                if d < bd then bd = d; best = m; bestId = id end
                            end
                        end
                    end
                    if not best then
                        -- v3.4: ค้นหาไม่มีวันตัน — ไม่ต้องเดินไปกด SNAP เองอีกแล้ว วนสแนป+หาใหม่ทุก 2-3 วิเอง
                        if #recentFires > 0 then
                            status.Text = "⏳ รอผลยิงที่ค้างอยู่..."
                            task.wait(0.6)
                        else
                            status.Text = ("✅ ครบสแนปนี้แล้ว (โดน %d/%d) — หาใบรอบใหม่ทั่วแมพ..."):format(hit, tryC)
                            task.wait(2 + math.random() * 1) -- 2-3 วิ แล้ววนสแนปหาอีกครั้งอัตโนมัติ
                            doSnapshot()
                            hit, tryC = 0, 0
                        end
                    else
                        -- v3.1: วาปไปใบใกล้สุด "ครั้งเดียว" แล้วอยู่นิ่งยิงทุกใบในรัศมี STAY_RADIUS
                        --   ก่อน ไม่วาปย้ายทุกใบ (กันโดดเป็นกบ) — ค่อยหาจุดใหม่เมื่อรอบตัวหมดจริง
                        tpTo(best.Position + Vector3.new(0, 2, 0))
                        task.wait(0.10)
                        local stayPos = best.Position
                        while AUTO_ON and _G.LF79_GEN == GEN do
                            -- หาใบที่ใกล้ "จุดยืน" สุดในบรรดาที่ยังไม่เก็บ + อยู่ในรัศมี
                            local nb, nid, nd = nil, nil, math.huge
                            for id, m in pairs(snapOrder) do
                                if not doneIds[id] and m.Parent then
                                    local ok, p = pcall(function() return m.Position end)
                                    if ok then
                                        local d = (p - stayPos).Magnitude
                                        if d < nd then nd = d; nb = m; nid = id end
                                    end
                                end
                            end
                            if not nb or nd > STAY_RADIUS then break end
                            pcall(function() ceR:FireServer(nid) end)
                            noteFire(nid)
                            tryC = tryC + 1
                            task.wait(LEAF_DELAY)
                            hit = hit + pendingHit; pendingHit = 0
                            sinceEmpty = sinceEmpty + 1
                            -- v3.7: เช็คถุงเต็มจริงจาก Gui.Bag.Amount / Capacity (เจอ path จริงจาก BAGDUMP แล้ว)
                            local bagFull = false
                            if hit > lastHit then
                                local lb = findBagLabel()
                                local cur = lb and tonumber(lb.Text)
                                local cap = bagCapacity()
                                if cur then lastBagCount = cur end
                                if cur and cap and cur >= cap - 2 then bagFull = true end
                                lastHit = hit
                            end
                            if bagFull or sinceEmpty >= EMPTY_EVERY then
                                doEmpty(); sinceEmpty = 0; lastBagCount = nil
                            end
                            status.Text = ("🎯 จุดนี้ โดน %d/%d | ระยะ %.1f | id %d | ถุง %s")
                                :format(hit, tryC, nd, nid, tostring(lastBagCount))
                        end
                    end
                end
            end
        else
            status.Text = "🍂 AutoLeaf v3.4 พร้อม (AUTO เริ่ม / SNAP รีเซ็ตสแนป)"
            task.wait(0.3)
        end
    end
end)

-- v3.8: ตัวสำรองเดิมขายทุก EMPTY_SEC วิ "ไม่สนใจว่าถุงมีกี่ใบ" — เลยรู้สึกรีบขายทั้งที่ยังไม่เต็ม
--   (เช่น "Sold 17 leaves" ทั้งที่ถุงจุ 75) แก้ให้เช็คถุงจริงก่อน: ขายเฉพาะมีของ + รอเกิน EMPTY_SEC
--   จริงๆ (กันเคสหลักในลูปเก็บพลาดจับไม่ได้) ไม่ใช่ขายทุกครั้งที่ครบเวลา
task.spawn(function()
    while _G.LF79_GEN == GEN do
        task.wait(EMPTY_SEC)
        if AUTO_ON then
            local lb = findBagLabel()
            local cur = lb and tonumber(lb.Text)
            if cur and cur > 0 then doEmpty() end
        end
    end
end)

warn("[AutoLeaf79] v3.8 loaded — ตัวสำรองขายเช็คถุงจริงก่อนขาย (ไม่ขายทั้งที่ยังไม่เต็มแล้ว)")
