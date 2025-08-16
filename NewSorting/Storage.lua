-- Storage.lua

_REGISTERED_STORAGES = {
    -- Structure: {
    --     pName = "string",    -- represents the old string content of the list
    --     type = "string",     -- gets populated by a call to peripheral.getType(pName)
    --     label = "string",    -- UNIQUE string that the player updates manually
    --     aMID = "string",     -- Nullable modpack ID
    --     generic = boolean    -- flag that identifies whether the storage should be only used for the indicated modpack
    -- }
}

_EXCLUSION_LIST = {}
_EXCLUSION_LIST[1] = "furnace"
_EXCLUSION_LIST[2] = "trapped"
_EXCLUSION_LIST[3] = "enderstorage:ender_chest_0"

_SELECTED_OUTPUT = "enderstorage:ender_chest_0"
_STORAGE_FILTER = {}

_STORAGE_FILTER[1] = "size"
_STORAGE_FILTER[2] = "list"
_STORAGE_FILTER[3] = "pushItems"
_STORAGE_FILTER[4] = "pullItems"

function GetAllStorages()
    local storages = {}
    for _, name in ipairs(peripheral.getNames()) do
        if (name:find("storage") ~= nil) or (name:find("chest") ~= nil) or (name:find("barrel") ~= nil) then
            if IsChest(name) then
                table.insert(storages, name)
            end
        end
    end
    return storages
end

function IsChest(peripheralName)
    local result = false

    for _, exclusion in ipairs(_EXCLUSION_LIST) do
        if peripheralName:find(exclusion) then
            return false
        end
    end
    
    local success, err = pcall(function()
        local methods = peripheral.getMethods(peripheralName)
        
        if #methods ~= 0 then
            if CheckMethods(methods) then
                result = true
            else
                result = false
            end
        else
            result = false
        end
    end)

    if not success then
        print("Error in IsChest: " .. tostring(err))
    end

    return result
end

