#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Script này cần chạy với quyền root"
  exit 1
fi

# Kiểm tra đầu vào
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Cách dùng: $0 <domain> <tên_file_template.conf>"
  echo "Ví dụ: ./script.sh cucre.net wordpress.conf"
  exit 1
fi

DOMAIN="$1"
TEMPLATE_NAME="$2"
TEMPLATE_DIR="/etc/nginx/rewrite_templates"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"
REWRITE_FILE="$TEMPLATE_DIR/$DOMAIN.conf"
SELECTED_TEMPLATE="$TEMPLATE_DIR/$TEMPLATE_NAME"
BACKUP_FILE="$NGINX_CONF.bak"

# Cài Nginx nếu chưa có
if ! command -v nginx &> /dev/null; then
  echo "Đang cài Nginx..."
  apt update && apt install -y nginx
fi

# Tạo thư mục web
WEB_ROOT="/var/www/$DOMAIN"
mkdir -p "$WEB_ROOT"
chown -R www-data:www-data "$WEB_ROOT"

# Kiểm tra template có tồn tại không
if [ ! -f "$SELECTED_TEMPLATE" ]; then
  echo "Template không tồn tại: $SELECTED_TEMPLATE"
  exit 1
fi

# Copy template thành file rewrite riêng cho domain
cp "$SELECTED_TEMPLATE" "$REWRITE_FILE"
echo "Tạo rewrite riêng: $REWRITE_FILE"

# Tạo file nginx config nếu chưa có
if [ ! -f "$NGINX_CONF" ]; then
  echo "Tạo file cấu hình mới: $NGINX_CONF"
  cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $WEB_ROOT;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    #REWRITE-START
    include $REWRITE_FILE;
    #REWRITE-END

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    error_log /var/log/nginx/${DOMAIN}-error.log;
    access_log /var/log/nginx/${DOMAIN}-access.log;

    location ~ /\.ht {
        deny all;
    }
}
EOF

else
  echo "File config đã tồn tại, backup và cập nhật include..."

  cp "$NGINX_CONF" "$BACKUP_FILE"

  # Nếu chưa có đoạn REWRITE-START thì thêm vào trước dấu }
  if ! grep -q "#REWRITE-START" "$NGINX_CONF"; then
    awk -v line="    #REWRITE-START\n    include $REWRITE_FILE;\n    #REWRITE-END" '
      $0 ~ /^\}/ && !done { print line; done=1 }
      { print }
    ' "$NGINX_CONF" > "${NGINX_CONF}.tmp" && mv "${NGINX_CONF}.tmp" "$NGINX_CONF"
  else
    echo "Đã có #REWRITE-START, sẽ cập nhật file rewrite tương ứng."
  fi
fi

# Tạo symlink nếu chưa có
[ -L "$NGINX_LINK" ] || ln -s "$NGINX_CONF" "$NGINX_LINK"

# Kiểm tra và reload Nginx
if nginx -t; then
  echo "Cấu hình hợp lệ. Đang reload..."
  systemctl reload nginx
  echo "Rewrite đã được áp dụng theo chuẩn aaPanel."
else
  echo "Lỗi Nginx! Khôi phục lại file cũ."
  cp "$BACKUP_FILE" "$NGINX_CONF"
  nginx -t && systemctl reload nginx
fi
