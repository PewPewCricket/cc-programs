local expect = require("cc.expect")
local base64 = require("cc.base64")
local crypto = peripheral.find("cryptographic_accelerator")
if not crypto then
    error("libcert requires a cyptographic accelerator to run.")
end

settings.define("libcert.certdir", {
    description = "Directory containing certificates.",
    default = "/.cert",
    type = "string"
})

local certdir = settings.get("libcert.certdir")
local trustedFileName = "trusted"
--                   HDR VER ISR SUB KEY FRM TO  FLG
local certPartFmt = "c6  H   s2  s2  s2  d   d   B   "
--                   HDR VER ISR SUB KEY FRM TO  FLG SIG
local certFullFmt = "c6  H   s2  s2  s2  d   d   B   c64"

local certMagic = "cc.504"
local p = {}
p._VERSION = 1

p.create = function(issuer, subject, pubKey, from, to, isSigner)
    expect(1, issuer, "string")
    expect(2, subject, "string")
    expect(3, pubKey, "string")
    expect(4, from, "number")
    expect(5, to, "number")
    expect(6, isSigner, "boolean")

    -- Flag Byte: 0, 0, 0, 0, 0, 0, 0, isSigner
    local flagByte = 0
    flagByte = bit32.bor(flagByte, bit32.lshift(isSigner and 1 or 0, 0))
    if not from then from = 0 end
    if not to then to = 0 end

    local certPart = string.pack(certPartFmt, certMagic, p._VERSION, issuer, subject, pubKey, from, to, flagByte)
    return certPart
end

p.sign = function(certPart, key)
    expect(1, certPart, "string")
    expect(2, key, "string")

    local sig = crypto.sign(certPart, key)
    local cert = certPart .. string.pack("c64", sig)

    return cert
end

p.unpack = function(cert)
    expect(1, cert, "string")

    -- Flag Byte: 0, 0, 0, 0, 0, 0, 0, isSigner
    local ok, magic, version, issuer, subject, key, from, to, flags, sig = pcall(string.unpack, certFullFmt, cert)
    if not ok or magic ~= certMagic or version ~= p._VERSION or to < from or from < 0 or to < 0 then
        return nil
    end

    local isSigner = bit32.band(flags, bit32.rshift(1, 0)) ~= 0

    return issuer, subject, key, from, to, sig, isSigner
end

p.save = function(cert, overwrite)
    expect(1, cert, "string")

    local ok, subject = p.unpack(cert)
    if overwrite == nil then overwrite = false end

    if not ok then
        error("malformed certificate")
    end

    local certpath = ("%s/%s.cert"):format(certdir, base64.encode(subject, "-_"))
    if not overwrite then
        if fs.exists(certpath) then
            error(certpath.." already exists.")
        end
    end

    local file = io.open(certpath, "w")
    file:write(cert)
    file:close()
end

p.load = function(subject)
    expect(1, subject, "string")

    local certpath = ("%s/%s.cert"):format(certdir, base64.encode(subject, "-_"))
    if not fs.exists(certpath) then
        return nil
    end

    local file = io.open(certpath, "r")
    local cert = file:read("*a")
    file:close()

    local ok = p.unpack(cert)
    if not ok then
        error("malformed certificate")
    end

    return cert
end

p.setTrust = function(cert, bool)
    expect(1, cert, "string")
    expect(2, bool, "boolean")

    local trustedList = {}
    local trustedPath = ("%s/%s"):format(certdir, trustedFileName)

    local trustedFile = io.open(trustedPath, "r")
    if trustedFile then
        trustedList = textutils.unserialize(trustedFile:read("*a"))
        trustedFile:close()
    end

    trustedList[crypto.sha256(cert)] = bool

    trustedFile = io.open(trustedPath, "w")
    trustedFile:write(textutils.serialize(trustedList))
    trustedFile:close()
end

p.verify = function(cert, depth)
    expect(1, cert, "string")

    depth = (depth or 0) + 1
    if depth > 32 then
        error("certificate chains may not exceed 32 signers.")
    end

    local issuer, subject, _, from, to, sig = p.unpack(cert)
    if not issuer then
        return false
    end

    local trustedFile = io.open(("%s/%s"):format(certdir, trustedFileName), "r")
    if trustedFile then
        local trustedList = textutils.unserialize(trustedFile:read("*a"))
        trustedFile:close()

        if trustedList[crypto.sha256(cert)] == true then
            return true
        end
    end

    if subject == issuer then
        return false
    end

    local icert = p.load(issuer)
    if not p.verify(icert, depth) then
        return false
    end

    local _, _, ikey, _, _, _, isParentSigner = p.unpack(icert)
    if not isParentSigner then
        return false
    end

    local curtime = os.epoch("utc")
    if not (from == 0 and to == 0) then
        if curtime > to or curtime < from or to < from then
            return false
        end
    end

    local certPayload = cert:sub(1, -65)

    if crypto.verify(certPayload, sig, ikey) then
        return true
    else
        return false
    end
end

p.hasIssuer = function(cert)
    expect(1, cert, "string")

    local issuer = p.unpack(cert)
    if not issuer then
        return nil
    end

    if not p.load(issuer) then
        return false, issuer
    else
        return true
    end
end

p.getKey = function(cert)
    expect(1, cert, "string")

    local _, _, key= p.unpack(cert)
    return key
end

return p
