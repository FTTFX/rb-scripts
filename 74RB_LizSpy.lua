-- 74RB_LizSpy v1.1 — หาว่า quest กล้อง UV เก็บ "ชื่อเป้าที่ต้องถ่าย" ไว้ที่ไหน (v1.1 ไม่สแกน GUI ตัวเอง)
-- เปิดตอน quest กำลังสั่งถ่ายรูป (รู้ชื่อเป้าอยู่ เช่น Maggie Fin) → RESCAN → Copy ส่งมา
-- สแกน: attr ทุกตัวบน NPC/ผู้เล่น/UVCamera/Liz + StringValue + ป้ายข้อความบนจอ ที่มีชื่อ NPC ปนอยู่

local Players = game:GetService("Players")
local RepStore = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("AHLIZGUI"); if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = "AHLIZGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,660,0,500); frame.Position = UDim2.new(0.5,-330,0.5,-250)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-180,0,28); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "Liz Quest Spy"; titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame
local function topBtn(w,x,col,txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,w,0,22); b.Position = UDim2.new(1,x,0,3)
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1,1,1); b.Text = txt
    b.Font = Enum.Font.Code; b.TextSize = 12; b.BorderSizePixel = 0; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4); return b
end
local copyBtn  = topBtn(62,-172,Color3.fromRGB(30,100,50),"Copy")
local reBtn    = topBtn(64,-106,Color3.fromRGB(40,70,120),"RESCAN")
local closeBtn = topBtn(28,-36,Color3.fromRGB(120,20,20),"X")
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-8,1,-34); scroll.Position = UDim2.new(0,4,0,30)
scroll.BackgroundColor3 = Color3.fromRGB(8,8,14); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5; scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Parent = frame
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,4)
local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = scroll
local padL = Instance.new("UIPadding"); padL.PaddingLeft = UDim.new(0,6); padL.Parent = scroll
local copyLines, order = {}, 0
local C = { OK=Color3.fromRGB(80,255,120), HEAD=Color3.fromRGB(255,210,0),
    B=Color3.fromRGB(140,160,255), S=Color3.fromRGB(140,140,140), M=Color3.fromRGB(255,120,255) }
local function addLine(txt,col)
    order += 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-12,0,15); l.BackgroundTransparency = 1; l.Font = Enum.Font.Code
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextTruncate = Enum.TextTruncate.AtEnd
    l.TextColor3 = col or C.S; l.Text = txt; l.LayoutOrder = order; l.Parent = scroll
    table.insert(copyLines, txt)
end
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
copyBtn.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard or write_clipboard or (getgenv and getgenv().setclipboard)
    local ok = clip and pcall(clip, table.concat(copyLines, "\n"))
    copyBtn.Text = ok and "Copied!" or "ไม่รองรับ"
    task.delay(2, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
end)

local function runScan()
    for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines = {}; order = 0
    pcall(function()
        -- รายชื่อ NPC ทั้งหมด (ไว้จับ match ชื่อในค่าอื่นๆ)
        local names = {}
        local npcs = workspace:FindFirstChild("NPCs")
        if npcs then for _, m in ipairs(npcs:GetChildren()) do names[m.Name] = true end end

        -- 1) attr ทุกตัวบน: ผู้เล่นเรา + UVCamera + NPC ทุกตัว (โชว์เฉพาะตัวที่มี attr แปลก)
        addLine("=== attributes (LP / UVCamera / NPC) ===", C.HEAD)
        local function dumpAttr(tag, inst)
            if not inst then addLine(tag .. ": (ไม่เจอ)", C.S) return end
            local out = {}
            for k, v in pairs(inst:GetAttributes()) do out[#out+1] = k .. "=" .. tostring(v) end
            if #out > 0 then addLine(tag .. ": " .. table.concat(out, " | "), C.OK) end
        end
        dumpAttr("LP", LP)
        dumpAttr("Char", LP.Character)
        local misc = workspace:FindFirstChild("Misc")
        dumpAttr("UVCamera", misc and misc:FindFirstChild("UVCamera"))
        if npcs then for _, m in ipairs(npcs:GetChildren()) do dumpAttr("NPC " .. m.Name, m) end end

        -- 2) ValueBase ทั้งเกมที่ค่าเป็น "ชื่อ NPC" หรือชื่อมีคำว่า target/photo/liz/quest
        addLine("", C.S); addLine("=== Values ที่น่าจะเก็บเป้า (workspace+ReplicatedStorage+LP) ===", C.HEAD)
        local n = 0
        for _, root in ipairs({ workspace, RepStore, LP }) do
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("ValueBase") then
                    local nm = d.Name:lower()
                    local v = tostring(d.Value)
                    if names[v] or nm:find("target") or nm:find("photo") or nm:find("liz") or nm:find("quest") then
                        n += 1
                        addLine(("[V%d] %s = %s"):format(n, d:GetFullName(), v), C.M)
                    end
                end
            end
        end
        if n == 0 then addLine("  (ไม่เจอ)", C.S) end

        -- 3) ป้ายบนจอที่มีชื่อ NPC / คำว่า photo (กระดาษ quest ของ Liz)
        addLine("", C.S); addLine("=== ป้ายบนจอ (PlayerGui) ที่มีชื่อ NPC/photo ===", C.HEAD)
        local n2 = 0
        for _, d in ipairs(pg:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible
               and not d:IsDescendantOf(sg) then   -- v1.1: ห้ามสแกนหน้าต่างตัวเอง
                local t = d.Text
                local hit = t:lower():find("photo")
                if not hit then
                    for nm in pairs(names) do
                        if t:find(nm, 1, true) then hit = true break end
                    end
                end
                if hit then
                    n2 += 1
                    addLine(("[G%d] '%s'"):format(n2, t), C.M)
                    addLine("     @ " .. d:GetFullName(), C.S)
                end
            end
        end
        if n2 == 0 then addLine("  (ไม่เจอ)", C.S) end

        -- 4) ป้าย 3D ในโลก (BillboardGui/SurfaceGui) แถว UVCamera/Liz
        addLine("", C.S); addLine("=== ป้าย 3D แถวกล้อง (<25 studs) ===", C.HEAD)
        local uvp = misc and misc:FindFirstChild("UVCamera")
        uvp = uvp and uvp:FindFirstChildWhichIsA("BasePart", true)
        local n3 = 0
        if uvp then
            for _, d in ipairs(workspace:GetDescendants()) do
                if (d:IsA("TextLabel")) and d.Text ~= "" then
                    local a = d:FindFirstAncestorWhichIsA("BasePart")
                    if a and (a.Position - uvp.Position).Magnitude < 25 then
                        n3 += 1
                        addLine(("[W%d] '%s' @ %s"):format(n3, d.Text, d:GetFullName()), C.M)
                    end
                end
            end
        end
        if n3 == 0 then addLine("  (ไม่เจอ)", C.S) end
        addLine("", C.S)
        addLine(">> เปิดตอน quest สั่งถ่ายอยู่ (รู้ชื่อเป้า) → Copy ส่งมา + บอกชื่อเป้าที่ถูกต้อง", C.OK)
    end)
    titleLbl.Text = "Liz Quest Spy — done (กด Copy)"
end
reBtn.MouseButton1Click:Connect(function() task.spawn(runScan) end)
task.spawn(function() task.wait(0.1); runScan() end)
