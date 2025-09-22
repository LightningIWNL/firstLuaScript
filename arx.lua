local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer

local retry_btn = false
local black_screen = false

-- ฟังก์ชันเช็คการมีอยู่ของ GUI อย่างปลอดภัย
local function safeGetGui(path)
    local current = plr.PlayerGui
    for _, part in ipairs(path) do
        if not current:FindFirstChild(part) then
            return nil
        end
        current = current[part]
    end
    return current
end

-- ฟังก์ชันดึงปุ่ม Retry อย่างปลอดภัย
local function getRetryButton()
    return safeGetGui({"RewardsUI", "Main", "LeftSide", "Button", "Retry"})
end

-- ฟังก์ชันดึง Upgrade Page อย่างปลอดภัย
local function getUpgradePage()
    return safeGetGui({"HUD", "InGame", "UnitsManager", "Main", "Main", "ScrollingFrame"})
end

-- กดปุ่มด้วยคีย์ Enter (เพิ่มการเช็คความปลอดภัย)
local function pressButton(btn)
    -- เก็บค่า SelectedObject เดิมไว้ก่อน
    local previousSelectedObject = GuiService.SelectedObject
    
    -- ตรวจสอบว่าปุ่มเป็น nil หรือไม่
    if not btn then
        warn("Button is nil")
        return false
    end
    
    -- ตรวจสอบว่าปุ่มยังอยู่ใน GUI tree หรือไม่
    if not btn.Parent then
        warn("Button parent is nil")
        return false
    end
    
    -- ตรวจสอบว่าเป็น GuiButton หรือไม่
    if not btn:IsA("GuiButton") then
        warn("Not a GuiButton: " .. tostring(btn.ClassName))
        return false
    end
    
    -- ตรวจสอบว่าปุ่มมองเห็นได้หรือไม่
    if not btn.Visible then
        warn("Button is not visible")
        return false
    end
    
    -- กำหนดให้ปุ่มสามารถถูกเลือกได้
    btn.Selectable = true
    
    -- ตั้งค่าปุ่มเป็น SelectedObject ปัจจุบัน
    GuiService.SelectedObject = btn
    
    -- ส่งคำสั่งกดปุ่ม Enter
    local success, err = pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.05) -- รอเล็กน้อยให้ระบบประมวลผล
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
    
    -- รอให้การกดปุ่มเสร็จสมบูรณ์
    task.wait(0.1)
    
    -- คืนค่า SelectedObject เดิม (สำคัญมาก!)
    pcall(function()
        GuiService.SelectedObject = previousSelectedObject
    end)
    
    if success then
        print("✅ กดปุ่ม " .. (btn.Name or "Unknown") .. " สำเร็จ")
        return true
    else
        warn("❌ เกิดข้อผิดพลาดในการกดปุ่ม: " .. tostring(err))
        return false
    end
end

local function blacksc(bscreen)
    black_screen = bscreen
    if black_screen then
        -- ลบ GUI เก่าก่อน (ถ้ามี)
        local oldGui = plr.PlayerGui:FindFirstChild("BlackScreen")
        if oldGui then oldGui:Destroy() end
        
        local gui = Instance.new("ScreenGui")
        gui.Name = "BlackScreen"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.Parent = plr.PlayerGui

        RunService:Set3dRenderingEnabled(false)

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BorderSizePixel = 0
        frame.Parent = gui
    else
        RunService:Set3dRenderingEnabled(true)
        local gui = plr.PlayerGui:FindFirstChild("BlackScreen")
        if gui then gui:Destroy() end
    end
end

-- ตัวแปร Global สำหรับควบคุม Loop
if _G.retryLoopRunning == nil then
    _G.retryLoopRunning = false
end

local function retryGG(retry)
    if retry then
        if _G.retryLoopRunning then
            print("Retry loop is already running")
            return
        end
        
        _G.retryLoopRunning = true
        print("Starting retry loop...")
        
        task.spawn(function()
            while _G.retryLoopRunning do
                local retryBTN = getRetryButton()
                if retryBTN then
                    local success = pressButton(retryBTN)
                    if not success then
                        warn("Failed to press retry button")
                    end
                else
                    -- ถ้าไม่พบปุ่ม retry รอนานขึ้น
                    task.wait(1)
                    continue
                end
                task.wait(0.1)
            end
            print("Retry loop stopped")
        end)
    else
        print("Stopping retry loop...")
        _G.retryLoopRunning = false
    end
