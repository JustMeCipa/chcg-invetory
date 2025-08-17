-- ================================
-- CHCG-INVENTAR CLIENT MAIN
-- client/main.lua - FUNCTIONAL VERSION
-- ================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Variables
local isInventoryOpen = false
local currentInventoryType = nil
local currentInventoryData = {}
local playerData = {}

-- ================================
-- PLAYER DATA HANDLER
-- ================================

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerData = QBCore.Functions.GetPlayerData()
    Wait(2000) -- Așteaptă să se încarce complet
    RequestInventoryUpdate()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerData = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    playerData = val
    if isInventoryOpen then
        RequestInventoryUpdate()
    end
end)

-- Când se actualizează inventarul în QBCore
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    playerData = val
    -- Trimite datele către NUI
    if isInventoryOpen then
        SendNUIMessage({
            action = 'updateInventory',
            items = ConvertQBItemsToNUI(playerData.items or {}),
            type = 'player'
        })
    end
end)

-- ================================
-- INVENTORY FUNCTIONS
-- ================================

function OpenInventory(inventoryType, identifier, data)
    if isInventoryOpen then return end
    
    currentInventoryType = inventoryType or 'player'
    currentInventoryData = data or {}
    
    print('^3[CHCG-INVENTAR]^0 Opening inventory type: ' .. currentInventoryType)
    
    -- Cere inventarul de la server
    TriggerServerEvent('chcg-inventory:server:OpenInventory', currentInventoryType, identifier)
    
    -- Deschide NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openInventory',
        type = currentInventoryType,
        data = currentInventoryData
    })
    
    isInventoryOpen = true
    
    -- Disable controls
    CreateThread(function()
        while isInventoryOpen do
            DisableControlAction(0, 1, true) -- Mouse look
            DisableControlAction(0, 2, true) -- Mouse look
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 263, true) -- Melee Attack
            Wait(0)
        end
    end)
end

function CloseInventory()
    if not isInventoryOpen then return end
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeInventory'
    })
    
    isInventoryOpen = false
    currentInventoryType = nil
    currentInventoryData = {}
    
    print('^3[CHCG-INVENTAR]^0 Inventory closed')
end

function RequestInventoryUpdate()
    if playerData and playerData.items then
        SendNUIMessage({
            action = 'updateInventory',
            items = ConvertQBItemsToNUI(playerData.items),
            type = 'player'
        })
    end
end

-- ================================
-- DATA CONVERSION
-- ================================

function ConvertQBItemsToNUI(qbItems)
    local nuiItems = {}
    
    for slot, item in pairs(qbItems or {}) do
        if item and item.amount and item.amount > 0 then
            nuiItems[tostring(slot)] = {
                name = item.name,
                amount = item.amount,
                info = item.info or {},
                label = item.label or 'Unknown Item',
                description = item.description or '',
                weight = item.weight or 0,
                type = item.type or 'item',
                unique = item.unique or false,
                useable = item.useable or false,
                image = item.image or item.name .. '.png'
            }
        end
    end
    
    return nuiItems
end

-- ================================
-- KEYBINDS AND COMMANDS
-- ================================

-- Command pentru inventar
RegisterCommand('inventory', function()
    if not isInventoryOpen then
        OpenInventory('player')
    else
        CloseInventory()
    end
end, false)

RegisterKeyMapping('inventory', 'Deschide Inventarul', 'keyboard', Config.Hotkeys.inventory.key)

-- Keybinds pentru hotbar
for i = 1, 5 do
    RegisterCommand('hotbar_' .. i, function()
        UseHotbarItem(i)
    end, false)
    
    RegisterKeyMapping('hotbar_' .. i, 'Folosește slotul ' .. i, 'keyboard', tostring(i))
end

-- ================================
-- HOTBAR FUNCTIONS
-- ================================

function UseHotbarItem(slot)
    if not playerData.items or not playerData.items[slot] then 
        return TriggerEvent('QBCore:Notify', 'Nu ai nimic în acest slot!', 'error')
    end
    
    local item = playerData.items[slot]
    print('^3[CHCG-INVENTAR]^0 Using hotbar item: ' .. item.name .. ' from slot ' .. slot)
    
    TriggerServerEvent('chcg-inventory:server:UseItem', slot, item.name)
