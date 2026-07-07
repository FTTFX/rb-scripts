-- 74RB_GunTest.lua v1.0 — ทดสอบยิงผีด้วยปืน (วาปห่าง 8 → คลิกที่ตัวเป้าผ่าน VIM)
-- ปุ่ม: TARGETS ดูรายชื่อผี | SHOOT ยิงผีใกล้สุด 1 นัด | COPY | CLOSE
-- ผลที่ต้องดู: Charges ลดไหม / ผีตาย-หนีไหม / มีโทษไหม (Strikes/สุขภาพจิต)
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer
local cam = workspace.CurrentCamera

if _G.AH74GT_GUI then pcall(function() _G.AH74GT_GUI:Destroy() end) end

local function partPos(i)
    if not i then return nil end
    if i:IsA("BasePart") then return i.Position end
    local b = i:FindFirstChild("HumanoidRootPart") or i:FindFirstChildWhichIsA("BasePart", true)
    return b and b.Position
end
local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function gunTool()
    local bp = LP:FindFirstChild("Backpack")
    if LP.Character then
        local t = LP.Character:FindFirstChild("Gun")
        if t and t:IsA("Tool") then return t, true end
    end
    if bp then
        local t = bp:FindFirstChild("Gun")
        if t and t:IsA("Tool") then return t, false end
    end
