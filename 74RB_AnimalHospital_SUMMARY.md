# 74RB — Animal Hospital — สรุปงาน + องค์ความรู้ (v5.00)

สคริปต์ช่วยเล่น **Animal Hospital** (Roblox horror social-deduction: เป็นหมอรักษา NPC สัตว์
บางตัวเป็นผี **Skinwalker** ปลอมตัวมา — รักษาผิดตัว/โดนผีหลอก = ตาย)

> เอกสารเทคนิคเชิงลึก (โครง workspace, ชื่อ prompt ครบ): [74RB_AnimalHospital_PROJECT.md](74RB_AnimalHospital_PROJECT.md)

## โหลดในเกม (บรรทัดถาวร — ไม่ต้องเปลี่ยนอีก)
```lua
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/FTTFX/rb-scripts@main/74RB_loader.lua"))()
```
loader จะดึง commit ล่าสุดจาก GitHub API → โหลดสคริปต์จริงผ่าน jsDelivr (pin SHA = สดเสมอ)
→ fallback raw.githubusercontent 2 ชั้น **ห้ามโหลด raw ตรงด้วย `?v=tick()` ถี่ๆ** — โดน 429 rate limit มาแล้ว

---

## 1. สถาปัตยกรรม (อ่านตรงนี้ก่อนแก้โค้ด)

ไฟล์เดียว `74RB_AnimalHospital.lua` (~1,700 บรรทัด) ประกอบด้วย **task.spawn loop อิสระ ~8 ตัว**
คุยกันผ่าน flag ส่วนกลาง:

| Loop | หน้าที่ | gate สำคัญ |
|---|---|---|
| Heartbeat | ESP + RUN + NOCLIP + blind-fire prompt เช็คอิน/วินิจฉัย | `WORKING` |
| Treat | เลือกห้อง → วินิจฉัย → เก็บยา → จ่ายยา | `faintPending/firePending/slimePending` หลีกทางงานฉุกเฉิน |
| Carry | อุ้มคนเป็นลมไปวางเตียง | ตั้ง `CARRYING` ล็อคทุก loop อื่น |
| Fire-NPC | ดับไฟบนตัว NPC (Extinguish/Treat Burns) | `not CARRYING and not faintPending()` |
| Fire-floor | ดับไฟกองพื้น + ล้างสไลม์ | เดียวกัน + เช็คซ้ำ "ทุกกอง" |
| Shutter | ปิดชัตเตอร์ใส่ผี / เปิดรอคนไข้ | `not CARRYING` |
| Whack / R6 | มินิเกม Room7 / ปริศนาสี Room6 | — |

**ลำดับความสำคัญ (แข็งตัวในโค้ด):** คนเป็นลม > ไฟ > สไลม์ > รักษา > เช็คอิน

**Mutex 3 ตัว:** `WORKING` (กำลังจ่ายยา — ห้าม blind-fire แทรก), `CARRYING` (กำลังอุ้มคน —
ห้ามทุกงานแทรกจนวางเสร็จ), `TREAT_BUSY` (treat loop มีห้องทำอยู่)

**Single-instance guard:** `_G.AH74_GEN` + `MYGEN` — โหลดซ้ำ = รุ่นเก่าตายเอง ทุก loop เช็ค
`_G.AH74_GEN == MYGEN` (pattern มาตรฐานของทีม ใช้ทุกสคริปต์)

---

## 2. กลไกเกมที่ค้นพบ (จ่ายบทเรียนมาแพง — อ่านก่อนต่อยอด)

### ตัวตน NPC = attribute ล้วน
```
Skinwalker=true        ผี (ห้ามกด prompt ใดๆ บนตัว ห้ามเช็คอิน)
Anomaly=true           ผีชนิดพิเศษ (Hider = WaterEntity)
IsPatient / IsVisitor  คนไข้ / คนเยี่ยม
DesignatedRoom=RoomX   ห้องประจำ — **ซ้ำกันได้!** (NPC event เช่น Ratthew) → ต้องเอาคนที่อยู่ห้องจริง (InBed/ใกล้) ก่อน
CheckedIn / CompletedCheckIn   ผ่านเช็คอินแล้ว
Treated / HealedAtleastOnce / IsCured   รักษาแล้ว
CarriedBy=<UserId>     ใครอุ้มอยู่ — **เกมไม่เคลียร์ให้เสมอ** → เช็ค "ของจริง" ด้วยระยะ NPC↔เรา <10 studs
MedicineImmune=true    ผีดื้อยา — ยาผิดฆ่าไม่เข้า ข้ามเลย
AlwaysFaints=true      NPC ที่จะเป็นลมแน่ๆ (มี PP 'Carry' โผล่ตอนล้ม)
```

