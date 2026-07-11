-- 74RB_AnimalHospital_FindNew v1.0
-- หา path ใหม่ 2 จุดที่ health check บอกว่าหาย: (1) ยา (Model.Items) (2) remote folder (Net.RE/RF)
-- เปิดในเกม → GUI ขึ้น → กด Copy ส่งมา

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")
local RS = game:GetService("ReplicatedStorage")

local old = pg:FindFirstChild("AHFINDGUI"); if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = "AHFINDGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,620,0,520); frame.Position = UDim2.new(0.5,-310,0.5,-260)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-100,0,28); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "AH FindNew — searching..."; titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame
local function topBtn(w,x,col,txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,w,0,22); b.Position = UDim2.new(1,x,0,3)
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1,1,1); b.Text = txt
    b.Font = Enum.Font.Code; b.TextSize = 12; b.BorderSizePixel = 0; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4); return b
end
local copyBtn  = topBtn(62,-70,Color3.fromRGB(30,100,50),"Copy")
local closeBtn = topBtn(28,-30,Color3.fromRGB(120,20,20),"X")
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
    scroll.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y)
end
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
copyBtn.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok = clip and pcall(clip, table.concat(copyLines, "\n"))
    copyBtn.Text = ok and "Copied!" or "ไม่รองรับ"
    task.delay(2, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
end)

task.spawn(function()
    task.wait(0.1)
    pcall(function()

    -- (1) ยา: Model ยังอยู่แต่ Items หาย → list ลูก Model + หา ProximityPrompt ที่เป็น "จุดเก็บยา"
    addLine("=== [1] ยา: children ของ Workspace.Model ===", C.HEAD)
    local model = workspace:FindFirstChild("Model")
    if model then
        for _, c in ipairs(model:GetChildren()) do
            addLine(("  %s (%s)"):format(c.Name, c.ClassName), C.B)
        end
    else addLine("  Workspace.Model ไม่มีแล้ว!", C.M) end

    -- หายาจาก ActionText ของ prompt เก็บยา (ชื่อยาที่รู้: Herbs/Eye Drops/Cough Syrup/Maple Syrup)
    addLine("", C.S); addLine("=== [1b] หา ProximityPrompt ที่ ActionText = ชื่อยา (ทั้ง workspace) ===", C.HEAD)
    local medNames = {"Herbs","Eye Drops","Cough Syrup","Maple Syrup","Medicine","Bandages","Antibiotics","Medkit","IV Drops"}
    local found = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            for _, m in ipairs(medNames) do
                if d.ActionText == m then
                    found += 1
                    addLine(("  '%s' @ %s"):format(m, d.Parent and d.Parent:GetFullName() or "?"), C.OK)
                    break
                end
            end
        end
        if found >= 20 then break end
    end
    if found == 0 then addLine("  (ไม่เจอ prompt ชื่อยาเลย — อาจต้องเข้าใกล้ให้ enable ก่อน)", C.S) end

    -- (2) remotes: Net ยังอยู่แต่ RE/RF หาย → dump ลูก Net + หาทุก RemoteEvent/Function ใต้ Util
    addLine("", C.S); addLine("=== [2] children ของ ReplicatedStorage.Util.Net ===", C.HEAD)
    local net = RS:FindFirstChild("Util") and RS.Util:FindFirstChild("Net")
    if net then
        for _, c in ipairs(net:GetChildren()) do
            addLine(("  %s (%s)"):format(c.Name, c.ClassName), C.B)
        end
    else addLine("  Util.Net ไม่มีแล้ว!", C.M) end

    addLine("", C.S); addLine("=== [2b] ทุก RemoteEvent/Function ใน ReplicatedStorage (max 80) ===", C.HEAD)
    local rc = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            rc += 1
            if rc <= 80 then addLine(("  %s (%s)"):format(d:GetFullName(), d.ClassName), C.M) end
        end
    end
    addLine(("  total = %d"):format(rc), C.S)

    end)
    titleLbl.Text = "AH FindNew — done (กด Copy)"
end)
