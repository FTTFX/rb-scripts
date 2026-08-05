-- 75RB_AutoFarm.lua v1.0 — ออโต้ฟาร์มครบวงจร: วาปหาก้อนแพงสุด → ยิงรีโมตเก็บ →
--   กระเป๋าใกล้เต็ม → วาปไปร้าน SellWorker → ยิงขาย → วนใหม่
-- ใช้ความรู้จากสปายทั้งหมด:
--   เก็บ = RS.Remotes.CrystalHoldComplete:FireServer(ก้อน)   (DeepSpy)
--   ขาย = firesignal ตัวเลือก 1 ในเมนู GUI 'dialog' ("Sell all crystals")  (SellSpy v1.1)
--         *ยิง SellRequest ตรงๆ ไม่ได้ผล — server รับเฉพาะการเลือกในเมนูจริง*
--   น้ำหนัก = GUI ExplorerHud.BackpackPanel.Value '656.0 / 1237.0 kg'  (BagSpy)
--   เพดาน = PlayerData.RealStats.CarryWeight | เงิน = RealStats.Cash
--   ก้อนบ้าน: ใต้ Plots / ไม่มี prompt → ข้าม (HomeSpy)
-- v1.6: กรองช่วงน้ำหนักแร่ (ดีฟอลต์ 50-1000 kg) ปรับได้ที่แผง — ก้อนจิ๋ว 0.2kg เสียเวลาวาปเปล่า
-- v1.5: วนหา 8 มุมรอบก้อน (ระดับเดียวกัน) + เช็ค "ปุ่มติดไหม" ด้วย PromptShown ก่อนกด
--       ติด=กดจริงรอผล | ไม่ติด=วาปมุมถัดไปทันที (ไม่เสียเวลากดลม) + จำมุมที่เข้า
-- v1.4: ยิง remote เปล่าไม่เข้าแล้ว (ยิง 10 ครั้งก้อนไม่ขยับ) → บอทไล่หา "ท่าที่เข้า" เอง
-- v1.3: กล่อง log ในตัว (สปายการทำงานเอง) — เวลาวาป/จำนวนครั้งที่ยิง/ก้อนหายเทียบของเข้า/
--       จังหวะขาย + ปุ่ม COPY log ส่งให้ Claude วิเคราะห์
-- v1.2: จังหวะแม่นขึ้น — รอ "ถึงก้อนจริง" ก่อนยิง + ยืนยันด้วย "น้ำหนักกระเป๋าเพิ่ม"
--       (ก้อนหายจากแมพไม่พอ! FX ลบก้อนก่อนของเข้ากระเป๋า → เดิมวาปหนีเร็วเกินของหลุด)
-- การเคลื่อนที่: ตรึง CFrame แบบ 74RB (ไม่ร่วง ไม่โดนผลัก ทะลุกำแพง) + ปิดท่าตก
if _G.AF75_CONNS then
    for _, c in pairs(_G.AF75_CONNS) do pcall(function() c:Disconnect() end) end
end
if _G.AF75_GUI then pcall(function() _G.AF75_GUI:Destroy() end) end
_G.AF75_CONNS = {}
_G.AF75_RUN = false

local V = "1.6"
local Players = game:GetService("Players")
local RunSvc  = game:GetService("RunService")
local RS      = game:GetService("ReplicatedStorage")
local LP      = Players.LocalPlayer

local Rem   = RS:FindFirstChild("Remotes")
local pickR = Rem and Rem:FindFirstChild("CrystalHoldComplete")
local sellR = Rem and Rem:FindFirstChild("SellRequest")

-- ==================== Config/State ====================
local MIN_TIER  = 4
local SELL_PCT  = 0.85          -- กระเป๋าถึง % นี้ → ไปขาย
local KG_MIN    = 50            -- v1.6: เอาเฉพาะก้อน 50-1000 kg (ก้อนจิ๋วเสียเวลาวาปเปล่า)
local KG_MAX    = 1000
local statPick, statVal, statSell = 0, 0, 0
local FAILED = {}               -- ก้อนที่เก็บไม่เข้า พัก 30 วิ
local TARGET_POS = nil          -- จุดตรึงตัว (nil = ไม่ตรึง เดินเองได้)

