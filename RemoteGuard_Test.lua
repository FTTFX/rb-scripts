-- RemoteGuard_Test.lua — ทดสอบ Server-side Validation
-- วางใน ServerScriptService (Script) แล้วดู Output
-- แนวคิด: client เรียก FireServer ด้วย args อะไรก็ได้ (ปลอมได้เสมอ)
--         server ต้องตัดสินจาก state จริงของ server เท่านั้น

--------------------------------------------------------------------
-- SERVER: setup
--------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "TestRemotes"
remotes.Parent = ReplicatedStorage

local startQuest = Instance.new("RemoteEvent")
startQuest.Name = "StartQuest"
startQuest.Parent = remotes

-- NPC เควส (ตำแหน่งจริงบน server เท่านั้น)
local NPCS = {
	[101] = Vector3.new(50, 5, 50),
	[102] = Vector3.new(-2000, 5, 3000),
}

--------------------------------------------------------------------
-- SERVER: per-player state (server-authoritative)
--------------------------------------------------------------------
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

--------------------------------------------------------------------
-- SERVER: ตัวตรวจกลาง (cooldown + rate)
--------------------------------------------------------------------
local function allow(plr, remoteName, cdKey, cdSec, maxPerSec)
	local s = State[plr]
	local now = os.clock()

	local r = s.rate[remoteName]
	if not r or now - r[2] >= 1 then
		r = {0, now}
	end
	r[1] += 1
	s.rate[remoteName] = r
	if r[1] > maxPerSec then
		return false, "rate"
	end

	if s.cooldown[cdKey] and now < s.cooldown[cdKey] then
		return false, "cooldown"
	end
	s.cooldown[cdKey] = now + cdSec
	return true
end

--------------------------------------------------------------------
-- SERVER: handler หลัก — pure function เพื่อให้เทสต์ยิงเข้ามาตรงได้
--------------------------------------------------------------------
local function handleStartQuest(plr, questId, claimedPos)
	-- 1) rate/cooldown
	local ok, why = allow(plr, "StartQuest", "start", 2, 5)
	if not ok then return false, why end

	-- 2) state machine: ยังมีเควสค้าง → reject (ป้องกันยิงซ้ำ/ข้ามขั้น)
	local s = State[plr]
	if s.questStage ~= 0 then
		return false, "state"
	end

	-- 3) questId ต้องมีจริงบน server (ป้องกันส่ง id มั่ว)
	local npcPos = NPCS[questId]
	if not npcPos then
		return false, "invalid_id"
	end

	-- 4) spatial check ด้วยตำแหน่งจริงที่ server เห็น
	--    ห้ามใช้ claimedPos ที่ client แนบมา — มันปลอมได้
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "no_char" end

	local dist = (hrp.Position - npcPos).Magnitude
	if dist > 100 then
		return false, "too_far"
	end

	-- ผ่านทั้งหมด → มอบเควส
	s.questStage = 1
	s.questId = questId
	return true, "ok"
end

startQuest.OnServerEvent:Connect(handleStartQuest)

--------------------------------------------------------------------
-- TEST HARNESS: จำลอง client ปกติ + client โกง (ยิง remote ตรง ๆ)
-- หมายเหตุ: attacker ไม่ต้อง hook อะไรเลย — FireServer(args ปลอม) คือการโกงเอง
--------------------------------------------------------------------
local function makeMockPlayer(name, pos)
	local plr = {Name = name}
	plr.Character = {
		FindFirstChild = function(_, n)
			if n == "HumanoidRootPart" then
				return {Position = pos}
			end
			return nil
		end,
	}
	return plr
end

local function run(label, fn)
	local ok, res, why = pcall(fn)
	print(("[TEST] %-42s => %s (%s)"):format(
		label,
		ok and res and "ACCEPT" or "REJECT",
		ok and tostring(why) or tostring(res)
	))
end

task.spawn(function()
	task.wait(1)

	local alice = makeMockPlayer("Alice_Legit", Vector3.new(55, 5, 55))   -- อยู่ใกล้ NPC 101
	local bob   = makeMockPlayer("Bob_Cheater", Vector3.new(0, 5, 0))     -- อยู่ไกล แต่จะยิงขอเควส

	-- 1) ปกติ: ยิงถูก id ถูกที่ → ควร ACCEPT
	run("legit: Alice StartQuest(101)", function()
		return handleStartQuest(alice, 101, nil)
	end)

	-- 2) ปลอม: Bob ยิงจากที่ไกล → server ใช้ตำแหน่งจริง → REJECT (too_far)
	run("forge: Bob ยิงจากไกล (หวังใช้ claimedPos)", function()
		return handleStartQuest(bob, 101, Vector3.new(50, 5, 50))
	end)

	-- 3) ปลอม: ส่ง questId ที่ไม่มีในระบบ → REJECT (invalid_id)
	run("forge: Alice ส่ง id 9999 ที่ไม่มีจริง", function()
		return handleStartQuest(alice, 9999, nil)
	end)

	-- 4) ปลอม: มีเควสค้าง (stage=1) แล้วขอใหม่ → REJECT (state)
	run("forge: Alice ยิงซ้ำขณะมีเควสค้าง", function()
		return handleStartQuest(bob, 101, nil) -- bob ยัง idle จึงจะโดน state ไม่ได้
	end)

	-- 4b) ให้ Alice ยิงซ้ำจริง (มีเควสค้าง) → REJECT (state)
	run("forge: Alice ยิงซ้ำขณะมีเควสค้าง (จริง)", function()
		return handleStartQuest(alice, 101, nil)
	end)

	-- 5) spam: ยิงรัวเกิน rate → REJECT (rate)
	for i = 1, 7 do
		run(("spam #%d: Bob ยิงรัว"):format(i), function()
			return handleStartQuest(bob, 101, nil)
		end)
	end

	-- 6) cooldown: รอ cooldown หมด แล้วยิงแบบถูกเงื่อนไข (bob reset stage)
	State[bob].questStage = 0
	task.wait(2.1)
	run("legit: รอ cooldown แล้วยิงใหม่ (ยังไกล→too_far ตามคาด)", function()
		return handleStartQuest(bob, 101, nil)
	end)

	print("\n[สรุป] จุดไหน REJECT = server ตัดสินจาก state จริง ไม่เชื่อ args จาก client")
end)