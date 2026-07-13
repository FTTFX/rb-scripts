-- 74RB_SanityBlock.lua v1.0 — ลองบล็อก remote PlayerLostSanity ขาออก
-- ทฤษฎี: client เป็นคนยิงบอก server เองว่า "ฉันเสีย sanity" → ถ้าไม่ยิง sanity อาจไม่ลด
-- ปุ่ม BLOCK: ON = กลืน PlayerLostSanity ทิ้ง (ไม่ถึง server) → ดูว่า % sanity ค้างไหม
-- ⚠️ ใช้ acc สำรอง — ถ้า server เช็คแล้ว kick จะได้ไม่เสีย acc หลัก

if _G.SANITYBLOCK_CONNS then
    for _, c in pairs(_G.SANITYBLOCK_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.SANITYBLOCK_CONNS = {}
local CONNS = _G.SANITYBLOCK_CONNS
_G.SANITY_BLOCK_ON = _G.SANITY_BLOCK_ON or false   -- toggle เก็บใน _G (รันซ้ำไม่รีเซ็ต)

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local blocked = 0
local reasons = {}   -- reason -> จำนวนครั้ง (ดูว่าโดนตีส่ง reason อะไร)
local function reasonStr()
    local t = {}
    for r, n in pairs(reasons) do t[#t + 1] = ("%s x%d"):format(r, n) end
    return #t > 0 and table.concat(t, " | ") or "-"
end

local gui = Instance.new("ScreenGui")
gui.Name = "SanityBlock"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local box = Instance.new("TextLabel", gui)
box.Size = UDim2.new(0, 400, 0, 110); box.Position = UDim2.new(0, 8, 0.3, 0)
box.BackgroundColor3 = Color3.new(0, 0, 0); box.BackgroundTransparency = 0.2
box.TextColor3 = Color3.fromRGB(140, 255, 140); box.TextSize = 14; box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left; box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true

-- อ่าน % sanity สด (path จาก memory: Sanity.Frame.Frame.textbox.amount)
local function sanityPct()
    local pg = LP:FindFirstChild("PlayerGui")
    local s = pg and pg:FindFirstChild("Sanity")
    local amt = s and s:FindFirstChild("amount", true)
    return amt and amt.Text or "?"
end

local function refresh()
    box.Text = ("[SanityBlock]  BLOCK = %s\nSanity: %s\nกลืนไปแล้ว: %d ครั้ง\nreason ที่กลืน: %s")
        :format(_G.SANITY_BLOCK_ON and "🟢 ON" or "🔴 OFF", sanityPct(), blocked, reasonStr())
end
refresh()

-- hook __namecall กลืน PlayerLostSanity
local ok = pcall(function()
    local hooked
    hooked = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer")
           and typeof(self) == "Instance" and self.Name:find("PlayerLostSanity")
           and _G.SANITY_BLOCK_ON then
            blocked = blocked + 1
            local a = {...}
            local r = tostring(a[2] or "?")
            reasons[r] = (reasons[r] or 0) + 1
            refresh()
            return   -- กลืนทิ้ง — ไม่เรียก original = ไม่ถึง server
        end
        return hooked(self, ...)
    end))
end)
if not ok then box.Text = "❌ executor ไม่รองรับ hookmetamethod — บล็อกไม่ได้" end

local b = Instance.new("TextButton", gui)
b.Size = UDim2.new(0, 160, 0, 34); b.Position = UDim2.new(0, 8, 0.24, 0)
b.Text = "BLOCK sanity"; b.TextSize = 15; b.Font = Enum.Font.GothamBold
b.BackgroundColor3 = Color3.fromRGB(30, 90, 40); b.TextColor3 = Color3.new(1, 1, 1)
table.insert(CONNS, b.MouseButton1Click:Connect(function()
    _G.SANITY_BLOCK_ON = not _G.SANITY_BLOCK_ON
    b.BackgroundColor3 = _G.SANITY_BLOCK_ON and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(30, 90, 40)
    refresh()
end))

-- อัปเดต % ทุก 1 วิ
task.spawn(function()
    while gui.Parent do refresh(); task.wait(1) end
end)
