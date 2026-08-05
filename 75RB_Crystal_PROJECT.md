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
| `75RB_DeepSpy.lua` | ดักขาไป+ขากลับ (OnClientEvent ทุก remote) + LIST ชื่อเข้าเค้า — ตัวเจอ CrystalHoldComplete | v1.0 |
| `75RB_BagSpy.lua` | ดัมพ์ attrs/Values ทั้ง Player + GUI "x / y" — ตัวเจอที่เก็บน้ำหนัก/เงิน | v1.0 |
| `75RB_AutoFarm.lua` | ฟาร์มครบวงจร: วาปเก็บก้อนแพงสุด → กระเป๋าถึง % → วาปขายที่ SellWorker → วน | v1.1 |
| `75RB_SellSpy.lua` | แกะเมนูขาย: ดัมพ์ต้นไม้ GUI dialog/Sell + ปุ่มกดขายด้วย firesignal | v1.1 |
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

- **เก็บของ = รีโมตตรง! (DeepSpy 2026-08-05)** — เก็บมือจริงๆ client ยิง
  **`RS.Remotes.CrystalHoldComplete:FireServer(<ก้อน MeshPart>)`** หลังกดครบ
  → บอทยิง remote นี้ตรงๆ เลย ไม่ต้องกดค้าง (Assist v2.0 / ESP warp v2.15)
  (NetSpy รอบแรกเห็นว่าไม่มี remote — ตอนนั้นดักก่อนเกมอัปเดต/พลาด — ความจริงมี)
- ประวัติทางตัน (กันเดินซ้ำ): `fireproximityprompt`+`Hold=0` เคยใช้ได้ยุคแรก → โดนอุด
  (server เท TRIGGER ที่ไม่มีช่วงกดค้าง แม้ @3m) | `InputHoldBegin/End` กดค้างจริงก็ยังไม่เข้า
  (user รายงาน "กดค้างไม่นานพอ") → จบที่ยิงรีโมตตรง
- ขากลับตอนเก็บสำเร็จ: `CrystalMinePrompt(part,false)` → `CrystalMineFX("hit",part,progress,
  userId,n1,n2)` → `CrystalMineFX("end")` → `CrystalPickupJuice(part,true)` → `IndexDiscover`
  → `Notify` — สังเกต MineFX มีเลข progress อาจต้องยิงหลายทีถ้าก้อนใหญ่ (T3 ทีเดียวหาย)
- remote น่าสนใจอื่น: `SellOpen/SellRequest/SellResult` (ขาย!), `TakeOutCrystal/
  TakeOutAllCrystals`, `CrystalDropRequest/CrystalDroppedPickup`, `LuckEventSync`,
  `RadarDropRequest`, `PlotPlacePickup`
- ระยะ prompt จริง `MaxActivationDistance` = 9-16m — แต่ยิงรีโมตตรงอาจไม่ติดลิมิตนี้ (รอวัด)

## ที่เก็บข้อมูลผู้เล่น (BagSpy 2026-08-05)

- น้ำหนักกระเป๋า (จอ): GUI `PlayerGui.ExplorerHud.BackpackPanel.Value` = `'656.0 / 1237.0 kg'`
- เพดาน: `LP.PlayerData.RealStats.CarryWeight` | เงิน: `RealStats.Cash` (NumberValue)
- ของในกระเป๋า: `LP.PlayerData.Inventory.Crystals.Crystal_*` (RayValue + attr Value/WeightKg ครบ)
- ของวางที่บ้านเรา: `LP.PlayerData.PlotData.Crystals.*` (แยกจากกระเป๋า)
- stat อื่นน่าสนใจ: `PlotLuck`, `LuckBoostRemaining`, `CurrentAir/AirCapacity` (ระบบอากาศ!),
  `JetpackFuel` (attr บน LP), `TrustedTeleport` (attr — เกมมีระบบเช็ควาป?), `SellCount`
- ร้านขาย = Model ชื่อ `SellWorker` ใน workspace (เดินใกล้ → server ยิง `SellOpen` มาให้)
- **การขาย (SellSpy 2026-08-05)**: ยิง `SellRequest:FireServer(...)` ตรงๆ **ไม่ได้ผลทุกรูปแบบ**
  (ยิงออกจริงแต่ server เท — ต้อง "เลือกในเมนู" จริงเท่านั้น)
  วิธีที่ได้ผล: เดินใกล้ NPC `SellWorker` → server ส่ง `SellOpen` → เมนูโผล่เป็น GUI ชื่อ
  **`PlayerGui.dialog`** → `dialogResponses.1` = "Sell all crystals" (`.2` = ขายอันเดียว)
  → **`firesignal` ทุกสัญญาณใส่ตัวเลือก 1 + พ่อทุกชั้น + `Sell.Frame.Sell`** → ขายเข้า ✅
  (พิสูจน์แล้ว: กระเป๋า 2.3 → 0.0 kg) — executor นี้มี `firesignal` ✅
  บางครั้งต้องกดซ้ำ 2-3 ที (เมนูอาจยังไม่ทันเปิด) → AutoFarm v1.1 ลองสูงสุด 5 รอบ
