-- 75RB_AutoFarm.lua v1.0 — ออโต้ฟาร์มครบวงจร: วาปหาก้อนแพงสุด → ยิงรีโมตเก็บ →
--   กระเป๋าใกล้เต็ม → วาปไปร้าน SellWorker → ยิงขาย → วนใหม่
-- ใช้ความรู้จากสปายทั้งหมด:
--   เก็บ = RS.Remotes.CrystalHoldComplete:FireServer(ก้อน)   (DeepSpy)
--   ขาย = firesignal ตัวเลือก 1 ในเมนู GUI 'dialog' ("Sell all crystals")  (SellSpy v1.1)
--         *ยิง SellRequest ตรงๆ ไม่ได้ผล — server รับเฉพาะการเลือกในเมนูจริง*
--   น้ำหนัก = GUI ExplorerHud.BackpackPanel.Value '656.0 / 1237.0 kg'  (BagSpy)
--   เพดาน = PlayerData.RealStats.CarryWeight | เงิน = RealStats.Cash
--   ก้อนบ้าน: ใต้ Plots / ไม่มี prompt → ข้าม (HomeSpy)
-- v3.6: (PickSpy) "ยิงตรงแบบ 74" ใช้ได้จริง! ยิง CrystalHoldComplete เฉยๆ ของเข้าใน 0.3 วิ
--       ขอแค่อยู่ในระยะ (4-13 studs) → ทุกมุมลองยิงตรงก่อน ไม่เข้าค่อยกดค้าง (เร็วขึ้น ~4 เท่า)
-- v3.5: v3.4 ยิง remote รัวเกิน (ทุกก้อน x3 รอบ) → server เมินทุกคำสั่ง เก็บไม่เข้าเลย!
--       → ยิงทีละก้อน เว้น 0.3 วิ เฉพาะก้อนในระยะ 14 สูงสุด 10 ก้อน + กวาดกองเว้น 20 วิ/ครั้ง
--       + "บินหนีก่อนขุด": ยืนเยื้องสูง 2 ห่าง 4 และถอยขึ้น 8 ทันทีที่ก้อนแตก (กันเศษดันตัว)
-- v3.4: ระเบิดทำของตกทับกันเป็นสิบ แต่ปุ่ม E ขึ้นให้ก้อนเดียว เก็บไม่ทัน →
--       ยิง remote CrystalDroppedPickup + CrystalHoldComplete ใส่ทุกก้อนรวดเดียว (ไม่ง้อปุ่ม)
--       + เจอกองของตก ≥3 ชิ้นใกล้ตัว (รัศมี 250) กวาดก่อนไปหาก้อนไกล
-- v3.3: ก้อนนึงกินเวลา 40 วิ! (ไล่กดค้างทุกมุม มุมละ 4.5 วิ) → เพดาน 12 วิ/ก้อน +
--       ยอมกดค้างแค่ 2 ครั้ง ไม่เข้าก็ข้ามไปก้อนอื่นเลย
-- v3.2: "ขายที่ %" ลงต่ำกว่า 10% ได้ (ต่ำกว่า 10 ปรับทีละ 1% ต่ำสุด 1%)
-- v3.1: "ขายที่ %" ปรับทีละ 5% ด้วยปุ่ม − [85%] + (เดิมกดวนทีละ 15% ข้ามค่าที่ต้องการ)
-- v3.0: ตัวกรองเปลี่ยนเป็น "พิมพ์เอง" 3 ช่อง (kg ต่ำ / kg สูง / ราคาขั้นต่ำ) รับ 30M 500K 1.5m
--       แทนปุ่ม −/+ ที่ปรับทีละนิดช้า | ราคา 0 = ปิดเงื่อนไขราคา
-- v2.9: ป๊อปอัป "เสร็จสิ้นการขุดแร่/ก้อนใหญ่เกิน" (PlayerGui.Sell.Frame) บังจอ → กดโอเค/X ปิดเอง
--       (ห้ามแตะปุ่ม "ขโมย/STEAL" เด็ดขาด — เสีย Robux จริง)
-- v2.8: "หยิบก่อน ขวานทีหลัง" — เลิกฟันขวานระหว่างวนมุม/รอผล (ขวานทำก้อนแตก ของร่วงลงถ้ำ
--       แทนที่จะเข้ากระเป๋าตรงๆ) ใช้ขวานเฉพาะตอนหยิบไม่ได้จริงๆ เท่านั้น
-- v2.7: Max=0 เป็นค่าชั่วคราว! (ก้อนเดียวกันเดี๋ยว 0 เดี๋ยว 14) → รอเช็คซ้ำ 1.5 วิก่อนตัดสินใจฟันขวาน
-- v2.6: (PickSpy v2.0) 2 บั๊กใหญ่ — (ก) เกมโชว์ปุ่มให้ก้อนใกล้สุดก้อนเดียว ก้อนเป้าหมายเลย
--       ไม่เคย "ปุ่มติด" ในโซนก้อนเยอะ → คิดระยะเองจาก MaxActivationDistance แทน
--       (ข) ก้อน Max=0 = กดไม่ได้เลย (ยังฝังในหิน) → ข้ามการวนมุม ไปฟันขวานทันที
-- v2.5: บั๊กร้าย! ตัวอ่านน้ำหนัก (GUI) คืน 0.0 ทั้งที่เพิ่งเก็บ 354kg → บอทคิดว่าเก็บไม่เข้าทุกก้อน
--       → อ่านจากข้อมูลจริง PlayerData.Inventory.Crystals แทน + ยืนยันด้วย "จำนวนก้อนเพิ่ม" ด้วย
-- v2.4: "เห็นแต่เก็บไม่ได้" = วาปไม่ถึง (ห่างเป้า 28!) เพราะ ItemESP เปิดบินอยู่ แย่งเขียน CFrame
--       → ตั้ง _G.AF75_PIN ให้ ESP หลบ (ESP v2.18) + ตอกตำแหน่งซ้ำทุกรอบ รอถึง 5 วิ + เตือนใน log
-- v2.3: เก็บช้า — (ก) กดค้างเช็คระหว่างทาง ของเข้าปล่อยทันที (เดิมรอครบ Hold 5 วิเสมอ)
--       (ข) ลองแค่ "both" พอ (เดิมลอง both แล้ว prompt ซ้ำ = เสียเวลา 2 เท่า)
--       (ค) รอปุ่มติดต่อมุมเหลือ 0.4 วิ + สปายจับเวลารายขั้น (⏱ หามุม/กดค้าง/ขวาน)
-- v2.2: (ก) เกมขึ้น "ไกลเกินไป! เข้าใกล้เพื่อขุด" → ยืนชิดขึ้น (2.5-5.5 studs แทน 4-10)
--       (ข) ขุดแตกแล้วของร่วงลงถ้ำ → ตามเก็บก้อนใน DroppedCrystals รัศมี 120 รอบจุดเดิม
-- v2.1: รวมร่าง — ทุกมุมที่วนจะ "หันหน้าใส่แร่ + ฟันขวาน" ไปพร้อมกับรอปุ่มติด
--       (ถือขวานไว้ตลอด) เร็วขึ้นและครอบคลุมทั้งก้อนหยิบและก้อนที่ต้องขุด
-- v2.0: ก้อนเล็กแต่แพง (T6 2-8kg) กด prompt ไม่เข้าเลย → เพิ่มโหมด "ฟันขวาน":
--       ถือขวาน หันตัว+กล้องใส่ก้อน แล้ว Tool:Activate() รัวสูงสุด 25 ที เช็คน้ำหนักทุกที
-- v1.9: ปุ่มน้ำหนักปรับทีละ 5 kg (เดิม 25/100 หยาบไป) + เงื่อนไข "หรือราคา"
--       ก้อนที่ราคา ≥ ค่าที่ตั้ง (ดีฟอลต์ $1M) เก็บเลยไม่สนน้ำหนัก | ปุ่ม ปิด/1M สลับเปิดปิด
-- v1.8: เจอตัวจริง! prompt ขาย = Workspace.Things.SellProx.ProximityPrompt
--       (Action='Sell Crystals' Hold=0 Max=10) ไม่ได้อยู่ใต้ Model SellWorker
--       + ตัวเลือกเมนู = ImageButton ที่ dialog.dialogResponses.1
-- v1.7: ขายไม่เข้า — (ก) ยืนระดับเดียวกับ NPC วน 8 มุมจนปุ่ม E ติด แล้วกด E เปิดเมนูก่อน
--       (ข) กดตัวเลือก 1 แน่นขึ้น: คีย์ '1' จริง (VirtualInputManager/keypress) + ยิงสัญญาณทุกชั้น
-- v1.6: กรองช่วงน้ำหนักแร่ (ดีฟอลต์ 50-1000 kg) ปรับได้ที่แผง — ก้อนจิ๋ว 0.2kg เสียเวลาวาปเปล่า
-- v1.5: วนหา 8 มุมรอบก้อน (ระดับเดียวกัน) + เช็ค "ปุ่มติดไหม" ด้วย PromptShown ก่อนกด
--       ติด=กดจริงรอผล | ไม่ติด=วาปมุมถัดไปทันที (ไม่เสียเวลากดลม) + จำมุมที่เข้า
-- v1.4: ยิง remote เปล่าไม่เข้าแล้ว (ยิง 10 ครั้งก้อนไม่ขยับ) → บอทไล่หา "ท่าที่เข้า" เอง
-- v1.3: กล่อง log ในตัว (สปายการทำงานเอง) — เวลาวาป/จำนวนครั้งที่ยิง/ก้อนหายเทียบของเข้า/
--       จังหวะขาย + ปุ่ม COPY log ส่งให้ Claude วิเคราะห์
-- v1.2: จังหวะแม่นขึ้น — รอ "ถึงก้อนจริง" ก่อนยิง + ยืนยันด้วย "น้ำหนักกระเป๋าเพิ่ม"
--       (ก้อนหายจากแมพไม่พอ! FX ลบก้อนก่อนของเข้ากระเป๋า → เดิมวาปหนีเร็วเกินของหลุด)
-- การเคลื่อนที่: ตรึง CFrame แบบ 74RB (ไม่ร่วง ไม่โดนผลัก ทะลุกำแพง) + ปิดท่าตก
if _G.AF75_CONNS then
    for _, c in pairs(_G.AF75_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.AF75_GUI then pcall(function() _G.AF75_GUI:Destroy() end) end
_G.AF75_CONNS = {}
_G.AF75_RUN = false

local V = "3.6"
local Players = game:GetService("Players")
local RunSvc  = game:GetService("RunService")
local RS      = game:GetService("ReplicatedStorage")
local LP      = Players.LocalPlayer

local Rem   = RS:FindFirstChild("Remotes")
local pickR = Rem and Rem:FindFirstChild("CrystalHoldComplete")
-- v3.4: ของที่ตกจากระเบิด (DroppedCrystals) มี remote เก็บของตัวเอง — ยิงตรงได้ ไม่ต้องกด E
local dropR = Rem and Rem:FindFirstChild("CrystalDroppedPickup")
local sellR = Rem and Rem:FindFirstChild("SellRequest")

-- ==================== Config/State ====================
local MIN_TIER  = 4
local SELL_PCT  = 0.85          -- กระเป๋าถึง % นี้ → ไปขาย
local KG_MIN    = 50            -- v1.6: เอาเฉพาะก้อน 50-1000 kg (ก้อนจิ๋วเสียเวลาวาปเปล่า)
local KG_MAX    = 1000
local VAL_MIN   = 1e6           -- v1.9: "หรือ" ราคา ≥ นี้ ก็เก็บ (ก้อนเล็กแต่แพงก็คุ้ม) | 0 = ปิด
local statPick, statVal, statSell = 0, 0, 0
local FAILED = {}               -- ก้อนที่เก็บไม่เข้า พัก 30 วิ
local TARGET_POS = nil          -- จุดตรึงตัว (nil = ไม่ตรึง เดินเองได้)
local TARGET_LOOK = nil         -- v2.1: จุดที่ให้หันหน้าใส่ (แร่) — ขวานต้องเล็งถึงจะโดน
local LAST_SWEEP = 0            -- v3.5: กันกวาดกองของตกถี่เกิน (เว้น 20 วิ)

local function fmtMoney(v)
    if v >= 1e9 then return ("$%.2fB"):format(v / 1e9) end
    if v >= 1e6 then return ("$%.1fM"):format(v / 1e6) end
    if v >= 1e3 then return ("$%.0fK"):format(v / 1e3) end
    return "$" .. math.floor(v)
end

-- น้ำหนักกระเป๋า: อ่านจาก GUI (ตรงกับจอเป๊ะ) | สำรอง: บวก WeightKg ของในกระเป๋า
-- v2.5: อ่านน้ำหนักจาก "ข้อมูลจริง" เป็นหลัก — GUI เชื่อไม่ได้!
-- (log เจอ GUI คืน 0.0 ทั้งที่เพิ่งเก็บ 354kg → บอทคิดว่าเก็บไม่เข้าทุกก้อนตั้งแต่นั้น)
-- หลัก: บวก WeightKg ของทุกก้อนใน PlayerData.Inventory.Crystals | สำรอง: ป้าย GUI
local function bagInfo()
    local pd = LP:FindFirstChild("PlayerData")
    local inv = pd and pd:FindFirstChild("Inventory")
    inv = inv and inv:FindFirstChild("Crystals")
    local rs2 = pd and pd:FindFirstChild("RealStats")
    local cw = rs2 and rs2:FindFirstChild("CarryWeight")
    if inv then
        local cur = 0
        for _, c in ipairs(inv:GetChildren()) do
            cur += (c:GetAttribute("WeightKg") or 0)
        end
        return cur, (cw and cw.Value or 1237)
    end
    local pg = LP:FindFirstChild("PlayerGui")
    local lbl = pg and pg:FindFirstChild("ExplorerHud")
    lbl = lbl and lbl:FindFirstChild("BackpackPanel")
    lbl = lbl and lbl:FindFirstChild("Value")
    if lbl and lbl:IsA("TextLabel") then
        local a, b = lbl.Text:match("([%d%.]+)%s*/%s*([%d%.]+)")
        if a and b then return tonumber(a), tonumber(b) end
    end
    return 0, (cw and cw.Value or 1237)
end

-- v2.5: นับ "จำนวนก้อนในกระเป๋า" เป็นตัวยืนยันคู่กับน้ำหนัก (ก้อนเบามาก น้ำหนักอาจไม่ขยับชัด)
local function bagCount()
    local pd = LP:FindFirstChild("PlayerData")
    local inv = pd and pd:FindFirstChild("Inventory")
    inv = inv and inv:FindFirstChild("Crystals")
    return inv and #inv:GetChildren() or 0
end

-- v2.5: "เก็บเข้าแล้วหรือยัง" = น้ำหนักเพิ่ม "หรือ" จำนวนก้อนเพิ่ม (อย่างใดอย่างหนึ่งก็พอ)
local BAG_N0 = 0
local function markBase() BAG_N0 = bagCount() end
local function picked(kg0)
    return bagInfo() > kg0 + 0.05 or bagCount() > BAG_N0
end

local function cashNow()
    local pd = LP:FindFirstChild("PlayerData")
    local st = pd and pd:FindFirstChild("RealStats")
    local c = st and st:FindFirstChild("Cash")
    return c and c.Value or 0
end

-- ก้อนที่เก็บได้จริง (กรองบ้านเพื่อน + ต้องมี prompt) — สูตรเดียวกับ ESP/Assist
local function getCrystals()
    local out = {}
    for _, c in ipairs(workspace:GetDescendants()) do
        if c:IsA("BasePart") and c:GetAttribute("CrystalName") and c:GetAttribute("Tier")
            and not c:FindFirstAncestor("Plots") then
            local pp = c:FindFirstChildOfClass("ProximityPrompt")
            if pp and pp.Enabled then out[#out + 1] = c end
        end
    end
    return out
end

local function bestCrystal(maxKg)
    local best, bv
    for _, c in ipairs(getCrystals()) do
        local t = c:GetAttribute("Tier")
        if t and t >= MIN_TIER and (not FAILED[c] or os.clock() > FAILED[c]) then
            local kg = c:GetAttribute("WeightKg") or 0
            local v = c:GetAttribute("Value") or 0
            -- ยัดกระเป๋าลง + (อยู่ในช่วงน้ำหนัก "หรือ" ราคาถึงเกณฑ์) — v1.9
            local okKg = kg >= KG_MIN and kg <= KG_MAX
            local okVal = VAL_MIN > 0 and v >= VAL_MIN
            if kg <= maxKg and (okKg or okVal) then
                if not bv or v > bv then best, bv = c, v end
            end
        end
    end
    return best
end

-- v1.1 (SellSpy): กดขาย = ยิงทุกสัญญาณใส่ตัวเลือก 1 ในเมนู GUI 'dialog' + ปุ่ม Sell.Frame.Sell
-- (ยิง SellRequest ตรงๆ server ไม่รับ — ต้อง "เลือกในเมนู" จริงเท่านั้น)
local FS = firesignal or (getgenv and getgenv().firesignal)
local function fireAll(obj)
    if not FS or not obj then return end
    for _, s in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down",
        "MouseButton1Up", "InputBegan", "InputEnded", "TouchTap" }) do
        pcall(function() if obj[s] then FS(obj[s]) end end)
    end
