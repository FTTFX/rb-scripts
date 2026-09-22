-- Egg01 Copy Server Id v1.2
-- ปุ่ม SHARE = เรียก API เดียวกับ Share ในเกม → ได้ลิงก์ share?code=... จริง

if _G.EGG01_COPY_SERVER then
    pcall(function() _G.EGG01_COPY_SERVER.gui:Destroy() end)
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SocialService = game:GetService("SocialService")
local LP = Players.LocalPlayer

local S = { gui = nil, lastLink = nil }
_G.EGG01_COPY_SERVER = S

local function http()
    return (syn and syn.request) or http_request or request or (fluxus and fluxus.request) or nil
end

local function copyText(t)
    local c = setclipboard or toclipboard
    if not c then return false end
    return pcall(c, t)
end

local function jobId()
    local id = tostring(game.JobId or "")
    if id == "" or id == "0" then return nil end
    return id
end

-- API เดียวกับเมนู Share Invite Link ในเกม
local function createShareLink(linkType)
    local req = http()
    if not req then return nil, "executor ไม่มี request" end
    local ok, res = pcall(function()
        return req({
            Url = "https://apis.roblox.com/sharelinks/v1/create-link",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Accept"] = "application/json",
            },
            Body = HttpService:JSONEncode({ linkType = linkType }),
        })
    end)
    if not ok or type(res) ~= "table" then
        return nil, "request พัง: " .. tostring(res)
    end
    local code = tonumber(res.StatusCode) or 0
    local body = res.Body or ""
    if code < 200 or code >= 300 then
        return nil, string.format("HTTP %s | %s", tostring(code), body:sub(1, 120))
    end
    local data
    local okJ, j = pcall(function() return HttpService:JSONDecode(body) end)
    if okJ then data = j end
    local linkId = data and (data.linkId or data.linkCode or data.code)
    if not linkId or tostring(linkId) == "" then
        return nil, "ไม่มี linkId: " .. body:sub(1, 160)
    end
    local url = string.format(
        "https://www.roblox.com/share?code=%s&type=%s",
        tostring(linkId), tostring(linkType)
    )
    return url, tostring(linkId)
end

local function makeShare()
    -- เมนูในเกมใช้ ExperienceInvite — type=Server มักเป็น private server
    local order = { "ExperienceInvite", "Server" }
    local errs = {}
    for _, t in ipairs(order) do
        local url, info = createShareLink(t)
        if url then
            return url, t, info
        end
        table.insert(errs, t .. "=" .. tostring(info))
    end
    return nil, nil, table.concat(errs, " | ")
end

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_CopyServerId"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1005
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui

local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 360, 0, 150)
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
title.Text = "Share Server Link (เหมือนปุ่ม Share)"
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
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, 32)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local shareB = btn("SHARE", 10, 100, Color3.fromRGB(40, 145, 75))
local inviteB = btn("INVITE UI", 118, 100, Color3.fromRGB(70, 110, 180))
local jobB = btn("COPY JOB", 226, 100, Color3.fromRGB(90, 90, 100))

local status = Instance.new("TextLabel", f)
status.Size = UDim2.new(1, -20, 0, 72)
status.Position = UDim2.new(0, 10, 0, 70)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(200, 210, 220)
status.Font = Enum.Font.Code
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "กด SHARE = สร้างลิงก์ share?code=... (API ในเกม)\nJobId=" .. tostring(jobId() or "?")

shareB.MouseButton1Click:Connect(function()
    status.Text = "กำลังสร้างลิงก์ Share..."
    shareB.Text = "..."
    task.spawn(function()
        local url, typ, info = makeShare()
        shareB.Text = "SHARE"
        if not url then
            status.Text = "สร้างไม่ได้:\n" .. tostring(info)
            return
        end
        S.lastLink = url
        copyText(url)
        status.Text = string.format("OK type=%s\n%s\n(คัดลอกแล้ว | JobId=%s)", typ, url, tostring(jobId() or "?"))
    end)
end)

inviteB.MouseButton1Click:Connect(function()
    local ok, err = pcall(function()
        SocialService:PromptGameInvite(LP)
    end)
    status.Text = ok and "เปิด Invite UI — กด Share Invite Link ในหน้าต่าง Roblox" or ("Invite พัง: " .. tostring(err))
end)

jobB.MouseButton1Click:Connect(function()
    local j = jobId()
    if not j then
        status.Text = "ยังไม่มี JobId"
        return
    end
    copyText(j)
    status.Text = "คัดลอก JobId:\n" .. j
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_COPY_SERVER = nil
end)

print("[Egg01 CopyServerId] v1.2 SHARE ready | JobId=" .. tostring(jobId()))
