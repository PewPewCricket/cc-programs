local expect = require("cc.expect")
local base64 = require("cc.base64")

-- Globals
local dbg_log = function() return end
--local dbg_log = print
local trustedFileName = "trusted"

-- Settings
settings.define("libcert.certdir", {
    description = "Directory containing certificates.",
    default = "/.cert",
    type = "string"
})

local certdir = settings.get("libcert.certdir")

-- Check for peripherals
local crypto = peripheral.find("cryptographic_accelerator")
if not crypto then
    error("libcert requires a cyptographic accelerator to run.")
end

-- Library state
local p = {}
p._VERSION = 1

-- Library functions
p.create = function(issuer, subject, pubKey, 
    isSigner, from, to)
    
    expect(1, issuer, "string")
    expect(2, subject, "string")
    expect(3, pubKey, "string")
    expect(4, isSigner, "boolean")
    
    local cert = {}
    local data = {
        version = p._VERSION, -- version number
        issuer = issuer,      -- issuer subj. id
        subject = subject,    -- subject
        key = pubKey,         -- pub. key of subj.
        isSigner = isSigner,  -- can sign certs?
        from = from,          -- from date in utc
        to = to               -- to date in utc
    }
    
    cert.data = textutils.serialize(data)
    return cert
end

p.sign = function(cert, key)
    expect(1, cert, "table")
    expect(2, key, "string")

    cert.sig = crypto.sign(cert.data, key)
end

p.verifyStructure = function(cert)
    expect(1, cert, "table")

    if cert.data == nil or cert.sig == nil then
        return false
    end
    
    local certData = textutils.unserialize(cert.data)
    if certData == nil then
        return false
    end
    
    if certData.version == nil or certData.issuer == nil
        or certData.subject == nil or certData.key == nil
        or certData.isSigner == nil or certData.from == nil
        or certData.to == nil then
        return false
    end
    
    return true
end

p.save = function(cert, overwrite)
    expect(1, cert, "table")
    
    if not p.verifyStructure(cert) then
        error("malformed certificate.")
    end
    
    local certData = textutils.unserialize(cert.data)

    if overwrite == nil then overwrite = false end
    local certpath = ("%s/%s.cert"):format(
        certdir, base64.encode(certData.subject, "-_"))
    if not overwrite then
        if fs.exists(certpath) then
            error(certpath.." already exists.")
        end
    end
    
    local file = io.open(certpath, "w")
    file:write(textutils.serialize(cert))
    file:close()
end

p.load = function(subject)
    expect(1, subject, "string")

    local certpath = ("%s/%s.cert"):format(
        certdir, base64.encode(subject, "-_"))
    if not fs.exists(certpath) then
        return nil
    end
    
    local file = io.open(certpath, "r")
    local cert = textutils.unserialize(
        file:read("*a"))
    
    if not p.verifyStructure(cert) then
        error("malformed certificate")
    end
    
    return cert
end

p.setTrust = function(cert, bool)
    expect(1, cert, "table")
    expect(2, bool, "boolean")
    
    local trustedFile = io.open(("%s/%s"):format(
        certdir, trustedFileName), "r")
    local trustedList = {}
    if trustedFile then
        trustedList = textutils.unserialize(
            trustedFile:read("*a"))
        trustedFile:close()
    end
    
    trustedList[crypto.sha256(cert.data)] = bool
    
    trustedFile = io.open(("%s/%s"):format(
        certdir, trustedFileName), "w")
    trustedFile:write(textutils.serialize(trustedList))
    trustedFile:close()
end

p.verify = function(cert, depth)
    expect(1, cert, "table")
    depth = depth or 0
    if depth > 25 then
        error("certificate chains may not exceed 25 signers.")
    end
    
    if not p.verifyStructure(cert) then
        return false
    end
    
    local certData = textutils.unserialize(cert.data)
    local trustedFile = io.open(("%s/%s"):format(
        certdir, trustedFileName), "r")
        
    if trustedFile then
        local trustedList = textutils.unserialize(
            trustedFile:read("*a"))
        trustedFile:close()

        if trustedList[crypto.sha256(cert.data)] == true then
            dbg_log(certData.subject..": trusted")
            return true
        end
    end
    
    local issuer = certData.issuer
    if certData.subject == issuer then
        dbg_log(certData.subject..": self signed")
        return false
    end
    
    local issuerCert = p.load(issuer)
    if not p.verify(issuerCert, depth) then
        dbg_log(certData.subject..": bad issuer")
        return false
    end
    
    local issuerCertData =
        textutils.unserialize(issuerCert.data)
    if not issuerCertData.isSigner then
        dbg_log(certData.subject..": issuer no sign")
        return false
    end
    
    local curtime = os.epoch("utc")
    if not (certData.from == 0 and certData.to == 0) then
        if curtime > certData.to or curtime < certData.from
            or certData.to < certData.from then
            dbg_log(certData.subject..": bad date")
            return false
        end
    end
    
    if crypto.verify(cert.data, cert.sig, 
        issuerCertData.key) then
        dbg_log(certData.subject..": issuer ok")
        return true
    else
        dbg_log(certData.subject..": bad signature")
        return false
    end
end

p.hasIssuer = function(cert)
    local certData = textutils.unserialize(cert.data)
    if not p.load(certData.issuer) then
        return false, certData.issuer
    else
        return true
    end
end

return p
