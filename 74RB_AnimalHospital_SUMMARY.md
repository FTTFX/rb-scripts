# 74RB — Animal Hospital — สรุปงาน (v3.2)

สคริปต์ช่วยเล่น **Animal Hospital** (Roblox horror social-deduction: เป็นหมอรักษา NPC, บางตัวเป็นผี Skinwalker ปลอมตัว)

> เอกสารเทคนิคเต็ม: [74RB_AnimalHospital_PROJECT.md](74RB_AnimalHospital_PROJECT.md)

## โหลดในเกม
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/FTTFX/rb-scripts/main/74RB_AnimalHospital.lua?v="..tick()))()
```

---

## ปุ่ม (toggles)
| ปุ่ม | ทำอะไร |
|---|---|
| **ESP** | ทะลุกำแพง: ผี🔴 / คนไข้🟢 / NPC🟡 / เพื่อน🔵 + ชื่อ+ระยะ |
| **RUN (+SPEED)** | เร่งความเร็ว (บังคับทุก frame) |
| **NOCLIP** | ทะลุกำแพง |
| **AUTO รักษา** | วินิจฉัย+เก็บยา+ให้ยา (match ชื่อยา, กันคนไข้ตาย) |
| **ผี→ยาผิด** | จงใจให้ยาผิดฆ่าผี (ตอนผีถึงขั้นจ่ายยา) |
| **ไปของ: วาป/เดิน** | สลับโหมดเคลื่อนที่ (วาป CFrame / เดิน pathfinding) |
| **วาปทำเครื่อง** | วาปไปทำเครื่องวินิจฉัยเอง (Medical + Emergency 6/7/8) |
| **ตีตัว (มินิเกม)** | auto whack-a-mole (Room7) |
| **ปริศนาสี R6** | auto Simon copy-sequence (Room6) |
| **เช็คอิน** | auto เช็คอินหน้าเคาน์เตอร์ (มอบใบที่ NPC ด้วย) |
| **ปิดชัตเตอร์ผี** | ผีมาเคาน์เตอร์→ปิด / คนไข้จริงยังไม่เช็คอิน→เปิด |
| **— / + (มุมขวาบน)** | ย่อ/ขยาย GUI |
| **CLOSE** | ปิดทุกอย่าง + คืนค่า + ลบ GUI |

---

## งานที่ทำรอบนี้ (v2.0 → v3.2)

| ver | เพิ่ม/แก้ |
|---|---|
| v2.1–2.2 | **มอบใบรับหมาย** ตอนเช็คอิน = กด E ที่ NPC (prompt "พูดคุย"/Talk บนตัว NPC) |
| v2.3 | **Room8 Surgery รองรับ** — มี `Report.inv` จริง; ใช้ attr `Cured=true` + `UI.Healing`/`Failed` เป็นสัญญาณเสร็จ |
| v2.5 | **Room6 ให้ยาได้** — คนไข้ยืน ไม่มีเตียง → `bedApplyPP` หา 'Apply Treatment' บนตัวคนไข้ด้วย |
| v2.6 | **วาปทำเครื่อง 6/7/8** — เพิ่ม Begin X-Ray/Set Up/Turn On/Begin/Collect/Prepare/Sleep + เอา gate InBed ออก |
| v2.7 | **ปิดชัตเตอร์ผี** (`Misc.ShutterButton.PP`) + กันเช็คอินผี |
| v2.8 | ชัตเตอร์อ่านสถานะประตู (ActionText Open/Close) → ผีปิด / คนไข้จริงเปิด |
| v2.9 | **ถอดระบบดับไฟออก** (ไม่ช่วย) |
| v3.0 | **ปุ่มย่อ/ขยาย GUI** (ClipsDescendants) |
| v3.1 | ชัตเตอร์: **เช็คอินคนดีก่อน แล้วค่อยปิดผี** (เช็ค CheckedIn/CompletedCheckIn) |
| v3.2 | **ไม่กดคุยกับผี** — blind-fire ข้าม prompt ทุกตัวบน Skinwalker (กันที่ระดับ owner, Talk อยู่ใน TREATD ด้วย) |

---

## กลไกเกมที่ค้นพบ (จาก spy)
- **เกมใช้ ProximityPrompt ล้วน** ไม่ใช่ remote → `fireproximityprompt`
- เกม **auto-translate ไทย** แต่ `.ActionText` ฝั่งสคริปต์ยังเป็นอังกฤษ (เช่น "พูดคุย" = `Talk`)
- แยก NPC ด้วย attribute: `Skinwalker`(ผี) / `IsPatient`(คนไข้) / `Fake`(visitor) / `DesignatedRoom` / `CheckedIn` / `Cured`
- "ยาที่ต้องใช้" อยู่ที่ `TV.Screen.UI.Report.inv` (populate หลังวินิจฉัย) — match ชื่อยากับ ProximityPrompt ActionText
- **ห้องรักษา:** Medical 1-5 (DNA), Room6 XRay (ปริศนาสี + คนไข้ยืน), Room7 Heart (whack), Room8 Surgery (เลือกอุปกรณ์)
- ชัตเตอร์ `Misc.ShutterButton.PP` ActionText สลับ `Open`(ปิดอยู่)/`Close`(เปิดอยู่)

## กันคนไข้ตาย (หัวใจ AUTO รักษา)
ให้ยาผิด/เกิน = คนไข้ตาย+strike → ป้องกัน 3 ชั้น: **ให้ตามลำดับ + ชื่อตรงเป๊ะค่อยกด + poll ยืนยัน `given` เพิ่มจริง** (ไม่ชัวร์ ไม่กด)