end

function UpdateHotbar()
    local hotbarItems = {}
    
    for i = 1, 5 do
        if playerData.items and playerData.items[i] then
            hotbarItems[i] = playerData.items[i]
        end
    end
    
    SendNUIMessage({
        action = 'updateHotbar',
        items = ConvertQBItemsToNUI(hotbarItems)
    })
end

-- ================================
-- VEHICLE INTERACTION
-- ================================

function GetNearestVehicle()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle, GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
    end
    
    return nil, nil
end

function OpenVehicleInventory(inventoryType)
    local vehicle, plate = GetNearestVehicle()
    
    if not vehicle then
        return TriggerEvent('QBCore:Notify', 'Nu există niciun vehicul în apropiere!', 'error')
    end
    
    local vehicleClass = GetVehicleClass(vehicle)
    local maxWeight = 300000 -- Default
    
    if inventoryType == 'glovebox' then
        maxWeight = 10000
    end
    
    local data = {
        plate = plate,
        maxWeight = maxWeight
    }
    
    OpenInventory(inventoryType, plate, data)
end

-- Commands pentru vehicule
RegisterCommand('trunk', function()
    OpenVehicleInventory('trunk')
end, false)

RegisterKeyMapping('trunk', 'Deschide Portbagajul', 'keyboard', 'U')

RegisterCommand('glovebox', function()
    OpenVehicleInventory('glovebox')
end, false)

RegisterKeyMapping('glovebox', 'Deschide Torpedoul', 'keyboard', 'G')

-- ================================
-- NUI CALLBACKS
-- ================================

RegisterNUICallback('closeInventory', function(data, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    print('^3[CHCG-INVENTAR]^0 Moving item via NUI:', json.encode(data))
    TriggerServerEvent('chcg-inventory:server:MoveItem', data)
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    print('^3[CHCG-INVENTAR]^0 Using item via NUI:', data.item.name, 'slot:', data.slot)
    TriggerServerEvent('chcg-inventory:server:UseItem', data.slot, data.item.name)
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    print('^3[CHCG-INVENTAR]^0 Dropping item via NUI:', json.encode(data))
    TriggerServerEvent('chcg-inventory:server:DropItem', data)
    cb('ok')
end)

RegisterNUICallback('giveItem', function(data, cb)
    print('^3[CHCG-INVENTAR]^0 Giving item via NUI:', json.encode(data))
    TriggerServerEvent('chcg-inventory:server:GiveItem', data)
    cb('ok')
end)

-- ================================
-- SERVER EVENTS
-- ================================

RegisterNetEvent('chcg-inventory:client:RefreshInventory', function(items, inventoryType)
    print('^3[CHCG-INVENTAR]^0 Received inventory update:', inventoryType, 'items:', #items)
    
    if inventoryType == 'player' then
        -- Actualizează și playerData local
        if playerData then
            playerData.items = items
        end
    end
    
    SendNUIMessage({
        action = 'updateInventory',
        items = items,
        type = inventoryType or 'player'
    })
    
    -- Actualizează și hotbar-ul
    if inventoryType == 'player' then
        UpdateHotbar()
    end
end)

RegisterNetEvent('chcg-inventory:client:ItemUsed', function(item, amount)
    TriggerEvent('QBCore:Notify', 'Ai folosit ' .. (item.label or item), 'success')
end)

-- ================================
-- EXPORTS
-- ================================

exports('OpenInventory', OpenInventory)
exports('CloseInventory', CloseInventory)
exports('IsInventoryOpen', function() return isInventoryOpen end)

-- ================================
-- INITIALIZATION
-- ================================

CreateThread(function()
    while not playerData or not playerData.citizenid do
        playerData = QBCore.Functions.GetPlayerData()
        Wait(1000)
    end
    
    Wait(2000)
    RequestInventoryUpdate()
    UpdateHotbar()
    
    print('^2[CHCG-INVENTAR]^0 Client initialized successfully!')
end)

-- ================================
-- INVENTORY FUNCTIONS
-- ================================

function OpenInventory(inventoryType, identifier, data)
    if isInventoryOpen then return end
    
    currentInventoryType = inventoryType or 'player'
    currentInventoryData = data or {}
    
    -- Request inventory data from server
    TriggerServerEvent('chcg-inventory:server:OpenInventory', currentInventoryType, identifier)
    
    -- Open NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openInventory',
        type = currentInventoryType,
        data = currentInventoryData,
        playerData = playerData
    })
    
    isInventoryOpen = true
    
    -- Start inventory thread for updates
    CreateInventoryThread()
    
    -- Disable controls
    DisableInventoryControls()
