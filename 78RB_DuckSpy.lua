-- 78RB_DuckSpy.lua v1.4 — NetSpy เกม "ยิงเป็ด" (โปรเจ็ก 78)
-- v1.4: ปุ่ม BOSS — หาป้าย "<เลข> HP" ทั้ง workspace+PlayerGui แล้วดัมป์พาธเต็มของโมเดลบอส +
--   โครงสร้าง + ValueBase ที่ค่าตรงกับ HP ในป้าย (⬅️) เพื่อรู้ว่าบอสจริงอยู่ที่ไหน/ชื่ออะไร
-- 78RB_DuckSpy.lua v1.3 — NetSpy เกม "ยิงเป็ด" (โปรเจ็ก 78)
-- v1.3: เปิด spy แล้วกดยิง/รีโหลด/ปุ่มไม่ได้เลย — เพราะ __namecall hook ดักการเรียกเมธอดทุกอย่าง
--   ถ้า logic ข้างในพลาดจะทำให้การเรียกเดิมพังหมด → ห่อ pcall ทั้งก้อน + table.pack กัน error เด็ดขาด
-- v1.2: จับคู่นัดยิงกับเป็ดที่ตาย — เป็ดใน Ume หายภายใน 0.6 วิ หลังยิง → tag [KILL?] พร้อม args
--   ของนัดนั้นเต็มๆ (8 ตัวแรก) เพื่อรู้ว่า "นัดที่ฆ่าได้" หน้าตา args เป็นยังไง
-- ดัก 4 อย่าง:
--   [REMOTE] FireServer/InvokeServer ทุกตัว พร้อม args ย่อ (ยิงปืน/โดนเป็ด/เก็บแต้ม จะโผล่ตรงนี้)
--   [MDL+]/[MDL-] โมเดลเกิด/หายใน workspace (เป็ด spawn/ตาย — ได้ชื่อจริงของเป้า)
--   [STAT] leaderstats/ค่าบนตัวผู้เล่นเปลี่ยน (คะแนน/เงิน ก่อน→หลัง)
--   ปุ่ม LIST = สรุปโมเดลใน workspace ตามชื่อ+จำนวน / COPY = ก๊อป log ทั้งหมด
if _G.DS78_GUI then pcall(function() _G.DS78_GUI:Destroy() end) end
if _G.DS78_CONNS then
    for _, c in ipairs(_G.DS78_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.DS78_CONNS = {}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local PAUSED = false
local LOG = {}
local function stamp() return os.date("%H:%M:%S") end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DuckSpy78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.DS78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 352, 0, 300); frame.Position = UDim2.new(0, 8, 0.18, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.15
frame.Active = true; frame.Draggable = true

local out = Instance.new("TextLabel", frame)
out.Size = UDim2.new(1, -8, 1, -40); out.Position = UDim2.new(0, 4, 0, 36)
out.BackgroundTransparency = 1; out.TextColor3 = Color3.fromRGB(180, 255, 180)
out.TextSize = 11; out.Font = Enum.Font.Code; out.TextWrapped = true
out.TextXAlignment = Enum.TextXAlignment.Left; out.TextYAlignment = Enum.TextYAlignment.Top

local function render()
    local n = #LOG
    local lines = {}
    for i = math.max(1, n - 18), n do lines[#lines + 1] = LOG[i] end
    out.Text = table.concat(lines, "\n")
end
local function log(s)
    if PAUSED then return end
    LOG[#LOG + 1] = stamp() .. " " .. s
    if #LOG > 3000 then table.remove(LOG, 1) end
    render()
end

local function mkbtn(txt, x, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0, 44, 0, 24); b.Position = UDim2.new(0, x, 0, 6)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local listB  = mkbtn("LIST", 4, Color3.fromRGB(60, 110, 180))
local duckB  = mkbtn("DUCK", 52, Color3.fromRGB(170, 110, 40))
local bossB  = mkbtn("BOSS", 100, Color3.fromRGB(180, 50, 120))
local clearB = mkbtn("CLR", 148, Color3.fromRGB(110, 110, 40))
local copyB  = mkbtn("COPY", 196, Color3.fromRGB(40, 130, 70))
local pauseB = mkbtn("PAUSE", 244, Color3.fromRGB(140, 80, 30))
local closeB = mkbtn("✕", 292, Color3.fromRGB(120, 40, 40))

-- ==================== helper: ย่อ args ====================
local function short(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then return v.ClassName .. ":" .. v.Name
    elseif t == "Vector3" then return ("(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "CFrame" then return "CF" .. ("(%.0f,%.0f,%.0f)"):format(v.Position.X, v.Position.Y, v.Position.Z)
    elseif t == "table" then
        if depth > 1 then return "{...}" end
        local parts = {}
        local cnt = 0
        for k, x in pairs(v) do
            cnt += 1
            if cnt > 4 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. short(x, depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then return #v > 40 and ('"' .. v:sub(1, 40) .. '..."') or ('"' .. v .. '"')
    else return tostring(v) end
end

-- ==================== [REMOTE] ดัก __namecall ====================
if hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        -- v1.3 สำคัญ: hook นี้ดักการเรียกเมธอด "ทุกอย่าง" ในเกม ถ้า logic ข้างในพลาด/ช้า จะทำให้
        -- การเรียกเดิม (ยิง/รีโหลด/ปุ่ม UI) พังหมด → ห่อ pcall + จับเฉพาะ method เป้าหมายก่อนทำอะไร
        -- และห้าม yield/error เด็ดขาด ส่งของเดิมต่อเสมอไม่ว่าเกิดอะไร
        local args = table.pack(...)
        pcall(function()
            local method = getnamecallmethod()
            if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
                local s = {}
                for i = 1, math.min(args.n, 8) do s[#s + 1] = short(args[i]) end
                local line = ("[REMOTE] %s:%s(%s)"):format(self.Name, method, table.concat(s, ", "))
                log(line)
                if args.n >= 3 and typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                    _G.DS78_LASTSHOT = { t = os.clock(), line = line }
                end
            end
        end)
        return old(self, ...)
    end)
else
    log("⚠️ ไม่มี hookmetamethod — ดัก remote ไม่ได้")
end

-- ==================== [MDL+/-] โมเดลเกิด/หาย ====================
table.insert(_G.DS78_CONNS, workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Model") then
        task.defer(function()
            local pv = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            log(("[MDL+] %s ที่ %s"):format(d:GetFullName(), pv and short(pv.Position) or "?"))
        end)
    end
end))
table.insert(_G.DS78_CONNS, workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then
        -- v1.2: ตายภายใน 0.6 วิ หลังยิง = นัดนั้นน่าจะเป็นนัดที่ฆ่า → tag ให้ชัด
        local ls = _G.DS78_LASTSHOT
        if ls and os.clock() - ls.t < 0.6 and d:IsDescendantOf(workspace:FindFirstChild("Ume") or workspace) then
            log(("[KILL?] %s ตาย หลังนัด: %s"):format(d.Name, ls.line))
        else
            log(("[MDL-] %s"):format(d:GetFullName()))
        end
    end
end))

-- ==================== [STAT] คะแนน/เงินเปลี่ยน ====================
local function watchValue(v)
    if not (v:IsA("IntValue") or v:IsA("NumberValue") or v:IsA("StringValue")) then return end
    local prev = v.Value
    table.insert(_G.DS78_CONNS, v:GetPropertyChangedSignal("Value"):Connect(function()
        log(("[STAT] %s: %s → %s"):format(v:GetFullName(), tostring(prev), tostring(v.Value)))
        prev = v.Value
    end))
end
local function watchContainer(c)
    for _, v in ipairs(c:GetDescendants()) do watchValue(v) end
    table.insert(_G.DS78_CONNS, c.DescendantAdded:Connect(watchValue))
end
if LP:FindFirstChild("leaderstats") then watchContainer(LP.leaderstats) end
table.insert(_G.DS78_CONNS, LP.ChildAdded:Connect(function(c)
    if c.Name == "leaderstats" then watchContainer(c) end
end))

-- ==================== Buttons ====================
listB.MouseButton1Click:Connect(function()
    local counts = {}
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") then counts[m.Name] = (counts[m.Name] or 0) + 1 end
    end
    local arr = {}
    for name, n in pairs(counts) do arr[#arr + 1] = { name, n } end
    table.sort(arr, function(a, b) return a[2] > b[2] end)
    log("===== [LIST] โมเดลใน workspace =====")
    for i = 1, math.min(#arr, 25) do
        log(("  %s x%d"):format(arr[i][1], arr[i][2]))
    end
    log("===== จบ LIST =====")
end)
-- v1.1: แงะโครงสร้างเป็ด 1 ตัว + ดักเลือดเปลี่ยนเรียลไทม์ (ไว้ดูว่า "ตาย" หน้าตาเป็นยังไง)
duckB.MouseButton1Click:Connect(function()
    local f = workspace:FindFirstChild("Ume")
    local duck = nil
    if f then
        for _, m in ipairs(f:GetChildren()) do
            if m:IsA("Model") then duck = m break end
        end
    end
    if not duck then log("[DUCK] ไม่เจอเป็ดใน workspace.Ume ตอนนี้") return end
    log("===== [DUCK] " .. duck.Name .. " =====")
    local hum = duck:FindFirstChildOfClass("Humanoid")
    if hum then
        log(("  Humanoid: HP %.0f/%.0f state=%s"):format(hum.Health, hum.MaxHealth, hum:GetState().Name))
    else
        log("  ไม่มี Humanoid")
    end
    for k, v in pairs(duck:GetAttributes()) do
        log(("  [attr] %s = %s"):format(k, tostring(v)))
    end
    for _, c in ipairs(duck:GetChildren()) do
        local extra = ""
        if c:IsA("IntValue") or c:IsA("NumberValue") or c:IsA("StringValue") or c:IsA("BoolValue") then
            extra = " = " .. tostring(c.Value)
        end
        log(("  %s (%s)%s"):format(c.Name, c.ClassName, extra))
    end
    log("===== จบ DUCK =====")

    -- ดักเลือด/ค่าตัวเลขของตัวนี้เปลี่ยน จนกว่ามันจะหายไป
    if hum then
        table.insert(_G.DS78_CONNS, hum.HealthChanged:Connect(function(h)
            log(("[HP] %s: %.0f/%.0f"):format(duck.Name, h, hum.MaxHealth))
        end))
        table.insert(_G.DS78_CONNS, hum.Died:Connect(function()
            log(("[DIED] %s Humanoid.Died"):format(duck.Name))
        end))
    end
    for _, c in ipairs(duck:GetDescendants()) do
        if c:IsA("IntValue") or c:IsA("NumberValue") then
            local prev = c.Value
            table.insert(_G.DS78_CONNS, c:GetPropertyChangedSignal("Value"):Connect(function()
                log(("[VAL] %s.%s: %s → %s"):format(duck.Name, c.Name, tostring(prev), tostring(c.Value)))
                prev = c.Value
            end))
        end
    end
    for k in pairs(duck:GetAttributes()) do
        table.insert(_G.DS78_CONNS, duck:GetAttributeChangedSignal(k):Connect(function()
            log(("[ATTR] %s.%s → %s"):format(duck.Name, k, tostring(duck:GetAttribute(k))))
        end))
    end
    log("[DUCK] เริ่มดักเลือด/ค่าของ " .. duck.Name .. " แล้ว — ยิงให้ตายดูว่าเปลี่ยนยังไง")
end)

-- ==================== [BOSS] หาการ์ด HP บอส แล้วดัมป์พาธ/โครงสร้าง/ที่เก็บ HP ====================
bossB.MouseButton1Click:Connect(function()
    -- หา TextLabel ที่มีข้อความ "<เลข> HP" ทั้งใน workspace และ PlayerGui
    local found = {}
    local function scan(root, where)
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:find("%d+%s*HP") then
                found[#found + 1] = { lbl = d, where = where }
            end
        end
    end
    scan(workspace, "workspace")
    scan(LP.PlayerGui, "PlayerGui")
    if #found == 0 then log("[BOSS] ไม่เจอป้าย HP บนจอ — บอสต้องโผล่ก่อน") return end

    for _, e in ipairs(found) do
        local d = e.lbl
        log(("===== [BOSS] ป้าย HP: \"%s\" (%s) ====="):format(d.Text, e.where))
        log("  พาธป้าย: " .. d:GetFullName())
        -- โมเดลบอส = Model บรรพบุรุษที่ใกล้สุด (เฉพาะป้ายใน workspace ถึงจะมีตัวจริง)
        local m = d:FindFirstAncestorWhichIsA("Model")
        if m then
            log("  🦆 โมเดลบอส: " .. m:GetFullName())
            log("    ลูก: ")
            for _, c in ipairs(m:GetChildren()) do
                local extra = ""
                if c:IsA("ValueBase") then extra = " = " .. tostring(c.Value) end
                log(("      %s (%s)%s"):format(c.Name, c.ClassName, extra))
            end
            for k, v in pairs(m:GetAttributes()) do
                log(("      [attr] %s = %s"):format(k, tostring(v)))
            end
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum then log(("    ♥ Humanoid %s/%s"):format(hum.Health, hum.MaxHealth)) end
            -- หา ValueBase เลขที่น่าจะเป็น HP (ค่าตรงกับเลขในป้าย)
            local hpNum = tonumber(d.Text:match("(%d+)"))
            for _, c in ipairs(m:GetDescendants()) do
                if (c:IsA("IntValue") or c:IsA("NumberValue")) then
                    local mark = (hpNum and math.abs(c.Value - hpNum) < 1) and "  ⬅️ ตรงกับป้าย!" or ""
                    log(("    val %s = %s%s"):format(c:GetFullName():gsub(m:GetFullName(), "…"), c.Value, mark))
                end
            end
        else
            log("  (ป้ายอยู่ใน GUI ไม่มีโมเดลตัวจริง — HP อาจเก็บฝั่ง client)")
        end
        log("===== จบ BOSS =====")
    end
end)

clearB.MouseButton1Click:Connect(function() LOG = {} render() end)
copyB.MouseButton1Click:Connect(function()
    local all = table.concat(LOG, "\n")
    if setclipboard then
        setclipboard(all)
        log("📋 ก๊อปลงคลิปบอร์ดแล้ว (" .. #LOG .. " บรรทัด)")
    elseif writefile then
        writefile("78RB_duck_log.txt", all)
        log("💾 เซฟไฟล์ 78RB_duck_log.txt แล้ว")
    end
end)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
end)
closeB.MouseButton1Click:Connect(function()
    for _, c in ipairs(_G.DS78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DS78_CONNS = {}
    gui:Destroy(); _G.DS78_GUI = nil
end)

log("[DuckSpy78] เริ่มดักแล้ว — ยิงเป็ดสัก 2-3 ตัว แล้วกด LIST + COPY ส่ง log มา")
warn("[DuckSpy78] loaded")