end
-- v1.7: กดตัวเลือก 1 ให้แน่นขึ้น — ยิงทุก GuiObject ในสาย dialogResponses.1 (ไม่ใช่แค่ GuiButton)
-- + ยิงปุ่มที่ "ข้อความมีคำว่าขายทั้งหมด" ทุกตัวใน PlayerGui + กดคีย์ 1 จริงผ่าน VirtualInputManager
local VIM = (function()
    local ok, s = pcall(function() return game:GetService("VirtualInputManager") end)
    return ok and s or nil
end)()
local function pressKey1()
    -- เมนู NPC แบบนี้มักผูกกับเลข 1 บนคีย์บอร์ด — ยิงคีย์จริงถ้า executor ให้ (มือถือก็ผ่าน VIM ได้)
    if VIM then
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.One, false, game)
            task.wait(0.06)
            VIM:SendKeyEvent(false, Enum.KeyCode.One, false, game)
        end)
    end
    local kp = (keypress or (getgenv and getgenv().keypress))
    local kr = (keyrelease or (getgenv and getgenv().keyrelease))
    if kp and kr then
        pcall(function() kp(0x31); task.wait(0.06); kr(0x31) end)   -- 0x31 = '1'
    end
end
-- v1.8: ตัวเลือกในเมนูคือ ImageButton ที่ dialog.dialogResponses.1 (SellSpy v1.4 ยืนยัน)
-- ("ขายคริสตัลทั้งหมด" — ปุ่มที่ 2 = ขายอันเดียว) | คีย์ 1 ใช้ไม่ได้ (ไปสลับช่องไอเทมแทน)
local function pressSellMenu()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    -- 1) กดปุ่มตัวเลือก 1 ตรงๆ (ImageButton)
    local dlg0 = pg:FindFirstChild("dialog", true)
    local resp0 = dlg0 and dlg0:FindFirstChild("dialogResponses", true)
    local btn1 = resp0 and resp0:FindFirstChild("1")
    if btn1 and btn1:IsA("GuiButton") then fireAll(btn1) end
    -- 2) ยิงสัญญาณทุกชั้นในสายตัวเลือก 1 (เผื่อ handler อยู่ชั้นอื่น)
    local dlg = pg:FindFirstChild("dialog", true)
    local resp = dlg and dlg:FindFirstChild("dialogResponses", true)
    local one = resp and resp:FindFirstChild("1")     -- "Sell all crystals"
    if one then
        fireAll(one)
        for _, c in ipairs(one:GetDescendants()) do fireAll(c) end   -- ทุกตัว ไม่เฉพาะ GuiButton
        local p = one.Parent
        while p and p ~= pg do fireAll(p); p = p.Parent end
    end
    -- 3) ปุ่มไหนก็ตามที่ข้อความ = ขายทั้งหมด
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local t = (d:IsA("TextButton") and d.Text or "") .. " " .. d.Name
            if t:find("ทั้งหมด") or t:lower():find("sell all") then fireAll(d) end
        end
    end
