# Flutter 專案整合 sherpa-onnx 語言辨識指南

本指南將詳細說明如何在您的 Flutter 專案中整合和使用 sherpa-onnx 的語言辨識功能。

## 📋 前置需求

- Flutter SDK 3.0 或更高版本
- Dart SDK 2.17 或更高版本
- 支援的平台：Android、iOS、Windows、macOS、Linux

## 🚀 步驟 1：添加依賴

### 方法 A：使用本地路徑（開發階段）

在您的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  sherpa_onnx:
    path: ../sherpa-onnx/flutter/sherpa_onnx  # 調整為實際路徑
```

### 方法 B：使用 Git 依賴

```yaml
dependencies:
  flutter:
    sdk: flutter
  sherpa_onnx:
    git:
      url: https://github.com/k2-fsa/sherpa-onnx.git
      path: flutter/sherpa_onnx
```

### 方法 C：使用 pub.dev（如果已發布）

```yaml
dependencies:
  flutter:
    sdk: flutter
  sherpa_onnx: ^1.0.0
```

## 🔧 步驟 2：配置原生庫

### Android 配置

1. 在 `android/app/build.gradle` 中添加：

```gradle
android {
    // ... 其他配置
    
    packagingOptions {
        pickFirst '**/libc++_shared.so'
        pickFirst '**/libsherpa-onnx-c-api.so'
    }
}
```

2. 確保在 `android/app/src/main/AndroidManifest.xml` 中有網路權限：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS 配置

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>此應用需要麥克風權限進行語音辨識</string>
```

### Windows 配置

確保 `sherpa-onnx-c-api.dll` 在系統 PATH 中或與執行檔在同一目錄。

## 📦 步驟 3：下載模型

### 下載 Whisper 語言辨識模型

```bash
# 創建模型目錄
mkdir -p assets/models/whisper-lang-id

# 下載模型（範例）
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2
tar -xf sherpa-onnx-whisper-tiny.tar.bz2
```

### 在 pubspec.yaml 中註冊資源

```yaml
flutter:
  assets:
    - assets/models/whisper-lang-id/
```

## 💻 步驟 4：實現語言辨識

### 基本實現

創建 `lib/language_detector.dart`：

```dart
import 'package:flutter/services.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'dart:typed_data';

class LanguageDetector {
  SpokenLanguageIdentification? _langId;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 初始化 sherpa-onnx 綁定
      initBindings();

      // 配置 Whisper 模型
      final whisperConfig = SpokenLanguageIdentificationWhisperConfig(
        encoder: 'assets/models/whisper-lang-id/encoder.onnx',
        decoder: 'assets/models/whisper-lang-id/decoder.onnx',
        tailPaddings: 1000,
      );

      final config = SpokenLanguageIdentificationConfig(
        whisper: whisperConfig,
        numThreads: 1,
        debug: false,
        provider: 'cpu',
      );

      _langId = SpokenLanguageIdentification(config: config);
      _isInitialized = true;
      
      print('語言辨識器初始化成功');
    } catch (e) {
      print('語言辨識器初始化失敗: $e');
      rethrow;
    }
  }

  Future<String> detectLanguage(String audioPath) async {
    if (!_isInitialized || _langId == null) {
      throw StateError('語言辨識器尚未初始化');
    }

    try {
      // 創建音頻流
      final stream = _langId!.createStream();
      
      try {
        // 讀取音頻檔案
        final wave = readWave(audioPath);
        if (wave == null) {
          throw Exception('無法讀取音頻檔案: $audioPath');
        }

        // 接受音頻數據
        stream.acceptWaveform(
          sampleRate: wave.sampleRate,
          samples: wave.samples,
        );

        // 計算語言
        final result = _langId!.compute(stream);
        return result.language;
        
      } finally {
        // 釋放流資源
        stream.free();
      }
    } catch (e) {
      print('語言辨識錯誤: $e');
      rethrow;
    }
  }

  Future<String> detectLanguageFromBytes(Uint8List audioBytes) async {
    if (!_isInitialized || _langId == null) {
      throw StateError('語言辨識器尚未初始化');
    }

    try {
      final stream = _langId!.createStream();
      
      try {
        // 假設音頻是 16kHz, 16-bit PCM 格式
        final samples = Float32List.fromList(
          audioBytes.buffer.asInt16List().map((e) => e / 32768.0).toList()
        );

        stream.acceptWaveform(
          sampleRate: 16000,
          samples: samples,
        );

        final result = _langId!.compute(stream);
        return result.language;
        
      } finally {
        stream.free();
      }
    } catch (e) {
      print('語言辨識錯誤: $e');
      rethrow;
    }
  }

  void dispose() {
    _langId?.free();
    _langId = null;
    _isInitialized = false;
  }
}
```

