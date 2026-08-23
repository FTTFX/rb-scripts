-- 79RB_LeafIdSpy.lua v1.0 — หาสูตร id ใบไม้ (ล้างบ้านขำๆ ภาค 2)
-- วิธีใช้: รันสคริปต์ → เดินเก็บใบด้วยมือ 5-10 ใบ → กด 📋 ก๊อปผลมาให้ดู
-- บันทึก: ตอนยิง CollectLeaf(id) + ใบไหนหายจาก WS.Leaves (ลำดับตอนสแนป/ตำแหน่ง/ระยะจากตัว)
--   → เอา id กับ "ลำดับใบตอนสแนป" มาเทียบกันหาสูตร
if _G.LIS79_GUI then pcall(function() _G.LIS79_GUI:Destroy() end) end
_G.LIS79_GEN = (_G.LIS79_GEN or 0) + 1
local GEN = _G.LIS79_GEN

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "LeafIdSpy79"; gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647; gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.LIS79_GUI = gui

local fr = Instance.new("Frame", gui)
fr.Size = UDim2.new(0, 430, 0, 420); fr.Position = UDim2.new(0.5, -215, 0.5, -210)
fr.BackgroundColor3 = Color3.new(0, 0, 0); fr.BackgroundTransparency = 0.05
fr.Active = true; fr.Draggable = true
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", fr); stk.Color = Color3.fromRGB(255, 160, 60); stk.Thickness = 3

local ttl = Instance.new("TextLabel", fr)
ttl.Size = UDim2.new(1, -80, 0, 26); ttl.Position = UDim2.new(0, 6, 0, 4)
ttl.BackgroundTransparency = 1; ttl.TextColor3 = Color3.fromRGB(255, 200, 120)
ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 13
ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.Text = "🔍 เดินเก็บใบด้วยมือ 5-10 ใบ!"

local cpy = Instance.new("TextButton", fr)
cpy.Size = UDim2.new(0, 34, 0, 24); cpy.Position = UDim2.new(1, -72, 0, 5)
cpy.Text = "📋"; cpy.Font = Enum.Font.GothamBold; cpy.TextSize = 13
cpy.BackgroundColor3 = Color3.fromRGB(40, 120, 70); cpy.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", cpy).CornerRadius = UDim.new(0, 5)
local cls = Instance.new("TextButton", fr)
cls.Size = UDim2.new(0, 28, 0, 24); cls.Position = UDim2.new(1, -34, 0, 5)
cls.Text = "✕"; cls.Font = Enum.Font.GothamBold; cls.TextSize = 15
cls.BackgroundColor3 = Color3.fromRGB(150, 50, 50); cls.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", cls).CornerRadius = UDim.new(0, 5)

local scf = Instance.new("ScrollingFrame", fr)
scf.Size = UDim2.new(1, -10, 1, -40); scf.Position = UDim2.new(0, 5, 0, 32)
scf.BackgroundColor3 = Color3.fromRGB(20, 14, 8); scf.BorderSizePixel = 0; scf.ScrollBarThickness = 8
scf.CanvasSize = UDim2.new(0, 0, 0, 0); scf.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scf).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel", scf)
lbl.Size = UDim2.new(1, -8, 0, 0); lbl.Position = UDim2.new(0, 4, 0, 4)
lbl.AutomaticSize = Enum.AutomaticSize.Y; lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Code; lbl.TextSize = 11; lbl.TextColor3 = Color3.fromRGB(255, 230, 180)
lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.TextWrapped = true; lbl.Text = "เริ่ม..."
local out = {}
local function say(s)
    out[#out + 1] = tostring(s)
    lbl.Text = table.concat(out, "\n")
end
cpy.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
end)
cls.MouseButton1Click:Connect(function()
    _G.LIS79_GEN = _G.LIS79_GEN + 1; gui:Destroy(); _G.LIS79_GUI = nil
end)

-- ==================== สแนปลำดับใบตอนเริ่ม ====================
-- leafIdx[instance] = ลำดับในโฟลเดอร์ตอนสแนป (ก่อนใบเริ่มหาย)
local leafIdx = {}
local snapCount = 0
do
    local lf = workspace:FindFirstChild("Leaves")
    if lf then
        for i, m in ipairs(lf:GetChildren()) do leafIdx[m] = i end
        snapCount = #lf:GetChildren()
    end
end
say(("สแนปใบตอนเริ่ม: %d ชิ้น"):format(snapCount))
say("id | ลำดับสแนป | ระยะจากตัว | ตำแหน่งใบ")
say("--------------------------------------")

-- ==================== ดัก CollectLeaf + ใบหาย ====================
local pendingFire = nil -- {id, t}
local hookOK = pcall(function()
    if not (hookmetamethod and getnamecallmethod) then error("no hook") end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if _G.LIS79_GEN == GEN then
            local a1 = ...
            pcall(function()
                if typeof(self) == "Instance" and self.Name == "CollectLeaf"
                    and getnamecallmethod() == "FireServer" and type(a1) == "number" then
                    pendingFire = { id = a1, t = os.clock() }
                end
            end)
        end
        return old(self, ...)
    end)
end)
if not hookOK then say("❌ hook ไม่ติด!") end

do
    local lf = workspace:FindFirstChild("Leaves")
    if lf then
        lf.ChildRemoved:Connect(function(m)
            if _G.LIS79_GEN ~= GEN then return end
            local idx = leafIdx[m] or -1
            local pos = "?"
            local dist = "?"
            pcall(function()
                if m:IsA("BasePart") then
                    pos = ("%.0f,%.0f,%.0f"):format(m.Position.X, m.Position.Y, m.Position.Z)
                    local c = LP.Character
                    local r = c and c:FindFirstChild("HumanoidRootPart")
                    if r then dist = ("%.1f"):format((m.Position - r.Position).Magnitude) end
                end
            end)
            local pf = pendingFire
            local id = "-"
            if pf and os.clock() - pf.t < 0.6 then id = tostring(pf.id) end
            say(("%s | %d | %s | %s"):format(id, idx, dist, pos))
        end)
    end
end

warn("[LeafIdSpy79] v1.0 loaded — เดินเก็บใบด้วยมือ 5-10 ใบ แล้วกด 📋")
