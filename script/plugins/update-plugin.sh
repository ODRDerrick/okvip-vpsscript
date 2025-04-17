#!/bin/bash

SITE_PATH="$1"
PLUGINS=("${@:2}")

if [ -z "$SITE_PATH" ] || [ "$#" -lt 2 ]; then
    echo "Cách dùng: $0 <site_path> \"plugin:status:update\" [\"plugin2:status:update\"] ..."
    echo "Ví dụ: $0 /var/www/html \"plugin-a:active:enabled\" \"plugin-b:inactive:disabled\""
    exit 1
fi

for plugin_info in "${PLUGINS[@]}"; do
    IFS=':' read -ra parts <<< "$plugin_info"
    name="${parts[0]}"
    desired_status="${parts[1]}"
    desired_update="${parts[2]}"

    echo "🔧 Đang xử lý plugin: $name"

    # Kích hoạt hoặc vô hiệu hóa plugin
    if [[ "$desired_status" == "active" ]]; then
        wp plugin activate "$name" --path="$SITE_PATH"
    else
        wp plugin deactivate "$name" --path="$SITE_PATH"
    fi

    # Bật hoặc tắt auto-update
    if [[ "$desired_update" == "enabled" ]]; then
        wp plugin auto-updates enable "$name" --path="$SITE_PATH"
    else
        wp plugin auto-updates disable "$name" --path="$SITE_PATH"
    fi
done
