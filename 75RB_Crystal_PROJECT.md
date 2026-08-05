# 75RB — เกมคริสตัล/เหมืองแร่ (โซนความหายาก)

> เกมเก็บคริสตัลขาย: เดินหาก้อนแร่ กด E เก็บ (มีน้ำหนักกระเป๋าจำกัด) เอาไปขายเป็นเงิน
> เริ่มโปรเจ็ก 2026-08-05 ต่อจาก 74RB Animal Hospital

## ไฟล์ในโปรเจ็ก

| ไฟล์ | หน้าที่ | สถานะ |
|---|---|---|
| `75RB_ItemESP.lua` | ESP คริสตัล: ป้ายชื่อ+ราคา+☘โชค+ระยะ, กรอง T1-T6/Giant, เรียงแพง/ใกล้/โชค, TOP5 กดวาปไปได้, บินแบบ 74+noclip, กรองบ้านเพื่อน | v2.10 |
| `75RB_Assist.lua` | เก็บอัตโนมัติ: fireproximityprompt ก้อนแพงสุดในระยะ + Hold bypass + วัดเพดานระยะ, กรองบ้านเพื่อน | v1.6 |
| `75RB_HomeSpy.lua` | สปายแยกก้อนป่า vs ก้อนบ้าน: TOP20 path เต็ม + census ตามโฟลเดอร์แม่ + นับ prompt | v1.0 |
| `75RB_PickSpy.lua` | สปายจังหวะเก็บ: HoldBegan/Ended/Triggered + เวลา + เฝ้าก้อนหาย (พิสูจน์ server จับเวลากด) | v1.0 |
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
- **server จับเวลากดค้าง! (PickSpy 2026-08-05)** — `fireproximityprompt` + `Hold=0`
  โดนปัดเกือบหมดแม้ @3m (TRIGGER ไม่มีช่วงกดค้าง = โกง) ส่วนเก็บมือกดครบ Hold ✅ ทุกก้อน
  → **วิธีที่ถูก: `pp:InputHoldBegin()` → รอ `HoldDuration`+0.15 → `pp:InputHoldEnd()`**
  engine trigger เองเหมือนนิ้วกดจริง server แยกไม่ออก (Assist v1.7 / ESP warp v2.13)
- **ระยะ prompt จริงเล็กมาก**: `MaxActivationDistance` = 9-16m (ต่อก้อนไม่เท่ากัน)
  — ตั้งระยะ Assist ≤15 ผลดีสุด (ตัวเลข ❌37m/54m/65m ที่เคยเจอคือเกินระยะ prompt นั่นเอง)
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
- **ก้อนบ้านเพื่อน (จาก HomeSpy 2026-08-05)**: ตัวก้อนจริงชื่อ `Handle` อยู่ใต้
  `Things.Plots.Slots.<ชื่อผู้เล่น>.PlacedCrystals.Placed_2..6` — กรองชื่อ `Placed_*` เฉยๆ ไม่โดน!
  จุดชี้ตัวชัวร์: **ไม่มี ProximityPrompt เลย** (เก็บได้ 0/8) ส่วนก้อนป่ามี 1465/1467
  → กรอง 2 ชั้น: `not c:FindFirstAncestor("Plots")` + ต้องมี prompt เปิดอยู่ (ESP v2.10 / Assist v1.6)
  หมายเหตุ: มูลค่าก้อนโชว์บ้านโป่งเวอร์ ($3.5B) — attr `CE_Value=1`, บางก้อน `BombCrystal=true`
- มีก้อนตกพื้นจากผู้เล่น: `DroppedCrystals.DroppedCrystal_T6` — attr `Purchased`,
  `DroppedByUserId`, `DisplayName` — บางก้อนมี prompt เก็บได้จริง (ผ่านตัวกรองอัตโนมัติ)
- วาปไปก้อน: เปิดโหมดบิน (CFrame pin) ก่อนแล้วค่อยย้าย `FLY_POS` ไปเหนือก้อน +6 studs
  → ถึงแล้วลอยค้างเลย ไม่ร่วง ไม่โดนฟิสิกส์เตะ (ESP v2.9 TOP5 กดได้)
- executor นี้มี `hookmetamethod` ✅ (ดัก __namecall ได้)

## _G ที่ใช้ (กันชนกัน)

`IESP75_*` (ItemESP) | `AS75_*` (Assist) | `ISPY75_GUI` | `NSPY75_*` | `AS75_RANGE` (ค่าระยะแชร์)

## งานถัดไป

- [ ] หาเพดานระยะเก็บที่แน่นอน (ดูจาก `เพดาน: ✅x ❌y` ใน Assist)
- [ ] สปายการขาย → ทำ auto ขายเมื่อกระเป๋าใกล้เต็ม (ดู attr น้ำหนักรวมจากไหน)
- [ ] เช็คว่าโซนอื่น (บ้าน/เกาะพิเศษ) เก็บก้อนไว้ path ไหน ถ้าไม่ใช่ Things.Crystals
