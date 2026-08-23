-- 79RB_HouseClean2_AutoLeaf.lua v1.0 — ฟาร์มใบไม้อัตโนมัติ (ล้างบ้านขำๆ ภาค 2 "นอกบ้าน")
-- จาก NetSpy: เก็บใบ = CollectLeaf:FireServer(<id ตัวเลข>) / เทกระเป๋า = EmptyBackpack:FireServer()
-- ไม่รู้ว่า id อยู่ไหนใน WS.Leaves.Leaf → ปุ่ม DUMP โชว์โครงสร้าง+Attributes ของใบ 3 ใบแรก
-- ปุ่ม AUTO: หา id จากใบทุกใบ (ลอง Attribute ทุกตัวที่เป็นเลข, IntValue/NumberValue ลูก, ชื่อที่เป็นเลข)
--   → ยิง CollectLeaf ทีละใบ ทุก LEAF_DELAY วิ → ยิง EmptyBackpack ทุก EMPTY_EVERY ใบ
if _G.LF79_GUI then pcall(function() _G.LF79_GUI:Destroy() end) end
_G.LF79_GEN = (_G.LF79_GEN or 0) + 1
local GEN = _G.LF79_GEN

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local LEAF_DELAY = 0.10  -- หน่วงระหว่างเก็บแต่ละใบ (วิ)
local EMPTY_EVERY = 20   -- เทกระเป๋าทุกๆ กี่ใบ
local AUTO_ON = false

-- ==================== หา remote ====================
local function findRemote(name)
    for _, svc in ipairs({ RS, workspace }) do
        local r = svc:FindFirstChild(name, true)
        if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    end
    return nil
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoLeaf79"; gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647; gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.LF79_GUI = gui

local fr = Instance.new("Frame", gui)
fr.Size = UDim2.new(0, 300, 0, 330); fr.Position = UDim2.new(0, 8, 0.35, 0)
fr.BackgroundColor3 = Color3.new(0, 0, 0); fr.BackgroundTransparency = 0.1
fr.Active = true; fr.Draggable = true
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", fr); stk.Color = Color3.fromRGB(120, 220, 100); stk.Thickness = 2

local status = Instance.new("TextLabel", fr)
status.Size = UDim2.new(1, -8, 0, 36); status.Position = UDim2.new(0, 4, 0, 4)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(180, 255, 180)
status.TextSize = 12; status.Font = Enum.Font.GothamBold; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.Text = "🍂 AutoLeaf พร้อม"

local scf = Instance.new("ScrollingFrame", fr)
scf.Size = UDim2.new(1, -8, 1, -116); scf.Position = UDim2.new(0, 4, 0, 74)
scf.BackgroundColor3 = Color3.fromRGB(12, 18, 12); scf.BorderSizePixel = 0; scf.ScrollBarThickness = 6
scf.CanvasSize = UDim2.new(0, 0, 0, 0); scf.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scf).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel", scf)
lbl.Size = UDim2.new(1, -8, 0, 0); lbl.Position = UDim2.new(0, 4, 0, 4)
lbl.AutomaticSize = Enum.AutomaticSize.Y; lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Code; lbl.TextSize = 11; lbl.TextColor3 = Color3.fromRGB(190, 255, 190)
lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.TextWrapped = true; lbl.Text = ""
local out = {}
local function say(s)
    out[#out + 1] = tostring(s)
    if #out > 300 then table.remove(out, 1) end
    lbl.Text = table.concat(out, "\n")
end

local function mkbtn(txt, x, y, w, col)
    local b = Instance.new("TextButton", fr)
    b.Size = UDim2.new(0, w, 0, 26); b.Position = UDim2.new(0, x, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local autoB  = mkbtn("▶ AUTO", 4, 42, 76, Color3.fromRGB(40, 130, 60))
local dumpB  = mkbtn("DUMP", 84, 42, 60, Color3.fromRGB(60, 90, 150))
local emptyB = mkbtn("เทถุง", 148, 42, 56, Color3.fromRGB(150, 110, 40))
local copyB  = mkbtn("📋", 208, 42, 40, Color3.fromRGB(60, 60, 60))
local closeB = mkbtn("✕", 252, 42, 40, Color3.fromRGB(140, 45, 45))

-- แถวล่าง: ปรับหน่วง
local dlyB = mkbtn(("หน่วง %.2f"):format(LEAF_DELAY), 4, 296, 96, Color3.fromRGB(70, 70, 110))
dlyB.MouseButton1Click:Connect(function()
    local steps = { 0.05, 0.10, 0.20, 0.40 }
    for i, v in ipairs(steps) do
        if math.abs(v - LEAF_DELAY) < 0.001 then LEAF_DELAY = steps[i % #steps + 1]; break end
    end
    dlyB.Text = ("หน่วง %.2f"):format(LEAF_DELAY)
end)

copyB.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.LF79_GEN = _G.LF79_GEN + 1; gui:Destroy(); _G.LF79_GUI = nil
end)

-- ==================== หา id ของใบ ====================
-- คืน id ตัวเลข + แหล่งที่เจอ (ไว้ debug)
local function leafId(inst)
    -- 1) Attribute ที่เป็นตัวเลข
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do
            if type(v) == "number" then return v, "attr:" .. k end
        end
    end
    -- 2) ลูกที่เป็น IntValue/NumberValue/StringValue ตัวเลข
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA("IntValue") or c:IsA("NumberValue") then return c.Value, "child:" .. c.Name end
        if c:IsA("StringValue") and tonumber(c.Value) then return tonumber(c.Value), "childS:" .. c.Name end
    end
    -- 3) ชื่อตัวเองเป็นเลข
    if tonumber(inst.Name) then return tonumber(inst.Name), "name" end
    return nil, nil
