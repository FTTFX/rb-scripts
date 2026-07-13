-- 74RB_NetProbe.lua v1.0 — แกะโปรโตคอล RequestRemoteEvent/RequestData ของ Net framework
-- 1) ดักดูว่าเกมเรียก Request* ด้วย args อะไร (เดินเล่นให้เกมทำงานปกติสัก 1-2 นาที)
-- 2) ปุ่ม PROBE: ลองขอ remote ตามชื่อที่เดา (SpawnNPC ฯลฯ) แล้วดูว่า server ตอบอะไร
-- 3) จับ remote ใหม่ที่โผล่ใน ReplicatedStorage แบบ realtime

if _G.NETPROBE_CONNS then
    for _, c in pairs(_G.NETPROBE_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.NETPROBE_CONNS = {}
local CONNS = _G.NETPROBE_CONNS

local RSt = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT, LINES = {}, {}

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "NetProbe"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 500, 0, 300); box.Position = UDim2.new(0, 8, 0.42, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.25
box.TextColor3 = Color3.fromRGB(120, 255, 160); box.TextSize = 12; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.Text = "[NetProbe] เริ่ม..."
local function add(s)
    OUT[#OUT + 1] = s
    LINES[#LINES + 1] = s
    while #LINES > 20 do table.remove(LINES, 1) end
    box.Text = table.concat(LINES, "\n")
    pcall(setclipboard, table.concat(OUT, "\n"))
    print("[NetProbe]", s)
end

local function ser(v)
    if typeof(v) == "Instance" then return "<" .. v.ClassName .. ":" .. v:GetFullName() .. ">" end
    if type(v) == "table" then
        local t = {}
        for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. tostring(x) end
        return "{" .. table.concat(t, ",") .. "}"
    end
    return tostring(v)
end

-- 1) ดักเกมเรียก Request*/remote ใหม่
local net = RSt:WaitForChild("Util"):WaitForChild("Net")
local hooked
hooked = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if (method == "FireServer" or method == "InvokeServer")
       and typeof(self) == "Instance" and self.Name:find("Request") then
        local a = {...}
        local s = {}
        for i = 1, #a do s[i] = ser(a[i]) end
        add(("เกมเรียก %s:%s(%s)"):format(self.Name, method, table.concat(s, ", ")))
    end
    return hooked(self, ...)
end))

-- remote ใหม่โผล่ = server สร้างตามคำขอ
table.insert(CONNS, RSt.DescendantAdded:Connect(function(o)
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") or o:IsA("UnreliableRemoteEvent") then
        add("✨ remote ใหม่โผล่: " .. o:GetFullName())
    end
end))

-- 2) ปุ่ม PROBE — ลองขอชื่อที่เดา
local GUESS = {
    "SpawnNPC", "SpawnVisitor", "SpawnPatient", "SpawnAnomaly", "CreateNPC",
    "AddNPC", "AddPatient", "SummonNPC", "Appointment", "BookAppointment",
    "ScheduleAppointment", "RequestAppointment", "NPCAppointment", "SpawnUniqueVisitor",
}
local pb = Instance.new("TextButton", gui)
pb.Size = UDim2.new(0, 160, 0, 30); pb.Position = UDim2.new(0, 8, 0.38, 0)
pb.Text = "PROBE ชื่อเดา " .. #GUESS .. " ชื่อ"; pb.TextSize = 13; pb.Font = Enum.Font.GothamBold
pb.BackgroundColor3 = Color3.fromRGB(90, 60, 20); pb.TextColor3 = Color3.new(1, 1, 1)
table.insert(CONNS, pb.MouseButton1Click:Connect(function()
    local reqRE = net:FindFirstChild("RE/RequestRemoteEvent", true) or net:FindFirstChild("RequestRemoteEvent", true)
    local reqRF = net:FindFirstChild("RF/RequestRemoteFunction", true) or net:FindFirstChild("RequestRemoteFunction", true)
    local reqD  = net:FindFirstChild("RF/RequestData", true) or net:FindFirstChild("RequestData", true)
    add(("เจอ reqRE=%s reqRF=%s reqData=%s"):format(tostring(reqRE ~= nil), tostring(reqRF ~= nil), tostring(reqD ~= nil)))
    for _, name in ipairs(GUESS) do
        if reqRE and reqRE:IsA("RemoteEvent") then pcall(function() reqRE:FireServer(name) end) end
        if reqRF and reqRF:IsA("RemoteFunction") then
            local ok, r = pcall(function() return reqRF:InvokeServer(name) end)
            if ok and r ~= nil then add("ตอบ [" .. name .. "] = " .. ser(r)) end
        end
        task.wait(0.1)
    end
    add("probe จบ — ดูว่ามี ✨ remote ใหม่โผล่ไหม")
end))
