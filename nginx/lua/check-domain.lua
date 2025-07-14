local http = require "resty.http"
local cjson = require "cjson.safe"

-- Configuration from environment variables (read directly)
local cache_ttl = tonumber(os.getenv("CACHE_TTL")) or 300  -- 5 minutes default
local request_timeout = tonumber(os.getenv("REQUEST_TIMEOUT")) or 3000  -- 3 seconds default

-- Get URLs from environment variables with debug logging
local backend_url = os.getenv("BACKEND_API_URL")
local fe_private_url_base = os.getenv("FRONTEND_PRIVATE_URL")

-- Debug logging
ngx.log(ngx.INFO, "Environment variables - BACKEND_API_URL: ", backend_url or "nil")
ngx.log(ngx.INFO, "Environment variables - FRONTEND_PRIVATE_URL: ", fe_private_url_base or "nil")

-- Set defaults if environment variables are not available
backend_url = backend_url or "http://localhost:3020/api/public/funnels/check-domain"
fe_private_url_base = fe_private_url_base or "http://localhost:3010/api/private/funnels/"

-- Get request details
local host = ngx.var.host
local cache_key = "domain:" .. host

ngx.log(ngx.INFO, "Domain check for: ", host, " using backend: ", backend_url)

-- Rate limiting
local rate_limit = ngx.shared.rate_limit
local key = ngx.var.binary_remote_addr
local limit, err = rate_limit:incr(key, 1, 0, 60)  -- 60 second window
if not limit then
    rate_limit:set(key, 1, 60)
elseif limit > 60 then  -- Max 60 requests per minute per IP
    ngx.log(ngx.WARN, "Rate limit exceeded for IP: ", ngx.var.remote_addr)
    return ngx.exit(429)
end

-- Check cache first
local domain_cache = ngx.shared.domain_cache
local cached_result = domain_cache:get(cache_key)

if cached_result then
    ngx.log(ngx.INFO, "Cache hit for domain: ", host)
    
    -- Parse cached result
    local cached_data = cjson.decode(cached_result)
    
    if cached_data and cached_data.exists then
        -- Set the dynamic proxy target for proxy_pass
        ngx.var.dynamic_proxy_target = cached_data.private_url
        ngx.log(ngx.INFO, "Domain found in cache: ", host, " -> ", cached_data.private_url)
        return
    else
        ngx.log(ngx.INFO, "Domain not found in cache: ", host)
        return ngx.exit(403)
    end
end

-- Cache miss - make API request
ngx.log(ngx.INFO, "Cache miss for domain: ", host, " - making API request to: ", backend_url)

local httpc = http.new()
httpc:set_timeout(request_timeout)

local res, err = httpc:request_uri(backend_url, {
    method = "GET",
    query = {
        domainName = host
    },
    headers = {
        ["User-Agent"] = "DomainChecker/1.0",
        ["Accept"] = "application/json",
    },
    ssl_verify = false -- Set to true in production with proper certs
})

-- Handle connection errors
if not res then
    ngx.log(ngx.ERR, "Failed to connect to backend API: ", err, " for domain: ", host, " URL: ", backend_url)
    -- Cache negative result for a shorter time to avoid repeated failures
    domain_cache:set(cache_key, cjson.encode({exists = false}), 60)
    return ngx.exit(503)  -- Service unavailable
end

ngx.log(ngx.INFO, "Backend API response: ", res.status, " Body: ", res.body or "empty")

-- Handle HTTP errors
if res.status ~= 200 then
    ngx.log(ngx.ERR, "Backend API returned non-200 status: ", res.status, " for domain: ", host, " Response body: ", res.body or "empty")
    
    -- Cache negative result for shorter time on server errors
    if res.status >= 500 then
        domain_cache:set(cache_key, cjson.encode({exists = false}), 60)
        return ngx.exit(503)
    else
        -- For client errors (4xx), cache longer
        domain_cache:set(cache_key, cjson.encode({exists = false}), cache_ttl)
        return ngx.exit(403)
    end
end

ngx.log(ngx.INFO, "Backend API response: ", res.status, " Body: ", res.body or "empty")

-- Parse response
local body = cjson.decode(res.body)

if not body then
    ngx.log(ngx.ERR, "Failed to parse JSON response from backend for domain: ", host)
    domain_cache:set(cache_key, cjson.encode({exists = false}), 60)
    return ngx.exit(503)
end

-- Handle the actual API response format: {statusCode: 200, data: {websiteId: X, name: "domain"}}
local domain_exists = false
local private_url = nil

if body.statusCode == 200 and body.data and body.data.websiteId then
    domain_exists = true
    -- Construct the private URL using the websiteId
    private_url = fe_private_url_base .. body.data.websiteId
    ngx.log(ngx.INFO, "Domain found: ", host, " -> websiteId: ", body.data.websiteId, " -> ", private_url)
elseif body.statusCode == 404 or (body.statusCode == 200 and not body.data) then
    domain_exists = false
    ngx.log(ngx.INFO, "Domain not found: ", host, " (statusCode: ", body.statusCode, ")")
else
    ngx.log(ngx.WARN, "Unexpected API response for domain: ", host, " statusCode: ", body.statusCode)
    domain_exists = false
end

-- Cache the result
local cache_data = {
    exists = domain_exists,
    private_url = private_url,
    timestamp = ngx.now()
}

local cache_success, cache_err = domain_cache:set(cache_key, cjson.encode(cache_data), cache_ttl)
if not cache_success then
    ngx.log(ngx.WARN, "Failed to cache domain result: ", cache_err)
end

-- Handle domain validation result
if domain_exists and private_url then
    -- Set the dynamic proxy target for proxy_pass
    ngx.var.dynamic_proxy_target = private_url
    ngx.log(ngx.INFO, "Domain validated: ", host, " -> ", private_url)
else
    ngx.log(ngx.INFO, "Domain not found or invalid: ", host)
    return ngx.exit(403)
end