end

-- v1.8 (SellSpy v1.4): prompt ขายตัวจริงอยู่ที่ Workspace.Things.SellProx.ProximityPrompt
-- (Action='Sell Crystals' Hold=0 Max=10) — ไม่ได้อยู่ใต้ Model SellWorker! เดิมเลยหาไม่เจอ
-- v2.9: ป๊อปอัป "เสร็จสิ้นการขุดแร่! / ก้อนใหญ่เกิน" (PlayerGui.Sell.Frame) บล็อกจอ บอททำต่อไม่ได้
-- → กด "โอเค" (ปุ่ม Sell/Keep Digging) หรือ X ให้อัตโนมัติ
-- ⚠ ห้ามแตะปุ่ม "ขโมย/STEAL" เด็ดขาด — เสีย Robux จริง!
local function closeBlockPopup()
    local pg = LP:FindFirstChild("PlayerGui")
    local sg = pg and pg:FindFirstChild("Sell")
    local fr = sg and sg:FindFirstChild("Frame")
    if not fr or not fr.Visible then return false end
    for _, n in ipairs({ "Sell", "Close" }) do    -- Sell = "โอเค/Keep Digging", Close = X
        local b = fr:FindFirstChild(n)
        if b and b:IsA("GuiButton") then fireAll(b) end
    end
    return true
end
table.insert(_G.AF75_CONNS, RunSvc.Heartbeat:Connect(function()
    if not _G.AF75_RUN then return end
    if os.clock() % 1 < 0.02 then closeBlockPopup() end   -- เช็ควินาทีละครั้ง ไม่กินแรง
end))

local function findSellPrompt()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and (d.ActionText or ""):lower():find("sell") then
            local holder = d.Parent
            local p = holder and (holder:IsA("BasePart") and holder
                or holder:FindFirstChildWhichIsA("BasePart", true))
            if p then return d, p.Position end
        end
    end
end

-- ==================== ตรึงตัวแบบ 74RB (บิน/วาป/กันผลัก/ทะลุกำแพง) ====================
local function setNoFall(on)
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not h then return end
    h:SetStateEnabled(Enum.HumanoidStateType.Freefall, not on)
    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not on)
    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not on)
end
table.insert(_G.AF75_CONNS, RunSvc.Heartbeat:Connect(function()
    _G.AF75_PIN = TARGET_POS ~= nil   -- v2.4: บอก ItemESP ว่าเราคุมตำแหน่งอยู่ (กันแย่งกันเขียน CFrame)
    if not TARGET_POS then return end
    local char = LP.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    if not r then return end
    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    -- v2.1: ถ้ามีเป้าให้มอง = หันตัวใส่แร่ทุกเฟรม (ขวานยิง ray ตามทิศที่หัน)
    if TARGET_LOOK and (TARGET_LOOK - TARGET_POS).Magnitude > 0.5 then
        r.CFrame = CFrame.lookAt(TARGET_POS, Vector3.new(TARGET_LOOK.X, TARGET_POS.Y, TARGET_LOOK.Z))
    else
        r.CFrame = CFrame.new(TARGET_POS) * (r.CFrame - r.CFrame.Position)
    end
    r.AssemblyLinearVelocity = Vector3.zero
end))
local function unpin()
    TARGET_POS, TARGET_LOOK = nil, nil
    setNoFall(false)
    local char = LP.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarm75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.AF75_GUI = gui

local FULL_H, MIN_H = 468, 32
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 210, 0, FULL_H)
panel.Position = UDim2.new(0.5, -105, 0, 20)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
panel.BorderSizePixel = 0
panel.Active, panel.Draggable = true, true
panel.ClipsDescendants = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -70, 0, 28); title.Position = UDim2.new(0, 8, 0, 2)
title.BackgroundTransparency = 1
title.Text = "AutoFarm v" .. V
title.Font = Enum.Font.GothamBold; title.TextSize = 14
title.TextColor3 = Color3.fromRGB(255, 170, 70)
title.TextXAlignment = Enum.TextXAlignment.Left

