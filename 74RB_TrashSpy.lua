-- 74RB_TrashSpy.lua v1.0 — หาถังขยะ + ดูว่าทิ้งคนไข้เป็นลมยังไง
-- วิธีใช้: รันสคริปต์นี้ → อุ้มคนไข้เป็นลม → เดินไปถังขยะ → กดปุ่มทิ้งเอง 1 ครั้ง
--          ทุกอย่างที่เกิดขึ้นจะโชว์บนจอ + ก๊อปลงคลิปบอร์ดให้เอง

if _G.TRSPY_CONNS then
    for _, c in pairs(_G.TRSPY_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.TRSPY_CONNS = {}
local CONNS = _G.TRSPY_CONNS

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local LOG = {}

-- จอโชว์ผล
local gui = Instance.new("ScreenGui")
gui.Name = "TrashSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 470, 0, 320); box.Position = UDim2.new(0, 8, 0.5, -160)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.25
box.TextColor3 = Color3.new(0, 1, 0.4); box.TextSize = 13; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[TrashSpy] เริ่ม..."

local function add(s)
    LOG[#LOG + 1] = s
    while #LOG > 18 do table.remove(LOG, 1) end
    box.Text = table.concat(LOG, "\n")
    pcall(setclipboard, table.concat(LOG, "\n"))
    print("[TrashSpy]", s)
end

local function path(o)
    local t = {}
    while o and o ~= game do table.insert(t, 1, o.Name); o = o.Parent end
    return table.concat(t, ".")
end

-- 1) สแกนหา object ที่น่าจะเป็นถังขยะ (ชื่อ/ActionText เข้าเค้า)
local kw = {"trash", "bin", "garbage", "dispose", "dump", "waste", "incinerat"}
local function match(s)
    s = s:lower()
    for _, k in ipairs(kw) do if s:find(k) then return true end end
    return false
end
add("=== สแกนหาถังขยะ ===")
local found = 0
for _, o in ipairs(workspace:GetDescendants()) do
    if o:IsA("ProximityPrompt") then
        if match(o.Parent.Name) or match(o.ActionText) or match(o.ObjectText)
           or match(o.Name) or (o.Parent.Parent and match(o.Parent.Parent.Name)) then
            found = found + 1
            add(("PP: '%s'/'%s' @ %s en=%s"):format(o.ActionText, o.ObjectText, path(o.Parent), tostring(o.Enabled)))
        end
    elseif o:IsA("Model") or o:IsA("BasePart") then
        if match(o.Name) and not o:FindFirstChildWhichIsA("ProximityPrompt") then
            found = found + 1
            if found <= 15 then add("OBJ: " .. path(o)) end
        end
    end
end
add(("เจอ %d รายการ — ทีนี้อุ้มคนไข้ไปกดทิ้งเองดู"):format(found))

-- 2) log ทุก prompt ที่ผู้ใช้กดเอง (จะได้เห็นปุ่มทิ้งตัวจริง)
table.insert(CONNS, PPS.PromptTriggered:Connect(function(pp, plr)
    if plr == LP then
        add(("กด: '%s'/'%s' @ %s"):format(pp.ActionText, pp.ObjectText, path(pp.Parent)))
    end
end))

-- 3) จับ attr ของ NPC ที่อุ้มอยู่ (CarriedBy=เรา) — ดูว่าทิ้งแล้ว attr เปลี่ยนยังไง/ตัวหายไหม
task.spawn(function()
    local watched = {}
    while _G.TRSPY_CONNS == CONNS do
        for _, m in ipairs(workspace:GetDescendants()) do
            if m:IsA("Model") and m:GetAttribute("CarriedBy") == LP.Name and not watched[m] then
                watched[m] = true
                add("อุ้มอยู่: " .. m.Name .. " (จับตา attr)")
                table.insert(CONNS, m.AttributeChanged:Connect(function(a)
                    add(("attr %s.%s = %s"):format(m.Name, a, tostring(m:GetAttribute(a))))
                end))
                table.insert(CONNS, m.AncestryChanged:Connect(function(_, parent)
                    add(m.Name .. (parent and " ย้ายไป " .. path(parent) or " ถูกลบ (ทิ้งสำเร็จ?)"))
                end))
                -- attr ทั้งหมดตอนนี้ — เผื่อมีตัวบอกว่า "ทิ้งได้" (เช่น Fake/Skinwalker/Dead)
                for a, v in pairs(m:GetAttributes()) do
                    add(("  %s=%s"):format(a, tostring(v)))
                end
            end
        end
        task.wait(0.5)
    end
end)
