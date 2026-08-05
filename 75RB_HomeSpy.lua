-- 75RB_HomeSpy.lua v1.0 — สปายแยก "ก้อนป่า" vs "ก้อนบ้านเพื่อน"
-- ปัญหา: ESP ยังเล็งก้อนในบ้านเพื่อนอยู่ (กรองแค่ชื่อ Placed_* ไม่พอ)
-- ดัมพ์: (1) TOP 20 ก้อนแพงสุด — path เต็ม + ชื่อ + attrs สำคัญ
--        (2) census: ก้อนทั้งหมดแยกตาม "โฟลเดอร์แม่" (parent path) + จำนวน + มูลค่ารวม
--        (3) attrs ที่ต่างกันระหว่างกลุ่ม (เช่น IsVisibleSpawn?)
-- → เอาผลมาดูว่าก้อนบ้านอยู่ path ไหน / มี attr อะไรชี้ตัว แล้วค่อยกรองใน ESP/Assist
if _G.HSPY75_GUI then pcall(function() _G.HSPY75_GUI:Destroy() end) end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT = {}
local function L(s) OUT[#OUT + 1] = s end

local function myPos()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return r and r.Position
end
local function fmtMoney(v)
    if v >= 1e6 then return ("$%.1fM"):format(v / 1e6) end
    if v >= 1e3 then return ("$%.0fK"):format(v / 1e3) end
    return "$" .. math.floor(v)
end

local function scan()
    OUT = {}
    local mp = myPos()
    local all = {}
    for _, c in ipairs(workspace:GetDescendants()) do
        if c:IsA("BasePart") and c:GetAttribute("CrystalName") and c:GetAttribute("Tier") then
            all[#all + 1] = c
        end
    end

    -- (1) TOP 20 แพงสุด — path เต็ม
    table.sort(all, function(a, b)
        return (a:GetAttribute("Value") or 0) > (b:GetAttribute("Value") or 0)
    end)
    L("=== TOP 20 แพงสุด (ดู path ว่าอยู่บ้านใครไหม) ===")
    for i = 1, math.min(20, #all) do
        local c = all[i]
        local p = c.Position
        local d = mp and math.floor((p - mp).Magnitude) or -1
        L(("%2d. %s %s %dm"):format(i, c:GetAttribute("CrystalName"),
            fmtMoney(c:GetAttribute("Value") or 0), d))
        L("    path: " .. c:GetFullName():gsub("^Workspace%.", ""))
        -- attrs ที่อาจชี้ตัวว่าเป็นของวาง/ของบ้าน
        local extra = {}
        for k, v in pairs(c:GetAttributes()) do
            if k ~= "CrystalName" and k ~= "Value" and k ~= "Tier" and k ~= "TierName"
                and k ~= "WeightKg" and k ~= "SpawnedAt" and k ~= "MeshTemplate"
                and not k:match("^TierColor") and not k:match("^SizeClass") then
                extra[#extra + 1] = k .. "=" .. tostring(v)
            end
        end
        local pp = c:FindFirstChildOfClass("ProximityPrompt")
        extra[#extra + 1] = "prompt=" .. (pp and (pp.Enabled and "✅เก็บได้" or "❌ปิดอยู่") or "❌ไม่มี!")
        L("    " .. table.concat(extra, " "))
    end

    -- (2) census ตามโฟลเดอร์แม่
    L("")
    L("=== ก้อนทั้งหมดแยกตามโฟลเดอร์แม่ ===")
    local grp = {}
    for _, c in ipairs(all) do
        local key = c.Parent and c.Parent:GetFullName():gsub("^Workspace%.", "") or "?"
        local g = grp[key] or { n = 0, v = 0, prompts = 0 }
        g.n += 1
        g.v += c:GetAttribute("Value") or 0
        local pp = c:FindFirstChildOfClass("ProximityPrompt")
        if pp and pp.Enabled then g.prompts += 1 end
        grp[key] = g
    end
    local keys = {}
    for k in pairs(grp) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return grp[a].v > grp[b].v end)
    for _, k in ipairs(keys) do
        local g = grp[k]
        L(("%s → %d ก้อน รวม %s | เก็บได้ %d/%d"):format(k, g.n, fmtMoney(g.v), g.prompts, g.n))
    end
    L("")
    L("รวมทั้งหมด " .. #all .. " ก้อน | สังเกต: กลุ่มไหน 'เก็บได้ 0/x' = ของโชว์/บ้านเพื่อน")
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "HomeSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.HSPY75_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 640, 0, 340); box.Position = UDim2.new(0, 8, 0.24, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(180, 255, 200); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function redraw() box.Text = table.concat(OUT, "\n") end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.24, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local rescanB = hbtn("RESCAN", 8, 80, Color3.fromRGB(40, 130, 70))
local copyB   = hbtn("COPY", 92, 70)
local closeB  = hbtn("✕", 166, 34, Color3.fromRGB(150, 40, 40))

rescanB.MouseButton1Click:Connect(function() scan(); redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_home_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function() gui:Destroy(); _G.HSPY75_GUI = nil end)

scan(); redraw()
