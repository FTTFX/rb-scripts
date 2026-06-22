-- 74RB_AnimalHospital_HookSpy v5.1  (ดัก 3 ทาง: Remote + ProximityPrompt + Tool ; + ปุ่มล้าง/พับ)
-- เปิดในเกม → GUI ขึ้น → scan เสร็จ → ไป "ให้ยา/รักษา 1 ครั้ง + quest 1 อัน"
-- ให้ยาแบบไหนก็จับได้: [REMOTE]ชมพู / [PROMPT]ฟ้า / [TOOL]เหลือง → กด Copy ส่งมา

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
frame.ClipsDescendants = true   -- พับ = ซ่อนเนื้อใต้แถบหัว
frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -292, 0, 28); titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1; titleLbl.TextColor3 = Color3.fromRGB(120, 200, 255)
titleLbl.Text = "AnimalHospital Spy v3 — scanning..."
titleLbl.Font = Enum.Font.Code; titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.Parent = frame

local function topBtn(w, x, col, txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 22); b.Position = UDim2.new(1, x, 0, 3)
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1,1,1)
    b.Text = txt; b.Font = Enum.Font.Code; b.TextSize = 12
    b.BorderSizePixel = 0; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end
local copyBtn   = topBtn(62, -282, Color3.fromRGB(30, 100, 50), "Copy")
local rescanBtn = topBtn(72, -216, Color3.fromRGB(40, 70, 120), "RESCAN")
local clearBtn  = topBtn(50, -140, Color3.fromRGB(110, 90, 30), "ล้าง")
local minBtn    = topBtn(30, -86,  Color3.fromRGB(60, 60, 80),  "—")
local closeBtn  = topBtn(48, -52,  Color3.fromRGB(120, 20, 20), "ปิด")

-- พับ/กาง
local FULL_SZ = UDim2.new(0, 560, 0, 460)
local folded = false
minBtn.MouseButton1Click:Connect(function()
    folded = not folded
    frame.Size = folded and UDim2.new(0, 560, 0, 32) or FULL_SZ
    minBtn.Text = folded and "+" or "—"
end)

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
clearBtn.MouseButton1Click:Connect(function()   -- ล้าง log (เริ่มจับใหม่)
    for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines = {}; order = 0
end)
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

-- ── 4. SCAN (แยกเป็นฟังก์ชัน — RESCAN เรียกได้ ไม่แตะ hook) ──────
local function runScan()
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
end
rescanBtn.MouseButton1Click:Connect(function()   -- สแกนข้อมูลใหม่ (ล้าง+ดัมพ์ใหม่) ; hook ยังทำงานต่อ
    for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    copyLines = {}; order = 0
    titleLbl.Text = "Spy — rescanning..."
    task.spawn(runScan)
end)