local function fmtMoney(v)
    if v >= 1e9 then return ("$%.2fB"):format(v / 1e9) end
    if v >= 1e6 then return ("$%.1fM"):format(v / 1e6) end
    if v >= 1e3 then return ("$%.0fK"):format(v / 1e3) end
    return "$" .. math.floor(v)
end

-- น้ำหนักกระเป๋า: อ่านจาก GUI (ตรงกับจอเป๊ะ) | สำรอง: บวก WeightKg ของในกระเป๋า
local function bagInfo()
    local pg = LP:FindFirstChild("PlayerGui")
    local lbl = pg and pg:FindFirstChild("ExplorerHud")
    lbl = lbl and lbl:FindFirstChild("BackpackPanel")
    lbl = lbl and lbl:FindFirstChild("Value")
    if lbl and lbl:IsA("TextLabel") then
        local a, b = lbl.Text:match("([%d%.]+)%s*/%s*([%d%.]+)")
        if a and b then return tonumber(a), tonumber(b) end
    end
    -- สำรอง: บวกเองจาก Inventory.Crystals + CarryWeight
    local cur, cap = 0, 1e9
    local pd = LP:FindFirstChild("PlayerData")
    local inv = pd and pd:FindFirstChild("Inventory")
    inv = inv and inv:FindFirstChild("Crystals")
    if inv then
        for _, c in ipairs(inv:GetChildren()) do
            cur += (c:GetAttribute("WeightKg") or 0)
        end
    end
    local rs2 = pd and pd:FindFirstChild("RealStats")
    local cw = rs2 and rs2:FindFirstChild("CarryWeight")
    if cw then cap = cw.Value end
    return cur, cap
end

local function cashNow()
    local pd = LP:FindFirstChild("PlayerData")
    local st = pd and pd:FindFirstChild("RealStats")
    local c = st and st:FindFirstChild("Cash")
    return c and c.Value or 0
end

-- ก้อนที่เก็บได้จริง (กรองบ้านเพื่อน + ต้องมี prompt) — สูตรเดียวกับ ESP/Assist
local function getCrystals()
    local out = {}
    for _, c in ipairs(workspace:GetDescendants()) do
        if c:IsA("BasePart") and c:GetAttribute("CrystalName") and c:GetAttribute("Tier")
            and not c:FindFirstAncestor("Plots") then
            local pp = c:FindFirstChildOfClass("ProximityPrompt")
            if pp and pp.Enabled then out[#out + 1] = c end
        end
    end
    return out
end

local function bestCrystal(maxKg)
    local best, bv
    for _, c in ipairs(getCrystals()) do
        local t = c:GetAttribute("Tier")
        if t and t >= MIN_TIER and (not FAILED[c] or os.clock() > FAILED[c]) then
            local kg = c:GetAttribute("WeightKg") or 0
            -- ยัดกระเป๋าลง + อยู่ในช่วงน้ำหนักที่ตั้งไว้ (v1.6)
            if kg <= maxKg and kg >= KG_MIN and kg <= KG_MAX then
                local v = c:GetAttribute("Value") or 0
                if not bv or v > bv then best, bv = c, v end
            end
        end
    end
    return best
end

-- v1.1 (SellSpy): กดขาย = ยิงทุกสัญญาณใส่ตัวเลือก 1 ในเมนู GUI 'dialog' + ปุ่ม Sell.Frame.Sell
-- (ยิง SellRequest ตรงๆ server ไม่รับ — ต้อง "เลือกในเมนู" จริงเท่านั้น)
local FS = firesignal or (getgenv and getgenv().firesignal)
local function fireAll(obj)
    if not FS or not obj then return end
    for _, s in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down",
        "MouseButton1Up", "InputBegan", "InputEnded", "TouchTap" }) do
        pcall(function() if obj[s] then FS(obj[s]) end end)
    end
end
local function pressSellMenu()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local dlg = pg:FindFirstChild("dialog", true)
    local resp = dlg and dlg:FindFirstChild("dialogResponses", true)
    local one = resp and resp:FindFirstChild("1")     -- "Sell all crystals"
    if one then
        fireAll(one)
        for _, c in ipairs(one:GetDescendants()) do
            if c:IsA("GuiButton") then fireAll(c) end
        end
        local p = one.Parent
        while p and p ~= pg do
            if p:IsA("GuiButton") then fireAll(p) end
            p = p.Parent
        end
    end
    local sg = pg:FindFirstChild("Sell")
    local sbtn = sg and sg:FindFirstChild("Frame")
    sbtn = sbtn and sbtn:FindFirstChild("Sell")
    if sbtn then fireAll(sbtn) end
