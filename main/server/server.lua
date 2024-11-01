local lootedPropsFile = "looted_props.json"
local lootedProps = {}

local QBCore = nil
local ESX = nil

Citizen.CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    end
end)

function resetLootedProps()
    lootedProps = {}
    SaveResourceFile(GetCurrentResourceName(), lootedPropsFile, json.encode(lootedProps), -1)
    print("Looted props reset to allow re-looting on script restart.")
end

function loadLootedProps()
    local content = LoadResourceFile(GetCurrentResourceName(), lootedPropsFile)
    if content then
        lootedProps = json.decode(content)
        if not lootedProps then
            lootedProps = {}
            print("Error decoding looted props. Starting with an empty list.")
        else
            print("Looted props loaded from file.")
        end
    else
        lootedProps = {}
        print("Looted props file not found. Starting with an empty list.")
    end
end

function saveLootedProps()
    local content = json.encode(lootedProps)
    if content then
        SaveResourceFile(GetCurrentResourceName(), lootedPropsFile, content, -1)
        print("Looted props saved to file.")
    else
        print("Error: Could not encode looted props to JSON.")
    end
end

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        resetLootedProps()  
        loadLootedProps()   
    end
end)

RegisterNetEvent("server:checkPropLooted")
AddEventHandler("server:checkPropLooted", function(propId)
    local src = source
    if lootedProps[propId] then
        TriggerClientEvent("client:propAlreadyLooted", src)
    else
        lootedProps[propId] = true
        saveLootedProps() 
        TriggerClientEvent("client:allowLooting", src)
    end
end)

RegisterNetEvent("server:syncLootedProps")
AddEventHandler("server:syncLootedProps", function()
    local src = source
    TriggerClientEvent("client:syncLootedProps", src, lootedProps)
end)

local function isItemValid(itemName)
    if QBCore then
        return QBCore.Shared.Items[itemName] ~= nil
    elseif ESX then
        return ESX.GetItem(itemName) ~= nil
    end
    return false
end

RegisterNetEvent("server:giveLootReward")
AddEventHandler("server:giveLootReward", function(rewardType, rewardValue)
    local src = source
    if rewardType == "item" then
        local itemName, quantity = rewardValue.itemName, rewardValue.quantity
        if not isItemValid(itemName) then
            print("[ERROR] Invalid item: "..itemName..". Not found in inventory system.")
            TriggerClientEvent("client:showNotification", src, "⚠️ This item does not exist: " .. itemName)
            return
        end
        if QBCore then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                local itemAdded = Player.Functions.AddItem(itemName, quantity)
                if itemAdded then
                    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
                    print("[INFO] Item given: "..itemName.." x"..quantity.." added to player.")
                else
                    print("[ERROR] Unable to add item: "..itemName.." to the player.")
                end
            else
                print("[ERROR] QBCore Player object not found.")
            end
        elseif ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.addInventoryItem(itemName, quantity)
                print("[INFO] Item given: "..itemName.." x"..quantity.." added to player.")
            else
                print("[ERROR] ESX player object not found.")
            end
        else
            print("[ERROR] No compatible framework found for giving items.")
        end
    elseif rewardType == "money" then
        local amount = rewardValue
        if QBCore then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                Player.Functions.AddMoney("cash", amount)
                print("[INFO] Money given: $"..amount.." added to player.")
            else
                print("[ERROR] QBCore Player object not found.")
            end
        elseif ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.addMoney(amount)
                print("[INFO] Money given: $"..amount.." added to player.")
            else
                print("[ERROR] ESX player object not found.")
            end
        else
            print("[ERROR] No compatible framework found for giving money.")
        end
    else
        print("[ERROR] Invalid reward type: "..tostring(rewardType))
    end
end)
