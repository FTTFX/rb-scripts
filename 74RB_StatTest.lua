-- 74RB_StatTest.lua v1.0 — ทดสอบแก้ค่า สุขภาพจิต / เงิน / กระสุน (ฝั่ง client ทำได้แค่ไหน)
-- ปุ่ม: DUMP ดูค่าทุกตัว | AMMO∞ ล็อคกระสุน | SANITY∞ ล็อคสุขภาพจิต | MONEY+ ลองเพิ่มเงิน
-- วิธีอ่านผล: กดปุ่มล็อค → เล่นตามปกติ → กด DUMP ซ้ำ ถ้าค่าเด้งกลับ = server คุม (แก้ไม่ได้จริง)
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

if _G.AH74ST_GUI then pcall(function() _G.AH74ST_GUI:Destroy() end) end
if _G.AH74ST_GEN then _G.AH74ST_GEN += 1 else _G.AH74ST_GEN = 1 end
local MYGEN = _G.AH74ST_GEN

local AMMO_LOCK, SANITY_LOCK = false, false

local function allTools()
    local out = {}
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then out[#out+1] = t end end end
    if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do if t:IsA("Tool") then out[#out+1] = t end end end
    return out
end

local function dump()
    local out = {}
    local function L(s) out[#out+1] = s end
    L("=== StatTest v1.0 ===")
    L("-- Player attributes --")
    for k, v in pairs(LP:GetAttributes()) do L(("  %s = %s"):format(k, tostring(v))) end
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        L("-- leaderstats --")
        for _, v in ipairs(ls:GetDescendants()) do
            if v:IsA("ValueBase") then L(("  %s = %s (%s)"):format(v.Name, tostring(v.Value), v.ClassName)) end
        end
    end
    L("-- Tools --")
    for _, t in ipairs(allTools()) do
        local a = {}
        for k, v in pairs(t:GetAttributes()) do a[#a+1] = k .. "=" .. tostring(v) end
        L(("  '%s' %s"):format(t.Name, table.concat(a, " ")))
    end
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then L(("-- Humanoid: HP=%.0f/%.0f WalkSpeed=%.0f"):format(h.Health, h.MaxHealth, h.WalkSpeed)) end
    L("-- ล็อคที่เปิดอยู่: AMMO=" .. tostring(AMMO_LOCK) .. " SANITY=" .. tostring(SANITY_LOCK))
    return table.concat(out, "\n")
end

-- loop ล็อคค่า (ยัดซ้ำทุก 0.3s — ถ้า server คุม ค่าจะสู้กันให้เห็นใน DUMP)
task.spawn(function()
    local sanityKeep
    while _G.AH74ST_GEN == MYGEN do
        if AMMO_LOCK then
            for _, t in ipairs(allTools()) do
                if t:GetAttribute("Charges") ~= nil then
                    pcall(function() t:SetAttribute("Charges", 99) end)
                end
            end
        end
        if SANITY_LOCK then
            if LP:GetAttribute("Sanity") ~= nil then
                pcall(function() LP:SetAttribute("Sanity", 100) end)
            end
            if LP:GetAttribute("BonusSanity") ~= nil then
                pcall(function() LP:SetAttribute("BonusSanity", 100) end)
            end
        end
        task.wait(0.3)
    end
end)

-- GUI (ตาม template RoomDebug)
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AH74ST", false, 10000
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
_G.AH74ST_GUI = gui

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 360, 0, 320), UDim2.new(0.5, -180, 0.5, -160)
f.BackgroundColor3, f.Active, f.Draggable = Color3.fromRGB(15, 15, 20), true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local box = Instance.new("TextBox", f)
box.Size, box.Position = UDim2.new(1, -12, 1, -86), UDim2.new(0, 6, 0, 6)
box.MultiLine, box.ClearTextOnFocus, box.TextEditable = true, false, false
box.TextWrapped, box.TextXAlignment, box.TextYAlignment = false, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
box.Font, box.TextSize = Enum.Font.Code, 11
box.BackgroundColor3, box.TextColor3 = Color3.fromRGB(25, 25, 32), Color3.fromRGB(200, 255, 200)
box.Text = dump()

local function mkbtn(txt, x, y, w, cb)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0, w, 0, 32), UDim2.new(0, x, 1, y)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(50, 50, 70), Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
    return b
end
mkbtn("DUMP", 6, -76, 82, function() box.Text = dump() end)
local ammoB = mkbtn("AMMO∞: OFF", 94, -76, 82, nil)
ammoB.MouseButton1Click:Connect(function()
    AMMO_LOCK = not AMMO_LOCK
    ammoB.Text = "AMMO∞: " .. (AMMO_LOCK and "ON" or "OFF")
    ammoB.BackgroundColor3 = AMMO_LOCK and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(50, 50, 70)
end)
local sanB = mkbtn("SANITY∞: OFF", 182, -76, 86, nil)
sanB.MouseButton1Click:Connect(function()
    SANITY_LOCK = not SANITY_LOCK
    sanB.Text = "SANITY∞: " .. (SANITY_LOCK and "ON" or "OFF")
    sanB.BackgroundColor3 = SANITY_LOCK and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(50, 50, 70)
end)
mkbtn("MONEY+", 274, -76, 80, function()
    -- ลองทุกทางที่เจอ: leaderstats + attribute ที่ชื่อเกี่ยวกับเงิน
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetDescendants()) do
            if v:IsA("IntValue") or v:IsA("NumberValue") then
                pcall(function() v.Value = v.Value + 1000 end)
            end
        end
    end
    for k, v in pairs(LP:GetAttributes()) do
        if type(v) == "number" and (k:lower():find("money") or k:lower():find("cash") or k:lower():find("coin")) then
            pcall(function() LP:SetAttribute(k, v + 1000) end)
        end
    end
    box.Text = "กด MONEY+ แล้ว — ดูจอเงินในเกม: เพิ่มจริงไหม? แล้วลองซื้อของ\n(ซื้อได้=client คุม / ซื้อไม่ได้=แค่ตัวเลขหลอก)\n\n" .. dump()
end)
mkbtn("COPY", 6, -40, 82, function() pcall(function() (setclipboard or toclipboard)(box.Text) end) end)
mkbtn("CLOSE", 94, -40, 82, function() gui:Destroy(); _G.AH74ST_GUI = nil; _G.AH74ST_GEN += 1 end)

print("[74RB StatTest v1.0] พร้อม — กด DUMP ดูค่า / เปิดล็อคแล้วเล่นดูว่าค่าเด้งกลับไหม")
