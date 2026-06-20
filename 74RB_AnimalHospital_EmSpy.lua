-- 74RB_AnimalHospital_EmSpy v1.0 — สแกน Emergency Room6 + Room7 (ข้าม Room8)
-- เข้าไปในห้อง 6 หรือ 7 ตอนมีคนไข้/มินิเกมเปิด → รัน → กด RESCAN → Copy
-- ดู: prompt (action/enabled), values, text บนจอ, สีปุ่ม (color minigame), รูป

local LP = game:GetService("Players").LocalPlayer
local pg = LP:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("AHEMGUI"); if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name="AHEMGUI"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.Parent=pg
local frame=Instance.new("Frame")
frame.Size=UDim2.new(0,600,0,470); frame.Position=UDim2.new(0.5,-300,0.5,-235)
frame.BackgroundColor3=Color3.fromRGB(12,12,18); frame.BorderSizePixel=0
frame.Active=true; frame.Draggable=true; frame.Parent=sg
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
local titleLbl=Instance.new("TextLabel")
titleLbl.Size=UDim2.new(1,-185,0,28); titleLbl.Position=UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency=1; titleLbl.TextColor3=Color3.fromRGB(120,200,255)
titleLbl.Text="EmSpy v1 — scanning..."; titleLbl.Font=Enum.Font.Code; titleLbl.TextSize=13
titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=frame
local copyBtn=Instance.new("TextButton")
copyBtn.Size=UDim2.new(0,110,0,22); copyBtn.Position=UDim2.new(1,-178,0,3)
copyBtn.BackgroundColor3=Color3.fromRGB(30,100,50); copyBtn.TextColor3=Color3.new(1,1,1)
copyBtn.Text="Copy"; copyBtn.Font=Enum.Font.Code; copyBtn.TextSize=12
copyBtn.BorderSizePixel=0; copyBtn.Parent=frame
Instance.new("UICorner",copyBtn).CornerRadius=UDim.new(0,4)
local rescanBtn=Instance.new("TextButton")
rescanBtn.Size=UDim2.new(0,90,0,22); rescanBtn.Position=UDim2.new(1,-272,0,3)
rescanBtn.BackgroundColor3=Color3.fromRGB(40,70,120); rescanBtn.TextColor3=Color3.new(1,1,1)
rescanBtn.Text="RESCAN"; rescanBtn.Font=Enum.Font.Code; rescanBtn.TextSize=12
rescanBtn.BorderSizePixel=0; rescanBtn.Parent=frame
Instance.new("UICorner",rescanBtn).CornerRadius=UDim.new(0,4)
local closeBtn=Instance.new("TextButton")
closeBtn.Size=UDim2.new(0,60,0,22); closeBtn.Position=UDim2.new(1,-64,0,3)
closeBtn.BackgroundColor3=Color3.fromRGB(120,20,20); closeBtn.TextColor3=Color3.new(1,1,1)
closeBtn.Text="ปิด"; closeBtn.Font=Enum.Font.Code; closeBtn.TextSize=12
closeBtn.BorderSizePixel=0; closeBtn.Parent=frame
Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,4)
local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-8,1,-34); scroll.Position=UDim2.new(0,4,0,30)
scroll.BackgroundColor3=Color3.fromRGB(8,8,14); scroll.BorderSizePixel=0
scroll.ScrollBarThickness=5; scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll.Parent=frame
Instance.new("UICorner",scroll).CornerRadius=UDim.new(0,4)
local layout=Instance.new("UIListLayout"); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=scroll
local padL=Instance.new("UIPadding"); padL.PaddingLeft=UDim.new(0,6); padL.Parent=scroll

local copyLines, order = {}, 0
local C={Y=Color3.fromRGB(255,210,0),G=Color3.fromRGB(80,255,120),B=Color3.fromRGB(140,160,255),
    O=Color3.fromRGB(255,160,50),W=Color3.fromRGB(210,210,210),S=Color3.fromRGB(140,140,140),
    R=Color3.fromRGB(255,80,80),M=Color3.fromRGB(255,120,255)}
