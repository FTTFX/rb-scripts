-- Egg01_PickSpy.lua v1.0 — ดัก remote + prompt ตอนยิบไข่
-- PlaceId เป้า: 107778070777162 (เกมขโมยไข่ — ไม่ใช่ BF)
-- วิธีใช้: รัน → กด LIST → ยิบไข่มือ 2–3 ใบ → COPY ส่งมา
-- ปุ่ม: LIST | CLEAR | COPY | PAUSE | ✕
if _G.EGG01_GUI then pcall(function() _G.EGG01_GUI:Destroy() end) end
if _G.EGG01_CONNS then
    for _, c in pairs(_G.EGG01_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.EGG01_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local LP = Players.LocalPlayer
local OUT, T0 = {}, os.clock()
local PAUSED = false
local MAXLINES = 500
local PLACE = game.PlaceId

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01PickSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.EGG01_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 700, 0, 380); box.Position = UDim2.new(0, 8, 0.2, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.12
box.TextColor3 = Color3.fromRGB(255, 230, 170); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function redraw()
    box.Text = table.concat(OUT, "\n")
end
local function L(s)
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > MAXLINES then table.remove(OUT, 1) end
    redraw()
end
_G.EGG01_LOG = L

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.2, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local listB  = hbtn("LIST", 8, 70, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 84, 70, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 160, 70)
local pauseB = hbtn("PAUSE", 236, 74, Color3.fromRGB(90, 90, 40))
local closeB = hbtn("✕", 316, 34, Color3.fromRGB(150, 40, 40))

local KW = { "egg", "steal", "pick", "grab", "hold", "collect", "inventory",
    "item", "loot", "nest", "hatch", "carry", "drop", "place", "claim", "prompt" }

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
        if depth > 2 then return "{...}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n += 1
            if n > 10 then parts[#parts + 1] = "..." break end
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

local function shortPath(inst)
    local ok, full = pcall(function() return inst:GetFullName() end)
    if not ok then return tostring(inst) end
    return full:gsub("^ReplicatedStorage%.", "RS."):gsub("^Workspace%.", "WS.")
end

-- LIST remotes (+ ไฮไลต์ชื่อที่น่าสงสัย)
local function listRemotes()
    L("=== REMOTES PlaceId=" .. tostring(PLACE) .. " ===")
    local n, hit = 0, 0
    local roots = { RS, workspace }
    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                n += 1
                local mark = interesting(d.Name) or interesting(shortPath(d))
                if mark then hit += 1 end
                L(("%s%s [%s] %s"):format(
                    mark and "★ " or "  ",
                    n,
                    d.ClassName:gsub("Remote", ""):gsub("Unreliable", "U"),
                    shortPath(d)))
            end
        end
    end
    L(("=== รวม %d ตัว (★ น่าสนใจ %d) — ยิบไข่มือ แล้วดู log ==="):format(n, hit))
end

-- สแกน ProximityPrompt ใกล้ตัว
local function listNearbyPrompts()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then L("ไม่มี HRP") return end
    L("=== Prompt รัศมี 80 รอบตัว ===")
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local p = d.Parent
            local pos = p and (p:IsA("BasePart") and p.Position
                or (p:FindFirstChildWhichIsA("BasePart") and p:FindFirstChildWhichIsA("BasePart").Position))
            if pos and (pos - hrp.Position).Magnitude <= 80 then
                n += 1
                L(("  PP act='%s' hold=%.1f max=%d @ %s dist=%.0f"):format(
                    tostring(d.ActionText), d.HoldDuration, d.MaxActivationDistance,
                    shortPath(d), (pos - hrp.Position).Magnitude))
            end
        end
    end
    L("=== Prompt ใกล้ตัว " .. n .. " ตัว ===")
end

-- HOOK remotes (ครั้งเดียว)
local function logRemote(self, method, ...)
    if PAUSED or not _G.EGG01_LOG then return end
    local full = ""
    pcall(function() full = shortPath(self) end)
    if full:find("RobloxReplicatedStorage", 1, true) then return end
    if full:find("Analytics", 1, true) or full:find("ClientKit", 1, true) then return end
    local args = { ... }
    local n = select("#", ...)
    local parts = {}
    for i = 1, math.min(n, 10) do parts[i] = ser(args[i]) end
    local star = (interesting(self.Name) or interesting(full)) and "★ " or ""
    L(("%s[%s] %s(%s)"):format(star, method, full, table.concat(parts, ", ")))
end

if not _G.EGG01_HOOKED then
    local hookMode = "none"
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
    if hookMode == "none" and hookmetamethod then
        pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", function(self, ...)
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    logRemote(self, m, ...)
                end
                return old(self, ...)
            end)
            hookMode = "namecall"
        end)
    end
    _G.EGG01_HOOKED = hookMode
end

-- ProximityPrompt
table.insert(_G.EGG01_CONNS, PPS.PromptShown:Connect(function(pp)
    if PAUSED then return end
    L(("👁 PromptShown act='%s' @ %s"):format(tostring(pp.ActionText), shortPath(pp)))
end))
table.insert(_G.EGG01_CONNS, PPS.PromptTriggered:Connect(function(pp, plr)
    if plr ~= LP or PAUSED then return end
    L(("⚡ PromptTriggered act='%s' hold=%.1f @ %s"):format(
        tostring(pp.ActionText), pp.HoldDuration, shortPath(pp)))
end))

-- Buttons
listB.MouseButton1Click:Connect(function()
    listRemotes()
    listNearbyPrompts()
end)
clearB.MouseButton1Click:Connect(function() OUT = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local header = ("=== Egg01 PickSpy ===\nTime: %s\nPlaceId: %s\nHook: %s\n\n")
        :format(os.date("%Y-%m-%d %H:%M:%S"), tostring(PLACE), tostring(_G.EGG01_HOOKED))
    local text = header .. table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    pcall(function()
        if writefile then writefile("Egg01_pick_log.txt", text) end
    end)
    copyB.Text = ok and "คัดลอกแล้ว!" or "เซฟไฟล์แล้ว?"
    task.delay(1.6, function() if copyB.Parent then copyB.Text = "COPY" end end)
end)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
    pauseB.BackgroundColor3 = PAUSED and Color3.fromRGB(150, 60, 30) or Color3.fromRGB(90, 90, 40)
end)
closeB.MouseButton1Click:Connect(function()
    _G.EGG01_LOG = nil
    if _G.EGG01_CONNS then
        for _, c in pairs(_G.EGG01_CONNS) do pcall(function() c:Disconnect() end) end
        _G.EGG01_CONNS = {}
    end
    gui:Destroy(); _G.EGG01_GUI = nil
end)

L("Egg01 PickSpy v1.0 | PlaceId=" .. tostring(PLACE)
    .. " | hook=" .. tostring(_G.EGG01_HOOKED or "?"))
if PLACE ~= 107778070777162 then
    L("⚠ PlaceId ไม่ตรงเป้า 107778070777162 — เช็คว่าเข้าเกมถูกไหม")
end
L("→ กด LIST → ยิบไข่มือ 2–3 ใบ → COPY ส่งมา")
L("★ = ชื่อเกี่ยวกับ egg/steal/pick/claim")
