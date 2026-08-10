-- 78RB_DuckAim.lua v7.4 — ยิงตามจำนวนที่ตั้งเป๊ะ ไม่เช็คตาย (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v7.4 (แบบ C): เลิกเช็คตายทั้งหมด — เป็ดปกติยิงครบ MAX_SHOTS นัดตามที่ตั้งแล้วไปตัวถัดไปเลย (ผู้ใช้
--   จูนเอง: ไม่ตายก็เพิ่มนัด/อัปปืน) บอสยังยิงไม่จำกัดจนหายไป
-- 78RB_DuckAim.lua v7.3 — แก้ยิงถี่ผิดปกติ (ลูปซ้อน) (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v7.3: ตั้งหน่วงยิง 2 วิ แต่ยังรัว — เพราะกดเปิด/ปิด/เปิด AUTO SHOOT สะสมหลายลูปยิงพร้อมกัน (ตัวเก่า
--   ค้างใน task.wait พอเปิดใหม่วิ่งต่อ) → ใส่ _G.DA78_SHOOTID ให้เหลือลูปยิงตัวเดียวเสมอ ตัวเก่าตายทันที
-- 78RB_DuckAim.lua v7.2 — ตั้งความถี่ + จำนวนนัดต่อตัวเองได้ (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v7.2: เช็คตายช้า → เลิกรอเช็คตาย เปลี่ยนเป็นยิงครบ "จำนวนนัดต่อตัว" ที่ตั้ง แล้วไปตัวถัดไปเลย
--   + ช่องพิมพ์ 2 ช่อง: หน่วงยิง (วิ/นัด) และ ยิงต่อตัว (นัด) — บอสยกเว้น ยิงไม่จำกัดจนตาย
-- 78RB_DuckAim.lua v7.1 — ตั้งความถี่ยิงเองได้ (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- 78RB_DuckAim.lua v7.0 — flow ตามผู้ใช้: เล็งใกล้→ยิง→เช็คตาย→ซ้ำ→ตัวถัดไป (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v7.0: บั๊ก "เล็งใกล้แต่ไม่ยิง" = รอกล้องหมุนเข้า <4° แต่เป็ดขยับ กล้องตามไม่ทัน → เลิกรอกล้อง ยิง dir
--   ไปที่ตัวเป้าตรงๆ (log พิสูจน์เซิร์ฟเวอร์ไม่เช็คกล้อง) ยิงได้ทันที + flow: เลือกใกล้สุด→ยิง 1→รอเช็ค
--   ตาย(target.Parent หาย)→ไม่ตายยิงซ้ำ→ตาย/เกิน MAX 40→หาตัวถัดไป (บอสยิงไม่จำกัดจนตาย)
-- 78RB_DuckAim.lua v6.9 — ไม่ค้างจ้องตัวยาก เก็บฝูงต่อ (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.9: v6.7 เหนียวเกิน — ล็อคเป้าไกล/ยิงยากแล้วค้างรอกล้อง ไม่ยิงตัวอื่นทั้งที่ฝูงบินผ่าน → ถ้าเล็ง
--   ไม่เข้าใน 0.8 วิ ทิ้งไปตัวใกล้/ง่ายกว่า (บอสยังให้เวลาเต็มที่ ล็อคจนตาย)
-- 78RB_DuckAim.lua v6.8 — เจอบอสจริง BossController_Client (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.8: Spy (สแกนโมเดลที่ขยับ) เจอบอสชื่อ "BossController_Client_N" ใน Ume (ตัวใหญ่ 75x50x50) →
--   findBoss หาชื่อนี้ตรงตัว (เลิกเดา Shrek/HP-bar) เล็ง+รัวจนตาย
-- 78RB_DuckAim.lua v6.7 — ล็อคยิงจนตาย + จับบอส Shrek (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.7: เป็ดด่านหลัง+บอสทนหลายนัด (Spy: บอส="Shrek" ใน workspace, ป้าย HP อยู่ PlayerGui) → เลิก
--   "ยิงนัดเดียวข้าม" เปลี่ยนเป็นล็อคตัวเดิมรัวจนหายไป(ตาย)แล้วค่อยเปลี่ยน (กันติดตายด้วย MAX_SHOTS
--   30 นัด) + findBoss เล็ง Shrek ตอนบอสแอ็กทีฟ (มี BossHealthBar_1)
-- 78RB_DuckAim.lua v6.6 — เก็บเป็ดหลุดผ่านให้มากขึ้น (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.6: เป็ดบินผ่านไม่โดนบางตัว เพราะ findBoss สแกน GetDescendants ทุกเฟรม (เป็ด 70+) หน่วงจนเล็งไม่ทัน
--   → throttle บอสทุก 0.5 วิ + cache + ลด SHOT_SKIP 1.0→0.4 (ตัวใหม่ถูกเล็งไวขึ้น)
-- 78RB_DuckAim.lua v6.5 — บอสหาจากป้าย HP + ยิงรัวต่อเนื่อง (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.5: (1) log พิสูจน์ยิง remote 0.18 วิต่อเนื่องฆ่าจริง (แม็ก/รีโหลดเป็นลิมิต client เท่านั้น) → ตัด
--   หน่วงรีโหลด v6.4 ทิ้ง ยิงรัว 0.2 วิ (2) บอสไม่มี Humanoid → หาจากป้าย "<เลข> HP" แล้วเอา Model บอส
-- 78RB_DuckAim.lua v6.4 — ยิงตามจังหวะจริงของปืน (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.4: เมนูอัปเกรดเผยปืนมีลิมิตจริง — แม็ก 2 นัด รีโหลด 1.5 วิ ยิงเร็วกว่านี้กระสุนไม่ออก (เซิร์ฟเวอร์
--   ทิ้งนัดเกิน) → เลิกยิงรัว 0.18 เปลี่ยนเป็น 2 นัดรวด(0.25) แล้วรอรีโหลด 1.6 วิ (ค่าฐาน — ยังไม่อ่าน
--   ค่าอัปเกรดจริง รอ spy)
-- 78RB_DuckAim.lua v6.3 — เล็งบอส + ยิงค้างจนตาย (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.3: บอส (เช่น "Silly Duck 150 HP") ไม่ถูกเล็ง เพราะชื่อไม่มี "Duck" — เป็ดปกติไม่มี Humanoid แต่
--   บอสมี HP bar = มี Humanoid → findBoss หา Model ที่มี Humanoid.Health>0 (ใน Ume+workspace) เล็ง
--   ก่อนเสมอ + ยิงค้างไม่ mark จนกว่าจะตาย (เป็ดปกติยังยิงนัดเดียวแล้วข้ามเหมือนเดิม)
-- 78RB_DuckAim.lua v6.2 — แก้ช้าเพราะรอนานเกิน (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.2: ช้าลงเพราะ SHOT_SKIP 6 วิ — ยิงเร็ว 3 วิครบทุกตัว แล้วนั่งรอ 6 วิ ("ไม่เจอเป้า") → ลดเหลือ
--   1 วิ (ตัวที่โดนจริงกลายเป็น Landed/หายเอง เหลือแต่ตัวพลาดที่ควรยิงใหม่ไวๆ)
-- 78RB_DuckAim.lua v6.1 — เล็งแม่น + ไม่ยิงศพ (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.1: (1) เล็งไม่แม่น → ดูดกล้องไวขึ้น SMOOTH 0.35→0.6 + ยิงเฉพาะตอนเข้าเป้า <4° (เดิม 10°)
--   (2)(3) ยิงศพ → เป็ดที่ตกกลายเป็น DuckController_LandedDucks ในโฟลเดอร์เดียวกัน กรองออก เอา
--   เฉพาะชื่อมี "Duck" และไม่มี "Landed" (เป็ดบินที่ยังไม่ตาย)
-- 78RB_DuckAim.lua v6.0 — 1 ตัวยิงนัดเดียว ไม่ถล่มตัวเดิม (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v6.0: เดิมจ่อยิงตัวเดิม 7 นัด (SHOT_SKIP 2 วิสั้นไป + fallback ไปตัวที่ยิงแล้ว) → ยิดตัวละนัดเดียว
--   ข้ามยาว 6 วิ (ล้างเมื่อตาย) + เลิก fallback ไปตัวที่ยิงแล้ว = ประหยัดกระสุน ฆ่าได้หลายตัวกว่า
-- 78RB_DuckAim.lua v5.9 — เก็บปืนใน _G ทุก gen + ข้ามเป็ดที่ยิงแล้ว (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.9: โหลดซ้ำแล้ว executor ไม่ยอม hook __namecall ซ้ำ → hook เก่า (gen เก่า) เป็นตัว active แต่เดิม
--   เช็ค gen เลยข้ามการจับปืนทิ้ง = จับปืนไม่ได้เลย → เก็บ remote ใน _G ไม่เช็ค gen ตอนจับ ทุก gen
--   เขียน/อ่านร่วมกัน + เพิ่ม markShot ข้ามเป็ดที่เพิ่งยิง 2 วิ (ไม่เล็งซ้ำ)
-- 78RB_DuckAim.lua v5.7 — สถานะปืนแยกบรรทัด (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.7: AIM เขียนทับ status ทุกเฟรมจนมองไม่เห็นสถานะเรียนปืน → เพิ่มบรรทัด gunLbl แยก โชว์
--   hook OK/ไม่ติด + เล็ง✓/✗ ยิง✓/✗ + นัดล่าสุด (AIM แตะไม่ได้) + ปุ่มบอกให้แตะบนมือถือ
-- 78RB_DuckAim.lua v5.5 — รายงานผลติดตั้ง hook + ตัด reload มั่ว (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.5: DuckSpy พบว่าไม่มี remote รีโหลด (รีโหลด=อนิเมชั่นฝั่งจอ) → ตัดโค้ดจับ/ยิงรีโหลดออก ยิง 2
--   remote รัวๆ พอ + pcall เดิมกลืน error ตอนติดตั้ง hook เงียบ ทำให้จับปืนไม่ได้แบบไม่รู้สาเหตุ →
--   เปลี่ยนเป็นรายงานสถานะ hook ชัดๆ (✅ พร้อม / ❌ ไม่ติด+เหตุผล) ตอนโหลด
-- 78RB_DuckAim.lua v5.4 — debug โชว์ remote ที่เห็น (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.4: ยิงเองแล้วยังจับปืนไม่ได้ → ตอนยังเรียนไม่ครบ โชว์ทุก FireServer ที่ hook เห็น (ชื่อ+จำนวน+
--   ชนิด args) บน status เพื่อดูว่าลายเซ็นจริงเป็นแบบไหน (เผื่อเกมเปลี่ยน/hook ไม่เห็น)
-- 78RB_DuckAim.lua v5.3 — รีโหลดทันที ยิงรัวไม่สะดุด (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.3: ปืนแม็กน้อย/รีโหลดหลังยิงเลยช้า → แอบเรียน remote รีโหลด (remote ที่เกมยิงเองภายใน 2 วิ
--   หลังยิง ไม่ใช่ aim/fire) แล้วยิงรีโหลดทันทีหลังทุกนัด ข้ามอนิเมชั่น + ลด FIRE_INTERVAL 0.5→0.18
-- 78RB_DuckAim.lua v5.2 — แก้ compile error "..." (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- v5.2: บั๊กตั้งแต่ v5.0 ทำ GUI ไม่ขึ้นเลย — เอา table.pack(...) ไปไว้ใน pcall(function()...) ซึ่งเป็น
--   ฟังก์ชันซ้อนไม่มี vararg → "Cannot use '...' outside of a vararg function" → ย้าย table.pack(...)
--   มาชั้นนอก แล้วให้ closure ของ pcall ใช้ตัวแปร a ที่ capture ไว้แทน
-- v5.0: DuckSpy พิสูจน์ว่า 1 นัด = 2 remote — A(origin,dir,counter,ts) + B(counter) counter เดินหน้า
--   ทุกนัด (4,5,6,...) v4.0 ยิง remote เดียว+เลขคงที่เลยไม่ติด → เรียนทั้ง 2 remote, counter เดินหน้า
-- v5.1: log ยืนยัน origin ขยับตามตัวผู้เล่นตอนเดิน (831→832→814...) → ใช้ตำแหน่งกล้องปัจจุบันเป็น origin
-- v4.0: เพิ่ม AUTO SHOOT (คีย์ K) — เรียนปืนแบบ "แอบดูไม่แก้ไข": hook __namecall อ่าน args ตอนผู้เล่น
--   ยิงเองจริง 1 นัด เพื่อจำ remote + รูปแบบคำสั่ง (ไม่แก้ค่า ไม่พังการรีโหลดแบบ SILENT เดิม) แล้วยิง
--   ซ้ำเองใส่เป็ดตามโหมด TARGET ทุก 0.12 วิ (อัปเดต timestamp ด้วย GetServerTimeNow กันโดนปฏิเสธ)
-- v3.1: TARGET เพิ่มโหมดที่ 4 เลือดเยอะสุด — อ่าน Humanoid.Health ก่อน ไม่มีค่อยหา attribute/Value
--   ชื่อพ้อง hp/health บนโมเดลเป็ด (บอสเลือดหนา = โดนล็อคก่อน)
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
local SMOOTH = 0.6 -- v6.1: ดูดกล้องไวขึ้น (0.35→0.6) ให้เข้าเป้าเร็ว เล็งแม่นขึ้น
-- v5.9: สถานะปืนเก็บใน _G (hook เขียน — ใช้ร่วมทุก gen กันโหลดซ้ำแล้ว hook เก่าจับไม่ได้)
_G.DA78_CTR = _G.DA78_CTR or 0

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

-- v5.7: บรรทัดสถานะปืนแยกต่างหาก — AIM เขียนทับ status ทุกเฟรมจนมองไม่เห็นสถานะเรียนปืน
local gunLbl = Instance.new("TextLabel", frame)
gunLbl.Size = UDim2.new(1, -8, 0, 16); gunLbl.Position = UDim2.new(0, 4, 0, 40)
gunLbl.BackgroundTransparency = 1; gunLbl.TextColor3 = Color3.fromRGB(140, 255, 140)
gunLbl.TextSize = 11; gunLbl.Font = Enum.Font.Code
gunLbl.TextXAlignment = Enum.TextXAlignment.Left
gunLbl.Text = "ปืน: ยังไม่รู้ — ยิงเอง 1 นัด"
-- อ่านสถานะปืนจาก _G (hook เขียนไว้ — ใช้ร่วมทุก gen)
local function setGun()
    gunLbl.Text = ("ปืน: เล็ง%s ยิง%s  นัดล่าสุด %d"):format(
        _G.DA78_AIM and "✓" or "✗", _G.DA78_FIRE and "✓" or "✗", _G.DA78_CTR or 0)
end

local function mkbtn(txt, y, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, -8, 0, 26); b.Position = UDim2.new(0, 4, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local aimB    = mkbtn("AIM: OFF (คีย์ลัด L)", 60, Color3.fromRGB(190, 60, 60))
local shootB  = mkbtn("AUTO SHOOT: OFF (แตะปุ่มนี้ / คีย์ K)", 90, Color3.fromRGB(60, 170, 90))
local targetB = mkbtn("TARGET: ไม่มีอะไรบัง", 120, Color3.fromRGB(60, 110, 180))

-- v7.1: ช่องพิมพ์ความถี่ยิงเอง (วินาที/นัด) — เลขมาก = ยิงช้าลง
local rateLbl = Instance.new("TextLabel", frame)
rateLbl.Size = UDim2.new(0, 150, 0, 26); rateLbl.Position = UDim2.new(0, 4, 0, 150)
rateLbl.BackgroundTransparency = 1; rateLbl.TextColor3 = Color3.new(1, 1, 1)
rateLbl.Font = Enum.Font.GothamBold; rateLbl.TextSize = 12
rateLbl.TextXAlignment = Enum.TextXAlignment.Left
rateLbl.Text = "หน่วงยิง (วิ/นัด):"
local rateBox = Instance.new("TextBox", frame)
rateBox.Size = UDim2.new(0, 88, 0, 26); rateBox.Position = UDim2.new(0, 154, 0, 150)
rateBox.BackgroundColor3 = Color3.fromRGB(40, 40, 60); rateBox.TextColor3 = Color3.new(1, 1, 1)
rateBox.Font = Enum.Font.Code; rateBox.TextSize = 14; rateBox.ClearTextOnFocus = false
rateBox.Text = tostring(FIRE_RATE)
rateBox.FocusLost:Connect(function()
    local v = tonumber(rateBox.Text)
    if v and v > 0 then
        FIRE_RATE = math.clamp(v, 0.05, 5)
        rateBox.Text = tostring(FIRE_RATE)
        setStatus(("[DuckAim78] ตั้งหน่วงยิง %.2f วิ/นัด"):format(FIRE_RATE))
    else
        rateBox.Text = tostring(FIRE_RATE) -- ใส่ผิด คืนค่าเดิม
    end
end)

-- v7.2: ช่องพิมพ์ "ยิงต่อตัว (กี่นัด)" — เป็ดปกติ ยิงครบเท่านี้แล้วไปตัวถัดไป (บอสยิงไม่จำกัด)
local maxLbl = Instance.new("TextLabel", frame)
maxLbl.Size = UDim2.new(0, 150, 0, 26); maxLbl.Position = UDim2.new(0, 4, 0, 180)
maxLbl.BackgroundTransparency = 1; maxLbl.TextColor3 = Color3.new(1, 1, 1)
maxLbl.Font = Enum.Font.GothamBold; maxLbl.TextSize = 12
maxLbl.TextXAlignment = Enum.TextXAlignment.Left
maxLbl.Text = "ยิงต่อตัว (นัด):"
local maxBox = Instance.new("TextBox", frame)
maxBox.Size = UDim2.new(0, 88, 0, 26); maxBox.Position = UDim2.new(0, 154, 0, 180)
maxBox.BackgroundColor3 = Color3.fromRGB(40, 40, 60); maxBox.TextColor3 = Color3.new(1, 1, 1)
maxBox.Font = Enum.Font.Code; maxBox.TextSize = 14; maxBox.ClearTextOnFocus = false
maxBox.Text = tostring(MAX_SHOTS)
maxBox.FocusLost:Connect(function()
    local v = tonumber(maxBox.Text)
    if v and v >= 1 then
        MAX_SHOTS = math.floor(math.clamp(v, 1, 200))
        maxBox.Text = tostring(MAX_SHOTS)
        setStatus(("[DuckAim78] ตั้งยิงต่อตัว %d นัด (บอสไม่จำกัด)"):format(MAX_SHOTS))
    else
        maxBox.Text = tostring(MAX_SHOTS)
    end
end)

local stopB   = mkbtn("STOP", 210, Color3.fromRGB(150, 60, 30))
local closeB  = mkbtn("✕ ปิด", 240, Color3.fromRGB(90, 40, 40))
frame.Size = UDim2.new(0, 250, 0, 274)

setStatus("[DuckAim78] พร้อม — ยิงเอง 1 นัดให้จำปืน แล้วกด K ยิงออโต้")

-- ==================== หาเป็ด ====================
local function duckFolder()
    return workspace:FindFirstChild("Ume")
end

local function duckPos(m)
    local p = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end

-- v6.0: จำเป็ดที่ "ยิงไปแล้ว" — 1 ตัวยิงนัดเดียวพอ ข้ามยาว (ให้ตาย/ร่วง) ถ้ายังอยู่เกิน SHOT_SKIP
-- ค่อยกลับมายิงซ้ำ (เผื่อยิงพลาดจริง) — ตั้งไว้นานพอไม่ให้ถล่มตัวเดิมรัวๆ เปลืองกระสุน
local shotDucks = {}          -- model -> os.clock() ตอนยิง
-- v6.2: SHOT_SKIP 6 วินานไป — ยิงเร็ว 3 วิก็ครบทุกตัว แล้วนั่งรอ 6 วิ ดูเหมือนช้า ตัวที่โดนจริงจะ
-- กลายเป็น Landed/หายเอง (recentlyShot ล้างให้) เหลือแต่ตัวพลาด → รอแค่ 1 วิพอ พลาดแล้วยิงใหม่ไว
local SHOT_SKIP = 0.4 -- v6.6: ลด 1.0→0.4 ให้ตัวใหม่ที่บินเข้ามาถูกเล็งไวขึ้น เป็ดหลุดผ่านน้อยลง
local function markShot(model) if model then shotDucks[model] = os.clock() end end
local function recentlyShot(model)
    if not model.Parent then shotDucks[model] = nil return false end -- ตายไปแล้ว ล้างทิ้ง
    local t = shotDucks[model]
    return t ~= nil and (os.clock() - t) < SHOT_SKIP
end

-- v6.1: เป้าต้องเป็น "เป็ดบินที่ยังไม่ตาย" เท่านั้น — เป็ดที่ยิงตกกลายเป็น DuckController_LandedDucks
-- (ศพร่วงพื้น) อยู่ในโฟลเดอร์ Ume เดียวกัน เดิมเลยเล็งศพด้วย → เอาเฉพาะชื่อมี "Duck" และไม่มี "Landed"
local function isLiveDuck(m)
    local n = m.Name
    return n:find("Duck") ~= nil and not n:find("Landed")
end

-- v6.6: บอสมีป้าย HP bar ("<เลข> HP") — แต่สแกน GetDescendants ทุกเฟรมหนักมาก (เป็ด 70+ ตัว) ทำให้
-- หน่วงจนเล็งเป็ดบินผ่านไม่ทัน → throttle สแกนทุก 0.5 วิ แล้ว cache ผลไว้
local bossCache, bossCacheAt = nil, 0
local function findBoss()
    if os.clock() - bossCacheAt < 0.5 then
        if bossCache and bossCache.model.Parent then return bossCache end
        if not bossCache then return nil end
    end
    bossCacheAt = os.clock()
    bossCache = nil
    -- Spy ยืนยัน: บอสชื่อ "BossController_Client_N" อยู่ในโฟลเดอร์ Ume (ตัวใหญ่ 75x50x50)
    local f = duckFolder()
    if not f then return nil end
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and m.Name:find("BossController") then
            local p = duckPos(m)
            if p then bossCache = { model = m, pos = p, boss = true }; return bossCache end
        end
    end
    return nil
end

local function allDucks(includeShot)
    local out = {}
    local f = duckFolder()
    if not f then return out end
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and isLiveDuck(m) and (includeShot or not recentlyShot(m)) then
            local p = duckPos(m)
            if p then out[#out + 1] = { model = m, pos = p } end
        end
    end
    return out
end

-- ==================== เกณฑ์เลือกเป้า: ใกล้สุด / ไม่มีอะไรบัง / คะแนนเยอะสุด ====================
local TARGET_MODES = { "ใกล้สุด", "ไม่มีอะไรบัง", "คะแนนเยอะสุด", "เลือดเยอะสุด" }
local targetModeIdx = 2

-- v3.1: อ่าน HP ของเป็ด — Humanoid.Health ก่อน แล้วค่อย attribute/Value ชื่อพ้อง hp/health/เลือด
local function duckHP(d)
    local hum = d.model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health end
    for k, v in pairs(d.model:GetAttributes()) do
        if type(v) == "number" and k:lower():find("h[pe]") then return v end
    end
    for _, c in ipairs(d.model:GetDescendants()) do
        if (c:IsA("IntValue") or c:IsA("NumberValue")) and c.Name:lower():find("h[pe]") then
            return c.Value
        end
    end
    return 0
end

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

-- v6.7: เป็ดด่านหลัง + บอส ทนหลายนัด (ผู้ใช้ยืนยัน) → เลิกแยกประเภท ใช้วิธี "ล็อคตัวเดิมยิงจนตาย"
-- (จัดการในลูปยิง) ที่นี่แค่เลือกเป้า: บอส (Shrek) มาก่อน แล้วเป็ดใกล้สุด
local function pickDuck(origin)
    local boss = findBoss()
    if boss then return boss end
    -- v6.0: เอาเฉพาะตัวที่ยังไม่ได้ยิง (ไม่ fallback ไปตัวที่ยิงแล้ว — กันถล่มตัวเดิมรัวๆ)
    -- เป็ดมีเยอะพอ มักมีตัวใหม่ให้ยิงเสมอ ถ้าไม่มีจริงๆ ก็รอแป๊บ (คืน nil)
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

    if mode == "เลือดเยอะสุด" then
        local best, bestHP = nil, -1
        for _, d in ipairs(ducks) do
            local hp = duckHP(d)
            if hp > bestHP then best, bestHP = d, hp end
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

-- ==================== AUTO SHOOT — เรียนปืนแบบ "แอบดูไม่แก้ไข" (ไม่พังการรีโหลด) ====================
-- ต่างจาก SILENT เดิม: hook นี้แค่ "อ่าน" args ตอนผู้เล่นยิงจริง เพื่อจำ remote + รูปแบบคำสั่ง
-- ไม่แก้ค่าใดๆ (return old(self, ...) เดิมทุกครั้ง) → คำสั่งรีโหลด/อื่นๆ ไม่ถูกแตะเลย
-- v5.0 จาก DuckSpy log: ยิง 1 นัด = 2 remote
--   A(aimRemote):  FireServer(Vector3 origin(คงที่ 780,68,104), Vector3 dir(ตามกล้อง), counter, timestamp)
--   B(fireRemote): FireServer(counter)   ← counter เดียวกัน เดินหน้าทุกนัด (4,5,6,...)
local SHOOT_ON = false
-- ปืนเก็บใน _G.DA78_AIM / _G.DA78_FIRE / _G.DA78_ORIGIN / _G.DA78_CTR (hook เขียน ทุก gen ใช้ร่วม)
local lastShotClock = 0
-- v6.5: log พิสูจน์ว่ายิง remote ตรง 0.18 วิ ต่อเนื่อง เซิร์ฟเวอร์รับ+ฆ่าจริง (แม็ก/รีโหลดเป็นลิมิต
-- ฝั่ง client ตอนกดยิงเอง เราข้ามได้) → ยิงรัวต่อเนื่อง ไม่ต้องหน่วงรีโหลด
-- v7.1: ปรับความถี่ยิงเองได้ (พิมพ์วินาที/นัดในช่อง RATE) — ผู้ใช้บอกยิงถี่ไป กระสุนออกทีละ 7 นัด
local FIRE_RATE = 0.4
-- v7.2: จำนวนนัดต่อเป็ด 1 ตัว (พิมพ์เองได้) — ยิงครบเท่านี้แล้วไปตัวถัดไปเลย (ไม่รอเช็คตายที่ช้า)
-- บอสยกเว้น ยิงไม่จำกัดจนหายไป
local MAX_SHOTS = 2

-- v5.5: รายงานผลติดตั้ง hook — เดิม pcall กลืน error เงียบ ทำให้ไม่รู้ว่า hook ไม่ติด (เลยจับปืนไม่ได้)
local hookOK, hookErr = pcall(function()
if not (hookmetamethod and getnamecallmethod) then
    error("executor ไม่มี hookmetamethod/getnamecallmethod")
end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        -- ดึง varargs ที่ชั้นนอก (vararg function) ก่อน — ห้ามใช้ ... ในฟังก์ชันซ้อนของ pcall
        local a = table.pack(...)
        local method = self
        pcall(function()
            -- v5.9: เก็บ remote ที่จับได้ไว้ใน _G (ใช้ร่วมทุก gen) และ "ไม่เช็ค gen" ตอนจับ — เพราะ
            -- โหลดซ้ำแล้ว executor ไม่ยอม hook __namecall ซ้ำ hook เก่า (gen เก่า) เลยเป็นตัวเดียวที่ active
            -- ถ้าเช็ค gen มันจะข้ามการจับทิ้ง → ปืนไม่เคยถูกจำ
            if getnamecallmethod() ~= "FireServer" then return end
            -- A: (Vector3, Vector3, number, number) = คำสั่งเล็ง
            if a.n >= 4 and typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3"
                and typeof(a[3]) == "number" and typeof(a[4]) == "number" then
                _G.DA78_AIM = method
                _G.DA78_ORIGIN = a[1]
                _G.DA78_CTR = math.max(_G.DA78_CTR or 0, a[3])
            -- B: (number เดียว) = คำสั่งยืนยันนัด
            elseif a.n == 1 and typeof(a[1]) == "number" then
                _G.DA78_FIRE = method
                _G.DA78_CTR = math.max(_G.DA78_CTR or 0, a[1])
            end
        end)
        return old(self, ...) -- ส่งต่อของเดิมเป๊ะ ไม่แตะอะไร
    end)
end)
if hookOK then
    setStatus("[DuckAim78] ✅ hook พร้อม — ยิงเอง 1 นัดให้จำปืน")
    gunLbl.Text = "ปืน: hook OK — ยิงเอง 1 นัด"
else
    setStatus("[DuckAim78] ❌ hook ไม่ติด")
    gunLbl.Text = "hook ไม่ติด: " .. tostring(hookErr)
end
-- รีเฟรชบรรทัดปืนจาก _G ตลอด (hook เขียน _G ไว้ — ทุก gen ใช้ร่วมกัน)
task.spawn(function()
    while _G.DA78_GEN == MY_GEN do
        if _G.DA78_AIM or _G.DA78_FIRE then pcall(setGun) end
        task.wait(0.3)
    end
end)

-- ยิง 1 นัดใส่ตำแหน่งเป้า — v7.0: ยิง dir ไปที่เป้าตรงๆ ไม่ต้องรอกล้องหมุนเข้า (log พิสูจน์เซิร์ฟเวอร์
-- ไม่เช็คว่ากล้องตรงเป๊ะ) → เล็งใกล้ยิงได้ทันที ไม่ค้าง
local function fireShotAt(targetPos)
    local aR, fR = _G.DA78_AIM, _G.DA78_FIRE
    if not (aR and fR) then return false end
    _G.DA78_CTR = (_G.DA78_CTR or 0) + 1
    local n = _G.DA78_CTR
    local origin = Camera.CFrame.Position
    local dir = targetPos and (targetPos - origin).Unit or Camera.CFrame.LookVector
    local ts = os.time()
    local ok, now = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and type(now) == "number" then ts = now end
    pcall(function() aR:FireServer(origin, dir, n, ts) end)
    pcall(function() fR:FireServer(n) end)
    lastShotClock = os.clock()
    return true
end

local function shootStop()
    SHOOT_ON = false -- ลูปเป็น task.spawn เช็คธงนี้แล้วจบเอง
    shootB.Text = "AUTO SHOOT: OFF (คีย์ K)"
end
local function shootStart()
    if not (_G.DA78_AIM and _G.DA78_FIRE) then
        setStatus(("[DuckAim78] ⚠️ ยังจับปืนไม่ครบ (เล็ง:%s ยิง:%s) — ยิงเองอีกนัด"):format(
            _G.DA78_AIM and "✓" or "✗", _G.DA78_FIRE and "✓" or "✗"))
        return
    end
    SHOOT_ON = true
    shootB.Text = "AUTO SHOOT: ON (กด K ปิด)"
    if not AIM_ON then aimStart() end -- ล็อคกล้องไว้ให้ดูสวย (ไม่ได้ใช้เป็นเงื่อนไขยิงแล้ว)
    -- v7.3: ตัวล็อกให้เหลือ "ลูปยิงตัวเดียว" เสมอ — เดิมกดเปิด/ปิด/เปิด สะสมหลายลูป ยิงถี่รวมกัน
    _G.DA78_SHOOTID = (_G.DA78_SHOOTID or 0) + 1
    local myLoop = _G.DA78_SHOOTID
    -- v7.4 (แบบ C): ยิงตามจำนวนนัดที่ตั้งเป๊ะๆ แล้วไปตัวถัดไปเลย — ไม่เช็คตายใดๆ (ผู้ใช้จูนเอง:
    -- ไม่ตายก็เพิ่มจำนวนนัด/อัปเกรดปืนเอง) บอสยกเว้น: ยิงไม่จำกัดจนหายไป (ตาย)
    task.spawn(function()
        while SHOOT_ON and _G.DA78_GEN == MY_GEN and _G.DA78_SHOOTID == myLoop do
            local d = pickDuck(Camera.CFrame.Position)
            local target = d and d.model
            if not target then task.wait(0.05)
            else
                local isBoss = target.Name:find("BossController") ~= nil
                local shots = 0
                -- เป็ดปกติ: ยิงครบ MAX_SHOTS นัด (ไม่สนว่าตายไหม) / บอส: ยิงจนหายไป
                while SHOOT_ON and _G.DA78_GEN == MY_GEN and _G.DA78_SHOOTID == myLoop
                    and (isBoss and target.Parent or (not isBoss and shots < MAX_SHOTS)) do
                    local p = duckPos(target)
                    if not p then break end
                    fireShotAt(p)
                    shots = shots + 1
                    setStatus(("[DuckAim78] 🔫 %s%s (%d/%s นัด, รวม %d)"):format(
                        isBoss and "บอส " or "", target.Name, shots,
                        isBoss and "∞" or tostring(MAX_SHOTS), _G.DA78_CTR or 0))
                    task.wait(FIRE_RATE)
                end
                -- ยิงครบโควตาแล้ว → กันเล็งตัวเดิมซ้ำทันที ไปตัวถัดไป
                if not isBoss then markShot(target) end
            end
        end
    end)
end
local function shootToggle()
    if SHOOT_ON then shootStop() else shootStart() end
end

-- คีย์ลัด L (AIM) / K (AUTO SHOOT)
table.insert(_G.DA78_CONNS, UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if _G.DA78_GEN ~= MY_GEN then return end
    if input.KeyCode == Enum.KeyCode.L then aimToggle()
    elseif input.KeyCode == Enum.KeyCode.K then shootToggle() end
end))

-- ==================== Buttons ====================
aimB.MouseButton1Click:Connect(aimToggle)
shootB.MouseButton1Click:Connect(shootToggle)
targetB.MouseButton1Click:Connect(function()
    targetModeIdx = targetModeIdx % #TARGET_MODES + 1
    targetB.Text = "TARGET: " .. TARGET_MODES[targetModeIdx]
end)
stopB.MouseButton1Click:Connect(function()
    aimStop()
    shootStop()
    setStatus("[DuckAim78] หยุดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    aimStop()
    shootStop()
    for _, c in ipairs(_G.DA78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DA78_CONNS = {}
    gui:Destroy(); _G.DA78_GUI = nil
end)

warn("[DuckAim78] v3.0 loaded")
