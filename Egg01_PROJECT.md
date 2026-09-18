# Egg01 — Steal An Egg (ขโมยไข่)

> PlaceId: `107778070777162`  
> เกม: [Steal An Egg](https://www.roblox.com/games/107778070777162/Steal-An-Egg)  
> Dev: and Collect Rare Pets  
> เริ่มโปรเจกต์: 2026-09-17  
> สถานะ: **ยิบ = Prompt Steal + Hold bypass ได้ (`Hold=0` + `fireproximityprompt`)**

รัน: `loadstring(game:HttpGet("https://fttinvesting.com/rb/<ไฟล์>?v="..tick()))()`

## ไฟล์

| ไฟล์ | หน้าที่ | สถานะ |
|---|---|---|
| `Egg01_PickSpy.lua` | LIST remotes + hook FireServer/InvokeServer + ProximityPrompt | v1.0 |
| `Egg01_HoldTest.lua` | ทดสอบข้าม Hold ตอน Steal (fp / firesignal / InputHold / RF) | v1.1 |
| `Egg01_PlaceSpy.lua` | ดักตอนวาง/ทิ้งไข่ (Prompt + GUI) | v1.2 |
| `Egg01_ZoneSpy.lua` | SAFE_DROP vs NEST_RECALL + สแกนโซน | v1.1 |
| `Egg01_StealRangeSpy.lua` | วัดระยะ Steal + ดัมพ์ Carry/Shifted | — |
| `Egg01_RaritySpy.lua` | ค้น config/getgc สำหรับ map `AssetCategory→rarity` โดยตรง | v1.5 |
| `Egg01_Auto.lua` | เดินทิ้ง/เก็บ + GUI drop/pick + `STEAL_RANGE=16` | v3.3 |
| `Egg01_MoveSpy.lua` | ทดสอบกลับ HOME; HOP14 stable / HOP16 edge + ตรวจ rollback | v1.4 SAFE |
| `Egg01_UidStealTest.lua` | ทดสอบขโมยด้วย UID table / Snapshot row / EggCmds wrapper ทีละคำขอ | v1.0 |
| `Egg01_TreadmillAuto.lua` | หา TreadmillBottom ใกล้สุด → เดินไป → วิ่งบนเครื่อง 45 วินาที | v1.0 |
| `Egg01_InviteFriend.lua` | กรอก UserId เพื่อน → เปิด Roblox Invite Prompt ทางการ | v1.0 |
| `Egg01_SizeEPS.lua` | GUIDE auto-refresh; พับแผงได้; ไม่มี log บนจอ | **v2.5** |
| `Egg01_PROJECT.md` | เอกสารนี้ | — |

## เน็ตเวิร์ก

- โครง: `RS.Packages.Networking` แบบ `RF/<Service>/<Method>` / `RE/<Service>/<Method>`
- Hook ใช้ได้: `hookfunction` (จาก Egg01 report 2026-09-17)

## เป้าหลัก — ยิบ/วางไข่ (`EggWorld`)

### ยืนยันจากยิบมือ (2026-09-17 19:54)

| สิ่งที่เกิด | ค่า |
|---|---|
| Prompt | `act='Steal'` |
| Path | `Workspace.SmartPromptPart.CarryAreaEgg` (ProximityPrompt) |
| Hold UI | **1.2 วิ** |
| Remote ขาออกตอนยิบมือ | ไม่มี RF จาก client |

### Hold bypass (HoldTest 2026-09-17 19:57, dist 0.8)

| วิธี | ผล |
|---|---|
| **`HoldDuration=0` + `fireproximityprompt`** | ✅ `RE FieldEggCarry` + `FieldEggShifted` |
| `fireproximityprompt` ปกติ | ✅ |
| `firesignal(Triggered)` | ✅ |
| `InputHold` 0 / ค้างครบ | ❌ |
| `AskFieldEggCarry()` / Instance | ❌ `table expected, got nil` (`AreaEggs:2156`) |

**auto ยิบ:** ใกล้ไข่ → `pp.HoldDuration=0` → `fireproximityprompt(pp)` — ไม่ต้องค้าง 1.2  
**RF:** ต้องส่ง **table** (ยังไม่รู้คีย์ — ดัมพ์จาก `RE FieldEggCarry`)

### โครง table จากยิบจริง (PlaceSpy 2026-09-17 20:03)

### FieldEggCarry / Shifted — โครงยืนยัน (StealRangeSpy 2026-09-18)

`RE FieldEggCarry` (7 keys):
```
Uid, AssetCategory, AreaId, IsCarrying,
SpeedMultiplier, GuardDisabled, RunBackWakeDelayRequired
```
ไม่มี Quality / Rarity

`RE FieldEggShifted` (17 keys):
```
Uid, AreaId, AssetCategory, AssetScale, NestScale,
AssetColorIndex, AssetColorSeed, AssetEyeColor,
BoundsCFrame, BoundsSize, BottomCFrame,
HasParasite, Mutations, NestId, State, DroppedAt, Version
```
- **ขนาด** ≈ `AssetScale` (เช่น 0.91)
- **ชนิด** = `AssetCategory` (Catfish / Irihorus / …)
- **คุณภาพ** — ไม่มีใน Carry/Shifted/Snapshot และยังไม่มี mapping ที่ยืนยัน  
  - `RF AskFieldEggRarityShows` คืนเพียง `true`; ไม่คืนตาราง  
  - `WS.ClientRenderedAssets.<id>.Data.Odds` มีมอน/สัตว์ผู้เล่นปน จึงใช้จับคู่ไข่ด้วยระยะไม่ได้  
  - RE `FieldEggRaritiesShown` มีชื่อแต่ยังไม่ส่ง event หลัง listener ในการทดสอบ  
  - สัตว์ในคอก: ป้าย Billboard หลังฟัก (คนละระบบ)

**ระยะ steal (fireproximityprompt):** สำเร็จได้ ~5–14 studs (MaxAct เกม = 8) → Auto ใช้ `STEAL_RANGE=16`

**Uid ของไข่ (UidStealTest 2026-09-18):** มี 2 รูปแบบ
- ทั่วไป: hex 32 ตัว ไม่มีขีด เช่น `7a090fae2dfb47b694d8de1ed7a5bd4f`
- โซนแรก/FirstArea: `FirstAreaEgg_<asset>_<userId>_<Biome>:Slot_00N`  
  ตัวอย่าง: `FirstAreaEgg_9763090423_5965716_Forest:Slot_002`  
  → จับคู่ Odds hexUid กับไข่ FirstArea **ไม่ได้** ตรงๆ ต้องใช้ NestId+พิกัด

**วางไข่:** ปุ่ม GUI กลางจอตอนถือไข่ (ไอคอนวาง + ถังขยะ)

### Drop ระหว่างทาง (ยืนยันจากผู้เล่น + log 2026-09-17 20:11)

**ไม่ใช่ปุ่มผิด** — ทิ้งไข่กลางทางเป็นกลยุทธ์หลัก:

1. ขโมยไข่ → วิ่งกลับบ้าน  
2. มอนตามทัน → กด **`PG.DropHeldEgg.Button`** → ไข่ `State="Dropped"` ค้างที่จุดทิ้ง  
3. มอนกลับรัง → เก็บไข่จุดเดิม (`Steal` / carry อีกรอบ) → วิ่งต่อ  
4. วนข้อ 2–3 จนถึงบ้าน → **ค่อยวางลงคอก** (วิธียังต้อง spy ตอนถึงบ้านจริง)

หลัง Drop: ไม่เห็น RF ใน log — GUI `DropHeldEgg` พอ

### ZoneSpy v1.1 (2026-09-17 20:22) — Desert

| เหตุการณ์ | พิกัดผู้เล่นตอนทิ้ง | nestDist | ผล |
|---|---|---|---|
| Drop #1 | `745,71,-357` | ~178 | **SAFE_DROP** egg ค้างใกล้จุดทิ้ง |
| Drop #2 | `841,71,-342` | ~91 | SAFE ชั่วคราว → แล้ว `GuardCarried` → `Slot` (มอนเก็บกลับ nest) |
| Drop #3 | `645,71,-372` | ~278 | **SAFE_DROP** |

Nest Desert อ้างอิง: `946,68,-328` (`Slot_002`)

**โครงสร้างโซนในเกม (จาก ZONES scan):**

| Path | หมายเหตุ |
|---|---|
| `WS.__OBJECTS.Areas.EggCarryBounds.SafeZone` | Part ~`457,67,-364` — น่าจะโซนทิ้งได้ปลอดภัย |
| `WS.__OBJECTS.Areas.GuardAreas.<Biome>` | บ้านมอน (Forest/Lake/…) + `Nests` + `Guard` |
| `WS.__OBJECTS.Areas.StartArea` | ~`543,68,-363` |
| `WS.AreaEggSlotsClient.*` | สล็อตไข่ฝั่ง client |

สรุปกลยุทธ์: ออกจาก `GuardAreas.*` / เข้าใกล้ `EggCarryBounds.SafeZone` ก่อน Drop  
ระวัง: SAFE แล้วยังโดน guard มาเก็บได้ (`GuardCarried` → กลับ `Slot`) — ต้องรอไกล/มอนกลับก่อนค่อยวิ่งต่อ

### วางลงคอกที่บ้าน

ยังไม่ยืนยัน path  
ต้อง COPY ตอนไข่เข้าคอกสำเร็จ

เสียงรบกวน: `RVBillboard...` / `GamepadService...` ข้ามได้

### Remotes ที่เกี่ยวกับไข่ (จาก LIST)

| Remote | ชนิด | เดาหน้าที่ |
|---|---|---|
| `RF/EggWorld/AskFieldEggCarry` | RF | ต้อง **table** (`AreaEggs:2156`) — โครงยังไม่ยืนยัน |
| `RF/EggWorld/AskFieldEggDrop` | RF | ปล่อยไข่ที่ถือ |
| `RF/EggWorld/AskPlaceEgg` | RF | วางไข่ลงคอก — **ยังไม่เห็นตอนวาง** (อาจเป็น GUI ไม่ใช่ Prompt) |
| `RF/EggWorld/AskHatch` | RF | เริ่มฟัก |
| `RF/EggWorld/AskFinishHatch` | RF | จบฟัก |
| `RF/EggWorld/AskWearTool` / `AskDoffTool` | RF | ถือ/เก็บ tool |
| `RF/EggWorld/AskSkipGrowth` | RF | สกิปโต |
| `RF/EggWorld/AskLiveSnapshot` / `AskFieldEggSnapshot` / `AskEggRecord` | RF | sync สถานะ |
| `RE/EggWorld/FieldEggCarry` | RE | server แจ้งว่ามีคนถือไข่ |
| `RE/EggWorld/FieldEggShifted` / `FieldEggBatchShifted` / `FieldEggGone` | RE | ไข่ในฟิลด์เปลี่ยน/หาย |
| `RE/EggWorld/OwnerShifted` / `OwnerDropped` | RE | เจ้าของไข่เปลี่ยน |
| `RE/EggCapture/*` | RE | cutscene / standings ตอนขโมย |

## ที่เกี่ยวไข่แต่ไม่ใช่ยิบฟิลด์

| Remote | หมายเหตุ |
|---|---|
| `RF/Bloomery/AskLoadEgg` / `AskEjectEgg` | เตา mutate ไข่ |
| `RF/Codex/AskRedeemLimitedEgg` | redeem ไข่ limited |
| `RE/StaffConsole/GrantSelfEgg` | staff ให้ไข่ (อย่าใช้) |

## ระบบรอบตัวที่ต้องรู้ตอน auto

| กลุ่ม | Remote สำคัญ |
|---|---|
| Guard | `RE/GuardPatrol/Rouse`, `ForestStrike`, `SpeedTollWarning` |
| Base | `RE/Homestead/*`, `RF/PenRoster/*` |
| Speed | `RF/Treadmill/*`, `RE/Treadmill/SpeedGained` |
| Sell | Prompt ใกล้ฐาน: `WS.Stands.Prompts.SellHeldAsset` / `SellAll` |

## Prompt

- ยิบไข่: **`Steal`** @ `WS.SmartPromptPart.CarryAreaEgg` Hold **1.2**
- ขายที่ฐาน: `WS.Stands.Prompts.SellHeldAsset` / `SellAll`

## แผนลูปเล่น (อัปเดต — วาร์ปทีละช่วง)

กฎสำคัญ: **ในบ้านมอน / โซนเก็บ ทิ้งไม่ได้** — ไข่จะ **NEST_RECALL** วาปกลับ nest  
ต้องหลุดโซนก่อนค่อย Drop

```
steal (Hold=0+fp)
  → วาร์ปออกนอกโซนมอน (ระยะสั้น)
  → DropHeldEgg  → รอมอนกลับ
  → Steal ไข่จุดทิ้ง
  → วาร์ปเข้าใกล้บ้านอีกช่วง
  → Drop → รอ → เก็บ → ซ้ำจนถึงจุดเกิด/บ้าน
  → place ลงคอก (ยังต้อง spy)
```

## Size EPS / Rarity (ความรู้ยืนยัน 2026-09-18)

### แหล่งข้อมูลแยกกัน — อย่าผสมผิด

| ข้อมูล | แหล่ง | หมายเหตุ |
|---|---|---|
| ขนาด | `AssetScale` ใน Snapshot / `FieldEggShifted` | ใช้กรอง MinScale |
| ชนิดสัตว์ | `AssetCategory` | Catfish / Dog / … |
| พิกัดไข่ใน DB | `BottomCFrame` / `BoundsCFrame` | LiveSnapshot มักไม่มีพิกัด (pen) |
| **คุณภาพ (rarity)** | **ไม่ได้อยู่ใน Carry/Shifted/Snapshot** | ยังขาด mapping ที่พิสูจน์ได้จาก `FieldEggRaritiesShown` |

### ลำดับ rarity (ต่ำ→สูง)

`Common → Uncommon → Rare → Epic → Legendary → Mythic → Cosmic → Secret → Eternal → Divine`

### สมมติฐาน rarity เดิม — ถูกหักล้างโดยภาพทดสอบ v1.13

`Workspace.ClientRenderedAssets.*.Data.Odds` มีป้ายสัตว์/มอนของผู้เล่นปน ไม่ใช่ field egg list ล้วน ๆ
จึงห้ามใช้ตำแหน่งหรือชื่อ asset กลุ่มนี้เป็นเป้าไข่โดยตรงอีก

สิ่งที่ต้องจับครั้งเดียว: payload เต็มของ `RE/EggWorld/FieldEggRaritiesShown`
หลังเรียก `RF/EggWorld/AskFieldEggRarityShows` เพื่อหา UID/record key ที่เชื่อมกับ `AskFieldEggSnapshot`

### บั๊กที่เจอแล้ว + วิธีแก้ใน SizeEPS

| อาการ | สาเหตุ | แก้ (v1.9→v1.10) |
|---|---|---|
| Odds=91 แต่ `จับคู่=0` / rar=`?` | จับคู่ Odds→eggDB ด้วย uid/ระยะล้มเหลว | **เป้า GUIDE จากพิกัด Odds โดยตรง** ไม่พึ่ง uid |
| GUIDE ไม่ขึ้นตอนติ๊ก Ete | ไม่มี Eternal ในแมพ / หรือ rar ยัง `?` | ดู hist `Leg=/Myt=/Ete=` แล้วติ๊กให้ตรง |
| ติ๊ก rarity ปิดหมดแล้วยังชี้ | เคย fallback scale-only | ต้องติ๊กอย่างน้อย 1 |
| เส้นชี้ Mythic `sc=0` ของเพื่อน/สัตว์โชว์ | Odds มีทั้งไข่รัง + ป้ายโชว์; sc ว่างยังผ่าน | **v1.10:** เก็บเป้าเฉพาะ **ใกล้ Prompt `Steal` ≤32** และ **บังคับ `scale ≥ MinScale`** (sc ว่าง/0 = ทิ้ง) |

### กติกา SizeEPS v2.4 SAFE

1. SCAN ใช้ `AskFieldEggSnapshot` เท่านั้นสำหรับไข่จริง  
2. พิกัด = `BottomCFrame/BoundsCFrame`, ขนาด = `AssetScale`  
3. จับคู่ไข่↔Prompt Steal แบบ one-to-one จากระยะใกล้สุด  
4. GUIDE หลายเส้นชี้เฉพาะ record ไข่จริง; NEAR/MAX กรองด้วย MinScale  
5. Snapshot ใหม่แทนที่ฐานเดิมทั้งก้อน ป้องกันรายการค้างสะสม 60→115  
6. Rarity อ่านจาก runtime config โดยตรง: `AssetCategory → Config.Rarity._id`  
7. เลือก rarity ได้หลายระดับด้วยปุ่มสี; สี Beam/ป้ายตรงกับระดับไข่  
8. START กรอง `MinScale + rarity ที่เลือก` แล้วยิง Prompt ที่จับกับไข่จริง  
9. อัปโหลด: `python gh_upload.py Egg01_SizeEPS.lua`

### แก้บั๊ก v1.11

- แก้ callback ปุ่ม rarity ที่อ้าง `say` / `updateGuide` ผิด scope จนกดแล้วเรียก global `nil`
- GUIDE ไม่สแกน network จาก `RenderStepped` อีก ป้องกัน `InvokeServer` และ `task.wait` ซ้อนทุกเฟรม
- SCAN / GUIDE / START โหลด Snapshot ก่อนจับคู่ Odds เพื่อให้ `AssetScale` พร้อมก่อนสร้างเป้า
- START ไม่ยอมให้ไข่ที่ไม่มี `AssetScale` ผ่าน `MinScale > 0`
- เก็บเป้าที่ผ่าน Steal+scale ทุก rarity แล้วกรองตอนใช้งาน ทำให้ติ๊กเปิด rarity ใหม่มีผลโดยไม่ต้องสแกนซ้ำ

### แก้บั๊ก v1.12

- Log v1.11 พบ `Odds=68`, `Steal=60`, `noScale=0` แต่ `noSteal=68`: ข้อมูลมีครบ แต่พิกัด `ClientRenderedAssets` ไม่ตรง Prompt
- หลังจับ Odds ด้วย UID ใช้ `eggDB.BottomCFrame/BoundsCFrame` เป็นตำแหน่งเทียบ Steal แทนตำแหน่งโมเดล render
- จำกัด fallback จับคู่ด้วยพิกัดจาก 120 เหลือ 24 studs ลดการเอา rarity ของไข่คนละใบ
- เพิ่ม log `match uid= / pos= / none=` สำหรับตรวจคุณภาพการจับคู่ในแต่ละเซิร์ฟเวอร์

### แก้บั๊ก v1.13

- ถ้า UID/Prompt จับคู่ไม่ได้ GUIDE ยังใช้ตำแหน่ง Odds โดยตรงแบบ rarity-only (`sc=?`)
- GUIDE วาดเส้นเพิ่มได้สูงสุด 18 เป้าที่ใกล้สุด ตาม rarity ที่ติ๊ก
- เป้าที่จับคู่ไม่ได้มีไว้บินตามเส้นเท่านั้น; START ยิงเฉพาะเป้าที่ `autoReady` เพื่อกันขโมยผิดใบ
- Log เปลี่ยน `keep` เป็น `guide`; `noSteal/noScale` เป็นสถานะของระบบ auto ไม่ได้ทำให้เส้น rarity-only หาย

### Rebuild v2.0

- ลบ pipeline Odds/ClientRenderedAssets ออกจาก SizeEPS ทั้งหมด เพราะชี้มอน/สัตว์ของผู้เล่น
- สร้างใหม่จาก FieldEggSnapshot + FieldEggShifted ซึ่งยืนยันว่าเป็นไข่จริง
- Rarity ปิดอย่างซื่อสัตย์จนกว่าจะได้ payload `FieldEggRaritiesShown` จาก RaritySpy v1.3

### v2.1 — หลังผล RaritySpy v1.3 (ยกเลิก)

- `AskFieldEggRarityShows()` คืนเพียง boolean `true`; ไม่มี `FieldEggRaritiesShown` หลัง listener เริ่มทำงาน
- ใช้หลักฐานจำนวน Odds≈58 / field eggs≈60 และระยะเดิม ≤120 สร้าง global nearest one-to-one assignment
- ทดสอบจริงพบ match เพียง 5/93 และห่างเฉลี่ย ~111 studs จึงหักล้างสมมติฐานนี้; ห้ามใช้ชื่อ rarity ที่ได้จากวิธีนี้

### v2.2 — ตัด rarity เดาระยะ

- คงพิกัด/ขนาดจาก FieldEggSnapshot และ Prompt ที่ match 0.0 studs ซึ่งยืนยันว่าเป็นไข่จริง
- ลบ Odds→ไข่ spatial rarity assignment ออกจาก runtime
- แก้ฐาน snapshot ค้าง: replace ฐานทุกครั้งแทน merge อย่างเดียว
- `Egg01_RaritySpy.lua v1.4` สแกน `getgc`/loaded modules เพื่อหา `AssetCategory→rarity` จาก config โดยตรง

### v2.3 — พบ rarity config โดยตรง

- RaritySpy v1.4 พบ record ที่มี `AssetCategory` และ `Config.Rarity._id` ครบชนิดใน Snapshot เช่น `Burrowing Owl→Rare`, `Centapede→Epic`, `Mammoth→Mythic`
- SizeEPS สแกน `getgc(true)` แล้วอ่านเฉพาะ `Config.Rarity._id`/`Rarity._id`; ไม่รับ `AreaId=Cosmic` และไม่ใช้ตำแหน่ง Odds
- RaritySpy v1.5 จำกัด detector ให้รับเฉพาะคีย์ Rarity/Tier/Quality ป้องกัน `AreaId` เป็น false positive

### v2.4 — สี rarity + multi-select

- เปลี่ยนช่องพิมพ์ MinRarity เป็นปุ่มเลือก `Common…Divine` เปิดพร้อมกันหลายระดับได้; ค่าเริ่มต้น Epic ขึ้นไป
- สีเส้นและป้ายใช้สีประจำ rarity; เป้าอันดับหนึ่งเด่นด้วยความหนาแทนการบังคับเป็นสีเหลือง
- ปุ่ม `ALL` เปิด/ปิดทุกระดับ และ log แสดงรายการระดับที่เลือก
- เพิ่มระยะแสดงป้ายจาก 1,200 เป็น 6,000 studs และแก้ status หลัง SCAN ให้กลับมาแสดงเป้าอันดับหนึ่ง

```lua
loadstring(game:HttpGet("https://fttinvesting.com/rb/Egg01_SizeEPS.lua?v="..tick()))()
```

### สิ่งที่ยังไม่นิ่ง

- จับคู่ Odds hexUid ↔ FieldEgg `Uid` ไม่เสถียรทุกเซิร์ฟ — ใช้พิกัด+Steal เป็นหลัก  
- ไข่เพื่อนที่มี Steal จริงยังเข้าเป้าได้ (เกมออกแบบให้ขโมยฐานคนอื่น) — ถ้าต้องการยกเว้นเพื่อน ต้องมีรายชื่อ/พิกัดฐานเพิ่ม  
- วางไข่ลงคอกที่บ้าน: path ยังไม่ยืนยัน

## ขั้นถัดไป

1. ~~spy + ZoneSpy + rarity Odds~~ ✅  
2. ~~Auto walk-drop + SizeEPS GUIDE~~ ✅  
3. เทสต์ v1.10: SCAN ต้องมี `keep>0` และเส้นไม่ชี้ sc=0  
4. (ทีหลัง) กรองยกเว้นฐานเพื่อน / วัด SafeZone แม่นกว่านี้

## Log อ้างอิง

- ZoneSpy 20:22 Desert: SAFE ~745 / ~645; `EggCarryBounds.SafeZone`  
- RaritySpy: Odds ที่ `ClientRenderedAssets.*.Data.Odds`  
- SizeEPS v1.9: Odds อ่าน=91 พิกัด=91 | Unc/Epi/Leg/Myt/Cos/Sec/Ete  
- SizeEPS v1.13: รองรับ rarity-only หลายเส้นเมื่อ UID/Prompt จับคู่ไม่ได้; START ยังล็อกความปลอดภัย  
- BF04 บนเกมนี้: ใช้ไม่ได้
