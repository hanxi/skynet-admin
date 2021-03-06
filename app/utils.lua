local skynet = require "skynet"
local crypt = require "skynet.crypt"

local sformat = string.format
local tconcat = table.concat

local M = {}

function M.gen_accesstoken(username)
    local now = skynet.time()
    local rnd = math.random(1, 1000)
    local sign = crypt.sha1(now .. username .. rnd)
    local str = sformat("%s,%s,%s", now, username, sign)
    return crypt.base64encode(str)
end

function M.sha1_encode(arr)
    local str = tconcat(arr, "")
    return crypt.base64encode(str)
end

function M.des_decode(text, des_key, padding)
    if not text or text == "" then return end
	text = crypt.base64decode(text)
	return crypt.desdecode(des_key, text, crypt.padding[padding or "iso7816_4"])
end

function M.des_encode(b64text, des_key, padding)
    b64text = b64text or ""
    local c = crypt.desencode(des_key, b64text, crypt.padding[padding or "iso7816_4"])
	return crypt.base64encode(c)
end

function M.now()
    return math.floor(skynet.time())
end

function M.keys(tbl)
    local arr = {}
    local i = 0
    for k,_ in pairs(tbl) do
        i = i + 1
        arr[i] = k
    end
    return arr
end

function M.values(tbl)
    local arr = {}
    local i = 0
    for _,v in pairs(tbl) do
        i = i + 1
        arr[i] = v
    end
    return arr
end

return M
