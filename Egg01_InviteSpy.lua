-- Egg01 Invite Spy v1.3
-- ดัก TeleportToPlaceInstance จากปุ่มเข้าร่วม → ได้ JobId
-- hook ต้อง defer log ห้าม JSONEncode ก่อน old (จะพัง Teleport)

if _G.EGG01_INVITE_SPY then
    pcall(function() _G.EGG01_INVITE_SPY.gui:Destroy() end)
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local S = { gui = nil, last = nil, log = {}, hookedBtns = {}, seenCard = {} }
_G.EGG01_INVITE_SPY = S

local function say(t)
    t = tostring(t)
    table.insert(S.log, 1, os.date("%H:%M:%S") .. " " .. t)
    while #S.log > 16 do table.remove(S.log) end
    if S.logBox then S.logBox.Text = table.concat(S.log, "\n") end
    print("[InviteSpy]", t)
end

local function copyText(t)
    local c = setclipboard or toclipboard
    if not c then return false end
    return pcall(c, t)
end

local function httpReq()
    return (syn and syn.request) or http_request or request or (fluxus and fluxus.request) or nil
end

local function safeJson(v, depth)
    depth = depth or 0
    if depth > 4 then return "..." end
    local t = typeof(v)
    if t == "table" then
        local out = {}
        local n = 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 40 then out["..."] = "truncated"; break end
            out[tostring(k)] = (typeof(val) == "table") and "(table)" or tostring(val):sub(1, 80)
        end
        local ok, s = pcall(function() return HttpService:JSONEncode(out) end)
        return ok and s or tostring(v)
    end
    return tostring(v)
end

local INTEREST = {
    jobid = true, job_id = true, placeid = true, place_id = true,
    gameid = true, game_id = true, gameinstanceid = true, instanceid = true,
    userid = true, user_id = true, visitorid = true, experienceid = true,
    universeid = true, rootplaceid = true, launchdata = true, linkid = true,
    inviteid = true, notificationid = true, senderuserid = true,
}

local function harvestValue(key, val, into)
    local lk = string.lower(tostring(key or ""))
    local sv = tostring(val)
    if INTEREST[lk] or lk:find("job", 1, true) or lk:find("place", 1, true)
        or lk:find("invite", 1, true) or lk:find("instance", 1, true) then
        into[lk] = sv
        say("FOUND " .. lk .. "=" .. sv:sub(1, 100))
        if (lk:find("job", 1, true) or lk == "gameid" or lk == "gameinstanceid" or lk == "instanceid")
            and sv:find("-") and #sv > 20 then
            S.last = S.last or {}
            S.last.jobId = sv
            copyText(sv)
            say("คัดลอก JobId แล้ว")
        end
        if lk:find("place", 1, true) and tonumber(sv) then
            S.last = S.last or {}
            S.last.placeId = tonumber(sv)
        end
        if lk:find("user", 1, true) and tonumber(sv) then
            S.last = S.last or {}
            S.last.userId = tonumber(sv)
        end
    end
    if typeof(val) == "table" then
        for k2, v2 in pairs(val) do
            harvestValue(k2, v2, into)
        end
    end
end

local function dumpUpvalues(fn, tag)
    if type(fn) ~= "function" then return end
    local dug = {}
    -- debug.getupvalue
    if debug and debug.getupvalue then
        for i = 1, 40 do
            local ok, n, v = pcall(debug.getupvalue, fn, i)
            if not ok or n == nil then break end
            say(string.format("%s up%d %s=%s", tag, i, tostring(n), safeJson(v):sub(1, 120)))
            harvestValue(n, v, dug)
        end
    end
    -- getupvalue / getupvalues (executor)
    if getupvalues then
        local ok, ups = pcall(getupvalues, fn)
        if ok and type(ups) == "table" then
            for k, v in pairs(ups) do
                say(string.format("%s getup[%s]=%s", tag, tostring(k), safeJson(v):sub(1, 120)))
                harvestValue(k, v, dug)
            end
        end
    end
    if getconstants then
        local ok, cs = pcall(getconstants, fn)
        if ok and type(cs) == "table" then
            for i, c in ipairs(cs) do
                local s = tostring(c)
                if #s > 2 and #s < 100 then
                    if s:find("-") and #s > 30 then
                        say(tag .. " const GUID " .. s)
                        harvestValue("jobId", s, dug)
                    elseif INTEREST[string.lower(s)] then
                        say(tag .. " const key " .. s)
                    end
                end
            end
        end
    end
    return dug
end

