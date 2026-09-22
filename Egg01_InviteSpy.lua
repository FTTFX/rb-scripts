-- Egg01 Invite Spy v1.0
-- ดัก/ตามเชิญเพื่อน → หาว่าเพื่อนอยู่เซิร์ฟไหน (JobId)
-- หมายเหตุ: ลิงก์ share?code= ใน toast Roblox ไม่เปิดให้ Lua อ่านตรงๆ
--          ใช้ GetPlayerPlaceInstanceAsync = รู้เซิร์ฟเพื่อนตอนเชิญ (ชัวร์สุด)

if _G.EGG01_INVITE_SPY then
    pcall(function() _G.EGG01_INVITE_SPY.gui:Destroy() end)
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local SocialService = game:GetService("SocialService")
local LP = Players.LocalPlayer

local S = {
    gui = nil,
    watch = {}, -- [userId]=true
    last = {},  -- [userId]={placeId,jobId,at}
    log = {},
    hookOn = false,
}
_G.EGG01_INVITE_SPY = S

local function say(t)
    t = tostring(t)
    table.insert(S.log, 1, os.date("%H:%M:%S") .. " " .. t)
    while #S.log > 12 do table.remove(S.log) end
    if S.logBox then S.logBox.Text = table.concat(S.log, "\n") end
    print("[InviteSpy]", t)
end

local function copyText(t)
    local c = setclipboard or toclipboard
    if not c then return false end
    return pcall(c, t)
end

local function http()
    return (syn and syn.request) or http_request or request or (fluxus and fluxus.request) or nil
end

-- GetPlayerPlaceInstanceAsync → currentInstance, errorMessage, placeId, jobId
local function resolveFriend(userId)
    userId = tonumber(userId)
    if not userId then return nil, "UserId ไม่ถูกต้อง" end
    local ok, a, b, c, d = pcall(function()
        return TeleportService:GetPlayerPlaceInstanceAsync(userId)
    end)
    if not ok then
        return nil, "เรียกไม่ได้: " .. tostring(a)
    end
    local success, errorString, pId, jId
    if type(a) == "boolean" then
        success, errorString, pId, jId = a, b, c, d
    else
        errorString, pId, jId = a, b, c
        success = (jId ~= nil and tostring(jId) ~= "")
    end
    if not success or not jId or tostring(jId) == "" then
        return nil, tostring(errorString or "เพื่อนออฟไลน์/ไม่ได้อยู่ในเกม")
    end
    return {
        userId = userId,
        placeId = tonumber(pId) or pId,
        jobId = tostring(jId),
    }
end

local function formatLink(info)
    if not info then return nil end
    return string.format(
        "https://www.roblox.com/games/start?placeId=%s&gameInstanceId=%s",
        tostring(info.placeId), tostring(info.jobId)
    )
end

local function flashFriend(userId)
    local info, err = resolveFriend(userId)
    if not info then
        say("UID " .. tostring(userId) .. " — " .. tostring(err))
        return
    end
    S.last[userId] = { placeId = info.placeId, jobId = info.jobId, at = os.clock() }
    local link = formatLink(info)
    say(string.format("เพื่อน %s → Place %s | Job %s", tostring(userId), tostring(info.placeId), info.jobId))
    if link then say(link) end
    return info, link
end

-- สแกน CoreGui หาข้อความเชิญ (toast)
local function scanCoreGuiInvites()
    local cg
    pcall(function() cg = game:GetService("CoreGui") end)
    if not cg then return end
    local keys = { "invite", "invited", "เชิญ", "ชวน", "join", "เล่น" }
    for _, d in ipairs(cg:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = string.lower(d.Text or "")
            if #t > 8 and #t < 200 then
                for _, k in ipairs(keys) do
                    if string.find(t, k, 1, true) then
                        local path = d:GetFullName()
                        if not S._seen then S._seen = {} end
                        local sig = t
                        if not S._seen[sig] then
                            S._seen[sig] = true
                            say("UI: " .. (d.Text or ""):sub(1, 80))
                        end
                        break
                    end
                end
            end
        end
    end
end

-- ดัก HTTP ที่เกี่ยวกับ share / notification / invite
local function installHttpHook()
    if S.hookOn then return end
    local req = http()
    if not req then
        say("ไม่มี request — ข้าม HTTP hook")
        return
    end
    S.hookOn = true
    local old = req
    -- ไม่แทนที่ global ทั้งก้อนถ้าเป็น syn.request แยก — ห่อเฉพาะที่เราเรียกเอง + ลอง hook __namecall
    local mt = getrawmetatable and getrawmetatable(game)
    if not mt or not hookmetamethod then
        say("hookmetamethod ไม่มี — ใช้ poll เพื่อนอย่างเดียว")
        return
    end
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }
        local ret = { oldNamecall(self, ...) }
        local m = string.lower(tostring(method or ""))
        if m == "getasync" or m == "postasync" or m == "requestasync" then
            local url = tostring(args[1] or "")
            local blob = url .. " " .. tostring(ret[1] or "")
            if blob:find("sharelink", 1, true) or blob:find("invite", 1, true)
                or blob:find("notification", 1, true) or blob:find("gameInstance", 1, true) then
                local code = blob:match("\"linkId\"%s*:%s*\"([%w%-]+)\"")
                    or blob:match("code=([%w%d]+)")
                local job = blob:match("\"jobId\"%s*:%s*\"([%w%-]+)\"")
                    or blob:match("gameInstanceId=([%w%-]+)")
                if code then
                    local typ = blob:match("\"linkType\"%s*:%s*\"(%w+)\"") or "ExperienceInvite"
                    local url2 = "https://www.roblox.com/share?code=" .. code .. "&type=" .. typ
                    say("HTTP link: " .. url2)
                    copyText(url2)
                end
                if job then say("HTTP JobId: " .. job) end
            end
        end
        return table.unpack(ret)
    end))
    say("HTTP namecall hook ติดแล้ว")
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_InviteSpy"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1006
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui

