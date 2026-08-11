-- 78RB_ShopOpen.lua v2.0 — เปิดร้านจากที่ไกล (เกม "ยิงเป็ด" 78)
-- v1 ผิด: รีโมต pj4Jqw ไม่ใช่ตัวเปิดร้าน (ร้านเปิดฝั่งจอตอนกด E ใกล้ๆ) → เปลี่ยนวิธี 2 ทาง:
--   (A) หา ProximityPrompt (ตัว E) แล้ว fireproximityprompt จากที่ไกล = เหมือนเดินไปกด E
--   (B) หา "หน้าต่างร้าน" ใน PlayerGui (จากข้อความ ขายเป็ด/อัปเกรด) แล้วเปิดตรงๆ (Enabled/Visible)
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
frame.Size = UDim2.new(0, 230, 0, 132); frame.Position = UDim2.new(0, 8, 0.6, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.18
frame.Active = true; frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -8, 0, 32); title.Position = UDim2.new(0, 4, 0, 4)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(255, 200, 120)
title.TextSize = 11; title.Font = Enum.Font.Code; title.TextWrapped = true
title.TextXAlignment = Enum.TextXAlignment.Left; title.TextYAlignment = Enum.TextYAlignment.Top

local openB = Instance.new("TextButton", frame)
openB.Size = UDim2.new(1, -8, 0, 42); openB.Position = UDim2.new(0, 4, 0, 40)
openB.Text = "🛒 เปิดร้าน (G)"; openB.Font = Enum.Font.GothamBold; openB.TextSize = 16
openB.BackgroundColor3 = Color3.fromRGB(150, 110, 50); openB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", openB).CornerRadius = UDim.new(0, 6)

local rescanB = Instance.new("TextButton", frame)
rescanB.Size = UDim2.new(0, 140, 0, 28); rescanB.Position = UDim2.new(0, 4, 0, 88)
rescanB.Text = "🔍 สแกนหาร้านใหม่"; rescanB.Font = Enum.Font.GothamBold; rescanB.TextSize = 11
rescanB.BackgroundColor3 = Color3.fromRGB(70, 110, 160); rescanB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", rescanB).CornerRadius = UDim.new(0, 5)

local closeB = Instance.new("TextButton", frame)
closeB.Size = UDim2.new(0, 78, 0, 28); closeB.Position = UDim2.new(0, 148, 0, 88)
closeB.Text = "✕ ปิด"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 12
closeB.BackgroundColor3 = Color3.fromRGB(90, 40, 40); closeB.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)

-- ==================== หา ProximityPrompt + หน้าต่างร้าน ====================
local SHOP_PROMPTS = {}   -- ProximityPrompt ที่น่าจะเปิดร้าน
local SHOP_GUIS = {}      -- ScreenGui/Frame ร้าน

local function looksShoppy(txt)
    if not txt then return false end
    txt = txt:lower()
    return txt:find("ร้าน") or txt:find("shop") or txt:find("อัปเกรด") or txt:find("upgrade")
        or txt:find("ขายเป็ด") or txt:find("อาวุธ") or txt:find("store") or txt:find("buy")
end

local function scan()
    SHOP_PROMPTS = {}; SHOP_GUIS = {}
    -- (A) ProximityPrompt ทั้งหมด (มักมีตัวเดียว/ไม่กี่ตัว) — เก็บทุกตัว เผื่อยิงเปิดร้าน
    pcall(function()
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                SHOP_PROMPTS[#SHOP_PROMPTS + 1] = p
            end
        end
    end)
    -- (B) หน้าต่างร้านใน PlayerGui — จากข้อความ ขายเป็ด/อัปเกรด/อาวุธ
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        local roots = { pg }
        if gethui then pcall(function() roots[#roots+1] = gethui() end) end
        for _, root in ipairs(roots) do
            if root then
                for _, d in ipairs(root:GetDescendants()) do
                    if (d:IsA("TextLabel") or d:IsA("TextButton")) and looksShoppy(d.Text) then
                        -- ไต่ขึ้นหา ScreenGui หรือ Frame ใหญ่สุดที่คุมร้าน
                        local sg = d:FindFirstAncestorWhichIsA("ScreenGui")
                        if sg then SHOP_GUIS[sg] = true end
                    end
                end
            end
        end
    end)
    local nG = 0; for _ in pairs(SHOP_GUIS) do nG = nG + 1 end
    title.Text = ("🛒 เจอ: prompt %d ตัว, หน้าต่างร้าน %d\n(ถ้ากดแล้วไม่เปิด ลองสแกนใหม่ตอนอยู่ใกล้ร้าน)"):format(#SHOP_PROMPTS, nG)
end

local function openShop()
    local did = false
    -- (A) fireproximityprompt (เหมือนกด E จากที่ไกล)
    if fireproximityprompt then
        for _, p in ipairs(SHOP_PROMPTS) do
            pcall(function() fireproximityprompt(p) end); did = true
        end
    end
    -- (B) เปิดหน้าต่างร้านตรงๆ (Enabled + Visible)
    for sg in pairs(SHOP_GUIS) do
        pcall(function()
            if sg:IsA("ScreenGui") then sg.Enabled = true end
            for _, d in ipairs(sg:GetDescendants()) do
                if d:IsA("Frame") and d.Size.X.Scale > 0.3 then d.Visible = true end
            end
            did = true
        end)
    end
    if did then
        title.Text = "🛒 สั่งเปิดร้านแล้ว — ถ้ายังไม่เปิด กด '🔍 สแกน' ตอนอยู่ใกล้ร้าน 1 ครั้งก่อน"
    else
        title.Text = "🛒 ยังไม่เจอร้าน — เดินไปใกล้ร้าน กด '🔍 สแกนหาร้านใหม่' ก่อน"
    end
end

openB.MouseButton1Click:Connect(openShop)
rescanB.MouseButton1Click:Connect(scan)
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

scan()
warn("[ShopOpen78] v2.0 loaded — กด G เปิดร้าน / ถ้าไม่เปิด สแกนใหม่ตอนอยู่ใกล้ร้าน")
