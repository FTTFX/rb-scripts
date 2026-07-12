-- 74RB_ExtSpy v1.0 — ดัมพ์แท่นถังดับเพลิงทุกจุด (prompt ที่มีคำว่า Ext) + ระยะจากตัวเรา
-- เปิดในเกม → เดินไปยืนแถวแท่นจริง → RESCAN → Copy ส่งมา (จะได้ล็อกพิกัดแท่นจริง ตัดตัวนอกแมพ)

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("AHEXTGUI"); if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = "AHEXTGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,640,0,420); frame.Position = UDim2.new(0.5,-320,0.5,-210)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-180,0,28); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "Ext Station Spy"; titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame
local function topBtn(w,x,col,txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,w,0,22); b.Position = UDim2.new(1,x,0,3)
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1,1,1); b.Text = txt
    b.Font = Enum.Font.Code; b.TextSize = 12; b.BorderSizePixel = 0; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4); return b
end
local copyBtn  = topBtn(62,-172,Color3.fromRGB(30,100,50),"Copy")
local reBtn    = topBtn(64,-106,Color3.fromRGB(40,70,120),"RESCAN")
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
local function addLine(txt,col)
    order += 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-12,0,15); l.BackgroundTransparency = 1; l.Font = Enum.Font.Code
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextTruncate = Enum.TextTruncate.AtEnd
    l.TextColor3 = col or C.S; l.Text = txt; l.LayoutOrder = order; l.Parent = scroll
    table.insert(copyLines, txt)
end
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
copyBtn.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok = clip and pcall(clip, table.concat(copyLines, "\n"))
    copyBtn.Text = ok and "Copied!" or "ไม่รองรับ"
    task.delay(2, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
end)

local function v3s(v) return ("%.1f, %.1f, %.1f"):format(v.X, v.Y, v.Z) end

local function runScan()
    for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines = {}; order = 0
    pcall(function()
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local me = r and r.Position
        addLine("me @ " .. (me and v3s(me) or "?"), C.S)
        addLine("=== prompts ที่มี 'ext' (ยืม/คืนถัง) ===", C.HEAD)
        local n = 0
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt")
               and (p.ActionText .. " " .. p.ObjectText):lower():find("ext", 1, true) then
                n += 1
                local a = p:FindFirstAncestorWhichIsA("BasePart")
                local pos = a and a.Position
                if not pos and p.Parent then
                    local b = p.Parent:FindFirstChildWhichIsA("BasePart", true)
                    pos = b and b.Position
                end
                local d = pos and me and (pos - me).Magnitude
                addLine(("[E%d] Action='%s' Object='%s' Enabled=%s"):format(n, p.ActionText, p.ObjectText, tostring(p.Enabled)), C.B)
                addLine(("     @ %s"):format(p.Parent and p.Parent:GetFullName() or "?"), C.S)
                addLine(("     pos=%s | ห่างเรา %s"):format(pos and v3s(pos) or "?",
                    d and ("%.1f"):format(d) or "?"), d and d < 60 and C.OK or C.M)
            end
        end
        if n == 0 then addLine("  (ไม่เจอ)", C.M) end
        addLine("", C.S)
        addLine(">> เดินไปยืนหน้าแท่นจริง แล้ว RESCAN — ตัวที่ห่างน้อยๆ (เขียว) = แท่นจริง", C.OK)
        addLine(">> Copy ส่งมา จะได้ล็อกพิกัด ตัดแท่นนอกแมพทิ้ง", C.OK)
    end)
    titleLbl.Text = "Ext Station Spy — done (กด Copy)"
end
reBtn.MouseButton1Click:Connect(function() task.spawn(runScan) end)
task.spawn(function() task.wait(0.1); runScan() end)
