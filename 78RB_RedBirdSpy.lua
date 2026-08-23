-- 78RB_RedBirdSpy.lua v3 — หา "Highlight/เส้นขอบ" ทั้งเกม (ตัวไฮไลท์=นกแดงตัวโจมตี)
-- เฝ้าดู 15 วิ — บอกว่า Highlight อยู่ไหน + ชี้ (Adornee) ไปที่โมเดลชื่ออะไร
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
pcall(function() local g=(gethui and gethui()) or game:GetService("CoreGui"); if g:FindFirstChild("REDSPY") then g.REDSPY:Destroy() end end)
local gui=Instance.new("ScreenGui"); gui.Name="REDSPY"; gui.ResetOnSpawn=false
gui.DisplayOrder=2147483647; gui.IgnoreGuiInset=true
pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end
local fr=Instance.new("Frame",gui); fr.Size=UDim2.new(0,410,0,490); fr.Position=UDim2.new(0.5,-205,0.5,-245)
fr.BackgroundColor3=Color3.new(0,0,0); fr.BackgroundTransparency=0.05; fr.Active=true; fr.Draggable=true
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,8)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(255,80,80); stk.Thickness=3
local ttl=Instance.new("TextLabel",fr); ttl.Size=UDim2.new(1,-40,0,26); ttl.Position=UDim2.new(0,6,0,4)
ttl.BackgroundTransparency=1; ttl.TextColor3=Color3.fromRGB(255,120,120); ttl.Font=Enum.Font.GothamBold
ttl.TextSize=15; ttl.TextXAlignment=Enum.TextXAlignment.Left; ttl.Text="🔴 หา Highlight..."
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
lbl.TextColor3=Color3.fromRGB(255,200,180); lbl.TextXAlignment=Enum.TextXAlignment.Left
lbl.TextYAlignment=Enum.TextYAlignment.Top; lbl.TextWrapped=true; lbl.Text="เริ่ม..."
local out={}
local function say(s) out[#out+1]=tostring(s); lbl.Text=table.concat(out,"\n") end

say("เฝ้าหา Highlight/SelectionBox 15 วิ...")
say("(บินหานกแดง/รอมันโผล่มาไฮไลท์)")
say("")
local seen={}
local cnt=0
local function scan()
    for _,svc in ipairs({workspace, game:GetService("Players")}) do
        pcall(function()
            for _,d in ipairs(svc:GetDescendants()) do
                if d:IsA("Highlight") or d:IsA("SelectionBox") then
                    local ad = d.Adornee or d.Parent
                    local adName = ad and ad.Name or "?"
                    local adCls = ad and ad.ClassName or "?"
                    local key = d:GetFullName()
                    if not seen[key] then
                        seen[key]=true; cnt=cnt+1
                        say(("[%s] %s"):format(d.ClassName, d:GetFullName()))
                        say(("   ชี้ไป(Adornee/พ่อ): %s [%s]"):format(adName, adCls))
                        pcall(function()
                            if d:IsA("Highlight") then say(("   สีขอบ=%s เติม=%s"):format(tostring(d.OutlineColor), tostring(d.FillColor))) end
                        end)
                    end
                end
            end
        end)
    end
end
task.spawn(function()
    for i=1,30 do
        scan()
        ttl.Text=("🔴 เฝ้าดู %ds เจอ %d"):format(math.floor((30-i)/2), cnt)
        task.wait(0.5)
    end
    if cnt==0 then say(""); say("(ไม่เจอ Highlight เลย — ตัวไฮไลท์อาจใช้วิธีอื่น เช่น เปลี่ยนสี/ScreenGui บอกผมได้)") end
    ttl.Text=("🔴 เสร็จ เจอ %d (ก๊อปแล้ว)"):format(cnt)
    pcall(function() if setclipboard then setclipboard(table.concat(out,"\n")) end end)
end)
