-- 79RB_HouseClean2_AutoLeaf.lua v3.0 — ฟาร์มใบไม้อัตโนมัติ (ล้างบ้านขำๆ ภาค 2 "นอกบ้าน")
-- จาก 79RB_LeafIdSpy: id ที่ CollectLeaf:FireServer(id) ใช้ = ลำดับใบใน WS.Leaves:GetChildren()
--   ตอน "สแนปครั้งแรก" เป๊ะๆ (448|448, 1987|1987, ... ตรงกันทุกแถว) — เดิม v1.x/v2.x เดาไม่ออก
--   เพราะยิงไล่เลข 1..N มั่วๆ (ช้า, ยิงข้าม) v1.7 โหมด "ใกล้สุด" ก็พลาดเพราะ re-fetch GetChildren()
--   ใหม่ทุกครั้ง (ลำดับเลื่อนเมื่อใบกลางลิสต์หาย) → v3.0 สแนป "ครั้งเดียวตอนเริ่ม" แล้วจำ id
--   คงที่ต่อใบไปตลอด ไม่ re-fetch → วาปไปใบใกล้สุดที่ยังไม่เก็บ ยิง id เดียวจบ แม่น + เร็ว
if _G.LF79_GUI then pcall(function() _G.LF79_GUI:Destroy() end) end
_G.LF79_GEN = (_G.LF79_GEN or 0) + 1
local GEN = _G.LF79_GEN

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local LEAF_DELAY = 0.03  -- หน่วงหลังยิงแต่ละใบ (วิ)
local EMPTY_SEC = 10      -- ขายอัตโนมัติทุกกี่วิ
local AUTO_ON = false

-- ==================== หา remote ====================
local function findRemote(name)
    for _, svc in ipairs({ RS, workspace }) do
        local r = svc:FindFirstChild(name, true)
        if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    end
    return nil
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoLeaf79"; gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647; gui.IgnoreGuiInset = true
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.LF79_GUI = gui

local fr = Instance.new("Frame", gui)
fr.Size = UDim2.new(0, 300, 0, 330); fr.Position = UDim2.new(0, 8, 0.35, 0)
fr.BackgroundColor3 = Color3.new(0, 0, 0); fr.BackgroundTransparency = 0.1
fr.Active = true; fr.Draggable = true
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
local stk = Instance.new("UIStroke", fr); stk.Color = Color3.fromRGB(120, 220, 100); stk.Thickness = 2

local status = Instance.new("TextLabel", fr)
status.Size = UDim2.new(1, -8, 0, 36); status.Position = UDim2.new(0, 4, 0, 4)
status.BackgroundTransparency = 1; status.TextColor3 = Color3.fromRGB(180, 255, 180)
status.TextSize = 12; status.Font = Enum.Font.GothamBold; status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left; status.Text = "🍂 AutoLeaf v3.0 พร้อม"

