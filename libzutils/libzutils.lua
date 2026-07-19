local LibDeflate = require("LibDeflate")

local p = {}

function p.loadz(chunk, name, mode, env)
    return load(LibDeflate:DecompressDeflate(chunk), name, mode, env)
end

function p.loadfilez(path, mode, env)
    local file = io.open(path, "r")
    local data = file:read("*a")
    if not data then error("failed to read " .. path) end
    local func = p.loadz(data, "@"..path, mode, env)
    file:close()
    return func
end

function p.dofilez(path)
    return p.loadfilez(path, "bt", _ENV)()
end

function p.serializez(t)
    return LibDeflate:CompressDeflate(textutils.serialize(t))
end

p.serialisez = p.serializez

function p.unserializez(s)
    return textutils.unserialize(LibDeflate:DecompressDeflate(s))
end

p.unserialisez = p.unserializez

return p
