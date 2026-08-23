-- 78RB_GunRemoteSpy.lua — เช็คว่าเกม 78 มี remote ยิง/ดาเมจ ที่ "สแปมได้" ไหม
-- ลิสต์ RemoteEvent/Function ทั้งเกม + เดาอาร์กิวเมนต์ (ชื่อ/โฟลเดอร์ที่เกี่ยวกับ gun/hit/damage/duck)
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer
pcall(function() local g=(gethui and gethui()) or game:GetService("CoreGui"); if g:FindFirstChild("GUNSPY") then g.GUNSPY:Destroy() end end)
local gui=Instance.new("ScreenGui"); gui.Name="GUNSPY"; gui.ResetOnSpawn=false
gui.DisplayOrder=2147483647; gui.IgnoreGuiInset=true
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
local fr=Instance.new("Frame",gui); fr.Size=UDim2.new(0,440,0,520); fr.Position=UDim2.new(0.5,-220,0.5,-260)
fr.BackgroundColor3=Color3.new(0,0,0); fr.BackgroundTransparency=0.05; fr.Active=true; fr.Draggable=true
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,8)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(255,200,80); stk.Thickness=3
local ttl=Instance.new("TextLabel",fr); ttl.Size=UDim2.new(1,-40,0,26); ttl.Position=UDim2.new(0,6,0,4)
ttl.BackgroundTransparency=1; ttl.TextColor3=Color3.fromRGB(255,220,120); ttl.Font=Enum.Font.GothamBold
ttl.TextSize=15; ttl.TextXAlignment=Enum.TextXAlignment.Left; ttl.Text="🔫 หา remote ยิง/ดาเมจ..."
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
lbl.TextColor3=Color3.fromRGB(255,235,180); lbl.TextXAlignment=Enum.TextXAlignment.Left
lbl.TextYAlignment=Enum.TextYAlignment.Top; lbl.TextWrapped=true; lbl.Text="เริ่ม..."
local out={}
local function say(s) out[#out+1]=tostring(s); lbl.Text=table.concat(out,"\n") end

-- 1) remote ที่ชื่อเกี่ยวกับยิง/ดาเมจ (เด่นๆ)
say("===== 1) remote ยิง/ดาเมจ (น่าสแปม) =====")
local hot=0
for _,svc in ipairs({RS, workspace, game:GetService("Players")}) do
    pcall(function()
        for _,r in ipairs(svc:GetDescendants()) do
            if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                local ln=r.Name:lower()
                if ln:find("hit") or ln:find("gun") or ln:find("fire") or ln:find("shoot")
                   or ln:find("damage") or ln:find("dmg") or ln:find("kill") or ln:find("attack")
                   or ln:find("weapon") or ln:find("bullet") or ln:find("hurt") then
                    hot=hot+1
                    say(("★ %s [%s]"):format(r:GetFullName(), r.ClassName))
                end
            end
        end
    end)
end
if hot==0 then say("(ไม่เจอ remote ยิง/ดาเมจตรงๆ)") end

-- 2) remote ทั้งหมด (ดูภาพรวมว่ามีอะไรบ้าง)
say(""); say("===== 2) RemoteEvent/Function ทั้งหมด =====")
local all=0
pcall(function()
    for _,r in ipairs(RS:GetDescendants()) do
        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
            all=all+1
            if all<=60 then say(("%s [%s]"):format(r:GetFullName():gsub("ReplicatedStorage%.",""), r.ClassName:gsub("Remote",""))) end
        end
    end
end)
say(("(รวม %d remote ใน ReplicatedStorage)"):format(all))

ttl.Text="🔫 เสร็จ (ก๊อปแล้ว)"
pcall(function() if setclipboard then setclipboard(table.concat(out,"\n")) end end)
