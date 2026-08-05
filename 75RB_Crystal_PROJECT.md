# 75RB — เกมคริสตัล/เหมืองแร่ (โซนความหายาก)

> เกมเก็บคริสตัลขาย: เดินหาก้อนแร่ กด E เก็บ (มีน้ำหนักกระเป๋าจำกัด) เอาไปขายเป็นเงิน
> เริ่มโปรเจ็ก 2026-08-05 ต่อจาก 74RB Animal Hospital

## ไฟล์ในโปรเจ็ก

| ไฟล์ | หน้าที่ | สถานะ |
|---|---|---|
| `75RB_ItemESP.lua` | ESP คริสตัล: ป้ายชื่อ+ราคา+☘โชค+ระยะ, กรอง T1-T6/Giant, เรียงแพง/ใกล้/โชค, TOP5 กดวาปไปได้, บินแบบ 74+noclip, ไม่นับ Placed_* | v2.9 |
| `75RB_Assist.lua` | เก็บอัตโนมัติ: fireproximityprompt ก้อนแพงสุดในระยะ + Hold bypass + วัดเพดานระยะ, ไม่นับ Placed_* | v1.5 |
| `75RB_ItemSpy.lua` | สปายดัมพ์ prompt เก็บของ 15 ตัวใกล้สุด: attrs/สี/mesh/label | v1.0 |
| `75RB_NetSpy.lua` | ดัก FireServer/InvokeServer + ProximityPrompt (ปุ่ม E) + LIST remotes | v1.1 |

รัน: `loadstring(game:HttpGet("https://fttinvesting.com/rb/<ไฟล์>?v="..tick()))()`

## โครงสร้างเกม (จาก ItemSpy 2026-08-05)

- ก้อนคริสตัล = `MeshPart` ชื่อ `Crystal_T1..T6` ใน `Workspace.Things.Crystals`
  (มี `Placed_2..6` ด้วย — น่าจะของที่ผู้เล่นวาง/ตกแต่ง)
- **ข้อมูลทุกอย่างอยู่ใน Attributes ของก้อน:**
  - `CrystalName` = ชื่อจริง (Bluestone, Diamond, Oculus Prime, ...)
  - `Tier` 1-6 + `TierName` (Common/…/Legendary/Mythic) + `TierColorR/G/B` = สีประจำเทียร์
  - `Value` = ราคาขาย ($) — T1 หลักหน่วย, T6 หลักล้าน-สิบล้าน
  - `WeightKg` = น้ำหนัก (กระเป๋าจำกัด เช่น 357 kg)
  - `SizeClass`/`SizeClassName` = S / Medium / Large / Giant (Giant มี `GiantAura:Sound`)
  - `SpawnedAt` = workspace time ตอนเกิด
- ลูกในก้อน: `ProximityPrompt` (Action='Pickup', **Hold = 1-5 วิตามเทียร์**), `BillboardGui`
  (ป้าย "Pickup"), `CrystalHover` (ป้ายเกรด/kg/$/Luck), `CrystalGlow:PointLight`, `Highlight`
- prompt แสดง `ObjectText` แบบ `[S] Bluestone • 1.2kg • $12`

## ระบบเน็ตเวิร์ก (จาก NetSpy)

- **เก็บของไม่ยิง Remote เลย** — ProximityPrompt ล้วน (Roblox ส่งให้ server เอง)
  → บอทใช้ `fireproximityprompt(pp, 0)` + ตั้ง `HoldDuration = 0` ก่อนยิง (bypass กดค้าง 5 วิ)
- **server เช็คระยะเก็บ**: ❌ ที่ 37m / 54m / 65m / 128m — ✅ เก็บได้ระยะใกล้
  เพดานจริงยังไม่นิ่ง (Assist v1.1+ วัดสะสมให้เอง โชว์ `เพดาน: ✅x ❌y`)
- การขาย: ยังไม่ได้สปาย (รอ user ขายมือ 1 ครั้งพร้อม NetSpy เปิด)

## บทเรียน/กับดัก

- **อย่า cache โฟลเดอร์ `Things.Crystals`** — เกมสร้างใหม่ตอนวาร์ปโซน/กลับบ้าน ตัวแปรเก่า
  ชี้ที่ว่าง → ขึ้น 0/0 ก้อน ต้อง FindFirstChild ใหม่ทุกรอบสแกน (แก้แล้ว ESP v2.4 / Assist v1.3)
- แมพมีคริสตัล ~2,000 ก้อน — ติดป้ายหมดจอแตก+เลค ต้องจำกัด (MAX_SHOW 150 / TOP5 only)
- ก้อนที่ยิง fp ไม่เข้า (ไกลเกิน) ต้อง blacklist ชั่วคราว 8 วิ ไม่งั้นบอทยิงก้อนเดิมซ้ำไม่ไปไหน
- ระยะเก็บใช้ร่วมกัน 2 สคริปต์ผ่าน `_G.AS75_RANGE` (ซิงก์สองทาง Assist ↔ ItemESP)
- **ค่าโชค (Luck) ไม่มีใน Attributes** — มีแค่เป็นข้อความใน TextLabel ของ `CrystalHover`
  รูปแบบ `'Luck: +6.0%'` → ต้องแกะด้วย pattern `Luck:%s*%+?([%d%.]+)%%` แล้ว cache
  (weak table กัน memory leak) — ทำแล้วใน ESP v2.8
- ก้อนชื่อ `Placed_2..6` = ของวางตกแต่งบ้านผู้เล่น — เก็บไม่ได้/ไม่ควรนับ ต้องกรอง
  `c.Name:match("^Placed")` ออกทุกสแกน (ESP v2.9 / Assist v1.5)
- วาปไปก้อน: เปิดโหมดบิน (CFrame pin) ก่อนแล้วค่อยย้าย `FLY_POS` ไปเหนือก้อน +6 studs
  → ถึงแล้วลอยค้างเลย ไม่ร่วง ไม่โดนฟิสิกส์เตะ (ESP v2.9 TOP5 กดได้)
- executor นี้มี `hookmetamethod` ✅ (ดัก __namecall ได้)

## _G ที่ใช้ (กันชนกัน)

`IESP75_*` (ItemESP) | `AS75_*` (Assist) | `ISPY75_GUI` | `NSPY75_*` | `AS75_RANGE` (ค่าระยะแชร์)

## งานถัดไป

- [ ] หาเพดานระยะเก็บที่แน่นอน (ดูจาก `เพดาน: ✅x ❌y` ใน Assist)
- [ ] สปายการขาย → ทำ auto ขายเมื่อกระเป๋าใกล้เต็ม (ดู attr น้ำหนักรวมจากไหน)
- [ ] เช็คว่าโซนอื่น (บ้าน/เกาะพิเศษ) เก็บก้อนไว้ path ไหน ถ้าไม่ใช่ Things.Crystals