### 在 Widget 中使用

創建 `lib/language_detection_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'language_detector.dart';

class LanguageDetectionPage extends StatefulWidget {
  @override
  _LanguageDetectionPageState createState() => _LanguageDetectionPageState();
}

class _LanguageDetectionPageState extends State<LanguageDetectionPage> {
  final LanguageDetector _detector = LanguageDetector();
  String _result = '尚未檢測';
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    setState(() => _isLoading = true);
    
    try {
      await _detector.initialize();
      setState(() => _isInitialized = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('語言辨識器初始化成功')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('初始化失敗: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndDetectLanguage() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請等待初始化完成')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'flac'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      
      try {
        final language = await _detector.detectLanguage(result.files.single.path!);
        setState(() => _result = language);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('檢測失敗: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('語言辨識'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.language,
                      size: 64,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '檢測結果',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _result,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32),
            if (_isLoading)
              CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _isInitialized ? _pickAndDetectLanguage : null,
                icon: Icon(Icons.audio_file),
                label: Text('選擇音頻檔案'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            SizedBox(height: 16),
            if (!_isInitialized)
              Text(
                '正在初始化語言辨識器...',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detector.dispose();
    super.dispose();
  }
}
```

## 🎯 步驟 5：在主應用中整合

更新 `lib/main.dart`：

```dart
import 'package:flutter/material.dart';
import 'language_detection_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '語言辨識應用',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LanguageDetectionPage(),
    );
  }
}
```

## 📱 步驟 6：添加必要的依賴

在 `pubspec.yaml` 中添加額外依賴：

```yaml
dependencies:
  flutter:
    sdk: flutter
  sherpa_onnx:
    path: ../sherpa-onnx/flutter/sherpa_onnx
  file_picker: ^5.3.2
  permission_handler: ^10.4.3
```

## 🔍 步驟 7：測試和除錯

### 測試語言辨識

```dart
// 在測試檔案中
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/language_detector.dart';

void main() {
  group('語言辨識測試', () {
    late LanguageDetector detector;

    setUp(() async {
      detector = LanguageDetector();
      await detector.initialize();
    });

    tearDown(() {
      detector.dispose();
    });

    test('應該能檢測英語', () async {
      final result = await detector.detectLanguage('test_assets/english.wav');
      expect(result, equals('en'));
    });

    test('應該能檢測中文', () async {
      final result = await detector.detectLanguage('test_assets/chinese.wav');
      expect(result, equals('zh'));
    });
  });
}
```

## ⚠️ 常見問題和解決方案

### 1. 模型載入失敗

**問題**: `無法載入模型檔案`

**解決方案**:
- 確認模型檔案路徑正確
- 檢查 `pubspec.yaml` 中的 assets 配置
- 使用絕對路徑進行測試

### 2. 原生庫載入失敗

**問題**: `DynamicLibrary.open failed`

**解決方案**:
```dart
// 在初始化時指定庫路徑
initBindings('/path/to/your/native/libs');
```

### 3. 記憶體洩漏

**問題**: 應用記憶體使用量持續增長

**解決方案**:
- 確保調用 `free()` 方法
- 使用 try-finally 確保資源釋放
- 避免創建多個辨識器實例

### 4. 音頻格式不支援

**問題**: 某些音頻格式無法處理

**解決方案**:
- 轉換為 WAV 格式
- 確保採樣率為 16kHz
- 使用 16-bit PCM 編碼

## 🚀 進階使用

### 批量語言辨識

```dart
class BatchLanguageDetector {
  final LanguageDetector _detector = LanguageDetector();

  Future<Map<String, String>> detectMultipleLanguages(
    List<String> audioPaths
  ) async {
    await _detector.initialize();
    
    final results = <String, String>{};
    
    for (final path in audioPaths) {
      try {
        final language = await _detector.detectLanguage(path);
        results[path] = language;
      } catch (e) {
        results[path] = 'error: $e';
      }
    }
    
    return results;
  }
}
```

### 即時語言辨識

```dart
class RealtimeLanguageDetector {
  // 實現即時音頻流處理和語言辨識
  // 需要結合音頻錄製功能
}
```

## 📚 更多資源

- [sherpa-onnx 官方文檔](https://k2-fsa.github.io/sherpa/onnx/)
- [Flutter 音頻處理指南](https://flutter.dev/docs/development/packages-and-plugins/using-packages)
- [模型下載地址](https://github.com/k2-fsa/sherpa-onnx/releases)

---

這個指南涵蓋了從安裝到實際使用的完整流程。如果您遇到任何問題，請參考常見問題部分或查看官方文檔。 