end

function CloseInventory()
    if not isInventoryOpen then return end
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeInventory'
    })
    
    isInventoryOpen = false
    currentInventoryType = nil
    currentInventoryData = {}
    
    -- Stop inventory thread
    inventoryThread = false
    
    -- Enable controls
    EnableInventoryControls()
end

function UpdateInventory(items, inventoryType)
    if not isInventoryOpen then return end
    
    SendNUIMessage({
        action = 'updateInventory',
        items = items,
        type = inventoryType or currentInventoryType
    })
end

-- ================================
-- HOTBAR FUNCTIONS
-- ================================

function CreateHotbarThread()
    if hotbarThread then return end
    hotbarThread = true
    
    CreateThread(function()
        while hotbarThread do
            if playerData.items then
                local newHotbarItems = {}
                
                -- Get first 5 items for hotbar
                for i = 1, 5 do
                    if playerData.items[i] then
                        newHotbarItems[i] = playerData.items[i]
                    end
                end
                
                -- Update hotbar if changed
                if not CompareTables(hotbarItems, newHotbarItems) then
                    hotbarItems = newHotbarItems
                    UpdateHotbar()
                end
            end
            
            Wait(500)
        end
    end)
end

function UpdateHotbar()
    SendNUIMessage({
        action = 'updateHotbar',
        items = hotbarItems
    })
end

function UseHotbarItem(slot)
    if not playerData.items or not playerData.items[slot] then return end
    
    local item = playerData.items[slot]
    TriggerServerEvent('chcg-inventory:server:UseItem', slot, item.name)
end

-- ================================
-- CONTROLS AND KEYBINDS
-- ================================

function DisableInventoryControls()
    CreateThread(function()
        while isInventoryOpen do
            DisableControlAction(0, 1, true) -- LookLeftRight
            DisableControlAction(0, 2, true) -- LookUpDown
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(2, 24, true) -- Attack
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 263, true) -- Melee Attack 1
            DisableControlAction(0, 32, true) -- W
            DisableControlAction(0, 34, true) -- A
            DisableControlAction(0, 31, true) -- S
            DisableControlAction(0, 30, true) -- D
            Wait(0)
        end
    end)
end

function EnableInventoryControls()
    -- Controls are automatically re-enabled when the thread stops
end

-- Keybind pentru inventar
RegisterCommand('inventory', function()
    if not isInventoryOpen then
        OpenInventory('player')
    else
        CloseInventory()
    end
end, false)

RegisterKeyMapping('inventory', 'Deschide Inventarul', 'keyboard', Config.Hotkeys.inventory.key)

-- Keybinds pentru hotbar
for i = 1, 5 do
    RegisterCommand('hotbar_' .. i, function()
        UseHotbarItem(i)
    end, false)
    
    RegisterKeyMapping('hotbar_' .. i, 'Folosește slotul ' .. i, 'keyboard', tostring(i))
end

-- ================================
-- INTERACTION FUNCTIONS
-- ================================

function GetNearestVehicle()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle, GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
    end
    
    return nil, nil
end

function OpenVehicleInventory(inventoryType)
    local vehicle, plate = GetNearestVehicle()
    
    if not vehicle then
        QBCore.Functions.Notify('Nu există niciun vehicul în apropiere!', 'error')
        return
    end
    
    local vehicleClass = GetVehicleClass(vehicle)
    local className = GetVehicleClassFromName(GetEntityModel(vehicle))
    
    local data = {
        plate = plate,
        class = className,
        maxWeight = Config.VehicleSettings[className] and Config.VehicleSettings[className][inventoryType] or 100000
    }
    
    OpenInventory(inventoryType, plate, data)
end

-- Commands pentru vehicule
RegisterCommand('trunk', function()
    OpenVehicleInventory('trunk')
end, false)

