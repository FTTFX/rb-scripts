-- Egg01_TreadGainMatrix v1.0
-- เทียบโหมดเคลื่อนไหวบนลู่ → หาว่าอะไรเร่ง leaderstats.Speed (WS×2 ยืนยันแล้วว่าไม่ส่งผล)

if _G.EGG01_TREADGAIN then
    _G.EGG01_TREADGAIN.abort = true
    _G.EGG01_TREADGAIN.busy = false
    pcall(function() _G.EGG01_TREADGAIN.gui:Destroy() end)
end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local SAMPLE_SEC     = 10
local POLL_HZ        = 0.05
local ARRIVE_DIST    = 5
local STATIONARY_EPS = 2.0
local ORBIT_R        = 1.2
local JOG_SLOW_WAIT  = 0.35
local JOG_FAST_WAIT  = 0.12
local MICRO_OFFSET   = 1.0
local JUMP_EVERY     = 0.40
local SPEED_MULT     = 2.00
local TREAD_NAME     = "TreadmillBottom"
local GUI_NAME       = "Egg01_TreadGainMatrix"
local DISPLAY_ORDER  = 1011
local GO_TIMEOUT     = 35
local PASS_RATIO     = 1.10

local MODES = {
    { id = "stand_brake", label = "Stand+Brake" },
    { id = "jog_slow",    label = "Jog slow" },
    { id = "jog_fast",    label = "Jog fast" },
    { id = "micro",       label = "MicroStep" },
    { id = "nobrake",     label = "NoBrake" },
    { id = "jump",        label = "JumpPulse" },
    { id = "ws2_lock",    label = "WS×2 lock" },
}

local S = {
    abort = false,
    busy = false,
    gui = nil,
    baseWS = nil,
    lockedBottom = nil,
    modeIdx = 1,
    results = {},
    baselineRate = nil,
}
_G.EGG01_TREADGAIN = S

local function parts()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function readScore()
    local stats = LP:FindFirstChild("leaderstats")
    if stats then
        for _, name in ipairs({ "Speed", "Steps", "Step", "Miles", "Distance", "Studs" }) do
            local v = stats:FindFirstChild(name)
            if v then
                local n = tonumber(v.Value)
                if n then return n, name end
            end
        end
        for _, c in ipairs(stats:GetChildren()) do
            if c:IsA("NumberValue") or c:IsA("IntValue") or c:IsA("StringValue") then
                local n = tonumber(c.Value)
                if n then return n, c.Name end
            end
        end
    end
    local pd = LP:FindFirstChild("PlayerData") or LP:FindFirstChild("Data")
    if pd then
        for _, name in ipairs({ "Speed", "Steps", "Step" }) do
            local v = pd:FindFirstChild(name, true)
            if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
                return tonumber(v.Value), name
            end
        end
    end
    return nil, nil
end

local function stepRate(bottom)
    if not bottom then return 0 end
    local root = bottom
    for _ = 1, 8 do
        if not root.Parent or root.Parent == workspace then break end
        root = root.Parent
    end
    local rate = 0
    local ok, desc = pcall(function() return root:GetDescendants() end)
    if not ok or not desc then return 0 end
    for _, d in ipairs(desc) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local t = tostring(d.Text or ""):gsub(",", ""):gsub("%s", "")
            local n = t:match("%+?(%d+)/step") or t:match("%+?(%d+)/Step")
            if n then rate = math.max(rate, tonumber(n) or 0) end
        end
    end
    return rate
end

local function nearestTreadmill()
    local _, root = parts()
    if not root then return nil end
    local best, bestD, bestRate
    local ok, desc = pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return nil end
    for _, item in ipairs(desc) do
        if item:IsA("BasePart") and item.Name == TREAD_NAME then
            local d = (item.Position - root.Position).Magnitude
            local rate = stepRate(item)
            if not best
                or rate > (bestRate or 0)
                or (rate == (bestRate or 0) and d < (bestD or 1e9)) then
                best, bestD, bestRate = item, d, rate
            end
        end
    end
    return best, bestD, bestRate or 0
