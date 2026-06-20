#!/bin/bash
# init-ssl.sh — Inisialisasi sertifikat Let's Encrypt untuk dua domain.
# Jalankan sekali setelah `docker compose up -d` pertama kali.
#
# Syarat:
#   - Domain pos.nbp.co.id dan api-pos.nbp.co.id sudah pointing ke IP server ini
#   - Port 80 dan 443 terbuka di firewall
#   - docker compose sudah running dengan konfigurasi HTTP-only

set -e

DOMAIN_FRONTEND="pos.nbp.co.id"
DOMAIN_API="api-pos.nbp.co.id"
EMAIL="daniswaramuktibawana@gmail.com"

echo "=== Step 1: Pastikan Nginx berjalan dengan config HTTP-only ==="
# Salin config HTTP-only ke container agar ACME challenge bisa diakses
sudo docker compose cp nginx/default.http-only.conf nginx:/etc/nginx/conf.d/default.conf
sudo docker compose exec nginx nginx -s reload
sleep 2

echo "=== Step 2: Dapatkan sertifikat untuk $DOMAIN_FRONTEND ==="
sudo docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN_FRONTEND"

echo "=== Step 3: Dapatkan sertifikat untuk $DOMAIN_API ==="
sudo docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN_API"

echo "=== Step 4: Download SSL options dari Certbot ==="
sudo docker compose run --rm certbot \
    sh -c "curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > /etc/letsencrypt/options-ssl-nginx.conf && \
           openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048"

echo "=== Step 5: Switch ke config HTTPS dan reload Nginx ==="
sudo docker compose cp nginx/default.conf nginx:/etc/nginx/conf.d/default.conf
sudo docker compose exec nginx nginx -s reload

echo ""
echo "=== Selesai! SSL aktif untuk: ==="
echo "   https://$DOMAIN_FRONTEND"
echo "   https://$DOMAIN_API"
echo ""
echo "Certbot otomatis memperbarui sertifikat setiap 12 jam."
