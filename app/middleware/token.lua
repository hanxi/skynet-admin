local config = require "config"
local ck = require "wlua.cookie"
local log = require "log"
local crypt = require "skynet.crypt"
local util_json = require "util.json"

local function decode_data(text, des_key, padding)
    if not text or text == "" then return {} end
	text = crypt.base64decode(text)
	local decrypt_str = crypt.desdecode(des_key, text, crypt.padding[padding or "iso7816_4"])
    local decode_obj = util_json.decode(decrypt_str)
    return decode_obj or {}
end

local function encode_data(obj, des_key, padding)
    local default = "{}"
    local text = util_json.encode(obj) or default
    local c = crypt.desencode(des_key, text, crypt.padding[padding or "iso7816_4"])
	return crypt.base64encode(c)
end

local function parse_token(field, des_key)
    if not field then return end
    return decode_data(field, des_key)
end

local function token_middleware()
    -- TODO: support store in db
    local token_config = config.get("app_token_config")
    local refresh_cookie = token_config.refresh_cookie
    local timeout = token_config.timeout or 3600
    local token_key = token_config.token_key or "_app_token_"
    local token_des_key = token_config.token_des_key or "12345678"

    return function(c)
        local cookie, err1 = ck:new(c)
        if not cookie then
            log.error("cookie is nil:", err1)
        end

        local current_token
        local token_data, err2 = cookie:get(token_key)
        if err2 then
            log.warn("cannot get token_data:", err2)
        else
            if token_data then
                current_token = parse_token(token_data, token_des_key)
            end
        end
        current_token = current_token or {}

        log.info("token.init. token_key:", token_key)

        c.token = {
            set = function (...)
                local p = ...
                if type(p) == "table" then
                    for i, v in pairs(p) do
                        current_token[i] = v
                    end
                else
                    local params = { ... }
                    if type(params[2]) == "table" then -- set("k", {1, 2, 3})
                        current_token[params[1]] = params[2]
                    else -- set("k", "123")
                        current_token[params[1]] = params[2] or ""
                    end
                end

                local value = encode_data(current_token, token_des_key)
                local max_age = timeout
                local ok, err = cookie:set({
                    key = token_key,
                    value = value or "",
                    max_age = max_age,
                    path = "/"
                })

                log.info("token.set: ", value)

                if err or not ok then
                    return log.error("token.set error:", err)
                end
            end,

            refresh = function()
                if token_data and token_data ~= "" then
                    local max_age = timeout
                    local ok, err = cookie:set({
                        key = token_key,
                        value = token_data or "",
                        max_age = max_age,
                        path = "/"
                    })
                    if err or not ok then
                        return log.error("token.refresh error:", err)
                    end
                end
            end,

            get = function(key)
                return current_token[key]
            end,

            destroy = function()
                local expires = "Thu, 01 Jan 1970 00:00:01 GMT"
                local max_age = 0
                local ok, err = cookie:set({
                    key = token_key,
                    value = "",
                    expires = expires,
                    max_age = max_age,
                    path = "/"
                })
                if err or not ok then
                    log.error("token.destroy error:", err)
                    return false
                end

                return true
            end
        }

        if refresh_cookie then
            local e, ok
            ok = xpcall(function()
                c.token.refresh()
            end, function()
                e = debug.traceback()
            end)

            if not ok then
                log.error("refresh cookie error:", e)
            end
        end

        c:next()
    end
end

return token_middleware
