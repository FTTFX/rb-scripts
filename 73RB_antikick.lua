-- 73RB_antikick.lua — Anti-Kick (กัน client kick + ตัดการรายงาน detection)
-- รันตัวนี้ "ก่อน" hub/บิน → เทสว่ากัน error 267 ได้ไหม
--   ไม่หลุดแล้ว = เกมเตะแบบ client-report (กันได้)
--   ยังหลุด     = server เตะล้วน (กันไม่ได้ ต้องเล่น legit)
local b1 = hookfunction or replaceclosure
local c1 = newcclosure or function(f) return f end
local d1 = hookmetamethod
local h1 = getnamecallmethod
local a1 = getgc
local cc = checkcaller
if not (b1 and d1 and h1) then warn("[73RB AntiKick] executor ขาด hook API"); return end

local p = game:GetService("Players").LocalPlayer
local R = {}
local function F(r)
    if R[r] then return true end
    local n = r.Name
    if #n == 36 and string.match(n, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
        R[r] = true; return true
    end
    return false
end

-- 1) FireServer: บล็อกถ้า args มีคำว่า "kick" (กัน client รายงานตัวเอง)
local o
o = b1(Instance.new("RemoteEvent").FireServer, c1(function(s, ...)
    if F(s) then return o(s, ...) end
    for _, v in ipairs({...}) do
        if type(v) == "string" and string.find(string.lower(v), "kick") then return end
    end
    return o(s, ...)
end))

-- 2) __namecall: บล็อก Kick/Destroy บน LocalPlayer
local n
n = d1(game, "__namecall", c1(function(s, ...)
    local m = h1()
    if s == p and (m == "Kick" or m == "kick" or m == "Destroy" or m == "destroy") then return end
    return n(s, ...)
end))

-- 3) hook p.Kick / p.Destroy ตรงๆ: ถ้าเกม (ไม่ใช่เรา) เรียก → บล็อก
if cc then
    local k
    k = b1(p.Kick, c1(function(self, ...)
        if not cc() and self == p then return end
        return k(self, ...)
    end))
    local D
    D = b1(p.Destroy, c1(function(self, ...)
        if not cc() and self == p then return end
        return D(self, ...)
    end))
end

-- 4) สแกน getgc หา table anti-cheat → ปิด Send("detected") + Kill/Disconnect
if a1 then
    pcall(function()
        for _, v in pairs(a1(true)) do
            if type(v) == "table" then
                pcall(function()
                    if rawget(v, "Send") and type(rawget(v, "Send")) == "function" and rawget(v, "Get") and rawget(v, "Encrypt") then
                        local s
                        s = b1(v.Send, c1(function(cmd, ...)
                            if type(cmd) == "string" then
                                local c = string.lower(cmd)
                                if c == "detected" or c == "logerror" then return end
                            end
                            return s(cmd, ...)
                        end))
                    end
                    if rawget(v, "Kill") and type(rawget(v, "Kill")) == "function" and rawget(v, "Disconnect") then
                        b1(v.Kill, c1(function(...) return end))
                        b1(v.Disconnect, c1(function(...) return end))
                    end
                end)
            end
        end
    end)
end

print("[73RB AntiKick] เปิดแล้ว — รัน hub/บิน ต่อได้ ถ้ายังหลุด 267 = server เตะล้วน")
