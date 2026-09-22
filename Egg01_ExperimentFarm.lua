-- Egg01 Experiment Farm v2.25 — โซนวาฬไม่ย้อน Rift | กระโดด+เดินหน้า | ก้าวขึ้น
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
local TREAD_ON_R=22      -- ถือว่ายังบนลู่
local TREAD_CLEAR_R=32  -- พ้นลู่
local TREAD_PICK_R=120  -- เลือกลู่เรทสูงสุดในรัศมีนี้ (กันไปยืน +1000 ทั้งที่มี +2000 ข้างๆ)
local FALLBACK=Vector3.new(2283.0,74.0,-312.0)
local FALLBACK_RIFT=Vector3.new(534.0,71.0,-340.0)
local S={run=false,test=false,gui=nil,lines={},point=nil,rift=nil,tread=nil,lockedTread=nil,badTreads={},progAt=0,progBase=nil,progName=nil,progOk=false,clipConn=nil,clipParts={},repath=false,leaving=false,stuckAbort=false,watchPos=nil,watchAt=0,fakeUntil=0,fakeInto=30}; _G.EGG01_EXPERIMENT_FARM=S
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
    local real=ok and t or os.time()
    -- PATH: หลอกว่าอยู่ในช่วง :00–:05 (secsIntoHalf = fakeInto)
    if (S.fakeUntil or 0)>os.clock() then
        local into=math.floor(real)%1800
        local want=math.clamp(tonumber(S.fakeInto) or 30,0,FARM_WINDOW-1)
        return real-into+want
    end
    return real
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
        if S.stuckAbort then restore(); return false end
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
        if S.stuckAbort then restore(); return false end
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
-- ถึงวาฬแล้วไม่ย้อน Rift — ไกล/ยังใกล้ลู่ค่อย Rift→วาฬ
local NEAR_WHALE_R=280
local function nearWhale(pos)
    local hub=S.point or FALLBACK
    local p=pos
    if not p then
        local _,_,r=char(); if not r then return false end
        p=r.Position
    end
    return Vector3.new(p.X-hub.X,0,p.Z-hub.Z).Magnitude<=NEAR_WHALE_R
end
-- บังคับเสมอ: ขั้น1 → Rift แล้ว ขั้น2 → วาฬ / ถ้าอยู่ใกล้วาฬแล้วข้าม Rift
local function goPoint()
    local whale=resolvePoint()
    local _,_,r=char(); if not r then say("ไม่มี HRP — ข้าม path"); return false end
    local dWhale=(Vector3.new(whale.X,r.Position.Y,whale.Z)-r.Position).Magnitude
    if dWhale<=NEAR_WHALE_R then
        say(string.format("อยู่โซนวาฬแล้ว d=%.0f — ไม่ย้อน Rift",dWhale))
        if dWhale>25 then
            local ok=walkFar(whale,20,math.clamp(dWhale/14+40,40,180),55)
            say(ok and "ถึงวาฬแล้ว ✓ — เริ่มตี" or "ฟาร์มต่อจากจุดนี้")
            return ok
        end
        say("ถึงวาฬแล้ว ✓ — เริ่มตี")
        return true
    end
    local rift=resolveRift()
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
-- แค่กลับจุดวาฬ (ไม่ผ่าน Rift)
local function goWhaleOnly(why)
    if why then say(why) end
    local whale=S.point or resolvePoint()
    local _,_,r=char(); if not r then return false end
    local d=(Vector3.new(whale.X,r.Position.Y,whale.Z)-r.Position).Magnitude
    if d<=25 then return true end
    return walkFar(whale,20,math.clamp(d/14+40,40,200),55)
