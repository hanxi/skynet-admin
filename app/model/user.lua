local log = require "log"
local db = require "app.db"
local utils = require "app.utils"
local skynet = require "skynet"
local config = require "config"

local M = {}

local app_password_salt = config.get("app_password_salt")
local app_default_avatar = config.get("app_default_avatar")

function M.check_user_password(username, password)
    local dbtbl_user = db.get_dbtbl_user()
    local data = dbtbl_user:findOne({username = username}, { _id = 0, password = 1, salt = 1 })
    log.debug("check_user_password. username:", username, ", password:", password, ", data:", data)
    if data then
        local encode_password = utils.sha1_encode({username, password, data.salt, app_password_salt})
        if encode_password == data.password then
            return true
        end
        log.debug("check_user_password failed. username:", username, ", password:", password, ", encode_password:", encode_password)
        return false
    else
        -- 是否user表空的？
        local ret = dbtbl_user:find({}, { _id = 0 })
        if ret:hasNext() then
            return false
        end

        local app_admin_username = config.get("app_admin_username")
        local app_admin_password = config.get("app_admin_password")
        -- 新增默认用户
        if M.add_user(app_admin_username, app_admin_password) then
            return M.check_user_password(username, password)
        end
    end
    return false
end

function M.add_user(username, password, name, avatar)
    name = name or username
    avatar = avatar or app_default_avatar
    local dbtbl_user = db.get_dbtbl_user()
    local salt = tostring(skynet.time())
    local encode_password = utils.sha1_encode({username, password, salt, app_password_salt})
    local now = utils.now()
    local ok, err, ret = dbtbl_user:safe_insert({
        username = username,
        password = encode_password,
        salt = salt,
        name = name,
        avatar = avatar,
        createtime = now,
    })
    if ok and ret and ret.n == 1 then
        return true
    end

    log.error("add user failed. username:", username, ", password:", password, ", err:", err)
    return false
end

function M.del_user(username)
    local dbtbl_user = db.get_dbtbl_user()
    local ok, err, ret = dbtbl_user:safe_delete({username = username}, true)
    if (ok and ret and ret.n == 1) then
        return true
    end
    log.error("del user failed. username:", username, ", err:", err)
    return false
end

function M.set_password(username, password)
    local dbtbl_user = db.get_dbtbl_user()
    local salt = tostring(skynet.time())
    local encode_password = utils.sha1_encode({username, password, salt, app_password_salt})
    local data = {
        ["$set"] = {
            password = encode_password,
            salt = salt,
        },
    }
    local ok, err, ret = dbtbl_user:safe_update({username = username}, data, true, false)
    if (ok and ret and ret.n == 1) then
        return true
    end
    log.error("update password failed. username:", username, ", password:", password, ", err:", err)
    return false
end

function M.get_info(username)
    local dbtbl_user = db.get_dbtbl_user()
    local data = dbtbl_user:findOne({username = username}, { _id = 0, name = 1, avatar = 1 })
    log.debug("get_info. username:", username, ", data:", data)
    return data
end

function M.get_users()
    local dbtbl_user = db.get_dbtbl_user()
    local ret = dbtbl_user:find({}, { _id = 0, name = 1, username = 1, avatar = 1, createtime = 1 })
    local users = {}
    local i = 0
    while ret:hasNext() do
        local data = ret:next()
        i = i + 1
        users[i] = data
    end
    return users
end

return M
