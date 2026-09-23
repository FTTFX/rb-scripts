-- Egg01_SpeedGainTest v1.0
-- ทดสอบว่า WalkSpeed +100% ขณะยืนบนลู่วิ่งเพิ่มอัตราคะแนนวิ่งหรือไม่ (รอบ A/B ละ 10 วิ)

if _G.EGG01_SPEEDGAIN then
    pcall(function() _G.EGG01_SPEEDGAIN.gui:Destroy() end)
end

local Players = game:GetService("Players")
local RunS = game:GetService("RunService")
local LP = Players.LocalPlayer

-- state machine: idle | going | measureA | measureB | done | aborted
local S = {
    state = "idle",
    abort = false,
    busy = false,
    gui = nil,
    baseWS = nil,
    resultA = nil,
    resultB = nil,
    stats = { A = "", B = "" },
}
_G.EGG01_SPEEDGAIN = S

-- ค่าคงที่
local SAMPLE_SEC     = 10    -- วินาทีต่อรอบวัด (บังคับ)
local SPEED_MULT     = 2.00  -- รอบ B = WalkSpeed * 2.00 (+100%)
local POLL_HZ        = 0.05  -- ช่วงอ่านคะแนนระหว่างวัด (~20 Hz)
local STATIONARY_EPS = 2.0   -- studs: เลื่อนเกินนี้ถือว่าหลุดจุดทดสอบ
local ARRIVE_DIST    = 5     -- ถึงลู่เมื่อระยะ <= นี้
local TREAD_NAME     = "TreadmillBottom"
local GUI_NAME       = "Egg01_SpeedGainTest"
local DISPLAY_ORDER  = 1010
local GO_TIMEOUT     = 35    -- timeout เดินไปลู่

-- ===== helpers =====
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

local function nearestTreadmill()
    local _, root = parts()
    if not root then return nil end
    local best, bestD
    local ok, desc = pcall(function() return workspace:GetDescendants() end)
    if not ok or not desc then return nil end
    for _, item in ipairs(desc) do
        if item:IsA("BasePart") and item.Name == TREAD_NAME then
            local d = (item.Position - root.Position).Magnitude
            if not bestD or d < bestD then best, bestD = item, d end
        end
    end
    return best, bestD
end

local function standPos(bottom)
    if not bottom then return nil end
    return bottom.CFrame:PointToWorldSpace(Vector3.new(0, bottom.Size.Y * 0.5 + 2.5, 0))
end

-- เบรคแรงเฉื่อยให้ยืนนิ่ง (ห้ามตั้ง WalkSpeed=0 ระหว่างวัด)
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
panel.Size = UDim2.new(0, 340, 0, 280)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 9)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -45, 0, 24)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(30, 30, 35)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Egg01 SpeedGain Test"

local function button(text, x, color, w)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, w or 98, 0, 26)
    b.Position = UDim2.new(0, x, 0, 32)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(30, 30, 35)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bGo    = button("ไปลู่", 10,  Color3.fromRGB(35, 145, 75))
local bStop  = button("STOP", 118, Color3.fromRGB(185, 60, 60))
local bX     = button("X", 300, Color3.fromRGB(185, 60, 60), 30)

local bA     = button("วัดปกติ A", 10,      Color3.fromRGB(70, 130, 220))
local bB     = button("วัด +100% B", 118,   Color3.fromRGB(235, 150, 60))
local bAuto  = button("A→B ออโต้", 226,    Color3.fromRGB(35, 145, 75))

local status = Instance.new("TextLabel", panel)
status.Size = UDim2.new(1, -20, 0, 64)
status.Position = UDim2.new(0, 10, 0, 66)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(60, 60, 65)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "พร้อม — กด A→B ออโต้ เพื่อเริ่มทดลอง"