end
local function nearestTreadmill()
    local _,_,r=char(); if not r then return nil end
    local now=os.clock()
    -- ล้างแบล็คลิสต์หมดอายุ
    for k,untilT in pairs(S.badTreads) do
        if not untilT or untilT<now or not k.Parent then S.badTreads[k]=nil end
    end
    if S.lockedTread and S.lockedTread.Parent and not S.badTreads[S.lockedTread] then
        return S.lockedTread,(S.lockedTread.Position-r.Position).Magnitude
    end
    local function stepRate(bottom)
        local rate=0
        local root=bottom
        for _=1,8 do
            if not root.Parent or root.Parent==workspace then break end
            root=root.Parent
        end
        local ok,desc=pcall(function() return root:GetDescendants() end)
        if not ok or not desc then return 0 end
        for _,d in ipairs(desc) do
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local t=tostring(d.Text or ""):gsub(",",""):gsub("%s","")
                local n=t:match("%+?(%d+)/step") or t:match("%+?(%d+)/Step")
                if n then rate=math.max(rate,tonumber(n) or 0) end
            end
        end
        return rate
    end
    local best,bestD,bestRate
    local ok,desc=pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return nil end
    for _,item in ipairs(desc) do
        if item:IsA("BasePart") and item.Name=="TreadmillBottom" and not S.badTreads[item] then
            local d=(item.Position-r.Position).Magnitude
            if d<=TREAD_PICK_R then
                local rate=stepRate(item)
                if not best
                    or rate>bestRate
                    or (rate==bestRate and d<(bestD or 1e9)) then
                    best,bestD,bestRate=item,d,rate
                end
            end
        end
    end
    if not best then
        for _,item in ipairs(desc) do
            if item:IsA("BasePart") and item.Name=="TreadmillBottom" and not S.badTreads[item] then
                local d=(item.Position-r.Position).Magnitude
                if not bestD or d<bestD then best,bestD,bestRate=item,d,0 end
            end
        end
    end
    return best,bestD,bestRate or 0
end
-- ค่าที่ขึ้นเมื่อยืนลู่ถูก (Speed / Steps)
local function readStepProgress()
    local stats=LP:FindFirstChild("leaderstats")
    if stats then
        for _,name in ipairs({"Speed","Steps","Step","Miles","Distance","Studs"}) do
            local v=stats:FindFirstChild(name)
            if v~=nil then
                local n=tonumber(v.Value)
                if n then return n,name end
            end
        end
        for _,c in ipairs(stats:GetChildren()) do
            if c:IsA("NumberValue") or c:IsA("IntValue") or c:IsA("StringValue") then
                local n=tonumber(c.Value)
                if n then return n,c.Name end
            end
        end
    end
    local pd=LP:FindFirstChild("PlayerData") or LP:FindFirstChild("Data")
    if pd then
        for _,name in ipairs({"Speed","Steps","Step"}) do
            local v=pd:FindFirstChild(name,true)
            if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
                return tonumber(v.Value),name
            end
        end
    end
    return nil,nil
end
local function beginProgCheck()
    local n,name=readStepProgress()
    S.progAt=os.clock()
    S.progBase=n
    S.progName=name or "?"
end
-- วิ่งบนลู่แล้วค่าไม่ขึ้น = ลู่ผิด → แบล็คลิสต์แล้วหาลู่อื่น
local function verifyTreadProgress(secs)
    secs=secs or 10
    if (S.progAt or 0)<=0 then beginProgCheck(); return nil end
    if os.clock()-(S.progAt or 0)<secs then return nil end
    local now,name=readStepProgress()
    local base=S.progBase
    S.progAt=0
    if base==nil or now==nil then
        say("เช็คก้าวไม่ได้ ("..tostring(S.progName)..") — คงลู่นี้ไว้")
        return true
    end
    if now>base+0.05 then
        say(string.format("ลู่ถูก — %s %.0f→%.0f",name or S.progName,base,now))
        if S.tread then S.lockedTread=S.tread end
        S.progOk=true
        return true
    end
    say(string.format("ลู่ผิด — %s ไม่ขึ้น (%.0f) — เปลี่ยนลู่",name or S.progName,now))
    if S.tread then
        S.badTreads[S.tread]=os.clock()+600
        if S.lockedTread==S.tread then S.lockedTread=nil end
        S.tread=nil
    end
    S.progOk=false
    return false
end
local function treadStandPos(bottom)
    if not bottom then return nil end
    return bottom.CFrame:PointToWorldSpace(Vector3.new(0,bottom.Size.Y*0.5+2.5,0))
end
local function onTreadPad()
    local _,_,r=char(); if not r then return false end
    -- เสมอเช็คใกล้ตัวก่อน (ไม่เชื่อ S.tread เก่าที่อาจผิดตัว)
    local b,d=nearestTreadmill()
    if b and d and d<=TREAD_ON_R then
        S.tread=b
        return true,b,d
    end
    return false,b,d
