# Local Audio Player (Android only)

一个仅兼容 Android 的 Flutter 本地音频播放器，支持后台播放、通知栏控制、播放列表持久化、自动切歌、跳过开头/结尾秒数。

## 环境要求

- Flutter: `3.16.9`
- JDK: `C:\Program Files\Java\jdk-11.0.12`
- Android minSdk: `21`

已在 `android/gradle.properties` 中设置：

```properties
org.gradle.java.home=C:\\Program Files\\Java\\jdk-11.0.12
```

## 主要功能

- 音频导入
  - 自动扫描（MediaStore）
  - 手动选择文件夹并递归导入
  - 手动选择多个文件导入
- 播放器功能
  - 播放/暂停、上一首/下一首、进度拖拽
  - 播放列表点击切歌、删除（仅移除列表）
  - 列表搜索
  - 循环模式：列表循环/单曲循环/随机
  - 播放完成自动切换下一首
  - 全局跳过开头 N 秒、跳过结尾 N 秒
- 后台与通知
  - 前台服务通知
  - 通知栏媒体控制：播放/暂停、上一首、下一首、关闭
  - 支持媒体按钮（耳机线控）
- 异常与权限引导
  - 自动扫描权限状态检测
  - 缺失权限顶部警示卡与独立“权限引导”页面
  - 导入/扫描成功与失败原因提示（SnackBar）
  - 一键跳转系统设置授权
- 持久化
  - `sqflite` 保存播放列表与设置

## 依赖版本

- `audio_service: 0.18.16`
- `just_audio: 0.9.42`
- `provider: 6.1.5+1`
- `sqflite: 2.3.2`
- `file_picker: 6.2.1`
- `permission_handler: 11.3.1`
- `on_audio_query: 2.9.0`
- `device_info_plus: 9.1.2`

## 运行

```bash
flutter pub get
flutter run -d <android_device_id>
```

## Android 配置说明

关键配置位于：

- `android/app/src/main/AndroidManifest.xml`
  - `READ_EXTERNAL_STORAGE`（maxSdk 32）
  - `READ_MEDIA_AUDIO`
  - `FOREGROUND_SERVICE`
  - `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
  - `POST_NOTIFICATIONS`
  - `AudioService` 前台服务与 `MediaButtonReceiver`
- `android/app/build.gradle`
  - `minSdkVersion 21`
  - Java/Kotlin 11

## 项目结构

- `lib/services/player_audio_handler.dart`：后台播放、通知控制、自动切歌、跳过逻辑
- `lib/services/audio_import_service.dart`：自动扫描/选文件夹/选文件
- `lib/repositories/library_repository.dart`：数据库持久化
- `lib/controllers/player_controller.dart`：状态管理（Provider）
- `lib/ui/screens/*`：播放列表、播放页、设置页
