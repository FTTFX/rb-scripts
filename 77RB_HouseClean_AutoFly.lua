-- 77RB_HouseClean_AutoFly.lua v4.7 — บิน+จับ+วางของอัตโนมัติ (เกม "ล้างบ้านขำๆ")
-- v4.7: ยังหลุดฟ้าได้เพราะกรอบสูงจาก GetBoundingBox บ้านกว้างเกินจริง (มีชิ้นประดับลอยสูงปน)
--   → คำนวณกรอบจากตำแหน่งสล็อตวางของจริงทุกจุดแทน (min/max Y ของสล็อต -10/+20) แคบตรงตัวบ้านเป๊ะ
-- v4.6: "โดนของผลัก" กระเด็นขึ้นฟ้า — flyTo เคยปิด NoClip ทันทีที่ถึงเป้า ทั้งที่ตัวจมอยู่ในเฟอร์นิเจอร์
--   เปิดการชนตอนซ้อนกับของ = ฟิสิกส์ดีดออกแรงมาก → ระหว่าง AUTO ไม่ปิด NoClip เลย จบงาน/STOP
--   ค่อยวาร์ปขึ้นกลางอากาศเหนือหลังคา (ไม่ซ้อนกับอะไร) แล้วค่อยเปิดการชนคืน
-- v4.5: GUIDE ชี้ข้ามทะเลไปเกาะคนอื่น — เซิร์ฟเวอร์มีหลายบ้าน/เกาะ แต่โค้ดกวาดทุกบ้าน/หยิบตัวแรก
--   → เพิ่ม nearestHouseList() ล็อคเฉพาะบ้านที่ใกล้เราสุด ใช้กับ AUTO / ESP / GUIDE / homePos ทั้งหมด
-- v4.4: v4.3 ยังหลุดฟ้า+ไม่วาร์ปกลับ เพราะ homePos อิงตำแหน่งตัวเราตอนกด AUTO (กดตอนลอยบนฟ้า =
--   เพดานเพี้ยนทั้งระบบ) → ยึดกล่องขอบเขตตัวบ้านจริง (GetBoundingBox) แทน เพดาน/พื้น = ขอบบ้าน ±15
--   วาร์ปกลับ = กลางบ้านเสมอ ไม่อิงตัวเราอีกต่อไป
-- v4.3: ล็อคความสูงเด็ดขาด — เพดานจุดเริ่ม +60 / พื้นจุดเริ่ม -30 บังคับทุกเฟรม (Stepped)
--   หลุดเมื่อไหร่กดกลับทันที + เป้าบินทุกจุด (ของ/จุดวาง) ถูก clamp ความสูงก่อนบินเสมอ
-- v4.2: ยังตกแผนที่เป็นบางครั้ง — เพราะของบางชิ้นฟิสิกส์พาร่วง/ลอยหลุดนอกบ้าน แล้วสคริปต์บินตาม
--   → จำจุดเริ่ม (homePos) ไว้ ของที่อยู่ห่างเกิน 600 หรือสูง/ต่ำเกิน 120 จากจุดเริ่ม = หลุดโลก ไม่ไล่
--   และถ้าตัวเราเองหลุดโซน วาร์ปกลับ homePos อัตโนมัติก่อนทำชิ้นถัดไป
-- v4.1: v4.0 NoClip ตลอดทำให้ตอนยืนวางของไม่มีพื้นเหยียบ ร่วงทะลุตกแผนที่ → ระหว่าง AUTO
--   ล็อคความเร็วเป็นศูนย์ทุกเฟรม ตัวลอยนิ่งค้างที่เดิมแทนการร่วง (ขยับจริงด้วย CFrame อยู่แล้ว)
-- v4.0: ยกเครื่องลูป AUTO ใหม่หมดตามสูตรผู้ใช้ 5 ข้อ: จับของใกล้สุด → ดูไฮไลต์ → บินไป → วาง →
--   วนใหม่ทันที + NoClip เปิดตลอดเวลาที่ AUTO ทำงาน เช็คสำเร็จทางเดียว: ของย้ายมานั่งที่สล็อต
--   วางไม่เข้า = ข้ามชิ้นนั้นถาวร (กันวนตาย) เลิกนับรอบ/เลิกไล่สล็อตสำรอง/เลิกเช็คเงิน
-- v3.4: อาการ "จุดเต็ม x8" = จริงๆ วางสำเร็จตั้งแต่รอบแรก แต่เช็คสำเร็จด้วยเงินอย่างเดียว (ด่านหลังๆ
--   รางวัลไม่เข้า Cash แล้ว) เลยคิดว่าพลาด วนยัดจุดอื่นต่อ → เพิ่มเช็คทางกายภาพ: ของย้ายไปนั่งที่สล็อต
--   (< 6 stud) = ผ่าน + status โชว์ว่าแต่ละรอบใช้ "ตามไฮไลต์" หรือ "เดาชื่อ" ให้เห็นชัด
-- v3.3: บั๊กเด็ดขาดที่ทำให้ไม่ยอมไปจุดไฮไลต์ — เดิมรับเฉพาะไฮไลต์ที่ "เพิ่งติดใหม่หลังจับ" แต่ไฮไลต์
--   จุดวางมักติดค้างอยู่ก่อนจับแล้ว เลยมองไม่เห็น ตกไปเดา PairId ได้สล็อตเต็ม วนตาย → ตัดเงื่อนไข
--   "เพิ่งติด" ทิ้ง ใช้ "ติดอยู่ตอนนี้ + ชื่อตรง <ชื่อของ>HomeGhost" และถ้าเต็มไล่ลองสล็อตชื่อตรง
--   ทุกตัวในแผนที่ (เรียง PairId → RoomId → ที่เหลือ) จนกว่าเงินขึ้น = วางผ่านจริง
-- v3.2: เลิกวาป/พุ่ง (ตัวละครล้มตลอด) — AUTO กลับมาบินต่อเนื่อง speed 100 แบบเดิม + NoClip
--   ระหว่างบิน (ปิด CanCollide ทุกส่วนของตัวทุกเฟรม ทะลุกำแพงได้ ไม่ชนจนล้ม) ถึงแล้วเปิดชนคืน
-- v3.1: STOP ยังหยุดไม่สนิทเพราะ "สคริปต์รุ่นเก่าค้าง" — โหลดสคริปต์ใหม่ทับ ลูปเก่าที่ spawn ไปแล้ว
--   ยังวิ่งด้วยตัวแปรชุดเก่า ปุ่มใหม่ปิดไม่ถึง → ใส่เลขรุ่น _G.AF77_GEN ทุกลูป (AUTO/ESP/GUIDE/flyTo)
--   เช็คเลขรุ่นแล้วตายเองทันทีที่มีการโหลดใหม่ + ตอนโหลดตามลบ Highlight/Beam ชื่อ AF77_* ที่ค้างทิ้ง
-- v3.0: ปุ่ม STOP ใช้ไม่ได้จริง — เดิมแค่ตั้งธง แต่ไม่ปิด ESP/GUIDE และลูป AUTO ที่กำลังบิน/รอไฮไลต์
--   ไม่เช็คธงก่อนยิง remote เลยจับ-วางต่ออีกพัก → เพิ่มเช็ค AUTO_ON หลังบินถึงทุกจุดก่อนยิง remote
--   และ STOP ปิด ESP + GUIDE พร้อมรีเซ็ตข้อความปุ่มให้ครบ
-- v2.9: เจอวางผิดสล็อต ("this spot wants Bear Plush!") — เกมจุดไฮไลต์ได้หลายจุดพร้อมกัน การคว้า
--   "ตัวแรกที่เพิ่งติด" เลยได้สล็อตของชิ้นอื่นได้ → เพิ่มเงื่อนไขชื่อ: ghost ต้องชื่อ <ชื่อของ>HomeGhost
--   (ชื่อตรง = ของถูก, เพิ่งติด = ห้องถูก) ตัวชื่อไม่ตรงเป็นได้แค่แผนสำรองหลังรอ 0.6 วิ
-- v2.8: "จุดนั้นเต็มแล้ว!" ไม่ใช่จุดจบ — เกมย้ายไฮไลต์ไปชี้จุดว่างใหม่ให้เอง แต่โค้ดเดิมนับพลาด
--   แล้วข้ามทั้งที่ของค้างมือ → แก้เป็นวนลองใหม่สูงสุด 4 รอบ: สแกนไฮไลต์ล่าสุด (ข้ามสล็อตที่เพิ่ง
--   ลองแล้วเต็ม) → บินไปจุดใหม่ที่เกมชี้ → วางซ้ำ จนกว่าจะผ่านหรือครบ 4 รอบ
-- v2.7: วาปทีเดียว (v2.5-2.6) เกมไม่รับ → AUTO เปลี่ยนเป็น "พุ่ง" ถึงเป้าใน 0.1 วิ แบบขยับเป็นสเต็ป
--   ต่อเนื่องทุก Heartbeat (Lerp จากจุดเดิมไปเป้า) + นิ่ง 0.1 วิ หลังถึงก่อนยิง remote
-- v2.6: ยอมรับความจริง — ตอน speed 200 วางไม่ผ่านคือบั๊กจับคู่สล็อตของเราเอง ไม่ใช่เรื่องซิงก์ตำแหน่ง
--   เลยตัดเวลารอที่ใส่กันเหนียวไว้ออกเกือบหมด: TP_SYNC_WAIT 0.3→0.1, ตัด wait 0.15 ก่อนจับ/ก่อนวาง,
--   รอเช็คเงินหลังวาง 0.4→0.25 — ต่อชิ้นเหลือประมาณครึ่งวิ (ไม่รวมเวลารอไฮไลต์ติดซึ่งออกทันทีที่เจอ)
-- v2.5: AUTO เปลี่ยนเป็นโหมดวาป (TELEPORT_MODE) — เด้งไปเป้าหมายทันทีแล้วยืนนิ่งรอ 0.3 วิ
--   ให้ตำแหน่งซิงก์ขึ้นเซิร์ฟเวอร์ก่อนยิง remote (เร็วกว่าบิน speed 100 มาก และปลอดภัยกว่า
--   speed 200 ที่เคยพังเพราะยิง remote ก่อนซิงก์) — ปุ่ม FLY บินเองยังใช้ speed ปกติเหมือนเดิม
-- v2.4: AUTO เปลี่ยนเป็น "จับก่อน แล้วตามไฮไลต์" — snapshot Ghost ที่ติดไฟไว้ก่อนจับ พอจับแล้วเกม
--   จะจุดไฮไลต์จุดวางของชิ้นนั้นขึ้นใหม่ 1 อัน → เอาตัวที่เพิ่งติดเป็นเป้าบิน+วางตรงๆ (แม่นกว่าเดาชื่อ
--   เพราะเกมชี้เอง) ถ้าจับไฮไลต์ใหม่ไม่ได้ใน 1.2 วิ ค่อย fallback เทียบชื่อ+PairId แบบเดิม
-- v2.3: แก้ ESP ไม่ขึ้น — Roblox เรนเดอร์ Highlight ได้สูงสุด 31 อันพร้อมกัน การสร้างให้ของทุกชิ้น
--   (หลายร้อยชิ้น) ทำให้เกินโควตาแล้วไม่แสดงเลย → เปลี่ยนเป็นไฮไลต์เฉพาะของยังไม่วาง 20 ชิ้น
--   ใกล้ตัวสุด รีเฟรชทุก 1 วิ พร้อมโชว์จำนวนของที่เหลือบน status bar
-- v2.2: เพิ่มปุ่ม GUIDE — เส้น Beam สีเขียวลากจากตัวผู้เล่นไปยัง "ของที่ใกล้ที่สุด" ทีละ 1 เส้น
--   พอเก็บชิ้นนั้นแล้ว (ของหาย/ถูกวางชิดสล็อต) เส้นจะย้ายไปชี้ชิ้นถัดไปเองอัตโนมัติ
--   ทั้ง GUIDE และ ESP กรอง "ของที่วางไปแล้ว" ออก (ของที่นั่งชิดสล็อตตัวเอง < 3 stud = วางแล้ว ไม่ชี้ซ้ำ)
-- v2.1: เพิ่มปุ่ม ESP ไฮไลต์ของที่ยังไม่ถูกจับ (มองทะลุกำแพงได้) ช่วยดูภาพรวมว่าเหลืออะไรบ้าง
-- v2.0: ของใหม่ในเกม (ร้านค้า/อัปเกรด) ทำให้มี RemoteEvent ชื่อ "RemoteEvent" มากกว่า 1 ตัว หาอัตโนมัติไม่เจอ
--   เลย timeout ยกเลิก AUTO — แก้เป็นจำ remote ที่เรียนรู้ถูกไว้ใน _G.RB77_REMOTE ข้ามรอบ/ข้ามสคริปต์
--   (ใช้ร่วมกับ AutoSpray77) ไม่ต้องหาใหม่ทุกครั้งที่กด AUTO ถ้าเคยรู้แล้วในเซสชันนี้
-- v1.9: หาสล็อตเป้าหมายไว้ก่อนจับของเลย (ไม่ต้องรอจับก่อนค่อยหา) แล้วตัดเวลารอ 0.35s เปล่าๆ หลังจับออก
--   (ให้ระยะทางบินไปสล็อตกินเวลาแทน ไม่ต้องหยุดรอเฉยๆ) ทำให้แต่ละชิ้นเร็วขึ้นโดยยังปลอดภัยเท่าเดิม
-- v1.8: ความเร็ว 200 เร็วไปจนวางของไม่ผ่าน (ตำแหน่งอาจยังไม่ซิงก์ขึ้นเซิร์ฟเวอร์ตอนยิง remote) — ลดเหลือ 100
--   และเพิ่ม task.wait(0.15) หลังบินถึงก่อนยิง remote ทุกครั้ง ให้ตำแหน่งนิ่ง/ซิงก์ก่อน
-- v1.7: เพิ่มความเร็วบิน FLY_SPEED 60 → 200 ตามที่ขอ
-- อ้างอิงผลจาก 77RB_HouseClean_NetSpy.lua ที่ยืนยันแล้ว:
--   จับของ:  RemoteEvent:FireServer("pickupItem", <Part ของที่จะจับ>)
--   วางของ:  RemoteEvent:FireServer("placeCarried", <Part สล็อตที่จะวาง>, <Part ของที่ถือ>)
--   โครงสร้าง: workspace.House_<N>.Items (ของกระจาย) / workspace.House_<N>.Slots (จุดวาง)
-- v1.1: v1.0 เดาสล็อตแบบ "ชื่อขึ้นต้นด้วย" (prefix match) แล้วพบว่าหยิบ/วางผิดจุดบ่อย เพราะของหลายชิ้น
--   ตั้งชื่อ Part ซ้ำกันแบบ generic (เช่น "Model") ทำให้ prefix match จับคู่มั่ว
-- v1.2: ลองอ่านไฟไฮไลต์สีฟ้า (Highlight → Ghost ใน workspace.Camera.SortingGhosts) แทนการเดาชื่อ
--   แต่จาก NetSpy log ล่าสุดพบว่า Ghost หลายอันไฮไลต์ค้างพร้อมกันได้ (ไม่ได้ผูกกับของที่ถืออยู่ตัวเดียว)
--   ทำให้ "หยิบไฮไลต์ตัวแรกที่เจอ" ยังคงสุ่มผิดได้เหมือนเดิม
-- v1.3: กลับมาใช้ชื่อ แต่เปลี่ยนจาก prefix match เป็น**เทียบชื่อตรงตัวเป๊ะ** — ชื่อ Ghost ที่ NetSpy ดักได้
--   ("CouchHomeGhost", "BookHomeGhost", "Hanging Lights VarHomeGhost") ยืนยันแพทเทิร์นสล็อตชัดเจนว่า =
--   <ชื่อของ>Home เป๊ะทุกตัว ไม่มีข้อยกเว้น เพราะงั้นใช้ slotsFolder:FindFirstChild(item.Name.."Home")
--   ตรงๆ แม่นกว่าทั้ง prefix-guess (v1.0) และการอ่านไฮไลต์ที่กำกวม (v1.2)
--   เพิ่มดักข้อความ "มือเต็ม" ตรงๆ จาก popup ในเกม เพื่อหยุด AUTO ทันทีถ้าของค้างมือ
-- v1.4: เจอบั๊ก "สำเร็จ 0 ทั้งที่จับคู่ถูกทุกตัว" เพราะ cache instance Cash ไว้ตัวเดียวตอนเริ่ม ถ้า leaderstats
--   โดนสร้างใหม่ระหว่างรัน (เช่น respawn) reference จะค้าง เช็คเงินไม่ขึ้นตลอด ทั้งที่วางสำเร็จจริง
--   แก้เป็นค้นหา leaderstats.Cash ใหม่สดๆ ทุกครั้งที่เช็ค แทนการ cache ไว้ล่วงหน้า
-- v1.5: เจอว่าของชื่อเดียวกัน (เช่น "Book") มี attribute PairId/RoomName/RoomId ต่างกันตามห้องที่อยู่
--   (Book ห้อง Office PairId=66, ห้อง Hallway PairId=43) แปลว่าสล็อตชื่อ "<ชื่อของ>Home" อาจมีซ้ำกันได้
--   หลายจุดคนละห้อง — ถ้าใช้ FindFirstChild ตัวเดียวจะได้จุดแรกที่เจอเสมอ ผิดห้องได้ถ้าของมาจากห้องอื่น
--   แก้เป็นหาโดย GetDescendants ทั้งหมดที่ชื่อตรง แล้วถ้าเจอมากกว่า 1 จุด เทียบ PairId ก่อน (แม่นสุด)
--   ตกไป RoomId ถ้าไม่มี PairId ตรง ก่อนจะ fallback ไปจุดแรกที่เจอ
-- v1.6: ผู้ใช้ขอให้บินไปตาม "จุดเรืองแสง" (Ghost) ที่เห็นจริงบนจอ แทนตำแหน่ง Slot ที่คำนวณเอง
--   เพิ่ม getGhostPosition() ดึงตำแหน่งจริงจาก workspace.Camera.SortingGhosts.<ชื่อสล็อต>Ghost มาบินไปแทน
--   remote ยังคงยิงด้วย Slot instance ที่จับคู่ถูกจาก v1.5 เหมือนเดิม (แค่เปลี่ยนจุดที่บินไปให้ตรงตาเห็น)
-- เพราะ RemoteEvent ที่ใช้จริงชื่อซ้ำกันได้หลายจุด (พาธเต็มไม่ยืนยัน) สคริปต์นี้ "เรียนรู้" ตัวจริงเอง 2 ทาง:
--   1) หาเอง: ถ้าเจอ RemoteEvent ชื่อ "RemoteEvent" ใน ReplicatedStorage แค่ตัวเดียว → ใช้ตัวนั้นเลย
--   2) เรียนรู้จากการเล่นจริง: ถ้าเจอมากกว่า 1 ตัว/หาไม่เจอ →ดัก __namecall รอจนกว่าเกมยิง
--      "pickupItem"/"placeCarried" เอง (ผู้ใช้จับ-วางของเอง 1 ครั้งก่อน) แล้วจำ instance ไว้อัตโนมัติ
-- ปุ่ม: FLY (บินอิสระ WASD+Space/Ctrl) | AUTO (บิน+จับ+วางของทั้งหมดอัตโนมัติ) | ESP (ไฮไลต์ของที่ยังไม่จับ) | STOP | ✕
if _G.AF77_GUI then pcall(function() _G.AF77_GUI:Destroy() end) end
if _G.AF77_CONNS then
    for _, c in ipairs(_G.AF77_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.AF77_CONNS = {}
-- v3.1: เลขรุ่น — โหลดสคริปต์ใหม่ทับ ลูป AUTO/ESP/GUIDE ของตัวเก่า (coroutine ที่ spawn ไปแล้ว)
-- ยังวิ่งต่อด้วยตัวแปรของมันเอง ปุ่ม STOP อันใหม่ปิดไม่ถึง → ทุกลูปเช็คว่าเลขรุ่นยังเป็นของตัวเอง
-- ถ้าไม่ใช่ (มีการโหลดใหม่แล้ว) ให้ตายเองทันที
_G.AF77_GEN = (_G.AF77_GEN or 0) + 1
local MY_GEN = _G.AF77_GEN
-- เก็บกวาดไฮไลต์ ESP / เส้น GUIDE ที่รุ่นเก่าทิ้งค้างไว้ (ตั้งชื่อเฉพาะไว้ให้ตามลบได้)
for _, d in ipairs(workspace:GetDescendants()) do
    if d.Name == "AF77_ESP" or d.Name == "AF77_GUIDE" then pcall(function() d:Destroy() end) end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local FLY_ON, AUTO_ON = false, false
local FLY_SPEED = 100
local learnedRemote = _G.RB77_REMOTE -- จำ remote ที่เรียนรู้ถูกไว้แล้วข้ามรอบ (กันหาไม่เจอตอนของใหม่โผล่ในเกม)
local statusText = "รอเริ่ม..."

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFly77"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.AF77_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 260, 0, 150); frame.Position = UDim2.new(0, 8, 0.2, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.2
frame.Active = true; frame.Draggable = true

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, -8, 0, 40); status.Position = UDim2.new(0, 4, 0, 4)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(180, 255, 180)
status.TextSize = 12; status.Font = Enum.Font.Code; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.TextYAlignment = Enum.TextYAlignment.Top
local function setStatus(s) statusText = s; status.Text = s end

