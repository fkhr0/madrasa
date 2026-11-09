# Who really asked (the app's limits and logs use it), and keep-alive to the API.
proxy_http_version 1.1;
proxy_set_header Connection "";
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_connect_timeout 5s;
proxy_read_timeout 60s;
# A copy that fails mid-request: try the other one (safe requests only).
proxy_next_upstream error timeout http_502 http_503;
