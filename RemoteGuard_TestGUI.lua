-- RemoteGuard_TestGUI.lua — ทดสอบ Server-side Validation แบบมี GUI + log
-- GUI: ปุ่มรันแต่ละเคส + Run All, log แสดง ACCEPT(เขียว)/REJECT(แดง) พร้อมเหตุผล
-- ใช้ได้ทั้ง Studio (วาง LocalScript/Command bar) และ executor (loadstring)

--------------------------------------------------------------------
-- SERVER LOGIC (จำลอง — pure function เพื่อเทสต์)
--------------------------------------------------------------------
local NPCS = {
	[101] = Vector3.new(50, 5, 50),
	[102] = Vector3.new(-2000, 5, 3000),
}

local State = setmetatable({}, {__index = function(t, k)
	local s = {
		questStage = 0,      -- 0=idle, 1=inprogress, 2=claimable
		questId = nil,
		cooldown = {},       -- [key] = จบ cooldown เมื่อไหร่
		rate = {},           -- [remoteName] = {count, windowStart}
	}
	t[k] = s
	return s
end})

local function allow(plr, remoteName, cdKey, cdSec, maxPerSec)
	local s = State[plr]
	local now = os.clock()
	local r = s.rate[remoteName]
	if not r or now - r[2] >= 1 then r = {0, now} end
	r[1] += 1
	s.rate[remoteName] = r
	if r[1] > maxPerSec then return false, "rate" end
	if s.cooldown[cdKey] and now < s.cooldown[cdKey] then
		return false, "cooldown"
	end
	s.cooldown[cdKey] = now + cdSec
	return true
end

local function handleStartQuest(plr, questId, claimedPos)
	local ok, why = allow(plr, "StartQuest", "start", 2, 5)
	if not ok then return false, why end

	local s = State[plr]
	if s.questStage ~= 0 then return false, "state" end

	local npcPos = NPCS[questId]
	if not npcPos then return false, "invalid_id" end

	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "no_char" end

	local dist = (hrp.Position - npcPos).Magnitude
	if dist > 100 then return false, "too_far" end

	s.questStage = 1
	s.questId = questId
	return true, "ok"
end

local function makeMockPlayer(name, pos)
	local plr = {Name = name}
	plr.Character = {
		FindFirstChild = function(_, n)
			if n == "HumanoidRootPart" then return {Position = pos} end
			return nil
		end,
	}
	return plr
end

local alice = makeMockPlayer("Alice_Legit", Vector3.new(55, 5, 55))
local bob   = makeMockPlayer("Bob_Cheater", Vector3.new(0, 5, 0))

-- แผนเทส: label, fn → คืน ok, why
local CASES = {
	{"legit: Alice StartQuest(101)", function()
		return handleStartQuest(alice, 101, nil)
	end},
	{"forge: Bob ยิงจากไกล (ส่ง claimedPos ปลอม)", function()
		return handleStartQuest(bob, 101, Vector3.new(50, 5, 50))
	end},
	{"forge: Alice ส่ง id 9999 ที่ไม่มีจริง", function()
		return handleStartQuest(alice, 9999, nil)
	end},
	{"forge: Alice ยิงซ้ำขณะมีเควสค้าง", function()
		return handleStartQuest(alice, 101, nil)
	end},
	{"spam: Bob ยิงรัว 7 ครั้ง (rate)", function()
		local rejects = 0
		for _ = 1, 7 do
			local ok = handleStartQuest(bob, 101, nil)
			if not ok then rejects += 1 end
		end
		return rejects >= 2, ("rejected %d/7"):format(rejects)
	end},
	{"cooldown: reset แล้วยิงทันที (ยังไม่พ้น cooldown)", function()
		State[bob].questStage = 0
		State[bob].cooldown.start = os.clock() + 2
		return handleStartQuest(bob, 101, nil)
	end},
	{"legit: รอ cooldown หมด → ยิงใหม่ (ยังไกล→too_far ตามคาด)", function()
		task.wait(2.1)
		return handleStartQuest(bob, 101, nil)
	end},
}

