-- 75RB_NetSpy.lua v1.0 — ดักรีโมตเกมคริสตัล: เก็บของ/ขาย/อัปเกรด ยิง Remote อะไร?
-- 1) LIST: รายชื่อ RemoteEvent/RemoteFunction ทั้งหมดใน ReplicatedStorage (path เต็ม)
-- 2) HOOK: ดัก __namecall FireServer/InvokeServer → log ชื่อ remote + args ทุกครั้งที่เกมยิง
-- วิธีใช้: รัน → เก็บคริสตัล 1 ก้อน / ขาย 1 ครั้ง → ดู log ว่าเด้งอะไร → COPY ส่งผล
-- ปุ่ม: LIST | CLEAR | COPY | PAUSE | ✕
if _G.NSPY75_GUI then pcall(function() _G.NSPY75_GUI:Destroy() end) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT = {}
local PAUSED = false
local MAXLINES = 400

local gui = Instance.new("ScreenGui")
gui.Name = "NetSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.NSPY75_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 640, 0, 340); box.Position = UDim2.new(0, 8, 0.24, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(255, 220, 160); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Bottom
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function redraw()
    box.Text = table.concat(OUT, "\n")
end
local function L(s)
    OUT[#OUT + 1] = s
    if #OUT > MAXLINES then table.remove(OUT, 1) end
    redraw()
end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.24, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local listB  = hbtn("LIST", 8, 70, Color3.fromRGB(40, 130, 70))
local clearB = hbtn("CLEAR", 84, 70, Color3.fromRGB(90, 60, 30))
local copyB  = hbtn("COPY", 160, 70)
local pauseB = hbtn("PAUSE", 236, 74, Color3.fromRGB(90, 90, 40))
local closeB = hbtn("✕", 316, 34, Color3.fromRGB(150, 40, 40))

-- ==================== serialize args ====================
local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then
        return "<" .. v.ClassName .. ":" .. v:GetFullName():gsub("^Workspace%.", "WS.") .. ">"
    elseif t == "table" then
        if depth > 2 then return "{...}" end
        local parts = {}
        local n = 0
        for k, val in pairs(v) do
            n += 1
            if n > 8 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. ser(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "string" then
        return '"' .. (v:len() > 60 and v:sub(1, 60) .. "…" or v) .. '"'
    elseif t == "Vector3" then
        return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        return ("CF(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    end
    return tostring(v)
end

-- ==================== LIST remotes ====================
local function listRemotes()
    L("=== REMOTES ใน ReplicatedStorage ===")
    local n = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
            n += 1
            L(("%s [%s] %s"):format(n, d.ClassName:sub(1, 9), d:GetFullName():gsub("^ReplicatedStorage%.", "RS.")))
        end
    end
    L("=== รวม " .. n .. " ตัว — ทีนี้ลองเก็บ/ขายของ ดู log ===")
end

-- ==================== HOOK __namecall (ครั้งเดียวต่อ session) ====================
if not _G.NSPY75_HOOKED and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer")
            and not PAUSED and _G.NSPY75_LOG then
            local args = { ... }
            task.defer(function()
                pcall(function()
                    local parts = {}
                    for i = 1, math.min(#args, 8) do parts[i] = ser(args[i]) end
                    _G.NSPY75_LOG(("[%s] %s:%s(%s)"):format(
                        os.date("%H:%M:%S"), self.Name, method, table.concat(parts, ", ")))
                end)
            end)
        end
        return old(self, ...)
    end)
    _G.NSPY75_HOOKED = true
end
_G.NSPY75_LOG = L

-- ==================== Buttons ====================
listB.MouseButton1Click:Connect(listRemotes)
clearB.MouseButton1Click:Connect(function() OUT = {}; redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_net_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
pauseB.MouseButton1Click:Connect(function()
    PAUSED = not PAUSED
    pauseB.Text = PAUSED and "RESUME" or "PAUSE"
    pauseB.BackgroundColor3 = PAUSED and Color3.fromRGB(150, 60, 30) or Color3.fromRGB(90, 90, 40)
end)
closeB.MouseButton1Click:Connect(function()
    _G.NSPY75_LOG = nil   -- hook ยังอยู่แต่เงียบ (ถอด hook กลางคันเสี่ยง crash)
    gui:Destroy(); _G.NSPY75_GUI = nil
end)

L("[NetSpy v1.0] hook=" .. tostring(_G.NSPY75_HOOKED == true)
    .. " — เก็บคริสตัล 1 ก้อน แล้วดูว่าเด้ง remote อะไร | กด LIST ดูรายชื่อ remote ทั้งหมด")
