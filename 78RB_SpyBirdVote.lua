-- 78RB_SpyBirdVote.lua — สปาย "นกแดง(ตัวโจมตี)" + "นาฬิกานับถอยหลัง/โหวตเรียกบอส"
-- สร้างกล่องก่อน แล้วค่อยสแกน (error ก็ยังเห็นกล่อง) + ก๊อปลงคลิปบอร์ด
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

-- ===== สร้างกล่องบนหน้าจอก่อนเลย =====
pcall(function() local g = (gethui and gethui()) or game:GetService("CoreGui"); if g:FindFirstChild("SPYOUT") then g.SPYOUT:Destroy() end end)
pcall(function() if LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("SPYOUT") then LP.PlayerGui.SPYOUT:Destroy() end end)
local gui = Instance.new("ScreenGui"); gui.Name = "SPYOUT"; gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647; gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local fr = Instance.new("Frame", gui)
fr.Size = UDim2.new(0, 400, 0, 480); fr.Position = UDim2.new(0.5, -200, 0.5, -240)
fr.BackgroundColor3 = Color3.new(0,0,0); fr.BackgroundTransparency = 0.05
fr.Active = true; fr.Draggable = true
Instance.new("UICorner", fr).CornerRadius = UDim.new(0,8)
local st = Instance.new("UIStroke", fr); st.Color = Color3.fromRGB(255,80,80); st.Thickness = 3

local ttl = Instance.new("TextLabel", fr)
ttl.Size = UDim2.new(1,-40,0,26); ttl.Position = UDim2.new(0,6,0,4)
ttl.BackgroundTransparency = 1; ttl.TextColor3 = Color3.fromRGB(255,210,120)
ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 15; ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.Text = "🔍 SPY กำลังสแกน..."

local cls = Instance.new("TextButton", fr)
cls.Size = UDim2.new(0,28,0,24); cls.Position = UDim2.new(1,-32,0,5)
cls.Text = "✕"; cls.Font = Enum.Font.GothamBold; cls.TextSize = 15
cls.BackgroundColor3 = Color3.fromRGB(150,50,50); cls.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", cls).CornerRadius = UDim.new(0,5)
cls.MouseButton1Click:Connect(function() gui:Destroy() end)

local sc = Instance.new("ScrollingFrame", fr)
sc.Size = UDim2.new(1,-10,1,-60); sc.Position = UDim2.new(0,5,0,32)
sc.BackgroundColor3 = Color3.fromRGB(15,15,22); sc.BorderSizePixel = 0
sc.ScrollBarThickness = 8; sc.CanvasSize = UDim2.new(0,0,0,0)
sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", sc).CornerRadius = UDim.new(0,6)
local lbl = Instance.new("TextLabel", sc)
lbl.Size = UDim2.new(1,-8,0,0); lbl.Position = UDim2.new(0,4,0,4)
lbl.AutomaticSize = Enum.AutomaticSize.Y; lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Code; lbl.TextSize = 13; lbl.TextColor3 = Color3.fromRGB(150,255,180)
lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.TextWrapped = true; lbl.Text = "เริ่ม..."

local hint = Instance.new("TextLabel", fr)
hint.Size = UDim2.new(1,-10,0,20); hint.Position = UDim2.new(0,5,1,-24)
hint.BackgroundTransparency = 1; hint.TextColor3 = Color3.fromRGB(180,180,180)
hint.Font = Enum.Font.Code; hint.TextSize = 12; hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "ถ่ายรูปกล่องนี้ส่งมา / ก๊อปในคลิปบอร์ดแล้ว"

-- ===== สแกน (กัน error ทุกส่วน) =====
local out = {}
local function say(s) out[#out+1] = tostring(s); lbl.Text = table.concat(out, "\n") end

say("===== 1) โมเดลใน workspace.Ume =====")
pcall(function()
    local Ume = workspace:FindFirstChild("Ume")
    if not Ume then say("ไม่เจอ workspace.Ume"); return end
    local counts, first = {}, {}
    for _, m in ipairs(Ume:GetChildren()) do
        local key = m.Name:gsub("_?%d+$",""):gsub("_Client_.*","_Client")
        counts[key] = (counts[key] or 0) + 1
        if not first[key] then first[key] = m end
    end
    for k, v in pairs(counts) do
        local m = first[k]
        local part = m and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"))
        local col = "?"
        pcall(function() if part then col = tostring(part.Color) end end)
        say(("%s x%d | %s | สี=%s"):format(k, v, m and m.Name or "?", col))
    end
end)

say("")
say("===== 2) นาฬิกา/โหวต/บอส/นาที ใน PlayerGui =====")
pcall(function()
    local pg = LP:FindFirstChild("PlayerGui")
    local n = 0
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = d.Text or ""
                local low = t:lower()
                if t:find("%d+:%d%d") or low:find("vote") or low:find("boss") or t:find("โหวต")
                   or t:find("บอส") or t:find("นาที") or t:find("วันที่") or low:find("day")
                   or low:find("min") or low:find("timer") then
                    n = n + 1
                    local path = d:GetFullName()
                    path = path:gsub("^.-PlayerGui%.", "")
                    say(("[%s] %q\n   -> %s"):format(d.ClassName, t, path))
                end
            end
        end
    end
    if n == 0 then say("(ไม่เจอ — ลองรันตอนนาฬิกากำลังเดิน)") end
end)

say("")
say("===== 3) Remote โหวต/เรียกบอส/ข้ามวัน =====")
pcall(function()
    local n = 0
    local function scan(root, label)
        if not root then return end
        for _, r in ipairs(root:GetDescendants()) do
            if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                local ln = r.Name:lower()
                if ln:find("vote") or ln:find("boss") or ln:find("skip") or ln:find("call")
                   or ln:find("summon") or ln:find("day") or ln:find("round") or ln:find("night")
                   or ln:find("time") then
                    n = n + 1
                    say(("%s: %s (%s)"):format(label, r:GetFullName(), r.ClassName))
                end
            end
        end
    end
    scan(RS, "RS"); scan(workspace, "WS")
    if n == 0 then say("(ไม่เจอ remote)") end
end)

say(""); say("===== จบ =====")
ttl.Text = "🔍 SPY เสร็จ (ก๊อปแล้ว)"
pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