end

local function standPos(bottom)
    if not bottom then return nil end
    return bottom.CFrame:PointToWorldSpace(Vector3.new(0, bottom.Size.Y * 0.5 + 2.5, 0))
end

local function brake(hum, root)
    if not root or not root.Parent then return end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    if hum and hum.Parent then
        hum:Move(Vector3.zero)
        pcall(function() hum:MoveTo(root.Position) end)
    end
end

local function restoreWalkSpeed()
    if S.baseWS and S.baseWS > 0 then
        local hum = select(1, parts())
        if hum and hum.Parent then hum.WalkSpeed = S.baseWS end
    end
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.DisplayOrder = DISPLAY_ORDER
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
S.gui = gui

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 380, 0, 340)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 9)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -45, 0, 22)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(30, 30, 35)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 TreadGain Matrix"

local function mkBtn(text, x, y, color, w)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w or 86, 0, 24)
    b.Position = UDim2.new(0, x, 0, y)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(30, 30, 35)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bGo   = mkBtn("ไปลู่", 10, 28, Color3.fromRGB(35, 145, 75), 70)
local bLock = mkBtn("ล็อคลู่", 86, 28, Color3.fromRGB(120, 90, 40), 70)
local bStop = mkBtn("STOP", 162, 28, Color3.fromRGB(185, 60, 60), 60)
local bX    = mkBtn("X", 340, 28, Color3.fromRGB(185, 60, 60), 28)

local bPrev = mkBtn("<", 10, 56, Color3.fromRGB(180, 180, 190), 28)
local bMode = mkBtn(MODES[1].label, 42, 56, Color3.fromRGB(70, 130, 220), 140)
local bNext = mkBtn(">", 186, 56, Color3.fromRGB(180, 180, 190), 28)
local bRun  = mkBtn("รันโหมด", 220, 56, Color3.fromRGB(70, 130, 220), 72)
local bAuto = mkBtn("ออโต้ทั้งชุด", 298, 56, Color3.fromRGB(35, 145, 75), 70)

local status = Instance.new("TextLabel", panel)
status.Size = UDim2.new(1, -20, 0, 48)
status.Position = UDim2.new(0, 10, 0, 86)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(55, 55, 60)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "WS×2 ไม่ส่งผล — ทดสอบโหมดจ๊อก/ก้าว/กระโดด บนลู่เดิม"

local result = Instance.new("TextLabel", panel)
result.Size = UDim2.new(1, -20, 0, 150)
result.Position = UDim2.new(0, 10, 0, 136)
result.BackgroundTransparency = 1
result.TextColor3 = Color3.fromRGB(30, 30, 35)
result.Font = Enum.Font.Code
result.TextSize = 10
result.TextXAlignment = Enum.TextXAlignment.Left
result.TextYAlignment = Enum.TextYAlignment.Top
result.TextWrapped = true
result.Text = "—"

local spy = Instance.new("TextLabel", panel)
spy.Size = UDim2.new(1, -20, 0, 36)
spy.Position = UDim2.new(0, 10, 0, 290)
spy.BackgroundTransparency = 1
spy.TextColor3 = Color3.fromRGB(90, 90, 95)
spy.Font = Enum.Font.Gotham
spy.TextSize = 10
spy.TextWrapped = true
spy.TextXAlignment = Enum.TextXAlignment.Left
spy.Text = "stat=? | +?/step | WS=? | mode=?"

local function say(t) status.Text = tostring(t) end

local function refreshModeBtn()
    local m = MODES[S.modeIdx]
    bMode.Text = m and m.label or "?"
end

local function setBusy(v)
    S.busy = v
    bRun.Text = v and "…" or "รันโหมด"
    bAuto.Text = v and "…" or "ออโต้ทั้งชุด"
end