end
local function treadDist(bottom)
    local _,_,r=char()
    if not r or not bottom or not bottom.Parent then return 999 end
    return (bottom.Position-r.Position).Magnitude
end
local function isClearOfTread(bottom)
    bottom=bottom or S.tread
    if not bottom or not bottom.Parent then
        local b,d=nearestTreadmill()
        return not b or not d or d>=TREAD_CLEAR_R,d or 999,b
    end
    local d=treadDist(bottom)
    return d>=TREAD_CLEAR_R,d,bottom
end
local function leaveDir(bottom,r)
    local rift=S.rift
    if not rift then rift=select(1,findRift()) end
    if rift then
        local flat=Vector3.new(rift.X-r.Position.X,0,rift.Z-r.Position.Z)
        if flat.Magnitude>=1 then return flat.Unit end
    end
    local away=Vector3.new(r.Position.X-bottom.Position.X,0,r.Position.Z-bottom.Position.Z)
    if away.Magnitude>=1 then return away.Unit end
    return r.CFrame.LookVector
end
-- กระโดด + เดินหน้าพร้อมกัน (กด 2 ปุ่มพร้อม — ห้ามวิ่งบนลู่เปล่าๆ จะติดกลับ)
local function leaveJumpWhileRun(bottom, times)
    times = times or 1
    for i = 1, times do
        if not busy() then break end
        local _, h, r = char()
        if not h or not r or not bottom or not bottom.Parent then break end
        h.Sit = false
        h.PlatformStand = false
        if h.WalkSpeed < 28 then h.WalkSpeed = 28 end
        local dir = leaveDir(bottom, r)
        local rift = S.rift or select(1, findRift())
        local goal = r.Position + dir * 70
        if rift then
            local toR = Vector3.new(rift.X - r.Position.X, 0, rift.Z - r.Position.Z)
            if toR.Magnitude > 5 then
                dir = toR.Unit
                goal = r.Position + dir * math.min(90, toR.Magnitude)
            end
        end
        -- Jump + Move พร้อมกันทันที (ไม่มีวิ่งก่อน)
        h.Jump = true
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
        h:MoveTo(Vector3.new(goal.X, r.Position.Y, goal.Z))
        pcall(function() h:Move(dir, false) end)
        pcall(function()
            local v = r.AssemblyLinearVelocity
            r.AssemblyLinearVelocity = Vector3.new(dir.X * 42, math.max(v.Y, 40), dir.Z * 42)
        end)
        -- ค้างกดเดินหน้า+กระโดดซ้ำขณะลอย/ลงพื้น
        for _ = 1, 18 do
            if not busy() then break end
            local _, h2, r2 = char()
            if not h2 or not r2 then break end
            if isClearOfTread(bottom) then return true end
            h2.Jump = true
            h2:MoveTo(Vector3.new(goal.X, r2.Position.Y, goal.Z))
            pcall(function() h2:Move(dir, false) end)
            task.wait(0.06)
        end
    end
    return select(1, isClearOfTread(bottom))
end
-- หลังกระโดดแล้ว: ยังกระโดด+เดินหน้าต่อ — ห้ามวิ่งพื้นบนลู่
local function dashOffTread(bottom, secs)
    local deadline = os.clock() + (secs or 3.5)
    local n = 0
    while busy() and os.clock() < deadline do
        if S.stuckAbort then break end
        local clear, d = isClearOfTread(bottom)
        if clear then return true, d end
        local _, h, r = char()
        if not h or not r or not bottom or not bottom.Parent then return false, d end
        h.Sit = false
        h.PlatformStand = false
        if h.WalkSpeed < 28 then h.WalkSpeed = 28 end
        local dir = leaveDir(bottom, r)
        local goal = r.Position + dir * 70
        local rift = S.rift or select(1, findRift())
        if rift then
            local toR = Vector3.new(rift.X - r.Position.X, 0, rift.Z - r.Position.Z)
            if toR.Magnitude > 5 then
                dir = toR.Unit
                goal = r.Position + dir * math.min(90, toR.Magnitude)
            end
        end
        -- ยังใกล้ลู่ = กระโดด+เดินหน้าพร้อมกันทุกเฟรม
        if (d or 0) < TREAD_CLEAR_R then
            h.Jump = true
            pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
            if n % 4 == 0 then
                pcall(function()
                    local v = r.AssemblyLinearVelocity
                    r.AssemblyLinearVelocity = Vector3.new(dir.X * 38, math.max(v.Y, 28), dir.Z * 38)
                end)
            end
        end
        h:MoveTo(Vector3.new(goal.X, r.Position.Y, goal.Z))
        pcall(function() h:Move(dir, false) end)
        n = n + 1
        task.wait(0.07)
    end
    local clear, d = isClearOfTread(bottom)
    return clear, d
