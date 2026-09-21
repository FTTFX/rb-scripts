-- Egg01 Experiment Model Spy v1.1 — GuardAreas / Guard / Nest (ข้ามตัวละครตัวเอง)
if _G.EGG01_EXPERIMENT_MODEL_SPY then
    pcall(function() _G.EGG01_EXPERIMENT_MODEL_SPY.gui:Destroy() end)
end
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local S={gui=nil,lines={},sel=nil}; _G.EGG01_EXPERIMENT_MODEL_SPY=S
local box
local function log(s)
    S.lines[#S.lines+1]=tostring(s)
    if #S.lines>80 then table.remove(S.lines,1) end
    if box then box.Text=table.concat(S.lines,"\n") end
    warn("[ExpModelSpy] "..tostring(s))
end
local function char()
    local c=LP.Character
    return c,c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart")
end
local function short(x)
    local ok,v=pcall(function() return x:GetFullName() end)
    return ok and v:gsub("^Workspace%.","WS.") or tostring(x)
end
local function posOf(d)
    if d:IsA("BasePart") then return d.Position end
    if d:IsA("Model") then
        local ok,pv=pcall(function() return d:GetPivot().Position end)
        if ok and pv then return pv end
        local pp=d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart",true)
        return pp and pp.Position
    end
    local p=d:FindFirstChildWhichIsA("BasePart",true)
    return p and p.Position
end
local function labelsOf(m,maxN)
    maxN=maxN or 4
    local out={}
    for _,x in ipairs(m:GetDescendants()) do
        if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text~="" then
            out[#out+1]=x.Text
            if #out>=maxN then break end
        end
    end
    return out
end
local KEYS={"drone","scramble","experiment","whale","abyss","ocean","fish","boss","event","sleep","zzz","guard","nest"}
local function interesting(name)
    local n=name:lower()
    for _,k in ipairs(KEYS) do
        if n:find(k,1,true) then return true,k end
    end
    return false
end
local function scanNear(rad)
    rad=rad or 120
    local _,_,r=char(); if not r then log("ไม่มีตัวละคร"); return {} end
    local meChar=LP.Character
    local hits,seen={},{}
    for _,d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("Model") or d:IsA("BasePart")) and not seen[d] then
            if meChar and (d==meChar or d:IsDescendantOf(meChar)) then
                -- skip self
            else
                local pos=posOf(d)
                if pos then
                    local dist=(pos-r.Position).Magnitude
                    if dist<=rad then
                        local ok,tag=interesting(d.Name)
                        local path=short(d)
                        local inAbyss=path:lower():find("abyss",1,true) or path:lower():find("guardareas",1,true)
                        local force=d:IsA("Model") and dist<=40 and inAbyss
                        if ok or force or inAbyss then
                            seen[d]=true
                            local labs=d:IsA("Model") and labelsOf(d) or {}
                            local score=0
                            if tag=="guard" or d.Name=="Guard" then score=50 end
                            if tag=="drone" or (d.Name:lower():find("dronevisual",1,true)) then score=40 end
                            if inAbyss then score=score+10 end
                            if d.Name=="NestModel" then score=score+5 end
                            hits[#hits+1]={
                                inst=d,name=d.Name,class=d.ClassName,pos=pos,dist=dist,score=score,
                                tag=tag or (inAbyss and "abyss" or "near"),path=path,labs=labs
                            }
                        end
                    end
                end
            end
        end
    end
    table.sort(hits,function(a,b)
        if (a.score or 0)~=(b.score or 0) then return (a.score or 0)>(b.score or 0) end
        return a.dist<b.dist
    end)
    return hits,r.Position
end
local function dumpHit(h,i)
    local p=h.pos
    log(string.format("#%d [%s] %s %s d=%.0f @%.1f,%.1f,%.1f",
        i,h.tag,h.class,h.name,h.dist,p.X,p.Y,p.Z))
    log("   "..h.path)
    if #h.labs>0 then log("   labels: "..table.concat(h.labs," | ")) end
end
local function scan(rad)
    local hits,me=scanNear(rad)
    log(string.format("=== SCAN r=%d me=%.0f,%.0f,%.0f hits=%d ===",rad or 120,me.X,me.Y,me.Z,#hits))
    for i=1,math.min(#hits,25) do dumpHit(hits[i],i) end
    if #hits==0 then log("ไม่เจอ — เข้าใกล้วาฬ/หุ่นแล้ว SCAN ใหม่") end
    S.last=hits
    return hits
end
local function pickClosestKeyword(words)
    local hits=S.last or scan(150)
    for _,w in ipairs(words) do
        for _,h in ipairs(hits) do
            if h.name:lower():find(w,1,true) or (h.tag and h.tag:find(w,1,true)) then
                S.sel=h
                log(string.format("SELECT %s @%.1f,%.1f,%.1f",h.name,h.pos.X,h.pos.Y,h.pos.Z))
                return h
            end
        end
    end
    if hits[1] then
        S.sel=hits[1]
        log(string.format("SELECT nearest %s @%.1f,%.1f,%.1f",hits[1].name,hits[1].pos.X,hits[1].pos.Y,hits[1].pos.Z))
        return hits[1]
    end
    log("ไม่มีให้เลือก")
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentModelSpy"; gui.ResetOnSpawn=false; gui.DisplayOrder=1024
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,520,0,310); f.Position=UDim2.new(0,12,.16,0)
f.BackgroundColor3=Color3.fromRGB(24,38,46); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-20,0,28); title.Position=UDim2.new(0,10,0,2)
title.BackgroundTransparency=1; title.Text="Egg01 Experiment Model Spy v1.0 — ยืนใกล้วาฬ/หุ่นแล้ว SCAN"
title.TextColor3=Color3.fromRGB(140,240,255); title.Font=Enum.Font.GothamBold; title.TextSize=13
title.TextXAlignment=Enum.TextXAlignment.Left
local function button(t,x,c,w)
    local b=Instance.new("TextButton",f); b.Size=UDim2.new(0,w or 72,0,28); b.Position=UDim2.new(0,x,0,34)
    b.Text=t; b.BackgroundColor3=c; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=11
    b.BorderSizePixel=0; Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
end
local scanB=button("SCAN",10,Color3.fromRGB(45,105,165))
local nearB=button("NEAR40",88,Color3.fromRGB(40,90,130))
local whaleB=button("WHALE",166,Color3.fromRGB(55,100,120))
local droneB=button("DRONE",244,Color3.fromRGB(55,100,120))
local copyB=button("COPY",322,Color3.fromRGB(75,75,80))
local clearB=button("CLEAR",400,Color3.fromRGB(75,75,80),52)
local closeB=button("X",460,Color3.fromRGB(145,50,65),28)
box=Instance.new("TextBox",f); box.Size=UDim2.new(1,-16,0,230); box.Position=UDim2.new(0,8,0,70)
box.BackgroundColor3=Color3.new(0,0,0); box.BackgroundTransparency=.2; box.TextColor3=Color3.fromRGB(185,245,190)
box.Font=Enum.Font.Code; box.TextSize=10; box.TextEditable=false; box.MultiLine=true; box.ClearTextOnFocus=false
box.TextWrapped=false; box.TextXAlignment=Enum.TextXAlignment.Left; box.TextYAlignment=Enum.TextYAlignment.Top; box.Text=""
scanB.MouseButton1Click:Connect(function() scan(120) end)
nearB.MouseButton1Click:Connect(function() scan(40) end)
whaleB.MouseButton1Click:Connect(function() pickClosestKeyword({"guard","whale","orca","nest"}) end)
droneB.MouseButton1Click:Connect(function() pickClosestKeyword({"dronevisual","drone","scramble"}) end)
clearB.MouseButton1Click:Connect(function() S.lines={}; if box then box.Text="" end end)
copyB.MouseButton1Click:Connect(function()
    local c=setclipboard or toclipboard
    local extra=""
    if S.sel then
        extra=string.format("\nSELECT=%s\nPOS=%.1f,%.1f,%.1f\nPATH=%s",S.sel.name,S.sel.pos.X,S.sel.pos.Y,S.sel.pos.Z,S.sel.path)
    end
    if c then pcall(c,"=== Egg01 Experiment Model Spy v1.0 ===\n"..table.concat(S.lines,"\n")..extra)
        copyB.Text="OK"; task.delay(1,function() if copyB.Parent then copyB.Text="COPY" end end) end
end)
closeB.MouseButton1Click:Connect(function()
    gui:Destroy(); _G.EGG01_EXPERIMENT_MODEL_SPY=nil
end)
log("ยืนหน้าวาฬ / ใกล้อีเวนต์ → SCAN หรือ NEAR40 → WHALE/DRONE → COPY")
