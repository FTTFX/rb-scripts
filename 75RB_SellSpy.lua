-- 75RB_SellSpy.lua v1.3 — แกะเมนูขาย
-- v1.3: กดปุ่มแล้วจอว่าง! — วาด log สดทุกบรรทัด (เดิมวาดตอนจบ ถ้า error กลางทาง = ไม่เห็นอะไร)
--       + หุ้ม pcall ทุกปุ่ม โชว์ 💥 ERROR ให้เห็น
-- v1.2: แกะเมนูขาย (ร้านไม่มี ProximityPrompt! ปุ่ม E เป็น UI เกมเอง)
-- v1.2: ปุ่มใหม่ 3 ตัว — "ไล่กดทีละตัว" (หาชิ้นที่ทำให้กระเป๋าลดจริง แล้วบอกชื่อเต็ม)
--       "ยิงคีย์ 1" (VirtualInputManager/keypress/ยิงเข้า InputBegan ตรงๆ)
--       "ดูปุ่มผูก" (ContextActionService — เมนูอาจผูกเลข 1-4 ไว้ที่นี่)
-- v1.1: แกะเมนูขาย (กด 1 ไม่ได้!) เพื่อกดมันด้วยสคริปต์
-- v1.1: SCAN เจอตัวจริงแล้ว — GUI 'dialog' (dialogResponses.1 = "Sell all crystals")
--       + 'Sell.Frame.Sell' ImageButton | executor มี firesignal ✅
--       เพิ่มปุ่ม "กดเมนู 1" = ยิงทุกสัญญาณใส่ตัวเลือก 1 + พ่อทุกชั้น + ปุ่มขายใหญ่
--       แล้ววัดน้ำหนักกระเป๋าก่อน/หลัง (ลด = ขายสำเร็จ)
-- อาการ: SellOpen เด้งมาแล้ว เมนู 4 ตัวเลือกโผล่ ("ขายคริสตัลทั้งหมด" ฯลฯ) แต่แตะไม่ติด
-- เดา 2 ทาง: (ก) เป็น Roblox Dialog/DialogChoice (ไม่ใช่ GUI ปกติ)
--             (ข) เป็น GUI ของเกมที่ปุ่มซ้อน/ปิด Active อยู่
-- ตัวนี้: 1) ค้น Dialog + DialogChoice ทั้ง workspace (โชว์ข้อความ+วิธียิง)
--         2) ดัมพ์ GUI ทุกตัวใน PlayerGui ที่มีคำว่า ขาย/Sell (path, ClassName, Visible, Active)
--         3) ปุ่ม "กดขายให้เลย" — ยิงปุ่มขายทุกช่องทางที่หาได้ (firesignal / Dialog / SellRequest)
-- วิธีใช้: เดินไปร้าน กด E ให้เมนูเด้ง → กด SCAN → COPY ส่งผล (หรือกด "กดขายให้เลย" ลองเลย)
if _G.SSPY75_GUI then pcall(function() _G.SSPY75_GUI:Destroy() end) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT = {}
local BOX   -- forward — v1.3: วาดสดทุกบรรทัด (เดิมวาดตอนจบ ถ้า error กลางทาง = จอว่างเปล่า)
local function L(s)
    OUT[#OUT + 1] = s
    if #OUT > 250 then table.remove(OUT, 1) end
    if BOX then BOX.Text = table.concat(OUT, "\n") end
end

local function isSellish(txt)
    if not txt or txt == "" then return false end
    local t = txt:lower()
    return t:find("sell") or txt:find("ขาย") or txt:find("ทั้งหมด")
end

-- เก็บปุ่มที่หาได้ไว้ให้ปุ่ม "กดขายให้เลย" ใช้
local foundBtns, foundDialogs = {}, {}

local function scan()
    OUT = {}
    foundBtns, foundDialogs = {}, {}
    L("=== SellSpy — แกะเมนูขาย ===")

    -- (1) Roblox Dialog (เมนูตัวเลือก 1-4 แบบคลาสสิก)
    L("--- Dialog / DialogChoice ใน workspace ---")
    local nd = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Dialog") then
            nd += 1
            foundDialogs[#foundDialogs + 1] = d
            L(("Dialog #%d @ %s | InUse=%s Tone=%s Purpose=%s")
                :format(nd, d:GetFullName():gsub("^Workspace%.", ""),
                    tostring(d.InUse), tostring(d.Tone), tostring(d.Purpose)))
            L("   ข้อความ: " .. tostring(d.InitialPrompt))
            for _, ch in ipairs(d:GetDescendants()) do
                if ch:IsA("DialogChoice") then
                    L(("   choice '%s' → UserDialog='%s' Response='%s'")
                        :format(ch.Name, tostring(ch.UserDialog), tostring(ch.ResponseDialog)))
                end
            end
        end
    end
    if nd == 0 then L("(ไม่เจอ Dialog — เมนูน่าจะเป็น GUI ของเกมเอง)") end

    -- (2) GUI ที่มีคำว่า ขาย/Sell
    L("--- GUI ที่เกี่ยวกับการขาย (PlayerGui) ---")
    local pg = LP:FindFirstChild("PlayerGui")
    local ng = 0
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            local nameSell = isSellish(d.Name)
            local txtSell = (d:IsA("TextLabel") or d:IsA("TextButton")) and isSellish(d.Text)
            if nameSell or txtSell then
                ng += 1
                local extra = ""
                if d:IsA("GuiButton") then
                    extra = (" Active=%s Visible=%s ZIndex=%d"):format(
                        tostring(d.Active), tostring(d.Visible), d.ZIndex)
                    foundBtns[#foundBtns + 1] = d
                elseif d:IsA("GuiObject") then
                    extra = (" Visible=%s"):format(tostring(d.Visible))
                end
                L(("%s [%s]%s%s"):format(
                    d:GetFullName():gsub("^Players%." .. LP.Name .. "%.PlayerGui%.", ""),
                    d.ClassName, extra,
                    (d:IsA("TextLabel") or d:IsA("TextButton")) and (" txt='" .. d.Text .. "'") or ""))
            end
        end
    end
    L("--- เจอ GUI " .. ng .. " ตัว | ปุ่มกดได้ " .. #foundBtns .. " ตัว ---")

    -- (3) ProximityPrompt ของร้าน
    -- v1.1: ต้นไม้เต็มของ GUI ตัวจริง
    local pg2 = LP:FindFirstChild("PlayerGui")
    if pg2 then
        local dlg = pg2:FindFirstChild("dialog", true)
        if dlg then dumpTree(dlg, "dialog (เมนูตัวเลือก)") else L("(ไม่เจอ GUI dialog — กด E ก่อน)") end
        local sg = pg2:FindFirstChild("Sell")
        if sg then dumpTree(sg, "Sell (ปุ่มขายใหญ่)") end
    end

    L("--- prompt ของ SellWorker ---")
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and d.Name == "SellWorker" then
            for _, pp in ipairs(d:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then
                    L(("prompt Action='%s' Object='%s' Hold=%.1f Max=%d En=%s")
                        :format(pp.ActionText, pp.ObjectText, pp.HoldDuration,
                            pp.MaxActivationDistance, tostring(pp.Enabled)))
                end
            end
        end
    end
    L("=== จบ — COPY ส่งผล หรือกด 'กดขายให้เลย' ทดลอง ===")
end

-- v1.1: ดัมพ์ต้นไม้เต็มของ GUI ที่ชื่อ dialog / Sell (ตัวจริงที่ต้องกด)
local function dumpTree(root, label)
    L("--- ต้นไม้ " .. label .. " ---")
    local function walk(o, ind)
        for _, c in ipairs(o:GetChildren()) do
            local extra = ""
            if c:IsA("GuiButton") then
                extra = (" ⭐ปุ่ม Active=%s ZIndex=%d"):format(tostring(c.Active), c.ZIndex)
            elseif c:IsA("GuiObject") then
                extra = (" Vis=%s"):format(tostring(c.Visible))
            end
            local txt = (c:IsA("TextLabel") or c:IsA("TextButton")) and (" '" .. c.Text .. "'") or ""
            L(("%s%s [%s]%s%s"):format(ind, c.Name, c.ClassName, extra, txt))
            if #ind < 12 then walk(c, ind .. "  ") end
        end
    end
    walk(root, "  ")
end

-- ยิงทุกสัญญาณของ GuiObject หนึ่งตัว (คลิก/แตะ/กดปล่อย)
local function fireAll(obj, why)
    local fs = firesignal or (getgenv and getgenv().firesignal)
    if not fs or not obj then return end
    local sigs = { "MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up",
        "InputBegan", "InputEnded", "TouchTap" }
    local hit = {}
    for _, s in ipairs(sigs) do
        pcall(function()
            if obj[s] then fs(obj[s]); hit[#hit + 1] = s end
        end)
    end
    L(("ยิง %s (%s): %s"):format(obj.Name, why, table.concat(hit, ",")))
end

-- v1.1: กดตัวเลือกในเมนู dialog + ปุ่ม Sell ตรงๆ (ตัวที่ SCAN เจอ)
local function pressMenu()
    L("")
    L(">>> กดเมนูขายตรงๆ (dialog + ปุ่ม Sell) <<<")
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local before = select(1, (function()
        local l = pg:FindFirstChild("ExplorerHud")
        l = l and l:FindFirstChild("BackpackPanel")
        l = l and l:FindFirstChild("Value")
        return l and l.Text or "?"
    end)())
    L("กระเป๋าก่อนกด: " .. tostring(before))

    -- 1) ตัวเลือกที่ 1 ในเมนู dialog ("Sell all crystals") — ยิงทั้งตัวมันและพ่อทุกชั้น
    local dlg = pg:FindFirstChild("dialog", true)
    if dlg then
        local resp = dlg:FindFirstChild("dialogResponses", true)
        local one = resp and resp:FindFirstChild("1")
        if one then
            fireAll(one, "ตัวเลือก 1")
            for _, c in ipairs(one:GetDescendants()) do
                if c:IsA("GuiButton") then fireAll(c, "ปุ่มใน ตัวเลือก1") end
            end
            local p = one.Parent
            while p and p ~= pg do
                if p:IsA("GuiButton") then fireAll(p, "พ่อของตัวเลือก1") end
                p = p.Parent
            end
        else
            L("❌ ไม่เจอ dialogResponses.1 (เมนูยังไม่เปิด? กด E ก่อน)")
        end
    else
        L("❌ ไม่เจอ GUI 'dialog' (กด E ที่ร้านให้เมนูเด้งก่อน)")
    end

    -- 2) ปุ่มขายใหญ่ Sell.Frame.Sell
    local sg = pg:FindFirstChild("Sell")
    local sbtn = sg and sg:FindFirstChild("Frame")
    sbtn = sbtn and sbtn:FindFirstChild("Sell")
    if sbtn then fireAll(sbtn, "ปุ่มขายใหญ่") else L("❌ ไม่เจอ Sell.Frame.Sell") end

    task.wait(1.5)
    local l = pg:FindFirstChild("ExplorerHud")
    l = l and l:FindFirstChild("BackpackPanel")
    l = l and l:FindFirstChild("Value")
    L("กระเป๋าหลังกด: " .. (l and l.Text or "?") .. "  ← ลดลง = ขายสำเร็จ!")
end

-- v1.2: ไล่กด "ทีละชิ้น" ในเมนู dialog จนเจอตัวที่ทำให้กระเป๋าลด แล้วบอกชื่อเต็มของมัน
-- (ยิงรวดเดียวทั้งกองแล้วไม่เข้า = ต้องรู้ว่าตัวไหนคือของจริง / หรือไม่มีตัวไหนเลย)
local function bagKg()
    local pg = LP:FindFirstChild("PlayerGui")
    local l = pg and pg:FindFirstChild("ExplorerHud")
    l = l and l:FindFirstChild("BackpackPanel")
    l = l and l:FindFirstChild("Value")
    local a = l and l.Text:match("([%d%.]+)")
    return tonumber(a) or -1
end

local function probeOneByOne()
    L("")
    L(">>> ไล่กดทีละชิ้น (หาตัวจริง) <<<")
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local dlg = pg:FindFirstChild("dialog", true)
    if not dlg then L("❌ ไม่เจอ GUI dialog") return end

    -- รวมผู้ต้องสงสัย: ทุก GuiObject ใต้ dialog + ปุ่มที่ข้อความเกี่ยวกับขาย
    local cand = {}
    for _, d in ipairs(dlg:GetDescendants()) do
        if d:IsA("GuiObject") then cand[#cand + 1] = d end
    end
    cand[#cand + 1] = dlg
    L(("ผู้ต้องสงสัย %d ชิ้น | กระเป๋าเริ่ม %.1f kg"):format(#cand, bagKg()))

    local start = bagKg()
    for i, d in ipairs(cand) do
        if bagKg() < start - 0.5 then
            L(("🎉 ขายเข้าแล้ว! ตัวก่อนหน้าคือของจริง (ชิ้นที่ %d)"):format(i - 1))
            return
        end
        fireAll(d, "ชิ้น " .. i)
        task.wait(0.25)
        if bagKg() < start - 0.5 then
            L(("🎉🎉 เจอแล้ว! ชิ้นที่ %d = %s [%s]"):format(i,
                d:GetFullName():gsub("^Players%." .. LP.Name .. "%.PlayerGui%.", ""), d.ClassName))
            L("    → เอาชื่อนี้ไปใส่ AutoFarm ได้เลย")
            return
        end
    end
    L("❌ กดครบทุกชิ้นแล้วกระเป๋าไม่ลด — เมนูนี้ไม่รับ firesignal (ต้องหาทางอื่น)")
    L(("กระเป๋าตอนนี้ %.1f kg"):format(bagKg()))
end

-- v1.2: ดัก ContextActionService/UserInputService — เมนูอาจผูกปุ่ม 1-4 ไว้ตรงนี้ ไม่ใช่ GUI คลิก
local function listBinds()
    L("")
    L(">>> ปุ่มที่เกมผูกไว้ (ContextAction) <<<")
    local CAS = game:GetService("ContextActionService")
    local ok, binds = pcall(function() return CAS:GetAllBoundActionInfo() end)
    if ok and binds then
        local n = 0
        for name, info in pairs(binds) do
            n += 1
            local keys = {}
            for _, k in ipairs(info.inputTypes or {}) do keys[#keys + 1] = tostring(k) end
            L(("action '%s' ← %s"):format(name, table.concat(keys, ",")))
        end
        if n == 0 then L("(ไม่มี action ผูกอยู่)") end
    else
        L("❌ อ่าน ContextActionService ไม่ได้")
    end
    -- getconnections ของ UserInputService.InputBegan (ถ้า executor ให้)
    local gc = getconnections or (getgenv and getgenv().getconnections)
    if gc then
        local UIS = game:GetService("UserInputService")
        local ok2, conns = pcall(gc, UIS.InputBegan)
        L("UserInputService.InputBegan มีคนฟัง: " .. (ok2 and #conns or "อ่านไม่ได้") .. " ตัว")
        L("→ ถ้ามี เราสั่ง Fire ให้เหมือนกดคีย์ 1 ได้ (ปุ่ม 'ยิงคีย์ 1')")
    else
        L("executor ไม่มี getconnections")
    end
end

-- v1.2: จำลองกดคีย์ '1' ทุกทาง
local function fireKey1()
    L("")
    L(">>> ยิงคีย์ '1' ทุกทาง <<<")
    local before = bagKg()
    local VIM = select(2, pcall(function() return game:GetService("VirtualInputManager") end))
    if VIM then
        local ok = pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.One, false, game)
            task.wait(0.08)
            VIM:SendKeyEvent(false, Enum.KeyCode.One, false, game)
        end)
        L("VirtualInputManager SendKeyEvent: " .. tostring(ok))
    end
    local kp = keypress or (getgenv and getgenv().keypress)
    if kp then
        local kr = keyrelease or (getgenv and getgenv().keyrelease)
        local ok = pcall(function() kp(0x31); task.wait(0.08); if kr then kr(0x31) end end)
        L("keypress(0x31): " .. tostring(ok))
    else
        L("executor ไม่มี keypress")
    end
    -- ยิงเข้า connection ของ InputBegan ตรงๆ (จำลอง InputObject KeyCode.One)
    local gc = getconnections or (getgenv and getgenv().getconnections)
    if gc then
        local UIS = game:GetService("UserInputService")
        local ok, conns = pcall(gc, UIS.InputBegan)
        if ok then
            local fake = { KeyCode = Enum.KeyCode.One, UserInputType = Enum.UserInputType.Keyboard,
                UserInputState = Enum.UserInputState.Begin }
            local n = 0
            for _, cn in ipairs(conns) do
                pcall(function() cn:Fire(fake, false); n += 1 end)
            end
            L(("ยิงเข้า InputBegan %d ตัว"):format(n))
        end
    end
    task.wait(1.2)
    L(("กระเป๋า %.1f → %.1f kg %s"):format(before, bagKg(),
        bagKg() < before - 0.5 and "🎉 ขายเข้า!" or "(ไม่ขยับ)"))
end

-- ยิงทุกช่องทางที่เป็นไปได้
local function trySell()
    L("")
    L(">>> ลองกดขายทุกช่องทาง <<<")
    -- ก) firesignal ปุ่ม GUI ที่เจอ
    local fs = firesignal or (getgenv and getgenv().firesignal)
    if fs then
        for _, b in ipairs(foundBtns) do
            if isSellish(b.Text) or isSellish(b.Name) then
                local ok = pcall(fs, b.MouseButton1Click)
                pcall(fs, b.Activated)
                L(("firesignal → %s : %s"):format(b.Name, tostring(ok)))
            end
        end
    else
        L("❌ executor ไม่มี firesignal (กด GUI ตรงๆ ไม่ได้)")
    end
    -- ข) Dialog choice
    for _, d in ipairs(foundDialogs) do
        for _, ch in ipairs(d:GetDescendants()) do
            if ch:IsA("DialogChoice") and isSellish(ch.UserDialog) then
                local ok = pcall(function() d:SignalDialogChoiceSelected(LP, ch) end)
                L(("Dialog choice '%s' : %s"):format(ch.UserDialog, tostring(ok)))
            end
        end
    end
    -- ค) SellRequest หลายรูปแบบ
    local rem = RS:FindFirstChild("Remotes")
    local sr = rem and rem:FindFirstChild("SellRequest")
    if sr then
        local seller
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Model") and d.Name == "SellWorker" then seller = d break end
        end
        local tries = {
            { "()", function() sr:FireServer() end },
            { "(true)", function() sr:FireServer(true) end },
            { "('All')", function() sr:FireServer("All") end },
            { "(1)", function() sr:FireServer(1) end },
            { "(seller)", function() sr:FireServer(seller) end },
            { "(seller,'All')", function() sr:FireServer(seller, "All") end },
        }
        for _, t in ipairs(tries) do
            local ok = pcall(t[2])
            L(("SellRequest%s : ยิงแล้ว=%s"):format(t[1], tostring(ok)))
            task.wait(0.35)
        end
    else
        L("❌ ไม่เจอ RS.Remotes.SellRequest")
    end
    L(">>> จบ — ดูว่ากระเป๋าลดไหม/เงินขึ้นไหม แล้ว COPY ส่งผล <<<")
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "SellSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.SSPY75_GUI = gui

local box = Instance.new("TextBox", gui)
BOX = box
box.Size = UDim2.new(0, 620, 0, 300); box.Position = UDim2.new(0, 8, 0.3, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(255, 230, 170); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function redraw() box.Text = table.concat(OUT, "\n") end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.3, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local scanB = hbtn("SCAN", 8, 60, Color3.fromRGB(40, 130, 70))
local probeB = hbtn("ไล่กดทีละตัว", 72, 104, Color3.fromRGB(30, 120, 60))
local keyB  = hbtn("ยิงคีย์ 1", 180, 82, Color3.fromRGB(120, 60, 140))
local bindB = hbtn("ดูปุ่มผูก", 266, 82, Color3.fromRGB(40, 90, 150))
local menuB = hbtn("กดเมนู", 352, 70, Color3.fromRGB(60, 100, 60))
local sellB = hbtn("ยิง remote", 426, 90, Color3.fromRGB(150, 110, 30))
local copyB = hbtn("COPY", 520, 60)
local hideB = hbtn("ซ่อน", 584, 56, Color3.fromRGB(50, 50, 70))
local closeB = hbtn("✕", 644, 34, Color3.fromRGB(150, 40, 40))

-- v1.3: หุ้ม pcall ทุกปุ่ม — พังตรงไหนโชว์ error ให้เห็น (เดิมพังเงียบ จอว่าง)
local function run(name, fn)
    return function()
        task.spawn(function()
            L("")
            L("▶ " .. name .. " ...")
            local ok, err = pcall(fn)
            if not ok then L("💥 ERROR: " .. tostring(err)) end
            redraw()
        end)
    end
end
probeB.MouseButton1Click:Connect(run("ไล่กดทีละตัว", probeOneByOne))
keyB.MouseButton1Click:Connect(run("ยิงคีย์ 1", fireKey1))
bindB.MouseButton1Click:Connect(run("ดูปุ่มผูก", listBinds))

scanB.MouseButton1Click:Connect(run("SCAN", scan))
menuB.MouseButton1Click:Connect(run("กดเมนู", pressMenu))
sellB.MouseButton1Click:Connect(run("ยิง remote", trySell))
hideB.MouseButton1Click:Connect(function()
    box.Visible = not box.Visible
    hideB.Text = box.Visible and "ซ่อน" or "โชว์"
end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_sell_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function() gui:Destroy(); _G.SSPY75_GUI = nil end)

L("[SellSpy v1.3] เดินไปร้าน กด E ให้เมนูขายเด้งก่อน แล้วกด SCAN")
L("firesignal=" .. tostring((firesignal or (getgenv and getgenv().firesignal)) ~= nil)
    .. " (ถ้ามี = กดปุ่ม GUI ด้วยสคริปต์ได้)")
redraw()
