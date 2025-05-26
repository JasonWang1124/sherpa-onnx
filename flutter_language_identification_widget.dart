// Copyright (c)  2024  Xiaomi Corporation
// Flutter 語言識別 Widget 範例

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class LanguageIdentificationWidget extends StatefulWidget {
  const LanguageIdentificationWidget({super.key});

  @override
  State<LanguageIdentificationWidget> createState() =>
      _LanguageIdentificationWidgetState();
}

class _LanguageIdentificationWidgetState
    extends State<LanguageIdentificationWidget> {
  sherpa_onnx.SpokenLanguageIdentification? _slid;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _result = '';
  String _selectedFile = '';
  String _status = '準備就緒';

  @override
  void initState() {
    super.initState();
    _initializeLanguageIdentification();
  }

  @override
  void dispose() {
    _slid?.free();
    super.dispose();
  }

  Future<void> _initializeLanguageIdentification() async {
    try {
      setState(() {
        _status = '正在初始化語言識別器...';
      });

      // 初始化 sherpa_onnx 綁定
      sherpa_onnx.initBindings();

      // 設定 Whisper 模型配置
      // 注意：您需要將模型檔案放在適當的位置
      final whisperConfig =
          sherpa_onnx.SpokenLanguageIdentificationWhisperConfig(
        encoder: 'assets/models/tiny-encoder.int8.onnx',
        decoder: 'assets/models/tiny-decoder.int8.onnx',
        tailPaddings: 1000,
      );

      // 設定語言識別配置
      final config = sherpa_onnx.SpokenLanguageIdentificationConfig(
        whisper: whisperConfig,
        numThreads: 1,
        debug: false,
        provider: 'cpu',
      );

      // 創建語言識別器
      _slid = sherpa_onnx.SpokenLanguageIdentification(config: config);

      setState(() {
        _isInitialized = true;
        _status = '語言識別器已就緒';
      });
    } catch (e) {
      setState(() {
        _status = '初始化失敗: $e';
      });
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'flac', 'm4a'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = result.files.single.path!;
          _result = '';
        });
      }
    } catch (e) {
      _showError('選擇檔案時發生錯誤: $e');
    }
  }

  Future<void> _identifyLanguage() async {
    if (!_isInitialized || _slid == null || _selectedFile.isEmpty) {
      _showError('請先選擇音訊檔案');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = '正在識別語言...';
      _result = '';
    });

    try {
      // 讀取音訊檔案
      final waveData = sherpa_onnx.readWave(_selectedFile);

      if (waveData.samples.isEmpty) {
        throw Exception('無法讀取音訊檔案');
      }

      // 創建離線串流
      final stream = _slid!.createStream();

      // 將音訊資料送入串流
      stream.acceptWaveform(
        samples: waveData.samples,
        sampleRate: waveData.sampleRate,
      );

      // 執行語言識別
      final result = _slid!.compute(stream);

      // 釋放串流記憶體
      stream.free();

      setState(() {
        _result = result.language;
        _status = '識別完成';
      });
    } catch (e) {
      setState(() {
        _status = '識別失敗';
      });
      _showError('語言識別失敗: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getLanguageName(String languageCode) {
    final languageMap = {
      'en': '英語 (English)',
      'zh': '中文 (Chinese)',
      'de': '德語 (German)',
      'es': '西班牙語 (Spanish)',
      'fr': '法語 (French)',
      'ja': '日語 (Japanese)',
      'ko': '韓語 (Korean)',
      'ar': '阿拉伯語 (Arabic)',
      'ru': '俄語 (Russian)',
      'pt': '葡萄牙語 (Portuguese)',
      'it': '義大利語 (Italian)',
      'nl': '荷蘭語 (Dutch)',
      'pl': '波蘭語 (Polish)',
      'tr': '土耳其語 (Turkish)',
      'uk': '烏克蘭語 (Ukrainian)',
      'bg': '保加利亞語 (Bulgarian)',
      'fa': '波斯語 (Persian)',
      'unknown': '未知語言',
    };

    return languageMap[languageCode] ?? '未知語言 ($languageCode)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('語言識別'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 狀態顯示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '狀態',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 檔案選擇
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '音訊檔案',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_selectedFile.isNotEmpty)
                      Text(
                        '已選擇: ${_selectedFile.split('/').last}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _pickAudioFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('選擇音訊檔案'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 識別按鈕
            ElevatedButton.icon(
              onPressed:
                  _isInitialized && !_isProcessing && _selectedFile.isNotEmpty
                      ? _identifyLanguage
                      : null,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.translate),
              label: Text(_isProcessing ? '識別中...' : '開始語言識別'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            // 結果顯示
            if (_result.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '識別結果',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '語言代碼: $_result',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        '語言名稱: ${_getLanguageName(_result)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // 說明文字
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '使用說明',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. 確保已將 Whisper 模型檔案放在 assets/models/ 目錄下\n'
                      '2. 支援的音訊格式：WAV, MP3, FLAC, M4A\n'
                      '3. 建議使用 16kHz 單聲道音訊以獲得最佳效果\n'
                      '4. 音訊長度建議在 30 秒以內',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 主應用程式
class LanguageIdentificationApp extends StatelessWidget {
  const LanguageIdentificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '語言識別範例',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LanguageIdentificationWidget(),
    );
  }
}

void main() {
  runApp(const LanguageIdentificationApp());
}
