-- 77RB_HouseClean_NetSpy.lua v1.0 — สปายเกม "ล้างบ้านขำๆ" (ยังไม่รู้ชื่อเกมจริง/PlaceId)
-- กลไกหลักที่ผู้ใช้บอก: จับของ (grab) → หาที่วาง (place) — เป้าหมาย: ดูว่า remote/ระบบไหนคุมการจับ-วางของ
-- วิธีใช้: รันสคริปต์ในเกม → จับของ 1 ชิ้นแล้ววางที่ถูกจุด → ดู log:
--   [PROMPT] เผื่อจับ/วางด้วยปุ่ม E
--   [EQUIP]/[UNEQUIP] เผื่อของที่จับเป็น Tool ใน Backpack
--   [REMOTE] ทุกครั้งที่ยิง RemoteEvent/RemoteFunction ไปเซิร์ฟเวอร์ (ไฮไลต์คำที่เกี่ยวจับ/วาง)
--   [DRAG-UI] เผื่อใช้ mouse drag (ClickDetector/UserInputService) แทนปุ่ม E
--   [ITEM+]/[ITEM-] เผื่อของจริงๆ ถูกสร้าง/ลบใน workspace ตอนจับ/วางสำเร็จ
-- แล้วกด LIST ดู remote ทั้งหมด → กด COPY ส่ง log กลับมาวิเคราะห์
-- ปุ่ม: LIST | CLEAR | COPY | PAUSE | ✕
if _G.NSPY77_GUI then pcall(function() _G.NSPY77_GUI:Destroy() end) end
if _G.NSPY77_CONNS then
    for _, c in ipairs(_G.NSPY77_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.NSPY77_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local OUT = {}
local PAUSED = false
local MAXLINES = 500
local START_T = tick()

local gui = Instance.new("ScreenGui")
gui.Name = "NetSpy77"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.NSPY77_GUI = gui

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

local function dumpAttrs(inst)
    local parts = {}
    for k, v in pairs(inst:GetAttributes()) do
        parts[#parts + 1] = k .. "=" .. ser(v)
    end
    return #parts > 0 and table.concat(parts, ", ") or "(ไม่มี attribute)"
end

-- ==================== LIST remotes ====================
local KEY = {
    "grab", "pickup", "pick_up", "hold", "carry", "place", "drop", "put",
    "clean", "wash", "sort", "tidy", "throw", "trash", "item", "object", "task", "chore",
}
local function listRemotes()
    L("=== REMOTES ใน ReplicatedStorage (ไฮไลต์ตัวที่น่าจะเกี่ยวจับ/วางของ) ===")
    local n, hit = 0, 0
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
    L(("=== รวม %d ตัว (ไฮไลต์ %d ตัวที่ชื่อพ้องจับ/วาง) ==="):format(n, hit))
end

-- ==================== 1) HOOK __namecall (ดัก remote ทุกครั้งที่ยิง) ====================
if not _G.NSPY77_HOOKED and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer")
            and not PAUSED and _G.NSPY77_LOG then
            local args = { ... }
            if method == "InvokeServer" then
                local ok, ret = pcall(old, self, ...)
                pcall(function()
                    local parts = {}
                    for i = 1, math.min(#args, 8) do parts[i] = ser(args[i]) end
                    _G.NSPY77_LOG(("[REMOTE] %s:InvokeServer(%s) → %s"):format(
                        self.Name, table.concat(parts, ", "), ok and ser(ret) or ("ERROR:" .. tostring(ret))))
                end)
                if ok then return ret end
                error(ret, 0)
            end
            task.defer(function()
                pcall(function()
                    local parts = {}
                    for i = 1, math.min(#args, 8) do parts[i] = ser(args[i]) end
                    _G.NSPY77_LOG(("[REMOTE] %s:%s(%s)"):format(
                        self.Name, method, table.concat(parts, ", ")))
                end)
            end)
        end
        return old(self, ...)
    end)
    _G.NSPY77_HOOKED = true
end
_G.NSPY77_LOG = L

-- ==================== 2) ProximityPrompt (จับ/วางด้วยปุ่ม E บ่อยสุด) ====================
local function watchPrompts()
    local PPS = game:GetService("ProximityPromptService")
    table.insert(_G.NSPY77_CONNS, PPS.PromptTriggered:Connect(function(pp, plr)
        if plr ~= LP or PAUSED then return end
        local holder = pp.Parent
        L(("[PROMPT] '%s' (ObjectText='%s') บน %s attr={%s}"):format(
            pp.ActionText, pp.ObjectText, holder and holder:GetFullName():gsub("^Workspace%.", "WS.") or "?",
            holder and dumpAttrs(holder) or ""))
    end))
    L("[SETUP] ดัก ProximityPrompt ที่กด (คาดว่าใช้จับ/วางของ)")
end

-- ==================== 3) Tool equip/unequip (เผื่อของที่จับเป็น Tool จริง) ====================
local function watchTools()
    local char = LP.Character
    if not char then return end
    table.insert(_G.NSPY77_CONNS, char.ChildAdded:Connect(function(c)
        if PAUSED then return end
        if c:IsA("Tool") then
            L(("[EQUIP] ถือ %s attr={%s}"):format(c.Name, dumpAttrs(c)))
        end
    end))
    table.insert(_G.NSPY77_CONNS, char.ChildRemoved:Connect(function(c)
        if PAUSED then return end
        if c:IsA("Tool") then
            L(("[UNEQUIP] ปล่อย %s"):format(c.Name))
        end
    end))
    L("[SETUP] ดัก Tool equip/unequip บนตัวละคร")
end

