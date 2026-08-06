-- 75RB_SpawnSpy.lua v1.2 — สปาย "การเสกแร่" (เรดาร์/ระเบิด)
-- v1.2: ปุ่ม "ลองยิงระเบิดฟรี" — ทดสอบว่า BombActivate ยิงตรงได้ไหมโดยไม่ต้องซื้อ
-- v1.1: เจอระบบร้านครบ! RadarShopQuery→RadarBuyRequest→RadarActivate/RadarDropRequest
--       (ระเบิดก็มีชุดเดียวกัน) + ปุ่ม "ถามร้านเรดาร์" ดูของ/ราคาโดยไม่เสียเงิน
-- เบาะแสที่มีอยู่แล้ว: RS.Remotes.RadarDropRequest / CrystalDropRequest / BigCrystalShake
--   RealStats: RadarPurchases='496083|CrystalRadar:1' RadarSkipCount BombPurchases BombSkipCount
--   Settings: AutoContinueRadar
-- ตัวนี้จับ: (1) remote ขาไป/ขากลับที่เกี่ยวกับ radar/drop/bomb/spawn
--          (2) ก้อนใหม่ที่ "โผล่ขึ้นมาในแมพ" พร้อมระยะจากตัวเรา (เห็นว่าเสกตรงไหน)
--          (3) ของในกระเป๋าเรดาร์/ระเบิด (Backpack + RealStats)
-- วิธีใช้: รัน → ใช้เรดาร์/ระเบิด 1 ครั้ง (ตามที่เพื่อนทำ) → COPY ส่งผล
if _G.SPSPY75_GUI then pcall(function() _G.SPSPY75_GUI:Destroy() end) end
if _G.SPSPY75_CONNS then
    for _, c in pairs(_G.SPSPY75_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.SPSPY75_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT, T0 = {}, os.clock()
local BOX

local function L(s)
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > 300 then table.remove(OUT, 1) end
    if BOX then BOX.Text = table.concat(OUT, "\n") end
end
local function ser(v)
    local t = typeof(v)
    if t == "Instance" then return "<" .. v.ClassName .. ":" .. v.Name .. ">" end
    if t == "Vector3" then return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z) end
    if t == "table" then
        local p = {}
        for k, val in pairs(v) do p[#p + 1] = tostring(k) .. "=" .. tostring(val) end
        return "{" .. table.concat(p, ", ") .. "}"
    end
    return tostring(v)
end
local function myPos()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return r and r.Position
end

-- (1) remote ที่เกี่ยวกับการเสก — ขาไป (hook) + ขากลับ (OnClientEvent)
local KW = { "radar", "drop", "bomb", "spawn", "shake", "dig", "burst" }
local function interesting(n)
    n = n:lower()
    for _, k in ipairs(KW) do if n:find(k) then return true end end
    return false
end

if not _G.SPSPY75_HOOKED and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and _G.SPSPY75_LOG and interesting(self.Name) then
            local a = { ... }
            local parts = {}
            for i = 1, math.min(#a, 6) do parts[i] = ser(a[i]) end
            local nm = self.Name
            task.defer(function()
                pcall(function() _G.SPSPY75_LOG(("→ %s:%s(%s)"):format(nm, m, table.concat(parts, ", "))) end)
            end)
        end
        return old(self, ...)
    end)
    _G.SPSPY75_HOOKED = true
end
_G.SPSPY75_LOG = L

local Rem = RS:FindFirstChild("Remotes")
if Rem then
    for _, d in ipairs(Rem:GetDescendants()) do
        if (d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent")) and interesting(d.Name) then
            table.insert(_G.SPSPY75_CONNS, d.OnClientEvent:Connect(function(...)
                local a = { ... }
                local parts = {}
                for i = 1, math.min(#a, 6) do parts[i] = ser(a[i]) end
                L(("← %s(%s)"):format(d.Name, table.concat(parts, ", ")))
            end))
        end
    end
end

-- (2) ก้อนใหม่โผล่ในแมพ = ผลของการเสก
table.insert(_G.SPSPY75_CONNS, workspace.DescendantAdded:Connect(function(d)
    task.wait(0.1)
    if not d:IsA("BasePart") then return end
    local nm = d:GetAttribute("CrystalName")
    if not nm then return end
    local mp = myPos()
    local dist = mp and math.floor((d.Position - mp).Magnitude) or -1
    -- โผล่ใกล้ตัว (< 150) น่าจะเป็นของที่เราเสก
    if dist >= 0 and dist < 150 then
        L(("✨ ก้อนใหม่: %s T%s %.1fkg $%s @%dm | path %s"):format(nm,
            tostring(d:GetAttribute("Tier")), d:GetAttribute("WeightKg") or 0,
            tostring(d:GetAttribute("Value")), dist,
            d:GetFullName():gsub("^Workspace%.", "")))
    end
end))

-- (3) ของที่ใช้เสกได้ (กระเป๋า/สถิติ)
local function dumpTools()
    L("--- ของในกระเป๋า (Backpack + ถือ) ---")
    local seen = {}
    local function look(cont)
        if not cont then return end
        for _, t in ipairs(cont:GetChildren()) do
            if t:IsA("Tool") and not seen[t.Name] then
                seen[t.Name] = true
                local at = {}
                for k, v in pairs(t:GetAttributes()) do at[#at + 1] = k .. "=" .. tostring(v) end
                L(("tool '%s' %s"):format(t.Name, table.concat(at, " ")))
            end
        end
    end
    look(LP:FindFirstChildOfClass("Backpack"))
    look(LP.Character)
    L("--- สถิติที่เกี่ยวกับเรดาร์/ระเบิด ---")
    local pd = LP:FindFirstChild("PlayerData")
    local st = pd and pd:FindFirstChild("RealStats")
    if st then
        for _, v in ipairs(st:GetChildren()) do
            local n = v.Name:lower()
            if n:find("radar") or n:find("bomb") or n:find("luck") or n:find("boost") then
                L(("stat %s = %s"):format(v.Name, tostring(v.Value)))
            end
        end
    end
    L("--- remote ที่เกี่ยวข้องทั้งหมด ---")
    if Rem then
        for _, d in ipairs(Rem:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                if interesting(d.Name) then L("  " .. d.ClassName .. " " .. d.Name) end
            end
        end
    end
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "SpawnSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.SPSPY75_GUI = gui

local box = Instance.new("TextBox", gui)
BOX = box
box.Size = UDim2.new(0, 650, 0, 300); box.Position = UDim2.new(0, 8, 0.3, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(180, 255, 220); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Bottom
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.3, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
-- v1.1: ถามร้านเรดาร์/ระเบิด (RemoteFunction Query = แค่ถาม ไม่เสียเงิน)
local function askShops()
    if not Rem then L("❌ ไม่เจอ RS.Remotes") return end
    for _, n in ipairs({ "RadarShopQuery", "BombShopQuery" }) do
        local f = Rem:FindFirstChild(n)
        if f and f:IsA("RemoteFunction") then
            local ok, res = pcall(function() return f:InvokeServer() end)
            if ok then
                L(("📋 %s → %s"):format(n, ser(res)))
                if typeof(res) == "table" then     -- กางรายการให้อ่านง่าย
                    for k, v in pairs(res) do
                        L(("    %s = %s"):format(tostring(k), ser(v)))
                    end
                end
            else
                L(("❌ %s พัง: %s"):format(n, tostring(res)))
            end
        else
            L("(ไม่เจอ " .. n .. ")")
        end
    end
    L("→ ดูราคา/ของในร้าน แล้วค่อยตัดสินใจว่าจะให้บอทซื้อ+ใช้อัตโนมัติไหม")
end

-- v1.2: ทดสอบ "ยิงระเบิดตรงๆ โดยไม่ซื้อ" — server รับไหม?
-- ถ้ารับ จะมี ← BombArmed(...) ตอบกลับใน ~1 วิ | ไม่รับ = เงียบ (ไม่เสียอะไร)
local BOMB_NAMES = { "ThunderBomb", "IceBomb", "FireBomb", "BasicBomb", "Bomb" }
local function testBomb()
    if not Rem then L("❌ ไม่เจอ RS.Remotes") return end
    local act = Rem:FindFirstChild("BombActivate")
    if not act then L("❌ ไม่เจอ BombActivate") return end
    local armed = false
    local watch = Rem:FindFirstChild("BombArmed")
    local conn = watch and watch.OnClientEvent:Connect(function(n, pos)
        armed = true
        L(("  🎉 server รับ! BombArmed(%s @ %s) ← ยิงตรงได้ ไม่ต้องซื้อ"):format(
            tostring(n), ser(pos)))
    end)
    for _, nm in ipairs(BOMB_NAMES) do
        armed = false
        L(("🧪 ลองยิง BombActivate('%s')..."):format(nm))
        pcall(function() act:FireServer(nm) end)
        for _ = 1, 12 do
            task.wait(0.15)
            if armed then break end
        end
        if not armed then L("   ❌ เงียบ (server ไม่รับ — น่าจะต้องมีของก่อน)") end
        task.wait(0.4)
    end
    if conn then conn:Disconnect() end
    L("→ ถ้าเงียบหมด แปลว่าต้องซื้อระเบิดก่อน (ดูราคาจากปุ่มถามร้าน)")
end

local testB  = hbtn("🧪 ลองยิงระเบิดฟรี", 8, 126, Color3.fromRGB(150, 60, 40))
testB.MouseButton1Click:Connect(function()
    task.spawn(function()
        L("")
        local ok, err = pcall(testBomb)
        if not ok then L("💥 ERROR: " .. tostring(err)) end
    end)
end)

local askB   = hbtn("ถามร้านเรดาร์", 138, 104, Color3.fromRGB(120, 60, 140))
askB.MouseButton1Click:Connect(function()
    task.spawn(function()
        L("")
        local ok, err = pcall(askShops)
        if not ok then L("💥 ERROR: " .. tostring(err)) end
    end)
end)

local dumpB  = hbtn("ดูของ/สถิติ", 246, 100, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 350, 60, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 414, 60)
local hideB  = hbtn("ซ่อน", 478, 52, Color3.fromRGB(50, 50, 70))
local closeB = hbtn("✕", 534, 34, Color3.fromRGB(150, 40, 40))

dumpB.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ok, err = pcall(dumpTools)
        if not ok then L("💥 ERROR: " .. tostring(err)) end
    end)
end)
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
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_spawn_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.SPSPY75_LOG = nil
    for _, c in pairs(_G.SPSPY75_CONNS) do pcall(function() c:Disconnect() end) end
    _G.SPSPY75_CONNS = {}
    gui:Destroy(); _G.SPSPY75_GUI = nil
end)

L("[SpawnSpy v1.0] ใช้เรดาร์/ระเบิด 1 ครั้ง → ดูว่ายิง remote อะไร + ก้อนโผล่ตรงไหน")
L("กด 'ดูของ/สถิติ' ก่อน เพื่อดูว่ามีไอเทมเสกอะไรอยู่ในกระเป๋าบ้าง")
dumpTools()
