-- 74RB_AnimalHospital.lua — ESP + AUTO รักษา + ชัตเตอร์ + ดับไฟ + NPC เร็ว  (v5.21 ยิงผี: ตัด Hider ออก ยิงแค่คนไข้ปลอม)
-- ESP ทะลุกำแพง: ผี🔴 (Skinwalker) | คนไข้🟢 (IsPatient) | NPC🟡 (visitor) | เพื่อน🔵 + ชื่อ+ระยะ
-- Speed: บังคับ WalkSpeed ทุก frame | Noclip: ทะลุกำแพง | AUTO: match ยาตามจอ ไม่ฆ่าคนไข้
local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local VIM     = game:GetService("VirtualInputManager")
local PathSvc = game:GetService("PathfindingService")
local LP      = Players.LocalPlayer

-- กดเลข 1-9 เลือก slot hotbar (เกมดู slot ที่เลือก ไม่ใช่ EquipTool)
local SLOT_KEYS = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
    Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}
local function pressSlot(n)
    local k = SLOT_KEYS[n]; if not k then return end
    pcall(function()
        VIM:SendKeyEvent(true, k, false, game); task.wait(0.02)
        VIM:SendKeyEvent(false, k, false, game)
    end)
end

-- ===== Single-Instance Guard =====
if _G.AH74_CONNS then for _, c in pairs(_G.AH74_CONNS) do pcall(function() c:Disconnect() end) end end
if _G.AH74_ESP  then for _, e in pairs(_G.AH74_ESP)  do pcall(function() e:Destroy() end) end end
_G.AH74_CONNS, _G.AH74_ESP = {}, {}
_G.AH74_GEN = (_G.AH74_GEN or 0) + 1   -- กัน loop เก่าทำงานซ้อนตอนรันใหม่
local MYGEN = _G.AH74_GEN
local CONNS, ESP = _G.AH74_CONNS, _G.AH74_ESP
local function bind(s, f) CONNS[#CONNS+1] = s:Connect(f) end
pcall(function() ((gethui and gethui()) or LP.PlayerGui):FindFirstChild("AH74GUI"):Destroy() end)

-- ===== State =====
local ESP_ON, RUN_ON, NOCLIP_ON, AUTO_ON, KILLGHOST_ON = true, false, false, false, false
local TP_ON = true       -- true=วาป, false=เดิน (pathfinding)
local MACHINE_ON = true  -- true=วาปไปทำเครื่อง(วินิจฉัย)เอง, false=เราเดินไปทำเอง
local WHACK_ON = false   -- auto-click มินิเกม whack (กดเป้าดี เลี่ยงหัวกระโลก Danger)
local R6_ON = false      -- auto ปริศนาสี Room6 (Simon copy-sequence)
local CHECKIN_ON = false -- auto เช็คอินหน้าเคาน์เตอร์ (แยกจากรักษา)
local SHUTTER_ON = false -- auto ปิดชัตเตอร์ใส่ผี: Skinwalker ใกล้เคาน์เตอร์ → ปิดชัตเตอร์
local FIRE_ON = false    -- ดับไฟที่ตัว NPC: ยิง FirePP (ActionText 'Fire'→'Treat Burns') — ไม่ใช้ถัง
local NPCFAST_ON = false -- (เลิกใช้ v5.18 — ปุ่มนี้กลายเป็น "ยิงผี")
local NPC_SPEED = 28     -- ปรับได้
local GUNKILL_ON = false -- v5.18: วาร์ปไปยิงผีด้วยปืน (remote) — แทนปุ่ม NPC เร็ว
local SPEED = 50
local cam = workspace.CurrentCamera
local setStatus = function() end   -- v4.32: โชว์ว่ากำลังทำอะไรบนหัว GUI (ตัวจริงผูกหลังสร้าง GUI)
-- v4.74: กุญแจล็อคงาน — ตอน treatRoom กำลังจ่ายยา ห้าม loop อื่น (สไลม์/ดับไฟ/อุ้ม) ลากตัวไปไหน
-- (เคยโดน: สไลม์เกิดกลางคิวผ่าตัด → บินไปล้าง → fp ยิงใส่ของตรงหน้า = จ่ายผิด = ตาย)
local WORKING = false
local TREAT_BUSY = false   -- v4.75: treat loop มีห้องให้ทำอยู่ไหม (ใช้กั้นเช็คอิน = งานอันดับท้าย)
local CARRYING = false     -- v4.91: กำลังอุ้มคนเป็นลม — ห้ามทุก loop (ไฟ/สไลม์/ชัตเตอร์) แทรกจนกว่าจะวางเสร็จ

-- prompt การรักษา/เช็คอิน/quest (จาก spy) — ยิงตัวที่ enabled อยู่ เกมจะไล่สเต็ปเอง
-- สเต็ปปลอดภัย (ยิงมั่วได้ ไม่ทำคนไข้ตาย): เช็คอิน + วินิจฉัย เท่านั้น
-- *** ไม่รวมเก็บยา/Apply Treatment *** เพราะให้ยาผิด = คนไข้ตาย → จัดการแยกแบบ match ชื่อ
-- กลุ่ม "เช็คอิน" (หน้าเคาน์เตอร์) — แยก toggle
local CHECKIN_ACTS = {
    ["Stamp Forms"]=true, ["Take Photo"]=true, ["Register"]=true,
    ["Print Badge"]=true, ["Take"]=true,
}
-- กลุ่ม "รักษา/วินิจฉัย" (รวมเตรียมคนไข้+สเต็ปเครื่อง Emergency) — อยู่กับ AUTO รักษา
local TREATD_ACTS = {
    ["Talk"]=true, ["Take DNA Sample"]=true, ["Analyze Sample"]=true, ["Process Results"]=true,
    ["Prepare Patient"]=true, ["Sleep Patient"]=true, ["Set Up"]=true, ["Turn On"]=true,
    ["Begin"]=true, ["Begin X-Ray"]=true, ["Collect"]=true,
    -- v4.21: เอา Inspect ออก — มันคือปุ่มซูมกล้องเข้าจอ ไม่ใช่สเต็ปรักษา (บอทกด = กล้องล็อคติดจอ)
}
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local fireAcc = 0
local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local b = inst:FindFirstChildWhichIsA("BasePart", true)
    return b and b.Position
end
-- คืน NPC model (ลูกของ Workspace.NPCs) ที่ prompt สังกัด ; nil ถ้าไม่อยู่ใต้ NPCs
-- ใช้ทั้ง "กด E ที่ NPC" (มอบใบ) + กันเช็คอินผี (เช็ค Skinwalker จาก owner)
local function npcOwner(inst)
    local n = inst
    while n and n.Parent and n.Parent ~= workspace do
        if n.Parent.Name == "NPCs" then return n end
        n = n.Parent
    end
    return nil
end

-- v4.27: คนไข้จริง (ไม่ใช่ผี) ใกล้เคาน์เตอร์ที่ยังไม่เช็คอิน → คืน pos ตัวคนไข้ (ไว้วาปไปเช็คอิน)
-- v4.38: รวม NPC อื่นที่มี prompt เปิดอยู่ด้วย (NPC เนื้อเรื่อง/??? มาขอคุยที่เคาน์เตอร์ — ไม่มี IsPatient)
local function checkinPending()
    local misc = workspace:FindFirstChild("Misc")
    if not misc then return nil end
    -- v4.58: เกมมีเคาน์เตอร์ 2 ช่อง (CheckIn + CheckIn2, attr AsignedCheckIn=2 บอกช่อง) → เช็คทุกช่อง
    local counters = {}
    for _, n in ipairs({"CheckIn", "CheckIn2", "Check-In"}) do
        local inst = misc:FindFirstChild(n)
        local p = partPos(inst)
        if p then counters[#counters+1] = { pos = p, inst = inst } end
    end
    if #counters == 0 then return nil end
    local function nearCounter(p)
        for _, c in ipairs(counters) do
            if (p - c.pos).Magnitude < 15 then return c end
        end
    end
    -- v5.04: จุดยืน hardcode จากผู้ใช้ไปยืน spy พิกัดจริง (แม่นกว่าคำนวณจากตำแหน่งเครื่อง)
    --        โต๊ะกาแฟ = -120.1, 3.4, 10.3 (จดไว้เผื่อทำ auto กาแฟ)
    local CI_STAND = {
        ["CheckIn"]  = Vector3.new(-103.5, 3.4, -0.2),
        ["Check-In"] = Vector3.new(-103.5, 3.4, -0.2),
        ["CheckIn2"] = Vector3.new(-100.2, 3.4, 5.9),
    }
    local function standPos(c)
        return CI_STAND[c.inst.Name] or c.pos
    end
    local npcs = workspace:FindFirstChild("NPCs"); if not npcs then return nil end
    for _, m in ipairs(npcs:GetChildren()) do
        if m:IsA("Model") and not m:GetAttribute("Skinwalker") and not m:GetAttribute("Anomaly") then
            local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
            -- v4.53: รัศมี 15 ต่อช่อง (ผู้ใช้จูน) — v4.58 เช็คใกล้ช่องไหนก็ได้
            local c = r and nearCounter(r.Position)
            if c then
                -- v4.52: คนไข้ *หรือ* คนเยี่ยม (IsVisitor) ที่ยังไม่เช็คอิน = วาปไปหาเหมือนกัน
                if (m:GetAttribute("IsPatient") or m:GetAttribute("IsVisitor"))
                   and m:GetAttribute("CheckedIn") ~= true and not m:GetAttribute("CompletedCheckIn") then
                    return standPos(c)
                end
                -- NPC อื่นที่มี prompt 'Talk' เปิดรอกด (มอบใบ/คุยรับงาน) — v4.49: Talk เท่านั้น
                -- ('Ask to Leave' = ผีปลอม attr สะอาด ห้ามวาปเข้าไปหา/ห้ามกด)
                for _, p in ipairs(m:GetDescendants()) do
                    if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText == "Talk" then return standPos(c) end
                end
            end
        end
    end
end

local COL = {
    ghost   = Color3.fromRGB(255, 40, 40),    -- ผี (Skinwalker = อันตรายจริง)
    anomaly = Color3.fromRGB(190, 60, 255),   -- v4.37 Hider/Anomaly (ผีซ่อน — อัปเดตใหม่)
    sus     = Color3.fromRGB(255, 150, 30),   -- v4.41 น่าสงสัย: มี Camera/PhotoEffect แต่ยังไม่ขึ้น Skinwalker
    visitor = Color3.fromRGB(60, 230, 230),   -- v4.44 คนมาเยี่ยมไข้ (IsVisitor — ไม่ใช่คนไข้ แต่ต้องต้อนรับ)
    patient = Color3.fromRGB(60, 255, 90),    -- คนไข้จริง
    mate    = Color3.fromRGB(60, 160, 255),   -- เพื่อนผู้เล่น
    npc     = Color3.fromRGB(220, 210, 110),  -- NPC ทั่วไป/visitor (Fake=true ไม่ใช่ผี)
}
local LBL = { ghost="ผี", anomaly="ผีซ่อน", sus="น่าสงสัย!", patient="คนไข้", visitor="เยี่ยมไข้", mate="เพื่อน", npc="NPC" }

local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- กด prompt: หันหน้าเข้าหาเป้า → fp พร้อม bypass กดค้าง (HoldDuration=0 ชั่วคราว) → รอ done()
-- done() = เช็คสำเร็จจากผลจริง (ยาติ๊ก/ของเข้ามือ) — Apply ไม่ดับหลังสำเร็จ ห้ามใช้ Enabled เป็นเกณฑ์กดซ้ำ
-- v4.29: ต้องหันหน้าก่อนยิง — executor มือถือบางตัว fp = จำลองกด E ใส่ตัว "ตรงหน้า" ไม่ใช่ตัวที่ระบุ
--        (Room8 หันผิดนิดเดียว = จ่ายยาผิด) + ย้ายฟังก์ชันมาหลัง hrp/partPos (เดิมประกาศก่อน = เรียก nil)
local function pressPrompt(pp, done)
    if not (pp and pp.Parent and pp.Enabled) then return true end
    done = done or function() return not (pp.Parent and pp.Enabled) end
    local r, pos = hrp(), partPos(pp.Parent)
    if r and pos then
        pcall(function()
            r.CFrame = CFrame.lookAt(r.Position, Vector3.new(pos.X, r.Position.Y, pos.Z))
        end)
        task.wait(0.05)
    end
    if fp then
        local hold = pp.HoldDuration
        pp.HoldDuration = 0
        pcall(fp, pp, 0)
        pp.HoldDuration = hold
    end
    local t0 = os.clock()
    repeat task.wait(0.05) until done() or os.clock() - t0 > 0.5
    return done()
end

-- ===== Auto รักษา (match ชื่อยา ไม่ฆ่าคนไข้) =====
-- เดินไปหา pos (pathfinding อ้อมกำแพง) — ใช้เมื่อปิดโหมดวาป
local function walkTo(pos)
    local h, r = hum(), hrp()
    if not (h and r) then return end
    local path = PathSvc:CreatePath({ AgentRadius = 2, AgentCanJump = true })
    local ok = pcall(function() path:ComputeAsync(r.Position, pos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if _G.AH74_GEN ~= MYGEN then return end   -- v4.85: เลิกผูก AUTO_ON (loop ไฟ/อุ้ม/เช็คอินก็ใช้)
            h:MoveTo(wp.Position)
            if wp.Action == Enum.PathWaypointAction.Jump then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            local t0 = os.clock()
            repeat task.wait(0.05)
            until not hrp() or (hrp().Position - wp.Position).Magnitude < 4 or os.clock() - t0 > 3
        end
    else
        h:MoveTo(pos)   -- fallback: เดินตรง
        local t0 = os.clock()
        repeat task.wait(0.1)
        until not hrp() or (hrp().Position - pos).Magnitude < 6 or os.clock() - t0 > 6
    end
end
-- ไปหา pos: วาป หรือ เดิน ตามโหมด
-- v4.35: กันบ้าคลั่งตาย — จุดหมายใกล้ผี (Skinwalker) <12 studs → ถอยออกมายืนห่างผี 12 studs
-- (อยู่ใกล้ผี sanity ไหลจนตาย ; fp ยิงถึงจากระยะนั้นอยู่แล้ว ไม่ต้องจ่อ)
local GHOST_GAP = 12
local function ghostSafe(pos)
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return pos end
    for _, m in ipairs(npcs:GetChildren()) do
        if m:GetAttribute("Skinwalker") then
            local g = partPos(m)
            if g and (g - pos).Magnitude < GHOST_GAP then
                local away = (pos - g)
                away = away.Magnitude > 0.5 and away.Unit or Vector3.new(1, 0, 0)
                pos = g + away * GHOST_GAP
            end
        end
    end
    return pos
end
local function tpTo(pos, speedOpt)   -- v5.05: speedOpt override ความเร็วสไลด์ (เช็คอิน=80)
    if not pos then return end
    -- v4.36: กันวาปหลุดโลก — เป้าต่ำกว่า Y=-50 หรือไกลเกิน 400 studs = เป้าเพี้ยน (prompt/ของนอกแมพ) ไม่ไป
    if pos.Y < -50 then return end
    -- v4.48: อยู่ใกล้เป้า ≤6 studs แล้ว = ไม่วาปซ้ำ (เดิม loop สั่งวาปจุดเดิมทุก 0.3s → ตัวกระตุกตลอด)
    do
        local r0 = hrp()
        if r0 and (pos - r0.Position).Magnitude <= 6 then return end
    end
    -- v4.45: ห้ามวาปตอนตัวลอย (กระโดด/ตกอยู่) — วาปกลางอากาศ = ตาย ; รอลงพื้นก่อน สูงสุด 1s
    local h = hum()
    if h and h.FloorMaterial == Enum.Material.Air then
        local t0 = os.clock()
        repeat task.wait(0.05); h = hum()
        until not h or h.FloorMaterial ~= Enum.Material.Air or os.clock() - t0 > 1
        if h and h.FloorMaterial == Enum.Material.Air then return end   -- ยังลอยอยู่ = ไม่วาปรอบนี้
    end
    local r = hrp()
    if r and (pos - r.Position).Magnitude > 400 then
        setStatus("บล็อควาปเพี้ยน " .. math.floor((pos - r.Position).Magnitude) .. "m")
        return
    end
    -- v4.79: กันบิน "ขึ้นฟ้า" — เป้าสูงกว่าตัวเรา >30 studs = เป้านอกแมพ (ลงต่ำได้ปกติ เผื่อหลุดไปอยู่ที่สูงแล้วต้องกลับพื้น)
    if r and pos.Y - r.Position.Y > 30 then
        setStatus("บล็อคเป้าบนฟ้า +" .. math.floor(pos.Y - r.Position.Y) .. "m")
        return
    end
    pos = ghostSafe(pos)
    if TP_ON then
        -- v4.85: เลิกบิน CFrame ทั้งหมด — เกมยังจับได้ (ตายบ้าคลั่งซ้ำ Shift19)
        -- v4.87: เดินเร็วตาม "เส้นทางจริง" (pathfinding) ไม่ใช้ noclip —
        --        v4.86 noclip+เดินตรง = ไต่ทะลุขึ้นหลังคาแล้วลงไม่ได้ ; เดินบนพื้นตามทางเท่านั้น
        local h = hum()
        if not (h and r) then return end
        -- กู้ตัวเองจากหลังคา: เราสูงกว่าเป้าเกิน 12 studs = ติดบนโครงสร้าง → หย่อนตัวลงแนวดิ่งสั้นๆ
        if r.Position.Y - pos.Y > 12 then
            local c = LP.Character
            local function clip(on)
                if c then for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = on end
                end end
            end
            clip(false)
            local t0 = os.clock()
            while r and r.Position.Y - pos.Y > 3 and os.clock() - t0 < 3 do
                r.CFrame = CFrame.new(r.Position - Vector3.new(0, 2, 0))   -- ก้าวสั้นแนวดิ่ง — ไม่ใช่วาปไกล
                r.AssemblyLinearVelocity = Vector3.zero
                task.wait(); r = hrp()
            end
            if not NOCLIP_ON then clip(true) end
        end
        -- v4.88: "สไลด์" ตาม waypoint — ดันด้วย velocity จริง (แบบ Climb Forsaken)
        --        เกมเห็นเป็นฟิสิกส์ต่อเนื่อง ไม่ใช่ teleport ; เร็วกว่า WalkSpeed เพราะไม่ติดแรงเสียดทาน
        local SLIDE_SPEED = speedOpt or 250   -- studs/s แนวราบ (v5.00 ผู้ใช้ขอ 250 — ถ้าตาย insanity ให้ลดกลับ)
        local wps
        -- v5.09: ไถลตรง "ทุกหมวด" (ผู้ใช้เน้นเร็วสุด) — เลิก pathfinding ทั้งหมด
        --        เส้นตรง + noclip ชั่วคราว + ล็อค Y (v5.07) = ไม่อ้อม ไม่ติดกำแพง ไม่จมแมพ
        local straight = true
        wps = { { Position = pos } }
        local clipOff = straight
        if clipOff then
            local c = LP.Character
            if c then for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end end
        end
        local t0 = os.clock()
        -- v5.07: โหมดไถลตรง (noclip อยู่) ห้ามมีแรงกดลง — ไม่มีพื้นรับ = จมทะลุแมพตาย
        --        ล็อคความสูง Y เดิมทุกเฟรมแทน (ก้าวแนวดิ่งสั้นๆ แบบ roof recovery — ปลอดภัย)
        local yLock = r.Position.Y
        for _, wp in ipairs(wps) do
            if _G.AH74_GEN ~= MYGEN or os.clock() - t0 > 10 then break end
            local t1 = os.clock()
            repeat
                r = hrp(); if not r then break end
                local dir = wp.Position - r.Position
                dir = Vector3.new(dir.X, 0, dir.Z)   -- ไถลแนวราบเท่านั้น
                if dir.Magnitude < 3 then break end
                -- v5.08: ตัวไม่มี collide (ไถลตรง หรือผู้ใช้เปิด NOCLIP) = ห้ามใส่แรงกดลง
                --        ไม่มีพื้นรับจะจมทะลุแมพ (ตายตอนรักษา Room3 เพราะ NOCLIP ON + แรงกด -15)
                if straight or NOCLIP_ON then
                    r.AssemblyLinearVelocity = dir.Unit * SLIDE_SPEED
                    r.CFrame = CFrame.new(Vector3.new(r.Position.X, yLock, r.Position.Z))
                        * (r.CFrame - r.CFrame.Position)
                else
                    -- กดลงพื้นเบาๆ (-15) กันลอย/เด้งขึ้นขอบ — ห้ามมี velocity ขึ้น
                    r.AssemblyLinearVelocity = dir.Unit * SLIDE_SPEED + Vector3.new(0, -15, 0)
                end
                task.wait()
            until os.clock() - t1 > 3
        end
        -- ถึงแล้วหยุดไถล (ตัดความเร็วค้าง — ไม่งั้นตัวไถลเลยเป้า)
        r = hrp(); if r then r.AssemblyLinearVelocity = Vector3.zero end
        if clipOff and not NOCLIP_ON then   -- v5.06: คืน collide (ยกเว้นผู้ใช้เปิด NOCLIP เอง)
            local c = LP.Character
            if c then for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end end
        end
    else
        walkTo(pos)
    end
end
-- หา ProximityPrompt ที่ ActionText ตรงชื่อยา + "ใกล้ตัวเราสุด" (ยามีหลายจุด/ตู้หน้าห้อง)
local function findPickup(medName)
    local fromPos = hrp() and hrp().Position
    local best, bestD
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == medName and p.Parent then
            local pos = partPos(p.Parent)
            -- v4.67: ตัดจุดเก็บนอกแมพทิ้ง (เกมพักไอเทมไว้ใต้น้ำ/ไกล — บินตามไป = ลอยน้ำ)
            -- v4.79: กันของที่จอด "บนฟ้า" ด้วย (สูงกว่าตัวเรา >25 studs = ก๊อปปี้นอกแมพ — บินขึ้นฟ้ากลางทะเล)
            if pos and (not fromPos or ((pos - fromPos).Magnitude < 150 and pos.Y - fromPos.Y < 25)) and pos.Y > -50 then
                local d = fromPos and (pos - fromPos).Magnitude or math.huge
                if not best or d < bestD then best, bestD = p, d end
            end
        end
    end
    return best
end
-- v5.05: เดินหมวดเช็คอิน = ระบบสไลด์เดียวกับงานอื่น (pathfinding + กันตกหลังคา/เป้าบนฟ้า)
--        แค่ลดความเร็วเหลือ 80 — เดิมใช้ MoveTo แยกระบบ พอชนกับ loop ดับไฟแล้วตัวกระตุก
local function ciGo(pos) return tpTo(pos, 80) end
-- หา Tool ชื่อตรงยา (ที่ถืออยู่ใน Backpack/ตัว)
local function findTool(medName)
    local bp = LP:FindFirstChild("Backpack")
    if bp then local t = bp:FindFirstChild(medName); if t and t:IsA("Tool") then return t end end
    if LP.Character then local t = LP.Character:FindFirstChild(medName); if t and t:IsA("Tool") then return t end end
end
-- เป็น "ยา" ไหม = มีจุดเก็บ (ProximityPrompt ActionText ตรงชื่อ)
local function isMedicine(name) return findPickup(name) ~= nil end
-- Tool ทั้งหมดที่ถืออยู่ (Backpack+ตัว)
local function heldTools()
    local out = {}
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then out[#out+1] = t end end end
    if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do if t:IsA("Tool") then out[#out+1] = t end end end
    return out
end
-- หาจุดทิ้งยา (Trash Item) — "ใกล้สุด" (มีหลายถัง อย่าไปไกล)
local function trashPrompt()
    local fromPos = hrp() and hrp().Position
    local best, bestD
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == "Trash Item" and p.Parent then
            local pos = partPos(p.Parent)
            local d = (fromPos and pos) and (pos - fromPos).Magnitude or math.huge
            if not best or d < bestD then best, bestD = p, d end
        end
    end
    return best
end
-- v4.92: ของห้ามทิ้งขยะ — ต้องคืน station (Taser/ถังดับเพลิง) หรือซื้อมาด้วยเงิน (Gun/Cola/Coffee)
local NO_DISCARD = { "taser", "extinguisher", "gun", "cola", "coffee", "syrup" }   -- v4.94: syrup ไล่ผีพื้น
local function protectedTool(tool)
    local n = tool.Name:lower()
    for _, k in ipairs(NO_DISCARD) do
        if n:find(k, 1, true) then return true end
    end
    return false
end
-- ทิ้ง Tool 1 ชิ้น: equip → วาปไปถังขยะ → fire
local function discardTool(tool)
    if protectedTool(tool) then return end   -- v4.92: ห้ามทิ้งของสำคัญ
    local h = hum()
    local tp = trashPrompt()
    if not (h and tp and tp.Parent) then return end
    pcall(function() h:EquipTool(tool) end); task.wait(0.15)
    tpTo(partPos(tp.Parent)); task.wait(0.2)
    pressPrompt(tp, nil, true); task.wait(0.2)   -- fp เท่านั้น
end
-- เคลียร์ยาที่ "ไม่ใช่" ของคนไข้นี้ออก (กัน slot เต็ม → เก็บยาถูกไม่ได้)
local function cleanInventory(needed)
    for _, t in ipairs(heldTools()) do
        if isMedicine(t.Name) and not needed[t.Name] then
            discardTool(t)
        end
    end
end
-- หา TV.Screen.UI ของห้อง (Healing/Failed อยู่ที่นี่ตรงๆ ; Report เป็นลูก)
local function getScreenUI(room)
    local r = room:FindFirstChild("Minigame")
    r = r and r:FindFirstChild("TV"); r = r and r:FindFirstChild("Screen")
    return r and r:FindFirstChild("UI")
end
-- หา Report ของห้อง (TV.Screen.UI.Report)
local function getReport(room)
    local ui = getScreenUI(room)
    return ui and ui:FindFirstChild("Report")
end
-- ห้องนี้รักษาเสร็จ/กำลังฟื้นแล้วหรือยัง → ข้าม ไม่วาปซ้ำ
local function roomDone(room)
    local ui = getScreenUI(room)
    if not ui then return true end                   -- ไม่มีจอ = ไม่ต้องทำ
    -- ฟื้นตัว(Healing) หรือ ผ่าล้มเหลว(Failed, Room8) = จบ ; Healing/Failed อยู่ที่ UI ตรงๆ ทุกห้อง
    for _, n in ipairs({"Healing", "Failed"}) do
        local g = ui:FindFirstChild(n)
        if g and g:IsA("GuiObject") and g.Visible then return true end
    end
    local rep = ui:FindFirstChild("Report")
    if not rep then return true end
    local tt = rep:FindFirstChild("treatment")
    if tt and tt:IsA("TextLabel") then
        local a, b = tt.Text:match("(%d+)%s*/%s*(%d+)")   -- Medical/Em: 'TREATMENT: X/Y' (Room8='SURGERY:' ไม่มีเลข → ใช้ Healing แทน)
        a, b = tonumber(a), tonumber(b)
        if a and b and b > 0 and a >= b then return true end   -- 2/2 = เสร็จ
    end
    return false
end
-- อ่าน "ยาที่ต้องใช้" ของห้อง จาก TV.Screen.UI.Report.inv (populate หลังวินิจฉัย)
local function requiredMeds(room)
    local inv = getReport(room)
    inv = inv and inv:FindFirstChild("inv")
    if not inv then return {} end
    local meds = {}
    for _, fr in ipairs(inv:GetChildren()) do
        if fr:IsA("GuiObject") then
            local nm = fr:FindFirstChild("name")
            local txt = (nm and nm:IsA("TextLabel") and nm.Text ~= "") and nm.Text or nil
            -- ชื่อ frame (อังกฤษ) นำ — .name.Text โดนแปลไทย ใช้เป็น fallback เท่านั้น
            meds[#meds+1] = (fr.Name ~= "" and fr.Name ~= "Template") and fr.Name or txt or fr.Name
        end
    end
    return meds
end
-- frame นี้ถูกให้ยาแล้ว — Room8(Surgery) มี attr Cured=true ต่อชิ้น (สัญญาณตรง ใช้ก่อน) ; ห้องอื่นดู check โผล่
local function frameGiven(fr)
    local cured = fr:GetAttribute("Cured")
    if cured ~= nil then return cured == true end
    local chk = fr:FindFirstChild("check")
    if not (chk and chk:IsA("GuiObject")) then return false end
    if not chk.Visible then return false end
    if chk:IsA("ImageLabel") and chk.ImageTransparency >= 0.5 then return false end
    return true
end
-- ชื่อยาของ frame — v4.24: ใช้ "ชื่อ frame" ก่อน (อังกฤษเสมอ ตรงกับ Tool/ActionText)
-- ห้ามใช้ .name.Text นำ: เกม auto-แปลไทย ("น้ำเชื่อมเมเปิ้ล") → เทียบ Tool "Maple Syrup" ไม่ตรง → บอทไม่ให้ยา
local function frameMed(fr)
    if fr.Name ~= "" and fr.Name ~= "Template" then return fr.Name end
    local nm = fr:FindFirstChild("name")
    return (nm and nm:IsA("TextLabel") and nm.Text ~= "") and nm.Text or fr.Name
end
-- frame ยาทั้งหมด "เรียงตามลำดับบนจอ" (LayoutOrder) — Room8 ผ่าตัดต้องให้ตามลำดับนี้เป๊ะ
local function invFrames(room)
    local inv = getReport(room); inv = inv and inv:FindFirstChild("inv")
    if not inv then return {} end
    local frs = {}
    for _, fr in ipairs(inv:GetChildren()) do
        if fr:IsA("GuiObject") then frs[#frs+1] = fr end
    end
    local idx = {}
    for i, f in ipairs(frs) do idx[f] = i end
    table.sort(frs, function(a, b)
        if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
        return idx[a] < idx[b]   -- LayoutOrder เท่ากัน = คงลำดับเดิม (sort ไม่ stable)
    end)
    return frs
end
-- นับจำนวนยาที่ต้องการ/ให้แล้ว ต่อชนิด (รองรับของซ้ำ เช่น มีดผ่าตัด ×2)
-- คืน need[m]=ต้องการกี่ชิ้น, given[m]=ให้แล้วกี่ชิ้น(ใครก็ได้), order=รายชื่อชนิดเรียงลำดับจอ
local function medCounts(room)
    local need, given, order = {}, {}, {}
    for _, fr in ipairs(invFrames(room)) do
        local m = frameMed(fr)
        if (need[m] or 0) == 0 then order[#order+1] = m end
        need[m] = (need[m] or 0) + 1
        if frameGiven(fr) then given[m] = (given[m] or 0) + 1 end
    end
    return need, given, order
end
local function givenOf(room, m) local _, g = medCounts(room); return g[m] or 0 end
-- นับ Tool ชื่อ m ที่ถืออยู่ (รองรับถือซ้ำหลายชิ้น)
local function heldCount(m)
    local c = 0
    for _, t in ipairs(heldTools()) do if t.Name == m then c += 1 end end
    return c
end
-- v4.14: ห้องนี้มี "งานทำได้จริง" ไหม — prompt สเต็ปงาน Enabled อยู่ (ในห้อง/บนตัวคนไข้) หรือมียาต้องเก็บ
-- ใช้กรองตอนเลือกห้อง: กัน commit ห้องที่คนไข้ยังเดินไม่ถึง/ทุกอย่างปิดอยู่ (เสียเวลาห้องละ 1.6s ฟรี)
local WORK_ACTS = {
    ["Talk"]=true, ["Take DNA Sample"]=true, ["Analyze Sample"]=true, ["Process Results"]=true,
    ["Prepare Patient"]=true, ["Sleep Patient"]=true, ["Set Up"]=true, ["Turn On"]=true,
    ["Begin"]=true, ["Begin X-Ray"]=true, ["Collect"]=true, ["Apply Treatment"]=true,
}
local function hasWork(room, pat)
    for _, p in ipairs(room:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Enabled and WORK_ACTS[p.ActionText] then return true end
    end
    if pat then
        for _, p in ipairs(pat:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.Enabled and WORK_ACTS[p.ActionText] then return true end
        end
    end
    if #requiredMeds(room) > 0 then return true end   -- มียาต้องเก็บ/ให้ = มีงาน
    return false
end

-- v4.71: คนเป็นลม (มี PP 'Carry' บนตัว, ไม่ใช่ผี) = งานด่วนอันดับ 1
local FAINT_DONE = {}   -- v4.77: พักต่อหัวหลังพยายามวาง — กันวนซ้ำถ้าเกมไม่เคลียร์ CarriedBy
local function faintEligible(m)
    return m:IsA("Model") and not m:GetAttribute("Skinwalker") and not m:GetAttribute("Anomaly")
       and not m:GetAttribute("InBed")   -- v4.77: ขึ้นเตียงแล้ว = จบงาน (เกมอาจไม่เคลียร์ CarriedBy)
       and (not FAINT_DONE[m] or os.clock() - FAINT_DONE[m] > 10)
end
local function faintPending()
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return nil, nil end
    local kids = npcs:GetChildren()
    -- v4.91: รอบแรก — คนที่ "อุ้มติดมืออยู่จริง" มาก่อนเสมอ
    --        (เป็นลม 2 คนพร้อมกัน: เดิมอาจคืนคนที่ 2 ทั้งที่ยังอุ้มคนแรก → กด Carry ซ้อน งานพันกัน คนตาย)
    for _, m in ipairs(kids) do
        if faintEligible(m) and m:GetAttribute("CarriedBy") == LP.UserId then
            -- v4.81: เช็ค "จากมือจริง" — อุ้มอยู่จริงตัว NPC ต้องติดตัวเรา (<10 studs)
            --        เกมไม่เคลียร์ CarriedBy หลังวางเตียงห้องอื่น → attr ค้างแต่ตัวอยู่ไกล = วางแล้ว จบถาวร
            local me, np = hrp() and hrp().Position, partPos(m)
            if me and np then
                if (np - me).Magnitude < 10 then return m, nil end
                FAINT_DONE[m] = math.huge   -- วางไปแล้ว — ไม่กลับมาวนอีก
            else
                return m, nil
            end
        end
    end
    -- รอบสอง — คนเป็นลมที่ยังไม่มีใครอุ้ม (มี Carry prompt)
    for _, m in ipairs(kids) do
        if faintEligible(m) then
            for _, p in ipairs(m:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText == "Carry" then
                    return m, p
                end
            end
        end
    end
end
-- v4.75: ลำดับความสำคัญ — ไฟ (อันดับ 2), สไลม์ (อันดับ 3)
-- v4.95: ตาราง cooldown แชร์กันระหว่าง loop ดับไฟ กับ firePending/slimePending
--        (เดิม cooldown เป็น local ใน loop — จุดหลอก/เอื้อมไม่ถึงที่พักอยู่ ยังถูกนับว่า
--         "มีไฟค้าง" → บล็อคเช็คอิน/รักษาถาวร สถานะค้าง "ดับไฟพื้น")
local FIRE_COOL, FIRE_FAILN = {}, {}   -- ไฟพื้น/สไลม์: [prompt] = os.clock() หมดพัก / นับพลาด
local BURN_FAIL = {}                   -- ไฟตัว NPC: [npc] = {n, t}
local function fireResting(d)   -- จุดนี้พักอยู่ = ข้าม ไม่นับว่างานค้าง
    return FIRE_COOL[d] and os.clock() - FIRE_COOL[d] <= 5
end
local function burnResting(m)
    local f = BURN_FAIL[m]
    return f and f.n >= 3 and os.clock() - f.t <= 15
end
local function firePending()
    local npcs = workspace:FindFirstChild("NPCs")
    if npcs then for _, m in ipairs(npcs:GetChildren()) do
        local pp = m:FindFirstChild("FirePP")
        if pp and pp:IsA("ProximityPrompt") and pp.Enabled and not burnResting(m) then return true end
    end end
    local rooms = workspace:FindFirstChild("Rooms")
    local me = hrp() and hrp().Position
    if rooms and me then for _, d in ipairs(rooms:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Put out fire"
           and not fireResting(d) then
            local pos = partPos(d.Parent)
            if pos and (pos - me).Magnitude < 120 then return true end
        end
    end end
    return false
end
local function slimePending()
    local misc = workspace:FindFirstChild("Misc")
    local me = hrp() and hrp().Position
    if misc and me then for _, d in ipairs(misc:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Clean Slime"
           and not fireResting(d) then
            local pos = partPos(d.Parent)
            if pos and (pos - me).Magnitude < 120 then return true end
        end
    end end
    return false
end
-- v5.21: ยิงเฉพาะคนไข้ปลอม (Skinwalker ที่ไม่ใช่ Anomaly) — ตัด Hider (Anomaly=true) เปลืองกระสุน + ตัด Ghost
local function ghostToShoot(m)
    if not (m:IsA("Model") and m:GetAttribute("Skinwalker")
            and not m:GetAttribute("Anomaly")
            and not m:GetAttribute("MedicineImmune")) then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    return not h or h.Health > 0   -- ยังไม่ตาย
end
local function gunPending()
    if not GUNKILL_ON then return false end
    local npcs = workspace:FindFirstChild("NPCs")
    local me = hrp() and hrp().Position
    if not (npcs and me) then return false end
    for _, m in ipairs(npcs:GetChildren()) do
        if ghostToShoot(m) then
            local p = partPos(m)
            if p and (p - me).Magnitude < 200 then return true end
        end
    end
    return false
end

-- v4.23: เลือกของด้วย "กดปุ่ม slot จริง" เท่านั้น — *** ห้ามใช้ EquipTool เด็ดขาด ***
-- เกมอ่านจากช่อง hotbar ที่เลือก ไม่ใช่ Tool ที่ถือ (EquipTool ถือถูกแต่เกมเห็นช่องเก่า
-- → Apply = ยาผิด = ตาย — พลาดมาแล้วใน v4.19-4.22) ; เร็วด้วย poll แทน wait คงที่
local function heldName()
    local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    return t and t.Name
end
local function selectTool(m)
    if heldName() == m then return true end
    for slot = 1, math.min(9, #heldTools()) do   -- PC: กดเลข slot จริง
        pressSlot(slot)
        local t0 = os.clock()
        repeat task.wait(0.03) until heldName() == m or os.clock() - t0 > 0.25
        if heldName() == m then return true end
    end
    -- v4.26: จอ touch กดเลขไม่ได้ (VIM คีย์บอร์ดไม่ติด) → EquipTool เป็นทางสุดท้าย
    -- ปลอดภัยเพราะ apply เช็ค done=ยาหายจากมือ — เกมไม่รับก็แค่ไม่ติ๊ก ไม่กดซ้ำ
    local tool = findTool(m)
    if tool then
        pcall(function() hum():EquipTool(tool) end)
        local t0 = os.clock()
        repeat task.wait(0.03) until heldName() == m or os.clock() - t0 > 0.4
    end
    return heldName() == m
end

-- หา NPC คนไข้ของห้องนี้ (จาก attribute DesignatedRoom)
local function roomPatient(room)
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return end
    local rpos = partPos(room:FindFirstChild("Minigame") or room)
    -- v4.96: DesignatedRoom ซ้ำกันได้หลายตัว (NPC event เช่น Ratthew ยืนอีกฝั่งแมพ แต่ attr=Room1)
    --        ต้องเอาคนที่ "อยู่ห้องจริง" (InBed/ใกล้ <35) ก่อน — ไม่งั้นห้องโดนล็อคด้วยเจ้าของที่ไม่อยู่
    local cand
    for _, m in ipairs(npcs:GetChildren()) do
        -- v4.44: ต้องเป็นคนไข้จริง — คนเยี่ยม (IsVisitor) ก็มี DesignatedRoom เดียวกัน อย่าคว้าผิดตัว
        if m:GetAttribute("DesignatedRoom") == room.Name and not m:GetAttribute("IsVisitor") then
            if m:GetAttribute("InBed") then return m end
            local p = partPos(m)
            if p and rpos and (p - rpos).Magnitude < 35 then return m end
            cand = cand or m
        end
    end
    -- fallback (v4.6): เกมอาจไม่ตั้ง/เคลียร์ DesignatedRoom → จับจากตำแหน่ง:
    -- NPC คนไข้ (IsPatient/InBed) ที่อยู่ใกล้ห้องนี้ <30 studs = คนไข้ของห้องนี้
    if rpos then
        local best, bestD
        for _, m in ipairs(npcs:GetChildren()) do
            if m:IsA("Model") and (m:GetAttribute("InBed") or m:GetAttribute("IsPatient")) then
                local p = partPos(m)
                local d = p and (p - rpos).Magnitude
                if d and d < 30 and (not best or d < bestD) then best, bestD = m, d end
            end
        end
        if best then return best end
    end
    return cand   -- เจ้าของตาม attr ที่ยังเดินไม่ถึงห้อง (treat loop เช็ค present เองอยู่แล้ว)
end
-- หา prompt "Apply Treatment" — ในห้อง (Room7/8 มีเตียง) หรือ บนตัวคนไข้ (Room6 คนไข้ยืน ไม่มีเตียง)
local function bedApplyPP(room)
    -- v4.12: มี 'Apply Treatment' หลายตัว (InBed เก่า Enabled=false + Main ตัวจริง) → เอาตัว Enabled ก่อน
    -- v4.50: ตัว Enabled ต้องอยู่ใกล้ห้องจริง <40 studs — obj 'Main' บางทีลอยอยู่นอกแมพ/ใต้น้ำ
    --        (บอทวาปตามแล้วหลุดแมพตอนรักษา) ; ไกลเกิน = ใช้ตัวในห้องแทน
    -- v4.60: obj=Main เปิดค้างข้ามห้อง/ก่อนวินิจฉัย (กลไกใหม่ ไม่ใช่ Apply ประจำเตียง)
    -- ลำดับเลือก: InBed(Enabled) > บนตัวคนไข้(Enabled) > Enabled อื่นในห้อง(Main) > ตัวแรกที่เจอ
    local rpos = partPos(room:FindFirstChild("Minigame") or room)
    local first, other
    for _, p in ipairs(room:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == "Apply Treatment" then
            if p.Enabled then
                local pp = partPos(p.Parent)
                if pp and rpos and (pp - rpos).Magnitude < 40 then
                    if p.Parent.Name == "InBed" then return p end   -- ตัวจริงประจำเตียง
                    other = other or p                              -- Main ฯลฯ เก็บเป็นตัวเลือกท้าย
                end
            end
            first = first or p
        end
    end
    local pat = roomPatient(room)   -- คนไข้ยืน: prompt อยู่บน NPC (ใน Workspace.NPCs ไม่ใช่ใต้ room)
    if pat then
        for _, p in ipairs(pat:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.ActionText == "Apply Treatment" then
                if p.Enabled then return p end
                first = first or p
            end
        end
    end
    return other or first
end
-- ตำแหน่งห้อง (ใช้เตียง) สำหรับเรียงระยะใกล้
local function roomPos(room)
    local pp = bedApplyPP(room)
    if pp and pp.Parent then return partPos(pp.Parent) end
    return partPos(room:FindFirstChild("Minigame") or room)
end
-- ฆ่าผี: จงใจให้ยา "ผิด" (ยาที่ไม่ใช่ของห้องนี้) 1 ตัว
-- *** ทำเฉพาะตอนผีถึงขั้น "จ่ายยา" แล้ว (Apply Treatment พร้อม) — ก่อนหน้านั้นปล่อย flow ปกติ ***
local function killWithWrongMed(room)
    -- v4.55: เงื่อนไขเริ่ม = "วินิจฉัยเสร็จ (จอขึ้นรายการยา)" ไม่ใช่รอ Apply เปิด
    -- เพราะ Apply เปิดเฉพาะตอน "ถือไอเทมอยู่" — รอ Apply ก่อนไปหยิบยา = กับดักไก่กับไข่ ค้างตลอด
    local meds = requiredMeds(room)
    local bedPP = bedApplyPP(room)
    local applyOpen = bedPP and bedPP.Parent and bedPP.Enabled
    if #meds == 0 and not applyOpen then
        setStatus("ผี" .. room.Name .. ": รอวินิจฉัยเสร็จ")
        return false
    end
    local needed = {}
    for _, m in ipairs(meds) do needed[m] = true end
    -- v4.62: หา "ยาผิด" จากรายชื่อยาที่รู้จัก ผ่าน findPickup (ค้น ActionText ทั้งแมพ —
    -- ไม่ผูก path Model.Items ที่เกมย้าย/ลบไปแล้ว) ; เลือกตัวแรกที่ไม่อยู่ในรายการของห้องนี้
    local MED_NAMES = {
        "Herbs", "Eye Drops", "Cough Syrup", "Maple Syrup", "Medicine", "Ointment", "Thermo",
        "Bandages", "Medkit", "Antibiotics", "IV Drops",
    }
    -- + ไดนามิก: ยาที่จอ "ห้องอื่น" เรียกอยู่ = เป็นยาแน่นอน (กันเกมออกยาใหม่ที่ไม่อยู่ในลิสต์)
    local rooms = workspace:FindFirstChild("Rooms")
    if rooms then
        for _, grp in ipairs({"Medical", "Emergency"}) do
            local g = rooms:FindFirstChild(grp)
            if g then for _, r2 in ipairs(g:GetChildren()) do
                if r2 ~= room then
                    for _, mm in ipairs(requiredMeds(r2)) do MED_NAMES[#MED_NAMES+1] = mm end
                end
            end end
        end
    end
    local wrongName, wrongPP
    for _, name in ipairs(MED_NAMES) do
        if not needed[name] then
            local pp = findPickup(name)
            if pp and pp.Parent then wrongName, wrongPP = name, pp; break end
        end
    end
    if not wrongName then setStatus("ผี" .. room.Name .. ": หายาผิดไม่เจอ"); return false end
    setStatus("ผี" .. room.Name .. ": ยาผิด=" .. wrongName)
    -- ถือยาเต็ม 3 ช่อง = เก็บเพิ่มไม่ได้ → ทิ้งอันแรกก่อน
    if not findTool(wrongName) then
        -- v4.93: ของสำคัญ (Taser/ถังดับเพลิง/Gun) ได้ช่องเพิ่ม ไม่กินโควต้า 3 ช่องยา — นับเฉพาะของทิ้งได้
        local n = 0
        for _, t in ipairs(heldTools()) do if not protectedTool(t) then n += 1 end end
        if n >= 3 then
            for _, t in ipairs(heldTools()) do
                if not protectedTool(t) then discardTool(t) break end
            end
        end
    end
    if not findTool(wrongName) and wrongPP and wrongPP.Parent then
        tpTo(partPos(wrongPP.Parent)); task.wait(0.18)
        pressPrompt(wrongPP, function() return findTool(wrongName) ~= nil end, true); task.wait(0.1)
    end
    if not findTool(wrongName) then setStatus("ผี" .. room.Name .. ": เก็บยาผิดไม่ขึ้น"); return false end
    if not selectTool(wrongName) then
        setStatus("ผี" .. room.Name .. ": หยิบ " .. wrongName .. " ขึ้นมือไม่ได้")
        return false
    end
    -- v4.56: ถือยาผิดแล้ว → ไปเตียง → ยิงเลย เหมือน path รักษาปกติเป๊ะ (ไม่รอ/ไม่เช็ค Enabled)
    bedPP = bedApplyPP(room)
    if not (bedPP and bedPP.Parent) then return false end
    tpTo(partPos(bedPP.Parent)); task.wait(0.18)
    setStatus("ผี" .. room.Name .. ": จ่าย " .. wrongName)
    if bedPP.Enabled then
        pressPrompt(bedPP)
    else
        pcall(fp, bedPP, 0)   -- prompt ยังไม่ Enabled ก็ลองยิงตรงแบบเดิม (pressPrompt จะ no-op)
    end
    task.wait(0.2); return true
end
-- ทำหนึ่งห้องที่วินิจฉัยเสร็จ: เก็บยาที่ถูก → ไปเตียง → equip+apply ทีละชนิด
local function treatRoom(room)
    if roomDone(room) then return false end          -- เสร็จ/ฟื้นแล้ว → ไม่วาปซ้ำ
    -- v4.54: ผีประจำห้อง (เปิดฆ่าผี) = รักษาตามขั้นตอนครบเหมือนคนไข้จริง (DNA/เครื่อง/วินิจฉัย)
    -- แล้ว "หักมุมตอนจ่ายยา" — Apply พร้อมเมื่อไหร่ค่อยยาผิด ; ห้ามไหลไปเก็บ/ให้ยาถูก (จะกลายเป็นรักษาผีหาย)
    local patient = roomPatient(room)
    if not patient then return false end   -- v4.60: ไม่มีคนไข้ (ตาย/ออกไปแล้ว) = ห้ามทำอะไรกับห้องนี้
    -- v4.65: บินไปหาตัวคนไข้ก่อนเริ่มงาน (เหมือนเช็คอิน) — อยู่ไกลเกิน 10 ค่อยบิน, ghostSafe กันจ่อผีเอง
    do
        local pPos, me = partPos(patient), hrp() and hrp().Position
        if pPos and me and (pPos - me).Magnitude > 10 then
            tpTo(pPos); task.wait(0.1)
        end
    end
    local ghost = patient and patient:GetAttribute("Skinwalker")
    if ghost then
        if not KILLGHOST_ON then return false end
        -- v4.76: ผีดื้อยา (MedicineImmune) — ยาผิดฆ่าไม่เข้า ("the mass of eyes seems unaffected")
        -- ป้อนต่อ = เปลืองยา+เสียเวลาฟรี → ข้ามห้องนี้ไปเลย
        if patient:GetAttribute("MedicineImmune") then
            setStatus("ผี" .. room.Name .. " ดื้อยา — ข้าม")
            return false
        end
        local bedPP = bedApplyPP(room)
        -- v4.55: วินิจฉัยเสร็จ (จอขึ้นรายการยา) หรือ Apply เปิด = เข้าขั้นจ่ายยาผิดได้เลย
        if (bedPP and bedPP.Parent and bedPP.Enabled) or #requiredMeds(room) > 0 then
            return killWithWrongMed(room)
        end
        -- ยังไม่ถึง → ทำสเต็ปวินิจฉัยข้างล่างเหมือนคนไข้ปกติ (บังคับเข้า branch วินิจฉัยเสมอ)
    end
    local meds = requiredMeds(room)
    -- ยังไม่วินิจฉัย: คนไข้นอนเตียงแล้ว → ทำเครื่อง (Talk/DNA ที่ตัว + Analyze/Process ในห้อง)
    -- MACHINE_ON=ON วาปไปก่อนยิง | OFF ยิงในที่ (ไม่วาป — เราเดินไปเอง เหมือน Ver.ก่อน)
    if #meds == 0 or ghost then   -- v4.54: ผี = อยู่ในโหมดวินิจฉัยตลอด ไม่มีวันไปเก็บ/ให้ยาถูก
        -- v4.10: ถอด gate "R6_ON ข้าม Room6" ออก — เดิมทำให้บอทไม่วาปไป Room6 เลยตอนเปิดสี R6
        -- (ช่วงเล่นปริศนาสี prompt ในห้อง Enabled=false หมดอยู่แล้ว → ไม่มีวาปแย่งกัน)
        local DIAG_NPC  = { ["Talk"]=true, ["Take DNA Sample"]=true }   -- prompt บนตัวคนไข้
        local DIAG_ROOM = {                                             -- prompt ในห้อง (เครื่อง + เตรียมคนไข้)
            ["Analyze Sample"]=true, ["Process Results"]=true,          -- Medical
            ["Prepare Patient"]=true, ["Sleep Patient"]=true,           -- Emergency เตรียมคนไข้ลงเตียง
            ["Begin X-Ray"]=true, ["Set Up"]=true, ["Turn On"]=true,    -- Emergency เครื่อง (Room6 X-Ray / Room7 Heart)
            ["Begin"]=true, ["Collect"]=true,                           -- เริ่มเครื่อง / เก็บผล
        }                                                               -- (Inspect = ซูมจอ ไม่ใช่งาน — ห้ามใส่)
        -- prompt บน "ตัวคนไข้" (Talk/DNA): กดเฉพาะตอนคนไข้อยู่ในห้องจริง (InBed/ใกล้ห้อง <35)
        --   กันวาปไปกดคนไข้ที่ยังยืนอยู่เคาน์เตอร์ (roomPatient จับด้วย DesignatedRoom ตั้งแต่ก่อนเดินเข้าห้อง)
        local rpos = roomPos(room)
        local pPos = patient and partPos(patient)
        local patInRoom = patient and (patient:GetAttribute("InBed")
            or (rpos and pPos and (pPos - rpos).Magnitude < 35))
        if patInRoom then
            for _, p in ipairs(patient:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Enabled and DIAG_NPC[p.ActionText] then
                    if MACHINE_ON then tpTo(partPos(patient)); task.wait(0.15) end
                    pressPrompt(p); task.wait(0.1)
                end
            end
        end
        -- *** เครื่อง/เตรียมคนไข้ ในห้อง (Sleep Patient ฯลฯ): ทำได้เสมอ — prompt อยู่ในห้อง ไม่ใช่เคาน์เตอร์ ***
        -- (เดิม v3.3 gate ทั้งก้อน → Room8 'Sleep Patient' ไม่ยิง = ผ่าตัดไม่เริ่ม วาปมาแต่ไม่ทำ)
        for _, p in ipairs(room:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.Enabled and DIAG_ROOM[p.ActionText] then
                if MACHINE_ON then tpTo(partPos(p.Parent)); task.wait(0.15) end
                pressPrompt(p); task.wait(0.1)
            end
        end
        return false
    end
    -- ===== v4.61: "ถือทีละชิ้นเดียว" — หยิบ 1 จ่าย 1 ตามลำดับจอ =====
    -- เกมอ่านช่อง hotbar ที่เลือก ไม่ใช่ Tool ที่ถือ (จอ touch เลือกช่องไม่ได้) — ถือหลายชิ้น
    -- = slot กับของในมือเหลื่อมกันได้ = จ่ายผิด = ตาย ; ถือชิ้นเดียวตลอด = ผิดไม่ได้
    -- v4.68: เช็ค "รายชนิดแบบนับจำนวน" แทนราย frame — ของซ้ำ (Scalpel ×2) เกมอาจติ๊ก
    -- คนละใบกับที่เราเล็ง → เช็คราย frame เห็นใบแรกว่างแล้วจ่ายชนิดเดิมซ้ำ = ผิดคิว = ตาย
    local function givenCount(m)
        local g = 0
        for _, fr in ipairs(invFrames(room)) do
            if frameMed(fr) == m and frameGiven(fr) then g += 1 end
        end
        return g
    end
    -- ชิ้นถัดไปตามลำดับจอ = ชนิดแรกที่ "ลำดับที่เจอ" เกินจำนวนที่ให้ไปแล้ว
    local function nextMed()
        local cnt = {}
        for _, fr in ipairs(invFrames(room)) do
            local m = frameMed(fr)
            cnt[m] = (cnt[m] or 0) + 1
            if cnt[m] > givenCount(m) then return m end
        end
    end
    if not nextMed() then return false end
    local guard = 0
    while not roomDone(room) and guard < 12 do
        guard += 1
        local m = nextMed()
        if not m then break end
        -- 1) เคลียร์มือ: ทิ้งทุกชิ้นที่ไม่ใช่ m (ถือชิ้นเดียวตลอด — slot ผิดไม่ได้)
        for _, t in ipairs(heldTools()) do
            if t.Name ~= m then discardTool(t) end
        end
        -- 2) ยังไม่มี m → บินไปหยิบมา 1 ชิ้น
        if heldCount(m) == 0 then
            local pp = findPickup(m)
            if not (pp and pp.Parent) then return false end
            tpTo(partPos(pp.Parent)); task.wait(0.15)
            pressPrompt(pp, function() return heldCount(m) > 0 end, true)
            task.wait(0.1)
            if heldCount(m) == 0 then return false end   -- หยิบไม่ขึ้น → หยุด
        end
        if not selectTool(m) then return false end       -- ชิ้นเดียวในมือ ยกขึ้นถือ
        -- 3) บินไปเตียง (prompt บนตัวคนไข้ = บินตามตัวสด) → จ่าย ; done = ของหายจากมือ/ยอดชนิดขยับ
        local bedPP = bedApplyPP(room)
        if not (bedPP and bedPP.Parent) then return false end
        local owner = npcOwner(bedPP)
        tpTo(owner and partPos(owner) or partPos(bedPP.Parent)); task.wait(0.15)
        local gBefore, hBefore = givenCount(m), heldCount(m)
        pressPrompt(bedPP, function()
            return heldCount(m) < hBefore or givenCount(m) > gBefore or roomDone(room)
        end)
        if heldCount(m) < hBefore then                   -- ของเข้าแล้ว → รอยอดชนิดขยับ (ห้ามกดซ้ำ)
            local t0 = os.clock()
            repeat task.wait(0.05)
            until givenCount(m) > gBefore or roomDone(room) or os.clock() - t0 > 2
        end
        if givenCount(m) <= gBefore and not roomDone(room) then return false end -- ไม่คืบ = หยุด (ไม่เดา)
        task.wait(0.1)
    end
    return true
end

-- ===== ESP helper: สร้าง/อัปเดต Highlight + ป้ายชื่อ (ทะลุกำแพง) =====
local function applyESP(model, kind, distStr)
    if not model or not model.Parent then return end
    local e = ESP[model]
    if not e or not e.Parent then
        if e then pcall(function() e:Destroy() end) end
        e = Instance.new("Highlight")
        e.FillTransparency = 0.6
        e.OutlineTransparency = 0
        e.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop   -- ทะลุกำแพง
        e.Adornee = model
        e.Parent  = model
        -- ป้ายชื่อลอยเหนือหัว
        local head = model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
        if head then
            local bb = Instance.new("BillboardGui")
            bb.Name = "AH74Tag"; bb.Adornee = head; bb.AlwaysOnTop = true
            bb.Size = UDim2.new(0, 150, 0, 20); bb.StudsOffset = Vector3.new(0, 2.8, 0)
            bb.Parent = e
            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1
            t.Font = Enum.Font.GothamBold; t.TextScaled = true
            t.TextStrokeTransparency = 0.3; t.Parent = bb
        end
        ESP[model] = e
    end
    e.FillColor = COL[kind]; e.OutlineColor = COL[kind]
    local bb = e:FindFirstChild("AH74Tag")
    local t  = bb and bb:FindFirstChildOfClass("TextLabel")
    if t then
        t.Text = ("[%s] %s%s"):format(LBL[kind], model.Name, distStr)
        t.TextColor3 = COL[kind]
    end
end

local function npcKind(m)
    if m:GetAttribute("Anomaly")    then return "anomaly" end   -- v4.37 Hider/ผีซ่อน (WaterEntity ฯลฯ)
    if m:GetAttribute("Skinwalker") then return "ghost" end     -- อันตรายจริง
    -- v4.41: attr กล้อง/รูปผี (TwistNeck/CursedPhoto/DifferentFace/...) เจอเฉพาะบน Skinwalker
    -- ตัวไหนมีแต่ยังไม่ขึ้น Skinwalker = ผีปลอมตัวที่เกมยังไม่เฉลย → ส้ม "น่าสงสัย!"
    if m:GetAttribute("CameraEffect") or m:GetAttribute("PhotoEffect")
       or m:GetAttribute("HasCameraEffect") or m:GetAttribute("HasPhotoEffect") then return "sus" end
    -- v4.49: มี prompt 'Ask to Leave' = ผีปลอมตัวแบบ attr สะอาด (เจอจาก Jack Hawks) → น่าสงสัย
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == "Ask to Leave" then return "sus" end
    end
    if m:GetAttribute("IsPatient")  then return "patient" end   -- คนไข้จริง
    if m:GetAttribute("IsVisitor")  then return "visitor" end   -- v4.44 คนมาเยี่ยมไข้ (DesignatedRoom=ห้องที่จะไปเยี่ยม)
    return "npc"   -- Fake/พนักงาน = NPC ทั่วไป (ไม่ใช่ผี)
end

-- ===== ESP refresh loop (re-check attr ทุก 0.5s — ผีเปลี่ยนสภาพกลางเกมก็เห็น) =====
local acc = 0
bind(RS.Heartbeat, function(dt)
    -- Speed (ทุก frame กัน reset/respawn)
    if RUN_ON then local h = hum(); if h then h.WalkSpeed = SPEED end end
    -- v4.47: โหมดวาป + auto ทำงานอยู่ = ปิดกระโดด (ไม่มีจังหวะตัวลอย → วาปพลาดตาย)
    do
        local h = hum()
        if h then
            local block = TP_ON and (AUTO_ON or FIRE_ON or CHECKIN_ON)
            h:SetStateEnabled(Enum.HumanoidStateType.Jumping, not block)
        end
    end
    -- v5.10: ตาข่ายนิรภัยกันจมแมพ — หลุดต่ำกว่าพื้น (พื้นจริง Y≈3.4) = ดึงกลับทันที
    do
        local r = hrp()
        if r and r.Position.Y < 0 then
            r.AssemblyLinearVelocity = Vector3.zero
            r.CFrame = CFrame.new(Vector3.new(r.Position.X, 4, r.Position.Z))
                * (r.CFrame - r.CFrame.Position)
        end
    end
    -- Noclip (ทุก frame)
    if NOCLIP_ON then
        local c = LP.Character
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end end
    end

    -- Auto: ยิงสเต็ป เช็คอิน (CHECKIN_ON) + วินิจฉัย/เตรียม (AUTO_ON) — หยุดตอนกำลังจ่ายยา (WORKING)
    if (AUTO_ON or CHECKIN_ON) and fp and not WORKING then
        fireAcc += dt
        if fireAcc >= 0.3 then   -- v4.9 เร็วขึ้น 2 เท่า
            fireAcc = 0
            -- v4.27: เช็คอินวาปหาคนไข้ — v4.75: งานอันดับท้ายสุด ทำเฉพาะตอน "ว่างจริง"
            -- (ไม่มีคนเป็นลม/ไฟ/สไลม์ และ treat loop ไม่มีห้องให้ทำ)
            if CHECKIN_ON and not TREAT_BUSY and not faintPending()
               and not firePending() and not slimePending() and not gunPending() then   -- v5.18: ยิงผีก่อนเช็คอิน
                local cpos = checkinPending()
                if cpos then
                    local misc = workspace:FindFirstChild("Misc")
                    local sb = misc and misc:FindFirstChild("ShutterButton")
                    local spp = sb and sb:FindFirstChild("PP")
                    if spp and spp.Enabled and spp.ActionText == "Open" then   -- ประตูปิดอยู่ → เปิดก่อน
                        ciGo(Vector3.new(-113.5, 3.4, -0.6)); task.wait(0.15)   -- v5.04: จุดยืนปุ่มชัตเตอร์ (spy)
                        pressPrompt(spp)
                    end
                    ciGo(cpos)   -- v5.02: เดินเข้าจุดในเคาน์เตอร์ (80, ไม่ไถล) — ไม่ใช้สไลด์ 250
                end
            end
            for _, p in ipairs(workspace:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Enabled then
                    local a = p.ActionText
                    local owner = npcOwner(p)
                    -- *** ห้ามยุ่งกับผี: ไม่กด prompt ใดๆ บนตัว Skinwalker (Talk/DNA/มอบใบ) ไม่ว่า toggle ไหนเปิด ***
                    -- (Talk อยู่ใน TREATD_ACTS ด้วย → ต้องกันที่ระดับ owner ไม่ใช่แค่ npcStep) — ใช้ชัตเตอร์/ยาผิดจัดการผีแทน
                    if not (owner and owner:GetAttribute("Skinwalker")) then
                        -- มอบใบรับหมาย = กด E ที่ NPC — v4.49: ยิงเฉพาะ 'Talk' เท่านั้น
                        -- ห้ามยิง prompt อื่นบน NPC ('Ask to Leave' = กับดักผีปลอมตัว attr สะอาด กดแล้วซวย)
                        local npcStep = CHECKIN_ON and owner ~= nil and a == "Talk"
                        if (CHECKIN_ON and CHECKIN_ACTS[a]) or (AUTO_ON and TREATD_ACTS[a]) or npcStep then
                            pcall(fp, p, 0)   -- เกม gate ลำดับเอง
                        end
                    end
                end
            end
        end
    end

    acc += dt
    if acc < 0.4 then return end
    acc = 0
    -- ลองเร่ง NPC (ทุก 0.4s) — ถ้า server คุมการเดินจะไม่มีผล (ทดสอบดู)
    if NPCFAST_ON then
        local npcs = workspace:FindFirstChild("NPCs")
        if npcs then for _, m in ipairs(npcs:GetChildren()) do
            local h = m:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = NPC_SPEED end
        end end
    end
    if not ESP_ON then return end

    local fromPos = hrp() and hrp().Position
    local wanted = {}

    -- เพื่อนผู้เล่น (ทุกคนทีมเดียว)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local dStr = (fromPos and root) and (" "..math.floor((root.Position-fromPos).Magnitude).."m") or ""
            applyESP(p.Character, "mate", dStr)
            wanted[p.Character] = true
        end
    end

    -- NPC ใน Workspace.NPCs
    local npcs = workspace:FindFirstChild("NPCs")
    if npcs then
        for _, m in ipairs(npcs:GetChildren()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
                local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
                local dStr = (fromPos and root) and (" "..math.floor((root.Position-fromPos).Magnitude).."m") or ""
                applyESP(m, npcKind(m), dStr)
                wanted[m] = true
            end
        end
    end

    -- ลบ ESP ของตัวที่หายไป (ตาย/respawn/ออกห้อง)
    for model, e in pairs(ESP) do
        if not wanted[model] or not model.Parent then
            pcall(function() e:Destroy() end); ESP[model] = nil
        end
    end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AH74GUI", false, 9999
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")

local FULL_H = 226   -- v4.43: ยุบเหลือ 5 แถว + CLOSE (รวมปุ่มแล้ว)
local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0,192,0,FULL_H), UDim2.new(0,20,0.5,-146)
f.BackgroundColor3, f.BackgroundTransparency = Color3.fromRGB(18,18,24), 0.1
f.BorderSizePixel, f.Active, f.Draggable = 0, true, true
f.ClipsDescendants = true   -- ย่อ = ซ่อนปุ่มที่อยู่ใต้แถบหัว
Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", f).Color = Color3.fromRGB(90,120,255)

local title = Instance.new("TextLabel", f)
title.Size, title.Position = UDim2.new(1,-40,0,26), UDim2.new(0,8,0,4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(150,180,255)
title.Text, title.Font, title.TextSize = "AH74 v5.21", Enum.Font.GothamBold, 14   -- โชว์เวอร์ชัน+สถานะบนหัว GUI
title.TextScaled = true
-- v4.46 กล่องดำ: จำสถานะล่าสุด — ตอนตายโชว์ค้างว่า "ตายตอนกำลังทำอะไร + ผีใกล้สุดกี่ studs"
local lastStatus, deadLock = "", false
setStatus = function(s)
    lastStatus = s or ""
    if not deadLock then title.Text = "v5.21 " .. lastStatus end
end
local function armDeathLog(char)
    local h = char:WaitForChild("Humanoid", 5)
    if not h then return end
    CONNS[#CONNS+1] = h.Died:Connect(function()
        local r = char:FindFirstChild("HumanoidRootPart")
        local gd = math.huge
        local npcs = workspace:FindFirstChild("NPCs")
        if r and npcs then
            for _, m in ipairs(npcs:GetChildren()) do
                if m:GetAttribute("Skinwalker") or m:GetAttribute("Anomaly") then
                    local p = partPos(m)
                    if p then gd = math.min(gd, (p - r.Position).Magnitude) end
                end
            end
        end
        deadLock = true
        title.Text = ("💀ตายตอน: %s | ผีใกล้สุด %s"):format(
            lastStatus ~= "" and lastStatus or "?", gd < math.huge and math.floor(gd).."m" or "-")
        print("[AH74 กล่องดำ] " .. title.Text)
        task.delay(20, function() deadLock = false end)   -- โชว์ค้าง 20s แล้วกลับมาปกติ
    end)
end
if LP.Character then armDeathLog(LP.Character) end
bind(LP.CharacterAdded, armDeathLog)
title.TextXAlignment = Enum.TextXAlignment.Left

-- ปุ่มย่อ/ขยาย (มุมขวาบน) — กดยุบเหลือแถบหัว กดอีกทีกาง
local minB = Instance.new("TextButton", f)
minB.Size, minB.Position = UDim2.new(0,26,0,22), UDim2.new(1,-32,0,4)
minB.Text, minB.TextScaled = "—", true
minB.BackgroundColor3 = Color3.fromRGB(60,60,80)
minB.TextColor3, minB.BorderSizePixel = Color3.fromRGB(255,255,255), 0
Instance.new("UICorner", minB).CornerRadius = UDim.new(0,6)
local minimized = false
minB.MouseButton1Click:Connect(function()
    minimized = not minimized
    f.Size = UDim2.new(0,192,0, minimized and 34 or FULL_H)
    minB.Text = minimized and "+" or "—"
end)

local function btn(txt, x, y, w, h, col)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0,w,0,h), UDim2.new(0,x,0,y)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3 = col or Color3.fromRGB(45,45,58)
    b.TextColor3, b.BorderSizePixel = Color3.fromRGB(255,255,255), 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    Instance.new("UIPadding", b).PaddingTop = UDim.new(0,4)
    return b
end

local espB = btn("ESP: ON", 8, 66, 86, 30, Color3.fromRGB(40,150,70))
espB.MouseButton1Click:Connect(function()
    ESP_ON = not ESP_ON
    espB.Text = "ESP: " .. (ESP_ON and "ON" or "OFF")
    espB.BackgroundColor3 = ESP_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if not ESP_ON then
        for m, e in pairs(ESP) do pcall(function() e:Destroy() end); ESP[m] = nil end
    end
end)

local runB = btn("RUN: OFF", 98, 66, 86, 30)
runB.MouseButton1Click:Connect(function()
    RUN_ON = not RUN_ON
    runB.Text = "RUN: " .. (RUN_ON and "ON" or "OFF")
    runB.BackgroundColor3 = RUN_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if not RUN_ON then local h = hum(); if h then h.WalkSpeed = 16 end end
end)

local spdL = btn(tostring(SPEED), 98, 162, 34, 30); spdL.Active = false
btn("−", 134, 162, 24, 30).MouseButton1Click:Connect(function()
    SPEED = math.max(16, SPEED - 10); spdL.Text = tostring(SPEED)
end)
btn("+", 160, 162, 24, 30).MouseButton1Click:Connect(function()
    SPEED = SPEED + 10; spdL.Text = tostring(SPEED)
end)

local clipB = btn("NOCLIP: OFF", 8, 98, 86, 30)
clipB.MouseButton1Click:Connect(function()
    NOCLIP_ON = not NOCLIP_ON
    clipB.Text = "NOCLIP: " .. (NOCLIP_ON and "ON" or "OFF")
    clipB.BackgroundColor3 = NOCLIP_ON and Color3.fromRGB(150,40,150) or Color3.fromRGB(45,45,58)
    if not NOCLIP_ON then
        local c = LP.Character
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end end
    end
end)

-- v4.43: ปุ่มรักษา = รวม ทำเครื่อง+ตีตัว(whack)+สี R6 ในปุ่มเดียว (แถวบนสุด)
local autoB = btn("รักษา: OFF", 8, 34, 86, 30)
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    MACHINE_ON, WHACK_ON, R6_ON = AUTO_ON, AUTO_ON, AUTO_ON
    autoB.Text = "รักษา: " .. (AUTO_ON and "ON" or "OFF")
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if AUTO_ON and not fp then autoB.Text = "ไม่มี fp!" end
end)

-- v5.15: อ่านแบนเนอร์ภาวะฉุกเฉิน (PlayerGui.EmergencyCounter.Frame.Feed — text+timer ต่อเหตุการณ์)
--        "ผู้ป่วยวิกฤตในห้อง X" / "Patient being eaten in room X" → ห้องนั้นแซงคิวทุกห้อง
local function criticalRooms()
    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    local feed = pg and pg:FindFirstChild("EmergencyCounter")
    feed = feed and feed:FindFirstChild("Frame")
    feed = feed and feed:FindFirstChild("Feed")
    if not feed then return out end
    for _, fr in ipairs(feed:GetChildren()) do
        local t = fr:FindFirstChild("text")
        if t and t:IsA("TextLabel") then
            local n = t.Text:match("ห้อง%s*(%d+)") or t.Text:lower():match("room%s*(%d+)")
            if n then out["Room" .. n] = true end
        end
    end
    return out
end

-- ===== v5.16 ยิงผีด้วยปืน (remote PlayShootEffect) — ไม่กินกระสุน ไม่ต้องเล็ง/หมุนตัว =====
-- พิสูจน์แล้ว: FireServer(จุดยิง, หัวผี) = server ฆ่าให้ ; ยิงเฉพาะ Skinwalker จริง กัน NPC ดีเป็นลม
-- (เกมทำดาเมจฝั่ง server แต่ "เชื่อ" part ที่เราส่งไป → ส่งหัวผีเป๊ะ 100% ไม่พลาด)
local shootRE
local function findShootRE()
    if shootRE and shootRE.Parent then return shootRE end
    -- v5.17: ค้นแค่ ReplicatedStorage (remote อยู่ที่นี่) — game:GetDescendants ทั้งเกม = ค้างนาน
    for _, d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if d:IsA("RemoteEvent") and d.Name:find("PlayShootEffect") then shootRE = d; return d end
    end
end
local function equipGun()   -- v5.18: หยิบปืนขึ้นมือ (เงื่อนไข remote = ต้อง equip ก่อน)
    local c = LP.Character
    local held = c and c:FindFirstChild("Gun")
    if held then return held end
    local gun = c and c:FindFirstChild("Gun")
        or (LP:FindFirstChild("Backpack") and LP.Backpack:FindFirstChild("Gun"))
    local h = hum()
    if gun and h then pcall(function() h:EquipTool(gun) end); task.wait(0.2) end
    return c and c:FindFirstChild("Gun")
end
-- v5.19: หาจุดยืนยิงที่ "ไม่ติดกำแพง" — วน 8 มุมรอบผี ห่าง ~10 studs, raycast ไปหัวผีต้องโล่ง
--        คืนจุดใกล้ตัวเราสุดที่ยิงโดนแน่ (nil = รอบตัวมันมีกำแพงหมด → ข้ามไว้ก่อน)
local function clearShotSpot(m, head)
    local hpos = head.Position
    local me = hrp() and hrp().Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { m, LP.Character }
    local best, bestD
    for i = 0, 7 do
        local ang = i * math.pi / 4
        local cand = hpos + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 10
        local res = workspace:Raycast(cand, hpos - cand, params)   -- โล่ง = ไม่โดนอะไร (ผี exclude ไว้)
        if not res then
            local d = me and (cand - me).Magnitude or 0
            if not best or d < bestD then best, bestD = cand, d end
        end
    end
    return best
end
-- v5.18: วาร์ปไปยิงผี — ระบบสไลด์ปกติ (Y-lock) + equip + ยิง 1 นัด/ตัว + จำว่ายิงแล้ว (กระสุนจำกัด)
task.spawn(function()
    local shotAt = {}   -- ยิงแล้วพัก 3s/ตัว (เผื่อนัดหลุด) — เช็ค Humanoid ตายก่อนยิงซ้ำ
    while _G.AH74_GEN == MYGEN do
        if GUNKILL_ON and not WORKING and not CARRYING and not faintPending() then
            local re = findShootRE()
            local npcs = workspace:FindFirstChild("NPCs")
            local me = hrp() and hrp().Position
            if re and npcs and me then
                -- หาผีใกล้สุดที่ยังไม่ตาย + ยังไม่เพิ่งยิง
                local target, td, thead
                for _, m in ipairs(npcs:GetChildren()) do
                    if ghostToShoot(m) and (not shotAt[m] or os.clock() - shotAt[m] > 3) then
                        local head = m:FindFirstChild("Head") or m:FindFirstChildWhichIsA("BasePart")
                        local hpos = head and head.Position
                        local d = hpos and (hpos - me).Magnitude
                        if head and d and d < 200 and (not target or d < td) then
                            target, td, thead = m, d, head
                        end
                    end
                end
                if target then
                    -- v5.19: หามุมยิงโล่ง (ไม่ติดกำแพง) แล้ววาร์ปไปยืนตรงนั้นก่อนยิง
                    local spot = clearShotSpot(target, thead)
                    if spot then
                        shotAt[target] = math.huge   -- v5.20: ยิงแล้ว = ไม่ยิงตัวนี้ซ้ำอีก (ragdoll ค้างทำให้เข้าใจผิดว่ายังไม่ตาย)
                        setStatus("วาร์ปยิงผี " .. target.Name)
                        tpTo(spot); task.wait(0.1)   -- วาร์ปไปจุดยิงโล่ง (สไลด์+Y-lock)
                        local gun = equipGun()
                        local r = hrp()
                        if gun and r and thead.Parent then
                            pcall(function() re:FireServer(r.Position, thead) end)
                        end
                    else
                        -- รอบตัวผีมีกำแพงหมด (เอื้อมไม่ถึงมุมยิง) → พักตัวนี้ 3s ไปตัวอื่นก่อน
                        shotAt[target] = os.clock()
                        setStatus("ผี " .. target.Name .. " ติดกำแพง — ข้าม")
                    end
                end
            end
        end
        task.wait(0.4)
    end
end)

-- loop ให้ยา: ทำ "ทีละห้องจนจบ" (ไม่วนข้ามห้องไปมา = กันวาปสับสน/ให้ยาผิด)
-- เลือกห้องใกล้สุดที่ยังต้องทำ → commit ทำจน done (หรือหมดเวลา ~6s) ก่อนเปลี่ยนห้อง
task.spawn(function()
    local lastStream = 0   -- v4.98: กันยิง RequestStream ถี่เกิน (yield ทีละ ~เฟรม)
    while _G.AH74_GEN == MYGEN do
        if AUTO_ON and fp and FIRE_ON and faintPending() then
            task.wait(0.2)   -- v4.72: มีคนเป็นลม (โหมดฉุกเฉินเปิด) = หลีกทางให้ loop อุ้ม
        elseif AUTO_ON and fp then
            local rooms = workspace:FindFirstChild("Rooms")
            if rooms then
                local fromPos = hrp() and hrp().Position
                local target, bestD
                local why = {}   -- v4.97: เหตุผลที่ข้ามห้องที่มีคนไข้ — โชว์ตอน "ว่าง" ไล่บั๊กจากหน้าจอได้เลย
                local crit = criticalRooms()   -- v5.15: ห้องวิกฤต (มีเวลานับถอยหลัง) มาก่อนทุกห้อง
                for _, grp in ipairs({"Medical", "Emergency"}) do   -- 1-5 + 6/7/8
                    local f = rooms:FindFirstChild(grp)
                    if f then for _, room in ipairs(f:GetChildren()) do
                        local pat = roomPatient(room)
                        local ghost = pat and pat:GetAttribute("Skinwalker")
                        -- v4.57: คนไข้ต้อง "อยู่ที่ห้องจริง" (InBed/ใกล้ห้อง <35) — รักษาเสร็จเดินออกไปแล้ว
                        -- attr DesignatedRoom + รายการยาเก่าบนจอยังค้าง ทำบอทหลงว่าห้องมีงาน
                        local present = pat and (pat:GetAttribute("InBed") or (function()
                            local pPos, rPos = partPos(pat), roomPos(room)
                            return pPos and rPos and (pPos - rPos).Magnitude < 35
                        end)())
                        -- v4.76: ผีดื้อยา (MedicineImmune) ไม่นับเป็นงาน — ฆ่าด้วยยาผิดไม่ได้
                        local killable = ghost and KILLGHOST_ON and not pat:GetAttribute("MedicineImmune")
                        -- v4.99: ห้องโดน stream out (ไม่มีจอ) → จอ/ปุ่มเชื่อไม่ได้ ใช้ attr คนไข้แทน
                        --        (attr ติดตัว NPC ตลอด อ่านได้ทันที): IsPatient + ยังไม่ Treated = มีงาน
                        local loaded = getScreenUI(room) ~= nil
                        local work = loaded and (not roomDone(room) and hasWork(room, pat))
                            or (not loaded and pat and pat:GetAttribute("IsPatient")
                                and not pat:GetAttribute("Treated"))
                        if pat and present and (not ghost or killable) and work then
                            local pos = roomPos(room)
                            local d = (fromPos and pos) and (pos - fromPos).Magnitude or math.huge
                            -- v4.13: Room8 (ผ่าตัด) สำคัญสุด — v5.15: ห้องวิกฤตแซงอีกชั้น
                            if crit[room.Name] then d = -2
                            elseif room.Name == "Room8" then d = -1 end
                            if not target or d < bestD then target, bestD = room, d end
                        elseif pat then   -- v4.97: ห้องมีคนไข้แต่โดนข้าม — จดเหตุผลแรกที่ติด
                            local reason = not present and "ไกล" or (ghost and not killable) and "ผี"
                                or not loaded and "รักษาแล้ว" or roomDone(room) and "จบ" or "ไม่มีปุ่ม"
                            why[#why+1] = room.Name:gsub("Room", "R") .. ":" .. reason
                        end
                    end end
                end
                TREAT_BUSY = target ~= nil
                if target then
                    setStatus((crit[target.Name] and "วิกฤต! รีบรักษา " or "รักษา ") .. target.Name)
                    -- v4.99: ห้องเป้าหมายยังไม่โหลด → สั่งโหลด + บินเข้าไปเลย (โหลดระหว่างเดินทาง
                    --        = ดีเลย์น้อยสุด) — ไม่งั้น roomDone อ่านจอไม่ได้จะเด้งออกก่อนเริ่มงาน
                    if not getScreenUI(target) then
                        local pos = roomPos(target)
                        if pos then
                            pcall(function() LP:RequestStreamAroundAsync(pos, 1) end)
                            tpTo(pos)
                            local t0 = os.clock()
                            repeat task.wait(0.1) until getScreenUI(target) or os.clock() - t0 > 3
                        end
                    end
                    local guard = 0
                    -- v4.69: ทุกห้องสลับไวเท่ากัน (~1.6s) = คนไข้ 2 คนทำสลับกันได้ (บินไปมา)
                    -- ห้องที่เครื่องกำลังหมุน = ไม่มีปุ่มเปิด = โดนข้ามไปทำอีกห้องเอง ; ลำดับจ่ายยา
                    -- ทำจบใน treatRoom ครั้งเดียวอยู่แล้ว ไม่มีทางโดนขัดกลางคิว (เกาะ 60s เดิมไม่จำเป็น)
                    while AUTO_ON and _G.AH74_GEN == MYGEN
                          and not roomDone(target)
                          and roomPatient(target)   -- v4.60: คนไข้หาย (ตาย/ออก) = เลิกเกาะทันที
                          and guard < 8 do
                        guard += 1
                        WORKING = true
                        pcall(treatRoom, target)
                        WORKING = false
                        task.wait(0.2)
                    end
                else
                    -- v4.97: โชว์ว่าห้องไหนโดนข้ามเพราะอะไร (ไกล/ผี/จบ/ไม่มีปุ่ม) — ไม่มีคนไข้เลย = ว่างจริง
                    setStatus(#why > 0 and ("ว่าง " .. table.concat(why, " ")) or "ว่าง (ไม่มีห้องมีงาน)")
                end
            end
        end
        task.wait(0.1)   -- v4.9: เดิม 0.3 — สแกนหาห้องใหม่ให้ไวขึ้น
    end
end)

-- ===== Auto whack-a-mole: คลิกเป้าดีใน PlayerGui.Minigame.Frame เลี่ยง Danger(หัวกระโลก) =====
task.spawn(function()
    local pgui = LP:WaitForChild("PlayerGui")
    while _G.AH74_GEN == MYGEN do
        if WHACK_ON then
            local mg = pgui:FindFirstChild("Minigame")
            local fr = mg and mg:FindFirstChild("Frame")
            if fr then
                for _, it in ipairs(fr:GetChildren()) do
                    -- เป้าดี = visible + ไม่ใช่ Danger(หัวกระโลก); Template ที่ visible = clone จริงต้องกด
                    if it:IsA("GuiObject") and it.Visible and it.Name ~= "Danger"
                       and it.AbsoluteSize.X > 0 then
                        local p, s = it.AbsolutePosition, it.AbsoluteSize
                        local x, y = p.X + s.X/2, p.Y + s.Y/2 + 36  -- +inset topbar
                        pcall(function()
                            VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
                            VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
                        end)
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- ===== Auto Room6 ปริศนาสี (Simon "Copy the sequence") =====
do
    local function colors6()
        local r=workspace:FindFirstChild("Rooms"); r=r and r:FindFirstChild("Emergency")
        r=r and r:FindFirstChild("Room6"); r=r and r:FindFirstChild("Minigame")
        return r and r:FindFirstChild("Colors")
    end
    local function num6(p)
        local nm=p:FindFirstChild("ui"); nm=nm and nm:FindFirstChildOfClass("TextLabel")
        return nm and nm.Text or "?"
    end
    local function near6(a,b,t) return a and b and (math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B)<t) end
    local function btn6(num)
        local c=colors6(); if not c then return end
        for _,b in ipairs(c:GetDescendants()) do
            if b:IsA("BasePart") and b.Name=="Button" and num6(b)==num then return b end
        end
    end
    local fcd = fireclickdetector
    local function click6(b)
        -- v4.64: บินเข้าไปหาปุ่มก่อน (เหมือนงานเช็คอิน) — กดใกล้ๆ แม่นกว่ายิงข้ามห้อง
        tpTo(b.Position); task.wait(0.05)
        -- v4.33: หันหน้าเข้าหาปุ่มก่อนกด — executor นี้ fp/คลิกลงตัว "ตรงหน้า" (ปุ่ม 6 อันติดกัน หันเฉียง = กดผิดสี)
        local r = hrp()
        if r then
            pcall(function() r.CFrame = CFrame.lookAt(r.Position, Vector3.new(b.Position.X, r.Position.Y, b.Position.Z)) end)
            task.wait(0.05)
        end
        local cd=b:FindFirstChildWhichIsA("ClickDetector", true)
        if cd and fcd then pcall(fcd, cd); return end
        local pp=b:FindFirstChild("PP")
        if pp and fp then pcall(fp, pp, 0); return end
        local sp,vis=cam:WorldToViewportPoint(b.Position)
        if vis then pcall(function()
            VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, true, game, 0)
            VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, false, game, 0)
        end) end
    end
    local seq, bright, lastFlash, playing, attached = {}, {}, 0, false, {}
    local function attach6(b)
        if attached[b] or not b:IsA("BasePart") or b.Name~="Button" then return end
        attached[b]=true
        CONNS[#CONNS+1]=b:GetPropertyChangedSignal("Color"):Connect(function()
            if not R6_ON or playing then return end
            local n=num6(b); local isB=near6(b.Color, b:GetAttribute("MainColor"), 0.08)
            if isB and not bright[n] then seq[#seq+1]=n; lastFlash=os.clock() end
            bright[n]=isB
        end)
    end
    local function rearm6()
        local c=colors6(); if not c then return end
        for _,d in ipairs(c:GetDescendants()) do attach6(d) end
        CONNS[#CONNS+1]=c.DescendantAdded:Connect(attach6)
    end
    rearm6()
    bind(workspace.DescendantAdded, function(d) if d.Name=="Colors" then task.wait(0.2); rearm6() end end)
    task.spawn(function()
        while _G.AH74_GEN == MYGEN do
            if R6_ON and #seq>0 and not playing and (os.clock()-lastFlash)>3 then
                playing=true
                for _,n in ipairs(seq) do
                    if not R6_ON then break end
                    -- v4.30: กดช้าลง 0.35→0.7s — เกมรับไม่ทันตอนกดรัว = นับผิดบ่อย
                    local b=btn6(n); if b then click6(b); task.wait(0.7) end
                end
                seq={}; bright={}; task.wait(1.2); playing=false
            elseif not R6_ON then seq={}; bright={}; playing=false end
            task.wait(0.1)
        end
    end)
end

-- ===== Auto ปิดชัตเตอร์ใส่ผี: Skinwalker ยืนใกล้เคาน์เตอร์เช็คอิน → ปิดชัตเตอร์ =====
-- ชัตเตอร์ = Workspace.Misc.ShutterButton.PP (ActionText สลับ 'Open'/'Close') → ยิงตอน 'Close' เท่านั้น
--   พอปิดแล้ว ActionText เป็น 'Open' → ไม่ยิงซ้ำ/ไม่เผลอเปิดเอง (self-limiting)
-- ponytail: ระยะ 20 studs จากจุดเช็คอิน ; ปรับ COUNTER_RANGE ถ้าจับไกล/ใกล้ไป
do
    local COUNTER_RANGE = 20
    local function shutterPP()
        local misc = workspace:FindFirstChild("Misc")
        local sb = misc and misc:FindFirstChild("ShutterButton")
        return sb and sb:FindFirstChild("PP")
    end
    local function counterPos()
        local misc = workspace:FindFirstChild("Misc")
        if not misc then return nil end
        return partPos(misc:FindFirstChild("CheckIn")) or partPos(misc:FindFirstChild("ShutterButton"))
    end
    -- สแกนใกล้เคาน์เตอร์ → ghost(ผีอยู่), pending(คนไข้/ผู้เยี่ยมจริงที่ "ยังไม่เช็คอิน")
    -- v4.80: pending นับ IsVisitor ด้วย (เดิมปิดใส่กลางคันตอนเช็คอินให้ผู้เยี่ยม) + ขยายรัศมีเป็น
    --        INCOMING_RANGE 60 — คนไข้จริง "กำลังเดินมา" ก็ถือว่ารอ → เปิดประตูรอ ไม่ปิดใส่
    --        (เคาน์เตอร์มี 2 ช่อง คนจริงใช้อีกช่องได้ ผีบอทไม่เช็คอินให้อยู่แล้ว)
    local INCOMING_RANGE = 60
    local function counterScan()
        local cpos = counterPos(); if not cpos then return false, false, false end
        local npcs = workspace:FindFirstChild("NPCs"); if not npcs then return false, false, false end
        local ghost, pending, leaving = false, false, false
        for _, m in ipairs(npcs:GetChildren()) do
            if m:IsA("Model") then
                local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
                local d = r and (r.Position - cpos).Magnitude
                if d then
                    if m:GetAttribute("Skinwalker") then
                        if d < COUNTER_RANGE then ghost = true end          -- ผี (มี IsPatient ด้วยก็นับเป็นผี)
                    elseif (m:GetAttribute("IsPatient") or m:GetAttribute("IsVisitor"))
                       and not m:GetAttribute("Anomaly") then
                        if m:GetAttribute("CheckedIn") ~= true and not m:GetAttribute("CompletedCheckIn")
                           and d < INCOMING_RANGE then
                            pending = true                                   -- คนจริงรอ/กำลังเดินมา
                        end
                        -- v4.82: เช็คอินเสร็จแล้วแต่ยังยืนหน้าเคาน์เตอร์ = ยังไม่เดินออก → ห้ามปิดขังเขา
                        -- v4.84: กลับมาใช้ 20 (ผู้ใช้จูน — จุดวัดมีแค่ช่อง CheckIn เดียว 5 แคบไปไม่คลุม CheckIn2)
                        if d < COUNTER_RANGE then leaving = true end
                    end
                end
            end
        end
        return ghost, pending, leaving
    end
    -- ActionText: 'Close'=ประตูเปิดอยู่(กด→ปิด) | 'Open'=ประตูปิดอยู่(กด→เปิด)
    -- ลำดับ: คนไข้จริงยังไม่เช็คอิน → เปิดไว้ก่อน (เช็คอินคนดีก่อน แม้มีผีปนอยู่) ; เช็คอินครบแล้ว+ผียังอยู่ → ปิด
    task.spawn(function()
        while _G.AH74_GEN == MYGEN do
            if SHUTTER_ON and fp and not CARRYING then   -- v4.91: ห้ามแทรกตอนอุ้มคน
                local pp = shutterPP()
                if pp and pp.Parent then
                    local ghost, pending, leaving = counterScan()
                    local want = (pending and pp.ActionText == "Open")                   -- คนไข้จริงรอ → เปิด
                              -- v4.82: ปิดใส่ผีเฉพาะตอนหน้าเคาน์เตอร์เหลือแต่ผี (คนจริงเดินออกหมดแล้ว)
                              or (ghost and not pending and not leaving and pp.ActionText == "Close")
                    if want then
                        tpTo(Vector3.new(-113.5, 3.4, -0.6)); task.wait(0.15)   -- v5.04: จุดยืนปุ่มชัตเตอร์ (spy)
                        pressPrompt(pp)
                    end
                end
            end
            task.wait(0.4)
        end
    end)
end

-- ===== Auto ดับไฟ + ทาครีม: คนติดไฟ (BurningPatient) มี Workspace.NPCs.<ชื่อ>.FirePP =====
-- FirePP ActionText: 'Fire'(ดับเปลว ใช้ FireCharges) → 'Treat Burns'(ทาครีม Ointment)
-- flow: ดับไฟ → เก็บ Ointment (Workspace.Model.Items.Ointment.PP) → เลือก slot → ทา ; fp ยิงไกลได้ ไม่ใช้ถัง
local function doBurning(pp)
    local a = pp.ActionText
    if a == "Fire" then
        tpTo(partPos(pp.Parent)); task.wait(0.15)          -- วาปประชิดคนติดไฟ (ผู้ใช้ยืนยันว่าดีแล้ว)
        pressPrompt(pp)                                    -- ดับเปลว
    elseif a == "Treat Burns" then
        if heldCount("Ointment") < 1 then                  -- ยังไม่มีครีม → ไปเก็บ
            -- v4.89: เคลียร์มือก่อน (กฎถือทีละชิ้น — ถือของอื่นอยู่ = เก็บครีมไม่เข้า → วนค้าง)
            for _, t in ipairs(heldTools()) do
                if t.Name ~= "Ointment" then discardTool(t) end
            end
            local cream = findPickup("Ointment")
            if not (cream and cream.Parent) then return end
            tpTo(partPos(cream.Parent)); task.wait(0.18)
            pressPrompt(cream, function() return heldCount("Ointment") >= 1 end, true); task.wait(0.1)
            if heldCount("Ointment") < 1 then return end
        end
        if not selectTool("Ointment") then return end      -- เลือกครีมตามชื่อ
        tpTo(partPos(pp.Parent)); task.wait(0.15)          -- กลับไปหาคนไข้ (เผื่อวาปไปเก็บครีมมา)
        pressPrompt(pp, nil, true)                         -- ทาครีม (fp เท่านั้น — ถือของอยู่ กัน E มั่ว)
    end
end
task.spawn(function()
    local lastAct = {}   -- v4.31: เว้นจังหวะต่อ NPC 2s — กันวาปถี่จนไม่ได้กลับไปรักษา
    -- v4.95: ตารางพลาดย้ายไปแชร์เป็น BURN_FAIL — firePending จะได้ข้าม NPC ที่พักอยู่
    local fails = BURN_FAIL
    while _G.AH74_GEN == MYGEN do
        if FIRE_ON and fp and not WORKING and not CARRYING and not faintPending() then   -- v4.75: คนเป็นลมมาก่อนไฟ
            local npcs = workspace:FindFirstChild("NPCs")
            if npcs then for _, m in ipairs(npcs:GetChildren()) do
                local pp = m:FindFirstChild("FirePP")
                local f = fails[m]
                if pp and pp:IsA("ProximityPrompt") and pp.Enabled
                   and (not lastAct[m] or os.clock() - lastAct[m] > 2)
                   and (not f or f.n < 3 or os.clock() - f.t > 15) then
                    lastAct[m] = os.clock()
                    setStatus("ดับไฟ NPC " .. m.Name .. " (" .. pp.ActionText .. ")")
                    local before = pp.ActionText
                    doBurning(pp)
                    -- ไม่คืบหน้า (prompt ยังอยู่ ActionText เดิม) = พลาด 1 ครั้ง
                    if pp.Parent and pp.Enabled and pp.ActionText == before then
                        f = f or { n = 0 }
                        f.n, f.t = f.n + 1, os.clock()
                        fails[m] = f
                        if f.n >= 3 then setStatus("ทา " .. m.Name .. " ไม่เข้า — พัก 15s") end
                    else
                        fails[m] = nil
                    end
                end
            end end
        end
        task.wait(0.15)
    end
end)

-- ===== Auto ดับไฟกองพื้น: PP 'Put out fire' (ใต้ Rooms, attr Charges) — กด E ที่ไฟ ไม่ใช้ถัง =====
task.spawn(function()
    -- v4.95: cooldown/failN ย้ายไปแชร์เป็น FIRE_COOL/FIRE_FAILN — pending จะได้ข้ามจุดที่พัก
    local cooldown, failN = FIRE_COOL, FIRE_FAILN
    while _G.AH74_GEN == MYGEN do
        if FIRE_ON and fp and not WORKING and not CARRYING and not faintPending() then   -- v4.75: คนเป็นลมมาก่อน
            local rooms = workspace:FindFirstChild("Rooms")
            if rooms then
                -- v4.34: รวมกองไฟทั้งหมด → เรียง "ใกล้เราสุดก่อน" = ดับจากขอบนอกเข้าใน ไม่เดินทะลุไฟ
                -- v4.75: ไฟมาก่อนสไลม์ — เก็บสไลม์เฉพาะตอนไม่มีไฟเหลือ
                local fires = {}
                local mypos = hrp() and hrp().Position
                local function collect(root, act)
                    for _, d in ipairs(root:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == act
                           and (not cooldown[d] or os.clock() - cooldown[d] > 5) then
                            -- v4.40: เอาเฉพาะเป้าใกล้ตัว <120 studs (กันของหลอกนอกแมพ)
                            local pos = partPos(d.Parent)
                            if pos and mypos and (pos - mypos).Magnitude < 120 then
                                fires[#fires+1] = d
                            end
                        end
                    end
                end
                collect(rooms, "Put out fire")
                if #fires == 0 then
                    local misc = workspace:FindFirstChild("Misc")
                    if misc then collect(misc, "Clean Slime") end
                end
                local me = hrp() and hrp().Position
                if me then
                    table.sort(fires, function(a, b)
                        local pa, pb = partPos(a.Parent), partPos(b.Parent)
                        return ((pa or me) - me).Magnitude < ((pb or me) - me).Magnitude
                    end)
                end
                for _, d in ipairs(fires) do
                    -- v4.91: เช็คคนเป็นลม "ทุกกอง" ก่อนดับ — เดิมเช็คแค่ต้นรอบ พอไฟหลายกอง
                    --        มีคนเป็นลมกลางคันก็ยังดับต่อจนครบ (แย่งกับ loop อุ้ม = อุ้มคนไปดับไฟ)
                    if not (FIRE_ON and _G.AH74_GEN == MYGEN) or CARRYING or faintPending() then break end
                    if d.Parent and d.Enabled then
                        setStatus(d.ActionText == "Clean Slime" and "ล้างสไลม์" or "ดับไฟพื้น")
                        local pos = partPos(d.Parent)
                        local from = hrp() and hrp().Position
                        if pos then
                            -- ยืนห่างกองไฟ 8 studs ฝั่งที่เรามา (ไม่เหยียบไฟ) ; fp ยิงถึงจากตรงนั้น
                            local dir = from and (from - pos).Magnitude > 1 and (from - pos).Unit or Vector3.new(1, 0, 0)
                            tpTo(pos + dir * 8); task.wait(0.15)
                        end
                        -- v4.90: พลาดสะสม 3 ครั้ง = จุดนี้เอื้อมไม่ถึงจริง (สไลม์หลังกำแพง/จุดหลอก) → พักยาว 1 นาที
                        if not pressPrompt(d) then
                            local n = (failN[d] or 0) + 1; failN[d] = n
                            cooldown[d] = os.clock() + (n >= 3 and 55 or 0)
                            if n >= 3 then setStatus((d.ActionText == "Clean Slime" and "สไลม์" or "ไฟ") .. "เอื้อมไม่ถึง — พัก 1 นาที") end
                        else
                            failN[d] = nil
                        end
                    end
                end
            end
        end
        task.wait(0.35)
    end
end)

-- ===== v5.12 ผีคลาน (ผู้ใช้อธิบาย 2 วิธีไล่) =====
-- 1) มีคนโดนจับ → prompt 'Help' โผล่บนตัวเหยื่อ (HumanoidRootPart) → สแปมกด ~4 รอบ (แบบดับไฟ)
-- 2) ผียังไม่จับใคร → ถือน้ำเชื่อม (Maple Syrup) เดินเข้าหามัน = มันหายไป
--    (ยังไม่รู้ชื่อ model ผีตอนเดินเพ่นพ่าน — ใช้จุดเหยื่อเป็นตำแหน่งผี: หลังช่วยเสร็จ
--     ถือน้ำเชื่อมยืนตรงนั้นกันจับซ้ำ ; เจอ model จริงเมื่อไหร่ค่อยเพิ่มวิธี 2 เต็มรูปแบบ)
task.spawn(function()
    local lastHelp = 0
    local function findSyrup()
        for _, t in ipairs(heldTools()) do
            if t.Name:lower():find("syrup") then return t.Name end
        end
    end
    -- หยิบน้ำเชื่อมให้อยู่ในมือ (มือเต็ม 3 ช่องยา = ทิ้งยา 1 ชิ้นก่อน) → คืนชื่อ tool
    local function ensureSyrup()
        local name = findSyrup()
        if name then return name end
        local pk
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText:lower():find("syrup") then
                pk = p; break
            end
        end
        if not (pk and pk.Parent) then return nil end
        setStatus("ไปหยิบน้ำเชื่อม (ไล่ผี)")
        local n = 0
        for _, t in ipairs(heldTools()) do if not protectedTool(t) then n += 1 end end
        if n >= 3 then
            for _, t in ipairs(heldTools()) do
                if not protectedTool(t) then discardTool(t) break end
            end
        end
        tpTo(partPos(pk.Parent)); task.wait(0.2)
        pressPrompt(pk, function() return findSyrup() ~= nil end, true); task.wait(0.2)
        return findSyrup()
    end
    while _G.AH74_GEN == MYGEN do
        if FIRE_ON and fp and not WORKING and not CARRYING
           and os.clock() - lastHelp > 2 then
            local me = hrp() and hrp().Position
            -- วิธี 1: มีคนโดนจับ — prompt 'Help' บนตัวเหยื่อ (NPC/ผู้เล่น) → สแปมช่วย
            local hp
            for _, p in ipairs(workspace:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText == "Help" then
                    local pos = partPos(p.Parent)
                    if pos and me and (pos - me).Magnitude < 150 then hp = p; break end
                end
            end
            if hp then
                lastHelp = os.clock()
                setStatus("ช่วยคนโดนผีจับ! (สแปม Help)")
                tpTo(partPos(hp.Parent)); task.wait(0.1)
                for _ = 1, 8 do   -- ผู้ใช้บอก ~4 รอบ — เผื่อ 8 (prompt ดับเองเมื่อหลุด)
                    if not (hp.Parent and hp.Enabled) then break end
                    pressPrompt(hp, nil, true)
                    task.wait(0.25)
                end
                local victimPos = partPos(hp.Parent)
                local name = ensureSyrup()
                if name and selectTool(name) and victimPos then
                    setStatus("ถือน้ำเชื่อมไล่ผีพื้น")
                    tpTo(victimPos); task.wait(1)
                end
            else
                -- วิธี 2 (v5.13): ผียังไม่จับใคร — ตัวจริง = Rooms.<กลุ่ม>.<ห้อง>.Minigame.MonsterBed
                --                (ผีใต้เตียง — RoomDebug เจอ MonsterBed.Arms ห้อง 4) → ถือน้ำเชื่อมเดินประชิด
                local mb
                local rooms = workspace:FindFirstChild("Rooms")
                if rooms then
                    for _, d in ipairs(rooms:GetDescendants()) do
                        if d.Name == "MonsterBed" and d:FindFirstChild("Arms") then
                            local pos = partPos(d)
                            if pos and me and (pos - me).Magnitude < 150 then mb = d; break end
                        end
                    end
                end
                if mb then
                    lastHelp = os.clock()
                    local name = ensureSyrup()
                    if name and selectTool(name) then
                        setStatus("ถือน้ำเชื่อมไล่ผีใต้เตียง")
                        -- v5.14: พื้นแดงรอบตัวมัน = เขตจับ — หยุดขอบโซน 10 studs ฝั่งเรา (แบบกองไฟ)
                        local gp = partPos(mb)
                        local from = hrp() and hrp().Position
                        if gp then
                            local dir = from and (from - gp).Magnitude > 1 and (from - gp).Unit or Vector3.new(1, 0, 0)
                            tpTo(gp + dir * 10); task.wait(1)
                        end
                    else
                        setStatus("หาน้ำเชื่อมไม่เจอ — ไล่ผีใต้เตียงไม่ได้")
                    end
                end
            end
        end
        task.wait(0.4)
    end
end)

-- ===== v4.70 อุ้มคนเป็นลมส่งห้อง: NPC (คนไข้/คนเยี่ยม ไม่ใช่ผี) มี PP 'Carry' =====
-- flow: บินไปหา → Carry → บินไปห้อง DesignatedRoom → กด prompt วาง (บนตัว NPC/เตียง)
-- v4.72: อยู่ในปุ่ม "ดับไฟ" (กลุ่มงานฉุกเฉิน) — เจอปุ๊บทำทันที (treat loop หลีกทางให้เอง)
task.spawn(function()
    while _G.AH74_GEN == MYGEN do
        if FIRE_ON and fp and not WORKING then
            do
                local m, carryPP = faintPending()
                do
                    if m then   -- v4.75: carryPP=nil = อุ้มค้างอยู่ → ข้ามไปขั้นส่ง/วางต่อเลย
                        CARRYING = true   -- v4.91: ล็อคงานอุ้ม — ไฟ/สไลม์/ชัตเตอร์ห้ามแทรกจนวางเสร็จ
                        if carryPP then
                            setStatus("อุ้ม " .. m.Name)
                            tpTo(partPos(m)); task.wait(0.15)
                            pressPrompt(carryPP)
                            task.wait(0.3)
                        end
                        -- พาไปห้องที่เขาต้องไป
                        local roomName = m:GetAttribute("DesignatedRoom")
                        local rooms = workspace:FindFirstChild("Rooms")
                        local room
                        if rooms and roomName then
                            for _, grp in ipairs({"Medical", "Emergency"}) do
                                local g = rooms:FindFirstChild(grp)
                                local rr = g and g:FindFirstChild(roomName)
                                if rr then room = rr end
                            end
                        end
                        -- v4.72: ไม่รู้ห้อง (คนเยี่ยม/ไม่มี DesignatedRoom) → พาไปวางหน้าเคาน์เตอร์
                        local dest = room and roomPos(room)
                        if not dest then
                            local misc = workspace:FindFirstChild("Misc")
                            dest = misc and partPos(misc:FindFirstChild("CheckIn"))
                        end
                        if dest then
                            setStatus("อุ้ม " .. m.Name .. " → " .. (room and roomName or "เคาน์เตอร์"))
                            tpTo(dest); task.wait(0.3)
                            -- v4.73: ปุ่มวางตัวจริง = 'Place Patient' ที่เตียงของห้อง (ยืนยันจาก dump)
                            local dropPP
                            if room then
                                for _, p in ipairs(room:GetDescendants()) do
                                    if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText == "Place Patient" then
                                        dropPP = p; break
                                    end
                                end
                            end
                            -- v4.78: ห้องเป้าหมายไม่มีปุ่มวาง (เตียงไม่ว่าง?) → หาเตียงว่างห้องไหนก็ได้
                            if not dropPP and rooms then
                                for _, grp in ipairs({"Medical", "Emergency"}) do
                                    local g = rooms:FindFirstChild(grp)
                                    if g then for _, r2 in ipairs(g:GetChildren()) do
                                        for _, p in ipairs(r2:GetDescendants()) do
                                            if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText == "Place Patient" then
                                                dropPP = p; break
                                            end
                                        end
                                        if dropPP then break end
                                    end end
                                    if dropPP then break end
                                end
                            end
                            if not dropPP then   -- fallback: prompt เปิดบนตัว NPC (Drop ฯลฯ)
                                for _, p in ipairs(m:GetDescendants()) do
                                    if p:IsA("ProximityPrompt") and p.Enabled then dropPP = p; break end
                                end
                            end
                            if dropPP then
                                setStatus("วาง (" .. dropPP.ActionText .. ")")
                                tpTo(partPos(dropPP.Parent)); task.wait(0.15)
                                pressPrompt(dropPP, function()
                                    return not dropPP.Parent or not dropPP.Enabled
                                        or m:GetAttribute("CarriedBy") == nil or m:GetAttribute("InBed")
                                end)
                                task.wait(0.2)
                                -- v4.81: วางสำเร็จจริง (ตัวหลุดจากมือ/ขึ้นเตียง) = จบถาวร กลับไปทำงานอื่นเลย
                                local me, np = hrp() and hrp().Position, partPos(m)
                                if m:GetAttribute("InBed") or m:GetAttribute("CarriedBy") == nil
                                   or (me and np and (np - me).Magnitude > 10) then
                                    FAINT_DONE[m] = math.huge
                                    setStatus("วาง " .. m.Name .. " เสร็จ")
                                else
                                    setStatus("วาง " .. m.Name .. " ไม่สำเร็จ — ลองใหม่ 10s")
                                end
                            else
                                setStatus("หาเตียงวาง " .. m.Name .. " ไม่ได้ — พัก 10s")
                            end
                            if not FAINT_DONE[m] or FAINT_DONE[m] ~= math.huge then
                                FAINT_DONE[m] = os.clock()   -- v4.78: พักทุกกรณี — วางไม่ได้ก็ห้ามวนติด
                            end
                        end
                        CARRYING = false   -- v4.91: ปลดล็อค — งานอุ้มรอบนี้จบ (สำเร็จ/พักก็ตาม)
                    end
                end
            end
        end
        task.wait(0.15)   -- v4.71: สแกนถี่เท่าดับไฟ — เจอปุ๊บอุ้มทันที
    end
end)

local killB = btn("ฆ่าผี: OFF", 98, 98, 86, 30)
killB.MouseButton1Click:Connect(function()
    KILLGHOST_ON = not KILLGHOST_ON
    killB.Text = "ฆ่าผี: " .. (KILLGHOST_ON and "ON" or "OFF")
    killB.BackgroundColor3 = KILLGHOST_ON and Color3.fromRGB(150,40,40) or Color3.fromRGB(45,45,58)
end)

local moveB = btn("ไปของ: วาป", 8, 130, 86, 30, Color3.fromRGB(55,35,80))
moveB.MouseButton1Click:Connect(function()
    TP_ON = not TP_ON
    moveB.Text = "ไปของ: " .. (TP_ON and "วาป" or "เดิน")
    moveB.BackgroundColor3 = TP_ON and Color3.fromRGB(55,35,80) or Color3.fromRGB(35,70,55)
end)

-- (v4.43: ทำเครื่อง/ตีตัว/สี R6 รวมเข้าปุ่ม "รักษา" แล้ว — ไม่มีปุ่มแยก)
-- v4.34: รวม เช็คอิน+ชัตเตอร์ เป็นปุ่มเดียว (งานหน้าเคาน์เตอร์เหมือนกัน) — แถวบนสุดคู่กับรักษา
local ciB = btn("เคาน์เตอร์: OFF", 98, 34, 86, 30, Color3.fromRGB(45,45,58))
ciB.MouseButton1Click:Connect(function()
    CHECKIN_ON = not CHECKIN_ON
    SHUTTER_ON = CHECKIN_ON
    ciB.Text = "เคาน์เตอร์: " .. (CHECKIN_ON and "ON" or "OFF")
    ciB.BackgroundColor3 = CHECKIN_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
end)

local fireB = btn("ดับไฟ: OFF", 98, 130, 86, 30, Color3.fromRGB(120,60,30))
fireB.MouseButton1Click:Connect(function()
    FIRE_ON = not FIRE_ON
    fireB.Text = "ดับไฟ: " .. (FIRE_ON and "ON" or "OFF")
    fireB.BackgroundColor3 = FIRE_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(120,60,30)
end)

local npcfB = btn("ยิงผี: OFF", 8, 162, 86, 30, Color3.fromRGB(60,60,80))
npcfB.MouseButton1Click:Connect(function()
    GUNKILL_ON = not GUNKILL_ON
    npcfB.Text = "ยิงผี: " .. (GUNKILL_ON and "ON" or "OFF")
    npcfB.BackgroundColor3 = GUNKILL_ON and Color3.fromRGB(150,40,40) or Color3.fromRGB(60,60,80)
    if GUNKILL_ON and not fp then npcfB.Text = "ไม่มี fp!" end
end)

btn("CLOSE", 8, 194, 176, 24, Color3.fromRGB(120,30,30)).MouseButton1Click:Connect(function()
    RUN_ON, NOCLIP_ON, ESP_ON, AUTO_ON, KILLGHOST_ON, WHACK_ON, R6_ON, CHECKIN_ON, SHUTTER_ON, NPCFAST_ON, FIRE_ON, GUNKILL_ON =
        false, false, false, false, false, false, false, false, false, false, false, false
    local h = hum()
    if h then
        h.WalkSpeed = 16
        h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)   -- คืนกระโดด
    end
    local c = LP.Character
    if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
    for m, e in pairs(ESP) do pcall(function() e:Destroy() end) end
    for _, conn in pairs(CONNS) do pcall(function() conn:Disconnect() end) end
    _G.AH74_CONNS, _G.AH74_ESP = nil, nil
    _G.AH74_GEN = (_G.AH74_GEN or 0) + 1   -- หยุด treat loop
    gui:Destroy()
end)

print("[74RB AnimalHospital v4.35] ทุกวาปถอยห่างผี ≥12 studs (กัน sanity หมดตาย) + ปุ่มเคาน์เตอร์ + ดับไฟนอกกอง พร้อม")
