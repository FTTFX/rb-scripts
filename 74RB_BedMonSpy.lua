-- 74RB_BedMonSpy.lua v2.0 — สปายผีใต้เตียง (MonsterBed): โดนจับแล้ว "การกด" ทำงานผ่านอะไรกันแน่?
-- v1.0 พิสูจน์แล้ว: สัญญาณจับ = Humanoid.PlatformStand=true — แต่ไม่ได้ดัก prompt/remote ต่อการกด
-- v2.0 อุดช่อง: + ProximityPrompt โผล่ใหม่ทุกที่ (บนตัวเรา/เตียง/workspace)
--              + ProximityPromptService.PromptShown/Triggered (จับ prompt ดิ้นที่อาจซ่อนอยู่)
--              + remote ทุกตัวที่ยิงตอนช่วงโดนจับ (ดูว่ากด E 1 ที = ยิงอะไร)
--              + attr เปลี่ยนบน MonsterBed
-- วิธีใช้: รัน → ปิด "หนีผีใต้เตียง" ใน main ก่อน (ให้กดมือ จะได้เห็น mapping กด→ผล)
--          → ให้โดนจับ → กด E มือถือๆ → หลุดแล้วกด COPY เอาผลมาให้ดู

if _G.BEDMONSPY_CONNS then
    for _, c in pairs(_G.BEDMONSPY_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.BEDMONSPY_CONNS = {}
local CONNS = _G.BEDMONSPY_CONNS

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local OUT, LINES = {}, {}
local T0 = os.clock()
local GRABBED = false   -- ช่วงโดนจับ = log ละเอียด

local gui = Instance.new("ScreenGui")
gui.Name = "BedMonSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 560, 0, 340); box.Position = UDim2.new(0, 8, 0.28, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(255, 200, 120); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[BedMonSpy v2.0] พร้อม — ปิดหนีอัตโนมัติใน main แล้วไปโดนจับ"

local copyB = Instance.new("TextButton", gui)
copyB.Size = UDim2.new(0, 90, 0, 30); copyB.Position = UDim2.new(0, 8, 0.28, -34)
copyB.Text = "COPY"; copyB.Font = Enum.Font.GothamBold; copyB.TextSize = 14
copyB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); copyB.TextColor3 = Color3.new(1, 1, 1)
table.insert(CONNS, copyB.MouseButton1Click:Connect(function()
    pcall(setclipboard, table.concat(OUT, "\n"))
    copyB.Text = "คัดลอกแล้ว!"
    task.delay(1.2, function() copyB.Text = "COPY" end)
end))

local function add(s)
    s = ("[%.1fs]%s %s"):format(os.clock() - T0, GRABBED and "🆘" or "", s)
    OUT[#OUT + 1] = s; LINES[#LINES + 1] = s
    while #LINES > 22 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
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

-- 1) remote ทุกตัวที่ยิง (ตัด sanity spam) — ช่วงโดนจับจะเห็นว่ากด E 1 ที ยิงอะไรบ้าง
pcall(function()
    local hooked
    hooked = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance"
           and not self.Name:find("PlayerLostSanity") then
            local a = {...}; local s = {}
            for i = 1, #a do s[i] = ser(a[i]) end
            add(("→ ยิง %s(%s)"):format(self.Name, table.concat(s, ", ")))
        end
        return hooked(self, ...)
    end))
end)

-- 2) ปุ่มที่กดจริง (ดู mapping กด → remote/prompt)
table.insert(CONNS, UIS.InputBegan:Connect(function(inp, gpe)
    if inp.UserInputType == Enum.UserInputType.Keyboard then
        add("⌨️ กด " .. inp.KeyCode.Name .. (gpe and " (GUI ดูด)" or ""))
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
        add("🖱️ คลิก" .. (gpe and " (GUI ดูด)" or ""))
    end
end))

-- 3) ★ใหม่ v2.0: ProximityPrompt โผล่ที่ไหนก็ตาม (ตัวเรา/เตียง/workspace) — รุ่นเก่าไม่ได้ดักเลย
table.insert(CONNS, workspace.DescendantAdded:Connect(function(d)
    if d:IsA("ProximityPrompt") then
        local path = d.Parent and d.Parent:GetFullName() or "?"
        add(("➕ prompt ใหม่ '%s' Key=%s Hold=%.1f @ %s"):format(
            d.ActionText, tostring(d.KeyboardKeyCode), d.HoldDuration, path))
        table.insert(CONNS, d:GetPropertyChangedSignal("ActionText"):Connect(function()
            add(("✏️ prompt เปลี่ยน '%s' @ %s"):format(d.ActionText, path))
        end))
    end
end))

