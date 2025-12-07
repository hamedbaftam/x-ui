# راهنمای نصب X-UI با قابلیت JWT Validation

این راهنما شامل روش‌های مختلف نصب پروژه X-UI با قابلیت جدید بررسی JWT token برای VLESS WebSocket است.

## روش 1: نصب از Source (توصیه می‌شود برای تغییرات جدید)

### پیش‌نیازها:

```bash
# نصب Go (نسخه 1.25 یا بالاتر)
wget https://go.dev/dl/go1.25.1.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.25.1.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

# نصب Git
sudo apt update
sudo apt install -y git build-essential
```

### مراحل نصب:

```bash
# 1. Clone کردن پروژه
git clone https://github.com/alireza0/x-ui.git
cd x-ui

# 2. Build کردن پروژه
go build -ldflags "-w -s" -o x-ui main.go

# 3. نصب Xray binary
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64 | x64 | amd64) XUI_ARCH="amd64" ;;
  armv8* | armv8 | arm64 | aarch64) XUI_ARCH="arm64" ;;
  armv7* | armv7) XUI_ARCH="armv7" ;;
  *) XUI_ARCH="amd64" ;;
esac

mkdir -p bin
cd bin
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XUI_ARCH}.zip
unzip Xray-linux-${XUI_ARCH}.zip
rm Xray-linux-${XUI_ARCH}.zip
chmod +x xray
cd ..

# 4. نصب systemd service
sudo cp x-ui.service /etc/systemd/system/
sudo systemctl daemon-reload

# 5. ایجاد دایرکتوری‌های لازم
sudo mkdir -p /etc/x-ui
sudo mkdir -p /usr/local/x-ui/bin

# 6. کپی فایل‌ها
sudo cp x-ui /usr/local/x-ui/
sudo cp bin/xray /usr/local/x-ui/bin/xray-linux-${XUI_ARCH}
sudo cp x-ui.sh /usr/local/x-ui/
sudo cp x-ui.sh /usr/bin/x-ui
sudo chmod +x /usr/local/x-ui/x-ui
sudo chmod +x /usr/local/x-ui/bin/xray-linux-${XUI_ARCH}
sudo chmod +x /usr/bin/x-ui

# 7. فعال‌سازی و راه‌اندازی
sudo systemctl enable x-ui
sudo systemctl start x-ui

# 8. بررسی وضعیت
sudo systemctl status x-ui
```

### تنظیمات اولیه:

```bash
# تنظیم username و password
sudo /usr/local/x-ui/x-ui setting -username admin -password your_password

# تنظیم port
sudo /usr/local/x-ui/x-ui setting -port 54321

# تنظیم webBasePath (برای امنیت بیشتر)
sudo /usr/local/x-ui/x-ui setting -webBasePath /your-random-path/

# مشاهده تنظیمات
sudo /usr/local/x-ui/x-ui setting -show
```

## روش 2: نصب با Docker

### پیش‌نیازها:

```bash
# نصب Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker
sudo systemctl start docker
```

### مراحل نصب:

```bash
# 1. Clone کردن پروژه
git clone https://github.com/alireza0/x-ui.git
cd x-ui

# 2. Build کردن Docker image
docker build -t x-ui:latest .

# 3. ایجاد دایرکتوری‌های لازم
mkdir -p db cert

# 4. راه‌اندازی با docker-compose
docker compose up -d

# یا راه‌اندازی مستقیم
docker run -itd \
    --name x-ui \
    --restart=unless-stopped \
    -p 54321:54321 \
    -p 443:443 \
    -p 80:80 \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    -e XRAY_VMESS_AEAD_FORCED=false \
    --network host \
    x-ui:latest
```

### دستورات مدیریت Docker:

```bash
# مشاهده لاگ‌ها
docker logs -f x-ui

# توقف
docker stop x-ui

# راه‌اندازی مجدد
docker restart x-ui

# حذف
docker stop x-ui
docker rm x-ui
```

## روش 3: نصب با Install Script (بدون تغییرات جدید)

اگر می‌خواهید نسخه اصلی را نصب کنید (بدون قابلیت JWT):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
```

## تنظیمات JWT Secret Key

بعد از نصب، می‌توانید JWT secret key را در پنل تنظیم کنید:

1. وارد پنل وب شوید
2. به قسمت Settings بروید
3. JWT Secret Key را پیدا کنید و مقدار آن را تغییر دهید
4. مقدار پیش‌فرض: `x-ui-jwt-secret-key-change-this-in-production`

یا از طریق خط فرمان:

```bash
# باید از طریق API یا دیتابیس تنظیم شود
# فعلاً در کد مقدار پیش‌فرض تنظیم شده است
```

## دستورات مفید

```bash
# مشاهده وضعیت سرویس
x-ui status
# یا
sudo systemctl status x-ui

# راه‌اندازی مجدد
x-ui restart
# یا
sudo systemctl restart x-ui

# مشاهده لاگ‌ها
x-ui log
# یا
sudo journalctl -u x-ui -f

# مشاهده تنظیمات
x-ui settings

# به‌روزرسانی
x-ui update
```

## تست JWT Token

بعد از نصب، می‌توانید JWT token بسازید:

```bash
# استفاده از اسکریپت موجود
node generate_jwt.js
```

یا در صورت نصب Node.js روی سرور:

```bash
# نصب jsonwebtoken
npm install jsonwebtoken

# ساخت token
node -e "
const jwt = require('jsonwebtoken');
const token = jwt.sign(
  { sub: 'user123', exp: Math.floor(Date.now()/1000) + 86400 },
  'x-ui-jwt-secret-key-change-this-in-production'
);
console.log(token);
"
```

## تنظیمات Firewall

```bash
# UFW
sudo ufw allow 54321/tcp
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp

# Firewalld
sudo firewall-cmd --permanent --add-port=54321/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --reload
```

## عیب‌یابی

### بررسی لاگ‌ها:

```bash
# لاگ پنل
sudo journalctl -u x-ui -n 100 -f

# لاگ xray
x-ui log
```

### بررسی پورت‌ها:

```bash
sudo netstat -tlnp | grep x-ui
# یا
sudo ss -tlnp | grep x-ui
```

### بررسی فایل‌های ضروری:

```bash
# بررسی وجود binary
ls -la /usr/local/x-ui/x-ui
ls -la /usr/local/x-ui/bin/xray-linux-*

# بررسی database
ls -la /etc/x-ui/x-ui.db
```

## امنیت

1. **تغییر رمز عبور پیش‌فرض**: حتماً username و password را تغییر دهید
2. **تغییر webBasePath**: یک مسیر تصادفی برای پنل تنظیم کنید
3. **استفاده از HTTPS**: SSL certificate تنظیم کنید
4. **تغییر JWT Secret**: secret key پیش‌فرض را تغییر دهید
5. **Firewall**: فقط پورت‌های لازم را باز کنید

## پشتیبانی

در صورت بروز مشکل، لاگ‌ها را بررسی کنید و به گیت‌هاب issue ایجاد کنید.

