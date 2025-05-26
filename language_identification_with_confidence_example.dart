// Copyright (c)  2024  Xiaomi Corporation
// 語言識別帶信心度 (Spoken Language Identification with Confidence) 使用範例

import 'dart:io';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

void main() async {
  // 初始化 sherpa_onnx 綁定
  sherpa_onnx.initBindings();

  print('🚀 語言識別帶信心度範例啟動');
  print('=' * 50);

  // 檢查音訊檔案是否存在
  const audioFile = './test_audio.wav';
  if (!File(audioFile).existsSync()) {
    print('❌ 找不到音訊檔案: $audioFile');
    print('請提供一個有效的 16kHz 16-bit 單聲道 WAV 檔案');
    return;
  }

  // 設定 Whisper 模型配置
  final whisperConfig = sherpa_onnx.SpokenLanguageIdentificationWhisperConfig(
    encoder: './models/sherpa-onnx-whisper-tiny/tiny-encoder.int8.onnx',
    decoder: './models/sherpa-onnx-whisper-tiny/tiny-decoder.int8.onnx',
    tailPaddings: 1000, // 尾部填充，推薦值為 1000
  );

  // 設定語言識別配置
  final config = sherpa_onnx.SpokenLanguageIdentificationConfig(
    whisper: whisperConfig,
    numThreads: 1, // 執行緒數量
    debug: true, // 是否開啟除錯模式
    provider: 'cpu', // 運算提供者：'cpu' 或 'gpu'
  );

  print('📋 配置資訊:');
  print('   編碼器: ${whisperConfig.encoder}');
  print('   解碼器: ${whisperConfig.decoder}');
  print('   執行緒數: ${config.numThreads}');
  print('   運算提供者: ${config.provider}');
  print('');

  // 創建語言識別器
  final slid = sherpa_onnx.SpokenLanguageIdentification(config: config);

  try {
    // 讀取音訊檔案
    print('📂 正在讀取音訊檔案: $audioFile');
    final waveData = sherpa_onnx.readWave(audioFile);
    if (waveData.samples.isEmpty) {
      print('❌ 無法讀取音訊檔案或檔案為空');
      return;
    }

    print('🎵 音訊資訊:');
    print('   採樣率: ${waveData.sampleRate} Hz');
    print('   樣本數: ${waveData.samples.length}');
    print(
        '   時長: ${(waveData.samples.length / waveData.sampleRate).toStringAsFixed(2)} 秒');
    print();

    // 創建離線串流
    final stream = slid.createStream();

    // 接受音訊樣本
    stream.acceptWaveform(
        samples: waveData.samples, sampleRate: waveData.sampleRate);

    // 執行語言識別
    print('🔍 正在執行語言識別...');
    final result = slid.compute(stream);

    print('\n✅ 語言識別完成！');
    print('🌍 檢測到的語言: ${result.language}');
    print('📊 信心度分數: ${result.confidence.toStringAsFixed(3)}');

    // 解釋信心度分數
    String confidenceLevel;
    String confidenceEmoji;
    String confidenceDesc;

    if (result.confidence > 5.0) {
      confidenceLevel = '非常高';
      confidenceEmoji = '🟢';
      confidenceDesc = '模型對此預測非常有信心';
    } else if (result.confidence > 2.0) {
      confidenceLevel = '高';
      confidenceEmoji = '🟡';
      confidenceDesc = '模型對此預測有較高信心';
    } else if (result.confidence > 0.0) {
      confidenceLevel = '中等';
      confidenceEmoji = '🟠';
      confidenceDesc = '模型對此預測有中等信心';
    } else if (result.confidence > -2.0) {
      confidenceLevel = '低';
      confidenceEmoji = '🔴';
      confidenceDesc = '模型對此預測信心較低';
    } else {
      confidenceLevel = '非常低';
      confidenceEmoji = '🚫';
      confidenceDesc = '模型對此預測幾乎沒有信心，可能是噪音或未知語言';
    }

    print('🎯 信心度等級: $confidenceLevel $confidenceEmoji');
    print('💡 說明: $confidenceDesc');
    print();

    // 印出常見語言代碼說明
    final commonLanguages = {
      'en': '英語 (English)',
      'zh': '中文 (Chinese)',
      'ja': '日語 (Japanese)',
      'ko': '韓語 (Korean)',
      'es': '西班牙語 (Spanish)',
      'fr': '法語 (French)',
      'de': '德語 (German)',
      'it': '義大利語 (Italian)',
      'pt': '葡萄牙語 (Portuguese)',
      'ru': '俄語 (Russian)',
      'ar': '阿拉伯語 (Arabic)',
      'hi': '印地語 (Hindi)',
      'th': '泰語 (Thai)',
      'vi': '越南語 (Vietnamese)',
      'nl': '荷蘭語 (Dutch)',
      'pl': '波蘭語 (Polish)',
      'tr': '土耳其語 (Turkish)',
      'sv': '瑞典語 (Swedish)',
      'da': '丹麥語 (Danish)',
      'no': '挪威語 (Norwegian)',
      'fi': '芬蘭語 (Finnish)',
    };

    if (commonLanguages.containsKey(result.language)) {
      print('📝 語言說明: ${commonLanguages[result.language]}');
    } else {
      print('📝 檢測到較少見的語言代碼: ${result.language}');
    }

    // 根據信心度給出建議
    print('\n💡 建議:');
    if (result.confidence > 2.0) {
      print('   ✅ 識別結果可靠，可以信任此預測');
    } else if (result.confidence > 0.0) {
      print('   ⚠️  識別結果尚可，建議與其他證據結合判斷');
    } else {
      print('   ❌ 識別結果不太可靠，建議:');
      print('      - 檢查音訊品質是否良好');
      print('      - 確認音訊內容是否包含清晰的語音');
      print('      - 嘗試使用更長或更清晰的音訊樣本');
    }

    // 清理資源
    stream.free();
  } catch (e) {
    print('❌ 處理過程中發生錯誤: $e');
  } finally {
    // 釋放語言識別器
    slid.free();
    print('\n🏁 語言識別範例執行完成');
  }
}

// 範例輸出格式:
/*
🚀 語言識別帶信心度範例啟動
==================================================
📋 配置資訊:
   編碼器: ./models/sherpa-onnx-whisper-tiny/tiny-encoder.int8.onnx
   解碼器: ./models/sherpa-onnx-whisper-tiny/tiny-decoder.int8.onnx
   執行緒數: 1
   運算提供者: cpu

📂 正在讀取音訊檔案: ./test_audio.wav
🎵 音訊資訊:
   採樣率: 16000 Hz
   樣本數: 48000
   時長: 3.00 秒

🔍 正在執行語言識別...

✅ 語言識別完成！
🌍 檢測到的語言: en
📊 信心度分數: 6.234
🎯 信心度等級: 非常高 🟢
💡 說明: 模型對此預測非常有信心

📝 語言說明: 英語 (English)

💡 建議:
   ✅ 識別結果可靠，可以信任此預測

🏁 語言識別範例執行完成
*/
