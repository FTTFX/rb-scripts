-- 74RB_AnimalHospital_FireSpy v1.0 — หา "ไฟกองพื้น" ใกล้ตัว (Fire/ParticleEmitter/Part)
-- ยืนใกล้ไฟพื้น → รัน → กด RESCAN → Copy  (ดู class/name/path/ระยะ เรียงใกล้สุด)
local LP = game:GetService("Players").LocalPlayer
local pg = LP:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("AHFIREGUI"); if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name="AHFIREGUI"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.Parent=pg
local frame=Instance.new("Frame")
frame.Size=UDim2.new(0,600,0,460); frame.Position=UDim2.new(0.5,-300,0.5,-230)
frame.BackgroundColor3=Color3.fromRGB(12,12,18); frame.BorderSizePixel=0
frame.Active=true; frame.Draggable=true; frame.Parent=sg
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
local titleLbl=Instance.new("TextLabel")
titleLbl.Size=UDim2.new(1,-280,0,28); titleLbl.Position=UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency=1; titleLbl.TextColor3=Color3.fromRGB(255,160,80)
titleLbl.Text="FireSpy — ยืนใกล้ไฟ แล้ว RESCAN"; titleLbl.Font=Enum.Font.Code; titleLbl.TextSize=13
titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=frame
local function mkBtn(txt,w,x,col)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(0,w,0,22); b.Position=UDim2.new(1,x,0,3)
    b.BackgroundColor3=col; b.TextColor3=Color3.new(1,1,1); b.Text=txt; b.Font=Enum.Font.Code
    b.TextSize=12; b.BorderSizePixel=0; b.Parent=frame
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,4); return b
end
local copyBtn=mkBtn("Copy",110,-178,Color3.fromRGB(30,100,50))
local rescanBtn=mkBtn("RESCAN",90,-272,Color3.fromRGB(40,70,120))
local closeBtn=mkBtn("ปิด",60,-64,Color3.fromRGB(120,20,20))
local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-8,1,-34); scroll.Position=UDim2.new(0,4,0,30)
scroll.BackgroundColor3=Color3.fromRGB(8,8,14); scroll.BorderSizePixel=0
scroll.ScrollBarThickness=5; scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll.Parent=frame
Instance.new("UICorner",scroll).CornerRadius=UDim.new(0,4)
local layout=Instance.new("UIListLayout"); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=scroll
Instance.new("UIPadding",scroll).PaddingLeft=UDim.new(0,6)

local copyLines, order = {}, 0
local C={Y=Color3.fromRGB(255,210,0),G=Color3.fromRGB(80,255,120),B=Color3.fromRGB(140,160,255),
    O=Color3.fromRGB(255,160,50),W=Color3.fromRGB(210,210,210),S=Color3.fromRGB(140,140,140),R=Color3.fromRGB(255,80,80)}
local function addLine(txt,col)
    order+=1
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-12,0,15); l.BackgroundTransparency=1
    l.Font=Enum.Font.Code; l.TextSize=11; l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.AtEnd; l.TextColor3=col or C.W; l.Text=txt; l.LayoutOrder=order; l.Parent=scroll
    table.insert(copyLines,txt)
end
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
copyBtn.MouseButton1Click:Connect(function()
    local clip=setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok=clip and pcall(clip,table.concat(copyLines,"\n"))
    copyBtn.Text=ok and "Copied!" or "ไม่รองรับ"
    task.delay(2,function() if copyBtn.Parent then copyBtn.Text="Copy" end end)
end)

local FIRE_WORDS={"fire","flame","burn","ember","blaze","smoke","heat"}
local function nameHints(s) s=s:lower(); for _,w in ipairs(FIRE_WORDS) do if s:find(w) then return true end end return false end
local function hrp() local c=LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function posOf(inst)
    if inst:IsA("BasePart") then return inst.Position end
    local b=inst.Parent
    if b and b:IsA("BasePart") then return b.Position end
    local bb=inst:FindFirstAncestorWhichIsA("BasePart"); return bb and bb.Position
end

local RANGE=45
local function runScan()
    for _,c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines={}; order=0
    local r=hrp()
    if not r then addLine("ไม่เจอตัวละคร",C.R); return end
    local me=r.Position
    addLine(("===== หาไฟใกล้ตัว (<%dm) — ยืนในไฟแล้วสแกน ====="):format(RANGE),C.Y)
    local hits={}
    for _,d in ipairs(workspace:GetDescendants()) do
        local kind,info
        if d:IsA("Fire") then kind="Fire"
        elseif d:IsA("ParticleEmitter") and d.Enabled then kind="Particle"
        elseif d:IsA("Smoke") then kind="Smoke"
        elseif d:IsA("BasePart") and (nameHints(d.Name) or d.Material==Enum.Material.Neon) then kind="Part"
        elseif (d:IsA("Model") or d:IsA("Folder")) and nameHints(d.Name) then kind="Model" end
        if kind then
            local p=posOf(d)
            if p then
                local dist=(p-me).Magnitude
                if dist<RANGE then hits[#hits+1]={d=d,kind=kind,dist=dist} end
            end
        end
    end
    table.sort(hits,function(a,b) return a.dist<b.dist end)
    if #hits==0 then addLine("ไม่เจอ object คล้ายไฟในระยะ — ลองขยับเข้าไฟ/เพิ่ม RANGE",C.O) end
    local n=0
    for _,h in ipairs(hits) do
        if n>=40 then break end
        n+=1
        local d=h.d
        addLine(("[%s] %.0fm  %s <%s>"):format(h.kind,h.dist,d.Name,d.ClassName),
            h.kind=="Fire" and C.R or h.kind=="Particle" and C.O or C.G)
        addLine("   "..d:GetFullName(),C.S)
        -- เผื่อมี ProximityPrompt/ClickDetector แถวนั้น (จุดกด)
        local par=d:IsA("BasePart") and d or (d.Parent and d.Parent:IsA("BasePart") and d.Parent)
        if par then
            for _,ch in ipairs(par:GetChildren()) do
                if ch:IsA("ProximityPrompt") then addLine(("     [PP] act='%s' enabled=%s"):format(tostring(ch.ActionText),tostring(ch.Enabled)),C.B)
                elseif ch:IsA("ClickDetector") then addLine("     [ClickDetector]",C.B) end
            end
            local at=par:GetAttributes()
            local ak={}; for k,v in pairs(at) do ak[#ak+1]=k.."="..tostring(v) end
            if #ak>0 then addLine("     attr: "..table.concat(ak,", "),C.S) end
        end
    end
    addLine(("(เจอ %d ตัว)"):format(#hits),C.S)
    titleLbl.Text="FireSpy — done ("..#hits..") กด Copy"
end
rescanBtn.MouseButton1Click:Connect(function() titleLbl.Text="FireSpy — scanning..."; task.spawn(runScan) end)
task.spawn(runScan)
