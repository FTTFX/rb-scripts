-- Egg01 Invite Spy v1.1
-- ดัก toast เชิญด้านบน + ปุ่มตกลง/Join → หา PlaceId/JobId/UserId ที่ซ่อน
-- + presence API (client) แทน GetPlayerPlaceInstanceAsync (server-only)

if _G.EGG01_INVITE_SPY then
    pcall(function() _G.EGG01_INVITE_SPY.gui:Destroy() end)
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local S = {
    gui = nil,
    watch = {},
    last = nil,
    log = {},
    hookedBtns = {},
    seenSig = {},
}
_G.EGG01_INVITE_SPY = S

local function say(t)
    t = tostring(t)
    table.insert(S.log, 1, os.date("%H:%M:%S") .. " " .. t)
    while #S.log > 14 do table.remove(S.log) end
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

local function safeJson(v)
    local ok, s = pcall(function() return HttpService:JSONEncode(v) end)
    return ok and s or tostring(v)
end

-- —— dump ค่าที่อาจซ่อนใน Instance ——
local function dumpInst(inst, tag)
    if not inst or not inst.Parent then return end
    local bits = {}
    table.insert(bits, (tag or "INST") .. " " .. inst.ClassName .. " " .. inst:GetFullName())
    if inst:IsA("GuiObject") then
        local txt = ""
        pcall(function()
            if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
                txt = tostring(inst.Text)
            end
        end)
        if txt ~= "" then table.insert(bits, "Text=" .. txt:sub(1, 100)) end
    end
    pcall(function()
        for _, a in ipairs(inst:GetAttributes()) do
            table.insert(bits, "attr." .. a .. "=" .. tostring(inst:GetAttribute(a)))
        end
    end)
    for _, ch in ipairs(inst:GetChildren()) do
        if ch:IsA("ValueBase") or ch:IsA("StringValue") or ch:IsA("IntValue") or ch:IsA("NumberValue")
            or ch:IsA("ObjectValue") or ch:IsA("BoolValue") then
            local v = nil
            pcall(function() v = ch.Value end)
            table.insert(bits, ch.ClassName .. "." .. ch.Name .. "=" .. tostring(v))
        end
    end
    -- getconnections บนปุ่ม
    if (inst:IsA("GuiButton") or inst:IsA("TextButton") or inst:IsA("ImageButton")) and getconnections then
        for _, evName in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down" }) do
            local ev = inst[evName]
            if ev then
                local ok, cons = pcall(getconnections, ev)
                if ok and cons then
                    for i, con in ipairs(cons) do
                        local info = {}
                        pcall(function() info.fn = tostring(con.Function) end)
                        pcall(function() info.foreign = tostring(con.ForeignState) end)
                        -- บาง executor มี con.Function แล้ว dump upvalues
                        if con.Function and debug and debug.getupvalue then
                            for ui = 1, 12 do
                                local okU, n, v = pcall(debug.getupvalue, con.Function, ui)
                                if not okU or n == nil then break end
                                local sv = tostring(v)
                                if #sv > 0 and #sv < 120 then
                                    table.insert(bits, string.format("up[%s.%d]%s=%s", evName, ui, tostring(n), sv))
                                end
                            end
                        end
                        table.insert(bits, evName .. "#" .. i)
                    end
                end
            end
        end
    end
    say(table.concat(bits, " | "):sub(1, 220))
end

local BTN_KEYS = { "ตกลง", "join", "accept", "ok", "yes", "เล่น", "เข้า", "ไป", "confirm" }
local TOAST_KEYS = { "เชิญ", "invite", "invited", "ชวน", "wants you", "asked you" }

local function textOf(inst)
    local t = ""
    pcall(function()
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            t = tostring(inst.Text or "")
        end
    end)
    return t
end

local function isInviteToastRoot(gui)
    local blob = ""
    for _, d in ipairs(gui:GetDescendants()) do
        local t = textOf(d)
        if t ~= "" then blob = blob .. "\n" .. t end
    end
    local low = string.lower(blob)
    for _, k in ipairs(TOAST_KEYS) do
        if string.find(low, string.lower(k), 1, true) then
            return true, blob
        end
    end
    return false, blob
end