local foldB = Instance.new("TextButton", panel)
foldB.Size = UDim2.new(0, 28, 0, 24); foldB.Position = UDim2.new(1, -62, 0, 4)
foldB.Text = "—"; foldB.Font = Enum.Font.GothamBold; foldB.TextSize = 14
foldB.BackgroundColor3 = Color3.fromRGB(50, 50, 70); foldB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", foldB).CornerRadius = UDim.new(0, 5)

local closeB = Instance.new("TextButton", panel)
closeB.Size = UDim2.new(0, 28, 0, 24); closeB.Position = UDim2.new(1, -32, 0, 4)
closeB.Text = "✕"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 14
closeB.BackgroundColor3 = Color3.fromRGB(140, 30, 30); closeB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)

local runB = Instance.new("TextButton", panel)
runB.Size = UDim2.new(0, 198, 0, 34); runB.Position = UDim2.new(0, 6, 0, 32)
runB.Text = "▶ เริ่มฟาร์ม"; runB.Font = Enum.Font.GothamBold; runB.TextSize = 15
runB.BackgroundColor3 = Color3.fromRGB(30, 120, 30); runB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", runB).CornerRadius = UDim.new(0, 6)

local tierB = Instance.new("TextButton", panel)
tierB.Size = UDim2.new(0, 96, 0, 26); tierB.Position = UDim2.new(0, 6, 0, 72)
tierB.Text = "เทียร์ ≥ T4"; tierB.Font = Enum.Font.GothamBold; tierB.TextSize = 12
tierB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); tierB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", tierB).CornerRadius = UDim.new(0, 5)
tierB.MouseButton1Click:Connect(function()
    MIN_TIER = MIN_TIER % 6 + 1
    tierB.Text = "เทียร์ ≥ T" .. MIN_TIER
end)

-- v3.1: ขายที่ % — ปรับทีละ 5% ด้วยปุ่ม −/+ (เดิมกดวนทีละ 15% ข้ามค่าที่อยากได้)
local pctB = Instance.new("TextButton", panel)
pctB.Size = UDim2.new(0, 52, 0, 26); pctB.Position = UDim2.new(0, 132, 0, 72)
pctB.Text = "85%"; pctB.Font = Enum.Font.GothamBold; pctB.TextSize = 12
pctB.BackgroundColor3 = Color3.fromRGB(150, 110, 30); pctB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", pctB).CornerRadius = UDim.new(0, 5)
local function pctBtn(txt, x)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 24, 0, 26); b.Position = UDim2.new(0, x, 0, 72)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 15
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 65); b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local pctDn, pctUp = pctBtn("−", 106), pctBtn("+", 186)
-- v3.2: ลงต่ำกว่า 10% ได้ — ต่ำกว่า 10 ปรับทีละ 1% (9,8,...,1) ตั้งแต่ 10 ขึ้นไปทีละ 5%
local function setPct(d)
    local p = SELL_PCT * 100
    local step = (d < 0 and p <= 10) or (d > 0 and p < 10) and 1 or 5
    p = math.clamp(p + (d > 0 and step or -step), 1, 95)
    SELL_PCT = p / 100
    pctB.Text = ("%d%%"):format(math.floor(p + 0.5))
end
pctDn.MouseButton1Click:Connect(function() setPct(-1) end)
pctUp.MouseButton1Click:Connect(function() setPct(1) end)
pctB.Text = ("%d%%"):format(math.floor(SELL_PCT * 100 + 0.5))
local pctTag = Instance.new("TextLabel", panel)
pctTag.Size = UDim2.new(0, 96, 0, 26); pctTag.Position = UDim2.new(0, 108, 0, 46)
pctTag.BackgroundTransparency = 1
pctTag.Text = "ขายเมื่อกระเป๋าถึง"
pctTag.Font = Enum.Font.Gotham; pctTag.TextSize = 10
pctTag.TextColor3 = Color3.fromRGB(130, 130, 150)

-- v1.6: ช่วงน้ำหนักแร่ที่จะเก็บ  ต่ำสุด − [50] +   สูงสุด − [1000] +
local kgL = Instance.new("TextLabel", panel)
kgL.Size = UDim2.new(1, -12, 0, 18); kgL.Position = UDim2.new(0, 6, 0, 102)
kgL.BackgroundTransparency = 1
kgL.Text = "น้ำหนักแร่ 50 - 1000 kg"
kgL.Font = Enum.Font.GothamBold; kgL.TextSize = 12
kgL.TextColor3 = Color3.fromRGB(255, 220, 150)
local function updKgL()
    kgL.Text = ("น้ำหนัก %d-%d kg  หรือ ≥%s"):format(KG_MIN, KG_MAX,
        VAL_MIN > 0 and fmtMoney(VAL_MIN) or "ปิด")
end
-- v3.0: พิมพ์เอง — 3 ช่องกรอก (kg ต่ำ / kg สูง / ราคาขั้นต่ำ) รับ 30M, 500K, 1.5m ได้
-- ราคา 0 = ปิดเงื่อนไขราคา (ใช้น้ำหนักอย่างเดียว)
local function parseNum(s)
    s = tostring(s):gsub("[%s,%$]", "")
    local n, suf = s:match("^([%d%.]+)([kKmMbB]?)$")
    n = tonumber(n)
    if not n then return nil end
    suf = suf:lower()
    if suf == "k" then n = n * 1e3
    elseif suf == "m" then n = n * 1e6
    elseif suf == "b" then n = n * 1e9 end
    return n
end
local function inputBox(x, w, y, val, tip, apply)
    local b = Instance.new("TextBox", panel)
    b.Size = UDim2.new(0, w, 0, 24); b.Position = UDim2.new(0, x, 0, y)
    b.Text = val; b.PlaceholderText = tip
    b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = Color3.fromRGB(28, 28, 40); b.TextColor3 = Color3.new(1, 1, 1)
    b.ClearTextOnFocus = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.FocusLost:Connect(function()
        local n = parseNum(b.Text)
        if n then apply(n) else b.Text = "?" end
        updKgL()
    end)
    return b
end
local kgMinB, kgMaxB, valB
kgMinB = inputBox(6, 58, 122, tostring(KG_MIN), "kg ต่ำ", function(n)
    KG_MIN = math.clamp(n, 0, 1e5); kgMinB.Text = tostring(math.floor(KG_MIN))
end)
kgMaxB = inputBox(68, 58, 122, tostring(KG_MAX), "kg สูง", function(n)
    KG_MAX = math.clamp(n, 0, 1e5); kgMaxB.Text = tostring(math.floor(KG_MAX))
end)
valB = inputBox(130, 74, 122, "1M", "ราคาต่ำสุด", function(n)
    VAL_MIN = math.clamp(n, 0, 1e12)
    valB.Text = VAL_MIN > 0 and fmtMoney(VAL_MIN):gsub("%$", "") or "0"
end)
local hintL = Instance.new("TextLabel", panel)
hintL.Size = UDim2.new(1, -12, 0, 16); hintL.Position = UDim2.new(0, 6, 0, 148)
hintL.BackgroundTransparency = 1
hintL.Text = "แตะช่องแล้วพิมพ์: kgต่ำ | kgสูง | ราคา (30M, 500K, 0=ปิด)"
hintL.Font = Enum.Font.Gotham; hintL.TextSize = 10
hintL.TextColor3 = Color3.fromRGB(130, 130, 150)
hintL.TextXAlignment = Enum.TextXAlignment.Left
updKgL()

local statusL = Instance.new("TextLabel", panel)
statusL.Size = UDim2.new(1, -12, 0, 34); statusL.Position = UDim2.new(0, 6, 0, 178)
statusL.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
statusL.Text = " พร้อม"
statusL.Font = Enum.Font.Gotham; statusL.TextSize = 11
statusL.TextColor3 = Color3.fromRGB(255, 220, 150)
statusL.TextXAlignment = Enum.TextXAlignment.Left
statusL.TextWrapped = true
Instance.new("UICorner", statusL).CornerRadius = UDim.new(0, 5)
local function status(s) statusL.Text = " " .. s end

