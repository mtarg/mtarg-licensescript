--[[
    MTARG License Check - Client
    Reads the local license.key file and sends it to the server when asked.
]]

-- When the server requests the license key, read it and reply
addEvent("mtarg:requestLicense", true)
addEventHandler("mtarg:requestLicense", root, function()
    -- The license key file is copied by the client core into this resource's
    -- files folder (mods/deathmatch/resources/licensecheck/files/license.key)
    local key = ""
    local f = fileOpen("license.key")
    if f then
        local size = fileGetSize(f)
        if size > 0 then
            key = fileRead(f, math.min(size, 64))
        end
        fileClose(f)
    end
    key = key:gsub("%s", "")
    triggerServerEvent("mtarg:sendLicense", localPlayer, key)
end)
