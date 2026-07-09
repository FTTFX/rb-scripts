-- 74RB_ShopSpy v1.0 — dump โฟลเดอร์ร้านค้า (ShopItems) ทั้งก้อน: ชื่อของ/ราคา/attr/ป้าย
-- เปิดแล้ว GUI ขึ้น กด REFRESH ตอนร้านเปิด ("the shop is open!") แล้วกด COPY ส่งให้ Claude
local LP = game:GetService("Players").LocalPlayer

if _G.SHOPSPY_GUI then pcall(function() _G.SHOPSPY_GUI:Destroy() end) end

local function dump()
    local out = {}
    local function add(s) out[#out+1] = s end
    add("=== 74RB ShopSpy v1.0 ===")
    -- หา node ชื่อ ShopItems ทุกที่ใน workspace
    local roots = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d.Name == "ShopItems" then roots[#roots+1] = d end
    end
    add("เจอ ShopItems: " .. #roots .. " ที่")
    for _, root in ipairs(roots) do
        add("== " .. root:GetFullName() .. " ==")
        for _, slot in ipairs(root:GetChildren()) do
            add("[ช่อง] " .. slot.Name .. " (" .. slot.ClassName .. ")")
            -- attributes ของช่อง
            for k, v in pairs(slot:GetAttributes()) do
                add("   attr " .. k .. " = " .. tostring(v))
            end
            -- ลูกทั้งหมด: ป้ายข้อความ / prompt / ObjectValue
            for _, d in ipairs(slot:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" then
                    add("   text [" .. d.Name .. "] '" .. d.Text .. "'")
                elseif d:IsA("ProximityPrompt") then
                    add("   PP '" .. d.ActionText .. "' Enabled=" .. tostring(d.Enabled))
                elseif d:IsA("ValueBase") then
                    add("   val " .. d.Name .. " = " .. tostring(d.Value))
                end
                for k, v in pairs(d:GetAttributes()) do
                    add("   attr(" .. d.Name .. ") " .. k .. " = " .. tostring(v))
                end
            end
        end
    end
    -- เผื่อร้านอยู่ใน ReplicatedStorage (config ของ)
    local RS = game:GetService("ReplicatedStorage")
    for _, d in ipairs(RS:GetDescendants()) do
        if d.Name:lower():find("shop") and (d:IsA("Folder") or d:IsA("ModuleScript")) then
            add("[RS] " .. d.ClassName .. " " .. d:GetFullName())
        end
    end
    return table.concat(out, "\n")
end

-- GUI + Copy (มือถือไม่มี F9)
local gui = Instance.new("ScreenGui")
gui.Name = "ShopSpyGUI"; gui.ResetOnSpawn = false; gui.DisplayOrder = 10000
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
_G.SHOPSPY_GUI = gui
local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 320, 0, 300), UDim2.new(0.5, -160, 0.5, -150)
f.BackgroundColor3 = Color3.fromRGB(20, 20, 26); f.Active, f.Draggable = true, true
Instance.new("UICorner", f)
local box = Instance.new("TextBox", f)
box.Size, box.Position = UDim2.new(1, -16, 1, -56), UDim2.new(0, 8, 0, 8)
box.MultiLine, box.ClearTextOnFocus, box.TextEditable = true, false, false
box.TextXAlignment, box.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
box.TextSize, box.Font = 12, Enum.Font.Code
box.TextColor3, box.BackgroundColor3 = Color3.fromRGB(180, 255, 180), Color3.fromRGB(12, 12, 16)
box.TextWrapped = true
local function btn(txt, x, col)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0, 96, 0, 32), UDim2.new(0, x, 1, -40)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3, b.TextColor3 = col, Color3.new(1, 1, 1)
    Instance.new("UICorner", b)
    return b
end
btn("REFRESH", 8, Color3.fromRGB(40, 120, 60)).MouseButton1Click:Connect(function()
    box.Text = dump()
end)
btn("COPY", 112, Color3.fromRGB(60, 80, 160)).MouseButton1Click:Connect(function()
    pcall(function() (setclipboard or toclipboard)(box.Text) end)
end)
btn("CLOSE", 216, Color3.fromRGB(140, 40, 40)).MouseButton1Click:Connect(function()
    gui:Destroy(); _G.SHOPSPY_GUI = nil
end)
box.Text = dump()
print("[74RB ShopSpy] พร้อม — กด REFRESH ตอนร้านเปิด แล้ว COPY")