end
local function leaveTreadmill()
    if _G.EGG01_TREADMILL then _G.EGG01_TREADMILL.run = false end
    S.leaving = true
    local on, bottom, d = onTreadPad()
    if not bottom or not bottom.Parent then
        bottom = S.tread
        if not bottom or not bottom.Parent then bottom = select(1, nearestTreadmill()) end
    end
    if not bottom then
        say("ไม่พบเครื่องวิ่ง — ไป Rift→วาฬเลย")
        S.leaving = false
        return true
    end
    S.tread = bottom
    local clear0, d0 = isClearOfTread(bottom)
    if clear0 then
        say(string.format("พ้นลู่วิ่งแล้ว d=%.0f", d0 or -1))
        S.leaving = false
        return true
    end
    say(string.format("บังคับออกลู่วิ่ง (ห่าง>%d) d=%.0f — กระโดด+เดินหน้าพร้อมกัน", TREAD_CLEAR_R, d0 or d or -1))
    local ok, dd = false, treadDist(bottom)
    for round = 1, 4 do
        if not busy() then break end
        if select(1, isClearOfTread(bottom)) then ok = true; dd = treadDist(bottom); break end
        local jumps = (round <= 2) and 2 or 3
        say(string.format("ออกลู่ รอบ%d ยังใกล้ d=%.0f — กดกระโดด+เดินหน้า %d", round, treadDist(bottom), jumps))
        leaveJumpWhileRun(bottom, jumps)
        ok, dd = dashOffTread(bottom, 2.2)
        say(string.format("ออกลู่ รอบ%d หลังกระโดด d=%.0f %s", round, dd or -1, ok and "✓" or "ยังใกล้"))
        if ok then break end
    end
    local clear, df = isClearOfTread(bottom)
    say(clear and string.format("ออกจากลู่วิ่งแล้ว d=%.0f", df or -1) or string.format("ยังติดลู่ d=%.0f — ฝืนไป Rift", df or -1))
    S.leaving = false
    return clear
end
local function returnTreadmill()
    local bottom,d,rate=nearestTreadmill()
    if not bottom then say("ไม่พบเครื่องวิ่ง"); return false end
    S.tread=bottom
    local target=treadStandPos(bottom)
    if not target then return false end
    local _,_,r=char()
    -- ขากลับผ่าน Rift ก่อน เหมือนขาไป — กันติดกำแพงตรงกลางแมพ
    if r then
        local rift=findRift()
        local dR=(Vector3.new(rift.X,r.Position.Y,rift.Z)-r.Position).Magnitude
        local dT=(Vector3.new(target.X,r.Position.Y,target.Z)-r.Position).Magnitude
        if dR>25 and dR+150<dT then
            say(string.format("กลับผ่าน Rift d=%.0f → ลู่ d≈%.0f (กันติดกำแพง)",dR,dT))
            if not walkFar(rift,22,math.clamp(dR/16+50,60,400),55) and not busy() then return false end
        end
    end
    local _,_,r2=char()
    local lim=r2 and math.clamp((target-r2.Position).Magnitude/18+25,45,200) or 90
    say(string.format("ไปลู่เรทสูงสุด +%s/step d=%.0f%s",
        tostring(rate and rate>0 and rate or "?"),
        d or (r2 and (bottom.Position-r2.Position).Magnitude) or -1,
        S.lockedTread==bottom and " (LOCK)" or ""))
    walk(target,5,lim,55)
    if onTreadPad() then
        say("อยู่เครื่องวิ่งแล้ว — เช็คก้าว 10s")
        beginProgCheck()
        return true
    end
    say("ยังไม่ถึงลู่จริง")
    return false
