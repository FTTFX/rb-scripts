-- 74RB_AnimalHospital_R6watch v1.0 — จับลำดับการกะพริบปุ่มสี Room6 (Simon "Copy the sequence")
-- เข้า Room6 → เริ่ม X-Ray → ปล่อยให้ปุ่มกะพริบ → timeline จะบันทึกลำดับ → Copy
-- ก็จะรู้ว่า "ลำดับที่ต้องกด" คือเลขอะไรบ้าง + ตอน input ปุ่ม PP enable ไหม

local LP = game:GetService("Players").LocalPlayer
local RS = game:GetService("RunService")
local pg = LP:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("AHR6GUI"); if old then old:Destroy() end
if _G.AHR6_CONN then pcall(function() _G.AHR6_CONN:Disconnect() end) end

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
    if _G.AHR6_CONN then pcall(function() _G.AHR6_CONN:Disconnect() end) _G.AHR6_CONN=nil end
    sg:Destroy()
end)

-- หาปุ่ม Room6
local function getButtons()
    local r=workspace:FindFirstChild("Rooms"); r=r and r:FindFirstChild("Emergency")
    r=r and r:FindFirstChild("Room6"); r=r and r:FindFirstChild("Minigame")
    r=r and r:FindFirstChild("Colors"); r=r and r:FindFirstChild("Model")
    if not r then return {} end
    local out={}
    for _,b in ipairs(r:GetChildren()) do
        if b:IsA("BasePart") and b.Name=="Button" then
            local nm=b:FindFirstChild("ui"); nm=nm and nm:FindFirstChildOfClass("TextLabel")
            out[#out+1]={ part=b, num=(nm and nm.Text or "?"),
                main=b:GetAttribute("MainColor"), pp=b:FindFirstChild("PP") }
        end
    end
    return out
end

addLine("=== R6 watch: เริ่ม X-Ray แล้วดูปุ่มกะพริบ ===", Color3.fromRGB(255,210,0))
local btns=getButtons()
addLine("เจอปุ่ม "..#btns.." อัน", Color3.fromRGB(140,160,255))

-- lit = Part.Color ใกล้ MainColor (สว่าง) ไม่ใช่สีมืด
local lit, lastPP = {}, {}
local function near(a,b) if not(a and b) then return false end
    return math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B) < 0.25 end

_G.AHR6_CONN = RS.Heartbeat:Connect(function()
    for i,bt in ipairs(btns) do
        if bt.part and bt.part.Parent then
            local on = near(bt.part.Color, bt.main)
            if on and not lit[i] then
                addLine("[กะพริบ] ปุ่ม #"..bt.num, Color3.fromRGB(80,255,120))
            end
            lit[i]=on
            -- log ตอน PP เปิด (ช่วง input ให้กด)
            if bt.pp then
                local en=bt.pp.Enabled
                if en and not lastPP[i] then addLine("[PP-ON] ปุ่ม #"..bt.num.." กดได้แล้ว", Color3.fromRGB(255,160,50)) end
                lastPP[i]=en
            end
        end
    end
end)
warn("[R6watch] armed — เริ่ม X-Ray ได้เลย")
