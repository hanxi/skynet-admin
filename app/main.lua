local wlua = require "wlua"
local config = require "config"
local log = require "log"
local token_middleware = require "app.middleware.token"
local check_login_middleware = require "app.middleware.check_login"
local router = require "app.router"

local app = wlua:default()
app:use(token_middleware())

-- filter: add response header
app:use(function(c)
    c:set_res_header('X-Powered-By', 'wlua framework')
    c:set_res_header('Access-Control-Allow-Origin', '*')
    c:set_res_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    c:set_res_header('Access-Control-Allow-Headers', 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization')
    c:next()
end)

-- intercepter: login or not
local whitelist = config.get_tbl("app_whitelist")
app:use(check_login_middleware(whitelist))

router(app) -- business routers and routes

app:static_file("/", "index.html")
app:static_dir("/", "./")

app:run()

