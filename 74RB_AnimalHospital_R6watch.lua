-- 74RB_AnimalHospital_R6watch v1.0 — จับลำดับการกะพริบปุ่มสี Room6 (Simon "Copy the sequence")
-- เข้า Room6 → เริ่ม X-Ray → ปล่อยให้ปุ่มกะพริบ → timeline จะบันทึกลำดับ → Copy
-- ก็จะรู้ว่า "ลำดับที่ต้องกด" คือเลขอะไรบ้าง + ตอน input ปุ่ม PP enable ไหม

local LP = game:GetService("Players").LocalPlayer
local RS = game:GetService("RunService")
local pg = LP:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("AHR6GUI"); if old then old:Destroy() end
if _G.AHR6_CONNS then for _,c in ipairs(_G.AHR6_CONNS) do pcall(function() c:Disconnect() end) end end

local sg=Instance.new("ScreenGui"); sg.Name="AHR6GUI"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true; sg.Parent=pg
local frame=Instance.new("Frame")
frame.Size=UDim2.new(0,520,0,440); frame.Position=UDim2.new(0.5,-260,0.5,-220)
frame.BackgroundColor3=Color3.fromRGB(12,12,18); frame.BorderSizePixel=0
frame.Active=true; frame.Draggable=true; frame.Parent=sg
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
local titleLbl=Instance.new("TextLabel")
titleLbl.Size=UDim2.new(1,-150,0,28); titleLbl.Position=UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency=1; titleLbl.TextColor3=Color3.fromRGB(120,200,255)
titleLbl.Text="R6 watch — รอปุ่มกะพริบ..."; titleLbl.Font=Enum.Font.Code; titleLbl.TextSize=12
titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=frame
local copyBtn=Instance.new("TextButton")
copyBtn.Size=UDim2.new(0,70,0,22); copyBtn.Position=UDim2.new(1,-140,0,3)
copyBtn.BackgroundColor3=Color3.fromRGB(30,100,50); copyBtn.TextColor3=Color3.new(1,1,1)
copyBtn.Text="Copy"; copyBtn.Font=Enum.Font.Code; copyBtn.TextSize=12
copyBtn.BorderSizePixel=0; copyBtn.Parent=frame
Instance.new("UICorner",copyBtn).CornerRadius=UDim.new(0,4)
local clrBtn=Instance.new("TextButton")
clrBtn.Size=UDim2.new(0,60,0,22); clrBtn.Position=UDim2.new(1,-205,0,3)
clrBtn.BackgroundColor3=Color3.fromRGB(80,80,30); clrBtn.TextColor3=Color3.new(1,1,1)
clrBtn.Text="Clear"; clrBtn.Font=Enum.Font.Code; clrBtn.TextSize=12
clrBtn.BorderSizePixel=0; clrBtn.Parent=frame
Instance.new("UICorner",clrBtn).CornerRadius=UDim.new(0,4)
local closeBtn=Instance.new("TextButton")
closeBtn.Size=UDim2.new(0,40,0,22); closeBtn.Position=UDim2.new(1,-44,0,3)
closeBtn.BackgroundColor3=Color3.fromRGB(120,20,20); closeBtn.TextColor3=Color3.new(1,1,1)
closeBtn.Text="X"; closeBtn.Font=Enum.Font.Code; closeBtn.TextSize=12
closeBtn.BorderSizePixel=0; closeBtn.Parent=frame
Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,4)
local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-8,1,-34); scroll.Position=UDim2.new(0,4,0,30)
scroll.BackgroundColor3=Color3.fromRGB(8,8,14); scroll.BorderSizePixel=0
scroll.ScrollBarThickness=5; scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll.Parent=frame
Instance.new("UICorner",scroll).CornerRadius=UDim.new(0,4)
local layout=Instance.new("UIListLayout"); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=scroll
local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,6); pad.Parent=scroll

