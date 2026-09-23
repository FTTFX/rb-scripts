-- Egg01_TreadBoostSpy v1.0
-- Spy ไอเทม "2x บูสเตอร์ลู่วิ่ง" — หา remote/value + วัด rate บนลู่ก่อน/หลังเปิดบูสต์
-- ไม่ยิง remote ซื้อเอง — กดซื้อในเกมด้วยมือ แล้วดู log

if _G.EGG01_TREADBOOST_SPY then
    _G.EGG01_TREADBOOST_SPY.on = false
    pcall(function() _G.EGG01_TREADBOOST_SPY.gui:Destroy() end)
    for _, c in ipairs(_G.EGG01_TREADBOOST_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local SAMPLE_SEC = 10
local POLL_HZ = 0.05
local KEYWORDS = {
    "tread", "boost", "potion", "speed", "shop", "store", "buy", "purchase",
    "luck", "clover", "x2", "2x", "multiplier", "consumable", "buff",
}

local S = { gui = nil, conns = {}, on = true, lines = {}, busy = false, abort = false, rateA = nil, rateB = nil }
_G.EGG01_TREADBOOST_SPY = S

local function interesting(s)
    s = tostring(s):lower()
    for _, k in ipairs(KEYWORDS) do
        if s:find(k, 1, true) then return true end
    end
    return false
end

local function path(v)
    local ok, p = pcall(function() return v:GetFullName() end)
    return ok and p:gsub("^ReplicatedStorage%.", "RS."):gsub("^Workspace%.", "WS."):gsub("^Players%.", "PL.") or tostring(v)
end

local function show(v, depth)
    depth = depth or 0
    if typeof(v) == "Instance" then return "<" .. v.ClassName .. ":" .. path(v) .. ">" end
    if typeof(v) == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z) end
    if typeof(v) == "table" then
        if depth > 1 then return "{...}" end
        local out, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 8 then out[#out + 1] = "..." break end
            out[#out + 1] = tostring(k) .. "=" .. show(x, depth + 1)
        end
        return "{" .. table.concat(out, ",") .. "}"
    end
    return tostring(v)
end

local function parts()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function readScore()
    local stats = LP:FindFirstChild("leaderstats")
    if stats then
        for _, name in ipairs({ "Speed", "Steps", "Step" }) do
            local v = stats:FindFirstChild(name)
            if v and tonumber(v.Value) then return tonumber(v.Value), name end
        end
    end
    return nil, nil
end

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_TreadBoostSpy"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1012
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 620, 0, 320)
box.Position = UDim2.new(0, 12, 0.22, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(190, 245, 190)
box.TextSize = 11
box.Font = Enum.Font.Code
box.TextEditable = false
box.ClearTextOnFocus = false
box.MultiLine = true
box.TextWrapped = false
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.Text = ""

local function log(m)
    if not S.on then return end
    S.lines[#S.lines + 1] = string.format("[%6.2f] %s", os.clock(), tostring(m))
    if #S.lines > 240 then table.remove(S.lines, 1) end
    local t = table.concat(S.lines, "\n")
    box.Text = t
    box.CursorPosition = #t + 1
    print("[TreadBoostSpy] " .. tostring(m))
end

local function button(text, x, w, color)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0.22, -32)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bList = button("LIST", 12, 58, Color3.fromRGB(50, 105, 165))
local bHook = button("HOOK", 76, 58, Color3.fromRGB(35, 145, 75))
local bScan = button("SCAN", 140, 58, Color3.fromRGB(120, 90, 40))
local bRateA = button("RATE A", 204, 64, Color3.fromRGB(70, 130, 220))
local bRateB = button("RATE B", 274, 64, Color3.fromRGB(235, 150, 60))
local bCopy = button("COPY", 344, 58, Color3.fromRGB(80, 80, 80))
local bClear = button("CLEAR", 408, 58, Color3.fromRGB(80, 80, 80))
local bX = button("X", 472, 36, Color3.fromRGB(165, 50, 50))

local function listRemotes()
    local all, hit = 0, 0
    log("=== TREAD/BOOST/SHOP REMOTES ===")
    for _, root in ipairs({ RS, workspace, LP }) do
        local ok, desc = pcall(function() return root:GetDescendants() end)
        if ok and desc then
            for _, v in ipairs(desc) do
                if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("UnreliableRemoteEvent") then
                    all = all + 1
                    if interesting(v.Name) or interesting(path(v)) then
                        hit = hit + 1
                        log("★ [" .. v.ClassName .. "] " .. path(v))
                    end
                end
            end
        end
    end
    log(string.format("remote=%d match=%d | กด HOOK แล้วซื้อบูสต์ในเกมด้วยมือ", all, hit))
end

local function scanValues()
    log("=== SCAN Values (boost/buff/2x/expire) ===")
    local n = 0
    local roots = { LP, RS }
    local pd = LP:FindFirstChild("PlayerData") or LP:FindFirstChild("Data") or LP:FindFirstChild("leaderstats")
    if pd then roots[#roots + 1] = pd end
    for _, root in ipairs(roots) do
        local ok, desc = pcall(function() return root:GetDescendants() end)
        if ok and desc then
            for _, v in ipairs(desc) do
                if v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("BoolValue")
                    or v:IsA("StringValue") or v:IsA("ObjectValue") then
                    if interesting(v.Name) or interesting(path(v)) then
                        n = n + 1
                        log(string.format("· %s = %s", path(v), tostring(v.Value)))
                        if n > 80 then log("…ตัดที่ 80"); return end
                    end
                end
            end
        end
    end
    -- GUI ที่มีข้อความ 2x / บูสต์ / 10m
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, v in ipairs(pg:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                local t = tostring(v.Text or "")
                local tl = t:lower()
                if tl:find("2x", 1, true) or t:find("บูสต์", 1, true) or t:find("ลู่วิ่ง", 1, true)
                    or tl:find("boost", 1, true) or tl:find("10m", 1, true) then
                    log("GUI «" .. t:sub(1, 60) .. "» @ " .. path(v))
                end
            end
        end
    end
    log("SCAN จบ — เปิดบูสต์แล้วกด SCAN อีกรอบเทียบค่าที่เปลี่ยน")
end

local hooked = false
local function hookRemotes()
    if hooked then log("HOOK อยู่แล้ว"); return end
    hooked = true
    local mt = getrawmetatable and getrawmetatable(game)
    if not mt then
        -- fallback: Namecall ไม่ได้ — ฟัง OnClientEvent ของ remote ที่ match
        log("ไม่มี getrawmetatable — ฟัง OnClientEvent ฝั่ง client")
        for _, root in ipairs({ RS }) do
            for _, v in ipairs(root:GetDescendants()) do
                if (v:IsA("RemoteEvent") or v:IsA("UnreliableRemoteEvent"))
                    and (interesting(v.Name) or interesting(path(v))) then
                    local ok, conn = pcall(function()
                        return v.OnClientEvent:Connect(function(...)
                            local args = { ... }
                            local parts = {}
                            for i = 1, math.min(#args, 6) do parts[i] = show(args[i]) end
                            log("← " .. path(v) .. " " .. table.concat(parts, " | "))
                        end)
                    end)
                    if ok and conn then S.conns[#S.conns + 1] = conn end
                end
            end
        end
        log("HOOK client-recv พร้อม — ซื้อบูสต์ด้วยมือ")
        return
    end
    local old = mt.__namecall
    if setreadonly then pcall(setreadonly, mt, false) end
    mt.__namecall = newcclosure and newcclosure(function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or ""
        if S.on and typeof(self) == "Instance"
            and (method == "FireServer" or method == "InvokeServer")
            and (interesting(self.Name) or interesting(path(self))) then
            local args = { ... }
            local parts = {}
            for i = 1, math.min(#args, 6) do parts[i] = show(args[i]) end
            log("→ " .. method .. " " .. path(self) .. " " .. table.concat(parts, " | "))
        end
        return old(self, ...)
    end) or function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or ""
        if S.on and typeof(self) == "Instance"
            and (method == "FireServer" or method == "InvokeServer")
            and (interesting(self.Name) or interesting(path(self))) then
            local args = { ... }
            local parts = {}
            for i = 1, math.min(#args, 6) do parts[i] = show(args[i]) end
            log("→ " .. method .. " " .. path(self) .. " " .. table.concat(parts, " | "))
        end
        return old(self, ...)
    end
    if setreadonly then pcall(setreadonly, mt, true) end
    log("HOOK namecall พร้อม — เปิดร้าน → กดซื้อ 2x บูสเตอร์ลู่วิ่ง (375)")
end

local function measureRate(label)
    if S.busy then return end
    S.busy = true
    S.abort = false
    task.spawn(function()
        local score0, name = readScore()
        if score0 == nil then log("RATE FAIL: อ่าน Speed ไม่ได้"); S.busy = false; return end
        local t0 = os.clock()
        log(string.format("RATE %s เริ่ม 10s | %s=%.0f — ยืนบนลู่", label, name or "?", score0))
        while not S.abort and os.clock() - t0 < SAMPLE_SEC do
            task.wait(POLL_HZ)
        end
        local score1 = readScore()
        S.busy = false
        if score1 == nil then log("RATE FAIL จบ"); return end
        local delta = score1 - score0
        local rate = delta / SAMPLE_SEC
        if label == "A" then S.rateA = rate else S.rateB = rate end
        log(string.format("RATE %s Δ=%.0f  rate=%.0f/s", label, delta, rate))
        if S.rateA and S.rateB and S.rateA > 0 then
            local r = S.rateB / S.rateA
            log(string.format("สรุป B/A = %.2f× (%+d%%) — ถ้า ≈2.0 แสดงบูสต์ทำงานที่เซิร์ฟ",
                r, math.floor((r - 1) * 100 + 0.5)))
        end
    end)
end

bList.MouseButton1Click:Connect(listRemotes)
bHook.MouseButton1Click:Connect(hookRemotes)
bScan.MouseButton1Click:Connect(scanValues)
bRateA.MouseButton1Click:Connect(function() measureRate("A") end)
bRateB.MouseButton1Click:Connect(function() measureRate("B") end)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local c = setclipboard or toclipboard
    if c then
        pcall(c, table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bX.MouseButton1Click:Connect(function()
    S.on = false
    S.abort = true
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    _G.EGG01_TREADBOOST_SPY = nil
end)

log("v1.0 — LIST→HOOK→ซื้อบูสต์มือ | SCAN ก่อน/หลัง | RATE A(ก่อน) RATE B(หลัง) บนลู่")
listRemotes()