end

-- ตั้งค่า Global Functions
_G.retryGG = retryGG
_G.blacksc = blacksc

-- เรียงการ์ดยูนิตในหน้าอัปเกรดตาม LayoutOrder
local function getCards()
    local upgradePage = getUpgradePage()
    if not upgradePage then
        warn("ไม่พบ upgradePage")
        return {}
    end
    
    local arr = {}
    for _, child in ipairs(upgradePage:GetChildren()) do
        if child:IsA("Frame") or child:IsA("ImageButton") or child:IsA("TextButton") then
            table.insert(arr, child)
        end
    end
    
    table.sort(arr, function(a, b)
        return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
    end)
    
    return arr
end

-- เรียงโฟลเดอร์ยูนิต
local function getUnits()
    local unitsFolder = plr:FindFirstChild("UnitsFolder")
    if not unitsFolder then
        warn("ไม่พบ UnitsFolder")
        return {}
    end
    
    local arr = {}
    for _, u in ipairs(unitsFolder:GetChildren()) do
        if u:IsA("Folder") or u:IsA("Model") then
            table.insert(arr, u)
        end
    end
    
    return arr
end

-- เช็คว่า Max แล้วหรือยัง
local function isMaxedByUpgradeText(card)
    if not card then return false end
    
    local txtObj = card:FindFirstChild("UpgradeText")
    if not txtObj then
        -- ลองหาใน children อื่น
        for _, child in ipairs(card:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                if child.Name:lower():find("upgrade") or child.Name:lower():find("text") then
                    txtObj = child
                    break
                end
            end
        end
    end
    
    if not (txtObj and (txtObj:IsA("TextLabel") or txtObj:IsA("TextButton"))) then
        return false
    end

    local txt = string.lower(txtObj.Text or "")
    return txt:find("%(max%)") ~= nil or txt:find("max") ~= nil
end

-- อัปเกรดจนสุด
local function upgradeIndexToMax(unit, card, opts)
    if not unit or not card then
        warn("Unit หรือ Card เป็น nil")
        return false
    end
    
    opts = opts or {}
    local maxTries = opts.maxTries or 300
    local waitBetween = opts.waitBetween or 0.15

    print(("[UPGRADE] เริ่มอัปเกรด: %s"):format(unit.Name or "Unknown"))

    for i = 1, maxTries do
        -- เช็คว่า Max แล้วหรือยัง
        if isMaxedByUpgradeText(card) then
            print(("[UPGRADE] %s MAXED! (รอบที่ %d)"):format(unit.Name or "Unknown", i))
            return true
        end

        -- หาปุ่ม Upgrade
        local btn = card:FindFirstChild("Upgrade")
        if not btn then
            -- ลองหาในชื่ออื่น
            for _, child in ipairs(card:GetChildren()) do
                if child:IsA("GuiButton") and (
                    child.Name:lower():find("upgrade") or 
                    child.Name:lower():find("buy") or
                    child.Name:lower():find("level")
                ) then
                    btn = child
                    break
                end
            end
        end
        
        if not btn then
            warn(("[UPGRADE] ไม่พบปุ่ม Upgrade ใน %s"):format(card.Name or "Unknown"))
            return false
        end

        -- ลองกดปุ่ม
        local success = pressButton(btn)
        if not success then
            warn(("[UPGRADE] กดปุ่มไม่สำเร็จ: %s (ครั้งที่ %d)"):format(btn.Name or "Unknown", i))
            -- ลองต่อแทนที่จะหยุด
        end

        task.wait(waitBetween)
        
        -- เช็คทุก 10 รอบว่า card ยังอยู่ไหม
        if i % 10 == 0 then
            if not card.Parent then
                warn(("[UPGRADE] Card ถูกลบไปแล้ว: %s"):format(unit.Name or "Unknown"))
                return false
            end
        end
    end

    warn(("[UPGRADE] เกิน maxTries (%d) แล้วยังไม่ Max: %s"):format(maxTries, unit.Name or "Unknown"))
    return false
end

-- ฟังก์ชันหลักที่มี Error Handling
local function mainUpgradeLoop()
    print("=== เริ่ม Auto Upgrade ===")
    
    while true do
        local success, err = pcall(function()
            -- เช็ค GUI ต่างๆ
            local upgradePage = getUpgradePage()
            if not upgradePage then
                warn("ไม่พบ upgradePage รอ 3 วินาที...")
                task.wait(3)
                return
            end
            
            local unitsFolder = plr:FindFirstChild("UnitsFolder")
            if not unitsFolder then
                warn("ไม่พบ unitsFolder รอ 3 วินาที...")
                task.wait(3)
                return
            end
            
            -- ดึงข้อมูล Cards และ Units
            local cards = getCards()
            local units = getUnits()
            
            if #cards == 0 then
                warn("ไม่พบ Cards รอ 3 วินาที...")
                task.wait(3)
                return
            end
            
            if #units == 0 then
                warn("ไม่พบ Units รอ 3 วินาที...")
                task.wait(3)
                return
            end
            
            local n = math.min(#cards, #units)
            print(("[INFO] พบ Cards: %d, Units: %d, จะทำ: %d ตัว"):format(#cards, #units, n))

            -- วนอัปเกรดทีละตัว
            for i = 1, n do
                local unit = units[i]
                local card = cards[i]

                if not unit or not card then
                    warn(("[SKIP] Index %d - Unit หรือ Card เป็น nil"):format(i))
                    continue
                end
                
                if not unit.Parent then
                    warn(("[SKIP] Index %d - Unit ถูกลบไปแล้ว: %s"):format(i, unit.Name or "Unknown"))
                    continue
                end
                
                if not card.Parent then
                    warn(("[SKIP] Index %d - Card ถูกลบไปแล้ว: %s"):format(i, card.Name or "Unknown"))
                    continue
                end

                -- เช็คว่า Max แล้วหรือยัง
                if isMaxedByUpgradeText(card) then
                    print(("[SKIP] %s MAX แล้ว"):format(unit.Name or "Unknown"))
                else
                    print(("[PROCESS] ตัวที่ %d => Unit: %s | Card: %s"):format(
                        i, 
                        unit.Name or "Unknown", 
                        card.Name or "Unknown"
                    ))
                    
                    -- อัปเกรดจนสุด
                    local upgradeSuccess = upgradeIndexToMax(unit, card, {
                        maxTries = 200, 
                        waitBetween = 0.2
                    })
                    
                    if upgradeSuccess then
                        print(("[SUCCESS] อัปเกรด %s เสร็จแล้ว"):format(unit.Name or "Unknown"))
                    else
                        warn(("[FAIL] อัปเกรด %s ไม่สำเร็จ"):format(unit.Name or "Unknown"))
                    end
                end
                
                -- พักระหว่างการอัปเกรด
                task.wait(0.5)
            end
            
            print("[CYCLE] รอบนี้เสร็จแล้ว รอ 2 วินาทีก่อนรอบต่อไป...")
            task.wait(2)
        end)
        
        if not success then
            warn("เกิดข้อผิดพลาดในลูปหลัก: " .. tostring(err))
            print("รอ 5 วินาทีแล้วลองใหม่...")
            task.wait(5)
        end
    end
end

-- เริ่มการทำงาน
print("=== Auto Upgrade Script Loaded ===")
print("ใช้คำสั่ง:")
print("_G.retryGG(true) -- เปิด Auto Retry")
print("_G.retryGG(false) -- ปิด Auto Retry") 
print("_G.blacksc(true) -- เปิด Black Screen")
print("_G.blacksc(false) -- ปิด Black Screen")
print("=====================================")

-- เริ่มลูปหลัก
task.spawn(mainUpgradeLoop)

print("[DONE] Script พร้อมใช้งาน!")