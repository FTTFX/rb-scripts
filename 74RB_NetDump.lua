-- 74RB_NetDump.lua v1.0 — dump รายชื่อ remote ทั้งหมด (Net framework) + จับ NPC โผล่ใหม่
-- ใช้หา remote เสก NPC/นัดหมาย: รัน → ก๊อปรายชื่อลงคลิปบอร์ดเอง → ส่งให้ Claude
-- ถ้ามีคนเสก NPC ตอน spy เปิดอยู่ จะ log ว่า NPC ชื่ออะไรโผล่ที่ไหนด้วย

if _G.NETDUMP_CONNS then
    for _, c in pairs(_G.NETDUMP_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.NETDUMP_CONNS = {}
local CONNS = _G.NETDUMP_CONNS

local RSt = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT = {}

local function add(s) OUT[#OUT + 1] = s; print("[NetDump]", s) end

-- 1) รายชื่อ remote ทุกตัวใต้ ReplicatedStorage (RemoteEvent/RemoteFunction/Bindable ข้าม)
add("=== REMOTES ===")
local n = 0
for _, o in ipairs(RSt:GetDescendants()) do
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") or o:IsA("UnreliableRemoteEvent") then
        n = n + 1
        local t = {}
        local p = o
        while p and p ~= RSt do table.insert(t, 1, p.Name); p = p.Parent end
        add(o.ClassName:sub(7, 7) .. ": " .. table.concat(t, "."))
    end
end
add("รวม " .. n .. " remotes")

-- 2) template NPC ที่ซ่อนใน ReplicatedStorage (ใช้เสกหลอกตา/ดูชื่อระบบ)
add("=== MODELS (Humanoid) ใน ReplicatedStorage ===")
for _, o in ipairs(RSt:GetDescendants()) do
    if o:IsA("Model") and o:FindFirstChildOfClass("Humanoid") then
        local t = {}
        local p = o
        while p and p ~= RSt do table.insert(t, 1, p.Name); p = p.Parent end
        add("M: " .. table.concat(t, "."))
    end
end

-- 3) จับ NPC โผล่ใหม่ใน workspace.NPCs (มีคนเสกตอนไหน เห็นชื่อ+attr ทันที)
local npcs = workspace:FindFirstChild("NPCs")
if npcs then
    table.insert(CONNS, npcs.ChildAdded:Connect(function(m)
        task.wait(0.3)
        local a = {}
        for k, v in pairs(m:GetAttributes()) do a[#a + 1] = k .. "=" .. tostring(v) end
        add(("NPC ใหม่: %s [%s]"):format(m.Name, table.concat(a, " ")))
        pcall(setclipboard, table.concat(OUT, "\n"))
    end))
end

-- GUI ปุ่ม copy
local gui = Instance.new("ScreenGui")
gui.Name = "NetDump"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local b = Instance.new("TextButton", gui)
b.Size = UDim2.new(0, 160, 0, 34); b.Position = UDim2.new(0, 8, 0.35, 0)
b.Text = "COPY NetDump (" .. n .. ")"; b.TextSize = 14; b.Font = Enum.Font.GothamBold
b.BackgroundColor3 = Color3.fromRGB(40, 90, 40); b.TextColor3 = Color3.new(1, 1, 1)
table.insert(CONNS, b.MouseButton1Click:Connect(function()
    pcall(setclipboard, table.concat(OUT, "\n"))
    b.Text = "คัดลอกแล้ว ✓"
    task.wait(1); b.Text = "COPY NetDump (" .. n .. ")"
end))
