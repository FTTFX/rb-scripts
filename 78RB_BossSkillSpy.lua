-- 78RB_BossSkillSpy.lua v1.1 — ดักสกิลใหม่ของบอส (เกม "ยิงเป็ด" 78) ล่วงหน้า
-- v1.1: เลิกดัมพ์รายชื่อ Remote นิ่งๆ (ชื่อสุ่ม GUID ไม่มีประโยชน์) → ดักตอนยิงจริงแทน
--   ฟัง OnClientEvent ทุก Remote, นับความถี่, โชว์เฉพาะตัว "ยิงไม่บ่อย" (น่าสงสัยว่าเป็นสกิล/อีเวนต์พิเศษ)
--   + แก้บั๊กคำใบ้ (เดิม substring เพี้ยน เช่น WeldConstraint แมตช์ "rain" เพราะ st-RAIN-t)
if _G.BSS_GUI then pcall(function() _G.BSS_GUI:Destroy() end) end
_G.BSS_GEN = (_G.BSS_GEN or 0) + 1
local GEN = _G.BSS_GEN

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "BossSkillSpy78"; gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647; gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.BSS_GUI = gui

local fr = Instance.new("Frame", gui)
fr.Size = UDim2.new(0, 460, 0, 440); fr.Position = UDim2.new(0.5, -230, 0.5, -220)
fr.BackgroundColor3 = Color3.new(0, 0, 0); fr.BackgroundTransparency = 0.05
fr.Active = true; fr.Draggable = true
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", fr); stk.Color = Color3.fromRGB(180, 60, 220); stk.Thickness = 3

local ttl = Instance.new("TextLabel", fr)
ttl.Size = UDim2.new(1, -80, 0, 26); ttl.Position = UDim2.new(0, 6, 0, 4)
ttl.BackgroundTransparency = 1; ttl.TextColor3 = Color3.fromRGB(230, 170, 255)
ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 13
ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.Text = "🕵️ BossSkillSpy v1.1"

local rareB = Instance.new("TextButton", fr)
rareB.Size = UDim2.new(0, 90, 0, 24); rareB.Position = UDim2.new(1, -168, 0, 5)
rareB.Text = "📊 รายงาน"; rareB.Font = Enum.Font.GothamBold; rareB.TextSize = 11
rareB.BackgroundColor3 = Color3.fromRGB(60, 100, 150); rareB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", rareB).CornerRadius = UDim.new(0, 5)

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
scf.BackgroundColor3 = Color3.fromRGB(20, 14, 24); scf.BorderSizePixel = 0; scf.ScrollBarThickness = 8
scf.CanvasSize = UDim2.new(0, 0, 0, 0); scf.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scf).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel", scf)
lbl.Size = UDim2.new(1, -8, 0, 0); lbl.Position = UDim2.new(0, 4, 0, 4)
lbl.AutomaticSize = Enum.AutomaticSize.Y; lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Code; lbl.TextSize = 11; lbl.TextColor3 = Color3.fromRGB(230, 210, 255)
lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.TextWrapped = true; lbl.Text = "รอ...\n"
local out = {}
local seen = {} -- กันซ้ำ (key -> true)
local function say(s)
    out[#out + 1] = tostring(s)
    if #out > 500 then table.remove(out, 1) end
    lbl.Text = table.concat(out, "\n")
end
local function sayOnce(key, s)
    if seen[key] then return end
    seen[key] = true
    say(s)
end
cpy.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
end)
cls.MouseButton1Click:Connect(function()
    _G.BSS_GEN = _G.BSS_GEN + 1; gui:Destroy(); _G.BSS_GUI = nil
end)

