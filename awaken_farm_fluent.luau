local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local utility = game.Players.LocalPlayer.PlayerScripts.Client.Utility
local util = require(utility)
local data = util.data
local playerItems = data.items or {}
local playerStats = data.stats or {}

-- Auto detect: in hub or in game
local inHub = pcall(function() return ReplicatedStorage.Remotes.Play ~= nil end)
local create_room, start_remote
if inHub then
    create_room = ReplicatedStorage.Remotes.Play:WaitForChild("create_room")
    start_remote = ReplicatedStorage.Remotes.Play:WaitForChild("start")
end

local MATERIAL_DROPS = {
	["Zenkai Ore"] = { world = "GT City", mode = "Story", acts = {1,2} },
	["Ki Resonant Crystal"] = { world = "GT City", mode = "Story", acts = {3,4} },
	["Stellar Ki Quartz"] = { world = "GT City", mode = "Story", acts = {5,6} },
	["Limitbreak Obsidian"] = { world = "GT City", mode = "Story", acts = {7,8} },
	["Eclipse Godstone"] = { world = "GT City", mode = "Story", acts = {9,10} },
	["Currentbinder Rope"] = { world = "Marine Lobby", mode = "Story", acts = {1,2} },
	["Depthglass Bottle"] = { world = "Marine Lobby", mode = "Story", acts = {3,4} },
	["Stormwake Sailcloth"] = { world = "Marine Lobby", mode = "Story", acts = {5,6} },
	["Beastblood Catalyst"] = { world = "Marine Lobby", mode = "Story", acts = {7,8} },
	["King's Haki Residue"] = { world = "Marine Lobby", mode = "Story", acts = {9,10} },
	["Shinobi Bone"] = { world = "Ninja Village", mode = "Story", acts = {1,2} },
	["Binding Cloth"] = { world = "Ninja Village", mode = "Story", acts = {3,4} },
	["Genjutsu Fog Vial"] = { world = "Ninja Village", mode = "Story", acts = {5,6} },
	["Fuin Script Paper"] = { world = "Ninja Village", mode = "Story", acts = {7,8} },
	["Chakra Fragment"] = { world = "Ninja Village", mode = "Story", acts = {9,10} },
	["Apostle Iron"] = { world = "Eclipse (Before)", mode = "Story", acts = {1,2} },
	["Eclipse Stone"] = { world = "Eclipse (Before)", mode = "Story", acts = {3,4} },
	["Brand Ash"] = { world = "Eclipse (Before)", mode = "Story", acts = {5,6} },
	["Moonlit Silver"] = { world = "Eclipse (Before)", mode = "Story", acts = {7,8} },
	["Black Sun Amber"] = { world = "Eclipse (Before)", mode = "Story", acts = {9,10} },
	["Gryphon"] = { world = "Marine Lobby", mode = "Squadron", act = 3 },
	["Pelli"] = { world = "Marine Lobby", mode = "Squadron", act = 1 },
	["Headband"] = { world = "Ninja Village", mode = "Squadron", act = 1 },
	["Karashi's Book"] = { world = "Ninja Village", mode = "Squadron", act = 2 },
	["Shuriken"] = { world = "Ninja Village", mode = "Squadron", act = 3 },
	["Power Pole"] = { world = "GT City", mode = "Squadron", act = 3 },
	["Scouter"] = { world = "GT City", mode = "Squadron", act = 2 },
	["Zeni"] = { world = "GT City", mode = "Squadron", act = 1 },
	["Behelit"] = { world = "Eclipse (Before)", mode = "Squadron", act = 1 },
	["Cavalry Saber"] = { world = "Eclipse (Before)", mode = "Squadron", act = 3 },
	["Dragon Slayer (Evo)"] = { world = "Eclipse (Before)", mode = "Squadron", act = 4 },
	["White Behelit"] = { world = "Eclipse (Before)", mode = "Raid", act = 1 },
	["Hogyoku Orb"] = { world = "Katakara Bridge", mode = "Challenge", act = 1 },
}