local result = Instance.new("TextLabel", panel)
result.Size = UDim2.new(1, -20, 0, 86)
result.Position = UDim2.new(0, 10, 0, 132)
result.BackgroundTransparency = 1
result.TextColor3 = Color3.fromRGB(30, 30, 35)
result.Font = Enum.Font.Code
result.TextSize = 11
result.TextXAlignment = Enum.TextXAlignment.Left
result.TextYAlignment = Enum.TextYAlignment.Top
result.TextWrapped = true
result.Text = "—"

local spy = Instance.new("TextLabel", panel)
spy.Size = UDim2.new(1, -20, 0, 40)
spy.Position = UDim2.new(0, 10, 0, 222)
spy.BackgroundTransparency = 1
spy.TextColor3 = Color3.fromRGB(90, 90, 95)
spy.Font = Enum.Font.Gotham
spy.TextSize = 10
spy.TextWrapped = true
spy.TextXAlignment = Enum.TextXAlignment.Left
spy.TextYAlignment = Enum.TextYAlignment.Top
spy.Text = "stat=? | WS=? | pos=?"

local function say(txt)
    status.Text = tostring(txt)
end

local function setBusy(v, btnTexts)
    S.busy = v
    bGo.Text = btnTexts and btnTexts[1] or (v and "…" or "ไปลู่")
    bA.Text = btnTexts and btnTexts[2] or (v and "…" or "วัดปกติ A")
    bB.Text = btnTexts and btnTexts[3] or (v and "…" or "วัด +100% B")
    bAuto.Text = btnTexts and btnTexts[4] or (v and "…" or "A→B ออโต้")
end

-- ===== ไปลู่ =====
local function goToTreadmill(cb)
    local bottom, distance = nearestTreadmill()
    if not bottom then say("ไม่พบ " .. TREAD_NAME); cb(false) return end
    local target = standPos(bottom)
    if not target then say("คำนวณจุดยืนไม่ได้"); cb(false) return end
    say(string.format("เจอลู่ d=%.0f — กำลังไป", distance or -1))

    local deadline = os.clock() + GO_TIMEOUT
    local reached = false
    while S.busy and not S.abort and os.clock() < deadline do
        local hum, root = parts()
        if not hum or not root or hum.Health <= 0 then say("ตัวละครไม่มีชีวิต"); break end
        local goal = Vector3.new(target.X, root.Position.Y, target.Z)
        local d = (goal - root.Position).Magnitude
        -- ใกล้พอแล้ว = ถึง, moveTo เบาๆ (ไม่วน)
        if d <= ARRIVE_DIST then
            reached = true
            break
        end
        hum:MoveTo(goal)
        say(string.format("กำลังไปลู่ d=%.0f", d))
        task.wait(0.35)
    end
    if S.abort then say("ยกเลิก"); cb(false) return end
    if not reached then
        local hum, root = parts()
        local d = root and target and ((Vector3.new(target.X, root.Position.Y, target.Z) - root.Position).Magnitude) or 999
        if d <= ARRIVE_DIST then reached = true end
    end
    if reached then
        say(string.format("ถึงลู่แล้ว — ยืนนิ่งวัดได้ | WS=%.1f", (select(1, parts()) or {}).WalkSpeed or 0))
        cb(true)
    else
        say("ไปลู่ไม่ทัน 35s")
        cb(false)
    end
end

