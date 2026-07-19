local expect = require("cc.expect")

local lib = {}

lib.addToTable = function(device, name, t)
    expect(1, device, "string")
    expect(2, name, "string")
    if t == nil then t = {} end
    
    local uIdx = device:match(".*()_")
    local id = tonumber(device:sub(uIdx+1))
    device = device:sub(1, uIdx-1)
    
    t[name] = {name = device, id = id}
    return t
end

lib.addToString = function(device, name, s)
    expect(1, device, "string")
    expect(2, name, "string")
    if s == nil then s = "{}" end
    
    local t = textutils.unserialize(s)
    t = lib.addToTable(device, name, t)
    return textutils.serialize(t)
end

lib.addToFile = function(device, name, path)
    expect(1, device, "string")
    expect(2, name, "string")
    expect(3, path, "string")
    
    local file = io.open(path, "r")
    local s = lib.addToString(device, name, file:read("*a"))
    file:close()
    
    file = io.open(path, "w")
    file:write(s)
    file:close()
end

lib.wrapTable = function(t)
    expect(1, t, "table")

    local p = {}
    for k, v in pairs(t) do
        local name = ("%s_%d"):format(v.name, v.id)
        p[k] = peripheral.wrap(name)
    end
    
    return p
end

lib.wrapString = function(s)
    expect(1, s, "string")
    return lib.wrapTable(textutils.unserialize(s))
end

lib.wrapFile = function(path)
    expect(1, path, "string")
    
    local file = io.open(path, "r")
    local p = lib.wrapString(file:read("*a"))
    file:close()
    return p
end

return lib