-- v1.3: กล่อง log ในตัว — เห็นจังหวะจริงทุกขั้น (เลือก/วาป/ถึง/ยิง/น้ำหนักขยับ) + COPY ส่งได้
local LOG = {}
local T0 = os.clock()
local logBox = Instance.new("TextLabel", panel)
logBox.Size = UDim2.new(1, -12, 0, 120); logBox.Position = UDim2.new(0, 6, 0, 314)
logBox.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
logBox.Text = ""
logBox.Font = Enum.Font.Code; logBox.TextSize = 10
logBox.TextColor3 = Color3.fromRGB(170, 230, 255)
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Bottom
logBox.TextWrapped = true
Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 5)
local function LG(s)
    LOG[#LOG + 1] = ("[%6.1f] %s"):format(os.clock() - T0, s)
    if #LOG > 200 then table.remove(LOG, 1) end
    local from = math.max(1, #LOG - 11)
    local view = {}
    for i = from, #LOG do view[#view + 1] = LOG[i] end
    logBox.Text = table.concat(view, "\n")
end

local copyB = Instance.new("TextButton", panel)
copyB.Size = UDim2.new(0, 96, 0, 24); copyB.Position = UDim2.new(0, 6, 0, 438)
copyB.Text = "COPY log"; copyB.Font = Enum.Font.GothamBold; copyB.TextSize = 12
copyB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); copyB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", copyB).CornerRadius = UDim.new(0, 5)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(LOG, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_farm_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์!" or "copy ไม่ได้")
    task.delay(1.6, function() copyB.Text = "COPY log" end)
end)

local clrB = Instance.new("TextButton", panel)
clrB.Size = UDim2.new(0, 96, 0, 24); clrB.Position = UDim2.new(0, 108, 0, 438)
clrB.Text = "CLEAR"; clrB.Font = Enum.Font.GothamBold; clrB.TextSize = 12
clrB.BackgroundColor3 = Color3.fromRGB(90, 60, 30); clrB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", clrB).CornerRadius = UDim.new(0, 5)
clrB.MouseButton1Click:Connect(function() LOG = {}; logBox.Text = "" end)

local statL = Instance.new("TextLabel", panel)
statL.Size = UDim2.new(1, -12, 0, 92); statL.Position = UDim2.new(0, 6, 0, 218)
statL.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
statL.Font = Enum.Font.Code; statL.TextSize = 11
statL.TextColor3 = Color3.fromRGB(190, 220, 190)
statL.TextXAlignment = Enum.TextXAlignment.Left
statL.TextYAlignment = Enum.TextYAlignment.Top
statL.TextWrapped = true
Instance.new("UICorner", statL).CornerRadius = UDim.new(0, 5)
local cash0 = cashNow()
local function updStat()
    local cur, cap = bagInfo()
    statL.Text = (" เก็บ %d ก้อน (%s)\n ขาย %d รอบ\n กระเป๋า %.0f/%.0f kg\n กำไรรอบนี้ %s")
        :format(statPick, fmtMoney(statVal), statSell, cur, cap, fmtMoney(cashNow() - cash0))
end
updStat()

-- ==================== v1.4: ตัวไล่หา "ท่าที่เก็บเข้า" ====================
-- ยิง remote เปล่าไม่เข้า (ยิง 10 ครั้งก้อนไม่ขยับ) แต่กดมือ E เข้า
-- → ไล่ลอง ตำแหน่ง x วิธี จนเจอสูตรที่ได้ผล แล้ว "จำสูตรนั้น" ใช้กับก้อนต่อไปเลย
-- ตำแหน่ง: ระดับเดียวกับก้อน (รอบทิศ) / เหนือ / ใต้  | วิธี: prompt กดค้าง / remote / ทั้งคู่
local WIN_POS, WIN_WAY = nil, nil     -- สูตรที่เคยเข้า (จำไว้ ลองอันนี้ก่อนเสมอ)

-- v1.5: เช็ค "ปุ่มติดไหม" ด้วย PromptShown/PromptHidden (เกมโชว์ปุ่ม E = อยู่ในระยะ+มองเห็น)
-- → วาปวนมุม ถ้าปุ่มติดค่อยกด ถ้าไม่ติดวาปมุมถัดไปเลย ไม่เสียเวลากดลม
local PROMPT_ON = nil
local PPS = game:GetService("ProximityPromptService")
table.insert(_G.AF75_CONNS, PPS.PromptShown:Connect(function(pp) PROMPT_ON = pp end))
table.insert(_G.AF75_CONNS, PPS.PromptHidden:Connect(function(pp)
    if PROMPT_ON == pp then PROMPT_ON = nil end
end))
-- v2.6 (PickSpy v2.0): เกมโชว์ปุ่มให้ "ก้อนใกล้สุดก้อนเดียว" — ในโซนก้อนเยอะ ปุ่มของเป้าหมายเรา
-- ไม่มีวันขึ้น (log เห็น Starsapphire/Cerulime สลับแย่งกันตลอด) → เลิกรอ PromptShown อย่างเดียว
-- คิดเองด้วยระยะจริง: ห่าง ≤ MaxActivationDistance = กดได้แน่ (Max=0 คือกดไม่ได้เลย)
local function promptReady(c)
    local pp = c:FindFirstChildOfClass("ProximityPrompt")
    if not pp or not pp.Enabled then return false end
    if PROMPT_ON == pp then return true end
    local mx = pp.MaxActivationDistance
    if mx <= 0 then return false end
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return r and (c.Position - r.Position).Magnitude <= mx * 0.9
end

