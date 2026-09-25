-- Egg01 Egg Status Spy v5.0 — ขั้น2: ไข่ = PlacedEggRenders.{UserId}_*
-- จากล็อก v4.2: CRA = สัตว์ฟักแล้ว | PlacedEggRenders = ไข่ที่วาง

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
local PROMPT_GAP = 12

local function say(x)
    S.lines[#S.lines + 1] = tostring(x)
    if #S.lines > 240 then table.remove(S.lines, 1) end
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
        if inst.PrimaryPart then return inst.PrimaryPart.Position end
        local p = inst:FindFirstChildWhichIsA("BasePart", true)
        return p and p.Position
    end
    local p = inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local function attrsOf(inst)
    local parts = {}
    pcall(function()
        for k, v in pairs(inst:GetAttributes()) do
            parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
        end
    end)
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function collectTexts(root, limit)
    local texts, seen = {}, {}
    if not root then return texts end
    local ok, desc = pcall(function() return root:GetDescendants() end)
    if not ok or not desc then return texts end
    local n = 0
    for _, d in ipairs(desc) do
        if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" then
            local t = d.Text:gsub("%s+", " "):match("^%s*(.-)%s*$")
            if t and #t > 0 and not seen[t] then
                seen[t] = true
                texts[#texts + 1] = t
                n = n + 1
                if n >= (limit or 10) then break end
            end
        end
    end
    return texts
end

local function eggTypeHint(model)
    -- ชื่อ mesh / child ที่บ่งชนิดไข่
    local hints = {}
    pcall(function()
        for _, d in ipairs(model:GetDescendants()) do
            local n = d.Name
            if n:find("Egg", 1, true) or n:find("egg", 1, true) or n:find("Dinosaur", 1, true) then
                if d:IsA("Model") or d:IsA("MeshPart") then
                    hints[#hints + 1] = n
                    if #hints >= 5 then break end
                end
            end
        end
    end)
    return hints
end

-- SmartPromptPart ใกล้จุด (ชั้นตื้น ไม่ GetDescendants ทั้งแมพ)
local function promptsNear(pos, maxGap)
    local rows = {}
    if not pos then return rows end
    pcall(function()
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LP.Character then params.FilterDescendantsInstances = { LP.Character } end
        local parts = workspace:GetPartBoundsInRadius(pos, maxGap, params)
        local seen = {}
        for _, part in ipairs(parts) do
            local host = part
            if part.Name ~= "SmartPromptPart" then
                -- ดูลูกและตัวเอง
            end
            local function take(pp, adornee)
                if not pp or seen[pp] then return end
                seen[pp] = true
                local ap = adornee and (adornee:IsA("BasePart") and adornee.Position or instPos(adornee)) or pos
                local gap = ap and (ap - pos).Magnitude or 0
                rows[#rows + 1] = {
                    en = pp.Enabled,
                    status = pp.Enabled and "READY" or "DISABLED",
                    act = tostring(pp.ActionText or ""),
                    obj = tostring(pp.ObjectText or ""),
                    hold = pp.HoldDuration,
                    maxD = pp.MaxActivationDistance,
                    gap = gap,
                    path = pathOf(pp),
                }
            end
            for _, ch in ipairs(part:GetChildren()) do
                if ch:IsA("ProximityPrompt") then take(ch, part) end
            end
            if part:IsA("ProximityPrompt") then take(part, part.Parent) end
        end
    end)
    -- สำรอง: SmartPromptPart เป็นลูก workspace โดยตรงใกล้ๆ
    for _, ch in ipairs(workspace:GetChildren()) do
        if ch.Name == "SmartPromptPart" and ch:IsA("BasePart") then
            local gap = (ch.Position - pos).Magnitude
            if gap <= maxGap then
                local pp = ch:FindFirstChildWhichIsA("ProximityPrompt")
                if pp then
                    local dup
                    for _, r in ipairs(rows) do if r.path == pathOf(pp) then dup = true break end end
                    if not dup then
                        rows[#rows + 1] = {
                            en = pp.Enabled,
                            status = pp.Enabled and "READY" or "DISABLED",
                            act = tostring(pp.ActionText or ""),
                            obj = tostring(pp.ObjectText or ""),
                            hold = pp.HoldDuration,
                            maxD = pp.MaxActivationDistance,
                            gap = gap,
                            path = pathOf(pp),
                        }
                    end
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.gap < b.gap end)
    return rows
end

local function listOurEggs()
    local folder = workspace:FindFirstChild("PlacedEggRenders")
    local out = {}
    if not folder then return out, "ไม่มี WS.PlacedEggRenders" end
    local prefix = ME .. "_"
    local root = hr()
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m.Name:sub(1, #prefix) == prefix then
            local p = instPos(m)
            local d = (root and p) and (p - root.Position).Magnitude or 99999
            local uid = m.Name:sub(#prefix + 1)
            out[#out + 1] = {
                model = m, uid = uid, name = m.Name, p = p, d = d,
                attrs = attrsOf(m),
                texts = collectTexts(m, 8),
                hints = eggTypeHint(m),
            }
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out, nil
end

local function scanEggs()
    S.lines = {}
    say("=== Egg Spy v5.0 — ขั้น2 PlacedEggRenders ===")
    say("UserId=" .. ME)
    local eggs, err = listOurEggs()
    if err then
        say(err)
        say("=== DONE ===")
        return
    end
    say(string.format("--- ไข่ของเราใน PlacedEggRenders: %d ---", #eggs))
    if #eggs == 0 then
        say("(ว่าง — วางไข่ในคอกแล้วสแกนใหม่)")
    end

    local mutN, hatchN = 0, 0
    for i, e in ipairs(eggs) do
        local prompts = e.p and promptsNear(e.p, PROMPT_GAP) or {}
        local mutLine, hatchLine = "-", "-"
        for _, pr in ipairs(prompts) do
            local al = (pr.act .. " " .. pr.obj):lower()
            if al:find("mutation", 1, true) or al:find("scrambl", 1, true) or al:find("apply", 1, true) then
                mutLine = string.format("%s %q/%q", pr.status, pr.act, pr.obj)
                if pr.status == "READY" or pr.status == "DISABLED" then mutN = mutN + 1 end
            end
            if al:find("hatch", 1, true) then
                hatchLine = string.format("%s %q", pr.status, pr.act)
                hatchN = hatchN + 1
            end
            if al:find("skip", 1, true) or al:find("growth", 1, true) then
                hatchLine = hatchLine .. string.format(" | %s %q", pr.status, pr.act)
            end
        end

        say(string.format("#%d d=%.0f uid=%s", i, e.d, e.uid:sub(1, 12)))
        if #e.hints > 0 then say("    typeHint: " .. table.concat(e.hints, ", ")) end
        if e.attrs ~= "" then say("    attrs: " .. e.attrs) end
        if #e.texts > 0 then say("    texts: " .. table.concat(e.texts, " || ")) else say("    texts: (ไม่มีบนโมเดลไข่)") end
        say("    mutPrompt: " .. mutLine)
        say("    hatch/growth: " .. hatchLine)
        if #prompts > 0 then
            for j = 1, math.min(4, #prompts) do
                local pr = prompts[j]
                say(string.format("    PP gap=%.1f en=%s act=%q obj=%q", pr.gap, tostring(pr.en), pr.act, pr.obj))
            end
        else
            say("    PP: (ไม่มีในรัศมี " .. PROMPT_GAP .. ")")
        end
        -- ลูกชั้นบน
        local kids = {}
        for _, ch in ipairs(e.model:GetChildren()) do
            kids[#kids + 1] = ch.ClassName .. ":" .. ch.Name
            if #kids >= 10 then break end
        end
        if #kids > 0 then say("    children: " .. table.concat(kids, ", ")) end
    end

    say(string.format("--- สรุป eggs=%d | มี mutPromptใกล้ๆ~%d | hatchใกล้ๆ~%d ---", #eggs, mutN, hatchN))
    say("=== DONE ===")
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
title.Text = "Egg01 Spy v5.0 — PlacedEggRenders (ไข่)"
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

local bEggs = btn("EGGS", 10, Color3.fromRGB(45, 110, 170))
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
box.Text = "EGGS = ลิสต์ PlacedEggRenders ของเรา\nยืนในคอก → EGGS → COPY"

bEggs.MouseButton1Click:Connect(scanEggs)
bClear.MouseButton1Click:Connect(function() S.lines = {}; box.Text = "" end)
bCopy.MouseButton1Click:Connect(function()
    local clip = setclipboard or toclipboard
    if clip then
        pcall(clip, "=== Egg01 Egg Spy v5.0 ===\n" .. table.concat(S.lines, "\n"))
        bCopy.Text = "OK"
        task.delay(1, function() if bCopy.Parent then bCopy.Text = "COPY" end end)
    end
end)
bClose.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_EGG_STATUS_SPY = nil
end)

say("v5.0 — ไข่ = PlacedEggRenders | กด EGGS")
