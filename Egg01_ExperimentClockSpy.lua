-- Egg01 Experiment Clock Spy v1.1 -- BossFight timer + server :00/:30 + DOCK + spawn
if _G.EGG01_EXPERIMENT_CLOCK_SPY then
    _G.EGG01_EXPERIMENT_CLOCK_SPY.on=false
    pcall(function() _G.EGG01_EXPERIMENT_CLOCK_SPY.gui:Destroy() end)
    for _,c in ipairs(_G.EGG01_EXPERIMENT_CLOCK_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local DEFAULT_DOCK=Vector3.new(2686.4,70.8,-374.9)
local S={on=true,gui=nil,conns={},lines={},dock=DEFAULT_DOCK,seen={},lastBoss=nil}; _G.EGG01_EXPERIMENT_CLOCK_SPY=S
local box,clockLbl
local function log(s)
    S.lines[#S.lines+1]=string.format("[%6.2f] %s",os.clock(),s)
    if #S.lines>120 then table.remove(S.lines,1) end
    if box then box.Text=table.concat(S.lines,"\n") end
    warn("[ExpClock] "..tostring(s))
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
local function parseTimer(txt)
    txt=tostring(txt or ""):gsub("%s","")
    local h,m,s=txt:match("^(%d+):(%d%d):(%d%d)$")
    if h then return tonumber(h)*3600+tonumber(m)*60+tonumber(s) end
    local mm,ss=txt:match("^(%d+):(%d%d)$")
    if mm then return tonumber(mm)*60+tonumber(ss) end
    return nil
end
local function findBossTimer()
    local pg=LP:FindFirstChild("PlayerGui")
    if not pg then return nil,nil end
    local boss=pg:FindFirstChild("BossFightUI",true)
    if not boss then return nil,nil end
    local lab=boss:FindFirstChild("TimerLabel",true)
    if lab and (lab:IsA("TextLabel") or lab:IsA("TextButton")) then
        return lab,tostring(lab.Text)
    end
    return nil,nil
end
local function looksClock(txt,path)
    txt=tostring(txt or ""); path=tostring(path or "")
    local pl=path:lower()
    if pl:find("odds",1,true) or pl:find("player_",1,true) or pl:find("displayname",1,true) then return false end
    if pl:find("autosell",1,true) or pl:find("secret",1,true) then return false end
    if txt:lower()=="secret" or txt:lower():find("coming",1,true) then return false end
    if txt:match("^%d+:%d%d$") or txt:match("^%d+:%d%d:%d%d$") then return true end
    if txt:match("^%d+m%s*%d+s$") or txt:match("^%d+m%s*%d+s$") then return true end
    if pl:find("timer",1,true) or pl:find("timerlabel",1,true) or pl:find("timeremaining",1,true) then
        return txt:find("%d")~=nil
    end
    return false
end
local function scanClocks()
    local hits={}
    local _,bossTxt=findBossTimer()
    if bossTxt then
        hits[#hits+1]={path="PG.BossFightUI...TimerLabel",text=bossTxt,pri=0}
    end
    local pg=LP:FindFirstChild("PlayerGui")
    if pg then
        for _,x in ipairs(pg:GetDescendants()) do
            if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text~="" then
                local p=x:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.","PG.")
                if looksClock(x.Text,p) then
                    local pri=2
                    if p:find("BossFight",1,true) then pri=0
                    elseif p:find("Timer",1,true) or p:find("TimeRemaining",1,true) then pri=1 end
                    hits[#hits+1]={path=p,text=x.Text,pri=pri}
                end
            end
        end
    end
    table.sort(hits,function(a,b) return (a.pri or 9)<(b.pri or 9) end)
    local out,seen={},{}
    for _,h in ipairs(hits) do
        local k=h.path.."|"..h.text
        if not seen[k] then seen[k]=true; out[#out+1]=h end
        if #out>=14 then break end
    end
    return out
end
local function dronePos(m)
    local ok,pivot=pcall(function() return m:GetPivot().Position end)
    if ok and pivot then return pivot end
    local p=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true)
    return p and p.Position
end
local function watchDrone(inst)
    if not inst or not inst:IsA("Model") then return end
    local n=inst.Name:lower()
    if not n:find("dronevisual",1,true) then return end
    if S.seen[inst] then return end
    S.seen[inst]=true
    local t=serverNow()
    local pos=dronePos(inst)
    local posS=pos and string.format("%.0f,%.0f,%.0f",pos.X,pos.Y,pos.Z) or "?"
    local _,bossTxt=findBossTimer()
    log(string.format("SPAWN %s @ server=%s rem=%ds boss=%s pos=%s",inst.Name,fmtHMS(t),secsToBoundary(t),tostring(bossTxt or "-"),posS))
end
local function seedDrones()
    for _,x in ipairs(workspace:GetDescendants()) do
        if x:IsA("Model") and x.Name:lower():find("dronevisual",1,true) then S.seen[x]=true end
    end
end
seedDrones()
S.conns[#S.conns+1]=workspace.DescendantAdded:Connect(function(x)
    if not S.on then return end
    if x:IsA("Model") then watchDrone(x)
    else
        local m=x
        while m and m~=workspace do
            if m:IsA("Model") and m.Name:lower():find("dronevisual",1,true) then watchDrone(m); break end
            m=m.Parent
        end
    end
end)
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentClockSpy"; gui.ResetOnSpawn=false; gui.DisplayOrder=1023
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,520,0,300); f.Position=UDim2.new(0,12,.18,0)
f.BackgroundColor3=Color3.fromRGB(22,40,48); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-20,0,28); title.Position=UDim2.new(0,10,0,2)
title.BackgroundTransparency=1; title.Text="Egg01 Experiment Clock Spy v1.1"; title.TextColor3=Color3.fromRGB(140,240,255)
title.Font=Enum.Font.GothamBold; title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left
clockLbl=Instance.new("TextLabel",f); clockLbl.Size=UDim2.new(1,-16,0,22); clockLbl.Position=UDim2.new(0,8,0,30)
clockLbl.BackgroundTransparency=1; clockLbl.TextColor3=Color3.fromRGB(255,230,140); clockLbl.Font=Enum.Font.Code
clockLbl.TextSize=12; clockLbl.TextXAlignment=Enum.TextXAlignment.Left; clockLbl.Text="..."
local function button(t,x,c,w)
    local b=Instance.new("TextButton",f); b.Size=UDim2.new(0,w or 72,0,28); b.Position=UDim2.new(0,x,0,54)
    b.Text=t; b.BackgroundColor3=c; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=11
    b.BorderSizePixel=0; Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
end
local scanB=button("CLOCKS",10,Color3.fromRGB(45,105,165))
local markB=button("MARK",88,Color3.fromRGB(55,130,90))
local clearB=button("CLEAR",166,Color3.fromRGB(75,75,80))
local copyB=button("COPY",244,Color3.fromRGB(75,75,80))
local closeB=button("X",470,Color3.fromRGB(145,50,65),28)
box=Instance.new("TextBox",f); box.Size=UDim2.new(1,-16,0,200); box.Position=UDim2.new(0,8,0,90)
box.BackgroundColor3=Color3.new(0,0,0); box.BackgroundTransparency=.2; box.TextColor3=Color3.fromRGB(185,245,190)
box.Font=Enum.Font.Code; box.TextSize=10; box.TextEditable=false; box.MultiLine=true; box.ClearTextOnFocus=false
box.TextWrapped=false; box.TextXAlignment=Enum.TextXAlignment.Left; box.TextYAlignment=Enum.TextYAlignment.Top; box.Text=""
scanB.MouseButton1Click:Connect(function()
    local hits=scanClocks(); local t=serverNow()
    local _,bossTxt=findBossTimer()
    local bossSec=parseTimer(bossTxt)
    log(string.format("=== CLOCKS @ server %s rem=%ds boss=%s (%s) ===",fmtHMS(t),secsToBoundary(t),tostring(bossTxt or "-"),bossSec and (bossSec.."s") or "-"))
    if #hits==0 then log("(ไม่พบ timer ที่กรองแล้ว)") end
    for i,h in ipairs(hits) do log(string.format("#%d %s | %s",i,h.text,h.path)) end
end)
markB.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if not r then log("MARK ล้มเหลว — ไม่มีตัวละคร"); return end
    S.dock=r.Position
    log(string.format("DOCK MARK %.1f,%.1f,%.1f",S.dock.X,S.dock.Y,S.dock.Z))
end)
clearB.MouseButton1Click:Connect(function() S.lines={}; if box then box.Text="" end end)
copyB.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=S.dock and string.format("\nDOCK=%.1f,%.1f,%.1f",S.dock.X,S.dock.Y,S.dock.Z) or ""
    if c then pcall(c,"=== Egg01 Experiment Clock Spy v1.1 ===\n"..table.concat(S.lines,"\n")..extra); copyB.Text="OK"; task.delay(1,function() if copyB.Parent then copyB.Text="COPY" end end) end
end)
closeB.MouseButton1Click:Connect(function()
    S.on=false
    for _,c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.EGG01_EXPERIMENT_CLOCK_SPY=nil
end)
task.spawn(function()
    while S.on and gui.Parent do
        local t=serverNow()
        local rem=secsToBoundary(t)
        local _,bossTxt=findBossTimer()
        if bossTxt and bossTxt~=S.lastBoss then
            log(string.format("BOSS TIMER %s → %s | server=%s rem=%ds",tostring(S.lastBoss),bossTxt,fmtHMS(t),rem))
            S.lastBoss=bossTxt
        end
        local dockS=string.format("%.0f,%.0f,%.0f",S.dock.X,S.dock.Y,S.dock.Z)
        clockLbl.Text=string.format("server %s | :00/:30 in %ds | boss=%s | dock=%s",fmtHMS(t),rem,tostring(bossTxt or "-"),dockS)
        task.wait(1)
    end
end)
log(string.format("ClockSpy v1.1 — DOCK default %.1f,%.1f,%.1f | โฟกัส BossFight TimerLabel | SCHED ใช้ server :00/:30",DEFAULT_DOCK.X,DEFAULT_DOCK.Y,DEFAULT_DOCK.Z))
