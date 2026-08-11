-- 78RB_GuiSpy.lua v1.0 — ลิสต์ GUI ทั้งหมด + ปุ่ม [ดู] เปิด/ปิดทีละตัว (เกม "ยิงเป็ด" 78)
-- ใช้หา "หน้าต่างร้าน" (หรือหน้าต่างอื่นที่อยากคุม) — กด [ดู] แล้วดูว่าอะไรโผล่/หาย บนจอ
--   เจอตัวที่ต้องการแล้วจดชื่อไว้ บอกกลับมา → เดี๋ยวทำปุ่มเปิด/ปิดเฉพาะตัวนั้นให้
if _G.GS78_GUI then pcall(function() _G.GS78_GUI:Destroy() end) end
_G.GS78_GEN = (_G.GS78_GEN or 0) + 1
local MY_GEN = _G.GS78_GEN

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "GuiSpy78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = pg end
_G.GS78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 340, 0, 400); frame.Position = UDim2.new(0, 8, 0.08, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.12
frame.Active = true; frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local head = Instance.new("TextLabel", frame)
head.Size = UDim2.new(1, -80, 0, 26); head.Position = UDim2.new(0, 6, 0, 4)
head.BackgroundTransparency = 1; head.TextColor3 = Color3.fromRGB(255, 220, 120)
head.Font = Enum.Font.GothamBold; head.TextSize = 13; head.TextXAlignment = Enum.TextXAlignment.Left
head.Text = "📋 GUI ทั้งหมด — กด [ดู] ดูว่าคืออะไร"

local rescanB = Instance.new("TextButton", frame)
rescanB.Size = UDim2.new(0, 66, 0, 24); rescanB.Position = UDim2.new(1, -140, 0, 5)
rescanB.Text = "สแกน"; rescanB.Font = Enum.Font.GothamBold; rescanB.TextSize = 12
rescanB.BackgroundColor3 = Color3.fromRGB(70, 110, 160); rescanB.TextColor3 = Color3.new(1,1,1)
local closeB = Instance.new("TextButton", frame)
closeB.Size = UDim2.new(0, 60, 0, 24); closeB.Position = UDim2.new(1, -68, 0, 5)
closeB.Text = "✕ ปิด"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 12
closeB.BackgroundColor3 = Color3.fromRGB(120, 40, 40); closeB.TextColor3 = Color3.new(1,1,1)

local scroll = Instance.new("ScrollingFrame", frame)
scroll.Size = UDim2.new(1, -12, 1, -38); scroll.Position = UDim2.new(0, 6, 0, 32)
scroll.BackgroundColor3 = Color3.fromRGB(15, 15, 22); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8; scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
local layout = Instance.new("UIListLayout", scroll)
layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 3)

-- ==================== สแกน + สร้างแถว ====================
local function firstText(sg)
    local n = 0
    for _, d in ipairs(sg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
            local t = d.Text:gsub("\n", " ")
            if #t > 0 then
                n = n + 1
                if n == 1 then return t:sub(1, 40) end
            end
        end
    end
    return "(ไม่มีข้อความ)"
end

local function rebuild()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local i = 0
    for _, sg in ipairs(pg:GetChildren()) do
        if sg:IsA("ScreenGui") and sg ~= gui then
            i = i + 1
            local row = Instance.new("Frame", scroll)
            row.Size = UDim2.new(1, -8, 0, 40); row.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            row.LayoutOrder = i
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

            local lbl = Instance.new("TextLabel", row)
            lbl.Size = UDim2.new(1, -66, 1, 0); lbl.Position = UDim2.new(0, 6, 0, 0)
            lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(200, 235, 255)
            lbl.Font = Enum.Font.Code; lbl.TextSize = 11; lbl.TextWrapped = true
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Top
            lbl.Text = ("%d. %s\n   [%s] %s"):format(i, sg.Name,
                sg.Enabled and "เปิดอยู่" or "ปิดอยู่", firstText(sg))

            local viewB = Instance.new("TextButton", row)
            viewB.Size = UDim2.new(0, 56, 0, 30); viewB.Position = UDim2.new(1, -60, 0.5, -15)
            viewB.Text = "ดู"; viewB.Font = Enum.Font.GothamBold; viewB.TextSize = 13
            viewB.BackgroundColor3 = Color3.fromRGB(60, 140, 80); viewB.TextColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", viewB).CornerRadius = UDim.new(0, 5)
            viewB.MouseButton1Click:Connect(function()
                sg.Enabled = not sg.Enabled
                viewB.Text = sg.Enabled and "ซ่อน" or "ดู"
                viewB.BackgroundColor3 = sg.Enabled and Color3.fromRGB(150,90,50) or Color3.fromRGB(60,140,80)
                lbl.Text = ("%d. %s\n   [%s] %s"):format(row.LayoutOrder, sg.Name,
                    sg.Enabled and "เปิดอยู่" or "ปิดอยู่", firstText(sg))
            end)
        end
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    head.Text = ("📋 เจอ %d GUI — กด [ดู] ทีละตัว"):format(i)
end

rescanB.MouseButton1Click:Connect(rebuild)
closeB.MouseButton1Click:Connect(function()
    _G.GS78_GEN = _G.GS78_GEN + 1
    gui:Destroy(); _G.GS78_GUI = nil
end)
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end)

rebuild()
warn("[GuiSpy78] v1.0 loaded — กด [ดู] ดูว่า GUI ตัวไหนคือร้าน แล้วจดชื่อ")
