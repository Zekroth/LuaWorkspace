_DEBUG = false

---@diagnostic disable-next-line: lowercase-global

function try(f, catch_f)
    local status, exception = pcall(f)
    if not status then
        catch_f(exception)
    end
end

function IsChest(peripheralName)

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

function Fetch(itemName, _debug)
    if _debug == "true" then
        _DEBUG = true
    end
    local nameList = peripheral.getNames()
    local locationList = {}
    
    for i, name in ipairs(nameList) do
        print("Searching " .. name)
        local inv = peripheral.wrap(name)
        local itemList
        
        if IsChest(name) then
            itemList = inv.list()            
            --print(itemList)
            --sleep(.5)
            for k, item in pairs(itemList) do
                local itemDesc = inv.getItemMeta(k)
                if itemDesc == nil then
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

function GetFromFetch( itemName, destination , quantity)
    
    local fetched = Fetch(itemName, false)
    local to_wrap = peripheral.wrap(destination);

    if IsChest(destination) == true then
        for i, item in ipairs(fetched) do
            local moved = 0
            if  destination ~= item.invName then
                print("source" .. item.invName)
                local iterations = 0
                local remaining = 0
                if quantity > 64 then
                    iterations = math.floor(quantity / 64)
                    remaining = math.fmod(quantity, 64)
                else
                    remaining = quantity
                end
                while (peripheral.wrap(item.invName).getItemMeta(item.position) ~= nil) or ((remaining == 0) and (iterations == 0)) do
                    
                    local changed = to_wrap.pullItems(item.invName, item.position)
                    if changed == 0 or changed == nil then
                        print("Destination is full")
                        break
                    end
                    remaining = remaining - changed
                    moved = moved + changed
                end
            end
        end
    else
        error(destination .. " is not an available inventory.")
    end
end