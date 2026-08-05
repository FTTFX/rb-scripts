-- 75RB_BagSpy.lua v1.0 — หาว่า "น้ำหนักกระเป๋า ปัจจุบัน/เพดาน" (เช่น 656/1237) เก็บไว้ไหน
-- ค้น: (1) Attributes ของ Player / Character / ทุก instance ใน Player
--      (2) leaderstats / Values ทุกตัวใต้ Player
--      (3) ข้อความ GUI ที่มีรูป "ตัวเลข / ตัวเลข"
--      (4) Attributes ทุกตัวใน ReplicatedStorage ชั้นบน
-- → เจอ path ไหนตรงกับเลขบนจอ = AutoFarm อ่านค่านั้นตัดสินใจไปขาย
if _G.BSPY75_GUI then pcall(function() _G.BSPY75_GUI:Destroy() end) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local OUT = {}
local function L(s) OUT[#OUT + 1] = s end

local function dumpAttrs(inst, label, deep)
    local list = deep and inst:GetDescendants() or { inst }
    if deep then table.insert(list, 1, inst) end
    for _, d in ipairs(list) do
        local ok, attrs = pcall(function() return d:GetAttributes() end)
        if ok then
            for k, v in pairs(attrs) do
                if typeof(v) == "number" then
                    L(("attr %s%s.%s = %s"):format(label,
                        d == inst and "" or ("." .. d.Name), k, tostring(v)))
                end
            end
        end
    end
end

local function scan()
    OUT = {}
    L("=== BagSpy — หาที่เก็บน้ำหนักกระเป๋า ===")

    -- (1)+(2) Player ทั้งยวง (attrs + ValueBase)
    L("--- Player attrs/values ---")
    dumpAttrs(LP, "LP", true)
    for _, d in ipairs(LP:GetDescendants()) do
        if d:IsA("ValueBase") then
            L(("value LP.%s (%s) = %s"):format(d:GetFullName():gsub(".*" .. LP.Name .. "%.", ""),
                d.ClassName, tostring(d.Value)))
        end
    end
    if LP.Character then
        L("--- Character attrs ---")
        dumpAttrs(LP.Character, "Char", true)
    end

    -- (3) GUI ที่หน้าตาเป็น "x / y"
    L("--- GUI 'ตัวเลข / ตัวเลข' ---")
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
                local a, b = d.Text:match("([%d,%.]+)%s*/%s*([%d,%.]+)")
                if a and b then
                    L(("gui %s = '%s'"):format(
                        d:GetFullName():gsub("^Players%." .. LP.Name .. "%.PlayerGui%.", ""), d.Text))
                end
            end
        end
    end

    -- (4) RS ชั้นบน (config เกมชอบวางไว้)
    L("--- ReplicatedStorage attrs (ชั้นบน) ---")
    dumpAttrs(RS, "RS", false)
    for _, d in ipairs(RS:GetChildren()) do dumpAttrs(d, "RS." .. d.Name, false) end

    L("=== จบ — มองหาเลขที่ตรงกับบนจอ (เช่น 656 / 1237) แล้ว COPY ส่งผล ===")
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "BagSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.BSPY75_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 640, 0, 330); box.Position = UDim2.new(0, 8, 0.26, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(255, 210, 140); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function redraw() box.Text = table.concat(OUT, "\n") end

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.26, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local rescanB = hbtn("RESCAN", 8, 80, Color3.fromRGB(40, 130, 70))
local copyB   = hbtn("COPY", 92, 70)
local closeB  = hbtn("✕", 166, 34, Color3.fromRGB(150, 40, 40))

rescanB.MouseButton1Click:Connect(function() scan(); redraw() end)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_bag_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function() gui:Destroy(); _G.BSPY75_GUI = nil end)

scan(); redraw()
