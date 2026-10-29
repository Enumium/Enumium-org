#!/bin/sh
# One-time setup on silocloud-api-01 (approved by the owner 2026-10-29):
# auto-deploy silocloud.dev/usland from this branch.
# The recurring job runs as www-data (not root), only downloads a tarball,
# never executes downloaded content, and only accepts plain .html/.md files
# under usland/ (no symlinks, hardlinks, "..", or other file types).
# Remove with: rm /etc/cron.d/usland-sync /usr/local/bin/usland-sync; rm -r /var/lib/usland-sync
set -e
mkdir -p /var/lib/usland-sync /var/www/html/usland
chown www-data:www-data /var/lib/usland-sync
chown -R www-data:www-data /var/www/html/usland
cat > /usr/local/bin/usland-sync <<'EOF'
#!/bin/sh
URL=https://raw.githubusercontent.com/Enumium/Enumium-org/usland-prototype/usland-deploy/usland.tar.gz
STATE=/var/lib/usland-sync
[ "$(id -un)" = "www-data" ] || { echo "run as www-data"; exit 1; }
TMP=$(mktemp) || exit 1
trap 'rm -f "$TMP"' EXIT
curl -fsSL --max-filesize 20000000 -H 'Cache-Control: no-cache' -o "$TMP" "$URL?t=$(date +%s)" || exit 0
NEW=$(sha256sum "$TMP" | cut -d' ' -f1)
[ "$NEW" = "$(cat $STATE/sha 2>/dev/null)" ] && exit 0
# Only regular files and dirs; names must be usland/... with no "..".
if tar -tvzf "$TMP" | grep -qv '^[-d]'; then logger "usland-sync: refused (links or special files)"; exit 1; fi
if tar -tzf "$TMP" | grep -qvE '^usland/([A-Za-z0-9_-]+/)*([A-Za-z0-9_.-]+\.(html|md))?$' || tar -tzf "$TMP" | grep -q '\.\.'; then logger "usland-sync: refused (unexpected path or file type)"; exit 1; fi
tar -xzf "$TMP" -C /var/www/html/ --no-same-owner --no-same-permissions && echo "$NEW" > $STATE/sha && logger "usland-sync: deployed $NEW"
EOF
chmod 755 /usr/local/bin/usland-sync
echo '* * * * * www-data /usr/local/bin/usland-sync' > /etc/cron.d/usland-sync
runuser -u www-data -- /usr/local/bin/usland-sync
echo "AUTO-DEPLOY ON. Live version: $(cat /var/lib/usland-sync/sha)"
