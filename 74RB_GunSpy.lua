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
    if _G.AH74GS_BOX then _G.AH74GS_BOX.Text = "=== GunSpy v1.0 (ยิงเองแล้วดู) ===\n" .. table.concat(LOG, "\n") end
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

-- hook __namecall (จับ FireServer/InvokeServer ทุก remote)
local mt = getrawmetatable and getrawmetatable(game)
if mt and hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod and getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" then
            local n = self.Name:lower()
            if n:find("shoot") or n:find("gun") or n:find("taser") or n:find("fire")
               or n:find("hit") or n:find("damage") or n:find("attack") then
                L(("[%s] %s(%s)"):format(m, self:GetFullName():gsub("^.-Net%.?", ""), argstr(...)))
            end
        end
        return old(self, ...)
    end)
    L("hook __namecall ติดแล้ว — ยิงปืนเองได้เลย")
else
    L("!! hookmetamethod ไม่มี — executor นี้ spy ไม่ได้")
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
box.Text = "=== GunSpy v1.0 (ยิงเองแล้วดู) ==="
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
