-- 74RB_AnimalHospital_HookSpy v3.0  (hookmetamethod — แบบเดียวกับ 69RB ที่รันได้)
-- เปิดในเกม → GUI ขึ้นบนจอ → scan เสร็จเอง
-- แล้วไป: เข้าใกล้ผี+คนดี / รักษาสัตว์ / ทำ quest → [REMOTE] สีชมพูเด้งสด
-- กด Copy → วาง log มาในแชต

local Players = game:GetService("Players")
local HS = game:GetService("HttpService")
local LP = Players.LocalPlayer
local pg = LP:WaitForChild("PlayerGui")

-- ── 1. Guard ────────────────────────────────────────────────────
local old = pg:FindFirstChild("AHSPYGUI")
if old then old:Destroy() end

-- ── 2. GUI (ลำดับ + idiom เดียวกับ 69RB ที่ทำงานได้) ────────────
local sg = Instance.new("ScreenGui")
sg.Name = "AHSPYGUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
sg.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 560, 0, 460)
frame.Position = UDim2.new(0.5, -280, 0.5, -230)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
frame.BorderSizePixel = 0; frame.Active = true; frame.Draggable = true
frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -185, 0, 28); titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120, 200, 255)
titleLbl.Text = "AnimalHospital Spy v3 — scanning..."
titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0, 110, 0, 22); copyBtn.Position = UDim2.new(1, -178, 0, 3)
copyBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 50); copyBtn.TextColor3 = Color3.new(1,1,1)
copyBtn.Text = "Copy"; copyBtn.Font = Enum.Font.Code; copyBtn.TextSize = 12
copyBtn.BorderSizePixel = 0; copyBtn.Parent = frame
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 60, 0, 22); closeBtn.Position = UDim2.new(1, -64, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20); closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Text = "ปิด"; closeBtn.Font = Enum.Font.Code; closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0; closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -8, 1, -34); scroll.Position = UDim2.new(0, 4, 0, 30)
scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 14); scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5; scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Parent = frame
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 4)
local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll
local padL = Instance.new("UIPadding"); padL.PaddingLeft = UDim.new(0, 6); padL.Parent = scroll

-- ── 3. Helper ───────────────────────────────────────────────────
local copyLines, order = {}, 0
local C = {
    Y = Color3.fromRGB(255,210,0),  G = Color3.fromRGB(80,255,120),
    B = Color3.fromRGB(140,160,255),O = Color3.fromRGB(255,160,50),
    W = Color3.fromRGB(210,210,210),S = Color3.fromRGB(140,140,140),
    R = Color3.fromRGB(255,80,80),  M = Color3.fromRGB(255,120,255),
}
local function addLine(txt, col)
    order += 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -12, 0, 15); l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left; l.TextTruncate = Enum.TextTruncate.AtEnd
    l.TextColor3 = col or C.W; l.Text = txt; l.LayoutOrder = order; l.Parent = scroll
    table.insert(copyLines, txt)
    scroll.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y) -- auto-scroll
end

closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
copyBtn.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard or write_clipboard
        or (getgenv and getgenv().setclipboard)
    local ok = clip and pcall(clip, table.concat(copyLines, "\n"))
    copyBtn.Text = ok and "Copied!" or "ไม่รองรับ"
    task.delay(2, function() if copyBtn.Parent then copyBtn.Text = "Copy" end end)
end)

local function v2s(v)
    local t = typeof(v)
    if t == "Instance" then return ("<%s:%s>"):format(v.ClassName, v:GetFullName())
    elseif t == "table" then
        local okk, j = pcall(HS.JSONEncode, HS, v); return okk and j or "<table>"
    else return ("<%s:%s>"):format(t, tostring(v)) end
end

