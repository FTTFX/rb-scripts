-- Egg01 Egg Status Spy v4.2 — ขั้น1: โมเดลใกล้ตัว (fix Folder PrimaryPart)

if _G.EGG01_EGG_STATUS_SPY then
    pcall(function() _G.EGG01_EGG_STATUS_SPY.gui:Destroy() end)
    for _, c in ipairs(_G.EGG01_EGG_STATUS_SPY.conns or {}) do pcall(function() c:Disconnect() end) end
end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local S = { gui = nil, lines = {}, conns = {} }
_G.EGG01_EGG_STATUS_SPY = S

local ME = tostring(LP.UserId)
local box
local NEAR_D = 40
local MAX_MODELS = 25

local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 220 then table.remove(S.lines, 1) end
    if box then box.Text = table.concat(S.lines, "\n") end
end

local function hr()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function pathOf(x)
    local ok, s = pcall(function() return x:GetFullName() end)
    return ok and s:gsub("^Workspace%.", "WS.") or tostring(x)
end

local function instPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, piv = pcall(function() return inst:GetPivot() end)
        if ok and piv then return piv.Position end
        local pp = inst.PrimaryPart
        if pp then return pp.Position end
        local p = inst:FindFirstChildWhichIsA("BasePart", true)
        return p and p.Position
    end
    -- Folder / อื่นๆ — ห้ามแตะ PrimaryPart
    local ok, piv = pcall(function() return inst:GetPivot() end)
    if ok and piv then return piv.Position end
    local p = inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local function interestingName(n)
    local low = tostring(n or ""):lower()
    return low:find("egg", 1, true) or low:find("mut", 1, true)
        or low:find("scrambl", 1, true) or low:find("prompt", 1, true)
        or low:find("smart", 1, true) or low:find("incub", 1, true)
        or low:find("nest", 1, true) or low:find("slot", 1, true)
        or low:find("stand", 1, true) or low:find("pen", 1, true)
        or low:find("farm", 1, true) or low:find("plot", 1, true)
end