local function hookAcceptButton(btn, toastRoot)
    if S.hookedBtns[btn] then return end
    S.hookedBtns[btn] = true
    say("HOOK ปุ่ม: " .. textOf(btn) .. " @ " .. btn:GetFullName():sub(-60))
    dumpInst(btn, "BTN")
    if toastRoot then dumpInst(toastRoot, "TOAST") end
    -- dump ทั้งต้น toast หา Value / attribute
    if toastRoot then
        for _, d in ipairs(toastRoot:GetDescendants()) do
            if d:IsA("ValueBase") or d:IsA("ObjectValue") then
                dumpInst(d, "VAL")
            end
            local attrs = {}
            pcall(function() attrs = d:GetAttributes() end)
            if attrs and #attrs > 0 then
                dumpInst(d, "ATTR")
            end
        end
    end
    local function onClick()
        say("=== กดปุ่มตกลง/Join แล้ว — dump รอบกด ===")
        dumpInst(btn, "CLICK")
        if toastRoot then
            for _, d in ipairs(toastRoot:GetDescendants()) do
                local t = textOf(d)
                if t ~= "" and #t < 120 then say("TXT " .. t) end
                pcall(function()
                    for _, a in ipairs(d:GetAttributes()) do
                        say("A " .. d.Name .. "." .. a .. "=" .. tostring(d:GetAttribute(a)))
                    end
                end)
            end
        end
    end
    pcall(function() btn.MouseButton1Click:Connect(onClick) end)
    pcall(function() btn.Activated:Connect(onClick) end)
end

local function scanToasts()
    local roots = {}
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    pcall(function() table.insert(roots, LP:FindFirstChild("PlayerGui")) end)
    for _, root in ipairs(roots) do
        if root then
        for _, gui in ipairs(root:GetDescendants()) do
            if gui:IsA("Frame") or gui:IsA("ScreenGui") or gui:IsA("BillboardGui") or gui:IsA("CanvasGroup") then
                local okInvite, blob = isInviteToastRoot(gui)
                if okInvite and #gui:GetDescendants() < 80 then
                    local sig = (blob:gsub("%s+", " ")):sub(1, 80)
                    if not S.seenSig[sig] then
                        S.seenSig[sig] = true
                        say("เจอ toast เชิญ: " .. sig)
                        dumpInst(gui, "ROOT")
                    end
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("GuiButton") or d:IsA("TextButton") or d:IsA("ImageButton") then
                            local t = string.lower(textOf(d))
                            local hit = false
                            for _, k in ipairs(BTN_KEYS) do
                                if t ~= "" and string.find(t, string.lower(k), 1, true) then
                                    hit = true
                                    break
                                end
                            end
                            if hit or (t == "" and d.AbsoluteSize.X > 40) then
                                hookAcceptButton(d, gui)
                            end
                        end
                    end
                end
            end
        end
        end
    end
end

-- ดัก Teleport ตอนกดตกลง (ถ้า CoreGui เรียก Teleport*)
local function installTeleportHook()
    if S._tpHook then return end
    if not hookmetamethod or not getnamecallmethod then
        say("ไม่มี hookmetamethod — ข้าม Teleport hook")
        return
    end
    S._tpHook = true
    local old
    local wrapper = function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }
        if self == TeleportService or (typeof(self) == "Instance" and self.ClassName == "TeleportService") then
            local m = tostring(method)
            if m:find("Teleport", 1, true) then
                say("TP CALL " .. m .. " args=" .. safeJson(args):sub(1, 180))
                for i, a in ipairs(args) do
                    local s = tostring(a)
                    if s:find("-", 1, true) and #s > 20 then
                        say("TP Job? arg" .. i .. "=" .. s)
                        copyText(s)
                        S.last = { jobId = s, placeId = args[1] }
                    end
                end
                if typeof(args[1]) == "Instance" and args[1].ClassName == "TeleportOptions" then
                    pcall(function()
                        say("TP ServerInstanceId=" .. tostring(args[1].ServerInstanceId))
                        if args[1].ServerInstanceId and args[1].ServerInstanceId ~= "" then
                            copyText(args[1].ServerInstanceId)
                        end
                    end)
                end
            end
        end
        return old(self, ...)
    end
    if newcclosure then wrapper = newcclosure(wrapper) end
    old = hookmetamethod(game, "__namecall", wrapper)
    say("Teleport hook ติดแล้ว — กดตกลงบน toast จะโชว์ args")
