local skynet = require "skynet"
local service = require "skynet.service"

local function clustermng_service()
    local skynet = require "skynet"
    local cluster = require "skynet.cluster"
    local clusterservice = require "app.lib.clusterservice"
    local config = require "config"
    local log = require "log"
    local utils = require "app.utils"

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

        -- call from service.close
        function debugagent.EXIT()
            skynet.exit()
        end

        function debugagent.ping()
            return "pong"
        end

        function debugagent.detail(ti)
            local rets = {}
            local stat = skynet.call(".launcher", "lua", "STAT", timeout(ti))
            for addr, info in pairs(stat) do
                info.addr = addr
                rets[addr] = info
            end
            local mem = skynet.call(".launcher", "lua", "MEM", timeout(ti))
            for addr, info in pairs(mem) do
                if not stat[addr] then
                    stat[addr] = {
                        addr = addr
                    }
                end
                stat[addr].mem = info:gsub("%(.*%)", "")
                stat[addr].service = info:gsub(".*%((.*)%)", "%1")
            end
            return rets
        end

        function debugagent.inject(code, ...)
            local address = skynet.self()
            local ok, output = skynet.call(address, "debug", "RUN", code, nil, ...)
            if ok == false then
                error(output)
            end
            return output
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


    local debugagent_name = config.get("app_debugagent_name", "debugagent")
    -- 给节点远程开启 debugagent 服务
    local function load_debugagent(t, key)
        if key == "address" then
            local ok, r = pcall(clusterservice.new, t.nodename, debugagent_name, debugagent_service)
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

        -- 清理旧节点
        for nodename,_ in pairs(nodes) do
            clusterservice.close(nodename, debugagent_name)
            nodes[nodename] = nil
            log.info("reload close old node. nodename:", nodename)
        end

        -- 创建新节点
        for nodename,_ in pairs(cluster_config) do
            if nodename:sub(1,2) ~= "__" then
                local node = {
                    nodename = nodename,
                    st = "UNCONNECT", -- 未连接
                }
                nodes[nodename] = setmetatable(node , mt)
                log.info("reload open new node. nodename:", nodename)
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
        clustermng.heartbeat()
        log.info("clustermng init ok.")
    end

    function clustermng.status(nodenames)
        if not nodenames then
            nodenames = utils.keys(nodes)
        end
        local rets = {}
        for _, nodename in pairs(nodenames) do
            if nodes[nodename] then
                rets[nodename] = {
                    st = nodes[nodename].st,
                    sttime = nodes[nodename].sttime,
                }
            else
                rets[nodename] = {
                    st = "UNKNOW", -- 未配置
                }
            end
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

    local app_cluster_port = config.get("app_cluster_port")
    cluster.open(app_cluster_port)

    -- 5 分钟心跳
    local HEARTBEAT_TIME = 1*60*100 -- 5 min
    function clustermng.heartbeat()
        local function ping()
            local reqs = skynet.request()

            for nodename, node in pairs(nodes) do
                reqs:add { node.address, "lua", "ping", nodename = nodename }
            end

            for req, resp in reqs:select(20) do
                local nodename = req.nodename
                log.info("nodename:", nodename, ", RESP:", resp[1])
                if nodes[nodename] then
                    nodes[nodename].st = "CONNECTED" -- 已连接
                    nodes[nodename].sttime = utils.now()
                else
                    log.warn("uknow node in heartbeat. nodename:", nodename)
                end
            end
            log.info("ping ok")
            skynet.timeout(HEARTBEAT_TIME, ping)
        end
        ping()
    end
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

-- 查看节点详情
function clustermng.status(nodenames)
    return skynet.call(clustermng.address, "lua", "status", nodenames)
end

-- 对节点执行指令
function clustermng.run(nodename, command, ...)
    return skynet.call(clustermng.address, "lua", "run", nodename, command, ...)
end

-- 对节点注入代码
function clustermng.inject(nodename, code, ...)
    return skynet.call(clustermng.address, "lua", "run", nodename, "inject", code, ...)
end

-- 重新加载节点配置
function clustermng.reload(cluster_config)
    skynet.call(clustermng.address, "lua", "reload", cluster_config)
end

-- 节点初始化
function clustermng.init(cluster_config)
    skynet.call(clustermng.address, "lua", "init", cluster_config)
end

return clustermng
