-- 74RB_GhostCiSpy.lua v1.0 — สปายเช็คอินผี: ผี (Skinwalker) เช็คอินเสร็จแล้ว attr อะไรเปลี่ยน?
-- วิธีใช้: รัน → ปล่อยให้ผีเดินมาเช็คอิน (อย่าเพิ่งยิง) → ดู log ว่า attr ไหนโผล่/เปลี่ยนตอนเช็คอินเสร็จ
-- → กด COPY แล้วเอาผลมาให้ดู
-- log ครอบคลุม: attr เริ่มต้นของผีทุกตัว + AttributeChanged สด + ระยะผี↔เคาน์เตอร์ตอนเปลี่ยน

if _G.GHOSTCISPY_CONNS then
    for _, c in pairs(_G.GHOSTCISPY_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.GHOSTCISPY_CONNS = {}
local CONNS = _G.GHOSTCISPY_CONNS

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT, LINES = {}, {}
local T0 = os.clock()

-- ===== GUI (ตาม DW_SpyTemplate: กล่อง log + ปุ่ม COPY ไม่ใช้ F9) =====
local gui = Instance.new("ScreenGui")
gui.Name = "GhostCiSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 560, 0, 360); box.Position = UDim2.new(0, 8, 0.24, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.25
box.TextColor3 = Color3.fromRGB(255, 120, 120); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[GhostCiSpy] พร้อม — ปล่อยผีเดินมาเช็คอิน"

local copyB = Instance.new("TextButton", gui)
copyB.Size = UDim2.new(0, 90, 0, 30); copyB.Position = UDim2.new(0, 8, 0.24, -34)
copyB.Text = "COPY"; copyB.Font = Enum.Font.GothamBold; copyB.TextSize = 14
copyB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); copyB.TextColor3 = Color3.new(1, 1, 1)
table.insert(CONNS, copyB.MouseButton1Click:Connect(function()
    pcall(setclipboard, table.concat(OUT, "\n"))
    copyB.Text = "คัดลอกแล้ว!"
    task.delay(1.2, function() copyB.Text = "COPY" end)
end))

local function add(s)
    s = ("[%.1fs] %s"):format(os.clock() - T0, s)
    OUT[#OUT + 1] = s; LINES[#LINES + 1] = s
    while #LINES > 24 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
    print("[GhostCiSpy]", s)
end

-- ===== ระยะผี↔เคาน์เตอร์ (ไว้ดูว่า attr เปลี่ยนตอนอยู่ตรงไหน) =====
local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
        return p and p.Position
    end
    local p = inst:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end
local function counterDist(m)
    local misc = workspace:FindFirstChild("Misc")
    local r = m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart"))
    if not (misc and r) then return "?" end
    local best
    for _, n in ipairs({ "CheckIn", "CheckIn2", "Check-In" }) do
        local p = partPos(misc:FindFirstChild(n))
        if p then
            local d = (r.Position - p).Magnitude
            if not best or d < best then best = d end
        end
    end
    return best and ("%.0f"):format(best) or "?"
end

-- ===== ดักผี: dump attr เริ่มต้น + ตามทุกการเปลี่ยน =====
local WATCHED = {}   -- [model]=true กันซ้ำ

local function attrLine(m)
    local t = {}
    for a, v in pairs(m:GetAttributes()) do t[#t + 1] = a .. "=" .. tostring(v) end
    table.sort(t)
    return table.concat(t, " | ")
end

local function watch(m)
    if WATCHED[m] then return end
    WATCHED[m] = true
    local ghost = m:GetAttribute("Skinwalker") and "👻" or "🙂"
    add(("%s %s [ห่างเคาน์เตอร์ %s] attr: %s"):format(ghost, m.Name, counterDist(m), attrLine(m)))
    -- attr เปลี่ยน = log สด (นี่คือหัวใจ — จับจังหวะ "เช็คอินเสร็จ")
    table.insert(CONNS, m.AttributeChanged:Connect(function(a)
        local mark = m:GetAttribute("Skinwalker") and "👻" or "🙂"
        add(("%s %s ★ %s = %s [ห่าง %s]"):format(mark, m.Name, a, tostring(m:GetAttribute(a)), counterDist(m)))
    end))
    -- ProximityPrompt บนตัว: โผล่/หาย (ผีอาจมี prompt เฉพาะตอนรอเช็คอิน)
    table.insert(CONNS, m.DescendantAdded:Connect(function(d)
        if d:IsA("ProximityPrompt") then
            add(("%s %s + prompt '%s' (%s)"):format("👻", m.Name, d.ActionText, d.Name))
        end
    end))
end

local npcs = workspace:FindFirstChild("NPCs")
if npcs then
    for _, m in ipairs(npcs:GetChildren()) do
        if m:IsA("Model") then watch(m) end
    end
    table.insert(CONNS, npcs.ChildAdded:Connect(function(m)
        if m:IsA("Model") then task.defer(watch, m) end
    end))
else
    add("⚠️ ไม่เจอ Workspace.NPCs")
end

add("เริ่มดักแล้ว — ★ = attr เปลี่ยนสด ; ให้ผีเช็คอินเสร็จแล้วกด COPY")
