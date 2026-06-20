-- 74RB_AnimalHospital_HookSpy v1.0
-- เปิดสคริปต์นี้ตอนอยู่ในเกม Animal Hospital
-- 1) มันจะ scan โครงสร้างเกมให้ทันที (Players/Teams/workspace/NPC) → ดู F9 console
-- 2) แล้วค่อยไป "รักษาสัตว์ 1 ตัว" + "ทำ quest 1 อัน" → log จะบอกว่ายิง remote อะไร
-- เป้าหมาย: หาว่า (ก) ผี mark ยังไง (ข) remote รักษา/quest คืออะไร (ค) team เพื่อน

-- ===== Single-Instance Guard (กัน hook ซ้อน) =====
if _G.AH_SPY_ARMED then
    warn("[AH_SPY] armed อยู่แล้ว — ข้าม")
    return
end
_G.AH_SPY_ARMED = true

local Players = game:GetService("Players")
local HS      = game:GetService("HttpService")
local LP      = Players.LocalPlayer

-- ---------- helper: แปลงค่าเป็น string อ่านง่าย ----------
local function v2s(v)
    local t = typeof(v)
    if t == "Instance" then
        return ("<%s:%s>"):format(v.ClassName, v:GetFullName())
    elseif t == "table" then
        local ok, j = pcall(HS.JSONEncode, HS, v)
        return ok and j or "<table>"
    else
        return ("<%s:%s>"):format(t, tostring(v))
    end
end

local function dump(args)
    local out = {}
    for i = 1, select("#", unpack(args)) do
        out[i] = v2s(args[i])
    end
    return table.concat(out, " | ")
end

-- ================================================================
-- PART 1: STRUCTURE SCAN — รันทันที (passive)
-- ================================================================

-- 1a) Teams (สำหรับ ESP แยกเพื่อน/ทีม)
print("===== [TEAMS] =====")
for _, t in ipairs(game:GetService("Teams"):GetChildren()) do
    print(("  Team: %s  color=%s"):format(t.Name, tostring(t.TeamColor)))
end
print(("  LocalPlayer.Team = %s"):format(tostring(LP.Team)))

-- 1b) Players + ตัวอย่าง attribute ของผู้เล่น (เผื่อ role อยู่บน player)
print("===== [PLAYERS] =====")
for _, p in ipairs(Players:GetPlayers()) do
    local attrs = p:GetAttributes()
    local ak = {}
    for k, val in pairs(attrs) do ak[#ak+1] = k.."="..tostring(val) end
    print(("  %s  team=%s  attrs={%s}"):format(
        p.Name, tostring(p.Team), table.concat(ak, ",")))
end
-- ดู leaderstats / values บน LocalPlayer
print("  -- LocalPlayer children --")
for _, c in ipairs(LP:GetChildren()) do
    print(("    %s (%s)"):format(c.Name, c.ClassName))
end

-- 1c) workspace top-level (หา folder NPC/Patients/Animals)
print("===== [WORKSPACE TOP-LEVEL] =====")
for _, c in ipairs(workspace:GetChildren()) do
    print(("  %s (%s)"):format(c.Name, c.ClassName))
end

-- 1d) หา NPC-like models (มี Humanoid) แล้ว dump attribute + ValueBase ลูก
--     -> นี่คือจุดสำคัญ: หา flag ที่บอก "ผี" vs "คนดี"
print("===== [NPC / CHARACTER SCAN] =====")
local seen = 0
local MAX_NPC = 25  -- ponytail: cap กัน log ท่วม, เพิ่มถ้าหาผีไม่เจอ
local function scanModel(m)
    if seen >= MAX_NPC then return end
    -- attributes
    local attrs = m:GetAttributes()
    local ak = {}
    for k, val in pairs(attrs) do ak[#ak+1] = k.."="..tostring(val) end
    -- ValueBase children (BoolValue/StringValue ฯลฯ มักเก็บ role)
    local vals = {}
    for _, c in ipairs(m:GetDescendants()) do
        if c:IsA("ValueBase") then
            vals[#vals+1] = ("%s[%s]=%s"):format(c.Name, c.ClassName, tostring(c.Value))
        end
    end
    seen = seen + 1
    print(("  NPC: %s"):format(m:GetFullName()))
    if #ak > 0   then print("      attrs: " .. table.concat(ak, ", ")) end
    if #vals > 0 then print("      values: " .. table.concat(vals, ", ")) end
end
-- ตัวละครผู้เล่นจริงไม่ใช่ NPC → ข้าม model ที่ตรงกับชื่อผู้เล่น
local playerNames = {}
for _, p in ipairs(Players:GetPlayers()) do playerNames[p.Name] = true end
for _, d in ipairs(workspace:GetDescendants()) do
    if seen >= MAX_NPC then break end
    if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid")
       and not playerNames[d.Name] then
        scanModel(d)
    end
end
print(("  (scanned %d NPC models, cap=%d)"):format(seen, MAX_NPC))

-- 1e) RemoteEvent/RemoteFunction ทั้งหมด (รายชื่อ remote ที่มี)
print("===== [REMOTES LIST] =====")
local rcount = 0
for _, d in ipairs(game:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
        rcount = rcount + 1
        if rcount <= 60 then
            print(("  %s (%s)"):format(d:GetFullName(), d.ClassName))
        end
    end
end
print(("  total remotes = %d"):format(rcount))

-- ================================================================
-- PART 2: REMOTE HOOK — ดักตอนเรารักษา/ทำ quest
-- ================================================================
local mt = getrawmetatable(game)
local oldnc = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    if m == "FireServer" or m == "InvokeServer" then
        warn(("[REMOTE] %s :%s(%s)"):format(self:GetFullName(), m, dump({...})))
    end
    return oldnc(self, ...)
end)
setreadonly(mt, true)
_G.AH_SPY_UNHOOK = function()
    setreadonly(mt, false); mt.__namecall = oldnc; setreadonly(mt, true)
    _G.AH_SPY_ARMED = nil
    warn("[AH_SPY] unhooked")
end

print("==================================================")
print("[AH_SPY] armed. ทำ 3 อย่างนี้แล้วส่ง log มา:")
print("  1) เข้าใกล้ NPC ผี 1 ตัว + NPC คนดี 1 ตัว (ดู attrs/values ต่างกันไหม)")
print("  2) รักษาสัตว์ 1 ตัว -> ดู [REMOTE]")
print("  3) ทำ quest/collect 1 อัน -> ดู [REMOTE]")
print("  เลิก hook: _G.AH_SPY_UNHOOK()")