-- v1.5: 8 มุมรอบก้อน "ระดับเดียวกัน" (ท่าที่ log พิสูจน์ว่าเข้า) + สำรองต่ำ/สูง
local function posList(c)
    local p, out = c.Position, {}
    -- v2.2: เกมขึ้น "ไกลเกินไป! เข้าใกล้เพื่อขุด" → ระยะขุดสั้นกว่าระยะหยิบ ต้องยืนชิดกว่าเดิม
    local d = 2.5 + math.min(3, (c.Size.Magnitude or 4) / 4)
    local dirs = {
        { "N", 0, -1 }, { "NE", 0.7, -0.7 }, { "E", 1, 0 }, { "SE", 0.7, 0.7 },
        { "S", 0, 1 }, { "SW", -0.7, 0.7 }, { "W", -1, 0 }, { "NW", -0.7, -0.7 },
    }
    for _, dir in ipairs(dirs) do
        out[#out + 1] = { "ระดับเดียวกัน " .. dir[1],
            p + Vector3.new(dir[2] * d, 0, dir[3] * d) }
    end
    out[#out + 1] = { "ต่ำกว่า 3", p + Vector3.new(0, -3, -d) }
    out[#out + 1] = { "เหนือ 6", p + Vector3.new(0, 6, 0) }
    return out
end
-- v2.3: "กดค้าง" คือตัวกินเวลาหลัก (T6 Hold=5 วิ!) — กดค้างแบบ "เช็คระหว่างทาง"
-- ของเข้าเมื่อไหร่ปล่อยทันที ไม่รอครบเวลา (เดิมรอเต็ม HoldDuration+0.4 เสมอ)
-- v3.3: เพดานเวลาต่อก้อน (เดิมไล่กดค้างทุกมุม มุมละ 4.5 วิ รวม 40 วิ!)
local TRY_DEADLINE = 0      -- เวลาหมดอายุของก้อนนี้
local HOLD_TRIES = 0        -- กดค้างไปกี่ครั้งแล้ว
local MAX_HOLDS = 2         -- กดค้างไม่เข้า 2 ครั้ง = เลิกยุ่ง ไปก้อนอื่น
local MAX_SECS = 12         -- เกิน 12 วิต่อก้อน = ทิ้ง

local function holdUntil(pp, c, kg0)
    pcall(function() pp:InputHoldBegin() end)
    -- ไม่กดค้างเกินเวลาที่เหลือของก้อนนี้
    local dl = math.min(os.clock() + pp.HoldDuration + 0.5, TRY_DEADLINE)
    while os.clock() < dl do
        task.wait(0.1)
        if picked(kg0) or not c.Parent then break end
    end
    pcall(function() pp:InputHoldEnd() end)
end
local function doWay(c, way, kg0)
    local pp = c:FindFirstChildOfClass("ProximityPrompt")
    if way == "prompt" and pp then
        holdUntil(pp, c, kg0)
    elseif way == "remote" then
        pcall(function() pickR:FireServer(c) end)
    elseif way == "both" and pp then
        pcall(function() pickR:FireServer(c) end)
        holdUntil(pp, c, kg0)
        pcall(function() pickR:FireServer(c) end)
    elseif way == "fp" then
        local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
        if fp and pp then pcall(fp, pp, 1) end
    end
end
-- v1.5: ที่มุมนี้ "กดติดไหม" → ติดก็กดจริง (รอผล) | ไม่ติดก็รีเทิร์นไว ไปมุมถัดไป
-- v2.1: ทุกมุมที่วน — หันหน้าใส่แร่ + ฟันขวานไปด้วยระหว่างรอปุ่มติด (ทำสองอย่างพร้อมกัน เร็วขึ้น)
local TM = {}   -- v2.3: จับเวลาสะสมรายขั้น (สปายในตัว — ดูว่าช้าตรงไหน)
local function attempt(c, kg0, pname, ppos)
    TARGET_POS = ppos
    TARGET_LOOK = c.Position          -- หันหน้าใส่แร่ตลอด (ขวานถึงจะโดน)
    local cam = workspace.CurrentCamera
    -- v2.8: ห้ามฟันขวานตอนนี้! (ขวานทำก้อนแตก ของร่วงลงถ้ำแทนที่จะเข้ากระเป๋าตรงๆ)
    -- เฟสนี้ = "หยิบอย่างเดียว" ขวานเก็บไว้เป็นทางสุดท้ายเท่านั้น
    local t0 = os.clock()
    local ok = false
    for _ = 1, 4 do
        pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, c.Position) end)
        task.wait(0.1)
        if picked(kg0) then
            LG(("  ✅ เข้า! [%s] %.1f วิ"):format(pname, os.clock() - t0))
            WIN_POS, WIN_WAY = pname, "หยิบ"
            return true
        end
        if promptReady(c) then ok = true break end
    end
    if not ok then
        TM.scan = (TM.scan or 0) + (os.clock() - t0)   -- เวลาที่เสียไปกับมุมที่ปุ่มไม่ติด
        return false
    end
    -- v3.6 (PickSpy): ยิง remote เฉยๆ ก็เข้าได้ ถ้าอยู่ในระยะ! (Diamond เข้าใน 0.28 วิ ไม่ต้องกดค้าง)
    -- → ลองยิงตรงก่อนเสมอ เร็วกว่ากดค้าง 4-5 วิมาก ไม่เข้าค่อยกดค้าง
    if pickR then
        local t2 = os.clock()
        pcall(function() pickR:FireServer(c) end)
        for _ = 1, 9 do
            task.wait(0.1)
            if picked(kg0) then
                LG(("  ⚡ เข้า! [%s] ยิงตรง %.1f วิ"):format(pname, os.clock() - t2))
                WIN_POS, WIN_WAY = pname, "ยิงตรง"
                return true
            end
        end
    end
    -- v3.3: กดค้างไม่เข้ามาแล้ว 2 ครั้ง / หมดเวลาแล้ว = ไม่กดซ้ำอีก (กันเสีย 4.5 วิต่อมุม)
    if HOLD_TRIES >= MAX_HOLDS or os.clock() > TRY_DEADLINE then return false end
    HOLD_TRIES += 1
    -- v2.3: ใช้ "both" อย่างเดียว (มันครอบ prompt อยู่แล้ว) — เดิมลอง 2 รอบเสียเวลาซ้ำซ้อน
    local t1 = os.clock()
    doWay(c, "both", kg0)
    for _ = 1, 8 do
        task.wait(0.1)   -- v2.8: รอผลเฉยๆ ไม่ฟันขวาน (กันก้อนแตกก่อนของเข้ากระเป๋า)
        if picked(kg0) then
            TM.hold = (TM.hold or 0) + (os.clock() - t1)
            LG(("  ✅ เข้า! [%s] กดค้าง %.1f วิ"):format(pname, os.clock() - t1))
            WIN_POS, WIN_WAY = pname, "both"
            return true
        end
    end
    TM.hold = (TM.hold or 0) + (os.clock() - t1)
    return false
end

-- v2.0: โหมดฟันขวาน — ก้อนเล็กแต่แพง (T6 2-8kg) กด prompt ไม่เข้า ต้อง "ขุด" หลายทีจริงๆ
-- (ตรงกับ CrystalMineFX("hit", part, progress...) ที่เจอตอนสปาย)
-- ถือขวาน → หันกล้องใส่ก้อน → Tool:Activate() รัวๆ → เช็คน้ำหนัก
local function equipPick()
    local char = LP.Character
    if not char then return nil end
    -- ถืออยู่แล้ว?
    local held = char:FindFirstChildOfClass("Tool")
    if held and (held:GetAttribute("DigPower") or held.Name:lower():find("pick")) then return held end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if not bp then return held end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and (t:GetAttribute("DigPower") or t.Name:lower():find("pick")) then
            local h = char:FindFirstChildOfClass("Humanoid")
            if h then pcall(function() h:EquipTool(t) end) end
            task.wait(0.3)
            return char:FindFirstChildOfClass("Tool")
        end
    end
    return held
end

local function mineIt(c, kg0)
    local tool = equipPick()
    if not tool then LG("  ⚠ ไม่เจอขวานในกระเป๋า") return false end
    local cam = workspace.CurrentCamera
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not r then return false end
    -- ยืนระดับเดียวกัน ห่าง ~6 แล้วหันหน้า+กล้องใส่ก้อน (สคริปต์เกมยิง ray จากกล้อง/เมาส์)
    -- v3.5: "บินหนีก่อนขุด" — ยืนเยื้องบนนิดนึง (ห่าง 4, สูง 2) กันเศษหิน/ก้อนที่แตกดันตัว
    TARGET_POS = c.Position + Vector3.new(0, 2, -4)
    TARGET_LOOK = c.Position
    task.wait(0.4)
    LG("  ⛏ โหมดฟันขวาน (" .. tool.Name .. ")")
    for i = 1, 40 do        -- v2.6: ฟันได้ถึง 40 ที (ก้อนใหญ่ต้องหลายที) ถี่ขึ้นเป็น 0.15 วิ
        if not _G.AF75_RUN then break end
        if not c.Parent then           -- ก้อนแตกแล้ว → ของร่วงเป็นก้อนตกพื้น ตามเก็บทันที
            LG(("  💥 ก้อนแตกหลังฟัน %d ที → ถอยแล้วเก็บของตก"):format(i))
            TARGET_POS = c.Position + Vector3.new(0, 8, 0)   -- v3.5: บินหนีขึ้นก่อน กันโดนเศษดัน
            task.wait(0.6)
            return collectDropped(c.Position, kg0)
        end
        local rr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if rr then
            rr.CFrame = CFrame.lookAt(rr.Position, c.Position)   -- หันตัวใส่ก้อน
            TARGET_POS = rr.Position
        end
        pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, c.Position) end)
        pcall(function() tool:Activate() end)
        task.wait(0.15)
        if picked(kg0) then
            LG(("  ✅ เข้า! ฟันขวาน %d ที"):format(i))
            return true
        end
    end
    return picked(kg0)
end

