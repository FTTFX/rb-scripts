-- Egg01_PlaceSpy.lua v1.0 — ดักตอนวางไข่จากมือลงคอก/เส้นชัย
-- วิธีใช้: ถือไข่ → วิ่งกลับบ้าน → กดวางมือ 1 ครั้ง → COPY ส่งมา
-- ดัก: Prompt (Shown/Triggered) + FireServer/InvokeServer + RE EggWorld ขากลับ
if _G.EGG01PS_GUI then pcall(function() _G.EGG01PS_GUI:Destroy() end) end
if _G.EGG01PS_CONNS then
    for _, c in pairs(_G.EGG01PS_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.EGG01PS_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local OUT, T0 = {}, os.clock()
local PAUSED = false
local MAXLINES = 500

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01PlaceSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.EGG01PS_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 720, 0, 380); box.Position = UDim2.new(0, 8, 0.2, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.12
box.TextColor3 = Color3.fromRGB(200, 255, 210); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function redraw() box.Text = table.concat(OUT, "\n") end
local function L(s)
    if PAUSED then return end
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > MAXLINES then table.remove(OUT, 1) end
    redraw()
end
_G.EGG01PS_LOG = L

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.2, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local nearB  = hbtn("NEAR", 8, 70, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 84, 70, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 160, 70)
local pauseB = hbtn("PAUSE", 236, 74, Color3.fromRGB(90, 90, 40))
local closeB = hbtn("✕", 316, 34, Color3.fromRGB(150, 40, 40))

local KW = {
    "egg", "place", "hatch", "pen", "nest", "drop", "carry", "home",
    "homestead", "finish", "slot", "plot", "deposit", "put", "lay",
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
        return "<" .. v.ClassName .. ":" .. (ok and full:gsub("^Workspace%.", "WS."):gsub("^ReplicatedStorage%.", "RS.") or v.Name) .. ">"
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
end

local function hrp()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end

-- ลิสต์ prompt ใกล้ตัว (โฟกัสวาง/บ้าน)
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
                    list[#list + 1] = { pp = d, dist = dist, part = part }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    if #list == 0 then L("  (ว่าง)") return end
    for i, it in ipairs(list) do
        if i > 25 then L("  ...") break end
        local pp = it.pp
        local star = interesting(pp.ActionText) or interesting(pp.Parent and pp.Parent.Name) or interesting(short(pp))
        L(("%s%2d d=%.0f act='%s' hold=%.2f max=%d @ %s"):format(
            star and "★ " or "  ", i, it.dist, tostring(pp.ActionText),
            pp.HoldDuration, pp.MaxActivationDistance, short(pp)))
    end
    L("=== จบ NEAR (" .. #list .. ") — ถือไข่แล้วกดวางมือ ===")
end

-- ดูว่าถืออะไรอยู่
local function dumpHeld()
    local char = LP.Character
    if not char then L("ไม่มี Character") return end
    L("--- สิ่งที่ถือ/ในตัว ---")
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") or t:IsA("Model") or t:IsA("Folder") then
            local attrs = {}
            for ak, av in pairs(t:GetAttributes()) do
                attrs[#attrs + 1] = ak .. "=" .. tostring(av)
                if #attrs >= 8 then break end
            end
            L(("  %s:%s attrs={%s}"):format(t.ClassName, t.Name, table.concat(attrs, ",")))
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local tool = char:FindFirstChildOfClass("Tool")
        L("  Equipped=" .. (tool and tool.Name or "nil") .. " WalkSpeed=" .. tostring(hum.WalkSpeed))
    end
end

-- Hook outbound remotes
local function logRemote(self, method, ...)
    if PAUSED or not _G.EGG01PS_LOG then return end
    local full = ""
    pcall(function() full = short(self) end)
    if full:find("RobloxReplicatedStorage", 1, true) then return end
    if full:find("Analytics", 1, true) or full:find("ClientKit", 1, true) then return end
    if full:find("RVBillboard", 1, true) then return end
    local n = select("#", ...)
    local parts = {}
    for i = 1, math.min(n, 10) do parts[i] = ser(select(i, ...)) end
    local star = interesting(self.Name) or interesting(full)
    -- ตอนวางไข่สนใจทุก RF/RE ของเกม แต่ไฮไลต์ egg/place
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
    if mode == "none" and hookmetamethod then
        pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", function(self, ...)
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    logRemote(self, m, ...)
                end
                return old(self, ...)
            end)
            mode = "namecall"
        end)
    end
    _G.EGG01PS_HOOKED = mode
end

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

-- RE ขากลับ EggWorld / Homestead / Pen
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
    L("ฟัง RE ขากลับ " .. n .. " ตัว (Egg/Home/Pen)")
end)

nearB.MouseButton1Click:Connect(function()
    listNear(80)
    dumpHeld()
end)
clearB.MouseButton1Click:Connect(function() OUT = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = ("=== Egg01 PlaceSpy ===\nTime: %s\nPlaceId: %s\nHook: %s\n\n%s")
        :format(os.date("%Y-%m-%d %H:%M:%S"), tostring(game.PlaceId),
            tostring(_G.EGG01PS_HOOKED), table.concat(OUT, "\n"))
    local clip = setclipboard or toclipboard
    local ok = clip and pcall(clip, text)
    pcall(function() if writefile then writefile("Egg01_place_log.txt", text) end end)
    copyB.Text = ok and "คัดลอกแล้ว!" or "เซฟ?"
    task.delay(1.4, function() if copyB.Parent then copyB.Text = "COPY" end end)
end)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
    pauseB.BackgroundColor3 = PAUSED and Color3.fromRGB(150, 60, 30) or Color3.fromRGB(90, 90, 40)
end)
closeB.MouseButton1Click:Connect(function()
    _G.EGG01PS_LOG = nil
    if _G.EGG01PS_CONNS then
        for _, c in pairs(_G.EGG01PS_CONNS) do pcall(function() c:Disconnect() end) end
        _G.EGG01PS_CONNS = {}
    end
    gui:Destroy(); _G.EGG01PS_GUI = nil
end)

L("Egg01 PlaceSpy v1.0 | hook=" .. tostring(_G.EGG01PS_HOOKED or "?"))
L("→ ถือไข่ → กลับบ้าน → กด NEAR ที่จุดวาง → วางมือ 1 ครั้ง → COPY")
L("เป้าหา: AskPlaceEgg / Prompt Place / RE OwnerShifted")
