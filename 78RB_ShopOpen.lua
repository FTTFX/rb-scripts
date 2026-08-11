-- 78RB_ShopOpen.lua v1.0 — เปิด/ปิดร้านจากที่ไกลๆ (เกม "ยิงเป็ด" 78)
-- ร้านเปิด/ปิดด้วยรีโมต InvokeServer (ชื่อสุ่มทุกครั้งที่เข้าเกม) ที่ยิงตอนกด E ใกล้ร้าน
-- วิธี: hook เบาจำ "รีโมต InvokeServer ตัวล่าสุด" → กด E ใกล้ร้าน 1 ครั้งให้เรียน → จากนั้นกดปุ่ม
--   (หรือคีย์ G) เปิด/ปิดร้านจากที่ไหนก็ได้ (เซิร์ฟเวอร์ไม่เช็คระยะสำหรับ RemoteFunction)
if _G.SO78_GUI then pcall(function() _G.SO78_GUI:Destroy() end) end
if _G.SO78_CONNS then for _, c in ipairs(_G.SO78_CONNS) do pcall(function() c:Disconnect() end) end end
_G.SO78_CONNS = {}
_G.SO78_GEN = (_G.SO78_GEN or 0) + 1
local MY_GEN = _G.SO78_GEN

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "ShopOpen78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.SO78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 220, 0, 120); frame.Position = UDim2.new(0, 8, 0.62, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.18
frame.Active = true; frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -8, 0, 30); title.Position = UDim2.new(0, 4, 0, 4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(255, 200, 120)
title.TextSize = 11; title.Font = Enum.Font.Code; title.TextWrapped = true
title.TextXAlignment = Enum.TextXAlignment.Left; title.TextYAlignment = Enum.TextYAlignment.Top
title.Text = "🛒 ร้าน: ยังไม่เรียน — เดินไปกด E 1 ครั้ง"

local openB = Instance.new("TextButton", frame)
openB.Size = UDim2.new(1, -8, 0, 40); openB.Position = UDim2.new(0, 4, 0, 38)
openB.Text = "🛒 เปิด/ปิดร้าน (G)"; openB.Font = Enum.Font.GothamBold; openB.TextSize = 15
openB.BackgroundColor3 = Color3.fromRGB(150, 110, 50); openB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", openB).CornerRadius = UDim.new(0, 6)

local learnB = Instance.new("TextButton", frame)
learnB.Size = UDim2.new(0, 140, 0, 28); learnB.Position = UDim2.new(0, 4, 0, 84)
learnB.Text = "🎯 จำร้าน (กดหลังกด E)"; learnB.Font = Enum.Font.GothamBold; learnB.TextSize = 11
learnB.BackgroundColor3 = Color3.fromRGB(70, 110, 160); learnB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", learnB).CornerRadius = UDim.new(0, 5)

local closeB = Instance.new("TextButton", frame)
closeB.Size = UDim2.new(0, 68, 0, 28); closeB.Position = UDim2.new(0, 148, 0, 84)
closeB.Text = "✕ ปิด"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 12
closeB.BackgroundColor3 = Color3.fromRGB(90, 40, 40); closeB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)

-- ==================== HOOK เบา: จำรีโมต InvokeServer ตัวล่าสุด ====================
-- ปืนยิงใช้ FireServer → InvokeServer จึงมักเป็นร้าน/เมนู เก็บตัวล่าสุดไว้ให้ "จำร้าน" ล็อก
_G.SO78_LAST = _G.SO78_LAST or nil
local hookOK, hookErr = pcall(function()
    if not (hookmetamethod and getnamecallmethod) then error("ไม่มี hookmetamethod") end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if _G.SO78_GEN == MY_GEN then
            local rself = self
            pcall(function()
                if getnamecallmethod() == "InvokeServer" then _G.SO78_LAST = rself end
            end)
        end
        return old(self, ...)
    end)
end)

local function nameOf(r) local n = "?"; pcall(function() n = r.Name end); return n end

local function refresh()
    if _G.SO78_REMOTE then
        title.Text = "🛒 ร้าน: เรียนแล้ว ✓ (" .. nameOf(_G.SO78_REMOTE) .. ")\nกด G หรือปุ่มเปิด/ปิดได้ทุกที่"
        title.TextColor3 = Color3.fromRGB(150, 255, 150)
    else
        title.Text = "🛒 ร้าน: ยังไม่เรียน — เดินไปกด E ใกล้ร้าน 1 ครั้ง\nแล้วกด '🎯 จำร้าน'"
        title.TextColor3 = Color3.fromRGB(255, 200, 120)
    end
end

local function learn()
    if _G.SO78_LAST then
        _G.SO78_REMOTE = _G.SO78_LAST
        refresh()
    else
        title.Text = "🛒 ยังไม่เห็นรีโมตเลย — ลองกด E เปิดร้านก่อน แล้วค่อยกดจำ"
    end
end

local function openShop()
    if not _G.SO78_REMOTE then title.Text = "🛒 ยังไม่เรียน — กด E ใกล้ร้าน แล้วกด 'จำร้าน'"; return end
    pcall(function() _G.SO78_REMOTE:InvokeServer() end)
    title.Text = "🛒 สั่งเปิด/ปิดร้านแล้ว (" .. nameOf(_G.SO78_REMOTE) .. ")"
end

openB.MouseButton1Click:Connect(openShop)
learnB.MouseButton1Click:Connect(learn)
closeB.MouseButton1Click:Connect(function()
    _G.SO78_GEN = _G.SO78_GEN + 1
    for _, c in ipairs(_G.SO78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.SO78_CONNS = {}
    gui:Destroy(); _G.SO78_GUI = nil
end)
table.insert(_G.SO78_CONNS, UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if _G.SO78_GEN ~= MY_GEN then return end
    if input.KeyCode == Enum.KeyCode.G then openShop() end
end))

if not hookOK then title.Text = "❌ hook ไม่ติด: " .. tostring(hookErr) end
refresh()
warn("[ShopOpen78] v1.0 loaded — กด E ใกล้ร้าน 1 ครั้ง แล้วกด 'จำร้าน' → เปิดจากทุกที่ด้วย G")
