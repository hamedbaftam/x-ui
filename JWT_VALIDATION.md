# JWT Token Validation for VLESS WebSocket

این پروژه حالا قابلیت بررسی JWT token در query string برای اتصال‌های VLESS WebSocket را دارد.

## نحوه کار

وقتی یک اتصال VLESS WebSocket با query string حاوی `token` می‌آید (مثل `/?token=jwt_token&...`)، سیستم به صورت خودکار:
1. Token را از query string استخراج می‌کند
2. Token را decode می‌کند
3. بررسی می‌کند که آیا token expire شده است یا نه
4. اگر expire شده باشد، اتصال را reject می‌کند

## توابع موجود

### `xray.ValidateJWTInPath(path string) bool`
این تابع یک path (که ممکن است شامل query string باشد) را دریافت می‌کند و اگر token در آن باشد، آن را بررسی می‌کند.

```go
isValid := xray.ValidateJWTInPath("/?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
```

### `xray.ExtractTokenFromPath(path string) string`
این تابع token را از path استخراج می‌کند.

```go
token := xray.ExtractTokenFromPath("/?token=jwt_token&other=params")
```

### `middleware.ValidateJWTToken(tokenStr string) bool`
این تابع یک JWT token string را دریافت می‌کند و بررسی می‌کند که expire شده یا نه.

```go
isValid := middleware.ValidateJWTToken("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
```

## نحوه استفاده

برای استفاده از این قابلیت، باید:

1. **در VLESS WebSocket link، token را به query string اضافه کنید:**
   ```
   vless://uuid@server:port?path=/?token=jwt_token&security=none&encryption=none&host=example.com&type=ws
   ```

2. **Token باید یک JWT معتبر با claim `exp` باشد:**
   ```json
   {
     "exp": 1735689600  // Unix timestamp
   }
   ```

3. **اگر token expire شده باشد، اتصال رد می‌شود**

## مثال JWT Token

یک JWT token معتبر باید دارای claim `exp` (expiration time) باشد:

```javascript
{
  "sub": "user123",
  "exp": 1735689600  // Unix timestamp - زمانی که token expire می‌شود
}
```

## توجه

- اگر token در query string نباشد، اتصال به صورت عادی برقرار می‌شود (token اختیاری است)
- بررسی signature انجام نمی‌شود، فقط expiration time چک می‌شود
- اگر می‌خواهید signature verification هم انجام شود، باید secret key را به کد اضافه کنید

