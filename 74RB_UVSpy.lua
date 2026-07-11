-- 74RB_UVSpy v1.0 — เฝ้าสด UVCamera: เปิดทิ้งไว้ → ไปกด Take UV Photo เอง 1 ครั้ง → Copy ส่งมา
-- จดทุกอย่างตอนถ่าย: attr กล้องเปลี่ยน / GUI ใหม่โผล่ / remote ที่ยิง / attr NPC ใกล้ๆ เปลี่ยน

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("AHUVGUI"); if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = "AHUVGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,640,0,480); frame.Position = UDim2.new(0.5,-320,0.5,-240)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-120,0,28); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "UV Spy — เฝ้าอยู่... ไปกด Take UV Photo ได้เลย"; titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame
local function topBtn(w,x,col,txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,w,0,22); b.Position = UDim2.new(1,x,0,3)
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1,1,1); b.Text = txt
    b.Font = Enum.Font.Code; b.TextSize = 12; b.BorderSizePixel = 0; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4); return b
end
local copyBtn  = topBtn(62,-104,Color3.fromRGB(30,100,50),"Copy")
local closeBtn = topBtn(28,-36,Color3.fromRGB(120,20,20),"X")
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-8,1,-34); scroll.Position = UDim2.new(0,4,0,30)
scroll.BackgroundColor3 = Color3.fromRGB(8,8,14); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5; scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Parent = frame
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,4)
local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = scroll
local padL = Instance.new("UIPadding"); padL.PaddingLeft = UDim.new(0,6); padL.Parent = scroll
local copyLines, order = {}, 0
local C = { OK=Color3.fromRGB(80,255,120), HEAD=Color3.fromRGB(255,210,0),
    B=Color3.fromRGB(140,160,255), S=Color3.fromRGB(140,140,140), M=Color3.fromRGB(255,120,255) }
local t00 = os.clock()
local function addLine(txt,col)
    txt = ("%.1fs %s"):format(os.clock() - t00, txt)
    order += 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-12,0,15); l.BackgroundTransparency = 1; l.Font = Enum.Font.Code
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextTruncate = Enum.TextTruncate.AtEnd
    l.TextColor3 = col or C.S; l.Text = txt; l.LayoutOrder = order; l.Parent = scroll
    table.insert(copyLines, txt)
end
local CONNS = {}
closeBtn.MouseButton1Click:Connect(function()
    for _, c in ipairs(CONNS) do pcall(function() c:Disconnect() end) end
    sg:Destroy()
end)
copyBtn.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok = clip and pcall(clip, table.concat(copyLines, "\n"))
    copyBtn.Text = ok and "Copied!" or "ไม่รองรับ"
    task.delay(2, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
end)
local function watch(c) CONNS[#CONNS+1] = c end

-- 1) attr กล้องเปลี่ยน (Charge ลด ฯลฯ)
local uv = workspace:FindFirstChild("Misc") and workspace.Misc:FindFirstChild("UVCamera")
if uv then
    addLine("เจอ UVCamera | attr เริ่มต้น: Charge=" .. tostring(uv:GetAttribute("Charge")), C.OK)
    watch(uv.AttributeChanged:Connect(function(a)
        addLine(("[UV attr] %s = %s"):format(a, tostring(uv:GetAttribute(a))), C.HEAD)
    end))
    watch(uv.DescendantAdded:Connect(function(d)
        addLine(("[UV +] %s (%s)"):format(d.Name, d.ClassName), C.B)
    end))
else
    addLine("!! ไม่เจอ Misc.UVCamera — เดินเข้าใกล้แล้วเปิดใหม่", C.M)
end

-- 2) GUI ใหม่โผล่บนจอ (จอเล็ง/ป้ายบอกเป้า) + ข้อความข้างใน
watch(pg.DescendantAdded:Connect(function(d)
    if d:IsA("ScreenGui") and d.Name ~= "AHUVGUI" then
        addLine(("[GUI +] %s"):format(d.Name), C.HEAD)
        task.delay(0.3, function()
            for _, t in ipairs(d:GetDescendants()) do
                if (t:IsA("TextLabel") or t:IsA("TextButton")) and t.Text ~= "" then
                    addLine(("   '%s' @ %s"):format(t.Text, t:GetFullName():sub(#d:GetFullName()+2)), C.M)
                end
            end
        end)
    end
end))

-- 3) remote ที่ยิงตอนถ่าย (__namecall FireServer/InvokeServer)
local okHook = pcall(function()
    local oldNC
    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") then
            local n = tostring(self)
            local args = {...}
            local parts = {}
            for i = 1, math.min(#args, 4) do parts[i] = tostring(args[i]) end
            task.defer(addLine, ("[%s] %s(%s)"):format(m, n, table.concat(parts, ", ")), C.OK)
        end
        return oldNC(self, ...)
    end)
end)
addLine(okHook and "hook remote: ON" or "hook remote: ไม่รองรับ executor นี้", C.S)

-- 4) attr NPC ใกล้ตัว (<40) เปลี่ยน (เผื่อถ่ายแล้วผีโดนแฉ)
local npcs = workspace:FindFirstChild("NPCs")
if npcs then
    for _, m in ipairs(npcs:GetChildren()) do
        watch(m.AttributeChanged:Connect(function(a)
            addLine(("[NPC %s] %s = %s"):format(m.Name, a, tostring(m:GetAttribute(a))), C.B)
        end))
    end
end
addLine(">> ไปกดถ่าย 1 ครั้ง แล้วกด Copy ส่งมา", C.OK)
