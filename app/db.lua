local mongo = require "skynet.db.mongo"
local config = require "config"

local M = {}
local db
local dbtbl_cluster
local dbtbl_user

function M.get_dbtbl(tblname)
    if not db then
        local app_mongodb_conf = config.get_tbl("app_mongodb_conf")
        local db_conn = mongo.client(app_mongodb_conf)
        local app_mongodb_dbname = config.get("app_mongodb_dbname")
        db = db_conn[app_mongodb_dbname]
    end
    return db[tblname]
end

function M.get_dbtbl_cluster()
    if not dbtbl_cluster then
        dbtbl_cluster = M.get_dbtbl("cluster")
        dbtbl_cluster:createIndex({{name = 1}, unique = true})
    end
    return dbtbl_cluster
end

function M.get_dbtbl_user()
    if not dbtbl_user then
        dbtbl_user = M.get_dbtbl("username")
        dbtbl_user:createIndex({{username = 1}, unique = true})
    end
    return dbtbl_user
end

return M
