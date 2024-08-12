local util_table = require "util.table"
local log = require "log"
local rax = require "rax"

local function is_login(c)
    if c.token then
        local accesstoken = c.req.headers["x-token"]
        if not accesstoken then
            accesstoken = c.req.query["token"]
        end
        local username = c.token.get(accesstoken)
        if username and username ~= "" then
            c.token.set('username', username)
            return true
        end
    end
    return false
end

local function check_login(whitelist)
    local match_router = rax:new()
    for _, path in pairs(whitelist) do
        match_router:insert("GET", path, true)
        log.debug("check_login, path:", path)
    end
    match_router:compile()
    --match_router:dump()

    return function(c)
        local request_path = c.req.path
        local in_white_list = match_router:match(request_path, "GET")

        log.debug("check_login:", request_path, in_white_list)

        if in_white_list then
            c:next()
        else
            if is_login(c) then
                c:next()
            else
                c:send_json({
                    code = "UN_LOGIN",
                    msg = "未登录",
                })
            end
        end
    end
end

return check_login
