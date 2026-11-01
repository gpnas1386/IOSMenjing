# 用 Codemagic 免费出包（无需 Mac）

Codemagic 免费版每月给 **500 分钟 macOS M2 构建时间**，本项目编译一次约 3–5 分钟，足够用很多次。

全程只需要：一个浏览器 + 一个 GitHub 账号（您已有）。

---

## 第 1 步：把工程上传到 GitHub（网页操作，2 分钟）

因为文件较多，用网页拖动上传最省事：

1. 打开 https://github.com/new
2. **Repository name** 填 `OutingTracker`
3. 选 **Private**（私有，别人看不到）
4. 点 **Create repository**
5. 在跳转后的页面，点 **uploading an existing file** 链接
6. 解压 `OutingTracker.zip`，把里面的 **`OutingTracker` 文件夹里的所有内容**（不是文件夹本身）一起拖进网页上传框
7. 底部填 commit message，点 **Commit changes**

> 提示：`.github` 是隐藏文件夹，macOS 按 `Cmd+Shift+.` 可以显示隐藏文件；Windows 在「查看」里勾选「隐藏的项目」。Codemagic 不依赖这个文件夹，漏了也没关系。

---

## 第 2 步：在 Codemagic 连接仓库

1. 打开 https://codemagic.io/signup ，用 **GitHub 账号登录**（点 "Sign up with GitHub"）
2. 授权后进入面板，点 **Add application**
3. 选择 **GitHub** → 找到 `OutingTracker` 仓库 → **Finish: Add application**
4. 项目类型选 **Other**（不是 Flutter 也不是 React Native）→ 下一步

---

## 第 3 步：用已写好的配置

仓库根目录已经放了 `codemagic.yaml`（如果上传时漏了，见文末「配置备份」手动粘贴）。

1. 进入应用 → 左侧 **Settings** → 找到 **Configuration** / **codemagic.yaml**
2. 确认它检测到 `codemagic.yaml`，Workflow 显示 **`ios-unsigned-ipa`**
3. 先去改一下邮箱：编辑仓库里的 `codemagic.yaml`，把 `you@example.com` 换成您的邮箱
   （收件箱里会收到 IPA 下载链接，这是拿到文件最方便的方式）
4. 回到 Codemagic，点右上角 **Start new build**
5. 选择 workflow `ios-unsigned-ipa` → **Start build**

---

## 第 4 步：下载 IPA

构建大约 **3–5 分钟**。完成后：

- **方式一（推荐）**：查收邮件，点邮件里的链接下载 `OutingTracker.ipa`
- **方式二**：Codemagic 构建页面底部 **Artifacts** → 点 `OutingTracker.ipa` 下载

---

## 第 5 步：TrollStore 安装

1. 把 `OutingTracker.ipa` 传到 iPhone（AirDrop / 微信文件传输 / 网盘）
2. 用「文件」App 长按该文件 → **分享** → 选择 **TrollStore**
3. TrollStore 里点 **Install**
4. 装好后打开 App，长按负一屏空白 → 「+」→ 搜索「外出登记」添加小组件

---

## 常见问题

**Q：构建报 "requires a development team"？**
配置里已经关闭了签名（`CODE_SIGNING_ALLOWED=NO`），正常不会出现。若出现，检查 `codemagic.yaml` 是否完整上传。

**Q：构建成功但 Artifacts 里没有 IPA？**
看构建日志最后的「打包成 IPA」步骤，那里会打印实际产物路径。把日志贴给我，我帮您改配置。

**Q：500 分钟用完怎么办？**
一次构建约 3–5 分钟。真要反复调，建议先在 Xcode 本地调好再上云。

---

## 配置备份（`codemagic.yaml` 全文）

如果上传时漏了这个文件，在 GitHub 仓库里点 **Add file → Create new file**，文件名填 `codemagic.yaml`，粘贴以下内容：

```yaml
workflows:
  ios-unsigned-ipa:
    name: 外出登记 · 构建未签名 IPA
    instance_type: mac_mini_m2
    max_build_duration: 30
    environment:
      xcode: latest
      vars:
        SCHEME: OutingTracker
        PROJECT: OutingTracker.xcodeproj
    scripts:
      - name: 环境信息
        script: |
          xcodebuild -version
          xcodebuild -showsdks | grep -i "ios" || true

      - name: 构建 archive（不签名）
        script: |
          set -o pipefail
          xcodebuild \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -sdk iphoneos \
            -destination 'generic/platform=iOS' \
            -archivePath "$CM_BUILD_DIR/OutingTracker.xcarchive" \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGN_ENTITLEMENTS="" \
            DEVELOPMENT_TEAM="" \
            PROVISIONING_PROFILE_SPECIFIER="" \
            ONLY_ACTIVE_ARCH=NO \
            archive 2>&1 | xcpretty || true

      - name: 打包成 IPA
        script: |
          set -e
          APP="$CM_BUILD_DIR/OutingTracker.xcarchive/Products/Applications/OutingTracker.app"
          if [ ! -d "$APP" ]; then
            find "$CM_BUILD_DIR" -name "*.app" -maxdepth 6
            APP=$(find "$CM_BUILD_DIR" -name "OutingTracker.app" -maxdepth 6 | head -1)
          fi
          [ -z "$APP" ] && { echo "构建产物缺失"; exit 1; }
          ls -la "$APP/PlugIns" || true
          file "$APP/OutingTracker" || true
          mkdir -p "$CM_BUILD_DIR/Payload"
          cp -R "$APP" "$CM_BUILD_DIR/Payload/"
          cd "$CM_BUILD_DIR"
          zip -qry OutingTracker.ipa Payload
          ls -lh OutingTracker.ipa

    artifacts:
      - $CM_BUILD_DIR/OutingTracker.ipa
      - $CM_BUILD_DIR/OutingTracker.xcarchive

    publishing:
      email:
        recipients:
          - you@example.com
        notify:
          success: true
          failure: true
```
