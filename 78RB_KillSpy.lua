-- 78RB_KillSpy.lua v1.0 — จับ "remote ทุกตัว" ตอนยิงเป็ด (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- โจทย์: เกมซอมบี้ (27.txt) ใช้ remote เดียว GunHit(ปืน, zombieId, pos) = ลงดาเมจตาม ID ตรงๆ
--   สงสัยว่าเกมเป็ดก็มี remote แบบ ID ซ่อนอยู่ไหม (hook เดิมจับแค่ 2 ลายเซ็น เลยพลาด remote อื่น)
-- ตัวนี้ log "ทุก FireServer/InvokeServer" พร้อม args เต็ม + ไฮไลต์ arg ที่ตรงกับ ID เป็ดที่ยังบินอยู่
-- อ่านอย่างเดียว ไม่แก้ค่า (return old(...) เดิม) ปลอดภัย ไม่กระทบการยิง/รีโหลด
if _G.KS78_GUI then pcall(function() _G.KS78_GUI:Destroy() end) end
if _G.KS78_CONNS then
    for _, c in ipairs(_G.KS78_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.KS78_CONNS = {}
_G.KS78_GEN = (_G.KS78_GEN or 0) + 1
local MY_GEN = _G.KS78_GEN

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local LOG = {}
local t0 = os.clock()
local function stamp() return os.date("%H:%M:%S") end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "KillSpy78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.KS78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 400, 0, 300); frame.Position = UDim2.new(0, 8, 0.12, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.12
frame.Active = true; frame.Draggable = true

local out = Instance.new("TextLabel", frame)
out.Size = UDim2.new(1, -8, 1, -38); out.Position = UDim2.new(0, 4, 0, 34)
out.BackgroundTransparency = 1; out.TextColor3 = Color3.fromRGB(180, 255, 180)
out.TextSize = 11; out.Font = Enum.Font.Code; out.TextWrapped = true
out.TextXAlignment = Enum.TextXAlignment.Left; out.TextYAlignment = Enum.TextYAlignment.Top

local function render()
    local n = #LOG
    local lines = {}
    for i = math.max(1, n - 24), n do lines[#lines + 1] = LOG[i] end
    out.Text = table.concat(lines, "\n")
end
local function log(s)
    LOG[#LOG + 1] = ("%s [+%.2f] %s"):format(stamp(), os.clock() - t0, s)
    if #LOG > 3000 then table.remove(LOG, 1) end
    render()
end

local function mkbtn(txt, x, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0, 74, 0, 24); b.Position = UDim2.new(0, x, 0, 5)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local pauseB = mkbtn("PAUSE", 4, Color3.fromRGB(120, 90, 40))
local clearB = mkbtn("CLR", 82, Color3.fromRGB(110, 110, 40))
local copyB  = mkbtn("COPY", 160, Color3.fromRGB(40, 130, 70))
local closeB = mkbtn("✕", 238, Color3.fromRGB(120, 40, 40))
local paused = false

-- ==================== หา ID เป็ดที่ยังบินอยู่ (DuckController_Client_N) ====================
local function duckFolder()
    return workspace:FindFirstChild("Ume") or workspace
end
-- คืน set ของเลข ID เป็ดที่ยังบิน (ไม่รวมศพ Landed) เพื่อไฮไลต์ arg ที่ตรงกับ ID
local function liveDuckIDs()
    local ids = {}
    local ok = pcall(function()
        for _, m in ipairs(duckFolder():GetDescendants()) do
            if m:IsA("Model") and m.Name:find("Duck") and not m.Name:find("Landed") then
                local id = tonumber(m.Name:match("(%d+)"))
                if id then ids[id] = m.Name end
            end
        end
    end)
    return ids
end

-- ==================== แปลง arg เป็นข้อความอ่านง่าย + ตรวจว่าตรง ID เป็ดไหม ====================
local function argStr(v, duckIDs)
    local t = typeof(v)
    if t == "number" then
        local tag = duckIDs[v] and (" ⬅️เป็ด#" .. v) or ""
        return ("num(%s)%s"):format(tostring(v), tag)
    elseif t == "Vector3" then
        return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "string" then
        return ('str("%s")'):format(v)
    elseif t == "boolean" then
        return "bool(" .. tostring(v) .. ")"
    elseif t == "Instance" then
        local id = tonumber(v.Name:match("(%d+)") or "")
        local tag = (id and duckIDs[id]) and " ⬅️เป็ด!" or ""
        return ("Inst(%s=%s)%s"):format(v.ClassName, v.Name, tag)
    elseif t == "table" then
        return "table{...}"
    end
    return t
end

-- ==================== HOOK: log ทุก FireServer/InvokeServer (อ่านอย่างเดียว) ====================
local hookOK, hookErr = pcall(function()
    if not (hookmetamethod and getnamecallmethod) then
        error("executor ไม่มี hookmetamethod")
    end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local a = table.pack(...)
        local rself = self
        pcall(function()
            if paused or _G.KS78_GEN ~= MY_GEN then return end
            local m = getnamecallmethod()
            if m ~= "FireServer" and m ~= "InvokeServer" then return end
            local duckIDs = liveDuckIDs()
            local parts = {}
            local hitDuck = false
            for i = 1, a.n do
                local s = argStr(a[i], duckIDs)
                if s:find("เป็ด") then hitDuck = true end
                parts[#parts + 1] = s
            end
            local rname = "?"
            pcall(function() rname = rself.Name end)
            local mark = hitDuck and "🎯 " or ""
            log(("%s[%s] %s(%s)"):format(mark, m, rname, table.concat(parts, ", ")))
        end)
        return old(rself, ...)
    end)
end)

if hookOK then
    log("✅ hook พร้อม — ยิงมือใส่เป็ด 1-2 นัด แล้วดูว่ามี remote ตัวไหน args มี ⬅️เป็ด# ไหม")
    log("   ถ้าเจอ = เกมเป็ดมี remote แบบ ID เหมือนซอมบี้ (ยิงรัวได้!) ถ้าไม่เจอ = มีแต่ hitscan")
else
    log("❌ hook ไม่ติด: " .. tostring(hookErr))
end
log(("(เห็นเป็ดบินอยู่ตอนนี้ %d ตัว)"):format((function() local n=0 for _ in pairs(liveDuckIDs()) do n=n+1 end return n end)()))

-- ==================== Buttons ====================
pauseB.MouseButton1Click:Connect(function()
    paused = not paused
    pauseB.Text = paused and "RESUME" or "PAUSE"
    pauseB.BackgroundColor3 = paused and Color3.fromRGB(40,120,40) or Color3.fromRGB(120,90,40)
end)
clearB.MouseButton1Click:Connect(function() LOG = {}; render() end)
copyB.MouseButton1Click:Connect(function()
    local all = table.concat(LOG, "\n")
    if setclipboard then
        setclipboard(all); log("📋 ก๊อปแล้ว (" .. #LOG .. " บรรทัด)")
    elseif writefile then
        writefile("78RB_kill_log.txt", all); log("💾 เซฟ 78RB_kill_log.txt แล้ว")
    end
end)
closeB.MouseButton1Click:Connect(function()
    _G.KS78_GEN = _G.KS78_GEN + 1 -- ปิด hook เก่า
    gui:Destroy(); _G.KS78_GUI = nil
end)

warn("[KillSpy78] loaded")