### เกมใช้ ProximityPrompt ล้วน (ไม่มี remote สำคัญ)
- ยิงด้วย `fireproximityprompt` — `.ActionText` ฝั่งโค้ดเป็น**อังกฤษเสมอ** (จอผู้เล่นแปลไทย)
- **`Inspect` = ปุ่มซูมกล้อง ไม่ใช่สเต็ปงาน** — auto-กดแล้วกล้องล็อคติดจอ (พลาดมาแล้ว v4.21)
- ชัตเตอร์: ActionText สลับ `Open`(ประตูปิดอยู่) / `Close`(ประตูเปิดอยู่) — self-limiting กดซ้ำไม่ได้

### จ่ายยา = จุดตายอันดับ 1
- ยาผิด/เกิน = คนไข้ตาย + strike → ป้องกัน 3 ชั้น: ให้ตามลำดับจอ + ชื่อตรงเป๊ะ + poll ยืนยัน `given` เพิ่มจริงค่อยไปตัวถัดไป
- **เกมอ่าน slot hotbar ที่เลือก ไม่ใช่ Tool ที่ถือ** → เลือกยาต้องกดเลข slot (`VIM` คีย์)
  ห้ามใช้ `EquipTool` เป็นทางหลัก (ถือถูกแต่เกมเห็นช่องเก่า = จ่ายยาผิด = ตาย)
- **ถือได้ทีละชิ้น** (โควต้ายา 3 ช่อง) → ก่อนหยิบต้องเคลียร์มือทิ้งถังขยะ
- **ของห้ามทิ้ง** (`NO_DISCARD` — match บางส่วนชื่อ): taser, extinguisher, gun, cola, coffee, syrup
  ของพวกนี้**ได้ช่องเพิ่ม ไม่กินโควต้า 3 ช่องยา** (ยาขยับไป slot 4-5-6)

### การเคลื่อนที่ — วิวัฒนาการ 4 รุ่น (สำคัญมาก ห้ามถอยหลัง)
| วิธี | ผล |
|---|---|
| CFrame teleport ทันที | ตาย — เกมมีระบบ **insanity** จับการวาป |
| CFrame ไหล 5 studs/frame | ตายเหมือนเดิม (Shift 19) |
| MoveTo + WalkSpeed 200 + noclip | ทะลุหลังคาค้างบนดาดฟ้า |
| **Velocity slide (ปัจจุบัน)** | รอด — `AssemblyLinearVelocity = dir*SPEED + Vector3.new(0,-15,0)` แนวราบอย่างเดียว ตาม waypoint ของ PathfindingService, ไม่ noclip, มี roof-recovery (สูงกว่าเป้า >12 → ไต่ลง) |
- `SLIDE_SPEED` ปัจจุบัน **250** (ผู้ใช้ขอ; ค่าพิสูจน์แล้วปลอดภัย = 80 — ถ้าตาย insanity ให้ลดกลับ)
- กันเป้าหลอก: เป้า >400 studs / ต่ำกว่า Y=-50 / **สูงกว่าเรา >30 studs = ของ copy ที่เกมจอดไว้บนฟ้ากลางทะเล** — บล็อคหมด

### StreamingEnabled — บทเรียนใหญ่สุดของ v4.9x
เกมถอด instance ไกลตัวออกจาก client → **เครื่อง/จอ TV/prompt ในห้องไกลหายจริง**
- สมัยวาปไม่เจอเพราะตัวซิ่งทั่วแมพตลอด ห้องเลยโหลดค้าง — พอเปลี่ยนเป็นเดินถึงโผล่
- ทางแก้ (v4.99): **attr บนตัว NPC ไม่โดน stream** → ใช้ `IsPatient + ไม่มี Treated` ตัดสินว่ามีงาน (0 วิ)
  แล้ว `LP:RequestStreamAroundAsync(pos)` สั่งโหลดห้อง**ระหว่างบินไป** — ห้ามนั่งรอโหลดก่อนตัดสินใจ

