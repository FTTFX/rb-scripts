-- Egg01 Rift Farm v1.0 -- เฉพาะไข่ที่ชื่อ/Category มี Rift ใน FieldEggSnapshot
if _G.EGG01_RIFT_FARM then _G.EGG01_RIFT_FARM.run=false; pcall(function() _G.EGG01_RIFT_FARM.gui:Destroy() end) end
local P=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local LP=P.LocalPlayer; local fp=fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local S={run=false,home=nil,gui=nil}; _G.EGG01_RIFT_FARM=S; local lines={}
local function say(x) lines[#lines+1]=x; if #lines>35 then table.remove(lines,1) end; if log then log.Text=table.concat(lines,"\n") end; warn("[RiftFarm] "..x) end
local function hr() local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart") end
local function net(n) for _,x in ipairs(RS:GetDescendants()) do if x.Name:find(n,1,true) then return x end end end
local function pos(r) for _,k in ipairs({"BottomCFrame","BoundsCFrame","CFrame","Position"}) do local v=r[k]; if typeof(v)=="CFrame" then return v.Position elseif typeof(v)=="Vector3" then return v end end end
local function rift(r) for _,k in ipairs({"AssetCategory","AssetId","AssetName","Name","EggType","Type"}) do if tostring(r[k]or""):lower():find("rift",1,true) then return true end end end
local function wanted()
 local root=LP.PlayerGui:FindFirstChild("RiftTradeIn",true); root=root and root:FindFirstChild("SacrificeInputs",true)
 if not root then say("เปิดหน้า Rift ก่อนเพื่ออ่าน 3 เป้า") return end
 local out={}; for i=1,3 do local box=root:FindFirstChild("Input"..i); local e=box and box:FindFirstChild("Empty"); local n=e and e:FindFirstChild("Name"); local a=e and e:FindFirstChild("Amount"); if n and a and a.Text=="0/1" then out[#out+1]=n.Text end end
 if #out==0 then say("Rift ครบ 3 ตัวแล้ว — รอคุณ STOP") return {} end; return out
end
local function target()
 local need=wanted(); if not need or #need==0 then return end
 local rf=net("AskFieldEggSnapshot"); if not rf or not rf:IsA("RemoteFunction") then say("ไม่พบ Snapshot") return end
 local ok,a=pcall(function() return rf:InvokeServer() end); local rec=ok and (a.Records or a.records or a); local _,root=hr(); if typeof(rec)~="table" or not root then return end
 local best; for id,row in pairs(rec) do local p=typeof(row)=="table" and pos(row); local cat=tostring(row and (row.AssetCategory or row.AssetName) or ""); local wantedName=false; for _,n in ipairs(need) do if cat:lower()==n:lower() then wantedName=n end end; if p and wantedName and row.State~="Carried" then local d=(p-root.Position).Magnitude; if not best or d<best.d then best={uid=row.Uid or id,cat=cat,need=wantedName,pos=p,d=d} end end end
 if best then say(string.format("RIFT NEED %s d=%.0f",best.need,best.d)) else say("ยังไม่เจอไข่: "..table.concat(need,", ")) end; return best
end
local function prompts() local o={}; for _,x in ipairs(workspace:GetDescendants()) do if x:IsA("ProximityPrompt") and x.Enabled and tostring(x.ActionText):lower():find("steal",1,true) then local q=x.Parent and (x.Parent:IsA("BasePart") and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart",true)); if q then o[#o+1]={p=x,pos=q.Position} end end end; return o end
local function walk(p,rad,lim) local t=os.clock(); while S.run and os.clock()-t<lim do local h,r=hr(); if not h or not r then return end; local g=Vector3.new(p.X,r.Position.Y,p.Z); if (g-r.Position).Magnitude<=rad then return true end; h:MoveTo(g); task.wait(.15) end end
local function stop() local h,r=hr(); if h and r then h:MoveTo(r.Position); h:Move(Vector3.zero) end end
local function one(t)
 if not walk(t.pos,8,90) then say("ไป Rift egg ไม่สำเร็จ") return end; stop()
 local pick,md; for _,v in ipairs(prompts()) do local d=(v.pos-t.pos).Magnitude; if d<30 and (not md or d<md) then pick,md=v,d end end
 if not pick then say("Rift egg มีใน Snapshot แต่ไม่พบ Prompt") return end
 say(string.format("Rift Prompt match=%.1f — Steal",md)); pcall(function() local old=pick.p.HoldDuration; pick.p.HoldDuration=0; fp(pick.p); pick.p.HoldDuration=old end)
 task.wait(.35); if S.home then walk(S.home,60,120); stop(); say("กลับ HOME") else say("เก็บแล้ว — ไม่มี HOME จึงหยุด") end
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_RiftFarm"; gui.ResetOnSpawn=false; pcall(function()gui.Parent=(gethui and gethui())or game:GetService("CoreGui")end); if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end; S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,360,0,185); f.Position=UDim2.new(0,12,.45,0); f.BackgroundColor3=Color3.fromRGB(25,15,40); f.BorderSizePixel=0; Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-40,0,28); title.Position=UDim2.new(0,10,0,4); title.BackgroundTransparency=1; title.Text="Egg01 Rift Farm v1.0 — RIFT ONLY"; title.TextColor3=Color3.fromRGB(220,170,255); title.Font=Enum.Font.GothamBold; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left
local function b(tx,x,col) local z=Instance.new("TextButton",f); z.Size=UDim2.new(0,62,0,28); z.Position=UDim2.new(0,x,0,36); z.Text=tx; z.BackgroundColor3=col; z.TextColor3=Color3.new(1,1,1); z.BorderSizePixel=0; z.Font=Enum.Font.GothamBold; z.TextSize=11; Instance.new("UICorner",z).CornerRadius=UDim.new(0,5); return z end
local home=b("HOME",10,Color3.fromRGB(50,100,180)); local scan=b("SCAN",78,Color3.fromRGB(50,100,180)); local start=b("START",146,Color3.fromRGB(35,145,75)); local halt=b("STOP",214,Color3.fromRGB(165,50,55)); local copy=b("COPY",282,Color3.fromRGB(75,75,80))
log=Instance.new("TextLabel",f); log.Size=UDim2.new(1,-16,0,105); log.Position=UDim2.new(0,8,0,72); log.BackgroundTransparency=.2; log.BackgroundColor3=Color3.new(0,0,0); log.TextColor3=Color3.fromRGB(180,245,190); log.Font=Enum.Font.Code; log.TextSize=10; log.TextXAlignment=Enum.TextXAlignment.Left; log.TextYAlignment=Enum.TextYAlignment.Top
home.MouseButton1Click:Connect(function() local _,r=hr(); if r then S.home=r.Position;say("HOME ตั้งแล้ว")end end); scan.MouseButton1Click:Connect(target); start.MouseButton1Click:Connect(function() if S.run then return end; if not fp then say("ไม่มี fireproximityprompt") return end; S.run=true; start.Text="AUTO"; say("RIFT AUTO ON — รอเฉพาะ Rift egg") task.spawn(function() while S.run do local t=target(); if t then one(t);task.wait(1) else task.wait(2) end end; start.Text="START" end) end); halt.MouseButton1Click:Connect(function()S.run=false;stop();say("STOP")end); copy.MouseButton1Click:Connect(function()local c=setclipboard or toclipboard;if c then pcall(c,"=== Egg01 Rift Farm v1.0 ===\n"..table.concat(lines,"\n"))end end)
say("เปิด Rift → HOME → START | เก็บเฉพาะ 3 ตัวที่ Rift ขอ")
