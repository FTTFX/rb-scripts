-- Egg01 Experiment Clock Spy v1.0 -- server time + UI clock + DroneVisual spawn + MARK dock
if _G.EGG01_EXPERIMENT_CLOCK_SPY then
    _G.EGG01_EXPERIMENT_CLOCK_SPY.on=false
    pcall(function() _G.EGG01_EXPERIMENT_CLOCK_SPY.gui:Destroy() end)
    for _,c in ipairs(_G.EGG01_EXPERIMENT_CLOCK_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local S={on=true,gui=nil,conns={},lines={},dock=nil,seen={}}; _G.EGG01_EXPERIMENT_CLOCK_SPY=S
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
local function looksClock(txt)
    txt=tostring(txt or "")
    if txt:match("%d+:%d%d") then return true end
    if txt:lower():find("min",1,true) or txt:lower():find("sec",1,true) then return true end
    if txt:match("%d+%s*[mM]%s*%d+") then return true end
    return false
end
local function scanClocks()
    local hits={}
    local roots={LP:FindFirstChild("PlayerGui"),game:GetService("CoreGui")}
    for _,root in ipairs(roots) do
        if root then
            for _,x in ipairs(root:GetDescendants()) do
                if (x:IsA("TextLabel") or x:IsA("TextButton") or x:IsA("TextBox")) and x.Text~="" and looksClock(x.Text) then
                    local p=x:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.","PG."):gsub("^CoreGui%.","CG.")
                    hits[#hits+1]={path=p,text=x.Text}
                    if #hits>=12 then break end
                end
            end
        end
        if #hits>=12 then break end
    end
    for _,x in ipairs(workspace:GetDescendants()) do
        if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text~="" and looksClock(x.Text) then
            hits[#hits+1]={path=x:GetFullName():gsub("^Workspace%.","WS."),text=x.Text}
            if #hits>=18 then break end
        end
    end
    return hits
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
    log(string.format("SPAWN %s @ %s server=%s rem=%ds pos=%s",inst.Name,fmtHMS(t),fmtHMS(t),secsToBoundary(t),posS))
end
local function seedDrones()
    for _,x in ipairs(workspace:GetDescendants()) do
        if x:IsA("Model") and x.Name:lower():find("dronevisual",1,true) then
            S.seen[x]=true
        end
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
title.BackgroundTransparency=1; title.Text="Egg01 Experiment Clock Spy v1.0"; title.TextColor3=Color3.fromRGB(140,240,255)
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
    log(string.format("=== UI CLOCKS @ server %s rem=%ds ===",fmtHMS(t),secsToBoundary(t)))
    if #hits==0 then log("(ไม่พบข้อความนาฬิกาใน GUI/WS)") end
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
    local extra=""
    if S.dock then extra=string.format("\nDOCK=%.1f,%.1f,%.1f",S.dock.X,S.dock.Y,S.dock.Z) end
    if c then pcall(c,"=== Egg01 Experiment Clock Spy v1.0 ===\n"..table.concat(S.lines,"\n")..extra); copyB.Text="OK"; task.delay(1,function() if copyB.Parent then copyB.Text="COPY" end end) end
end)
closeB.MouseButton1Click:Connect(function()
    S.on=false
    for _,c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.EGG01_EXPERIMENT_CLOCK_SPY=nil
end)
task.spawn(function()
    local lastUiScan=0
    while S.on and gui.Parent do
        local t=serverNow()
        local rem=secsToBoundary(t)
        local dockS=S.dock and string.format("%.0f,%.0f,%.0f",S.dock.X,S.dock.Y,S.dock.Z) or "-"
        clockLbl.Text=string.format("server %s | next :00/:30 in %ds | dock=%s",fmtHMS(t),rem,dockS)
        if os.clock()-lastUiScan>30 then
            lastUiScan=os.clock()
            local hits=scanClocks()
            if #hits>0 then
                log(string.format("tick UI top=%s | server=%s rem=%ds",hits[1].text,fmtHMS(t),rem))
            end
        end
        task.wait(1)
    end
end)
log("ClockSpy ON — MARK ที่อู่เชียน | CLOCKS เทียบ UI | รอ SPAWN DroneVisual ใกล้ :00/:30")
