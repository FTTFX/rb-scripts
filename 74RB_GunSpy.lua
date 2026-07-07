-- 74RB_GunSpy.lua v1.0 — จับว่า "ยิงปืน" เรียก remote อะไร + argument อะไร
-- วิธีใช้: รัน → ยืนใกล้ผี → ยิงด้วยมือจริง 1-2 นัด → ดู log (โผล่บน GUI + COPY)
-- hook FireServer/InvokeServer + fireproximityprompt เพื่อดูว่าปืนคุยกับ server ยังไง
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

if _G.AH74GS_GUI then pcall(function() _G.AH74GS_GUI:Destroy() end) end

local LOG = {}
local function L(s)
    LOG[#LOG+1] = s
    if #LOG > 40 then table.remove(LOG, 1) end
    if _G.AH74GS_BOX then _G.AH74GS_BOX.Text = "=== GunSpy v1.2 (namecall+dot+tool) ===\n" .. table.concat(LOG, "\n") end
end

local function short(v)
    local t = typeof(v)
    if t == "Instance" then return v.Name .. "(" .. v.ClassName .. ")"
    elseif t == "Vector3" then return ("V3(%.0f,%.0f,%.0f)"):format(v.X, v.Y, v.Z)
    elseif t == "CFrame" then return "CFrame@" .. short(v.Position)
    elseif t == "table" then return "{table}"
    else return tostring(v) end
end
local function argstr(...)
    local a = {}
    for i = 1, select("#", ...) do a[i] = short(select(i, ...)) end
    return table.concat(a, ", ")
end

-- hook __namecall (จับ FireServer/InvokeServer "ทุก" remote — v1.1 เลิกกรองชื่อ)
local mt = getrawmetatable and getrawmetatable(game)
if mt and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod and getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" then
            -- log ทุกตัว แต่ตัดพวกที่ยิงถี่ประจำ (เดิน/heartbeat) ที่ไม่เกี่ยว
            local n = self.Name:lower()
            if not (n:find("chat") or n:find("typing") or n:find("replic") or n:find("ping")) then
                L(("[%s] %s(%s)"):format(m, self:GetFullName():gsub("^.-Net%.?", ""), argstr(...)))
            end
        end
        return old(self, ...)
    end)
    L("hook v1.2 __namecall ติดแล้ว")
else
    L("!! hookmetamethod ไม่มี")
end

-- v1.2: ปืนอาจยิงผ่าน dot-call (RE.FireServer(RE, ...)) ไม่ใช่ namecall → hook ที่ตัว method เอง
if hookfunction then
    local RS = game:GetService("ReplicatedStorage")
    local seen = {}
    local function hookRemotes()
        for _, d in ipairs(RS:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and not seen[d] then
                seen[d] = true
                local key = d:IsA("RemoteEvent") and "FireServer" or "InvokeServer"
                pcall(function()
                    local orig = d[key]
                    hookfunction(orig, function(self, ...)
                        if self == d then
                            local n = d.Name:lower()
                            if not (n:find("chat") or n:find("ping") or n:find("replic")) then
                                L(("[dot:%s] %s(%s)"):format(key, d.Name, argstr(...)))
                            end
                        end
                        return orig(self, ...)
                    end)
                end)
            end
        end
    end
    hookRemotes()
    L("hook v1.2 dot-call ติดแล้ว (" .. tostring(#RS:GetDescendants()) .. " nodes)")
end

-- v1.2: จับ Tool.Activated (บางเกม server ยิงจาก tool activation ไม่ใช่ remote)
do
    local gun = (LP.Character and LP.Character:FindFirstChild("Gun"))
        or (LP:FindFirstChild("Backpack") and LP.Backpack:FindFirstChild("Gun"))
    if gun and gun:IsA("Tool") then
        gun.Activated:Connect(function() L("[Tool] Gun.Activated (ยิง)") end)
        L("ฟัง Gun.Activated แล้ว")
    end
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "AH74GS", false, 10000
gui.Parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
_G.AH74GS_GUI = gui
local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 400, 0, 300), UDim2.new(0.5, -200, 0.5, -150)
f.BackgroundColor3, f.Active, f.Draggable = Color3.fromRGB(15, 15, 20), true, true
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
local box = Instance.new("TextBox", f)
box.Size, box.Position = UDim2.new(1, -12, 1, -50), UDim2.new(0, 6, 0, 6)
box.MultiLine, box.ClearTextOnFocus, box.TextEditable = true, false, false
box.TextWrapped, box.TextXAlignment, box.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
box.Font, box.TextSize = Enum.Font.Code, 11
box.BackgroundColor3, box.TextColor3 = Color3.fromRGB(25, 25, 32), Color3.fromRGB(200, 255, 200)
box.Text = "=== GunSpy v1.2 (namecall+dot+tool) ==="
_G.AH74GS_BOX = box
local function mkbtn(txt, x, cb)
    local b = Instance.new("TextButton", f)
    b.Size, b.Position = UDim2.new(0, 120, 0, 32), UDim2.new(0, x, 1, -40)
    b.Text, b.TextScaled = txt, true
    b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(50, 50, 70), Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
end
mkbtn("COPY", 6, function() pcall(function() (setclipboard or toclipboard)(box.Text) end) end)
mkbtn("CLEAR", 132, function() LOG = {}; box.Text = "=== GunSpy v1.0 ===" end)
mkbtn("CLOSE", 258, function() gui:Destroy(); _G.AH74GS_GUI = nil end)
print("[74RB GunSpy v1.0] พร้อม — ยิงปืนเอง 1-2 นัด แล้ว COPY ส่งมา")