-- ==================== 4) ClickDetector / mouse drag (เผื่อวางของด้วยเมาส์ ไม่ใช่ปุ่ม E) ====================
local function watchClickDetectors()
    local function hook(cd)
        table.insert(_G.NSPY77_CONNS, cd.MouseClick:Connect(function(plr)
            if plr ~= LP or PAUSED then return end
            local holder = cd.Parent
            L(("[CLICK] ClickDetector บน %s attr={%s}"):format(
                holder and holder:GetFullName():gsub("^Workspace%.", "WS.") or "?",
                holder and dumpAttrs(holder) or ""))
        end))
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ClickDetector") then hook(d) end
    end
    table.insert(_G.NSPY77_CONNS, workspace.DescendantAdded:Connect(function(d)
        if not PAUSED and d:IsA("ClickDetector") then hook(d) end
    end))
    L("[SETUP] ดัก ClickDetector ใน workspace")

    -- เผื่อระบบ drag ใช้ UserInputService ล้วน (ไม่มี ClickDetector) — log แค่จังหวะเริ่ม/จบ drag
    table.insert(_G.NSPY77_CONNS, UIS.InputBegan:Connect(function(input, processed)
        if PAUSED or processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            L("[DRAG-UI] MouseButton1/Touch เริ่มกด (เผื่อเริ่มลาก item)")
        end
    end))
end

-- ==================== 5) ของในบ้าน (item) ที่ถูกสร้าง/ลบใน workspace ====================
local ITEM_KEY = { "item", "dirt", "trash", "dish", "toy", "clothes", "sock", "book", "grab", "prop" }
local function looksLikeItemName(name)
    local l = name:lower()
    for _, k in ipairs(ITEM_KEY) do
        if l:find(k, 1, true) then return true end
    end
    return false
end
local function watchItems()
    table.insert(_G.NSPY77_CONNS, workspace.DescendantAdded:Connect(function(inst)
        if PAUSED then return end
        if (inst:IsA("Model") or inst:IsA("BasePart")) and looksLikeItemName(inst.Name) then
            L(("[ITEM+] เกิด %s [%s]"):format(inst.Name, inst.ClassName))
        end
    end))
    table.insert(_G.NSPY77_CONNS, workspace.DescendantRemoving:Connect(function(inst)
        if PAUSED then return end
        if (inst:IsA("Model") or inst:IsA("BasePart")) and looksLikeItemName(inst.Name) then
            L(("[ITEM-] หาย %s [%s] attr={%s}"):format(inst.Name, inst.ClassName, dumpAttrs(inst)))
        end
    end))
    L("[SETUP] ดักของในบ้าน (ชื่อพ้อง item/dirt/trash/dish/toy/...) เกิด/หายใน workspace")
end

-- ==================== 6) leaderstats (เผื่อมีคะแนน/เงินให้ตอนจับ-วางถูก) ====================
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
    table.insert(_G.NSPY77_CONNS, c)
end
local function scanLeaderstats()
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do watchValue(v) end
        table.insert(_G.NSPY77_CONNS, ls.ChildAdded:Connect(watchValue))
        L("[SETUP] ดัก leaderstats: " .. table.concat((function()
            local t = {} for _, v in ipairs(ls:GetChildren()) do t[#t+1] = v.Name end return t
        end)(), ", "))
    else
        L("[SETUP] ไม่เจอ leaderstats — เกมนี้อาจไม่มีคะแนน/เงิน หรือยังไม่โหลด")
        table.insert(_G.NSPY77_CONNS, LP.ChildAdded:Connect(function(c)
            if c.Name == "leaderstats" then
                task.wait(0.2)
                for _, v in ipairs(c:GetChildren()) do watchValue(v) end
                table.insert(_G.NSPY77_CONNS, c.ChildAdded:Connect(watchValue))
                L("[SETUP] leaderstats โผล่ทีหลัง — ดักแล้ว")
            end
        end))
    end
end

-- ==================== 7) workspace top-level dump (หา folder เก็บของ/จุดวาง) ====================
local function dumpWorkspaceTop()
    local names = {}
    for _, c in ipairs(workspace:GetChildren()) do
        names[#names + 1] = c.Name .. "[" .. c.ClassName .. "]"
    end
    L("[WS-TOP] " .. table.concat(names, ", "))
end

-- ==================== Buttons ====================
listB.MouseButton1Click:Connect(listRemotes)
clearB.MouseButton1Click:Connect(function() OUT = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "77RB_net_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
    pauseB.BackgroundColor3 = PAUSED and Color3.fromRGB(150, 60, 30) or Color3.fromRGB(90, 90, 40)
end)
closeB.MouseButton1Click:Connect(function()
    _G.NSPY77_LOG = nil
    for _, c in ipairs(_G.NSPY77_CONNS) do pcall(function() c:Disconnect() end) end
    _G.NSPY77_CONNS = {}
    gui:Destroy(); _G.NSPY77_GUI = nil
end)

-- ==================== Setup ====================
scanLeaderstats()
watchPrompts()
watchTools()
watchClickDetectors()
watchItems()
dumpWorkspaceTop()

L("[NetSpy77 v1.0] hookmetamethod=" .. (hookmetamethod and "✅มี" or "❌ไม่มี (ดัก remote ไม่ได้!)"))
L("→ วิธีทดสอบ: จับของ 1 ชิ้น (ดู [PROMPT]/[EQUIP]/[CLICK]) → เอาไปวางที่ถูกจุด (ดู [REMOTE]/[ITEM-]/[STAT])")
L("→ ถ้ายังไม่เห็น log ตอนจับ/วาง ให้กด LIST ดู remote ทั้งหมด แล้วลองจับ-วางอีกที ดูว่า [REMOTE] ตัวไหนยิงตรงจังหวะนั้น")
warn("[NetSpy77] loaded")