local Window = Fluent:CreateWindow({
    Title = "Evo Material Farmer",
    SubTitle = "Anime Squadron" .. (inHub and " [HUB]" or " [IN-GAME]"),
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = { Main = Window:AddTab({ Title = "Evo Farm", Icon = "sword" }) }
local Options = Fluent.Options
local selectedUnit = nil

-- Scan ALL units the player owns (work in both hub and in-game)
local units = {}
local unitIds = {}

-- Helper: try to get evolution data from a template module
local function getEvoData(template)
    if not template then return nil end
    local d = template:FindFirstChild("data")
    if not d then return nil end
    local ok, mod = pcall(require, d)
    if not ok then return nil end
    -- Check different possible field names for evolution
    return mod.awakening or mod.evolution or mod.evolve or mod.evo
end

-- Helper: find template by name with fallbacks
local function findTemplate(name)
    if not name then return nil end
    local t = ReplicatedStorage.Characters:FindFirstChild(name)
    if t then return t end
    -- Case-insensitive search
    for _, child in ipairs(ReplicatedStorage.Characters:GetChildren()) do
        if child.Name:lower() == name:lower() then return child end
        if child.Name:find(name, 1, true) or name:find(child.Name, 1, true) then return child end
    end
    return nil
end

-- Count total characters
local charCount = 0
for _ in pairs(data.characters or {}) do charCount = charCount + 1 end

local scanned = 0; local noTemplate = 0; local noData = 0; local noEvo = 0
for id, char in pairs(data.characters or {}) do
    if not char or not char.name then continue end
    if unitIds[char.name] then continue end
    unitIds[char.name] = true
    scanned = scanned + 1

    local template = findTemplate(char.name)
    if not template then noTemplate = noTemplate + 1; print("No template:", char.name); continue end

    local evo = getEvoData(template)
    if not evo then
        local d = template:FindFirstChild("data")
        if d then
            local ok, mod = pcall(require, d)
            if ok then
                local keys = ""
                for k,_ in pairs(mod) do keys = keys .. k .. "," end
                print("No evo field for:", char.name, "keys:", keys)
            else
                print("Require failed for:", char.name, tostring(mod))
            end
        else
            noData = noData + 1; print("No data child:", char.name)
        end
        continue
    end
    if not evo.cost or not evo.object then noEvo = noEvo + 1; print("Incomplete evo:", char.name); continue end

    local missingMats = {}
    for mat, needed in pairs(evo.cost) do
        local have = playerItems[mat] or playerStats[mat] or 0
        if have < needed then
            missingMats[#missingMats+1] = { mat = mat, have = have, need = needed, short = needed - have }
        end
    end
    local traitStr = ""
    if char.trait then
        traitStr = char.trait
        if char.trait_2 then traitStr = traitStr .. "+" .. char.trait_2 end
    end
    units[#units+1] = {
        id = id, name = char.name, target = evo.object.Name,
        level = char.level, shiny = char.shiny, traitStr = traitStr,
        missing = missingMats, numMissing = #missingMats,
        fullCost = evo.cost
    }
end

table.sort(units, function(a,b) return a.numMissing > b.numMissing end)
print(string.format("Scanned %d, noTemplate=%d, noData=%d, noEvo=%d, found=%d", scanned, noTemplate, noData, noEvo, #units))

print(string.format("Chars: %d, Evo units: %d", charCount, #units))

local HttpService = game:GetService("HttpService")
local hasWrite = pcall(function() writefile("EFarmTest.txt", "1"); delfile("EFarmTest.txt") end)

-- Save/load selected unit name for cross-session restore
local function saveSelectedUnitName(name)
    if not hasWrite then return end
    pcall(function() writefile("EFarmUnit.txt", HttpService:JSONEncode(name)) end)
end

local function loadSelectedUnitName()
    if not hasWrite then return "" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile("EFarmUnit.txt")) end)
    return (ok and type(data) == "string" and data) or ""
end

-- Save full unit list to file for cross-session use
local function saveUnitsList()
    if not hasWrite then return end
    local dataOut = {}
    for _, u in ipairs(units) do
        dataOut[u.name] = {
            level = u.level, shiny = u.shiny, traitStr = u.traitStr,
            target = u.target, fullCost = u.fullCost
        }
    end
    pcall(function() writefile("EFarmUnits.txt", HttpService:JSONEncode(dataOut)) end)
end

local function loadUnitsList()
    if not hasWrite then return {} end
    local ok, dataIn = pcall(function()
        return HttpService:JSONDecode(readfile("EFarmUnits.txt"))
    end)
    if ok and type(dataIn) == "table" then return dataIn end
    return {}
end

-- In hub: save unit list immediately + auto-refresh. In game: load from saved hub list.
if inHub then
    saveUnitsList()
    print("Saved unit list to file: " .. #units .. " units")
    task.spawn(function()
        while true do
            task.wait(30)
            pcall(function()
                local m = require(utility)
                data = m.data
                playerItems = data.items or {}
                playerStats = data.stats or {}
            end)
            for _, u in ipairs(units) do
                local missing = {}
                for mat, needed in pairs(u.fullCost) do
                    local have = playerItems[mat] or playerStats[mat] or 0
                    if have < needed then
                        missing[#missing+1] = { mat = mat, have = have, need = needed, short = needed - have }
                    end
                end
                u.missing = missing; u.numMissing = #missing
            end
            saveUnitsList()
        end
    end)
else
    -- In-game: evo data NOT available from templates, use saved hub data
    local savedData = loadUnitsList()
    if next(savedData) then
        units = {}
        for name, info in pairs(savedData) do
            local fullCost = info.fullCost or {}
            local missing = {}
            for mat, needed in pairs(fullCost) do
                local have = playerItems[mat] or playerStats[mat] or 0
                if have < needed then
                    missing[#missing+1] = { mat = mat, have = have, need = needed, short = needed - have }
                end
            end
            local level, shiny, traitStr = info.level or 1, info.shiny or false, info.traitStr or ""
            for _, char in pairs(data.characters or {}) do
                if char.name == name then
                    level = char.level; shiny = char.shiny
                    traitStr = char.trait or ""
                    if char.trait_2 then traitStr = traitStr .. "+" .. char.trait_2 end
                    break
                end
            end
            units[#units+1] = {
                name = name, level = level, shiny = shiny, traitStr = traitStr,
                target = info.target or "?", missing = missing, numMissing = #missing,
                fullCost = fullCost
            }
        end
        table.sort(units, function(a,b) return a.numMissing > b.numMissing end)
        print("Loaded " .. #units .. " units from hub save (in-game)")
    end
end

-- Build dropdown values AFTER units are finalized
local unitNames = { "Select a unit..." }
local unitMap = { ["Select a unit..."] = nil }
local unitByName = {}
for _, u in ipairs(units) do
    local shiny = u.shiny and " [SHINY]" or ""
    local trait = u.traitStr ~= "" and " [" .. u.traitStr .. "]" or ""
    local key = "Lv" .. tostring(u.level) .. " " .. u.name .. shiny .. trait .. " need" .. tostring(u.numMissing)
    unitNames[#unitNames+1] = key
    unitMap[key] = u
    unitByName[u.name] = u
end

Tabs.Main:AddParagraph({
    Title = "Evo Material Farmer",
    Content = inHub and ("HUB - " .. #units .. " unit co the awaken") or ("GAME - " .. #units .. " unit co the awaken")
})

Tabs.Main:AddButton({
    Title = "Cap nhat so lieu Material",
    Description = "Lam tuoi so luong vat pham hien tai",
    Callback = function()
        pcall(function()
            local m = require(utility)
            data = m.data
            playerItems = data.items or {}
            playerStats = data.stats or {}
            for _, u in ipairs(units) do
                local missing = {}
                for mat, needed in pairs(u.fullCost) do
                    local have = playerItems[mat] or playerStats[mat] or 0
                    if have < needed then missing[#missing+1] = { mat = mat, have = have, need = needed, short = needed - have } end
                end
                u.missing = missing; u.numMissing = #missing
            end
            if selectedUnit then pcall(showUnitInfo, selectedUnit); pcall(logMaterialStatus, selectedUnit) end
        end)
        Fluent:Notify({ Title = "Cap nhat", Content = "Da lam tuoi material!", Duration = 3 })
    end
})

local unitDropdown = Tabs.Main:AddDropdown("UnitSelect", {
    Title = "Unit can awaken",
    Values = unitNames, Multi = false, Default = 1,
})

local diffDropdown = Tabs.Main:AddDropdown("Difficulty", {
    Title = "Do kho (Normal/Hard)",
    Values = {"Normal", "Hard"}, Multi = false, Default = 1,
})

local function showUnitInfo(unit)
    if not unit then
        Fluent:Notify({ Title = "Info", Content = "Chon unit de xem chi tiet.", Duration = 3 })
        return
    end
    local lines = {}
    local s = unit.shiny and " [SHINY]" or ""
    local t = unit.traitStr ~= "" and " Trait: " .. unit.traitStr or ""
    lines[#lines+1] = unit.name .. s .. " Lv" .. unit.level .. t
    lines[#lines+1] = "-> " .. unit.target
    lines[#lines+1] = "Materials:"
    for mat, needed in pairs(unit.fullCost) do
        local have = playerItems[mat] or playerStats[mat] or 0
        local icon = have >= needed and "✓" or "✗"
        local drop = MATERIAL_DROPS[mat]
        local d = ""
        if drop then
            local a = drop.acts and drop.acts[#drop.acts] or drop.act or 1
            d = " [" .. drop.world .. " A" .. a .. " " .. drop.mode .. "]"
        end
        lines[#lines+1] = icon .. " " .. mat .. ": " .. tostring(have) .. "/" .. tostring(needed) .. d
    end
    if unit.numMissing > 0 then
        lines[#lines+1] = "Con thieu " .. unit.numMissing .. " loai:"
        for _, m in ipairs(unit.missing) do
            lines[#lines+1] = "  - " .. m.mat .. " x" .. tostring(m.short)
        end
    else
        lines[#lines+1] = "DA DU! Co the awaken!"
    end
    Fluent:Notify({ Title = unit.name, Content = table.concat(lines, "\n"), Duration = 10 })
end

unitDropdown:OnChanged(function(val)
    local u = unitMap[val]
    selectedUnit = u
    if u then
        saveSelectedUnitName(u.name)
        pcall(refreshData, u)
        pcall(showUnitInfo, u)
        pcall(logMaterialStatus, u)
        -- If AutoFarm toggle was restored before dropdown, start now
        if farming and inHub and u.numMissing > 0 then
            Fluent:Notify({ Title = "Auto Farm", Content = "Bat dau farm cho " .. u.name .. " (chuyen map tu dong)...", Duration = 4 })
            task.spawn(doFarmLoop)
        end
    end
end)

local function logMaterialStatus(unit)
    if not unit then return end
    print("===== Evo Material [" .. unit.name .. "] =====")
    for mat, needed in pairs(unit.fullCost) do
        local have = playerItems[mat] or playerStats[mat] or 0
        print("  " .. (have >= needed and "READY" or "NEED") .. " " .. mat .. ": " .. tostring(have) .. "/" .. tostring(needed))
    end
    print("=====================================")
end

-- Auto refresh status every 10s
task.spawn(function()
    while true do
        task.wait(10)
        if selectedUnit then
            pcall(function()
                refreshData(selectedUnit)
                logMaterialStatus(selectedUnit)
            end)
        end
    end
end)

local autoFarmToggle = Tabs.Main:AddToggle("AutoFarm", {
    Title = "Auto Farm Material Evo Unit",
    Description = inHub and "Tu dong farm cho unit da chon, chuyen map cho den khi du ALL material" or "Theo doi material + auto replay khi trong game",
    Default = false,
})

local allowToggleOff = false

local function setFarmOff()
    allowToggleOff = true
    farming = false
    autoFarmToggle:SetValue(false)
    allowToggleOff = false
end

local farming = false
local gameReplay, gameEnding, gameTeleport
pcall(function() gameReplay = ReplicatedStorage.Remotes.Game:WaitForChild("replay") end)
pcall(function() gameEnding = ReplicatedStorage.Remotes.Game:WaitForChild("ending") end)
pcall(function() gameTeleport = ReplicatedStorage.Remotes.Players:WaitForChild("teleport") end)

local function refreshData(u)
    pcall(function()
        local m = require(utility)
        data = m.data
        playerItems = data.items or {}
        playerStats = data.stats or {}
    end)
    if not u then return end
    local cost = nil
    local template = ReplicatedStorage.Characters:FindFirstChild(u.name)
    if template and template:FindFirstChild("data") then
        local ok, mod = pcall(require, template.data)
        if ok then
            cost = (mod.awakening or mod.evolution or mod.evolve or mod.evo or {}).cost
        end
    end
    cost = cost or u.fullCost
    local newMissing = {}
    for mat, needed in pairs(cost) do
        local have = playerItems[mat] or playerStats[mat] or 0
        if have < needed then
            newMissing[#newMissing+1] = { mat = mat, have = have, need = needed, short = needed - have }
        end
    end
    u.missing = newMissing
    u.numMissing = #newMissing
end

-- Pick highest act of first missing material's drop
local function getFirstDrop(u)
    if not u then return nil end
    for _, m in ipairs(u.missing or {}) do
        local d = MATERIAL_DROPS[m.mat]
        if d then return d, m.mat end
    end
    return nil
end

local currentFarmedMat = ""  -- Track which material we entered the game for

-- Create room + start for the selected unit's first missing material
local function enterGame(u)
    local drop, matName = getFirstDrop(u)
    if not drop then return false end
    currentFarmedMat = matName or ""
    local act = drop.acts and drop.acts[#drop.acts] or drop.act or 1
    local diff = diffDropdown.Value
    local ok, err = create_room:InvokeServer({
        boosted = true, act = act, difficulty = diff,
        mode = drop.mode, only_friends = false, world = drop.world
    })
    if not ok then return false end
    print("Farming: " .. (matName or "?") .. " at " .. drop.world .. " A" .. act .. " " .. drop.mode)
    task.wait(1.5)
    pcall(function() start_remote:InvokeServer() end)
    return true
end

-- Scan EndScreen rewards and add to player material counts
local function scanRewards(endScreen)
    if not endScreen then return false end
    local rewardsFrame = endScreen:FindFirstChild("Rewards")
    local scroll = rewardsFrame and rewardsFrame:FindFirstChild("ScrollingFrame")
    if not scroll then return false end
    local added = false
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("ImageButton") then
            local qtyLabel = child:FindFirstChild("Quantity")
            local qty = qtyLabel and tonumber(qtyLabel.Text) or 0
            if qty and qty > 0 then
                local name = child.Name
                if playerItems[name] ~= nil then
                    playerItems[name] = (playerItems[name] or 0) + qty
                    added = true
                elseif playerStats[name] ~= nil then
                    playerStats[name] = (playerStats[name] or 0) + qty
                    added = true
                end
            end
        end
    end
    return added
end

-- Listen for game ending -> read rewards -> update -> replay or leave
if gameEnding then
    gameEnding.OnClientEvent:Connect(function()
        -- Wait for EndScreen GUI to appear (up to 5s)
        local endScreen = nil
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        for i = 1, 10 do
            local menus = playerGui:FindFirstChild("Menus")
            if menus then
                endScreen = menus:FindFirstChild("EndScreen")
                if endScreen and endScreen.Visible then break end
            end
            task.wait(0.5)
        end

        if not endScreen then
            -- Fallback: try remote replay
            if gameReplay then pcall(function() gameReplay:FireServer() end) end
            return
        end

        -- Scan rewards from victory screen
        pcall(scanRewards, endScreen)

        local u = selectedUnit
        if u then
            pcall(refreshData, u)
            pcall(logMaterialStatus, u)
        end

        if not farming then return end

        if not u or u.numMissing == 0 then
            Fluent:Notify({ Title = "HOAN THANH!", Content = "Unit da du ALL material de awaken!", Duration = 10 })
            setFarmOff()
            if gameTeleport then
                pcall(function() gameTeleport:FireServer() end)
            end
            return
        end

        -- Check if current map's material is done -> switch maps
        local curMatDone = true
        for _, m in ipairs(u.missing) do
            if m.mat == currentFarmedMat then
                curMatDone = false; break
            end
        end

        if curMatDone and inHub and create_room and start_remote then
            -- Current material gathered -> leave and create room for next material
            Fluent:Notify({ Title = "Chuyen map", Content = currentFarmedMat .. " da du! Chuyen sang material khac...", Duration = 3 })
            if gameTeleport then
                pcall(function() gameTeleport:FireServer() end)
                task.wait(3)
            end
            if not enterGame(u) then
                Fluent:Notify({ Title = "Loi", Content = "Khong the tao phong!", Duration = 3 })
            end
        else
            -- Still missing same material -> replay
            Fluent:Notify({ Title = "Con thieu", Content = tostring(u.numMissing) .. " material - replay...", Duration = 3 })
            if gameReplay then
                pcall(function() gameReplay:FireServer() end)
            end
        end
    end)
end

local function doFarmLoop()
    local u = selectedUnit
    if not u then setFarmOff(); return end

    refreshData(u)
    logMaterialStatus(u)

    if u.numMissing == 0 then
        Fluent:Notify({ Title = "HOAN THANH!", Content = "Unit da du ALL material!", Duration = 10 })
        setFarmOff(); return
    end

    if not getFirstDrop(u) then
        Fluent:Notify({ Title = "Loi", Content = "Khong tim thay drop location cho material con thieu!", Duration = 5 })
        setFarmOff(); return
    end

    -- Enter first game
    if inHub and create_room and start_remote then
        if not enterGame(u) then
            Fluent:Notify({ Title = "Loi", Content = "Khong the tao phong!", Duration = 3 })
            setFarmOff(); return
        end
    end

    -- Wait for ending handler to manage all transitions
    while farming do
        task.wait(5)
        refreshData(u)
        logMaterialStatus(u)
        if u.numMissing == 0 then
            Fluent:Notify({ Title = "HOAN THANH!", Content = "Unit da du ALL material!", Duration = 10 })
            setFarmOff(); break
        end
    end
end

local function isActuallyInGame()
    local hasGame = pcall(function() return ReplicatedStorage.Remotes.Game ~= nil end)
    local hasPlay = pcall(function() return ReplicatedStorage.Remotes.Play ~= nil end)
    return hasGame and not hasPlay
end

autoFarmToggle:OnChanged(function(value)
    -- Prevent USER from turning off when in-game stage and farming is active
    if not value and farming and isActuallyInGame() and not allowToggleOff then
        Fluent:Notify({ Title = "Warning", Content = "Khong the tat Auto Farm khi dang trong tran!", Duration = 3 })
        autoFarmToggle:SetValue(true)
        return
    end
    farming = value
    if value then
        if inHub then
            if not selectedUnit then
                -- Restoring from config before dropdown is ready -- wait for dropdown
                Fluent:Notify({ Title = "Auto Farm", Content = "Cho chon unit...", Duration = 2 })
                return
            end
            if selectedUnit.numMissing == 0 then
                Fluent:Notify({ Title = "Loi", Content = "Unit da du material!", Duration = 3 })
                setFarmOff(); return
            end
            Fluent:Notify({ Title = "Auto Farm", Content = "Bat dau farm cho " .. selectedUnit.name .. " (chuyen map tu dong)...", Duration = 4 })
            task.spawn(doFarmLoop)
        else
            Fluent:Notify({ Title = "Auto Farm", Content = "Trong game - auto replay + teleport khi du material", Duration = 4 })
        end
    else
        Fluent:Notify({ Title = "Auto Farm", Content = "Da dung.", Duration = 3 })
    end
end)

local TabsS = Window:AddTab({ Title = "Settings", Icon = "settings" })
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
-- Let SaveManager handle all UI state (dropdown, toggle, etc.)
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("EvoFarmer2")
SaveManager:SetFolder("EvoFarmer2/configs")
InterfaceManager:BuildInterfaceSection(TabsS)
SaveManager:BuildConfigSection(TabsS)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

-- Restore selected unit from saved name if dropdown didn't match (stale value)
task.spawn(function()
    task.wait(1)
    if not selectedUnit then
        local savedName = loadSelectedUnitName()
        if savedName ~= "" and unitByName[savedName] then
            selectedUnit = unitByName[savedName]
            for key, u in pairs(unitMap) do
                if u == selectedUnit then
                    unitDropdown:SetValue(key)
                    break
                end
            end
        end
    end
    if selectedUnit then
        refreshData(selectedUnit)
        showUnitInfo(selectedUnit)
        logMaterialStatus(selectedUnit)
    end
    -- If farming was enabled by config but no unit selected yet, start now
    if farming and inHub and selectedUnit and selectedUnit.numMissing > 0 then
        Fluent:Notify({ Title = "Auto Farm", Content = "Bat dau farm cho " .. selectedUnit.name .. " (chuyen map tu dong)...", Duration = 4 })
        task.spawn(doFarmLoop)
    end
end)

Fluent:Notify({ Title = "Evo Farmer", Content = "Loaded! " .. tostring(#units) .. " unit co the awaken." .. (inHub and "" or " [IN-GAME]"), Duration = 6 })