--------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------
local parentGui
local okEnv, hui = pcall(function()
	return (gethui and gethui()) or game:GetService("CoreGui")
end)
if okEnv and hui then
	parentGui = hui
else
	parentGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local old = parentGui:FindFirstChild("RemoteGuardTestGUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "RemoteGuardTestGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(420, 430)
main.Position = UDim2.fromOffset(20, 20)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "RemoteGuard Server-Validation Test"
title.TextColor3 = Color3.fromRGB(0, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = main

local runAll = Instance.new("TextButton")
runAll.Size = UDim2.new(1, -20, 0, 30)
runAll.Position = UDim2.fromOffset(10, 38)
runAll.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
runAll.Text = "▶ RUN ALL TESTS"
runAll.TextColor3 = Color3.new(1, 1, 1)
runAll.Font = Enum.Font.GothamBold
runAll.TextSize = 14
runAll.BorderSizePixel = 0
runAll.Parent = main
Instance.new("UICorner", runAll).CornerRadius = UDim.new(0, 6)

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -20, 1, -85)
logFrame.Position = UDim2.fromOffset(10, 76)
logFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
logFrame.BorderSizePixel = 0
logFrame.CanvasSize = UDim2.new()
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.ScrollingDirection = Enum.ScrollingDirection.Y
logFrame.Parent = main
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 6)
local list = Instance.new("UIListLayout", logFrame)
list.Padding = UDim.new(0, 2)
local pad = Instance.new("UIPadding", logFrame)
pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6)

local function log(text, color)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.TextWrapped = true
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 13
	lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
	lbl.Text = text
	lbl.Parent = logFrame
	print("[RemoteGuard] " .. text)
	task.defer(function()
		logFrame.CanvasPosition = Vector2.new(0, math.max(0, logFrame.AbsoluteCanvasSize.Y))
	end)
end

local ACC  = Color3.fromRGB(80, 255, 120)
local REJ  = Color3.fromRGB(255, 90, 90)
local INFO = Color3.fromRGB(0, 200, 255)

local running = false
local function runCase(i, label, fn)
	local ok, res, why = pcall(fn)
	local accepted = ok and res
	log(("[TEST %d] %s\n        => %s (%s)"):format(
		i, label,
		accepted and "ACCEPT" or "REJECT",
		ok and tostring(why) or tostring(res)
	), accepted and ACC or REJ)
	return accepted, ok and why or res
end

runAll.MouseButton1Click:Connect(function()
	if running then return end
	running = true
	-- reset state เพื่อรันซ้ำได้
	for _, p in ipairs({alice, bob}) do
		State[p] = nil
	end
	log("── รันทั้งหมด " .. #CASES .. " เคส ──", INFO)
	for i, c in ipairs(CASES) do
		runCase(i, c[1], c[2])
		task.wait(0.15)
	end
	log("── จบ: REJECT ทุกจุดที่ควร reject = server ใช้ state จริง ไม่เชื่อ args client ──", INFO)
	running = false
end)

-- ปุ่มรันทีละเคส
local y = 76
for i, c in ipairs(CASES) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 130, 0, 22)
	b.Position = UDim2.new(1, -145, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	b.Text = ("เคส %d"):format(i)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.BorderSizePixel = 0
	b.Parent = main
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
	b.MouseButton1Click:Connect(function()
		if running then return end
		runCase(i, c[1], c[2])
	end)
	y += 26
end
main.Size = UDim2.fromOffset(420, math.max(430, y + 20))

log("พร้อม — กด RUN ALL หรือปุ่มเคส 1-7", INFO)
log("REJECT ที่ถูกต้อง: too_far / invalid_id / state / rate / cooldown", INFO)

-- ค้างสคริปต์ไว้ (Studio: กัน script จบ → GUI โดนเก็บ)
while gui.Parent do task.wait(1) end