local function addLine(txt,col)
    order+=1
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,-12,0,15); l.BackgroundTransparency=1
    l.Font=Enum.Font.Code; l.TextSize=11; l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.AtEnd; l.TextColor3=col or C.W
    l.Text=txt; l.LayoutOrder=order; l.Parent=scroll
    table.insert(copyLines,txt)
end
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
copyBtn.MouseButton1Click:Connect(function()
    local clip=setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok=clip and pcall(clip,table.concat(copyLines,"\n"))
    copyBtn.Text=ok and "Copied!" or "ไม่รองรับ"
    task.delay(2,function() if copyBtn.Parent then copyBtn.Text="Copy" end end)
end)

local function relPath(c,root)
    local s=c.Name; local p=c.Parent
    while p and p~=root do s=p.Name.."."..s; p=p.Parent end
    return s
end
local function attrsStr(inst)
    local ak={}
    for k,v in pairs(inst:GetAttributes()) do ak[#ak+1]=k.."="..tostring(v) end
    return table.concat(ak,", ")
end
local function col3(c) return ("%d,%d,%d"):format(c.R*255,c.G*255,c.B*255) end

local function dumpRoom(room)
    addLine("===== "..room.Name.." =====", C.Y)
    local ra=attrsStr(room); if ra~="" then addLine("  attrs: "..ra, C.O) end
    for _,c in ipairs(room:GetDescendants()) do
        local rp=relPath(c,room)
        if c:IsA("ProximityPrompt") then
            addLine(("  [PP] '%s' enabled=%s @ %s"):format(tostring(c.ActionText),tostring(c.Enabled),rp), C.G)
        elseif c:IsA("ValueBase") then
            addLine(("  [VAL] %s = %s"):format(rp,tostring(c.Value)), C.M)
        elseif c:IsA("TextLabel") and c.Text~="" then
            addLine(("  [TXT] %s = '%s'"):format(rp,c.Text), C.W)
        elseif (c:IsA("ImageLabel") or c:IsA("ImageButton")) and c.Image~="" then
            addLine(("  [IMG] %s = %s"):format(rp,c.Image), C.B)
        elseif c:IsA("Decal") and c.Texture~="" then
            addLine(("  [DECAL] %s = %s"):format(rp,c.Texture), C.B)
        elseif c:IsA("BasePart") then
            -- ปุ่ม/ไฟสีในเกมจับคู่สี: โชว์สีถ้าชื่อเกี่ยว button/light/color
            local low=c.Name:lower()
            if low:find("button") or low:find("light") or low:find("color") or low:find("led") then
                addLine(("  [PART] %s color=%s"):format(rp,col3(c.Color)), C.O)
            end
        end
        local ca=attrsStr(c)
        if ca~="" then addLine(("    attr@%s: %s"):format(rp,ca), C.S) end
    end
    addLine("",C.S)
end

local function runScan()
    for _,c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines={}; order=0
    task.wait(0.05)
    local ok,err=pcall(function()
        local em=workspace:FindFirstChild("Rooms")
        em=em and em:FindFirstChild("Emergency")
        if not em then addLine("ไม่เจอ Workspace.Rooms.Emergency", C.R); return end
        for _,name in ipairs({"Room6","Room7"}) do   -- ข้าม Room8
            local room=em:FindFirstChild(name)
            if room then dumpRoom(room) else addLine("ไม่เจอ "..name, C.O) end
        end
    end)
    if not ok then addLine("SCAN ERROR: "..tostring(err), C.R) end
    addLine(">> เข้าไปในห้อง 6/7 ตอนมินิเกมเปิด → กด RESCAN → Copy", C.Y)
    titleLbl.Text="EmSpy v1 — done (กด Copy / RESCAN)"
end
rescanBtn.MouseButton1Click:Connect(function()
    titleLbl.Text="EmSpy v1 — rescanning..."; task.spawn(runScan)
end)
task.spawn(runScan)
