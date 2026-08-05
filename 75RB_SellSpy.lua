-- 75RB_SellSpy.lua v1.0 — แกะเมนูขาย (กด 1 ไม่ได้!) เพื่อกดมันด้วยสคริปต์
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
local function L(s) OUT[#OUT + 1] = s end

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
local scanB = hbtn("SCAN", 8, 66, Color3.fromRGB(40, 130, 70))
local sellB = hbtn("กดขายให้เลย", 78, 108, Color3.fromRGB(150, 110, 30))
local copyB = hbtn("COPY", 190, 66)
local hideB = hbtn("ซ่อน", 260, 60, Color3.fromRGB(50, 50, 70))
local closeB = hbtn("✕", 324, 34, Color3.fromRGB(150, 40, 40))

scanB.MouseButton1Click:Connect(function() scan(); redraw() end)
sellB.MouseButton1Click:Connect(function()
    task.spawn(function() trySell(); redraw() end)
end)
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

L("[SellSpy v1.0] เดินไปร้าน กด E ให้เมนูขายเด้งก่อน แล้วกด SCAN")
L("firesignal=" .. tostring((firesignal or (getgenv and getgenv().firesignal)) ~= nil)
    .. " (ถ้ามี = กดปุ่ม GUI ด้วยสคริปต์ได้)")
redraw()
