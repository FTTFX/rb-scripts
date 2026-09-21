-- Egg01 Experiment Farm v1.5 -- DOCK + SCHED :00/:30 + CLIP test + MOTION_BRAKE
if _G.EGG01_EXPERIMENT_FARM then
    _G.EGG01_EXPERIMENT_FARM.run=false
    pcall(function() _G.EGG01_EXPERIMENT_FARM.gui:Destroy() end)
end
local Players=game:GetService("Players")
local RunS=game:GetService("RunService")
local LP=Players.LocalPlayer
local LEAD=60
local FARM_WINDOW=600
local S={run=false,mode=nil,gui=nil,lines={},searchOrigin=nil,searchIndex=0,dock=nil,clockSkew=0,clip=false,clipConn=nil,clipParts={}}; _G.EGG01_EXPERIMENT_FARM=S
local logBox
local function say(m)
    S.lines[#S.lines+1]=tostring(m); if #S.lines>14 then table.remove(S.lines,1) end
    if logBox then logBox.Text=table.concat(S.lines,"\n") end
    warn("[ExperimentFarm] "..tostring(m))
end
local function char()
    local c=LP.Character; return c,c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart")
end
local function serverNow()
    local ok,t=pcall(function() return workspace:GetServerTimeNow() end)
    return (ok and t or os.time())+(S.clockSkew or 0)
end
local function fmtHMS(t)
    t=math.floor(t%86400)
    return string.format("%02d:%02d:%02d",math.floor(t/3600),math.floor(t/60)%60,t%60)
end
local function secsToBoundary(t)
    local sec=math.floor(t)%1800
    local rem=1800-sec
    if rem==1800 then rem=0 end
    return rem
end
local function setClip(on)
    local c=LP.Character
    if not on then
        if S.clipConn then pcall(function() S.clipConn:Disconnect() end); S.clipConn=nil end
        for part,was in pairs(S.clipParts) do
            if part and part.Parent then pcall(function() part.CanCollide=was end) end
        end
        S.clipParts={}; S.clip=false; return
    end
    if not c then return end
    S.clipParts={}
    for _,p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then
            S.clipParts[p]=p.CanCollide
            p.CanCollide=false
        end
    end
    if S.clipConn then pcall(function() S.clipConn:Disconnect() end) end
    S.clipConn=RunS.Stepped:Connect(function()
        local ch=LP.Character; if not ch then return end
        for _,p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                if S.clipParts[p]==nil then S.clipParts[p]=true end
                p.CanCollide=false
            end
        end
    end)
    S.clip=true
end
local function stop(label)
    local _,h,r=char(); if not h or not r then return end
    h:MoveTo(r.Position); h:Move(Vector3.zero)
    for _=1,3 do
        if not r.Parent then break end
        r.AssemblyLinearVelocity=Vector3.zero; r.AssemblyAngularVelocity=Vector3.zero
        RunS.Heartbeat:Wait()
    end
    if label then say(label) end
end
local function walk(p,rad,lim,slowNear)
    local t=os.clock(); local moveHum,oldSpeed,lastBand
    local function restore()
        if moveHum and moveHum.Parent then moveHum.WalkSpeed=oldSpeed end
    end
    while S.run and os.clock()-t<lim do
        local _,h,r=char(); if not h or not r or h.Health<=0 then restore(); return false end
        local g=Vector3.new(p.X,r.Position.Y,p.Z); local d=(g-r.Position).Magnitude
        if d<=rad then restore(); stop(); return true end
        if slowNear then
            if not moveHum then moveHum=h; oldSpeed=h.WalkSpeed end
            local band,cap
            if d<=18 then band,cap="ละเอียด",35 elseif d<=slowNear then band,cap="ชะลอ",90 else band,cap="ปกติ",oldSpeed end
            h.WalkSpeed=math.min(oldSpeed,cap)
            if band~=lastBand and band~="ปกติ" then say(band.."ก่อนถึงเป้า — เหลือ "..math.floor(d).." studs") end
            lastBand=band
        end
        h:MoveTo(g); task.wait(.04)
    end
    restore()
    return false
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
    if name:find("dronevisual",1,true) or name:find("scramble",1,true) or name:find("experiment",1,true) then return true end
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
            if s:find("drscramble",1,true) or s:find("experiment",1,true) or tostring(x.Text):match("%d+%s*/%s*%d+") then
                local m=modelOf(x); local p=rootPart(m)
                if m and p and not seen[m] and isExperiment(m) then
                    seen[m]=true; local hp,max,label=hpOf(m)
                    local center=m:GetPivot().Position
                    if not hp or hp>0 then out[#out+1]={m=m,p=p,pos=center,hp=hp,max=max,label=label,d=(center-r.Position).Magnitude} end
                end
            end
        end
    end
    table.sort(out,function(a,b) return a.d<b.d end); return out
end
local function searchStep()
    local _,_,r=char(); if not r then return end
    S.searchOrigin=S.searchOrigin or r.Position
    local offsets={Vector3.new(110,0,0),Vector3.new(110,0,110),Vector3.new(0,0,110),Vector3.new(-110,0,110),Vector3.new(-110,0,0),Vector3.new(-110,0,-110),Vector3.new(0,0,-110),Vector3.new(110,0,-110)}
    S.searchIndex=(S.searchIndex % #offsets)+1
    local goal=S.searchOrigin+offsets[S.searchIndex]
    say(string.format("ไม่พบหุ่น — เดินค้นหาจุด %d/%d",S.searchIndex,#offsets))
    walk(goal,14,12,55)
end
local function scan()
    local all=robots(); say("พบหุ่น="..#all)
    for i=1,math.min(#all,6) do local x=all[i]; say(string.format("#%d %s hp=%s d=%.0f",i,x.m.Name,x.label or "?",x.d)) end
    return all
end
local function bat()
    local c,h=char(); if not c or not h then return end
    local t=c:FindFirstChildOfClass("Tool")
    if not t then t=LP.Backpack:FindFirstChildWhichIsA("Tool"); if t then pcall(function() h:EquipTool(t) end); task.wait(.15) end end
    return t
end
local function hit(robot)
    if not walk(robot.pos,10,70,55) then say("ไปไม่ถึง "..robot.m.Name); return end
    local tool=bat(); if not tool then say("ไม่พบไม้/Tool") return end
    say("ตี "..robot.m.Name.." | "..(robot.label or "HP ?"))
    local began=os.clock(); local lastHP=robot.hp
    while S.run and os.clock()-began<10 do
        local latest=robots()[1]
        local currentPart=rootPart(robot.m)
        local _,_,me=char()
        local currentD=currentPart and me and (currentPart.Position-me.Position).Magnitude or math.huge
        if latest and latest.m~=robot.m and latest.d+8<currentD then
            say(string.format("พบตัวใกล้กว่า d=%.0f → %.0f — เปลี่ยนเป้า",currentD,latest.d))
            return
        end
        local p=rootPart(robot.m); if not p or not robot.m.Parent then say("หุ่นหาย/แพ้แล้ว"); return end
        local _,h,r=char(); if not h or not r or (p.Position-r.Position).Magnitude>14 then break end
        local hp=select(1,hpOf(robot.m))
        if hp and hp<=0 then say("กำจัดแล้ว"); return end
        if hp and lastHP and hp<lastHP then say("HP "..lastHP.." → "..hp); lastHP=hp end
        pcall(function() tool:Activate() end)
        task.wait(.62)
    end
    say("เปลี่ยนเป้าถัดไป")
end
local function goDock(useClip)
    if not S.dock then say("ยังไม่มี DOCK — ยืนอู่เชียนแล้วกด DOCK"); return false end
    local usedClip=false
    if useClip then setClip(true); usedClip=true; say("CLIP ON — เดินไป DOCK") end
    local ok=walk(S.dock,12,90,55)
    if usedClip then setClip(false); say("CLIP OFF") end
    if ok then say("ถึง DOCK") else say("ไป DOCK ไม่ทัน/ไม่ถึง") end
    return ok
end
local function waitForLead()
    while S.run do
        local t=serverNow()
        local rem=secsToBoundary(t)
        if rem<=LEAD then
            say(string.format("ใกล้รอบ %s — เหลือ %ds ≤ LEAD %d — ไป DOCK",fmtHMS(t),rem,LEAD))
            return true
        end
        if rem%30==0 or rem==LEAD+1 then
            say(string.format("รอรอบ :00/:30 | server %s | อีก %ds (LEAD=%d)",fmtHMS(t),rem,LEAD))
        end
        task.wait(1)
    end
    return false
end
local function farmWindow()
    local deadline=os.clock()+FARM_WINDOW
    local _,_,r=char(); S.searchOrigin=(S.dock) or (r and r.Position) or nil; S.searchIndex=0
    say(string.format("FARM หน้าต่าง %ds",FARM_WINDOW))
    while S.run and os.clock()<deadline do
        local all=robots()
        if #all==0 then
            -- ใน SCHED ไม่สไปรอลไกล: สแกนรอบ dock สั้น ๆ
            if S.dock then
                local _,_,me=char()
                if me and (me.Position-S.dock).Magnitude>40 then walk(S.dock,12,40,55) end
            end
            task.wait(.8)
        else
            hit(all[1]); task.wait(.35)
        end
    end
    say("จบหน้าต่างฟาร์ม — รอครึ่งชั่วโมงถัดไป")
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentFarm";gui.ResetOnSpawn=false;gui.DisplayOrder=1022
pcall(function()gui.Parent=(gethui and gethui()) or game:GetService("CoreGui")end); if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui")end;S.gui=gui
local f=Instance.new("Frame",gui);f.Size=UDim2.new(0,460,0,248);f.Position=UDim2.new(0,12,.40,0);f.BackgroundColor3=Color3.fromRGB(18,43,46);f.BorderSizePixel=0;f.Active=true;f.Draggable=true;Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f);title.Size=UDim2.new(1,-80,0,28);title.Position=UDim2.new(0,10,0,2);title.BackgroundTransparency=1;title.Text="Egg01 Experiment Farm v1.5 — SCHED";title.TextColor3=Color3.fromRGB(145,245,230);title.Font=Enum.Font.GothamBold;title.TextSize=13;title.TextXAlignment=Enum.TextXAlignment.Left
local function button(text,x,y,color,w)
    local b=Instance.new("TextButton",f);b.Size=UDim2.new(0,w or 68,0,28);b.Position=UDim2.new(0,x,0,y);b.Text=text;b.TextColor3=Color3.new(1,1,1);b.BackgroundColor3=color;b.BorderSizePixel=0;b.Font=Enum.Font.GothamBold;b.TextSize=11;Instance.new("UICorner",b).CornerRadius=UDim.new(0,5);return b
end
local scanB=button("SCAN",10,34,Color3.fromRGB(45,105,165))
local start=button("AUTO",84,34,Color3.fromRGB(35,145,75))
local schedB=button("SCHED",158,34,Color3.fromRGB(35,120,160))
local dockB=button("DOCK",232,34,Color3.fromRGB(90,110,55))
local clipB=button("CLIP",306,34,Color3.fromRGB(120,90,40))
local stopB=button("STOP",380,34,Color3.fromRGB(165,50,55),52)
local copy=button("COPY",10,66,Color3.fromRGB(75,75,80),68)
local goDockB=button("→DOCK",84,66,Color3.fromRGB(70,100,130),68)
local fold=button("−",380,66,Color3.fromRGB(75,65,105),24)
local close=button("X",408,66,Color3.fromRGB(145,50,65),24)
logBox=Instance.new("TextLabel",f);logBox.Size=UDim2.new(1,-16,0,148);logBox.Position=UDim2.new(0,8,0,100);logBox.BackgroundColor3=Color3.new(0,0,0);logBox.BackgroundTransparency=.2;logBox.TextColor3=Color3.fromRGB(180,245,190);logBox.Font=Enum.Font.Code;logBox.TextSize=10;logBox.TextXAlignment=Enum.TextXAlignment.Left;logBox.TextYAlignment=Enum.TextYAlignment.Top;logBox.TextWrapped=true;logBox.ClipsDescendants=true
local row2={scanB,start,schedB,dockB,clipB,stopB,copy,goDockB,logBox}
local folded=false
fold.MouseButton1Click:Connect(function()
    folded=not folded;f.Size=UDim2.new(0,460,0,folded and 34 or 248)
    for _,x in ipairs(row2) do x.Visible=not folded end
    fold.Text=folded and "+" or "−"
end)
scanB.MouseButton1Click:Connect(scan)
dockB.MouseButton1Click:Connect(function()
    local _,_,r=char(); if not r then say("ไม่มีตัวละคร"); return end
    S.dock=r.Position
    say(string.format("DOCK ตั้งแล้ว %.1f,%.1f,%.1f",S.dock.X,S.dock.Y,S.dock.Z))
end)
clipB.MouseButton1Click:Connect(function()
    if S.clip then setClip(false); clipB.Text="CLIP"; say("CLIP OFF")
    else setClip(true); clipB.Text="CLIP✓"; say("CLIP ON — ทดสอบหนูขลิบ (กดอีกทีปิด)") end
end)
goDockB.MouseButton1Click:Connect(function()
    if S.run then return end
    if not S.dock then say("กด DOCK ที่อู่เชียนก่อน"); return end
    S.run=true; S.mode="testdock"
    task.spawn(function()
        say("ทดสอบ →DOCK"..(S.clip and " +CLIP" or ""))
        goDock(S.clip)
        S.run=false; S.mode=nil
    end)
end)
start.MouseButton1Click:Connect(function()
    if S.run then return end;S.run=true;S.mode="auto";start.Text="ON";say("AUTO ON — ไล่ตีใกล้สุด")
    local _,_,r=char();S.searchOrigin=r and r.Position or nil;S.searchIndex=0
    task.spawn(function()
        while S.run and S.mode=="auto" do
            local all=robots()
            if #all==0 then searchStep();task.wait(.4) else hit(all[1]);task.wait(.4) end
        end
        start.Text="AUTO"
    end)
end)
schedB.MouseButton1Click:Connect(function()
    if S.run then return end
    if not S.dock then say("ยังไม่ได้ตั้ง DOCK — ยืนอู่เชียนแล้วกด DOCK ก่อน SCHED"); return end
    S.run=true; S.mode="sched"; schedB.Text="ON"
    say(string.format("SCHED ON — LEAD=%ds FARM=%ds server=%s",LEAD,FARM_WINDOW,fmtHMS(serverNow())))
    task.spawn(function()
        while S.run and S.mode=="sched" do
            if not waitForLead() then break end
            goDock(false)
            if not S.run then break end
            farmWindow()
        end
        schedB.Text="SCHED"; S.mode=nil
    end)
end)
stopB.MouseButton1Click:Connect(function()
    S.run=false; S.mode=nil; setClip(false); clipB.Text="CLIP"; stop("STOP")
    start.Text="AUTO"; schedB.Text="SCHED"
end)
copy.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=S.dock and string.format("\nDOCK=%.1f,%.1f,%.1f",S.dock.X,S.dock.Y,S.dock.Z) or ""
    if c then pcall(c,"=== Egg01 Experiment Farm v1.5 ===\n"..table.concat(S.lines,"\n")..extra);copy.Text="OK";task.delay(1,function()if copy.Parent then copy.Text="COPY"end end)end
end)
close.MouseButton1Click:Connect(function()
    S.run=false; setClip(false); gui:Destroy(); _G.EGG01_EXPERIMENT_FARM=nil
end)
say("DOCK ที่อู่เชียน → SCHED รอ :00/:30 | CLIP/→DOCK ทดสอบหนูขลิบ | AUTO ไล่ตีทันที")
