-- 74RB_StatView.lua v1.0 — ดูเงิน/แมว/คะแนน สดๆ ในเกม (ไม่ต้องออกเกมถึงจะเห็น)
-- แหล่งข้อมูล 4 ทาง: leaderstats | Player attributes | RF/RequestData (ขอข้อมูลจาก server ตรง)
--                   | ป้ายตัวเลขใน PlayerGui (HUD ที่เกมซ่อนไว้)
-- ปุ่ม: REFRESH ดึงใหม่ | AUTO รีทุก 3s | COPY | CLOSE

local Players = game:GetService("Players")
local RSt = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

if _G.AH74SV_GUI then pcall(function() _G.AH74SV_GUI:Destroy() end) end
if _G.AH74SV_GEN then _G.AH74SV_GEN += 1 else _G.AH74SV_GEN = 1 end
local MYGEN = _G.AH74SV_GEN
local AUTO = false

-- serialize table ลึก 3 ชั้น (ผลจาก RequestData มักเป็น table ซ้อน)
local function ser(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    local t = typeof(v)
    if t == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "Instance" then
        return "<" .. v.ClassName .. ":" .. v.Name .. ">"
    end
    return tostring(v)
end

local function dump()
    local out = {}
    local function L(s) out[#out + 1] = s end
    L("=== StatView v1.0 (" .. os.date("%H:%M:%S") .. ") ===")

    -- 1) leaderstats (คะแนนบนกระดาน)
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        L("-- leaderstats --")
        for _, v in ipairs(ls:GetDescendants()) do
            if v:IsA("ValueBase") then L(("  %s = %s"):format(v.Name, tostring(v.Value))) end
        end
    else
        L("-- leaderstats: ไม่มี --")
    end

    -- 2) attribute บนตัว player (Sanity/เงิน/คะแนน เกมนี้ชอบเก็บเป็น attr)
    L("-- Player attributes --")
    local ks = {}
    for k in pairs(LP:GetAttributes()) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do L(("  %s = %s"):format(k, tostring(LP:GetAttribute(k)))) end

    -- 3) ขอข้อมูลจาก server ตรงผ่าน RF/RequestData (PROJECT.md: remote นี้มีจริง)
    L("-- RF/RequestData --")
    local rf
    pcall(function() rf = RSt:FindFirstChild("Util") and RSt.Util:FindFirstChild("Net") and RSt.Util.Net:FindFirstChild("RF/RequestData") end)
    if rf then
        -- ลองหลายรูปแบบ arg — เกมแต่ละตัวรับไม่เหมือนกัน อันไหนติดก็โชว์
        for _, arg in ipairs({ { }, { "Stats" }, { "Data" }, { "PlayerData" }, { LP } }) do
            local ok, res = pcall(function() return rf:InvokeServer(unpack(arg)) end)
            if ok and res ~= nil then
                L(("  InvokeServer(%s) → %s"):format(ser(arg):sub(2, -2), ser(res)))
            end
        end
    else
        L("  ไม่เจอ RF/RequestData")
    end

    -- 4) ป้ายตัวเลขใน PlayerGui (HUD เงิน/แมว/คะแนน ที่เกมมีอยู่แล้ว — รวมที่ Visible=false)
    L("-- ป้าย HUD ใน PlayerGui (ชื่อ/ข้อความเข้าเค้า เงิน|แมว|คะแนน|score|money|cat|coin|point|token) --")
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local n = 0
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then
                local name, txt = d.Name:lower(), d.Text:lower()
                local hit = name:find("money") or name:find("cash") or name:find("coin") or name:find("score")
                         or name:find("point") or name:find("cat") or name:find("token") or name:find("cur")
                         or txt:find("%$") or txt:find("แมว") or txt:find("คะแนน")
                if hit then
                    n += 1
                    if n <= 25 then
                        L(("  [%s] \"%s\"%s"):format(d.Name, d.Text, d.Visible and "" or " (ซ่อนอยู่)"))
                    end
                end
            end
        end
        if n == 0 then L("  ไม่เจอป้ายเข้าเค้า") end
        if n > 25 then L(("  ...รวม %d ป้าย (โชว์ 25 แรก)"):format(n)) end
    end
    return table.concat(out, "\n")
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AH74SV", false, 10000
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
_G.AH74SV_GUI = gui

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 420, 0, 360), UDim2.new(0.5, -210, 0.5, -180)
f.BackgroundColor3, f.Active, f.Draggable = Color3.fromRGB(15, 15, 20), true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local box = Instance.new("TextBox", f)
box.Size, box.Position = UDim2.new(1, -12, 1, -50), UDim2.new(0, 6, 0, 6)
box.MultiLine, box.ClearTextOnFocus, box.TextEditable = true, false, false
box.TextWrapped, box.TextXAlignment, box.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
box.Font, box.TextSize = Enum.Font.Code, 11
box.BackgroundColor3, box.TextColor3 = Color3.fromRGB(25, 25, 32), Color3.fromRGB(200, 255, 200)
box.Text = "กด REFRESH เพื่อดึงค่า"

local function mkbtn(txt, x, w, cb)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0, w, 0, 30), UDim2.new(0, x, 1, -38)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(50, 50, 70), Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end
mkbtn("REFRESH", 6, 90, function() box.Text = dump() end)
local autoB = mkbtn("AUTO: OFF", 102, 90, nil)
autoB.MouseButton1Click:Connect(function()
    AUTO = not AUTO
    autoB.Text = "AUTO: " .. (AUTO and "ON" or "OFF")
    autoB.BackgroundColor3 = AUTO and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(50, 50, 70)
end)
mkbtn("COPY", 198, 80, function() pcall(function() (setclipboard or toclipboard)(box.Text) end) end)
mkbtn("CLOSE", 284, 80, function() gui:Destroy(); _G.AH74SV_GUI = nil; _G.AH74SV_GEN += 1 end)

task.spawn(function()
    while _G.AH74SV_GEN == MYGEN do
        if AUTO then pcall(function() box.Text = dump() end) end
        task.wait(3)
    end
end)

box.Text = dump()
print("[74RB StatView v1.0] พร้อม — REFRESH/AUTO ดูค่าเงิน/แมว/คะแนนสด")