- **ยิง `CrystalHoldComplete` เปล่าๆ เลิกได้ผลแล้ว** (2026-08-05 รอบหลัง) — ยิง 10 ครั้ง
  ก้อนไม่ขยับเลย ทั้งที่กดมือ E เข้าปกติ → server เช็คมากกว่าแค่ remote
  **ท่าที่ได้ผล: ยืน "ระดับเดียวกับก้อน" (ไม่ใช่ลอยเหนือ!) แล้วกดค้าง prompt จริง**
  พิสูจน์จาก log: `✅ เข้า! ท่า [ระดับเดียวกัน N + prompt/both]` ทุกครั้ง
- **เช็คว่า "ปุ่มติด" ได้ด้วย `ProximityPromptService.PromptShown/PromptHidden`** — เกมโชว์ปุ่ม E
  = อยู่ในระยะ+มองเห็นจริง → วาปวน 8 มุมรอบก้อน ติดค่อยกด ไม่ติดวาปต่อ (AutoFarm v1.5)
- **ยืนยันการเก็บต้องดู "น้ำหนักกระเป๋าเพิ่ม" ไม่ใช่ "ก้อนหายจากแมพ"** — FX ลบก้อนออกก่อน
  ของเข้ากระเป๋าจริง ถ้าวาปหนีทันทีที่ก้อนหาย = ของหลุด (AutoFarm v1.2 แก้แล้ว: รอ kg เพิ่ม
  + รอ "ถึงก้อนจริง" ด้วยการเช็คระยะก่อนยิง ไม่ใช่ task.wait เวลาคงที่)
- **จุดขายตัวจริง (SellSpy v1.4)**: `Workspace.Things.SellProx.ProximityPrompt`
  Action='Sell Crystals' Obj='Crystal Buyer' **Hold=0 Max=10** Style=Custom
  ⚠ **ไม่ได้อยู่ใต้ Model `SellWorker`** — ค้นใต้ SellWorker จะได้ prompt=false (AutoFarm v1.7 พลาดตรงนี้)
  → หา prompt ด้วย `ActionText:find("sell")` ทั้ง workspace แล้ววาปไปหา "พาร์ตพ่อของมัน" ระยะ ≤10
- **เมนูตัวเลือก = ImageButton** ที่ `PlayerGui.dialog.dialogResponses.1` (Active=true)
  1=ขายทั้งหมด 2=ขายอันเดียว 3=ราคา 4=ลาก่อน (ช่อง 5-9 คือ 'temp text' ตัวสำรองที่ซ่อนไว้)
  ⚠ GUI `dialog` **มีอยู่ตลอดเวลา** — เช็ค "เมนูเปิดไหม" จากการมีอยู่ของมันไม่ได้
- **เลข 1-4 ในเมนูไม่ใช่คีย์ลัด** — ContextActionService ไม่มี action ผูกเลขพวกนี้เลย
  ยิงคีย์ '1' (VirtualInputManager/keypress) ไม่มีผล แถมไปสลับช่องไอเทมแทน
- บทเรียน: อย่ากรอง GUI ด้วย "ชื่อมีคำว่าขาย" — ตัวจริงชื่อ `dialog` / `1` เฉยๆ ต้องดัมพ์ต้นไม้ดู
- การขาย: ยังไม่ได้สปาย (รอ user ขายมือ 1 ครั้งพร้อม NetSpy เปิด)

## บทเรียน/กับดัก

- **อย่า cache โฟลเดอร์ `Things.Crystals`** — เกมสร้างใหม่ตอนวาร์ปโซน/กลับบ้าน ตัวแปรเก่า
  ชี้ที่ว่าง → ขึ้น 0/0 ก้อน ต้อง FindFirstChild ใหม่ทุกรอบสแกน (แก้แล้ว ESP v2.4 / Assist v1.3)
- แมพมีคริสตัล ~2,000 ก้อน — ติดป้ายหมดจอแตก+เลค ต้องจำกัด (MAX_SHOW 150 / TOP5 only)
- ก้อนที่ยิง fp ไม่เข้า (ไกลเกิน) ต้อง blacklist ชั่วคราว 8 วิ ไม่งั้นบอทยิงก้อนเดิมซ้ำไม่ไปไหน
- ระยะเก็บใช้ร่วมกัน 2 สคริปต์ผ่าน `_G.AS75_RANGE` (ซิงก์สองทาง Assist ↔ ItemESP)
- **ค่าโชค (Luck) ไม่มีใน Attributes** — มีแค่เป็นข้อความใน TextLabel ของ `CrystalHover`
  **ป้ายแปลตามภาษาเครื่อง!** ("Luck: +6.0%" / "โชค +2.9%") — อย่าจับคำ ให้จับ pattern
  `%+%s*([%d%.]+)%%` (+ตัวเลข%) แทน และอย่าแคชค่า 0 (ป้ายก้อนไกลโหลดช้า) — ESP v2.17
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
