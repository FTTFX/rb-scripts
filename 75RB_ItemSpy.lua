-- 75RB_ItemSpy.lua v1.0 — เจาะดูของ "Pickup": ชื่อจริง/เกรด/ความหายากซ่อนอยู่ตรงไหน?
-- ดัมพ์ของใกล้ตัว 15 ชิ้น: ชื่อโมเดล+พ่อแม่ | Attributes ทุกตัว | ลูกทั้งหมด (ชื่อ:Class)
--   | สี/Material ของ part | ข้อความใน BillboardGui/TextLabel ถ้ามี
-- ปุ่ม: RESCAN | COPY | ✕
if _G.ISPY75_GUI then pcall(function() _G.ISPY75_GUI:Destroy() end) end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT = {}

local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local p = (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")))
        or inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local gui = Instance.new("ScreenGui")
gui.Name = "ItemSpy75"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.ISPY75_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 640, 0, 360); box.Position = UDim2.new(0, 8, 0.22, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.15
box.TextColor3 = Color3.fromRGB(180, 255, 190); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.22, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 14
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local rescanB = hbtn("RESCAN", 8, 90, Color3.fromRGB(40, 130, 70))
local copyB = hbtn("COPY", 104, 80)
local closeB = hbtn("✕", 190, 34, Color3.fromRGB(150, 40, 40))

local function dumpAttrs(inst)
    local a = {}
    for k, v in pairs(inst:GetAttributes()) do
        a[#a + 1] = k .. "=" .. tostring(v)
    end
    return table.concat(a, " ")
end

local function scan()
    OUT = {}
    local function L(s) OUT[#OUT + 1] = s end
    local mp = partPos(LP.Character)
    L("=== ItemSpy v1.0 " .. os.date("%H:%M:%S") .. " ===")
    -- เก็บ prompt "Pickup" ทั้งหมด → เรียงใกล้สุด → ดัมพ์ 15 ตัวแรก
    local list = {}
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Enabled and p.Parent
            and (p.ActionText == "Pickup" or p.ActionText == "Pick Up" or p.ActionText == "Take") then
            local pos = partPos(p.Parent)
            local d = pos and mp and (pos - mp).Magnitude or 1e9
            list[#list + 1] = { pp = p, d = d }
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    L("รวม prompt เก็บของ: " .. #list .. " | โชว์ 15 ตัวใกล้สุด")
    for i = 1, math.min(15, #list) do
        local pp = list[i].pp
        local holder = pp.Parent
        local model = holder:FindFirstAncestorOfClass("Model")
        L(("--- #%d ระยะ %.0fm ---"):format(i, list[i].d))
        -- เส้นทางพ่อแม่ 3 ชั้น
        local path = holder.Name .. ":" .. holder.ClassName
        local up = holder.Parent
        for _ = 1, 3 do
            if not up or up == workspace then break end
            path = up.Name .. ":" .. up.ClassName .. " > " .. path
            up = up.Parent
        end
        L("path: " .. path)
        L("prompt: Action='" .. pp.ActionText .. "' Object='" .. pp.ObjectText .. "' Hold=" .. pp.HoldDuration)
        -- Attributes ของ holder + model + prompt
        local a1 = dumpAttrs(pp);     if a1 ~= "" then L("attr(prompt): " .. a1) end
        local a2 = dumpAttrs(holder); if a2 ~= "" then L("attr(holder): " .. a2) end
        if model and model ~= holder then
            local a3 = dumpAttrs(model)
            if a3 ~= "" then L("attr(model " .. model.Name .. "): " .. a3) end
        end
        -- ลูกๆ ของ model/holder (ชื่อ:Class) — หา MeshPart ชื่อของจริง
        local root = model or holder
        local kids = {}
        for _, c in ipairs(root:GetChildren()) do
            kids[#kids + 1] = c.Name .. ":" .. c.ClassName
        end
        L("kids(" .. root.Name .. "): " .. table.concat(kids, ", "))
        -- สี/วัสดุ/mesh
        if holder:IsA("BasePart") then
            local c = holder.Color
            L(("part: Color=%d,%d,%d Mat=%s Size=%.1f,%.1f,%.1f"):format(
                c.R * 255, c.G * 255, c.B * 255, holder.Material.Name,
                holder.Size.X, holder.Size.Y, holder.Size.Z))
            if holder:IsA("MeshPart") then L("meshId: " .. holder.MeshId) end
        end
        -- ข้อความ GUI ที่ติดอยู่กับของ (ป้ายชื่อ/เกรดที่เกมโชว์เอง)
        for _, g in ipairs(root:GetDescendants()) do
            if g:IsA("TextLabel") and g.Text ~= "" then
                L("label[" .. g.Parent.Name .. "]: '" .. g.Text .. "'")
            end
        end
    end
    -- สรุปชื่อโมเดลไม่ซ้ำทั้งแมพ (นับจำนวน) — เผื่อชื่อโมเดล = ชื่อแร่
    local names = {}
    for _, e in ipairs(list) do
        local m = e.pp.Parent:FindFirstAncestorOfClass("Model") or e.pp.Parent
        names[m.Name] = (names[m.Name] or 0) + 1
    end
    local sum = {}
    for n, c in pairs(names) do sum[#sum + 1] = n .. " x" .. c end
    table.sort(sum)
    L("=== ชื่อโมเดลทั้งแมพ: " .. table.concat(sum, " | "))
    box.Text = table.concat(OUT, "\n")
end

rescanB.MouseButton1Click:Connect(scan)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "75RB_item_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function() gui:Destroy(); _G.ISPY75_GUI = nil end)

scan()
print("[75RB ItemSpy v1.0] พร้อม — เดินใกล้ๆ ของแล้วกด RESCAN")
