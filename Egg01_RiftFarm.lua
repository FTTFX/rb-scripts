-- Egg01 Rift Farm v1.39 -- Shark=Finned Thresher alias | hop 30s
if _G.EGG01_RIFT_FARM then _G.EGG01_RIFT_FARM.run=false; pcall(function() _G.EGG01_RIFT_FARM.carryConn:Disconnect() end); pcall(function() _G.EGG01_RIFT_FARM.shiftConn:Disconnect() end); pcall(function() _G.EGG01_RIFT_FARM.clipConn:Disconnect() end); if _G.EGG01_RIFT_FARM.eggConns then for _,c in ipairs(_G.EGG01_RIFT_FARM.eggConns) do pcall(function() c:Disconnect() end) end end; pcall(function() if _G.EGG01_RIFT_FARM.tpFailConn then _G.EGG01_RIFT_FARM.tpFailConn:Disconnect() end end); pcall(function() _G.EGG01_RIFT_FARM.gui:Destroy() end) end
local P=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local RunS=game:GetService("RunService"); local TS=game:GetService("TeleportService"); local HS=game:GetService("HttpService"); local LP=P.LocalPlayer; local fp=fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
local REJOIN_AFTER=30
local RIFT_R,RIFT_DEPTH=6,-8
local FALLBACK_RIFT=Vector3.new(534.0,71.0,-340.0)
local S={run=false,home=nil,gui=nil,carrying=false,carryConn=nil,eggConns={},clipConn=nil,clipParts={},eggDB={},skip={},expectedUid=nil,carryVerified=false,carryMismatch=false,lastMiss=nil,hunt=nil,carrySpeed=nil,missSince=nil,hopping=false,tpFailConn=nil,rift=nil,hopJobs=nil,hopIdx=0,netCache={}}; _G.EGG01_RIFT_FARM=S; local lines={}
local function say(x) lines[#lines+1]=x; if #lines>12 then table.remove(lines,1) end; if log then log.Text=table.concat(lines,"\n") end; warn("[RiftFarm] "..x) end
local function hr() local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart") end
local function setClip(on)
 if not on then
  if S.clipConn then pcall(function() S.clipConn:Disconnect() end); S.clipConn=nil end
  for part,was in pairs(S.clipParts) do if part and part.Parent then pcall(function() part.CanCollide=was end) end end
  S.clipParts={}; return
 end
 if S.clipConn then return end
 local function apply(ch)
  if not ch then return end
  for _,p in ipairs(ch:GetDescendants()) do
   if p:IsA("BasePart") then
    if S.clipParts[p]==nil then S.clipParts[p]=p.CanCollide end
    p.CanCollide=false
   end
  end
 end
 apply(LP.Character)
 S.clipConn=RunS.Stepped:Connect(function() apply(LP.Character) end)
end
local function net(name, className)
 if not className and S.netCache[name]~=nil then return S.netCache[name] end
 local packages=RS:FindFirstChild("Packages")
 local networking=packages and packages:FindFirstChild("Networking")
 local exact,fuzzy
 for _,root in ipairs({networking,RS}) do
  if root then
   for _,item in ipairs(root:GetDescendants()) do
    if className and not item:IsA(className) then
     -- skip
    else
     local n=item.Name
     local isExact=(n==name) or (n:sub(-#name-1)=="/"..name)
     local isFuzzy=(not isExact) and n:find(name,1,true)
      and not n:find("Ask"..name,1,true)
      and not (name=="FieldEggCarry" and n:find("Ask",1,true))
     if isExact then exact=exact or item
     elseif isFuzzy then fuzzy=fuzzy or item end
    end
   end
  end
 end
 local hit=exact or fuzzy
 if not className then S.netCache[name]=hit end
 return hit
end
-- FieldEggCarry ต้องเป็น RE — ห้ามจับ AskFieldEggCarry (RF)
local function findCarryEvent()
 local packages=RS:FindFirstChild("Packages")
 local networking=packages and packages:FindFirstChild("Networking")
 if networking then
  for _,item in ipairs(networking:GetDescendants()) do
   if item:IsA("RemoteEvent") or item:IsA("UnreliableRemoteEvent") then
    local n=item.Name
    if n=="FieldEggCarry" or n:find("/FieldEggCarry",1,true)
     or (n:find("FieldEggCarry",1,true) and not n:find("Ask",1,true)) then
     return item
    end
   end
  end
 end
 return net("FieldEggCarry","RemoteEvent") or net("FieldEggCarry","UnreliableRemoteEvent")
end
local function lookingLikeCarry()
 local ch=LP.Character; if not ch then return false end
 for _,x in ipairs(ch:GetDescendants()) do
  local n=tostring(x.Name):lower()
  if (x:IsA("Tool") or x:IsA("Model") or x:IsA("BasePart")) and (n:find("egg",1,true) or n:find("carry",1,true)) then
   return true
  end
 end
 return false
end
local function attachCarry()
 if S.carryConn then return true end
 local e=findCarryEvent()
 if not e then return false end
 S.carryConn=e.OnClientEvent:Connect(function(row)
  if typeof(row)~="table" or row.IsCarrying==nil then return end
  S.carrying=row.IsCarrying==true
  if row.SpeedMultiplier~=nil then S.carrySpeed=tonumber(row.SpeedMultiplier) end
  if S.carrying and S.expectedUid then
   if row.Uid and tostring(row.Uid)==tostring(S.expectedUid) then
    S.carryVerified=true
   elseif row.Uid then
    S.carryMismatch=true
    say("ถือ UID อื่น: "..tostring(row.Uid).." — ข้ามไปเป้าอื่น")
   else
    S.carryVerified=true
    say("ถือไข่แล้ว (server ไม่ส่ง UID) — ถือว่าผ่าน")
   end
  elseif S.carrying and not S.expectedUid then
   S.carryVerified=true
  end
 end); say("ฟัง FieldEggCarry ✅ "..tostring(e.Name)); return true
end
local function skipUid(uid,sec)
 if not uid then return end
 S.skip[tostring(uid)]=os.clock()+(sec or 90)
end
local function isSkipped(uid)
 local t=S.skip[tostring(uid or "")]
 return t and os.clock()<t
end
local function tryDrop()
 local rf=net("AskFieldEggDrop")
 if rf and rf:IsA("RemoteFunction") then pcall(function() rf:InvokeServer({}) end); task.wait(0.35); return end
 if rf and rf:IsA("RemoteEvent") then pcall(function() rf:FireServer({}) end); task.wait(0.35) end
end
local function pos(r) for _,k in ipairs({"BottomCFrame","BoundsCFrame","CFrame","Position"}) do local v=r[k]; if typeof(v)=="CFrame" then return v.Position elseif typeof(v)=="Vector3" then return v end end end
local function upsert(row, uidHint)
 if typeof(row)~="table" then return false end
 local uid=row.Uid or uidHint; if not uid then return false end
 uid=tostring(uid)
 local e=S.eggDB[uid] or {uid=uid}
 if row.AssetCategory then e.cat=tostring(row.AssetCategory) end
 if row.AssetName then e.name=tostring(row.AssetName) end
 if row.AreaId then e.area=tostring(row.AreaId) end
 if row.State then e.state=tostring(row.State) end
 local p=pos(row); if p then e.pos=p end
 e.row=row; e.t=os.clock()
 S.eggDB[uid]=e
 return true
end
local function ingest(value)
 if typeof(value)~="table" then return 0 end
 local n=0
 local records=value.Records or value.records
 if typeof(records)=="table" then
  for k,row in pairs(records) do if upsert(row,typeof(k)=="string" and k or nil) then n=n+1 end end
  return n
 end
 if value[1] then
  for _,row in ipairs(value) do
   if typeof(row)=="table" and (row.Records or row.records) then n=n+ingest(row)
   elseif upsert(row) then n=n+1 end
  end
  return n
 end
 if upsert(value) then return 1 end
 for k,row in pairs(value) do if upsert(row,typeof(k)=="string" and k or nil) then n=n+1 end end
 return n
end
local function attachEggFeed()
 if #S.eggConns>0 then return true end
 local function bind(name,fn)
  local e=net(name)
  if e and (e:IsA("RemoteEvent") or e:IsA("UnreliableRemoteEvent")) then
   S.eggConns[#S.eggConns+1]=e.OnClientEvent:Connect(fn); return true
  end
 end
 bind("FieldEggShifted",function(row) upsert(row) end)
 bind("FieldEggBatchShifted",function(v) ingest(v) end)
 bind("FieldEggGone",function(row)
  local uid=typeof(row)=="table" and row.Uid or row
  if uid then S.eggDB[tostring(uid)]=nil end
 end)
 return #S.eggConns>0
end
local function refreshSnapshot()
 attachEggFeed()
 local rf=net("AskFieldEggSnapshot"); if not rf or not rf:IsA("RemoteFunction") then say("ไม่พบ AskFieldEggSnapshot"); return 0 end
 local done,res=false,nil
 task.spawn(function()
  local ok,a=pcall(function() return rf:InvokeServer() end)
  done=true; res=ok and a or {__err=tostring(a)}
 end)
 local t0=os.clock()
 while not done and os.clock()-t0<8 do task.wait(0.05) end
 if not done then say("Snapshot ค้าง >8s — ใช้ eggDB เดิม"); return 0 end
 if typeof(res)=="table" and res.__err then say("Snapshot error: "..tostring(res.__err)); return 0 end
 if typeof(res)~="table" then say("Snapshot type="..typeof(res)); return 0 end
 local prev=S.eggDB; S.eggDB={}
 local n=ingest(res)
 if n==0 then S.eggDB=prev; return 0 end
 return n
end
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
local function lcsLen(a,b)
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
-- ตรงเป๊ะ / สลับคำครบเท่านั้น — ไม่ใช้ LCS/ชิ้นคำสั้น (fish→swordfish/parrotfish มั่ว)
local function matchScore(need,cand)
 local wa,ka=wordsOf(need)
 local wb,kb=wordsOf(cand)
 if ka=="" or kb=="" then return 0 end
 if ka==kb or nameKey(need)==nameKey(cand) then return 100 end
 if #wa>0 and #wa==#wb then
  local ok=true
  for i=1,#wa do if wa[i]~=wb[i] then ok=false break end end
  if ok then return 95 end
 end
 -- หลายคำ: ต้องครบทุกคำของ need ใน cand (เทียบทั้งคำ ไม่ใช่ substring)
 if #wa>=2 then
  local set={}
  for _,w in ipairs(wb) do set[w]=true end
  local all=true
  for _,w in ipairs(wa) do if not set[w] then all=false break end end
  if all and #wb==#wa then return 95 end
 end
 return 0
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
 if bestS>=90 then return bestN,bestS,bestC end
end
local function findLabel(box,name)
 if not box then return end
 local hit=box:FindFirstChild(name,true)
 if hit and (hit:IsA("TextLabel") or hit:IsA("TextButton") or hit:IsA("TextBox")) then return hit end
end
local function wanted()
 local root=LP.PlayerGui:FindFirstChild("RiftTradeIn",true); root=root and root:FindFirstChild("SacrificeInputs",true)
 if not root then
  if not S.lastWantSay or os.clock()-(S.lastWantSay or 0)>=5 then S.lastWantSay=os.clock(); say("เปิดหน้า Rift ก่อนเพื่ออ่าน 3 เป้า") end
  return
 end
 local out={}
 for i=1,3 do
  local box=root:FindFirstChild("Input"..i)
  local empty=box and box:FindFirstChild("Empty")
  local n=findLabel(empty,"Name") or findLabel(box,"Name")
  local a=findLabel(empty,"Amount") or findLabel(box,"Amount")
  local txt=n and tostring(n.Text or ""):gsub("^%s+",""):gsub("%s+$","") or ""
  if txt~="" and amountNeeds(a) then out[#out+1]=txt end
 end
 if #out==0 then
  if not S.lastWantSay or os.clock()-(S.lastWantSay or 0)>=5 then S.lastWantSay=os.clock(); say("Rift ครบ 3 ตัวแล้ว (หรืออ่าน Amount/Name ไม่ได้)") end
  return {}
 end
 return out
end
local function saveHomeSetting()
 if not S.home then return end
 pcall(function() TS:SetTeleportSetting("Egg01_RiftHome",{S.home.X,S.home.Y,S.home.Z}) end)
end
local function loadHomeSetting()
 local ok,h=pcall(function() return TS:GetTeleportSetting("Egg01_RiftHome") end)
 if ok and typeof(h)=="table" and tonumber(h[1]) then
  S.home=Vector3.new(tonumber(h[1]),tonumber(h[2]) or 0,tonumber(h[3]) or 0)
  return true
 end
end
local function httpGet(url)
 local ok,r=pcall(function() return game:HttpGet(url) end); if ok and r then return r end
 local req=request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
 if req then
  local ok2,res=pcall(function() return req({Url=url,Method="GET"}) end)
  if ok2 and typeof(res)=="table" then return res.Body or res.body end
 end
end
local function loadBanJobs()
 local ban={}
 local ok,raw=pcall(function() return TS:GetTeleportSetting("Egg01_RiftBanJobs") end)
 if ok and typeof(raw)=="string" and raw~="" then
  for id in string.gmatch(raw,"[^,]+") do if id~="" then ban[id]=true end end
 end
 local ok2,prev=pcall(function() return TS:GetTeleportSetting("Egg01_RiftPrevJob") end)
 if ok2 and prev and prev~="" then ban[tostring(prev)]=true end
 return ban
end
local function pushBanJob(jobId)
 if not jobId or jobId=="" then return end
 local ban=loadBanJobs(); ban[tostring(jobId)]=true
 local list={}
 for id in pairs(ban) do list[#list+1]=id end
 -- เก็บล่าสุดไม่เกิน 8 ห้อง
 while #list>8 do table.remove(list,1) end
 pcall(function() TS:SetTeleportSetting("Egg01_RiftBanJobs",table.concat(list,",")) end)
end
local function savePrevJob()
 pushBanJob(game.JobId)
 pcall(function() TS:SetTeleportSetting("Egg01_RiftPrevJob",tostring(game.JobId)) end)
 local n=0
 pcall(function() n=tonumber(TS:GetTeleportSetting("Egg01_RiftHopN")) or 0 end)
 pcall(function() TS:SetTeleportSetting("Egg01_RiftHopN",n+1) end)
end
local function clearHopMark()
 pcall(function() TS:SetTeleportSetting("Egg01_RiftPrevJob","") end)
 pcall(function() TS:SetTeleportSetting("Egg01_RiftHopN",0) end)
end
local function hopAttemptN()
 local ok,n=pcall(function() return tonumber(TS:GetTeleportSetting("Egg01_RiftHopN")) or 0 end)
 return ok and n or 0
end
-- Teleport(place) มักโยนกลับเซิร์ฟเพื่อน → ต้องชี้ JobId คนละห้อง
local function listOtherJobs()
 local ban=loadBanJobs()
 ban[tostring(game.JobId)]=true
 local url=("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
 local raw=httpGet(url); if not raw then return {} end
 local ok,data=pcall(function() return HS:JSONDecode(raw) end)
 if not ok or typeof(data)~="table" or typeof(data.data)~="table" then return {} end
 local list={}
 for _,srv in ipairs(data.data) do
  if typeof(srv)=="table" then
   local id=tostring(srv.id or "")
   if id~="" and not ban[id] then
    local playing=tonumber(srv.playing) or 0
    local maxp=tonumber(srv.maxPlayers) or 99
    local free=maxp-playing
    if playing>0 and free>=2 then
     list[#list+1]={id=id,playing=playing,free=free}
    end
   end
  end
 end
 for i=#list,2,-1 do
  local j=math.random(i)
  list[i],list[j]=list[j],list[i]
 end
 table.sort(list,function(a,b) return a.free>b.free end)
 return list
end
local function tryTeleportJob(job)
 if not job then return false end
 say("ไปเซิร์ฟอื่น JobId="..job:sub(1,8).."… (ตัดเซิร์ฟเดิม/แบนออก)")
 local ok,err=pcall(function() TS:TeleportToPlaceInstance(game.PlaceId,job,LP) end)
 if not ok then say("TP ล้ม: "..tostring(err)); return false end
 return true
end
local function hopNextJob()
 if not S.hopJobs then return false end
 while S.hopIdx<#S.hopJobs do
  S.hopIdx=S.hopIdx+1
  local j=S.hopJobs[S.hopIdx]
  if j and tryTeleportJob(j.id) then return true end
 end
 return false
end
local function ensureTpFailHandler()
 if S.tpFailConn then return end
 S.tpFailConn=TS.TeleportInitFailed:Connect(function(player,teleportResult,errorMessage)
  if player~=LP or not S.hopping then return end
  say("TP fail: "..tostring(teleportResult).." | "..tostring(errorMessage or "").." — ลองใบถัดไป")
  task.defer(function()
   if hopNextJob() then return end
   say("list หมด — รอแล้วดึง list ใหม่")
   task.wait(1.5)
   S.hopJobs=listOtherJobs(); S.hopIdx=0
   if #S.hopJobs>0 and hopNextJob() then return end
   S.hopping=false
   say("หาเซิร์ฟอื่นไม่ได้ตอนนี้")
  end)
 end)
end
local function rejoinServer(why)
 if S.hopping or S.carrying then return false end
 S.hopping=true; S.run=false
 saveHomeSetting()
 savePrevJob()
 ensureTpFailHandler()
 say((why or "ไม่เจอเป้า").." — hop ออกจากเซิร์ฟนี้ (กันเพื่อน/JobId เดิม)")
 task.spawn(function()
  task.wait(0.35)
  local jobs=listOtherJobs()
  S.hopJobs=jobs; S.hopIdx=0
  if #jobs==0 then
   say("ไม่เจอเซิร์ฟว่างใน list — ลองใหม่ภายหลัง")
   S.hopping=false
   return
  end
  say(string.format("มี %d เซิร์ฟว่าง (ตัด JobId เดิมออก) — ลองทีละใบ",#jobs))
  if not hopNextJob() then S.hopping=false end
 end)
 return true
end
local function rejectSameServerIfNeeded()
 local n=hopAttemptN()
 if n<=0 then return false end
 local ban=loadBanJobs()
 if not ban[tostring(game.JobId)] then
  clearHopMark(); return false
 end
 if n>=6 then
  say("ยังวนเซิร์ฟแบน "..tostring(n).." ครั้ง — หยุดชั่วคราว")
  clearHopMark()
  return false
 end
 say("ยังเป็นเซิร์ฟแบน ("..tostring(game.JobId):sub(1,8).."…) — hop ใหม่ #"..tostring(n))
 task.delay(1.2,function() rejoinServer("กันเซิร์ฟเดิม/เพื่อน") end)
 return true
end
local biomeForNeed, flatDist, biomeHubPos, proxyPosFromSnapshot
local WAIT_ROTATE=28
local NEED_BIOME={
 spideron="Titan Temple",bladehide="Titan Temple",crustacia="Titan Temple",mantaris="Titan Temple",
 rhinotaur="Titan Temple",mutantshark="Titan Temple",gorillaking="Titan Temple",nightflame="Titan Temple",
 redpanda="Cherry Blossom",crane="Cherry Blossom",salamander="Cherry Blossom",snowowl="Cherry Blossom",
 snowyowl="Cherry Blossom",koi="Cherry Blossom",stag="Cherry Blossom",onitiger="Cherry Blossom",kitsune="Cherry Blossom",
 dodo="Prehistoric",pterodactyl="Prehistoric",ankylosaurus="Prehistoric",triceratops="Prehistoric",
 bronto="Prehistoric",trex="Prehistoric",mosasaurus="Prehistoric",tralaledon="Prehistoric",
 lavagecko="Volcano",lavafrog="Volcano",flamingbull="Volcano",lavaiguana="Volcano",
 orca="Abyss Ocean",shark="Abyss Ocean",swordfish="Abyss Ocean",parrotfish="Abyss Ocean",
}
flatDist=function(a,b)
 if not a or not b then return math.huge end
 local dx,dz=a.X-b.X,a.Z-b.Z
 return math.sqrt(dx*dx+dz*dz)
end
biomeForNeed=function(n) return NEED_BIOME[nameKey(n)] end
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
biomeHubPos=function(areaName)
 local biome=findGuardBiome(areaName)
 if not biome then return end
 for _,nm in ipairs({"Nests","RequiredSpeedSign","Guard"}) do
  local node=biome:FindFirstChild(nm,true)
  if node then
   if nm=="Nests" then
    local sx,sy,sz,n=0,0,0,0
    for _,ch in ipairs(node:GetDescendants()) do
     if ch:IsA("BasePart") then local p=ch.Position; sx=sx+p.X; sy=sy+p.Y; sz=sz+p.Z; n=n+1 end
    end
    if n>0 then return Vector3.new(sx/n,sy/n,sz/n),areaName..".Nests" end
   end
   if node:IsA("Model") then local ok,cf=pcall(function()return node:GetPivot()end); if ok and cf then return cf.Position,areaName.."."..nm end end
   if node:IsA("BasePart") then return node.Position,areaName.."."..nm end
   local p=node:FindFirstChildWhichIsA("BasePart",true); if p then return p.Position,areaName.."."..nm end
  end
 end
 local ok,cf=pcall(function()return biome:GetPivot()end); if ok and cf then return cf.Position,areaName end
end
local function attachShift()
 return attachEggFeed()
end
-- ชื่อใน Rift ≠ AssetCategory ในฟิลด์ (เกมตั้งชื่อคนละแบบ)
local NEED_ALIAS={
 shark={"finnedthresher","thresher"},
}
local function eggMatchesNeed(e,needList)
 if not e then return end
 local cands={}
 if e.cat and e.cat~="" then cands[#cands+1]=e.cat end
 if e.name and e.name~="" then cands[#cands+1]=e.name end
 if #cands==0 then return end
 for _,n in ipairs(needList) do
  local keys={nameKey(n)}
  local al=NEED_ALIAS[keys[1]]
  if al then for _,a in ipairs(al) do keys[#keys+1]=nameKey(a) end end
  for _,cand in ipairs(cands) do
   local ck=nameKey(cand)
   for _,nk in ipairs(keys) do
    if nk~="" and nk==ck then return n,100,cand end
   end
   local s=matchScore(n,cand)
   if s>=90 then return n,s,cand end
  end
 end
end
local function nearestStealPos(eggPos)
 if not eggPos then return end
 local best,bestD
 for _,x in ipairs(workspace:GetDescendants()) do
  if x:IsA("ProximityPrompt") and x.Enabled and tostring(x.ActionText):lower():find("steal",1,true) then
   local q=x.Parent and (x.Parent:IsA("BasePart") and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart",true))
   if q then
    local d=(q.Position-eggPos).Magnitude
    if d<=14 and (not bestD or d<bestD) then best,bestD=q.Position,d end
   end
  end
 end
 return best,bestD
end
proxyPosFromSnapshot=function(areaName,rootPos)
 local want=tostring(areaName or ""):lower(); if want=="" then return end
 local best,bestD
 for _,e in pairs(S.eggDB) do
  local area=tostring(e.area or ""):lower()
  if area~="" and (area==want or area:find(want,1,true) or want:find(area,1,true)) and e.pos then
   local d=flatDist(e.pos,rootPos); if not best or d<bestD then best,bestD=e.pos,d end
  end
 end
 if best then return best,areaName.." nest" end
end
local prompts
local function target(quiet)
 local need=wanted(); if not need or #need==0 then return end
 attachEggFeed()
 if not quiet then
  local now0=os.clock()
  if not S.lastSnap or now0-(S.lastSnap or 0)>2.5 then S.lastSnap=now0; refreshSnapshot() end
 end
 local _,root=hr(); if not root then return end
 local best; local total,withPos,nameHit,nameNoPos=0,0,0,0
 local areasNeeded,areaSeen={},{}
 for _,n in ipairs(need) do local b=biomeForNeed(n); if b and not areaSeen[b] then areaSeen[b]=true; areasNeeded[#areasNeeded+1]=b end end
 local function areaCats(areaName)
  local want=tostring(areaName or ""):lower(); local counts,list={},{}
  for _,e in pairs(S.eggDB) do
   local area=tostring(e.area or ""):lower()
   if area~="" and (area==want or area:find(want,1,true) or want:find(area,1,true)) then
    local cat=tostring(e.cat or "?")
    if not counts[cat] then counts[cat]=0; list[#list+1]=cat end
    counts[cat]=counts[cat]+1
   end
  end
  table.sort(list)
  local parts={}
  for i=1,math.min(10,#list) do parts[#parts+1]=list[i].."x"..tostring(counts[list[i]]) end
  return #list,table.concat(parts,", ")
 end
 for uid,e in pairs(S.eggDB) do
  total=total+1
  if e.pos then withPos=withPos+1 end
  if not isSkipped(uid) then
   local wantedName,score,via=eggMatchesNeed(e,need)
   if wantedName then
    nameHit=nameHit+1
    if not e.pos or e.state=="Carried" then nameNoPos=nameNoPos+1
    else
     local walkPos=nearestStealPos(e.pos) or e.pos
     local d=(walkPos-root.Position).Magnitude
     if not best or d<best.d or (math.abs(d-best.d)<40 and score>best.score) then
      best={uid=uid,cat=tostring(e.cat or "?"),need=wantedName,pos=walkPos,eggPos=e.pos,d=d,score=score,via=via}
     end
    end
   end
  end
 end
 if best then
  S.lastMiss=nil; S.hunt=nil; S.waitSince=nil
  local loose=(best.score or 100)<100 and ("≈"..tostring(best.via or best.cat).." ") or ""
  if not quiet then say(string.format("RIFT NEED %s %sUID=%s d=%.0f @%.0f,%.0f,%.0f",best.need,loose,tostring(best.uid),best.d,best.pos.X,best.pos.Y,best.pos.Z)) end
  return best
 end
 if not quiet and (not S.lastScanSay or os.clock()-(S.lastScanSay or 0)>=10) then
  S.lastScanSay=os.clock()
  local found={}
  for _,n in ipairs(need) do
   local hit=false
   local nk=nameKey(n)
   local near={}
   for uid,e in pairs(S.eggDB) do
    if not isSkipped(uid) and e.pos and e.state~="Carried" then
     if eggMatchesNeed(e,{n}) then hit=true break end
     local ck=nameKey(e.cat or e.name or "")
     if nk~="" and ck~="" and (#ck>=#nk) and (ck:find(nk,1,true) or nk:find(ck,1,true)) then
      near[#near+1]=tostring(e.cat or e.name)
     end
    end
   end
   if hit then found[#found+1]="Y:"..n
   else
    local tip=""
    if #near>0 then
     table.sort(near)
     tip=" (ใกล้ชื่อ: "..table.concat(near,", ",1,math.min(3,#near))..")"
    end
    found[#found+1]="N:"..n..tip
   end
  end
  say("สแกน 3 เป้า: "..table.concat(found," | "))
 end
 local now=os.clock()
 S.huntIdx=S.huntIdx or 1
 if #areasNeeded>1 and S.waitSince and now-S.waitSince>=WAIT_ROTATE then
  S.huntIdx=S.huntIdx+1; S.waitSince=nil; S.stood=false
  if not quiet then say(string.format("รอครบ %ds ไม่เกิดเป้า — หมุนไบโอม",WAIT_ROTATE)) end
 end
 local huntArea=#areasNeeded>0 and areasNeeded[((S.huntIdx-1)%#areasNeeded)+1] or nil
 local hub,hubLabel
 if huntArea then
  hub,hubLabel=biomeHubPos(huntArea)
  if not hub then hub,hubLabel=proxyPosFromSnapshot(huntArea,root.Position) end
 end
 local tip
 if nameHit>0 then tip=string.format("ชื่อตรง=%d แต่ไม่มีพิกัด/Carried=%d",nameHit,nameNoPos)
 elseif huntArea then tip="eggDB ไม่มีเป้า → "..huntArea
 else tip="eggDB ว่างเป้า"
 end
 if hub and S.run then
  local d=flatDist(hub,root.Position)
  if d<=140 then
   if not S.waitSince then S.waitSince=now end
   if not quiet and (not S.lastCatSay or now-(S.lastCatSay or 0)>=20) then
    S.lastCatSay=now
    local nCat,cats=areaCats(huntArea)
    local dbN=0; for _ in pairs(S.eggDB) do dbN=dbN+1 end
    say(string.format("โซน %s มี %d ชนิด | eggDB=%d: %s",tostring(huntArea),nCat,dbN,cats~="" and cats or "(ว่าง)"))
    say("ต้องการ: "..table.concat(need,", ").." — ยังไม่สปอว์นในฟิลด์")
   end
   if not quiet and (not S.lastWaitSay or now-(S.lastWaitSay or 0)>=8) then
    S.lastWaitSay=now
    say(string.format("ยืนรอที่ %s (dXZ=%.0f) — สแกน eggDB เรื่อยๆ",tostring(hubLabel or huntArea),d))
   end
   return {uid=nil,need="WAIT",pos=hub,d=d,hunt=true,wait=true,area=huntArea,label=hubLabel}
  end
  S.waitSince=nil
  if not quiet and (not S.lastMiss or now-(S.lastMiss or 0)>=6) then
   S.lastMiss=now
   local dbN=0; for _ in pairs(S.eggDB) do dbN=dbN+1 end
   say(string.format("ยังไม่เจอ: %s | eggDB=%d | ไป %s dXZ=%.0f",table.concat(need,", "),dbN,tostring(hubLabel or huntArea),d))
  end
  return {uid=nil,need="HUNT",pos=hub,d=d,hunt=true,area=huntArea,label=hubLabel}
 end
 if not quiet and (not S.lastMiss or now-(S.lastMiss or 0)>=6) then
  S.lastMiss=now
  local dbN=0; for _ in pairs(S.eggDB) do dbN=dbN+1 end
  say(string.format("ยังไม่เจอ: %s | eggDB=%d | %s",table.concat(need,", "),dbN,tip))
 end
end
prompts=function() local o={}; for _,x in ipairs(workspace:GetDescendants()) do if x:IsA("ProximityPrompt") and x.Enabled and tostring(x.ActionText):lower():find("steal",1,true) then local q=x.Parent and (x.Parent:IsA("BasePart") and x.Parent or x.Parent:FindFirstChildWhichIsA("BasePart",true)); if q then o[#o+1]={p=x,pos=q.Position} end end end; return o end
local function stop(label)
 local h,r=hr(); if not h or not r then return end
 h:MoveTo(r.Position); h:Move(Vector3.zero)
 for _=1,3 do
  if not r.Parent then break end
  r.AssemblyLinearVelocity=Vector3.zero; r.AssemblyAngularVelocity=Vector3.zero
  RunS.Heartbeat:Wait()
 end
 if label then say(label) end
end
-- ค้างตำแหน่ง → กระโดด+เดินหน้า (แบบ ExperimentFarm leaveJumpWhileRun)
local function unstickJump(toward)
 local h,r=hr(); if not h or not r then return end
 h.Sit=false; h.PlatformStand=false
 if h.WalkSpeed<28 then h.WalkSpeed=28 end
 local dir=r.CFrame.LookVector
 local flat=toward and Vector3.new(toward.X-r.Position.X,0,toward.Z-r.Position.Z)
 if flat and flat.Magnitude>=1 then dir=flat.Unit end
 local rift=S.rift
 if rift then
  local toR=Vector3.new(rift.X-r.Position.X,0,rift.Z-r.Position.Z)
  if toR.Magnitude>5 and (not flat or flat.Magnitude<20) then dir=toR.Unit end
 end
 local goal=r.Position+dir*70
 say("ค้างตำแหน่ง — กระโดดออก")
 h.Jump=true
 pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
 h:MoveTo(Vector3.new(goal.X,r.Position.Y,goal.Z))
 pcall(function() h:Move(dir,false) end)
 pcall(function()
  local v=r.AssemblyLinearVelocity
  r.AssemblyLinearVelocity=Vector3.new(dir.X*42,math.max(v.Y,40),dir.Z*42)
 end)
 for _=1,14 do
  local h2,r2=hr(); if not h2 or not r2 then break end
  h2.Jump=true
  h2:MoveTo(Vector3.new(goal.X,r2.Position.Y,goal.Z))
  pcall(function() h2:Move(dir,false) end)
  task.wait(0.06)
 end
end
local function walk(p,rad,lim,slowNear,watchUid)
 local t0=os.clock(); local moveHum,oldSpeed,lastBand,lastSay,lastPoll=nil,nil,nil,0,0
 local lastPos,lastMoveAt=nil,os.clock()
 local function restore()
  if moveHum and moveHum.Parent then moveHum.WalkSpeed=oldSpeed end
 end
 while S.run and os.clock()-t0<lim do
  local h,r=hr(); if not h or not r then restore(); return end
  if watchUid and os.clock()-lastPoll>2 then
   lastPoll=os.clock()
   local n=target(true)
   if not n or n.hunt or tostring(n.uid)~=tostring(watchUid) then restore(); say("เป้าเปลี่ยน — สแกนใหม่"); return false,"switch" end
   if n.pos then p=n.pos end
  end
  -- ค้าง <8 studs / 4s → กระโดดออก
  if lastPos then
   local moved=Vector3.new(r.Position.X-lastPos.X,0,r.Position.Z-lastPos.Z).Magnitude
   if moved>=8 then lastPos,lastMoveAt=r.Position,os.clock()
   elseif os.clock()-lastMoveAt>=4 then
    restore(); unstickJump(p); lastPos,lastMoveAt=r.Position,os.clock()
    if moveHum then oldSpeed=h.WalkSpeed end
   end
  else
   lastPos,lastMoveAt=r.Position,os.clock()
  end
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
  local dir=g-r.Position
  local step=math.min(dir.Magnitude,110)
  local goal=r.Position+dir.Unit*step
  h:MoveTo(Vector3.new(goal.X,r.Position.Y,goal.Z))
  if d>80 and os.clock()-lastSay>6 then lastSay=os.clock(); say(string.format("เดิน d=%.0f",d)) end
  -- ใกล้ไข่ ≤18: อัปเดตถี่ (MOTION_BRAKE.md)
  task.wait((slowNear and d<=18) and 0.04 or 0.12)
 end
 restore()
end
local function instPos(inst)
 if not inst then return end
 if inst:IsA("BasePart") then return inst.Position end
 local ok,piv=pcall(function() return inst:GetPivot() end)
 if ok and piv then return piv.Position end
 local p=inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart",true)
 return p and p.Position
end
local function findRift()
 local objs=workspace:FindFirstChild("__OBJECTS")
 local machines=objs and objs:FindFirstChild("Machines")
 local rm=machines and machines:FindFirstChild("RiftMachine")
 if rm then
  local rift=rm:FindFirstChild("Rift")
  local p=instPos(rift) or instPos(rm)
  if p then return Vector3.new(p.X,math.max(p.Y,70),p.Z),"RiftMachine" end
 end
 return FALLBACK_RIFT,"fallback-rift"
end
local function resolveRift(quiet)
 local pos,src=findRift()
 S.rift=pos
 if not quiet then say(string.format("RIFT=%s @%.0f,%.0f,%.0f",tostring(src),pos.X,pos.Y,pos.Z)) end
 return pos
end
local function riftDeepTarget(towardPos)
 local rift=resolveRift(true)
 local dir=Vector3.new(1,0,0)
 if towardPos then
  local flat=Vector3.new(towardPos.X-rift.X,0,towardPos.Z-rift.Z)
  if flat.Magnitude>=1 then dir=flat.Unit end
 end
 return Vector3.new(rift.X+dir.X*RIFT_DEPTH,math.max(rift.Y,70),rift.Z+dir.Z*RIFT_DEPTH),rift
end
-- ใกล้เป้าแล้วไม่ย้อน Rift | ไกล=ขั้น1 Rift แล้วขั้น2 เป้า (เหมือน TargetFarm)
local function goViaRift(dest,rad,lim,label,watchUid)
 if not dest then return false end
 local _,r=hr(); if not r then return false end
 local dDirect=(Vector3.new(dest.X,r.Position.Y,dest.Z)-r.Position).Magnitude
 if dDirect<=180 then
  return walk(dest,rad or 5,lim or math.clamp(dDirect/12+40,50,280),55,watchUid)
 end
 local deep=select(1,riftDeepTarget(dest))
 local dR=(Vector3.new(deep.X,r.Position.Y,deep.Z)-r.Position).Magnitude
 if dR>RIFT_R then
  say(string.format("ขั้น1 → Rift ลึก%+d d=%.0f → %s",RIFT_DEPTH,dR,tostring(label or "เป้า")))
  local okR=walk(deep,RIFT_R,math.clamp(dR/16+40,50,320),55)
  if not S.run then return false end
  if watchUid and okR==false then return false,"switch" end
  say(okR and ("ถึง Rift แล้ว → "..tostring(label or "เป้า")) or "Rift ไม่สุด → ไปต่อ")
 end
 local _,r2=hr()
 local d2=r2 and (Vector3.new(dest.X,r2.Position.Y,dest.Z)-r2.Position).Magnitude or 9999
 say(string.format("ขั้น2 → %s d=%.0f",tostring(label or "เป้า"),d2))
 return walk(dest,rad or 5,lim or math.clamp(d2/14+60,60,400),55,watchUid)
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
 refreshSnapshot()
 local e=S.eggDB[tostring(t.uid)]
 if e and e.state~="Carried" and e.pos then
  t.pos=nearestStealPos(e.pos) or e.pos; t.eggPos=e.pos; return true
 end
 return false
end
-- เลือก Steal ใกล้พิกัดไข่ UID ที่สุดใน 18 studs (Egg01_MOTION_BRAKE.md)
local function choosePrompt(t)
 local _,me=hr(); if not me then return end
 local eggPos=t.eggPos or t.pos; if not eggPos then return end
 local candidates={}
 for _,v in ipairs(prompts()) do
  local d=(v.pos-eggPos).Magnitude
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
 local rf=net("AskFieldEggCarry","RemoteFunction") or net("AskFieldEggCarry")
 if not rf or not rf:IsA("RemoteFunction") then return false,"no-RF" end
 local ok,res=pcall(function() return rf:InvokeServer({Uid=tostring(uid)}) end)
 return ok,res
end
local function fireSteal(pick)
 if not pick or not fp then return false end
 local old=pick.HoldDuration
 local ok,err=pcall(function() pick.HoldDuration=0; fp(pick) end)
 pcall(function() pick.HoldDuration=old end)
 if not ok then say("Steal error: "..tostring(err)) end
 return ok
end
local function one(t)
 if not refreshTarget(t) then say("UID หาย — ข้าม"); skipUid(t.uid,45); return end
 t.eggPos=t.eggPos or t.pos
 local _,me=hr(); local dist=me and (t.pos-me.Position).Magnitude or (t.d or 200)
 local lim=math.clamp(dist/12+40,50,280)
 say(string.format("ไปหา %s — ผ่าน Rift (จับแม่น rad=5 slow=55)",tostring(t.need or t.cat)))
 local ok,why=goViaRift(t.pos,5,lim,tostring(t.need or "ไข่"),t.uid)
 if why=="switch" then return end
 if not ok then say("ไปไข่ไม่สำเร็จ — ข้าม"); skipUid(t.uid,45); return end
 stop()
 if not refreshTarget(t) then say("UID หายหลังถึง — ข้าม"); skipUid(t.uid,45); return end
 t.eggPos=t.eggPos or t.pos
 -- เข้าพิกัดไข่ละเอียดอีกรอบ (MOTION_BRAKE)
 local walkPos=nearestStealPos(t.eggPos) or t.pos
 say(string.format("เข้าไข่ละเอียด @%.0f,%.0f",walkPos.X,walkPos.Z))
 do
  local ok2,why2=walk(walkPos,5,22,55,t.uid)
  if why2=="switch" then return end
  if not ok2 then say("เข้าพิกัดไข่ไม่สุด — ลองยิงต่อ") end
 end
 stop()
 local haveCarry=attachCarry()
 if not haveCarry then say("ยังไม่มี FieldEggCarry RE — ยิง Steal/RF ต่อ แล้วดู visual") end
 S.expectedUid=t.uid; S.carrying=false; S.carryVerified=false; S.carryMismatch=false; S.carrySpeed=nil

 say("ลอง RF AskFieldEggCarry Uid="..tostring(t.uid))
 select(1,tryCarryUid(t.uid))
 local untilRf=os.clock()+1.2
 while S.run and os.clock()<untilRf and not S.carryVerified and not S.carryMismatch do task.wait(.05) end
 if S.carryMismatch then
  skipUid(t.uid,90); S.expectedUid=nil; tryDrop(); S.carryMismatch=false; say("ข้าม UID นี้ ไปสแกนเป้าอื่น"); return
 end
 if not S.carryVerified then
  local pick,md,gap,detail=choosePrompt(t)
  if not pick then
   for _,off in ipairs({Vector3.new(3,0,0),Vector3.new(-3,0,0),Vector3.new(0,0,3),Vector3.new(0,0,-3)}) do
    if walk((t.eggPos or t.pos)+off,2,2.5,10) then pick,md,gap,detail=choosePrompt(t); if pick then break end end
   end
  end
  if pick then
   local part=pick.Parent and (pick.Parent:IsA("BasePart") and pick.Parent or pick.Parent:FindFirstChildWhichIsA("BasePart",true))
   if part then walk(part.Position,3.2,6,14); stop() end
   if not refreshTarget(t) then S.expectedUid=nil; skipUid(t.uid,45); return end
   t.eggPos=t.eggPos or t.pos
   pick,md,gap,detail=choosePrompt(t)
   if pick then
    say(string.format("fp Steal ใกล้ไข่ pd=%.2f gap=%.2f",md or -1,gap or -1))
    fireSteal(pick)
    tryCarryUid(t.uid)
    local untilT=os.clock()+2
    while S.run and os.clock()<untilT and not S.carryVerified and not S.carryMismatch do
     if lookingLikeCarry() then S.carrying=true; S.carryVerified=true; break end
     task.wait(.05)
    end
   else
    say("ไม่เจอ Prompt ("..tostring(detail)..") — ข้าม"); skipUid(t.uid,45)
   end
  else
   say("RF ไม่ติด + ไม่เจอ Prompt — ข้าม"); skipUid(t.uid,45)
  end
 end
 -- ไม่มี RE: ยืนยันถือด้วย visual
 if not S.carryVerified and lookingLikeCarry() then
  S.carrying=true; S.carryVerified=true; say("ถือไข่แล้ว (visual) — วิ่งกลับ")
 end
 S.expectedUid=nil
 if S.carryMismatch then
  skipUid(t.uid,90); tryDrop(); S.carryMismatch=false; say("ข้าม (UID ผิด) — หาใบอื่น"); return
 end
 if not S.carryVerified then say("ยังไม่ถือเป้า — ข้าม"); skipUid(t.uid,45); return end
 if S.carrySpeed and S.carrySpeed<0.55 then
  say(string.format("ไข่หนักเกินไป speed=%.2f — ทิ้งแล้วข้าม",S.carrySpeed))
  skipUid(t.uid,120); tryDrop(); return
 end
 if S.home then
  local _,r=hr(); local d0=r and (r.Position-S.home).Magnitude or -1
  say(string.format("ถือไข่แล้ว — กลับ HOME ผ่าน Rift d=%.0f",d0))
  local deep=select(1,riftDeepTarget(S.home))
  if deep and r then
   local dR=(Vector3.new(deep.X,r.Position.Y,deep.Z)-r.Position).Magnitude
   if dR>RIFT_R+20 and d0>180 then
    say(string.format("ขั้น1 → Rift ลึก%+d d=%.0f",RIFT_DEPTH,dR))
    local tR=os.clock(); local limR=math.clamp(dR/16+40,50,220)
    while S.run and S.carrying and os.clock()-tR<limR do
     local h,rr=hr(); if not h or not rr then break end
     if (rr.Position-deep).Magnitude<=RIFT_R then stop(); break end
     if not S.carrying then say("ไข่หล่นระหว่างทาง — ไม่ไล่เก็บ ไปเป้าอื่น"); skipUid(t.uid,60); return end
     walk(deep,RIFT_R,3.5)
    end
    if not S.carrying then return end
    say("ถึง Rift แล้ว → HOME")
   end
  end
  local _,r2=hr(); d0=r2 and (r2.Position-S.home).Magnitude or d0
  local homeLim=math.clamp((d0>0 and d0/10 or 80)+50,80,220)
  local tHome=os.clock(); local lastD=d0; local stuck=0
  local okHome=false
  while S.run and os.clock()-tHome<homeLim do
   local h,rr=hr(); if not h or not rr then break end
   if not S.carrying then say("ไข่หล่นระหว่างทาง — ไม่ไล่เก็บ ไปเป้าอื่น"); skipUid(t.uid,60); return end
   local d=(rr.Position-S.home).Magnitude
   if d<=60 then okHome=true; stop(); break end
   if lastD>0 and lastD-d<8 then stuck=stuck+1 else stuck=0 end
   lastD=d
   if stuck>=8 then
    say("กลับบ้านช้า/หนัก — ทิ้งไข่ ข้ามไปใบอื่น")
    skipUid(t.uid,120); tryDrop(); return
   end
   walk(S.home,60,3.5)
  end
  if okHome then say("ถึง HOME — รอวาง/ฟัก"); waitPlaced()
  else say("กลับ HOME ไม่ทัน — ทิ้งแล้วข้าม"); skipUid(t.uid,90); tryDrop() end
 else
  say("เก็บแล้ว — ไม่มี HOME จึงหยุด")
 end
end
local gui=Instance.new("ScreenGui"); gui.Name="Egg01_RiftFarm"; gui.ResetOnSpawn=false; pcall(function()gui.Parent=(gethui and gethui())or game:GetService("CoreGui")end); if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end; S.gui=gui
local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,360,0,185); f.Position=UDim2.new(0,12,.45,0); f.BackgroundColor3=Color3.fromRGB(25,15,40); f.BorderSizePixel=0; f.Active=true; f.Draggable=true; Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f); title.Size=UDim2.new(1,-78,0,28); title.Position=UDim2.new(0,10,0,4); title.BackgroundTransparency=1; title.Text="Egg01 Rift Farm v1.39 — SHARK=THRESHER"; title.TextColor3=Color3.fromRGB(220,170,255); title.Font=Enum.Font.GothamBold; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left
local function b(tx,x,col) local z=Instance.new("TextButton",f); z.Size=UDim2.new(0,62,0,28); z.Position=UDim2.new(0,x,0,36); z.Text=tx; z.BackgroundColor3=col; z.TextColor3=Color3.new(1,1,1); z.BorderSizePixel=0; z.Font=Enum.Font.GothamBold; z.TextSize=11; Instance.new("UICorner",z).CornerRadius=UDim.new(0,5); return z end
local home=b("HOME",10,Color3.fromRGB(50,100,180)); local scan=b("SCAN",78,Color3.fromRGB(50,100,180)); local start=b("START",146,Color3.fromRGB(35,145,75)); local halt=b("STOP",214,Color3.fromRGB(165,50,55)); local hop=b("HOP",282,Color3.fromRGB(120,70,30))
local fold=b("−",292,Color3.fromRGB(85,65,115)); local close=b("X",326,Color3.fromRGB(145,50,65)); fold.Size=UDim2.new(0,28,0,24); fold.Position=UDim2.new(0,292,0,4); close.Size=UDim2.new(0,28,0,24); close.Position=UDim2.new(0,326,0,4)
log=Instance.new("TextLabel",f); log.Size=UDim2.new(1,-16,0,105); log.Position=UDim2.new(0,8,0,72); log.BackgroundTransparency=.2; log.BackgroundColor3=Color3.new(0,0,0); log.TextColor3=Color3.fromRGB(180,245,190); log.Font=Enum.Font.Code; log.TextSize=10; log.TextXAlignment=Enum.TextXAlignment.Left; log.TextYAlignment=Enum.TextYAlignment.Top; log.TextWrapped=true; log.ClipsDescendants=true
local folded=false; fold.MouseButton1Click:Connect(function() folded=not folded; f.Size=UDim2.new(0,360,0,folded and 32 or 185); for _,v in ipairs({home,scan,start,halt,hop,log}) do v.Visible=not folded end; fold.Text=folded and "+" or "−" end); close.MouseButton1Click:Connect(function()S.run=false;setClip(false);gui:Destroy();_G.EGG01_RIFT_FARM=nil end)
local function ensureHome(forceHere)
 local _,r=hr()
 if forceHere and r then
  S.home=r.Position; saveHomeSetting()
  say(string.format("HOME auto @%.0f,%.0f,%.0f",S.home.X,S.home.Y,S.home.Z))
  return true
 end
 if S.home then return true end
 if r then
  S.home=r.Position; saveHomeSetting()
  say(string.format("HOME auto (จุดยืน) @%.0f,%.0f,%.0f",S.home.X,S.home.Y,S.home.Z))
  return true
 end
 return false
end
local function startAuto(reason)
 if S.run or S.hopping then return false end
 if not ensureHome(false) then say("ยังไม่มีตัวละคร — รอแล้ว auto ใหม่"); return false end
 S.run=true; S.missSince=nil; start.Text="AUTO"
 say((reason or "AUTO").." — ไม่เจอ→รอโหลด "..tostring(REJOIN_AFTER).."s ค่อย hop")
 task.spawn(function()
  resolveRift()
  local n=refreshSnapshot(); say("eggDB โหลด "..tostring(n).." รายการ — รอสแกน "..tostring(REJOIN_AFTER).."s")
  S.missSince=os.clock()
  while S.run do
   local ok,t=pcall(target)
   if not ok then say("target err: "..tostring(t)); task.wait(1)
   elseif t and t.hunt then
    S.missSince=S.missSince or os.clock()
    local left=REJOIN_AFTER-(os.clock()-S.missSince)
    if left<=0 then
     rejoinServer("ไม่เจอเป้าหลังโหลด "..tostring(REJOIN_AFTER).."s — hop")
     break
    end
    if not S.lastMissSay or os.clock()-(S.lastMissSay or 0)>=4 then
     S.lastMissSay=os.clock()
     say(string.format("ยังไม่เจอเป้า — รอโหลด/สแกน อีก %.0fs ค่อย hop",left))
    end
    -- ระหว่างรอ: ยืน/ไปโซนสั้นๆ + รีเฟรช snapshot
    if t.wait then
     if not S.stood then S.stood=true; stop("หยุดรอโหลดไข่") end
     if not S.lastSnap or os.clock()-(S.lastSnap or 0)>3 then S.lastSnap=os.clock(); refreshSnapshot() end
     task.wait(0.6)
    else
     S.stood=false
     goViaRift(t.pos,60,8,tostring(t.area))
    end
   elseif t then
    S.missSince=nil; S.stood=false; one(t); task.wait(.35)
   else
    task.wait(.6)
   end
  end
  start.Text="START"
 end)
 return true
end
attachCarry(); attachEggFeed()
if loadHomeSetting() then say(string.format("HOME โหลดจากเซิร์ฟก่อน @%.0f,%.0f,%.0f",S.home.X,S.home.Y,S.home.Z)) end
rejectSameServerIfNeeded()
say("เซิร์ฟนี้ JobId="..tostring(game.JobId):sub(1,8).."…")
home.MouseButton1Click:Connect(function() ensureHome(true) end)
scan.MouseButton1Click:Connect(function() task.spawn(function() local n=refreshSnapshot(); say("SCAN eggDB="..tostring(n)); target() end) end)
start.MouseButton1Click:Connect(function() startAuto("กด START") end)
halt.MouseButton1Click:Connect(function()S.run=false;stop();say("STOP")end)
hop.MouseButton1Click:Connect(function() if S.carrying then say("ถือไข่อยู่ — ไม่ HOP"); return end; rejoinServer("กด HOP") end)
setClip(true)
say("v1.39: Shark=Finned Thresher | hop "..tostring(REJOIN_AFTER).."s")
-- เปิดโปรแกรม = ตั้ง HOME (ถ้ายังไม่มี) + START เอง
task.spawn(function()
 local t0=os.clock()
 while os.clock()-t0<15 do
  if S.hopping then return end
  local _,r=hr()
  if r then break end
  task.wait(0.25)
 end
 if S.hopping then return end
 if rejectSameServerIfNeeded() then return end
 ensureHome(false)
 task.wait(0.6)
 if not S.hopping and not S.run then startAuto("autoboot") end
end)