end

local function allLeaves()
    local res = {}
    local folder = workspace:FindFirstChild("Leaves")
    if folder then
        for _, m in ipairs(folder:GetChildren()) do res[#res + 1] = m end
    end
    return res
end

-- ==================== DUMP ====================
dumpB.MouseButton1Click:Connect(function()
    out = {}; say("===== DUMP ใบไม้ 3 ใบแรก =====")
    local ls = allLeaves()
    say(("WS.Leaves มี %d ชิ้น"):format(#ls))
    for i = 1, math.min(3, #ls) do
        local m = ls[i]
        say(("--- [%d] %s [%s] ---"):format(i, m.Name, m.ClassName))
        local ok, attrs = pcall(function() return m:GetAttributes() end)
        if ok and attrs then
            local n = 0
            for k, v in pairs(attrs) do say(("  attr %s = %s (%s)"):format(k, tostring(v), typeof(v))); n = n + 1 end
            if n == 0 then say("  (ไม่มี attribute)") end
        end
        for _, c in ipairs(m:GetChildren()) do
            local extra = ""
            if c:IsA("ValueBase") then extra = " = " .. tostring(c.Value) end
            say(("  child %s [%s]%s"):format(c.Name, c.ClassName, extra))
            -- attributes ของลูกด้วย
            local ok2, a2 = pcall(function() return c:GetAttributes() end)
            if ok2 and a2 then
                for k, v in pairs(a2) do say(("    attr %s = %s"):format(k, tostring(v))) end
            end
        end
        local id, src = leafId(m)
        say(("  → id ที่เดาได้: %s (จาก %s)"):format(tostring(id), tostring(src)))
    end
    local ce = findRemote("CollectLeaf"); local ee = findRemote("EmptyBackpack")
    say(""); say("CollectLeaf: " .. (ce and ce:GetFullName() or "❌ ไม่เจอ"))
    say("EmptyBackpack: " .. (ee and ee:GetFullName() or "❌ ไม่เจอ"))
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
    say("(📋 ก๊อปแล้ว)")
end)

-- ==================== เทถุง ====================
local function doEmpty()
    local ee = findRemote("EmptyBackpack")
    if ee and ee:IsA("RemoteEvent") then ee:FireServer(); return true end
    return false
end
emptyB.MouseButton1Click:Connect(function()
    say(doEmpty() and "🗑️ เทกระเป๋าแล้ว" or "❌ ไม่เจอ EmptyBackpack")
end)

-- ==================== AUTO ====================
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    autoB.Text = AUTO_ON and "⏸ หยุด" or "▶ AUTO"
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(150, 60, 40) or Color3.fromRGB(40, 130, 60)
end)

task.spawn(function()
    local collected = 0
    local sinceEmpty = 0
    while _G.LF79_GEN == GEN do
        if AUTO_ON then
            local ce = findRemote("CollectLeaf")
            if not ce then
                status.Text = "❌ ไม่เจอ remote CollectLeaf (กด DUMP ดู)"
                task.wait(1)
            else
                local ls = allLeaves()
                if #ls == 0 then
                    status.Text = "🍂 ไม่มีใบไม้เหลือ — รอเกิดใหม่..."
                    task.wait(1)
                else
                    local fired = 0
                    for _, m in ipairs(ls) do
                        if not AUTO_ON or _G.LF79_GEN ~= GEN then break end
                        local id, src = leafId(m)
                        if id then
                            pcall(function() ce:FireServer(id) end)
                            collected = collected + 1
                            sinceEmpty = sinceEmpty + 1
                            fired = fired + 1
                            if sinceEmpty >= EMPTY_EVERY then
                                doEmpty(); sinceEmpty = 0
                            end
                            status.Text = ("🍂 เก็บแล้ว %d ใบ (เหลือ ~%d) id ล่าสุด %s [%s]")
                                :format(collected, #ls - fired, tostring(id), tostring(src))
                            task.wait(LEAF_DELAY)
                        end
                    end
                    if fired == 0 then
                        status.Text = ("⚠️ มีใบ %d ชิ้นแต่หา id ไม่เจอเลย — กด DUMP แล้วก๊อปมาให้ดู"):format(#ls)
                        task.wait(1.5)
                    else
                        doEmpty(); sinceEmpty = 0
                        task.wait(0.5)
                    end
                end
            end
        else
            status.Text = "🍂 AutoLeaf พร้อม (กด AUTO เริ่มฟาร์ม / DUMP ดูโครงสร้างใบ)"
            task.wait(0.3)
        end
    end
end)

warn("[AutoLeaf79] v1.0 loaded — AUTO เก็บใบไม้ทั้งแมพ + เทถุงอัตโนมัติ")
