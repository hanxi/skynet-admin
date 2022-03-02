local skynet = require "skynet"
local log = require "log"
local db = require "app.db"
local utils = require "app.utils"

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

return M
