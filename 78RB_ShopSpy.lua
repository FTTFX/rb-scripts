-- 78RB_ShopSpy.lua v1.0 — จับรีโมต "ซื้อของ/อัปเกรด" ในร้าน (เกม "ยิงเป็ด" 78)
-- เป้าหมาย: ทำปุ่มซื้อโดยไม่ต้องไปร้าน → ต้องรู้ก่อนว่าปุ่มซื้อยิงรีโมตชื่ออะไร args อะไร
-- วิธี: hook เบา (เก็บค่าดิบลง queue แล้วปล่อยผ่านทันที ไม่ทำงานหนักใน hook = ไม่กระทบเกม)
--   เปิดร้าน → กดซื้อ 1 อย่าง (เช่น อัปดาเมจ) → ดูว่ามี remote ตัวไหนโผล่ + args
-- อ่านอย่างเดียว ไม่แก้ค่า
if _G.SHOP78_GUI then pcall(function() _G.SHOP78_GUI:Destroy() end) end
_G.SHOP78_GEN = (_G.SHOP78_GEN or 0) + 1
local MY_GEN = _G.SHOP78_GEN

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local LOG = {}
local function render()
    local n = #LOG; local lines = {}
    for i = math.max(1, n - 20), n do lines[#lines + 1] = LOG[i] end
    _G.SHOP78_OUT.Text = table.concat(lines, "\n")
end
local function log(s) LOG[#LOG + 1] = s; if #LOG > 400 then table.remove(LOG, 1) end; render() end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "ShopSpy78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.SHOP78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 440, 0, 320); frame.Position = UDim2.new(0, 8, 0.1, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.1
frame.Active = true; frame.Draggable = true

local out = Instance.new("TextLabel", frame)
out.Size = UDim2.new(1, -8, 1, -60); out.Position = UDim2.new(0, 4, 0, 34)
out.BackgroundTransparency = 1; out.TextColor3 = Color3.fromRGB(180, 255, 180)
out.TextSize = 12; out.Font = Enum.Font.Code; out.TextWrapped = true
out.TextXAlignment = Enum.TextXAlignment.Left; out.TextYAlignment = Enum.TextYAlignment.Top
_G.SHOP78_OUT = out

local hint = Instance.new("TextLabel", frame)
hint.Size = UDim2.new(1, -8, 0, 22); hint.Position = UDim2.new(0, 4, 1, -24)
hint.BackgroundTransparency = 1; hint.TextColor3 = Color3.fromRGB(255, 220, 120)
hint.TextSize = 12; hint.Font = Enum.Font.GothamBold; hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "เปิดร้าน → กดซื้อ 1 อย่าง → ดูว่ามี remote อะไรโผล่"

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

-- ==================== แปลง arg เป็นข้อความ ====================
local function argStr(v)
    local t = typeof(v)
    if t == "number" then return ("num(%s)"):format(tostring(v))
    elseif t == "string" then return ('str("%s")'):format(v)
    elseif t == "boolean" then return "bool(" .. tostring(v) .. ")"
    elseif t == "Vector3" then return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "Instance" then return ("Inst(%s=%s)"):format(v.ClassName, v.Name)
    elseif t == "table" then
        local parts = {}
        for k, vv in pairs(v) do
            parts[#parts+1] = tostring(k) .. "=" .. tostring(vv)
            if #parts >= 6 then parts[#parts+1] = "..."; break end
        end
        return "table{" .. table.concat(parts, ",") .. "}"
    end
    return t
end

-- ==================== HOOK เบา: เก็บ FireServer/InvokeServer ทุกตัว ====================
_G.SHOP78_QUEUE = _G.SHOP78_QUEUE or {}
local hookOK, hookErr = pcall(function()
    if not (hookmetamethod and getnamecallmethod) then error("ไม่มี hookmetamethod") end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if _G.SHOP78_GEN == MY_GEN and not paused then
            local packed = table.pack(...)
            local rself = self
            pcall(function()
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    table.insert(_G.SHOP78_QUEUE, { name = rself.Name, method = m, args = packed })
                end
            end)
        end
        return old(self, ...)
    end)
end)

-- ประมวลผลนอก hook (แปลง+log ที่นี่ ปลอดภัย)
task.spawn(function()
    while _G.SHOP78_GEN == MY_GEN do
        local q = _G.SHOP78_QUEUE
        while q and #q > 0 do
            local e = table.remove(q, 1)
            local parts = {}
            for i = 1, e.args.n do parts[#parts + 1] = argStr(e.args[i]) end
            -- กรองรีโมตยิงปืน (AIM/FIRE) ออก ให้เห็นรีโมตร้านชัดๆ
            local isGun = (e.args.n >= 4 and typeof(e.args[1]) == "Vector3")
                or (e.args.n == 1 and typeof(e.args[1]) == "number")
            local tag = isGun and "·" or "🛒"
            log(("%s[%s] %s(%s)"):format(tag, e.method, e.name, table.concat(parts, ", ")))
        end
        task.wait(0.1)
    end
end)

pauseB.MouseButton1Click:Connect(function()
    paused = not paused
    pauseB.Text = paused and "RESUME" or "PAUSE"
    pauseB.BackgroundColor3 = paused and Color3.fromRGB(40,120,40) or Color3.fromRGB(120,90,40)
end)
clearB.MouseButton1Click:Connect(function() LOG = {}; render() end)
copyB.MouseButton1Click:Connect(function()
    local all = table.concat(LOG, "\n")
    if setclipboard then setclipboard(all); log("📋 ก๊อปแล้ว")
    elseif writefile then writefile("78RB_shop_log.txt", all); log("💾 เซฟแล้ว") end
end)
closeB.MouseButton1Click:Connect(function()
    _G.SHOP78_GEN = _G.SHOP78_GEN + 1
    gui:Destroy(); _G.SHOP78_GUI = nil
end)

if hookOK then
    log("✅ พร้อม — 🛒 = รีโมตที่ 'ไม่ใช่ยิงปืน' (น่าจะเป็นซื้อของ)")
    log("   เปิดร้าน แล้วกดซื้อ 1 อย่าง (เช่น อัปดาเมจ) ดูบรรทัด 🛒")
else
    log("❌ hook ไม่ติด: " .. tostring(hookErr))
end
warn("[ShopSpy78] v1.0 loaded")