end
-- ผีเป้าหมาย: Skinwalker/Anomaly ที่ไม่นอนเตียง (ผีเดิน/ผียืน)
local function ghosts()
    local out = {}
    local me = hrp() and hrp().Position
    local npcs = workspace:FindFirstChild("NPCs")
    if npcs and me then
        for _, m in ipairs(npcs:GetChildren()) do
            if m:IsA("Model") and (m:GetAttribute("Skinwalker") or m:GetAttribute("Anomaly"))
               and not m:GetAttribute("InBed") then
                local p = partPos(m)
                if p then out[#out+1] = { m = m, d = (p - me).Magnitude } end
            end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local LOG = {}
local function L(s) LOG[#LOG+1] = s; if #LOG > 30 then table.remove(LOG, 1) end end

local function shoot()
    local list = ghosts()
    local tgt = list[1]
    if not tgt then L("ไม่เจอผีเดิน/ยืน (Skinwalker/Anomaly นอกเตียง)"); return end
    local gun, equipped = gunTool()
    if not gun then L("ไม่มีปืนในมือ/กระเป๋า — ซื้อก่อน (Buy Gun)"); return end
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not equipped and h then pcall(function() h:EquipTool(gun) end); task.wait(0.2) end
    local ch0 = gun:GetAttribute("Charges")
    -- วาปเข้า 8 studs (velocity slide ไม่มีในตัวเทสต์ — ใช้ CFrame สั้นๆ ระวัง insanity: ทดสอบเท่านั้น)
    local r, gp = hrp(), partPos(tgt.m)
    if r and gp and tgt.d > 9 then
        local dir = (r.Position - gp).Unit
        r.CFrame = CFrame.new(gp + dir * 8 + Vector3.new(0, 1, 0))
        task.wait(0.15)
    end
    -- หันหน้า + คลิกที่ตัวผีบนจอ
    gp = partPos(tgt.m)
    if r and gp then
        pcall(function() r.CFrame = CFrame.lookAt(r.Position, Vector3.new(gp.X, r.Position.Y, gp.Z)) end)
        task.wait(0.1)
    end
    local sp, vis = cam:WorldToViewportPoint(gp)
    if not vis then L("เป้าไม่อยู่ในจอ — ลองใหม่"); return end
    pcall(function() gun:Activate() end)   -- เผื่อ tool ใช้ Activate
    VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, false, game, 0)
    task.wait(0.4)
    local ch1 = gun and gun.Parent and gun:GetAttribute("Charges")
    L(("ยิง %s (%.0f studs) Charges %s → %s | ผียัง%sอยู่"):format(
        tgt.m.Name, tgt.d, tostring(ch0), tostring(ch1),
        tgt.m.Parent and "" or "ไม่"))
end

-- v2.3: หา remote ครั้งเดียวแล้วจำ (game:GetDescendants ทั้งเกม = ค้างนาน → ค้นแค่ RS)
local _re
local function findRE()
    if _re and _re.Parent then return _re end
    local RS = game:GetService("ReplicatedStorage")
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") and d.Name:find("PlayShootEffect") then _re = d; return d end
    end
end
-- v2.0: ยิงผ่าน remote RE/PlayShootEffect(จุดยิง, part หัวผี) — เล็งหัวเป๊ะ ไม่พลาด
local function shootRE()
    local list = ghosts()
    local tgt = list[1]
    if not tgt then L("ไม่เจอผี"); return end
    local re = findRE()
    if not re then L("!! หา PlayShootEffect ไม่เจอ"); return end
    local head = tgt.m:FindFirstChild("Head") or tgt.m:FindFirstChildWhichIsA("BasePart")
    if not head then L("!! หา Head ผีไม่เจอ"); return end
    -- v2.3: (1) หยิบปืนขึ้นมือก่อน (เงื่อนไข: ต้อง equip) (2) ยิงนัดเดียว (กินกระสุน 1 นัด)
    local gun, equipped = gunTool()
    if not gun then L("!! ไม่มีปืน"); return end
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not equipped and h then pcall(function() h:EquipTool(gun) end); task.wait(0.25) end
    local ch0 = gun:GetAttribute("Charges")
    local r = hrp()
    local muzzle = r and r.Position or head.Position
    pcall(function() re:FireServer(muzzle, head) end)
    task.wait(0.5)
    local ch1 = gun and gun.Parent and gun:GetAttribute("Charges")
    L(("[RE] ยิง 1 นัด %s | Charges %s→%s | ผี%s"):format(
        tgt.m.Name, tostring(ch0), tostring(ch1),
        tgt.m.Parent and "ยังอยู่" or "ตาย! ✅"))
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AH74GT", false, 10000
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
_G.AH74GT_GUI = gui
local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 340, 0, 260), UDim2.new(0.5, -170, 0.5, -130)
f.BackgroundColor3, f.Active, f.Draggable = Color3.fromRGB(15, 15, 20), true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
local box = Instance.new("TextBox", f)
box.Size, box.Position = UDim2.new(1, -12, 1, -50), UDim2.new(0, 6, 0, 6)
box.MultiLine, box.ClearTextOnFocus, box.TextEditable = true, false, false
box.TextWrapped, box.TextXAlignment, box.TextYAlignment = false, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
box.Font, box.TextSize = Enum.Font.Code, 11
box.BackgroundColor3, box.TextColor3 = Color3.fromRGB(25, 25, 32), Color3.fromRGB(200, 255, 200)
local function refresh()
    local t = { "=== GunTest v2.4 (equip+1นัด+เร็ว) ===" }
    for _, g in ipairs(ghosts()) do
        t[#t+1] = ("[ผี] %s ระยะ=%.0f"):format(g.m.Name, g.d)
    end
    t[#t+1] = "--- LOG ---"
    for _, s in ipairs(LOG) do t[#t+1] = s end
    box.Text = table.concat(t, "\n")
end
refresh()
local function mkbtn(txt, x, w, cb)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0, w, 0, 32), UDim2.new(0, x, 1, -40)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(50, 50, 70), Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
end
mkbtn("TARGETS", 6, 62, refresh)
mkbtn("SHOOT-คลิก", 72, 82, function() shoot(); refresh() end)
mkbtn("SHOOT-RE", 158, 78, function() shootRE(); refresh() end)
mkbtn("COPY", 240, 50, function() pcall(function() (setclipboard or toclipboard)(box.Text) end) end)
mkbtn("X", 294, 40, function() gui:Destroy(); _G.AH74GT_GUI = nil end)
print("[74RB GunTest v2.0] พร้อม — กด SHOOT-RE ยิงผ่าน remote (เล็งหัวเป๊ะ)")
