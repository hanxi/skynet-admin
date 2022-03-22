local skynet = require "skynet"
local log = require "log"
local db = require "app.db"
local utils = require "app.utils"
local clustermng = require "app.lib.clustermng"

local M = {}

function M.get_nodes()
    local dbtbl_cluster = db.get_dbtbl_cluster()
    local ret = dbtbl_cluster:find({}, { _id = 0 })
    local nodes = {}
    local i = 0
    while ret:hasNext() do
        local data = ret:next()
        i = i + 1
        nodes[i] = data
    end
    return nodes
end

function M.get_nodes_status()
    local nodes = M.get_nodes()
    local node2status = clustermng.status()
    for _, node in pairs(nodes) do
        local nodename = node.name
        local status = node2status[nodename]
        if status then
            node.st = status.st
            node.sttime = status.sttime
        end
    end
    return nodes
end

function M.add_node(name, addr)
    local dbtbl_cluster = db.get_dbtbl_cluster()
    local now = utils.now()
    local ok, err, ret = dbtbl_cluster:safe_insert({
        name = name,
        addr = addr,
        createtime = now,
        updatetime = now,
    })
    if ok and ret and ret.n == 1 then
        return "OK", "add node success"
    end

    log.error("add node failed. name:", name, ", addr:", addr, ", err:", err)
    return "DB_ERROR", "db operate failed"
end

function M.update_node(name, addr)
    local now = utils.now()
    local data = {
        ["$set"] = {
            addr = addr,
            updatetime = now,
        },
    }
    local dbtbl_cluster = db.get_dbtbl_cluster()
    local ok, err, ret = dbtbl_cluster:safe_update({name = name}, data, true, false)
    if (ok and ret and ret.n == 1) then
        return "OK", "update node sucess"
    end
    log.error("update node failed. name:", name, ", addr:", addr, ", err:", err)
    return "DB_ERROR", "db operate failed"
end

function M.del_node(name)
    local dbtbl_cluster = db.get_dbtbl_cluster()
    local ok, err, ret = dbtbl_cluster:safe_delete({name = name}, true)
    if (ok and ret and ret.n == 1) then
        return "OK", "del node sucess"
    end
    log.error("del node failed. name:", name, ", err:", err)
    return "DB_ERROR", "db operate failed"
end

function M.get_node_detail(name)
    local data = clustermng.run(name, "list")
    log.debug("get_node_detail. name:", name, ",data:", data)
    if data then
        return "OK", data
    end
    return "CLUSTER_ERROR", "cluster call failed"
end

function M.get_cluster_config()
    local cluster_config = {
        __nowaiting = true,
    }
    local nodes = M.get_nodes()
    for _, node in pairs(nodes) do
        local name = node.name
        local addr = node.addr
        cluster_config[name] = addr
    end
    return cluster_config
end

function M.reload()
    local cluster_config = M.get_cluster_config()
    clustermng.reload(cluster_config)
    return "OK", "reload nodes sucess"
end

skynet.init(function()
    local cluster_config = M.get_cluster_config()
    clustermng.init(cluster_config)
end)

-- TODO: 解决 clustermng 的热更问题？

return M
