# 74RB — Animal Hospital (Roblox) — Developer Reference

เอกสารสรุปสำหรับนักพัฒนาต่อยอด สคริปต์ช่วยเล่นเกม **Animal Hospital** (แนว horror social-deduction: เป็นหมอรักษาคนไข้ NPC แต่บางตัวเป็นผีปลอมตัว/Skinwalker)

> สถานะ: ใช้งานได้ — ESP, Speed, Noclip, Auto รักษา (Medical 1-5 + Emergency 6/7), มินิเกม whack + ปริศนาสี, แยกเช็คอิน/รักษา. **ค้าง: Room8 (Surgery) ยังไม่รองรับ** (ดู §8)

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

**โหลดในเกม** (loadstring + `?v=tick()` กัน cache):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/FTTFX/rb-scripts/main/74RB_AnimalHospital.lua?v="..tick()))()
```

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

> **⚠️ Room6 ไม่มียา/Bed/Apply Treatment เลย** (ยืนยันจาก spy 2 รอบ: ไม่มี `Bed`, ไม่มี `Medicine.Model`, `Report.inv` ว่าง) — **รักษาด้วยปริศนาสีล้วน** flow: `Begin X-Ray`→ปริศนาสี→`Process Results`→`Collect`. บอทจบ Room6 ต้องเปิด **ปริศนาสี R6 + AUTO รักษา** พร้อมกัน (ไม่มีขั้นเก็บยา) ; ตรงข้ามกับ Room7/8 ที่มี Apply Treatment + ต้องให้ยา

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
3. medCounts; ถ้ายังไม่มี inv (#order==0):
     คนไข้ InBed → doDiagnosis (Talk/DNA ที่ตัว + Analyze/Process ในห้อง)
       MACHINE_ON=ON วาปไปก่อนยิง / OFF ยิงในที่
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
- **แก้เสร็จ = อัปทันที** (`python gh_upload.py`) ไม่ต้องถาม
- ทุกสคริปต์ต้องมี **single-instance guard** (`_G.<PREFIX>_CONNS`)
- ห้ามใส่ ping prediction (เกม client-sided hitreg)
- โหลด GitHub raw + `?v=tick()` กัน cache
- ของอันตราย (ให้ยา/Apply) = **ไม่ชัวร์ ไม่กด** (ยอมรักษาไม่จบ ดีกว่าฆ่าคนไข้)
