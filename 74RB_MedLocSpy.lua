-- 74RB_MedLocSpy.lua v1.0 — สปายตำแหน่งยา/ของเก็บทั้งแมพ (เกมอัปเดตย้ายจุดยา — บอทบินไปเอานอกแมพ)
-- dump: ทุก ProximityPrompt ที่หน้าตาเป็น "จุดเก็บของ" + ทุกอย่างใต้ Workspace.Model.Items
-- แต่ละรายการ: ชื่อยา | path เต็ม | พิกัด | ระยะจากเรา | ธง ⚠️ ถ้าดูเป็นของนอกแมพ
-- ปุ่ม: RESCAN | COPY | พับ | ✕

if _G.MEDLOCSPY_CONNS then
    for _, c in pairs(_G.MEDLOCSPY_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.MEDLOCSPY_CONNS = {}
local CONNS = _G.MEDLOCSPY_CONNS

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT = {}

-- ActionText ที่ "ไม่ใช่ของเก็บ" — ตัดทิ้ง (ที่เหลือทั้งหมดถือว่าน่าสนใจ จะได้เห็นยาชื่อใหม่ด้วย)
local SKIP = {
    Talk = true, Open = true, Locked = true, Inspect = true, Register = true,
    ["Stamp Forms"] = true, Take = true, ["Print Badge"] = true, ["Take Photo"] = true,
    ["Apply Treatment"] = true, ["Analyze Sample"] = true, ["Process Results"] = true,
    ["Take DNA Sample"] = true, ["Prepare Patient"] = true, ["Sleep Patient"] = true,
    ["Set Up"] = true, ["Turn On"] = true, Begin = true, ["Begin X-Ray"] = true, Collect = true,
    ["Clean Slime"] = true, ["Put out fire"] = true, Fire = true, ["Treat Burns"] = true,
    Struggle = true, Carry = true, ["Place Patient"] = true, Help = true, ["Ask to Leave"] = true,
    Buy = true, ["Buy Gun"] = true, Coffee = true, ["Reroll Shop"] = true, ["Fix Camera"] = true,
    ["Scan Identity"] = true, ["Jumpscare All"] = true, ["Trash Item"] = true,
}

local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local p = (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")))
        or inst:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end

local gui = Instance.new("ScreenGui")
gui.Name = "MedLocSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 600, 0, 360); box.Position = UDim2.new(0, 8, 0.24, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(160, 255, 180); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false
box.Text = "[MedLocSpy] กด RESCAN"

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.24, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 14
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local rescanB = hbtn("RESCAN", 8, 90, Color3.fromRGB(40, 130, 70))
local copyB = hbtn("COPY", 104, 80)
local foldB = hbtn("พับ", 190, 56, Color3.fromRGB(90, 70, 40))
local closeB = hbtn("✕", 252, 34, Color3.fromRGB(150, 40, 40))

local function scan()
    OUT = {}
    local function L(s) OUT[#OUT + 1] = s end
    local me = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local mp = me and me.Position
    L("=== MedLocSpy v1.0 " .. os.date("%H:%M:%S") .. " | เรา=" ..
        (mp and ("%.0f,%.0f,%.0f"):format(mp.X, mp.Y, mp.Z) or "?") .. " ===")

    -- 1) จุดเก็บของทั้งแมพ (ProximityPrompt ที่ไม่อยู่ในลิสต์ตัด) — จัดกลุ่มตามชื่อ
    local byName = {}
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Parent and p.ActionText ~= ""
           and not SKIP[p.ActionText] then
            local pos = partPos(p.Parent)
            if pos then
                byName[p.ActionText] = byName[p.ActionText] or {}
                table.insert(byName[p.ActionText], { p = p, pos = pos })
            end
        end
    end
    local names = {}
    for n in pairs(byName) do names[#names + 1] = n end
    table.sort(names)
    L("-- จุดเก็บของ (ตาม ActionText) --")
    for _, n in ipairs(names) do
        local list = byName[n]
        L(("● '%s' × %d จุด"):format(n, #list))
        for _, it in ipairs(list) do
            local d = mp and (it.pos - mp).Magnitude
            -- ธงนอกแมพ: ต่ำกว่าพื้น / สูงกว่าเรามาก / ไกลมาก (เกณฑ์เดียวกับ findPickup ใน main)
            local flag = ""
            if it.pos.Y < -50 then flag = " ⚠️ใต้แมพ"
            elseif mp and it.pos.Y - mp.Y > 25 then flag = " ⚠️บนฟ้า"
            elseif d and d > 150 then flag = " ⚠️ไกล(>150)"
            end
            L(("   (%.0f,%.0f,%.0f) %s%s Enabled=%s @ %s"):format(
                it.pos.X, it.pos.Y, it.pos.Z,
                d and ("%.0fm"):format(d) or "?", flag, tostring(it.p.Enabled),
                it.p.Parent:GetFullName()))
        end
    end

    -- 2) โครง Workspace.Model.Items (ที่เก็บยาเดิม) — ดูว่าเกมย้าย/เปลี่ยนชื่อ folder ไหม
    L("-- Workspace.Model.Items (path ยาเดิม) --")
    local model = workspace:FindFirstChild("Model")
    local items = model and model:FindFirstChild("Items")
    if items then
        for _, it in ipairs(items:GetChildren()) do
            local pos = partPos(it)
            L(("  %s @ %s"):format(it.Name, pos and ("(%.0f,%.0f,%.0f)"):format(pos.X, pos.Y, pos.Z) or "?"))
        end
    else
        L("  ⚠️ ไม่พบ Workspace.Model.Items — เกมย้าย path แล้วแน่นอน!")
        -- หา folder ที่ชื่อคล้าย Items ทั้ง workspace
        for _, o in ipairs(workspace:GetDescendants()) do
            if (o:IsA("Folder") or o:IsA("Model")) and o.Name:lower():find("item") then
                L("  เจอชื่อคล้าย: " .. o:GetFullName() .. " (ลูก " .. #o:GetChildren() .. ")")
            end
        end
    end
    box.Text = table.concat(OUT, "\n")
end

table.insert(CONNS, rescanB.MouseButton1Click:Connect(scan))
table.insert(CONNS, copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "74RB_medloc_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end))
table.insert(CONNS, foldB.MouseButton1Click:Connect(function()
    box.Visible = not box.Visible
    foldB.Text = box.Visible and "พับ" or "กาง"
end))
table.insert(CONNS, closeB.MouseButton1Click:Connect(function()
    for _, c in pairs(CONNS) do pcall(function() c:Disconnect() end) end
    _G.MEDLOCSPY_CONNS = {}
    gui:Destroy()
end))

scan()
print("[74RB MedLocSpy v1.0] พร้อม — RESCAN หลังวินิจฉัย (ยาบางตัวโผล่ตอนจอเรียก)")