-- ===== รอบวัด =====
local function runSample(label)
    local hum, root = parts()
    if not hum or not root or hum.Health <= 0 then
        say("รอบ FAIL: ตัวละครไม่มีชีวิต")
        return nil
    end
    local ws0 = hum.WalkSpeed
    local score0, scoreName = readScore()
    if score0 == nil then
        say("รอบ FAIL: อ่านคะแนนไม่ได้")
        return nil
    end

    local anchor = Vector3.new(root.Position.X, 0, root.Position.Z)
    local t0 = os.clock()
    local moved = false
    local lastDelta = 0

    while S.busy and not S.abort and os.clock() - t0 < SAMPLE_SEC do
        hum, root = parts()
        if not hum or not root or hum.Health <= 0 then say("รอบ FAIL: ตายระหว่างวัด"); return nil end
        if label == "B" and hum.WalkSpeed ~= S.baseWS * SPEED_MULT then
            hum.WalkSpeed = S.baseWS * SPEED_MULT
        end
        brake(hum, root)
        local now = root.Position
        if Vector3.new(now.X - anchor.X, 0, now.Z - anchor.Z).Magnitude > STATIONARY_EPS then
            moved = true
        end
        local sc = readScore()
        if sc then lastDelta = sc - score0 end
        local remain = SAMPLE_SEC - (os.clock() - t0)
        say(string.format("[%s] เหลือ %.1fs  Δ=%.0f  WS=%.1f", label, remain, lastDelta, hum.WalkSpeed))
        spy.Text = string.format("stat=%s | WS=%.1f | %s", scoreName or "?", hum.WalkSpeed, moved and "moved!" or "posOK")
        task.wait(POLL_HZ)
    end
    if S.abort then say("รอบถูกยกเลิก"); return nil end

    local score1 = readScore()
    if score1 == nil then say("รอบ FAIL: อ่านคะแนนไม่ได้ตอนจบ"); return nil end
    local ws1 = select(1, parts()) and select(1, parts()).WalkSpeed or ws0

    return {
        label = label,
        sampleSec = SAMPLE_SEC,
        walkSpeedStart = ws0,
        walkSpeedEnd = ws1,
        scoreName = scoreName,
        scoreStart = score0,
        scoreEnd = score1,
        delta = score1 - score0,
        rate = (score1 - score0) / SAMPLE_SEC,
        moved = moved,
    }
end

local function showResult(res)
    local line = string.format("%s: WS=%.1f→%.1f  Δ=%.0f  rate=%.2f/s%s",
        res.label, res.walkSpeedStart, res.walkSpeedEnd or res.walkSpeedStart,
        res.delta, res.rate, res.moved and "  (moved)" or "")
    S.stats[res.label] = line
    result.Text = table.concat({ S.stats.A, S.stats.B, "" }, "\n")
end

local function conclude()
    local a, b = S.resultA, S.resultB
    if not a or not b then
        result.Text = table.concat({ S.stats.A, S.stats.B, "ข้อมูลไม่พอ (ต้องการทั้ง A และ B)" }, "\n")
        return
    end
    local eps = math.max(1, math.abs(a.rate) * 0.001)
    local verdict
    if math.abs(a.rate) < eps and math.abs(b.rate) < eps then
        verdict = "คะแนนไม่ขึ้นทั้งสองรอบ — อาจลู่ผิดหรือยังไม่เข้าโซน"
    elseif b.rate > a.rate * 1.05 then
        verdict = "WalkSpeed ส่งผลเชิงบวก (≥+5%)"
    elseif b.rate < a.rate * 0.95 then
        verdict = "แย่ลงหรือโดนรีเซ็ต"
    else
        verdict = "ไม่ต่างอย่างมีนัย (±5%)"
    end
    local ratio = math.abs(a.rate) > 0 and (b.rate / a.rate) or 0
    local pct = (ratio - 1) * 100
    result.Text = string.format("%s\n%s\nอัตรา B/A = %.2f×  (pct=%+d%%)\nสรุป: %s",
        S.stats.A, S.stats.B, ratio, math.floor(pct + 0.5), verdict)
    print(string.format("[SpeedGain] A: Δ=%.0f rate=%.2f/s | B: Δ=%.0f rate=%.2f/s | B/A=%.2f× (%+d%%) | %s",
        a.delta, a.rate, b.delta, b.rate, ratio, math.floor(pct + 0.5), verdict))
end