end

-- presence API (client HTTP) — ได้ jobId ของเพื่อน
local function presenceOf(userId)
    userId = tonumber(userId)
    if not userId then return nil, "UserId ไม่ถูกต้อง" end
    local req = httpReq()
    if not req then return nil, "ไม่มี request" end
    local ok, res = pcall(function()
        return req({
            Url = "https://presence.roblox.com/v1/presence/users",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json", ["Accept"] = "application/json" },
            Body = HttpService:JSONEncode({ userIds = { userId } }),
        })
    end)
    if not ok or type(res) ~= "table" then return nil, tostring(res) end
    local body = res.Body or ""
    local data
    pcall(function() data = HttpService:JSONDecode(body) end)
    local u = data and data.userPresences and data.userPresences[1]
    if not u then return nil, "ไม่มี presence: " .. body:sub(1, 100) end
    -- gameId ใน presence มักเป็น JobId (GUID)
    local job = u.gameId or u.GameId
    local place = u.placeId or u.PlaceId
    local root = u.rootPlaceId or u.RootPlaceId
    say(string.format("presence uid=%s place=%s root=%s gameId=%s type=%s",
        tostring(userId), tostring(place), tostring(root), tostring(job), tostring(u.userPresenceType)))
    if job and tostring(job):find("-") then
        S.last = { userId = userId, placeId = place or root, jobId = tostring(job) }
        copyText(tostring(job))
        say("คัดลอก JobId จาก presence แล้ว")
        return S.last
    end
    -- ลอง GetFriendsOnline สำรอง
    local okF, list = pcall(function() return LP:GetFriendsOnline(200) end)
    if okF and type(list) == "table" then
        for _, f in ipairs(list) do
            local id = f.VisitorId or f.UserId or f.Id
            if tonumber(id) == userId then
                say("FriendsOnline: " .. safeJson(f):sub(1, 200))
                local g = f.GameId or f.gameId
                local p = f.PlaceId or f.placeId
                if g and tostring(g):find("-") then
                    S.last = { userId = userId, placeId = p, jobId = tostring(g) }
                    copyText(tostring(g))
                    return S.last
                end
            end
        end
    end
    return { userId = userId, placeId = place, jobId = job, raw = u }, "gameId อาจไม่ใช่ JobId"
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
f.Size = UDim2.new(0, 400, 0, 240)
f.Position = UDim2.new(0, 12, 0, 180)
f.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -40, 0, 22)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Invite Spy v1.1 — ดัก toast / ปุ่มตกลง"
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
input.Size = UDim2.new(0, 150, 0, 26)
input.Position = UDim2.new(0, 10, 0, 32)
input.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
input.BorderSizePixel = 0
input.PlaceholderText = "Friend UserId"
input.Text = "4881914385"
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

local scanB = mk("SCAN TOAST", 168, 90, Color3.fromRGB(40, 145, 75))
local nowB = mk("PRESENCE", 264, 72, Color3.fromRGB(70, 110, 180))
local joinB = mk("JOIN", 342, 48, Color3.fromRGB(150, 100, 40))

S.logBox = Instance.new("TextLabel", f)
S.logBox.Size = UDim2.new(1, -16, 0, 168)
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
    S.seenSig = {}
    say("สแกน toast...")
    scanToasts()
    say("สแกนจบ — ถ้ามีปุ่มตกลง จะ hook แล้ว")
end)

nowB.MouseButton1Click:Connect(function()
    local id = tonumber(input.Text)
    if not id then say("ใส่ UserId"); return end
    presenceOf(id)
end)

joinB.MouseButton1Click:Connect(function()
    if not S.last or not S.last.jobId then
        say("ยังไม่มี JobId — กด PRESENCE หรือรอ hook ตอนกดตกลง")
        return
    end
    local place = S.last.placeId or game.PlaceId
    say("JOIN place=" .. tostring(place) .. " job=" .. S.last.jobId)
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

task.spawn(function()
    while S.gui and S.gui.Parent do
        pcall(scanToasts)
        task.wait(2)
    end
end)

say("v1.1 พร้อม — ให้เพื่อนเชิญ → toast โผล่ → สคริปต์ดักปุ่มตกลง")
say("หรือกด PRESENCE ด้วย UserId เพื่อน (ไม่ใช้ GetPlayerPlaceInstance)")
