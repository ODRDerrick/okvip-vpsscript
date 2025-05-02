#!/bin/bash

# Kiểm tra quyền root
if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root."
  exit 1
fi

# Kiểm tra đầu vào
if [[ $# -lt 1 ]]; then
    echo "Cách dùng: $0 domain1 [domain2 ...]"
    echo "Ví dụ: $0 example.com abc.xyz"
    exit 1
fi

# Gốc thư mục chứa site WordPress
BASE_PATH="/var/www"

# Kiểm tra từng domain được truyền vào
for DOMAIN in "$@"; do
    SITE="$BASE_PATH/$DOMAIN"

    if [[ ! -f "$SITE/wp-config.php" ]]; then
        echo "Không tìm thấy wp-config.php tại $SITE — bỏ qua $DOMAIN"
        continue
    fi

    echo "============================================="
    echo "Kiểm tra site: $DOMAIN (tại $SITE)"
    echo ""

    echo "Kiểm tra quyền file (file != 644):"
    find "$SITE" -type f ! -perm 644 -exec ls -l {} \; 2>/dev/null | head -n 10

    echo ""
    echo "Kiểm tra quyền thư mục (folder != 755):"
    find "$SITE" -type d ! -perm 755 -exec ls -ld {} \; 2>/dev/null | head -n 10

    echo ""
    echo "Kiểm tra SSL:"
    NGINX_CONF=$(grep -rl "$DOMAIN" /etc/nginx/sites-enabled 2>/dev/null | head -n 1)
    if [[ -n "$NGINX_CONF" && $(grep -c "443" "$NGINX_CONF") -gt 0 ]]; then
        echo "✔ Có SSL trong file cấu hình: $NGINX_CONF"
    else
        echo "✘ Không thấy SSL trong cấu hình Nginx"
    fi

    echo ""
    echo "Kiểm tra headers bảo mật trong Nginx:"
    if [[ -n "$NGINX_CONF" ]] && grep -Eq "X-Frame-Options|X-XSS-Protection|Strict-Transport-Security" "$NGINX_CONF"; then
        echo "Header bảo mật đã được thêm"
    else
        echo "Header bảo mật chưa có trong $NGINX_CONF"
    fi

    echo ""
done