local lines, order = {}, 0
local function addLine(txt,col)
    order+=1
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,-12,0,15); l.BackgroundTransparency=1; l.Font=Enum.Font.Code; l.TextSize=11
    l.TextXAlignment=Enum.TextXAlignment.Left; l.TextColor3=col or Color3.fromRGB(210,210,210)
    l.Text=txt; l.LayoutOrder=order; l.Parent=scroll
    table.insert(lines,txt)
    scroll.CanvasPosition=Vector2.new(0,layout.AbsoluteContentSize.Y)
end
copyBtn.MouseButton1Click:Connect(function()
    local clip=setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok=clip and pcall(clip,table.concat(lines,"\n"))
    copyBtn.Text=ok and "OK!" or "ไม่ได้"; task.delay(2,function() if copyBtn.Parent then copyBtn.Text="Copy" end end)
end)
clrBtn.MouseButton1Click:Connect(function()
    for _,c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    lines={}; order=0
end)
closeBtn.MouseButton1Click:Connect(function()
    if _G.AHR6_CONNS then for _,c in ipairs(_G.AHR6_CONNS) do pcall(function() c:Disconnect() end) end _G.AHR6_CONNS=nil end
    sg:Destroy()
end)

addLine("=== R6 watch: เริ่ม X-Ray แล้วดูปุ่มกะพริบ ===", Color3.fromRGB(255,210,0))
_G.AHR6_CONNS = {}
local function track(c) table.insert(_G.AHR6_CONNS, c) end
local function rgb(col) return ("%d,%d,%d"):format(col.R*255, col.G*255, col.B*255) end
local function numOf(p)
    local nm=p:FindFirstChild("ui"); nm=nm and nm:FindFirstChildOfClass("TextLabel")
    return nm and nm.Text or "?"
end

-- ผูก listener ปุ่ม 1 อัน (color/trans/material/PP) — เรียกตอนเจอปุ่มใหม่ทุกครั้ง
local attached = {}
local function attach(p)
    if attached[p] or not p:IsA("BasePart") or p.Name~="Button" then return end
    attached[p]=true
    addLine(("+ ปุ่ม #%s base=%s main=%s"):format(numOf(p), rgb(p.Color),
        p:GetAttribute("MainColor") and rgb(p:GetAttribute("MainColor")) or "?"), Color3.fromRGB(140,140,140))
    track(p:GetPropertyChangedSignal("Color"):Connect(function()
        addLine(("[สีเปลี่ยน] #%s -> %s"):format(numOf(p), rgb(p.Color)), Color3.fromRGB(80,255,120))
    end))
    track(p:GetPropertyChangedSignal("Transparency"):Connect(function()
        addLine(("[trans] #%s -> %.2f"):format(numOf(p), p.Transparency), Color3.fromRGB(140,160,255))
    end))
    local pp=p:FindFirstChild("PP")
    if pp then track(pp:GetPropertyChangedSignal("Enabled"):Connect(function()
        addLine(("[PP] #%s enabled=%s"):format(numOf(p), tostring(pp.Enabled)), Color3.fromRGB(255,160,50))
    end)) end
end

-- หา container Colors แล้วดักทั้งของเดิม + ที่จะถูกสร้างใหม่ตอนเริ่มเกม
local r=workspace:FindFirstChild("Rooms"); r=r and r:FindFirstChild("Emergency")
r=r and r:FindFirstChild("Room6"); r=r and r:FindFirstChild("Minigame")
local colors=r and r:FindFirstChild("Colors")
if not colors then
    addLine("ไม่เจอ Room6.Minigame.Colors — เข้าห้อง 6 ก่อน", Color3.fromRGB(255,80,80))
else
    local n=0
    for _,d in ipairs(colors:GetDescendants()) do attach(d); if attached[d] then n+=1 end end
    addLine("ผูกปุ่มเดิม "..n.." อัน + รอปุ่มใหม่ตอนเริ่มเกม", Color3.fromRGB(140,160,255))
    track(colors.DescendantAdded:Connect(attach))   -- ปุ่มที่สร้างตอนเริ่ม X-Ray
end
warn("[R6watch] armed (dynamic) — เริ่ม X-Ray ได้เลย")