end

local function findSeller()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d.Name == "SellWorker" then
            local p = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)
            if p then return d, p.Position end
        end
    end
end

-- ==================== ตรึงตัวแบบ 74RB (บิน/วาป/กันผลัก/ทะลุกำแพง) ====================
local function setNoFall(on)
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not h then return end
    h:SetStateEnabled(Enum.HumanoidStateType.Freefall, not on)
    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not on)
    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not on)
end
table.insert(_G.AF75_CONNS, RunSvc.Heartbeat:Connect(function()
    if not TARGET_POS then return end
    local char = LP.Character
    local r = char and char:FindFirstChild("HumanoidRootPart")
    if not r then return end
    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    r.CFrame = CFrame.new(TARGET_POS) * (r.CFrame - r.CFrame.Position)
    r.AssemblyLinearVelocity = Vector3.zero
end))
local function unpin()
    TARGET_POS = nil
    setNoFall(false)
    local char = LP.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarm75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.AF75_GUI = gui

local FULL_H, MIN_H = 440, 32
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 210, 0, FULL_H)
panel.Position = UDim2.new(0.5, -105, 0, 20)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
panel.BorderSizePixel = 0
panel.Active, panel.Draggable = true, true
panel.ClipsDescendants = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -70, 0, 28); title.Position = UDim2.new(0, 8, 0, 2)
title.BackgroundTransparency = 1
title.Text = "AutoFarm v" .. V
title.Font = Enum.Font.GothamBold; title.TextSize = 14
title.TextColor3 = Color3.fromRGB(255, 170, 70)
title.TextXAlignment = Enum.TextXAlignment.Left

local foldB = Instance.new("TextButton", panel)
foldB.Size = UDim2.new(0, 28, 0, 24); foldB.Position = UDim2.new(1, -62, 0, 4)
foldB.Text = "—"; foldB.Font = Enum.Font.GothamBold; foldB.TextSize = 14
foldB.BackgroundColor3 = Color3.fromRGB(50, 50, 70); foldB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", foldB).CornerRadius = UDim.new(0, 5)

local closeB = Instance.new("TextButton", panel)
closeB.Size = UDim2.new(0, 28, 0, 24); closeB.Position = UDim2.new(1, -32, 0, 4)
closeB.Text = "✕"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 14
closeB.BackgroundColor3 = Color3.fromRGB(140, 30, 30); closeB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", closeB).CornerRadius = UDim.new(0, 5)

local runB = Instance.new("TextButton", panel)
runB.Size = UDim2.new(0, 198, 0, 34); runB.Position = UDim2.new(0, 6, 0, 32)
runB.Text = "▶ เริ่มฟาร์ม"; runB.Font = Enum.Font.GothamBold; runB.TextSize = 15
runB.BackgroundColor3 = Color3.fromRGB(30, 120, 30); runB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", runB).CornerRadius = UDim.new(0, 6)

local tierB = Instance.new("TextButton", panel)
tierB.Size = UDim2.new(0, 96, 0, 26); tierB.Position = UDim2.new(0, 6, 0, 72)
tierB.Text = "เทียร์ ≥ T4"; tierB.Font = Enum.Font.GothamBold; tierB.TextSize = 12
tierB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); tierB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", tierB).CornerRadius = UDim.new(0, 5)
tierB.MouseButton1Click:Connect(function()
    MIN_TIER = MIN_TIER % 6 + 1
    tierB.Text = "เทียร์ ≥ T" .. MIN_TIER
end)

local pctB = Instance.new("TextButton", panel)
pctB.Size = UDim2.new(0, 96, 0, 26); pctB.Position = UDim2.new(0, 108, 0, 72)
pctB.Text = "ขายที่ 85%"; pctB.Font = Enum.Font.GothamBold; pctB.TextSize = 12
pctB.BackgroundColor3 = Color3.fromRGB(150, 110, 30); pctB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", pctB).CornerRadius = UDim.new(0, 5)
pctB.MouseButton1Click:Connect(function()
    SELL_PCT = SELL_PCT >= 0.95 and 0.5 or SELL_PCT + 0.15
    pctB.Text = ("ขายที่ %d%%"):format(SELL_PCT * 100)
end)

