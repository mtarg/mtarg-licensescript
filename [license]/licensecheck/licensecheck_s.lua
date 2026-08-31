--[[
    MTARG License Check - Server
    - Validates the server's license key (from mtaserver.conf <license>) against
      the MTARG Cloudflare Worker endpoint (set in <license_endpoint>).
    - Sends a heartbeat every 60 seconds so the server appears ONLINE in the
      client's server browser (the browser only lists licensed + online servers).
    - Enforces the license on players: every joining player must present a valid
      MTARG license key or they are kicked.

    No database credentials are stored in any resource file or the game server.
]]

local config = {
    license_endpoint = getServerConfigSetting("license_endpoint") or "https://key.mtarg.xyz"
}

-- Whether to kick players without a valid license. Default 0: the license is
-- owned by the SERVER (mtaserver.conf <license>), not by each player, so we do
-- not require players to hold a key. Set to 1 only if you want per-player keys.
local enforce = tonumber(getServerConfigSetting("license_enforce") or 0) == 1

-- Read the server's license from mtaserver.conf. We use
-- getServerConfigSetting("license") rather than fileOpen() with a ../../..
-- path: MTA's resource file sandbox blocks reads outside the resource
-- folder, so the old fileOpen("../../../mtaserver.conf") always returned
-- nothing (and the server was never listed) even though the key was present.
local function getServerLicense()
    local lic = getServerConfigSetting("license")
    if not lic or type(lic) ~= "string" then return "" end
    return lic:gsub("%s", "")
end

local serverLicense = getServerLicense()
-- License validity state: nil = not yet checked, true = valid, false = invalid.
-- An invalid/fake license must not let the server accept players or stay
-- listed in the browser, so everything is gated on this flag.
local serverLicenseValid = nil

-- ------------------------------------------------------------
-- Heartbeat: keep the server marked ONLINE in the client browser
-- and report the current player count so the browser list can
-- display it per server. Also reports the server's own IP:port so
-- players do not need to type the IP when registering a license.
-- The client browser only lists servers that sent a heartbeat in
-- the last 3 minutes, so an offline server disappears automatically.
-- ------------------------------------------------------------
local function sendHeartbeat()
    if serverLicense == "" then return end
    if serverLicenseValid ~= true then return end  -- only heartbeats when confirmed valid
    local playerCount = #getElementsByType("player")
    local maxPlayers = tonumber(getServerConfigSetting("maxplayers")) or 32
    local serverPort = getServerPort() or 22003
    -- Send the server port so the Cloudflare Worker can combine it with the
    -- connecting IP (CF-Connecting-IP header) to auto-fill server_ip in the
    -- browser list, without requiring the owner to type the IP manually.
    fetchRemote(config.license_endpoint .. "?action=heartbeat&key=" .. serverLicense .. "&players=" .. playerCount .. "&maxplayers=" .. maxPlayers .. "&serverport=" .. serverPort, function(response, errno)
        -- Log once per heartbeat so the server operator can verify the API
        -- round-trip is working (the browser list depends on this PATCH).
        if errno ~= 0 then
            outputServerLog("[MTARG] Heartbeat error " .. tostring(errno))
        elseif not response or response == "" then
            outputServerLog("[MTARG] Heartbeat empty response - server may not be listed.")
        end
    end, "")
end

if serverLicense == "" then
    serverLicenseValid = false
    outputServerLog("[MTARG] No <license> key found in mtaserver.conf - server will NOT be listed.")
else
    outputServerLog("[MTARG] Server license: " .. serverLicense)
    -- Validate via the Cloudflare Worker endpoint
    fetchRemote(config.license_endpoint .. "?key=" .. serverLicense, function(response, errno)
        if errno == 0 and response then
            local ok, data = pcall(function() return fromJSON(response) end)
            if ok and data and data.valid then
                serverLicenseValid = true
                outputServerLog("[MTARG] License VALID - server is listed.")
                -- First heartbeat goes out immediately (the startup sendHeartbeat
                -- below is skipped because validation had not finished yet), so
                -- the browser sees the server ONLINE right away instead of
                -- waiting up to 60s for the timer.
                sendHeartbeat()
            else
                serverLicenseValid = false
                outputServerLog("[MTARG] License INVALID or inactive - server is NOT listed.")
            end
        else
            -- License server unreachable: keep the last known state (nil = not
            -- confirmed). Do not kick players on network failure, but also do
            -- not claim the server is listed until the license is confirmed.
            outputServerLog("[MTARG] License server unreachable.")
        end
    end, "")
end

function getLicense()
    return serverLicense
end

-- Start the recurring heartbeat timer. The first heartbeat fires inside the
-- validation callback above (once the license is confirmed VALID), so the
-- server appears ONLINE immediately; this timer keeps it online afterwards.
setTimer(sendHeartbeat, 60000, 0) -- every 60s

-- ------------------------------------------------------------
-- Player license enforcement:
-- When a player joins, ask them for their license key. The client
-- resource reads the local license.key file and replies. Players
-- without a valid key are kicked.
-- ------------------------------------------------------------
addEvent("mtarg:sendLicense", true)
addEventHandler("mtarg:sendLicense", root, function(key)
    if not enforce then return end
    local player = source
    if getElementType(player) ~= "player" then return end

    key = tostring(key or ""):gsub("%s", "")
    if key == "" then
        kickPlayer(player, "MTARG", "No MTARG license key found. Get one at mtarg.xyz")
        return
    end

    fetchRemote(config.license_endpoint .. "?key=" .. key, function(response, errno)
        if not isElement(player) then return end
        if errno ~= 0 or not response then
            outputServerLog("[MTARG] License check failed for " .. getPlayerName(player))
            return -- license server unreachable: allow (do not kick on network failure)
        end
        local ok, data = pcall(function() return fromJSON(response) end)
        if ok and data and data.valid then
            setElementData(player, "mtarg:licensed", true, true)
            outputServerLog("[MTARG] License OK: " .. getPlayerName(player))
        else
            kickPlayer(player, "MTARG", "Invalid or inactive MTARG license key. Get one at mtarg.xyz")
        end
    end, "")
end)

addEventHandler("onPlayerJoin", root, function()
    if not enforce then return end
    local player = source
    -- Give the client a moment to load the resource, then request its key
    setTimer(function()
        if not isElement(player) then return end
        triggerClientEvent(player, "mtarg:requestLicense", root)
    end, 3000, 1)
    -- If the player never replies, kick after a grace period
    setTimer(function()
        if not isElement(player) then return end
        if not getElementData(player, "mtarg:licensed") then
            kickPlayer(player, "MTARG", "MTARG license verification timed out. Get one at mtarg.xyz")
        end
    end, 15000, 1)
end)
