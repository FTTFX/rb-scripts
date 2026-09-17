-- Egg01_PlaceSpy.lua v1.1 — ดักตอนวางไข่จากมือ (Prompt + RF + GUI ปุ่ม)
-- v1.1: HIDE ไม่บังปุ่มเกม + ดักคลิก GuiButton + ปุ่ม DUMPUI หาปุ่มวาง/ทิ้ง
-- วิธีใช้: ถือไข่ → กด HIDE → กดปุ่มวางของเกม → กด SHOW → COPY
if _G.EGG01PS_GUI then pcall(function() _G.EGG01PS_GUI:Destroy() end) end
if _G.EGG01PS_CONNS then
    for _, c in pairs(_G.EGG01PS_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.EGG01PS_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local OUT, T0 = {}, os.clock()
local PAUSED = false
local HIDDEN = false
local MAXLINES = 500

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01PlaceSpy"; gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01PS_GUI = gui

-- แถบปุ่มมุมบนขวา — ไม่บังกลางจอ (ปุ่มวางไข่อยู่กลาง)
local bar = Instance.new("Frame", gui)
bar.Name = "Bar"
bar.Size = UDim2.new(0, 420, 0, 34)
bar.Position = UDim2.new(1, -428, 0, 8)
bar.BackgroundColor3 = Color3.fromRGB(20, 30, 20)
bar.BackgroundTransparency = 0.2
bar.BorderSizePixel = 0

local box = Instance.new("TextBox", gui)
box.Name = "Log"
box.Size = UDim2.new(0, 520, 0, 220)
box.Position = UDim2.new(0, 8, 1, -228) -- มุมล่างซ้าย
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(200, 255, 210)
box.TextSize = 11
box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true
box.MultiLine = true
box.ClearTextOnFocus = false
box.TextEditable = false
box.Active = false -- คลิกทะลุได้มากขึ้น (บาง executor)

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    if PAUSED then return end
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > MAXLINES then table.remove(OUT, 1) end
    if not HIDDEN then redraw() end
end
_G.EGG01PS_LOG = L

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", bar)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, 3)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    return b
end
local nearB  = hbtn("NEAR", 4, 52, Color3.fromRGB(40, 130, 70))
local dumpB  = hbtn("UI", 58, 40, Color3.fromRGB(60, 100, 140))
local clearB = hbtn("CLR", 100, 40, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 142, 52)
local pauseB = hbtn("PAUSE", 196, 56, Color3.fromRGB(90, 90, 40))
local hideB  = hbtn("HIDE", 254, 56, Color3.fromRGB(120, 50, 120))
local closeB = hbtn("✕", 312, 28, Color3.fromRGB(150, 40, 40))
bar.Size = UDim2.new(0, 348, 0, 34)
bar.Position = UDim2.new(1, -356, 0, 8)

local KW = {
    "egg", "place", "hatch", "pen", "nest", "drop", "carry", "home",
    "homestead", "finish", "slot", "plot", "deposit", "put", "lay",
    "unplace", "discard", "trash", "throw", "release",
}

local function interesting(name)
    local n = tostring(name):lower()
    for _, k in ipairs(KW) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then
        local ok, full = pcall(function() return v:GetFullName() end)
        return "<" .. v.ClassName .. ":" .. (ok and full:gsub("^Workspace%.", "WS."):gsub("^ReplicatedStorage%.", "RS."):gsub("^Players%..-%.PlayerGui%.", "PG.") or v.Name) .. ">"
    elseif t == "table" then
        if depth > 3 then return "{...}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n += 1
            if n > 14 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. ser(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "string" then
        return '"' .. (v:len() > 80 and v:sub(1, 80) .. "…" or v) .. '"'
    elseif t == "Vector3" then
        return ("V3(%.1f,%.1f,%.1f)"):format(v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        return ("CF(%.1f,%.1f,%.1f)"):format(v.X, v.Y, v.Z)
    end
    return tostring(v)
end

local function short(inst)
    local ok, full = pcall(function() return inst:GetFullName() end)
    if not ok then return "?" end
    return full:gsub("^ReplicatedStorage%.", "RS."):gsub("^Workspace%.", "WS.")
        :gsub("^Players%.[^%.]+%.PlayerGui%.", "PG.")
end

local function hrp()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end

local function setHidden(h)
    HIDDEN = h
    box.Visible = not h
    hideB.Text = h and "SHOW" or "HIDE"
    hideB.BackgroundColor3 = h and Color3.fromRGB(40, 130, 70) or Color3.fromRGB(120, 50, 120)
    if not h then redraw() end
    L(h and "ซ่อน log แล้ว — กดปุ่มวางของเกมได้" or "โชว์ log")
end

-- ลิสต์ prompt ใกล้ตัว
local function listNear(radius)
    radius = radius or 60
    local r = hrp()
    if not r then L("❌ ไม่มี HRP") return end
    L(("=== Prompt รัศมี %d @ %.0f,%.0f,%.0f ==="):format(radius, r.Position.X, r.Position.Y, r.Position.Z))
    local list = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local p = d.Parent
            local part = p and (p:IsA("BasePart") and p or p:FindFirstChildWhichIsA("BasePart", true))
            if part then
                local dist = (part.Position - r.Position).Magnitude
                if dist <= radius then
                    list[#list + 1] = { pp = d, dist = dist }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    if #list == 0 then L("  (ว่าง)") end
    for i, it in ipairs(list) do
        if i > 25 then L("  ...") break end
        local pp = it.pp
        local star = interesting(pp.ActionText) or interesting(short(pp))
        L(("%s%2d d=%.0f act='%s' hold=%.2f @ %s"):format(
            star and "★ " or "  ", i, it.dist, tostring(pp.ActionText), pp.HoldDuration, short(pp)))
    end
end

local function dumpHeld()
    local char = LP.Character
    if not char then return end
    L("--- ถือ/ในตัว ---")
    local tool = char:FindFirstChildOfClass("Tool")
    L("  Equipped=" .. (tool and tool.Name or "nil"))
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then
            local attrs = {}
            for ak, av in pairs(t:GetAttributes()) do
                attrs[#attrs + 1] = ak .. "=" .. tostring(av)
                if #attrs >= 6 then break end
            end
            L(("  Tool:%s {%s}"):format(t.Name, table.concat(attrs, ",")))
        end
    end
end

-- DUMP UI ที่มองเห็น — หาปุ่มวาง/ทิ้ง
local function dumpVisibleUI()
    L("=== DUMPUI ปุ่มที่ Visible ใน PlayerGui ===")
    local n = 0
    for _, d in ipairs(PG:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local vis = true
            local p = d.Parent
            while p and p ~= PG do
                if p:IsA("GuiObject") and not p.Visible then vis = false break end
                p = p.Parent
            end
            local abs = d.AbsoluteSize
            if vis and abs.X >= 8 and abs.Y >= 8 then
                n += 1
                if n <= 40 then
                    local star = interesting(d.Name) or interesting(short(d))
                        or (d:IsA("TextButton") and interesting(d.Text))
                    local txt = d:IsA("TextButton") and tostring(d.Text):sub(1, 40) or ""
                    local pos = d.AbsolutePosition
                    L(("%s%s '%s' txt='%s' pos=%.0f,%.0f size=%.0fx%.0f @ %s"):format(
                        star and "★ " or "  ", d.ClassName, d.Name, txt, pos.X, pos.Y, abs.X, abs.Y, short(d)))
                elseif n == 41 then
                    L("  ...cap 40")
                end
            end
        end
    end
    L("=== รวมปุ่ม Visible " .. n .. " ===")
end

-- Hook outbound
local function logRemote(self, method, ...)
    if PAUSED or not _G.EGG01PS_LOG then return end
    local full = ""
    pcall(function() full = short(self) end)
    if full:find("RobloxReplicatedStorage", 1, true) then return end
    if full:find("Analytics", 1, true) or full:find("ClientKit", 1, true) then return end
    if full:find("RVBillboard", 1, true) then return end
    local argc = select("#", ...)
    local parts = {}
    for i = 1, math.min(argc, 10) do parts[i] = ser(select(i, ...)) end
    local star = interesting(self.Name) or interesting(full)
    L(("%s[%s] %s(%s)"):format(star and "★ " or "", method, full, table.concat(parts, ", ")))
end

if not _G.EGG01PS_HOOKED then
    local mode = "none"
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
            mode = "hookfunction"
        end)
    end
    _G.EGG01PS_HOOKED = mode
end

-- ดักคลิกทุก GuiButton ใน PlayerGui
local hookedBtn = {}
local function hookBtn(btn)
    if hookedBtn[btn] then return end
    hookedBtn[btn] = true
    table.insert(_G.EGG01PS_CONNS, btn.Activated:Connect(function()
        if PAUSED then return end
        L(("🖱 GUI Activated '%s' @ %s"):format(btn.Name, short(btn)))
        if btn:IsA("TextButton") and btn.Text ~= "" then
            L("   text='" .. tostring(btn.Text):sub(1, 60) .. "'")
        end
        dumpHeld()
    end))
    if btn:IsA("GuiButton") then
        table.insert(_G.EGG01PS_CONNS, btn.MouseButton1Click:Connect(function()
            if PAUSED then return end
            -- ลดซ้ำกับ Activated — log เฉพาะชื่อน่าสนใจ
            if interesting(btn.Name) or interesting(short(btn)) then
                L(("🖱 Click ★ '%s' @ %s"):format(btn.Name, short(btn)))
            end
        end))
    end
end

local function scanHookButtons(root)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("GuiButton") then hookBtn(d) end
    end
end
scanHookButtons(PG)
table.insert(_G.EGG01PS_CONNS, PG.DescendantAdded:Connect(function(d)
    if d:IsA("GuiButton") then
        task.defer(hookBtn, d)
    end
end))

-- Prompt
table.insert(_G.EGG01PS_CONNS, PPS.PromptShown:Connect(function(pp)
    if PAUSED then return end
    L(("👁 Shown act='%s' hold=%.2f @ %s"):format(tostring(pp.ActionText), pp.HoldDuration, short(pp)))
end))
table.insert(_G.EGG01PS_CONNS, PPS.PromptTriggered:Connect(function(pp, plr)
    if plr ~= LP or PAUSED then return end
    L(("⚡ TRIGGER act='%s' hold=%.2f @ %s"):format(tostring(pp.ActionText), pp.HoldDuration, short(pp)))
    dumpHeld()
end))

-- RE ขากลับ
task.spawn(function()
    local net = RS:FindFirstChild("Packages")
    net = net and net:FindFirstChild("Networking")
    if not net then L("⚠ ไม่เจอ Networking") return end
    local n = 0
    for _, d in ipairs(net:GetDescendants()) do
        if d:IsA("RemoteEvent") then
            local path = short(d)
            if interesting(path) or path:find("EggWorld") or path:find("Homestead") or path:find("PenRoster") then
                n += 1
                table.insert(_G.EGG01PS_CONNS, d.OnClientEvent:Connect(function(...)
                    if PAUSED then return end
                    local argc = select("#", ...)
                    local parts = {}
                    for i = 1, math.min(argc, 8) do parts[i] = ser(select(i, ...)) end
                    L(("← %s(%s)"):format(d.Name, table.concat(parts, ", ")))
                end))
            end
        end
    end
    L("ฟัง RE ขากลับ " .. n .. " ตัว + GUI click")
end)

nearB.MouseButton1Click:Connect(function() listNear(80); dumpHeld() end)
dumpB.MouseButton1Click:Connect(dumpVisibleUI)
clearB.MouseButton1Click:Connect(function() OUT = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = ("=== Egg01 PlaceSpy ===\nTime: %s\nPlaceId: %s\nHook: %s\n\n%s")
        :format(os.date("%Y-%m-%d %H:%M:%S"), tostring(game.PlaceId),
            tostring(_G.EGG01PS_HOOKED), table.concat(OUT, "\n"))
    local clip = setclipboard or toclipboard
    local ok = clip and pcall(clip, text)
    pcall(function() if writefile then writefile("Egg01_place_log.txt", text) end end)
    copyB.Text = ok and "OK!" or "?"
    task.delay(1.2, function() if copyB.Parent then copyB.Text = "COPY" end end)
end)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
end)
hideB.MouseButton1Click:Connect(function() setHidden(not HIDDEN) end)
closeB.MouseButton1Click:Connect(function()
    _G.EGG01PS_LOG = nil
    if _G.EGG01PS_CONNS then
        for _, c in pairs(_G.EGG01PS_CONNS) do pcall(function() c:Disconnect() end) end
        _G.EGG01PS_CONNS = {}
    end
    gui:Destroy(); _G.EGG01PS_GUI = nil
end)

L("Egg01 PlaceSpy v1.1 | hook=" .. tostring(_G.EGG01PS_HOOKED or "?"))
L("→ กด HIDE ก่อน → กดปุ่มวาง(กลางจอ) → SHOW → COPY")
L("หรือกด UI เพื่อลิสต์ปุ่ม Visible ที่อาจเป็น Place/Drop")
-- เริ่มซ่อน log อัตโนมัติ ไม่บังปุ่มกลาง
setHidden(true)
