-- 74RB_AnimalHospital_RoomDebug.lua v1.0 — เช็คเงื่อนไข treat loop ทีละข้อ (ทำไมบอทไม่วาปไปห้อง)
-- GUI + ปุ่ม RESCAN + Copy (ตาม DW_SpyTemplate)
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

if _G.AH74DBG_GUI then pcall(function() _G.AH74DBG_GUI:Destroy() end) end

local function partPos(i)
    if not i then return nil end
    if i:IsA("BasePart") then return i.Position end
    local b = i:FindFirstChildWhichIsA("BasePart", true)
    return b and b.Position
end

local function scan()
    local out = {}
    local function L(s) out[#out+1] = s end
    L("=== AH74 RoomDebug v1.6 ===")
    -- v1.6: dump ข้อความบนจอ (PlayerGui) — หาแบนเนอร์เหตุการณ์ เช่น "ผู้ป่วยวิกฤตในห้อง 3 — 28s"
    L("=== PLAYERGUI TEXTS (ที่มองเห็น) ===")
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetDescendants()) do
            if (g:IsA("TextLabel") or g:IsA("TextButton")) and g.Visible and g.Text ~= ""
               and #g.Text <= 80 then
                local sg = g:FindFirstAncestorWhichIsA("ScreenGui")
                local root = sg and sg.Name or "?"
                if root ~= "AH74DBG" and root:sub(1, 4) ~= "AH74" then
                    L(("[UI] %s | '%s'"):format(g:GetFullName():gsub("Players%.[^.]+%.PlayerGui%.", ""), g.Text))
                end
            end
        end
    end
    -- v1.5: dump ของที่ถืออยู่ (หา่ชื่อจริงของน้ำเชื่อม/ของ station)
    L("=== TOOLS ในมือ/กระเป๋า ===")
    local bp = LP:FindFirstChild("Backpack")
    for _, holder in ipairs({bp, LP.Character}) do
        if holder then
            for _, t in ipairs(holder:GetChildren()) do
                if t:IsA("Tool") then
                    local a = {}
                    for k, v in pairs(t:GetAttributes()) do a[#a+1] = k.."="..tostring(v) end
                    L("[TOOL] '"..t.Name.."' ที่="..holder.Name.." "..table.concat(a, " "))
                end
            end
        end
    end
    -- v1.5: หา "ผีพื้น" — Model มี Humanoid/AnimationController ใกล้เรา ≤120 ที่ไม่ใช่ player/NPC folder
    L("=== ตัวเคลื่อนไหวใกล้เรา (นอก NPCs) ===")
    local myp = LP.Character and partPos(LP.Character)
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") or d:IsA("AnimationController") then
            local m = d.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m)
               and not (m.Parent and m.Parent.Name == "NPCs") then
                local p = partPos(m)
                local dist = p and myp and (p - myp).Magnitude
                if dist and dist <= 120 then
                    local a = {}
                    for k, v in pairs(m:GetAttributes()) do a[#a+1] = k.."="..tostring(v) end
                    L(("[MOB] %s ระยะ=%d | %s"):format(m:GetFullName(), dist, table.concat(a, " ")))
                    for _, p2 in ipairs(m:GetDescendants()) do
                        if p2:IsA("ProximityPrompt") then
                            L(("   PP '%s' obj=%s Enabled=%s"):format(p2.ActionText, p2.Parent.Name, tostring(p2.Enabled)))
                        end
                    end
                end
            end
        end
    end
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then L("!! ไม่มี workspace.NPCs") else
        L("=== NPCs ("..#npcs:GetChildren()..") ===")
        for _, m in ipairs(npcs:GetChildren()) do
            local a = {}
            for k, v in pairs(m:GetAttributes()) do a[#a+1] = k.."="..tostring(v) end
            table.sort(a)
            L("[NPC] "..m.Name.." | "..table.concat(a, " "))
            for _, p in ipairs(m:GetDescendants()) do
                if p:IsA("ProximityPrompt") then
                    L(("   PP '%s' obj=%s Enabled=%s"):format(p.ActionText, p.Parent.Name, tostring(p.Enabled)))
                end
            end
        end
    end
    -- v1.3: ตามหาสไลม์/Grime/Anomaly ทั้ง workspace (ไม่อยู่ใต้ NPCs)
    L("=== SLIME/GRIME/ANOMALY ===")
    for _, d in ipairs(workspace:GetDescendants()) do
        local n = d.Name:lower()
        if d:IsA("Model") or d:IsA("BasePart") then
            if n:find("slime") or n:find("grime") or n:find("goo") or n:find("anomal") or n:find("puddle") then
                local a = {}
                for k, v in pairs(d:GetAttributes()) do a[#a+1] = k.."="..tostring(v) end
                L("[OBJ] "..d:GetFullName().." | "..table.concat(a, " "))
                for _, p in ipairs(d:GetDescendants()) do
                    if p:IsA("ProximityPrompt") then
                        L(("   PP '%s' obj=%s Enabled=%s"):format(p.ActionText, p.Parent.Name, tostring(p.Enabled)))
                    end
                end
            end
        end
    end
    -- v1.4: dump prompt ทุกตัวใต้ Misc (เคาน์เตอร์/โต๊ะต้อนรับผู้เยี่ยม/กริ่ง/กล้อง)
    L("=== MISC PROMPTS ===")
    local misc = workspace:FindFirstChild("Misc")
    if misc then
        for _, p in ipairs(misc:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                L(("[MISC] '%s' obj=%s path=%s Enabled=%s Hold=%.1f"):format(
                    p.ActionText, p.Parent.Name,
                    p.Parent.Parent and p.Parent.Parent.Name or "?", tostring(p.Enabled), p.HoldDuration))
            end
        end
    else L("!! ไม่มี workspace.Misc") end
    L("=== ROOMS ===")
    local rooms = workspace:FindFirstChild("Rooms")
    if not rooms then L("!! ไม่มี workspace.Rooms") end
    if rooms and npcs then
        for _, grp in ipairs({"Medical", "Emergency"}) do
            local g = rooms:FindFirstChild(grp)
            if not g then L("!! ไม่มีกลุ่ม "..grp) else
                for _, room in ipairs(g:GetChildren()) do
                    local pat
                    for _, m in ipairs(npcs:GetChildren()) do
                        if m:GetAttribute("DesignatedRoom") == room.Name then pat = m; break end
                    end
                    local ui = room:FindFirstChild("Minigame")
                    ui = ui and ui:FindFirstChild("TV"); ui = ui and ui:FindFirstChild("Screen")
                    ui = ui and ui:FindFirstChild("UI")
                    local healing = ui and ui:FindFirstChild("Healing")
                    local rep = ui and ui:FindFirstChild("Report")
                    local rp = partPos(room:FindFirstChild("Minigame") or room)
                    local nearest, nd
                    for _, m in ipairs(npcs:GetChildren()) do
                        local p = m:IsA("Model") and partPos(m)
                        local d = p and rp and (p - rp).Magnitude
                        if d and (not nearest or d < nd) then nearest, nd = m, d end
                    end
                    L(("[%s/%s] pat=%s UI=%s Report=%s Healing=%s ใกล้สุด=%s(%d)"):format(
                        grp, room.Name, pat and pat.Name or "nil",
                        tostring(ui ~= nil), tostring(rep ~= nil),
                        tostring(healing and healing.Visible),
                        nearest and nearest.Name or "-", nd and math.floor(nd) or -1))
                    -- v1.1: dump prompt ทุกตัวในห้อง + inv
                    for _, p in ipairs(room:GetDescendants()) do
                        if p:IsA("ProximityPrompt") then
                            L(("   PP '%s' obj=%s Enabled=%s Hold=%.1f"):format(
                                p.ActionText, p.Parent.Name, tostring(p.Enabled), p.HoldDuration))
                        end
                    end
                    local inv = rep and rep:FindFirstChild("inv")
                    if inv then
                        for _, fr in ipairs(inv:GetChildren()) do
                            if fr:IsA("GuiObject") then
                                local nm = fr:FindFirstChild("name")
                                L("   INV "..fr.Name.." name="..tostring(nm and nm:IsA("TextLabel") and nm.Text))
                            end
                        end
                    end
                end
            end
        end
    end
    return table.concat(out, "\n")
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AH74DBG", false, 10000
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
_G.AH74DBG_GUI = gui

local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 340, 0, 300), UDim2.new(0.5, -170, 0.5, -150)
f.BackgroundColor3, f.Active, f.Draggable = Color3.fromRGB(15, 15, 20), true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local box = Instance.new("TextBox", f)
box.Size, box.Position = UDim2.new(1, -12, 1, -50), UDim2.new(0, 6, 0, 6)
box.MultiLine, box.ClearTextOnFocus, box.TextEditable = true, false, false
box.TextWrapped, box.TextXAlignment, box.TextYAlignment = false, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
box.Font, box.TextSize = Enum.Font.Code, 11
box.BackgroundColor3, box.TextColor3 = Color3.fromRGB(25, 25, 32), Color3.fromRGB(200, 255, 200)
box.Text = scan()

local function mkbtn(txt, x, cb)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0, 100, 0, 32), UDim2.new(0, x, 1, -40)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(50, 50, 70), Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
end
mkbtn("RESCAN", 6, function() box.Text = scan() end)
mkbtn("COPY", 112, function()
    pcall(function() (setclipboard or toclipboard)(box.Text) end)
end)
mkbtn("CLOSE", 218, function() gui:Destroy(); _G.AH74DBG_GUI = nil end)

print("[AH74 RoomDebug v1.2] พร้อม — RESCAN ตอนมีคนไข้นอนห้อง แล้ว COPY ส่งมา")
