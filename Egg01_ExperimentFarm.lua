-- Egg01 Experiment Farm v2.13 — เช็คเวลา 0–5/30–35 ตลอด | บนลู่วิ่ง/ไม่เจอหุ่น → กระโดด→Rift→วาฬ
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
local FARM_WINDOW=300 -- :00–:05 และ :30–:35 (วินาทีในครึ่งชั่วโมง)
local FALLBACK=Vector3.new(2283.0,74.0,-312.0)
local FALLBACK_RIFT=Vector3.new(534.0,71.0,-340.0)
local S={run=false,test=false,gui=nil,lines={},point=nil,rift=nil,tread=nil,clipConn=nil,clipParts={},repath=false}; _G.EGG01_EXPERIMENT_FARM=S
local logBox
local function say(m)
    S.lines[#S.lines+1]=tostring(m); if #S.lines>12 then table.remove(S.lines,1) end
    if logBox then logBox.Text=table.concat(S.lines,"\n") end
    warn("[ExperimentFarm] "..tostring(m))
end
local function busy() return S.run or S.test end
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
local function secsIntoHalf(t)
    return math.floor(t)%1800
end
-- หน้าต่างอีเวนต์: นาที 0–5 และ 30–35 ของทุกชั่วโมง
local function inFarmWindow(t)
    t=t or serverNow()
    return secsIntoHalf(t)<FARM_WINDOW
end
local function windowLeft(t)
    t=t or serverNow()
    local into=secsIntoHalf(t)
    if into>=FARM_WINDOW then return 0 end
    return FARM_WINDOW-into
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
local function findRift()
    -- path ตรงเท่านั้น (ไม่สแกนทั้งแมพ — เคยค้าง)
    local objs=workspace:FindFirstChild("__OBJECTS")
    local machines=objs and objs:FindFirstChild("Machines")
    local rm=machines and machines:FindFirstChild("RiftMachine")
    if rm then
        local rift=rm:FindFirstChild("Rift")
        local p=instPos(rift) or instPos(rm)
        if p then return Vector3.new(p.X,math.max(p.Y,70),p.Z),"RiftMachine" end
    end
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
    while busy() and os.clock()-t<lim do
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
-- เดินไกลแบบปกติ (MoveTo เท่านั้น — ไม่บิน/ไม่ดัน CFrame)
local function walkFar(p,rad,lim,slowNear)
    local t=os.clock(); local moveHum,oldSpeed,lastBand
    local lastLog=0
    local function restore()
        if moveHum and moveHum.Parent then moveHum.WalkSpeed=oldSpeed end
    end
    while busy() and os.clock()-t<lim do
        local _,h,r=char(); if not h or not r or h.Health<=0 then restore(); return false end
        local g=Vector3.new(p.X,r.Position.Y,p.Z)
        local d=(g-r.Position).Magnitude
        if d<=rad then restore(); stop(); return true end
        if d>200 and (lastLog==0 or lastLog-d>=300) then
            say(string.format("…เหลือ %.0f studs",d)); lastLog=d
        end
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
-- บังคับเสมอ: ขั้น1 → Rift แล้ว ขั้น2 → วาฬ / ถึงวาฬ (เดินปกติ)
local function goPoint()
    local rift=resolveRift()
    local whale=resolvePoint()
    local _,_,r=char(); if not r then say("ไม่มี HRP — ข้าม path"); return false end
    local d1=(Vector3.new(rift.X,r.Position.Y,rift.Z)-r.Position).Magnitude
    say(string.format("ขั้น1 → Rift @%.0f,%.0f,%.0f  d=%.0f",rift.X,rift.Y,rift.Z,d1))
    local ok1=walkFar(rift,22,math.clamp(d1/16+50,60,400),55)
    if not busy() then return false end
    say(ok1 and "ถึง Rift แล้ว → ขั้น2 วาฬ" or "Rift ไม่สุด → ไปวาฬต่อ")
    local _,_,r2=char(); r2=r2 or r
    local d2=(Vector3.new(whale.X,r2.Position.Y,whale.Z)-r2.Position).Magnitude
    say(string.format("ขั้น2 → วาฬ @%.0f,%.0f,%.0f  d=%.0f",whale.X,whale.Y,whale.Z,d2))
    local ok2=walkFar(whale,20,math.clamp(d2/14+80,90,500),55)
    if ok2 then
        say("ถึงวาฬแล้ว ✓ — เริ่มตี")
    else
        say("ยังไม่ถึงวาฬ — ฟาร์มต่อจากจุดนี้")
    end
    return ok2
end
local function nearestTreadmill()
    local _,_,r=char(); if not r then return nil end
    local best,bestD
    local ok,desc=pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return nil end
    for _,item in ipairs(desc) do
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
local function onTreadPad()
    local _,_,r=char(); if not r then return false end
    if S.tread and S.tread.Parent then
        local d=(S.tread.Position-r.Position).Magnitude
        if d<=14 then return true,S.tread,d end
    end
    local b,d=nearestTreadmill()
    if b and d and d<=14 then S.tread=b; return true,b,d end
    return false,b,d
end
local function leaveTreadmill()
    if _G.EGG01_TREADMILL then _G.EGG01_TREADMILL.run=false end
    local on,bottom,d=onTreadPad()
    if not on then
        bottom=S.tread
        if not bottom or not bottom.Parent then
            say("ไม่ได้อยู่บนเครื่องวิ่ง — ไป Rift→วาฬเลย")
            return false
        end
        local _,_,r=char()
        d=r and (bottom.Position-r.Position).Magnitude or 99
    end
    S.tread=bottom
    say(string.format("กระโดดออกจากเครื่องวิ่ง d=%.0f",d or -1))
    for _=1,3 do
        if not busy() then break end
        local _,h=char()
        if h then
            h.Jump=true
            pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
        task.wait(0.22)
    end
    local _,h,r=char()
    if h and r and bottom and bottom.Parent then
        local dir=Vector3.new(r.Position.X-bottom.Position.X,0,r.Position.Z-bottom.Position.Z)
        if dir.Magnitude<1 then dir=r.CFrame.RightVector else dir=dir.Unit end
        walk(r.Position+dir*22,3,8,nil)
    end
    stop()
    if onTreadPad() then
        say("ยังติดลู่วิ่ง — กระโดดซ้ำ+ถอย")
        local _,h2,r2=char()
        if h2 then h2.Jump=true; pcall(function() h2:ChangeState(Enum.HumanoidStateType.Jumping) end) end
        task.wait(0.25)
        if h2 and r2 and bottom and bottom.Parent then
            local dir=Vector3.new(r2.Position.X-bottom.Position.X,0,r2.Position.Z-bottom.Position.Z)
            if dir.Magnitude<1 then dir=r2.CFrame.LookVector else dir=dir.Unit end
            walk(r2.Position+dir*28,3,10,nil)
        end
        stop()
    end
    return not onTreadPad()
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
-- บังคับ path ที่ถูกตอนอีเวนต์: ออกลู่วิ่ง → Rift → วาฬ
local function forceEventPath(why)
    say(why or "บังคับ Rift → วาฬ")
    leaveTreadmill()
    if not busy() then return false end
    goPoint()
    S.lastForceAt=os.clock()
    return true
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
-- แบบ 2.12 ที่เคยตีได้: สแกน DroneVisual ทั้งแมพ + มี HP (ไม่กรองรัศมี hub แคบ)
local function robots()
    local _,_,r=char(); if not r then return {} end
    local out,seen={},{}
    local ok,desc=pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return {} end
    for _,x in ipairs(desc) do
        if x:IsA("Model") and not seen[x] and isExperiment(x) then
            seen[x]=true
            local p=rootPart(x)
            if p then
                local hp,_,label=hpOf(x)
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
    -- กันไล่ข้ามแมพ (ปัญหาหลัง 2.12) แต่ยังตีโดรนใกล้ๆ ที่เห็น
    if d>350 then say(string.format("ข้ามเป้าไกล d=%.0f",d)); return end
    if not walk(robot.pos,10,d>28 and 80 or 50,55) then return end
    local tool=bat(); if not tool then say("ไม่มีไม้"); return end
    say("ตี "..robot.m.Name.." | "..(robot.label or "?"))
    local began=os.clock(); local lastHP=robot.hp
    while busy() and os.clock()-began<10 do
        local latest=robots()[1]
        local currentPart=rootPart(robot.m)
        local _,_,me2=char()
        local currentD=currentPart and me2 and (currentPart.Position-me2.Position).Magnitude or math.huge
        if latest and latest.m~=robot.m and latest.d+8<currentD and latest.d<=350 then return end
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
        local on,b=onTreadPad()
        if on then S.tread=b end
    end
    do
        local t=serverNow()
        if not inFarmWindow(t) then
            local into=secsIntoHalf(t)
            local rem=1800-into; if rem==1800 then rem=0 end
            if rem>LEAD then
                if not onTreadPad() then
                    say("นอกอีเวนต์ — ไปเครื่องวิ่งรอ")
                    returnTreadmill()
                end
            end
        end
    end
    while S.run do
        local t=serverNow()
        local into=secsIntoHalf(t)
        local rem=1800-into
        if rem==1800 then rem=0; into=0 end
        -- หน้าต่าง 0–5 / 30–35 เปิดแล้ว → ออกไป Rift→วาฬ
        if inFarmWindow(t) then
            say(string.format("อีเวนต์เปิด %s — เข้าแล้ว %ds / เหลือ ~%ds → ออกลู่วิ่ง",fmtHMS(t),into,windowLeft(t)))
            return true
        end
        if rem<=LEAD then
            say(string.format("ใกล้รอบ %s — อีก %ds → ออกเครื่องวิ่ง",fmtHMS(t),rem))
            return true
        end
        if onTreadPad() then
            n=jogTreadTick(n)
            if rem%60==0 then say(string.format("รอบนเครื่องวิ่ง | %s | อีก %ds",fmtHMS(t),rem)) end
            task.wait(0.18)
        else
            say("หลุดเครื่องวิ่ง — วิ่งกลับไปรอ")
            returnTreadmill()
            if rem%60==0 then say(string.format("รอ :00/:30 | %s | อีก %ds",fmtHMS(t),rem)) end
            task.wait(1)
        end
    end
    return false
end
local function farm5min()
    local hub=S.point or FALLBACK
    say(string.format("SCAN/ตี — เช็คเวลาตลอด เหลือ ~%ds",windowLeft()))
    while S.run do
        local t=serverNow()
        if not inFarmWindow(t) then
            say(string.format("จบหน้าต่างอีเวนต์ %s — กลับลู่วิ่ง",fmtHMS(t)))
            break
        end
        local left=windowLeft(t)
        -- สำคัญสุด: ยังบนลู่วิ่งตอนอีเวนต์ = ผิด → กระโดด→Rift→วาฬ
        if onTreadPad() then
            forceEventPath(string.format("ยังบนลู่วิ่งตอนอีเวนต์ (เหลือ %ds) — กระโดด→Rift→วาฬ",left))
            hub=S.point or FALLBACK
            if not S.run then break end
        elseif S.repath then
            S.repath=false
            forceEventPath("เกิดใหม่ — RiftMachine → วาฬ อีกครั้ง")
            hub=S.point or FALLBACK
            if not S.run then break end
        end
        local all=robots()
        local near={}
        for _,x in ipairs(all) do
            if x.d<=350 then near[#near+1]=x end
        end
        if #near==0 then
            local _,_,me=char()
            local dHub=me and (me.Position-hub).Magnitude or 9999
            -- ไม่เจอหุ่น + ยังไกลวาฬ = ต้อง Rift→วาฬ (คูลดาวน์กันวนซ้ำ)
            if dHub>80 then
                local cool=(os.clock()-(S.lastForceAt or 0))>=18
                if cool then
                    forceEventPath(string.format("อีเวนต์เปิด ไม่เจอหุ่น dHub=%.0f — Rift→วาฬ",dHub))
                    hub=S.point or FALLBACK
                else
                    walk(hub,25,40,55)
                end
            else
                if left%30==0 then say(string.format("โซนวาฬแล้ว ไม่มีหุ่น — รอสปอน | เหลือ %ds",left)) end
                walk(hub,20,25,55)
            end
            task.wait(0.5)
        else
            say(string.format("พบ %d ตัว — ตีใกล้สุด d=%.0f | เหลือ %ds",#near,near[1].d,left))
            hit(near[1]); task.wait(.3)
        end
    end
end
local function loop()
    while S.run do
        if not waitEvent() then break end
        -- ทุกครั้งที่เข้าหน้าต่าง: กระโดดออก → Rift → วาฬ เท่านั้น
        forceEventPath("เข้าอีเวนต์ — กระโดดลู่วิ่ง→Rift→วาฬ")
        if not S.run then break end
        S.repath=false
        farm5min()
        if not S.run then break end
        returnTreadmill()
    end
end

local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentFarm"; gui.ResetOnSpawn=false; gui.DisplayOrder=1022
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,320,0,210); f.Position=UDim2.new(0,12,.45,0)
f.BackgroundColor3=Color3.fromRGB(18,43,46); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-40,0,26); title.Position=UDim2.new(0,10,0,2)
title.BackgroundTransparency=1; title.Text="Egg01 Experiment v2.13 — เวลา 0-5/30-35 → Rift→วาฬ"; title.TextColor3=Color3.fromRGB(145,245,230)
title.Font=Enum.Font.GothamBold; title.TextSize=12; title.TextXAlignment=Enum.TextXAlignment.Left
local function button(text,x,color,w)
    local b=Instance.new("TextButton",f); b.Size=UDim2.new(0,w or 58,0,28); b.Position=UDim2.new(0,x,0,32)
    b.Text=text; b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=color; b.BorderSizePixel=0
    b.Font=Enum.Font.GothamBold; b.TextSize=11; Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
end
local startB=button("AUTO",10,Color3.fromRGB(35,145,75))
local stopB=button("STOP",72,Color3.fromRGB(165,50,55))
local pathB=button("PATH",134,Color3.fromRGB(70,110,180))
local copyB=button("COPY",196,Color3.fromRGB(75,75,80),52)
local closeB=button("X",252,Color3.fromRGB(145,50,65),28)
logBox=Instance.new("TextLabel",f); logBox.Size=UDim2.new(1,-16,0,136); logBox.Position=UDim2.new(0,8,0,66)
logBox.BackgroundColor3=Color3.new(0,0,0); logBox.BackgroundTransparency=.2; logBox.TextColor3=Color3.fromRGB(180,245,190)
logBox.Font=Enum.Font.Code; logBox.TextSize=10; logBox.TextXAlignment=Enum.TextXAlignment.Left
logBox.TextYAlignment=Enum.TextYAlignment.Top; logBox.TextWrapped=true; logBox.ClipsDescendants=true

local function beginAuto()
    if S.run or S.test then return end
    S.run=true; startB.Text="ON"
    resolveRift(); resolvePoint()
    local b,d=nearestTreadmill()
    if b and d and d<=14 then S.tread=b; say(string.format("จำเครื่องวิ่ง d=%.0f",d)) end
    say("AUTO ON — เช็คเวลา 0–5/30–35 | บนลู่วิ่ง/ไม่เจอหุ่น → Rift→วาฬ")
    task.spawn(function()
        local ok,err=pcall(loop)
        if not ok then say("ERROR: "..tostring(err)) end
        S.run=false
        if S.gui and S.gui.Parent then startB.Text="AUTO" end
    end)
end
local function runPathTest()
    if S.test then return end
    if S.run then S.run=false; stop("STOP AUTO"); task.wait(0.15) end
    S.test=true; pathB.Text="..."
    setClip(true)
    task.spawn(function()
        local ok,err=pcall(goPoint)
        if not ok then say("PATH ERR: "..tostring(err)) end
        S.test=false
        if pathB and pathB.Parent then pathB.Text="PATH" end
    end)
end

startB.MouseButton1Click:Connect(beginAuto)
stopB.MouseButton1Click:Connect(function()
    S.run=false; S.test=false; stop("STOP"); startB.Text="AUTO"; pathB.Text="PATH"
end)
pathB.MouseButton1Click:Connect(runPathTest)
copyB.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=S.point and string.format("\nPOINT=%.1f,%.1f,%.1f",S.point.X,S.point.Y,S.point.Z) or ""
    if c then pcall(c,"=== Egg01 Experiment Farm v2.13 ===\n"..table.concat(S.lines,"\n")..extra)
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
    if S.run then S.repath=true; say("เกิดใหม่ — repath Rift→วาฬ") end
end)

local function boot()
    setClip(true)
    local c=LP.Character or LP.CharacterAdded:Wait()
    if c then c:WaitForChild("HumanoidRootPart",8) end
    task.wait(0.4)
    if S.gui and S.gui.Parent then beginAuto() end
end
say("v2.13 | เวลา 0–5/30–35 เช็คตลอด | บนลู่วิ่ง/ไม่เจอหุ่น → กระโดด→Rift→วาฬ")
task.spawn(boot)
