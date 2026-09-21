-- Egg01 Experiment Rift Spy v1.0 — หาพิกัดคริสตัล RIFT ก่อนล็อกใน Farm
if _G.EGG01_EXPERIMENT_RIFT_SPY then
    pcall(function() _G.EGG01_EXPERIMENT_RIFT_SPY.gui:Destroy() end)
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local S={gui=nil,lines={},sel=nil}; _G.EGG01_EXPERIMENT_RIFT_SPY=S
local box
local function log(s)
    S.lines[#S.lines+1]=tostring(s)
    if #S.lines>100 then table.remove(S.lines,1) end
    if box then box.Text=table.concat(S.lines,"\n") end
    warn("[ExpRiftSpy] "..tostring(s))
end
local function hrp()
    local c=LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function short(x)
    local ok,v=pcall(function() return x:GetFullName() end)
    return ok and v:gsub("^Workspace%.","WS."):gsub("^Players%.","PL.") or tostring(x)
end
local function posOf(d)
    if not d then return end
    if d:IsA("BasePart") then return d.Position end
    if d:IsA("Model") then
        local ok,pv=pcall(function() return d:GetPivot().Position end)
        if ok and pv then return pv end
        local pp=d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart",true)
        return pp and pp.Position
    end
    if d:IsA("Attachment") then return d.WorldPosition end
    if d:IsA("BillboardGui") and d.Adornee then return posOf(d.Adornee) end
    local p=d:FindFirstChildWhichIsA("BasePart",true) or d.Parent
    return p and posOf(p)
end
local function skipPath(path)
    local p=path:lower()
    return p:find("playergui",1,true) or p:find("rifttrade",1,true)
        or p:find("coregui",1,true) or p:find("egg01",1,true)
end
local function scan()
    local me=hrp(); if not me then log("ไม่มี HRP"); return end
    local hits={}
    for _,d in ipairs(workspace:GetDescendants()) do
        local path=short(d)
        if not skipPath(path) then
        local score,why=0,nil
        local n=d.Name:lower()
        if n=="rift" then score,why=80,"name=Rift"
        elseif n:find("rift",1,true) and not n:find("trade",1,true) then score,why=40,"name~rift"
        end
        if (d:IsA("TextLabel") or d:IsA("TextButton")) then
            local t=tostring(d.Text):upper():gsub("%s+","")
            if t=="RIFT" then score,why=100,"TextLabel RIFT"
            elseif t:find("RIFT",1,true) then score,why=math.max(score,60),"text~RIFT"
            end
        end
        if score>0 then
            local p=posOf(d)
            if p then
                local dist=(p-me.Position).Magnitude
                hits[#hits+1]={inst=d,pos=p,d=dist,score=score,why=why,path=path,cls=d.ClassName,name=d.Name}
            end
        end
        end
    end
    table.sort(hits,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        return a.d<b.d
    end)
    log(string.format("=== RIFT SCAN me=%.0f,%.0f,%.0f hits=%d ===",me.Position.X,me.Position.Y,me.Position.Z,#hits))
    for i=1,math.min(15,#hits) do
        local h=hits[i]
        log(string.format("#%d sc=%d d=%.0f %s %s | %s @%.1f,%.1f,%.1f",
            i,h.score,h.d,h.cls,h.name,h.why,h.pos.X,h.pos.Y,h.pos.Z))
        log("  "..h.path)
    end
    if #hits==0 then
        log("ไม่เจอ — ยืนหน้าคริสตัลม่วงคำว่า RIFT แล้วกด SCAN / หรือ MARK")
    else
        S.sel=hits[1]
        log(string.format("SELECT #%d POS=%.1f,%.1f,%.1f",1,S.sel.pos.X,S.sel.pos.Y,S.sel.pos.Z))
    end
    return hits
end
local function mark()
    local me=hrp(); if not me then return end
    S.sel={pos=me.Position,path="MARK",name="MARK",why="player",d=0,score=999}
    log(string.format("MARK RIFT @%.1f,%.1f,%.1f",me.Position.X,me.Position.Y,me.Position.Z))
end
local function near()
    local me=hrp(); if not me then return end
    local hits=scan() or {}
    local best
    for _,h in ipairs(hits) do
        if h.d<=80 and (not best or h.d<best.d) then best=h end
    end
    if best then
        S.sel=best
        log(string.format("NEAR40 SELECT d=%.0f POS=%.1f,%.1f,%.1f",best.d,best.pos.X,best.pos.Y,best.pos.Z))
    else
        log("NEAR ไม่เจอใน 80 — MARK แทน")
    end
end

local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentRiftSpy"; gui.ResetOnSpawn=false; gui.DisplayOrder=1031
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,420,0,260); f.Position=UDim2.new(0,12,0.3,0)
f.BackgroundColor3=Color3.fromRGB(35,20,55); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-40,0,28); title.Position=UDim2.new(0,10,0,4)
title.BackgroundTransparency=1; title.Text="Egg01 Rift Spy v1.0 — หาจุดคริสตัล RIFT"; title.TextColor3=Color3.fromRGB(230,180,255)
title.Font=Enum.Font.GothamBold; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left
local function b(tx,x,col) local z=Instance.new("TextButton",f); z.Size=UDim2.new(0,70,0,28); z.Position=UDim2.new(0,x,0,34)
    z.Text=tx; z.BackgroundColor3=col; z.TextColor3=Color3.new(1,1,1); z.Font=Enum.Font.GothamBold; z.TextSize=11
    z.BorderSizePixel=0; Instance.new("UICorner",z).CornerRadius=UDim.new(0,5); return z end
local scanB=b("SCAN",10,Color3.fromRGB(90,60,150))
local nearB=b("NEAR40",86,Color3.fromRGB(70,100,160))
local markB=b("MARK",162,Color3.fromRGB(50,130,90))
local copyB=b("COPY",238,Color3.fromRGB(75,75,80))
local closeB=b("X",314,Color3.fromRGB(145,50,65)); closeB.Size=UDim2.new(0,36,0,28)
box=Instance.new("TextLabel",f); box.Size=UDim2.new(1,-16,0,180); box.Position=UDim2.new(0,8,0,70)
box.BackgroundColor3=Color3.new(0,0,0); box.BackgroundTransparency=.2; box.TextColor3=Color3.fromRGB(210,200,255)
box.Font=Enum.Font.Code; box.TextSize=10; box.TextXAlignment=Enum.TextXAlignment.Left
box.TextYAlignment=Enum.TextYAlignment.Top; box.TextWrapped=true; box.ClipsDescendants=true; box.Text=""
scanB.MouseButton1Click:Connect(function() task.spawn(scan) end)
nearB.MouseButton1Click:Connect(function() task.spawn(near) end)
markB.MouseButton1Click:Connect(mark)
copyB.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=""
    if S.sel and S.sel.pos then
        extra=string.format("\nRIFT_POS=%.1f,%.1f,%.1f\nFALLBACK_RIFT=Vector3.new(%.1f,%.1f,%.1f)",
            S.sel.pos.X,S.sel.pos.Y,S.sel.pos.Z,S.sel.pos.X,S.sel.pos.Y,S.sel.pos.Z)
    end
    if c then pcall(c,"=== Egg01 Experiment Rift Spy v1.0 ===\n"..table.concat(S.lines,"\n")..extra) end
    copyB.Text="OK"; task.delay(1,function() if copyB.Parent then copyB.Text="COPY" end end)
end)
closeB.MouseButton1Click:Connect(function() gui:Destroy(); _G.EGG01_EXPERIMENT_RIFT_SPY=nil end)
log("ยืนหน้าคริสตัลม่วงคำว่า RIFT → SCAN หรือ MARK → COPY ส่งมา")
