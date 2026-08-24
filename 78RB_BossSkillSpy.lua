-- 78RB_BossSkillSpy.lua v1.0 — ดักสกิลใหม่ของบอส (เกม "ยิงเป็ด" 78) ล่วงหน้า
-- ไม่ต้องรอโดนสกิลจริง แค่บอสโหลด/เล่นแอนิเมชั่นก็ดักได้ (hook LoadAnimation)
-- + สแกนลึกในโมเดลบอสหา Attachment/Particle/Sound/Highlight ที่มีคำใบ้สกิล
-- + สแกน Remote ใหม่ทั้งเกมที่ยังไม่รู้จัก
-- วิธีใช้: รันตอนมีบอสในด่าน (หรือรอจนบอสโผล่) → ปล่อยทิ้งไว้ → กด 📋 ก๊อปผล
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
ttl.Text = "🕵️ BossSkillSpy — ดักสกิลใหม่บอส"

local scanB = Instance.new("TextButton", fr)
scanB.Size = UDim2.new(0, 60, 0, 24); scanB.Position = UDim2.new(1, -138, 0, 5)
scanB.Text = "🔎 สแกน"; scanB.Font = Enum.Font.GothamBold; scanB.TextSize = 11
scanB.BackgroundColor3 = Color3.fromRGB(60, 100, 150); scanB.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", scanB).CornerRadius = UDim.new(0, 5)

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
    if #out > 400 then table.remove(out, 1) end
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

-- ==================== คำใบ้ที่จะหา ====================
local HINT_WORDS = {
    "peck", "dive", "rain", "warn", "telegraph", "shadow", "skill", "attack",
    "special", "ulti", "cast", "summon", "drop", "meteor", "smash", "slam",
    "impact", "storm", "wing", "swoop", "charge", "beam", "aoe", "circle",
    "danger", "indicator", "zone", "target",
}
local function hasHint(name)
    local ln = name:lower()
    for _, w in ipairs(HINT_WORDS) do
        if ln:find(w, 1, true) then return w end
    end
    return nil
end

-- รู้จักแล้ว (เกม 78) — remote พวกนี้ไม่ต้อง flag ซ้ำ
local KNOWN_REMOTES = {
    fire = true, shoot = true, reload = true, vote = true, buy = true,
    upgrade = true, equip = true,
}

-- ==================== ส่วน 1: hook LoadAnimation ====================
say("=== 1) ดักแอนิเมชั่นที่เล่นจริง (hook LoadAnimation) ===")
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
                        -- สนใจเฉพาะของบอส (กันสแปมท่าเดินเป็ดทั่วไป)
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

-- ==================== ส่วน 2: สแกนลึกในโมเดลบอส ====================
local function scanBossModels()
    say("")
    say("=== 2) สแกนลึกในโมเดลบอส (Attachment/Particle/Sound/Highlight ที่มีคำใบ้) ===")
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
                    say(("  🔸 [%s] %s  (คำใบ้:%s)"):format(d.ClassName, d:GetFullName():gsub("^.-BossController[^%.]*%.?", ""), hint))
                elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
                    say(("  ✨ Effect [%s] %s"):format(d.ClassName, d.Name))
                elseif d:IsA("Sound") then
                    say(("  🔊 Sound %s  id:%s"):format(d.Name, tostring(d.SoundId)))
                end
            end
        end
    end
    if not foundAny then say("⚠️ ยังไม่มีบอสในด่านตอนนี้ — รอบอสโผล่แล้วกด 🔎 สแกน อีกที") end
end

-- ==================== ส่วน 3: สแกน Remote ใหม่ที่ยังไม่รู้จัก ====================
local function scanRemotes()
    say("")
    say("=== 3) สแกน RemoteEvent/RemoteFunction ที่ยังไม่รู้จัก ===")
    local roots = { RS, workspace }
    local shown = {}
    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local ln = d.Name:lower()
                local known = false
                for k in pairs(KNOWN_REMOTES) do if ln:find(k) then known = true; break end end
                if not known and not shown[d] then
                    shown[d] = true
                    say(("  📡 [%s] %s"):format(d.ClassName, d:GetFullName()))
                end
            end
        end
    end
end

scanB.MouseButton1Click:Connect(function()
    scanBossModels()
    scanRemotes()
end)

-- สแกนอัตโนมัติครั้งแรกตอนโหลด (เผื่อบอสอยู่ในด่านอยู่แล้ว)
task.spawn(function()
    task.wait(1)
    if _G.BSS_GEN == GEN then
        scanBossModels()
        scanRemotes()
    end
end)

warn("[BossSkillSpy78] v1.0 loaded — ปล่อยทิ้งไว้จนบอสเล่นสกิล แล้วกด 📋 ก๊อปผลมาให้ดู")
