-- 78RB_AmmoSpy.lua v1.0 — สปายเฉพาะกิจ: ตามจำนวนกระสุนบนจอ (เกม "ยิงเป็ด" โปรเจ็ก 78)
-- โจทย์: ผู้เล่นกดยิงมือได้ 3 ครั้งต่อแม็ก (ตัวเลขมุมขวาล่างจอ) แต่สคริปต์ยิง 1 คำสั่ง
-- กลับเห็นกระสุนออก/ลดพรวดเดียว 3 — สคริปต์นี้จับเฉพาะ "เลขกระสุนบนจอ" เปลี่ยนเมื่อไหร่/ยังไง
-- ไม่ยุ่งกับ remote เกม (อ่านอย่างเดียว) ปลอดภัย ไม่กระทบการยิง/รีโหลด
if _G.AS78_GUI then pcall(function() _G.AS78_GUI:Destroy() end) end
if _G.AS78_CONNS then
    for _, c in ipairs(_G.AS78_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.AS78_CONNS = {}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local LOG = {}
local function stamp() return os.date("%H:%M:%S") end
local t0 = os.clock()

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AmmoSpy78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.AS78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 340, 0, 260); frame.Position = UDim2.new(0, 8, 0.15, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.15
frame.Active = true; frame.Draggable = true

local out = Instance.new("TextLabel", frame)
out.Size = UDim2.new(1, -8, 1, -40); out.Position = UDim2.new(0, 4, 0, 36)
out.BackgroundTransparency = 1; out.TextColor3 = Color3.fromRGB(255, 210, 120)
out.TextSize = 11; out.Font = Enum.Font.Code; out.TextWrapped = true
out.TextXAlignment = Enum.TextXAlignment.Left; out.TextYAlignment = Enum.TextYAlignment.Top

local function render()
    local n = #LOG
    local lines = {}
    for i = math.max(1, n - 22), n do lines[#lines + 1] = LOG[i] end
    out.Text = table.concat(lines, "\n")
end
local function log(s)
    LOG[#LOG + 1] = ("%s [+%.2fs] %s"):format(stamp(), os.clock() - t0, s)
    if #LOG > 2000 then table.remove(LOG, 1) end
    render()
end

local function mkbtn(txt, x, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0, 60, 0, 24); b.Position = UDim2.new(0, x, 0, 6)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local scanB  = mkbtn("SCAN", 4, Color3.fromRGB(60, 110, 180))
local clearB = mkbtn("CLR", 70, Color3.fromRGB(110, 110, 40))
local copyB  = mkbtn("COPY", 136, Color3.fromRGB(40, 130, 70))
local closeB = mkbtn("✕", 202, Color3.fromRGB(120, 40, 40))

-- ==================== หา "ตัวเลขกระสุน" บนจอ (เลขล้วน 1-2 หลัก ใกล้ปุ่มยิง/รีโหลด) ====================
-- ยึดแนวว่าเป็น TextLabel/TextButton ที่ Text เป็นตัวเลขล้วน (ไม่มีตัวอักษรอื่นปน) ค่า 0-99
local function isPureNumber(t)
    return t and t:match("^%d+$") ~= nil and tonumber(t) and tonumber(t) < 100
end

local watched = {} -- instance -> true (กันดักซ้ำ)
local function watchLabel(d)
    if watched[d] then return end
    if not (d:IsA("TextLabel") or d:IsA("TextButton")) then return end
    if not isPureNumber(d.Text) then return end
    watched[d] = true
    local prev = d.Text
    log(("[FOUND] เลขล้วน \"%s\" ที่ %s"):format(d.Text, d:GetFullName()))
    table.insert(_G.AS78_CONNS, d:GetPropertyChangedSignal("Text"):Connect(function()
        if isPureNumber(d.Text) then
            log(("[AMMO] %s: %s → %s  (%s)"):format(d.Name, prev, d.Text, d:GetFullName()))
            prev = d.Text
        end
    end))
end

local function scanAll()
    watched = {}
    local n = 0
    for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and isPureNumber(d.Text) then
            watchLabel(d)
            n += 1
        end
    end
    log(("===== SCAN: เจอป้ายตัวเลขล้วน %d จุด (ดักการเปลี่ยนแปลงแล้ว) ====="):format(n))
end

table.insert(_G.AS78_CONNS, LP.PlayerGui.DescendantAdded:Connect(function(d)
    task.defer(function() watchLabel(d) end)
end))

-- ==================== ดัก FireServer แบบอ่านอย่างเดียว (ไม่แก้ค่า) เพื่อ correlate เวลา ====================
if hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local a = table.pack(...)
        pcall(function()
            if getnamecallmethod() ~= "FireServer" then return end
            if a.n >= 4 and typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3" then
                log(("[ยิง-เล็ง] counter=%s"):format(tostring(a[3])))
            elseif a.n == 1 and typeof(a[1]) == "number" then
                log(("[ยิง-ยืนยัน] counter=%s"):format(tostring(a[1])))
            end
        end)
        return old(self, ...)
    end)
end

-- ==================== Buttons ====================
scanB.MouseButton1Click:Connect(scanAll)
clearB.MouseButton1Click:Connect(function() LOG = {} render() end)
copyB.MouseButton1Click:Connect(function()
    local all = table.concat(LOG, "\n")
    if setclipboard then
        setclipboard(all)
        log("📋 ก๊อปลงคลิปบอร์ดแล้ว (" .. #LOG .. " บรรทัด)")
    elseif writefile then
        writefile("78RB_ammo_log.txt", all)
        log("💾 เซฟไฟล์ 78RB_ammo_log.txt แล้ว")
    end
end)
closeB.MouseButton1Click:Connect(function()
    for _, c in ipairs(_G.AS78_CONNS) do pcall(function() c:Disconnect() end) end
    _G.AS78_CONNS = {}
    gui:Destroy(); _G.AS78_GUI = nil
end)

log("[AmmoSpy78] พร้อม — กด SCAN 1 ครั้งก่อน (ต้องเห็นเลขกระสุนบนจอตอนกด) แล้วยิงมือ 3 นัดดู log")
scanAll()
warn("[AmmoSpy78] loaded")
