// Copyright (c)  2024  Xiaomi Corporation
// 語言識別所有機率分佈 (Spoken Language Identification with All Probabilities) 使用範例

import 'dart:io';
import 'dart:math' as math;
import 'flutter/sherpa_onnx/lib/sherpa_onnx.dart';

void main() async {
  print('🚀 語言識別完整機率分佈範例啟動');
  print('=' * 50);

  // 檢查命令行參數
  if (Platform.environment['SHERPA_ONNX_MODELS'] == null) {
    print('❌ 請設定環境變數 SHERPA_ONNX_MODELS 指向模型目錄');
    exit(1);
  }

  final modelDir = Platform.environment['SHERPA_ONNX_MODELS']!;
  print('📁 模型目錄: $modelDir');

  // 語言識別配置
  final config = SpokenLanguageIdentificationConfig(
    whisper: SpokenLanguageIdentificationWhisperConfig(
      encoder: '$modelDir/sherpa-onnx-whisper-small/small-encoder.onnx',
      decoder: '$modelDir/sherpa-onnx-whisper-small/small-decoder.onnx',
      tailPaddings: 1000,
    ),
    numThreads: 2,
    debug: true,
    provider: 'cpu',
  );

  print('⚙️  配置: ${config.toString()}');

  // 創建語言識別器
  final slid = SpokenLanguageIdentification(config: config);
  print('✅ 語言識別器創建成功');

  try {
    // 創建音訊流
    final stream = slid.createStream();
    print('📥 音訊流創建成功');

    // 這裡應該載入音訊數據到流中
    // stream.acceptWaveform(sampleRate: 16000, samples: audioSamples);
    print('🔊 (這裡應該載入音訊數據...)');

    // 使用新的帶完整機率分佈的方法進行語言識別
    print('\n🔍 開始語言識別 (包含完整機率分佈)...');
    final result = slid.computeWithAllProbabilities(stream);

    // 顯示基本結果
    print('\n📊 語言識別結果:');
    print('-' * 40);
    print(
        '🏆 頂級預測: ${result.language} (信心度: ${(result.confidence * 100).toStringAsFixed(2)}%)');

    // 檢查是否有完整的機率分佈
    if (result.allLanguageCodes != null && result.allConfidences != null) {
      print('📈 完整機率分佈:');
      print('   總語言數: ${result.allLanguageCodes!.length}');

      // 獲取按機率排序的結果
      final sortedResults = result.getSortedProbabilities();

      // 顯示前 15 名結果
      print('\n🥇 前 15 名語言預測:');
      for (int i = 0; i < math.min(15, sortedResults.length); i++) {
        final entry = sortedResults[i];
        final confidence = entry.value;
        final langCode = entry.key;

        String emoji = _getConfidenceEmoji(confidence);
        String bar = _getProgressBar(confidence);
        String displayName = _getLanguageDisplayName(langCode);

        print(
            '${(i + 1).toString().padLeft(2)}. $emoji ${langCode.padRight(3)} '
            '$bar ${(confidence * 100).toStringAsFixed(2)}% - $displayName');
      }

      // 統計分析
      print('\n📊 統計分析:');
      print('-' * 40);

      double totalConfidence =
          sortedResults.fold(0, (sum, entry) => sum + entry.value);
      double entropy = result.getEntropy();
      int highConfidenceCount =
          sortedResults.where((e) => e.value > 0.1).length;

      print('🔢 總機率和: ${totalConfidence.toStringAsFixed(6)} (應該約等於 1.0)');
      print('📈 熵值: ${entropy.toStringAsFixed(3)} (越低表示預測越確定)');
      print('🎯 高信心度語言數 (>10%): $highConfidenceCount');

      // 不確定性分析
      if (entropy > 2.0) {
        print('⚠️  高不確定性: 模型對此音訊的語言識別不太確定');
      } else if (entropy > 1.0) {
        print('ℹ️  中等確定性: 模型有幾個候選語言');
      } else {
        print('✅ 高確定性: 模型對預測結果很有信心');
      }

      // 特定語言查詢範例
      print('\n🔍 特定語言機率查詢:');
      final testLanguages = ['en', 'zh', 'ja', 'ko', 'es', 'fr', 'de'];
      for (final lang in testLanguages) {
        final prob = result.getProbabilityForLanguage(lang);
        if (prob != null) {
          print('   $lang: ${(prob * 100).toStringAsFixed(2)}%');
        }
      }

      // 前5名詳細分析
      print('\n🏅 前5名詳細分析:');
      final top5 = result.getTopN(5);
      for (int i = 0; i < top5.length; i++) {
        final entry = top5[i];
        final percentage = (entry.value * 100);
        final displayName = _getLanguageDisplayName(entry.key);

        String recommendation = '';
        if (percentage > 70) {
          recommendation = '強烈推薦';
        } else if (percentage > 30) {
          recommendation = '可考慮';
        } else if (percentage > 10) {
          recommendation = '可能候選';
        } else {
          recommendation = '不太可能';
        }

        print(
            '   ${i + 1}. ${entry.key} ($displayName): ${percentage.toStringAsFixed(2)}% - $recommendation');
      }
    } else {
      print('ℹ️  僅獲得基本預測結果 (使用舊版 API)');
    }

    // 清理資源
    stream.free();
    print('\n🧹 音訊流已釋放');
  } catch (e) {
    print('❌ 處理過程中發生錯誤: $e');
  } finally {
    // 釋放語言識別器
    slid.free();
    print('🏁 語言識別器已釋放');
    print('🎉 語言識別完整機率分佈範例執行完成');
  }
}

