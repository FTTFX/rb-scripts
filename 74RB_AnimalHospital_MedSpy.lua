-- 74RB_AnimalHospital_MedSpy v1.0  (หา: ยาที่ถูกของผู้ป่วย + ตำแหน่งยาแต่ละชนิด)
-- *** วินิจฉัยผู้ป่วย 1 คนก่อน (Analyze/Process) ให้จอ TREATMENT โชว์ไอคอนยา ***
-- แล้วค่อยรันอันนี้ → dump: NPC attrs เต็ม / จอ treatment (Image id) / ยาทั้งหมด + ตำแหน่ง
-- กด Copy → วางมา  เราจะ map "โรค → ยา" ได้ แล้วทำ Auto วาปเก็บยา+ให้ตรงโรค

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("AHMEDGUI"); if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "AHMEDGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 580, 0, 470); frame.Position = UDim2.new(0.5, -290, 0.5, -235)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-185,0,28); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "MedSpy v2 — scanning..."; titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame
local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0,110,0,22); copyBtn.Position = UDim2.new(1,-178,0,3)
copyBtn.BackgroundColor3 = Color3.fromRGB(30,100,50); copyBtn.TextColor3 = Color3.new(1,1,1)
copyBtn.Text = "Copy"; copyBtn.Font = Enum.Font.Code; copyBtn.TextSize = 12
copyBtn.BorderSizePixel = 0; copyBtn.Parent = frame
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0,4)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,60,0,22); closeBtn.Position = UDim2.new(1,-64,0,3)
closeBtn.BackgroundColor3 = Color3.fromRGB(120,20,20); closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Text = "ปิด"; closeBtn.Font = Enum.Font.Code; closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0; closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,4)
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-8,1,-34); scroll.Position = UDim2.new(0,4,0,30)
scroll.BackgroundColor3 = Color3.fromRGB(8,8,14); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5; scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Parent = frame
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,4)
local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = scroll
local padL = Instance.new("UIPadding"); padL.PaddingLeft = UDim.new(0,6); padL.Parent = scroll

local copyLines, order = {}, 0
local C = { Y=Color3.fromRGB(255,210,0), G=Color3.fromRGB(80,255,120), B=Color3.fromRGB(140,160,255),
    O=Color3.fromRGB(255,160,50), W=Color3.fromRGB(210,210,210), S=Color3.fromRGB(140,140,140),
    R=Color3.fromRGB(255,80,80), M=Color3.fromRGB(255,120,255) }
local function addLine(txt, col)
    order += 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-12,0,15); l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd; l.TextColor3 = col or C.W
    l.Text = txt; l.LayoutOrder = order; l.Parent = scroll
    table.insert(copyLines, txt)
end
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
copyBtn.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok = clip and pcall(clip, table.concat(copyLines, "\n"))
    copyBtn.Text = ok and "Copied!" or "ไม่รองรับ"
    task.delay(2, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
end)

local rescanBtn = Instance.new("TextButton")
rescanBtn.Size = UDim2.new(0,90,0,22); rescanBtn.Position = UDim2.new(1,-272,0,3)
rescanBtn.BackgroundColor3 = Color3.fromRGB(40,70,120); rescanBtn.TextColor3 = Color3.new(1,1,1)
rescanBtn.Text = "RESCAN"; rescanBtn.Font = Enum.Font.Code; rescanBtn.TextSize = 12
rescanBtn.BorderSizePixel = 0; rescanBtn.Parent = frame
Instance.new("UICorner", rescanBtn).CornerRadius = UDim.new(0,4)

