-- 74RB_CameraSpy v1.0 — หากล้องวงจรปิดทั้งหมด + ตัวไหนเสีย + prompt ซ่อม
-- เปิดในเกม (ตอนมีกล้องเสียยิ่งดี) → กด RESCAN → Copy ส่งมา

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("AHCAMGUI"); if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = "AHCAMGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,660,0,500); frame.Position = UDim2.new(0.5,-330,0.5,-250)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-180,0,28); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "Camera Spy"; titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
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
    B=Color3.fromRGB(140,160,255), S=Color3.fromRGB(140,140,140), M=Color3.fromRGB(255,120,255),
    R=Color3.fromRGB(255,120,80) }
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

local function v3s(v) return ("%.1f, %.1f, %.1f"):format(v.X, v.Y, v.Z) end
local function partPos(inst)
    if not inst then return end
    if inst:IsA("BasePart") then return inst.Position end
    local b = inst:FindFirstChildWhichIsA("BasePart", true)
    if b then return b.Position end
    local a = inst:FindFirstAncestorWhichIsA("BasePart")
    return a and a.Position
end
local function attrs(inst)
    local out = {}
    for k, v in pairs(inst:GetAttributes()) do out[#out+1] = k .. "=" .. tostring(v) end
    return #out > 0 and table.concat(out, " ") or "-"
end

local function runScan()
    for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines = {}; order = 0
    pcall(function()
        local me = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        addLine("me @ " .. (me and v3s(me.Position) or "?"), C.S)

        -- 1) instance ชื่อมีคำว่า camera/cctv (Model/BasePart) — ตำแหน่ง + attributes + ลูกที่น่าสน
        addLine("=== instances ชื่อ camera/cctv ===", C.HEAD)
        local cams, seen = {}, {}
        for _, d in ipairs(workspace:GetDescendants()) do
            local n = d.Name:lower()
            if (n:find("camera") or n:find("cctv")) and (d:IsA("Model") or d:IsA("BasePart")) then
                -- เก็บเฉพาะตัวบนสุด (กัน part ลูกซ้ำ)
                local top = d
                while top.Parent and top.Parent ~= workspace do
                    local pn = top.Parent.Name:lower()
                    if pn:find("camera") or pn:find("cctv") then top = top.Parent else break end
                end
                if not seen[top] then
                    seen[top] = true; cams[#cams+1] = top
                end
            end
        end
        for i, m in ipairs(cams) do
            local pos = partPos(m)
            addLine(("[C%d] %s (%s)"):format(i, m:GetFullName(), m.ClassName), C.B)
            addLine(("     pos=%s | attr: %s"):format(pos and v3s(pos) or "?", attrs(m)), C.OK)
            -- ลูกที่บอกสถานะ (ParticleEmitter ไฟช็อต / Highlight / prompt)
            for _, c in ipairs(m:GetDescendants()) do
                if c:IsA("ProximityPrompt") then
                    addLine(("     PP: Action='%s' Object='%s' Enabled=%s Hold=%.1f"):format(
                        c.ActionText, c.ObjectText, tostring(c.Enabled), c.HoldDuration), C.M)
                elseif c:IsA("ParticleEmitter") or c:IsA("Sparkles") then
                    addLine(("     FX: %s '%s' Enabled=%s"):format(c.ClassName, c.Name, tostring(c.Enabled)), C.R)
                end
            end
        end
        if #cams == 0 then addLine("  (ไม่เจอ)", C.M) end

        -- 2) prompt ทั้งแมพที่ข้อความเกี่ยวกับซ่อม/กล้อง (เผื่อ prompt ไม่ได้อยู่ใต้ตัวกล้อง)
        addLine("", C.S); addLine("=== prompts fix/repair/camera ===", C.HEAD)
        local n2 = 0
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                local t = (p.ActionText .. " " .. p.ObjectText):lower()
                if t:find("fix") or t:find("repair") or t:find("camera") or t:find("ซ่อม") or t:find("กล้อง") then
                    n2 += 1
                    local pos = partPos(p.Parent)
                    addLine(("[P%d] Action='%s' Object='%s' Enabled=%s"):format(n2, p.ActionText, p.ObjectText, tostring(p.Enabled)), C.M)
                    addLine(("     @ %s | pos=%s"):format(p.Parent and p.Parent:GetFullName() or "?", pos and v3s(pos) or "?"), C.S)
                end
            end
        end
        if n2 == 0 then addLine("  (ไม่เจอ)", C.M) end
        addLine("", C.S)
        addLine(">> เปิดตอนมีกล้องเสีย แล้ว RESCAN — จะได้เทียบ attr/FX ตัวดี vs ตัวเสีย แล้ว Copy ส่งมา", C.OK)
    end)
    titleLbl.Text = "Camera Spy — done (กด Copy)"
end
reBtn.MouseButton1Click:Connect(function() task.spawn(runScan) end)
task.spawn(function() task.wait(0.1); runScan() end)
