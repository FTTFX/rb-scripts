-- 75RB_DeepSpy.lua v1.0 — ดักทุกช่องทางตอน "เก็บมือสำเร็จ 1 ก้อน" หาทางรีโมตตรง
-- ดัก: (1) ขาไป: FireServer/InvokeServer (namecall hook)
--      (2) ขากลับ: OnClientEvent ของ RemoteEvent ทุกตัวใน RS+workspace (server ส่งอะไรมา)
--      (3) BindableEvent Fire ภายใน client
--      (4) รายชื่อ remote ที่ชื่อเข้าเค้า (crystal/pick/collect/sell/bag/inv)
-- วิธีใช้: รัน → เก็บมือ 1 ก้อน (กดค้างครบ) → COPY ส่งผล
if _G.DSPY75_GUI then pcall(function() _G.DSPY75_GUI:Destroy() end) end
if _G.DSPY75_CONNS then
    for _, c in pairs(_G.DSPY75_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.DSPY75_CONNS = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT = {}
local T0 = os.clock()
local MAXLINES = 350

local box   -- forward
local function L(s)
    OUT[#OUT + 1] = ("[%6.2f] %s"):format(os.clock() - T0, s)
    if #OUT > MAXLINES then table.remove(OUT, 1) end
    if box then box.Text = table.concat(OUT, "\n") end
end

local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then
        return "<" .. v.ClassName .. ":" .. v.Name .. ">"
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
        return '"' .. (v:len() > 50 and v:sub(1, 50) .. "…" or v) .. '"'
    elseif t == "Vector3" then
        return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        return ("CF(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    end
    return tostring(v)
end
local function serAll(args)
    local parts = {}
    for i = 1, math.min(#args, 8) do parts[i] = ser(args[i]) end
    return table.concat(parts, ", ")
end

-- (1) ขาไป — namecall hook (FireServer/InvokeServer + Bindable Fire/Invoke)
if not _G.DSPY75_HOOKED and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer" or m == "Fire" or m == "Invoke")
            and _G.DSPY75_LOG then
            local args = { ... }
            local path = self:GetFullName()
            task.defer(function()
                pcall(function()
                    _G.DSPY75_LOG(("→ %s:%s(%s)"):format(
                        path:gsub("^ReplicatedStorage%.", "RS."):gsub("^Workspace%.", "WS."),
                        m, serAll(args)))
                end)
            end)
        end
        return old(self, ...)
    end)
    _G.DSPY75_HOOKED = true
end
_G.DSPY75_LOG = L

-- (2) ขากลับ — ฟัง OnClientEvent ของ RemoteEvent ทุกตัว (RS + workspace)
local nIn = 0
local function watchIncoming(root)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") then
            nIn += 1
            local path = d:GetFullName():gsub("^ReplicatedStorage%.", "RS."):gsub("^Workspace%.", "WS.")
            table.insert(_G.DSPY75_CONNS, d.OnClientEvent:Connect(function(...)
                local args = { ... }
                L(("← %s(%s)"):format(path, serAll(args)))
            end))
        end
    end
end
watchIncoming(RS)
watchIncoming(workspace)

-- (4) remote ชื่อเข้าเค้า
local function listInteresting()
    L("=== remote ชื่อเข้าเค้า ===")
    local kw = { "crystal", "pick", "collect", "sell", "bag", "inv", "weight", "carry", "drop" }
    local n = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
            local low = d.Name:lower()
            for _, k in ipairs(kw) do
                if low:find(k) then
                    n += 1
                    L(("  [%s] %s"):format(d.ClassName:sub(1, 9),
                        d:GetFullName():gsub("^ReplicatedStorage%.", "RS.")))
                    break
                end
            end
        end
    end
    L("=== เจอ " .. n .. " ตัว ===")
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "DeepSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.DSPY75_GUI = gui

box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 660, 0, 320); box.Position = UDim2.new(0, 8, 0.28, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(170, 240, 255); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Bottom
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.28, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local listB  = hbtn("LIST", 8, 60, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 72, 66, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 142, 66)
local closeB = hbtn("✕", 212, 34, Color3.fromRGB(150, 40, 40))

listB.MouseButton1Click:Connect(listInteresting)
clearB.MouseButton1Click:Connect(function() OUT = {}; box.Text = "" end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_deep_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.DSPY75_LOG = nil
    for _, c in pairs(_G.DSPY75_CONNS) do pcall(function() c:Disconnect() end) end
    _G.DSPY75_CONNS = {}
    gui:Destroy(); _G.DSPY75_GUI = nil
end)

L("[DeepSpy v1.0] ดักขาไป(→) ขากลับ(←) | ฟัง RemoteEvent ขากลับ " .. nIn .. " ตัว")
L("→ เก็บมือ 1 ก้อน (กดค้างครบ) แล้วดูว่าเด้งอะไร | LIST = remote ชื่อเข้าเค้า | COPY ส่งผล")
listInteresting()
