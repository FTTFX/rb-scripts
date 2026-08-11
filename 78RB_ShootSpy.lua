-- 78RB_ShootSpy.lua v1.0 — สปาย "ตอนยิงมือ" ส่ง origin/dir อะไร (เกม "ยิงเป็ด" 78)
-- โจทย์: ยิงรีโมตตรงๆ ไม่ตาย เพราะเกม "ราคาสต์เรย์จากปากกระบอก" ตาม dir จริง (ไม่ใช่ ID)
--   → ต้องรู้ว่าเกมเอา origin/dir มาจากไหน (กล้อง? ปากปืน? ปุ่มยิงมือถือ?)
-- ตัวนี้ hook FireServer เฉพาะลายเซ็น AIM (V3,V3,num,num) แล้วโชว์:
--   • origin ที่เกมส่ง + ต่างจาก "กล้องตอนนี้" กี่หน่วย (บอกว่า origin = กล้องไหม)
--   • dir ที่เกมส่ง + มุมต่างจาก "กล้องมองไปทางไหน" (LookVector) กี่องศา
--   • เป้าที่เรย์จาก origin+dir ไปโดนจริง (ราคาสต์ตาม) = เป็ดตัวไหน/อะไร
-- อ่านอย่างเดียว ไม่แก้ค่า — ยิงมือใส่เป็ด 2-3 นัด แล้วอ่านผล
if _G.SS78_GUI then pcall(function() _G.SS78_GUI:Destroy() end) end
_G.SS78_GEN = (_G.SS78_GEN or 0) + 1
local MY_GEN = _G.SS78_GEN

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local LOG = {}
local function stamp() return os.date("%H:%M:%S") end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "ShootSpy78"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.SS78_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 430, 0, 300); frame.Position = UDim2.new(0, 8, 0.12, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0); frame.BackgroundTransparency = 0.1
frame.Active = true; frame.Draggable = true

local out = Instance.new("TextLabel", frame)
out.Size = UDim2.new(1, -8, 1, -38); out.Position = UDim2.new(0, 4, 0, 34)
out.BackgroundTransparency = 1; out.TextColor3 = Color3.fromRGB(180, 255, 180)
out.TextSize = 12; out.Font = Enum.Font.Code; out.TextWrapped = true
out.TextXAlignment = Enum.TextXAlignment.Left; out.TextYAlignment = Enum.TextYAlignment.Top

local function render()
    local n = #LOG; local lines = {}
    for i = math.max(1, n - 16), n do lines[#lines + 1] = LOG[i] end
    out.Text = table.concat(lines, "\n")
end
local function log(s)
    LOG[#LOG + 1] = s
    if #LOG > 2000 then table.remove(LOG, 1) end
    render()
end

local function mkbtn(txt, x, col)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0, 100, 0, 24); b.Position = UDim2.new(0, x, 0, 5)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local copyB  = mkbtn("COPY", 4, Color3.fromRGB(40, 130, 70))
local clearB = mkbtn("CLR", 110, Color3.fromRGB(110, 110, 40))
local closeB = mkbtn("✕ ปิด", 216, Color3.fromRGB(120, 40, 40))

-- ==================== หาเป็ดที่เรย์ไปโดน ====================
local function duckFolder() return workspace:FindFirstChild("Ume") end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function rayHitName(origin, dir)
    rp.FilterDescendantsInstances = { LP.Character }
    local res = workspace:Raycast(origin, dir * 5000, rp)
    if not res then return "ไม่โดนอะไร (เรย์ทะลุ)" end
    local inst = res.Instance
    -- ไต่ขึ้นหา Model เป็ด
    local m = inst
    while m and m.Parent ~= workspace do
        if m:IsA("Model") and m.Name:find("Duck") then break end
        m = m.Parent
    end
    local mn = (m and m:IsA("Model")) and m.Name or inst.Name
    local isDuck = mn:find("Duck") ~= nil
    return ("%s%s @%.0f"):format(isDuck and "🦆 " or "", mn, res.Distance)
end

-- ==================== HOOK: เก็บค่าดิบเร็วๆ แล้วปล่อยผ่านทันที (ห้ามทำงานหนักใน hook!) ====================
-- v1.1: v1.0 raycast+log ใน hook → บล็อกการยิง แก้: hook แค่ push ค่าลง queue แล้ว return
_G.SS78_QUEUE = _G.SS78_QUEUE or {}
local hookOK, hookErr = pcall(function()
    if not (hookmetamethod and getnamecallmethod) then error("ไม่มี hookmetamethod") end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        -- เบาสุด: เช็คชนิด args แล้วเก็บลง queue (สแนปช็อตกล้อง ณ ตอนยิง) — ไม่ raycast ไม่ log
        local a1, a2, a3 = ...
        if _G.SS78_GEN == MY_GEN and typeof(a1) == "Vector3" and typeof(a2) == "Vector3"
            and typeof(a3) == "number" then
            pcall(function()
                if getnamecallmethod() == "FireServer" then
                    local cf = Camera.CFrame
                    table.insert(_G.SS78_QUEUE, {
                        origin = a1, dir = a2, ctr = a3,
                        camP = cf.Position, camLook = cf.LookVector,
                    })
                end
            end)
        end
        return old(self, ...)
    end)
end)

