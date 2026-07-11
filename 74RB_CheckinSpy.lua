-- 74RB_CheckinSpy v1.0 — วัดขอบเขต "ห้อง/โซนเช็คอิน" จริง
-- ใช้: 1) เปิด → เห็น part ของ CheckIn/CheckIn2 + NPC รอบๆ แบบสด
--      2) เดินไปยืน "มุมห้องเช็คอิน" แต่ละมุม แล้วกด MARK (4 มุม + จุดที่คนไข้ชอบไปหลบ)
--      3) กด Copy ส่งมา → จะได้กรอบห้องจริง ไว้ตัดคนไข้ที่หลบข้างในออกจากตัวนับ

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("AHCKGUI"); if old then old:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name = "AHCKGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,640,0,500); frame.Position = UDim2.new(0.5,-320,0.5,-250)
frame.BackgroundColor3 = Color3.fromRGB(12,12,18); frame.BorderSizePixel = 0
frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true; frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-250,0,28); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120,200,255)
titleLbl.Text = "CheckIn Spy"; titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame
local function topBtn(w,x,col,txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,w,0,22); b.Position = UDim2.new(1,x,0,3)
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1,1,1); b.Text = txt
    b.Font = Enum.Font.Code; b.TextSize = 12; b.BorderSizePixel = 0; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4); return b
end
local markBtn  = topBtn(60,-240,Color3.fromRGB(150,90,20),"MARK")
local copyBtn  = topBtn(62,-174,Color3.fromRGB(30,100,50),"Copy")
local reBtn    = topBtn(64,-108,Color3.fromRGB(40,70,120),"RESCAN")
local closeBtn = topBtn(28,-38,Color3.fromRGB(120,20,20),"X")
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
local function hrp()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end
local function partPos(inst)
    if not inst then return end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then local p = inst:FindFirstChildWhichIsA("BasePart", true) return p and p.Position end
end

-- MARK: จดพิกัดที่ยืนอยู่ (เดินไปมุมห้องแล้วกด)
local marks = {}
markBtn.MouseButton1Click:Connect(function()
    local r = hrp()
    if not r then return end
    marks[#marks+1] = r.Position
    addLine(("[MARK %d] %s"):format(#marks, v3s(r.Position)), C.HEAD)
    -- ครบ 2 จุดขึ้นไป โชว์กรอบ min/max ให้เลย
    if #marks >= 2 then
        local mn = Vector3.new(math.huge, math.huge, math.huge)
        local mx = -mn
        for _, p in ipairs(marks) do
            mn = Vector3.new(math.min(mn.X,p.X), math.min(mn.Y,p.Y), math.min(mn.Z,p.Z))
            mx = Vector3.new(math.max(mx.X,p.X), math.max(mx.Y,p.Y), math.max(mx.Z,p.Z))
        end
        addLine(("   กรอบจาก %d จุด: min=(%s) max=(%s)"):format(#marks, v3s(mn), v3s(mx)), C.OK)
    end
end)

local function runScan()
    pcall(function()
        local me = hrp()
        addLine("me @ " .. (me and v3s(me.Position) or "?"), C.S)
        -- 1) โครง CheckIn ทุกชิ้น (part + ขนาด) — หา part พื้น/กำแพงห้องจริง
        addLine("=== Misc.CheckIn* parts (name | pos | size) ===", C.HEAD)
        local misc = workspace:FindFirstChild("Misc")
        for _, nm in ipairs({"CheckIn", "CheckIn2", "Check-In", "CheckInRoom"}) do
            local ck = misc and misc:FindFirstChild(nm)
            if ck then
                addLine(("[%s] %s"):format(nm, ck.ClassName), C.B)
                local n = 0
                local function dump(inst, depth)
                    for _, c in ipairs(inst:GetChildren()) do
                        if c:IsA("BasePart") and n < 40 then
                            n += 1
                            addLine(("  %s%s | %s | size %s"):format(string.rep("  ", depth),
                                c.Name, v3s(c.Position), v3s(c.Size)), C.S)
                        end
                        if depth < 3 then dump(c, depth + 1) end
                    end
                end
                dump(ck, 0)
            end
        end
        -- 2) NPC ใกล้เคาน์เตอร์ (<40) — พิกัด + attr เช็คอิน (ดูว่าตัวไหน "หลบในห้อง" ระบบยังนับ)
        addLine("", C.S); addLine("=== NPC ใกล้ CheckIn (<40 studs) ===", C.HEAD)
        local ckpos = misc and partPos(misc:FindFirstChild("CheckIn"))
        local npcs = workspace:FindFirstChild("NPCs")
        if ckpos and npcs then
            for _, m in ipairs(npcs:GetChildren()) do
                local p = partPos(m)
                if p and (p - ckpos).Magnitude < 40 then
                    addLine(("  %s @ %s | d=%.1f | IsPatient=%s IsVisitor=%s CheckedIn=%s Completed=%s"):format(
                        m.Name, v3s(p), (p - ckpos).Magnitude,
                        tostring(m:GetAttribute("IsPatient")), tostring(m:GetAttribute("IsVisitor")),
                        tostring(m:GetAttribute("CheckedIn")), tostring(m:GetAttribute("CompletedCheckIn"))), C.M)
                end
            end
        end
        addLine("", C.S)
        addLine(">> เดินไปยืน 'มุมห้องเช็คอิน' ทีละมุม กด MARK (4 มุม + จุดที่คนไข้ชอบหลบ)", C.OK)
        addLine(">> เสร็จแล้วกด Copy ส่งมา", C.OK)
    end)
end
reBtn.MouseButton1Click:Connect(function() task.spawn(runScan) end)
task.spawn(function() task.wait(0.1); runScan() end)