local scf = Instance.new("ScrollingFrame", fr)
scf.Size = UDim2.new(1, -8, 1, -116); scf.Position = UDim2.new(0, 4, 0, 74)
scf.BackgroundColor3 = Color3.fromRGB(12, 18, 12); scf.BorderSizePixel = 0; scf.ScrollBarThickness = 6
scf.CanvasSize = UDim2.new(0, 0, 0, 0); scf.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scf).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel", scf)
lbl.Size = UDim2.new(1, -8, 0, 0); lbl.Position = UDim2.new(0, 4, 0, 4)
lbl.AutomaticSize = Enum.AutomaticSize.Y; lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.Code; lbl.TextSize = 11; lbl.TextColor3 = Color3.fromRGB(190, 255, 190)
lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.TextWrapped = true; lbl.Text = ""
local out = {}
local function say(s)
    out[#out + 1] = tostring(s)
    if #out > 300 then table.remove(out, 1) end
    lbl.Text = table.concat(out, "\n")
end

local function mkbtn(txt, x, y, w, col)
    local b = Instance.new("TextButton", fr)
    b.Size = UDim2.new(0, w, 0, 26); b.Position = UDim2.new(0, x, 0, y)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.BackgroundColor3 = col; b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local autoB  = mkbtn("▶ AUTO", 4, 42, 76, Color3.fromRGB(40, 130, 60))
local snapB  = mkbtn("SNAP", 84, 42, 60, Color3.fromRGB(60, 90, 150))
local emptyB = mkbtn("เทถุง", 148, 42, 56, Color3.fromRGB(150, 110, 40))
local copyB  = mkbtn("📋", 208, 42, 40, Color3.fromRGB(60, 60, 60))
local closeB = mkbtn("✕", 252, 42, 40, Color3.fromRGB(140, 45, 45))

local dlyB = mkbtn(("หน่วง %.2f"):format(LEAF_DELAY), 4, 296, 96, Color3.fromRGB(70, 70, 110))
dlyB.MouseButton1Click:Connect(function()
    local steps = { 0.01, 0.03, 0.05, 0.10 }
    for i, v in ipairs(steps) do
        if math.abs(v - LEAF_DELAY) < 0.001 then LEAF_DELAY = steps[i % #steps + 1]; break end
    end
    dlyB.Text = ("หน่วง %.2f"):format(LEAF_DELAY)
end)

copyB.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
end)
closeB.MouseButton1Click:Connect(function()
    _G.LF79_GEN = _G.LF79_GEN + 1; gui:Destroy(); _G.LF79_GUI = nil
end)

-- ==================== วาป (ตำแหน่งอย่างเดียว ไม่หมุนกล้อง) ====================
local function myRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function tpTo(pos)
    local root = myRoot(); if not root then return false end
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = (root.CFrame - root.CFrame.Position) + pos
    return true
end
local function dumpsterPos()
    local d = workspace:FindFirstChild("Map")
    d = d and d:FindFirstChild("Dumpsters")
    if not d then return nil end
    local p = d:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

-- ==================== เทถุง (วาปไปถัง+กดปุ่ม แล้ววาปกลับ) ====================
local function doEmpty()
    local ee = findRemote("EmptyBackpack")
    if not (ee and ee:IsA("RemoteEvent")) then return false end
    local dp = dumpsterPos()
    local root = myRoot()
    if dp and root then
        local back = root.Position
        tpTo(dp + Vector3.new(0, 3, 0))
        task.wait(0.45)
        ee:FireServer()
        pcall(function()
            local d = workspace:FindFirstChild("Map")
            d = d and d:FindFirstChild("Dumpsters")
            if d and fireproximityprompt then
                for _, pr in ipairs(d:GetDescendants()) do
                    if pr:IsA("ProximityPrompt") then fireproximityprompt(pr) end
                end
            end
        end)
        task.wait(0.3)
        tpTo(back)
    else
        ee:FireServer()
    end
    return true
end
emptyB.MouseButton1Click:Connect(function() say(doEmpty() and "🗑️ เทกระเป๋าแล้ว" or "❌ ไม่เจอ EmptyBackpack") end)

-- ==================== v3.0: สแนป id ครั้งเดียว (ยืนยันจาก LeafIdSpy: id = ลำดับสแนป) ====================
-- snapshot[leafInstance] = id ตายตัว | ไม่ re-fetch GetChildren() อีกหลังจากนี้ (กันลำดับเลื่อน)
local snapshot = {}   -- inst -> id
local snapOrder = {}  -- id -> inst (สำหรับไล่หา / debug)
local snapDone = false
_G.LF79_DONE = _G.LF79_DONE or {} -- id ที่เก็บสำเร็จแล้ว (เซฟลงไฟล์ข้ามรอบรัน)
local doneIds = _G.LF79_DONE
local SAVE_FILE = "LF79_done.json"

local function doSnapshot()
    snapshot = {}; snapOrder = {}
    local folder = workspace:FindFirstChild("Leaves")
    if not folder then say("❌ ไม่เจอ WS.Leaves"); return 0 end
    local kids = folder:GetChildren()
    for i, m in ipairs(kids) do
        snapshot[m] = i
        snapOrder[i] = m
    end
    snapDone = true
    say(("📸 สแนปแล้ว: %d ใบ (id = ลำดับตอนนี้)"):format(#kids))
    return #kids
end

-- โหลดความจำ (ผูก JobId)
pcall(function()
    if readfile and isfile and isfile(SAVE_FILE) then
        local d = HttpService:JSONDecode(readfile(SAVE_FILE))
        if d.job == game.JobId then
            for _, id in ipairs(d.ids) do doneIds[id] = true end
            say(("💾 โหลดความจำ: เก็บไปแล้ว %d ใบ (เซิร์ฟเดิม)"):format(#d.ids))
        end
    end
end)
local function saveDone()
    pcall(function()
        if not writefile then return end
        local ids = {}
        for id in pairs(doneIds) do ids[#ids + 1] = id end
        writefile(SAVE_FILE, HttpService:JSONEncode({ job = game.JobId, ids = ids }))
    end)
end
task.spawn(function()
    while _G.LF79_GEN == GEN do task.wait(20); saveDone() end
end)

snapB.MouseButton1Click:Connect(function() doSnapshot() end)

local ce = findRemote("CollectLeaf")
say("CollectLeaf: " .. (ce and ce:GetFullName() or "❌ ไม่เจอ"))
say("กด SNAP ก่อนเริ่ม (หรือ AUTO จะสแนปให้อัตโนมัติครั้งแรก)")

-- ==================== AUTO ====================
autoB.MouseButton1Click:Connect(function()
    AUTO_ON = not AUTO_ON
    autoB.Text = AUTO_ON and "⏸ หยุด" or "▶ AUTO"
    autoB.BackgroundColor3 = AUTO_ON and Color3.fromRGB(150, 60, 40) or Color3.fromRGB(40, 130, 60)
end)

task.spawn(function()
    local sinceEmpty = 0
    local hit, tryC = 0, 0
    while _G.LF79_GEN == GEN do
        if AUTO_ON then
            local ceR = findRemote("CollectLeaf")
            if not ceR then
                status.Text = "❌ ไม่เจอ remote CollectLeaf"
                task.wait(1)
            else
                if not snapDone then doSnapshot() end
                local root = myRoot()
                if not root then
                    task.wait(0.5)
                else
                    -- หาใบใกล้ตัวสุดที่ "ยังไม่เก็บ" จากสแนป (ไม่ re-fetch GetChildren)
                    local myP = root.Position
                    local best, bestId, bd = nil, nil, math.huge
                    for id, m in pairs(snapOrder) do
                        if not doneIds[id] and m.Parent then
                            local ok, p = pcall(function() return m.Position end)
                            if ok then
                                local d = (p - myP).Magnitude
                                if d < bd then bd = d; best = m; bestId = id end
                            end
                        end
                    end
                    if not best then
                        status.Text = ("✅ ครบสแนปนี้แล้ว (%d ใบ) — สแนปรอบใหม่..."):format(tryC)
                        task.wait(0.5)
                        doSnapshot()
                        hit, tryC = 0, 0
                    else
                        tpTo(best.Position + Vector3.new(0, 2, 0))
                        task.wait(0.10)
                        pcall(function() ceR:FireServer(bestId) end)
                        tryC = tryC + 1
                        task.wait(LEAF_DELAY)
                        local gone = best.Parent == nil
                        if gone then
                            doneIds[bestId] = true
                            hit = hit + 1
                        end
                        sinceEmpty = sinceEmpty + 1
                        if sinceEmpty >= 20 then doEmpty(); sinceEmpty = 0 end
                        status.Text = ("🎯 โดน %d/%d | ระยะ %.1f | id %d"):format(hit, tryC, bd, bestId)
                    end
                end
            end
        else
            status.Text = "🍂 AutoLeaf v3.0 พร้อม (AUTO เริ่ม / SNAP รีเซ็ตสแนป)"
            task.wait(0.3)
        end
    end
end)

task.spawn(function() -- ขายอัตโนมัติเป็นระยะ ระหว่างที่ยังไม่ครบ EMPTY_EVERY
    while _G.LF79_GEN == GEN do
        if AUTO_ON then doEmpty() end
        task.wait(EMPTY_SEC)
    end
end)

warn("[AutoLeaf79] v3.0 loaded — id=ลำดับสแนปครั้งแรก (ยืนยันจาก LeafIdSpy) วาปใบใกล้สุด ยิง id เดียวจบ")
