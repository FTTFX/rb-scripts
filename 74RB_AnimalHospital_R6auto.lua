-- 74RB_AnimalHospital_R6auto v1.0 (ทดสอบ) — auto เล่นปริศนาสี Room6 (Simon "Copy the sequence")
-- จับลำดับปุ่มที่สว่าง (peak=MainColor) → พอโชว์จบ (เงียบ 1.3วิ) → คลิกปุ่มตามลำดับ
-- คลิก: fireclickdetector(ถ้ามี) > fp(PP ถ้า enable) > VIM คลิกตำแหน่งจอ

local Players = game:GetService("Players")
local RS  = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local LP  = Players.LocalPlayer
local cam = workspace.CurrentCamera
local pg  = LP:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("AHR6AUTO"); if old then old:Destroy() end
if _G.AHR6A_CONNS then for _,c in ipairs(_G.AHR6A_CONNS) do pcall(function() c:Disconnect() end) end end
_G.AHR6A_CONNS = {}
local function track(c) table.insert(_G.AHR6A_CONNS, c) end

-- GUI เล็ก
local sg=Instance.new("ScreenGui"); sg.Name="AHR6AUTO"; sg.ResetOnSpawn=false; sg.Parent=pg
local f=Instance.new("Frame"); f.Size=UDim2.new(0,230,0,96); f.Position=UDim2.new(0,250,0,80)
f.BackgroundColor3=Color3.fromRGB(15,15,22); f.Active=true; f.Draggable=true; f.Parent=sg
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local st=Instance.new("TextLabel"); st.Size=UDim2.new(1,-10,0,40); st.Position=UDim2.new(0,5,0,4)
st.BackgroundTransparency=1; st.TextColor3=Color3.fromRGB(150,220,150); st.Font=Enum.Font.Code
st.TextSize=12; st.TextWrapped=true; st.Text="R6 auto: OFF"; st.Parent=f
local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,-10,0,26); btn.Position=UDim2.new(0,5,0,46)
btn.BackgroundColor3=Color3.fromRGB(45,45,58); btn.TextColor3=Color3.new(1,1,1); btn.Font=Enum.Font.GothamBold
btn.TextSize=14; btn.Text="R6 AUTO: OFF"; btn.Parent=f
Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
local cls=Instance.new("TextButton"); cls.Size=UDim2.new(1,-10,0,18); cls.Position=UDim2.new(0,5,0,74)
cls.BackgroundColor3=Color3.fromRGB(120,30,30); cls.TextColor3=Color3.new(1,1,1); cls.Font=Enum.Font.Code
cls.TextSize=11; cls.Text="ปิด"; cls.Parent=f
Instance.new("UICorner",cls).CornerRadius=UDim.new(0,4)

local ON=false
btn.MouseButton1Click:Connect(function()
    ON=not ON; btn.Text="R6 AUTO: "..(ON and "ON" or "OFF")
    btn.BackgroundColor3=ON and Color3.fromRGB(40,150,70) or Color3.fromRGB(45,45,58)
end)
cls.MouseButton1Click:Connect(function()
    for _,c in ipairs(_G.AHR6A_CONNS) do pcall(function() c:Disconnect() end) end
    _G.AHR6A_CONNS=nil; sg:Destroy()
end)

-- หาปุ่ม + ClickDetector
local function colorsContainer()
    local r=workspace:FindFirstChild("Rooms"); r=r and r:FindFirstChild("Emergency")
    r=r and r:FindFirstChild("Room6"); r=r and r:FindFirstChild("Minigame")
    return r and r:FindFirstChild("Colors")
end
local function numOf(p)
    local nm=p:FindFirstChild("ui"); nm=nm and nm:FindFirstChildOfClass("TextLabel")
    return nm and nm.Text or "?"
end
local function buttons()
    local c=colorsContainer(); if not c then return {} end
    local out={}
    for _,b in ipairs(c:GetDescendants()) do
        if b:IsA("BasePart") and b.Name=="Button" then out[numOf(b)]=b end
    end
    return out
end
local function near(a,b,t) return a and b and (math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B) < t) end

-- คลิกปุ่ม 1 อัน (3 วิธี เผื่อ executor/เกมต่างกัน)
local fcd = fireclickdetector
local fp  = fireproximityprompt
local function clickButton(b)
    local cd=b:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fcd then pcall(fcd, cd); return end
    local pp=b:FindFirstChild("PP")
    if pp and fp then pcall(fp, pp, 0); return end
    -- fallback: VIM คลิกตำแหน่งจอของปุ่ม
    local sp, vis = cam:WorldToViewportPoint(b.Position)
    if vis then pcall(function()
        VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, false, game, 0)
    end) end
end

-- ===== จับ peak ด้วย EVENT (เชื่อถือได้ ไม่พลาดเหมือน polling) =====
local seq = {}          -- ลำดับเลขที่ต้องกด
local bright = {}       -- สถานะปุ่มสว่างล่าสุด (กัน record ซ้ำระหว่าง fade)
local lastFlash = 0
local playing = false
local attached = {}

local function attach(b)
    if attached[b] or not b:IsA("BasePart") or b.Name~="Button" then return end
    attached[b]=true
    track(b:GetPropertyChangedSignal("Color"):Connect(function()
        if not ON or playing then return end
        local main = b:GetAttribute("MainColor")
        local num = numOf(b)
        local isB = near(b.Color, main, 0.08)
        if isB and not bright[num] then
            seq[#seq+1] = num; lastFlash = os.clock()
            st.Text = "ลำดับ: "..table.concat(seq, " ")
        end
        bright[num] = isB
    end))
end
-- diagnostic: ปุ่มแรกมี ClickDetector ไหม
local function diag()
    local c=colorsContainer()
    if not c then st.Text="ไม่เจอ Room6 (เข้าห้องก่อน)"; return end
    for _,b in ipairs(c:GetDescendants()) do
        if b:IsA("BasePart") and b.Name=="Button" then
            local cd=b:FindFirstChildWhichIsA("ClickDetector", true)
            st.Text=("CD=%s PP=%s fcd=%s"):format(
                tostring(cd~=nil), tostring(b:FindFirstChild("PP")~=nil), tostring(fcd~=nil))
            break
        end
    end
end

local function rearm()
    local c=colorsContainer()
    if not c then return end
    for _,d in ipairs(c:GetDescendants()) do attach(d) end
    track(c.DescendantAdded:Connect(attach))
end
rearm()
-- เผื่อ Colors ถูกสร้างใหม่ทีหลัง
track(workspace.DescendantAdded:Connect(function(d)
    if d.Name=="Colors" then task.wait(0.2); rearm() end
end))

-- input loop: เงียบ >1.5วิ + มีลำดับ → คลิกตามลำดับ
task.spawn(function()
    while _G.AHR6A_CONNS do
        if ON and #seq>0 and not playing and (os.clock()-lastFlash) > 1.5 then
            playing = true
            st.Text = "กด: "..table.concat(seq, " ")
            for _, num in ipairs(seq) do
                if not ON then break end
                local b = buttons()[num]
                if b then clickButton(b); task.wait(0.35) end
            end
            seq = {}; bright = {}
            task.wait(1.2)
            playing = false
            st.Text = "R6 auto: รอลำดับใหม่..."
        elseif not ON then
            seq = {}; bright = {}; playing = false
        end
        task.wait(0.1)
    end
end)
diag()
warn("[R6auto] loaded(event) — เข้า Room6 → R6 AUTO: ON → เริ่ม X-Ray (ดู F9 = ผลตรวจ ClickDetector)")
