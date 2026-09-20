-- Egg01 Experiment Farm v1.0 -- ไล่ตี Dr. Scramble's Experiments ด้วยการใช้ไม้ปกติ
if _G.EGG01_EXPERIMENT_FARM then
    _G.EGG01_EXPERIMENT_FARM.run=false
    pcall(function() _G.EGG01_EXPERIMENT_FARM.gui:Destroy() end)
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local S={run=false,gui=nil,lines={},searchOrigin=nil,searchIndex=0}; _G.EGG01_EXPERIMENT_FARM=S
local logBox
local function say(m)
    S.lines[#S.lines+1]=tostring(m); if #S.lines>12 then table.remove(S.lines,1) end
    if logBox then logBox.Text=table.concat(S.lines,"\n") end
    warn("[ExperimentFarm] "..tostring(m))
end
local function char()
    local c=LP.Character; return c,c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart")
end
local function norm(s) return tostring(s or ""):lower():gsub("[^%w]","") end
local function rootPart(m)
    if not m then return end
    if m:IsA("BasePart") then return m end
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart",true) or m:FindFirstChildWhichIsA("BasePart",true)
end
local function modelOf(x)
    while x and x~=workspace do
        if x:IsA("Model") then return x end
        x=x.Parent
    end
end
local function hpOf(m)
    local found
    for _,x in ipairs(m:GetDescendants()) do
        if x:IsA("TextLabel") or x:IsA("TextButton") then
            local a,b=tostring(x.Text):match("(%d+)%s*/%s*(%d+)")
            if a and b then return tonumber(a),tonumber(b),x.Text end
            if tostring(x.Text):lower():find("hp",1,true) then found=x.Text end
        end
    end
    return nil,nil,found
end
local function isExperiment(m)
    if not m or m:IsDescendantOf(LP.Character or Instance.new("Folder")) then return false end
    local name=norm(m.Name)
    if name:find("scramble",1,true) or name:find("experiment",1,true) then return true end
    for _,x in ipairs(m:GetDescendants()) do
        if x:IsA("TextLabel") or x:IsA("TextButton") then
            local s=norm(x.Text)
            if s:find("drscramble",1,true) or s:find("experiment",1,true) then return true end
        end
    end
    return false
end
local function robots()
    local _,_,r=char(); if not r then return {} end
    local out,seen={},{}
    for _,x in ipairs(workspace:GetDescendants()) do
        if x:IsA("TextLabel") or x:IsA("TextButton") then
            local s=norm(x.Text)
            -- ป้ายชื่อหุ่นบางรอบมาเป็น "6/10 HP" ก่อนชื่อ Dr. Scramble จึงใช้ทั้งสองแบบ
            local hasHP=tostring(x.Text):match("%d+%s*/%s*%d+")~=nil
            if s:find("drscramble",1,true) or s:find("experiment",1,true) or hasHP then
                local m=modelOf(x); local p=rootPart(m)
                if m and p and not seen[m] and (isExperiment(m) or hasHP) then
                    seen[m]=true; local hp,max,label=hpOf(m)
                    if not hp or hp>0 then out[#out+1]={m=m,p=p,pos=p.Position,hp=hp,max=max,label=label,d=(p.Position-r.Position).Magnitude} end
                end
            end
        end
    end
    -- เลือกหุ่นเลือดรวมสูงก่อน: 10 → 5 → 3; ในกลุ่มเดียวกันเอาตัวไกลสุด
    table.sort(out,function(a,b)
        local ah,bh=tonumber(a.max) or 0,tonumber(b.max) or 0
        if ah~=bh then return ah>bh end
        return a.d>b.d
    end); return out
end
local function searchStep()
    local _,_,r=char(); if not r then return end
    S.searchOrigin=S.searchOrigin or r.Position
    -- เดินค้นหาแบบวงรอบ: ไม่วาร์ป และ scan ใหม่ทุกจุด
    local offsets={Vector3.new(110,0,0),Vector3.new(110,0,110),Vector3.new(0,0,110),Vector3.new(-110,0,110),Vector3.new(-110,0,0),Vector3.new(-110,0,-110),Vector3.new(0,0,-110),Vector3.new(110,0,-110)}
    S.searchIndex=(S.searchIndex % #offsets)+1
    local goal=S.searchOrigin+offsets[S.searchIndex]
    say(string.format("ไม่พบหุ่น — เดินค้นหาจุด %d/%d",S.searchIndex,#offsets))
    walkTo(goal,14,12)
end
local walkTo
local function scan()
    local all=robots(); say("พบหุ่น="..#all)
    for i=1,math.min(#all,6) do local x=all[i]; say(string.format("#%d %s hp=%s d=%.0f",i,x.m.Name,x.label or "?",x.d)) end
    return all
end
walkTo=function(point,range,limit)
    local began=os.clock()
    while S.run and os.clock()-began<limit do
        local _,h,r=char(); if not h or not r or h.Health<=0 then return false end
        local goal=Vector3.new(point.X,r.Position.Y,point.Z)
        if (goal-r.Position).Magnitude<=range then h:MoveTo(r.Position); return true end
        h:MoveTo(goal); task.wait(.15)
    end
    return false
end
local function bat()
    local c,h=char(); if not c or not h then return end
    local t=c:FindFirstChildOfClass("Tool")
    if not t then t=LP.Backpack:FindFirstChildWhichIsA("Tool"); if t then pcall(function() h:EquipTool(t) end); task.wait(.15) end end
    return t
end
local function hit(robot)
    if not walkTo(robot.pos,10,70) then say("ไปไม่ถึง "..robot.m.Name); return end
    local tool=bat(); if not tool then say("ไม่พบไม้/Tool") return end
    say("ตี "..robot.m.Name.." | "..(robot.label or "HP ?"))
    local began=os.clock(); local lastHP=robot.hp
    while S.run and os.clock()-began<10 do
        local p=rootPart(robot.m); if not p or not robot.m.Parent then say("หุ่นหาย/แพ้แล้ว"); return end
        local _,h,r=char(); if not h or not r or (p.Position-r.Position).Magnitude>14 then break end
        local hp,max,label=hpOf(robot.m)
        if hp and hp<=0 then say("กำจัดแล้ว"); return end
        if hp and lastHP and hp<lastHP then say("HP "..lastHP.." → "..hp); lastHP=hp end
        pcall(function() tool:Activate() end)
        task.wait(.62)
    end
    say("เปลี่ยนเป้าถัดไป")
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentFarm";gui.ResetOnSpawn=false;gui.DisplayOrder=1022
pcall(function()gui.Parent=(gethui and gethui()) or game:GetService("CoreGui")end); if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui")end;S.gui=gui
local f=Instance.new("Frame",gui);f.Size=UDim2.new(0,385,0,220);f.Position=UDim2.new(0,12,.42,0);f.BackgroundColor3=Color3.fromRGB(18,43,46);f.BorderSizePixel=0;f.Active=true;f.Draggable=true;Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f);title.Size=UDim2.new(1,-80,0,30);title.Position=UDim2.new(0,10,0,3);title.BackgroundTransparency=1;title.Text="Egg01 Experiment Farm v1.0";title.TextColor3=Color3.fromRGB(145,245,230);title.Font=Enum.Font.GothamBold;title.TextSize=14;title.TextXAlignment=Enum.TextXAlignment.Left
local function button(text,x,color,w)
    local b=Instance.new("TextButton",f);b.Size=UDim2.new(0,w or 72,0,30);b.Position=UDim2.new(0,x,0,38);b.Text=text;b.TextColor3=Color3.new(1,1,1);b.BackgroundColor3=color;b.BorderSizePixel=0;b.Font=Enum.Font.GothamBold;b.TextSize=11;Instance.new("UICorner",b).CornerRadius=UDim.new(0,5);return b
end
local scanB=button("SCAN",10,Color3.fromRGB(45,105,165));local start=button("AUTO",88,Color3.fromRGB(35,145,75));local stopB=button("STOP",166,Color3.fromRGB(165,50,55));local copy=button("COPY",244,Color3.fromRGB(75,75,80));local fold=button("−",310,Color3.fromRGB(75,65,105),28);local close=button("X",344,Color3.fromRGB(145,50,65),28)
logBox=Instance.new("TextLabel",f);logBox.Size=UDim2.new(1,-16,0,132);logBox.Position=UDim2.new(0,8,0,78);logBox.BackgroundColor3=Color3.new(0,0,0);logBox.BackgroundTransparency=.2;logBox.TextColor3=Color3.fromRGB(180,245,190);logBox.Font=Enum.Font.Code;logBox.TextSize=10;logBox.TextXAlignment=Enum.TextXAlignment.Left;logBox.TextYAlignment=Enum.TextYAlignment.Top;logBox.TextWrapped=true;logBox.ClipsDescendants=true
local folded=false;fold.MouseButton1Click:Connect(function() folded=not folded;f.Size=UDim2.new(0,385,0,folded and 34 or 220);for _,x in ipairs({scanB,start,stopB,copy,logBox})do x.Visible=not folded end;fold.Text=folded and "+" or "−"end)
scanB.MouseButton1Click:Connect(scan)
start.MouseButton1Click:Connect(function()
    if S.run then return end;S.run=true;start.Text="ON";say("AUTO ON — HP 10 → 5 → 3 | กลุ่มเดียวกันเอาไกลสุด")
    local _,_,r=char();S.searchOrigin=r and r.Position or nil;S.searchIndex=0
    task.spawn(function() while S.run do local all=robots();if #all==0 then searchStep();task.wait(.4) else hit(all[1]);task.wait(.4) end end;start.Text="AUTO" end)
end)
stopB.MouseButton1Click:Connect(function()S.run=false;local _,h,r=char();if h and r then h:MoveTo(r.Position);h:Move(Vector3.zero)end;say("STOP")end)
copy.MouseButton1Click:Connect(function()local c=setclipboard or toclipboard;if c then pcall(c,"=== Egg01 Experiment Farm v1.0 ===\n"..table.concat(S.lines,"\n"));copy.Text="OK";task.delay(1,function()if copy.Parent then copy.Text="COPY"end end)end end)
close.MouseButton1Click:Connect(function()S.run=false;gui:Destroy();_G.EGG01_EXPERIMENT_FARM=nil end)
say("SCAN → ตรวจหุ่น | AUTO → ไล่ตีด้วยไม้ปกติ")
