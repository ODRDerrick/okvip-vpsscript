#!/bin/bash

# Kiểm tra quyền root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: Vui lòng chạy script này với quyền root."
  exit 1
fi

# Tìm tất cả thư mục chứa wp-config.php
echo "Đang tìm tất cả site WordPress trên VPS..."
WP_SITES=$(find / -type f -name wp-config.php 2>/dev/null | xargs -n1 dirname)

# Kiểm tra nếu không có site nào
if [[ -z "$WP_SITES" ]]; then
    echo "Error: Không tìm thấy site WordPress nào trên hệ thống."
    exit 1
fi

# Thực hiện action: enable hoặc disable
ACTION=$1
if [[ "$ACTION" != "enable" && "$ACTION" != "disable" ]]; then
    echo "Error: Usage: $0 [enable|disable]"
    exit 1
fi

# Lặp qua từng site và bật / tắt auto update
for SITE in $WP_SITES; do
    {
        echo "$ACTION auto-update themes for $SITE"
        wp --path="$SITE" theme list --field=name --allow-root | xargs -n1 -I {} wp --path="$SITE" theme auto-updates "$ACTION" {} --allow-root
    }
done