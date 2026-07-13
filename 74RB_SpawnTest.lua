-- 74RB_SpawnTest.lua v1.0 — ทดสอบว่า remote spawn ที่เจอ "เกิด NPC จริง" ไหม
-- ยิงทีละตัว หลายรูปแบบ args → นับ NPC ก่อน/หลัง → ตัวไหนทำให้เพิ่ม = ของจริง
-- ⚠️ ยิง remote จริงไปหา server — ถ้าเกมมี anti-cheat ฝั่ง server อาจโดนเตะ (ใช้ acc สำรอง)

if _G.SPAWNTEST_CONNS then
    for _, c in pairs(_G.SPAWNTEST_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.SPAWNTEST_CONNS = {}
local CONNS = _G.SPAWNTEST_CONNS

local RSt = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT = {}

local gui = Instance.new("ScreenGui")
gui.Name = "SpawnTest"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 520, 0, 340); box.Position = UDim2.new(0, 8, 0.3, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(140, 255, 140); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[SpawnTest] กด START"
local LINES = {}
local function add(s)
    OUT[#OUT + 1] = s; LINES[#LINES + 1] = s
    while #LINES > 22 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
    pcall(setclipboard, table.concat(OUT, "\n"))
    print("[SpawnTest]", s)
end

local net = RSt:WaitForChild("Util"):WaitForChild("Net")
local function getRE(name)
    return net:FindFirstChild("RE/" .. name) or net:FindFirstChild(name, true)
end

local function countNPCs()
    local c = 0
    local f = workspace:FindFirstChild("NPCs")
    if f then for _, m in ipairs(f:GetChildren()) do if m:IsA("Model") then c = c + 1 end end end
    return c
end

local function hrp()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

-- ชื่อ remote ที่จะลอง (จาก probe รอบก่อน) — ตัดชื่อที่ผมเดามั่วออก เหลือที่เข้าเค้าสุด
local NAMES = {"SpawnNPC", "SpawnVisitor", "SpawnPatient", "AddPatient", "CreateNPC", "SummonNPC", "Appointment", "BookAppointment"}

-- รูปแบบ args ที่จะลองต่อ 1 ชื่อ (เดาจากแม่แบบ ReplicatedStorage.NPCs)
local function argSets()
    local pos = hrp() and hrp().Position or Vector3.new(0, 5, 0)
    return {
        {label = "()", args = {}},
        {label = "(pos)", args = {pos}},
        {label = "('Doctor')", args = {"Doctor"}},
        {label = "('Doctor',pos)", args = {"Doctor", pos}},
        {label = "(template)", args = {RSt.NPCs.UniqueVisitors:FindFirstChild("Doctor")}},
    }
end

local running = false
local function run()
    if running then return end
    running = true
    add("=== เริ่มทดสอบ (จับตา NPC เพิ่ม) ===")
    for _, name in ipairs(NAMES) do
        local re = getRE(name)
        if not (re and re:IsA("RemoteEvent")) then
            add("ข้าม " .. name .. " (ไม่ใช่ RemoteEvent)")
        else
            for _, set in ipairs(argSets()) do
                local before = countNPCs()
                local ok, err = pcall(function() re:FireServer(table.unpack(set.args)) end)
                task.wait(0.6)
                local after = countNPCs()
                if not ok then
                    add(("%s%s ❌ error: %s"):format(name, set.label, tostring(err):sub(1, 40)))
                elseif after > before then
                    add(("%s%s ✅✅ NPC +%d !!! (ตัวนี้ใช้ได้)"):format(name, set.label, after - before))
                else
                    add(("%s%s — เงียบ (NPC=%d)"):format(name, set.label, after))
                end
                if not LP.Parent then add("⚠️ โดนเตะ! หยุด"); return end
            end
        end
    end
    add("=== จบ — ตัวที่ ✅✅ คือใช้ได้จริง ===")
    running = false
end

-- นับ NPC ที่โผล่ใหม่แบบ realtime ด้วย (เผื่อ server สร้างช้า)
local f = workspace:FindFirstChild("NPCs")
if f then
    table.insert(CONNS, f.ChildAdded:Connect(function(m)
        task.wait(0.2)
        local a = {}
        for k, v in pairs(m:GetAttributes()) do a[#a + 1] = k .. "=" .. tostring(v) end
        add("👶 NPC โผล่: " .. m.Name .. " [" .. table.concat(a, " ") .. "]")
    end))
end

local sb = Instance.new("TextButton", gui)
sb.Size = UDim2.new(0, 120, 0, 32); sb.Position = UDim2.new(0, 8, 0.26, 0)
sb.Text = "START ทดสอบ"; sb.TextSize = 14; sb.Font = Enum.Font.GothamBold
sb.BackgroundColor3 = Color3.fromRGB(30, 100, 40); sb.TextColor3 = Color3.new(1, 1, 1)
table.insert(CONNS, sb.MouseButton1Click:Connect(function() task.spawn(run) end))
