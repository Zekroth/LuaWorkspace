config = {
    invDefs = {
        ["junk"] = "back",
        ["ores"] = "front",
        ["dusts"] = "right",
        extra = "left",
        from = "bottom",
        rOut = "top"
    },
    itemRoutes = {
        ["junk"] = {
            "Sapling",
            "Leaves",
            "Cobblestone",
            "Diorite",
            "Granite",
            "Dirt",
            "Seed",
            "Flower",
            "Shimmerleaf",
            "Lotus"
        },
        ["ores"] = {
            "Ore"
        },
        ["extra"] = {
        },
        ["dusts"] = {
            "Dust",
            "Crystal",
            "Diamond",
            "Emerald",
            "Gem",
            "Sapphire",
            "Ruby",
            "Ender Amethyst",
            "Amber",
            "Topaz",
            "Malachite",
            "Raw Firestone",
            "Clay",
            "Cinnabar",
            "Peridot",
            "Destabilized",
            "Ingot",
            "Nugget",
            "Resonating Ore",
            "Pulverized",
            "Grit",
            "Redstone",
            "Electrotine",
            "Powder",
            "Coal",
            "Lapis"
        }
    }
}
function moveItems( configTable, extraToJunk ) 
    local from_wrap = peripheral.wrap(configTable.invDefs.from)
    redstone.setOutput(configTable.invDefs.rOut, true)
    local item_list = from_wrap.list()
    
    for pos, item in pairs(item_list) do 
        local route
        for routeKey, routes in pairs(configTable.itemRoutes) do
            for i,routeVal in ipairs(configTable.itemRoutes[routeKey]) do
                if string.find(from_wrap.getItemMeta(pos).displayName, routeVal) then
                    route = routeKey
                    break
                end
            end
        end

        if (route == nil) and ((extraToJunk == "true") or (extraToJunk == true)) then
            route = "extra"
        end

--        ::moveItem::
        print(route)
        local to_wrap = peripheral.wrap(configTable.invDefs[route])
        to_wrap.pullItems(configTable.invDefs.from, pos)
    end
    
    return "done"
end