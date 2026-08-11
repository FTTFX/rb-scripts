-- 78RB_FireRateSpy.lua v1.0 — วัด fire rate จริงของปืน (เกม "ยิงเป็ด" 78)
-- 2 ทาง: (1) อ่านค่าในปืน (attribute/Value ชื่อ firerate/cooldown/delay/reload)
--        (2) จับเวลาห่างระหว่าง "นัดจริง" ตอนยิงมือรัว (hook เบา เก็บเวลา แล้วคำนวณนอก hook)
-- ผล: บอกหน่วงต่ำสุด/เฉลี่ย (วิ/นัด) + นัด/วิ → เอาไปตั้ง FIRE_DELAY กับ SHOT_SKIP ใน V2
-- อ่านอย่างเดียว ไม่แก้ค่า — ยิงมือรัวๆ 10+ นัด แล้วอ่าน
if _G.FR78_GUI then pcall(function() _G.FR78_GUI:Destroy() end) end
_G.FR78_GEN = (_G.FR78_GEN or 0) + 1
local MY_GEN = _G.FR78_GEN

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local LOG = {}
local function render()
    local n = #LOG; local lines = {}
    for i = math.max(1, n - 18), n do lines[#lines + 1] = LOG[i] end
    _G.FR78_OUT.Text = table.concat(lines, "\n")
end
local function log(s) LOG[#LOG + 1] = s; if #LOG > 500 then table.remove(LOG, 1) end; render() end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "FireRateSpy78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.FR78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 400, 0, 290); frame.Position = UDim2.new(0, 8, 0.12, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.1
frame.Active = true; frame.Draggable = true

local out = Instance.new("TextLabel", frame)
out.Size = UDim2.new(1, -8, 1, -60); out.Position = UDim2.new(0, 4, 0, 56)
out.BackgroundTransparency = 1; out.TextColor3 = Color3.fromRGB(180, 255, 180)
out.TextSize = 12; out.Font = Enum.Font.Code; out.TextWrapped = true
out.TextXAlignment = Enum.TextXAlignment.Left; out.TextYAlignment = Enum.TextYAlignment.Top
_G.FR78_OUT = out

local big = Instance.new("TextLabel", frame)
big.Size = UDim2.new(1, -8, 0, 44); big.Position = UDim2.new(0, 4, 0, 4)
big.BackgroundTransparency = 1; big.TextColor3 = Color3.fromRGB(255, 230, 120)
big.TextSize = 15; big.Font = Enum.Font.GothamBold; big.TextWrapped = true
big.TextXAlignment = Enum.TextXAlignment.Left; big.TextYAlignment = Enum.TextYAlignment.Top
big.Text = "🔫 ยิงมือรัวๆ 10+ นัด แล้วดูค่า"

local function mkbtn(txt, x, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0, 60, 0, 22); b.Position = UDim2.new(1, -(x), 0, 4)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local resetB = mkbtn("รีเซ็ต", 130, Color3.fromRGB(110, 90, 40))
local closeB = mkbtn("✕", 64, Color3.fromRGB(120, 40, 40))

-- ==================== (1) อ่านค่าในปืน ====================
local function scanGun()
    local ch = LP.Character
    local tool = ch and ch:FindFirstChildWhichIsA("Tool")
    if not tool then log("• ปืน(Tool): ✗ ไม่เจอ (ถือปืนก่อน)"); return end
    log(("• ปืน: %s"):format(tool.Name))
    local found = false
    for k, v in pairs(tool:GetAttributes()) do
        if type(v) == "number" then
            local lk = k:lower()
            if lk:find("fire") or lk:find("rate") or lk:find("cool") or lk:find("delay")
                or lk:find("reload") or lk:find("rpm") or lk:find("shot") then
                log(("   [attr] %s = %s"):format(k, tostring(v))); found = true
            end
        end
    end
    for _, c in ipairs(tool:GetDescendants()) do
        if (c:IsA("NumberValue") or c:IsA("IntValue")) then
            local lk = c.Name:lower()
            if lk:find("fire") or lk:find("rate") or lk:find("cool") or lk:find("delay")
                or lk:find("reload") or lk:find("rpm") or lk:find("shot") then
                log(("   [val] %s = %s"):format(c.Name, tostring(c.Value))); found = true
            end
        end
    end
    if not found then log("   (ไม่เจอค่า firerate ในปืน — วัดจากเวลายิงแทน ↓)") end
end

-- ==================== (2) จับเวลาห่างระหว่างนัดจริง (hook เบา) ====================
_G.FR78_TIMES = {}
local hookOK, hookErr = pcall(function()
    if not (hookmetamethod and getnamecallmethod) then error("ไม่มี hookmetamethod") end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        -- เบาสุด: เจอ AIM (V3,V3,num,num) = 1 นัด → เก็บเวลา
        local a1, a2, a3, a4 = ...
        if _G.FR78_GEN == MY_GEN and typeof(a1) == "Vector3" and typeof(a2) == "Vector3"
            and typeof(a3) == "number" and typeof(a4) == "number" then
            pcall(function()
                if getnamecallmethod() == "FireServer" then
                    table.insert(_G.FR78_TIMES, os.clock())
                end
            end)
        end
        return old(self, ...)
    end)
end)

-- คำนวณผลนอก hook
task.spawn(function()
    local lastN = 0
    while _G.FR78_GEN == MY_GEN do
        local T = _G.FR78_TIMES
        if #T ~= lastN and #T >= 2 then
            lastN = #T
            -- ใช้เฉพาะช่วงยิงรัว (เวลาห่าง < 1 วิ) กันช่วงพักยาว
            local deltas = {}
            for i = 2, #T do
                local d = T[i] - T[i-1]
                if d > 0 and d < 1.0 then deltas[#deltas + 1] = d end
            end
            if #deltas >= 1 then
                table.sort(deltas)
                local mn = deltas[1]
                local sum = 0; for _, d in ipairs(deltas) do sum = sum + d end
                local avg = sum / #deltas
                local med = deltas[math.ceil(#deltas / 2)]
                big.Text = ("🔫 เร็วสุด %.3fวิ (%.1f นัด/วิ)\nเฉลี่ย %.3fวิ | กลาง %.3fวิ | %d นัด"):format(
                    mn, mn > 0 and 1/mn or 0, avg, med, #T)
                -- แนะนำค่าตั้ง: ใช้ค่ากลาง (median) เผื่อนิดหน่อย
                _G.FR78_SUGGEST = med
            end
        end
        task.wait(0.2)
    end
end)

resetB.MouseButton1Click:Connect(function()
    _G.FR78_TIMES = {}; LOG = {}; render()
    big.Text = "🔫 ยิงมือรัวๆ 10+ นัด แล้วดูค่า"
    scanGun()
end)
closeB.MouseButton1Click:Connect(function()
    _G.FR78_GEN = _G.FR78_GEN + 1
    gui:Destroy(); _G.FR78_GUI = nil
end)

if hookOK then log("✅ hook พร้อม") else log("❌ hook ไม่ติด: " .. tostring(hookErr)) end
scanGun()
log("→ ยิงมือรัวให้สุดมือ 10+ นัด (ปืนยิงเต็มสปีด) แล้วอ่านค่าด้านบน")
log("→ เอา 'เร็วสุด' ไปตั้ง FIRE_DELAY / 'กลาง' ไปตั้ง SHOT_SKIP")
warn("[FireRateSpy78] v1.0 loaded")