### Anti-stuck pattern (ใช้ทุก loop — ต่อยอดต้องทำตาม)
ทุกงานที่ retry ได้ต้องมี **fail counter ต่อเป้า → พักขั้นบันได**:
ทาครีม 3 พลาด→พัก 15s / ไฟพื้น-สไลม์ 3 พลาด→พัก ~1 นาที / วางคนเป็นลม→พัก 10s หรือจบถาวร (`math.huge`)
**ตาราง cooldown ต้องแชร์กับฟังก์ชัน `*Pending()`** — ถ้าไม่แชร์ จุดหลอกที่พักอยู่จะถูกนับว่า
"งานค้าง" แล้วบล็อคงานอื่นทั้งระบบ (บั๊ก v4.94 เคาน์เตอร์ค้างหลังดับไฟ)

### Debug จากหน้าจอ (v4.97)
สถานะ "ว่าง" บอกเหตุผลข้ามรายห้อง: `ว่าง R1:ไม่มีปุ่ม R4:ไกล` (ไกล/ผี/จบ/รักษาแล้ว/ไม่มีปุ่ม)
→ ผู้ใช้ถ่ายหัว GUI มา = รู้ทันทีว่าติดเงื่อนไขไหน ไม่ต้องเดา

---

## 3. เครื่องมือประกอบ (repo เดียวกัน)

| ไฟล์ | ใช้ทำอะไร |
|---|---|
| `74RB_loader.lua` | ตัวโหลดถาวร (SHA ล่าสุด + jsDelivr + กันหน้า error 429 มารัน) |
| `74RB_AnimalHospital_RoomDebug.lua` | GUI dump ทุกอย่าง: NPC+attr, prompt ทุกห้อง, ของในมือ, **ตัวเคลื่อนไหวนอก folder NPCs** (ไว้หาผีพื้น) — ปุ่ม RESCAN/COPY |
| `74RB_AnimalHospital_HookSpy.lua` ฯลฯ | hook spy สมัยแกะเกม (namecall/loadstring) |
| `gh_upload.py` | อัปขึ้น GitHub: เช็ค syntax (`lua_balanced`) → skip ถ้าไม่เปลี่ยน → purge jsDelivr อัตโนมัติ |

**Workflow แก้โค้ด (กฎเหล็ก):** แก้ → bump เวอร์ชัน **3 จุด** (header บรรทัด 1, `title.Text = "AH74 vX"`,
`title.Text = "vX " .. lastStatus`) → เช็ค syntax ด้วย node/luaparse (strip Luau: `+=` → `=`, `continue` → `print()`)
→ `python gh_upload.py 74RB_AnimalHospital.lua` ทันที ไม่ต้องถาม

---

## 4. งานค้าง / ทางต่อยอด

1. **น้ำเชื่อมไล่ผีพื้น** — ผีดำคลานพื้น ต้องถือ syrup เดินเข้าหาถึงไล่ได้ (ผู้ใช้ยืนยัน)
   ยังไม่รู้ชื่อ model ผี + ชื่อ tool จริง → รอผล RoomDebug v1.5 ตอนผีโผล่ (`syrup` กันทิ้งไว้แล้ว)
   แผน: อยู่ในโหมดดับไฟ — เจอผี → หยิบ syrup → เดินเข้าหา
2. **ผี Hider/Anomaly (WaterEntity)** — วิธีกำจัดยังไม่รู้ (ตอนนี้แค่ไม่ยุ่ง)
3. **MedicineImmune** — ผีดื้อยา ข้ามอย่างเดียว ยังไม่มีวิธีฆ่า
4. **Place Patient ตอนเตียงเต็มทุกห้อง** — พฤติกรรมเกมยังไม่เคยเจอ
5. **SLIDE_SPEED 250** — เพิ่งปรับ ยังไม่ผ่านการพิสูจน์รอบยาว (จับตา insanity + วิ่งเลยเป้า)
