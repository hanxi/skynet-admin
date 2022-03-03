local skynet = require "skynet"
local cluster = require "skynet.cluster"

local service = {}
local caches = {}
local providers = {}

local function uniqueservice(nodename, ...)
    return cluster.call(nodename, ".service", "LAUNCH",  ...)
end

local function get_provider(nodename)
    local provider = providers[nodename]
    if not provider then
        provider = uniqueservice(nodename, "service_provider")
        providers[nodename] = provider
    end
    return provider
end

local function check(func)
    local info = debug.getinfo(func, "u")
    assert(info.nups == 1)
    assert(debug.getupvalue(func,1) == "_ENV")
end

function service.new(nodename, name, mainfunc, ...)
    local p = get_provider(nodename)
    local addr, booting = cluster.call(nodename, p, "test", name)
    local address
    if addr then
        address = addr
    else
        if booting then
            address = cluster.call(nodename, p, "query", name)
        else
            check(mainfunc)
            local code = string.dump(mainfunc)
            address = cluster.call(nodename, p, "launch", name, code, ...)
        end
    end
    if not caches[nodename] then
        caches[nodename] = {}
    end
    caches[nodename][name] = address
    return address
end

function service.close(nodename, name)
    local addr = cluster.call(nodename, get_provider(nodename), "close", name)
    if addr then
        if caches[nodename] then
            caches[nodename][name] = nil
        end
        if not next(caches[nodename]) then
            caches[nodename] = nil
        end
        cluster.send(nodename, addr, "EXIT")
        return true
    end
    return false
end

function service.query(nodename, name)
    if (not caches[nodename]) or (not caches[nodename][name]) then
        local address = cluster.call(nodename, get_provider(nodename), "query", name)
        if not caches[nodename] then
            caches[nodename] = {}
        end
        caches[nodename][name] = address
    end
    return caches[nodename][name]
end

return service