local function dumpConnections(btn, tag)
    if not getconnections then
        say("ไม่มี getconnections")
        return
    end
    for _, evName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }) do
        local ev = btn[evName]
        if not ev then -- skip
        else
            local ok, cons = pcall(getconnections, ev)
            if ok and cons then
                say(tag .. " " .. evName .. " x" .. #cons)
                for i, con in ipairs(cons) do
                    local fn = con.Function or con.fn
                    pcall(function()
                        if con.Fire then -- some expose
                        end
                    end)
                    dumpUpvalues(fn, tag .. "." .. evName .. "#" .. i)
                end
            end
        end
    end
end

local function allTextUnder(root)
    local lines = {}
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local t = tostring(d.Text or "")
            if t ~= "" and #t < 200 then
                table.insert(lines, t)
                say("TXT " .. t)
            end
        end
    end
    return table.concat(lines, " | ")
end

local function dumpAttrsDeep(root)
    for _, d in ipairs(root:GetDescendants()) do
        pcall(function()
            for _, a in ipairs(d:GetAttributes()) do
                local v = d:GetAttribute(a)
                say("ATTR " .. d.Name .. "." .. a .. "=" .. tostring(v))
                harvestValue(a, v, {})
            end
        end)
        if d:IsA("ValueBase") or d:IsA("ObjectValue") then
            local v
            pcall(function() v = d.Value end)
            say("VAL " .. d.ClassName .. "." .. d.Name .. "=" .. tostring(v))
            harvestValue(d.Name, v, {})
        end
    end
end

local function presenceOf(userId)
    userId = tonumber(userId)
    if not userId then return nil end
    local req = httpReq()
    if not req then say("ไม่มี request"); return nil end
    local ok, res = pcall(function()
        return req({
            Url = "https://presence.roblox.com/v1/presence/users",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json", ["Accept"] = "application/json" },
            Body = HttpService:JSONEncode({ userIds = { userId } }),
        })
    end)
    if not ok or type(res) ~= "table" then say("presence พัง " .. tostring(res)); return nil end
    local data
    pcall(function() data = HttpService:JSONDecode(res.Body or "") end)
    local u = data and data.userPresences and data.userPresences[1]
    if not u then say("ไม่มี presence body"); return nil end
    say("presence raw=" .. safeJson(u):sub(1, 200))
    local job = tostring(u.gameId or u.GameId or "")
    local place = u.placeId or u.PlaceId or u.rootPlaceId
    S.last = { userId = userId, placeId = place, jobId = job, raw = u }
    if job:find("-") then
        copyText(job)
        say("JobId จาก presence: " .. job)
    else
        say("gameId ไม่ใช่ GUID: " .. job)
    end
    return S.last
end

local function resolveNameToPresence(name)
    if not name or #name < 2 then return end
    say("แปลงชื่อ → UserId: " .. name)
    local ok, uid = pcall(function()
        return Players:GetUserIdFromNameAsync(name)
    end)
    if not ok or not uid then
        say("หา UserId ไม่ได้: " .. tostring(uid))
        return
    end
    say("UserId=" .. tostring(uid))
    if S.input then S.input.Text = tostring(uid) end
    return presenceOf(uid)
end

local function parseInviterFromText(blob)
    -- "Timmy15z" เชิญคุณ / Timmy15z @Bigkun15z
    local q = blob:match('"([^"]+)"%s*เชิญ') or blob:match("([%w_]+)%s*เชิญ")
    if q then return q end
    local at = blob:match("([%w_]+)%s*@")
    return at
end

local function inspectCard(card)
    local id = card:GetFullName()
    if S.seenCard[id] then return end
    S.seenCard[id] = true
    say("=== NotificationCard ===")
    local blob = allTextUnder(card)
    dumpAttrsDeep(card)
    local name = parseInviterFromText(blob)
    if name then
        say("ชื่อผู้เชิญจาก toast: " .. name)
        task.spawn(resolveNameToPresence, name)
    end
    -- ปุ่ม ActionButtons
    local actions = card:FindFirstChild("NotificationActionsFrame", true)
    local btns = actions and actions:FindFirstChild("ActionButtons", true)
    if not btns then
        -- path จากภาพ
        btns = card:FindFirstChild("ActionButtons", true)
    end
    if btns then
        for _, b in ipairs(btns:GetChildren()) do
            if b:IsA("GuiButton") or b:IsA("ImageButton") or b:IsA("TextButton") then
                say("ปุ่ม " .. b.Name .. " " .. b.ClassName)
                dumpConnections(b, "BTN." .. b.Name)
                if not S.hookedBtns[b] then
                    S.hookedBtns[b] = true
                    local function onClick()
                        say("=== กด " .. b.Name .. " ===")
                        dumpConnections(b, "CLICK." .. b.Name)
                        dumpAttrsDeep(card)
                    end
                    pcall(function() b.Activated:Connect(onClick) end)
                    pcall(function() b.MouseButton1Click:Connect(onClick) end)
                end
            end
        end
    end
end

local function findToastCards()
    local cg = game:GetService("CoreGui")
    local toast = cg:FindFirstChild("ToastNotification")
    if not toast then
        say("ยังไม่มี ToastNotification")
        return
    end
    for _, d in ipairs(toast:GetDescendants()) do
        if d.Name == "NotificationCard" then
            inspectCard(d)
        end
    end
end

local function installTeleportHook()
    if S._tpHook or not hookmetamethod or not getnamecallmethod then return end
    S._tpHook = true
    local old
    local function onTp(method, args)
        say("TP " .. method .. " " .. safeJson(args):sub(1, 200))
        for i, a in ipairs(args) do
            harvestValue("arg" .. i, a, {})
            local s = tostring(a)
            if s:find("-") and #s > 20 then
                say("TP JobId=" .. s)
                copyText(s)
                S.last = S.last or {}
                S.last.jobId = s
                if typeof(args[1]) == "number" then S.last.placeId = args[1] end
            end
            if typeof(a) == "Instance" and a.ClassName == "TeleportOptions" then
                pcall(function()
                    harvestValue("ServerInstanceId", a.ServerInstanceId, {})
                end)
            end
        end
    end
    local wrapper = function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }
        -- ห้ามเรียก namecall อื่นก่อน old — จะทำให้ method เพี้ยนเป็น JSONEncode
        if typeof(self) == "Instance" and self == TeleportService then
            local m = tostring(method)
            if m:find("Teleport", 1, true) then
                task.defer(onTp, m, args)
            end
        end
        return old(self, ...)
    end
    if newcclosure then wrapper = newcclosure(wrapper) end
    old = hookmetamethod(game, "__namecall", wrapper)
    say("Teleport hook ON (defer-safe)")
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
f.Size = UDim2.new(0, 420, 0, 250)
f.Position = UDim2.new(0, 12, 0, 160)
f.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -40, 0, 22)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Invite Spy v1.3 — JobId จาก toast OK"
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