end
local function resetTreadmill(why)
    say(why or "รีเซ็ต — ฆ่าตัวตาย เกิดใหม่")
    S.tread=nil
    S.watchPos=nil
    local _,h=char()
    if h and h.Health>0 then
        pcall(function() h.Health=0 end)
    end
    -- เกิดใหม่แล้ว CharacterAdded จะตั้ง repath ถ้า S.run อยู่
    return true
end
local function jogTreadTick(n)
    local bottom=S.tread
    if not bottom or not bottom.Parent then
        local b=select(1,nearestTreadmill())
        if not b then return n end
        bottom=b; S.tread=b
    end
    local _,h,r=char(); if not h or not r then return n end
    local offset=Vector3.new(math.sin(n)*1.2,bottom.Size.Y*0.5+2.5,math.cos(n)*1.2)
    local step=bottom.CFrame:PointToWorldSpace(offset)
    h:MoveTo(Vector3.new(step.X,r.Position.Y,step.Z))
    return n+math.pi*0.5
end
-- บังคับ path ตอนอีเวนต์: ออกลู่ → (ใกล้วาฬ=ตรงวาฬ / ไกล=Rift→วาฬ)
local function forceEventPath(why)
    say(why or "บังคับไปวาฬ")
    S.stuckAbort=false
    S.watchPos=nil
    leaveTreadmill()
    if not busy() then return false end
    if onTreadPad() or not select(1,isClearOfTread(S.tread)) then
        say("ยังไม่พ้นลู่ — ลองอีกรอบ")
        leaveTreadmill()
    end
    if not busy() then return false end
    if nearWhale() then
        goWhaleOnly("โซนวาฬแล้ว — ไม่ย้อน Rift")
    else
        goPoint()
    end
    S.lastForceAt=os.clock()
    S.watchPos=nil
    return true
end
-- ทุก 5 วิ: ค้างระหว่างทาง/บนลู่ → ไปวาฬ (ไม่ย้อน Rift ถ้าอยู่โซนแล้ว)
-- ยืนตีในโซนวาฬ = ไม่รีสตาร์ท
local function startStuckWatch()
    S.watchGen=(S.watchGen or 0)+1
    local gen=S.watchGen
    task.spawn(function()
        while S.run and S.watchGen==gen do
            task.wait(5)
            if not S.run or S.watchGen~=gen then break end
            if S.leaving or not inFarmWindow() then
                S.watchPos=nil
            else
                local _,_,r=char()
                if not r then
                    S.watchPos=nil
                else
                    local p=r.Position
                    if S.watchPos then
                        local moved=Vector3.new(p.X-S.watchPos.X,0,p.Z-S.watchPos.Z).Magnitude
                        if moved<8 then
                            if nearWhale(p) and not onTreadPad() then
                                -- ยืนตี/รอสปอนในโซนวาฬ — ไม่ทำอะไร
                                S.watchPos=p
                            else
                                say(string.format("ค้างตำแหน่ง %.0f studs/5s — ไปวาฬ (ไม่ย้อน Rift)",moved))
                                S.stuckAbort=true
                                S.repath=true
                                S.watchPos=nil
                            end
                        else
                            S.watchPos=p
                        end
                    else
                        S.watchPos=p
                    end
                end
            end
        end
    end)
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
        if S.stuckAbort then return end
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
    local missSince=nil
    local lastWaitSay=0
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
        if inFarmWindow(t) then
            say(string.format("อีเวนต์เปิด %s — เข้าแล้ว %ds / เหลือ ~%ds → ออกลู่วิ่ง",fmtHMS(t),into,windowLeft(t)))
            return true
        end
        if rem<=LEAD then
            say(string.format("ใกล้รอบ %s — อีก %ds → ออกเครื่องวิ่ง",fmtHMS(t),rem))
            return true
        end
        if onTreadPad() then
            missSince=nil
            if not S.progOk then
                if (S.progAt or 0)<=0 then beginProgCheck() end
                local okProg=verifyTreadProgress(10)
                if okProg==false then
                    returnTreadmill()
                    task.wait(0.5)
                else
                    n=jogTreadTick(n)
                    if rem%60==0 and os.clock()-lastWaitSay>=5 then
                        say(string.format("รอบนเครื่องวิ่ง | %s | อีก %ds",fmtHMS(t),rem))
                        lastWaitSay=os.clock()
                    end
                    task.wait(0.18)
                end
            else
                n=jogTreadTick(n)
                if rem%60==0 and os.clock()-lastWaitSay>=5 then
                    say(string.format("รอบนเครื่องวิ่ง | %s | อีก %ds",fmtHMS(t),rem))
                    lastWaitSay=os.clock()
                end
                task.wait(0.18)
            end
        else
            S.progAt=0
            S.progBase=nil
            S.progOk=false
            if not missSince then missSince=os.clock() end
            local missFor=os.clock()-missSince
            if missFor>=60 then
                say("ไม่เจอลู่วิ่งจริงครบ 1 นาที — ฆ่าตัวตายรีเซ็ต")
                missSince=nil
                resetTreadmill()
                task.wait(2)
            else
                if os.clock()-lastWaitSay>=8 then
                    say(string.format("หลุดลู่ — กลับไปรอ (ยังไม่เจอ %.0fs/60s)",missFor))
                    lastWaitSay=os.clock()
                end
                returnTreadmill()
                task.wait(1)
            end
        end
    end
    return false
