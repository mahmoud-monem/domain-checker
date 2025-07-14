FROM openresty/openresty:alpine

# Install required packages
RUN apk add --no-cache curl

# Manually install lua-resty-http and all its dependencies
RUN mkdir -p /usr/local/openresty/lualib/resty && \
    curl -fSL https://raw.githubusercontent.com/ledgetech/lua-resty-http/master/lib/resty/http.lua \
         -o /usr/local/openresty/lualib/resty/http.lua && \
    curl -fSL https://raw.githubusercontent.com/ledgetech/lua-resty-http/master/lib/resty/http_headers.lua \
         -o /usr/local/openresty/lualib/resty/http_headers.lua && \
    curl -fSL https://raw.githubusercontent.com/ledgetech/lua-resty-http/master/lib/resty/http_connect.lua \
         -o /usr/local/openresty/lualib/resty/http_connect.lua

# Copy custom entrypoint
COPY nginx/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"] 