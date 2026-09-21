-- Egg01 Experiment Farm v1.8 -- Abyss Ocean FISH + DroneVisual + SCHED + CLIP
if _G.EGG01_EXPERIMENT_FARM then
    _G.EGG01_EXPERIMENT_FARM.run=false
    pcall(function() _G.EGG01_EXPERIMENT_FARM.gui:Destroy() end)
end
local Players=game:GetService("Players")
local RunS=game:GetService("RunService")
local LP=Players.LocalPlayer
local LEAD=60
local FARM_WINDOW=600
local DEFAULT_DOCK=Vector3.new(2194.0,70.8,-364.1)
local DEFAULT_FISH=Vector3.new(1371.0,90.0,-357.0) -- Abyss Ocean จาก ZONE scan
local ZONE_KEYS={
    abyss=10,ocean=8,fish=7,sea=6,reef=6,coral=5,aquatic=5,catfish=5,
    water=3,lake=3,swamp=3,
}
local S={run=false,mode=nil,gui=nil,lines={},searchOrigin=nil,searchIndex=0,dock=DEFAULT_DOCK,fish=DEFAULT_FISH,clockSkew=0,clip=false,clipConn=nil,clipParts={}}; _G.EGG01_EXPERIMENT_FARM=S
local logBox
local function say(m)
    S.lines[#S.lines+1]=tostring(m); if #S.lines>16 then table.remove(S.lines,1) end
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
local function bossTimerText()
    local pg=LP:FindFirstChild("PlayerGui"); if not pg then return nil end
    local boss=pg:FindFirstChild("BossFightUI",true); if not boss then return nil end
    local lab=boss:FindFirstChild("TimerLabel",true)
    if lab and (lab:IsA("TextLabel") or lab:IsA("TextButton")) then return tostring(lab.Text) end
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
        if p:IsA("BasePart") then S.clipParts[p]=p.CanCollide; p.CanCollide=false end
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
local function walkBudget(from,to)
    local d=(from-to).Magnitude
    return math.clamp(d/18+25,45,200)
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
    if name:find("dronevisual",1,true) or name:find("scramble",1,true) then return true end
    for _,x in ipairs(m:GetDescendants()) do
        if x:IsA("TextLabel") or x:IsA("TextButton") then
            local t=tostring(x.Text):lower()
            if t:find("dr. scramble",1,true) or t:find("dr scramble",1,true) then return true end
        end
    end
    return false
end
local function robots()
    local _,_,r=char(); if not r then return {} end
    local out,seen={},{}
    for _,x in ipairs(workspace:GetDescendants()) do
        if x:IsA("Model") and not seen[x] and isExperiment(x) then
            seen[x]=true
            local p=rootPart(x)
            if p then
                local hp,max,label=hpOf(x)
                local center=x:GetPivot().Position
                if not hp or hp>0 then
                    out[#out+1]={m=x,p=p,pos=center,hp=hp,max=max,label=label,d=(center-r.Position).Magnitude}
                end
            end
        end
    end
    table.sort(out,function(a,b) return a.d<b.d end); return out
end
local function zoneScore(name)
    local n=name:lower()
    if n:find("eggfit",1,true) or n:find("eggspot",1,true) or n:find("eggpoint",1,true)
        or n:find("eggcarry",1,true) or n:find("bounds",1,true) then return 0,nil end
    local score,tag=0,nil
    for k,w in pairs(ZONE_KEYS) do
        if n:find(k,1,true) and w>score then score=w; tag=k end
    end
    if n:find("abyss",1,true) then score=score+5; tag=tag or "abyss" end
    return score,tag
end
local function instPos(d)
    if d:IsA("BasePart") then return d.Position end
    if d:IsA("Model") then
        local ok,pv=pcall(function() return d:GetPivot().Position end)
        if ok and pv then return pv end
    end
    local p=d:FindFirstChildWhichIsA("BasePart",true)
    return p and p.Position
end
local function shortPath(d)
    local ok,v=pcall(function() return d:GetFullName() end)
    return ok and v:gsub("^Workspace%.","WS."):gsub("^Workspace","WS") or d.Name
end
local function scanZones()
    local _,_,r=char(); if not r then say("ไม่มีตัวละคร"); return {} end
    local hits,seen={},{}
    local function add(d,bonus)
        if seen[d] then return end
        if not (d:IsA("Model") or d:IsA("Folder") or d:IsA("BasePart")) then return end
        -- รับเฉพาะชื่อโซนชัด (ไม่กวาด area ทั่วแมพ)
        local score,tag=zoneScore(d.Name)
        score=score+(bonus or 0)
        if score<3 then return end
        local pos=instPos(d); if not pos then return end
        local dd=(pos-r.Position).Magnitude
        if dd>2500 then return end
        seen[d]=true
        hits[#hits+1]={d=d,pos=pos,dist=dd,score=score,tag=tag or "?",name=d.Name,path=shortPath(d)}
    end
    local objs=workspace:FindFirstChild("__OBJECTS")
    local areas=objs and objs:FindFirstChild("Areas")
    if areas then
        for _,ch in ipairs(areas:GetDescendants()) do add(ch,2) end
    end
    for _,d in ipairs(workspace:GetDescendants()) do add(d,0) end
    table.sort(hits,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        return a.dist<b.dist
    end)
    say(string.format("ZONE hits=%d me=%.0f,%.0f,%.0f",#hits,r.Position.X,r.Position.Y,r.Position.Z))
    for i=1,math.min(#hits,8) do
        local h=hits[i]
        say(string.format("#%d [%s/%d] %s d=%.0f @%.0f,%.0f,%.0f",i,h.tag,h.score,h.name,h.dist,h.pos.X,h.pos.Y,h.pos.Z))
    end
    if #hits==0 then say("ไม่เจอ Abyss/Ocean — ยืนโซนปลาแล้วกด FISH") end
    return hits
end
local function pickFishZone(hits)
    hits=hits or scanZones()
    if #hits==0 then return nil end
    -- 1) ชื่อ Abyss Ocean ตรงๆ
    for _,h in ipairs(hits) do
        local n=h.name:lower()
        if n:find("abyss",1,true) and n:find("ocean",1,true) then return h end
    end
    -- 2) tag ocean/fish/sea — ใกล้สุดไม่ใช่ไกลสุด
    local best
    for _,h in ipairs(hits) do
        local tag=h.tag
        if tag=="abyss" or tag=="ocean" or tag=="fish" or tag=="sea" or tag=="reef" or tag=="coral" or tag=="aquatic" then
            local rank=h.score*10000-h.dist
            if not best or rank>best.rank then best={h=h,rank=rank} end
        end
    end
    return best and best.h or hits[1]
end
local function goTo(pos,label,useClip,rad)
    rad=rad or 18
    local _,_,r=char(); if not r or not pos then return false end
    local lim=walkBudget(r.Position,pos)
    local used=false
    if useClip then setClip(true); used=true; say("CLIP ON — "..label) end
    say(string.format("%s → %.0f,%.0f,%.0f lim=%ds",label,pos.X,pos.Y,pos.Z,lim))
    local ok=walk(pos,rad,lim,55)
    if used then setClip(false); say("CLIP OFF") end
    say(ok and ("ถึง "..label) or (label.." ไม่ถึง/timeout"))
    return ok
end
local function goDock(useClip)
    if not S.dock then say("ยังไม่มี DOCK"); return false end
    return goTo(S.dock,"DOCK",useClip,12)
end
local function goFish(useClip)
    -- ถ้า FISH เก่าเป็น EggFit ไกลผิด → เลือกใหม่
    local bad=S.fish and ((S.fish-DEFAULT_DOCK).Magnitude>2000)
    if (not S.fish) or bad then
        local z=pickFishZone()
        if z then
            S.fish=z.pos
            say(string.format("เลือก FISH จากโมเดล %s [%s] @%.0f,%.0f,%.0f",z.name,z.tag,z.pos.X,z.pos.Y,z.pos.Z))
        elseif not S.fish then
            S.fish=DEFAULT_FISH
            say(string.format("ใช้ DEFAULT FISH Abyss Ocean @%.0f,%.0f,%.0f",S.fish.X,S.fish.Y,S.fish.Z))
        end
    end
    if not S.fish then say("ยังไม่มีจุด FISH — กด ZONE หรือยืนโซนปลาแล้วกด FISH"); return false end
    return goTo(S.fish,"FISH",useClip~=false,20)
end
local function searchStep()
    local _,_,r=char(); if not r then return end
    local origin=S.fish or S.dock or r.Position
    S.searchOrigin=S.searchOrigin or origin
    local offsets={Vector3.new(80,0,0),Vector3.new(80,0,80),Vector3.new(0,0,80),Vector3.new(-80,0,80),Vector3.new(-80,0,0),Vector3.new(-80,0,-80),Vector3.new(0,0,-80),Vector3.new(80,0,-80)}
    S.searchIndex=(S.searchIndex % #offsets)+1
    walk(S.searchOrigin+offsets[S.searchIndex],14,20,55)
end
local function scan()
    local all=robots(); say("พบ DroneVisual="..#all)
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
local function waitForLead()
    while S.run do
        local t=serverNow()
        local rem=secsToBoundary(t)
        local boss=bossTimerText()
        if rem<=LEAD then
            say(string.format("ใกล้รอบ %s — เหลือ %ds — ไป DOCK→FISH (boss=%s)",fmtHMS(t),rem,tostring(boss or "-")))
            return true
        end
        if rem%30==0 or rem==LEAD+1 then
            say(string.format("รอรอบ :00/:30 | server %s | อีก %ds | boss=%s",fmtHMS(t),rem,tostring(boss or "-")))
        end
        task.wait(1)
    end
    return false
end
local function farmWindow()
    local deadline=os.clock()+FARM_WINDOW
    local _,_,r=char()
    S.searchOrigin=S.fish or S.dock or (r and r.Position) or nil; S.searchIndex=0
    say(string.format("FARM หน้าต่าง %ds รอบ FISH/DOCK",FARM_WINDOW))
    while S.run and os.clock()<deadline do
        local all=robots()
        if #all==0 then
            local hub=S.fish or S.dock
            local _,_,me=char()
            if hub and me and (me.Position-hub).Magnitude>50 then walk(hub,18,40,55) end
            task.wait(.8)
        else
            hit(all[1]); task.wait(.35)
        end
    end
    say("จบหน้าต่างฟาร์ม — รอครึ่งชั่วโมงถัดไป")
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentFarm";gui.ResetOnSpawn=false;gui.DisplayOrder=1022
pcall(function()gui.Parent=(gethui and gethui()) or game:GetService("CoreGui")end); if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui")end;S.gui=gui
local f=Instance.new("Frame",gui);f.Size=UDim2.new(0,500,0,268);f.Position=UDim2.new(0,12,.38,0);f.BackgroundColor3=Color3.fromRGB(18,43,46);f.BorderSizePixel=0;f.Active=true;f.Draggable=true;Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f);title.Size=UDim2.new(1,-80,0,26);title.Position=UDim2.new(0,10,0,2);title.BackgroundTransparency=1;title.Text="Egg01 Experiment Farm v1.8 — Abyss";title.TextColor3=Color3.fromRGB(145,245,230);title.Font=Enum.Font.GothamBold;title.TextSize=13;title.TextXAlignment=Enum.TextXAlignment.Left
local function button(text,x,y,color,w)
    local b=Instance.new("TextButton",f);b.Size=UDim2.new(0,w or 62,0,26);b.Position=UDim2.new(0,x,0,y);b.Text=text;b.TextColor3=Color3.new(1,1,1);b.BackgroundColor3=color;b.BorderSizePixel=0;b.Font=Enum.Font.GothamBold;b.TextSize=10;Instance.new("UICorner",b).CornerRadius=UDim.new(0,5);return b
end
local scanB=button("SCAN",10,32,Color3.fromRGB(45,105,165))
local zoneB=button("ZONE",78,32,Color3.fromRGB(40,90,130))
local start=button("AUTO",146,32,Color3.fromRGB(35,145,75))
local schedB=button("SCHED",214,32,Color3.fromRGB(35,120,160))
local dockB=button("DOCK",282,32,Color3.fromRGB(90,110,55))
local fishB=button("FISH",350,32,Color3.fromRGB(50,120,100))
local clipB=button("CLIP",418,32,Color3.fromRGB(120,90,40),52)
local stopB=button("STOP",10,62,Color3.fromRGB(165,50,55),62)
local copy=button("COPY",78,62,Color3.fromRGB(75,75,80),62)
local goDockB=button("→DOCK",146,62,Color3.fromRGB(70,100,130),62)
local goFishB=button("→FISH",214,62,Color3.fromRGB(40,130,120),62)
local fold=button("−",418,62,Color3.fromRGB(75,65,105),24)
local close=button("X",446,62,Color3.fromRGB(145,50,65),24)
logBox=Instance.new("TextLabel",f);logBox.Size=UDim2.new(1,-16,0,168);logBox.Position=UDim2.new(0,8,0,94);logBox.BackgroundColor3=Color3.new(0,0,0);logBox.BackgroundTransparency=.2;logBox.TextColor3=Color3.fromRGB(180,245,190);logBox.Font=Enum.Font.Code;logBox.TextSize=10;logBox.TextXAlignment=Enum.TextXAlignment.Left;logBox.TextYAlignment=Enum.TextYAlignment.Top;logBox.TextWrapped=true;logBox.ClipsDescendants=true
local row2={scanB,zoneB,start,schedB,dockB,fishB,clipB,stopB,copy,goDockB,goFishB,logBox}
local folded=false
fold.MouseButton1Click:Connect(function()
    folded=not folded;f.Size=UDim2.new(0,500,0,folded and 32 or 268)
    for _,x in ipairs(row2) do x.Visible=not folded end
    fold.Text=folded and "+" or "−"
end)
scanB.MouseButton1Click:Connect(scan)
zoneB.MouseButton1Click:Connect(function()
    local hits=scanZones()
    local z=pickFishZone(hits)
    if z then
        S.fish=z.pos
        say(string.format("FISH = %s [%s] %.0f,%.0f,%.0f",z.name,z.tag,z.pos.X,z.pos.Y,z.pos.Z))
    end
end)
dockB.MouseButton1Click:Connect(function()
    local _,_,r=char(); if not r then say("ไม่มีตัวละคร"); return end
    S.dock=r.Position
    say(string.format("DOCK ตั้งแล้ว %.1f,%.1f,%.1f",S.dock.X,S.dock.Y,S.dock.Z))
end)
fishB.MouseButton1Click:Connect(function()
    local _,_,r=char(); if not r then say("ไม่มีตัวละคร"); return end
    S.fish=r.Position
    say(string.format("FISH MARK %.1f,%.1f,%.1f",S.fish.X,S.fish.Y,S.fish.Z))
end)
clipB.MouseButton1Click:Connect(function()
    if S.clip then setClip(false); clipB.Text="CLIP"; say("CLIP OFF")
    else setClip(true); clipB.Text="CLIP✓"; say("CLIP ON") end
end)
goDockB.MouseButton1Click:Connect(function()
    if S.run then return end
    S.run=true; S.mode="testdock"
    task.spawn(function() goDock(true); S.run=false; S.mode=nil end)
end)
goFishB.MouseButton1Click:Connect(function()
    if S.run then return end
    S.run=true; S.mode="testfish"
    task.spawn(function() goFish(true); S.run=false; S.mode=nil end)
end)
start.MouseButton1Click:Connect(function()
    if S.run then return end;S.run=true;S.mode="auto";start.Text="ON";say("AUTO ON — DroneVisual ใกล้สุด")
    local _,_,r=char();S.searchOrigin=S.fish or S.dock or (r and r.Position);S.searchIndex=0
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
    if not S.dock then say("ตั้ง DOCK ก่อน"); return end
    S.run=true; S.mode="sched"; schedB.Text="ON"
    say(string.format("SCHED ON — DOCK→FISH(CLIP)→FARM | LEAD=%d server=%s",LEAD,fmtHMS(serverNow())))
    task.spawn(function()
        while S.run and S.mode=="sched" do
            if not waitForLead() then break end
            goDock(true)
            if not S.run then break end
            goFish(true)
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
    local extra=""
    if S.dock then extra=extra..string.format("\nDOCK=%.1f,%.1f,%.1f",S.dock.X,S.dock.Y,S.dock.Z) end
    if S.fish then extra=extra..string.format("\nFISH=%.1f,%.1f,%.1f",S.fish.X,S.fish.Y,S.fish.Z) end
    if c then pcall(c,"=== Egg01 Experiment Farm v1.8 ===\n"..table.concat(S.lines,"\n")..extra);copy.Text="OK";task.delay(1,function()if copy.Parent then copy.Text="COPY"end end)end
end)
close.MouseButton1Click:Connect(function()
    S.run=false; setClip(false); gui:Destroy(); _G.EGG01_EXPERIMENT_FARM=nil
end)
say("v1.8: FISH=Abyss Ocean @1371,90,-357 | ไม่เลือก EggFitBounds | ZONE/→FISH")