-- ── 4. SCAN (task.spawn ไม่ block GUI) ──────────────────────────
task.spawn(function()
    task.wait(0.1)
    local ok, err = pcall(function()
        addLine("===== TEAMS =====", C.Y)
        for _, t in ipairs(game:GetService("Teams"):GetChildren()) do
            addLine(("  %s color=%s"):format(t.Name, tostring(t.TeamColor)), C.G)
        end
        addLine("  LocalPlayer.Team = " .. tostring(LP.Team), C.B)
        addLine("", C.S)

        addLine("===== PLAYERS =====", C.Y)
        for _, p in ipairs(Players:GetPlayers()) do
            local ak = {}
            for k, val in pairs(p:GetAttributes()) do ak[#ak+1] = k.."="..tostring(val) end
            addLine(("  %s team=%s {%s}"):format(p.Name, tostring(p.Team),
                table.concat(ak, ",")), C.W)
        end
        addLine("  -- LocalPlayer children --", C.S)
        for _, c in ipairs(LP:GetChildren()) do
            addLine(("    %s (%s)"):format(c.Name, c.ClassName), C.W)
        end
        addLine("", C.S)

        addLine("===== WORKSPACE TOP-LEVEL =====", C.Y)
        for _, c in ipairs(workspace:GetChildren()) do
            addLine(("  %s (%s)"):format(c.Name, c.ClassName), C.W)
        end
        addLine("", C.S)

        addLine("===== NPC SCAN (attrs+values) =====", C.Y)
        local playerNames = {}
        for _, p in ipairs(Players:GetPlayers()) do playerNames[p.Name] = true end
        local seen, MAX = 0, 30
        for _, d in ipairs(workspace:GetDescendants()) do
            if seen >= MAX then break end
            if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid")
               and not playerNames[d.Name] then
                local ak = {}
                for k, val in pairs(d:GetAttributes()) do ak[#ak+1] = k.."="..tostring(val) end
                local vals = {}
                for _, c in ipairs(d:GetDescendants()) do
                    if c:IsA("ValueBase") then
                        vals[#vals+1] = ("%s[%s]=%s"):format(c.Name, c.ClassName, tostring(c.Value))
                    end
                end
                seen += 1
                addLine("  NPC: " .. d.Name .. " @ " .. d:GetFullName(), C.G)
                if #ak > 0   then addLine("     attrs: " .. table.concat(ak, ", "), C.O) end
                if #vals > 0 then addLine("     vals:  " .. table.concat(vals, ", "), C.M) end
            end
        end
        addLine(("  (scanned %d NPC, cap=%d)"):format(seen, MAX), C.S)
        addLine("", C.S)

        addLine("===== REMOTES (max 60) =====", C.Y)
        local rc = 0
        for _, d in ipairs(game:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                rc += 1
                if rc <= 60 then addLine(("  %s (%s)"):format(d:GetFullName(), d.ClassName), C.B) end
            end
        end
        addLine(("  total remotes = %d"):format(rc), C.S)
    end)
    if not ok then addLine("SCAN ERROR: " .. tostring(err), C.R) end

    -- ── 5. REMOTE HOOK (หลัง scan + best-effort, ใช้ hookmetamethod แบบ 69RB) ──
    addLine("", C.S)
    local remoteCount, hookOK = 0, false
    if hookmetamethod then
        local okh = pcall(function()
            local oldnc
            oldnc = hookmetamethod(game, "__namecall", function(self, ...)
                local m = getnamecallmethod and getnamecallmethod()
                if (m == "FireServer" or m == "InvokeServer") and remoteCount < 120 then
                    remoteCount += 1
                    local args, n = {...}, select("#", ...)
                    local parts = {}
                    for i = 1, n do parts[i] = v2s(args[i]) end
                    addLine(("[REMOTE] %s :%s(%s)"):format(self.Name, m,
                        table.concat(parts, " | ")), C.M)
                    addLine("   path: " .. self:GetFullName(), C.S)
                end
                return oldnc(self, ...)
            end)
            hookOK = true
        end)
        if not okh then hookOK = false end
    end

    if hookOK then
        addLine(">> hook ติดแล้ว — ไป: เข้าใกล้ผี+คนดี / รักษาสัตว์ / ทำ quest", C.Y)
        addLine(">> [REMOTE] สีชมพูจะเด้ง แล้วกด Copy ส่งให้ผม", C.Y)
        titleLbl.Text = "AnimalHospital Spy v3 — ready (เล่นต่อ → ดู REMOTE)"
    else
        addLine(">> executor นี้ hook remote ไม่ได้ — แต่ข้อมูล scan ข้างบนใช้ได้", C.O)
        addLine(">> กด Copy ส่ง scan มาก่อน เดี๋ยวผมหาวิธี remote อื่น", C.O)
        titleLbl.Text = "AnimalHospital Spy v3 — scan done (no hook)"
    end
end)
