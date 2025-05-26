# 🚀 Flutter 語言辨識快速開始

這是一個 5 分鐘快速開始指南，讓您立即在 Flutter 專案中使用語言辨識功能。

## 📦 1. 添加依賴 (1 分鐘)

在您的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  sherpa_onnx:
    git:
      url: https://github.com/k2-fsa/sherpa-onnx.git
      path: flutter/sherpa_onnx
  file_picker: ^5.3.2
```

然後執行：
```bash
flutter pub get
```

## 🎯 2. 基本使用 (3 分鐘)

創建 `lib/simple_language_detector.dart`：

```dart
import 'package:sherpa_onnx/sherpa_onnx.dart';

class SimpleLanguageDetector {
  static SpokenLanguageIdentification? _langId;

  static Future<void> init() async {
    if (_langId != null) return;

    // 初始化綁定
    initBindings();

    // 配置模型（請替換為您的模型路徑）
    final config = SpokenLanguageIdentificationConfig(
      whisper: SpokenLanguageIdentificationWhisperConfig(
        encoder: 'path/to/encoder.onnx',
        decoder: 'path/to/decoder.onnx',
      ),
    );

    _langId = SpokenLanguageIdentification(config: config);
  }

  static Future<String> detect(String audioPath) async {
    if (_langId == null) await init();

    final stream = _langId!.createStream();
    try {
      final wave = readWave(audioPath);
      if (wave != null) {
        stream.acceptWaveform(
          sampleRate: wave.sampleRate,
          samples: wave.samples,
        );
        final result = _langId!.compute(stream);
        return result.language;
      }
      return 'unknown';
    } finally {
      stream.free();
    }
  }

  static void dispose() {
    _langId?.free();
    _langId = null;
  }
}
```

## 🎨 3. 簡單 UI (1 分鐘)

更新您的 `lib/main.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'simple_language_detector.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '語言辨識',
      home: LanguageDetectorPage(),
    );
  }
}

class LanguageDetectorPage extends StatefulWidget {
  @override
  _LanguageDetectorPageState createState() => _LanguageDetectorPageState();
}

class _LanguageDetectorPageState extends State<LanguageDetectorPage> {
  String _result = '點擊按鈕選擇音頻檔案';
  bool _loading = false;

  Future<void> _detectLanguage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );

    if (result?.files.single.path != null) {
      setState(() => _loading = true);
      
      try {
        final language = await SimpleLanguageDetector.detect(
          result!.files.single.path!
        );
        setState(() => _result = '檢測到的語言: $language');
      } catch (e) {
        setState(() => _result = '錯誤: $e');
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('語言辨識')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_result, textAlign: TextAlign.center),
            SizedBox(height: 20),
            _loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _detectLanguage,
                    child: Text('選擇音頻檔案'),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    SimpleLanguageDetector.dispose();
    super.dispose();
  }
}
```

## 🎵 4. 測試

1. 準備一個 WAV 音頻檔案
2. 下載對應的 Whisper 模型檔案
3. 更新模型路徑
4. 執行 `flutter run`
5. 點擊按鈕選擇音頻檔案

## 📝 注意事項

- 確保模型檔案路徑正確
- 音頻檔案建議使用 WAV 格式，16kHz 採樣率
- 首次使用需要下載模型檔案

## 🔗 下一步

- 查看 [完整整合指南](INTEGRATION_GUIDE.md) 了解更多功能
- 下載預訓練模型：[sherpa-onnx releases](https://github.com/k2-fsa/sherpa-onnx/releases)
- 查看更多範例：[sherpa-onnx examples](https://github.com/k2-fsa/sherpa-onnx/tree/master/flutter-examples)

---

�� 恭喜！您已經成功整合了語言辨識功能！ 