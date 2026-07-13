-- 74RB_ReplayTest.lua v1.0 — ดัก remote ขาออกตอนรักษาจบจริง แล้วยิงซ้ำ (replay)
-- วิธีใช้: 1) รันสคริปต์ 2) ไปรักษาคนไข้จบ 1 ตัวตามปกติ → ดู log ว่ายิง remote อะไร
--          3) กดเลข replay ช็อตที่สงสัย → ดูว่า NPC ตัวอื่นเสร็จ/ได้เงินไหม
-- ⚠️ ยิงซ้ำของจริงไปหา server — ใช้ acc สำรองก่อน

if _G.REPLAY_CONNS then
    for _, c in pairs(_G.REPLAY_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.REPLAY_CONNS = {}
local CONNS = _G.REPLAY_CONNS

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT, LINES = {}, {}
local CAPTURED = {}   -- {remote, method, args, label}

local gui = Instance.new("ScreenGui")
gui.Name = "ReplayTest"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 560, 0, 330); box.Position = UDim2.new(0, 8, 0.3, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(140, 255, 140); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[Replay] รักษาคนไข้ 1 ตัวตามปกติ — ผมจะดักทุก remote"
local function add(s)
    OUT[#OUT + 1] = s; LINES[#LINES + 1] = s
    while #LINES > 20 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
    pcall(setclipboard, table.concat(OUT, "\n"))
    print("[Replay]", s)
end

local function ser(v)
    if typeof(v) == "Instance" then return "<" .. v.ClassName .. ":" .. v.Name .. ">" end
    if typeof(v) == "Vector3" then return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z) end
    if type(v) == "table" then
        local t = {}
        for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. ser(x) end
        return "{" .. table.concat(t, ",") .. "}"
    end
    return tostring(v)
end

-- ตัดเสียงรบกวน: remote ที่ยิงถี่ตลอดเวลา (movement/replication) ไม่ต้อง log
local NOISE = { ["ReplicateMouse"] = 1, ["ClientReplication"] = 1, ["UpdateCamera"] = 1 }

local function record(self, method, a)
    if not (typeof(self) == "Instance" and not NOISE[self.Name]) then return end
    local s = {}
    for i = 1, #a do s[i] = ser(a[i]) end
    local label = ("%s(%s)"):format(self.Name, table.concat(s, ", "))
    for _, c in ipairs(CAPTURED) do if c.label == label then c.count = c.count + 1; return end end
    CAPTURED[#CAPTURED + 1] = {remote = self, method = method, args = a, label = label, count = 1}
    add(("#%d %s"):format(#CAPTURED, label))
end

-- วิธีที่ 1: hookmetamethod (executor ดีๆ) — ดักได้ทุก remote
local ok1 = pcall(function()
    local hooked
    hooked = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            record(self, method, {...})
        end
        return hooked(self, ...)
    end))
end)

-- วิธีที่ 2 (fallback): hook FireServer/InvokeServer ทีละ remote ตรงๆ
if not ok1 then
    add("⚠️ hookmetamethod ไม่รองรับ → ใช้ hook ตรงแทน")
    local function wrap(inst)
        if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") then
            pcall(function()
                local old; old = hookfunction(inst.FireServer, function(self, ...)
                    if self == inst then record(inst, "FireServer", {...}) end
                    return old(self, ...)
                end)
            end)
        elseif inst:IsA("RemoteFunction") then
            pcall(function()
                local old; old = hookfunction(inst.InvokeServer, function(self, ...)
                    if self == inst then record(inst, "InvokeServer", {...}) end
                    return old(self, ...)
                end)
            end)
        end
    end
    for _, o in ipairs(game:GetDescendants()) do wrap(o) end
    table.insert(CONNS, game.DescendantAdded:Connect(wrap))
end

-- ปุ่ม replay: พิมพ์เลขในช่องแล้วกดยิง
local tb = Instance.new("TextBox", gui)
tb.Size = UDim2.new(0, 60, 0, 30); tb.Position = UDim2.new(0, 8, 0.24, 0)
tb.PlaceholderText = "#"; tb.Text = ""; tb.TextSize = 14; tb.Font = Enum.Font.Code
tb.BackgroundColor3 = Color3.fromRGB(40, 40, 40); tb.TextColor3 = Color3.new(1, 1, 1)

local function mkb(txt, x, w, cb)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.24, 0)
    b.Text = txt; b.TextSize = 13; b.Font = Enum.Font.GothamBold
    b.BackgroundColor3 = Color3.fromRGB(30, 90, 40); b.TextColor3 = Color3.new(1, 1, 1)
    table.insert(CONNS, b.MouseButton1Click:Connect(function() task.spawn(cb) end))
end

mkb("REPLAY ยิง #", 74, 110, function()
    local i = tonumber(tb.Text)
    local c = i and CAPTURED[i]
    if not c then add("❌ ไม่มี #" .. tostring(tb.Text)); return end
    add("🔁 replay #" .. i .. " " .. c.label)
    local ok, err = pcall(function()
        if c.method == "FireServer" then c.remote:FireServer(table.unpack(c.args))
        else local r = c.remote:InvokeServer(table.unpack(c.args)); add("  ↩ ตอบ: " .. ser(r)) end
    end)
    if not ok then add("  ❌ " .. tostring(err):sub(1, 60)) end
end)

mkb("LIST ทั้งหมด", 190, 100, function()
    add("=== จับได้ " .. #CAPTURED .. " แบบ ===")
    for i, c in ipairs(CAPTURED) do add(("#%d (x%d) %s"):format(i, c.count, c.label)) end
end)

mkb("CLEAR", 296, 70, function()
    CAPTURED = {}; OUT = {}; LINES = {}
    box.Text = "[Replay] ล้างแล้ว — เริ่มดักใหม่"
end)

add("พร้อม — ไปรักษาคนไข้ 1 ตัวจบตามปกติ")
