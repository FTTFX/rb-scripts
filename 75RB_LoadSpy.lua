-- 75RB_LoadSpy.lua v1.0 — สปาย "จังหวะโหลด" เพื่อหาสัญญาณ "พร้อมจริง"
-- ปัญหา: บอทเริ่มฟาร์มตอนเกมยังโหลด → ทุกก้อน Max=0 กดไม่เข้า เสียเวลา 12 วิ/ก้อน
-- ตัวนี้เก็บทุก 0.5 วิ: ตัวละคร / กระเป๋า / Inventory / จำนวนก้อน / ก้อนที่ Max>0 /
--   ป้ายโหลด "x / y" / LP.loaded  → จะได้รู้ว่าอะไรมาก่อนหลัง และ "พร้อม" ดูจากอะไรดีที่สุด
-- วิธีใช้: รัน → วาร์ปโซน หรือ ออก-เข้าเกมใหม่ → ดูลำดับ → COPY ส่งผล
if _G.LSPY75_GUI then pcall(function() _G.LSPY75_GUI:Destroy() end) end
if _G.LSPY75_CONNS then
    for _, c in pairs(_G.LSPY75_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.LSPY75_CONNS = {}
_G.LSPY75_RUN = true

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT, T0 = {}, os.clock()
local BOX

local function L(s)
    OUT[#OUT + 1] = ("[%6.1f] %s"):format(os.clock() - T0, s)
    if #OUT > 300 then table.remove(OUT, 1) end
    if BOX then BOX.Text = table.concat(OUT, "\n") end
end

-- นับก้อน + ก้อนที่ prompt พร้อมใช้ (Max>0)
local function crystalStats()
    local total, ready, noPrompt = 0, 0, 0
    for _, c in ipairs(workspace:GetDescendants()) do
        if c:IsA("BasePart") and c:GetAttribute("CrystalName")
            and not c:FindFirstAncestor("Plots") then
            total += 1
            local pp = c:FindFirstChildOfClass("ProximityPrompt")
            if not pp then noPrompt += 1
            elseif pp.MaxActivationDistance > 0 then ready += 1 end
        end
    end
    return total, ready, noPrompt
end

-- ป้ายโหลด "x / y" ใน PlayerGui (แถบที่เห็นตอนเข้าเกม)
local function loadBar()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible then
            local a, b = d.Text:match("^%s*([%d,]+)%s*/%s*([%d,]+)%s*$")
            if a and b then
                return ("%s (%s)"):format(d.Text, d:GetFullName()
                    :gsub("^Players%." .. LP.Name .. "%.PlayerGui%.", ""))
            end
        end
    end
    return nil
end

local function snap()
    local char = LP.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local bp = LP:FindFirstChildOfClass("Backpack")
    local pd = LP:FindFirstChild("PlayerData")
    local inv = pd and pd:FindFirstChild("Inventory")
    inv = inv and inv:FindFirstChild("Crystals")
    local loaded = LP:FindFirstChild("loaded")
    local total, ready, noPrompt = crystalStats()
    return {
        char = char ~= nil, hrp = r ~= nil,
        hp = h and math.floor(h.Health) or -1,
        tools = bp and #bp:GetChildren() or -1,
        inv = inv and #inv:GetChildren() or -1,
        loaded = loaded and tostring(loaded.Value) or "?",
        total = total, ready = ready, noPrompt = noPrompt,
        bar = loadBar(),
    }
end

local function fmt(s)
    return ("char=%s hrp=%s hp=%d tools=%d inv=%d loaded=%s | ก้อน %d (พร้อม %d, ไม่มี prompt %d)%s")
        :format(tostring(s.char), tostring(s.hrp), s.hp, s.tools, s.inv, s.loaded,
            s.total, s.ready, s.noPrompt, s.bar and (" | แถบ " .. s.bar) or "")
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "LoadSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.LSPY75_GUI = gui

local box = Instance.new("TextBox", gui)
BOX = box
box.Size = UDim2.new(0, 660, 0, 280); box.Position = UDim2.new(0, 8, 0.34, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(200, 240, 255); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Bottom
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.34, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local nowB   = hbtn("เช็คตอนนี้", 8, 90, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 102, 66, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 172, 66)
local hideB  = hbtn("ซ่อน", 242, 56, Color3.fromRGB(50, 50, 70))
local closeB = hbtn("✕", 302, 34, Color3.fromRGB(150, 40, 40))

nowB.MouseButton1Click:Connect(function() L("📸 " .. fmt(snap())) end)
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
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_load_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.LSPY75_RUN = false
    for _, c in pairs(_G.LSPY75_CONNS) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.LSPY75_GUI = nil
end)

-- ==================== เฝ้าดูทุก 0.5 วิ — log เฉพาะตอน "มีอะไรเปลี่ยน" ====================
task.spawn(function()
    local last
    while _G.LSPY75_RUN do
        local s = snap()
        local changed = (not last)
            or s.char ~= last.char or s.hrp ~= last.hrp or s.loaded ~= last.loaded
            or (s.tools ~= last.tools) or (s.inv ~= last.inv)
            or math.abs(s.total - last.total) > 30       -- ก้อนเปลี่ยนเยอะ = กำลังโหลด
            or math.abs(s.ready - last.ready) > 30
            or (s.bar ~= nil) ~= (last.bar ~= nil)
        if changed then L(fmt(s)) end
        last = s
        task.wait(0.5)
    end
end)

-- เกิดใหม่/ตาย
table.insert(_G.LSPY75_CONNS, LP.CharacterAdded:Connect(function()
    L("👶 CharacterAdded (เกิดใหม่)")
end))
table.insert(_G.LSPY75_CONNS, LP.CharacterRemoving:Connect(function()
    L("💀 CharacterRemoving (ตาย/วาร์ป)")
end))

L("[LoadSpy v1.0] เฝ้าดูจังหวะโหลด — ลองวาร์ปโซน / ออก-เข้าเกมใหม่ แล้ว COPY")
L("ดูว่า: ก้อน 'พร้อม' (Max>0) มาช้ากว่าตัวละครแค่ไหน = ต้องรอเท่าไหร่ถึงเริ่มฟาร์มได้")
L("📸 " .. fmt(snap()))
