-- 78RB_ReloadSpy.lua v2 — ไทม์ไลน์: แอมโม + อนิเมชันที่เล่น ทุก 0.3 วิ
-- ยิงจนรีโหลด 1-2 รอบ → ดูว่าตอนแอมโมเติมกลับ อนิเมชันไหนเล่น = รีโหลด
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
_G.RLS_GEN=(_G.RLS_GEN or 0)+1; local GEN=_G.RLS_GEN
pcall(function() local g=(gethui and gethui()) or game:GetService("CoreGui"); if g:FindFirstChild("RLSPY") then g.RLSPY:Destroy() end end)
local gui=Instance.new("ScreenGui"); gui.Name="RLSPY"; gui.ResetOnSpawn=false
gui.DisplayOrder=2147483647; gui.IgnoreGuiInset=true
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
local fr=Instance.new("Frame",gui); fr.Size=UDim2.new(0,450,0,520); fr.Position=UDim2.new(0.5,-225,0.5,-260)
fr.BackgroundColor3=Color3.new(0,0,0); fr.BackgroundTransparency=0.05; fr.Active=true; fr.Draggable=true
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,8)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(120,200,255); stk.Thickness=3
local ttl=Instance.new("TextLabel",fr); ttl.Size=UDim2.new(1,-74,0,26); ttl.Position=UDim2.new(0,6,0,4)
ttl.BackgroundTransparency=1; ttl.TextColor3=Color3.fromRGB(150,220,255); ttl.Font=Enum.Font.GothamBold
ttl.TextSize=13; ttl.TextXAlignment=Enum.TextXAlignment.Left; ttl.Text="🔄 ยิงจนรีโหลด 1-2 รอบ!"
local cls=Instance.new("TextButton",fr); cls.Size=UDim2.new(0,28,0,24); cls.Position=UDim2.new(1,-32,0,5)
cls.Text="✕"; cls.Font=Enum.Font.GothamBold; cls.TextSize=15; cls.BackgroundColor3=Color3.fromRGB(150,50,50)
cls.TextColor3=Color3.new(1,1,1); Instance.new("UICorner",cls).CornerRadius=UDim.new(0,5)
cls.MouseButton1Click:Connect(function() _G.RLS_GEN=_G.RLS_GEN+1; gui:Destroy() end)
local cpy=Instance.new("TextButton",fr); cpy.Size=UDim2.new(0,34,0,24); cpy.Position=UDim2.new(1,-68,0,5)
cpy.Text="📋"; cpy.Font=Enum.Font.GothamBold; cpy.TextSize=13; cpy.BackgroundColor3=Color3.fromRGB(40,120,70)
cpy.TextColor3=Color3.new(1,1,1); Instance.new("UICorner",cpy).CornerRadius=UDim.new(0,5)
local scf=Instance.new("ScrollingFrame",fr); scf.Size=UDim2.new(1,-10,1,-40); scf.Position=UDim2.new(0,5,0,32)
scf.BackgroundColor3=Color3.fromRGB(15,15,22); scf.BorderSizePixel=0; scf.ScrollBarThickness=8
scf.CanvasSize=UDim2.new(0,0,0,0); scf.AutomaticCanvasSize=Enum.AutomaticSize.Y
Instance.new("UICorner",scf).CornerRadius=UDim.new(0,6)
local lbl=Instance.new("TextLabel",scf); lbl.Size=UDim2.new(1,-8,0,0); lbl.Position=UDim2.new(0,4,0,4)
lbl.AutomaticSize=Enum.AutomaticSize.Y; lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.Code; lbl.TextSize=11
lbl.TextColor3=Color3.fromRGB(190,230,255); lbl.TextXAlignment=Enum.TextXAlignment.Left
lbl.TextYAlignment=Enum.TextYAlignment.Top; lbl.TextWrapped=true; lbl.Text="เริ่ม..."
local out={}
local function say(s) out[#out+1]=tostring(s); lbl.Text=table.concat(out,"\n") end
cpy.MouseButton1Click:Connect(function() pcall(function() if setclipboard then setclipboard(table.concat(out,"\n")) end end) end)

-- หาแอมโม label
local function ammoLabel()
    local pg=LP:FindFirstChild("PlayerGui"); if not pg then return nil end
    local ag=pg:FindFirstChild("AmmoGui"); if not ag then return nil end
    return ag:FindFirstChild("AmmoAmount", true)
end
-- animator (ตัวละคร + ปืน viewmodel)
local function animators()
    local res={}
    local c=LP.Character
    if c then
        local h=c:FindFirstChildOfClass("Humanoid")
        local a=h and h:FindFirstChildOfClass("Animator"); if a then res[#res+1]=a end
    end
    -- viewmodel อาจอยู่ใน camera/workspace
    for _,root in ipairs({workspace:FindFirstChild("Ume"), workspace.CurrentCamera}) do
        if root then
            for _,d in ipairs(root:GetDescendants()) do
                if d:IsA("Animator") then res[#res+1]=d end
            end
        end
    end
    return res
end
-- ย่อ id อนิเมชันให้สั้น
local function shortId(id) return (tostring(id):gsub("rbxassetid://",""):gsub("http.-id=","")) end

say("เวลา | แอมโม | อนิเมชันที่กำลังเล่น")
say("------------------------------------")
task.spawn(function()
    local t0=os.clock()
    local lastLine=""
    for i=1,60 do -- 60 x 0.3 = 18 วิ
        if _G.RLS_GEN~=GEN then return end
        local al=ammoLabel()
        local ammo=al and tostring(al.Text) or "?"
        local ids={}
        for _,a in ipairs(animators()) do
            pcall(function()
                for _,tr in ipairs(a:GetPlayingAnimationTracks()) do
                    if tr.Animation then ids[#ids+1]=shortId(tr.Animation.AnimationId) end
                end
            end)
        end
        local line=("%.1f | %s | %s"):format(os.clock()-t0, ammo, table.concat(ids,","))
        if line:gsub("^%d+%.%d ","")~=lastLine:gsub("^%d+%.%d ","") then -- โชว์เฉพาะตอนเปลี่ยน
            say(line); lastLine=line
        end
        ttl.Text=("🔄 %ds — ยิงจนรีโหลด!"):format(math.floor((60-i)*0.3))
        task.wait(0.3)
    end
    say("=== จบ (📋 ก๊อป) ===")
    pcall(function() if setclipboard then setclipboard(table.concat(out,"\n")) end end)
end)
