-- 74RB_BedEscape.lua v1.0 — โดนผีใต้เตียงจับ = สแปม E อัตโนมัติจนหลุด
-- สัญญาณจับ (BedMonSpy ยืนยัน): Humanoid.PlatformStand=true + state PlatformStanding
-- → กด E รัวผ่าน VIM จน PlatformStand=false = หลุด

if _G.BEDESCAPE_CONNS then
    for _, c in pairs(_G.BEDESCAPE_CONNS) do pcall(function() c:Disconnect() end) end
end
_G.BEDESCAPE_CONNS = {}
local CONNS = _G.BEDESCAPE_CONNS
_G.BEDESCAPE_ON = true

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BedEscape"; gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
local b = Instance.new("TextButton", gui)
b.Size = UDim2.new(0, 170, 0, 34); b.Position = UDim2.new(0, 8, 0.2, 0)
b.TextSize = 14; b.Font = Enum.Font.GothamBold; b.TextColor3 = Color3.new(1, 1, 1)
local function paint() b.Text = _G.BEDESCAPE_ON and "หนีผีใต้เตียง: ON" or "หนีผีใต้เตียง: OFF"
    b.BackgroundColor3 = _G.BEDESCAPE_ON and Color3.fromRGB(30, 90, 40) or Color3.fromRGB(90, 30, 30) end
paint()
table.insert(CONNS, b.MouseButton1Click:Connect(function() _G.BEDESCAPE_ON = not _G.BEDESCAPE_ON; paint() end))

local function tapE()
    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait()
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local hum
local function bind(ch)
    hum = ch:WaitForChild("Humanoid", 5)
end
if LP.Character then bind(LP.Character) end
table.insert(CONNS, LP.CharacterAdded:Connect(bind))

-- ลูปเช็ค: โดนจับเมื่อไหร่ สแปม E จนหลุด
task.spawn(function()
    while gui.Parent do
        if _G.BEDESCAPE_ON and hum and hum.Parent
           and (hum.PlatformStand or hum:GetState() == Enum.HumanoidState.PlatformStanding) then
            b.Text = "🆘 โดนจับ! สแปม E..."
            local t0 = os.clock()
            while hum.PlatformStand and gui.Parent and os.clock() - t0 < 15 do
                tapE()
                task.wait(0.08)
            end
            paint()
        end
        task.wait(0.1)
    end
end)