S.input = Instance.new("TextBox", f)
S.input.Size = UDim2.new(0, 150, 0, 26)
S.input.Position = UDim2.new(0, 10, 0, 32)
S.input.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
S.input.BorderSizePixel = 0
S.input.PlaceholderText = "Friend UserId"
S.input.Text = "4881914385"
S.input.TextColor3 = Color3.new(1, 1, 1)
S.input.Font = Enum.Font.Code
S.input.TextSize = 12
Instance.new("UICorner", S.input).CornerRadius = UDim.new(0, 5)

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

local scanB = mk("DUMP CARD", 168, 88, Color3.fromRGB(40, 145, 75))
local nowB = mk("PRESENCE", 262, 72, Color3.fromRGB(70, 110, 180))
local joinB = mk("JOIN", 340, 60, Color3.fromRGB(150, 100, 40))

S.logBox = Instance.new("TextLabel", f)
S.logBox.Size = UDim2.new(1, -16, 0, 178)
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

scanB.MouseButton1Click:Connect(function()
    S.seenCard = {}
    findToastCards()
end)

nowB.MouseButton1Click:Connect(function()
    presenceOf(tonumber(S.input.Text))
end)

joinB.MouseButton1Click:Connect(function()
    if not S.last or not S.last.jobId or not tostring(S.last.jobId):find("-") then
        say("ยังไม่มี JobId GUID — DUMP CARD หรือ PRESENCE ก่อน")
        return
    end
    local place = S.last.placeId or game.PlaceId
    say("JOIN " .. tostring(place) .. " / " .. S.last.jobId)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(place, S.last.jobId)
    end)
    if not ok then say("JOIN ล้ม: " .. tostring(err)) end
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_INVITE_SPY = nil
end)

installTeleportHook()

-- auto: รอ ToastNotification โผล่
task.spawn(function()
    local cg = game:GetService("CoreGui")
    local function watch(toast)
        toast.DescendantAdded:Connect(function(d)
            if d.Name == "NotificationCard" then
                task.defer(function()
                    task.wait(0.15)
                    inspectCard(d)
                end)
            end
        end)
        for _, d in ipairs(toast:GetDescendants()) do
            if d.Name == "NotificationCard" then
                task.defer(inspectCard, d)
            end
        end
    end
    local t0 = cg:FindFirstChild("ToastNotification")
    if t0 then watch(t0) end
    cg.ChildAdded:Connect(function(ch)
        if ch.Name == "ToastNotification" then watch(ch) end
    end)
    while S.gui and S.gui.Parent do
        pcall(findToastCards)
        task.wait(3)
    end
end)

say("v1.3 — กดเข้าร่วมบน toast → จับ JobId (JOIN แก้แล้ว)")
say("JobId ที่เคยจับได้: e37dfd64-b527-4295-b677-cf1d3f6251c3")
