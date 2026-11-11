# 共享的 location 配置
# 此文件被 HTTP 和 HTTPS server 块共同使用
#
# 使用 Docker 内置 DNS + 变量 proxy_pass：上游在请求时解析。
# 可选扩展（cms/department/…）未启动时 nginx 仍可起来，访问对应路径会 502。
resolver 127.0.0.11 valid=10s ipv6=off;

# 默认页面配置 - 根路径重定向到/main/home
location = / {
    return 302 /main/home;
}

# API代理（原 proxy_pass …/ 会剥掉 /api 前缀；变量形式用 rewrite 等价处理）
location /api/ {
    set $upstream_gateway g2rain-gateway:8080;
    rewrite ^/api/(.*)$ /$1 break;
    proxy_pass http://$upstream_gateway;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_connect_timeout 30s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;

    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
}

# IAM代理
location /auth/ {
    set $upstream_iam g2rain-iam:8080;
    proxy_pass http://$upstream_iam;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_connect_timeout 30s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;

    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;

    if ($request_method = 'OPTIONS') {
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
        add_header Access-Control-Allow-Headers 'Content-Type, Authorization, X-Requested-With';
        add_header Access-Control-Max-Age 1728000;
        return 204;
    }

    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
    add_header Access-Control-Allow-Headers 'Content-Type, Authorization, X-Requested-With';
}

# 匹配/auth路径下的多种静态资源文件
location ~ ^/auth/.*\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    set $upstream_iam g2rain-iam:8080;
    rewrite ^/auth/(.*) /$1 break;
    proxy_pass http://$upstream_iam;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_connect_timeout 30s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;

    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
}

# 健康检查
location /health {
    access_log off;
    return 200 "healthy\n";
    add_header Content-Type text/plain;
}

location /main/ {
    set $upstream_main g2rain-main-shell:8080;
    proxy_pass http://$upstream_main;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /admin/ {
    set $upstream_admin g2rain-admin-shell:8080;
    proxy_pass http://$upstream_admin;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /chat/ {
    set $upstream_chat g2rain-chat-shell:8080;
    proxy_pass http://$upstream_chat;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /manager/ {
    set $upstream_manager g2rain-manager-app:8080;
    proxy_pass http://$upstream_manager;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /cms/ {
    set $upstream_cms g2rain-cms-app:8080;
    proxy_pass http://$upstream_cms;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /infra/ {
    set $upstream_infra g2rain-infra-app:8080;
    proxy_pass http://$upstream_infra;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /department/ {
    set $upstream_department g2rain-department-app:8080;
    proxy_pass http://$upstream_department;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /member/ {
    set $upstream_member g2rain-member-app:8080;
    proxy_pass http://$upstream_member;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /agent/ {
    set $upstream_agent g2rain-agent-app:8080;
    proxy_pass http://$upstream_agent;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}

location /knowledge/ {
    set $upstream_knowledge g2rain-knowledge-app:8080;
    proxy_pass http://$upstream_knowledge;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
}
