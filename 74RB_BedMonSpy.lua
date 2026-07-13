-- 74RB_BedMonSpy.lua v1.0 — สปายผีใต้เตียง (MonsterBed): โดนจับแล้วต้องกดอะไร?
-- ดักทุกอย่างตอนโดนจับ: GUI ที่โผล่ / ProximityPrompt ใหม่ / ปุ่มที่กด / remote ที่ยิง
-- วิธีใช้: รัน → ให้ตัวเองโดนผีใต้เตียงจับ → อ่าน log ว่าอะไรโผล่ + ลองกดปุ่มดูว่ายิง remote อะไร

if _G.BEDMONSPY_CONNS then
    for _, c in pairs(_G.BEDMONSPY_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.BEDMONSPY_CONNS = {}
local CONNS = _G.BEDMONSPY_CONNS

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local OUT, LINES = {}, {}

local gui = Instance.new("ScreenGui")
gui.Name = "BedMonSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 560, 0, 340); box.Position = UDim2.new(0, 8, 0.28, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(255, 200, 120); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[BedMonSpy] พร้อม — ไปโดนผีใต้เตียงจับ"
local function add(s)
    OUT[#OUT + 1] = s; LINES[#LINES + 1] = s
    while #LINES > 22 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
    pcall(setclipboard, table.concat(OUT, "\n"))
    print("[BedMonSpy]", s)
end

local function ser(v)
    if typeof(v) == "Instance" then return "<" .. v.ClassName .. ":" .. v.Name .. ">" end
    if typeof(v) == "Vector3" then return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z) end
    if type(v) == "table" then
        local t = {} for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. tostring(x) end
        return "{" .. table.concat(t, ",") .. "}"
    end
    return tostring(v)
end

-- 1) ดักปุ่มที่กด + remote ที่ยิงตอนนั้น (ตอนโดนจับ กดอะไร → มันยิง remote อะไร)
pcall(function()
    local hooked
    hooked = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance"
           and self.Name ~= "PlayerLostSanity" then   -- ตัด sanity spam ออก
            local a = {...}; local s = {}
            for i = 1, #a do s[i] = ser(a[i]) end
            add(("→ ยิง %s(%s)"):format(self.Name, table.concat(s, ", ")))
        end
        return hooked(self, ...)
    end))
end)

-- ปุ่มคีย์บอร์ดที่กด (ดูว่าเกมบอกให้กดอะไร แล้วเรากดตรงไหม)
table.insert(CONNS, UIS.InputBegan:Connect(function(inp, gpe)
    if inp.UserInputType == Enum.UserInputType.Keyboard then
        add("⌨️ กด: " .. inp.KeyCode.Name .. (gpe and " (โดน GUI ดูด)" or ""))
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
        add("🖱️ คลิกซ้าย" .. (gpe and " (โดน GUI ดูด)" or ""))
    end
end))

-- 2) GUI ที่โผล่ใน PlayerGui ตอนโดนจับ (struggle bar / ข้อความ "press...")
local pg = LP:WaitForChild("PlayerGui")
local function scanText(o)
    -- หา TextLabel/Button ที่มีคำใบ้ struggle
    for _, d in ipairs(o:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
            local t = d.Text:lower()
            if t:find("press") or t:find("struggle") or t:find("escape") or t:find("mash")
               or t:find("กด") or t:find("ดิ้น") or t:find("หนี") then
                add(("📢 [%s] \"%s\""):format(d.Name, d.Text))
            end
        end
    end
end
table.insert(CONNS, pg.DescendantAdded:Connect(function(o)
    if o:IsA("Frame") or o:IsA("ScreenGui") or o:IsA("ImageLabel") then
        add("🖼️ GUI โผล่: " .. o.Name .. " (" .. o.ClassName .. ")")
        task.delay(0.2, function() scanText(o) end)
    elseif o:IsA("TextLabel") or o:IsA("TextButton") then
        task.delay(0.1, function() scanText(o.Parent) end)
    end
end))

-- 3) จับสถานะตัวละครโดนจับ (Sit / PlatformStand / Anchored / Humanoid state)
local function watchChar(ch)
    local hum = ch:WaitForChild("Humanoid", 5)
    local hrp = ch:WaitForChild("HumanoidRootPart", 5)
    if hum then
        table.insert(CONNS, hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
            add("🧍 PlatformStand = " .. tostring(hum.PlatformStand))
        end))
        table.insert(CONNS, hum.StateChanged:Connect(function(_, new)
            add("🧍 state → " .. new.Name)
        end))
    end
    if hrp then
        table.insert(CONNS, hrp:GetPropertyChangedSignal("Anchored"):Connect(function()
            add("⚓ Anchored = " .. tostring(hrp.Anchored))
        end))
    end
    -- attribute บนตัวเรา (เกมอาจ set Grabbed/Caught)
    table.insert(CONNS, ch.AttributeChanged:Connect(function(a)
        add(("🏷️ char attr %s = %s"):format(a, tostring(ch:GetAttribute(a))))
    end))
    for a, v in pairs(ch:GetAttributes()) do add(("(char attr เริ่มต้น %s=%s)"):format(a, tostring(v))) end
end
if LP.Character then watchChar(LP.Character) end
table.insert(CONNS, LP.CharacterAdded:Connect(watchChar))

-- 4) จับ MonsterBed ทำงาน (attr เปลี่ยนตอนมันโผล่/จับ)
for _, m in ipairs(workspace:GetDescendants()) do
    if m.Name == "MonsterBed" then
        add("🛏️ เจอ MonsterBed: " .. m:GetFullName())
    end
end
table.insert(CONNS, workspace.DescendantAdded:Connect(function(o)
    if o.Name == "MonsterBed" then add("🛏️ MonsterBed ใหม่: " .. o:GetFullName()) end
end))

add("เริ่มดัก — เดินไปให้ผีใต้เตียงจับ แล้วลองกดปุ่มดิ้น")
