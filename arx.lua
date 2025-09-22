local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
local retryBTN = game:GetService("Players").LocalPlayer.PlayerGui.RewardsUI.Main.LeftSide.Button.Retry
local retry_btn = false
local black_screen = false



-- กดปุ่มด้วยคีย์ Enter (วิธีเบสิคที่ใช้ได้กว้าง)
local function pressButton(btn)
	if not (btn and btn:IsA("GuiButton")) then return false end
	btn.Selectable = true

	GuiService.SelectedObject = btn
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
	return true
end

local function blacksc(bscreen)
    black_screen = bscreen
    if black_screen then
        local gui = Instance.new("ScreenGui")
        gui.Name = "BlackScreen"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.Parent = plr:WaitForChild("PlayerGui")

        RunService:Set3dRenderingEnabled(false)

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BorderSizePixel = 0
        frame.Parent = gui
    else
        RunService:Set3dRenderingEnabled(true)
        local gui = plr.PlayerGui:FindFirstChild("BlackScreen")
        if gui then gui:Destroy() end    -- <- กัน nil
    end
end






local function retryGG(retry)
	retry_btn = retry
	if retry then
		task.spawn(function()
			while retry_btn do
				if retryBTN then
					pressButton(retryBTN)
				end
				task.wait(0.1)
			end
		end)
	end
end

-- blacksc(true)
_G.blacksc = blacksc
_G.retryGG = retryGG
-- retryGG(true)

-- UI ของหน้ารายการยูนิต (ลำดับปุ่ม = ลำดับ index ที่เราจะวน)
local upgradePage = plr.PlayerGui.HUD.InGame.UnitsManager.Main.Main.ScrollingFrame

-- (ถ้าต้องโยงกับข้อมูลฝั่ง UnitsFolder)
local unitsFolder = plr:WaitForChild("UnitsFolder")


-- เรียงการ์ดยูนิตในหน้าอัปเกรดตาม LayoutOrder (ให้ index ตรงกับที่เห็น)
local function getCards()
	local arr = {}
	for _, child in ipairs(upgradePage:GetChildren()) do
		if child:IsA("Frame") or child:IsA("ImageButton") or child:IsA("TextButton") then
			table.insert(arr, child)
		end
	end
	table.sort(arr, function(a,b)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)
	return arr
end

-- เรียงโฟลเดอร์ยูนิต (ถ้าคุณจัดไว้แล้วให้ตรง index ก็ใช้ตรงๆ ได้เลย)
local function getUnits()
	local arr = {}
	for _, u in ipairs(unitsFolder:GetChildren()) do
		table.insert(arr, u)
	end
	-- ถ้า UnitsFolder มีฟิลด์ LayoutOrder ของตัวเอง ก็สามารถ sort แบบเดียวกับการ์ด
	-- ไม่งั้นจะใช้ลำดับที่คืนมาจาก GetChildren() ตามเดิม
	return arr
end



local function isMaxedByUpgradeText(card)
    if not card then return false end
    local txtObj = card:FindFirstChild("UpgradeText")
    if not (txtObj and (txtObj:IsA("TextLabel") or txtObj:IsA("TextButton"))) then
        return false
    end

    local txt = string.lower(txtObj.Text)
    -- ถ้าในข้อความมี "(max)" แปลว่าเต็มแล้ว
    return txt:find("%(max%)") ~= nil
end


local function upgradeIndexToMax(unit, card, opts)
    opts = opts or {}
    local maxTries = opts.maxTries or 300
    local waitBetween = opts.waitBetween or 0.15

    for _ = 1, maxTries do
        if isMaxedByUpgradeText(card) then
            print("[UPG] "..unit.Name.." MAXED (UpgradeText)")
            return true
        end

        local btn = card:FindFirstChild("Upgrade")
        if not (btn and btn:IsA("GuiButton")) then
            warn("[UPG] ไม่พบปุ่ม Upgrade ใน "..card.Name)
            return false
        end

        if not pressButton(btn) then
            warn("[UPG] กดปุ่มไม่สำเร็จ: "..btn.Name)
            return false
        end

        task.wait(waitBetween)
    end

    warn("[UPG] เกิน maxTries แล้วยังไม่ตัน: "..unit.Name)
    return false
end

-- MAIN: จับคู่ด้วย index แล้ววนทีละตัว
local cards = getCards()
local units = getUnits()
local n = math.min(#cards, #units)

while true do
    local cards = getCards()
    local units = getUnits()
    local n = math.min(#cards, #units)

    for i = 1, n do
        local unit = units[i]
        local card = cards[i]

        -- ถ้าการ์ดนี้ตันแล้วก็ข้าม
        if not isMaxedByUpgradeText(card) then
            print(("[LOOP] ตัวที่ %d => Unit:%s | Card:%s"):format(i, unit.Name, card.Name))
            upgradeIndexToMax(unit, card, {maxTries = 400, waitBetween = 0.2})
        else
            print("[SKIP] "..unit.Name.." MAXED แล้ว")
        end
    end
		
		

    task.wait(1)  
end

print("[DONE] วนจนครบตาม index แล้ว")

