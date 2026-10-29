#!/bin/sh
# One-time setup on silocloud-api-01 (approved by the owner 2026-10-29):
# auto-deploy silocloud.dev/usland from this branch. Remove with:
#   rm /etc/cron.d/usland-sync /usr/local/bin/usland-sync /var/lib/usland-sync.sha
set -e
cat > /usr/local/bin/usland-sync <<'EOF'
#!/bin/sh
URL=https://raw.githubusercontent.com/Enumium/Enumium-org/usland-prototype/usland-deploy/usland.tar.gz
TMP=$(mktemp) || exit 1
trap 'rm -f "$TMP"' EXIT
curl -fsSL -H 'Cache-Control: no-cache' -o "$TMP" "$URL?t=$(date +%s)" || exit 0
NEW=$(sha256sum "$TMP" | cut -d' ' -f1)
[ "$NEW" = "$(cat /var/lib/usland-sync.sha 2>/dev/null)" ] && exit 0
if tar -tzf "$TMP" | grep -qv '^usland/'; then logger "usland-sync: refused archive with paths outside usland/"; exit 1; fi
tar -xzf "$TMP" -C /var/www/html/ && chown -R www-data:www-data /var/www/html/usland && echo "$NEW" > /var/lib/usland-sync.sha && logger "usland-sync: deployed $NEW"
EOF
chmod +x /usr/local/bin/usland-sync
echo '* * * * * root /usr/local/bin/usland-sync' > /etc/cron.d/usland-sync
/usr/local/bin/usland-sync
echo "AUTO-DEPLOY ON. Live version: $(cat /var/lib/usland-sync.sha)"
