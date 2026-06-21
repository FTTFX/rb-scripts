-- 74RB_AnimalHospital.lua — ESP + Speed + Noclip + AUTO รักษา + ฆ่าผี + ดับไฟ  (v2.5 +Room6 apply ที่ตัวคนไข้)
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
local FIRE_ON = false    -- auto ดับไฟ: ถือ FireExtinguisher → เล็งไฟ → พ่น (Activate)
local SPEED = 50
local cam = workspace.CurrentCamera

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
}
local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local fireAcc = 0
local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local b = inst:FindFirstChildWhichIsA("BasePart", true)
    return b and b.Position
end
-- prompt อยู่ใต้ Workspace.NPCs ไหม (ใช้รู้ว่า "กด E ที่ NPC" — เช่น มอบใบรับหมาย)
local function underNPCs(inst)
    local n = inst.Parent
    while n and n ~= workspace do
        if n.Name == "NPCs" then return true end
        n = n.Parent
    end
    return false
end

local COL = {
    ghost   = Color3.fromRGB(255, 40, 40),    -- ผี (Skinwalker = อันตรายจริง)
    patient = Color3.fromRGB(60, 255, 90),    -- คนไข้จริง
    mate    = Color3.fromRGB(60, 160, 255),   -- เพื่อนผู้เล่น
    npc     = Color3.fromRGB(220, 210, 110),  -- NPC ทั่วไป/visitor (Fake=true ไม่ใช่ผี)
}
local LBL = { ghost="ผี", patient="คนไข้", mate="เพื่อน", npc="NPC" }

