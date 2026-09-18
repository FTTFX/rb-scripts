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
| `Egg01_PlaceSpy.lua` | ดักตอนวาง/ทิ้งไข่ (Prompt + RF + GUI) | v1.2 |
| `Egg01_ZoneSpy.lua` | ตัดสิน SAFE_DROP vs NEST_RECALL + สแกนโซน | v1.1 |
| `Egg01_Auto.lua` | v2.4: ทิ้งนอกโซนสีที่ขโมย / เขตปลอดภัย→วิ่งเข้า HOME | v2.4 |
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
- **คุณภาพ** — ไม่มีในสอง remote นี้ (อาจอยู่ GUI / `AskEggRecord` / Codex)

**ระยะ steal (fireproximityprompt):** สำเร็จได้ ~5–14 studs (MaxAct เกม = 8) → Auto ใช้ `STEAL_RANGE=16`

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

## ขั้นถัดไป

1. ~~spy + ZoneSpy~~ ✅  
2. ~~`Egg01_Auto` MVP~~ ✅ ผู้เล่นขโมยเอง → hop/drop/wait/steal จน HOME (วางคอกเอง)  
3. ปรับ `hopStuds` / `dropWait` ตามเทสต์จริง  
4. (ทีหลัง) วัด SafeZone Part แม่นกว่านี้

## Log อ้างอิง

- ZoneSpy 20:22 Desert: SAFE ~745 / ~645; `EggCarryBounds.SafeZone`  
- Auto: รอเทสต์ผู้ใช้  
- BF04 บนเกมนี้: ใช้ไม่ได้
