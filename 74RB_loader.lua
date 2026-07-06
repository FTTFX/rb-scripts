-- 74RB_loader.lua — ตัวโหลดถาวร Animal Hospital (ไฟล์นี้ไม่ต้องแก้อีก)
-- ดึง commit SHA ล่าสุดจาก GitHub API (ไม่โดน CDN cache) → โหลดสคริปต์เวอร์ชันนั้นตรงๆ
-- ผลลัพธ์: อัปปุ๊บ โหลดได้ตัวใหม่ทันที ไม่ต้องรอ cache 1-5 นาที
print("[74RB loader] กำลังหาเวอร์ชันล่าสุด...")
local ok, sha = pcall(function()
    return game:HttpGet("https://api.github.com/repos/FTTFX/rb-scripts/commits/main")
        :match('"sha"%s*:%s*"(%x+)"')
end)
local url = (ok and sha)
    and ("https://raw.githubusercontent.com/FTTFX/rb-scripts/" .. sha .. "/74RB_AH.lua")
    or  ("https://raw.githubusercontent.com/FTTFX/rb-scripts/main/74RB_AH.lua?v=" .. tick())  -- API ล่ม → fallback แบบเดิม
print("[74RB loader] " .. ((ok and sha) and ("ได้ commit ล่าสุด " .. sha:sub(1, 7) .. " (สดใหม่แน่นอน)") or "API ไม่ตอบ → โหลดแบบเดิม (อาจติด cache 1-5 นาที)"))
loadstring(game:HttpGet(url))()
