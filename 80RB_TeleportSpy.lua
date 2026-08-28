-- 80RB_TeleportSpy.lua v1.0 — จับว่าเกม "วาป" ยังไง: ดัก remote ตอนตำแหน่งเด้ง
-- หลักการ (3 ชั้น):
--   1) HOOK __namecall → เก็บ FireServer/InvokeServer ทุกตัว พร้อมเวลา + args (เก็บ raw ไว้ replay)
--   2) Heartbeat → วัดระยะกระโดดของ HumanoidRootPart ต่อเฟรม
--      เด้ง > 35 สตัดใน 1 เฟรม = "มีการวาป" → ย้อนดู remote ที่ยิงก่อนหน้า 1.5 วิ
--   3) LIST → หา remote ชื่อ tp/teleport/warp/position/cframe ฯลฯ | REPLAY → ยิง remote ตัวสงสัยซ้ำ
-- วิธีใช้: รัน → ไปทำให้เกมวาป 1 ครั้ง (กด E ขึ้นด่าน/เช็คพอยต์/ประตู) → อ่าน log ช่อง "จับวาปได้"
-- ถ้า log บอก "ไม่มี remote ยิงช่วงนั้น" = เกมวาปฝั่ง server ล้วน → ยิง remote เองไม่ได้
-- ปุ่ม: LIST | REPLAY | PAUSE | CLEAR | COPY | ✕
if _G.TPSY80_GUI then pcall(function() _G.TPSY80_GUI:Destroy() end) end
if _G.TPSY80_PPCONN then pcall(function() _G.TPSY80_PPCONN:Disconnect() end) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer

local OUT = {}
local PAUSED = false
local MAXLINES = 500
local JUMP_STUDS = 35          -- ระยะกระโดดต่อเฟรมที่ถือว่า "วาป"
local CORRELATE_WINDOW = 1.5   -- ย้อนดู remote ที่ยิงก่อนวาป ไม่เกินกี่วินาที
local REMOTE_LOG = {}          -- ring buffer: {t, name, method, args(raw), remote, path}
local SUSPECT                  -- remote ตัวล่าสุดที่ยิงก่อนวาป (สำหรับ REPLAY)
local TP_COUNT = 0

