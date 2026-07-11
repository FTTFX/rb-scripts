-- 74RB_CoffeeSpy v1.0 — ดัมพ์ตำแหน่งเครื่องกาแฟทั้ง 2 เครื่อง + ป้าย ready/brewing
-- เปิดในเกม → เดินให้เห็นเครื่องกาแฟ → กด RESCAN → Copy ส่งมา (จะได้ fix พิกัดถูกเครื่อง)

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("AHCOFGUI"); if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = "AHCOFGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,620,0,480); frame.Position = UDim2.new(0.5,-310,0.5,-240)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-180,0,28); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "Coffee Spy — scanning..."; titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
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
local function partPos(inst)
    if not inst then return end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then local p = inst:FindFirstChildWhichIsA("BasePart", true) return p and p.Position end
    local p = inst:FindFirstAncestorWhichIsA("BasePart"); return p and p.Position
end
local function labelPos(d)
    local part = d:FindFirstAncestorWhichIsA("BasePart")
    if part then return part.Position end
    local bb = d:FindFirstAncestorWhichIsA("BillboardGui")
    local ad = bb and (bb.Adornee or bb.Parent)
    if ad and ad:IsA("BasePart") then return ad.Position end
end

local function runScan()
    for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines = {}; order = 0
    pcall(function()
        local me = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        addLine("me @ " .. (me and v3s(me.Position) or "?"), C.S)

        -- 1) ทุก prompt 'Coffee' — path + พิกัดเป๊ะ
        addLine("=== Coffee prompts ===", C.HEAD)
        local prompts = {}
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.ActionText == "Coffee" then
                prompts[#prompts+1] = p
                local pos = partPos(p.Parent)
                addLine(("[P%d] %s"):format(#prompts, p.Parent and p.Parent:GetFullName() or "?"), C.B)
                addLine(("     pos = %s  Enabled=%s"):format(pos and v3s(pos) or "?", tostring(p.Enabled)), C.OK)
            end
        end
        if #prompts == 0 then addLine("  (ไม่เจอ — เดินเข้าใกล้เครื่องแล้ว RESCAN)", C.M) end

        -- 2) ป้าย coffee ทุกใบ — ข้อความ + พิกัด + ระยะถึงแต่ละ prompt
        addLine("", C.S); addLine("=== coffee labels (ready/brewing) ===", C.HEAD)
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("TextLabel") then
                local t = d.Text:lower()
                if t:find("coffee") or t:find("ready") or t:find("brewing") then
                    local lp2 = labelPos(d)
                    local dists = {}
                    for i, p in ipairs(prompts) do
                        local pp = partPos(p.Parent)
                        if lp2 and pp then dists[#dists+1] = ("P%d=%.1f"):format(i, (lp2 - pp).Magnitude) end
                    end
                    addLine(("'%s'"):format(d.Text), C.M)
                    addLine(("   @ %s | pos=%s | %s"):format(d:GetFullName(), lp2 and v3s(lp2) or "?",
                        table.concat(dists, "  ")), C.S)
                end
            end
        end
    end)
    titleLbl.Text = "Coffee Spy — done (กด Copy)"
end
reBtn.MouseButton1Click:Connect(function() task.spawn(runScan) end)
task.spawn(function() task.wait(0.1); runScan() end)
