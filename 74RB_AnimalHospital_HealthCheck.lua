-- 74RB_AnimalHospital_HealthCheck v1.2  (fix false-positive: remote เป็นลูกตรงๆ ของ Net + Items stream ช้า)
-- เช็ค "เฉพาะ" path/attr/remote/keyword ที่สคริปต์หลัก 74RB พึ่งพา ว่าเกมอัปเดตแล้วยังใช้ได้ไหม
-- ไม่ dump ทั้งเกม → ไล่เช็ครายการที่เรา hardcode ไว้เท่านั้น → ❌ = จุดที่ต้องแก้
-- เปิดในเกม (อยู่ในโรงพยาบาล, มีคนไข้/งานสักตัวจะเช็คได้ครบ) → GUI ขึ้น → กด Copy ส่งมา

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")
local RS = game:GetService("ReplicatedStorage")

local old = pg:FindFirstChild("AHHEALTHGUI"); if old then old:Destroy() end

-- ── GUI ─────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name = "AHHEALTHGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 600, 0, 500); frame.Position = UDim2.new(0.5, -300, 0.5, -250)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -180, 0, 28); titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "AH HealthCheck v1.2 — checking..."; titleLbl.Font = Enum.Font.Code
titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame
local function topBtn(w, x, col, txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 22); b.Position = UDim2.new(1, x, 0, 3)
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1,1,1); b.Text = txt
    b.Font = Enum.Font.Code; b.TextSize = 12; b.BorderSizePixel = 0; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4); return b
end
local copyBtn  = topBtn(62, -128, Color3.fromRGB(30,100,50), "Copy")
local reBtn    = topBtn(58, -62,  Color3.fromRGB(40,70,120), "อีกครั้ง")
local closeBtn = topBtn(28, -30,  Color3.fromRGB(120,20,20), "X")
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-8,1,-34); scroll.Position = UDim2.new(0,4,0,30)
scroll.BackgroundColor3 = Color3.fromRGB(8,8,14); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5; scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Parent = frame
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 4)
local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = scroll
local padL = Instance.new("UIPadding"); padL.PaddingLeft = UDim.new(0,6); padL.Parent = scroll

local copyLines, order = {}, 0
local C = { OK=Color3.fromRGB(80,255,120), BAD=Color3.fromRGB(255,80,80),
    WARN=Color3.fromRGB(255,210,0), HEAD=Color3.fromRGB(140,160,255), S=Color3.fromRGB(140,140,140) }
local function addLine(txt, col)
    order += 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-12,0,15); l.BackgroundTransparency = 1; l.Font = Enum.Font.Code
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextTruncate = Enum.TextTruncate.AtEnd
    l.TextColor3 = col or C.S; l.Text = txt; l.LayoutOrder = order; l.Parent = scroll
    table.insert(copyLines, txt)
    scroll.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y)
end
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
copyBtn.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok = clip and pcall(clip, table.concat(copyLines, "\n"))
    copyBtn.Text = ok and "Copied!" or "ไม่รองรับ"
    task.delay(2, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
end)

-- ── helper: resolve path แบบ dot เช่น "Workspace.NPCs" หรือ "ReplicatedStorage.Util.Net" ─────
local ROOTS = { Workspace = workspace, ReplicatedStorage = RS, workspace = workspace }
local function resolve(path)
    local parts = string.split(path, ".")
    local node = ROOTS[parts[1]]
    if not node then return nil, "root '"..parts[1].."' ไม่รู้จัก" end
    for i = 2, #parts do
        node = node:FindFirstChild(parts[i])
        if not node then return nil, "หยุดที่ '"..parts[i].."'" end
    end
    return node
end

-- ── ตารางเช็ค: {path, หมายเหตุ} — เช็คว่า instance ตาม path นี้ยังมีอยู่ไหม ──────────────
local PATHS = {
    -- โครงสร้างหลัก
    {"Workspace.NPCs",                         "โฟลเดอร์ NPC (ESP/รักษาทั้งหมด)"},
    {"Workspace.Misc",                         "ที่เก็บ CheckIn/Slime/Shop/RatthewKey"},
    {"Workspace.Misc.CheckIn",                 "จุดเช็คอิน"},
    {"Workspace.Misc.ShopItems",               "ร้านค้า container"},
    {"Workspace.Misc.ShopItems.1",             "ช่องร้าน 1"},
    {"Workspace.Model",                        "parent ของ Items (Items เอง stream ช้า — เช็คใน [2b])"},
    {"Workspace.Trash",                         "ถังขยะทิ้งยาผิด"},
    {"ReplicatedStorage.Util.Net",             "Net framework root (remote เป็นลูกตรงๆ ชื่อ 'RE/xxx')"},
    {"ReplicatedStorage.Data.UpgradeShopWares","config ร้านค้า"},
}

-- remote ที่ยิงจริง (ชื่อ substring ใต้ Net.RE / Net.RF)
local REMOTES = {
    "PlayShootEffect",   -- ยิงผี
    "RequestData",       -- RF หลัก
    "Quests", "Stats", "Historic", "Gamepasses",
    "HeartbeatMinigameComplete", "ReviveOther", "Touch",
    "TaserFired", "ExtinguisherBubbleHit", "ApplySpeedEffect",
}

-- attribute บน NPC ที่เราใช้แยกผี/งาน
local NPC_ATTRS = {
    "Skinwalker",  -- ผีปลอมตัว
    "Anomaly",     -- Hider/Ghost
    "Ghost", "WaterEntity", "OriginalFace",  -- Hider/Ghost signals
    "Fake", "IsPatient", "IsVisitor", "VisitingName",
    "Treated", "DesignatedRoom", "MedicineImmune", "AlwaysFaints",
}