-- ==================== คำใบ้ที่จะหา (เช็คทั้งคำ ไม่ใช่ substring) ====================
local HINT_WORDS = {
    "peck", "dive", "rain", "warn", "telegraph", "shadow", "skill", "attack",
    "special", "ulti", "cast", "summon", "drop", "meteor", "smash", "slam",
    "impact", "storm", "swoop", "charge", "danger", "indicator", "zone", "target",
}
-- แยกชื่อเป็นคำๆ ตาม PascalCase/underscore/ตัวเลข แล้วเทียบทั้งคำเท่านั้น (กัน false positive เช่น WeldConstraint~=rain)
local function splitWords(name)
    local words = {}
    for w in name:gmatch("%u?%l+") do words[#words + 1] = w:lower() end
    for w in name:gmatch("%u%u+") do words[#words + 1] = w:lower() end
    return words
end
local function hasHint(name)
    local words = splitWords(name)
    for _, w in ipairs(words) do
        for _, hw in ipairs(HINT_WORDS) do
            if w == hw then return hw end
        end
    end
    return nil
end

-- ==================== ส่วน 1: hook LoadAnimation/Play ====================
say("=== 1) ดักแอนิเมชั่นที่เล่นจริง (hook LoadAnimation/Play) ===")
local hookOK = pcall(function()
    if not (hookmetamethod and getnamecallmethod) then error("no hook") end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if _G.BSS_GEN == GEN then
            local method = getnamecallmethod()
            if method == "LoadAnimation" or method == "Play" then
                local a1 = ...
                pcall(function()
                    if method == "LoadAnimation" and typeof(self) == "Instance"
                        and (self:IsA("Animator") or self:IsA("Humanoid") or self:IsA("AnimationController")) then
                        local animId = (typeof(a1) == "Instance" and a1:IsA("Animation")) and a1.AnimationId or "?"
                        local ownerModel = self:FindFirstAncestorOfClass("Model")
                        local ownerName = ownerModel and ownerModel.Name or self:GetFullName()
                        local key = ownerName .. "|" .. animId
                        sayOnce(key, ("🎬 LoadAnimation | เจ้าของ:%s | id:%s"):format(ownerName, animId))
                    elseif method == "Play" and typeof(self) == "Instance" and self:IsA("AnimationTrack") then
                        local anim = self.Animation
                        local animId = anim and anim.AnimationId or "?"
                        local ownerModel = self:FindFirstAncestorOfClass("Model")
                        local ownerName = ownerModel and ownerModel.Name or "?"
                        if ownerName:find("Boss") or ownerName:find("boss") then
                            local key = "PLAY|" .. ownerName .. "|" .. animId
                            sayOnce(key, ("▶️ Play (บอส) | %s | id:%s"):format(ownerName, animId))
                        end
                    end
                end)
            end
        end
        return old(self, ...)
    end)
end)
if not hookOK then say("❌ hook ไม่ติด (executor ไม่รองรับ)") end

-- ==================== ส่วน 2: สแกนลึกในโมเดลบอส (แก้บั๊กคำใบ้แล้ว) ====================
local function scanBossModels()
    say("")
    say("=== 2) สแกนลึกในโมเดลบอส (คำใบ้แบบทั้งคำ) ===")
    local f = workspace:FindFirstChild("Ume")
    if not f then say("⚠️ ไม่เจอ workspace.Ume"); return end
    local foundAny = false
    for _, m in ipairs(f:GetChildren()) do
        if m:IsA("Model") and m.Name:find("BossController") then
            foundAny = true
            say(("--- บอส: %s ---"):format(m.Name))
            for _, d in ipairs(m:GetDescendants()) do
                local hint = hasHint(d.Name)
                if hint then
                    say(("  🔸 [%s] %s  (คำใบ้:%s)"):format(d.ClassName, d.Name, hint))
                end
            end
        end
    end
    if not foundAny then say("⚠️ ยังไม่มีบอสในด่านตอนนี้") end
end

-- ==================== ส่วน 3: ดักตอน Remote ยิงจริง (ไม่ดัมพ์นิ่งๆ) ====================
-- ฟัง OnClientEvent ของทุก RemoteEvent ที่เจอ, นับความถี่ + เก็บ arg ตัวอย่างล่าสุด
-- ตัวที่ "ยิงไม่บ่อย" (นานๆครั้ง) ระหว่างเล่น = น่าสงสัยว่าเป็นสกิล/อีเวนต์พิเศษ (ต่างจากตัว sync ตำแหน่งที่ยิงรัวทุกเฟรม)
local remoteStat = {} -- [remote] = {count=n, lastArgs="...", firstT=os.clock()}
local hookedRemotes = {}
local function fmtArgs(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        local s
        if typeof(v) == "Instance" then s = "Inst:" .. v.Name
        elseif typeof(v) == "Vector3" then s = ("Vec3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
        elseif typeof(v) == "table" then s = "table"
        else s = tostring(v) end
        parts[#parts + 1] = s
        if i >= 5 then parts[#parts + 1] = "..."; break end
    end
    return table.concat(parts, ", ")
end
local function hookRemote(rem)
    if hookedRemotes[rem] then return end
    hookedRemotes[rem] = true
    remoteStat[rem] = { count = 0, lastArgs = "", firstT = os.clock() }
    pcall(function()
        rem.OnClientEvent:Connect(function(...)
            if _G.BSS_GEN ~= GEN then return end
            local st = remoteStat[rem]
            st.count = st.count + 1
            st.lastArgs = fmtArgs(...)
            st.lastT = os.clock()
        end)
    end)
end
local function scanAndHookRemotes()
    local roots = { RS, workspace }
    local n = 0
    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") then hookRemote(d); n = n + 1 end
        end
    end
    say(("(ติดตั้ง hook OnClientEvent กับ %d remote — ปล่อยเล่นไปเรื่อยๆ แล้วกด 📊 รายงาน)"):format(n))
end

local function report()
    say("")
    say(("=== 3) รายงาน Remote ที่ยิง 'ไม่บ่อย' (นานๆครั้ง = น่าสงสัยว่าเป็นสกิล) เวลา %.0f วิ ==="):format(os.clock()))
    local list = {}
    for rem, st in pairs(remoteStat) do
        if st.count > 0 then list[#list + 1] = { rem = rem, st = st } end
    end
    table.sort(list, function(a, b) return a.st.count < b.st.count end)
    local shown = 0
    for _, e in ipairs(list) do
        if e.st.count <= 30 then -- ตัดตัวที่ยิงรัว (sync ตำแหน่ง ฯลฯ) ออก โชว์แค่ตัวนานๆครั้ง
            shown = shown + 1
            if shown > 40 then break end
            say(("  📡 x%d | %s | args:[%s]"):format(e.st.count, e.rem:GetFullName(), e.st.lastArgs))
        end
    end
    if shown == 0 then say("  (ยังไม่มี remote ที่เข้าเกณฑ์ — เล่นต่อแล้วกดรายงานใหม่)") end
end
rareB.MouseButton1Click:Connect(report)

task.spawn(function()
    task.wait(1)
    if _G.BSS_GEN == GEN then
        scanBossModels()
        scanAndHookRemotes()
    end
end)

warn("[BossSkillSpy78] v1.1 loaded — เล่นไปเรื่อยๆ จนบอสใช้สกิล แล้วกด 📊 รายงาน + 📋 ก๊อป")
