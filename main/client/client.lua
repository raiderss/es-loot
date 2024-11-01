local lootedProps = {}
local lootableProps = Config.box
local lootItems = Config.loot
local QBCore = nil
local ESX = nil

Citizen.CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Citizen.Wait(0)
        end
    end
end)

local function GetPropUniqueId(prop)
    local model = GetEntityModel(prop)
    local coords = GetEntityCoords(prop)
    return tostring(model) .. "_" .. math.floor(coords.x * 100) .. "_" .. math.floor(coords.y * 100) .. "_" .. math.floor(coords.z * 100)
end

local function getLootablePropData(entity)
    local model = GetEntityModel(entity)
    for _, propData in ipairs(lootableProps) do
        if model == propData.model then
            return propData
        end
    end
    return nil
end

local function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z + 1.0, 0)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 215, 0, 255)
    SetTextCentre(true)

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function playLootSound()
    PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

local function giveMoneyBagAndDance()
    local playerPed = PlayerPedId()
    local bagModel = GetHashKey("prop_money_bag_01")
    RequestModel(bagModel)
    while not HasModelLoaded(bagModel) do
        Citizen.Wait(10)
    end
    local bagObject = CreateObject(bagModel, 0, 0, 0, true, true, true)
    AttachEntityToEntity(bagObject, playerPed, GetPedBoneIndex(playerPed, 57005), 0.15, 0.02, 0.0, 270.0, 0.0, 0.0, true, true, false, true, 1, true)
    local animDict = "anim@mp_player_intcelebrationmale@uncle_disco"
    local animName = "uncle_disco"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(10)
    end
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
    Citizen.Wait(5000)
    ClearPedTasks(playerPed)
    DeleteObject(bagObject)
    SetModelAsNoLongerNeeded(bagModel)
end

local function startLooting(prop)
    local playerPed = PlayerPedId()
    local propCoords = GetEntityCoords(prop)
    TaskTurnPedToFaceCoord(playerPed, propCoords.x, propCoords.y, propCoords.z, 500)
    Citizen.Wait(500)
    local animDict = "amb@medic@standing@kneel@base"
    local animName = "base"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(0)
    end
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    Citizen.Wait(2000)
    animDict = "mini@repair"
    animName = "fixing_a_ped"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(0)
    end
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    Citizen.Wait(3000)
    ClearPedTasks(playerPed)
    local propId = GetPropUniqueId(prop)
    lootedProps[propId] = true
    if math.random(100) <= Config.moneyChance then
        local moneyAmount = math.random(Config.moneyReward.min, Config.moneyReward.max)
        TriggerServerEvent("server:giveLootReward", "money", moneyAmount)
        AddNotification("💵 You found $" .. moneyAmount .. "! Lucky find!", 'success')
        giveMoneyBagAndDance()
    else
        local availableLoot = {}
        for _, loot in ipairs(lootItems) do
            if math.random(100) <= loot.chance then
                table.insert(availableLoot, loot)
            end
        end
        if #availableLoot > 0 then
            local loot = availableLoot[math.random(#availableLoot)]
            local quantity = math.random(loot.minQty, loot.maxQty)
            TriggerServerEvent("server:giveLootReward", "item", { itemName = loot.item, quantity = quantity })
            AddNotification("🎉 You found: " .. loot.item .. " x" .. quantity .. "! Nice find!", 'success')
        else
            AddNotification("⚠️ Nothing useful found this time.", 'error')
        end
    end
    playLootSound()
end



function AddNotification(text, type)
    if QBCore then
        QBCore.Functions.Notify(text, type or 'primary', 5000)
    elseif ESX then
        ESX.ShowNotification(text)
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(text)
        DrawNotification(false, true)
    end
end

local lootingProp = nil
local lootingPropData = nil

Citizen.CreateThread(function()
    TriggerServerEvent("server:syncLootedProps")
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearestProp, propDistance, propData = nil, 1.5, nil

        for prop in EnumerateObjects() do
            local data = getLootablePropData(prop)
            if data then
                local propCoords = GetEntityCoords(prop)
                if propCoords then
                    local distance = #(playerCoords - propCoords)
                    local propId = GetPropUniqueId(prop)
                    if distance < propDistance and not lootedProps[propId] then
                        nearestProp = prop
                        propDistance = distance
                        propData = data
                    end
                end
            end
        end
        if nearestProp and propData then
            local propCoords = GetEntityCoords(nearestProp)
            DrawText3D(propCoords.x, propCoords.y, propCoords.z, "💰 [E] Loot this treasure!")
            if IsControlJustPressed(1, 38) then
                local propId = GetPropUniqueId(nearestProp)
                lootingProp = nearestProp
                lootingPropData = propData
                TriggerServerEvent("server:checkPropLooted", propId)
            end
        end
    end
end)

RegisterNetEvent("client:propAlreadyLooted")
AddEventHandler("client:propAlreadyLooted", function()
    AddNotification("⚠️ This prop has already been looted!", 'error')
end)

RegisterNetEvent("client:allowLooting")
AddEventHandler("client:allowLooting", function()
    if lootingProp and lootingPropData then
        startLooting(lootingProp)
        lootingProp = nil
        lootingPropData = nil
    else
        AddNotification("⚠️ Could not find the prop to loot.", 'error')
    end
end)

RegisterNetEvent("client:syncLootedProps")
AddEventHandler("client:syncLootedProps", function(serverLootedProps)
    lootedProps = serverLootedProps
end)

function EnumerateObjects()
    return coroutine.wrap(function()
        local handle, object = FindFirstObject()
        if not handle or handle == -1 then
            EndFindObject(handle)
            return
        end
        local success
        repeat
            coroutine.yield(object)
            success, object = FindNextObject(handle)
        until not success
        EndFindObject(handle)
    end)
end
