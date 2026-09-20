-- Egg01 Experiment Spy v1.0 -- ดูหุ่น Dr. Scramble และ log การตีด้วยมือเท่านั้น
if _G.EGG01_EXPERIMENT_SPY then
    _G.EGG01_EXPERIMENT_SPY.on=false
    pcall(function() _G.EGG01_EXPERIMENT_SPY.gui:Destroy() end)
    for _,c in ipairs(_G.EGG01_EXPERIMENT_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
end
local Players,RS=game:GetService("Players"),game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer
local S={on=false,gui=nil,conns={},lines={}}; _G.EGG01_EXPERIMENT_SPY=S
local box
local function path(x) local ok,v=pcall(function() return x:GetFullName() end); return ok and v:gsub("^Workspace%.","WS."):gsub("^ReplicatedStorage%.","RS.") or tostring(x) end
local function val(x)
    if typeof(x)=="Instance" then return "<"..x.ClassName..":"..path(x)..">" end
    if typeof(x)=="Vector3" then return string.format("V3(%.0f,%.0f,%.0f)",x.X,x.Y,x.Z) end
    if typeof(x)=="table" then return "{table}" end
    return tostring(x)
end
local function log(s)
    S.lines[#S.lines+1]=string.format("[%6.2f] %s",os.clock(),s)
    if #S.lines>100 then table.remove(S.lines,1) end
    if box then box.Text=table.concat(S.lines,"\n") end
end
local function robotModel(x)
    while x and x~=workspace do
        if x:IsA("Model") then
            local n=x.Name:lower()
            if n:find("scramble",1,true) or n:find("experiment",1,true) or n:find("robot",1,true) then return x end
        end
        x=x.Parent
    end
end
local function scan()
    local seen,n={},0
    log("=== EXPERIMENT ROBOTS ===")
    for _,x in ipairs(workspace:GetDescendants()) do
        local m=robotModel(x)
        if m and not seen[m] then
            seen[m]=true; n=n+1
            local parts={}
            for _,d in ipairs(m:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text~="" then parts[#parts+1]=d.Text end
                if #parts>=3 then break end
            end
            log(string.format("BOT %s | %s | labels=%s",m.Name,path(m),table.concat(parts," / ")))
        end
    end
    log("พบหุ่น="..n.." | ถือไม้ → START → ตีหุ่น 2-3 ตัวด้วยมือ → COPY")
end
local function watchTool(x)
    if x:IsA("Tool") then S.conns[#S.conns+1]=x.Activated:Connect(function() if S.on then log("⚔ Tool.Activated "..x.Name) end end) end
end
local function watchChar(c)
    for _,x in ipairs(c:GetChildren()) do watchTool(x) end
    S.conns[#S.conns+1]=c.ChildAdded:Connect(watchTool)
end
if LP.Character then watchChar(LP.Character) end
S.conns[#S.conns+1]=LP.CharacterAdded:Connect(watchChar)
if not _G.EGG01_EXPERIMENT_SPY_HOOK and hookmetamethod and getnamecallmethod then
    local old; old=hookmetamethod(game,"__namecall",function(self,...)
        local method=getnamecallmethod()
        if _G.EGG01_EXPERIMENT_SPY and _G.EGG01_EXPERIMENT_SPY.on and (method=="FireServer" or method=="InvokeServer") then
            local args={...}; local out={}
            for i=1,math.min(6,#args) do out[#out+1]=val(args[i]) end
            log(method.." "..path(self).."("..table.concat(out,", ")..")")
        end
        return old(self,...)
    end)
    _G.EGG01_EXPERIMENT_SPY_HOOK=true
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_ExperimentSpy"; gui.ResetOnSpawn=false; gui.DisplayOrder=1021
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end); if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end; S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,620,0,300); f.Position=UDim2.new(0,12,.2,0); f.BackgroundColor3=Color3.fromRGB(20,35,42); f.BorderSizePixel=0; f.Active=true; f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-20,0,30); title.Position=UDim2.new(0,10,0,2); title.BackgroundTransparency=1; title.Text="Egg01 Experiment Spy v1.0 — Dr. Scramble"; title.TextColor3=Color3.fromRGB(135,235,255); title.Font=Enum.Font.GothamBold; title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left
local function button(t,x,c)
    local b=Instance.new("TextButton",f); b.Size=UDim2.new(0,76,0,29); b.Position=UDim2.new(0,x,0,36); b.Text=t; b.BackgroundColor3=c; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=11; b.BorderSizePixel=0; Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
end
local list=button("SCAN",10,Color3.fromRGB(45,105,165)); local start=button("START",92,Color3.fromRGB(35,145,75)); local stop=button("STOP",174,Color3.fromRGB(165,50,55)); local clear=button("CLEAR",256,Color3.fromRGB(75,75,80)); local copy=button("COPY",338,Color3.fromRGB(75,75,80)); local close=button("X",530,Color3.fromRGB(145,50,65))
box=Instance.new("TextBox",f); box.Size=UDim2.new(1,-16,0,216); box.Position=UDim2.new(0,8,0,76); box.BackgroundColor3=Color3.new(0,0,0); box.BackgroundTransparency=.2; box.TextColor3=Color3.fromRGB(185,245,190); box.Font=Enum.Font.Code; box.TextSize=10; box.TextEditable=false; box.MultiLine=true; box.ClearTextOnFocus=false; box.TextWrapped=false; box.TextXAlignment=Enum.TextXAlignment.Left; box.TextYAlignment=Enum.TextYAlignment.Top
list.MouseButton1Click:Connect(scan); start.MouseButton1Click:Connect(function() S.on=true; log("SPY ON — ตีหุ่นด้วยมือ 2-3 ตัว") end); stop.MouseButton1Click:Connect(function() S.on=false; log("SPY OFF") end); clear.MouseButton1Click:Connect(function() S.lines={};box.Text="" end); copy.MouseButton1Click:Connect(function() local c=setclipboard or toclipboard;if c then pcall(c,"=== Egg01 Experiment Spy v1.0 ===\n"..table.concat(S.lines,"\n"));copy.Text="OK";task.delay(1,function() if copy.Parent then copy.Text="COPY" end end)end end); close.MouseButton1Click:Connect(function() S.on=false;for _,c in ipairs(S.conns) do pcall(function()c:Disconnect()end)end;gui:Destroy();_G.EGG01_EXPERIMENT_SPY=nil end)
log("SCAN → ดูตำแหน่ง/ชื่อหุ่น | START → ตีด้วยมือ → COPY")