local function mkbtn(txt, y, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, -8, 0, 26); b.Position = UDim2.new(0, 4, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local flyB   = mkbtn("FLY: OFF (บินอิสระ WASD+Space/Ctrl)", 48, Color3.fromRGB(40, 90, 150))
local autoB  = mkbtn("AUTO: OFF (จับ-วางของทั้งหมด)", 78, Color3.fromRGB(40, 130, 70))
local espB   = mkbtn("ESP: OFF (ไฮไลต์ของที่ยังไม่จับ)", 108, Color3.fromRGB(150, 100, 20))
local guideB = mkbtn("GUIDE: OFF (เส้นนำทางไปของใกล้สุด)", 138, Color3.fromRGB(30, 150, 150))
local stopB  = mkbtn("STOP ทั้งหมด", 168, Color3.fromRGB(150, 60, 30))
local closeB = mkbtn("✕ ปิด", 198, Color3.fromRGB(90, 40, 40))
frame.Size = UDim2.new(0, 260, 0, 230)

setStatus("[AutoFly77] พร้อม — กด FLY เพื่อบินอิสระ หรือ AUTO เพื่อจับ-วางของอัตโนมัติ")

-- ==================== หา RemoteEvent ที่ใช้จริง ====================
local function tryAutoFindRemote()
    local candidates = {}
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") and d.Name == "RemoteEvent" then
            candidates[#candidates + 1] = d
        end
    end
    if #candidates == 1 then
        learnedRemote = candidates[1]
        _G.RB77_REMOTE = learnedRemote
        setStatus("[AutoFly77] เจอ RemoteEvent อัตโนมัติ: " .. learnedRemote:GetFullName())
        return true
    end
    return false
end

local function hookLearn()
    if not hookmetamethod then
        setStatus("[AutoFly77] ❌ ไม่มี hookmetamethod — เรียนรู้ remote อัตโนมัติไม่ได้")
        return
    end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not learnedRemote then
            local method = getnamecallmethod()
            if method == "FireServer" then
                local args = { ... }
                if args[1] == "pickupItem" or args[1] == "placeCarried" then
                    learnedRemote = self
                    _G.RB77_REMOTE = learnedRemote
                    setStatus("[AutoFly77] ✅ เรียนรู้ remote จากการเล่นจริง: " .. self:GetFullName())
                end
            end
        end
        return old(self, ...)
    end)
end

-- ==================== หาห้อง/ของ/สล็อต ====================
-- v4.5: เซิร์ฟเวอร์มีหลายบ้าน/หลายเกาะ (ของผู้เล่นคนอื่น) — ทุกระบบต้องมองเฉพาะ "บ้านที่ใกล้เราสุด"
-- ไม่งั้น GUIDE/ESP/AUTO จะชี้ข้ามทะเลไปเกาะคนอื่น
local function nearestHouseList()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local all = {}
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("Model") and c:FindFirstChild("Items") and c:FindFirstChild("Slots") then
            all[#all + 1] = c
        end
    end
    if not hrp or #all <= 1 then return all end
    local best, bestD = nil, math.huge
    for _, h in ipairs(all) do
        local ok, pv = pcall(function() return h:GetPivot() end)
        if ok then
            local d = (pv.Position - hrp.Position).Magnitude
            if d < bestD then best, bestD = h, d end
        end
    end
    return best and { best } or all
end

local function findHouses()
    local out = {}
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("Model") and c:FindFirstChild("Items") and c:FindFirstChild("Slots") then
            out[#out + 1] = c
        end
    end
    return out
end

-- ประกาศล่วงหน้า (นิยามจริงอยู่ด้านล่าง) เพื่อให้ ESP/GUIDE เรียกใช้ได้ก่อนถึงจุดนิยามจริง
local findSlotFor, partPosition, looksAlreadyPlaced

-- ==================== ESP: ไฮไลต์ของที่ยังไม่จับ (มองทะลุกำแพงได้) ====================
-- Roblox เรนเดอร์ Highlight พร้อมกันได้สูงสุด 31 อัน — ถ้าสร้างให้ของทุกชิ้น (หลายร้อย)
-- อันที่เกินโควตาจะไม่ขึ้นเลย เพราะงั้นจำกัดเฉพาะของที่ยังไม่วาง 20 ชิ้นใกล้ตัวสุด รีเฟรชทุก 1 วิ
local ESP_ON = false
local ESP_MAX = 20
local espHighlights = {} -- item -> Highlight instance
local espLoop

local function espRemoveAll()
    for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end
    espHighlights = {}
end

local function espRefresh()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local cands = {}
    for _, house in ipairs(nearestHouseList()) do
        for _, item in ipairs(house.Items:GetChildren()) do
            if not (looksAlreadyPlaced and looksAlreadyPlaced(item, house.Slots)) then
                local pos = partPosition(item)
                if pos then
                    cands[#cands + 1] = { item = item, d = (pos - hrp.Position).Magnitude }
                end
            end
        end
    end
    table.sort(cands, function(a, b) return a.d < b.d end)
    local keep = {}
    for i = 1, math.min(ESP_MAX, #cands) do keep[cands[i].item] = true end
    for item, h in pairs(espHighlights) do
        if not keep[item] or not item.Parent then
            pcall(function() h:Destroy() end)
            espHighlights[item] = nil
        end
    end
    for item in pairs(keep) do
        if not espHighlights[item] and item.Parent then
            local h = Instance.new("Highlight")
            h.Name = "AF77_ESP"
            h.FillColor = Color3.fromRGB(60, 255, 90)
            h.FillTransparency = 0.5
            h.OutlineColor = Color3.fromRGB(120, 255, 140)
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Adornee = item
            h.Parent = item
            espHighlights[item] = h
        end
    end
    setStatus(("[AutoFly77] ESP: เหลือของยังไม่วาง %d ชิ้น (ไฮไลต์ %d ชิ้นใกล้สุด)")
        :format(#cands, math.min(ESP_MAX, #cands)))
end

local function espStart()
    ESP_ON = true
    espLoop = task.spawn(function()
        while ESP_ON and _G.AF77_GEN == MY_GEN do
            pcall(espRefresh)
            task.wait(1)
        end
        if _G.AF77_GEN ~= MY_GEN then espRemoveAll() end
    end)
end
local function espStop()
    ESP_ON = false
    if espLoop then pcall(function() task.cancel(espLoop) end) espLoop = nil end
    espRemoveAll()
end

function partPosition(inst)
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart.Position end
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok then return cf.Position end
    end
    return nil
end

-- ==================== GUIDE: เส้นนำทางไปของที่ใกล้ที่สุด ทีละเส้น ====================
local GUIDE_ON = false
local guideConn, guideBeam, guideA0, guideA1, guideTarget

-- ของที่วางสำเร็จแล้วไม่หายไปจาก Items folder (ยืนยันจาก AutoFly ก่อนหน้า) แต่มักถูกขยับไปนั่งชิดสล็อตของมันเอง
-- เพราะงั้นถ้าของอยู่ใกล้สล็อตตัวเองมากๆ (< 3 stud) ให้ถือว่า "วางไปแล้ว" ข้ามไม่ต้องชี้ทางไปซ้ำ
function looksAlreadyPlaced(item, slotsFolder)
    local slot = findSlotFor(item, slotsFolder)
    if not slot then return false end
    local ipos, spos = partPosition(item), partPosition(slot)
    if not ipos or not spos then return false end
    return (ipos - spos).Magnitude < 3
end

local function findNearestItem()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local best, bestDist = nil, math.huge
    for _, house in ipairs(nearestHouseList()) do
        for _, item in ipairs(house.Items:GetChildren()) do
            if not looksAlreadyPlaced(item, house.Slots) then
                local pos = partPosition(item)
                if pos then
                    local d = (pos - hrp.Position).Magnitude
                    if d < bestDist then bestDist = d; best = item end
                end
            end
        end
    end
    return best
end

local function guideStop()
    GUIDE_ON = false
    if guideConn then guideConn:Disconnect() guideConn = nil end
    if guideBeam then pcall(function() guideBeam:Destroy() end) guideBeam = nil end
    if guideA0 then pcall(function() guideA0:Destroy() end) guideA0 = nil end
    if guideA1 then pcall(function() guideA1:Destroy() end) guideA1 = nil end
    guideTarget = nil
end

local function guideStart()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    GUIDE_ON = true

    guideA0 = Instance.new("Attachment")
    guideA0.Name = "AF77_GUIDE"
    guideA0.Parent = hrp
    guideBeam = Instance.new("Beam")
    guideBeam.Name = "AF77_GUIDE"
    guideBeam.Width0 = 0.4
    guideBeam.Width1 = 0.1
    guideBeam.Color = ColorSequence.new(Color3.fromRGB(60, 255, 150))
    guideBeam.Transparency = NumberSequence.new(0.15)
    guideBeam.FaceCamera = true
    guideBeam.Attachment0 = guideA0
    guideBeam.Parent = guideA0

    guideConn = RunService.Heartbeat:Connect(function()
        if _G.AF77_GEN ~= MY_GEN then guideStop() return end -- โหลดสคริปต์ใหม่ทับแล้ว — ปิดตัวเองทิ้ง
        if not GUIDE_ON then return end
        if not (guideTarget and guideTarget.Parent) then
            local nearest = findNearestItem()
            if not nearest then
                guideBeam.Enabled = false
                setStatus("[AutoFly77] GUIDE: ไม่พบของที่เหลือแล้ว")
                return
            end
            guideTarget = nearest
            if guideA1 then pcall(function() guideA1:Destroy() end) end
            guideA1 = Instance.new("Attachment")
            guideA1.Name = "AF77_GUIDE"
            guideA1.Parent = guideTarget
            guideBeam.Attachment1 = guideA1
            setStatus(("[AutoFly77] GUIDE → %s"):format(guideTarget.Name))
        end
        guideBeam.Enabled = true
    end)
end

-- ==================== บิน (ย้าย HumanoidRootPart ไปจุดหมายแบบนุ่มๆ) ====================
-- v3.2: กลับมาบินแบบเดิม (วาป/พุ่งแล้วตัวละครล้มตลอด) + NoClip ระหว่างบิน — ปิด CanCollide
-- ทุกส่วนของตัวละครทุกเฟรม จะได้ทะลุกำแพง/เฟอร์นิเจอร์ ไม่ชนอะไรจนล้มหรือติดขอบ
local function setNoClip(on)
    local char = LP.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = not on end
    end
end

local function flyTo(targetPos, timeoutSec)
    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local t0 = tick()
    while tick() - t0 < (timeoutSec or 6) do
        if not AUTO_ON or _G.AF77_GEN ~= MY_GEN then return false end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        setNoClip(true)
        hrp.AssemblyLinearVelocity = Vector3.zero
        local cur = hrp.Position
        local dist = (targetPos - cur).Magnitude
        if dist < 4 then
            -- v4.6: ห้ามปิด NoClip ตรงนี้เด็ดขาด — ตัวมักจมอยู่ในเฟอร์นิเจอร์พอดี เปิดการชนกลับ
            -- ตอนซ้อนกับของ = ฟิสิกส์ดีดตัวกระเด็นขึ้นฟ้า ("โดนของผลัก") ให้ AUTO จบก่อนค่อยปิดที่จุดปลอดภัย
            task.wait(0.1) -- ถึงแล้วนิ่งแป๊บให้ตำแหน่งซิงก์ก่อนคนเรียกยิง remote
            return true
        end
        local dir = (targetPos - cur).Unit
        hrp.CFrame = CFrame.new(cur + dir * math.min(FLY_SPEED * RunService.Heartbeat:Wait(), dist), targetPos)
    end
    return true
end

-- ==================== หาสล็อตเป้าหมายจากชื่อ + PairId/RoomId (กันชื่อซ้ำข้ามห้อง) ====================
-- ยืนยันจาก NetSpy: item มี attribute PairId/RoomName/RoomId (เช่น Book ตัวใน "Office" PairId=66,
-- ตัวใน "Hallway" PairId=43) แปลว่าของชื่อเดียวกันอาจมีสล็อตชื่อ "<ชื่อของ>Home" ซ้ำกันได้หลายห้อง
-- ถ้าเจอสล็อตชื่อตรงมากกว่า 1 จุด ต้องเทียบ PairId ก่อน (แม่นสุด) แล้วค่อย RoomId ถ้าไม่มี PairId ตรง
function findSlotFor(item, slotsFolder)
    local wantName = item.Name .. "Home"
    local candidates = {}
    for _, s in ipairs(slotsFolder:GetDescendants()) do
        if s.Name == wantName then
            candidates[#candidates + 1] = s
        end
    end
    if #candidates == 0 then return nil end
    if #candidates == 1 then return candidates[1] end

    local pairId = item:GetAttribute("PairId")
    if pairId ~= nil then
        for _, s in ipairs(candidates) do
            if s:GetAttribute("PairId") == pairId then return s end
        end
    end
    local roomId = item:GetAttribute("RoomId")
    if roomId ~= nil then
        for _, s in ipairs(candidates) do
            if s:GetAttribute("RoomId") == roomId then return s end
        end
    end
    return candidates[1]
end

-- ==================== ตำแหน่งจริงของจุดเรืองแสง (Ghost) — บินไปตามที่ตาเห็นจริงบนจอ ====================
-- ยืนยันจาก NetSpy [ARROW]: workspace.Camera.SortingGhosts มี Ghost ชื่อ "<ชื่อสล็อต>Ghost" ต่อสล็อต 1 จุด
local function getGhostPosition(slot)
    local ghostFolder = workspace:FindFirstChild("Camera")
    ghostFolder = ghostFolder and ghostFolder:FindFirstChild("SortingGhosts")
    if not ghostFolder then return nil end
    local ghost = ghostFolder:FindFirstChild(slot.Name .. "Ghost")
    if not ghost then return nil end
    if ghost:IsA("BasePart") then return ghost.Position end
    if ghost:IsA("Model") then
        if ghost.PrimaryPart then return ghost.PrimaryPart.Position end
        local ok, cf = pcall(function() return ghost:GetPivot() end)
        if ok then return cf.Position end
    end
    return nil
end

-- ==================== อ่านไฮไลต์ที่ "เพิ่งติด" หลังจับของ — เกมชี้จุดวางให้เองตรงๆ ====================
-- Ghost หลายอันไฮไลต์ค้างพร้อมกันได้ (v1.2 พังเพราะงี้) แต่ "อันที่เพิ่งติดใหม่หลังจับของ" มีอันเดียว
-- คือจุดวางของชิ้นที่ถืออยู่แน่นอน → snapshot ก่อนจับ เทียบกับหลังจับ เอาตัวที่โผล่ใหม่
local function getLitGhosts()
    local set = {}
    local cam = workspace:FindFirstChild("Camera")
    local folder = cam and cam:FindFirstChild("SortingGhosts")
    if not folder then return set end
    for _, g in ipairs(folder:GetChildren()) do
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("Highlight") and d.Enabled then set[g] = true; break end
        end
    end
    return set
end

-- แปลง Ghost ที่ติดไฟ → Slot instance จริงสำหรับยิง remote (ชื่อสล็อต = ชื่อ Ghost ตัด "Ghost" ท้ายออก
-- ถ้าชื่อซ้ำหลายห้อง เลือกตัวที่ตำแหน่งใกล้ Ghost ที่สุด — ชี้ห้องถูกแน่นอนเพราะ Ghost อยู่ตรงจุดวางจริง)
local function slotFromGhost(ghost, slotsFolder)
    local slotName = ghost.Name:gsub("Ghost$", "")
    local gpos = partPosition(ghost)
    local best, bestD = nil, math.huge
    for _, s in ipairs(slotsFolder:GetDescendants()) do
        if s.Name == slotName then
            local p = partPosition(s)
            local d = (p and gpos) and (p - gpos).Magnitude or math.huge
            if d < bestD or not best then best, bestD = s, d end
        end
    end
    return best
end

-- ==================== ดักข้อความ "มือเต็ม!" ตรงๆ จาก popup ในเกม ====================
local HAND_FULL_FLAG = false
local function looksLikeHandFullText(t)
    return t and (t:find("มือเต็ม") ~= nil)
end
local function watchHandFull()
    local function hook(inst)
        if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then return end
        local function check()
            if looksLikeHandFullText(inst.Text) then HAND_FULL_FLAG = true end
        end
        check()
        table.insert(_G.AF77_CONNS, inst:GetPropertyChangedSignal("Text"):Connect(check))
    end
    for _, d in ipairs(LP.PlayerGui:GetDescendants()) do hook(d) end
    table.insert(_G.AF77_CONNS, LP.PlayerGui.DescendantAdded:Connect(hook))
end

local function runAuto()
    if learnedRemote and not learnedRemote.Parent then
        learnedRemote = nil -- remote ที่จำไว้โดนทำลายไปแล้ว (เช่น เข้าเซิร์ฟเวอร์ใหม่) ต้องหาใหม่
    end
    if not learnedRemote then
        if not tryAutoFindRemote() then
            setStatus("[AutoFly77] ⚠️ ยังไม่รู้ remote — ลองจับ-วางของเอง 1 ครั้งก่อน (สคริปต์กำลังดักเรียนรู้อยู่)")
            local t0 = tick()
            while AUTO_ON and _G.AF77_GEN == MY_GEN and not learnedRemote and tick() - t0 < 30 do task.wait(0.5) end
            if not learnedRemote then
                setStatus("[AutoFly77] ❌ หา remote ไม่เจอ ยกเลิก AUTO")
                AUTO_ON = false
                autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
                return
            end
        end
    end

    if #findHouses() == 0 then
        setStatus("[AutoFly77] ❌ ไม่เจอ House ที่มี Items/Slots ใน workspace — ยกเลิก")
        AUTO_ON = false
        autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
        return
    end

    -- ค้นหา Cash ใหม่ทุกครั้ง (ไม่ cache instance ไว้) กัน reference ค้างถ้า leaderstats โดนสร้างใหม่ระหว่างรัน (เช่น respawn)
    local function getCashStat()
        local ls = LP:FindFirstChild("leaderstats")
        return ls and ls:FindFirstChild("Cash")
    end
    local function getCash()
        local c = getCashStat()
        return c and c.Value or 0
    end

    -- ==================== v4.0 ยกเครื่องลูป AUTO — สูตรเรียบง่าย 5 ข้อ ====================
    -- 1) จับของใกล้สุด 2) ดูไฮไลต์อยู่ตรงไหน 3) บินไปตรงนั้น 4) วาง 5) วนข้อ 1 — NoClip ตลอด
    HAND_FULL_FLAG = false
    watchHandFull()
    local ABORT_HANDFULL = "[AutoFly77] ⛔ หยุด AUTO เพราะเกมแจ้ง \"มือเต็ม\" — ไปวาง/ทิ้งของที่ถืออยู่เองก่อน แล้วค่อยกด AUTO ใหม่"

    local processed, failed = 0, 0
    local skipItems = {} -- ชิ้นที่วางไม่ผ่าน/วางแล้ว — ไม่หยิบซ้ำในรอบรันนี้ กันวนชิ้นเดิมไม่จบ

    -- v4.2: จุดอ้างอิงกันหลุดแผนที่ — ของบางชิ้นฟิสิกส์พาร่วง/ลอยหลุดออกนอกบ้าน สคริปต์เคยบินตาม
    -- จนตกแผนที่ → (1) ไม่ไล่ของที่ตำแหน่งหลุดโลก (2) ตัวเราหลุดโซนเมื่อไหร่ วาร์ปกลับจุดเริ่มเอง
    -- v4.4: homePos เคยอิงตำแหน่งตัวเราตอนกด AUTO — ถ้ากดตอนลอยบนฟ้า เพดานทั้งระบบเพี้ยนตาม
    -- และ "วาร์ปกลับ" ก็พากลับไปกลางฟ้า → เปลี่ยนมายึดกล่องขอบเขตของตัวบ้านจริง (GetBoundingBox)
    -- v4.7: GetBoundingBox ของโมเดลบ้านกว้างเกินจริง (มีชิ้นประดับ/เอฟเฟกต์ลอยสูงปน เพดานเลยอยู่บนฟ้า)
    -- → คำนวณกรอบจากตำแหน่ง "สล็อตวางของจริงทุกจุด" แทน — สล็อตอยู่ในตัวบ้านแน่นอน ได้กรอบแคบตรงจริง
    local homePos, Y_MIN, Y_MAX
    do
        local h1 = nearestHouseList()[1]
        local minY, maxY = math.huge, -math.huge
        local sumX, sumY, sumZ, n = 0, 0, 0, 0
        for _, s in ipairs(h1.Slots:GetDescendants()) do
            if s:IsA("BasePart") then
                local y = s.Position.Y
                if y < minY then minY = y end
                if y > maxY then maxY = y end
                sumX += s.Position.X; sumY += y; sumZ += s.Position.Z; n += 1
            end
        end
        if n > 0 then
            homePos = Vector3.new(sumX / n, sumY / n, sumZ / n)
            Y_MIN, Y_MAX = minY - 10, maxY + 20
        else
            local ok, pv = pcall(function() return h1:GetPivot() end)
            homePos = ok and pv.Position or Vector3.zero
            Y_MIN, Y_MAX = homePos.Y - 30, homePos.Y + 40
        end
    end
    local function clampY(p)
        return Vector3.new(p.X, math.clamp(p.Y, Y_MIN, Y_MAX), p.Z)
    end
    local function positionSane(p)
        return p and p.Y > Y_MIN - 30 and p.Y < Y_MAX + 30 and (p - homePos).Magnitude < 600
    end

    -- NoClip ตลอดเวลาที่ AUTO ทำงาน (Stepped ยิงก่อนฟิสิกส์ทุกเฟรม — เปิดซ้ำตลอดกันเกมรีเซ็ตคืน)
    -- v4.1: NoClip ตลอด = ไม่มีพื้นให้เหยียบ ตอนยืนวางของเลยร่วงทะลุแผนที่ → ล็อคความเร็วเป็นศูนย์
    -- ทุกเฟรมด้วย (ตัวลอยนิ่งค้างที่เดิม ไม่ตกลงไปเรื่อยๆ) การขยับจริงใช้ CFrame ใน flyTo อยู่แล้ว
    -- v4.3: + บังคับเพดานความสูงทุกเฟรม — โผล่เกินเพดาน/ทะลุพื้นเมื่อไหร่กดกลับทันที
    local noclipConn = RunService.Stepped:Connect(function()
        if AUTO_ON and _G.AF77_GEN == MY_GEN then
            setNoClip(true)
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
                local p = hrp.Position
                local cp = clampY(p)
                if (cp - p).Magnitude > 0.01 then
                    hrp.CFrame = CFrame.new(cp) * hrp.CFrame.Rotation
                end
            end
        end
    end)
    table.insert(_G.AF77_CONNS, noclipConn)

    local function nearestUnplacedItem()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local best, bestD, bestHouse = nil, math.huge, nil
        for _, house in ipairs(nearestHouseList()) do
            for _, it in ipairs(house.Items:GetChildren()) do
                if not skipItems[it] and not looksAlreadyPlaced(it, house.Slots) then
                    local p = partPosition(it)
                    if p and positionSane(p) then
                        local d = (p - hrp.Position).Magnitude
                        if d < bestD then best, bestD, bestHouse = it, d, house end
                    end
                end
            end
        end
        return best, bestHouse
    end

    while AUTO_ON and _G.AF77_GEN == MY_GEN do
        if HAND_FULL_FLAG then
            setStatus(ABORT_HANDFULL)
            break
        end

        -- ตัวเราหลุดโซนบ้าน (ตกแผนที่/ลอยหลุดฟ้า) → วาร์ปกลับจุดเริ่มก่อนทำงานต่อ
        do
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and not positionSane(hrp.Position) then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = CFrame.new(homePos)
                task.wait(0.2)
            end
        end

        -- (1) ของชิ้นใกล้สุดที่ยังไม่ได้วาง
        local item, house = nearestUnplacedItem()
        if not item then
            setStatus(("[AutoFly77] ✅ ไม่เหลือของให้เก็บแล้ว — จบ (สำเร็จ %d, ข้าม %d)"):format(processed, failed))
            break
        end

        setStatus(("[AutoFly77] เก็บ: %s (วางแล้ว %d)"):format(item.Name, processed))
        local ipos = partPosition(item)
        if ipos then flyTo(clampY(ipos), 6) end
        if not AUTO_ON or _G.AF77_GEN ~= MY_GEN then break end
        pcall(function() learnedRemote:FireServer("pickupItem", item) end)

        -- (2) ดูไฮไลต์: ghost ชื่อ <ชื่อของ>HomeGhost ที่ติดไฟอยู่ตอนนี้
        local wantGhostName = item.Name .. "HomeGhost"
        local ghost
        local t0 = tick()
        while AUTO_ON and _G.AF77_GEN == MY_GEN and not ghost and tick() - t0 < 1.0 do
            for g in pairs(getLitGhosts()) do
                if g.Name == wantGhostName then ghost = g; break end
            end
            if not ghost then task.wait(0.05) end
        end

        local slot = (ghost and slotFromGhost(ghost, house.Slots)) or findSlotFor(item, house.Slots)
        if not slot or not slot.Parent then
            skipItems[item] = true
            failed += 1
            setStatus(("[AutoFly77] ⚠️ %s ไม่เจอทั้งไฮไลต์และสล็อต — ข้าม"):format(item.Name))
        else
            -- (3) บินไปจุดไฮไลต์
            local spos = (ghost and partPosition(ghost)) or getGhostPosition(slot) or partPosition(slot)
            if spos then flyTo(clampY(spos), 6) end
            if not AUTO_ON or _G.AF77_GEN ~= MY_GEN then break end

            -- (4) วาง
            pcall(function() learnedRemote:FireServer("placeCarried", slot, item) end)
            task.wait(0.2)

            -- วางติดจริงไหม: ของย้ายมานั่งใกล้สล็อตที่เพิ่งวาง — ติดก็ (5) วนต่อ ไม่ติดก็ข้ามชิ้นนี้
            local ip, sp = partPosition(item), partPosition(slot)
            if ip and sp and (ip - sp).Magnitude < 6 then
                processed += 1
                skipItems[item] = true -- วางแล้ว ไม่ต้องกลับมามองชิ้นนี้อีก
            else
                skipItems[item] = true
                failed += 1
                setStatus(("[AutoFly77] ⚠️ %s วางไม่เข้า (จุดอาจเต็ม) — ข้ามไปชิ้นถัดไป"):format(item.Name))
            end
        end
    end

    -- จบงาน: วาร์ปขึ้นกลางอากาศเหนือหลังคาก่อนเปิดการชนคืน — เปิดตอนตัวซ้อนกับเฟอร์นิเจอร์จะโดนดีดกระเด็น
    do
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(homePos.X, Y_MAX + 5, homePos.Z)
        end
    end
    setNoClip(false)
    setStatus(("[AutoFly77] ✅ จบแล้ว! สำเร็จ %d, ข้าม/พลาด %d"):format(processed, failed))
    AUTO_ON = false
    autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
end

-- ==================== FLY: บินอิสระด้วย WASD + Space/Ctrl ====================
local flyConn
local function startFly()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.Name = "AF77_FlyVel"
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.new()
    bv.Parent = hrp
    flyConn = RunService.Heartbeat:Connect(function()
        if not FLY_ON then return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.new()
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        bv.Velocity = dir * FLY_SPEED
    end)
    table.insert(_G.AF77_CONNS, flyConn)
end
local function stopFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            local bv = hrp:FindFirstChild("AF77_FlyVel")
            if bv then bv:Destroy() end
        end
    end
end

-- ==================== Buttons ====================
flyB.MouseButton1Click:Connect(function()
    FLY_ON = not FLY_ON
    flyB.Text = FLY_ON and "FLY: ON (WASD+Space/Ctrl)" or "FLY: OFF (บินอิสระ WASD+Space/Ctrl)"
    if FLY_ON then startFly() else stopFly() end
end)
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    autoB.Text = AUTO_ON and "AUTO: ON (กำลังทำงาน...)" or "AUTO: OFF (จับ-วางของทั้งหมด)"
    if AUTO_ON then task.spawn(runAuto) end
end)
espB.MouseButton1Click:Connect(function()
    if ESP_ON then
        espStop()
        espB.Text = "ESP: OFF (ไฮไลต์ของที่ยังไม่จับ)"
    else
        espStart()
        espB.Text = "ESP: ON (มองทะลุกำแพง)"
    end
end)
guideB.MouseButton1Click:Connect(function()
    if GUIDE_ON then
        guideStop()
        guideB.Text = "GUIDE: OFF (เส้นนำทางไปของใกล้สุด)"
    else
        guideStart()
        guideB.Text = "GUIDE: ON (กำลังชี้ทาง...)"
    end
end)
stopB.MouseButton1Click:Connect(function()
    FLY_ON, AUTO_ON = false, false
    flyB.Text = "FLY: OFF (บินอิสระ WASD+Space/Ctrl)"
    autoB.Text = "AUTO: OFF (จับ-วางของทั้งหมด)"
    stopFly()
    espStop()
    espB.Text = "ESP: OFF (ไฮไลต์ของที่ยังไม่จับ)"
    guideStop()
    guideB.Text = "GUIDE: OFF (เส้นนำทางไปของใกล้สุด)"
    setStatus("[AutoFly77] หยุดทั้งหมดแล้ว")
end)
closeB.MouseButton1Click:Connect(function()
    FLY_ON, AUTO_ON = false, false
    stopFly()
    espStop()
    guideStop()
    for _, c in ipairs(_G.AF77_CONNS) do pcall(function() c:Disconnect() end) end
    _G.AF77_CONNS = {}
    gui:Destroy(); _G.AF77_GUI = nil
end)

-- ==================== Setup ====================
hookLearn()
tryAutoFindRemote()
warn("[AutoFly77] loaded")