function CreateRegister ()
    if not _REGISTERED_STORAGES then
        print("Recreating storage register")
    else
        print("Creating storage register")
    end

    _REGISTERED_STORAGES = {}

    for _, name in pairs(GetAllStorages()) do
        -- Get modpack ID by analyzing items in the storage
        local aMID = nil
        local generic = true
        
        local success, items = pcall(function()
            return peripheral.call(name, "list")
        end)
        
        if success and items and next(items) ~= nil then
            local modpackSet = {}
            local itemCount = 0
            
            -- Analyze all items to find modpack identifiers
            for slot, item in pairs(items) do
                itemCount = itemCount + 1
                if item.name then
                    -- Extract modpack name (everything before the first colon)
                    local modpack = item.name:match("^([^:]+):")
                    if modpack and modpack ~= "minecraft" then
                        modpackSet[modpack] = (modpackSet[modpack] or 0) + 1
                    else
                        -- Vanilla minecraft items or items without modpack prefix
                        modpackSet["minecraft"] = (modpackSet["minecraft"] or 0) + 1
                    end
                end
            end
            
            -- Check if all items belong to the same modpack
            local modpackCount = 0
            local dominantModpack = nil
            for modpack, count in pairs(modpackSet) do
                modpackCount = modpackCount + 1
                if not dominantModpack or count > modpackSet[dominantModpack] then
                    dominantModpack = modpack
                end
            end
            
            -- If all items are from the same modpack (and it's not minecraft), set aMID
            if modpackCount == 1 and dominantModpack and dominantModpack ~= "minecraft" then
                aMID = dominantModpack
                generic = false
            elseif dominantModpack and dominantModpack ~= "minecraft" and modpackSet[dominantModpack] == itemCount then
                -- All items are from the same non-vanilla modpack
                aMID = dominantModpack
                generic = false
            end
        end
        
        table.insert(_REGISTERED_STORAGES, {
            pName = name, 
            type = peripheral.getType(name), 
            label = name, -- Default label to pName, can be updated manually
            aMID = aMID,  -- Modpack ID extracted from items
            generic = generic -- False if dedicated to a specific modpack
        })
    end

    if #_REGISTERED_STORAGES == 0 then
        print("No storages found.")
        return false
    else
        local storageNames = {}
        for _, storage in ipairs(_REGISTERED_STORAGES) do
            local storageInfo = storage.pName
            if storage.aMID then
                storageInfo = storageInfo .. " (Modpack: " .. storage.aMID .. ")"
            end
            table.insert(storageNames, storageInfo)
        end
        print("Registered storages: " .. table.concat(storageNames, ", "))
        return true
    end

end

function SearchItem(itemData)
    if itemData == nil or itemData.name == nil then
        return nil
    end

    if not _REGISTERED_STORAGES or #_REGISTERED_STORAGES == 0 then
        CreateRegister()
        if #_REGISTERED_STORAGES == 0 then
            return nil
        end
    end

    local found = {}

    for _, storage in ipairs(_REGISTERED_STORAGES) do
        local storageName = storage.pName
        local items = peripheral.call(storageName, "list")
        for slot, item in pairs(items) do
            if item.name:find(string.lower(itemData.name)) then
                if type(found[storageName]) ~= "table" then
                    found[storageName] = {}
                end
                table.insert(found[storageName], { slot = slot, item = item })
            end
        end
    end
    if found == nil then
        return false, nil
    end
    return true, found
end

function FetchItem(itemData, amount, verbose)
    if ( type(verbose) ~= "boolean") then
        verbose = false
    end
    local log = {}

    if itemData == nil or itemData.name == nil then
        PrintLog({"Invalid item data provided."})
        return false
    end

    local _, found = SearchItem(itemData)
    if not found or next(found) == nil then
        PrintLog({"Item not found in any storage."})
        return false
    end

    local remaining = amount

    -- If amount is nil or -1, fetch all items found
    local fetchAll = (remaining == nil or remaining == -1)

    for storageName, slots in pairs(found) do
        for _, entry in ipairs(slots) do
            local slot = entry.slot
            local item = entry.item

            if not fetchAll and remaining <= 0 then break end

            local toFetch = fetchAll and item.count or math.min(item.count, remaining)
            -- Assuming _SELECTED_OUTPUT is the destination chest
            if _SELECTED_OUTPUT then
                local moved = peripheral.call(storageName, "pushItems", _SELECTED_OUTPUT, slot, toFetch)
                if moved and moved > 0 then
                    log[#log + 1] = "Fetched " .. moved .. " of " .. item.name .. " from " .. storageName
                    if not fetchAll then
                        remaining = remaining - moved
                    end
                end
            else
                log[#log + 1] = "No output chest selected for fetching items."
                return false
            end
        end
        if not fetchAll and remaining <= 0 then 
            break
        end
    end

    if #log > 0 then
        if verbose then
            PrintLog(log)
        else
            print("Items fetched successfully.")
        end
        return true, log
    else
        PrintLog({"No items fetched."})
        return false
    end
end

function UpdateStorageRegister()
    print("Storage update requested")
    CreateRegister()
end

-- Helper function to find storage by label
function FindStorageByLabel(label)
    for _, storage in ipairs(_REGISTERED_STORAGES) do
        if storage.label == label then
            return storage
        end
    end
    return nil
end

-- Helper function to find storage by peripheral name
function FindStorageByPName(pName)
    for _, storage in ipairs(_REGISTERED_STORAGES) do
        if storage.pName == pName then
            return storage
        end
    end
    return nil
end

-- Helper function to update storage label
function UpdateStorageLabel(pName, newLabel)
    local storage = FindStorageByPName(pName)
    if storage then
        storage.label = newLabel
        return true
    end
    return false
end

-- Helper function to update storage modpack ID
function UpdateStorageModpackID(pName, aMID)
    local storage = FindStorageByPName(pName)
    if storage then
        storage.aMID = aMID
        return true
    end
    return false
end

-- Helper function to set storage generic flag
function SetStorageGeneric(pName, generic)
    local storage = FindStorageByPName(pName)
    if storage then
        storage.generic = generic
        return true
    end
    return false
end

-- Helper function to get storages by modpack ID
function GetStoragesByModpackID(aMID)
    local result = {}
    for _, storage in ipairs(_REGISTERED_STORAGES) do
        if storage.aMID == aMID then
            table.insert(result, storage)
        end
    end
    return result
end

-- Helper function to get generic storages
function GetGenericStorages()
    local result = {}
    for _, storage in ipairs(_REGISTERED_STORAGES) do
        if storage.generic then
            table.insert(result, storage)
        end
    end
    return result
end

-- Function to load backup on startup
function LoadBackupOnStartup()
    local drives = {peripheral.find("drive")}
    if #drives >= 1 then
        local backupDisk = drives[1]
        
        local success, err = pcall(function()
            local diskPath = peripheral.call(peripheral.getName(backupDisk), "getMountPath")
            if diskPath and fs.exists(diskPath .. "/storage_backup.lua") then
                local file = fs.open(diskPath .. "/storage_backup.lua", "r")
                if file then
                    local content = file.readAll()
                    file.close()
                    
                    -- Extract the return statement
                    local dataString = content:match("return (.+)")
                    if dataString then
                        local backupData = textutils.unserialise(dataString)
                        if backupData then
                            _REGISTERED_STORAGES = backupData._REGISTERED_STORAGES or {}
                            _EXCLUSION_LIST = backupData._EXCLUSION_LIST or _EXCLUSION_LIST
                            _SELECTED_OUTPUT = backupData._SELECTED_OUTPUT or _SELECTED_OUTPUT
                            _STORAGE_FILTER = backupData._STORAGE_FILTER or _STORAGE_FILTER
                            
                            print("Backup loaded successfully from: " .. (backupData.timestamp or "unknown time"))
                            return true
                        end
                    end
                end
            end
        end)
        
        if not success then
            print("Could not load backup: " .. tostring(err))
        end
    else
        print("No disk drive found for backup loading")
    end
    return false
end

-- Function to view fetch logs
function ViewFetchLogs(lines)
    lines = lines or 20 -- Default to last 20 lines
    local drives = {peripheral.find("drive")}
    if #drives >= 2 then
        local logDisk = drives[2]
        
        local success, err = pcall(function()
            local diskPath = peripheral.call(peripheral.getName(logDisk), "getMountPath")
            if diskPath and fs.exists(diskPath .. "/fetch_log.txt") then
                local file = fs.open(diskPath .. "/fetch_log.txt", "r")
                if file then
                    local content = file.readAll()
                    file.close()
                    
                    local logLines = {}
                    for line in content:gmatch("[^\r\n]+") do
                        table.insert(logLines, line)
                    end
                    
                    local startLine = math.max(1, #logLines - lines + 1)
                    print("Last " .. lines .. " fetch log entries:")
                    print("=" .. string.rep("=", 50))
                    for i = startLine, #logLines do
                        print(logLines[i])
                    end
                    print("=" .. string.rep("=", 50))
                    return true
                end
            else
                print("Fetch log file not found")
            end
        end)
        
        if not success then
            print("Could not read fetch logs: " .. tostring(err))
        end
    else
        print("Log disk not found (need at least 2 disk drives)")
    end
    return false
end

-- Function to push all items from output chest to another chest
function PushAllFromOutput(targetIdentifier, useLabel, verbose)
    if type(verbose) ~= "boolean" then
        verbose = false
    end
    
    local log = {}
    
    -- Validate that we have an output chest selected
    if not _SELECTED_OUTPUT then
        table.insert(log, "No output chest selected (_SELECTED_OUTPUT is nil)")
        if verbose then PrintLog(log) end
        return false, log
    end
    
    -- Find the target chest
    local targetChest = nil
    if useLabel then
        -- Search by label in registered storages
        local storage = FindStorageByLabel(targetIdentifier)
        if storage then
            targetChest = storage.pName
        else
            table.insert(log, "No storage found with label: " .. targetIdentifier)
            if verbose then PrintLog(log) end
            return false, log
        end
    else
        -- Use pName directly, but verify it exists
        local found = false
        for _, name in ipairs(peripheral.getNames()) do
            if name == targetIdentifier then
                found = true
                break
            end
        end
        
        if found then
            targetChest = targetIdentifier
        else
            table.insert(log, "Peripheral not found: " .. targetIdentifier)
            if verbose then PrintLog(log) end
            return false, log
        end
    end
    
    -- Verify target chest has the required methods
    local success, err = pcall(function()
        local methods = peripheral.getMethods(targetChest)
        if not CheckMethods(methods) then
            error("Target chest does not have required storage methods")
        end
    end)
    
    if not success then
        table.insert(log, "Target chest validation failed: " .. tostring(err))
        if verbose then PrintLog(log) end
        return false, log
    end
    
    -- Get all items from the output chest
    local outputItems = nil
    success, err = pcall(function()
        outputItems = peripheral.call(_SELECTED_OUTPUT, "list")
    end)
    
    if not success then
        table.insert(log, "Failed to list items in output chest: " .. tostring(err))
        if verbose then PrintLog(log) end
        return false, log
    end
    
    if not outputItems or next(outputItems) == nil then
        table.insert(log, "Output chest is empty")
        if verbose then PrintLog(log) end
        return true, log
    end
    
    -- Push all items to the target chest
    local totalItemsMoved = 0
    local totalSlotsMoved = 0
    
    for slot, item in pairs(outputItems) do
        local moved = 0
        success, err = pcall(function()
            moved = peripheral.call(_SELECTED_OUTPUT, "pushItems", targetChest, slot)
        end)
        
        if success and moved > 0 then
            totalItemsMoved = totalItemsMoved + moved
            totalSlotsMoved = totalSlotsMoved + 1
            table.insert(log, "Moved " .. moved .. " " .. item.name .. " from slot " .. slot .. " to " .. (useLabel and targetIdentifier or targetChest))
        elseif not success then
            table.insert(log, "Failed to move items from slot " .. slot .. ": " .. tostring(err))
        else
            table.insert(log, "Could not move items from slot " .. slot .. " (target may be full)")
        end
    end
    
    if totalItemsMoved > 0 then
        table.insert(log, "Successfully moved " .. totalItemsMoved .. " items from " .. totalSlotsMoved .. " slots")
        if verbose then PrintLog(log) end
        return true, log
    else
        table.insert(log, "No items were moved (target chest may be full)")
        if verbose then PrintLog(log) end
        return false, log
    end
end

-- Function to set the selected output chest
function SetSelectedOutput(identifier, useLabel)
    if useLabel then
        -- Search by label in registered storages
        local storage = FindStorageByLabel(identifier)
        if storage then
            _SELECTED_OUTPUT = storage.pName
            print("Selected output chest set to: " .. storage.pName .. " (label: " .. identifier .. ")")
            return true
        else
            print("No storage found with label: " .. identifier)
            return false
        end
    else
        -- Use pName directly, but verify it exists
        local found = false
        for _, name in ipairs(peripheral.getNames()) do
            if name == identifier then
                found = true
                break
            end
        end
        
        if found then
            -- Verify it's a valid storage
            if IsChest(identifier) then
                _SELECTED_OUTPUT = identifier
                print("Selected output chest set to: " .. identifier)
                return true
            else
                print("Peripheral is not a valid storage chest: " .. identifier)
                return false
            end
        else
            print("Peripheral not found: " .. identifier)
            return false
        end
    end
end

function PrintLog(log)
    if not log or #log == 0 then
        return
    end

    for _, entry in ipairs(log) do
        print(entry)
    end
    print("")
end

function TableHasItem(t, i)
    for j, v in ipairs(t) do
        if j == i then
            return j
        end
    end
    
    return nil
end

function TableHasAnyItem(t, ti)
    for j, v in ipairs(t) do
        for k, w in ipairs(ti) do
            if v == w then
                return {j, k}
            end
        end
    end
end

function CheckMethods(t)
    return TableHasAnyItem(_STORAGE_FILTER, t)
end

function HandleByModem() 
    local modem = peripheral.find("modem")
    if not modem then
        print("No modem found.")
        return
    end

    -- Find backup disk drives
    local backupDisk = peripheral.find("drive")
    local logDisk = nil
    
    -- Find two separate disk drives for backup and logging
    local drives = {peripheral.find("drive")}
    if #drives >= 2 then
        backupDisk = drives[1]
        logDisk = drives[2]
        print("Found backup disk: " .. peripheral.getName(backupDisk))
        print("Found log disk: " .. peripheral.getName(logDisk))
    elseif #drives == 1 then
        backupDisk = drives[1]
        print("Found only one disk drive for backup: " .. peripheral.getName(backupDisk))
        print("Warning: No separate disk drive found for logging")
    else
        print("Warning: No disk drives found for backup/logging")
    end

    -- Function to save globals to backup disk
    local function saveGlobalsBackup()
        if not backupDisk then return false end
        
        local backupData = {
            _REGISTERED_STORAGES = _REGISTERED_STORAGES,
            _EXCLUSION_LIST = _EXCLUSION_LIST,
            _SELECTED_OUTPUT = _SELECTED_OUTPUT,
            _STORAGE_FILTER = _STORAGE_FILTER,
            timestamp = os.date("%Y-%m-%d %H:%M:%S")
        }
        
        local success, err = pcall(function()
            local diskPath = peripheral.call(peripheral.getName(backupDisk), "getMountPath")
            if diskPath then
                local file = fs.open(diskPath .. "/storage_backup.lua", "w")
                if file then
                    file.write("-- Storage System Backup - " .. backupData.timestamp .. "\n")
                    file.write("return " .. textutils.serialise(backupData) .. "\n")
                    file.close()
                    return true
                end
            end
            return false
        end)
        
        if not success then
            print("Backup failed: " .. tostring(err))
            return false
        end
        return true
    end

    -- Function to log fetch actions
    local function logFetchAction(itemName, amount, storages, success)
        if not logDisk then return false end
        
        local logEntry = {
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            item = itemName,
            amount = amount,
            storages = storages,
            success = success
        }
        
        local logSuccess, err = pcall(function()
            local diskPath = peripheral.call(peripheral.getName(logDisk), "getMountPath")
            if diskPath then
                local file = fs.open(diskPath .. "/fetch_log.txt", "a")
                if file then
                    file.write(logEntry.timestamp .. " | " .. 
                              (logEntry.success and "SUCCESS" or "FAILED") .. " | " ..
                              "Item: " .. logEntry.item .. " | " ..
                              "Amount: " .. tostring(logEntry.amount) .. " | " ..
                              "Storages: " .. table.concat(logEntry.storages or {}, ", ") .. "\n")
                    file.close()
                    return true
                end
            end
            return false
        end)
        
        if not logSuccess then
            print("Logging failed: " .. tostring(err))
            return false
        end
        return true
    end

    -- Initial backup on startup
    print("Creating initial backup...")
    saveGlobalsBackup()

    modem.open(1) -- Open channel 1 for communication
    local res = { status = false, log = {} }
    local lastBackupTime = os.clock()
    local backupInterval = 300 -- Backup every 5 minutes (300 seconds)
    
    while true do
        -- Check if it's time for periodic backup
        local currentTime = os.clock()
        if currentTime - lastBackupTime >= backupInterval then
            print("Performing periodic backup...")
            saveGlobalsBackup()
            lastBackupTime = currentTime
        end
        
        local event, side, channel, replyChannel, payload, distance = os.pullEvent("modem_message")
        if (channel == 1) then
            if (payload.code == 1) then
                -- Search command
                local success, found = SearchItem(payload)
                if success and found then
                    res.status = true
                    res.log = {}
                    for storageName, items in pairs(found) do
                        for _, entry in ipairs(items) do
                            table.insert(res.log, "Found " .. entry.item.count .. " " .. entry.item.name .. " in " .. storageName .. " (slot " .. entry.slot .. ")")
                        end
                    end
                else
                    res.status = false
                    res.log = {"Item not found in any storage."}
                end
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 2) then
                -- Fetch command
                local fetchSuccess, fetchLog = FetchItemWrapper(payload)
                res.status = fetchSuccess
                res.log = fetchLog
                
                -- Log the fetch action
                local storagesUsed = {}
                if fetchLog then
                    for _, logEntry in ipairs(fetchLog) do
                        local storageName = logEntry:match("from ([^%s]+)")
                        if storageName and not table.concat(storagesUsed, ","):find(storageName) then
                            table.insert(storagesUsed, storageName)
                        end
                    end
                end
                logFetchAction(payload.name or "unknown", payload.amount or -1, storagesUsed, fetchSuccess)
                
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 3) then
                -- Update storage register
                res.status = CreateRegister()
                res.log = res.status and {"Storage register updated successfully."} or {"Failed to update storage register."}
                
                -- Backup after register update
                if res.status then
                    saveGlobalsBackup()
                end
                
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 4) then
                -- Get storages by modpack ID
                if payload.aMID then
                    local storages = GetStoragesByModpackID(payload.aMID)
                    res.status = #storages > 0
                    res.log = {}
                    if #storages > 0 then
                        for _, storage in ipairs(storages) do
                            table.insert(res.log, "Storage: " .. storage.label .. " (" .. storage.pName .. ")")
                        end
                    else
                        table.insert(res.log, "No storages found for modpack: " .. payload.aMID)
                    end
                else
                    res.status = false
                    res.log = {"Modpack ID (aMID) required for this command."}
                end
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 5) then
                -- Get generic storages
                local storages = GetGenericStorages()
                res.status = #storages > 0
                res.log = {}
                if #storages > 0 then
                    for _, storage in ipairs(storages) do
                        table.insert(res.log, "Generic Storage: " .. storage.label .. " (" .. storage.pName .. ")")
                    end
                else
                    table.insert(res.log, "No generic storages found.")
                end
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 6) then
                -- Update storage label
                if payload.pName and payload.newLabel then
                    res.status = UpdateStorageLabel(payload.pName, payload.newLabel)
                    res.log = res.status and {"Storage label updated successfully."} or {"Failed to update storage label."}
                else
                    res.status = false
                    res.log = {"pName and newLabel required for this command."}
                end
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 7) then
                -- Manual backup command
                res.status = true
                res.log = {}
                
                local backupSuccess = false
                local drives = {peripheral.find("drive")}
                if #drives >= 1 then
                    local backupDisk = drives[1]
                    local backupData = {
                        _REGISTERED_STORAGES = _REGISTERED_STORAGES,
                        _EXCLUSION_LIST = _EXCLUSION_LIST,
                        _SELECTED_OUTPUT = _SELECTED_OUTPUT,
                        _STORAGE_FILTER = _STORAGE_FILTER,
                        timestamp = os.date("%Y-%m-%d %H:%M:%S")
                    }
                    
                    local success, err = pcall(function()
                        local diskPath = peripheral.call(peripheral.getName(backupDisk), "getMountPath")
                        if diskPath then
                            local file = fs.open(diskPath .. "/storage_backup.lua", "w")
                            if file then
                                file.write("-- Storage System Backup - " .. backupData.timestamp .. "\n")
                                file.write("return " .. textutils.serialise(backupData) .. "\n")
                                file.close()
                                backupSuccess = true
                            end
                        end
                    end)
                    
                    if backupSuccess then
                        table.insert(res.log, "Manual backup completed successfully")
                    else
                        table.insert(res.log, "Manual backup failed: " .. tostring(err))
                        res.status = false
                    end
                else
                    table.insert(res.log, "No disk drive found for backup")
                    res.status = false
                end
                
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 8) then
                -- Restore from backup command
                res.status = false
                res.log = {}
                
                local drives = {peripheral.find("drive")}
                if #drives >= 1 then
                    local backupDisk = drives[1]
                    
                    local success, err = pcall(function()
                        local diskPath = peripheral.call(peripheral.getName(backupDisk), "getMountPath")
                        if diskPath and fs.exists(diskPath .. "/storage_backup.lua") then
                            local file = fs.open(diskPath .. "/storage_backup.lua", "r")
                            if file then
                                local content = file.readAll()
                                file.close()
                                
                                -- Extract the return statement
                                local dataString = content:match("return (.+)")
                                if dataString then
                                    local backupData = textutils.unserialise(dataString)
                                    if backupData then
                                        _REGISTERED_STORAGES = backupData._REGISTERED_STORAGES or {}
                                        _EXCLUSION_LIST = backupData._EXCLUSION_LIST or {}
                                        _SELECTED_OUTPUT = backupData._SELECTED_OUTPUT or "enderstorage:ender_chest_0"
                                        _STORAGE_FILTER = backupData._STORAGE_FILTER or {}
                                        
                                        res.status = true
                                        table.insert(res.log, "Restore completed successfully from backup: " .. (backupData.timestamp or "unknown time"))
                                    else
                                        table.insert(res.log, "Failed to parse backup data")
                                    end
                                else
                                    table.insert(res.log, "Invalid backup file format")
                                end
                            else
                                table.insert(res.log, "Could not read backup file")
                            end
                        else
                            table.insert(res.log, "Backup file not found")
                        end
                    end)
                    
                    if not success then
                        table.insert(res.log, "Restore failed: " .. tostring(err))
                    end
                else
                    table.insert(res.log, "No disk drive found for restore")
                end
                
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 9) then
                -- Push all from output chest command
                if payload.targetIdentifier then
                    local useLabel = payload.useLabel or false
                    local pushSuccess, pushLog = PushAllFromOutput(payload.targetIdentifier, useLabel, false)
                    res.status = pushSuccess
                    res.log = pushLog or {}
                else
                    res.status = false
                    res.log = {"targetIdentifier required for this command."}
                end
                modem.transmit(replyChannel, 1, res)
            elseif (payload.code == 10) then
                -- Set selected output chest command
                if payload.targetIdentifier then
                    local useLabel = payload.useLabel or false
                    res.status = SetSelectedOutput(payload.targetIdentifier, useLabel)
                    res.log = res.status and {"Selected output chest updated successfully."} or {"Failed to set selected output chest."}
                else
                    res.status = false
                    res.log = {"targetIdentifier required for this command."}
                end
                modem.transmit(replyChannel, 1, res)
            else
                res.status = false
                res.log = {"Unknown command code: " .. tostring(payload.code)}
                modem.transmit(replyChannel, 1, res)
            end
        end
    end
