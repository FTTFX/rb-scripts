# Egg01_TreadGainMatrix — สเปกทดสอบเรทคะแนนบนลู่ (หลายสมมติฐาน)

เป้าหมาย: หาว่า **โหมดเคลื่อนไหวแบบไหน** ทำให้ `leaderstats.Speed` (หรือ stat เทียบเท่า) สะสมเร็วขึ้นบนลู่วิ่ง — ไม่สมมติว่า `Humanoid.WalkSpeed` เกี่ยว (ยืนยันแล้วว่า ×2 ≈ +3% ไม่มีนัย)

ไฟล์: `Egg01_TreadGainMatrix.lua`  
อ้างอิง: `Egg01_SpeedGainTest.lua`, `Egg01_TreadmillAuto.lua`, `Egg01_ExperimentFarm.lua` (`stepRate` / `readStepProgress`), `Egg01_NO_CFRAME.md`

อัปโหลด: `python gh_upload.py Egg01_TreadGainMatrix.lua`

---

## 0. ผลจาก SpeedGainTest (ล็อกแล้ว)

| รอบ | WS | Δ/10s | rate/s |
| --- | --- | --- | --- |
| A baseline | 243.1 | 980000 | 98000 |
| B WS×2 | 486.2→243.1 (เกมรีเซ็ต) | 1010000 | 101000 |

B/A ≈ **1.03× (+3%)** → WalkSpeed **ไม่ใช่ตัวเร่งหลัก** ของคะแนนบนลู่

ชุดนี้ทดสอบตัวแปรอื่น: จ๊อก / cadence / jump / เบรค / บังคับ WS / เรทลู่

---

## 1. ค่าคงที่

```
SAMPLE_SEC       = 10
POLL_HZ          = 0.05
ARRIVE_DIST      = 5
STATIONARY_EPS   = 2.0
ORBIT_R          = 1.2
JOG_SLOW_WAIT    = 0.35
JOG_FAST_WAIT    = 0.12
MICRO_OFFSET     = 1.0
JUMP_EVERY       = 0.40
SPEED_MULT       = 2.00
TREAD_NAME       = "TreadmillBottom"
GLOB_KEY         = "_G.EGG01_TREADGAIN"
GUI_NAME         = "Egg01_TreadGainMatrix"
DISPLAY_ORDER    = 1011
PASS_RATIO       = 1.10      -- ≥+10% เทียบ baseline = ผ่านสมมติฐาน
REPEAT_N         = 1         -- รอบซ้ำต่อโหมด (ออโต้รัน 1; ปุ่มซ้ำได้)
```

ห้าม CFrame / PivotTo / teleport ย้ายตัว — ใช้ MoveTo / Jump / Impulse เท่านั้น

---

## 2. โหมดทดสอบ (matrix)

| id | ชื่อ | พฤติกรรมระหว่าง SAMPLE_SEC |
| --- | --- | --- |
| `stand_brake` | Stand+Brake | เบรค velocity + Move zero (baseline เดิม) |
| `jog_slow` | JogOrbit slow | MoveTo วน sin/cos r=ORBIT_R ทุก JOG_SLOW_WAIT |
| `jog_fast` | JogOrbit fast | เหมือนบน แต่ JOG_FAST_WAIT |
| `micro` | MicroStep | สลับ MoveTo ±MICRO_OFFSET บน XZ จากจุดยืน ทุก POLL |
| `nobrake` | NoBrakeIdle | ไม่เบรค ไม่ MoveTo — ปล่อย animation |
| `jump` | JumpPulse | ยืนจุดเดิม + Jump ทุก JUMP_EVERY (เบรค XZ เบาๆ) |
| `ws2_lock` | WS×2 Heartbeat | ตั้ง WS=base×2 ทุกเฟรม + stand_brake (ยืนยันรีเซ็ต) |

ลำดับออโต้แนะนำ: `stand_brake` → `jog_slow` → `jog_fast` → `micro` → `nobrake` → `jump` → `ws2_lock`

---

## 3. อ่านคะแนน + เรทลู่

`readScore()` — คัดลอกลำดับจาก SpeedGainTest / ExperimentFarm

`stepRate(bottom)` — สแกน TextLabel ใน ancestor ของลู่ หา `+%d+/step` (เหมือน ExperimentFarm)

แสดงบน UI: `stat=Speed | +N/step | ลู่ล็อก`

ก่อนชุดวัด: ล็อค `lockedBottom` — ห้ามเปลี่ยนลู่กลางชุด

---

## 4. ผลต่อโหมด

```
{
  id, label, sampleSec,
  scoreName, scoreStart, scoreEnd, delta, rate,
  walkSpeedStart, walkSpeedEnd,
  stepPerStep,   -- +N/step ของลู่
  moved,         -- เลื่อน XZ จาก anchor > EPS (ยกเว้นโหมดที่ตั้งใจเคลื่อน)
  ok,
}
```

หลังครบชุด:

- เรียงโหมดตาม `rate` สูง→ต่ำ
- เทียบทุกโหมดกับ `stand_brake`: `ratio = rate / rateBaseline`
- verdict: `PASS ≥+10%` / `WEAK ±10%` / `WORSE` / `ZERO` (ทั้งคู่ ~0)

พิมพ์สรุปลง `print` + แผงผล

---

## 5. UI

พื้นขาว · ลากได้ · ชื่อ `Egg01_TreadGainMatrix`

ปุ่ม:
- `ไปลู่` | `STOP` | `X`
- `รันโหมด` (dropdown/cycle โหมดปัจจุบัน) | `ออโต้ทั้งชุด`
- (optional) `ล็อคลู่นี้`

Labels: สถานะ · ตารางผลย่อ · spy (`stat | +N/step | WS | mode`)

---

## 6. Acceptance

- [ ] แต่ละโหมดวัดครบ 10s
- [ ] ลู่เดิมทั้งชุดออโต้
- [ ] ไม่มี CFrame ย้ายผู้เล่น
- [ ] แสดง +N/step และ ranking
- [ ] reload เคลียร์ GUI/`_G` เก่า
- [ ] STOP คืน WalkSpeed

---

## 7. หลังได้ผู้ชนะ (ให้ AI ระบบเคลื่อนไหว)

| ถ้าชนะ | นำไปใช้ |
| --- | --- |
| jog_* / micro | ใส่แพทเทิร์นนั้นในฟาร์มลู่ (แทนยืนนิ่ง) |
| jump | pulse jump ในลูปฟาร์ม |
| nobrake | เลิกเบรคตอนอยู่บนลู่ |
| ws2_lock ยังไม่ขึ้น | ยืนยันตัด WalkSpeed ออกจากฟาร์มลู่ |
| ทุกโหมด rate≈เท่า | โฟกัสเลือกลู่ max +/step + เวลาอยู่บนลู่ |
