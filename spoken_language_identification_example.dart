// Copyright (c)  2024  Xiaomi Corporation
// 語言識別 (Spoken Language Identification) 使用範例

import 'dart:io';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

void main() async {
  // 初始化 sherpa_onnx 綁定
  sherpa_onnx.initBindings();

  // 設定 Whisper 模型配置
  final whisperConfig = sherpa_onnx.SpokenLanguageIdentificationWhisperConfig(
    encoder: './models/sherpa-onnx-whisper-tiny/tiny-encoder.int8.onnx',
    decoder: './models/sherpa-onnx-whisper-tiny/tiny-decoder.int8.onnx',
    tailPaddings: 1000, // 尾部填充，預設為 1000
  );

  // 設定語言識別配置
  final config = sherpa_onnx.SpokenLanguageIdentificationConfig(
    whisper: whisperConfig,
    numThreads: 1, // 執行緒數量
    debug: true, // 是否開啟除錯模式
    provider: 'cpu', // 運算提供者：'cpu' 或 'gpu'
  );

  // 創建語言識別器
  final slid = sherpa_onnx.SpokenLanguageIdentification(config: config);

  // 測試音訊檔案列表
  final testFiles = [
    './test_wavs/en-english.wav',
    './test_wavs/zh-chinese.wav',
    './test_wavs/de-german.wav',
    './test_wavs/es-spanish.wav',
    './test_wavs/fr-french.wav',
    './test_wavs/ja-japanese.wav',
    './test_wavs/ko-korean.wav',
  ];

  print('開始語言識別測試...\n');

  // 處理每個測試檔案
  for (final filename in testFiles) {
    try {
      // 檢查檔案是否存在
      if (!File(filename).existsSync()) {
        print('警告：檔案不存在 - $filename');
        continue;
      }

      print('處理檔案: $filename');

      // 讀取音訊檔案
      final waveData = sherpa_onnx.readWave(filename);

      if (waveData.samples.isEmpty) {
        print('錯誤：無法讀取音訊檔案 - $filename');
        continue;
      }

      print('  音訊資訊: ${waveData.samples.length} 樣本, ${waveData.sampleRate} Hz');

      // 創建離線串流
      final stream = slid.createStream();

      // 將音訊資料送入串流
      stream.acceptWaveform(
        samples: waveData.samples,
        sampleRate: waveData.sampleRate,
      );

      // 執行語言識別
      final result = slid.compute(stream);

      // 顯示結果
      print('  識別語言: ${result.language}');
      print('  語言名稱: ${getLanguageName(result.language)}');
      print('---');

      // 釋放串流記憶體
      stream.free();
    } catch (e) {
      print('處理檔案 $filename 時發生錯誤: $e');
    }
  }

  // 釋放語言識別器記憶體
  slid.free();
  print('語言識別測試完成！');
}

/// 將語言代碼轉換為語言名稱
String getLanguageName(String languageCode) {
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

/// 簡化版本的語言識別函數
Future<String> identifyLanguage(String audioFilePath) async {
  // 初始化綁定
  sherpa_onnx.initBindings();

  // 設定配置
  final whisperConfig = sherpa_onnx.SpokenLanguageIdentificationWhisperConfig(
    encoder: './models/sherpa-onnx-whisper-tiny/tiny-encoder.int8.onnx',
    decoder: './models/sherpa-onnx-whisper-tiny/tiny-decoder.int8.onnx',
  );

  final config = sherpa_onnx.SpokenLanguageIdentificationConfig(
    whisper: whisperConfig,
    numThreads: 1,
    debug: false,
    provider: 'cpu',
  );

  // 創建識別器
  final slid = sherpa_onnx.SpokenLanguageIdentification(config: config);

  try {
    // 讀取音訊
    final waveData = sherpa_onnx.readWave(audioFilePath);

    // 創建串流並處理
    final stream = slid.createStream();
    stream.acceptWaveform(
      samples: waveData.samples,
      sampleRate: waveData.sampleRate,
    );

    // 執行識別
    final result = slid.compute(stream);

    // 清理資源
    stream.free();
    slid.free();

    return result.language;
  } catch (e) {
    slid.free();
    throw Exception('語言識別失敗: $e');
  }
}

/// 批次處理多個音訊檔案的語言識別
Future<Map<String, String>> batchIdentifyLanguages(
    List<String> audioFiles) async {
  sherpa_onnx.initBindings();

  final whisperConfig = sherpa_onnx.SpokenLanguageIdentificationWhisperConfig(
    encoder: './models/sherpa-onnx-whisper-tiny/tiny-encoder.int8.onnx',
    decoder: './models/sherpa-onnx-whisper-tiny/tiny-decoder.int8.onnx',
  );

  final config = sherpa_onnx.SpokenLanguageIdentificationConfig(
    whisper: whisperConfig,
    numThreads: 1,
    debug: false,
    provider: 'cpu',
  );

  final slid = sherpa_onnx.SpokenLanguageIdentification(config: config);
  final results = <String, String>{};

  try {
    for (final audioFile in audioFiles) {
      if (!File(audioFile).existsSync()) {
        results[audioFile] = 'file_not_found';
        continue;
      }

      try {
        final waveData = sherpa_onnx.readWave(audioFile);
        final stream = slid.createStream();

        stream.acceptWaveform(
          samples: waveData.samples,
          sampleRate: waveData.sampleRate,
        );

        final result = slid.compute(stream);
        results[audioFile] = result.language;

        stream.free();
      } catch (e) {
        results[audioFile] = 'error: $e';
      }
    }
  } finally {
    slid.free();
  }

  return results;
}
