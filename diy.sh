#!/bin/bash
# ============================================================================
#  diy.sh —— 编译前的自定义修改脚本（可选，放到仓库根目录并 chmod +x）
#
#  作用：在 feeds 装好、.config 加载完之后，正式编译之前执行。
#        用来改默认 IP、主机名、时区、root 密码、开机 WiFi 等"烧进固件"的默认值。
#
#  注意：本脚本在源码根目录下执行（不是 openwrt/ 子目录）。
# ============================================================================
set -e

# ------------------------------------------------------------------ 可调参数
LAN_IP="192.168.1.1"          # 改成你想要的 LAN 口地址，比如 10.0.0.1
HOSTNAME="ImmortalWrt"        # 路由器主机名
TIMEZONE="Asia/Shanghai"      # 时区
ROOT_PASSWORD=""              # 留空 = 无密码；填了就是开机 root 密码，比如 "password"
ENABLE_WIFI="0"               # 1 = 开机默认开启 WiFi（仅无线路由机型有意义）
WIFI_SSID="ImmortalWrt"
WIFI_KEY=""                   # 留空 = 开放网络；至少 8 位才算加密

echo ">>> 开始自定义修改"

# ------------------------------------------------------- 1. 默认 LAN IP / 主机名 / 时区
CFG="package/base-files/files/bin/config_generate"
if [ -f "$CFG" ]; then
  sed -i "s/192\.168\.1\.1/${LAN_IP}/g" "$CFG"
  sed -i "s/\(set system\.\@system\[0\]\.hostname=\).*/\1'${HOSTNAME}'/" "$CFG"
  sed -i "s/\(set system\.\@system\[0\]\.timezone=\).*/\1'${TIMEZONE}'/" "$CFG"
  sed -i "s/\(set system\.\@system\[0\]\.zonename=\).*/\1'${TIMEZONE}'/" "$CFG"
  echo "  ✔ LAN IP -> ${LAN_IP}，主机名 -> ${HOSTNAME}，时区 -> ${TIMEZONE}"
else
  echo "  ⚠ 未找到 ${CFG}，跳过网络默认配置修改"
fi

# ------------------------------------------------------------------ 2. root 密码
if [ -n "${ROOT_PASSWORD}" ]; then
  # 用 uci-defaults 在首次开机时写入密码，避免直接改 shadow 里的哈希
  mkdir -p package/base-files/files/etc/uci-defaults
  cat > package/base-files/files/etc/uci-defaults/99-set-root-password <<EOF
#!/bin/sh
(echo "${ROOT_PASSWORD}"; sleep 1; echo "${ROOT_PASSWORD}") | passwd root >/dev/null 2>&1
exit 0
EOF
  chmod +x package/base-files/files/etc/uci-defaults/99-set-root-password
  echo "  ✔ 已设置开机 root 密码"
else
  echo "  · root 密码保持为空（首次登录直接回车）"
fi

# ------------------------------------------------------------------ 3. 开机 WiFi
if [ "${ENABLE_WIFI}" = "1" ] && [ -f "$CFG" ]; then
  cat >> "$CFG" <<EOF

# --- 由 diy.sh 追加：默认启用无线 ---
if [ -x /sbin/wifi ]; then
  uci -q set wireless.radio0.disabled='0'
  uci -q set wireless.radio0.country='CN'
  uci -q set wireless.default_radio0.ssid='${WIFI_SSID}'
  uci -q set wireless.default_radio0.encryption='$( [ -n "${WIFI_KEY}" ] && echo psk2 || echo none )'
  $( [ -n "${WIFI_KEY}" ] && echo "uci -q set wireless.default_radio0.key='${WIFI_KEY}'" )
  uci -q commit wireless
fi
EOF
  echo "  ✔ 已写入开机 WiFi 配置：${WIFI_SSID}"
fi

# ------------------------------------------------------------------ 4. 追加第三方插件
# 想装仓库里没有的插件，在这里 git clone 到 package/ 下，并在 .config 里打开对应开关。
# 例：PassWall
# git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall package/openwrt-passwall
# git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall-packages
# 例：OpenClash
# git clone --depth=1 https://github.com/vernesong/OpenClash package/OpenClash

# ------------------------------------------------------------------ 5. 其他杂项
# 修改默认主题（取消注释生效）
# sed -i 's/luci-theme-bootstrap/luci-theme-argon/' feeds/luci/collections/luci/Makefile

# 修改软件源为国内镜像（加快路由器上 opkg 安装速度）
# sed -i 's#https://downloads.immortalwrt.org#https://mirrors.nju.edu.cn/immortalwrt#g' \
#     package/base-files/files/etc/opkg/distfeeds.conf 2>/dev/null || true

echo ">>> 自定义修改完成"
