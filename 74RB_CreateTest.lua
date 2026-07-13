-- 74RB_CreateTest.lua v1.0 — พิสูจน์ CreateNPC() ว่าเสกจริงหรือบังเอิญ server เสกเอง
-- ยิง CreateNPC() รัวๆ N ครั้งเร็วๆ → นับ NPC ที่โผล่ในช่วงนั้น
-- server เสกเองช้า (ตัวละ 30วิ+) → ถ้ายิง 10 ครั้งได้ ~10 ตัว = CreateNPC จริง

if _G.CREATETEST_CONNS then
    for _, c in pairs(_G.CREATETEST_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.CREATETEST_CONNS = {}
local CONNS = _G.CREATETEST_CONNS

local RSt = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT, LINES = {}, {}

local gui = Instance.new("ScreenGui")
gui.Name = "CreateTest"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 520, 0, 320); box.Position = UDim2.new(0, 8, 0.32, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(140, 255, 140); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[CreateTest] พร้อม — กดปุ่ม"
local function add(s)
    OUT[#OUT + 1] = s; LINES[#LINES + 1] = s
    while #LINES > 20 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
    pcall(setclipboard, table.concat(OUT, "\n"))
    print("[CreateTest]", s)
end

local net = RSt:WaitForChild("Util"):WaitForChild("Net")
local re = net:FindFirstChild("RE/CreateNPC") or net:FindFirstChild("CreateNPC", true)
local f = workspace:FindFirstChild("NPCs")

-- นับ NPC ที่โผล่ระหว่างจับเวลา
local watching, spawned = false, 0
if f then
    table.insert(CONNS, f.ChildAdded:Connect(function(m)
        if watching then
            spawned = spawned + 1
            task.wait(0.2)
            local a = {}
            for k, v in pairs(m:GetAttributes()) do a[#a + 1] = k .. "=" .. tostring(v) end
            add(("  👶 #%d %s [%s]"):format(spawned, m.Name, table.concat(a, " ")))
        end
    end))
end

-- baseline: นับ NPC โผล่เอง 10 วิ ไม่ยิงอะไร
local function baseline()
    if not re then add("❌ ไม่เจอ CreateNPC"); return end
    add("=== BASELINE: ไม่ยิง รอ 10 วิ (นับ server เสกเอง) ===")
    watching, spawned = true, 0
    task.wait(10)
    watching = false
    add(("BASELINE = server เสกเอง %d ตัว/10วิ"):format(spawned))
end

-- burst: ยิง 15 ครั้งใน ~3 วิ
local function burst()
    if not re then add("❌ ไม่เจอ CreateNPC"); return end
    add("=== BURST: ยิง CreateNPC() 15 ครั้ง ===")
    watching, spawned = true, 0
    for i = 1, 15 do
        pcall(function() re:FireServer() end)
        task.wait(0.15)
        if not LP.Parent then add("⚠️ โดนเตะ!"); return end
    end
    task.wait(3)   -- รอ server ตอบครบ
    watching = false
    add(("BURST = ยิง 15 → โผล่ %d ตัว"):format(spawned))
    if spawned >= 8 then add("✅✅ CreateNPC ใช้ได้จริง! (โผล่ตามจำนวนยิง)")
    elseif spawned <= 2 then add("❌ บังเอิญ — พอๆ กับ baseline (server เสกเอง)")
    else add("🤔 ก้ำกึ่ง — ลองซ้ำอีกรอบ") end
end

local function mkb(txt, y, cb)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, 150, 0, 30); b.Position = UDim2.new(0, 8, y, 0)
    b.Text = txt; b.TextSize = 13; b.Font = Enum.Font.GothamBold
    b.BackgroundColor3 = Color3.fromRGB(30, 90, 40); b.TextColor3 = Color3.new(1, 1, 1)
    table.insert(CONNS, b.MouseButton1Click:Connect(function() task.spawn(cb) end))
end
mkb("1) BASELINE 10วิ", 0.24, baseline)
mkb("2) BURST ยิง 15", 0.28, burst)