local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 380, 0, 220)
f.Position = UDim2.new(0, 12, 0, 200)
f.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -40, 0, 22)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Invite Spy — ดักเซิร์ฟจากเพื่อน"
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
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)

local input = Instance.new("TextBox", f)
input.Size = UDim2.new(0, 160, 0, 26)
input.Position = UDim2.new(0, 10, 0, 32)
input.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
input.BorderSizePixel = 0
input.PlaceholderText = "Friend UserId"
input.Text = ""
input.TextColor3 = Color3.new(1, 1, 1)
input.Font = Enum.Font.Code
input.TextSize = 12
Instance.new("UICorner", input).CornerRadius = UDim.new(0, 5)

local function mk(text, x, w, color)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, w, 0, 26)
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

local watchB = mk("WATCH", 178, 64, Color3.fromRGB(40, 145, 75))
local nowB = mk("NOW", 248, 52, Color3.fromRGB(70, 110, 180))
local joinB = mk("JOIN", 306, 54, Color3.fromRGB(150, 100, 40))

S.logBox = Instance.new("TextLabel", f)
S.logBox.Size = UDim2.new(1, -16, 0, 148)
S.logBox.Position = UDim2.new(0, 8, 0, 66)
S.logBox.BackgroundColor3 = Color3.new(0, 0, 0)
S.logBox.BackgroundTransparency = 0.25
S.logBox.TextColor3 = Color3.fromRGB(180, 230, 190)
S.logBox.Font = Enum.Font.Code
S.logBox.TextSize = 10
S.logBox.TextXAlignment = Enum.TextXAlignment.Left
S.logBox.TextYAlignment = Enum.TextYAlignment.Top
S.logBox.TextWrapped = true
S.logBox.Text = ""

watchB.MouseButton1Click:Connect(function()
    local id = tonumber(input.Text)
    if not id then say("ใส่ UserId เพื่อนก่อน"); return end
    S.watch[id] = true
    say("WATCH UID " .. id .. " ทุก 8s")
    flashFriend(id)
end)

nowB.MouseButton1Click:Connect(function()
    local id = tonumber(input.Text)
    if not id then say("ใส่ UserId"); return end
    local info, link = flashFriend(id)
    if info then
        copyText(info.jobId)
        say("คัดลอก JobId แล้ว")
    end
end)

joinB.MouseButton1Click:Connect(function()
    local id = tonumber(input.Text)
    if not id then say("ใส่ UserId"); return end
    local info = flashFriend(id)
    if not info then return end
    say("Teleport → " .. info.jobId)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(info.placeId, info.jobId, LP)
    end)
    if not ok then say("JOIN ล้ม: " .. tostring(err)) end
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_INVITE_SPY = nil
end)

pcall(function()
    SocialService.GameInvitePromptClosed:Connect(function(player, sentIds)
        say("InvitePromptClosed ids=" .. HttpService:JSONEncode(sentIds or {}))
    end)
end)

task.spawn(installHttpHook)

task.spawn(function()
    while S.gui and S.gui.Parent do
        for uid in pairs(S.watch) do
            flashFriend(uid)
        end
        pcall(scanCoreGuiInvites)
        task.wait(8)
    end
end)

say("พร้อม — ใส่ UserId เพื่อนที่เชิญ → WATCH/NOW/JOIN")
say("toast Roblox ไม่ให้ลิงก์ตรงๆ — ดึง JobId จากที่เพื่อนอยู่")
