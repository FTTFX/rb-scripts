-- 76RB_NetSpy.lua v1.3 — สปายเกมทันคูน เบซิก (Tycoon Basic)
-- v1.2 พิสูจน์แล้ว: Npc_* ที่ "หาย" ไม่ใช่ถูกจับ — เป็น NPC ผู้เยี่ยมชมเดินเพ่นพ่านทั่วเกาะ (ทุกฐาน ทุกคน)
--   ถูกสร้างใหม่ทุก ~1.45s ตาม pathfinding (ลบเก่า+สร้างใหม่ทุกก้าว ไม่เกี่ยวกับเงิน)
--   รายได้จริงน่าจะมาจาก "มอนสเตอร์" ที่วางในฐาน (ชื่อแปลกๆ เช่น PapaFlame21, Bigkun15z) จับ NPC ที่เดินผ่านเอง
--   attribute ThreatMonsterId="Base1_MonsterSpawn367" บน NPC คือจุดเชื่อมไปมอนสเตอร์ตัวที่จะจับมัน
-- v1.3 ขุดต่อ: ดัก attribute โมเดลมอนสเตอร์ที่วางในฐาน (กรองชื่อ Npc_/NpcCaptureCloud/Highlight/Terrain/ฯลฯ ออก)
--   ทั้งตอนโหลดและตอน AttributeChanged — หา field อัตราจับ/ผู้เยี่ยมชมต่อนาที ที่ผูกกับรายได้จริง
-- v1.1 พิสูจน์แล้ว: NpcCaptureCloud มีลูกแค่ "RootPart" ตัวเดียว (ไม่ใช่ที่เก็บ NPC จริง)
--   → มันคือ "จุดปักป้ายลอยตัวเลข" ที่ใช้ร่วมกันเฉยๆ ไม่ใช่ folder เก็บ NPC ที่ถูกจับ
--   → ค่าเงินแต่ละครั้งไม่คงที่ (144-4443) เป็นกลุ่มขั้น (เล็ก/กลาง/ใหญ่/มหาศาล) คล้ายระบบ rarity
--   → STAT บางครั้งกระโดดเท่ากับ "ผลรวม" ของ popup ที่เด้งพร้อมกันหลายอัน (เช่น 1235+4360=5595) = ยืนยันว่า
--     popup = มูลค่าจริงต่อ NPC 1 ตัว ไม่ใช่ของปลอม/สุ่มแสดงผล
-- v1.2 ขุดหา "ตัว NPC จริง" ที่ถูกจับ (ต้องอยู่ที่อื่นในเกม ไม่ใช่ใต้ NpcCaptureCloud):
--   1) dump workspace:GetChildren() ตอนโหลด — หา folder ที่น่าจะเก็บ NPC (Npcs/Customers/Enemies/...)
--   2) เฝ้า DescendantRemoving ทั้ง workspace — ตอน NPC ถูกจับ โมเดลควรหายไปจาก workspace
--      กรองเฉพาะ Model ที่มี Humanoid หรือชื่อ/attribute ดูเป็น NPC แล้ว dump attribute ก่อนหาย (หา field ค่า/tier)
--   3) ดัก ProximityPromptService.PromptTriggered เผื่อการจับใช้ปุ่ม E ไม่ใช่ touch ล้วน
-- วิธีใช้: รัน → ไปจับ NPC 5-6 ตัว → ดู [NPC-] (ก่อนหาย) เทียบกับ [POPUP]/[STAT] ว่า field ไหนตรงกับมูลค่า
--         → กด LIST ดู remote เงิน → COPY ส่งผลมา
-- ปุ่ม: LIST | CLEAR | COPY | PAUSE | ✕
if _G.NSPY76_GUI then pcall(function() _G.NSPY76_GUI:Destroy() end) end
if _G.NSPY76_CONNS then
    for _, c in ipairs(_G.NSPY76_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.NSPY76_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT = {}
local PAUSED = false
local MAXLINES = 500
local START_T = tick()

local gui = Instance.new("ScreenGui")
gui.Name = "NetSpy76"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.NSPY76_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 680, 0, 360); box.Position = UDim2.new(0, 8, 0.2, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(180, 255, 180); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false
box.Active = true; box.Draggable = true

local function redraw()
    box.Text = table.concat(OUT, "\n")
end
local function L(s)
    OUT[#OUT + 1] = ("[%6.2fs] "):format(tick() - START_T) .. s
    if #OUT > MAXLINES then table.remove(OUT, 1) end
    redraw()
end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.2, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local listB  = hbtn("LIST", 8, 70, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 84, 74, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 164, 70)
local pauseB = hbtn("PAUSE", 240, 74, Color3.fromRGB(90, 90, 40))
local closeB = hbtn("✕", 320, 34, Color3.fromRGB(150, 40, 40))

-- ==================== serialize args ====================
local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then
        return "<" .. v.ClassName .. ":" .. v:GetFullName():gsub("^Workspace%.", "WS.") .. ">"
    elseif t == "table" then
        if depth > 2 then return "{...}" end
        local parts = {}
        local n = 0
        for k, val in pairs(v) do
            n += 1
            if n > 8 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. ser(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "string" then
        return '"' .. (v:len() > 60 and v:sub(1, 60) .. "…" or v) .. '"'
    elseif t == "Vector3" then
        return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        return ("CF(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    end
    return tostring(v)
end

-- ==================== LIST remotes ====================
local function listRemotes()
    L("=== REMOTES ใน ReplicatedStorage (ไฮไลต์ตัวที่น่าจะเกี่ยวเงิน) ===")
    local n, hit = 0, 0
    local KEY = { "cash", "money", "income", "collect", "buy", "purchase", "reward", "earn", "sell", "claim" }
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
            n += 1
            local full = d:GetFullName():gsub("^ReplicatedStorage%.", "RS.")
            local lname = d.Name:lower()
            local flagged = false
            for _, k in ipairs(KEY) do
                if lname:find(k, 1, true) then flagged = true break end
            end
            if flagged then
                hit += 1
                L(("★ %s [%s] %s"):format(hit, d.ClassName:sub(1, 9), full))
            end
        end
    end
    L(("=== รวม %d ตัว (ไฮไลต์ %d ตัวที่ชื่อพ้องเงิน) ==="):format(n, hit))
end

-- ==================== 1) HOOK __namecall (ดัก remote ทุกครั้งที่ยิง + ผลลัพธ์) ====================
if not _G.NSPY76_HOOKED and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer")
            and not PAUSED and _G.NSPY76_LOG then
            local args = { ... }
            if method == "InvokeServer" then
                -- ต้องเรียกจริงก่อนถึงจะมีผลลัพธ์ (ต่างจาก FireServer ที่ log args แล้วปล่อยผ่านทีหลังได้)
                local ok, ret = pcall(old, self, ...)
                pcall(function()
                    local parts = {}
                    for i = 1, math.min(#args, 8) do parts[i] = ser(args[i]) end
                    _G.NSPY76_LOG(("[REMOTE] %s:InvokeServer(%s) → %s"):format(
                        self.Name, table.concat(parts, ", "), ok and ser(ret) or ("ERROR:" .. tostring(ret))))
                end)
                if ok then return ret end
                error(ret, 0)
            end
            task.defer(function()
                pcall(function()
                    local parts = {}
                    for i = 1, math.min(#args, 8) do parts[i] = ser(args[i]) end
                    _G.NSPY76_LOG(("[REMOTE] %s:%s(%s)"):format(
                        self.Name, method, table.concat(parts, ", ")))
                end)
            end)
        end
        return old(self, ...)
    end)
    _G.NSPY76_HOOKED = true
end
_G.NSPY76_LOG = L

-- ==================== 2) leaderstats / เงินบนตัวผู้เล่น ====================
-- ดักทุก NumberValue/IntValue ใต้ leaderstats (และโฟลเดอร์ค่าเงินอื่นที่มักแอบอยู่นอก leaderstats)
local function watchValue(v)
    if not (v:IsA("NumberValue") or v:IsA("IntValue")) then return end
    local last = v.Value
    local c = v:GetPropertyChangedSignal("Value"):Connect(function()
        if PAUSED then return end
        local now = v.Value
        local diff = now - last
        L(("[STAT] %s: %s → %s  (Δ%s%s)"):format(
            v:GetFullName():gsub("^Players%."..LP.Name.."%.", "P."),
            tostring(last), tostring(now),
            diff >= 0 and "+" or "", tostring(diff)))
        last = now
    end)
    table.insert(_G.NSPY76_CONNS, c)
end

local function scanLeaderstats()
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do watchValue(v) end
        table.insert(_G.NSPY76_CONNS, ls.ChildAdded:Connect(watchValue))
        L("[SETUP] ดัก leaderstats: " .. table.concat((function()
            local t = {} for _, v in ipairs(ls:GetChildren()) do t[#t+1] = v.Name end return t
        end)(), ", "))
    else
        L("[SETUP] ไม่เจอ leaderstats — ลองกด LIST ดู remote แทน หรือรอ ChildAdded")
        table.insert(_G.NSPY76_CONNS, LP.ChildAdded:Connect(function(c)
            if c.Name == "leaderstats" then
                task.wait(0.2)
                for _, v in ipairs(c:GetChildren()) do watchValue(v) end
                table.insert(_G.NSPY76_CONNS, c.ChildAdded:Connect(watchValue))
                L("[SETUP] leaderstats โผล่ทีหลัง — ดักแล้ว")
            end
        end))
    end
    -- เผื่อค่าเงินอยู่นอก leaderstats (attribute บนตัว player เอง — เกม tycoon บางเกมทำแบบนี้)
    for k, val in pairs(LP:GetAttributes()) do
        if typeof(val) == "number" then
            L(("[ATTR] Player.%s = %s (เลขล้วน — เฝ้าดูตอนเลขเด้งว่าเปลี่ยนไหม)"):format(k, tostring(val)))
        end
    end
end

-- ==================== 3) ป้ายเลขลอย "+699$" ====================
-- จับตอนป้าย/BillboardGui/TextLabel ที่มี "$" ถูกสร้างขึ้นใหม่ ทั้ง workspace และ PlayerGui
local function looksLikeMoneyPopup(inst)
    if not inst:IsA("TextLabel") and not inst:IsA("TextButton") then return false end
    local t = inst.Text or ""
    return t:find("%$") ~= nil or t:find("[+%-]%s*%d") ~= nil
end

-- กันล็อกซ้ำ: ป้ายเดียวกันโดน DescendantAdded (ตอนสร้าง) + TextChanged (ตอน tween ตั้งค่า) ยิงซ้อนกัน
-- key = instance, value = ข้อความล่าสุดที่ log ไปแล้ว (log ใหม่เฉพาะตอนข้อความเปลี่ยนจริง)
local loggedPopup = setmetatable({}, { __mode = "k" })

local function hookPopup(inst)
    if not looksLikeMoneyPopup(inst) then return end
    if loggedPopup[inst] == inst.Text then return end   -- ข้อความเดิม ไม่ log ซ้ำ
    loggedPopup[inst] = inst.Text
    local parent = inst.Parent
    local anchor = parent
    -- ไล่หา BillboardGui/Part ที่ผูกป้ายนี้อยู่ (จะได้รู้ว่าเด้งจากอาคาร/จุดไหน)
    local hops = 0
    while anchor and hops < 6 do
        if anchor:IsA("BillboardGui") or anchor:IsA("BasePart") or anchor:IsA("Model") then break end
        anchor = anchor.Parent
        hops += 1
    end
    local anchorDesc = anchor and anchor:GetFullName():gsub("^Workspace%.", "WS.") or "?"
    local pos = ""
    if anchor and anchor:IsA("BasePart") then
        pos = (" @ %.0f,%.0f,%.0f"):format(anchor.Position.X, anchor.Position.Y, anchor.Position.Z)
    elseif anchor and anchor:IsA("Model") and anchor.PrimaryPart then
        local p = anchor.PrimaryPart.Position
        pos = (" @ %.0f,%.0f,%.0f"):format(p.X, p.Y, p.Z)
    end
    L(("[POPUP] text=\"%s\" anchor=%s%s"):format(inst.Text, anchorDesc, pos))
end

local function watchContainer(root, label)
    table.insert(_G.NSPY76_CONNS, root.DescendantAdded:Connect(function(inst)
        if PAUSED then return end
        -- popup มักเปลี่ยน .Text หลัง instance ถูกสร้าง (tween ตัวเลข) — ฟังทั้ง 2 จังหวะ (dedupe กันซ้ำแล้ว)
        task.defer(function()
            pcall(hookPopup, inst)
        end)
        if inst:IsA("TextLabel") or inst:IsA("TextButton") then
            local conn
            conn = inst:GetPropertyChangedSignal("Text"):Connect(function()
                if PAUSED then return end
                pcall(hookPopup, inst)
            end)
            table.insert(_G.NSPY76_CONNS, conn)
        end
    end))
    L("[SETUP] ดักป้ายเลขลอยใน " .. label)
end

-- ==================== 4) เฝ้า NpcCaptureCloud ตรงๆ (แหล่งกำเนิด popup เงิน) ====================
local function dumpAttrs(inst)
    local parts = {}
    for k, v in pairs(inst:GetAttributes()) do
        parts[#parts + 1] = k .. "=" .. ser(v)
    end
    return #parts > 0 and table.concat(parts, ", ") or "(ไม่มี attribute)"
end

local function watchCaptureCloud()
    local cloud = workspace:FindFirstChild("NpcCaptureCloud")
    if not cloud then
        L("[SETUP] ยังไม่เจอ NpcCaptureCloud ใน workspace ตอนนี้ — รอ ChildAdded ของ workspace")
        table.insert(_G.NSPY76_CONNS, workspace.ChildAdded:Connect(function(c)
            if c.Name == "NpcCaptureCloud" then
                task.wait(0.1)
                watchCaptureCloud()
            end
        end))
        return
    end
    L("[SETUP] เจอ NpcCaptureCloud — attr ตัวเอง: " .. dumpAttrs(cloud))
    local function onChild(c)
        task.wait()   -- รอ attribute ตั้งค่าเสร็จก่อน (บาง field มาทีหลัง instance ถูกสร้าง)
        L(("[CLOUD] +เพิ่ม %s [%s] attr={%s}"):format(c.Name, c.ClassName, dumpAttrs(c)))
        table.insert(_G.NSPY76_CONNS, c.AttributeChanged:Connect(function(attr)
            if PAUSED then return end
            L(("[CLOUD] %s.%s เปลี่ยนเป็น %s"):format(c.Name, attr, ser(c:GetAttribute(attr))))
        end))
    end
    for _, c in ipairs(cloud:GetChildren()) do task.spawn(onChild, c) end
    table.insert(_G.NSPY76_CONNS, cloud.ChildAdded:Connect(function(c)
        if not PAUSED then task.spawn(onChild, c) end
    end))
    table.insert(_G.NSPY76_CONNS, cloud.ChildRemoved:Connect(function(c)
        if not PAUSED then L(("[CLOUD] -หาย %s [%s]"):format(c.Name, c.ClassName)) end
    end))
end

-- ==================== 5) หา NPC จริง — dump workspace children + จับตอนหายไป (capture) ====================
local function dumpWorkspaceTop()
    local names = {}
    for _, c in ipairs(workspace:GetChildren()) do
        names[#names + 1] = c.Name .. "[" .. c.ClassName .. "]"
    end
    L("[WS-TOP] " .. table.concat(names, ", "))
end

local NPC_KEY = { "npc", "customer", "visitor", "enemy", "mob", "pet", "creature", "zombie", "monster" }
local function looksLikeNpcName(name)
    local l = name:lower()
    for _, k in ipairs(NPC_KEY) do
        if l:find(k, 1, true) then return true end
    end
    return false
end

local function watchNpcRemoval()
    table.insert(_G.NSPY76_CONNS, workspace.DescendantRemoving:Connect(function(inst)
        if PAUSED then return end
        if not inst:IsA("Model") then return end
        local hum = inst:FindFirstChildOfClass("Humanoid")
        if not hum and not looksLikeNpcName(inst.Name) then return end
        L(("[NPC-หาย] %s attr={%s}"):format(inst.Name, dumpAttrs(inst)))
    end))
    L("[SETUP] ดักโมเดล NPC ที่หายไปจาก workspace (สงสัยว่า=ถูกจับ)")
end

-- ==================== 6) ดัก ProximityPrompt (เผื่อการจับใช้ปุ่ม E) ====================
local function watchPrompts()
    local PPS = game:GetService("ProximityPromptService")
    table.insert(_G.NSPY76_CONNS, PPS.PromptTriggered:Connect(function(pp, plr)
        if plr ~= LP or PAUSED then return end
        local holder = pp.Parent
        L(("[PROMPT] '%s' บน %s attr={%s}"):format(
            pp.ActionText, holder and holder.Name or "?", holder and dumpAttrs(holder) or ""))
    end))
    L("[SETUP] ดัก ProximityPrompt ที่กด")
end

-- ==================== 7) มอนสเตอร์ที่วางในฐาน (ตัวจับ NPC ตัวจริง) ====================
local SKIP_NAME = {
    Camera = true, Island = true, NpcShop = true, Terrain = true,
    MonsterPlacementHighlight = true, PersistentTeleportPoints = true, NpcCaptureCloud = true,
}
local function isSkippable(name)
    if SKIP_NAME[name] then return true end
    if name:match("^Npc_%d") then return true end
    if name:find("Icon") or name:find("Backpack") then return true end
    return false
end

local watchedMonster = {}
local function watchMonster(m)
    if watchedMonster[m] then return end
    watchedMonster[m] = true
    L(("[MONSTER] %s [%s] attr={%s}"):format(m.Name, m.ClassName, dumpAttrs(m)))
    table.insert(_G.NSPY76_CONNS, m.AttributeChanged:Connect(function(attr)
        if PAUSED then return end
        L(("[MONSTER] %s.%s → %s"):format(m.Name, attr, ser(m:GetAttribute(attr))))
    end))
end

local function scanMonsters()
    local found = 0
    for _, c in ipairs(workspace:GetChildren()) do
        if (c:IsA("Model") or c:IsA("Folder")) and not isSkippable(c.Name) then
            found += 1
            watchMonster(c)
        end
    end
    table.insert(_G.NSPY76_CONNS, workspace.ChildAdded:Connect(function(c)
        if PAUSED then return end
        if (c:IsA("Model") or c:IsA("Folder")) and not isSkippable(c.Name) then
            task.wait()
            watchMonster(c)
        end
    end))
    L(("[SETUP] เจอมอนสเตอร์/ของวางในฐาน %d ตัว — ดัก attribute แล้ว"):format(found))
end

-- ==================== Buttons ====================
listB.MouseButton1Click:Connect(listRemotes)
clearB.MouseButton1Click:Connect(function() OUT = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "76RB_net_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
    pauseB.BackgroundColor3 = PAUSED and Color3.fromRGB(150, 60, 30) or Color3.fromRGB(90, 90, 40)
end)
closeB.MouseButton1Click:Connect(function()
    _G.NSPY76_LOG = nil
    for _, c in ipairs(_G.NSPY76_CONNS) do pcall(function() c:Disconnect() end) end
    _G.NSPY76_CONNS = {}
    gui:Destroy(); _G.NSPY76_GUI = nil
end)

-- ==================== Setup ====================
scanLeaderstats()
watchContainer(workspace, "Workspace")
watchContainer(LP:WaitForChild("PlayerGui"), "PlayerGui")
watchCaptureCloud()
dumpWorkspaceTop()
watchNpcRemoval()
watchPrompts()
scanMonsters()

L("[NetSpy76 v1.3] hookmetamethod=" .. (hookmetamethod and "✅มี" or "❌ไม่มี (ดัก remote ไม่ได้!)"))
L("→ ปล่อยไว้เฉยๆ 20-30 วิ (ไม่ต้องกดอะไร) → ดู [MONSTER] เปลี่ยนพร้อม [POPUP]/[STAT] ไหม → กด LIST → COPY ส่งผล")
warn("[NetSpy76] loaded")