end
local function farm5min()
    local hub=S.point or FALLBACK
    say(string.format("SCAN/ตี — ค้าง5s=เริ่มใหม่ | เหลือ ~%ds",windowLeft()))
    while S.run do
        local t=serverNow()
        if not inFarmWindow(t) then
            say(string.format("จบหน้าต่างอีเวนต์ %s — กลับลู่วิ่ง",fmtHMS(t)))
            break
        end
        local left=windowLeft(t)
        if S.stuckAbort or S.repath then
            S.stuckAbort=false
            S.repath=false
            if nearWhale() then
                goWhaleOnly(string.format("ค้าง/repath โซนวาฬ — อยู่ต่อ ไม่ย้อน Rift | เหลือ %ds",left))
            else
                forceEventPath(string.format("เริ่มใหม่ (ค้าง/repath) เหลือ %ds",left))
            end
            hub=S.point or FALLBACK
            if not S.run then break end
        elseif onTreadPad() then
            forceEventPath(string.format("ยังบนลู่วิ่งตอนอีเวนต์ (เหลือ %ds) — ออกลู่→วาฬ",left))
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
            if dHub>80 then
                -- ห้ามย้อน Rift — เดินตรงกลับ hub วาฬ
                if (os.clock()-(S.lastForceAt or 0))>=12 then
                    S.lastForceAt=os.clock()
                    goWhaleOnly(string.format("ไม่เจอหุ่น dHub=%.0f — เดินกลับจุดวาฬ",dHub))
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
        startStuckWatch()
        forceEventPath("เข้าอีเวนต์ — ออกลู่วิ่ง→Rift→วาฬ")
        if not S.run then break end
        S.repath=false
        S.stuckAbort=false
        farm5min()
        if not S.run then break end
        returnTreadmill()
    end
end

local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentFarm"; gui.ResetOnSpawn=false; gui.DisplayOrder=1022
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,360,0,210); f.Position=UDim2.new(0,12,.45,0)
f.BackgroundColor3=Color3.fromRGB(18,43,46); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-40,0,26); title.Position=UDim2.new(0,10,0,2)
title.BackgroundTransparency=1; title.Text="Egg01 Experiment v2.25 — ไม่ย้อน Rift"; title.TextColor3=Color3.fromRGB(145,245,230)
title.Font=Enum.Font.GothamBold; title.TextSize=12; title.TextXAlignment=Enum.TextXAlignment.Left
local function button(text,x,color,w)
    local b=Instance.new("TextButton",f); b.Size=UDim2.new(0,w or 52,0,28); b.Position=UDim2.new(0,x,0,32)
    b.Text=text; b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=color; b.BorderSizePixel=0
    b.Font=Enum.Font.GothamBold; b.TextSize=11; Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
