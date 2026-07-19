local expect = require("cc.expect")
local LibDeflate = require("LibDeflate")

local p = {}

function p.loadz(chunk, name, mode, env)
    expect(1, chunk, "string")
    return load(LibDeflate:DecompressDeflate(chunk), name, mode, env)
end

function p.loadfilez(path, mode, env)
    expect(1, path, "string")
    local file = io.open(path, "r")
    local data = file:read("*a")
    if not data then error("failed to read " .. path) end
    local func = p.loadz(data, "@"..path, mode, env)
    file:close()
    return func
end

function p.dofilez(path)
    expect(1, path, "string")
    return p.loadfilez(path, "bt", _ENV)()
end

function p.serializez(t)
    expect(1, t, "table")
    return LibDeflate:CompressDeflate(textutils.serialize(t))
end

p.serialisez = p.serializez

function p.unserializez(s)
    expect(1, s, "string")
    return textutils.unserialize(LibDeflate:DecompressDeflate(s))
end

p.unserialisez = p.unserializez

return p