local function collectTexts(root, limit)
    local texts, seen = {}, {}
    if not root then return texts end
    local n = 0
    local ok, desc = pcall(function() return root:GetDescendants() end)
    if not ok or not desc then return texts end
    for _, d in ipairs(desc) do
        if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" then
            local t = d.Text:gsub("%s+", " "):match("^%s*(.-)%s*$")
            if t and #t > 0 and not seen[t] then
                seen[t] = true
                texts[#texts + 1] = t
                n = n + 1
                if n >= (limit or 12) then break end
            end
        end
    end
    return texts
end

local function addNear(out, seen, inst, rootPos, maxD)
    if not inst or seen[inst] then return end
    local char = LP.Character
    if char and (inst == char or inst:IsDescendantOf(char)) then return end
    local p = instPos(inst)
    if not p then return end
    local d = (p - rootPos).Magnitude
    if d > maxD then return end
    seen[inst] = true
    out[#out + 1] = { inst = inst, d = d, p = p }
end

-- สแกนเฉพาะชั้นตื้น — ห้าม workspace:GetDescendants()
local function nearRoots(maxD)
    local root = hr()
    local out, seen = {}, {}
    if not root then return out end
    local rp = root.Position

    say("…สแกน ClientRenderedAssets")
    local cra = workspace:FindFirstChild("ClientRenderedAssets")
    if cra then
        for _, m in ipairs(cra:GetChildren()) do
            addNear(out, seen, m, rp, maxD)
        end
        say(string.format("  CRA children=%d near=%d", #cra:GetChildren(), #out))
    else
        say("  (ไม่มี ClientRenderedAssets)")
    end

    say("…สแกน AreaEggSlotsClient")
    local slots = workspace:FindFirstChild("AreaEggSlotsClient")
    if slots then
        for _, m in ipairs(slots:GetChildren()) do
            addNear(out, seen, m, rp, maxD)
        end
    end

    say("…สแกน workspace ชั้นบน + ลูก 1 ชั้น")
    for _, ch in ipairs(workspace:GetChildren()) do
        if interestingName(ch.Name) or ch.Name == "SmartPromptPart" then
            addNear(out, seen, ch, rp, maxD)
        end
        -- SmartPromptPart มักเป็น Part กระจายใต้โฟลเดอร์
        local okKids, kids = pcall(function() return ch:GetChildren() end)
        if okKids then
            for _, sub in ipairs(kids) do
                if sub.Name == "SmartPromptPart" or interestingName(sub.Name) then
                    addNear(out, seen, sub, rp, maxD)
                end
                -- ชั้น 2 เฉพาะชื่อน่าสนใจ
                if interestingName(sub.Name) or sub.Name == "SmartPromptPart" then
                    local ok2, kids2 = pcall(function() return sub:GetChildren() end)
                    if ok2 then
                        for _, s2 in ipairs(kids2) do
                            if s2.Name == "SmartPromptPart" or interestingName(s2.Name) then
                                addNear(out, seen, s2, rp, maxD)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Overlap: BasePart ในรัศมี (เร็วกว่า GetDescendants)
    say("…OverlapParams รัศมี " .. maxD)
    pcall(function()
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LP.Character then params.FilterDescendantsInstances = { LP.Character } end
        local parts = workspace:GetPartBoundsInRadius(rp, maxD, params)
        local nPart = 0
        for _, part in ipairs(parts) do
            nPart = nPart + 1
            -- โฮสต์ = Model บรรพบุรุษ หรือตัวพาร์ท
            local host = part:FindFirstAncestorWhichIsA("Model") or part
            addNear(out, seen, host, rp, maxD)
            if part.Name == "SmartPromptPart" or interestingName(part.Name) then
                addNear(out, seen, part, rp, maxD)
            end
            -- Prompt ใต้พาร์ท
            for _, ch in ipairs(part:GetChildren()) do
                if ch:IsA("ProximityPrompt") then
                    addNear(out, seen, part, rp, maxD)
                end
            end
        end
        say(string.format("  overlap parts=%d hosts_total=%d", nPart, #out))
    end)

    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local function dumpModel(entry, idx)
    local m = entry.inst
    local texts = collectTexts(m, 10)
    local prompts, flags = {}, {}
    local descCount = 0
    pcall(function()
        local desc = m:GetDescendants()
        descCount = #desc
        for _, d in ipairs(desc) do
            if d:IsA("ProximityPrompt") then
                prompts[#prompts + 1] = {
                    act = tostring(d.ActionText or ""),
                    obj = tostring(d.ObjectText or ""),
                    en = d.Enabled,
                    hold = d.HoldDuration,
                    maxD = d.MaxActivationDistance,
                    path = pathOf(d),
                }
            end
            if interestingName(d.Name) then
                flags[#flags + 1] = d.ClassName .. ":" .. d.Name
            end
        end
    end)

    local mine = tostring(m.Name):sub(1, #ME + 1) == (ME .. "_")
    say(string.format(
        "===== NEAR#%d d=%.1f %s %s%s =====",
        idx, entry.d, m.ClassName, m.Name, mine and " [OURS]" or ""
    ))
    say("  path=" .. pathOf(m))
    say(string.format("  descendants=%d prompts=%d", descCount, #prompts))

    if #texts > 0 then
        say("  texts: " .. table.concat(texts, " || "))
    else
        say("  texts: (ไม่มี)")
    end

    if #prompts == 0 then
        say("  prompts: (ไม่มีในโมเดลนี้)")
    else
        for i, pr in ipairs(prompts) do
            say(string.format(
                "  PP#%d en=%s hold=%.1f maxD=%.0f act=%q obj=%q",
                i, tostring(pr.en), pr.hold or 0, pr.maxD or 0, pr.act, pr.obj
            ))
            say("       " .. pr.path)
        end
    end

    if #flags > 0 then
        local show = {}
        for i = 1, math.min(15, #flags) do show[i] = flags[i] end
        say("  flags: " .. table.concat(show, ", ") .. (#flags > 15 and (" +" .. (#flags - 15)) or ""))
    end

    local kids = {}
    for _, ch in ipairs(m:GetChildren()) do
        kids[#kids + 1] = ch.ClassName .. ":" .. ch.Name
        if #kids >= 24 then break end
    end
    if #kids > 0 then say("  children: " .. table.concat(kids, ", ")) end
end

local function scanNear()
    S.lines = {}
    say("=== Egg Spy v4.2 — ขั้น1 NEAR (โมเดลใกล้ตัว) ===")
    say("UserId=" .. ME .. " | radius=" .. NEAR_D)
    local root = hr()
    if not root then
        say("ไม่มี HRP")
        say("=== DONE ===")
        return
    end
    say(string.format("HRP=%.0f,%.0f,%.0f", root.Position.X, root.Position.Y, root.Position.Z))

    local ok, listOrErr = pcall(nearRoots, NEAR_D)
    if not ok then
        say("nearRoots error: " .. tostring(listOrErr))
        say("=== DONE ===")
        return
    end
    local list = listOrErr
    say(string.format("--- พบใกล้ตัว: %d (โชว์สูงสุด %d) ---", #list, MAX_MODELS))

    local n = math.min(MAX_MODELS, #list)
    if n == 0 then
        say("(ว่าง — เดินชิดไข่/สัตว์ในคอก แล้วกด NEAR)")
        -- ช่วย debug: CRA ใกล้สุดแม้เกินรัศมี
        local cra = workspace:FindFirstChild("ClientRenderedAssets")
        if cra then
            local best
            for _, m in ipairs(cra:GetChildren()) do
                if tostring(m.Name):sub(1, #ME + 1) == (ME .. "_") then
                    local p = instPos(m)
                    if p then
                        local d = (p - root.Position).Magnitude
                        if not best or d < best.d then best = { m = m, d = d } end
                    end
                end
            end
            if best then
                say(string.format("CRA ของเราใกล้สุด: d=%.0f %s", best.d, best.m.Name))
            else
                say("CRA ของเรา: ไม่เจอ")
            end
        end
    end
    for i = 1, n do
        local okD, err = pcall(dumpModel, list[i], i)
        if not okD then say("  dump error: " .. tostring(err)) end
    end

    say("=== DONE — ส่งล็อกมาเพื่อสืบโครงสร้างไข่ ===")
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_EggStatusSpy"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1030
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
S.gui = gui

local f = Instance.new("Frame", gui)
f.Size = UDim2.new(0, 640, 0, 360)
f.Position = UDim2.new(0, 12, 0.18, 0)
f.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", f)
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "Egg01 Spy v4.2 — NEAR โมเดลใกล้ตัว"
title.TextColor3 = Color3.fromRGB(160, 230, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local function btn(tx, x, col)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, 72, 0, 28)
    b.Position = UDim2.new(0, x, 0, 36)
    b.Text = tx
    b.BackgroundColor3 = col
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local bNear = btn("NEAR", 10, Color3.fromRGB(45, 110, 170))
local bClear = btn("CLEAR", 88, Color3.fromRGB(70, 70, 75))
local bCopy = btn("COPY", 166, Color3.fromRGB(70, 70, 75))
local bClose = btn("X", 556, Color3.fromRGB(145, 50, 65))

box = Instance.new("TextBox", f)
box.Size = UDim2.new(1, -16, 0, 280)
box.Position = UDim2.new(0, 8, 0, 72)
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(190, 245, 200)
box.Font = Enum.Font.Code
box.TextSize = 11
box.TextEditable = false
box.MultiLine = true
box.ClearTextOnFocus = false
box.TextWrapped = false
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.Text = "ยืนชิดไข่ → NEAR → COPY\nv4.2 fix Folder PrimaryPart"

bNear.MouseButton1Click:Connect(scanNear)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Spy v4.2 NEAR ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bClose.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_EGG_STATUS_SPY = nil
end)

say("v4.2 — ยืนชิดไข่ แล้วกด NEAR")