-- v1.6: ช่วงน้ำหนักแร่ที่จะเก็บ  ต่ำสุด − [50] +   สูงสุด − [1000] +
local kgL = Instance.new("TextLabel", panel)
kgL.Size = UDim2.new(1, -12, 0, 18); kgL.Position = UDim2.new(0, 6, 0, 102)
kgL.BackgroundTransparency = 1
kgL.Text = "น้ำหนักแร่ 50 - 1000 kg"
kgL.Font = Enum.Font.GothamBold; kgL.TextSize = 12
kgL.TextColor3 = Color3.fromRGB(255, 220, 150)
local function updKgL()
    kgL.Text = ("น้ำหนักแร่ %d - %d kg"):format(KG_MIN, KG_MAX)
end
local function kgBtn(txt, x, isMin, delta)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 42, 0, 24); b.Position = UDim2.new(0, x, 0, 122)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = isMin and Color3.fromRGB(45, 65, 45) or Color3.fromRGB(65, 45, 45)
    b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function()
        if isMin then
            KG_MIN = math.clamp(KG_MIN + delta, 0, KG_MAX - 10)
        else
            KG_MAX = math.clamp(KG_MAX + delta, KG_MIN + 10, 5000)
        end
        updKgL()
    end)
end
kgBtn("ต่ำ −", 6, true, -25)
kgBtn("ต่ำ +", 52, true, 25)
kgBtn("สูง −", 110, false, -100)
kgBtn("สูง +", 156, false, 100)

local statusL = Instance.new("TextLabel", panel)
statusL.Size = UDim2.new(1, -12, 0, 34); statusL.Position = UDim2.new(0, 6, 0, 150)
statusL.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
statusL.Text = " พร้อม"
statusL.Font = Enum.Font.Gotham; statusL.TextSize = 11
statusL.TextColor3 = Color3.fromRGB(255, 220, 150)
statusL.TextXAlignment = Enum.TextXAlignment.Left
statusL.TextWrapped = true
Instance.new("UICorner", statusL).CornerRadius = UDim.new(0, 5)
local function status(s) statusL.Text = " " .. s end

-- v1.3: กล่อง log ในตัว — เห็นจังหวะจริงทุกขั้น (เลือก/วาป/ถึง/ยิง/น้ำหนักขยับ) + COPY ส่งได้
local LOG = {}
local T0 = os.clock()
local logBox = Instance.new("TextLabel", panel)
logBox.Size = UDim2.new(1, -12, 0, 120); logBox.Position = UDim2.new(0, 6, 0, 286)
logBox.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
logBox.Text = ""
logBox.Font = Enum.Font.Code; logBox.TextSize = 10
logBox.TextColor3 = Color3.fromRGB(170, 230, 255)
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Bottom
logBox.TextWrapped = true
Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 5)
local function LG(s)
    LOG[#LOG + 1] = ("[%6.1f] %s"):format(os.clock() - T0, s)
    if #LOG > 200 then table.remove(LOG, 1) end
    local from = math.max(1, #LOG - 11)
    local view = {}
    for i = from, #LOG do view[#view + 1] = LOG[i] end
    logBox.Text = table.concat(view, "\n")
end

local copyB = Instance.new("TextButton", panel)
copyB.Size = UDim2.new(0, 96, 0, 24); copyB.Position = UDim2.new(0, 6, 0, 410)
copyB.Text = "COPY log"; copyB.Font = Enum.Font.GothamBold; copyB.TextSize = 12
copyB.BackgroundColor3 = Color3.fromRGB(40, 90, 150); copyB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", copyB).CornerRadius = UDim.new(0, 5)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(LOG, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_farm_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์!" or "copy ไม่ได้")
    task.delay(1.6, function() copyB.Text = "COPY log" end)
end)

local clrB = Instance.new("TextButton", panel)
clrB.Size = UDim2.new(0, 96, 0, 24); clrB.Position = UDim2.new(0, 108, 0, 410)
clrB.Text = "CLEAR"; clrB.Font = Enum.Font.GothamBold; clrB.TextSize = 12
clrB.BackgroundColor3 = Color3.fromRGB(90, 60, 30); clrB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", clrB).CornerRadius = UDim.new(0, 5)
clrB.MouseButton1Click:Connect(function() LOG = {}; logBox.Text = "" end)

