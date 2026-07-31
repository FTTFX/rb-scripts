-- 74RB_PatSpy.lua v1.0 — สปายตำแหน่ง NPC/คนไข้ทุกตัว: มีตัวก๊อปจอดนอกกรอบไหม?
-- แต่ละตัว: ชื่อ | พิกัด | DesignatedRoom | InBed | Treated | Skinwalker | ธง ⚠️ ถ้าอยู่นอกกรอบโรงพยาบาล
-- ปุ่ม: RESCAN | COPY | ✕
local HOSP = { x1 = -175, x2 = -85, z1 = -145, z2 = 130 }   -- กรอบเดียวกับ main v6.63

if _G.PATSPY_GUI then pcall(function() _G.PATSPY_GUI:Destroy() end) end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local OUT = {}

local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local b = inst:FindFirstChildWhichIsA("BasePart", true)
    return b and b.Position
end

local gui = Instance.new("ScreenGui")
gui.Name = "PatSpy"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
_G.PATSPY_GUI = gui

local box = Instance.new("TextBox", gui)
box.Size = UDim2.new(0, 620, 0, 340); box.Position = UDim2.new(0, 8, 0.26, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(180, 220, 255); box.TextSize = 11; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true; box.MultiLine = true
box.ClearTextOnFocus = false; box.TextEditable = false

local function hbtn(txt, x, w, col)
    local b = Instance.new("TextButton", gui)
    b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 0.26, -34)
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 14
    b.BackgroundColor3 = col or Color3.fromRGB(40, 90, 150); b.TextColor3 = Color3.new(1, 1, 1)
    return b
end
local rescanB = hbtn("RESCAN", 8, 90, Color3.fromRGB(40, 130, 70))
local copyB = hbtn("COPY", 104, 80)
local closeB = hbtn("✕", 190, 34, Color3.fromRGB(150, 40, 40))

local function scan()
    OUT = {}
    local function L(s) OUT[#OUT + 1] = s end
    local me = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local mp = me and me.Position
    L("=== PatSpy v1.0 " .. os.date("%H:%M:%S") .. " | เรา=" ..
        (mp and ("%.0f,%.0f,%.0f"):format(mp.X, mp.Y, mp.Z) or "?") .. " ===")
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then L("⚠️ ไม่พบ Workspace.NPCs"); box.Text = table.concat(OUT, "\n"); return end
    for _, m in ipairs(npcs:GetChildren()) do
        if m:IsA("Model") then
            local p = partPos(m)
            local outMap = p and not (p.X > HOSP.x1 and p.X < HOSP.x2 and p.Z > HOSP.z1 and p.Z < HOSP.z2)
            local a = {}
            for _, k in ipairs({ "DesignatedRoom", "InBed", "IsPatient", "IsVisitor", "Skinwalker",
                                 "Anomaly", "Treated", "CompletedCheckIn", "CarriedBy" }) do
                local v = m:GetAttribute(k)
                if v ~= nil then a[#a + 1] = k .. "=" .. tostring(v) end
            end
            L(("%s%s @ %s | %s"):format(
                outMap and "⚠️นอกกรอบ! " or "", m.Name,
                p and ("(%.0f,%.0f,%.0f)"):format(p.X, p.Y, p.Z) or "?",
                table.concat(a, " ")))
        end
    end
    box.Text = table.concat(OUT, "\n")
end

rescanB.MouseButton1Click:Connect(scan)
copyB.MouseButton1Click:Connect(function()
    local text = table.concat(OUT, "\n")
    local clip = (typeof(setclipboard) == "function" and setclipboard)
        or (typeof(toclipboard) == "function" and toclipboard)
    local ok = clip and pcall(clip, text)
    local saved = typeof(writefile) == "function" and pcall(writefile, "74RB_pat_log.txt", text)
    copyB.Text = ok and "คัดลอกแล้ว!" or (saved and "เซฟไฟล์แล้ว!" or "copy ไม่ได้!")
    task.delay(1.6, function() copyB.Text = "COPY" end)
end)
closeB.MouseButton1Click:Connect(function() gui:Destroy(); _G.PATSPY_GUI = nil end)

scan()
print("[74RB PatSpy v1.0] พร้อม — RESCAN ตอนบอทติดสถานะ 'บล็อคเป้าโซนก๊อป'")
