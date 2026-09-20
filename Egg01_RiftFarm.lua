-- Egg01 Rift Farm v1.3 -- ยืนยัน Prompt ด้วยชื่อ/UID ก่อน Steal
if _G.EGG01_RIFT_FARM then _G.EGG01_RIFT_FARM.run=false; pcall(function() _G.EGG01_RIFT_FARM.gui:Destroy() end) end
local P=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local LP=P.LocalPlayer; local fp=fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local S={run=false,home=nil,gui=nil,carrying=false,carryConn=nil}; _G.EGG01_RIFT_FARM=S; local lines={}
local function say(x) lines[#lines+1]=x; if #lines>12 then table.remove(lines,1) end; if log then log.Text=table.concat(lines,"\n") end; warn("[RiftFarm] "..x) end
local function hr() local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart") end
local function net(n) for _,x in ipairs(RS:GetDescendants()) do if x.Name:find(n,1,true) then return x end end end
local function attachCarry()
 if S.carryConn then return true end
 local e=net("FieldEggCarry"); if not e or not (e:IsA("RemoteEvent") or e:IsA("UnreliableRemoteEvent")) then return false end
 S.carryConn=e.OnClientEvent:Connect(function(row) if typeof(row)=="table" and row.IsCarrying~=nil then S.carrying=row.IsCarrying==true end end); return true
end
local function pos(r) for _,k in ipairs({"BottomCFrame","BoundsCFrame","CFrame","Position"}) do local v=r[k]; if typeof(v)=="CFrame" then return v.Position elseif typeof(v)=="Vector3" then return v end end end
-- ไม่มีตัวกรอง Rarity: Rift ต้องการชื่อใดก็หาได้หมด แม้เป็น Common/Rare
local function norm(s) return tostring(s or ""):lower():gsub("[^%w]", "") end
local function rowNames(row)
 local out={}
 for _,k in ipairs({"AssetCategory","AssetName","Name","EggType","Type","AssetId"}) do
  local v=row and row[k]; if v~=nil then out[#out+1]=tostring(v) end
 end
 local c=row and row.Config
 if typeof(c)=="table" then for _,k in ipairs({"AssetCategory","AssetName","Name","Id","_id"}) do if c[k]~=nil then out[#out+1]=tostring(c[k]) end end end
 return out
end
local function wanted()
 local root=LP.PlayerGui:FindFirstChild("RiftTradeIn",true); root=root and root:FindFirstChild("SacrificeInputs",true)
 if not root then say("เปิดหน้า Rift ก่อนเพื่ออ่าน 3 เป้า") return end
 local out={}; for i=1,3 do local box=root:FindFirstChild("Input"..i); local e=box and box:FindFirstChild("Empty"); local n=e and e:FindFirstChild("Name"); local a=e and e:FindFirstChild("Amount"); if n and a and a.Text=="0/1" then out[#out+1]=n.Text end end
 if #out==0 then say("Rift ครบ 3 ตัวแล้ว — รอคุณ STOP") return {} end; return out
end
local prompts,worldTarget
local function target()
 local need=wanted(); if not need or #need==0 then return end
 local rf=net("AskFieldEggSnapshot"); if not rf or not rf:IsA("RemoteFunction") then say("ไม่พบ Snapshot") return end
 local ok,a=pcall(function() return rf:InvokeServer() end); local rec=ok and (a.Records or a.records or a); local _,root=hr(); if typeof(rec)~="table" or not root then return end
 local best; local total,withPos=0,0
 for id,row in pairs(rec) do
  if typeof(row)=="table" then
   total=total+1; local p=pos(row); if p then withPos=withPos+1 end
   local cat=tostring(row.AssetCategory or row.AssetName or row.Name or "?"); local wantedName=false
   for _,n in ipairs(need) do
    local want=norm(n)
    for _,candidate in ipairs(rowNames(row)) do
     local got=norm(candidate)
     -- Rift ต้องใช้ชื่อเต็มตรงกันเท่านั้น: ห้ามเดาจากคำร่วม เช่น "frog"
     if got==want then wantedName=n; break end
    end
    if wantedName then break end
   end
   if p and wantedName and tostring(row.State or "")~="Carried" then
    local d=(p-root.Position).Magnitude
    if not best or d<best.d then best={uid=row.Uid or id,cat=cat,need=wantedName,pos=p,d=d} end
   end
  end
 end
 if not best and worldTarget then best=worldTarget(need,root) end
 if best then say(string.format("RIFT NEED %s d=%.0f%s (ไม่ล็อก rarity)",best.need,best.d,best.world and " [world]" or "")) else say(string.format("ยังไม่เจอ: %s | Snapshot=%d pos=%d | ไม่ล็อก rarity",table.concat(need,", "),total,withPos)) end; return best
end
prompts=function() local o={}; for _,x in ipairs(workspace:GetDescendants()) do if x:IsA("ProximityPrompt") and x.Enabled and tostring(x.ActionText):lower():find("steal",1,true) then local q=x.Parent and (x.Parent:IsA("BasePart") and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart",true)); if q then o[#o+1]={p=x,pos=q.Position} end end end; return o end
worldTarget=function(need,root)
 local best
 for _,v in ipairs(prompts()) do
  local words={}; local node=v.p.Parent
  for _=1,5 do if not node then break end; words[#words+1]=node.Name; for _,d in ipairs(node:GetDescendants()) do if d:IsA("TextLabel") or d:IsA("TextButton") then words[#words+1]=d.Text elseif d:IsA("StringValue") then words[#words+1]=d.Value end end; node=node.Parent end
  for _,want in ipairs(need) do for _,word in ipairs(words) do if norm(word)==norm(want) then local dist=(v.pos-root.Position).Magnitude; if not best or dist<best.d then best={need=want,cat=want,pos=v.pos,d=dist,world=true,worldPrompt=v.p} end; break end end end
 end
 return best
end
local function walk(p,rad,lim) local t=os.clock(); while S.run and os.clock()-t<lim do local h,r=hr(); if not h or not r then return end; local g=Vector3.new(p.X,r.Position.Y,p.Z); if (g-r.Position).Magnitude<=rad then return true end; h:MoveTo(g); task.wait(.15) end end
local function stop() local h,r=hr(); if h and r then h:MoveTo(r.Position); h:Move(Vector3.zero) end end
local function refreshTarget(t)
 if not t.uid then return true end
 local rf=net("AskFieldEggSnapshot"); if not rf or not rf:IsA("RemoteFunction") then return false end
 local ok,a=pcall(function() return rf:InvokeServer() end); local rec=ok and (a.Records or a.records or a)
 if typeof(rec)~="table" then return false end
 for id,row in pairs(rec) do
  if typeof(row)=="table" and tostring(row.Uid or id)==tostring(t.uid) and tostring(row.State or "")~="Carried" then
   local p=pos(row); if p then t.pos=p; return true end
  end
 end
 return false
end
local function promptProof(pp,t)
 if pp==t.worldPrompt then return true,"world-name" end
 local want,uid=norm(t.need),t.uid and tostring(t.uid) or nil
 local node=pp.Parent
 for _=1,5 do
  if not node or node==workspace then break end
  local values={node.Name}
  for _,k in ipairs({"Uid","UID","EggUid","AssetCategory","AssetName","Name"}) do local v=node:GetAttribute(k); if v~=nil then values[#values+1]=tostring(v) end end
  for _,d in ipairs(node:GetDescendants()) do
   if d:IsA("TextLabel") or d:IsA("TextButton") then values[#values+1]=d.Text elseif d:IsA("StringValue") then values[#values+1]=d.Value end
   for _,k in ipairs({"Uid","UID","EggUid","AssetCategory","AssetName"}) do local v=d:GetAttribute(k); if v~=nil then values[#values+1]=tostring(v) end end
  end
  for _,v in ipairs(values) do if norm(v)==want then return true,"name" end; if uid and tostring(v)==uid then return true,"uid" end end
  node=node.Parent
 end
 return false,nil
end
local function one(t)
 if not refreshTarget(t) then say("UID เป้าหมายหาย/เปลี่ยน — ไม่หยิบ") return end
 if not walk(t.pos,6,90) then say("ไป Rift egg ไม่สำเร็จ") return end; stop()
 if not refreshTarget(t) then say("UID เป้าหมายหายหลังเดินถึง — ไม่หยิบ") return end
 local _,me=hr(); local pick,md,proof=nil,nil,nil
 for _,v in ipairs(prompts()) do
  local d=(v.pos-t.pos).Magnitude; local near=me and (v.pos-me.Position).Magnitude or math.huge; local ok,why=promptProof(v.p,t)
  if d<=9 and near<=12 and ok and (not md or d<md) then pick,md,proof=v.p,d,why end
 end
 if not pick then say("ไม่ยืนยัน Prompt ตรงชื่อ/UID ของ "..t.need.." — ไม่หยิบ") return end
 say(string.format("Prompt ยืนยัน %s match=%.1f — Steal",proof,md)); S.carrying=false; pcall(function() local old=pick.HoldDuration; pick.HoldDuration=0; fp(pick); pick.HoldDuration=old end)
 local untilT=os.clock()+2; while S.run and os.clock()<untilT and not S.carrying do task.wait(.05) end
 if not S.carrying then say("Steal ยังไม่ยืนยันถือไข่ — ไม่วิ่งกลับ") return end
 say("ถือไข่แล้ว — กลับ HOME"); if S.home then walk(S.home,60,120); stop(); say("กลับ HOME") else say("เก็บแล้ว — ไม่มี HOME จึงหยุด") end
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_RiftFarm"; gui.ResetOnSpawn=false; pcall(function()gui.Parent=(gethui and gethui())or game:GetService("CoreGui")end); if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end; S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,360,0,185); f.Position=UDim2.new(0,12,.45,0); f.BackgroundColor3=Color3.fromRGB(25,15,40); f.BorderSizePixel=0; f.Active=true; f.Draggable=true; Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-78,0,28); title.Position=UDim2.new(0,10,0,4); title.BackgroundTransparency=1; title.Text="Egg01 Rift Farm v1.3 — VERIFY PROMPT"; title.TextColor3=Color3.fromRGB(220,170,255); title.Font=Enum.Font.GothamBold; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left
local function b(tx,x,col) local z=Instance.new("TextButton",f); z.Size=UDim2.new(0,62,0,28); z.Position=UDim2.new(0,x,0,36); z.Text=tx; z.BackgroundColor3=col; z.TextColor3=Color3.new(1,1,1); z.BorderSizePixel=0; z.Font=Enum.Font.GothamBold; z.TextSize=11; Instance.new("UICorner",z).CornerRadius=UDim.new(0,5); return z end
local home=b("HOME",10,Color3.fromRGB(50,100,180)); local scan=b("SCAN",78,Color3.fromRGB(50,100,180)); local start=b("START",146,Color3.fromRGB(35,145,75)); local halt=b("STOP",214,Color3.fromRGB(165,50,55)); local copy=b("COPY",282,Color3.fromRGB(75,75,80))
local fold=b("−",292,Color3.fromRGB(85,65,115)); local close=b("X",326,Color3.fromRGB(145,50,65)); fold.Size=UDim2.new(0,28,0,24); fold.Position=UDim2.new(0,292,0,4); close.Size=UDim2.new(0,28,0,24); close.Position=UDim2.new(0,326,0,4)
log=Instance.new("TextLabel",f); log.Size=UDim2.new(1,-16,0,105); log.Position=UDim2.new(0,8,0,72); log.BackgroundTransparency=.2; log.BackgroundColor3=Color3.new(0,0,0); log.TextColor3=Color3.fromRGB(180,245,190); log.Font=Enum.Font.Code; log.TextSize=10; log.TextXAlignment=Enum.TextXAlignment.Left; log.TextYAlignment=Enum.TextYAlignment.Top; log.TextWrapped=true; log.ClipsDescendants=true
local folded=false; fold.MouseButton1Click:Connect(function() folded=not folded; f.Size=UDim2.new(0,360,0,folded and 32 or 185); for _,v in ipairs({home,scan,start,halt,copy,log}) do v.Visible=not folded end; fold.Text=folded and "+" or "−" end); close.MouseButton1Click:Connect(function()S.run=false;gui:Destroy();_G.EGG01_RIFT_FARM=nil end)
attachCarry(); home.MouseButton1Click:Connect(function() local _,r=hr(); if r then S.home=r.Position;say("HOME ตั้งแล้ว")end end); scan.MouseButton1Click:Connect(target); start.MouseButton1Click:Connect(function() if S.run then return end; if not fp then say("ไม่มี fireproximityprompt") return end; S.run=true; start.Text="AUTO"; say("RIFT AUTO ON — เก็บตาม 3 ชื่อใน UI") task.spawn(function() while S.run do local t=target(); if t then one(t);task.wait(1) else task.wait(2) end end; start.Text="START" end) end); halt.MouseButton1Click:Connect(function()S.run=false;stop();say("STOP")end); copy.MouseButton1Click:Connect(function()local c=setclipboard or toclipboard;if c then pcall(c,"=== Egg01 Rift Farm v1.3 ===\n"..table.concat(lines,"\n"))end end)
say("เปิด Rift → HOME → START | เก็บเฉพาะ 3 ตัวที่ Rift ขอ")