end

function Remote()
    local modem = peripheral.find("modem")
    
    if modem == nil then
        error("Modem not found")
    end
    
    modem.open(2)
    
    local p = {}
    print("Available commands:")
    print("1) Search for item")
    print("2) Fetch item") 
    print("3) Update storage register")
    print("4) Get storages by modpack ID")
    print("5) Get generic storages")
    print("6) Update storage label")
    print("7) Manual backup")
    print("8) Restore from backup")
    print("9) Push all from output chest")
    print("10) Set selected output chest")
    print("Select command (1-10): ")
    local input = read()
    
    ::Input1::
    local commandCode = tonumber(input)
    if not commandCode or commandCode < 1 or commandCode > 10 then
        print("Input must be a number between 1 and 10")
        print("Select command (1-10): ")
        input = read()
        goto Input1
    end
    
    p.code = commandCode
    
    if p.code == 1 then
        -- Search command
        print("Enter item name to search for:")
        ::Input2::
        input = read()
        if input == nil or input == "" then
            print("Please enter a valid item name:")
            goto Input2
        end
        p.name = input
        
    elseif p.code == 2 then
        -- Fetch command
        print("Enter item name to fetch:")
        ::Input3::
        input = read()
        if input == nil or input == "" then
            print("Please enter a valid item name:")
            goto Input3
        end
        p.name = input
        
        print("Enter desired amount (-1 for all):")
        local amountInput = read()
        p.amount = tonumber(amountInput) or -1
        
    elseif p.code == 3 then
        -- Update storage register - no additional input needed
        print("Updating storage register...")
        
    elseif p.code == 4 then
        -- Get storages by modpack ID
        print("Enter modpack ID:")
        ::Input4::
        input = read()
        if input == nil or input == "" then
            print("Please enter a valid modpack ID:")
            goto Input4
        end
        p.aMID = input
        
    elseif p.code == 5 then
        -- Get generic storages - no additional input needed
        print("Getting generic storages...")
        
    elseif p.code == 6 then
        -- Update storage label
        print("Enter peripheral name (pName):")
        ::Input5::
        input = read()
        if input == nil or input == "" then
            print("Please enter a valid peripheral name:")
            goto Input5
        end
        p.pName = input
        
        print("Enter new label:")
        ::Input6::
        input = read()
        if input == nil or input == "" then
            print("Please enter a valid label:")
            goto Input6
        end
        p.newLabel = input
    elseif p.code == 7 then
        -- Manual backup - no additional input needed
        print("Creating manual backup...")
        
    elseif p.code == 8 then
        -- Restore from backup - no additional input needed
        print("Restoring from backup...")
        
    elseif p.code == 9 then
        -- Push all from output chest
        print("Push items by (1) Peripheral Name or (2) Label?")
        ::InputPushType::
        local pushTypeInput = read()
        local pushType = tonumber(pushTypeInput)
        
        if pushType == 1 then
            p.useLabel = false
            print("Enter target peripheral name (pName):")
        elseif pushType == 2 then
            p.useLabel = true
            print("Enter target storage label:")
        else
            print("Please enter 1 for Peripheral Name or 2 for Label:")
            goto InputPushType
        end
        
        ::InputTarget::
        input = read()
        if input == nil or input == "" then
            print("Please enter a valid target identifier:")
            goto InputTarget
        end
        p.targetIdentifier = input
        
    elseif p.code == 10 then
        -- Set selected output chest
        print("Set output by (1) Peripheral Name or (2) Label?")
        ::InputOutputType::
        local outputTypeInput = read()
        local outputType = tonumber(outputTypeInput)
        
        if outputType == 1 then
            p.useLabel = false
            print("Enter output peripheral name (pName):")
        elseif outputType == 2 then
            p.useLabel = true
            print("Enter output storage label:")
        else
            print("Please enter 1 for Peripheral Name or 2 for Label:")
            goto InputOutputType
        end
        
        ::InputOutputTarget::
        input = read()
        if input == nil or input == "" then
            print("Please enter a valid identifier:")
            goto InputOutputTarget
        end
        p.targetIdentifier = input
    end
        
    modem.transmit(1, 2, p)

    local event, side, channel, replyChannel, payload, distance = nil, nil, nil, nil, nil, nil
    repeat
        event, side, channel, replyChannel, payload, distance = os.pullEvent("modem_message")
    until channel == 2
    
    if payload and payload.log then
        print("Response:")
        print("Status: " .. (payload.status and "SUCCESS" or "FAILED"))
        PrintLog(payload.log)
    else
        print("No response received or invalid response format.")
    end
end

function FetchItemWrapper(payload, verbose)
    return FetchItem(payload, payload.amount, verbose)
end
