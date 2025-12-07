# راهنمای Build و Release برای نصب با install.sh

برای اینکه `install.sh` بتواند از repository شما نصب کند، باید یک Release با binary بسازید.

## روش 1: Build و ساخت Release (توصیه می‌شود)

### مرحله 1: Build کردن Binary

```bash
# 1. Build برای معماری‌های مختلف
# برای Linux AMD64
GOOS=linux GOARCH=amd64 go build -ldflags "-w -s" -o x-ui-linux-amd64 main.go

# برای Linux ARM64
GOOS=linux GOARCH=arm64 go build -ldflags "-w -s" -o x-ui-linux-arm64 main.go

# برای Linux ARMv7
GOOS=linux GOARCH=arm GOARM=7 go build -ldflags "-w -s" -o x-ui-linux-armv7 main.go
```

### مرحله 2: دانلود Xray Binary

```bash
# برای هر معماری، xray binary را دانلود کنید
mkdir -p bin-amd64 bin-arm64 bin-armv7

# AMD64
cd bin-amd64
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-amd64.zip
unzip Xray-linux-amd64.zip
mv xray xray-linux-amd64
rm Xray-linux-amd64.zip
cd ..

# ARM64
cd bin-arm64
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip
unzip Xray-linux-arm64-v8a.zip
mv xray xray-linux-arm64
rm Xray-linux-arm64-v8a.zip
cd ..

# ARMv7
cd bin-armv7
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm32-v7a.zip
unzip Xray-linux-arm32-v7a.zip
mv xray xray-linux-armv7
rm Xray-linux-arm32-v7a.zip
cd ..
```

### مرحله 3: ساخت Tarball برای هر معماری

```bash
# AMD64
mkdir -p release-amd64
cp x-ui-linux-amd64 release-amd64/x-ui
cp x-ui.sh release-amd64/
cp x-ui.service release-amd64/
mkdir -p release-amd64/bin
cp bin-amd64/xray-linux-amd64 release-amd64/bin/
cd release-amd64
tar czf ../x-ui-linux-amd64.tar.gz *
cd ..

# ARM64
mkdir -p release-arm64
cp x-ui-linux-arm64 release-arm64/x-ui
cp x-ui.sh release-arm64/
cp x-ui.service release-arm64/
mkdir -p release-arm64/bin
cp bin-arm64/xray-linux-arm64 release-arm64/bin/
cd release-arm64
tar czf ../x-ui-linux-arm64.tar.gz *
cd ..

# ARMv7
mkdir -p release-armv7
cp x-ui-linux-armv7 release-armv7/x-ui
cp x-ui.sh release-armv7/
cp x-ui.service release-armv7/
mkdir -p release-armv7/bin
cp bin-armv7/xray-linux-armv7 release-armv7/bin/
cd release-armv7
tar czf ../x-ui-linux-armv7.tar.gz *
cd ..
```

### مرحله 4: ساخت Release در GitHub

1. به repository خود در GitHub بروید
2. روی **Releases** کلیک کنید
3. **Draft a new release** را انتخاب کنید
4. یک **Tag** و **Title** وارد کنید (مثلاً `v1.0.0-jwt`)
5. توضیحات Release را اضافه کنید
6. فایل‌های `.tar.gz` را drag & drop کنید:
   - `x-ui-linux-amd64.tar.gz`
   - `x-ui-linux-arm64.tar.gz`
   - `x-ui-linux-armv7.tar.gz`
7. **Publish release** را کلیک کنید

## روش 2: استفاده از GitHub Actions (خودکار)

یک workflow برای GitHub Actions بسازید:

```yaml
# .github/workflows/build-release.yml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [amd64, arm64, armv7]
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.25'
      
      - name: Build x-ui
        env:
          GOOS: linux
          GOARCH: ${{ matrix.arch == 'armv7' && 'arm' || matrix.arch }}
          GOARM: ${{ matrix.arch == 'armv7' && '7' || '' }}
        run: |
          go build -ldflags "-w -s" -o x-ui main.go
      
      - name: Download Xray
        run: |
          ARCH=${{ matrix.arch }}
          if [ "$ARCH" = "armv7" ]; then
            ARCH="arm32-v7a"
          elif [ "$ARCH" = "arm64" ]; then
            ARCH="arm64-v8a"
          fi
          wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${ARCH}.zip
          unzip Xray-linux-${ARCH}.zip
          mkdir -p bin
          mv xray bin/xray-linux-${{ matrix.arch }}
      
      - name: Create tarball
        run: |
          mkdir -p release
          cp x-ui release/
          cp x-ui.sh release/
          cp x-ui.service release/
          cp -r bin release/
          cd release
          tar czf ../x-ui-linux-${{ matrix.arch }}.tar.gz *
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: x-ui-linux-${{ matrix.arch }}
          path: x-ui-linux-${{ matrix.arch }}.tar.gz
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            x-ui-linux-${{ matrix.arch }}.tar.gz
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## روش 3: استفاده از install.sh با Build از Source

اگر نمی‌خواهید Release بسازید، `install.sh` به صورت خودکار از source build می‌کند (اگر release موجود نباشد).

فقط باید:
1. `GITHUB_USER` و `GITHUB_REPO` را در `install.sh` تنظیم کنید
2. `install.sh` را در repository خود push کنید
3. از این دستور استفاده کنید:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/hamedbaftam/x-ui/main/install.sh)
```

## تنظیم install.sh

در `install.sh` این بخش را تغییر دهید:

```bash
# Repository configuration - Change this to your repository
GITHUB_USER="hamedbaftam"
GITHUB_REPO="x-ui"
GITHUB_BRANCH="main"
```

## تست install.sh

```bash
# تست بر روی سرور
bash <(curl -Ls https://raw.githubusercontent.com/YOUR_USERNAME/x-ui/main/install.sh)
```

## نکات مهم:

1. **Release Tag**: باید به فرمت `v*` باشد (مثلاً `v1.0.0`)
2. **Binary Names**: باید دقیقاً `x-ui-linux-{arch}.tar.gz` باشند
3. **Permissions**: بعد از extract، فایل‌ها باید executable باشند
4. **Testing**: قبل از publish، روی یک سرور تست کنید