local statL = Instance.new("TextLabel", panel)
statL.Size = UDim2.new(1, -12, 0, 92); statL.Position = UDim2.new(0, 6, 0, 190)
statL.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
statL.Font = Enum.Font.Code; statL.TextSize = 11
statL.TextColor3 = Color3.fromRGB(190, 220, 190)
statL.TextXAlignment = Enum.TextXAlignment.Left
statL.TextYAlignment = Enum.TextYAlignment.Top
statL.TextWrapped = true
Instance.new("UICorner", statL).CornerRadius = UDim.new(0, 5)
local cash0 = cashNow()
local function updStat()
    local cur, cap = bagInfo()
    statL.Text = (" เก็บ %d ก้อน (%s)\n ขาย %d รอบ\n กระเป๋า %.0f/%.0f kg\n กำไรรอบนี้ %s")
        :format(statPick, fmtMoney(statVal), statSell, cur, cap, fmtMoney(cashNow() - cash0))
end
updStat()

-- ==================== v1.4: ตัวไล่หา "ท่าที่เก็บเข้า" ====================
-- ยิง remote เปล่าไม่เข้า (ยิง 10 ครั้งก้อนไม่ขยับ) แต่กดมือ E เข้า
-- → ไล่ลอง ตำแหน่ง x วิธี จนเจอสูตรที่ได้ผล แล้ว "จำสูตรนั้น" ใช้กับก้อนต่อไปเลย
-- ตำแหน่ง: ระดับเดียวกับก้อน (รอบทิศ) / เหนือ / ใต้  | วิธี: prompt กดค้าง / remote / ทั้งคู่
local WIN_POS, WIN_WAY = nil, nil     -- สูตรที่เคยเข้า (จำไว้ ลองอันนี้ก่อนเสมอ)

-- v1.5: เช็ค "ปุ่มติดไหม" ด้วย PromptShown/PromptHidden (เกมโชว์ปุ่ม E = อยู่ในระยะ+มองเห็น)
-- → วาปวนมุม ถ้าปุ่มติดค่อยกด ถ้าไม่ติดวาปมุมถัดไปเลย ไม่เสียเวลากดลม
local PROMPT_ON = nil
local PPS = game:GetService("ProximityPromptService")
table.insert(_G.AF75_CONNS, PPS.PromptShown:Connect(function(pp) PROMPT_ON = pp end))
table.insert(_G.AF75_CONNS, PPS.PromptHidden:Connect(function(pp)
    if PROMPT_ON == pp then PROMPT_ON = nil end
end))
local function promptReady(c)
    local pp = c:FindFirstChildOfClass("ProximityPrompt")
    return pp and PROMPT_ON == pp
end

