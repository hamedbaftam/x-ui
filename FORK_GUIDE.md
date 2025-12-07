# راهنمای Fork و Push تغییرات JWT Validation

## مرحله 1: Fork کردن Repository

### روش 1: از طریق GitHub (ساده‌ترین روش)

1. به آدرس https://github.com/hamedbaftam/x-ui بروید
2. روی دکمه **Fork** در بالای صفحه کلیک کنید
3. repository را در اکانت خود fork کنید

### روش 2: از طریق Git CLI

```bash
# 1. اضافه کردن remote جدید
git remote add upstream https://github.com/hamedbaftam/x-ui.git

# 2. یا اگر می‌خواهید remote origin را تغییر دهید
git remote set-url origin https://github.com/YOUR_USERNAME/x-ui.git
```

## مرحله 2: تنظیم Remote برای Repository شما

```bash
# بررسی remote فعلی
git remote -v

# اگر می‌خواهید origin را به repository جدید تغییر دهید
git remote set-url origin https://github.com/YOUR_USERNAME/x-ui.git

# یا remote جدید اضافه کنید
git remote add myfork https://github.com/YOUR_USERNAME/x-ui.git
```

## مرحله 3: Commit کردن تغییرات JWT Validation

```bash
# 1. اضافه کردن تمام فایل‌های تغییر یافته
git add go.mod go.sum
git add web/service/setting.go
git add web/service/xray.go
git add web/web.go
git add web/middleware/jwt_validator.go
git add web/network/ws_jwt_proxy.go
git add xray/jwt_validator.go

# 2. اضافه کردن فایل‌های جدید
git add INSTALL_GUIDE.md
git add JWT_VALIDATION.md
git add generate_jwt.js

# یا همه را با هم
git add .

# 3. Commit کردن تغییرات
git commit -m "feat: Add JWT token validation for VLESS WebSocket connections

- Add JWT secret key management in settings
- Implement JWT token validation middleware
- Add JWT validator functions for xray
- Add WebSocket proxy for JWT validation
- Add JWT token generator script
- Add documentation for JWT validation feature"

# 4. Push کردن به repository
git push origin main

# یا اگر branch دیگری دارید
git push origin YOUR_BRANCH_NAME
```

## مرحله 4: ایجاد Pull Request (اگر می‌خواهید به upstream merge شود)

```bash
# 1. اطمینان از sync با upstream
git fetch upstream
git checkout main
git merge upstream/main

# 2. ایجاد branch جدید برای PR
git checkout -b feature/jwt-validation
git push origin feature/jwt-validation

# سپس از GitHub interface یک Pull Request ایجاد کنید
```

## مرحله 5: بررسی تغییرات قبل از Push

```bash
# مشاهده تغییرات
git diff

# مشاهده فایل‌های تغییر یافته
git status

# مشاهده history
git log --oneline -10
```

## خلاصه تغییرات اضافه شده:

### فایل‌های جدید:
- `web/middleware/jwt_validator.go` - Middleware برای بررسی JWT در HTTP requests
- `xray/jwt_validator.go` - توابع بررسی JWT برای xray
- `web/network/ws_jwt_proxy.go` - WebSocket proxy برای بررسی JWT
- `JWT_VALIDATION.md` - مستندات قابلیت JWT
- `INSTALL_GUIDE.md` - راهنمای نصب
- `generate_jwt.js` - اسکریپت ساخت JWT token

### فایل‌های تغییر یافته:
- `go.mod` - اضافه شدن کتابخانه `github.com/golang-jwt/jwt/v5`
- `go.sum` - dependency checksums
- `web/service/setting.go` - اضافه شدن `jwtSecret` setting
- `web/service/xray.go` - اضافه شدن `Init()` برای تنظیم JWT secret
- `web/web.go` - فراخوانی `Init()` هنگام start سرور

## دستورات مفید

```bash
# بازگردانی تغییرات (در صورت نیاز)
git restore <file>

# مشاهده تفاوت با upstream
git fetch upstream
git diff upstream/main

# Merge کردن تغییرات از upstream
git merge upstream/main

# ایجاد tag برای release
git tag -a v1.0.0-jwt -m "Release with JWT validation"
git push origin v1.0.0-jwt
```

## نکات مهم:

1. **قبل از Push**: مطمئن شوید همه تست‌ها درست کار می‌کنند
2. **Commit Message**: از commit message های واضح و توصیفی استفاده کنید
3. **Branch Strategy**: برای تغییرات بزرگ، branch جداگانه ایجاد کنید
4. **Testing**: قبل از merge کردن، تست کنید که همه چیز کار می‌کند

