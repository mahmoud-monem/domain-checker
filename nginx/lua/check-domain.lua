local http = require "resty.http"

local host = ngx.var.host
local backend_url = ngx.var.backend_api_url

local httpc = http.new()
httpc:set_timeout(3000) -- 3 seconds timeout

local res, err = httpc:request_uri(backend_url, {
    method = "GET",
    query = {
        domain = host
    },
    ssl_verify = false -- Set to true in production with proper certs
})

if not res then
    ngx.log(ngx.ERR, "Failed to request: ", err)
    return ngx.exit(403)
end

if res.status ~= 200 then
    ngx.log(ngx.ERR, "Non-200 response from backend: ", res.status)
    return ngx.exit(403)
end

local cjson = require "cjson.safe"
local body = cjson.decode(res.body)

if not body or not body.exists then
    ngx.log(ngx.ERR, "Domain not found: ", host)
    return ngx.exit(403)
end

-- Set the private URL for proxy_pass
ngx.var.fe_private_url = body.private_url