end
local startB=button("AUTO",10,Color3.fromRGB(35,145,75))
local stopB=button("STOP",66,Color3.fromRGB(165,50,55))
local pathB=button("PATH",122,Color3.fromRGB(70,110,180))
local lockB=button("LOCK",178,Color3.fromRGB(120,90,40),52)
local copyB=button("COPY",234,Color3.fromRGB(75,75,80),48)
local closeB=button("X",286,Color3.fromRGB(145,50,65),28)
logBox=Instance.new("TextLabel",f); logBox.Size=UDim2.new(1,-16,0,136); logBox.Position=UDim2.new(0,8,0,66)
logBox.BackgroundColor3=Color3.new(0,0,0); logBox.BackgroundTransparency=.2; logBox.TextColor3=Color3.fromRGB(180,245,190)
logBox.Font=Enum.Font.Code; logBox.TextSize=10; logBox.TextXAlignment=Enum.TextXAlignment.Left
logBox.TextYAlignment=Enum.TextYAlignment.Top; logBox.TextWrapped=true; logBox.ClipsDescendants=true

local function beginAuto()
    if S.run or S.test then return end
    S.run=true; startB.Text="ON"
    resolveRift(); resolvePoint()
    local b,d,rate=nearestTreadmill()
    if b then
        S.tread=b
        say(string.format("จำลู่ +%s/step d=%.0f",tostring(rate and rate>0 and rate or "?"),d or -1))
    end
    say("v2.25 | โซนวาฬแล้วไม่ย้อน Rift | ยืนตีไม่รีสตาร์ท")
    say("AUTO ON — ลู่เรทสูงสุดใน 120 | ค้างนอกโซน=ไปวาฬ")
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
    S.test=true; pathB.Text="0-5"
    setClip(true)
    -- หลอกเวลาอยู่ในช่วง :00–:05 นาน 5 นาทีจริง (ทดลอง path อีเวนต์)
    S.fakeInto=30
    S.fakeUntil=os.clock()+FARM_WINDOW
    resolveRift(); resolvePoint()
    local b,d=nearestTreadmill()
    if b and d and d<=TREAD_ON_R then S.tread=b end
    say(string.format("PATH — หลอกเวลาช่วง 0–5 (เหลืออีเวนต์จำลอง ~%ds) | ออกลู่→วาฬ",windowLeft()))
    task.spawn(function()
        local ok,err=pcall(function()
            forceEventPath("PATH ทดสอบ (เวลาหลอก 0–5) — ออกลู่→Rift→วาฬ")
        end)
        if not ok then say("PATH ERR: "..tostring(err)) end
        S.test=false
        if pathB and pathB.Parent then pathB.Text="PATH" end
        say(string.format("PATH จบ — ยังหลอกเวลาอีก ~%.0fs (หรือกด STOP เคลียร์)",math.max(0,(S.fakeUntil or 0)-os.clock())))
    end)
end

startB.MouseButton1Click:Connect(beginAuto)
stopB.MouseButton1Click:Connect(function()
    S.run=false; S.test=false; S.fakeUntil=0; stop("STOP"); startB.Text="AUTO"; pathB.Text="PATH"
end)
pathB.MouseButton1Click:Connect(runPathTest)
lockB.MouseButton1Click:Connect(function()
    local on,b,d=onTreadPad()
    if on and b then
        S.lockedTread=b
        S.tread=b
        lockB.Text="ON"
        say(string.format("LOCK ลู่นี้แล้ว d=%.0f — จะกลับลู่นี้เสมอ",d or -1))
    elseif S.lockedTread then
        S.lockedTread=nil
        lockB.Text="LOCK"
        say("ปลด LOCK — เลือกลู่เรทสูงสุดอัตโนมัติ")
    else
        say("ยืนบนลู่ที่ต้องการแล้วกด LOCK")
    end
end)
copyB.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=S.point and string.format("\nPOINT=%.1f,%.1f,%.1f",S.point.X,S.point.Y,S.point.Z) or ""
    if c then pcall(c,"=== Egg01 Experiment Farm v2.25 ===\n"..table.concat(S.lines,"\n")..extra)
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
    if S.run then S.repath=true; say("เกิดใหม่ — repath ไปวาฬ (ไม่ย้อน Rift ถ้าอยู่โซน)") end
end)

local function boot()
    setClip(true)
    local c=LP.Character or LP.CharacterAdded:Wait()
    if c then c:WaitForChild("HumanoidRootPart",8) end
    task.wait(0.4)
    if S.gui and S.gui.Parent then beginAuto() end
end
say("v2.25 | โซนวาฬแล้วไม่ย้อน Rift | ยืนตีไม่รีสตาร์ท")
task.spawn(boot)
