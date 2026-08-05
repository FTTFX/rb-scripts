-- 75RB_PickSpy.lua v2.0 — สปายการเก็บของแบบแม่นยำ: ดูตั้งแต่กดจนของเข้ากระเป๋าจริง
-- ตอบให้ครบ 5 คำถาม:
--   1) ก้อนแบบไหน "หยิบ" แบบไหน "ต้องขุด"  (Action ของ prompt + MaxActivationDistance)
--   2) ตอนกด เรายืนห่างเท่าไหร่ / ปุ่มขึ้นตอนห่างเท่าไหร่ (ระยะจริงที่ใช้ได้)
--   3) กดค้างกี่วิถึง trigger
--   4) client ยิง remote อะไรออกไปบ้าง
--   5) ของเข้ากระเป๋าตอนไหน (ดัก Inventory.Crystals.ChildAdded = ความจริงชั้นเดียว)
-- วิธีใช้: รัน → เก็บมือ 2-3 ก้อน (ทั้งก้อนใหญ่/ก้อนเล็กแพง) → COPY ส่งผล
if _G.PSPY75_GUI then pcall(function() _G.PSPY75_GUI:Destroy() end) end
if _G.PSPY75_CONNS then
    for _, c in pairs(_G.PSPY75_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.PSPY75_CONNS = {}

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT, T0 = {}, os.clock()
local BOX
local holdT, lastTrig = {}, nil

local function L(s)
    OUT[#OUT + 1] = ("[%7.2f] %s"):format(os.clock() - T0, s)
    if #OUT > 300 then table.remove(OUT, 1) end
    if BOX then BOX.Text = table.concat(OUT, "\n") end
end
local function dist(part)
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not r or not part then return -1 end
    return (part.Position - r.Position).Magnitude
end
local function bagNow()
    local pd = LP:FindFirstChild("PlayerData")
    local inv = pd and pd:FindFirstChild("Inventory")
    inv = inv and inv:FindFirstChild("Crystals")
    if not inv then return 0, 0 end
    local kg, n = 0, 0
    for _, c in ipairs(inv:GetChildren()) do
        kg += (c:GetAttribute("WeightKg") or 0); n += 1
    end
    return kg, n
end
local function info(pp)
    local h = pp.Parent
    local nm = h and (h:GetAttribute("CrystalName") or h.Name) or "?"
    local kg = h and h:GetAttribute("WeightKg") or 0
    local v = h and h:GetAttribute("Value") or 0
    local t = h and h:GetAttribute("Tier") or 0
    local sz = h and h:GetAttribute("SizeClassName") or "?"
    return ("%s T%d [%s] %.1fkg $%s | Action='%s' Hold=%.1f Max=%d | ห่าง %.1f")
        :format(nm, t, sz, kg, tostring(v), pp.ActionText, pp.HoldDuration,
            pp.MaxActivationDistance, dist(h))
end

-- (1) ปุ่มขึ้น/ปุ่มหาย = ระยะจริงที่เกมยอมให้กด
table.insert(_G.PSPY75_CONNS, PPS.PromptShown:Connect(function(pp)
    L("👁 ปุ่มขึ้น: " .. info(pp))
end))
table.insert(_G.PSPY75_CONNS, PPS.PromptHidden:Connect(function(pp)
    local h = pp.Parent
    if h and h:GetAttribute("CrystalName") then
        L(("🚫 ปุ่มหาย: %s (ห่าง %.1f)"):format(h:GetAttribute("CrystalName"), dist(h)))
    end
end))

-- (2) จังหวะกดค้าง
table.insert(_G.PSPY75_CONNS, PPS.PromptButtonHoldBegan:Connect(function(pp)
    holdT[pp] = os.clock()
    L("⬇ เริ่มกดค้าง: " .. info(pp))
end))
table.insert(_G.PSPY75_CONNS, PPS.PromptButtonHoldEnded:Connect(function(pp)
    L(("⬆ ปล่อย (ค้าง %.2f วิ)"):format(holdT[pp] and (os.clock() - holdT[pp]) or -1))
end))
table.insert(_G.PSPY75_CONNS, PPS.PromptTriggered:Connect(function(pp, plr)
    if plr ~= LP then return end
    local dt = holdT[pp] and (os.clock() - holdT[pp]) or -1
    lastTrig = { t = os.clock(), name = pp.Parent and pp.Parent:GetAttribute("CrystalName") }
    L(("⚡ TRIGGER%s: %s"):format(
        dt >= 0 and (" (กดค้าง %.2f วิ)"):format(dt) or " (ไม่มีกดค้าง = สคริปต์ยิง)", info(pp)))
end))

-- (3) ของเข้ากระเป๋าจริง — ความจริงชั้นเดียว
task.spawn(function()
    local pd = LP:WaitForChild("PlayerData", 10)
    local inv = pd and pd:WaitForChild("Inventory", 10)
    inv = inv and inv:WaitForChild("Crystals", 10)
    if not inv then L("❌ ไม่เจอ PlayerData.Inventory.Crystals") return end
    local kg, n = bagNow()
    L(("📦 กระเป๋าเริ่มต้น %.1f kg / %d ก้อน"):format(kg, n))
    table.insert(_G.PSPY75_CONNS, inv.ChildAdded:Connect(function(c)
        task.wait(0.05)   -- รอ attr มาครบ
        local kg2, n2 = bagNow()
        local lag = lastTrig and (os.clock() - lastTrig.t) or -1
        L(("✅ เข้ากระเป๋า: %s %.1fkg $%s | หลัง TRIGGER %.2f วิ | รวม %.1fkg %d ก้อน"):format(
            tostring(c:GetAttribute("CrystalName") or c.Name), c:GetAttribute("WeightKg") or 0,
            tostring(c:GetAttribute("Value") or 0), lag, kg2, n2))
    end))
    table.insert(_G.PSPY75_CONNS, inv.ChildRemoved:Connect(function(c)
        local kg2, n2 = bagNow()
        L(("➖ ออกจากกระเป๋า: %s | เหลือ %.1fkg %d ก้อน"):format(
            tostring(c:GetAttribute("CrystalName") or c.Name), kg2, n2))
    end))
end)

-- (4) remote ที่ client ยิงออก (เฉพาะที่เกี่ยวกับคริสตัล)
if not _G.PSPY75_HOOKED and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and _G.PSPY75_LOG then
            local nm = self.Name
            if nm:lower():find("crystal") or nm:lower():find("mine") or nm:lower():find("pick") then
                local a = { ... }
                local p1 = a[1]
                local d = (typeof(p1) == "Instance") and p1 or nil
                task.defer(function()
                    pcall(function()
                        _G.PSPY75_LOG(("→ %s:%s(%s)"):format(nm, m,
                            d and (d.Name .. " " .. tostring(d:GetAttribute("CrystalName") or "")) or
                            tostring(p1)))
                    end)
                end)
            end
        end
        return old(self, ...)
    end)
    _G.PSPY75_HOOKED = true
end
_G.PSPY75_LOG = L

-- (5) ขากลับ: MineFX บอก progress การขุด (ก้อนที่ต้องฟันหลายที)
local Rem = RS:FindFirstChild("Remotes")
if Rem then
    for _, n in ipairs({ "CrystalMineFX", "CrystalPickupJuice", "CrystalDroppedPickup" }) do
        local r = Rem:FindFirstChild(n)
        if r and r:IsA("RemoteEvent") then
            table.insert(_G.PSPY75_CONNS, r.OnClientEvent:Connect(function(...)
                local a = { ... }
                local parts = {}
                for i = 1, math.min(#a, 4) do
                    local x = a[i]
                    parts[i] = (typeof(x) == "Instance") and (x.Name) or
                        (typeof(x) == "number" and ("%.2f"):format(x) or tostring(x))
                end
                L(("← %s(%s)"):format(n, table.concat(parts, ", ")))
            end))
        end
    end
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "PickSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.PSPY75_GUI = gui

local box = Instance.new("TextBox", gui)
BOX = box
box.Size = UDim2.new(0, 660, 0, 300); box.Position = UDim2.new(0, 8, 0.32, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(255, 230, 170); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Bottom
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.32, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local clearB = hbtn("CLEAR", 8, 70, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 84, 70)
local hideB  = hbtn("ซ่อน", 158, 60, Color3.fromRGB(50, 50, 70))
local closeB = hbtn("✕", 222, 34, Color3.fromRGB(150, 40, 40))

clearB.MouseButton1Click:Connect(function() OUT = {}; box.Text = "" end)
hideB.MouseButton1Click:Connect(function()
    box.Visible = not box.Visible
    hideB.Text = box.Visible and "ซ่อน" or "โชว์"
end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_pick_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.PSPY75_LOG = nil
    for _, c in pairs(_G.PSPY75_CONNS) do pcall(function() c:Disconnect() end) end
    _G.PSPY75_CONNS = {}
    gui:Destroy(); _G.PSPY75_GUI = nil
end)

L("[PickSpy v2.0] เก็บมือ 2-3 ก้อน (ทั้งก้อนใหญ่ธรรมดา + ก้อนเล็กแพงๆ T6) แล้ว COPY")
L("ดู: 👁ปุ่มขึ้น ⬇กดค้าง ⚡TRIGGER →remote ←MineFX ✅เข้ากระเป๋า")
