# 74RB — Animal Hospital (Roblox) — Developer Reference

เอกสารสรุปสำหรับนักพัฒนาต่อยอด สคริปต์ช่วยเล่นเกม **Animal Hospital** (แนว horror social-deduction: เป็นหมอรักษาคนไข้ NPC แต่บางตัวเป็นผีปลอมตัว/Skinwalker)

> สถานะ (v4.41, 2026-07-06): ใช้งานได้ครบ — ESP (ผี/ผีซ่อน/น่าสงสัย/คนไข้), Auto รักษา 1-8, เช็คอิน+ชัตเตอร์ (ปุ่มเดียว), ดับไฟ+ล้างสไลม์, ฆ่าผีด้วยยาผิด, whack + ปริศนาสี
> **อ่าน §10 ก่อนแก้อะไร — บทเรียน executor + กับดักที่เคยทำคนไข้ตายมาแล้ว**

---

## 1. ไฟล์ในโปรเจกต์

| ไฟล์ | บทบาท |
|---|---|
| `74RB_AnimalHospital.lua` | **สคริปต์หลัก** (main) — ESP/Speed/Noclip/Auto + GUI |
| `74RB_AnimalHospital_HookSpy.lua` | spy v5: hook remote (hookfunction/__namecall) + ProximityPrompt + Tool — หา flow เกม |
| `74RB_AnimalHospital_MedSpy.lua` | spy: dump คนไข้ (attr) + Medical rooms (Report/inv) + ยา + ตำแหน่ง (มี RESCAN) |
| `74RB_AnimalHospital_EmSpy.lua` | spy: dump Emergency Room6/7/8 + PlayerGui buttons (มี AUTO refresh) |
| `74RB_AnimalHospital_R6watch.lua` | (เลิกใช้/อ้างอิง) จับลำดับกะพริบปุ่มสี Room6 ด้วย event |
| `74RB_AnimalHospital_R6auto.lua` | (เลิกใช้/อ้างอิง) ต้นแบบ auto Room6 ก่อนรวมเข้า main |
| `gh_upload.py` | อัปทุกไฟล์ขึ้น GitHub (repo `rb-scripts`) — แก้เสร็จรันอันนี้ |

**โหลดในเกม** (ใช้ URL สำเนา `74RB_AH.lua` เป็นหลัก — ตัวเต็มเคยโดน executor cache ค้าง):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/FTTFX/rb-scripts/main/74RB_AH.lua?v="..tick()))()
```
เช็คหัว GUI ต้องขึ้นเลขเวอร์ชันล่าสุด (เช่น "AH74 v4.41") — ไม่ตรง = cache ค้าง รอ 1-2 นาทีรันใหม่

---

## 2. Game Internals (จาก reverse-engineer)

### 2.1 NPC / คนไข้ — `Workspace.NPCs.<ชื่อ>`
แยกชนิดจาก **attribute** (อ่านได้ฝั่ง client):

| attribute | ความหมาย |
|---|---|
| `Skinwalker=true` | **ผีปลอมตัว = อันตรายจริง** (จุดสังเกต: ตาเป็นเส้นแนวตั้ง) |
| `IsPatient=true` | คนไข้จริง |
| `Fake=true` | **ไม่ใช่ผี** — NPC ทั่วไป/visitor/พนักงาน (เช่น "Ron from Accounting") |
| `DesignatedRoom=RoomN` | ห้องที่คนไข้นี้ถูกจัดให้ |
| `InBed=true` | คนไข้นอนเตียงแล้ว (พร้อมวินิจฉัย) |
| `CompletedCheckIn=<ชื่อผู้เล่น>` | เช็คอินเสร็จแล้ว |
| `Treated`, `HealedAtleastOnce` | รักษาแล้ว |
| `CameraEffect` | ท่าโจมตีของผี (TwistNeck / SkinwalkerOpensMouth) |
| `Strikes` / `MAX_STRIKES` | จำนวนพลาด |

ESP จับ: `Skinwalker`→🔴, `IsPatient`→🟢, อื่นๆ→🟡 ; ผู้เล่น→🔵 (ทุกคน team=nil = ทีมเดียว)

### 2.2 ผู้เล่น
- `team=nil` ทุกคน (หมอด้วยกัน)
- attribute บน player: `Sanity`, `BonusSanity`, `SanityGainReason`, `SanityLossReason`, `PlayerColor`
- `leaderstats` = Folder

### 2.3 Remotes — Net framework (`ReplicatedStorage.Util.Net.RE/` , `RF/`)
ตัวที่เจอ: `RE/Quests`, `RE/Stats`, `RF/RequestData`, `RE/HeartbeatMinigameComplete`, `RE/ReviveOther`, `RE/Touch`, `RE/TaserFired` ฯลฯ
> **สำคัญ: การรักษา/quest ไม่ได้ใช้ remote** — เป็น **ProximityPrompt** ล้วน (จึงใช้ `fireproximityprompt`)

### 2.4 Flow การรักษา (Medical Room1-5) — ProximityPrompt chain
```
เช็คอิน (Workspace.Misc.CheckIn):
  Stamp Forms → Take Photo → Register → Print Badge → Take (PrintedBadge)
