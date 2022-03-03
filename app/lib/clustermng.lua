local skynet = require "skynet"
local service = require "skynet.service"

local function clustermng_service()
    local skynet = require "skynet"
    local cluster = require "skynet.cluster"
    local clusterservice = require "app.lib.clusterservice"
    local config = require "config"
    local log = require "log"

    local clustermng = {}
    local nodes = {}
    local is_init = false

    local function debugagent_service()
        local skynet = require "skynet"
        local log = require "log"

        local debugagent = {}

        local TIMEOUT = 300 -- 3 sec

        local function timeout(ti)
            if ti then
                ti = tonumber(ti)
                if ti <= 0 then
                    ti = nil
                end
            else
                ti = TIMEOUT
            end
            return ti
        end

        function debugagent.EXIT()
            skynet.exit()
        end

        function debugagent.stat(ti)
            log.debug("in stat")
            local ret = skynet.call(".launcher", "lua", "STAT", timeout(ti))
            log.debug("out stat. ret:", ret)
            return ret
        end

        function debugagent.mem(ti)
            return skynet.call(".launcher", "lua", "MEM", timeout(ti))
        end

        function debugagent.list()
            return skynet.call(".launcher", "lua", "LIST")
        end

        skynet.dispatch("lua", function(_, source, cmd, ...)
            local f = debugagent[cmd]
            if f then
                skynet.ret(skynet.pack(f(...)))
            else
                log.error(string.format("Unknown cmd:%s, source:%s", cmd, source))
            end
        end)
    end

    -- 给节点远程开启 debugagent 服务
    local function load_debugagent(t, key)
        if key == "address" then
            local ok, r = pcall(clusterservice.new, t.nodename, "debugagent", debugagent_service)
            if ok then
                t.address = r
                return t.address
            else
                log.error("load_debugagent failed. err:", r)
            end
        else
            return nil
        end
    end

    local mt = {
        __index = load_debugagent,
    }
    function clustermng.reload(cluster_config)
        cluster.reload(cluster_config)

        for nodename,_ in pairs(cluster_config) do
            if nodename:sub(1,2) ~= "__" then
                local node = {
                    nodename = nodename,
                }

                if nodes[nodename] then
                    clusterservice.close(nodename, "debugagent")
                end
                nodes[nodename] = setmetatable(node , mt)
            end
        end
        log.info("clustermng reload ok.")
    end

    function clustermng.init(cluster_config)
        if is_init then
            return
        end
        is_init = true
        clustermng.reload(cluster_config)
        log.info("clustermng init ok.")
    end

    function clustermng.status(nodenames)
        local rets = {}
        for _, nodename in pairs(nodenames) do
            --rets[nodename] = {
            --    st = 0, -- 未连接，连接成功，连接失败
            --    stat = {
            --        [addr] = xxx,
            --    }
            --}
        end
        return rets
    end

    local function cluster_safe_call(nodename, address, ...)
        local rettbl = table.pack(xpcall(cluster.call, debug.traceback, nodename, address, ...))
        if rettbl[1] then
            return table.unpack(rettbl, 2, rettbl.n)
        end
        log.error("error in cluster_safe_call. err:", rettbl[2])
    end

    local COMMAND = {}
    function clustermng.run(nodename, command, ...)
        local node = nodes[nodename]
        if not node then
            return
        end
        return cluster_safe_call(nodename, node.address, command, ...)
    end

    skynet.dispatch("lua", function(_, source, cmd, ...)
        local f = clustermng[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            log.error(string.format("Unknown cmd:%s, source:%s", cmd, source))
        end
    end)

    local app_cluster_port = config.get_tbl("app_cluster_port")
    cluster.open(app_cluster_port)

    -- TODO: 5 分钟心跳
end

local function load_service(t, key)
    if key == "address" then
        t.address = service.new("clustermng", clustermng_service)
        return t.address
    else
        return nil
    end
end

local clustermng = setmetatable ({} , {
    __index = load_service,
})

function clustermng.status(nodenames)
    return skynet.call(clustermng.address, "lua", "status", nodenames)
end

function clustermng.run(nodename, command, ...)
    return skynet.call(clustermng.address, "lua", "run", nodename, command, ...)
end

function clustermng.reload(cluster_config)
    skynet.call(clustermng.address, "lua", "reload", cluster_config)
end

function clustermng.init(cluster_config)
    skynet.call(clustermng.address, "lua", "init", cluster_config)
end

return clustermng