-- ประมวลผล queue นอก hook (raycast + log ที่นี่ ปลอดภัย ไม่กระทบการยิง)
task.spawn(function()
    while _G.SS78_GEN == MY_GEN do
        local q = _G.SS78_QUEUE
        while q and #q > 0 do
            local e = table.remove(q, 1)
            local ndir = e.dir.Magnitude > 0 and e.dir.Unit or e.dir
            local dOrigin = (e.origin - e.camP).Magnitude
            local dot = math.clamp(ndir:Dot(e.camLook), -1, 1)
            local ang = math.deg(math.acos(dot))
            log(("── ยิงมือ ctr=%d ──"):format(e.ctr))
            log((" origin เกม: %.1f,%.1f,%.1f"):format(e.origin.X, e.origin.Y, e.origin.Z))
            log((" กล้องตอนยิง: %.1f,%.1f,%.1f  (ต่าง %.1f)"):format(e.camP.X, e.camP.Y, e.camP.Z, dOrigin))
            log((" dir เกม: %.2f,%.2f,%.2f"):format(e.dir.X, e.dir.Y, e.dir.Z))
            log((" dir กล้อง(Look): มุมต่าง %.1f°"):format(ang))
            log((" เรย์ origin+dir โดน: %s"):format(rayHitName(e.origin, ndir)))
        end
        task.wait(0.15)
    end
end)
if hookOK then
    log("✅ พร้อม — ยิงมือใส่เป็ด 2-3 นัด แล้วอ่าน:")
    log("  • 'ต่าง' origin↔กล้อง น้อย = origin คือกล้อง")
    log("  • 'มุมต่าง' dir↔กล้อง น้อย = dir คือทิศกล้องมอง")
    log("  • ถ้าเรย์โดน 🦆 = origin+dir นี้ยิงโดนเป็ดจริง (เราลอกได้)")
else
    log("❌ hook ไม่ติด: " .. tostring(hookErr))
end

-- ==================== ปุ่ม ====================
copyB.MouseButton1Click:Connect(function()
    local all = table.concat(LOG, "\n")
    if setclipboard then setclipboard(all); log("📋 ก๊อปแล้ว")
    elseif writefile then writefile("78RB_shoot_spy.txt", all); log("💾 เซฟแล้ว") end
end)
clearB.MouseButton1Click:Connect(function() LOG = {}; render() end)
closeB.MouseButton1Click:Connect(function()
    _G.SS78_GEN = _G.SS78_GEN + 1
    gui:Destroy(); _G.SS78_GUI = nil
end)

warn("[ShootSpy78] v1.1 loaded — hook เบา ยิงได้ปกติ / ยิงมือ 2-3 นัด")
