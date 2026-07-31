-- 74RB_MoveSpy.lua v1.0 — สปายการเคลื่อนไหว: จับว่า "ใครพาบินออกนอกแมพ"
-- เก็บ (เวลา, พิกัด, สถานะหัว GUI ของ AH74 = งานที่บอทกำลังทำ) ทุก 0.2s ย้อนหลัง 10s
-- หลุดขอบแมพเมื่อไหร่ → dump เส้นทางก่อนหน้า + สถานะ ณ ตอนนั้นทันที
-- ขอบแมพ (จาก MedLocSpy: ของทั้งหมด X -157..-97, Z -129..+112, Y≈4): เผื่อขอบกว้างๆ
local BOUND = { x1 = -220, x2 = -40, z1 = -180, z2 = 160, y1 = -5, y2 = 45 }

if _G.MOVESPY_CONNS then
    for _, c in pairs(_G.MOVESPY_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.MOVESPY_CONNS = {}
local CONNS = _G.MOVESPY_CONNS
if _G.MOVESPY_GEN then _G.MOVESPY_GEN += 1 else _G.MOVESPY_GEN = 1 end
local MYGEN = _G.MOVESPY_GEN

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT, LINES = {}, {}
local T0 = os.clock()

local gui = Instance.new("ScreenGui")
gui.Name = "MoveSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 600, 0, 330); box.Position = UDim2.new(0, 8, 0.3, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(255, 220, 140); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false
box.Text = "[MoveSpy] กำลังจับตา — หลุดขอบแมพเมื่อไหร่จะ dump เส้นทางให้"

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.3, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 14
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local copyB = hbtn("COPY", 8, 80)
local foldB = hbtn("พับ", 94, 56, Color3.fromRGB(90, 70, 40))
local closeB = hbtn("✕", 156, 34, Color3.fromRGB(150, 40, 40))

local function add(s)
    s = ("[%.1fs] %s"):format(os.clock() - T0, s)
    OUT[#OUT + 1] = s; LINES[#LINES + 1] = s
    while #LINES > 22 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
    print("[MoveSpy]", s)
end

table.insert(CONNS, copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "74RB_move_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end))
table.insert(CONNS, foldB.MouseButton1Click:Connect(function()
    box.Visible = not box.Visible
    foldB.Text = box.Visible and "พับ" or "กาง"
end))
table.insert(CONNS, closeB.MouseButton1Click:Connect(function()
    for _, c in pairs(CONNS) do pcall(function() c:Disconnect() end) end
    _G.MOVESPY_CONNS = {}
    _G.MOVESPY_GEN += 1
    gui:Destroy()
end))

-- อ่านสถานะหัว GUI ของ AH74 (บอกว่าบอทกำลังทำงานอะไร)
local function ahStatus()
    for _, root in ipairs({ (gethui and gethui()), game:GetService("CoreGui"), LP:FindFirstChild("PlayerGui") }) do
        local g = root and root:FindFirstChild("AH74GUI")
        if g then
            for _, d in ipairs(g:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text:find("^v6") then return d.Text end
            end
        end
    end
    return "?"
end

local function inMap(p)
    return p.X > BOUND.x1 and p.X < BOUND.x2 and p.Z > BOUND.z1 and p.Z < BOUND.z2
       and p.Y > BOUND.y1 and p.Y < BOUND.y2
end

-- ring buffer เส้นทาง 10s (0.2s/จุด = 50 จุด)
local trail = {}
local wasOut = false
task.spawn(function()
    while _G.MOVESPY_GEN == MYGEN and gui.Parent do
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if r then
            local p = r.Position
            trail[#trail + 1] = { t = os.clock() - T0, p = p, s = ahStatus() }
            while #trail > 50 do table.remove(trail, 1) end
            local out = not inMap(p)
            if out and not wasOut then
                add(("🚨 หลุดขอบแมพที่ (%.0f,%.0f,%.0f) — เส้นทาง 10s ก่อนหน้า:"):format(p.X, p.Y, p.Z))
                local lastS = nil
                for _, e in ipairs(trail) do
                    -- log เฉพาะจุดที่สถานะเปลี่ยน (อ่านง่าย — สถานะ = ตัวบอกงานที่พาไป)
                    if e.s ~= lastS then
                        lastS = e.s
                        add(("  [%.1fs] (%.0f,%.0f,%.0f) ← %s"):format(e.t, e.p.X, e.p.Y, e.p.Z, e.s))
                    end
                end
                add("  (สถานะบรรทัดสุดท้าย = งานที่พาออกไป)")
            elseif out and os.clock() % 2 < 0.25 then
                add(("… ยังอยู่นอกแมพ (%.0f,%.0f,%.0f) สถานะ: %s"):format(p.X, p.Y, p.Z, ahStatus()))
            elseif not out and wasOut then
                add("✅ กลับเข้าแมพแล้ว")
            end
            wasOut = out
        end
        task.wait(0.2)
    end
end)

add("เริ่มจับตาแล้ว — ปล่อยบอทเล่นตามปกติ พอหลุดแมพจะ dump เอง (พับจอไว้ได้)")