-- ── 5. ครั้งแรก: scan + ตั้ง hook (hook ตั้งครั้งเดียว ไม่อยู่ใน runScan) ──────
task.spawn(function()
    task.wait(0.1)
    runScan()

    -- REMOTE HOOK v4 — ดักทั้ง dot-call (Net lib) + colon-call
    -- Net framework เรียก fs(remote,...) ไม่ใช่ remote:FireServer() → ต้อง hookfunction
    -- ที่ตัวฟังก์ชัน FireServer/InvokeServer โดยตรง (ดักได้ทุกแบบ) แทน __namecall
    addLine("", C.S)
    local remoteCount = 0
    local function logRemote(self, method, ...)
        if remoteCount >= 150 then return end
        local full = ""
        pcall(function() full = self:GetFullName() end)
        -- filter เสียงรบกวนของ Roblox internal — เอาเฉพาะ remote ของเกม
        if full:find("RobloxReplicatedStorage") then return end
        remoteCount += 1
        local args, n = {...}, select("#", ...)
        local parts = {}
        for i = 1, n do parts[i] = v2s(args[i]) end
        addLine(("[REMOTE] %s :%s(%s)"):format(self.Name, method,
            table.concat(parts, " | ")), C.M)
        addLine("   " .. full, C.S)
        titleLbl.Text = "AnimalHospital Spy v4 — REMOTE: " .. remoteCount
    end

    local hookMode = "none"
    -- วิธีที่ 1 (ดีสุด): hookfunction บน FireServer/InvokeServer — ดัก dot-call ได้
    if hookfunction then
        pcall(function()
            local wrap = newcclosure or function(f) return f end
            local re = Instance.new("RemoteEvent")
            local oldFS
            oldFS = hookfunction(re.FireServer, wrap(function(self, ...)
                logRemote(self, "FireServer", ...)
                return oldFS(self, ...)
            end))
            re:Destroy()
            local rf = Instance.new("RemoteFunction")
            local oldIS
            oldIS = hookfunction(rf.InvokeServer, wrap(function(self, ...)
                logRemote(self, "InvokeServer", ...)
                return oldIS(self, ...)
            end))
            rf:Destroy()
            hookMode = "hookfunction"
        end)
    end
    -- วิธีที่ 2 (สำรอง): __namecall — ดักได้แค่ colon-call
    if hookMode == "none" and hookmetamethod then
        pcall(function()
            local oldnc
            oldnc = hookmetamethod(game, "__namecall", function(self, ...)
                local m = getnamecallmethod and getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    logRemote(self, m, ...)
                end
                return oldnc(self, ...)
            end)
            hookMode = "namecall"
        end)
    end

    -- ── 6. ProximityPrompt capture (ให้ยาอาจเป็นการกด prompt) ──────────
    local promptCount = 0
    pcall(function()
        local PPS = game:GetService("ProximityPromptService")
        CONNS_SPY = CONNS_SPY or {}
        CONNS_SPY[#CONNS_SPY+1] = PPS.PromptTriggered:Connect(function(prompt, plr)
            if plr ~= LP or promptCount >= 60 then return end
            promptCount += 1
            local full = ""; pcall(function() full = prompt:GetFullName() end)
            addLine(("[PROMPT] act='%s' obj='%s'"):format(
                tostring(prompt.ActionText), tostring(prompt.Parent and prompt.Parent.Name)), C.B)
            addLine("   " .. full, C.S)
            titleLbl.Text = "Spy v5 — R:"..remoteCount.." P:"..promptCount
        end)
    end)

    -- ── 7. Tool capture (ยาอาจเป็น Tool ที่ equip/ใช้) ──────────────────
    local toolCount = 0
    local function watchTool(tool)
        if not tool:IsA("Tool") then return end
        tool.Activated:Connect(function()
            if toolCount >= 40 then return end
            toolCount += 1
            addLine(("[TOOL] activated '%s'"):format(tool.Name), C.O)
            titleLbl.Text = "Spy v5 — R:"..remoteCount.." P:"..promptCount.." T:"..toolCount
        end)
    end
    pcall(function()
        addLine("===== TOOLS (Backpack/Character) =====", C.Y)
        local bp = LP:FindFirstChild("Backpack")
        if bp then for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then addLine("  Tool: "..t.Name, C.G); watchTool(t) end
        end end
        if LP.Character then for _, t in ipairs(LP.Character:GetChildren()) do
            if t:IsA("Tool") then addLine("  Tool(equipped): "..t.Name, C.G); watchTool(t) end
        end end
        if bp then bp.ChildAdded:Connect(watchTool) end
        LP.CharacterAdded:Connect(function(c) c.ChildAdded:Connect(watchTool) end)
        if LP.Character then LP.Character.ChildAdded:Connect(watchTool) end
    end)

    addLine("", C.S)
    if hookMode ~= "none" then
        addLine((">> ดักครบ 3 ทาง (remote=%s) — ไป ให้ยา/รักษา 1 ครั้ง + quest 1 อัน"):format(hookMode), C.Y)
    else
        addLine(">> remote hook ไม่ได้ แต่ PROMPT+TOOL ยังดักได้ — ลองให้ยาดู", C.O)
    end
    addLine(">> อย่ารันซ้ำ! เล่นต่อ → ดูบรรทัด ชมพู/ฟ้า/เหลือง เด้ง → กด Copy", C.Y)
    addLine(">> หัวกล่องนับ R:remote P:prompt T:tool ให้เห็นว่าจับติด", C.G)
    titleLbl.Text = "Spy v5 — ready (ให้ยา → R/P/T จะนับ)"
end)