-- v1.5: 8 มุมรอบก้อน "ระดับเดียวกัน" (ท่าที่ log พิสูจน์ว่าเข้า) + สำรองต่ำ/สูง
local function posList(c)
    local p, out = c.Position, {}
    local d = 4 + math.min(6, (c.Size.Magnitude or 4) / 2)   -- ก้อนใหญ่ยืนห่างขึ้นนิด
    local dirs = {
        { "N", 0, -1 }, { "NE", 0.7, -0.7 }, { "E", 1, 0 }, { "SE", 0.7, 0.7 },
        { "S", 0, 1 }, { "SW", -0.7, 0.7 }, { "W", -1, 0 }, { "NW", -0.7, -0.7 },
    }
    for _, dir in ipairs(dirs) do
        out[#out + 1] = { "ระดับเดียวกัน " .. dir[1],
            p + Vector3.new(dir[2] * d, 0, dir[3] * d) }
    end
    out[#out + 1] = { "ต่ำกว่า 3", p + Vector3.new(0, -3, -d) }
    out[#out + 1] = { "เหนือ 6", p + Vector3.new(0, 6, 0) }
    return out
end
local function doWay(c, way)
    local pp = c:FindFirstChildOfClass("ProximityPrompt")
    if way == "prompt" and pp then
        pcall(function() pp:InputHoldBegin() end)
        task.wait(pp.HoldDuration + 0.4)
        pcall(function() pp:InputHoldEnd() end)
    elseif way == "remote" then
        pcall(function() pickR:FireServer(c) end)
    elseif way == "both" and pp then
        pcall(function() pp:InputHoldBegin() end)
        pcall(function() pickR:FireServer(c) end)
        task.wait(pp.HoldDuration + 0.4)
        pcall(function() pp:InputHoldEnd() end)
        pcall(function() pickR:FireServer(c) end)
    elseif way == "fp" then
        local fp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
        if fp and pp then pcall(fp, pp, 1) end
    end
end
-- v1.5: ที่มุมนี้ "กดติดไหม" → ติดก็กดจริง (รอผล) | ไม่ติดก็รีเทิร์นไว ไปมุมถัดไป
local function attempt(c, kg0, pname, ppos)
    TARGET_POS = ppos
    -- รอปุ่มติดสูงสุด 0.75 วิ (เช็คถี่ — ติดเร็วก็กดเร็ว)
    local ok = false
    for _ = 1, 5 do
        task.wait(0.15)
        if promptReady(c) then ok = true break end
    end
    if not ok then return false end       -- ไม่ติด → วาปมุมถัดไปทันที
    for _, way in ipairs({ "both", "prompt" }) do
        doWay(c, way)
        for _ = 1, 8 do
            task.wait(0.15)
            if bagInfo() > kg0 + 0.05 then
                LG(("  ✅ เข้า! [%s + %s] (ปุ่มติด)"):format(pname, way))
                WIN_POS, WIN_WAY = pname, way
                return true
            end
        end
        if not c.Parent then break end
    end
    return false
end

function tryPick(c, kg0)
    local list = posList(c)
    -- 1) มุมที่เคยเข้า ลองก่อน (เร็ว)
    if WIN_POS then
        for _, e in ipairs(list) do
            if e[1] == WIN_POS then
                status("⛏ " .. WIN_POS)
                if attempt(c, kg0, e[1], e[2]) then return true end
                break
            end
        end
    end
    -- 2) วนหามุมที่ "ปุ่มติด" (8 มุมรอบก้อน + ต่ำ/สูง) — ติดแล้วกด ไม่ติดวาปต่อ
    for _, e in ipairs(list) do
        if not _G.AF75_RUN then return false end
        if not c.Parent then
            task.wait(0.5)
            return bagInfo() > kg0 + 0.05
        end
        if e[1] ~= WIN_POS then
            status("🔎 " .. e[1])
            if attempt(c, kg0, e[1], e[2]) then return true end
        end
    end
    LG(("  ❌ วนครบ %d มุมแล้วไม่เข้า (ก้อนหาย=%s)"):format(#list, tostring(c.Parent == nil)))
    return false
end

-- ==================== Main farm loop ====================
local function farmLoop()
    while _G.AF75_RUN do
        local cur, cap = bagInfo()
        updStat()
        if cur / cap >= SELL_PCT then
            -- ─── ไปขาย ───
            local seller, spos = findSeller()
            if not seller then
                status("❌ หาร้าน SellWorker ไม่เจอ — หยุด")
                break
            end
            LG(("💰 กระเป๋า %.1f/%.0f (%.0f%%) → ไปขาย"):format(cur, cap, cur / cap * 100))
            status("💰 วาปไปร้าน...")
            setNoFall(true)
            TARGET_POS = spos + Vector3.new(0, 3, 0)
            task.wait(1.2)   -- ให้ตำแหน่ง replicate + SellOpen เด้ง
            local before = cur
            local sold = false
            -- v1.1 (SellSpy): ขาย = กดตัวเลือก 1 ในเมนู GUI 'dialog' ("Sell all crystals")
            -- ด้วย firesignal (ยิง SellRequest เปล่าๆ server ไม่รับ ต้องเลือกในเมนูจริง)
            for vi = 1, 5 do
                if not _G.AF75_RUN then break end
                status(("💰 กดขาย ครั้งที่ %d/5..."):format(vi))
                local pg = LP:FindFirstChild("PlayerGui")
                local hasMenu = pg and pg:FindFirstChild("dialog", true) ~= nil
                pressSellMenu()
                task.wait(1.5)
                local c2 = bagInfo()
                LG(("  ขายครั้ง %d: เมนูเปิด=%s | %.1f → %.1f kg"):format(
                    vi, tostring(hasMenu), before, c2))
                if c2 < before - 1 then sold = true break end
            end
            unpin()
            if sold then
                statSell += 1
                LG("  ✅ ขายสำเร็จ! เงินรวม " .. fmtMoney(cashNow()))
                status("✅ ขายสำเร็จ! ฟาร์มต่อ")
            else
                status("❌ ขายไม่เข้า — เมนูอาจไม่เปิด (ลองเดินเข้าใกล้ NPC อีกนิด)")
                _G.AF75_RUN = false
                break
            end
        else
            -- ─── ขุด ───
            local c = bestCrystal(cap - cur)
            if not c then
                status(("🔍 ไม่เจอก้อน (T≥%d, %d-%dkg) — รอ spawn..."):format(
                    MIN_TIER, KG_MIN, KG_MAX))
                task.wait(2)
            else
                local nm = c:GetAttribute("CrystalName") or "?"
                local v = c:GetAttribute("Value") or 0
                local kg0 = cur   -- น้ำหนักก่อนเก็บ — ใช้ยืนยันว่าของเข้ากระเป๋าจริง
                local myp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                LG(("🎯 %s %s %.1fkg | ห่าง %dm | กระเป๋า %.1f"):format(nm, fmtMoney(v),
                    c:GetAttribute("WeightKg") or 0,
                    myp and math.floor((c.Position - myp.Position).Magnitude) or -1, kg0))
                status(("⛏ ไปหา %s %s"):format(nm, fmtMoney(v)))
                setNoFall(true)
                local dest = c.Position + Vector3.new(0, 6, 0)
                TARGET_POS = dest
                -- v1.2: รอ "ถึงจริง" ก่อนยิง (เช็คระยะ) — ไม่ใช่หลับตารอเวลาคงที่
                local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local tA = os.clock()
                while _G.AF75_RUN and r and (r.Position - dest).Magnitude > 5
                    and os.clock() - tA < 3 do
                    task.wait(0.1)
                end
                LG(("  ✈ ถึงแล้วใน %.2f วิ (ห่างเป้า %.1f)"):format(os.clock() - tA,
                    r and (r.Position - dest).Magnitude or -1))
                task.wait(0.35)   -- ให้ตำแหน่งใหม่ replicate ถึง server
                status(("⛏ ขุด %s %s"):format(nm, fmtMoney(v)))
                local got = tryPick(c, kg0)
                if got then
                    statPick += 1
                    statVal += v
                    task.wait(0.25)   -- ค้างอีกนิด ให้ FX/ของเข้าครบก่อนวาปหนี
                else
                    FAILED[c] = os.clock() + 30
                    status("❌ " .. nm .. " เก็บไม่เข้า — ข้าม 30 วิ")
                end
                updStat()
            end
        end
        task.wait(0.2)
    end
    unpin()
    runB.Text = "▶ เริ่มฟาร์ม"
    runB.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
end

runB.MouseButton1Click:Connect(function()
    _G.AF75_RUN = not _G.AF75_RUN
    if _G.AF75_RUN then
        runB.Text = "⏸ หยุดฟาร์ม"
        runB.BackgroundColor3 = Color3.fromRGB(150, 60, 30)
        task.spawn(farmLoop)
    else
        status("หยุดแล้ว")
    end
end)

local folded = false
foldB.MouseButton1Click:Connect(function()
    folded = not folded
    panel.Size = UDim2.new(0, 210, 0, folded and MIN_H or FULL_H)
end)
closeB.MouseButton1Click:Connect(function()
    _G.AF75_RUN = false
    unpin()
    for _, c in pairs(_G.AF75_CONNS) do pcall(function() c:Disconnect() end) end
    gui:Destroy(); _G.AF75_GUI, _G.AF75_CONNS = nil, {}
end)

if not pickR then status("⚠️ ไม่เจอ remote เก็บ CrystalHoldComplete!") end
if not FS then status("⚠️ executor ไม่มี firesignal — ขายอัตโนมัติไม่ได้ (ต้องขายมือ)") end
print("[75RB AutoFarm v" .. V .. "] พร้อม | เก็บ=CrystalHoldComplete | ขาย=กดเมนู dialog ตัวเลือก 1")
