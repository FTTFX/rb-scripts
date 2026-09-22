-- Egg01 Copy Server Id v1.1
-- JobId ≠ share code — ใช้ deep link + TeleportToPlaceInstance แทน

if _G.EGG01_COPY_SERVER then
    pcall(function() _G.EGG01_COPY_SERVER.gui:Destroy() end)
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LP = Players.LocalPlayer

local S = { gui = nil }
_G.EGG01_COPY_SERVER = S

local function jobId()
    local id = tostring(game.JobId or "")
    if id == "" or id == "0" then return nil end
    return id
end

local function deepLink()
    local j = jobId()
    if not j then return nil end
    return string.format(
        "https://www.roblox.com/games/start?placeId=%s&gameInstanceId=%s",
        tostring(game.PlaceId), j
    )
end

local function copyText(t)
    local c = setclipboard or toclipboard
    if not c then return false end
    return pcall(c, t)
end

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_CopyServerId"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1005
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui

local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 340, 0, 148)
f.Position = UDim2.new(0, 12, 0, 120)
f.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
f.BackgroundTransparency = 0.08
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -46, 0, 22)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Copy / Join Server (JobId)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton", f)
close.Size = UDim2.new(0, 28, 0, 22)
close.Position = UDim2.new(1, -34, 0, 4)
close.BackgroundColor3 = Color3.fromRGB(125, 45, 45)
close.BorderSizePixel = 0
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.TextSize = 12
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)

local function btn(text, x, w, color)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, w, 0, 26)
    b.Position = UDim2.new(0, x, 0, 30)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local copyLinkB = btn("COPY LINK", 10, 88, Color3.fromRGB(40, 145, 75))
local copyJobB = btn("COPY JOB", 104, 88, Color3.fromRGB(70, 110, 180))
local joinHereB = btn("JOIN PASTE", 198, 100, Color3.fromRGB(150, 100, 40))

local input = Instance.new("TextBox", f)
input.Size = UDim2.new(1, -20, 0, 26)
input.Position = UDim2.new(0, 10, 0, 64)
input.BackgroundColor3 = Color3.fromRGB(40, 43, 49)
input.BorderSizePixel = 0
input.ClearTextOnFocus = false
input.PlaceholderText = "วาง JobId แล้วกด JOIN PASTE (บัญชีอื่น)"
input.PlaceholderColor3 = Color3.fromRGB(140, 145, 155)
input.TextColor3 = Color3.new(1, 1, 1)
input.Font = Enum.Font.Code
input.TextSize = 11
input.Text = ""
Instance.new("UICorner", input).CornerRadius = UDim.new(0, 5)

local status = Instance.new("TextLabel", f)
status.Size = UDim2.new(1, -20, 0, 44)
status.Position = UDim2.new(0, 10, 0, 96)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(200, 210, 220)
status.Font = Enum.Font.Code
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "share?code= ใช้ JobId ไม่ได้ — ใช้ LINK / JOIN แทน"

local function flash(b)
    local old = b.Text
    b.Text = "OK"
    task.delay(1, function()
        if b and b.Parent then b.Text = old end
    end)
end

local function showJob()
    local j = jobId()
    if not j then
        status.Text = "ยังไม่มี JobId"
        return
    end
    status.Text = "PlaceId=" .. tostring(game.PlaceId) .. "\nJobId=" .. j
end

copyLinkB.MouseButton1Click:Connect(function()
    local link = deepLink()
    if not link then
        status.Text = "ยังไม่มี JobId"
        return
    end
    if copyText(link) then
        flash(copyLinkB)
        status.Text = "คัดลอก deep link แล้ว\n(บางทีเว็บอาจสุ่มเซิร์ฟ — ใช้ JOIN PASTE ชัวร์กว่า)"
    else
        status.Text = link
    end
end)

copyJobB.MouseButton1Click:Connect(function()
    local j = jobId()
    if not j then
        status.Text = "ยังไม่มี JobId"
        return
    end
    if copyText(j) then
        flash(copyJobB)
        status.Text = "คัดลอก JobId:\n" .. j
    else
        status.Text = j
    end
end)

joinHereB.MouseButton1Click:Connect(function()
    local raw = (input.Text or ""):gsub("%s+", "")
    if raw == "" then
        status.Text = "วาง JobId ในช่องก่อน"
        return
    end
    -- รองรับวางทั้ง UUID หรือลิงก์เต็ม
    local j = raw:match("gameInstanceId=([%w%-]+)") or raw:match("code=([%w%-]+)") or raw
    status.Text = "กำลัง Teleport → " .. j
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, j, LP)
    end)
    if not ok then
        status.Text = "JOIN ล้ม: " .. tostring(err)
    end
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_COPY_SERVER = nil
end)

showJob()
print("[Egg01 CopyServerId] v1.1 | " .. tostring(deepLink()))