-- ProximityPrompt ActionText ที่ auto-รักษาพึ่งพา (match ด้วยข้อความ)
local PP_ACTIONS = {
    "Talk", "Take DNA Sample", "Analyze Sample", "Process Results",
    "Apply Treatment", "Stamp Forms", "Take Photo", "Register",
    "Print Badge", "Ask to Leave", "Clean Slime", "Buy", "Coffee",
}

-- Report path (แหล่ง "ยาที่ถูก") — เช็คแบบ pattern เพราะ RoomN ต่างกัน
local REPORT_BITS = {
    {"Monitor.Screen.UI.Report", "illnesses (โรค)"},
    {"TV.Screen.UI.Report",      "inv (ยาที่ต้องใช้)"},
}

-- ── RUN ─────────────────────────────────────────────────────────
local function run()
    for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines = {}; order = 0
    local okN, badN = 0, 0
    local function mark(good) if good then okN += 1 else badN += 1 end end

    addLine("=== [1] PATHS (โครงสร้างที่ hardcode) ===", C.HEAD)
    for _, e in ipairs(PATHS) do
        local node, why = resolve(e[1])
        if node then addLine("  OK  "..e[1], C.OK)
        else addLine("  หาย "..e[1].."  ("..(why or "?")..")  ← "..e[2], C.BAD) end
        mark(node ~= nil)
    end

    addLine("", C.S); addLine("=== [2] REMOTES (ลูกตรงๆ ของ Net, ชื่อ 'RE/xxx') ===", C.HEAD)
    local net = select(1, resolve("ReplicatedStorage.Util.Net"))
    local remoteNames = {}
    if net then for _, d in ipairs(net:GetChildren()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then remoteNames[d.Name] = true end
    end end
    for _, r in ipairs(REMOTES) do
        local hit = nil
        for name in pairs(remoteNames) do if name:find(r, 1, true) then hit = name; break end end
        if hit then addLine(("  OK  %s  (=%s)"):format(r, hit), C.OK)
        else addLine("  หาย "..r, C.BAD) end
        mark(hit ~= nil)
    end

    addLine("", C.S); addLine("=== [3] NPC ATTRIBUTES (สแกน NPC ที่มีจริงตอนนี้) ===", C.HEAD)
    local seenAttr = {}
    local npcFolder = select(1, resolve("Workspace.NPCs"))
    local npcCount = 0
    if npcFolder then
        for _, npc in ipairs(npcFolder:GetChildren()) do
            if npc:IsA("Model") then
                npcCount += 1
                for k in pairs(npc:GetAttributes()) do seenAttr[k] = true end
            end
        end
    end
    addLine(("  (สแกน %d NPC ใน Workspace.NPCs)"):format(npcCount), C.S)
    for _, a in ipairs(NPC_ATTRS) do
        if seenAttr[a] then addLine("  พบ  "..a, C.OK)
        else addLine("  ไม่เจอ "..a.."  (อาจเพราะไม่มี NPC ชนิดนี้ตอนนี้ — ไม่ใช่ error เสมอไป)", C.WARN) end
    end

    addLine("", C.S); addLine("=== [4] PROMPT ACTIONS (สแกน PP ทั้ง Workspace) ===", C.HEAD)
    local seenPP = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then seenPP[d.ActionText] = true end
    end
    for _, a in ipairs(PP_ACTIONS) do
        if seenPP[a] then addLine("  พบ  '"..a.."'", C.OK)
        else addLine("  ไม่เจอ '"..a.."'  (อาจเพราะ prompt ยังไม่ enable/ห้องไกลโดน stream)", C.WARN) end
    end

    addLine("", C.S); addLine("=== [5] REPORT (แหล่งยาที่ถูก — เช็คในห้อง Medical) ===", C.HEAD)
    local medical = workspace:FindFirstChild("Rooms") and workspace.Rooms:FindFirstChild("Medical")
    if not medical then
        addLine("  หาย Workspace.Rooms.Medical", C.BAD); mark(false)
    else
        for _, room in ipairs(medical:GetChildren()) do
            local mg = room:FindFirstChild("Minigame")
            if mg then
                for _, bit in ipairs(REPORT_BITS) do
                    local node = mg
                    for _, seg in ipairs(string.split(bit[1], ".")) do
                        node = node and node:FindFirstChild(seg)
                    end
                    if node then addLine(("  OK  %s.Minigame.%s (%s)"):format(room.Name, bit[1], bit[2]), C.OK)
                    else addLine(("  หาย %s.Minigame.%s (%s)"):format(room.Name, bit[1], bit[2]), C.BAD) end
                end
                break -- เช็คห้องแรกที่มี Minigame พอ
            end
        end
    end

    addLine("", C.S)
    local verdict = (badN == 0) and C.OK or C.BAD
    addLine(("=== สรุป: OK=%d  หาย=%d ==="):format(okN, badN), verdict)
    if badN == 0 then addLine(">> โครงสร้างหลักครบ — ข้อมูลเดิมยังใช้ได้", C.OK)
    else addLine(">> มีจุดหาย ("..badN..") = เกมเปลี่ยน path/remote → ต้องแก้ตรงนั้น กด Copy ส่งมา", C.BAD) end
    addLine(">> หมวด NPC attr/PROMPT ที่ 'ไม่เจอ' เป็นสีเหลือง = ต้องมี NPC/งานชนิดนั้นในแมพตอนเช็คจึงยืนยันได้", C.WARN)
    titleLbl.Text = ("AH HealthCheck — OK:%d หาย:%d"):format(okN, badN)
end

reBtn.MouseButton1Click:Connect(run)
task.spawn(function() task.wait(0.1); run() end)
