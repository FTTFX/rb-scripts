-- Egg01 Experiment Farm v2.11 -- วิ่งตามขั้น: RIFT → วาฬ (Abyss) ไม่ใช้ L
if _G.EGG01_EXPERIMENT_FARM then
    _G.EGG01_EXPERIMENT_FARM.run=false
    pcall(function() _G.EGG01_EXPERIMENT_FARM.clipConn:Disconnect() end)
    pcall(function() _G.EGG01_EXPERIMENT_FARM.gui:Destroy() end)
end
local Players=game:GetService("Players")
local RunS=game:GetService("RunService")
local LP=Players.LocalPlayer
local LEAD=25 -- ออกใกล้ :00/:30 (เดิม 60 เร็วเกินไป)
local FARM_WINDOW=300
local FALLBACK=Vector3.new(2283.0,74.0,-312.0) -- Guard Abyss Ocean จาก ModelSpy
local FALLBACK_RIFT=Vector3.new(534.0,71.0,-340.0) -- RiftSpy MARK / RiftMachine
local S={run=false,gui=nil,lines={},point=nil,rift=nil,tread=nil,clipConn=nil,clipParts={}}; _G.EGG01_EXPERIMENT_FARM=S
local logBox
local function say(m)
    S.lines[#S.lines+1]=tostring(m); if #S.lines>12 then table.remove(S.lines,1) end
    if logBox then logBox.Text=table.concat(S.lines,"\n") end
    warn("[ExperimentFarm] "..tostring(m))
end
local function char()
    local c=LP.Character; return c,c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart")
end
local function serverNow()
    local ok,t=pcall(function() return workspace:GetServerTimeNow() end)
    return ok and t or os.time()
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
local function instPos(d)
    if not d then return nil end
    if d:IsA("BasePart") then return d.Position end
    if d:IsA("Model") then
        local ok,pv=pcall(function() return d:GetPivot().Position end)
        if ok and pv then return pv end
    end
    local p=d:FindFirstChildWhichIsA("BasePart",true)
    return p and p.Position
end
local function findAbyssFolder()
    local objs=workspace:FindFirstChild("__OBJECTS")
    local areas=objs and objs:FindFirstChild("Areas")
    local guards=areas and areas:FindFirstChild("GuardAreas")
    if not guards then return nil end
    local abyss=guards:FindFirstChild("Abyss Ocean") or guards:FindFirstChild("AbyssOcean")
    if abyss then return abyss end
    for _,ch in ipairs(guards:GetChildren()) do
        if ch.Name:lower():find("abyss",1,true) then return ch end
    end
end
local function findAbyss()
    -- จุดจริง = Guard / Nests ใน GuardAreas.Abyss Ocean (ไม่ใช่ pivot ชื่อโซนที่ 1371)
    local abyss=findAbyssFolder()
    if abyss then
        local guard=abyss:FindFirstChild("Guard")
        if guard then
            local gmodel=guard:FindFirstChild("Model") or guard
            local pos=instPos(gmodel) or instPos(guard)
            if pos then return pos,"Abyss Ocean.Guard" end
        end
        local nests=abyss:FindFirstChild("Nests")
        if nests then
            local sx,sy,sz,n=0,0,0,0
            for _,nest in ipairs(nests:GetChildren()) do
                local p=instPos(nest)
                if p then sx=sx+p.X; sy=sy+p.Y; sz=sz+p.Z; n=n+1 end
            end
            if n>0 then return Vector3.new(sx/n,sy/n,sz/n),"Abyss Ocean.Nests" end
        end
        local sign=abyss:FindFirstChild("RequiredSpeedSign")
        local sp=instPos(sign)
        if sp then return sp,"Abyss Ocean.Sign" end
    end
    return FALLBACK,"fallback-guard"
end
local function findRift()
    -- Spy: WS.__OBJECTS.Machines.RiftMachine.Rift @540,65,-333
    local objs=workspace:FindFirstChild("__OBJECTS")
    local machines=objs and objs:FindFirstChild("Machines")
    local rm=machines and machines:FindFirstChild("RiftMachine")
    if rm then
        local rift=rm:FindFirstChild("Rift")
        local p=instPos(rift) or instPos(rm)
        if p then return Vector3.new(p.X,math.max(p.Y,70),p.Z),"RiftMachine" end
    end
    local best,bestScore,bestSrc
    local function consider(inst,score,src)
        local p=instPos(inst)
        if not p then return end
        if not best or score>bestScore then best,bestScore,bestSrc=p,score,src end
    end
    for _,d in ipairs(workspace:GetDescendants()) do
        local n=d.Name:lower()
        if n=="riftmachine" then consider(d,90,"RiftMachine")
        elseif n=="rift" and not n:find("trade",1,true) then consider(d,70,"Rift")
        elseif n:find("rift",1,true) and not n:find("trade",1,true) and not n:find("gui",1,true)
            and not n:find("farm",1,true) and not n:find("input",1,true) then
            consider(d,20,"rift~")
        end
    end
    if best then return Vector3.new(best.X,math.max(best.Y,70),best.Z),bestSrc end
    return FALLBACK_RIFT,"fallback-rift"
end
local function resolvePoint()
    local pos,src=findAbyss()
    S.point=pos
    say(string.format("วาฬ=%s @%.0f,%.0f,%.0f",tostring(src),pos.X,pos.Y,pos.Z))
    return pos
end
local function resolveRift()
    local pos,src=findRift()
    S.rift=pos
    say(string.format("RIFT=%s @%.0f,%.0f,%.0f",tostring(src),pos.X,pos.Y,pos.Z))
    return pos
end
local function setClip(on)
    if not on then
        if S.clipConn then pcall(function() S.clipConn:Disconnect() end); S.clipConn=nil end
        for part,was in pairs(S.clipParts) do
            if part and part.Parent then pcall(function() part.CanCollide=was end) end
        end
        S.clipParts={}; return
    end
    if S.clipConn then return end
    local function apply(ch)
        if not ch then return end
        for _,p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then
                if S.clipParts[p]==nil then S.clipParts[p]=p.CanCollide end
                p.CanCollide=false
            end
        end
    end
    apply(LP.Character)
    S.clipConn=RunS.Stepped:Connect(function() apply(LP.Character) end)
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
            if band~=lastBand and band~="ปกติ" then say(band.." — เหลือ "..math.floor(d).." studs") end
            lastBand=band
        end
        h:MoveTo(g); task.wait(.04)
    end
    restore()
    return false
end
-- ขั้นที่ 1 ไป RIFT → ขั้นที่ 2 ไปวาฬ (เส้นทางตามจุด ไม่ใช่เส้นตรงทะลุกำแพง)
local function goPoint()
    local rift=resolveRift()
    local whale=resolvePoint()
    local _,_,r=char(); if not r then return false end
    local d1=(rift-r.Position).Magnitude
    local lim1=math.clamp(d1/18+30,40,200)
    say(string.format("ขั้น1 → RIFT @%.0f,%.0f,%.0f",rift.X,rift.Y,rift.Z))
    local ok1=walk(rift,28,lim1,55)
    if not S.run then return false end
    say(ok1 and "ถึง RIFT แล้ว → ไปวาฬ" or "ใกล้ RIFT ไม่สุด — ไปวาฬต่อ")
    local _,_,r2=char(); r2=r2 or r
    local d2=(whale-r2.Position).Magnitude
    local lim2=math.clamp(d2/18+30,40,200)
    say(string.format("ขั้น2 → วาฬ @%.0f,%.0f,%.0f",whale.X,whale.Y,whale.Z))
    local ok2=walk(whale,20,lim2,55)
    say(ok2 and "ถึงจุดวาฬแล้ว" or "ไปวาฬไม่ทัน")
    return ok2
end
local function nearestTreadmill()
    local _,_,r=char(); if not r then return nil end
    local best,bestD
    for _,item in ipairs(workspace:GetDescendants()) do
        if item:IsA("BasePart") and item.Name=="TreadmillBottom" then
            local d=(item.Position-r.Position).Magnitude
            if not bestD or d<bestD then best,bestD=item,d end
        end
    end
    return best,bestD
end
local function treadStandPos(bottom)
    if not bottom then return nil end
    return bottom.CFrame:PointToWorldSpace(Vector3.new(0,bottom.Size.Y*0.5+2.5,0))
end
local function leaveTreadmill()
    local bottom,d=nearestTreadmill()
    if not bottom or not d or d>14 then
        say("ไม่ได้อยู่บนเครื่องวิ่ง — ไปอีเวนต์เลย")
        return
    end
    S.tread=bottom
    if _G.EGG01_TREADMILL then _G.EGG01_TREADMILL.run=false end
    local _,h,r=char()
    say(string.format("กระโดดออกจากเครื่องวิ่ง d=%.0f",d))
    if h then
        h.Jump=true
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
    task.wait(0.25)
    if h and r then
        local dir=Vector3.new(r.Position.X-bottom.Position.X,0,r.Position.Z-bottom.Position.Z)
        if dir.Magnitude<1 then dir=r.CFrame.RightVector else dir=dir.Unit end
        local goal=r.Position+dir*16
        walk(goal,3,6,nil)
    end
    stop()
end
local function returnTreadmill()
    local bottom=S.tread
    if not bottom or not bottom.Parent then bottom=select(1,nearestTreadmill()) end
    if not bottom then say("ไม่พบเครื่องวิ่งเดิม"); return end
    S.tread=bottom
    local target=treadStandPos(bottom)
    if not target then return end
    local _,_,r=char()
    local lim=r and math.clamp((target-r.Position).Magnitude/18+25,45,200) or 90
    say("กลับเครื่องวิ่งเดิม")
    walk(target,5,lim,55)
    say("อยู่เครื่องวิ่งแล้ว — รอรอบถัดไป")
end
local function jogTreadTick(n)
    local bottom=S.tread
    if not bottom or not bottom.Parent then return n end
    local _,h,r=char(); if not h or not r then return n end
    local offset=Vector3.new(math.sin(n)*1.2,bottom.Size.Y*0.5+2.5,math.cos(n)*1.2)
    local step=bottom.CFrame:PointToWorldSpace(offset)
    h:MoveTo(Vector3.new(step.X,r.Position.Y,step.Z))
    return n+math.pi*0.5
end
local function rootPart(m)
    if not m then return end
    if m:IsA("BasePart") then return m end
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart",true) or m:FindFirstChildWhichIsA("BasePart",true)
end
local function underClientEggs(m)
    local p=m
    while p and p~=workspace do
        local n=p.Name:lower()
        if n:find("clientrendered",1,true) or n=="eggs" or n:find("fieldegg",1,true) then return true end
        p=p.Parent
    end
    return false
end
local function isExperiment(m)
    if not m or underClientEggs(m) then return false end
    if m:IsDescendantOf(LP.Character or Instance.new("Folder")) then return false end
    local name=m.Name:lower()
    -- ห้าม: DrScrambleEvent = มาร์กเกอร์อีเวนต์ ไม่ใช่หุ่นตีได้
    if name:find("event",1,true) and not name:find("dronevisual",1,true) then return false end
    if name:find("dronevisual",1,true) then return true end
    return false
end
local function hpOf(m)
    for _,x in ipairs(m:GetDescendants()) do
        if x:IsA("TextLabel") or x:IsA("TextButton") then
            local a,b=tostring(x.Text):match("(%d+)%s*/%s*(%d+)")
            if a and b then return tonumber(a),tonumber(b),x.Text end
        end
    end
end
local function robots()
    local _,_,r=char(); if not r then return {} end
    local out,seen={},{}
    for _,x in ipairs(workspace:GetDescendants()) do
        if x:IsA("Model") and not seen[x] and isExperiment(x) then
            seen[x]=true
            local p=rootPart(x)
            if p then
                local hp,_,label=hpOf(x)
                -- ต้องมี HP จริง (ตัด prop/มาร์กเกอร์)
                if hp and hp>0 then
                    local center=x:GetPivot().Position
                    out[#out+1]={m=x,p=p,pos=center,hp=hp,label=label,d=(center-r.Position).Magnitude}
                end
            end
        end
    end
    table.sort(out,function(a,b) return a.d<b.d end)
    return out
end
local function bat()
    local c,h=char(); if not c or not h then return end
    local t=c:FindFirstChildOfClass("Tool")
    if not t then t=LP.Backpack:FindFirstChildWhichIsA("Tool"); if t then pcall(function() h:EquipTool(t) end); task.wait(.15) end end
    return t
end
local function hit(robot)
    local _,_,me=char()
    local d=me and (robot.pos-me.Position).Magnitude or 99
    if not walk(robot.pos,10,d>28 and 80 or 50,55) then return end
    local tool=bat(); if not tool then say("ไม่มีไม้"); return end
    say("ตี "..robot.m.Name.." | "..(robot.label or "?"))
    local began=os.clock(); local lastHP=robot.hp
    while S.run and os.clock()-began<10 do
        local latest=robots()[1]
        local currentPart=rootPart(robot.m)
        local _,_,me2=char()
        local currentD=currentPart and me2 and (currentPart.Position-me2.Position).Magnitude or math.huge
        if latest and latest.m~=robot.m and latest.d+8<currentD then return end
        local p=rootPart(robot.m); if not p or not robot.m.Parent then say("กำจัดแล้ว"); return end
        local _,h,r=char(); if not h or not r or (p.Position-r.Position).Magnitude>14 then break end
        local hp=select(1,hpOf(robot.m))
        if hp and hp<=0 then say("กำจัดแล้ว"); return end
        if hp and lastHP and hp<lastHP then say("HP "..lastHP.." → "..hp); lastHP=hp end
        pcall(function() tool:Activate() end)
        task.wait(.62)
    end
end
local function secsIntoHalf(t)
    return math.floor(t)%1800
end
local function waitEvent()
    local n=0
    do
        local b,d=nearestTreadmill()
        if b and d and d<=14 then S.tread=b end
    end
    -- นอกอีเวนต์และยังไม่บนเครื่องวิ่ง → ไปยืนรอ
    do
        local t=serverNow()
        local into=secsIntoHalf(t)
        local rem=1800-into; if rem==1800 then rem=0; into=0 end
        if into>=FARM_WINDOW and rem>LEAD then
            local b,d=nearestTreadmill()
            if not (b and d and d<=14) then
                say("นอกอีเวนต์ — ไปเครื่องวิ่งรอ")
                returnTreadmill()
            elseif b then
                S.tread=b
            end
        end
    end
    while S.run do
        local t=serverNow()
        local into=secsIntoHalf(t)
        local rem=1800-into
        if rem==1800 then rem=0; into=0 end
        if into<FARM_WINDOW then
            say(string.format("อีเวนต์กำลังเปิด %s — เข้าไปแล้ว %ds / เหลือ ~%ds",fmtHMS(t),into,FARM_WINDOW-into))
            return true
        end
        if rem<=LEAD then
            say(string.format("ใกล้รอบ %s — อีก %ds → ออกเครื่องวิ่ง",fmtHMS(t),rem))
            return true
        end
        if S.tread and S.tread.Parent then
            n=jogTreadTick(n)
            if rem%60==0 then say(string.format("รอบนเครื่องวิ่ง | %s | อีก %ds",fmtHMS(t),rem)) end
            task.wait(0.18)
        else
            local b,d=nearestTreadmill()
            if b and (not d or d>14) then
                say("หลุดเครื่องวิ่ง — วิ่งกลับไปรอ")
                returnTreadmill()
            elseif b and d and d<=14 then
                S.tread=b
            end
            if rem%60==0 then say(string.format("รอ :00/:30 | %s | อีก %ds",fmtHMS(t),rem)) end
            task.wait(1)
        end
    end
    return false
end
local function farm5min()
    local t=serverNow()
    local into=secsIntoHalf(t)
    local left=FARM_WINDOW
    if into<FARM_WINDOW then left=math.max(45,FARM_WINDOW-into) end
    local deadline=os.clock()+left
    local hub=S.point or FALLBACK
    say(string.format("SCAN/ตี — เหลือหน้าต่าง %ds",left))
    while S.run and os.clock()<deadline do
        local all=robots()
        if #all==0 then
            local _,_,me=char()
            if me and (me.Position-hub).Magnitude>40 then walk(hub,20,45,55) end
            task.wait(.6)
        else
            say(string.format("พบ %d ตัว — ตีใกล้สุด d=%.0f",#all,all[1].d))
            hit(all[1]); task.wait(.3)
        end
    end
    say("จบอีเวนต์ — กลับเครื่องวิ่ง")
end
local function loop()
    while S.run do
        if not waitEvent() then break end
        leaveTreadmill()
        if not S.run then break end
        goPoint()
        if not S.run then break end
        farm5min()
        if not S.run then break end
        returnTreadmill()
    end
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentFarm"; gui.ResetOnSpawn=false; gui.DisplayOrder=1022
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,300,0,200); f.Position=UDim2.new(0,12,.45,0)
f.BackgroundColor3=Color3.fromRGB(18,43,46); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-40,0,26); title.Position=UDim2.new(0,10,0,2)
title.BackgroundTransparency=1; title.Text="Egg01 Experiment v2.11 — RIFT→วาฬ"; title.TextColor3=Color3.fromRGB(145,245,230)
title.Font=Enum.Font.GothamBold; title.TextSize=12; title.TextXAlignment=Enum.TextXAlignment.Left
local function button(text,x,color,w)
    local b=Instance.new("TextButton",f); b.Size=UDim2.new(0,w or 72,0,28); b.Position=UDim2.new(0,x,0,32)
    b.Text=text; b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=color; b.BorderSizePixel=0
    b.Font=Enum.Font.GothamBold; b.TextSize=11; Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
end
local startB=button("AUTO",10,Color3.fromRGB(35,145,75))
local stopB=button("STOP",88,Color3.fromRGB(165,50,55))
local copyB=button("COPY",166,Color3.fromRGB(75,75,80),52)
local closeB=button("X",244,Color3.fromRGB(145,50,65),28)
logBox=Instance.new("TextLabel",f); logBox.Size=UDim2.new(1,-16,0,128); logBox.Position=UDim2.new(0,8,0,66)
logBox.BackgroundColor3=Color3.new(0,0,0); logBox.BackgroundTransparency=.2; logBox.TextColor3=Color3.fromRGB(180,245,190)
logBox.Font=Enum.Font.Code; logBox.TextSize=10; logBox.TextXAlignment=Enum.TextXAlignment.Left
logBox.TextYAlignment=Enum.TextYAlignment.Top; logBox.TextWrapped=true; logBox.ClipsDescendants=true
local function beginAuto()
    if S.run then return end
    S.run=true; startB.Text="ON"
    resolveRift()
    resolvePoint()
    local b,d=nearestTreadmill()
    if b and d and d<=14 then S.tread=b; say(string.format("จำเครื่องวิ่ง d=%.0f",d)) end
    say("AUTO ON — ขั้นอีเวนต์: RIFT → วาฬ | นอก=เครื่องวิ่งรอ")
    task.spawn(function()
        loop()
        if S.gui and S.gui.Parent then startB.Text="AUTO" end
    end)
end
local function boot()
    setClip(true)
    local c=LP.Character or LP.CharacterAdded:Wait()
    if c then c:WaitForChild("HumanoidRootPart",8) end
    task.wait(0.4)
    if S.gui and S.gui.Parent then beginAuto() end
end
startB.MouseButton1Click:Connect(beginAuto)
stopB.MouseButton1Click:Connect(function()
    S.run=false; stop("STOP"); startB.Text="AUTO"
end)
copyB.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=S.point and string.format("\nPOINT=%.1f,%.1f,%.1f",S.point.X,S.point.Y,S.point.Z) or ""
    if c then pcall(c,"=== Egg01 Experiment Farm v2.11 ===\n"..table.concat(S.lines,"\n")..extra)
        copyB.Text="OK"; task.delay(1,function() if copyB.Parent then copyB.Text="COPY" end end) end
end)
closeB.MouseButton1Click:Connect(function()
    S.run=false; setClip(false); gui:Destroy(); _G.EGG01_EXPERIMENT_FARM=nil
end)
LP.CharacterAdded:Connect(function()
    if not S.gui or not S.gui.Parent then return end
    task.wait(0.6)
    setClip(true)
    if not S.run then beginAuto() end
end)
say("เปิดสคริปต์ = AUTO | ขั้น1 RIFT → ขั้น2 วาฬ")
task.spawn(boot)