-- ===== ปุ่ม =====
local function runA()
    if S.busy or S.abort then return end
    setBusy(true)
    S.baseWS = select(1, parts()) and select(1, parts()).WalkSpeed or nil
    if not S.baseWS then say("อ่าน WalkSpeed ไม่ได้"); setBusy(false); return end
    S.state = "measureA"
    local res = runSample("A")
    if res then
        S.resultA = res
        showResult(res)
        say("รอบ A เสร็จ — กด วัด +10% B หรือ A→B ออโต้")
    end
    setBusy(false)
    if S.state ~= "aborted" then S.state = "idle" end
end

local function runB()
    if S.busy or S.abort then return end
    if not S.resultA then say("ต้องวัด A ก่อน"); return end
    if not S.baseWS or S.baseWS <= 0 then
        local hum = select(1, parts())
        S.baseWS = hum and hum.WalkSpeed or nil
    end
    if not S.baseWS or S.baseWS <= 0 then say("ไม่มี baseWS — วัด A ใหม่"); return end
    setBusy(true)
    S.state = "measureB"
    local hum = select(1, parts())
    if not hum then say("ไม่มี Humanoid"); setBusy(false); return end
    hum.WalkSpeed = S.baseWS * SPEED_MULT
    say(string.format("ตั้ง WS=%.1f (x%.2f) — วัด 10s", hum.WalkSpeed, SPEED_MULT))
    local res = runSample("B")
    if res then
        S.resultB = res
        showResult(res)
        restoreWalkSpeed()
        conclude()
    else
        restoreWalkSpeed()
    end
    setBusy(false)
    if S.state ~= "aborted" then S.state = "done" end
end

local function runAuto()
    if S.busy or S.abort then return end
    setBusy(true)
    task.spawn(function()
        S.baseWS = select(1, parts()) and select(1, parts()).WalkSpeed or nil
        if not S.baseWS then say("อ่าน WalkSpeed ไม่ได้"); setBusy(false); return end
        S.state = "measureA"
        local resA = runSample("A")
        if not resA then setBusy(false); return end
        S.resultA = resA
        showResult(resA)
        say("A เสร็จ — พัก 0.5s แล้วรัน B")
        task.wait(0.5)
        if not S.busy or S.abort then setBusy(false); return end
        S.state = "measureB"
        local hum = select(1, parts())
        if not hum then say("ไม่มี Humanoid"); setBusy(false); return end
        hum.WalkSpeed = S.baseWS * SPEED_MULT
        local resB = runSample("B")
        if resB then
            S.resultB = resB
            showResult(resB)
            restoreWalkSpeed()
            conclude()
        else
            restoreWalkSpeed()
        end
        setBusy(false)
        if S.state ~= "aborted" then S.state = "done" end
    end)
end

local function doGo()
    if S.busy or S.abort then return end
    setBusy(true)
    S.state = "going"
    task.spawn(function()
        goToTreadmill(function(ok)
            setBusy(false)
            if S.state ~= "aborted" then S.state = "idle" end
            if not ok then S.abort = false end
        end)
    end)
end

bGo.MouseButton1Click:Connect(doGo)
bStop.MouseButton1Click:Connect(function()
    S.abort = true
    S.busy = false
    restoreWalkSpeed()
    task.wait(0.1)
    S.abort = false
    S.state = "idle"
    setBusy(false)
    say("STOP — คืน WalkSpeed แล้ว")
end)
bX.MouseButton1Click:Connect(function()
    S.abort = true
    S.busy = false
    restoreWalkSpeed()
    gui:Destroy()
    _G.EGG01_SPEEDGAIN = nil
end)
bA.MouseButton1Click:Connect(runA)
bB.MouseButton1Click:Connect(runB)
bAuto.MouseButton1Click:Connect(runAuto)

say("โหลดแล้ว — กด ไปลู่ (หรือยืนบนลู่) แล้วกด A→B ออโต้")
print("[Egg01 SpeedGainTest] v1.0 ready — กด A→B ออโต้ ที่ UI")