รักษา:
  Talk (NPCs.<name>.PP) → Take DNA Sample (NPCs.<name>.PP)
  → Analyze Sample (Rooms.Medical.RoomN.Minigame.Analyzer.PP)
  → Process Results (...Monitor.PP2)
  → [ดู "ยาที่ต้องใช้" จากจอ] → เก็บยา → Apply Treatment (Bed.InBed.PP)
```

### 2.5 ★ แหล่งข้อมูล "ยาที่ต้องใช้" (หัวใจของ Auto รักษา)
หลังวินิจฉัย จอ TV จะ list ยาที่ต้องใช้:
```
Workspace.Rooms.Medical.RoomN.Minigame.TV.Screen.UI.Report.inv.<ชื่อยา>
  .name (TextLabel) = ชื่อยา เช่น 'Medicine', 'Maple Syrup'
  .check (ImageLabel) = เครื่องหมายถูก → "ยาตัวนี้ถูกให้แล้ว" (.Visible)
.treatment (TextLabel) = 'TREATMENT: X/Y'
```
- โรค/ผล DNA: `Monitor.Screen.UI.Report.illnesses` (.Text), `.race` = ชื่อคนไข้
- **match ยาด้วยชื่อตรงๆ**: จุดเก็บยา = ProximityPrompt ที่ `ActionText == ชื่อยา`
- ยาทั่วไป: `Workspace.Model.Items.<ชื่อ>.PP` (Herbs/Eye Drops/Cough Syrup/Maple Syrup/Medicine...)
- ถังขยะ (ทิ้งยาเกิน): `Workspace.Trash.PP` (ActionText='Trash Item')
- **⚠️ ให้ยาผิด/ซ้ำเกินจำนวน = คนไข้ตาย + strike** → ต้อง match ชื่อ + นับจำนวนเป๊ะ

### 2.6 Emergency Rooms (6/7/8) — `room.attr Minigame=...`
| ห้อง | Minigame | กลไก |
|---|---|---|
| Room6 | `XRayRoom` | **Simon "Copy the sequence"** — ปุ่มสีกะพริบเป็นลำดับ กดตาม |
| Room7 | `HeartMonitorRoom` | **whack-a-mole** — กดเป้าดี เลี่ยงหัวกระโลก, มีเวลาจำกัด |
| Room8 | `SurgeryRoom` | เลือกอุปกรณ์ผ่าตัด (รองรับแล้ว — §8) |

> **⚠️ Room6 คนไข้ "ยืน" ไม่มีเตียง** — `Report.inv`/ยา **มีจริง** แต่ขึ้นหลังทำ X-ray เสร็จเท่านั้น (ตอน spy ก่อนวินิจฉัย inv ว่าง เลยเข้าใจผิดว่าไม่มี). flow: `Begin X-Ray`→ปริศนาสี(R6)→`Process Results`→ inv ขึ้นยา → เก็บยา → **Apply Treatment ที่ prompt บน "ตัวคนไข้" (อยู่ใน `Workspace.NPCs` ไม่ใช่ใต้ room)** → ต้องวาปไปใกล้คนไข้. ห้อง 7/8 prompt อยู่ที่ `Bed.InBed.PP` ใต้ห้อง ; **Room6 อยู่บน NPC** → `bedApplyPP` ต้อง fallback หาบนตัว `roomPatient(room)` (แก้ v2.5). เปิด **ปริศนาสี R6 + AUTO รักษา** พร้อมกัน

**ทั้ง 6/7/8 มี:** เตรียมคนไข้ลงเตียง (`Bed.InBed.PP2` = 'Prepare Patient'/'Sleep Patient'), สเต็ปเครื่อง ('Set Up','Turn On','Begin','Begin X-Ray'), เก็บผล ('Collect')

**Room6 ปุ่มสี** — `Room6.Minigame.Colors.<...>.Button` (สร้างตอนเริ่มเกม → ต้อง `DescendantAdded`):
- attr `MainColor` = สีปุ่ม, `ui.TextLabel` = เลข 1-6
- กะพริบ = `Part.Color` เด้งเป็น MainColor แล้ว fade → จับ peak ด้วย `GetPropertyChangedSignal("Color")` + เทียบใกล้ MainColor (sum-abs-diff < 0.08)
- สี: 1=แดง 2=เขียว 3=น้ำเงิน 4=เหลือง 5=ชมพู 6=ฟ้า
- กดปุ่ม: `fireclickdetector` > `fireproximityprompt(PP)` > VIM คลิก `cam:WorldToViewportPoint`

**Room7 whack** — `PlayerGui.Minigame.Frame`:
- เป้าดี = child name ≠ "Danger" (Template img `76833679466645`), visible
- ห้ามกด = "Danger" (img `2766332187` หัวกระโลก)
- กด = VIM `SendMouseButtonEvent` ที่ `AbsolutePosition + AbsoluteSize/2 + (0,36)` (เผื่อ topbar inset)

---

## 3. สถาปัตยกรรม `74RB_AnimalHospital.lua`

### 3.1 Single-instance guard
- `_G.AH74_CONNS` (table ของ connection), `_G.AH74_ESP` (Highlight), `_G.AH74_GEN` (gen token กัน loop เก่าซ้อนตอนรันใหม่)
- รันใหม่ = disconnect/destroy ของเก่า + เพิ่ม GEN → loop เก่าเห็น `_G.AH74_GEN ~= MYGEN` แล้วหยุด
- `bind(signal, fn)` เก็บ connection ลง CONNS อัตโนมัติ

### 3.2 State (toggles)
`ESP_ON, RUN_ON, NOCLIP_ON, AUTO_ON, KILLGHOST_ON, TP_ON, MACHINE_ON, WHACK_ON, R6_ON, CHECKIN_ON`, `SPEED`

### 3.3 Loops
| Loop | ที่อยู่ | ทำอะไร |
|---|---|---|
| `RS.Heartbeat` | bind | Speed(WalkSpeed) + Noclip(CanCollide) ทุก frame ; blind-fire เช็คอิน/วินิจฉัย ทุก 0.6s ; ESP refresh ทุก 0.4s |
| treat loop | `task.spawn` | วน Rooms (Medical+Emergency) เรียงระยะใกล้ → `treatRoom` |
| whack loop | `task.spawn` | คลิกเป้า `PlayerGui.Minigame.Frame` เลี่ยง Danger |
| R6 block | `do...end` + `task.spawn` | จับลำดับปุ่มสี (event) → คลิกตามลำดับ |

### 3.4 ฟังก์ชันสำคัญ (Auto รักษา)
- `getReport(room)` → `Minigame.TV.Screen.UI.Report`
- `roomDone(room)` → เสร็จ/recovering (Healing.Visible หรือ treatment X≥Y) → ข้าม กันวาปซ้ำ
- `medCounts(room)` → `need[ยา]=จำนวนต้องการ, given[ยา]=ให้แล้ว(จาก .check), order=ลำดับชนิด` (**รองรับของซ้ำ เช่นมีดผ่าตัด ×2**)
- `findPickup(ยา)` → ProximityPrompt ActionText==ชื่อ **ใกล้สุด**
- `heldCount(ยา)` / `findTool(ยา)` → นับ/หา Tool ที่ถือ
- `cleanInventory(needed)` → ทิ้งยาที่ไม่ใช่ของห้องนี้ (ไป Trash) กัน slot เต็ม
- `roomPatient(room)` → NPC ที่ `DesignatedRoom==room.Name`
- `tpTo(pos)` → วาป (TP_ON) หรือ เดิน `walkTo` (PathfindingService)
- `treatRoom(room)` → ดู §3.5
- `killWithWrongMed(room)` → โหมดผี: รอ Apply พร้อม → ให้ยาผิด 1 ตัว

### 3.5 ตรรกะ `treatRoom` (กันคนไข้ตาย)
```
1. roomDone? → ข้าม
2. คนไข้เป็นผี (Skinwalker)? → KILLGHOST_ON ? killWithWrongMed : ข้าม
3. ถ้ายังไม่มี inv (#meds==0): doDiagnosis (ไม่เช็ค InBed แล้ว — Room6 คนไข้ยืนก็ทำได้)
     - บนตัวคนไข้: Talk / Take DNA Sample
     - ในห้อง: Analyze Sample, Process Results (Medical) + Prepare/Sleep Patient, Begin X-Ray, Set Up, Turn On, Begin, Collect (Emergency 6/7/8)
     - ยิงเฉพาะ .Enabled (เกม gate ลำดับ) ; MACHINE_ON=ON วาปไปจุดเครื่องก่อนยิง / OFF ยิงในที่
     return
4. cleanInventory → เก็บยาให้ครบ (need-given) ต่อชนิด
5. กันตาย: ถือไม่ครบ → ไม่ Apply
6. ไปเตียง (Apply Treatment PP) → ให้ยาแต่ละชนิด "จนครบจำนวน":
     - เลือก slot ด้วยกดเลข (VIM SendKeyEvent One..Nine) จนเจอ Tool ชื่อตรง
     - กด Apply → poll ยืนยัน given เพิ่ม (สูงสุด 0.5s) ; ไม่เพิ่ม=ผิด หยุด
```
**กันตาย 3 ชั้น:** ให้ตามลำดับ + ชื่อตรงเป๊ะค่อยกด (หาไม่เจอ=ยกเลิก) + เช็ค given เพิ่มจริง

### 3.6 input เกม (วิธีคลิก/กด)
- เลือก slot hotbar: `VIM:SendKeyEvent(true/false, Enum.KeyCode.One..Nine, false, game)` (**เกมดู slot ที่เลือก ไม่ใช่ EquipTool**)
- ProximityPrompt: `fireproximityprompt(pp, 0)`
- คลิก GUI (whack): `VIM:SendMouseButtonEvent(x,y,0,true/false,game,0)`
- คลิก 3D part (ปุ่มสี): `fireclickdetector(cd)` หรือ `cam:WorldToViewportPoint` → VIM mouse

### 3.7 GUI
- Frame ลากได้ (`gethui()` หรือ PlayerGui), ปุ่มเรียงแนวตั้ง, helper `btn(txt,x,y,w,h,col)`
- ปุ่ม: ESP / RUN(+SPEED) / NOCLIP / AUTO รักษา / ผี→ยาผิด / ไปของ(วาป·เดิน) / วาปทำเครื่อง / ตีตัว(มินิเกม) / ปริศนาสี R6 / เช็คอิน / CLOSE
- CLOSE = ปิด toggle ทั้งหมด + คืน WalkSpeed/CanCollide + disconnect + เพิ่ม GEN

---

## 4. กลุ่ม Action (blind-fire)
- `CHECKIN_ACTS` (ปุ่ม "เช็คอิน"): Stamp Forms, Take Photo, Register, Print Badge, Take
- `TREATD_ACTS` (ปุ่ม "AUTO รักษา"): Talk, Take DNA Sample, Analyze Sample, Process Results, Prepare Patient, Sleep Patient, Set Up, Turn On, Begin, Begin X-Ray, Collect
- blind-fire ยิงเฉพาะ prompt ที่ `.Enabled` (เกม gate ลำดับเอง) — **ไม่รวมเก็บยา/Apply Treatment** (อันตราย ทำแยกใน treatRoom)
- ตอนเช็คอิน ยังยิง prompt บนตัว NPC ด้วย (มอบใบ = "พูดคุย"/Talk) ผ่าน `npcOwner(p)`
- **v6.23: ปุ่ม "รับผี" แยกจากปุ่ม "เคาน์เตอร์"** (`GHOSTCI_ON`, ผู้ใช้ขอ 2 ปุ่ม):
  - **ปิด (ปกติ, ค่าเริ่มต้น)** = พฤติกรรมเดิมทุกจุด: `checkinPending()` กรอง `Skinwalker`/`Anomaly` ออก + blind-fire ข้าม prompt **ทุกตัว**บนผี
  - **เปิด (รับผี)** = `checkinPending()` นับผีเป็นคิวเช็คอินด้วย + blind-fire อนุญาตเฉพาะ `CHECKIN_ACTS`/`Talk` บนผี — **ยังกัน `TREATD_ACTS` (DNA/วินิจฉัย/ฯลฯ) บนผีเด็ดขาดทั้ง 2 โหมด** (เช็ค `ghostOwner` แยกจาก CHECKIN_ACTS/npcStep) กันไม่ให้หลุดเข้า flow รักษาจริงที่จบด้วยจ่ายยา
- **v6.24/v6.27: โหมดรับผี — ยิงปืนรอเช็คอินเสร็จก่อน** (ผู้ใช้ขอ: เอาแต้มเช็คอินจากผีด้วย): `ghostWaitCheckin(m)` — ผีที่ยังไม่มี `CheckedIn`/`CompletedCheckIn` → `ghostToShoot` คืน false **ทุกระยะ** (ทั้ง gunPending และ loop ยิงหยุดรอ) ; พอเช็คอินเสร็จ attr ขึ้น → ยิงตามปกติ ; ยกเว้นผีที่ไม่มีวันเช็คอิน (`SkippedCheckIn`/`WasForceSpawnedByEvent`/`InBed`) ยิงได้ทันที ไม่รอเก้อ ; โหมดปกติ (GHOSTCI_ON=false) ไม่รอเลย (v6.24 เคยจำกัดโซนเคาน์เตอร์ 60 studs — ผีเดินมาจากไกลโดนยิงก่อนถึง เลิกใช้)

### ดับไฟ (คนติดไฟ) — toggle "ดับไฟ"
- คนติดไฟ = NPC attr `CustomPatientIntro=BurningPatient`, `CustomRoomAssigned=BurningRoom`, `FireCharges=N` (จำนวนเปลวที่ต้องดับ)
- prompt อยู่บนตัว NPC: `Workspace.NPCs.<ชื่อ>.FirePP` — ActionText วน `'Fire'`(ดับเปลว ใช้ FireCharges) → `'Treat Burns'`(รักษาแผล)
- **flow: ดับไฟ → ทาครีม** : `'Fire'` → `fp` ดับเปลว ; `'Treat Burns'` → ต้องถือ **`Ointment`** (ครีม, ที่ `Workspace.Model.Items.Ointment.PP`) → `findPickup("Ointment")` วาปเก็บ → เลือก slot → `fp` ทา
- `doBurning(pp)` จัดการตาม ActionText ; วนทุก 0.15s — **ไม่ใช้ถังดับเพลิง** (ถัง=tank `FireExtinguisher`:Activate เปลือง charge + ต้องเล็ง → ทิ้ง)
- **ไฟกองพื้น** = มี PP `'Put out fire'` (attr `Charges=N`) ที่ `Workspace.Rooms.Emergency.RoomN...Fire.Part` (หลายจุด) → `fp` ทุกจุดที่ `.Enabled` ใต้ `Workspace.Rooms` (ทุก 0.35s) — กด E ที่ไฟ **ไม่ใช้ถัง** (ถังเป็นทางเลือก method 2 ที่ทิ้งไป)
- ถัง `FireExtinguisher` (tank) = method 2 ไม่ใช้ (เปลือง charge + ต้องเล็ง)

### ชัตเตอร์ — toggle "เคาน์เตอร์" (ปิดผีปกติ) + ปุ่มแยก "รับผี" (`GHOSTCI_ON`)
- `Workspace.Misc.ShutterButton.PP` = ProximityPrompt, ActionText สลับ `'Open'`/`'Close'`
- **อ่านสถานะประตูจาก ActionText:** `'Close'`=เปิดอยู่(กด→ปิด) | `'Open'`=ปิดอยู่(กด→เปิด)
- logic (สแกนใกล้ `Workspace.Misc.CheckIn` <60 studs): คนไข้จริง/ผู้เยี่ยมยังไม่เช็คอิน + ActionText=='Open' → **เปิด**
- **v6.23: ปุ่ม "รับผี" แยกต่างหาก** (ผู้ใช้ขอ 2 โหมด):
  - `GHOSTCI_ON=false` (ปกติ, ค่าเริ่มต้น) → พฤติกรรมเดิม: ผี(Skinwalker) + ไม่มีคนดีค้างเช็คอิน + ActionText=='Close' → **ปิด**
  - `GHOSTCI_ON=true` (รับผี) → ตัดสาขาปิดออก ยิงเฉพาะตอนเปิดรอคนไข้เท่านั้น (ไม่ปิดใส่ผีเลย)

---

## 5. ESP
- `Highlight` (DepthMode=AlwaysOnTop ทะลุกำแพง) + `BillboardGui` ป้ายชื่อ+ระยะ
- refresh ทุก 0.4s: re-check attribute (ผีเปลี่ยนสภาพกลางเกมก็เปลี่ยนสี), ลบ ESP ตัวที่หาย
- `npcKind(m)`: Skinwalker→ghost, IsPatient→patient, else→npc

---

## 6. Movement
- Speed: บังคับ `Humanoid.WalkSpeed = SPEED` ทุก frame (กัน reset/respawn), ปิด=คืน 16
- Noclip: `BasePart.CanCollide=false` ทุก frame, ปิด=คืน true
- ไปของ: TP (CFrame) หรือ เดิน (PathfindingService + MoveTo + fallback เดินตรง)

---

## 7. Spy workflow (เครื่องมือ reverse)
ทุก spy = GUI บนจอ + ปุ่ม Copy (ไม่มี F9) ตาม `DW_SpyTemplate.md`:
1. **HookSpy** — เปิดในเกม จับ remote/prompt/tool ที่ถูกยิง (R:remote P:prompt T:tool)
2. **MedSpy** — dump คนไข้ + Medical rooms + ยา (วินิจฉัยก่อน → RESCAN → Copy)
3. **EmSpy** — dump Emergency 6/7/8 + PlayerGui buttons (AUTO refresh จับ active state)
> เทคนิค: ปุ่มมินิเกมสร้าง dynamic → ใช้ `DescendantAdded` ; flash เร็ว → ใช้ `GetPropertyChangedSignal` ไม่ใช่ polling

---

## 8. Room8 (SurgeryRoom) — ✅ รองรับแล้ว (v2.3)
**ข้อมูลเดิมผิด:** Room8 **มี `Report.inv` จริง** (path เดียวกับห้องอื่น `TV.Screen.UI.Report.inv`) แต่ต่างกัน 2 จุด → เลยพังก่อนแก้:
1. **สัญญาณเสร็จ:** `treatment='SURGERY:'` (ไม่มีเลข X/Y) → roomDone match ไม่ได้ ; ใช้ **`TV.Screen.UI.Healing.Visible`** (ฟื้นตัว) / **`.Failed.Visible`** (ผ่าล้มเหลว) แทน — Healing/Failed อยู่ที่ **UI ตรงๆ** (ไม่ใช่ใต้ Report) **ทุกห้อง**
2. **given count:** inv item ใช้ **attribute `Cured=true`** ต่อชิ้น (ไม่ใช่ `.check.Visible`) → `frameGiven` เช็ค Cured ก่อน fallback ไป check
- อุปกรณ์: `Room8.Minigame.Medicine.Model.<ชื่อ>.PP` ActionText ตรงชื่อ enabled=true (Scalpel/Antibiotics/Bandages/Medkit/Organ/Transplant/IV Drops/Scissors/Medicine)
- bed = `Bed.InBed.PP` ('Apply Treatment') / `PP2` ('Sleep Patient') ; `Bed.InBed.Attachment.UI.TextLabel` = HP เช่น '6☠️'
- flow ใช้ medCounts/treatRoom เดิม (collect ตามชื่อ → Apply → poll Cured) — ไม่ต้องแยกโค้ด Room8
- **v4.3 fix ความแม่นยำ:** ผ่าตัดต้องให้อุปกรณ์ **ตามลำดับบนจอ ที่สลับชนิดได้** (เช่น Scalpel→Bandages→Scalpel) — เดิมให้ "ทีละชนิดจนครบ" = ผิดคิว เกมไม่รับ → บอทหยุด/นับพลาด. แก้: `invFrames(room)` คืน frame เรียง LayoutOrder → ให้ทีละ frame, poll `frameGiven(fr)` ของชิ้นนั้นตรงๆ

### แก้ใน v2.3
- `getScreenUI(room)` ใหม่ → คืน `TV.Screen.UI` (getReport เรียกต่อ) ; roomDone เช็ค `UI.Healing`/`UI.Failed` ตรงๆ
- `frameGiven`: `Cured` attr มาก่อน `.check`
- EmSpy v1.1: dump `TV.Screen.UI` ทุก GuiObject + `.Visible` (จับ Frame เปล่า = สัญญาณเสร็จ)

### จุดที่อาจต้องจูนตาม executor
- VIM กดเลข/คลิก ติดทุก executor ไหม (ทดสอบ: Delta/Codex/Solara...)
- whack VIM click `+36` inset อาจต่างตามจอ/มือถือ
- timing: gap R6 (2.5s รอโชว์จบ), poll ยืนยัน (0.5s), wait ระหว่างให้ยา (0.2s)
- `roomDone`/`medGiven` เดาว่า `.check.Visible` = ให้แล้ว — ถ้าเกมใช้สัญญาณอื่นต้องปรับ

---

## 9. กฎการพัฒนา (สำคัญ)
- **แก้เสร็จ = อัปทันที** (`python gh_upload.py 74RB_AnimalHospital.lua 74RB_AH` — ระบุชื่อไฟล์ = อัปเฉพาะตัวนั้น เร็ว, ไฟล์ไม่เปลี่ยน = ข้ามอัตโนมัติ) ไม่ต้องถาม
- **อัป 2 ชื่อเสมอ**: `74RB_AnimalHospital.lua` + สำเนา `74RB_AH.lua` — executor ผู้ใช้ cache HttpGet ตาม URL (`?v=tick()` เอาไม่อยู่) ชื่อไหน cache ค้างให้สลับอีกชื่อ
- **bump เลขเวอร์ชัน 3 จุดทุกครั้ง**: หัวไฟล์ (comment), `title.Text "AH74 vX.Y"`, `setStatus` — เลขบนหัว GUI = ทางเดียวที่ผู้ใช้เช็คได้ว่าโหลดตัวใหม่จริง
- ทุกสคริปต์ต้องมี **single-instance guard** (`_G.<PREFIX>_CONNS` + `_G.AH74_GEN` token)
- ห้ามใส่ ping prediction (เกม client-sided hitreg)
- ของอันตราย (ให้ยา/Apply) = **ไม่ชัวร์ ไม่กด** (ยอมรักษาไม่จบ ดีกว่าฆ่าคนไข้)

---

## 10. ⚠️ บทเรียน v4.11-v4.41 (2026-07-05/06) — อ่านก่อนแก้

### 10.1 พฤติกรรม executor ของผู้ใช้ (จอ touch / มือถือ)
| เรื่อง | ความจริงที่พิสูจน์แล้ว |
|---|---|
| `fireproximityprompt` | **ยิงลง prompt ที่ตัวละคร "หันหน้าหา" ไม่ใช่ตัวที่ส่งเป็น argument** → ต้องหมุน HRP `CFrame.lookAt` เข้าหาเป้าก่อนยิงเสมอ (ทำแล้วใน `pressPrompt` + `click6`) |
| prompt กดค้าง (HoldDuration 0.2-1.0) | fp เฉยๆ โดนเมิน → **bypass: ตั้ง `pp.HoldDuration=0` → fp → คืนค่า** |
| VIM SendKeyEvent (กดเลข slot/กด E) | **ไม่ติดบนจอ touch** — เลือกของต้องมี `EquipTool` เป็น fallback ท้ายสุด (ดู 10.2) |
| VIM คลิกจอ / กด E ใส่ prompt | ห้ามใช้เป็น fallback ของ prompt — ไม่เลือกเป้า เคยคว้าของผิด/สแปมจนคนไข้ตาย (v4.15-4.17 ถอดทิ้งแล้ว) |
| `fireclickdetector` | เป้าแม่น (object-level) — เหตุที่ปุ่มสี R6 เคยแม่นในอดีต; เกมอัปเดตเพิ่ม PP บนปุ่มสี + path fcd อาจไม่มี → click6 ต้องหันหน้าก่อนเช่นกัน |

### 10.2 กันคนไข้ตาย (แก่นของทั้งสคริปต์)
- **สัญญาณ "Apply สำเร็จ" ที่ถูกต้อง = ยาหายจากมือ (`heldCount` ลด)** — เกม consume Tool ทันที; ติ๊กบนจอ (check/Cured) ขึ้นช้าตอนแลค **ห้าม**ใช้เป็นเกณฑ์กดซ้ำ (เคยกดซ้ำ=ยาเกิน=ตาย)
- ปุ่ม Apply Treatment **ไม่ดับหลังกดสำเร็จ** (ใช้ซ้ำทุกชิ้น) → default done ของ pressPrompt (prompt ดับ=สำเร็จ) ใช้กับ Apply ไม่ได้ ต้องส่ง done เอง
- **เลือกของ = กดปุ่ม slot 1-9 จริงก่อนเสมอ** (เกมอ่านช่อง hotbar ที่เลือก) → `EquipTool` เป็นทางสุดท้ายเฉพาะจอ touch ที่กดเลขไม่ติด — ปลอดภัยเพราะ done=ยาหายจากมือกันกดซ้ำ
- **v4.61 กฎถือทีละชิ้น (บทสรุปสุดท้ายของปัญหา slot):** จอ touch เลือกช่องไม่ได้จริง → ถือหลายชิ้น = slot/ของในมือเหลื่อม = จ่ายผิด → **หยิบ 1 จ่าย 1 ตามลำดับจอ** (ก่อนหยิบ ทิ้งทุกชิ้นที่ไม่ใช่เป้าลง Trash) — ช้ากว่านิดแต่ผิดไม่ได้ ; ใช้ทั้ง Medical และ Room8
- **v4.74 กุญแจล็อค `WORKING`:** ตอน treatRoom กำลังทำงาน (โดยเฉพาะจ่ายยา) loop อื่นทั้งหมด (สไลม์/ดับไฟ/อุ้มคนเป็นลม/blind-fire) **ห้ามลากตัว/ยิง prompt แทรก** — เคยโดนสไลม์เกิดกลางคิวผ่าตัด บอทบินไปล้างพร้อมยิง fp = จ่ายผิด (executor ยิงตามหน้าหัน) ; งานฉุกเฉินได้คิวทันทีที่ treatRoom รอบนั้นจบ (~วินาทีเดียว)
- **v4.68 ของซ้ำ:** เกมติ๊กใบไหนก็ได้ในจอ (ไม่เรียง) → เช็คความคืบ "รายชนิดแบบนับจำนวน" ไม่ใช่ราย frame
- **ชื่อยา: ใช้ `fr.Name` (อังกฤษ) นำเสมอ** — `.name.Text` โดนเกมแปลไทย ("น้ำเชื่อมเมเปิ้ล" vs Tool "Maple Syrup") ทำ match ไม่ติด บอทหยุดให้ยา
- ฆ่าผี (`killWithWrongMed`): หยิบ "ยาผิด" จาก `Workspace.Model.Items.*` เท่านั้น — ห้ามสแกน ActionText ทั้ง workspace (เคยคว้า 'Interact'/'Trash Item' มาเป็นยา = ล้มเงียบ)

### 10.3 กับดัก prompt/การวาป
- **'Inspect' ไม่ใช่สเต็ปรักษา** — เป็นปุ่มซูมกล้องเข้าจอ TV; ใส่ในลิสต์ act = กล้องล็อคติดจอ/จอรายงานค้าง **ห้ามใส่กลับ**
- `tpTo` มีการ์ด: เป้า `Y < -50` หรือไกล `>400 studs` = ไม่ไป (prompt/ของนอกแมพ) + `ghostSafe` ถอยห่างผี 12 studs + ใกล้เป้า ≤6 ไม่วาปซ้ำ (กันกระตุก) + ไม่วาปตอนตัวลอย
- **⚠️ เกมจับ teleport ระยะไกล → ลงโทษตาย "สุขภาพจิตหมด/บ้าคลั่ง"** (กล่องดำยืนยัน: ตายตอนวาปไกลโดยไม่มีผีใกล้, Sanity HUD ยังเต็ม) — v4.59 เปลี่ยนการเคลื่อนที่โหมดวาปเป็น **"บินทะลุเร็ว"**: ขยับ CFrame ~5 studs/frame (~300 studs/s, ทะลุกำแพงเพราะ set CFrame ตรง) + `AssemblyLinearVelocity=0` กันฟิสิกส์เหวี่ยง ; ก้าวเล็กต่อเนื่อง = เกมมองเป็นการเคลื่อนที่ปกติ
- ดับไฟ/สไลม์: รับเป้าเฉพาะ `<120 studs` จากตัวเรา — `Misc.Slime` ตอนไม่มีเหตุเกมจอดไว้นอกแมพแต่ PP ยัง Enabled (เคยวาปตามไปตกตาย) + จุดกดไม่เข้า cooldown 5s (กันวนค้างไม่กลับไปรักษา)
- เลือกห้อง: `hasWork()` — เอาเฉพาะห้องที่มี prompt งาน Enabled จริง/มียาต้องเก็บ (กัน commit ห้องเปล่า) ; **Room8 priority สูงสุด + เกาะจนจบ** (~60s) ห้องอื่นสลับทุก 1.6s

### 10.4 อัปเดตเกม ก.ค. 2026 — entity ใหม่
| ตัว | attr | จัดการ |
|---|---|---|
| **Hider** | `Anomaly=true + Skinwalker=true + WaterEntity=true` | ESP ม่วง "ผีซ่อน" ; วิธีกำจัดยังไม่ยืนยัน (คาด: ถังดับเพลิง — remote `RE/ExtinguisherBubbleHit*`) |
| **Ghost** | `Anomaly=true + Ghost=true + GhostVisible + Fake=true` (ไม่มี Skinwalker!) | ESP ม่วง — **เช็ค `Anomaly` ก่อน Skinwalker เสมอ** |
| **Slime** | `Workspace.Misc.Slime` attr `SpeedMod=0.5` (หน่วงขา+ดาเมจ บังเตียง) | PP `'Clean Slime'` กดทีเดียวหาย — auto ใน toggle ดับไฟ |
| **ผีปลอมไม่เฉลย** | มี `CameraEffect/PhotoEffect/Has*Effect` แต่ยังไม่มี Skinwalker | ESP ส้ม "น่าสงสัย!" — attr กลุ่มนี้เจอเฉพาะผี ไม่เคยอยู่บนคนไข้จริง |
| **NPC เนื้อเรื่อง** | `StoryForced=true` (Barney `CoffeeArcDay=N`, "???", 'Let him hide with you', 'Accept Suitcase') | ยังไม่ auto — ชื่อ NPC ทั่วไปสุ่ม ใช้ชื่อจับผีไม่ได้ |
| **คนเยี่ยมไข้ (Visitor)** | `IsVisitor=N + VisitingName + DesignatedRoom=ห้องที่มาเยี่ยม` (ไม่มี IsPatient) | **ต้องเช็คอินเหมือนคนไข้** (v4.52 ✅ ยืนยันทำงาน): checkinPending นับ IsVisitor เท่า IsPatient → วาปไปหา + blind-fire CHECKIN_ACTS ; ESP ฟ้า "เยี่ยมไข้" ; โต๊ะต้อนรับอยู่คนละช่องกับเช็คอิน → รัศมีเคาน์เตอร์ 60 studs ; ⚠️ roomPatient ต้องกรอง IsVisitor ทิ้ง (DesignatedRoom ชนกับคนไข้) |
| **ผี 'Ask to Leave'** | attr สะอาดหมด (ดูเหมือนคนไข้ปกติ!) แต่มี PP `'Ask to Leave'` | **ห้ามกด/ห้ามเข้าใกล้** — NPC blind-fire ยิงเฉพาะ `'Talk'` เท่านั้น (v4.49) ; ESP ใช้ prompt นี้เป็นตัวเฉลย → ส้ม "น่าสงสัย!" |
| **เคาน์เตอร์ช่อง 2** | `Misc.CheckIn2` (Camera/Form/Badge ชุดของตัวเอง) + คนไข้ attr `AsignedCheckIn=2` = ต้องไปช่อง 2 | v4.58: checkinPending เช็คระยะกับทุกช่อง (CheckIn/CheckIn2) รัศมี 15/ช่อง |
| **คนเป็นลม (faint)** | NPC ล้ม มี PP `'Carry'` (obj=spine.002 บนตัว) ; ตอนถูกอุ้มมี attr `CarriedBy=<userid>` ; ปุ่มวาง = **PP `'Place Patient'` (obj=Union, Hold 1.0) ที่เตียงของห้อง** (โผล่เมื่อกำลังอุ้ม) ; คนไข้และคนเยี่ยมเป็นได้ทั้งคู่ | v4.73 (อยู่ใน toggle **ดับไฟ** = งานฉุกเฉิน, treat loop หลีกทาง): บินไปหา → Carry → บินไปเตียง DesignatedRoom → Place Patient (done = CarriedBy หาย) ; ไม่มี DesignatedRoom → วางหน้าเคาน์เตอร์ |
| **เหตุการณ์ force spawn** | `WasForceSpawnedByEvent=true + SkippedCheckIn=true` ทั้งล็อต (ผีนอนเตียงเลย ไม่เช็คอิน) | เปิด "ฆ่าผี" (v4.54): **รักษาผีตามขั้นตอนครบเหมือนคนไข้จริง** (DNA/เครื่อง/วินิจฉัย — เกมบังคับ flow) แล้ว "หักมุมตอนจ่ายยา" = Apply พร้อมค่อยให้ยาผิดจาก Model.Items ; ห้ามไหลเข้า path เก็บ/ให้ยาถูก (จะรักษาผีหายฟรี) ; บาง event ผีมี `MedicineImmune=true` |

### 10.5 โครง pressPrompt / selectTool ปัจจุบัน (v4.41)
```
pressPrompt(pp, done):
  หัน HRP เข้าหา pp → HoldDuration=0 → fp → คืน Hold → poll done() ≤0.5s → คืน done()
  (done default = prompt ดับ — ใช้ได้เฉพาะ prompt one-shot; Apply/เก็บของต้องส่ง done เอง)
selectTool(m):
  ถืออยู่แล้ว → true | กด slot 1-9 (poll 0.25s/ช่อง) | EquipTool fallback (จอ touch)
```
- สถานะสดบนหัว GUI: `setStatus(s)` → "v4.41 รักษา Room3 / ดับไฟพื้น / ล้างสไลม์ / ว่าง / บล็อควาปเพี้ยน XXXm" — ใช้ไล่บัคกับผู้ใช้ได้เร็วมาก
- debug หลัก: `74RB_AnimalHospital_RoomDebug.lua` v1.3 (GUI+RESCAN+COPY) — dump NPC attrs + PP ทุกห้อง + INV + SLIME/ANOMALY scan
