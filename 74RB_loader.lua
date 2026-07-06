-- 74RB_loader.lua — ตัวโหลดถาวร Animal Hospital (ไฟล์นี้ไม่ต้องแก้อีก)
-- v2: ดึง SHA ล่าสุดจาก GitHub API → โหลดจาก jsDelivr CDN (pin SHA = สดเสมอ + ไม่โดน 429)
-- raw.githubusercontent โดน rate limit (429) ได้ถ้าโหลดถี่ — ใช้เป็นสำรองเท่านั้น
print("[74RB loader] กำลังหาเวอร์ชันล่าสุด...")
local ok, sha = pcall(function()
    return game:HttpGet("https://api.github.com/repos/FTTFX/rb-scripts/commits/main")
        :match('"sha"%s*:%s*"(%x+)"')
end)
local urls = {}
if ok and sha then
    urls[#urls+1] = "https://cdn.jsdelivr.net/gh/FTTFX/rb-scripts@" .. sha .. "/74RB_AH.lua"
    urls[#urls+1] = "https://raw.githubusercontent.com/FTTFX/rb-scripts/" .. sha .. "/74RB_AH.lua"
    print("[74RB loader] ได้ commit ล่าสุด " .. sha:sub(1, 7) .. " (สดใหม่แน่นอน)")
else
    print("[74RB loader] API ไม่ตอบ → โหลดแบบสำรอง (อาจติด cache)")
end
urls[#urls+1] = "https://raw.githubusercontent.com/FTTFX/rb-scripts/main/74RB_AH.lua?v=" .. tick()
urls[#urls+1] = "https://cdn.jsdelivr.net/gh/FTTFX/rb-scripts@main/74RB_AH.lua"
for i, url in ipairs(urls) do
    local ok2, src = pcall(game.HttpGet, game, url)
    -- กันโหลดได้หน้า error (429/404) มารันแทนสคริปต์ — เช็คหัวไฟล์ต้องเป็นคอมเมนต์สคริปต์เรา
    if ok2 and type(src) == "string" and src:sub(1, 2) == "--" then
        print("[74RB loader] โหลดจากแหล่งที่ " .. i .. " สำเร็จ")
        loadstring(src)()
        return
    end
    print("[74RB loader] แหล่งที่ " .. i .. " ใช้ไม่ได้ ลองตัวถัดไป...")
end
warn("[74RB loader] โหลดไม่ได้ทุกแหล่ง — รอ 5 นาทีแล้วลองใหม่ (GitHub rate limit)")
