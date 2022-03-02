return function(router)

local model_user = require "app.model.user"
local utils = require "app.utils"
local ipairs = ipairs

router:get("/info", function(c)
    local username = c.token.get('username')
    local info = model_user.get_info(username)
    c:send_json({
        code = "OK",
        msg = "",
        data = info,
    })
end)

router:post("/login", function(c)
    local username = c.req.body.username
    local password = c.req.body.password

    local ret = model_user.check_user_password(username, password)
    if ret then
        local accesstoken = utils.gen_accesstoken(username)
        c.token.set(accesstoken, username)
        c:send_json({
            code = "OK",
            msg = "登录成功",
            data = {
                token = accesstoken,
            }
        })
        return
    end

    c:send_json({
        code = "LOGIN_FAILED",
        msg = "Wrong username or password! Please check.",
    })
end)

router:post("/logout", function(c)
    c.token.destroy()
    c:send_json({
        code = "OK",
        msg = "登出成功",
    })
end)

router:post("/setpassword", function(c)
    local username = c.token.get('username')
    local password = c.req.body.password
    local ret = model_user.set_password(username, password)
    if ret then
        c:send_json({
            code = "OK",
            msg = "密码修改成功",
        })
        return
    end
    c:send_json({
        code = "DB_FAILED",
        msg = "密码修改失败",
    })
end)

router:post("/add", function(c)
    local username = c.req.body.username
    local password = c.req.body.password
    local name = c.req.body.name
    local avatar = c.req.body.avatar

    local ret = model_user.add_user(username, password, name, avatar)
    if ret then
            c:send_json({
            code = "OK",
            msg = "用户添加成功",
        })
        return
    end
    c:send_json({
        code = "DB_FAILED",
        msg = "用户添加失败",
    })
end)

router:post("/del", function(c)
    local username = c.req.body.username

    local ret = model_user.del_user(username)
    if ret then
            c:send_json({
            code = "OK",
            msg = "用户删除成功",
        })
        return
    end
    c:send_json({
        code = "DB_FAILED",
        msg = "用户删除失败",
    })
end)

router:get("/list", function(c)
    local users = model_user.get_users()
    c:send_json({
        code = "OK",
        data = {
            users = users,
        },
    })
end)

end

