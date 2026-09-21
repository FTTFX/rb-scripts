-- Egg01 Experiment Farm v2.19 — เครื่องวิ่งหาได้ + ปุ่ม PATH ทดสอบ Rift→วาฬ
if _G.EGG01_EXPERIMENT_FARM then
    _G.EGG01_EXPERIMENT_FARM.run=false
    _G.EGG01_EXPERIMENT_FARM.test=false
    pcall(function() _G.EGG01_EXPERIMENT_FARM.clipConn:Disconnect() end)
    pcall(function() _G.EGG01_EXPERIMENT_FARM.gui:Destroy() end)
end
local Players=game:GetService("Players")
local RunS=game:GetService("RunService")
local LP=Players.LocalPlayer
local LEAD=25
local FARM_WINDOW=300
local HUNT_RAD=220
local AWAY_REPATH=380
local NEAR_WHALE=260
local FALLBACK=Vector3.new(2283.0,74.0,-312.0)
local FALLBACK_RIFT=Vector3.new(534.0,71.0,-340.0)
local S={
    run=false,test=false,gui=nil,lines={},point=nil,rift=nil,tread=nil,
    clipConn=nil,clipParts={},repath=false,inFarm=false,onTread=false,
    treadList=nil,treadAt=0,
}
_G.EGG01_EXPERIMENT_FARM=S
local logBox
local function say(m)
    S.lines[#S.lines+1]=tostring(m); if #S.lines>14 then table.remove(S.lines,1) end
    if logBox then logBox.Text=table.concat(S.lines,"\n") end
    warn("[ExperimentFarm] "..tostring(m))
end
local function active()
    return S.run or S.test
end
local function char()
    local c=LP.Character
    return c,c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart")
end
local function serverNow()
    local ok,t=pcall(function() return workspace:GetServerTimeNow() end)
    return ok and t or os.time()
end
local function fmtHMS(t)
    t=math.floor(t%86400)
    return string.format("%02d:%02d:%02d",math.floor(t/3600),math.floor(t/60)%60,t%60)
end
local function secsIntoHalf(t)
    return math.floor(t)%1800
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
    end
    return FALLBACK,"fallback-guard"
end
-- ห้าม GetDescendants ทั้งแมพตอนหา Rift (ค้าง) — path + FALLBACK เท่านั้น
local function findRift()
    local objs=workspace:FindFirstChild("__OBJECTS")
    local machines=objs and objs:FindFirstChild("Machines")
    local rm=machines and machines:FindFirstChild("RiftMachine")
    if rm then
        local rift=rm:FindFirstChild("Rift")
        local p=instPos(rift) or instPos(rm)
        if p then return Vector3.new(p.X,math.max(p.Y,70),p.Z),"RiftMachine" end
    end
    if S.rift then return S.rift,"cache-rift" end
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
local function stopTreadScripts()
    S.onTread=false
    if _G.EGG01_TREADMILL then _G.EGG01_TREADMILL.run=false end
end
-- แคชรายการเครื่องวิ่ง (สแกนทั้งแมพได้ แต่ไม่บ่อยกว่าทุก 20 วิ)
local function refreshTreadList(force)
    if not force and S.treadList and (os.clock()-S.treadAt)<20 then return S.treadList end
    local list={}
    local ok,desc=pcall(function() return workspace:GetDescendants() end)
    if ok and desc then
        for _,item in ipairs(desc) do
            if item:IsA("BasePart") and item.Name=="TreadmillBottom" then
                list[#list+1]=item
            end
        end
    end
    S.treadList=list; S.treadAt=os.clock()
    return list
end
local function nearestTreadmill()
    local _,_,r=char(); if not r then return nil end
    local best,bestD
    for _,item in ipairs(refreshTreadList(false)) do
        if item and item.Parent then
            local d=(item.Position-r.Position).Magnitude
            if not bestD or d<bestD then best,bestD=item,d end
        end
    end
    if not best then
        for _,item in ipairs(refreshTreadList(true)) do
            if item and item.Parent then
                local d=(item.Position-r.Position).Magnitude
                if not bestD or d<bestD then best,bestD=item,d end
            end
        end
    end
    return best,bestD
end
local function treadStandPos(bottom)
    if not bottom then return nil end
    return bottom.CFrame:PointToWorldSpace(Vector3.new(0,bottom.Size.Y*0.5+2.5,0))
end
-- เดินสั้น (ใกล้เป้า)
local function walk(p,rad,lim,slowNear)
    local t=os.clock(); local moveHum,oldSpeed,lastBand
    local function restore()
        if moveHum and moveHum.Parent then moveHum.WalkSpeed=oldSpeed end
    end
    while active() and os.clock()-t<lim do
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
-- เดินไกล/น้ำ (แบบ 1.12 + CFrame)
local function walkOpen(p,rad,lim,slowNear)
    local t=os.clock(); local moveHum,oldSpeed,lastBand
    local lastPos,lastProg=nil,os.clock()
    local lastDistLog=0
    local function restore()
        if moveHum and moveHum.Parent then moveHum.WalkSpeed=oldSpeed end
    end
    while active() and os.clock()-t<lim do
        local _,h,r=char(); if not h or not r or h.Health<=0 then restore(); return false end
        local flat=Vector3.new(p.X,r.Position.Y,p.Z)
        local d=(flat-r.Position).Magnitude
        if d<=rad then restore(); stop(); return true end
        if d>250 and (lastDistLog==0 or lastDistLog-d>=300) then
            say(string.format("เดินทางเหลือ %.0f",d)); lastDistLog=d
        end
        if slowNear then
            if not moveHum then moveHum=h; oldSpeed=h.WalkSpeed end
            local band,cap
            if d<=18 then band,cap="ละเอียด",35 elseif d<=slowNear then band,cap="ชะลอ",90 else band,cap="ปกติ",oldSpeed end
            h.WalkSpeed=math.min(oldSpeed,cap)
            if band~=lastBand and band~="ปกติ" then say(band.." — เหลือ "..math.floor(d).." studs") end
            lastBand=band
        end
        local dir=Vector3.new(p.X-r.Position.X,0,p.Z-r.Position.Z)
        if dir.Magnitude<0.1 then dir=r.CFrame.LookVector else dir=dir.Unit end
        local swimming=false
        pcall(function()
            local st=h:GetState()
            swimming=st==Enum.HumanoidStateType.Swimming or st==Enum.HumanoidStateType.Freefall
        end)
        if swimming or d>80 then
            local step=math.min(55,math.max(10,d-rad))
            r.CFrame=CFrame.new(r.Position+dir*step+Vector3.new(0,swimming and 6 or 2,0))
            r.AssemblyLinearVelocity=Vector3.zero
        else
            h:MoveTo(flat)
        end
        if lastPos then
            local moved=(r.Position-lastPos).Magnitude
            if moved<2 and (os.clock()-lastProg)>=0.8 then
                r.CFrame=CFrame.new(r.Position+dir*20+Vector3.new(0,12,0))
                lastPos=r.Position; lastProg=os.clock()
            elseif moved>=2 then
                lastPos=r.Position; lastProg=os.clock()
            end
        else
            lastPos=r.Position; lastProg=os.clock()
        end
        task.wait(.05)
    end
    restore()
    return false
end
-- force=true = ปุ่ม PATH บังคับ Rift→วาฬ แม้ใกล้วาฬ
local function goPoint(force)
    stopTreadScripts()
    say(force and "TEST path Rift→วาฬ" or "เริ่ม path Rift→วาฬ")
    local rift=resolveRift()
    local whale=resolvePoint()
    local _,_,r=char()
    if not r then
        say("รอ HRP..."); task.wait(1.2)
        _,_,r=char()
        if not r then say("ไม่มีตัว — ข้าม path"); return false end
    end
    if not force then
        local dWhale=(Vector3.new(whale.X,r.Position.Y,whale.Z)-r.Position).Magnitude
        if dWhale<=NEAR_WHALE then
            say(string.format("อยู่โซนวาฬ d=%.0f — เข้าฟาร์มเลย",dWhale))
            return true
        end
    end
    local d1=(Vector3.new(rift.X,r.Position.Y,rift.Z)-r.Position).Magnitude
    say(string.format("ขั้น1 → Rift @%.0f,%.0f,%.0f d=%.0f",rift.X,rift.Y,rift.Z,d1))
    local ok1=walkOpen(rift,22,math.clamp(d1/12+40,40,300),55)
    if not active() then return false end
    say(ok1 and "ถึง Rift → ไปวาฬ" or "Rift ไม่สุด → ไปวาฬต่อ")
    local _,_,r2=char(); r2=r2 or r
    local d2=(Vector3.new(whale.X,r2.Position.Y,whale.Z)-r2.Position).Magnitude
    say(string.format("ขั้น2 → วาฬ @%.0f,%.0f,%.0f d=%.0f",whale.X,whale.Y,whale.Z,d2))
    local ok2=walkOpen(whale,20,math.clamp(d2/10+50,60,420),55)
    say(ok2 and "ถึงวาฬแล้ว ✓" or "วาฬไม่ทัน")
    return ok2
end
local function leaveTreadmill()
    local bottom,d=nearestTreadmill()
    stopTreadScripts()
    if not bottom or not d or d>14 then
        say("ไม่ได้อยู่บนเครื่องวิ่ง — ไปอีเวนต์เลย")
        return
    end
    S.tread=bottom
    local _,h,r=char()
    say(string.format("กระโดดออกจากเครื่องวิ่ง d=%.0f",d))
    if h then
        h.Jump=true
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
    task.wait(0.3)
    if h and r then
        local dir=Vector3.new(r.Position.X-bottom.Position.X,0,r.Position.Z-bottom.Position.Z)
        if dir.Magnitude<1 then dir=r.CFrame.RightVector else dir=dir.Unit end
        walk(r.Position+dir*45,4,10,nil)
        local _,_,r2=char()
        if r2 and bottom.Parent and (r2.Position-bottom.Position).Magnitude<20 then
            r2.CFrame=CFrame.new(bottom.Position+dir*50+Vector3.new(0,6,0))
            say("ดันพ้นแผ่นเครื่องวิ่ง")
        end
    end
    stop()
    say("ออกเครื่องวิ่งแล้ว")
end
local function returnTreadmill()
    local bottom=S.tread
    if not bottom or not bottom.Parent then
        bottom=select(1,nearestTreadmill())
    end
    if not bottom then
        say("ไม่พบ TreadmillBottom — ลองสแกนใหม่")
        refreshTreadList(true)
        bottom=select(1,nearestTreadmill())
    end
    if not bottom then say("ไม่พบเครื่องวิ่งในแมพ"); return false end
    S.tread=bottom
    local target=treadStandPos(bottom)
    if not target then return false end
    local _,_,r=char()
    local d=r and (target-r.Position).Magnitude or 999
    local lim=math.clamp(d/12+40,45,300)
    say(string.format("ไปเครื่องวิ่ง d=%.0f @%.0f,%.0f,%.0f",d,target.X,target.Y,target.Z))
    local ok=walkOpen(target,5,lim,55)
    if ok then
        S.onTread=true
        say("อยู่เครื่องวิ่งแล้ว — รอรอบถัดไป")
    else
        say("ไปเครื่องวิ่งไม่สุด")
    end
    return ok
end
local function jogTreadTick(n)
    if not S.onTread then return n end
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
    if name:find("event",1,true) and not name:find("dronevisual",1,true) then return false end
    return name:find("dronevisual",1,true)~=nil
end
local function hpOf(m)
    for _,x in ipairs(m:GetDescendants()) do
        if x:IsA("TextLabel") or x:IsA("TextButton") then
            local a,b=tostring(x.Text):match("(%d+)%s*/%s*(%d+)")
            if a and b then return tonumber(a),tonumber(b),x.Text end
        end
    end
end
local function robots(hub,maxD)
    local _,_,r=char(); if not r then return {} end
    hub=hub or S.point or FALLBACK
    maxD=maxD or HUNT_RAD
    local out,seen={},{}
    local function consider(x)
        if not x or seen[x] or not x:IsA("Model") or not isExperiment(x) then return end
        seen[x]=true
        local p=rootPart(x); if not p then return end
        local hp,_,label=hpOf(x)
        if not hp or hp<=0 then return end
        local center=x:GetPivot().Position
        if (center-hub).Magnitude<=maxD then
            out[#out+1]={m=x,p=p,pos=center,hp=hp,label=label,d=(center-r.Position).Magnitude}
        end
    end
    local abyss=findAbyssFolder()
    if abyss then
        for _,x in ipairs(abyss:GetDescendants()) do consider(x) end
    end
    pcall(function()
        for _,x in ipairs(workspace:GetPartBoundsInRadius(hub,maxD)) do
            local m=x:FindFirstAncestorOfClass("Model")
            if m then consider(m) end
        end
    end)
    table.sort(out,function(a,b) return a.d<b.d end)
    return out
end
local function bat()
    local c,h=char(); if not c or not h then return end
    local t=c:FindFirstChildOfClass("Tool")
    if not t then
        t=LP.Backpack:FindFirstChildWhichIsA("Tool")
        if t then pcall(function() h:EquipTool(t) end); task.wait(.15) end
    end
    return t
end
local function hit(robot)
    local _,_,me=char()
    local d=me and (robot.pos-me.Position).Magnitude or 99
    if d>HUNT_RAD then return end
    if not walk(robot.pos,10,d>28 and 80 or 50,55) then return end
    local tool=bat(); if not tool then say("ไม่มีไม้"); return end
    say("ตี "..robot.m.Name.." | "..(robot.label or "?"))
    local began=os.clock(); local lastHP=robot.hp
    local hub=S.point or FALLBACK
    while S.run and os.clock()-began<10 do
        local latest=robots(hub,HUNT_RAD)[1]
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
local function waitEvent()
    local n=0
    do
        local b,d=nearestTreadmill()
        if b then
            S.tread=b
            if d and d<=14 then S.onTread=true end
            say(string.format("พบเครื่องวิ่ง %d ตัว | ใกล้สุด d=%.0f",#(S.treadList or {}),d or -1))
        else
            say("เตือน: ยังไม่พบ TreadmillBottom")
        end
    end
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
                S.tread=b; S.onTread=true
                say("อยู่บนเครื่องวิ่งแล้ว — รอ")
            end
        end
    end
    local lastWaitSay=0
    while S.run do
        local t=serverNow()
        local into=secsIntoHalf(t)
        local rem=1800-into
        if rem==1800 then rem=0; into=0 end
        if into<FARM_WINDOW then
            say(string.format("อีเวนต์เปิด %s — เข้าแล้ว %ds / เหลือ ~%ds",fmtHMS(t),into,FARM_WINDOW-into))
            return true
        end
        if rem<=LEAD then
            say(string.format("ใกล้รอบ %s — อีก %ds → ออกเครื่องวิ่ง",fmtHMS(t),rem))
            return true
        end
        if S.tread and S.tread.Parent and S.onTread then
            n=jogTreadTick(n)
            if rem<=60 and (os.clock()-lastWaitSay)>8 then
                say(string.format("รอบนเครื่องวิ่ง | %s | อีก %ds",fmtHMS(t),rem)); lastWaitSay=os.clock()
            end
            task.wait(0.18)
        else
            local b,d=nearestTreadmill()
            if b and (not d or d>14) then
                say("หลุดเครื่องวิ่ง — กลับไปรอ")
                returnTreadmill()
            elseif b and d and d<=14 then
                S.tread=b; S.onTread=true
            elseif not b then
                if (os.clock()-lastWaitSay)>12 then
                    say("รออีเวนต์ — ยังไม่เจอเครื่องวิ่ง"); lastWaitSay=os.clock()
                end
            end
            if rem<=60 and (os.clock()-lastWaitSay)>8 then
                say(string.format("รอ :00/:30 | %s | อีก %ds",fmtHMS(t),rem)); lastWaitSay=os.clock()
            end
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
    S.inFarm=true
    say(string.format("SCAN/ตีรัศมี %d รอบวาฬ — เหลือ %ds",HUNT_RAD,left))
    while S.run and os.clock()<deadline do
        if S.repath then
            S.repath=false
            say("เกิดใหม่ — Rift→วาฬ อีกครั้ง")
            goPoint(false)
            hub=S.point or FALLBACK
            if not S.run then break end
        end
        local _,_,me=char()
        if me and (me.Position-hub).Magnitude>AWAY_REPATH then
            say(string.format("ห่างวาฬ %.0f — บังคับ Rift→วาฬ", (me.Position-hub).Magnitude))
            goPoint(false)
            hub=S.point or FALLBACK
            if not S.run then break end
        end
        local all=robots(hub,HUNT_RAD)
        if #all==0 then
            if me and (me.Position-hub).Magnitude>40 then
                say("ไม่มีโดรนในโซน — กลับจุดวาฬ")
                walk(hub,20,45,55)
            end
            task.wait(.6)
        else
            say(string.format("พบ %d ตัวในโซน — ตี d=%.0f",#all,all[1].d))
            hit(all[1]); task.wait(.3)
        end
    end
    S.inFarm=false
    say("จบอีเวนต์ — กลับเครื่องวิ่ง")
end
local function loop()
    while S.run do
        if not waitEvent() then break end
        leaveTreadmill()
        if not S.run then break end
        S.repath=false
        local ok=goPoint(false)
        say(ok and "path เสร็จ → ฟาร์ม" or "path ไม่สุด → ฟาร์มต่อ")
        if not S.run then break end
        if S.repath then
            S.repath=false
            say("เกิดใหม่ตอนเดินทาง — path ซ้ำ")
            goPoint(false)
            if not S.run then break end
        end
        farm5min()
        if not S.run then break end
        returnTreadmill()
    end
end

local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentFarm"; gui.ResetOnSpawn=false; gui.DisplayOrder=1022
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,340,0,230); f.Position=UDim2.new(0,12,.42,0)
f.BackgroundColor3=Color3.fromRGB(18,43,46); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-40,0,26); title.Position=UDim2.new(0,10,0,2)
title.BackgroundTransparency=1; title.Text="Egg01 Experiment v2.19 — Rift→วาฬ"; title.TextColor3=Color3.fromRGB(145,245,230)
title.Font=Enum.Font.GothamBold; title.TextSize=12; title.TextXAlignment=Enum.TextXAlignment.Left
local function button(text,x,y,color,w)
    local b=Instance.new("TextButton",f); b.Size=UDim2.new(0,w or 62,0,26); b.Position=UDim2.new(0,x,0,y)
    b.Text=text; b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=color; b.BorderSizePixel=0
    b.Font=Enum.Font.GothamBold; b.TextSize=11; Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
end
local startB=button("AUTO",10,32,Color3.fromRGB(35,145,75),58)
local stopB=button("STOP",72,32,Color3.fromRGB(165,50,55),58)
local pathB=button("PATH",134,32,Color3.fromRGB(70,110,180),58)
local treadB=button("TREAD",196,32,Color3.fromRGB(120,90,40),58)
local copyB=button("COPY",258,32,Color3.fromRGB(75,75,80),40)
local closeB=button("X",302,32,Color3.fromRGB(145,50,65),28)
logBox=Instance.new("TextLabel",f); logBox.Size=UDim2.new(1,-16,0,158); logBox.Position=UDim2.new(0,8,0,64)
logBox.BackgroundColor3=Color3.new(0,0,0); logBox.BackgroundTransparency=.2; logBox.TextColor3=Color3.fromRGB(180,245,190)
logBox.Font=Enum.Font.Code; logBox.TextSize=10; logBox.TextXAlignment=Enum.TextXAlignment.Left
logBox.TextYAlignment=Enum.TextYAlignment.Top; logBox.TextWrapped=true; logBox.ClipsDescendants=true

local function beginAuto()
    if S.run or S.test then say("หยุด TEST/AUTO ก่อน"); return end
    S.run=true; startB.Text="ON"
    setClip(true)
    resolveRift(); resolvePoint()
    refreshTreadList(true)
    local b,d=nearestTreadmill()
    if b then
        S.tread=b
        say(string.format("จำเครื่องวิ่ง d=%.0f (ทั้งหมด %d)",d or -1,#(S.treadList or {})))
    else
        say("เตือน: ไม่พบเครื่องวิ่งตอนเปิด")
    end
    say("AUTO ON — นอกอีเวนต์=เครื่องวิ่ง | อีเวนต์=Rift→วาฬ")
    task.spawn(function()
        local ok,err=pcall(loop)
        if not ok then say("ERROR loop: "..tostring(err)) end
        S.run=false
        if S.gui and S.gui.Parent then startB.Text="AUTO" end
    end)
end
local function runPathTest()
    if S.test then say("PATH กำลังทดสอบอยู่"); return end
    if S.run then S.run=false; stop("หยุด AUTO เพื่อ TEST"); task.wait(0.2) end
    S.test=true; pathB.Text="..."
    setClip(true)
    task.spawn(function()
        local ok,err=pcall(function()
            goPoint(true)
        end)
        if not ok then say("ERROR PATH: "..tostring(err)) end
        S.test=false
        if pathB and pathB.Parent then pathB.Text="PATH" end
    end)
end
local function runTreadTest()
    if S.test then say("BUSY"); return end
    if S.run then S.run=false; stop("หยุด AUTO เพื่อ TREAD"); task.wait(0.2) end
    S.test=true; treadB.Text="..."
    setClip(true)
    task.spawn(function()
        local ok,err=pcall(function()
            refreshTreadList(true)
            local b,d=nearestTreadmill()
            if not b then say("TREAD FAIL — ไม่พบ TreadmillBottom"); return end
            say(string.format("TREAD TEST เจอ d=%.0f n=%d",d or -1,#(S.treadList or {})))
            returnTreadmill()
        end)
        if not ok then say("ERROR TREAD: "..tostring(err)) end
        S.test=false
        if treadB and treadB.Parent then treadB.Text="TREAD" end
    end)
end

local function boot()
    setClip(true)
    local c=LP.Character or LP.CharacterAdded:Wait()
    if c then c:WaitForChild("HumanoidRootPart",8) end
    task.wait(0.4)
    refreshTreadList(true)
    say(string.format("พร้อม | เครื่องวิ่งในแคช=%d | กด PATH ทดสอบ Rift→วาฬ",#(S.treadList or {})))
    if S.gui and S.gui.Parent then beginAuto() end
end
startB.MouseButton1Click:Connect(beginAuto)
stopB.MouseButton1Click:Connect(function()
    S.run=false; S.test=false; stop("STOP"); startB.Text="AUTO"; pathB.Text="PATH"; treadB.Text="TREAD"
end)
pathB.MouseButton1Click:Connect(runPathTest)
treadB.MouseButton1Click:Connect(runTreadTest)
copyB.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=""
    if S.point then extra=extra..string.format("\nPOINT=%.1f,%.1f,%.1f",S.point.X,S.point.Y,S.point.Z) end
    if S.rift then extra=extra..string.format("\nRIFT=%.1f,%.1f,%.1f",S.rift.X,S.rift.Y,S.rift.Z) end
    if c then pcall(c,"=== Egg01 Experiment Farm v2.19 ===\n"..table.concat(S.lines,"\n")..extra)
        copyB.Text="OK"; task.delay(1,function() if copyB.Parent then copyB.Text="COPY" end end) end
end)
closeB.MouseButton1Click:Connect(function()
    S.run=false; S.test=false; setClip(false); gui:Destroy(); _G.EGG01_EXPERIMENT_FARM=nil
end)
LP.CharacterAdded:Connect(function(ch)
    if not S.gui or not S.gui.Parent then return end
    task.wait(0.5)
    pcall(function() ch:WaitForChild("HumanoidRootPart",8) end)
    setClip(true)
    if not S.run then return end
    S.repath=true
    say("เกิดใหม่ — มาร์ก repath Rift→วาฬ")
end)
say("v2.19 | AUTO=ฟาร์ม | PATH=ทดสอบ Rift→วาฬ | TREAD=ทดสอบเครื่องวิ่ง")
task.spawn(boot)
