-- Egg01 Invite Friend v1.0
-- เชิญเพื่อนด้วย Roblox UserId ผ่านหน้าต่าง Invite ทางการ

if _G.EGG01_INVITE then
    pcall(function() _G.EGG01_INVITE.gui:Destroy() end)
end

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "Egg01_InviteFriend"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1004
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = PG end
_G.EGG01_INVITE = { gui = gui }

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 285, 0, 126)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, -46, 0, 24)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Invite Friend to Game"

local close = Instance.new("TextButton", panel)
close.Size = UDim2.new(0, 30, 0, 24)
close.Position = UDim2.new(1, -38, 0, 3)
close.BackgroundColor3 = Color3.fromRGB(125, 45, 45)
close.BorderSizePixel = 0
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.Text = "X"
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)

local input = Instance.new("TextBox", panel)
input.Size = UDim2.new(0, 158, 0, 29)
input.Position = UDim2.new(0, 10, 0, 35)
input.BackgroundColor3 = Color3.fromRGB(40, 43, 49)
input.BorderSizePixel = 0
input.ClearTextOnFocus = false
input.PlaceholderText = "Friend Roblox UserId"
input.PlaceholderColor3 = Color3.fromRGB(150, 155, 165)
input.TextColor3 = Color3.new(1, 1, 1)
input.Font = Enum.Font.GothamBold
input.TextSize = 12
Instance.new("UICorner", input).CornerRadius = UDim.new(0, 5)

local invite = Instance.new("TextButton", panel)
invite.Size = UDim2.new(0, 96, 0, 29)
invite.Position = UDim2.new(0, 178, 0, 35)
invite.BackgroundColor3 = Color3.fromRGB(40, 145, 75)
invite.BorderSizePixel = 0
invite.TextColor3 = Color3.new(1, 1, 1)
invite.Font = Enum.Font.GothamBold
invite.TextSize = 12
invite.Text = "INVITE"
Instance.new("UICorner", invite).CornerRadius = UDim.new(0, 5)

local status = Instance.new("TextLabel", panel)
status.Size = UDim2.new(1, -20, 0, 48)
status.Position = UDim2.new(0, 10, 0, 72)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 220, 105)
status.Font = Enum.Font.GothamBold
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "กรอก UserId ของเพื่อน แล้วกด INVITE"

invite.MouseButton1Click:Connect(function()
    local userId = tonumber(input.Text)
    if not userId or userId <= 0 or userId % 1 ~= 0 then
        status.Text = "UserId ต้องเป็นเลขจำนวนเต็มที่ถูกต้อง"
        return
    end
    local okCan, canInvite = pcall(function()
        return SocialService:CanSendGameInviteAsync(LP)
    end)
    if not okCan or not canInvite then
        status.Text = "บัญชี/แพลตฟอร์มนี้ส่ง Invite ไม่ได้"
        return
    end
    local options = Instance.new("ExperienceInviteOptions")
    options.InviteUser = userId
    options.PromptMessage = "มาเล่นด้วยกัน!"
    local ok, err = pcall(function()
        SocialService:PromptGameInvite(LP, options)
    end)
    options:Destroy()
    status.Text = ok and ("เปิดหน้าต่าง Invite สำหรับ UserId " .. userId) or ("Invite error: " .. tostring(err))
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
    _G.EGG01_INVITE = nil
end)