String _getConfidenceEmoji(double confidence) {
  if (confidence > 0.7) return '🟢';
  if (confidence > 0.3) return '🟡';
  if (confidence > 0.1) return '🟠';
  return '🔴';
}

String _getProgressBar(double confidence, {int width = 10}) {
  final filled = (confidence * width).round();
  final bar = '█' * filled + '░' * (width - filled);
  return '[$bar]';
}

String _getLanguageDisplayName(String langCode) {
  const languageNames = {
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
    'cs': '捷克語 (Czech)',
    'hu': '匈牙利語 (Hungarian)',
    'sk': '斯洛伐克語 (Slovak)',
    'sl': '斯洛維尼亞語 (Slovenian)',
    'hr': '克羅埃西亞語 (Croatian)',
    'bg': '保加利亞語 (Bulgarian)',
    'ro': '羅馬尼亞語 (Romanian)',
    'el': '希臘語 (Greek)',
    'he': '希伯來語 (Hebrew)',
    'fa': '波斯語 (Persian)',
    'ur': '烏爾都語 (Urdu)',
    'bn': '孟加拉語 (Bengali)',
    'ta': '泰米爾語 (Tamil)',
    'te': '泰盧固語 (Telugu)',
    'ml': '馬拉雅拉姆語 (Malayalam)',
    'kn': '卡納達語 (Kannada)',
    'gu': '古吉拉特語 (Gujarati)',
    'pa': '旁遮普語 (Punjabi)',
    'mr': '馬拉地語 (Marathi)',
    'ne': '尼泊爾語 (Nepali)',
    'si': '僧伽羅語 (Sinhala)',
    'my': '緬甸語 (Myanmar)',
    'km': '高棉語 (Khmer)',
    'lo': '寮語 (Lao)',
    'ka': '喬治亞語 (Georgian)',
    'am': '阿姆哈拉語 (Amharic)',
    'sw': '斯瓦希里語 (Swahili)',
    'zu': '祖魯語 (Zulu)',
    'af': '南非語 (Afrikaans)',
    'is': '冰島語 (Icelandic)',
    'mt': '馬爾他語 (Maltese)',
    'cy': '威爾斯語 (Welsh)',
    'ga': '愛爾蘭語 (Irish)',
    'eu': '巴斯克語 (Basque)',
    'ca': '加泰隆語 (Catalan)',
    'gl': '加利西亞語 (Galician)',
    'ast': '阿斯圖里亞語 (Asturian)',
    'br': '布列塔尼語 (Breton)',
    'oc': '奧克語 (Occitan)',
    'mk': '馬其頓語 (Macedonian)',
    'sq': '阿爾巴尼亞語 (Albanian)',
    'lv': '拉脫維亞語 (Latvian)',
    'lt': '立陶宛語 (Lithuanian)',
    'et': '愛沙尼亞語 (Estonian)',
    'be': '白俄羅斯語 (Belarusian)',
    'uk': '烏克蘭語 (Ukrainian)',
    'az': '亞塞拜然語 (Azerbaijani)',
    'kk': '哈薩克語 (Kazakh)',
    'ky': '吉爾吉斯語 (Kyrgyz)',
    'uz': '烏茲別克語 (Uzbek)',
    'tg': '塔吉克語 (Tajik)',
    'mn': '蒙古語 (Mongolian)',
    'bo': '藏語 (Tibetan)',
    'ug': '維吾爾語 (Uyghur)',
  };

  return languageNames[langCode] ?? '未知語言 ($langCode)';
}

// 範例輸出格式:
/*
🚀 語言識別完整機率分佈範例啟動
==================================================
📁 模型目錄: /path/to/models
⚙️  配置: SpokenLanguageIdentificationConfig(...)
✅ 語言識別器創建成功
📥 音訊流創建成功
🔊 (這裡應該載入音訊數據...)

🔍 開始語言識別 (包含完整機率分佈)...

📊 語言識別結果:
----------------------------------------
🏆 頂級預測: en (信心度: 85.32%)
📈 完整機率分佈:
   總語言數: 99

🥇 前 15 名語言預測:
 1. 🟢 en  [████████░░] 85.32% - 英語 (English)
 2. 🟡 zh  [██░░░░░░░░] 8.45% - 中文 (Chinese)
 3. 🟠 ja  [█░░░░░░░░░] 2.18% - 日語 (Japanese)
 4. 🔴 es  [░░░░░░░░░░] 1.32% - 西班牙語 (Spanish)
 5. 🔴 fr  [░░░░░░░░░░] 0.98% - 法語 (French)
 ... (更多結果)

📊 統計分析:
----------------------------------------
🔢 總機率和: 1.000000 (應該約等於 1.0)
📈 熵值: 0.892 (越低表示預測越確定)
🎯 高信心度語言數 (>10%): 1
✅ 高確定性: 模型對預測結果很有信心

🔍 特定語言機率查詢:
   en: 85.32%
   zh: 8.45%
   ja: 2.18%
   ko: 0.67%
   es: 1.32%
   fr: 0.98%
   de: 0.45%

🏅 前5名詳細分析:
   1. en (英語): 85.32% - 強烈推薦
   2. zh (中文): 8.45% - 可能候選
   3. ja (日語): 2.18% - 不太可能
   4. es (西班牙語): 1.32% - 不太可能
   5. fr (法語): 0.98% - 不太可能

🧹 音訊流已釋放
🏁 語言識別器已釋放
🎉 語言識別完整機率分佈範例執行完成
*/
