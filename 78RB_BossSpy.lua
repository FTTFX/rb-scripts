-- 78RB_BossSpy.lua v2 — หา "บอส" จากหลอด HP (ไม่ยึดชื่อ BossController)
-- บอสจริงชื่ออาจเป็น "Dragon Duck" ฯลฯ → หาจาก BillboardGui/HP + Highlight
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
pcall(function() local g=(gethui and gethui()) or game:GetService("CoreGui"); if g:FindFirstChild("BOSSSPY") then g.BOSSSPY:Destroy() end end)
local gui=Instance.new("ScreenGui"); gui.Name="BOSSSPY"; gui.ResetOnSpawn=false
gui.DisplayOrder=2147483647; gui.IgnoreGuiInset=true
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
local fr=Instance.new("Frame",gui); fr.Size=UDim2.new(0,430,0,510); fr.Position=UDim2.new(0.5,-215,0.5,-255)
fr.BackgroundColor3=Color3.new(0,0,0); fr.BackgroundTransparency=0.05; fr.Active=true; fr.Draggable=true
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,8)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(255,80,80); stk.Thickness=3
local ttl=Instance.new("TextLabel",fr); ttl.Size=UDim2.new(1,-40,0,26); ttl.Position=UDim2.new(0,6,0,4)
ttl.BackgroundTransparency=1; ttl.TextColor3=Color3.fromRGB(255,150,120); ttl.Font=Enum.Font.GothamBold
ttl.TextSize=15; ttl.TextXAlignment=Enum.TextXAlignment.Left; ttl.Text="👑 หาบอส(จาก HP)..."
local cls=Instance.new("TextButton",fr); cls.Size=UDim2.new(0,28,0,24); cls.Position=UDim2.new(1,-32,0,5)
cls.Text="✕"; cls.Font=Enum.Font.GothamBold; cls.TextSize=15; cls.BackgroundColor3=Color3.fromRGB(150,50,50)
cls.TextColor3=Color3.new(1,1,1); Instance.new("UICorner",cls).CornerRadius=UDim.new(0,5)
cls.MouseButton1Click:Connect(function() gui:Destroy() end)
local scf=Instance.new("ScrollingFrame",fr); scf.Size=UDim2.new(1,-10,1,-40); scf.Position=UDim2.new(0,5,0,32)
scf.BackgroundColor3=Color3.fromRGB(15,15,22); scf.BorderSizePixel=0; scf.ScrollBarThickness=8
scf.CanvasSize=UDim2.new(0,0,0,0); scf.AutomaticCanvasSize=Enum.AutomaticSize.Y
Instance.new("UICorner",scf).CornerRadius=UDim.new(0,6)
local lbl=Instance.new("TextLabel",scf); lbl.Size=UDim2.new(1,-8,0,0); lbl.Position=UDim2.new(0,4,0,4)
lbl.AutomaticSize=Enum.AutomaticSize.Y; lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.Code; lbl.TextSize=12
lbl.TextColor3=Color3.fromRGB(255,210,190); lbl.TextXAlignment=Enum.TextXAlignment.Left
lbl.TextYAlignment=Enum.TextYAlignment.Top; lbl.TextWrapped=true; lbl.Text="เริ่ม..."
local out={}
local function say(s) out[#out+1]=tostring(s); lbl.Text=table.concat(out,"\n") end

-- 1) ทุก TextLabel ที่มี "HP" ทั้งเกม → ไล่หาโมเดลบอสที่มันเกาะ
say("===== 1) ป้าย HP อยู่ที่ไหน =====")
local nh=0
for _,scope in ipairs({workspace, LP:FindFirstChild("PlayerGui")}) do
    if scope then
        pcall(function()
            for _,d in ipairs(scope:GetDescendants()) do
                if d:IsA("TextLabel") and tostring(d.Text):upper():find("HP") then
                    nh=nh+1
                    local bb=d:FindFirstAncestorWhichIsA("BillboardGui")
                    local ad = bb and bb.Adornee
                    local mdl = ad and ad:FindFirstAncestorWhichIsA("Model")
                             or d:FindFirstAncestorWhichIsA("Model")
                    say(("HP=%q"):format(d.Text))
                    say(("   path=%s"):format(d:GetFullName():gsub("^.-%.PlayerGui%.",""):gsub("^Workspace%.","")))
                    if bb then say(("   BillboardGui.Adornee=%s"):format(ad and ad:GetFullName() or "nil")) end
                    if mdl then say(("   >> โมเดลบอส: %s (พ่อ=%s)"):format(mdl.Name, mdl.Parent and mdl.Parent.Name or "?")) end
                    if nh>=8 then break end
                end
            end
        end)
    end
end
if nh==0 then say("(ไม่เจอป้าย HP — รันตอนบอสอยู่)") end

-- 2) ชนิดโมเดลใน Ume ตอนนี้ (หาชื่อแปลกๆ ที่ไม่ใช่ DuckController ปกติ)
say(""); say("===== 2) ชนิดโมเดลใน Ume =====")
local Ume=workspace:FindFirstChild("Ume")
if Ume then
    local counts={}
    for _,m in ipairs(Ume:GetChildren()) do
        local key=m.Name:gsub("_?%d+$",""):gsub("_Client_.*","_Client")
        counts[key]=(counts[key] or 0)+1
    end
    for k,v in pairs(counts) do say(("  %s x%d"):format(k,v)) end
end

-- 3) โมเดลใน Ume ที่มี Highlight (บอส/นกแดง มักถูกไฮไลท์)
say(""); say("===== 3) โมเดลใน Ume ที่มี Highlight =====")
local ni=0
if Ume then
    for _,m in ipairs(Ume:GetChildren()) do
        if m:IsA("Model") then
            for _,d in ipairs(m:GetChildren()) do
                if d:IsA("Highlight") or d.Name:find("Highlight") then
                    ni=ni+1; say(("  %s → ลูกไฮไลท์: %s"):format(m.Name, d.Name)); break
                end
            end
        end
    end
end
if ni==0 then say("  (ไม่มี)") end

ttl.Text="👑 เสร็จ (ก๊อปแล้ว)"
pcall(function() if setclipboard then setclipboard(table.concat(out,"\n")) end end)
