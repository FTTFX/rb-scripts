-- Egg01 Dr.Scramble Lab Spy v1.0 -- dump model / prompt / remote / UI
if _G.EGG01_SCRAMBLE_SPY then pcall(function() _G.EGG01_SCRAMBLE_SPY.stop() end) end
local P=game:GetService("Players");local RS=game:GetService("ReplicatedStorage");local LP=P.LocalPlayer
local S={lines={},conns={},watching=false,model=nil};_G.EGG01_SCRAMBLE_SPY=S
local box
local function say(x)S.lines[#S.lines+1]=tostring(x);if #S.lines>400 then table.remove(S.lines,1)end;if box then box.Text=table.concat(S.lines,"\n")end;warn("[ScrambleSpy] "..tostring(x))end
local function hr()local c=LP.Character;return c and c:FindFirstChild("HumanoidRootPart")end
local function path(x)local ok,s=pcall(function()return x:GetFullName()end);return ok and s:gsub("^Workspace%.","WS."):gsub("^ReplicatedStorage%.","RS.")or tostring(x)end
local function attrs(x)local out={};for k,v in pairs(x:GetAttributes())do out[#out+1]=k.."="..tostring(v)end;table.sort(out);return #out>0 and table.concat(out,", ")or ""end
local function fmt(v)if typeof(v)=="Instance"then return "<"..path(v)..">" elseif typeof(v)=="table"then local o={};local n=0;for k,x in pairs(v)do n=n+1;if n>8 then o[#o+1]="...";break end;o[#o+1]=tostring(k).."="..(typeof(x)=="table"and"{..}"or tostring(x))end;return "{"..table.concat(o,", ").."}" else return tostring(v)end end
local KEYS={"scramble","lab","mutat","fuse","merge","experiment","machine","incubat","splice"}
local function hit(s)s=tostring(s):lower();for _,k in ipairs(KEYS)do if s:find(k,1,true)then return k end end end
local function bpos(x)if x:IsA("BasePart")then return x.Position end;if x:IsA("Model")then local ok,cf=pcall(function()return x:GetPivot()end);if ok then return cf.Position end end;local p=x:FindFirstAncestorWhichIsA("BasePart");return p and p.Position end

local function findModel()
    local r=hr();if not r then say("ไม่มีตัวละคร");return end
    local best,bd
    for _,x in ipairs(workspace:GetDescendants())do
        if x:IsA("ProximityPrompt")then
            local p=bpos(x.Parent);local d=p and(p-r.Position).Magnitude
            if d and d<40 and(not bd or d<bd)then best,bd=x,d end
        end
    end
    say("=== NEAR PROMPTS (<40) ===")
    for _,x in ipairs(workspace:GetDescendants())do
        if x:IsA("ProximityPrompt")then local p=bpos(x.Parent);local d=p and(p-r.Position).Magnitude
            if d and d<40 then say(string.format("d=%.1f action=%q object=%q key=%s hold=%.1f enabled=%s | %s",d,x.ActionText,x.ObjectText,tostring(x.KeyboardKeyCode.Name),x.HoldDuration,tostring(x.Enabled),path(x)))end end
    end
    local m=best and best:FindFirstAncestorOfClass("Model")
    if m then while m.Parent and m.Parent~=workspace and m.Parent:IsA("Model")do m=m.Parent end end
    if not m then
        for _,x in ipairs(workspace:GetDescendants())do if x:IsA("Model")and hit(x.Name)then local p=bpos(x);local d=p and(p-r.Position).Magnitude;if d and d<120 and(not bd or d<bd)then m,bd=x,d end end end
    end
    S.model=m;S.prompt=best
    say(m and("MODEL = "..path(m))or"ไม่เจอโมเดล — เดินไปใกล้แล็บแล้วกด NEAR ใหม่")
    return m
end

local function dump()
    local m=S.model or findModel();if not m then return end
    say("=== DUMP "..path(m).." ===")
    local a=attrs(m);if a~=""then say("attrs: "..a)end
    local n=0
    local function walk(x,depth)
        for _,c in ipairs(x:GetChildren())do
            n=n+1;if n>350 then return end
            local extra=""
            if c:IsA("ValueBase")then extra=" ="..fmt(c.Value)
            elseif c:IsA("TextLabel")or c:IsA("TextButton")then extra=" text="..string.format("%q",c.Text)
            elseif c:IsA("ProximityPrompt")then extra=string.format(" action=%q object=%q",c.ActionText,c.ObjectText)
            elseif c:IsA("ClickDetector")then extra=" maxDist="..c.MaxActivationDistance
            elseif c:IsA("BaseRemoteEvent")or c:IsA("RemoteFunction")then extra=" <REMOTE>" end
            local at=attrs(c);if at~=""then extra=extra.." | "..at end
            local skip=(c:IsA("BasePart")or c:IsA("Decal")or c:IsA("Texture")or c:IsA("SpecialMesh"))and extra==""and #c:GetChildren()==0
            if not skip then say(string.rep(" ",depth)..c.ClassName.." "..c.Name..extra)end
            walk(c,depth+1)
        end
    end
    walk(m,1)
    say("=== REMOTES ที่ชื่อเกี่ยว (RS) ===")
    for _,x in ipairs(RS:GetDescendants())do if(x:IsA("RemoteEvent")or x:IsA("RemoteFunction")or x:IsA("UnreliableRemoteEvent"))and hit(x.Name)then say(x.ClassName.." "..path(x))end end
    say("=== PlayerGui ที่ชื่อเกี่ยว ===")
    for _,g in ipairs(LP.PlayerGui:GetChildren())do if hit(g.Name)then say(g.ClassName.." "..g.Name.." enabled="..tostring(g.Enabled))end end
    say("DUMP จบ ("..n.." nodes) — กด COPY")
end

local oldNC
local function stopWatch()
    S.watching=false
    for _,c in ipairs(S.conns)do pcall(function()c:Disconnect()end)end;S.conns={}
end
local function watch()
    if S.watching then stopWatch();say("WATCH OFF");return end
    if not S.model then findModel() end
    S.watching=true
    say("WATCH ON — กด E ที่แล็บ แล้วเล่นตามปกติ 1 รอบ")
    for _,x in ipairs(workspace:GetDescendants())do
        if x:IsA("ProximityPrompt")and(S.model and x:IsDescendantOf(S.model))then
            S.conns[#S.conns+1]=x.Triggered:Connect(function()say("PROMPT TRIGGERED "..path(x))end)
        end
    end
    S.conns[#S.conns+1]=LP.PlayerGui.DescendantAdded:Connect(function(x)
        if x:IsA("ScreenGui")or x:IsA("Frame")and x.Parent and x.Parent:IsA("ScreenGui")then say("GUI + "..path(x))end
    end)
    for _,g in ipairs(LP.PlayerGui:GetChildren())do
        if g:IsA("ScreenGui")then S.conns[#S.conns+1]=g:GetPropertyChangedSignal("Enabled"):Connect(function()say("GUI "..g.Name.." Enabled="..tostring(g.Enabled))end)end
        for _,f in ipairs(g:GetChildren())do if f:IsA("GuiObject")then S.conns[#S.conns+1]=f:GetPropertyChangedSignal("Visible"):Connect(function()if f.Visible then say("GUI SHOW "..path(f))end end)end end
    end
    for _,x in ipairs(RS:GetDescendants())do
        if x:IsA("RemoteEvent")or x:IsA("UnreliableRemoteEvent")then
            S.conns[#S.conns+1]=x.OnClientEvent:Connect(function(...)local a={...};local o={};for i=1,math.min(#a,5)do o[i]=fmt(a[i])end;say("S→C "..x.Name.." ("..table.concat(o,", ")..")")end)
        end
    end
    if hookmetamethod and getnamecallmethod and not oldNC then
        oldNC=hookmetamethod(game,"__namecall",function(self,...)
            if S.watching and not(checkcaller and checkcaller())then
                local m=getnamecallmethod()
                if m=="FireServer"or m=="InvokeServer"then
                    local a={...};task.spawn(function()local o={};for i=1,math.min(#a,5)do o[i]=fmt(a[i])end;say("C→S "..m.." "..self.Name.." ("..table.concat(o,", ")..")")end)
                end
            end
            return oldNC(self,...)
        end)
    end
end

local gui=Instance.new("ScreenGui");gui.Name="Egg01_ScrambleSpy";gui.ResetOnSpawn=false;gui.DisplayOrder=1030;pcall(function()gui.Parent=(gethui and gethui())or game:GetService("CoreGui")end);if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui")end
local f=Instance.new("Frame",gui);f.Size=UDim2.new(0,680,0,380);f.Position=UDim2.new(0,12,.18,0);f.BackgroundColor3=Color3.fromRGB(18,32,22);f.BorderSizePixel=0;f.Active=true;f.Draggable=true;Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f);title.Size=UDim2.new(1,-50,0,30);title.Position=UDim2.new(0,10,0,3);title.BackgroundTransparency=1;title.Text="Egg01 Dr.Scramble Lab Spy v1.0";title.TextColor3=Color3.fromRGB(190,255,120);title.Font=Enum.Font.GothamBold;title.TextSize=14;title.TextXAlignment=Enum.TextXAlignment.Left
local function b(t,x,w,c)local z=Instance.new("TextButton",f);z.Size=UDim2.new(0,w,0,30);z.Position=UDim2.new(0,x,0,38);z.Text=t;z.BackgroundColor3=c;z.TextColor3=Color3.new(1,1,1);z.BorderSizePixel=0;z.Font=Enum.Font.GothamBold;z.TextSize=11;Instance.new("UICorner",z).CornerRadius=UDim.new(0,5);return z end
local near=b("NEAR",10,74,Color3.fromRGB(50,100,180));local dumpB=b("DUMP",90,74,Color3.fromRGB(35,145,75));local watchB=b("WATCH",170,74,Color3.fromRGB(130,95,45));local clear=b("CLEAR",250,74,Color3.fromRGB(75,75,80));local copy=b("COPY",330,74,Color3.fromRGB(75,75,80));local close=b("X",630,34,Color3.fromRGB(145,50,65))
box=Instance.new("TextBox",f);box.Size=UDim2.new(1,-16,0,300);box.Position=UDim2.new(0,8,0,76);box.BackgroundColor3=Color3.new(0,0,0);box.BackgroundTransparency=.2;box.TextColor3=Color3.fromRGB(185,245,190);box.Font=Enum.Font.Code;box.TextSize=10;box.TextEditable=false;box.MultiLine=true;box.ClearTextOnFocus=false;box.TextWrapped=false;box.TextXAlignment=Enum.TextXAlignment.Left;box.TextYAlignment=Enum.TextYAlignment.Top
S.stop=function()stopWatch();pcall(function()gui:Destroy()end);_G.EGG01_SCRAMBLE_SPY=nil end
near.MouseButton1Click:Connect(findModel);dumpB.MouseButton1Click:Connect(dump)
watchB.MouseButton1Click:Connect(function()watch();watchB.Text=S.watching and"WATCH ●"or"WATCH"end)
clear.MouseButton1Click:Connect(function()S.lines={};box.Text=""end)
copy.MouseButton1Click:Connect(function()local c=setclipboard or toclipboard;if c then pcall(c,"=== Egg01 Scramble Spy v1.0 ===\n"..table.concat(S.lines,"\n"));copy.Text="OK";task.delay(1,function()if copy.Parent then copy.Text="COPY"end end)end end)
close.MouseButton1Click:Connect(S.stop)
say("ยืนใกล้แล็บ → NEAR → DUMP → WATCH แล้วกด E เล่น 1 รอบ → COPY")
