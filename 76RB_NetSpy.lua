-- 76RB_NetSpy.lua v1.0 — สปายเกมทันคูน เบซิก (Tycoon Basic)
-- เป้าหมาย: หาว่าเลข "+699$" ที่เด้งขึ้นมา คำนวนจากอะไร (rate ต่ออาคาร? ต่อผู้เยี่ยมชม? สุ่ม?)
-- ดัก 3 อย่างพร้อมกัน:
--   1) Remote  — FireServer/InvokeServer ทุกตัว (โดยเฉพาะที่มีคำว่า Cash/Money/Income/Collect/Buy)
--   2) leaderstats / ค่าเงินบนตัวผู้เล่น — GetPropertyChangedSignal("Value") ทุกครั้งที่เปลี่ยน (log ค่าก่อน/หลัง/ผลต่าง)
--   3) ป้ายเลขลอย (+699$) ที่โผล่ใน workspace/PlayerGui — DescendantAdded จับ TextLabel/BillboardGui ที่มี "$" ในข้อความ ทันทีที่ถูกสร้าง (log ตำแหน่ง/พาเรนต์ = รู้ว่าเด้งจากอาคารไหน)
-- วิธีใช้: รัน → ไปยืนใกล้อาคารที่สร้างรายได้ รอให้เลขเด้ง 3-4 ครั้ง (จับเวลาห่างกันด้วยจะได้คำนวน "ต่อวินาที")
--         → ลองซื้ออาคารใหม่ 1 หลัง ดูว่ามี remote ไหนถูกยิง → กด COPY ส่งผลมา
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

-- ==================== 1) HOOK __namecall (ดัก remote ทุกครั้งที่ยิง) ====================
if not _G.NSPY76_HOOKED and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer")
            and not PAUSED and _G.NSPY76_LOG then
            local args = { ... }
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

local function hookPopup(inst)
    if not looksLikeMoneyPopup(inst) then return end
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
        -- popup มักเปลี่ยน .Text หลัง instance ถูกสร้าง (tween ตัวเลข) — ฟังทั้ง 2 จังหวะ
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

L("[NetSpy76 v1.0] hookmetamethod=" .. (hookmetamethod and "✅มี" or "❌ไม่มี (ดัก remote ไม่ได้!)"))
L("→ ไปยืนใกล้อาคารที่ปั๊มเงิน รอเลข +699$ เด้ง 3-4 ครั้ง (จับเวลาห่างด้วย) → กด LIST ดู remote เงิน → COPY ส่งผล")
warn("[NetSpy76] loaded")