local gui = Instance.new("ScreenGui")
gui.Name = "TeleSpy80"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.TPSY80_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 680, 0, 380); box.Position = UDim2.new(0, 8, 0.24, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(180, 255, 200); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    OUT[#OUT + 1] = s
    if #OUT > MAXLINES then table.remove(OUT, 1) end
    redraw()
end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.24, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local listB   = hbtn("LIST", 8, 60, Color3.fromRGB(40, 130, 70))
local replayB = hbtn("REPLAY", 74, 76, Color3.fromRGB(120, 60, 150))
local pauseB  = hbtn("PAUSE", 156, 72, Color3.fromRGB(90, 90, 40))
local clearB  = hbtn("CLEAR", 234, 68, Color3.fromRGB(90, 60, 30))
local copyB   = hbtn("COPY", 308, 64)
local closeB  = hbtn("✕", 378, 34, Color3.fromRGB(150, 40, 40))

-- ==================== serialize args (โชว์) + เก็บ raw (replay) ====================
local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then
        return "<" .. v.ClassName .. ":" .. v:GetFullName():gsub("^Workspace%.", "WS."):gsub("^ReplicatedStorage%.", "RS.") .. ">"
    elseif t == "CFrame" then
        return ("CF(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "Vector3" then
        return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "table" then
        if depth > 2 then return "{...}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n += 1
            if n > 8 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. ser(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "string" then
        return '"' .. (v:len() > 60 and v:sub(1, 60) .. "…" or v) .. '"'
    end
    return tostring(v)
end

-- ==================== HOOK __namecall (ครั้งเดียวต่อ session) ====================
if not _G.TPSY80_HOOKED and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and not PAUSED and _G.TPSY80_LOG then
            local args = { ... }
            task.defer(function()
                pcall(function()
                    local entry = {
                        t = os.clock(),
                        name = self.Name,
                        method = method,
                        remote = self,
                        path = self:GetFullName():gsub("^ReplicatedStorage%.", "RS."):gsub("^Workspace%.", "WS."),
                        args = args,
                    }
                    table.insert(REMOTE_LOG, entry)
                    if #REMOTE_LOG > 120 then table.remove(REMOTE_LOG, 1) end

                    local parts = {}
                    for i = 1, math.min(#args, 8) do parts[i] = ser(args[i]) end
                    _G.TPSY80_LOG(("[%s] %s:%s(%s)"):format(
                        os.date("%H:%M:%S"), entry.name, method, table.concat(parts, ", ")))
                end)
            end)
        end
        return old(self, ...)
    end)
    _G.TPSY80_HOOKED = true
end
_G.TPSY80_LOG = L

-- ==================== จับ "วาป": ตำแหน่งเด้งเกิน 35 สตัดต่อเฟรม ====================
local lastPos, lastRoot
RunService.Heartbeat:Connect(function()
    if PAUSED then return end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then lastPos, lastRoot = nil, nil return end

    local pos = root.Position
    if lastPos and lastRoot == root then
        local jump = (pos - lastPos).Magnitude
        if jump > JUMP_STUDS then
            TP_COUNT += 1
            L("════════════════════════════════")
            L(("[%s] 🌀 วาป! เด้ง %.0f สตัดใน 1 เฟรม → %s"):format(
                os.date("%H:%M:%S"), jump,
                ("%.0f,%.0f,%.0f"):format(pos.X, pos.Y, pos.Z)))
            L("→ remote ที่ยิง " .. CORRELATE_WINDOW .. " วิก่อนหน้า:")
            local now = os.clock()
            local found = 0
            for i = #REMOTE_LOG, 1, -1 do
                local e = REMOTE_LOG[i]
                if now - e.t > CORRELATE_WINDOW then break end
                found += 1
                local parts = {}
                for a = 1, math.min(#e.args, 8) do parts[a] = ser(e.args[a]) end
                L(("   ★ %s [%s]\n      %s(%s)"):format(
                    e.path, e.remote.ClassName, e.method, table.concat(parts, ", ")))
                if not SUSPECT or e.t >= SUSPECT.t then
                    local hasPos = false
                    for a = 1, #e.args do
                        local at = typeof(e.args[a])
                        if at == "CFrame" or at == "Vector3" or at == "Instance" then hasPos = true break end
                    end
                    if hasPos or found == 1 then SUSPECT = e end
                end
            end
            if found == 0 then
                L("   (ไม่มี remote ยิงเลย = เกมวาปฝั่ง server เงียบๆ — client ยิงเองไม่ได้)")
                L("   ลองเช็ค: ProximityPrompt / Seat / SpawnLocation / แรงระเบิดในเกม")
            else
                L("→ กด REPLAY เพื่อยิง remote นี้ซ้ำทดสอบว่าวาปได้จริงไหม")
            end
            L("════════════════════════════════")
        end
    end
    lastPos, lastRoot = pos, root
end)

-- ==================== ดัก ProximityPrompt (กด E อาจเป็นตัวชนวนวาป) ====================
_G.TPSY80_PPCONN = ProximityPromptService.PromptTriggered:Connect(function(pp, plr)
    if plr ~= LP or PAUSED or not _G.TPSY80_LOG then return end
    _G.TPSY80_LOG(("[%s] PROMPT '%s' @ %s"):format(os.date("%H:%M:%S"),
        pp.ActionText, pp.Parent and pp.Parent:GetFullName():gsub("^Workspace%.", "WS.") or "?"))
end)

-- ==================== LIST: remote ชื่อคล้ายวาป ====================
local function listRemotes()
    L("=== remote ชื่อเดาว่า 'วาป/ย้าย' ===")
    local keys = { "tp", "teleport", "warp", "position", "cframe", "setpos",
        "move", "place", "checkpoint", "spawn", "return", "back", "pin" }
    local n = 0
    for _, svc in ipairs({ RS, workspace, Players }) do
        pcall(function()
            for _, r in ipairs(svc:GetDescendants()) do
                if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                    local ln = r.Name:lower()
                    for _, k in ipairs(keys) do
                        if ln:find(k, 1, true) then
                            n += 1
                            L(("★ %s [%s]"):format(r:GetFullName(), r.ClassName))
                            break
                        end
                    end
                end
            end
        end)
    end
    if n == 0 then L("(ไม่เจอ — วาปอาจซ่อนใน remote ชื่ออื่น ใช้วิธีจับวาปแทน)") end
    L("=== เจอ " .. n .. " ตัว ===")
end

-- ==================== REPLAY: ยิง remote ตัวสงสัยซ้ำ ====================
local function replaySuspect()
    if not SUSPECT then
        L("ยังไม่มีตัวสงสัย — รอจับวาปก่อน แล้วกด REPLAY")
        return
    end
    if not SUSPECT.remote or not SUSPECT.remote.Parent then
        L("remote ถูกลบไปแล้ว รอจับวาปใหม่")
        return
    end
    local ok, err = pcall(function()
        if SUSPECT.method == "InvokeServer" then
            SUSPECT.remote:InvokeServer(unpack(SUSPECT.args))
        else
            SUSPECT.remote:FireServer(unpack(SUSPECT.args))
        end
    end)
    L(ok and ("🔁 REPLAY %s:%s สำเร็จ — ถ้าเกมวาป = เจอตัวจริง ใช้ยิงเองได้เลย"
        or "🔁 REPLAY พัง: %s"):format(SUSPECT.name, SUSPECT.method), err or "")
end

-- ==================== Buttons ====================
listB.MouseButton1Click:Connect(listRemotes)
replayB.MouseButton1Click:Connect(replaySuspect)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
    pauseB.BackgroundColor3 = PAUSED and Color3.fromRGB(150, 60, 30) or Color3.fromRGB(90, 90, 40)
end)
clearB.MouseButton1Click:Connect(function() OUT = {}; REMOTE_LOG = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "80RB_telespy_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.TPSY80_LOG = nil
    if _G.TPSY80_PPCONN then pcall(function() _G.TPSY80_PPCONN:Disconnect() end) end
    gui:Destroy(); _G.TPSY80_GUI = nil
end)

L("[TeleSpy80 v1.0] hookmetamethod=" .. (hookmetamethod and "✅มี" or "❌ไม่มี (ดัก remote ไม่ได้!)")
    .. " | จับวาป=✅ ดักปุ่ม E=✅")
L("→ ไปทำให้เกมวาป 1 ครั้ง (กด E/เช็คพอยต์/ประตู) แล้วดูช่อง '🌀 วาป!'")