RegisterKeyMapping('trunk', 'Deschide Portbagajul', 'keyboard', 'U')

RegisterCommand('glovebox', function()
    OpenVehicleInventory('glovebox')
end, false)

RegisterKeyMapping('glovebox', 'Deschide Torpedoul', 'keyboard', 'G')

-- ================================
-- DROP SYSTEM
-- ================================

function CreateDrop(coords, items)
    local dropId = GenerateDropId()
    
    SendNUIMessage({
        action = 'createDrop',
        id = dropId,
        coords = coords,
        items = items
    })
    
    return dropId
end

function RemoveDrop(dropId)
    SendNUIMessage({
        action = 'removeDrop',
        id = dropId
    })
end

function GenerateDropId()
    return 'drop_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
end

-- ================================
-- UTILITY FUNCTIONS
-- ================================

function CompareTables(t1, t2)
    if not t1 or not t2 then return false end
    
    for k, v in pairs(t1) do
        if type(v) == 'table' then
            if not CompareTables(v, t2[k]) then
                return false
            end
        else
            if v ~= t2[k] then
                return false
            end
        end
    end
    
    for k, v in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end
    
    return true
end

function GetVehicleClassFromName(hash)
    local class = GetVehicleClass(GetVehicleModelNumberFromHash(hash))
    local classNames = {
        [0] = 'compacts',
        [1] = 'sedans',
        [2] = 'suvs',
        [3] = 'coupes',
        [4] = 'muscle',
        [5] = 'sports',
        [6] = 'sports',
        [7] = 'super',
        [8] = 'motorcycles',
        [9] = 'offroad',
        [10] = 'industrial',
        [11] = 'utility',
        [12] = 'vans',
        [13] = 'cycles',
        [14] = 'boats',
        [15] = 'helicopters',
        [16] = 'planes'
    }
    
    return classNames[class] or 'sedans'
end

function CreateInventoryThread()
    if inventoryThread then return end
    inventoryThread = true
    
    CreateThread(function()
        while inventoryThread do
            -- Update weight and other inventory stats
            if currentInventoryType == 'player' and playerData.items then
                local totalWeight = 0
                local usedSlots = 0
                
                for _, item in pairs(playerData.items) do
                    if item and item.amount > 0 then
                        local itemData = QBCore.Shared.Items[item.name]
                        if itemData then
                            totalWeight = totalWeight + (itemData.weight * item.amount)
                            usedSlots = usedSlots + 1
                        end
                    end
                end
                
                SendNUIMessage({
                    action = 'updateStats',
                    weight = totalWeight,
                    maxWeight = Config.MaxWeight,
                    slots = usedSlots,
                    maxSlots = Config.MaxSlots
                })
            end
            
            Wait(1000)
        end
    end)
end

-- ================================
-- NUI CALLBACKS
-- ================================

