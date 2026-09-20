-- Egg01 Rift Prompt Spy v1.0 -- อ่าน Prompt/model/attributes/snapshot เท่านั้น ไม่ยิง Steal
if _G.EGG01_RIFT_PROMPT_SPY then
    pcall(function() _G.EGG01_RIFT_PROMPT_SPY.gui:Destroy() end)
end
local P=game:GetService("Players");local RS=game:GetService("ReplicatedStorage");local LP=P.LocalPlayer
local S={gui=nil,lines={}};_G.EGG01_RIFT_PROMPT_SPY=S
local box
local function say(x)S.lines[#S.lines+1]=tostring(x);if #S.lines>160 then table.remove(S.lines,1)end;if box then box.Text=table.concat(S.lines,"\n")end;warn("[RiftPromptSpy] "..tostring(x))end
local function hr()local c=LP.Character;return c and c:FindFirstChild("HumanoidRootPart")end
local function path(x)local ok,s=pcall(function()return x:GetFullName()end);return ok and s:gsub("^Workspace%.","WS."):gsub("^ReplicatedStorage%.","RS.")or tostring(x)end
local function pos(row)for _,k in ipairs({"BottomCFrame","BoundsCFrame","CFrame","Position"})do local v=row[k];if typeof(v)=="CFrame"then return v.Position elseif typeof(v)=="Vector3"then return v end end end
local function net(name)
    for _,x in ipairs(RS:GetDescendants())do if x.Name:find(name,1,true)then return x end end
end
local function prompts()
    local root=hr();local out={}
    if not root then return out end
    for _,x in ipairs(workspace:GetDescendants())do
        if x:IsA("ProximityPrompt") and x.Enabled and tostring(x.ActionText):lower():find("steal",1,true)then
            local p=x.Parent and(x.Parent:IsA("BasePart")and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart",true))
            if p then out[#out+1]={pp=x,pos=p.Position,d=(p.Position-root.Position).Magnitude}end
        end
    end
    table.sort(out,function(a,b)return a.d<b.d end);return out
end
local function attrs(x)
    local out={};for k,v in pairs(x:GetAttributes())do out[#out+1]=k.."="..tostring(v)end;table.sort(out);return #out>0 and table.concat(out,", ")or "-"
end
local function list()
    local a=prompts();say("=== NEAREST STEAL PROMPTS ===")
    for i=1,math.min(8,#a)do local v=a[i];say(string.format("#%d d=%.1f action=%q object=%q path=%s",i,v.d,v.pp.ActionText,v.pp.ObjectText,path(v.pp)))end
    if #a==0 then say("ไม่พบ Prompt Steal — ยืนใกล้ไข่แล้วกด NEAR ใหม่")end
    return a[1]
end
local function dumpNode(x,depth)
    say(string.rep(" ",depth*2)..x.ClassName.." "..x.Name.." | attrs: "..attrs(x).." | "..path(x))
end
local function dump()
    local chosen=list();if not chosen then return end
    say("=== DUMP NEAREST PROMPT ===")
    say(string.format("Prompt pos=(%.2f,%.2f,%.2f)",chosen.pos.X,chosen.pos.Y,chosen.pos.Z))
    local node=chosen.pp
    for i=0,7 do if not node or node==workspace then break end;dumpNode(node,i);node=node.Parent end
    local model=chosen.pp:FindFirstAncestorOfClass("Model")
    if model then
        local cf=model:GetPivot();say(string.format("MODEL %s pivot=(%.2f,%.2f,%.2f)",path(model),cf.X,cf.Y,cf.Z))
        local n=0
        for _,x in ipairs(model:GetDescendants())do
            if x:IsA("StringValue") or x:IsA("ObjectValue") or x:IsA("TextLabel") then
                n=n+1;if n<=30 then local v=x:IsA("TextLabel")and x.Text or tostring(x.Value);say("  VALUE "..x.ClassName.." "..x.Name.."="..v.." attrs="..attrs(x))end
            end
        end
    else say("ไม่มี Model ancestor")end
    local rf=net("AskFieldEggSnapshot")
    if not rf or not rf:IsA("RemoteFunction")then say("ไม่พบ AskFieldEggSnapshot")return end
    local ok,result=pcall(function()return rf:InvokeServer()end);local records=ok and(result.Records or result.records or result)
    say("=== SNAPSHOT NEAR PROMPT (<=40) ===")
    local found=0
    if typeof(records)=="table"then for id,row in pairs(records)do if typeof(row)=="table"then local p=pos(row);local d=p and(p-chosen.pos).Magnitude;if d and d<=40 then found=found+1;say(string.format("UID=%s d=%.2f cat=%s asset=%s state=%s attrs=%s",tostring(row.Uid or id),d,tostring(row.AssetCategory),tostring(row.AssetName),tostring(row.State),attrs(row)))end end end end
    say("records near="..found.." | COPY แล้วส่ง log นี้")
end
local gui=Instance.new("ScreenGui");gui.Name="Egg01_RiftPromptSpy";gui.ResetOnSpawn=false;gui.DisplayOrder=1030;pcall(function()gui.Parent=(gethui and gethui())or game:GetService("CoreGui")end);if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui")end;S.gui=gui
local f=Instance.new("Frame",gui);f.Size=UDim2.new(0,680,0,380);f.Position=UDim2.new(0,12,.18,0);f.BackgroundColor3=Color3.fromRGB(28,18,42);f.BorderSizePixel=0;f.Active=true;f.Draggable=true;Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f);title.Size=UDim2.new(1,-50,0,30);title.Position=UDim2.new(0,10,0,3);title.BackgroundTransparency=1;title.Text="Egg01 Rift Prompt Spy v1.0 — UID ↔ Prompt";title.TextColor3=Color3.fromRGB(225,180,255);title.Font=Enum.Font.GothamBold;title.TextSize=14;title.TextXAlignment=Enum.TextXAlignment.Left
local function b(t,x,w,c)local z=Instance.new("TextButton",f);z.Size=UDim2.new(0,w,0,30);z.Position=UDim2.new(0,x,0,38);z.Text=t;z.BackgroundColor3=c;z.TextColor3=Color3.new(1,1,1);z.BorderSizePixel=0;z.Font=Enum.Font.GothamBold;z.TextSize=11;Instance.new("UICorner",z).CornerRadius=UDim.new(0,5);return z end
local near=b("NEAR",10,74,Color3.fromRGB(50,100,180));local dumpB=b("DUMP",90,74,Color3.fromRGB(35,145,75));local clear=b("CLEAR",170,74,Color3.fromRGB(75,75,80));local copy=b("COPY",250,74,Color3.fromRGB(75,75,80));local close=b("X",630,34,Color3.fromRGB(145,50,65))
box=Instance.new("TextBox",f);box.Size=UDim2.new(1,-16,0,300);box.Position=UDim2.new(0,8,0,76);box.BackgroundColor3=Color3.new(0,0,0);box.BackgroundTransparency=.2;box.TextColor3=Color3.fromRGB(185,245,190);box.Font=Enum.Font.Code;box.TextSize=10;box.TextEditable=false;box.MultiLine=true;box.ClearTextOnFocus=false;box.TextWrapped=false;box.TextXAlignment=Enum.TextXAlignment.Left;box.TextYAlignment=Enum.TextYAlignment.Top
near.MouseButton1Click:Connect(list);dumpB.MouseButton1Click:Connect(dump);clear.MouseButton1Click:Connect(function()S.lines={};box.Text=""end);copy.MouseButton1Click:Connect(function()local c=setclipboard or toclipboard;if c then pcall(c,"=== Egg01 Rift Prompt Spy v1.0 ===\n"..table.concat(S.lines,"\n"));copy.Text="OK";task.delay(1,function()if copy.Parent then copy.Text="COPY"end end)end end);close.MouseButton1Click:Connect(function()gui:Destroy();_G.EGG01_RIFT_PROMPT_SPY=nil end)
say("ยืนติด Pterodactyl → DUMP → COPY ส่ง log")