local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- ===== Auto รักษา (match ชื่อยา ไม่ฆ่าคนไข้) =====
-- เดินไปหา pos (pathfinding อ้อมกำแพง) — ใช้เมื่อปิดโหมดวาป
local function walkTo(pos)
    local h, r = hum(), hrp()
    if not (h and r) then return end
    local path = PathSvc:CreatePath({ AgentRadius = 2, AgentCanJump = true })
    local ok = pcall(function() path:ComputeAsync(r.Position, pos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not (AUTO_ON and _G.AH74_GEN == MYGEN) then return end
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
local function tpTo(pos)
    if not pos then return end
    if TP_ON then
        local r = hrp()
        if r then r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
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
            local d = (fromPos and pos) and (pos - fromPos).Magnitude or math.huge
            if not best or d < bestD then best, bestD = p, d end
        end
    end
    return best
end
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
-- หาจุดทิ้งยา (Trash Item)
local function trashPrompt()
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == "Trash Item" then return p end
    end
end
-- ทิ้ง Tool 1 ชิ้น: equip → วาปไปถังขยะ → fire
local function discardTool(tool)
    local h = hum()
    local tp = trashPrompt()
    if not (h and tp and tp.Parent) then return end
    pcall(function() h:EquipTool(tool) end); task.wait(0.15)
    tpTo(partPos(tp.Parent)); task.wait(0.2)
    pcall(fp, tp, 0); task.wait(0.2)
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
            meds[#meds+1] = (nm and nm:IsA("TextLabel") and nm.Text ~= "") and nm.Text or fr.Name
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
-- นับจำนวนยาที่ต้องการ/ให้แล้ว ต่อชนิด (รองรับของซ้ำ เช่น มีดผ่าตัด ×2)
-- คืน need[m]=ต้องการกี่ชิ้น, given[m]=ให้แล้วกี่ชิ้น(ใครก็ได้), order=รายชื่อชนิดเรียงลำดับ
local function medCounts(room)
    local need, given, order = {}, {}, {}
    local inv = getReport(room); inv = inv and inv:FindFirstChild("inv")
    if not inv then return need, given, order end
    for _, fr in ipairs(inv:GetChildren()) do
        if fr:IsA("GuiObject") then
            local nm = fr:FindFirstChild("name")
            local m = (nm and nm:IsA("TextLabel") and nm.Text ~= "") and nm.Text or fr.Name
            if (need[m] or 0) == 0 then order[#order+1] = m end
            need[m] = (need[m] or 0) + 1
            if frameGiven(fr) then given[m] = (given[m] or 0) + 1 end
        end
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
-- หา NPC คนไข้ของห้องนี้ (จาก attribute DesignatedRoom)
local function roomPatient(room)
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return end
    for _, m in ipairs(npcs:GetChildren()) do
        if m:GetAttribute("DesignatedRoom") == room.Name then return m end
    end
end
-- หา prompt "Apply Treatment" — ในห้อง (Room7/8 มีเตียง) หรือ บนตัวคนไข้ (Room6 คนไข้ยืน ไม่มีเตียง)
local function bedApplyPP(room)
    for _, p in ipairs(room:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.ActionText == "Apply Treatment" then return p end
    end
    local pat = roomPatient(room)   -- คนไข้ยืน: prompt อยู่บน NPC (ใน Workspace.NPCs ไม่ใช่ใต้ room)
    if pat then
        for _, p in ipairs(pat:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.ActionText == "Apply Treatment" then return p end
        end
    end
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
    -- รอจนผีอยู่ในเตียง + ถึงขั้นจ่ายยา (prompt Apply Treatment เปิดใช้งาน)
    local bedPP = bedApplyPP(room)
    if not bedPP or not bedPP.Parent or not bedPP.Enabled then return false end  -- ยังไม่ถึงขั้นจ่ายยา → รอ
    local needed = {}
    for _, m in ipairs(requiredMeds(room)) do needed[m] = true end
    -- หายาสักตัวที่ไม่ใช่ของห้องนี้ (ผิดแน่นอน)
    local wrongName, wrongPP
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and isMedicine(p.ActionText) and not needed[p.ActionText] then
            wrongName, wrongPP = p.ActionText, p; break
        end
    end
    if not wrongName then return false end
    if not findTool(wrongName) and wrongPP and wrongPP.Parent then
        tpTo(partPos(wrongPP.Parent)); task.wait(0.18); pcall(fp, wrongPP, 0); task.wait(0.2)
    end
    if not findTool(wrongName) then return false end
    tpTo(partPos(bedPP.Parent)); task.wait(0.18)
    for slot = 1, math.min(9, #heldTools()) do
        pressSlot(slot); task.wait(0.08)
        local held = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
        if held and held.Name == wrongName then
            pcall(fp, bedPP, 0); task.wait(0.2); return true
        end
    end
    return false
end
-- ทำหนึ่งห้องที่วินิจฉัยเสร็จ: เก็บยาที่ถูก → ไปเตียง → equip+apply ทีละชนิด
local function treatRoom(room)
    if roomDone(room) then return false end          -- เสร็จ/ฟื้นแล้ว → ไม่วาปซ้ำ
    -- คนไข้เป็นผี? → ฆ่าด้วยยาผิด (ถ้าเปิดโหมด) / ข้าม (ถ้าปิด — ไม่รักษาผี)
    local patient = roomPatient(room)
    if patient and patient:GetAttribute("Skinwalker") then
        if KILLGHOST_ON then return killWithWrongMed(room) end
        return false
    end
    local meds = requiredMeds(room)
    -- ยังไม่วินิจฉัย: คนไข้นอนเตียงแล้ว → ทำเครื่อง (Talk/DNA ที่ตัว + Analyze/Process ในห้อง)
    -- MACHINE_ON=ON วาปไปก่อนยิง | OFF ยิงในที่ (ไม่วาป — เราเดินไปเอง เหมือน Ver.ก่อน)
    if #meds == 0 then
        if patient and patient:GetAttribute("InBed") then
            local DIAG_NPC  = { ["Talk"]=true, ["Take DNA Sample"]=true }
            local DIAG_ROOM = { ["Analyze Sample"]=true, ["Process Results"]=true }
            for _, p in ipairs(patient:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Enabled and DIAG_NPC[p.ActionText] then
                    if MACHINE_ON then tpTo(partPos(patient)); task.wait(0.15) end
                    pcall(fp, p, 0); task.wait(0.1)
                end
            end
            for _, p in ipairs(room:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Enabled and DIAG_ROOM[p.ActionText] then
                    if MACHINE_ON then tpTo(partPos(p.Parent)); task.wait(0.15) end
                    pcall(fp, p, 0); task.wait(0.1)
                end
            end
        end
        return false
    end
    -- ===== แบบนับจำนวน (รองรับของซ้ำ เช่น มีดผ่าตัด ×2) =====
    local need, given, order = medCounts(room)
    if #order == 0 then return false end
    local needed = {}
    for _, m in ipairs(order) do needed[m] = true end
    -- 0) ทิ้งยาเก่า/ผิดที่ไม่ใช่ของคนไข้นี้ก่อน (กัน slot เต็ม → ให้ยาผิด → ตาย)
    cleanInventory(needed)
    -- 1) เก็บยาให้ "ครบจำนวนที่ยังขาด" (ต้องการ − ที่ให้ไปแล้ว) ต่อชนิด
    for _, m in ipairs(order) do
        local want = need[m] - (given[m] or 0)        -- จำนวนที่ต้องถือ
        local guard = 0
        while heldCount(m) < want and guard < 8 do
            guard += 1
            local pp = findPickup(m)
            if not pp or not pp.Parent then break end
            local before = heldCount(m)
            tpTo(partPos(pp.Parent)); task.wait(0.18); pcall(fp, pp, 0); task.wait(0.2)
            if heldCount(m) <= before then break end  -- เก็บไม่ขึ้น → เลิก
        end
    end
    -- กันตาย: ต้องถือครบทุกชนิดตามจำนวนที่ยังขาด ไม่งั้นไม่ Apply
    for _, m in ipairs(order) do
        local g = givenOf(room, m)
        if heldCount(m) < (need[m] - g) then return false end
    end
    -- 2) ไปเตียง แล้วให้ยาแต่ละชนิด "จนครบจำนวน" (เช็คจาก given บนจอทุกครั้ง)
    local bedPP = bedApplyPP(room)
    if not bedPP or not bedPP.Parent then return false end
    tpTo(partPos(bedPP.Parent)); task.wait(0.18)
    local nslots = math.min(9, #heldTools())
    for _, m in ipairs(order) do
        local guard = 0
        while not roomDone(room) and guard < 8 do
            if givenOf(room, m) >= need[m] then break end   -- ครบจำนวนแล้ว → ชนิดถัดไป
            guard += 1
            -- เลือก slot ที่ถือ m
            local picked = false
            for slot = 1, nslots do
                pressSlot(slot); task.wait(0.08)
                local held = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
                if held and held.Name == m then picked = true; break end
            end
            if not picked then break end       -- ไม่มี m แล้ว (ถูกใช้หมด/ขาด) → ชนิดถัดไป
            local before = givenOf(room, m)
            pcall(fp, bedPP, 0)                 -- ให้ยา m 1 ชิ้น
            -- poll: ยืนยันทันทีที่ given เพิ่ม เผื่อสูงสุด 0.5
            local t0 = os.clock()
            repeat task.wait(0.03)
            until givenOf(room, m) > before or roomDone(room) or os.clock() - t0 > 0.5
            if givenOf(room, m) <= before and not roomDone(room) then return false end -- ไม่คืบ = ผิด หยุด
        end
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
    if m:GetAttribute("Skinwalker") then return "ghost" end     -- อันตรายจริง
    if m:GetAttribute("IsPatient")  then return "patient" end   -- คนไข้จริง
    return "npc"   -- Fake/visitor/พนักงาน = NPC ทั่วไป (ไม่ใช่ผี)
end

-- ===== ESP refresh loop (re-check attr ทุก 0.5s — ผีเปลี่ยนสภาพกลางเกมก็เห็น) =====
local acc = 0
bind(RS.Heartbeat, function(dt)
    -- Speed (ทุก frame กัน reset/respawn)
    if RUN_ON then local h = hum(); if h then h.WalkSpeed = SPEED end end
    -- Noclip (ทุก frame)
    if NOCLIP_ON then
        local c = LP.Character
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end end
    end

    -- Auto: ยิงสเต็ป เช็คอิน (CHECKIN_ON) + วินิจฉัย/เตรียม (AUTO_ON) ทุก 0.6s
    if (AUTO_ON or CHECKIN_ON) and fp then
        fireAcc += dt
        if fireAcc >= 0.6 then
            fireAcc = 0
            for _, p in ipairs(workspace:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Enabled then
                    local a = p.ActionText
                    -- มอบใบรับหมาย = กด E ที่ NPC (ขึ้น "พูดคุย"/Talk) → ยิงทุก prompt บนตัว NPC ตอนเช็คอิน
                    -- ปลอดภัย: prompt บน NPC ไม่ใช่ยา + เกม gate ด้วย .Enabled อยู่แล้ว (DNA/Analyze ไม่ enabled ที่เคาน์เตอร์)
                    -- ponytail: ยิงทุก prompt ใต้ NPCs; ถ้าเกมเพิ่ม prompt บน NPC ที่ไม่อยากให้กด ค่อย match ชื่อ
                    local npcStep = CHECKIN_ON and underNPCs(p)
                    if (CHECKIN_ON and CHECKIN_ACTS[a]) or (AUTO_ON and TREATD_ACTS[a]) or npcStep then
                        pcall(fp, p, 0)   -- เกม gate ลำดับเอง
                    end
                end
            end
        end
    end

    acc += dt
    if acc < 0.4 then return end
    acc = 0
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

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0,190,0,546), UDim2.new(0,20,0.5,-273)
f.BackgroundColor3, f.BackgroundTransparency = Color3.fromRGB(18,18,24), 0.1
f.BorderSizePixel, f.Active, f.Draggable = 0, true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", f).Color = Color3.fromRGB(90,120,255)

local title = Instance.new("TextLabel", f)
title.Size, title.Position = UDim2.new(1,-12,0,26), UDim2.new(0,8,0,4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(150,180,255)
title.Text, title.Font, title.TextSize = "ANIMAL HOSPITAL 74", Enum.Font.GothamBold, 14
title.TextXAlignment = Enum.TextXAlignment.Left

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

local espB = btn("ESP: ON", 10, 36, 170, 36, Color3.fromRGB(40,150,70))
espB.MouseButton1Click:Connect(function()
    ESP_ON = not ESP_ON
    espB.Text = "ESP: " .. (ESP_ON and "ON" or "OFF")
    espB.BackgroundColor3 = ESP_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if not ESP_ON then
        for m, e in pairs(ESP) do pcall(function() e:Destroy() end); ESP[m] = nil end
    end
end)

local runB = btn("RUN: OFF", 10, 80, 170, 36)
runB.MouseButton1Click:Connect(function()
    RUN_ON = not RUN_ON
    runB.Text = "RUN: " .. (RUN_ON and "ON" or "OFF")
    runB.BackgroundColor3 = RUN_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if not RUN_ON then local h = hum(); if h then h.WalkSpeed = 16 end end
end)

local spdL = btn(tostring(SPEED), 10, 122, 90, 34); spdL.Active = false
btn("−", 106, 122, 36, 34).MouseButton1Click:Connect(function()
    SPEED = math.max(16, SPEED - 10); spdL.Text = tostring(SPEED)
end)
btn("+", 144, 122, 36, 34).MouseButton1Click:Connect(function()
    SPEED = SPEED + 10; spdL.Text = tostring(SPEED)
end)

local clipB = btn("NOCLIP: OFF", 10, 164, 170, 36)
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

local autoB = btn("AUTO รักษา: OFF", 10, 206, 170, 36)
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    autoB.Text = "AUTO รักษา: " .. (AUTO_ON and "ON" or "OFF")
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
    if AUTO_ON and not fp then autoB.Text = "ไม่มี fireproximityprompt" end
end)

-- loop ให้ยา (match ชื่อ) แยกจาก Heartbeat — มี wait ระหว่างสเต็ป
task.spawn(function()
    while _G.AH74_GEN == MYGEN do
        if AUTO_ON and fp then
            local rooms = workspace:FindFirstChild("Rooms")
            if rooms then
                -- รวมห้องทั้งหมด แล้วเรียงตามระยะใกล้ตัวเรา (ทำห้องใกล้ก่อน)
                local list = {}
                for _, grp in ipairs({"Medical", "Emergency"}) do   -- 1-5 + 6/7/8
                    local f = rooms:FindFirstChild(grp)
                    if f then for _, room in ipairs(f:GetChildren()) do
                        list[#list+1] = room
                    end end
                end
                local fromPos = hrp() and hrp().Position
                if fromPos then
                    local dist = {}
                    for _, room in ipairs(list) do
                        local pos = roomPos(room)
                        dist[room] = pos and (pos - fromPos).Magnitude or math.huge
                    end
                    table.sort(list, function(a, b) return dist[a] < dist[b] end)
                end
                for _, room in ipairs(list) do
                    if not (AUTO_ON and _G.AH74_GEN == MYGEN) then break end
                    pcall(treatRoom, room)   -- treatRoom เช็คเองว่าห้องมียาที่ต้องให้ไหม
                end
            end
        end
        task.wait(0.2)
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
            if R6_ON and #seq>0 and not playing and (os.clock()-lastFlash)>2.5 then
                playing=true
                for _,n in ipairs(seq) do
                    if not R6_ON then break end
                    local b=btn6(n); if b then click6(b); task.wait(0.35) end
                end
                seq={}; bright={}; task.wait(1.2); playing=false
            elseif not R6_ON then seq={}; bright={}; playing=false end
            task.wait(0.1)
        end
    end)
end

-- ===== Auto ดับไฟ: ถือ FireExtinguisher → เล็งไฟใกล้สุด → พ่น (Activate) =====
-- กลไก (จาก HookSpy): Tool 'FireExtinguisher' ใช้ :Activate() พ่นฟอง → ฟองโดนไฟ
--   เกมยิง RE/ExtinguisherBubbleHit* เองตอนฟองชน — เราแค่ equip + เล็งกล้อง + Activate
-- *** ปลอดภัย: เล็งกล้องอย่างเดียว ห้ามวาป/เดินเข้าไฟ (เข้าใกล้ = ตาย) ***
-- ponytail: หาไฟด้วย Fire class + ParticleEmitter ที่ชื่อ/แม่มีคำว่า fire/flame/burn ; เจอ path จริงค่อยเจาะ
do
    local FIRE_WORDS = { "fire", "flame", "burn" }
    local function looksFire(part, emitterName)
        local low = (part.Name .. " " .. emitterName):lower()
        for _, w in ipairs(FIRE_WORDS) do if low:find(w) then return true end end
        return false
    end
    local function nearestFire()
        local r = hrp(); if not r then return nil end
        local best, bestD
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Fire") or d:IsA("ParticleEmitter") then
                local p = d.Parent
                if p and p:IsA("BasePart") and (d:IsA("Fire") or looksFire(p, d.Name)) then
                    local dist = (p.Position - r.Position).Magnitude
                    if not best or dist < bestD then best, bestD = p.Position, dist end
                end
            end
        end
        return best
    end
    local function getExtinguisher()
        local t = findTool("FireExtinguisher")               -- หา Tool ชื่อตรง (Backpack/ตัว)
        if t then return t end
        local bp = LP:FindFirstChild("Backpack")             -- เผื่อชื่อมีคำว่า extinguisher
        for _, src in ipairs({ bp, LP.Character }) do
            if src then for _, x in ipairs(src:GetChildren()) do
                if x:IsA("Tool") and x.Name:lower():find("extinguish") then return x end
            end end
        end
    end
    task.spawn(function()
        while _G.AH74_GEN == MYGEN do
            if FIRE_ON then
                local tool = getExtinguisher()
                if tool then
                    local h = hum()
                    if h and tool.Parent ~= LP.Character then pcall(function() h:EquipTool(tool) end) end
                    local fpos = nearestFire()
                    if fpos then
                        local head = LP.Character and (LP.Character:FindFirstChild("Head") or hrp())
                        if head then pcall(function() cam.CFrame = CFrame.new(head.Position, fpos) end) end
                    end
                    pcall(function() tool:Activate() end)     -- พ่น 1 จังหวะ (ไม่เจอไฟก็พ่นค้างไว้ตามที่เล็ง)
                end
            end
            task.wait(0.12)
        end
    end)
end

local killB = btn("ผี→ยาผิด: OFF", 10, 248, 170, 32)
killB.MouseButton1Click:Connect(function()
    KILLGHOST_ON = not KILLGHOST_ON
    killB.Text = "ผี→ยาผิด: " .. (KILLGHOST_ON and "ON" or "OFF")
    killB.BackgroundColor3 = KILLGHOST_ON and Color3.fromRGB(150,40,40) or Color3.fromRGB(45,45,58)
end)

local moveB = btn("ไปของ: วาป", 10, 284, 170, 32, Color3.fromRGB(55,35,80))
moveB.MouseButton1Click:Connect(function()
    TP_ON = not TP_ON
    moveB.Text = "ไปของ: " .. (TP_ON and "วาป" or "เดิน")
    moveB.BackgroundColor3 = TP_ON and Color3.fromRGB(55,35,80) or Color3.fromRGB(35,70,55)
end)

local machB = btn("วาปทำเครื่อง: ON", 10, 320, 170, 32, Color3.fromRGB(40,150,70))
machB.MouseButton1Click:Connect(function()
    MACHINE_ON = not MACHINE_ON
    machB.Text = "วาปทำเครื่อง: " .. (MACHINE_ON and "ON" or "OFF")
    machB.BackgroundColor3 = MACHINE_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
end)

local whackB = btn("ตีตัว(มินิเกม): OFF", 10, 358, 170, 32, Color3.fromRGB(120,60,30))
whackB.MouseButton1Click:Connect(function()
    WHACK_ON = not WHACK_ON
    whackB.Text = "ตีตัว(มินิเกม): " .. (WHACK_ON and "ON" or "OFF")
    whackB.BackgroundColor3 = WHACK_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(120,60,30)
end)

local r6B = btn("ปริศนาสี R6: OFF", 10, 396, 170, 32, Color3.fromRGB(120,60,30))
r6B.MouseButton1Click:Connect(function()
    R6_ON = not R6_ON
    r6B.Text = "ปริศนาสี R6: " .. (R6_ON and "ON" or "OFF")
    r6B.BackgroundColor3 = R6_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(120,60,30)
end)

local ciB = btn("เช็คอิน: OFF", 10, 434, 170, 32, Color3.fromRGB(45,45,58))
ciB.MouseButton1Click:Connect(function()
    CHECKIN_ON = not CHECKIN_ON
    ciB.Text = "เช็คอิน: " .. (CHECKIN_ON and "ON" or "OFF")
    ciB.BackgroundColor3 = CHECKIN_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
end)

local fireB = btn("ดับไฟ: OFF", 10, 472, 170, 30, Color3.fromRGB(120,60,30))
fireB.MouseButton1Click:Connect(function()
    FIRE_ON = not FIRE_ON
    fireB.Text = "ดับไฟ: " .. (FIRE_ON and "ON" or "OFF")
    fireB.BackgroundColor3 = FIRE_ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(120,60,30)
end)

btn("CLOSE", 10, 508, 170, 22, Color3.fromRGB(120,30,30)).MouseButton1Click:Connect(function()
    RUN_ON, NOCLIP_ON, ESP_ON, AUTO_ON, KILLGHOST_ON, WHACK_ON, R6_ON, CHECKIN_ON, FIRE_ON =
        false, false, false, false, false, false, false, false, false
    local h = hum(); if h then h.WalkSpeed = 16 end
    local c = LP.Character
    if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
    for m, e in pairs(ESP) do pcall(function() e:Destroy() end) end
    for _, conn in pairs(CONNS) do pcall(function() conn:Disconnect() end) end
    _G.AH74_CONNS, _G.AH74_ESP = nil, nil
    _G.AH74_GEN = (_G.AH74_GEN or 0) + 1   -- หยุด treat loop
    gui:Destroy()
end)

print("[74RB AnimalHospital v2.5] ESP + Speed + Noclip + AUTO รักษา + Room6/8 + ดับไฟ พร้อม")