-- v2.2: ขุดแตกแล้วของ "ตกพื้น" (ร่วงลงถ้ำ) — ตามไปเก็บก้อนที่ตกแถวนั้น
-- ก้อนตก = อยู่ใน DroppedCrystals หรือมี attr DroppedByUserId (มี prompt Action='Mine'/'Pickup')
local function collectDropped(near, kg0)
    local found = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d:GetAttribute("CrystalName")
            and (d:FindFirstAncestor("DroppedCrystals") or d:GetAttribute("DroppedByUserId"))
            and (d.Position - near).Magnitude < 120 then
            found[#found + 1] = d
        end
    end
    if #found == 0 then return false end
    table.sort(found, function(a, b)
        return (a.Position - near).Magnitude < (b.Position - near).Magnitude
    end)
    LG(("  📦 ของตกพื้น %d ชิ้น — กวาดเก็บ (ยิงตรง ไม่ง้อปุ่ม E)"):format(#found))
    local n0 = bagCount()
    -- v3.5: ห้ามยิงรัว! (v3.4 ยิงทุกก้อน x3 รอบ → server throttle เมินทุกคำสั่ง)
    -- ยืนกลางกอง ยิง CrystalDroppedPickup ทีละก้อน เว้นจังหวะ 0.3 วิ เฉพาะก้อนที่อยู่ในระยะจริง
    TARGET_POS = near + Vector3.new(0, 3, 0)
    TARGET_LOOK = near
    task.wait(0.5)
    if dropR then
        local myp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local fired = 0
        for _, dr in ipairs(found) do
            if not _G.AF75_RUN or fired >= 10 then break end
            -- v3.6: ใช้ CrystalHoldComplete ด้วย (พิสูจน์แล้วว่าเข้าจริงกับของตก DroppedCrystal)
            if dr.Parent and myp and (dr.Position - myp.Position).Magnitude <= 12 then
                pcall(function() dropR:FireServer(dr) end)
                if pickR then pcall(function() pickR:FireServer(dr) end) end
                fired += 1
                task.wait(0.35)
            end
        end
        if fired > 0 then
            task.wait(0.6)
            local got = bagCount() - n0
            LG(("  📤 ยิงตรง %d ก้อน → ได้ %d"):format(fired, got))
            if got > 0 then return true end
        end
    end
    -- ยิงตรงไม่เข้า → ถอยไปวิธีเดิม: เดินไปทีละก้อนแล้วกดค้าง
    LG("  ↩ ยิงตรงไม่เข้า — ไล่เก็บทีละก้อนแทน")
    for i = 1, math.min(6, #found) do
        local dr = found[i]
        if not _G.AF75_RUN then break end
        if dr.Parent then
            status("📦 เก็บของตก " .. i)
            TARGET_POS = dr.Position + Vector3.new(0, 0, -3)
            TARGET_LOOK = dr.Position
            task.wait(0.4)
            if promptReady(dr) then
                doWay(dr, "both", kg0)
                task.wait(0.4)
            end
        end
    end
    return bagCount() > n0 or picked(kg0)
end

function tryPick(c, kg0)
    markBase()           -- v2.5: จำจำนวนก้อนในกระเป๋าตอนเริ่ม (ใช้ยืนยันคู่กับน้ำหนัก)
    TRY_DEADLINE = os.clock() + MAX_SECS    -- v3.3: เริ่มจับเวลาก้อนนี้
    HOLD_TRIES = 0
    -- v2.8: ไม่หยิบขวานตั้งแต่แรกแล้ว — ลอง "หยิบเข้ากระเป๋า" ให้ครบก่อน ค่อยใช้ขวานทีหลัง
    local cpos = c.Position   -- จำไว้ เผื่อก้อนหาย (ของตกแถวนี้)
    -- v2.6 (PickSpy v2.0): MaxActivationDistance = 0 → ปุ่ม "ไม่มีวันขึ้น" (ก้อนยังฝังในหิน)
    -- วนหามุมเท่าไหร่ก็เสียเวลาเปล่า → ไปฟันขวานเลย
    -- v2.7: Max=0 เป็นค่า "ชั่วคราว" (ก้อนยังโหลดไม่เสร็จ/คนอื่นขุดอยู่) — รอ 1.5 วิเช็คซ้ำก่อน
    -- (log: Apexarch Max=0 เสียเวลา 30 วิ แต่ 1 นาทีถัดมาก้อนเดียวกันกดเข้าใน 2.1 วิ)
    local pp0 = c:FindFirstChildOfClass("ProximityPrompt")
    if pp0 and pp0.MaxActivationDistance <= 0 then
        for _ = 1, 10 do
            task.wait(0.15)
            if pp0.MaxActivationDistance > 0 then break end
        end
    end
    if pp0 and pp0.MaxActivationDistance <= 0 then
        LG("  ⛏ ก้อนนี้ Max=0 (ปุ่มขึ้นไม่ได้) → ฟันขวานเลย")
        if mineIt(c, kg0) then return true end
        if collectDropped(cpos, kg0) then return true end
        LG("  ❌ ฟันไม่แตก")
        return false
    end
    local list = posList(c)
    -- 1) มุมที่เคยเข้า ลองก่อน (เร็ว)
    if WIN_POS then
        for _, e in ipairs(list) do
            if e[1] == WIN_POS then
                status("⛏ " .. WIN_POS)
                if attempt(c, kg0, e[1], e[2]) then return true end
                break
            end
        end
    end
    -- 2) วนหามุมที่ "ปุ่มติด" (8 มุมรอบก้อน + ต่ำ/สูง) — ติดแล้วกด ไม่ติดวาปต่อ
    for _, e in ipairs(list) do
        if not _G.AF75_RUN then return false end
        if os.clock() > TRY_DEADLINE then    -- v3.3: หมดเวลา — ทิ้งก้อนนี้ ไปก้อนถัดไปเลย
            LG(("  ⏭ เกิน %d วิ ยังไม่เข้า → ข้ามก้อนนี้"):format(MAX_SECS))
            return false
        end
        if not c.Parent then
            task.wait(0.5)
            if picked(kg0) then return true end
            return collectDropped(cpos, kg0)   -- v2.2: ก้อนแตกแล้วของตกพื้น → ตามเก็บ
        end
        if e[1] ~= WIN_POS then
            status("🔎 " .. e[1])
            if attempt(c, kg0, e[1], e[2]) then return true end
        end
    end
    -- v2.0: กด prompt ไม่เข้า → ลองฟันขวาน (ก้อนเล็กแพงๆ ต้องขุด ไม่ใช่หยิบ)
    LG(("  ⚠ วนครบ %d มุมไม่เข้า → ลองฟันขวาน"):format(#list))
    if c.Parent and mineIt(c, kg0) then return true end
    -- v2.2: ขุดแตกแล้วของร่วง (ลงถ้ำ) → ตามเก็บก้อนที่ตกแถวนั้น
    if collectDropped(cpos, kg0) then return true end
    LG(("  ❌ ไม่เข้า (ก้อนหาย=%s)"):format(tostring(c.Parent == nil)))
    return false
end

-- ==================== Main farm loop ====================
local function farmLoop()
    while _G.AF75_RUN do
        local cur, cap = bagInfo()
        updStat()
        if cur / cap >= SELL_PCT then
            -- ─── ไปขาย ───
            local sp, spos = findSellPrompt()
            if not sp then
                status("❌ หา prompt ขาย (SellProx) ไม่เจอ — หยุด")
                break
            end
            LG(("💰 กระเป๋า %.1f/%.0f (%.0f%%) → ไปขาย"):format(cur, cap, cur / cap * 100))
            status("💰 วาปไปร้าน...")
            setNoFall(true)
            -- v1.7: ยืน "ระดับเดียวกับ NPC" (บทเรียนเดียวกับตอนขุด — ลอยเหนือหลังคาปุ่มไม่ติด)
            -- วน 8 มุมจนปุ่ม E ร้านติด → กด E เปิดเมนู → ค่อยกดตัวเลือก 1
            local opened = false
            for _, dd in ipairs({ { 0, -1 }, { 0.7, -0.7 }, { 1, 0 }, { 0.7, 0.7 },
                { 0, 1 }, { -0.7, 0.7 }, { -1, 0 }, { -0.7, -0.7 } }) do
                if not _G.AF75_RUN then break end
                TARGET_POS = spos + Vector3.new(dd[1] * 5, 0, dd[2] * 5)
                for _ = 1, 5 do
                    task.wait(0.15)
                    if sp and PROMPT_ON == sp then opened = true break end
                end
                if opened then
                    LG("  🚪 ปุ่ม E ร้านติด — กดเปิดเมนู")
                    pcall(function() sp:InputHoldBegin() end)
                    task.wait(math.max(sp.HoldDuration, 0.1) + 0.35)
                    pcall(function() sp:InputHoldEnd() end)
                    local fpz = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
                    if fpz then pcall(fpz, sp, 1) end   -- เผื่อ InputHold ไม่ติด
                    task.wait(0.7)
                    break
                end
            end
            if not opened then
                LG("  ⚠ ปุ่ม E ร้านไม่ติดสักมุม (prompt=" .. tostring(sp ~= nil) .. ")")
                TARGET_POS = spos + Vector3.new(0, 0, -5)
                task.wait(0.8)
            end
            local before = cur
            local sold = false
            -- v1.1 (SellSpy): ขาย = กดตัวเลือก 1 ในเมนู GUI 'dialog' ("Sell all crystals")
            -- ด้วย firesignal (ยิง SellRequest เปล่าๆ server ไม่รับ ต้องเลือกในเมนูจริง)
            for vi = 1, 5 do
                if not _G.AF75_RUN then break end
                status(("💰 กดขาย ครั้งที่ %d/5..."):format(vi))
                local pg = LP:FindFirstChild("PlayerGui")
                local hasMenu = pg and pg:FindFirstChild("dialog", true) ~= nil
                pressSellMenu()
                task.wait(1.5)
                local c2 = bagInfo()
                LG(("  ขายครั้ง %d: เมนูเปิด=%s | %.1f → %.1f kg"):format(
                    vi, tostring(hasMenu), before, c2))
                if c2 < before - 1 then sold = true break end
            end
            unpin()
            if sold then
                statSell += 1
                LG("  ✅ ขายสำเร็จ! เงินรวม " .. fmtMoney(cashNow()))
                status("✅ ขายสำเร็จ! ฟาร์มต่อ")
            else
                status("❌ ขายไม่เข้า — เมนูอาจไม่เปิด (ลองเดินเข้าใกล้ NPC อีกนิด)")
                _G.AF75_RUN = false
                break
            end
        else
            -- ─── ขุด ───
            local c = bestCrystal(cap - cur)
            if not c then
                status(("🔍 ไม่เจอก้อน (T≥%d, %d-%dkg หรือ ≥%s) — รอ spawn..."):format(
                    MIN_TIER, KG_MIN, KG_MAX, VAL_MIN > 0 and fmtMoney(VAL_MIN) or "-"))
                task.wait(2)
            else
                local nm = c:GetAttribute("CrystalName") or "?"
                local v = c:GetAttribute("Value") or 0
                local kg0 = cur   -- น้ำหนักก่อนเก็บ — ใช้ยืนยันว่าของเข้ากระเป๋าจริง
                local myp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local ppx = c:FindFirstChildOfClass("ProximityPrompt")
                LG(("🎯 %s %s %.1fkg | ห่าง %dm | %s Max=%d | กระเป๋า %.1f"):format(
                    nm, fmtMoney(v), c:GetAttribute("WeightKg") or 0,
                    myp and math.floor((c.Position - myp.Position).Magnitude) or -1,
                    ppx and ppx.ActionText or "?", ppx and ppx.MaxActivationDistance or -1, kg0))
                status(("⛏ ไปหา %s %s"):format(nm, fmtMoney(v)))
                setNoFall(true)
                local dest = c.Position + Vector3.new(0, 6, 0)
                TARGET_POS = dest
                -- v1.2: รอ "ถึงจริง" ก่อนยิง (เช็คระยะ) — ไม่ใช่หลับตารอเวลาคงที่
                -- v2.4: วาปไม่ถึงบ่อย (ห่างเป้า 28!) → ตอกตำแหน่งซ้ำทุกรอบ + รอนานขึ้น
                local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local tA = os.clock()
                while _G.AF75_RUN and os.clock() - tA < 5 do
                    r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if not r then break end
                    if (r.Position - dest).Magnitude <= 5 then break end
                    TARGET_POS = dest    -- ตอกซ้ำ เผื่อโดนสคริปต์อื่น/เกมดึงกลับ
                    task.wait(0.1)
                end
                local off = r and (r.Position - dest).Magnitude or -1
                if off > 5 then
                    LG(("  ⚠ วาปไม่ถึง! ห่าง %.0f — ปิดปุ่ม 'บิน' ใน ItemESP ด้วย (แย่งตำแหน่งกัน)"):format(off))
                end
                LG(("  ✈ ถึงแล้วใน %.2f วิ (ห่างเป้า %.1f)"):format(os.clock() - tA,
                    r and (r.Position - dest).Magnitude or -1))
                task.wait(0.35)   -- ให้ตำแหน่งใหม่ replicate ถึง server
                status(("⛏ ขุด %s %s"):format(nm, fmtMoney(v)))
                if closeBlockPopup() then LG("  🪟 ปิดป๊อปอัปที่บังจอ") end
                -- v3.4: มีกองของตก (จากระเบิด) อยู่ใกล้ๆ → กวาดก่อน คุ้มกว่าไปหาก้อนไกลๆ
                local myp2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if myp2 then
                    local pile, pileCount = nil, 0
                    for _, d in ipairs(workspace:GetDescendants()) do
                        if d:IsA("BasePart") and d:GetAttribute("CrystalName")
                            and (d:FindFirstAncestor("DroppedCrystals") or d:GetAttribute("DroppedByUserId"))
                            and (d.Position - myp2.Position).Magnitude < 250 then
                            pileCount += 1
                            pile = pile or d.Position
                        end
                    end
                    -- v3.5: กวาดเฉพาะกองที่ "อยู่ใกล้จริง" (≤80) และเว้นระยะ 20 วิ/ครั้ง
                    -- (v3.4 กวาดทุกกองในรัศมี 250 ทุกรอบ = ยิง remote รัวจน server เมิน)
                    if pileCount >= 3 and pile and (pile - myp2.Position).Magnitude <= 80
                        and os.clock() > (LAST_SWEEP + 20) then
                        LAST_SWEEP = os.clock()
                        LG(("  💣 กองของตก %d ชิ้นใกล้ๆ — กวาดก่อน"):format(pileCount))
                        markBase()
                        collectDropped(pile, bagInfo())
                    end
                end
                local got = tryPick(c, kg0)
                if got then
                    statPick += 1
                    statVal += v
                    -- v2.3: สรุปเวลาที่เสียไปแต่ละขั้น (สปายในตัว — ช้าตรงไหนเห็นเลย)
                    LG(("  ⏱ รวม %.1f วิ | หามุม %.1f | กดค้าง %.1f | ขวาน %.1f"):format(
                        os.clock() - tA, TM.scan or 0, TM.hold or 0, TM.mine or 0))
                    TM = {}
                    task.wait(0.25)   -- ค้างอีกนิด ให้ FX/ของเข้าครบก่อนวาปหนี
                else
                    FAILED[c] = os.clock() + 30
                    status("❌ " .. nm .. " เก็บไม่เข้า — ข้าม 30 วิ")
                end
                updStat()
            end
        end
        task.wait(0.2)
    end
    unpin()
    runB.Text = "▶ เริ่มฟาร์ม"
    runB.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
end

runB.MouseButton1Click:Connect(function()
    _G.AF75_RUN = not _G.AF75_RUN
    if _G.AF75_RUN then
        runB.Text = "⏸ หยุดฟาร์ม"
        runB.BackgroundColor3 = Color3.fromRGB(150, 60, 30)
        task.spawn(farmLoop)
    else
        status("หยุดแล้ว")
    end
end)

local folded = false
foldB.MouseButton1Click:Connect(function()
    folded = not folded
    panel.Size = UDim2.new(0, 210, 0, folded and MIN_H or FULL_H)
end)
closeB.MouseButton1Click:Connect(function()
    _G.AF75_RUN = false
    unpin()
    for _, c in pairs(_G.AF75_CONNS) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.AF75_GUI, _G.AF75_CONNS = nil, {}
end)

if not pickR then status("⚠️ ไม่เจอ remote เก็บ CrystalHoldComplete!") end
if not FS then status("⚠️ executor ไม่มี firesignal — ขายอัตโนมัติไม่ได้ (ต้องขายมือ)") end
print("[75RB AutoFarm v" .. V .. "] พร้อม | เก็บ=CrystalHoldComplete | ขาย=กดเมนู dialog ตัวเลือก 1")
