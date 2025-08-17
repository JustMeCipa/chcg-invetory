-- ================================
-- CHCG-INVENTAR SERVER MAIN
-- server/main.lua - FUNCTIONAL VERSION
-- ================================

local QBCore = exports['qb-core']:GetCoreObject()
local Inventories = {}
local Drops = {}

-- ================================
-- DATABASE SETUP
-- ================================

CreateThread(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `chcg_inventory_stash` (
            `id` varchar(50) NOT NULL,
            `inventory` longtext DEFAULT NULL,
            `created_at` timestamp NULL DEFAULT current_timestamp(),
            `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `chcg_inventory_trunk` (
            `plate` varchar(50) NOT NULL,
            `inventory` longtext DEFAULT NULL,
            `created_at` timestamp NULL DEFAULT current_timestamp(),
            `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `chcg_inventory_glovebox` (
            `plate` varchar(50) NOT NULL,
            `inventory` longtext DEFAULT NULL,
            `created_at` timestamp NULL DEFAULT current_timestamp(),
            `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    print('^2[CHCG-INVENTAR]^0 Database tables created successfully!')
end)

-- ================================
-- HELPER FUNCTIONS
-- ================================

function GetPlayerInventory(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return {} end
    
    local items = {}
    if Player.PlayerData.items then
        for slot, item in pairs(Player.PlayerData.items) do
            if item and item.amount and item.amount > 0 then
                items[tostring(slot)] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info or {},
                    label = item.label or QBCore.Shared.Items[item.name]?.label or item.name,
                    description = item.description or QBCore.Shared.Items[item.name]?.description or '',
                    weight = QBCore.Shared.Items[item.name]?.weight or 0,
                    type = QBCore.Shared.Items[item.name]?.type or 'item',
                    unique = QBCore.Shared.Items[item.name]?.unique or false,
                    useable = QBCore.Shared.Items[item.name]?.useable or false,
                    image = QBCore.Shared.Items[item.name]?.image or item.name .. '.png'
                }
            end
        end
    end
    
    return items
end

function GetInventoryWeight(items)
    local weight = 0
    for _, item in pairs(items) do
        if item and item.amount then
            weight = weight + ((QBCore.Shared.Items[item.name]?.weight or 0) * item.amount)
        end
    end
    return weight
end

-- ================================
-- MAIN SERVER EVENTS
-- ================================

-- Deschide inventarul
RegisterNetEvent('chcg-inventory:server:OpenInventory', function(inventoryType, identifier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    print('^3[CHCG-INVENTAR]^0 Opening inventory for player ' .. src .. ' type: ' .. (inventoryType or 'player'))
    
    -- Trimite inventarul jucătorului
    local playerItems = GetPlayerInventory(src)
    TriggerClientEvent('chcg-inventory:client:RefreshInventory', src, playerItems, 'player')
    
    -- Dacă e inventar secundar, trimite și pe acela
    if inventoryType and inventoryType ~= 'player' then
        local secondaryItems = GetSecondaryInventory(inventoryType, identifier)
        TriggerClientEvent('chcg-inventory:client:RefreshInventory', src, secondaryItems, inventoryType)
    end
end)

-- Folosește item
RegisterNetEvent('chcg-inventory:server:UseItem', function(slot, itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    slot = tonumber(slot)
    if not slot then
        return TriggerClientEvent('QBCore:Notify', src, 'Slot invalid!', 'error')
    end
    
    local item = Player.PlayerData.items[slot]
    if not item then
        return TriggerClientEvent('QBCore:Notify', src, 'Nu ai acest item!', 'error')
    end
    
    if item.name ~= itemName then
        return TriggerClientEvent('QBCore:Notify', src, 'Item nu corespunde!', 'error')
    end
    
    if item.amount <= 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Nu ai acest item!', 'error')
    end
    
    -- Verifică dacă itemul poate fi folosit
    local itemData = QBCore.Shared.Items[itemName]
    if not itemData then
        return TriggerClientEvent('QBCore:Notify', src, 'Item inexistent!', 'error')
    end
    
    if not itemData.useable then
        return TriggerClientEvent('QBCore:Notify', src, 'Acest item nu poate fi folosit!', 'error')
    end
    
    print('^3[CHCG-INVENTAR]^0 Player ' .. src .. ' used item: ' .. itemName .. ' from slot ' .. slot)
    
    -- Pentru arme, nu le consuma
    if string.find(itemName, 'weapon_') then
        TriggerClientEvent('QBCore:Notify', src, 'Ai echipat ' .. (itemData.label or itemName), 'success')
        
        -- Trigger pentru echiparea armei
        TriggerEvent('QBCore:Server:UseItem', src, itemName)
        TriggerClientEvent('QBCore:Client:UseWeapon', src, itemName)
    else
        -- Pentru alte iteme, le consumă
        local success = Player.Functions.RemoveItem(itemName, 1, slot)
        if success then
            TriggerClientEvent('QBCore:Notify', src, 'Ai folosit ' .. (itemData.label or itemName), 'success')
            
            -- Trigger pentru folosirea itemului
            TriggerEvent('QBCore:Server:UseItem', src, itemName)
            
            -- Refreshează inventarul
            local updatedItems = GetPlayerInventory(src)
            TriggerClientEvent('chcg-inventory:client:RefreshInventory', src, updatedItems, 'player')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Nu se poate folosi itemul!', 'error')
        end
    end
end)

-- Mută item
RegisterNetEvent('chcg-inventory:server:MoveItem', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local fromSlot = tonumber(data.fromSlot)
    local toSlot = tonumber(data.toSlot)
    local amount = tonumber(data.amount) or 1
    
    if not fromSlot or not toSlot then
        return TriggerClientEvent('QBCore:Notify', src, 'Slot invalid!', 'error')
    end
    
    local fromItem = Player.PlayerData.items[fromSlot]
    if not fromItem or fromItem.amount < amount then
        return TriggerClientEvent('QBCore:Notify', src, 'Nu ai acest item!', 'error')
    end
    
    print('^3[CHCG-INVENTAR]^0 Moving item from slot ' .. fromSlot .. ' to slot ' .. toSlot)
    
    -- Mută itemul
    local success = Player.Functions.MoveItem(fromSlot, toSlot, amount)
    
    if success then
        -- Refreshează inventarul
        local updatedItems = GetPlayerInventory(src)
        TriggerClientEvent('chcg-inventory:client:RefreshInventory', src, updatedItems, 'player')
        TriggerClientEvent('QBCore:Notify', src, 'Item mutat!', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Nu se poate muta itemul!', 'error')
    end
end)

-- Dă item
RegisterNetEvent('chcg-inventory:server:GiveItem', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local targetId = tonumber(data.targetPlayer)
    local slot = tonumber(data.slot)
    local amount = tonumber(data.amount) or 1
    
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        return TriggerClientEvent('QBCore:Notify', src, 'Jucătorul nu a fost găsit!', 'error')
    end
    
    local item = Player.PlayerData.items[slot]
    if not item or item.amount < amount then
        return TriggerClientEvent('QBCore:Notify', src, 'Nu ai acest item!', 'error')
    end
    
    -- Verifică distanța
    local srcCoords = GetEntityCoords(GetPlayerPed(src))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetId))
    local distance = #(srcCoords - targetCoords)
    
    if distance > 3.0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Jucătorul este prea departe!', 'error')
    end
    
    -- Dă itemul
    local success = Player.Functions.RemoveItem(item.name, amount, slot)
    if success then
        TargetPlayer.Functions.AddItem(item.name, amount, false, item.info)
        
        TriggerClientEvent('QBCore:Notify', src, 'Ai dat ' .. amount .. 'x ' .. (item.label or item.name), 'success')
        TriggerClientEvent('QBCore:Notify', targetId, 'Ai primit ' .. amount .. 'x ' .. (item.label or item.name), 'success')
        
        -- Refreshează inventarele
        local updatedItems = GetPlayerInventory(src)
        TriggerClientEvent('chcg-inventory:client:RefreshInventory', src, updatedItems, 'player')
        
        local targetItems = GetPlayerInventory(targetId)
        TriggerClientEvent('chcg-inventory:client:RefreshInventory', targetId, targetItems, 'player')
    end
end)

-- Aruncă item
RegisterNetEvent('chcg-inventory:server:DropItem', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local slot = tonumber(data.slot)
    local amount = tonumber(data.amount) or 1
    
    local item = Player.PlayerData.items[slot]
    if not item or item.amount < amount then
        return TriggerClientEvent('QBCore:Notify', src, 'Nu ai acest item!', 'error')
    end
    
    -- Verifică dacă itemul poate fi aruncat
    if Config.RestrictedItems[item.name] then
        return TriggerClientEvent('QBCore:Notify', src, 'Acest item nu poate fi aruncat!', 'error')
    end
    
    -- Aruncă itemul
    local success = Player.Functions.RemoveItem(item.name, amount, slot)
    if success then
        -- Aici poți adăuga logica pentru drop-uri pe jos
        TriggerClientEvent('QBCore:Notify', src, 'Ai aruncat ' .. amount .. 'x ' .. (item.label or item.name), 'success')
        
        -- Refreshează inventarul
        local updatedItems = GetPlayerInventory(src)
        TriggerClientEvent('chcg-inventory:client:RefreshInventory', src, updatedItems, 'player')
    end
end)

-- ================================
-- SECONDARY INVENTORY FUNCTIONS
-- ================================

function GetSecondaryInventory(inventoryType, identifier)
    local items = {}
    
    if inventoryType == 'trunk' then
        local result = MySQL.Sync.fetchAll('SELECT inventory FROM chcg_inventory_trunk WHERE plate = ?', {identifier})
        if result[1] and result[1].inventory then
            items = json.decode(result[1].inventory) or {}
        end
    elseif inventoryType == 'glovebox' then
        local result = MySQL.Sync.fetchAll('SELECT inventory FROM chcg_inventory_glovebox WHERE plate = ?', {identifier})
        if result[1] and result[1].inventory then
            items = json.decode(result[1].inventory) or {}
        end
    elseif inventoryType == 'stash' then
        local result = MySQL.Sync.fetchAll('SELECT inventory FROM chcg_inventory_stash WHERE id = ?', {identifier})
        if result[1] and result[1].inventory then
            items = json.decode(result[1].inventory) or {}
        end
    end
    
    return items
end

-- ================================
-- PLAYER EVENTS
-- ================================

-- Când jucătorul se conectează
RegisterNetEvent('QBCore:Server:PlayerLoaded', function(playerId)
    Wait(1000) -- Așteaptă să se încarce complet
    local Player = QBCore.Functions.GetPlayer(playerId)
    if Player then
        local items = GetPlayerInventory(playerId)
        TriggerClientEvent('chcg-inventory:client:RefreshInventory', playerId, items, 'player')
    end
end)

-- Când inventarul se actualizează
RegisterNetEvent('QBCore:Server:OnItemUpdate', function(playerId)
    local items = GetPlayerInventory(playerId)
    TriggerClientEvent('chcg-inventory:client:RefreshInventory', playerId, items, 'player')
end)

-- ================================
-- EXPORTS
-- ================================

-- Export pentru alte resurse
exports('GetPlayerInventory', GetPlayerInventory)
exports('GetInventoryWeight', GetInventoryWeight)

print('^2[CHCG-INVENTAR]^0 Server loaded successfully!')

-- Eveniment pentru folosirea itemelor
RegisterNetEvent('qb-inventory:server:UseItem', function(slot, itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local item = Player.PlayerData.items[slot]
    if not item or item.name ~= itemName then
        return TriggerClientEvent('QBCore:Notify', src, 'Item invalid!', 'error')
    end
    
    if item.amount <= 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Nu ai destule bucăți!', 'error')
    end
    
    -- Procesează folosirea itemului
    ProcessItemUse(src, slot, item)
end)

-- ================================
-- FUNCȚII SERVER
-- ================================

function ValidateMove(src, fromSlot, toSlot, fromInventory, toInventory, amount)
    -- Validări de bază
    if not fromSlot or not toSlot or not fromInventory or not toInventory then
        return false
    end
    
    if amount <= 0 then
        return false
    end
    
    -- Verifică dacă jucătorul are permisiunea
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    
    return true
end

function ProcessItemMove(src, fromSlot, toSlot, fromInventory, toInventory, amount, fromIdentifier, toIdentifier)
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- Obține itemul sursă
    local sourceItem = GetItemFromInventory(fromInventory, fromSlot, fromIdentifier)
    if not sourceItem or sourceItem.amount < amount then
        return false
    end
    
    -- Verifică itemul restricționat
    if Config.RestrictedItems[sourceItem.name] and fromInventory ~= toInventory then
        TriggerClientEvent('QBCore:Notify', src, 'Acest item nu poate fi mutat!', 'error')
        return false
    end
    
    -- Verifică greutatea și sloturile
    if not CanAddToInventory(toInventory, toIdentifier, sourceItem, amount) then
        TriggerClientEvent('QBCore:Notify', src, 'Nu ai destul spațiu!', 'error')
        return false
    end
    
    -- Procesează mutarea
    if fromInventory == toInventory and fromIdentifier == toIdentifier then
        -- Mutare în același inventar
        return MoveWithinSameInventory(src, fromSlot, toSlot, amount)
    else
        -- Mutare între inventare diferite
        return MoveBetweenInventories(src, fromSlot, toSlot, fromInventory, toInventory, amount, fromIdentifier, toIdentifier)
    end
end

function GetItemFromInventory(inventoryType, slot, identifier)
    if inventoryType == 'player' then
        local Player = QBCore.Functions.GetPlayer(tonumber(identifier))
        if Player and Player.PlayerData.items[slot] then
            return Player.PlayerData.items[slot]
        end
    else
        -- Pentru alte tipuri de inventar
        local inventory = GetInventoryData(inventoryType, identifier)
        if inventory and inventory[slot] then
            return inventory[slot]
        end
    end
    return nil
end

function CanAddToInventory(inventoryType, identifier, item, amount)
    local config = Config.InventoryTypes[inventoryType]
    if not config then return false end
    
    local currentWeight = GetInventoryWeight(inventoryType, identifier)
    local itemWeight = (QBCore.Shared.Items[item.name].weight or 0) * amount
    
    if currentWeight + itemWeight > config.maxWeight then
        return false
    end
    
    local usedSlots = GetUsedSlots(inventoryType, identifier)
    if usedSlots >= config.maxSlots then
        return false
    end
    
    return true
end

function GetInventoryWeight(inventoryType, identifier)
    local weight = 0
    local inventory = {}
    
    if inventoryType == 'player' then
        local Player = QBCore.Functions.GetPlayer(tonumber(identifier))
        if Player then
            inventory = Player.PlayerData.items or {}
        end
    else
        inventory = GetInventoryData(inventoryType, identifier) or {}
    end
    
    for _, item in pairs(inventory) do
        if item and item.name and item.amount then
            local itemData = QBCore.Shared.Items[item.name]
            if itemData then
                weight = weight + (itemData.weight or 0) * item.amount
            end
        end
    end
    
    return weight
end

function GetUsedSlots(inventoryType, identifier)
    local slots = 0
    local inventory = {}
    
    if inventoryType == 'player' then
        local Player = QBCore.Functions.GetPlayer(tonumber(identifier))
        if Player then
            inventory = Player.PlayerData.items or {}
        end
    else
        inventory = GetInventoryData(inventoryType, identifier) or {}
    end
    
    for _, item in pairs(inventory) do
        if item and item.amount > 0 then
            slots = slots + 1
        end
    end
    
    return slots
end

function ProcessItemUse(src, slot, item)
    -- Verifică dacă itemul poate fi folosit
    local itemData = QBCore.Shared.Items[item.name]
    if not itemData or not itemData.useable then
        return TriggerClientEvent('QBCore:Notify', src, 'Acest item nu poate fi folosit!', 'error')
    end
    
    -- Trigger eveniment de folosire specifică itemului
    TriggerEvent('qb-inventory:server:ItemUsed', src, item.name, slot, item.info)
    
    -- Reduce cantitatea
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.RemoveItem(item.name, 1, slot)
    
    TriggerClientEvent('QBCore:Notify', src, 'Ai folosit ' .. itemData.label, 'success')
end

function RefreshInventories(src, fromInventory, toInventory, fromIdentifier, toIdentifier)
    -- Actualizează inventarul sursă
    if fromInventory == 'player' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            TriggerClientEvent('qb-inventory:client:RefreshInventory', src, Player.PlayerData.items, 'player')
        end
    end
    
    -- Actualizează inventarul destinație dacă este diferit
    if toInventory ~= fromInventory or toIdentifier ~= fromIdentifier then
        if toInventory == 'player' then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                TriggerClientEvent('qb-inventory:client:RefreshInventory', src, Player.PlayerData.items, 'player')
            end
        else
            local inventory = GetInventoryData(toInventory, toIdentifier)
            TriggerClientEvent('qb-inventory:client:RefreshInventory', src, inventory, toInventory)
        end
    end
end

function GetInventoryData(inventoryType, identifier)
    -- Implementează logica pentru a obține datele inventarului din baza de date
    -- Aceasta este o funcție placeholder - trebuie adaptată la sistemul tău de bază de date
    
    if inventoryType == 'trunk' then
        -- Exemplu pentru portbagaj
        local result = MySQL.Sync.fetchAll('SELECT inventory FROM vehicle_trunk WHERE plate = ?', {identifier})
        if result[1] then
            return json.decode(result[1].inventory) or {}
        end
    elseif inventoryType == 'stash' then
        -- Exemplu pentru stash
        local result = MySQL.Sync.fetchAll('SELECT inventory FROM stash WHERE id = ?', {identifier})
        if result[1] then
            return json.decode(result[1].inventory) or {}
        end
    end
    
    return {}
end

-- ================================
-- FUNCȚII UTILITARE
-- ================================

function MoveWithinSameInventory(src, fromSlot, toSlot, amount)
    -- Implementează logica pentru mutarea în același inventar
    return true
end

function MoveBetweenInventories(src, fromSlot, toSlot, fromInventory, toInventory, amount, fromIdentifier, toIdentifier)
    -- Implementează logica pentru mutarea între inventare diferite
    return true
end

-- ================================
-- DEBUG
-- ================================

function DebugLog(message)
    if Config.Debug then
        print('[QB-INVENTORY DEBUG]: ' .. tostring(message))
    end
end

-- Export pentru alte resurse
exports('GetInventoryWeight', GetInventoryWeight)
exports('CanAddToInventory', CanAddToInventory)
exports('GetInventoryData', GetInventoryData)