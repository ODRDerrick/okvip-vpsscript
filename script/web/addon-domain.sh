#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Vui lòng chạy script với quyền root."
  exit 1
fi

# Kiểm tra OS có phải là Ubuntu hay không
if ! command -v lsb_release &>/dev/null || [[ $(lsb_release -si) != "Ubuntu" ]]; then
  echo "Error: Script này chỉ hỗ trợ Ubuntu."
  exit 1
fi

# Kiểm tra tham số đầu vào
if [ $# -lt 2 ]; then
  echo "Error: Vui lòng cung cấp domain chính và ít nhất một alias domain."
  echo "Usage: $0 <primary_domain> <alias_domain1> [alias_domain2 ... alias_domainN]"
  exit 1
fi

PRIMARY_DOMAIN=$1
shift # Loại bỏ tham số đầu tiên để xử lý các alias domain còn lại
ALIAS_DOMAINS=($@)

# Đường dẫn cấu hình Nginx
NGINX_CONF_FILE="/etc/nginx/sites-available/$PRIMARY_DOMAIN"

# Kiểm tra website chính đã tồn tại hay chưa
if [ ! -f "$NGINX_CONF_FILE" ]; then
  echo "Error: Không tìm thấy cấu hình cho website chính $PRIMARY_DOMAIN."
  exit 1
fi

# Regex để validate domain
DOMAIN_REGEX='^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

# Lấy danh sách alias domain hiện tại trong cấu hình Nginx
EXISTING_ALIASES=$(grep -oP '(?<=server_name\s).*;' "$NGINX_CONF_FILE" | tr -d ';')

# Kiểm tra và thêm từng alias domain
for ALIAS_DOMAIN in "${ALIAS_DOMAINS[@]}"; do
  # Validate alias domain (đảm bảo domain hợp lệ)
  if [[ ! $ALIAS_DOMAIN =~ $DOMAIN_REGEX ]]; then
    echo
    continue
  fi

  # Kiểm tra alias domain có liên quan đến domain chính hay không
  if [[ $ALIAS_DOMAIN != "www.$PRIMARY_DOMAIN" && $ALIAS_DOMAIN != *".$PRIMARY_DOMAIN" ]]; then
    echo
    continue
  fi

  # Kiểm tra alias domain đã tồn tại hay chưa
  if [[ "$EXISTING_ALIASES" =~ (^|[[:space:]])$ALIAS_DOMAIN($|[[:space:]]) ]]; then
    echo "Alias domain '$ALIAS_DOMAIN' đã tồn tại trong cấu hình Nginx của $PRIMARY_DOMAIN."
  else
    # Thêm alias domain vào cấu hình
    sed -i "/server_name/s/$/ $ALIAS_DOMAIN;/" "$NGINX_CONF_FILE"
    echo "Alias domain '$ALIAS_DOMAIN' đã được thêm vào cấu hình Nginx của $PRIMARY_DOMAIN."
  fi
done

# Kiểm tra cấu hình Nginx
if nginx -t; then
  echo "Cấu hình Nginx hợp lệ."
  systemctl reload nginx
  echo "Nginx đã được tải lại."
else
  echo "Error: Cấu hình Nginx không hợp lệ, vui lòng kiểm tra lại."
  exit 1
fi

echo "Quá trình thêm alias domain vào website hoàn tất."