local function refreshResultPanel()
    if #S.results == 0 then result.Text = "—"; return end
    local lines = {}
    local ranked = {}
    for _, r in ipairs(S.results) do ranked[#ranked + 1] = r end
    table.sort(ranked, function(a, b) return (a.rate or 0) > (b.rate or 0) end)
    local base = S.baselineRate
    for i, r in ipairs(ranked) do
        local ratio = (base and base > 0) and (r.rate / base) or 0
        local tag = "WEAK"
        if base and math.abs(base) < 1 and math.abs(r.rate) < 1 then
            tag = "ZERO"
        elseif ratio >= PASS_RATIO then
            tag = "PASS"
        elseif ratio < 0.90 then
            tag = "WORSE"
        end
        lines[#lines + 1] = string.format("%d. %s  Δ=%.0f  %.0f/s  ×%.2f %s",
            i, r.label, r.delta or 0, r.rate or 0, ratio, tag)
    end
    result.Text = table.concat(lines, "\n")
end

-- ===== travel =====
local function ensureOnTread(timeout)
    local bottom = S.lockedBottom
    if not bottom or not bottom.Parent then
        local b, d, rate = nearestTreadmill()
        if not b then say("ไม่พบ " .. TREAD_NAME); return false end
        bottom = b
        S.lockedBottom = b
        say(string.format("ล็อคลู่ +%s/step d=%.0f", tostring(rate > 0 and rate or "?"), d or -1))
    end
    local target = standPos(bottom)
    if not target then return false end
    local deadline = os.clock() + (timeout or GO_TIMEOUT)
    while S.busy and not S.abort and os.clock() < deadline do
        local hum, root = parts()
        if not hum or not root or hum.Health <= 0 then return false end
        local goal = Vector3.new(target.X, root.Position.Y, target.Z)
        local d = (goal - root.Position).Magnitude
        if d <= ARRIVE_DIST then return true end
        hum:MoveTo(goal)
        say(string.format("ไปลู่ d=%.0f", d))
        task.wait(0.35)
    end
    local _, root = parts()
    if root and target then
        return (Vector3.new(target.X, root.Position.Y, target.Z) - root.Position).Magnitude <= ARRIVE_DIST
    end
    return false
end

-- ===== sample one mode =====
local function runMode(mode)
    local hum, root = parts()
    if not hum or not root or hum.Health <= 0 then
        say("FAIL: ไม่มีตัวละคร"); return nil
    end
    if not S.baseWS then S.baseWS = hum.WalkSpeed end
    local bottom = S.lockedBottom
    if not bottom or not bottom.Parent then
        say("FAIL: ยังไม่ล็อคลู่ — กดไปลู่/ล็อคลู่ก่อน"); return nil
    end
    local score0, scoreName = readScore()
    if score0 == nil then say("FAIL: อ่านคะแนนไม่ได้"); return nil end
    local spr = stepRate(bottom)
    local ws0 = hum.WalkSpeed
    local anchor = Vector3.new(root.Position.X, 0, root.Position.Z)
    local t0 = os.clock()
    local moved = false
    local n = 0
    local lastJump = 0
    local microFlip = false
    local lastJog = 0

    while S.busy and not S.abort and os.clock() - t0 < SAMPLE_SEC do
        hum, root = parts()
        if not hum or not root or hum.Health <= 0 then say("FAIL: ตายระหว่างวัด"); return nil end
        local now = os.clock()
        local id = mode.id

        if id == "ws2_lock" then
            hum.WalkSpeed = S.baseWS * SPEED_MULT
        end

        if id == "stand_brake" or id == "ws2_lock" then
            brake(hum, root)
        elseif id == "nobrake" then
            -- ไม่ทำอะไร
        elseif id == "jog_slow" or id == "jog_fast" then
            local waitT = (id == "jog_fast") and JOG_FAST_WAIT or JOG_SLOW_WAIT
            if now - lastJog >= waitT then
                lastJog = now
                local offset = Vector3.new(math.sin(n) * ORBIT_R, bottom.Size.Y * 0.5 + 2.5, math.cos(n) * ORBIT_R)
                local step = bottom.CFrame:PointToWorldSpace(offset)
                hum:MoveTo(Vector3.new(step.X, root.Position.Y, step.Z))
                n = n + math.pi * 0.5
            end
        elseif id == "micro" then
            microFlip = not microFlip
            local ox = microFlip and MICRO_OFFSET or -MICRO_OFFSET
            local base = standPos(bottom) or root.Position
            hum:MoveTo(Vector3.new(base.X + ox, root.Position.Y, base.Z))
        elseif id == "jump" then
            -- เบรค XZ เบา + กระโดดเป็นจังหวะ
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
            root.AssemblyAngularVelocity = Vector3.zero
            if now - lastJump >= JUMP_EVERY then
                lastJump = now
                hum.Jump = true
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end
        end

        local pos = root.Position
        if Vector3.new(pos.X - anchor.X, 0, pos.Z - anchor.Z).Magnitude > STATIONARY_EPS then
            moved = true
        end
        local sc = readScore()
        local delta = sc and (sc - score0) or 0
        local remain = SAMPLE_SEC - (now - t0)
        say(string.format("[%s] %.1fs  Δ=%.0f  WS=%.1f", mode.label, remain, delta, hum.WalkSpeed))
        spy.Text = string.format("stat=%s | +%s/step | WS=%.1f | mode=%s",
            scoreName or "?", tostring(spr > 0 and spr or "?"), hum.WalkSpeed, mode.id)
        task.wait(POLL_HZ)
    end

    if S.abort then say("ยกเลิก"); restoreWalkSpeed(); return nil end
    local score1 = readScore()
    if score1 == nil then say("FAIL: อ่านคะแนนจบไม่ได้"); restoreWalkSpeed(); return nil end
    local ws1 = select(1, parts()) and select(1, parts()).WalkSpeed or ws0
    if mode.id == "ws2_lock" then restoreWalkSpeed() end

    return {
        id = mode.id,
        label = mode.label,
        sampleSec = SAMPLE_SEC,
        scoreName = scoreName,
        scoreStart = score0,
        scoreEnd = score1,
        delta = score1 - score0,
        rate = (score1 - score0) / SAMPLE_SEC,
        walkSpeedStart = ws0,
        walkSpeedEnd = ws1,
        stepPerStep = spr,
        moved = moved,
        ok = true,
    }
end

local function storeResult(res)
    if not res then return end
    -- แทนที่ผลโหมดเดิมถ้ามี
    for i, old in ipairs(S.results) do
        if old.id == res.id then
            S.results[i] = res
            if res.id == "stand_brake" then S.baselineRate = res.rate end
            refreshResultPanel()
            print(string.format("[TreadGain] %s Δ=%.0f rate=%.0f/s WS=%.1f→%.1f +%s/step moved=%s",
                res.label, res.delta, res.rate, res.walkSpeedStart, res.walkSpeedEnd,
                tostring(res.stepPerStep), tostring(res.moved)))
            return
        end
    end
    S.results[#S.results + 1] = res
    if res.id == "stand_brake" then S.baselineRate = res.rate end
    refreshResultPanel()
    print(string.format("[TreadGain] %s Δ=%.0f rate=%.0f/s WS=%.1f→%.1f +%s/step moved=%s",
        res.label, res.delta, res.rate, res.walkSpeedStart, res.walkSpeedEnd,
        tostring(res.stepPerStep), tostring(res.moved)))
end

local function concludeAll()
    if #S.results == 0 then return end
    refreshResultPanel()
    local ranked = {}
    for _, r in ipairs(S.results) do ranked[#ranked + 1] = r end
    table.sort(ranked, function(a, b) return (a.rate or 0) > (b.rate or 0) end)
    local best = ranked[1]
    local base = S.baselineRate
    local msg
    if best and base and base > 0 and best.rate >= base * PASS_RATIO then
        msg = string.format("ชนะ: %s (×%.2f vs Stand+Brake) — ใช้โหมดนี้ในฟาร์มลู่",
            best.label, best.rate / base)
    elseif best and base and math.abs(best.rate - base) / math.max(base, 1) < 0.10 then
        msg = "ทุกโหมดใกล้เคียง — โฟกัสเลือกลู่ max +/step + เวลาอยู่บนลู่"
    else
        msg = best and string.format("สูงสุด: %s @ %.0f/s", best.label, best.rate) or "ไม่มีผล"
    end
    say(msg)
    print("[TreadGain] " .. msg)
end

-- ===== buttons =====
bPrev.MouseButton1Click:Connect(function()
    if S.busy then return end
    S.modeIdx = S.modeIdx <= 1 and #MODES or (S.modeIdx - 1)
    refreshModeBtn()
end)
bNext.MouseButton1Click:Connect(function()
    if S.busy then return end
    S.modeIdx = S.modeIdx >= #MODES and 1 or (S.modeIdx + 1)
    refreshModeBtn()
end)
bMode.MouseButton1Click:Connect(function()
    if S.busy then return end
    S.modeIdx = S.modeIdx >= #MODES and 1 or (S.modeIdx + 1)
    refreshModeBtn()
end)

bGo.MouseButton1Click:Connect(function()
    if S.busy then return end
    setBusy(true)
    S.abort = false
    task.spawn(function()
        local b, d, rate = nearestTreadmill()
        if b then
            S.lockedBottom = b
            say(string.format("ล็อค +%s/step d=%.0f — กำลังไป", tostring(rate > 0 and rate or "?"), d or -1))
        end
        local ok = ensureOnTread(GO_TIMEOUT)
        setBusy(false)
        say(ok and "ถึงลู่แล้ว — เลือกรันโหมด / ออโต้ทั้งชุด" or "ไปลู่ไม่สำเร็จ")
    end)
end)

bLock.MouseButton1Click:Connect(function()
    if S.busy then return end
    local b, d, rate = nearestTreadmill()
    if not b then say("ไม่พบลู่"); return end
    S.lockedBottom = b
    say(string.format("ล็อคลู่นี้ +%s/step d=%.0f", tostring(rate > 0 and rate or "?"), d or -1))
end)

bRun.MouseButton1Click:Connect(function()
    if S.busy then return end
    setBusy(true)
    S.abort = false
    task.spawn(function()
        if not ensureOnTread(15) then setBusy(false); say("ยังไม่ถึงลู่"); return end
        local mode = MODES[S.modeIdx]
        local res = runMode(mode)
        storeResult(res)
        restoreWalkSpeed()
        setBusy(false)
        if res then say(string.format("%s เสร็จ Δ=%.0f rate=%.0f/s", res.label, res.delta, res.rate)) end
        concludeAll()
    end)
end)

bAuto.MouseButton1Click:Connect(function()
    if S.busy then return end
    setBusy(true)
    S.abort = false
    S.results = {}
    S.baselineRate = nil
    task.spawn(function()
        if not ensureOnTread(GO_TIMEOUT) then setBusy(false); say("ยังไม่ถึงลู่"); return end
        local hum = select(1, parts())
        S.baseWS = hum and hum.WalkSpeed or S.baseWS
        for i, mode in ipairs(MODES) do
            if S.abort or not S.busy then break end
            S.modeIdx = i
            refreshModeBtn()
            say(string.format("ออโต้ %d/%d: %s", i, #MODES, mode.label))
            if not ensureOnTread(10) then break end
            local res = runMode(mode)
            storeResult(res)
            restoreWalkSpeed()
            task.wait(0.4)
        end
        setBusy(false)
        concludeAll()
    end)
end)

bStop.MouseButton1Click:Connect(function()
    S.abort = true
    S.busy = false
    restoreWalkSpeed()
    setBusy(false)
    say("STOP — คืน WalkSpeed")
end)

bX.MouseButton1Click:Connect(function()
    S.abort = true
    S.busy = false
    restoreWalkSpeed()
    gui:Destroy()
    _G.EGG01_TREADGAIN = nil
end)

refreshModeBtn()
say("โหลดแล้ว — ไปลู่ → ออโต้ทั้งชุด (~70s) หรือรันโหมดทีละอัน")
print("[Egg01 TreadGainMatrix] v1.0 ready")