RegisterNUICallback('closeInventory', function(data, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('chcg-inventory:server:MoveItem', data)
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('chcg-inventory:server:UseItem', data.slot, data.item.name)
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('chcg-inventory:server:DropItem', data)
    cb('ok')
end)

RegisterNUICallback('giveItem', function(data, cb)
    TriggerServerEvent('chcg-inventory:server:GiveItem', data)
    cb('ok')
end)

-- ================================
-- SERVER EVENTS
-- ================================

RegisterNetEvent('chcg-inventory:client:RefreshInventory', function(items, inventoryType)
    if inventoryType == 'player' then
        playerData.items = items
    end
    UpdateInventory(items, inventoryType)
end)

RegisterNetEvent('chcg-inventory:client:ItemUsed', function(item, amount)
    -- Aici poți adăuga efecte vizuale pentru folosirea itemelor
    QBCore.Functions.Notify('Ai folosit ' .. QBCore.Shared.Items[item].label, 'success')
end)

RegisterNetEvent('chcg-inventory:client:UpdateHotbar', function()
    CreateHotbarThread()
end)

-- ================================
-- INITIALIZATION
-- ================================

CreateThread(function()
    -- Initialize hotbar on resource start
    Wait(1000)
    UpdateHotbar()
end)

-- DEBUG COMMAND pentru a forța update
RegisterCommand('forceupdate', function()
    if playerData and playerData.items then
        print('^2[CHCG-INVENTAR]^0 Forcing inventory update...')
        
        -- Convertește itemele
        local items = {}
        for slot, item in pairs(playerData.items) do
            if item and item.amount > 0 then
                items[tostring(slot)] = {
                    name = item.name,
                    amount = item.amount,
                    label = item.label or item.name,
                    weight = item.weight or 0,
                    info = item.info or {}
                }
                print('  Slot ' .. slot .. ': ' .. item.name .. ' x' .. item.amount)
            end
        end
        
        -- Trimite direct către NUI
        SendNUIMessage({
            action = 'updateInventory',
            items = items,
            type = 'player'
        })
        
        TriggerEvent('QBCore:Notify', 'Inventar forțat să se actualizeze!', 'success')
    else
        TriggerEvent('QBCore:Notify', 'Nu ai date de jucător!', 'error')
    end
end, false)
-- DEBUG COMMAND pentru a testa sloturile
RegisterCommand('testslots', function()
    -- Trimite date simple către NUI
    SendNUIMessage({
        action = 'updateInventory',
        items = {
            ["1"] = { name = "water", amount = 5, label = "Water" },
            ["3"] = { name = "bread", amount = 2, label = "Bread" },
            ["5"] = { name = "phone", amount = 1, label = "Phone" }
        },
        type = 'player'
    })
    
    -- Deschide și inventarul
    SendNUIMessage({
        action = 'openInventory',
        type = 'player',
        data = {}
    })
    
    TriggerEvent('QBCore:Notify', 'Test slots command executed!', 'success')
end, false)

RegisterCommand('testdrag', function()
    TriggerEvent('QBCore:Notify', 'Inventarul ar trebui să suporte drag & drop acum!', 'success')
    
    -- Refresh inventarul
    if playerData and playerData.items then
        local items = {}
        for slot, item in pairs(playerData.items) do
            if item and item.amount > 0 then
                items[tostring(slot)] = {
                    name = item.name,
                    amount = item.amount,
                    label = item.label or item.name,
                    weight = item.weight or 0
                }
            end
        end
        
        SendNUIMessage({
            action = 'updateInventory',
            items = items,
            type = 'player'
        })
    end
end, false)

RegisterCommand('testimages', function()
    -- Test cu iteme comune care au imagini
    SendNUIMessage({
        action = 'updateInventory',
        items = {
            ["1"] = { name = "water", amount = 5 },
            ["2"] = { name = "bread", amount = 3 },
            ["3"] = { name = "phone", amount = 1 },
            ["4"] = { name = "money", amount = 100 },
            ["5"] = { name = "bandage", amount = 2 }
        },
        type = 'player'
    })
    TriggerEvent('QBCore:Notify', 'Test images loaded!', 'success')
end, false)

-- Event pentru echiparea armelor
RegisterNetEvent('QBCore:Client:UseWeapon', function(weaponName)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    
    if HasPedGotWeapon(playerPed, weaponHash, false) then
        -- Dacă deja are arma, o selectează
        SetCurrentPedWeapon(playerPed, weaponHash, true)
        TriggerEvent('QBCore:Notify', 'Ai selectat ' .. weaponName, 'primary')
    else
        -- Dacă nu are arma, o adaugă
        GiveWeaponToPed(playerPed, weaponHash, 250, false, true)
        SetCurrentPedWeapon(playerPed, weaponHash, true)
        TriggerEvent('QBCore:Notify', 'Ai echipat ' .. weaponName, 'success')
    end
end)

RegisterCommand('debugimg', function()
    -- Test path-urile pentru o imagine specifică
    SendNUIMessage({
        action = 'updateInventory',
        items = {
            ["1"] = { name = "phone", amount = 1 }
        },
        type = 'player'
    })
    
    -- Deschide inventarul pentru a vedea rezultatul
    SendNUIMessage({
        action = 'openInventory',
        type = 'player'
    })
    
    TriggerEvent('QBCore:Notify', 'Check F8 console for image debug info!', 'primary')
end, false)
RegisterCommand('debugfiles', function()
    -- Trimite comanda către JavaScript pentru debug files
    SendNUIMessage({
        action = 'debugFiles'
    })
    
    TriggerEvent('QBCore:Notify', 'Check F8 for file debug info!', 'primary')
end, false)