_DEBUG = false
 
function try(f, catch_f)
    local status, exception = pcall(f)
    if not status then
        catch_f(exception)
    end
end
 
function isChest(peripheralName)
 
    local wrap = peripheral.wrap(peripheralName)
    local result = false
    try(function()
        wrap.list()
        result = true
    end,
    function(e)
        print(e .. " | not a chest")
--        sleep(2)
        result = false
    end)
    return result
end 
 
function fetch(itemName, _debug)
    if _debug == "true" then
        _DEBUG = true
    end
    local nameList = peripheral.getNames()
    local locationList = {}
    
    for i, name in ipairs(nameList) do
        print("Searching " .. name)
        local inv = peripheral.wrap(name)
        local itemList
        
        if isChest(name) then
            itemList = inv.list()            
            --print(itemList)
            --sleep(.5)
            for k, item in pairs(itemList) do
                local itemDesc = inv.getItemMeta(k)
                if itemDesc == null then
                    if _DEBUG then
                        print("Slot n° " .. k .. " was empty")
                    end
                else
                    local temp = itemDesc.displayName
                    if(_DEBUG) then
                        print("DisplayName: ".. temp)
                        io.read()
                    end
                    if string.find(temp, itemName) then
                        local found = {
                            count = item.count,
                            invName = name,
                            position = k
                        }    
                        table.insert(locationList,found)
                        print(found)
                    end
                end
            end
        end
        
    end
    
    return locationList
    
end