local function attrsStr(inst)
    local ak = {}
    for k, v in pairs(inst:GetAttributes()) do ak[#ak+1] = k.."="..tostring(v) end
    return table.concat(ak, ", ")
end

local function runScan()
    -- ล้างผลเก่า
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    copyLines = {}; order = 0
    task.wait(0.05)
    local ok, err = pcall(function()
        -- A) ผู้ป่วยทุกคน — attrs เต็ม + values (หา Disease/Cure/Medicine/Sickness)
        addLine("===== PATIENTS (attrs เต็ม) =====", C.Y)
        local npcs = workspace:FindFirstChild("NPCs")
        if npcs then for _, m in ipairs(npcs:GetChildren()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
                addLine("NPC: " .. m.Name, C.G)
                local a = attrsStr(m); if a ~= "" then addLine("   attrs: " .. a, C.O) end
                for _, c in ipairs(m:GetDescendants()) do
                    if c:IsA("ValueBase") then
                        addLine(("   val %s[%s]=%s"):format(c.Name, c.ClassName, tostring(c.Value)), C.M)
                    end
                end
            end
        end end
        addLine("", C.S)

        -- B) ห้อง Medical: หาไอคอน "ยาที่ต้องใช้" บนจอ TREATMENT (Decal.Texture/Image) + values/attrs
        addLine("===== MEDICAL ROOMS (จอ treatment + minigame) =====", C.Y)
        local function relPath(c, root)
            local s = c.Name
            local p = c.Parent
            while p and p ~= root do s = p.Name .. "." .. s; p = p.Parent end
            return s
        end
        local rooms = workspace:FindFirstChild("Rooms")
        local med = rooms and rooms:FindFirstChild("Medical")
        if med then for _, room in ipairs(med:GetChildren()) do
            addLine("ROOM: " .. room.Name, C.B)
            local ra = attrsStr(room); if ra ~= "" then addLine("   attrs: " .. ra, C.O) end
            for _, c in ipairs(room:GetDescendants()) do
                local rp = relPath(c, room)
                if c:IsA("ValueBase") then
                    addLine(("   val %s = %s"):format(rp, tostring(c.Value)), C.M)
                elseif (c:IsA("ImageLabel") or c:IsA("ImageButton")) and c.Image ~= "" then
                    addLine(("   IMG %s = %s"):format(rp, c.Image), C.G)
                elseif c:IsA("Decal") and c.Texture ~= "" then       -- Decal ใช้ .Texture
                    addLine(("   DECAL %s = %s"):format(rp, c.Texture), C.G)
                elseif c:IsA("TextLabel") and c.Text ~= "" then
                    addLine(("   TXT %s = '%s'"):format(rp, c.Text), C.W)
                end
                local ca = attrsStr(c)
                if ca ~= "" then addLine(("   attr@%s: %s"):format(rp, ca), C.O) end
            end
        end end
        addLine("", C.S)

        -- C) ยาแต่ละชนิด: ไอคอน (Decal/Image/Tool TextureId) → เอาไป match กับจอ
        addLine("===== MEDICINE ITEMS (ไอคอน เพื่อ map กับจอ) =====", C.Y)
        local model = workspace:FindFirstChild("Model")
        local items = model and model:FindFirstChild("Items")
        if items then for _, it in ipairs(items:GetChildren()) do
            addLine("ITEM: " .. it.Name, C.G)
            for _, c in ipairs(it:GetDescendants()) do
                if c:IsA("Decal") and c.Texture ~= "" then
                    addLine(("   DECAL %s = %s"):format(c.Name, c.Texture), C.B)
                elseif (c:IsA("ImageLabel") or c:IsA("ImageButton")) and c.Image ~= "" then
                    addLine(("   IMG %s = %s"):format(c.Name, c.Image), C.B)
                end
            end
            local a = attrsStr(it); if a ~= "" then addLine("   attrs: " .. a, C.O) end
        end end
        -- Tools ที่ถืออยู่ (มี TextureId = ไอคอน)
        local function dumpTool(t, where)
            if not t:IsA("Tool") then return end
            addLine(("   Tool[%s]: '%s' tex=%s"):format(where, t.Name, tostring(t.TextureId)), C.G)
        end
        local bp = LP:FindFirstChild("Backpack")
        if bp then for _, t in ipairs(bp:GetChildren()) do dumpTool(t, "BP") end end
        if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do dumpTool(t, "EQ") end end
        addLine("", C.S)

        -- D) จุดเก็บยา: ProximityPrompt ที่ไม่ใช่ door/treatment + ตำแหน่ง (เพื่อ Auto วาป)
        addLine("===== ITEM/MEDICINE PROMPTS + ตำแหน่ง =====", C.Y)
        local cnt = 0
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and cnt < 50 then
                local act = tostring(p.ActionText)
                local low = act:lower()
                -- ข้าม door/treatment-step ที่รู้แล้ว เอาเฉพาะของที่อาจเป็น "ยา/ไอเทม"
                if not (low:find("open") or low:find("treatment") or low:find("analyze")
                        or low:find("process") or low:find("talk") or low:find("dna")
                        or low:find("stamp") or low:find("photo") or low:find("register")
                        or low:find("badge")) then
                    cnt += 1
                    local par = p.Parent
                    local pos = "?"
                    pcall(function()
                        local b = par:IsA("BasePart") and par or par:FindFirstChildWhichIsA("BasePart", true)
                        if b then pos = tostring(b.Position) end
                    end)
                    addLine(("ITEM act='%s' obj='%s'"):format(act, par and par.Name or "?"), C.G)
                    addLine(("   path=%s"):format(p:GetFullName()), C.S)
                    addLine(("   pos=%s"):format(pos), C.B)
                end
            end
        end
        addLine(("(item prompts = %d)"):format(cnt), C.S)
    end)
    if not ok then addLine("SCAN ERROR: " .. tostring(err), C.R) end
    addLine("", C.S)
    addLine(">> วินิจฉัยผู้ป่วยให้จอโชว์ไอคอนยา → กด RESCAN → Copy", C.Y)
    titleLbl.Text = "MedSpy v3 — done (กด Copy / RESCAN)"
end

rescanBtn.MouseButton1Click:Connect(function()
    titleLbl.Text = "MedSpy v2 — rescanning..."
    task.spawn(runScan)
end)
task.spawn(runScan)
