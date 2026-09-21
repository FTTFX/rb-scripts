-- Egg01 Rift Farm v1.16 -- จับชื่อหลวม: สลับคำได้ + อักษรเหมือน ≥5 + ไม่สน rarity
if _G.EGG01_RIFT_FARM then _G.EGG01_RIFT_FARM.run=false; pcall(function() _G.EGG01_RIFT_FARM.carryConn:Disconnect() end); pcall(function() _G.EGG01_RIFT_FARM.shiftConn:Disconnect() end); pcall(function() _G.EGG01_RIFT_FARM.gui:Destroy() end) end
local P=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local RunS=game:GetService("RunService"); local LP=P.LocalPlayer; local fp=fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local S={run=false,home=nil,gui=nil,carrying=false,carryConn=nil,shiftConn=nil,live={},expectedUid=nil,carryVerified=false,carryMismatch=false,lastMiss=nil,hunt=nil}; _G.EGG01_RIFT_FARM=S; local lines={}
local function say(x) lines[#lines+1]=x; if #lines>12 then table.remove(lines,1) end; if log then log.Text=table.concat(lines,"\n") end; warn("[RiftFarm] "..x) end
local function hr() local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart") end
local function net(n) for _,x in ipairs(RS:GetDescendants()) do if x.Name:find(n,1,true) then return x end end end
local function attachCarry()
 if S.carryConn then return true end
 local e=net("FieldEggCarry"); if not e or not (e:IsA("RemoteEvent") or e:IsA("UnreliableRemoteEvent")) then return false end
 S.carryConn=e.OnClientEvent:Connect(function(row)
  if typeof(row)~="table" or row.IsCarrying==nil then return end
  S.carrying=row.IsCarrying==true
  if S.carrying and S.expectedUid then
   if row.Uid and tostring(row.Uid)==tostring(S.expectedUid) then
    S.carryVerified=true
   elseif row.Uid then
    S.carryMismatch=true; say("ถือ UID อื่น: "..tostring(row.Uid).." — หยุด AUTO")
    S.run=false
   else
    say("ถือไข่แล้ว แต่ server ไม่ส่ง UID — ยังไม่ยืนยันเป้า")
   end
  end
 end); return true
end
local function pos(r) for _,k in ipairs({"BottomCFrame","BoundsCFrame","CFrame","Position"}) do local v=r[k]; if typeof(v)=="CFrame" then return v.Position elseif typeof(v)=="Vector3" then return v end end end
-- ไม่มีตัวกรอง Rarity: Rift ต้องการชื่อใดก็หาได้หมด แม้เป็น Common/Rare
local RAR={common=true,uncommon=true,rare=true,epic=true,legendary=true,mythic=true,cosmic=true,secret=true,eternal=true,divine=true}
local function norm(s) return tostring(s or ""):lower():gsub("[^%w]", "") end
local function nameKey(s) local k=norm(s); return (k:gsub("eggs?$","")) end
local function wordsOf(s)
 local words={}
 for w in tostring(s or ""):lower():gmatch("%a+") do
  w=w:gsub("eggs?$","")
  if #w>=2 and not RAR[w] then words[#words+1]=w end
 end
 table.sort(words)
 return words,table.concat(words)
end
local function lcs(a,b)
 local n,m=#a,#b
 if n==0 or m==0 or n>48 or m>48 then return 0 end
 local prev={}; for j=0,m do prev[j]=0 end
 local best=0
 for i=1,n do
  local cur={[0]=0}
  local ai=a:sub(i,i)
  for j=1,m do
   if ai==b:sub(j,j) then cur[j]=(prev[j-1] or 0)+1; if cur[j]>best then best=cur[j] end
   else cur[j]=0 end
  end
  prev=cur
 end
 return best
end
-- คะแนน: 100 ตรง, ≥45 = หลวม (คำสลับ / อักษรติดกัน ≥5) ไม่สนระดับ
local function matchScore(need,cand)
 local wa,ka=wordsOf(need)
 local wb,kb=wordsOf(cand)
 if ka=="" or kb=="" then return 0 end
 if ka==kb or nameKey(need)==nameKey(cand) then return 100 end
 local score=0
 for _,w in ipairs(wa) do
  if #w>=4 and (kb:find(w,1,true) or nameKey(cand):find(w,1,true)) then score=math.max(score,60+#w) end
 end
 for _,w in ipairs(wb) do
  if #w>=4 and (ka:find(w,1,true) or nameKey(need):find(w,1,true)) then score=math.max(score,60+#w) end
 end
 local c=math.max(lcs(ka,kb), lcs(nameKey(need), nameKey(cand)))
 if c>=5 then score=math.max(score,40+c) end
 return score
end
local function amountNeeds(a)
 if not a then return false end
 local t=tostring(a.Text or ""):gsub("%s+",""):lower()
 return t=="0/1" or t:match("^0/")~=nil
end
local function rowNames(row)
 local out={}
 for _,k in ipairs({"AssetCategory","AssetName","Name","EggType","Type","AssetId","DisplayName"}) do
  local v=row and row[k]; if v~=nil then out[#out+1]=tostring(v) end
 end
 local c=row and row.Config
 if typeof(c)=="table" then for _,k in ipairs({"AssetCategory","AssetName","Name","Id","_id","DisplayName"}) do if c[k]~=nil then out[#out+1]=tostring(c[k]) end end end
 return out
end
local function rowMatchesNeed(row,needList)
 local bestN,bestS,bestC=nil,0,nil
 for _,n in ipairs(needList) do
  for _,candidate in ipairs(rowNames(row)) do
   local s=matchScore(n,candidate)
   if s>bestS then bestN,bestS,bestC=n,s,candidate end
  end
 end
 if bestS>=45 then return bestN,bestS,bestC end
end
local function findLabel(box,name)
 if not box then return end
 local hit=box:FindFirstChild(name,true)
 if hit and (hit:IsA("TextLabel") or hit:IsA("TextButton") or hit:IsA("TextBox")) then return hit end
end
local function wanted()
 local root=LP.PlayerGui:FindFirstChild("RiftTradeIn",true); root=root and root:FindFirstChild("SacrificeInputs",true)
 if not root then say("เปิดหน้า Rift ก่อนเพื่ออ่าน 3 เป้า") return end
 local out={}
 for i=1,3 do
  local box=root:FindFirstChild("Input"..i)
  local empty=box and box:FindFirstChild("Empty")
  local n=findLabel(empty,"Name") or findLabel(box,"Name")
  local a=findLabel(empty,"Amount") or findLabel(box,"Amount")
  local txt=n and tostring(n.Text or ""):gsub("^%s+",""):gsub("%s+$","") or ""
  if txt~="" and amountNeeds(a) then out[#out+1]=txt end
 end
 if #out==0 then say("Rift ครบ 3 ตัวแล้ว (หรืออ่าน Amount/Name ไม่ได้) — รอ STOP / เปิด Rift ใหม่") return {} end
 return out
end
local function attachShift()
 if S.shiftConn then return true end
 local e=net("FieldEggShifted"); if not e or not (e:IsA("RemoteEvent") or e:IsA("UnreliableRemoteEvent")) then return false end
 S.shiftConn=e.OnClientEvent:Connect(function(row)
  if typeof(row)~="table" then return end
  local uid=row.Uid and tostring(row.Uid)
  if not uid then return end
  if tostring(row.State or "")=="Carried" then S.live[uid]=nil; return end
  local p=pos(row)
  if p then S.live[uid]={uid=uid,row=row,pos=p,t=os.clock(),area=row.AreaId} end
 end); return true
end
-- ไข่หายากเกิดเฉพาะไบโอม — Snapshot ไม่มีชนิด ≠ บั๊กชื่อ
local NEED_BIOME={
 spideron="Titan Temple",bladehide="Titan Temple",crustacia="Titan Temple",mantaris="Titan Temple",
 rhinotaur="Titan Temple",mutantshark="Titan Temple",gorillaking="Titan Temple",nightflame="Titan Temple",
 redpanda="Cherry Blossom",crane="Cherry Blossom",salamander="Cherry Blossom",snowowl="Cherry Blossom",
 koi="Cherry Blossom",stag="Cherry Blossom",onitiger="Cherry Blossom",kitsune="Cherry Blossom",
}
local function biomeForNeed(n) return NEED_BIOME[nameKey(n)] end
local function findGuardBiome(areaName)
 if not areaName then return end
 local areas=workspace:FindFirstChild("__OBJECTS"); areas=areas and areas:FindFirstChild("Areas")
 local guards=areas and areas:FindFirstChild("GuardAreas"); if not guards then return end
 local want=tostring(areaName):lower()
 local hit=guards:FindFirstChild(areaName); if hit then return hit end
 for _,c in ipairs(guards:GetChildren()) do
  local n=c.Name:lower()
  if n==want or n:find(want,1,true) or want:find(n,1,true) then return c end
 end
end
local function biomeHubPos(areaName)
 local biome=findGuardBiome(areaName)
 if not biome then return end
 for _,nm in ipairs({"Guard","Nests","RequiredSpeedSign"}) do
  local node=biome:FindFirstChild(nm,true)
  if node then
   if node:IsA("Model") then local ok,cf=pcall(function()return node:GetPivot()end); if ok and cf then return cf.Position,areaName.."."..nm end end
   if node:IsA("BasePart") then return node.Position,areaName.."."..nm end
   local p=node:FindFirstChildWhichIsA("BasePart",true); if p then return p.Position,areaName.."."..nm end
  end
 end
 local ok,cf=pcall(function()return biome:GetPivot()end); if ok and cf then return cf.Position,areaName end
end
local function proxyPosFromSnapshot(byUid,areaName,rootPos)
 local want=tostring(areaName or ""):lower(); if want=="" then return end
 local best,bestD
 for _,row in pairs(byUid) do
  if typeof(row)=="table" then
   local area=tostring(row.AreaId or ""):lower()
   if area~="" and (area==want or area:find(want,1,true) or want:find(area,1,true)) then
    local p=pos(row) or (S.live[tostring(row.Uid or "")] and S.live[tostring(row.Uid)].pos)
    if p then local d=(p-rootPos).Magnitude; if not best or d<bestD then best,bestD=p,d end end
   end
  end
 end
 if best then return best,areaName.." nest" end
end
local prompts
local function target()
 local need=wanted(); if not need or #need==0 then return end
 attachShift()
 local rf=net("AskFieldEggSnapshot"); if not rf or not rf:IsA("RemoteFunction") then say("ไม่พบ Snapshot") return end
 local ok,a=pcall(function() return rf:InvokeServer() end); local rec=ok and (a.Records or a.records or a); local _,root=hr(); if typeof(rec)~="table" or not root then return end
 local byUid={}
 for id,row in pairs(rec) do
  if typeof(row)=="table" then byUid[tostring(row.Uid or id)]=row end
 end
 for uid,live in pairs(S.live) do
  if os.clock()-(live.t or 0)>90 then S.live[uid]=nil
  elseif not byUid[uid] and live.row then byUid[uid]=live.row end
 end
 local best; local total,withPos,nameHit,nameNoPos=0,0,0,0
 local areasNeeded,areaSeen={},{}
 for _,n in ipairs(need) do local b=biomeForNeed(n); if b and not areaSeen[b] then areaSeen[b]=true; areasNeeded[#areasNeeded+1]=b end end
 for id,row in pairs(byUid) do
  if typeof(row)=="table" then
   total=total+1
   local live=S.live[tostring(row.Uid or id)]
   local p=pos(row) or (live and live.pos)
   if p then withPos=withPos+1 end
   local wantedName,score,via=rowMatchesNeed(row,need)
   if wantedName then
    nameHit=nameHit+1
    if not p or tostring(row.State or "")=="Carried" then nameNoPos=nameNoPos+1
    else
     local d=(p-root.Position).Magnitude
     if not best or score>best.score or (score==best.score and d<best.d) then
      best={uid=row.Uid or id,cat=tostring(row.AssetCategory or "?"),need=wantedName,pos=p,d=d,score=score,via=via}
     end
    end
   end
  end
 end
 if best then
  S.lastMiss=nil; S.hunt=nil
  local loose=(best.score or 100)<100 and ("≈"..tostring(best.via or best.cat).." ") or ""
  say(string.format("RIFT NEED %s %sUID=%s d=%.0f",best.need,loose,tostring(best.uid),best.d))
  return best
 end
 -- ไม่มีชนิดในฟิลด์ → ไปไบโอมที่ไข่เกิด แล้วรอสปอว์น
 local huntArea=areasNeeded[1]
 local hub,hubLabel
 if huntArea then
  hub,hubLabel=biomeHubPos(huntArea)
  if not hub then hub,hubLabel=proxyPosFromSnapshot(byUid,huntArea,root.Position) end
 end
 local tip
 if nameHit>0 then tip=string.format("ชื่อตรง=%d แต่ไม่มีพิกัด/Carried=%d",nameHit,nameNoPos)
 elseif huntArea then tip="ไม่มีในฟิลด์ → ไป "..huntArea..(hub and (" @"..tostring(hubLabel)) or " (ยังไม่เจอ Guard)")
 else tip="ไม่มีใน Snapshot ตอนนี้"
 end
 local now=os.clock()
 if not S.lastMiss or now-(S.lastMiss or 0)>=6 then
  S.lastMiss=now
  say(string.format("ยังไม่เจอ: %s | snap=%d | %s",table.concat(need,", "),total,tip))
 end
 if hub and S.run then
  local d=(hub-root.Position).Magnitude
  if d>80 then
   S.hunt={pos=hub,area=huntArea,label=hubLabel}
   return {uid=nil,need="HUNT",pos=hub,d=d,hunt=true,area=huntArea,label=hubLabel}
  end
 end
end
local function huntBiome(t)
 if not t or not t.pos then return end
 say(string.format("ไปไบโอม %s (%s) d=%.0f — รอไข่สปอว์น",tostring(t.area or "?"),tostring(t.label or "?"),t.d or -1))
 if not walk(t.pos,40,180,90) then say("ไปไบโอมไม่สำเร็จ"); return end
 say("ถึงไบโอมแล้ว — สแกนซ้ำ 12s")
 local untilT=os.clock()+12
 while S.run and os.clock()<untilT do
  local hit=target()
  if hit and not hit.hunt then return hit end
  task.wait(1.2)
 end
end
prompts=function() local o={}; for _,x in ipairs(workspace:GetDescendants()) do if x:IsA("ProximityPrompt") and x.Enabled and tostring(x.ActionText):lower():find("steal",1,true) then local q=x.Parent and (x.Parent:IsA("BasePart") and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart",true)); if q then o[#o+1]={p=x,pos=q.Position} end end end; return o end
local function stop(label)
 local h,r=hr(); if not h or not r then return end
 h:MoveTo(r.Position); h:Move(Vector3.zero)
 -- MoveTo ยกเลิกคำสั่งเดินเท่านั้น แต่ inertia ยังเหลืออยู่: ล้าง velocity 3 heartbeat
 for _=1,3 do
  if not r.Parent then break end
  r.AssemblyLinearVelocity=Vector3.zero; r.AssemblyAngularVelocity=Vector3.zero
  RunS.Heartbeat:Wait()
 end
 if label then say(label) end
end
local function walk(p,rad,lim,slowNear)
 local t=os.clock(); local moveHum,oldSpeed,lastBand
 local function restore()
  if moveHum and moveHum.Parent then moveHum.WalkSpeed=oldSpeed end
 end
 while S.run and os.clock()-t<lim do
  local h,r=hr(); if not h or not r then restore(); return end
  local g=Vector3.new(p.X,r.Position.Y,p.Z); local d=(g-r.Position).Magnitude
  if d<=rad then restore(); stop(); return true end
  if slowNear then
   if not moveHum then moveHum=h; oldSpeed=h.WalkSpeed end
   local band,cap
   if d<=18 then band,cap="ละเอียด",35 elseif d<=slowNear then band,cap="ชะลอ",90 else band,cap="ปกติ",oldSpeed end
   h.WalkSpeed=math.min(oldSpeed,cap)
   if band~=lastBand and band~="ปกติ" then say(band.."ก่อนถึงไข่ — เหลือ "..math.floor(d).." studs") end
   lastBand=band
  end
  h:MoveTo(g); task.wait(.04)
 end
 restore()
end
local function waitPlaced()
 local deadline=os.clock()+12
 while S.run and S.carrying and os.clock()<deadline do task.wait(.10) end
 if S.carrying then say("ถึง HOME แต่ยังถือไข่ — รอวาง/ฟักก่อน ไม่หาใบถัดไป"); return false end
 say("วาง/ฟักเสร็จ — หา Rift เป้าถัดไป")
 return true
end
local function refreshTarget(t)
 if not t.uid then return true end
 local rf=net("AskFieldEggSnapshot"); if not rf or not rf:IsA("RemoteFunction") then return false end
 local ok,a=pcall(function() return rf:InvokeServer() end); local rec=ok and (a.Records or a.records or a)
 if typeof(rec)~="table" then return false end
 local uid=tostring(t.uid)
 for id,row in pairs(rec) do
  if typeof(row)=="table" and tostring(row.Uid or id)==uid and tostring(row.State or "")~="Carried" then
   local p=pos(row) or (S.live[uid] and S.live[uid].pos)
   if p then t.pos=p; return true end
  end
 end
 local live=S.live[uid]
 if live and live.pos then t.pos=live.pos; return true end
 return false
end
-- เลือก Steal ที่ใกล้พิกัดไข่ (UID) ที่สุด — ไม่บังคับ gap กับไข่ข้างๆ
local function choosePrompt(t)
 local _,me=hr(); if not me then return end
 local candidates={}
 for _,v in ipairs(prompts()) do
  local d=(v.pos-t.pos).Magnitude
  if d<=18 then candidates[#candidates+1]={p=v.p,pos=v.pos,d=d} end
 end
 table.sort(candidates,function(a,b)return a.d<b.d end)
 local a,b=candidates[1],candidates[2]
 if a and (a.pos-me.Position).Magnitude<=16 then
  return a.p,a.d,b and (b.d-a.d) or math.huge
 end
 local detail=a and string.format("pd=%.2f gap=%s player=%.1f",a.d,b and string.format("%.2f",b.d-a.d) or "-",(a.pos-me.Position).Magnitude) or "ไม่มี Prompt ใน 18"
 return nil,nil,nil,detail
end
local function tryCarryUid(uid)
 local rf=net("AskFieldEggCarry")
 if not rf or not rf:IsA("RemoteFunction") then return false,"no-RF" end
 local ok,res=pcall(function() return rf:InvokeServer({Uid=tostring(uid)}) end)
 return ok,res
end
local function fireSteal(pick)
 if not pick or not fp then return false end
 return pcall(function()
  local old=pick.HoldDuration
  pick.HoldDuration=0
  fp(pick)
  pick.HoldDuration=old
 end)
end
local function one(t)
 if not refreshTarget(t) then say("UID เป้าหมายหาย/เปลี่ยน — ไม่หยิบ") return end
 if not walk(t.pos,5,90,55) then say("ไป Rift egg ไม่สำเร็จ") return end
 if not refreshTarget(t) then say("UID เป้าหมายหายหลังเดินถึง — ไม่หยิบ") return end
 if not attachCarry() then say("ไม่พบ FieldEggCarry — ยังตรวจ UID หลังหยิบไม่ได้") return end
 S.expectedUid=t.uid; S.carrying=false; S.carryVerified=false; S.carryMismatch=false

 -- 1) ลอง RF ด้วย Uid ตรงๆ (ยืนใกล้พอ server มักรับ)
 say("ลอง RF AskFieldEggCarry Uid="..tostring(t.uid))
 local okRf=select(1,tryCarryUid(t.uid))
 local untilRf=os.clock()+1.2
 while S.run and os.clock()<untilRf and not S.carryVerified and not S.carryMismatch do task.wait(.05) end
 if S.carryMismatch then S.expectedUid=nil; return end
 if S.carryVerified then
  say("RF Uid สำเร็จ — ถือไข่เป้าแล้ว")
 else
  -- 2) fallback: fireproximityprompt ใกล้พิกัดไข่ (ไม่สน gap กับไข่ข้าง)
  local pick,md,gap,detail=choosePrompt(t)
  if not pick then
   for _,off in ipairs({Vector3.new(3,0,0),Vector3.new(-3,0,0),Vector3.new(0,0,3),Vector3.new(0,0,-3)}) do
    if walk(t.pos+off,2,2.5,10) then pick,md,gap,detail=choosePrompt(t); if pick then break end end
   end
  end
  if pick then
   local part=pick.Parent and (pick.Parent:IsA("BasePart") and pick.Parent or pick.Parent:FindFirstChildWhichIsA("BasePart",true))
   if part then walk(part.Position,3.2,6,14) end
   if not refreshTarget(t) then S.expectedUid=nil; say("UID หายก่อนยิง Prompt — ไม่หยิบ"); return end
   pick,md,gap,detail=choosePrompt(t)
   if pick then
    say(string.format("fp Steal ใกล้ไข่ pd=%.2f gap=%.2f",md or -1,gap or -1))
    fireSteal(pick)
    local untilT=os.clock()+2
    while S.run and os.clock()<untilT and not S.carryVerified and not S.carryMismatch do task.wait(.05) end
   else
    say("ไม่เจอ Prompt ใกล้ไข่ ("..tostring(detail)..") — ไม่หยิบ")
   end
  else
   say("RF ไม่ติด + ไม่เจอ Prompt ("..tostring(detail)..") — ไม่หยิบ")
  end
 end
 S.expectedUid=nil
 if S.carryMismatch then return end
 if not S.carryVerified then say("ยังไม่ยืนยันถือ UID เป้าหมาย — ไม่วิ่งกลับ") return end
 if S.home then
  local _,r=hr(); local d=r and (r.Position-S.home).Magnitude or -1
  say(string.format("ถือไข่แล้ว — กลับ HOME d=%.0f",d))
  local ok=walk(S.home,60,120)
  if ok then say("ถึง HOME — รอให้ไข่วาง/ฟัก"); waitPlaced() else say("กลับ HOME ไม่สำเร็จ") end
 else
  say("เก็บแล้ว — ไม่มี HOME จึงหยุด")
 end
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_RiftFarm"; gui.ResetOnSpawn=false; pcall(function()gui.Parent=(gethui and gethui())or game:GetService("CoreGui")end); if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end; S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,360,0,185); f.Position=UDim2.new(0,12,.45,0); f.BackgroundColor3=Color3.fromRGB(25,15,40); f.BorderSizePixel=0; f.Active=true; f.Draggable=true; Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-78,0,28); title.Position=UDim2.new(0,10,0,4); title.BackgroundTransparency=1; title.Text="Egg01 Rift Farm v1.16 — UID STEAL"; title.TextColor3=Color3.fromRGB(220,170,255); title.Font=Enum.Font.GothamBold; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left
local function b(tx,x,col) local z=Instance.new("TextButton",f); z.Size=UDim2.new(0,62,0,28); z.Position=UDim2.new(0,x,0,36); z.Text=tx; z.BackgroundColor3=col; z.TextColor3=Color3.new(1,1,1); z.BorderSizePixel=0; z.Font=Enum.Font.GothamBold; z.TextSize=11; Instance.new("UICorner",z).CornerRadius=UDim.new(0,5); return z end
local home=b("HOME",10,Color3.fromRGB(50,100,180)); local scan=b("SCAN",78,Color3.fromRGB(50,100,180)); local start=b("START",146,Color3.fromRGB(35,145,75)); local halt=b("STOP",214,Color3.fromRGB(165,50,55)); local copy=b("COPY",282,Color3.fromRGB(75,75,80))
local fold=b("−",292,Color3.fromRGB(85,65,115)); local close=b("X",326,Color3.fromRGB(145,50,65)); fold.Size=UDim2.new(0,28,0,24); fold.Position=UDim2.new(0,292,0,4); close.Size=UDim2.new(0,28,0,24); close.Position=UDim2.new(0,326,0,4)
log=Instance.new("TextLabel",f); log.Size=UDim2.new(1,-16,0,105); log.Position=UDim2.new(0,8,0,72); log.BackgroundTransparency=.2; log.BackgroundColor3=Color3.new(0,0,0); log.TextColor3=Color3.fromRGB(180,245,190); log.Font=Enum.Font.Code; log.TextSize=10; log.TextXAlignment=Enum.TextXAlignment.Left; log.TextYAlignment=Enum.TextYAlignment.Top; log.TextWrapped=true; log.ClipsDescendants=true
local folded=false; fold.MouseButton1Click:Connect(function() folded=not folded; f.Size=UDim2.new(0,360,0,folded and 32 or 185); for _,v in ipairs({home,scan,start,halt,copy,log}) do v.Visible=not folded end; fold.Text=folded and "+" or "−" end); close.MouseButton1Click:Connect(function()S.run=false;gui:Destroy();_G.EGG01_RIFT_FARM=nil end)
attachCarry(); attachShift(); home.MouseButton1Click:Connect(function() local _,r=hr(); if r then S.home=r.Position;say("HOME ตั้งแล้ว (ฐาน)")end end); scan.MouseButton1Click:Connect(target); start.MouseButton1Click:Connect(function() if S.run then return end; if not S.home then say("ยังไม่ได้ตั้ง HOME — ยืนที่ฐานแล้วกด HOME ก่อน AUTO"); return end; S.run=true; start.Text="AUTO"; say("RIFT AUTO ON — ไม่เจอชนิด → ไปไบโอมรอสปอว์น") task.spawn(function() while S.run do local t=target(); if t and t.hunt then huntBiome(t); task.wait(.5) elseif t then one(t);task.wait(1) else task.wait(2.5) end end; start.Text="START" end) end); halt.MouseButton1Click:Connect(function()S.run=false;stop();say("STOP")end); copy.MouseButton1Click:Connect(function()local c=setclipboard or toclipboard;if c then pcall(c,"=== Egg01 Rift Farm v1.16 ===\n"..table.concat(lines,"\n"))end end)
say("v1.16: ชื่อหลวม — สลับคำ / อักษร≥5 / ไม่สน rarity")