-- 4) ★ใหม่ v2.0: ระบบ prompt กลางของ Roblox — เห็นแม้ prompt สร้างก่อนเรารัน spy
table.insert(CONNS, PPS.PromptShown:Connect(function(pp)
    add(("👁️ PromptShown '%s' Key=%s Hold=%.1f @ %s"):format(
        pp.ActionText, tostring(pp.KeyboardKeyCode), pp.HoldDuration,
        pp.Parent and pp.Parent:GetFullName() or "?"))
end))
table.insert(CONNS, PPS.PromptTriggered:Connect(function(pp)
    add(("✅ PromptTriggered '%s' @ %s"):format(pp.ActionText,
        pp.Parent and pp.Parent:GetFullName() or "?"))
end))
-- กดค้าง (HoldDuration>0): เริ่มกด/ปล่อยกลางคัน — ดูว่าปุ่มดิ้นเป็นแบบ hold ไหม
table.insert(CONNS, PPS.PromptButtonHoldBegan:Connect(function(pp)
    add(("⏬ HoldBegan '%s' Hold=%.1f"):format(pp.ActionText, pp.HoldDuration))
end))
table.insert(CONNS, PPS.PromptButtonHoldEnded:Connect(function(pp)
    add(("⏫ HoldEnded '%s'"):format(pp.ActionText))
end))

-- 5) GUI โผล่ใน PlayerGui (แถบดิ้น/ข้อความ press)
local pg = LP:WaitForChild("PlayerGui")
table.insert(CONNS, pg.DescendantAdded:Connect(function(o)
    if o:IsA("Frame") or o:IsA("ScreenGui") or o:IsA("ImageLabel") then
        add("🖼️ GUI โผล่: " .. o.Name .. " (" .. o.ClassName .. ")")
        task.delay(0.2, function()
            for _, d in ipairs(o:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
                    local t = d.Text:lower()
                    if t:find("press") or t:find("struggle") or t:find("escape") or t:find("mash")
                       or t:find("กด") or t:find("ดิ้น") or t:find("หนี") then
                        add(("📢 [%s] \"%s\""):format(d.Name, d.Text))
                    end
                end
            end
        end)
    end
end))

-- 6) สถานะตัวเรา (จับ/หลุด) + attr
local function watchChar(ch)
    local hum = ch:WaitForChild("Humanoid", 5)
    if hum then
        table.insert(CONNS, hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
            GRABBED = hum.PlatformStand
            add("🧍 PlatformStand = " .. tostring(hum.PlatformStand) .. (GRABBED and " ← โดนจับ! กด E มือ" or " ← หลุดแล้ว"))
        end))
    end
    table.insert(CONNS, ch.AttributeChanged:Connect(function(a)
        add(("🏷️ เรา attr %s = %s"):format(a, tostring(ch:GetAttribute(a))))
    end))
end
if LP.Character then watchChar(LP.Character) end
table.insert(CONNS, LP.CharacterAdded:Connect(watchChar))

-- 7) MonsterBed: เจอ/โผล่ใหม่ + attr เปลี่ยน (เตียงอาจนับจำนวนดิ้นเป็น attr)
local function watchBed(b)
    add("🛏️ MonsterBed: " .. b:GetFullName() .. " attr:" .. ser(b:GetAttributes()))
    table.insert(CONNS, b.AttributeChanged:Connect(function(a)
        add(("🛏️ เตียง attr %s = %s"):format(a, tostring(b:GetAttribute(a))))
    end))
end
for _, m in ipairs(workspace:GetDescendants()) do
    if m.Name == "MonsterBed" then watchBed(m) end
end
table.insert(CONNS, workspace.DescendantAdded:Connect(function(o)
    if o.Name == "MonsterBed" then task.defer(watchBed, o) end
end))

add("v2.0 เริ่มดัก — ปิดหนีอัตโนมัติใน main → โดนจับ → กด E มือ → COPY")
