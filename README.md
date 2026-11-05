# 按时吃药（TimeToEat）

SwiftUI + SwiftData 的服药提醒 App，iOS 17+。

## 开发

工程文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成，改了工程配置后执行：

```bash
xcodegen generate
```

模拟器预览时可加启动参数：`-demo`（数据库为空时重新写入内置的三种药和记录；正常首次启动也会自动写入一次）、`-tab 0/1/2`、`-add`、`-record`。

## 打包 IPA

```bash
./scripts/build-ipa.sh            # 开发证书签名，需要团队里至少登记一台 iPhone
UNSIGNED=1 ./scripts/build-ipa.sh # 不签名，用 Sideloadly / AltStore 等工具签名安装
```

产物在 `dist/`（不进 git）。

## 版本

版本号在 `project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`，每次发布打 `vX.Y.Z` 标签。
