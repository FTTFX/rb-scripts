-- Egg01 Experiment Farm v2.0 -- ถึงเวลา → วิ่ง Abyss → ตี 5 นาที → รอ +30
if _G.EGG01_EXPERIMENT_FARM then
    _G.EGG01_EXPERIMENT_FARM.run=false
    pcall(function() _G.EGG01_EXPERIMENT_FARM.gui:Destroy() end)
end
local Players=game:GetService("Players")
local RunS=game:GetService("RunService")
local LP=Players.LocalPlayer
local LEAD=60
local FARM_WINDOW=300 -- 5 นาที
local POINT=Vector3.new(1371.0,90.0,-357.0) -- Abyss Ocean
local S={run=false,gui=nil,lines={},point=POINT,clipConn=nil,clipParts={}}; _G.EGG01_EXPERIMENT_FARM=S
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
local function setClip(on)
    local c=LP.Character
    if not on then
        if S.clipConn then pcall(function() S.clipConn:Disconnect() end); S.clipConn=nil end
        for part,was in pairs(S.clipParts) do
            if part and part.Parent then pcall(function() part.CanCollide=was end) end
        end
        S.clipParts={}; return
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
local function goPoint()
    local _,_,r=char(); if not r then return false end
    local d=(S.point-r.Position).Magnitude
    local lim=math.clamp(d/18+25,45,200)
    setClip(true); say(string.format("วิ่งจุด Abyss @%.0f,%.0f,%.0f",S.point.X,S.point.Y,S.point.Z))
    local ok=walk(S.point,20,lim,55)
    setClip(false)
    say(ok and "ถึงจุดแล้ว" or "ไปจุดไม่ทัน")
    return ok
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
    if name:find("dronevisual",1,true) or name:find("scramble",1,true) then return true end
    for _,x in ipairs(m:GetDescendants()) do
        if x:IsA("TextLabel") or x:IsA("TextButton") then
            local t=tostring(x.Text):lower()
            if t:find("dr. scramble",1,true) or t:find("dr scramble",1,true) then return true end
        end
    end
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
                local center=x:GetPivot().Position
                if not hp or hp>0 then
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
    if not walk(robot.pos,10,70,55) then return end
    local tool=bat(); if not tool then say("ไม่มีไม้"); return end
    say("ตี "..robot.m.Name.." | "..(robot.label or "?"))
    local began=os.clock(); local lastHP=robot.hp
    while S.run and os.clock()-began<10 do
        local latest=robots()[1]
        local currentPart=rootPart(robot.m)
        local _,_,me=char()
        local currentD=currentPart and me and (currentPart.Position-me.Position).Magnitude or math.huge
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
    while S.run do
        local t=serverNow()
        local rem=secsToBoundary(t)
        if rem<=LEAD then
            say(string.format("ถึงเวลา %s — อีก %ds → วิ่งจุด",fmtHMS(t),rem))
            return true
        end
        if rem%60==0 then say(string.format("รอ :00/:30 | %s | อีก %ds",fmtHMS(t),rem)) end
        task.wait(1)
    end
    return false
end
local function farm5min()
    local deadline=os.clock()+FARM_WINDOW
    say("SCAN/ตี — จบใน 5 นาที")
    while S.run and os.clock()<deadline do
        local all=robots()
        if #all==0 then
            local _,_,me=char()
            if me and (me.Position-S.point).Magnitude>40 then walk(S.point,20,30,55) end
            task.wait(.6)
        else
            say(string.format("พบ %d ตัว — ตีใกล้สุด d=%.0f",#all,all[1].d))
            hit(all[1]); task.wait(.3)
        end
    end
    say("จบอีเวนต์ — รอ +30 นาที")
end
local function loop()
    while S.run do
        if not waitEvent() then break end
        goPoint()
        if not S.run then break end
        farm5min()
    end
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentFarm"; gui.ResetOnSpawn=false; gui.DisplayOrder=1022
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,340,0,200); f.Position=UDim2.new(0,12,.45,0)
f.BackgroundColor3=Color3.fromRGB(18,43,46); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-40,0,26); title.Position=UDim2.new(0,10,0,2)
title.BackgroundTransparency=1; title.Text="Egg01 Experiment v2.0 — 5min / +30"; title.TextColor3=Color3.fromRGB(145,245,230)
title.Font=Enum.Font.GothamBold; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left
local function button(text,x,color,w)
    local b=Instance.new("TextButton",f); b.Size=UDim2.new(0,w or 72,0,28); b.Position=UDim2.new(0,x,0,32)
    b.Text=text; b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=color; b.BorderSizePixel=0
    b.Font=Enum.Font.GothamBold; b.TextSize=11; Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
end
local startB=button("START",10,Color3.fromRGB(35,145,75))
local markB=button("MARK",88,Color3.fromRGB(90,110,55))
local stopB=button("STOP",166,Color3.fromRGB(165,50,55))
local copyB=button("COPY",244,Color3.fromRGB(75,75,80),52)
local closeB=button("X",300,Color3.fromRGB(145,50,65),28)
logBox=Instance.new("TextLabel",f); logBox.Size=UDim2.new(1,-16,0,128); logBox.Position=UDim2.new(0,8,0,66)
logBox.BackgroundColor3=Color3.new(0,0,0); logBox.BackgroundTransparency=.2; logBox.TextColor3=Color3.fromRGB(180,245,190)
logBox.Font=Enum.Font.Code; logBox.TextSize=10; logBox.TextXAlignment=Enum.TextXAlignment.Left
logBox.TextYAlignment=Enum.TextYAlignment.Top; logBox.TextWrapped=true; logBox.ClipsDescendants=true
startB.MouseButton1Click:Connect(function()
    if S.run then return end
    S.run=true; startB.Text="ON"
    say(string.format("START — จุด %.0f,%.0f,%.0f | ตี 5 นาที | ลูป +30",S.point.X,S.point.Y,S.point.Z))
    task.spawn(function() loop(); startB.Text="START" end)
end)
markB.MouseButton1Click:Connect(function()
    local _,_,r=char(); if not r then return end
    S.point=r.Position
    say(string.format("MARK จุด %.1f,%.1f,%.1f",S.point.X,S.point.Y,S.point.Z))
end)
stopB.MouseButton1Click:Connect(function()
    S.run=false; setClip(false); stop("STOP"); startB.Text="START"
end)
copyB.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=string.format("\nPOINT=%.1f,%.1f,%.1f",S.point.X,S.point.Y,S.point.Z)
    if c then pcall(c,"=== Egg01 Experiment Farm v2.0 ===\n"..table.concat(S.lines,"\n")..extra)
        copyB.Text="OK"; task.delay(1,function() if copyB.Parent then copyB.Text="COPY" end end) end
end)
closeB.MouseButton1Click:Connect(function()
    S.run=false; setClip(false); gui:Destroy(); _G.EGG01_EXPERIMENT_FARM=nil
end)
say("START = รอ :00/:30 → วิ่ง Abyss → ตี 5 นาที → รอ +30 | MARK เปลี่ยนจุด")
