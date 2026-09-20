-- Egg01 Motion Lab v1.0 -- วัดเดินปกติ / แรงผลักสั้น / แรงผลัก + Hop เบรก
if _G.EGG01_MOTION_LAB then _G.EGG01_MOTION_LAB.run=false; pcall(function() _G.EGG01_MOTION_LAB.gui:Destroy() end) end
local Players=game:GetService("Players"); local LP=Players.LocalPlayer
local S={run=false,home=nil,gui=nil,lines={}}; _G.EGG01_MOTION_LAB=S
local logBox
local function say(m) S.lines[#S.lines+1]=tostring(m);if #S.lines>16 then table.remove(S.lines,1)end;if logBox then logBox.Text=table.concat(S.lines,"\n")end;warn("[MotionLab] "..tostring(m))end
local function hr() local c=LP.Character;return c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart") end
local function stop() local h,r=hr();if h and r then h:MoveTo(r.Position);h:Move(Vector3.zero)end;local c=LP.Character;if c then local b=c:FindFirstChild("Egg01MotionPush");if b then b:Destroy()end end end
local function pulsePush(r,dir)
    local old=r:FindFirstChild("Egg01MotionPush");if old then old:Destroy()end
    local b=Instance.new("BodyVelocity");b.Name="Egg01MotionPush";b.MaxForce=Vector3.new(18000,0,18000);b.P=1800;b.Velocity=dir*42;b.Parent=r
    task.delay(.055,function()if b.Parent then b:Destroy()end end)
end
local function run(name,mode)
    if S.run then return end
    local h,r=hr();if not h or not r then say("ไม่มีตัวละคร")return end
    if not S.home then say("กด HOME ที่ฐานก่อน")return end
    S.run=true;local began=os.clock();local start=(r.Position-S.home).Magnitude;local path,rollback,maxV,last,lastSample=0,0,0,r.Position,0;local pushed,braked=false,false
    say(string.format("=== %s === d=%.0f | WS=%.1f",name,start,h.WalkSpeed))
    while S.run and os.clock()-began<45 do
        h,r=hr();if not h or not r or h.Health<=0 then say("หยุด: ตัวละครเปลี่ยน");break end
        local flat=Vector3.new(S.home.X,r.Position.Y,S.home.Z);local delta=flat-r.Position;local d=delta.Magnitude
        if d<=5 then say(string.format("ถึง HOME %.2fs path=%.0f rollback=%.0f peak=%.0f",os.clock()-began,path,rollback,maxV));break end
        local dir=delta.Unit;h:MoveTo(flat)
        if (mode=="PUSH" or mode=="HOP") and not braked and d>26 then pulsePush(r,dir);pushed=true end
        -- Hop สั้นเพียงครั้งเดียวเพื่อเบรกก่อนถึง ไม่ล็อกตำแหน่งค้าง
        if mode=="HOP" and not braked and d<=24 then
            braked=true;local step=math.min(10,math.max(0,d-7));r.CFrame=CFrame.new(r.Position+dir*step)* (r.CFrame-r.CFrame.Position);h:MoveTo(r.Position);say("HOP brake 1 ครั้ง @d="..math.floor(d))
        end
        local now=os.clock();local moved=(r.Position-last).Magnitude;path=path+moved;local vel=r.AssemblyLinearVelocity.Magnitude;maxV=math.max(maxV,vel)
        if d>(Vector3.new(S.home.X,last.Y,S.home.Z)-last).Magnitude+12 then rollback=rollback+(d-(Vector3.new(S.home.X,last.Y,S.home.Z)-last).Magnitude) end
        if now-lastSample>=.6 then say(string.format("t=%.1f d=%.0f v=%.0f phys=%.0f push=%s",now-began,d,moved/math.max(now-lastSample,.01),vel,pushed and "Y" or "N"));lastSample=now end
        last=r.Position;task.wait(.11)
    end
    stop();S.run=false
end
local gui=Instance.new("ScreenGui");gui.Name="Egg01_MotionLab";gui.ResetOnSpawn=false;gui.DisplayOrder=1025;pcall(function()gui.Parent=(gethui and gethui())or game:GetService("CoreGui")end);if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui")end;S.gui=gui
local f=Instance.new("Frame",gui);f.Size=UDim2.new(0,410,0,245);f.Position=UDim2.new(0,12,.45,0);f.BackgroundColor3=Color3.fromRGB(23,31,45);f.BorderSizePixel=0;f.Active=true;f.Draggable=true;Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f);title.Size=UDim2.new(1,-50,0,30);title.Position=UDim2.new(0,10,0,2);title.BackgroundTransparency=1;title.Text="Egg01 Motion Lab v1.0 — Walk / Push / Hop";title.TextColor3=Color3.fromRGB(180,220,255);title.Font=Enum.Font.GothamBold;title.TextSize=13;title.TextXAlignment=Enum.TextXAlignment.Left
local function button(t,x,w,c)local b=Instance.new("TextButton",f);b.Size=UDim2.new(0,w,0,30);b.Position=UDim2.new(0,x,0,38);b.Text=t;b.BackgroundColor3=c;b.TextColor3=Color3.new(1,1,1);b.BorderSizePixel=0;b.Font=Enum.Font.GothamBold;b.TextSize=11;Instance.new("UICorner",b).CornerRadius=UDim.new(0,5);return b end
local home=button("HOME",10,62,Color3.fromRGB(45,105,165));local normal=button("WALK",78,62,Color3.fromRGB(70,115,160));local push=button("PUSH",146,62,Color3.fromRGB(35,145,75));local hop=button("PUSH+HOP",214,76,Color3.fromRGB(130,100,45));local halt=button("STOP",296,62,Color3.fromRGB(165,50,55));local copy=button("COPY",364,38,Color3.fromRGB(75,75,80))
logBox=Instance.new("TextLabel",f);logBox.Size=UDim2.new(1,-16,0,158);logBox.Position=UDim2.new(0,8,0,78);logBox.BackgroundColor3=Color3.new(0,0,0);logBox.BackgroundTransparency=.2;logBox.TextColor3=Color3.fromRGB(180,245,190);logBox.Font=Enum.Font.Code;logBox.TextSize=10;logBox.TextXAlignment=Enum.TextXAlignment.Left;logBox.TextYAlignment=Enum.TextYAlignment.Top;logBox.TextWrapped=true;logBox.ClipsDescendants=true
home.MouseButton1Click:Connect(function()local _,r=hr();if r then S.home=r.Position;say(string.format("HOME=(%.0f,%.0f,%.0f) — ออกไปไกลแล้วทดสอบ",r.Position.X,r.Position.Y,r.Position.Z))end end)
normal.MouseButton1Click:Connect(function()task.spawn(run,"WALK","WALK")end);push.MouseButton1Click:Connect(function()task.spawn(run,"PUSH","PUSH")end);hop.MouseButton1Click:Connect(function()task.spawn(run,"PUSH+HOP","HOP")end);halt.MouseButton1Click:Connect(function()S.run=false;stop();say("STOP")end);copy.MouseButton1Click:Connect(function()local c=setclipboard or toclipboard;if c then pcall(c,"=== Egg01 Motion Lab v1.0 ===\n"..table.concat(S.lines,"\n"));copy.Text="OK";task.delay(1,function()if copy.Parent then copy.Text="COPY"end end)end end)
say("HOME → ออกไปไกล → WALK/PUSH/PUSH+HOP | ทุก test คืนแรงผลักเมื่อจบ")
