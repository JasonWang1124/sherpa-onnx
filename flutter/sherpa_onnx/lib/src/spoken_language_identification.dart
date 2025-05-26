// Copyright (c)  2024  Xiaomi Corporation
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:math' as math;

import './offline_stream.dart';
import './sherpa_onnx_bindings.dart';
import './utils.dart';

class SpokenLanguageIdentificationWhisperConfig {
  const SpokenLanguageIdentificationWhisperConfig({
    required this.encoder,
    required this.decoder,
    this.tailPaddings = 1000,
  });

  factory SpokenLanguageIdentificationWhisperConfig.fromJson(
      Map<String, dynamic> json) {
    return SpokenLanguageIdentificationWhisperConfig(
      encoder: json['encoder'] as String,
      decoder: json['decoder'] as String,
      tailPaddings: json['tailPaddings'] as int? ?? 1000,
    );
  }

  @override
  String toString() {
    return 'SpokenLanguageIdentificationWhisperConfig(encoder: $encoder, decoder: $decoder, tailPaddings: $tailPaddings)';
  }

  Map<String, dynamic> toJson() => {
        'encoder': encoder,
        'decoder': decoder,
        'tailPaddings': tailPaddings,
      };

  final String encoder;
  final String decoder;
  final int tailPaddings;
}

class SpokenLanguageIdentificationConfig {
  const SpokenLanguageIdentificationConfig({
    required this.whisper,
    this.numThreads = 1,
    this.debug = true,
    this.provider = 'cpu',
  });

  factory SpokenLanguageIdentificationConfig.fromJson(
      Map<String, dynamic> json) {
    return SpokenLanguageIdentificationConfig(
      whisper: SpokenLanguageIdentificationWhisperConfig.fromJson(
          json['whisper'] as Map<String, dynamic>),
      numThreads: json['numThreads'] as int? ?? 1,
      debug: json['debug'] as bool? ?? true,
      provider: json['provider'] as String? ?? 'cpu',
    );
  }

  @override
  String toString() {
    return 'SpokenLanguageIdentificationConfig(whisper: $whisper, numThreads: $numThreads, debug: $debug, provider: $provider)';
  }

  Map<String, dynamic> toJson() => {
        'whisper': whisper.toJson(),
        'numThreads': numThreads,
        'debug': debug,
        'provider': provider,
      };

  final SpokenLanguageIdentificationWhisperConfig whisper;
  final int numThreads;
  final bool debug;
  final String provider;
}

class SpokenLanguageIdentificationResult {
  const SpokenLanguageIdentificationResult({
    required this.language,
    required this.confidence,
    this.allLanguageCodes,
    this.allConfidences,
  });

  @override
  String toString() {
    if (allLanguageCodes == null || allConfidences == null) {
      return 'SpokenLanguageIdentificationResult(language: $language, confidence: $confidence)';
    }

    // 顯示前3名結果
    final top3 = <String>[];
    final sortedIndices = List.generate(allLanguageCodes!.length, (i) => i)
      ..sort((a, b) => allConfidences![b].compareTo(allConfidences![a]));

    for (int i = 0; i < 3 && i < sortedIndices.length; i++) {
      final idx = sortedIndices[i];
      top3.add(
          '${allLanguageCodes![idx]}:${(allConfidences![idx] * 100).toStringAsFixed(1)}%');
    }

    return 'SpokenLanguageIdentificationResult(top: $language(${(confidence * 100).toStringAsFixed(1)}%), top3: [${top3.join(', ')}])';
  }

  /// 頂級預測的語言代碼 (向後相容)
  final String language;

  /// 頂級預測的信心度 (0-1 之間的機率值)
  final double confidence;

  /// 所有語言的語言代碼列表 (可選，僅在使用 computeWithAllProbabilities 時提供)
  final List<String>? allLanguageCodes;

  /// 所有語言的機率列表 (可選，僅在使用 computeWithAllProbabilities 時提供)
  final List<double>? allConfidences;

  /// 獲取特定語言的機率
  double? getProbabilityForLanguage(String languageCode) {
    if (allLanguageCodes == null || allConfidences == null) {
      return null;
    }

    for (int i = 0; i < allLanguageCodes!.length; i++) {
      if (allLanguageCodes![i] == languageCode) {
        return allConfidences![i];
      }
    }
    return null;
  }

  /// 獲取按機率排序的語言列表 (機率由高到低)
  List<MapEntry<String, double>> getSortedProbabilities() {
    if (allLanguageCodes == null || allConfidences == null) {
      return [MapEntry(language, confidence)];
    }

    final results = <MapEntry<String, double>>[];
    for (int i = 0; i < allLanguageCodes!.length; i++) {
      results.add(MapEntry(allLanguageCodes![i], allConfidences![i]));
    }

    results.sort((a, b) => b.value.compareTo(a.value));
    return results;
  }

  /// 獲取前 N 名語言預測
  List<MapEntry<String, double>> getTopN(int n) {
    final sorted = getSortedProbabilities();
    return sorted.take(n).toList();
  }

  /// 計算預測的熵值 (用於衡量模型的不確定性)
  double getEntropy() {
    if (allConfidences == null) {
      return 0.0;
    }

    double entropy = 0.0;
    for (final prob in allConfidences!) {
      if (prob > 0) {
        entropy -= prob * (prob.clamp(1e-10, 1.0)).logarithm;
      }
    }
    return entropy;
  }
}

extension DoubleExtension on double {
  double get logarithm => this <= 0 ? 0 : math.log(this);
}

class SpokenLanguageIdentification {
  SpokenLanguageIdentification.fromPtr({required this.ptr});

  SpokenLanguageIdentification._({required this.ptr});

  /// The user is responsible to call the SpokenLanguageIdentification.free()
  /// method of the returned instance to avoid memory leak.
  factory SpokenLanguageIdentification({
    required SpokenLanguageIdentificationConfig config,
  }) {
    final c = calloc<SherpaOnnxSpokenLanguageIdentificationConfig>();

    // Set up whisper config
    final encoderPtr = config.whisper.encoder.toNativeUtf8();
    final decoderPtr = config.whisper.decoder.toNativeUtf8();

    c.ref.whisper.encoder = encoderPtr;
    c.ref.whisper.decoder = decoderPtr;
    c.ref.whisper.tailPaddings = config.whisper.tailPaddings;

    // Set up main config
    c.ref.numThreads = config.numThreads;
    c.ref.debug = config.debug ? 1 : 0;

    final providerPtr = config.provider.toNativeUtf8();
    c.ref.provider = providerPtr;

    final ptr =
        SherpaOnnxBindings.createSpokenLanguageIdentification?.call(c) ??
            nullptr;

    calloc.free(providerPtr);
    calloc.free(decoderPtr);
    calloc.free(encoderPtr);
    calloc.free(c);

    return SpokenLanguageIdentification._(ptr: ptr);
  }

  void free() {
    SherpaOnnxBindings.destroySpokenLanguageIdentification?.call(ptr);
    ptr = nullptr;
  }

  /// The user has to invoke stream.free() on the returned instance
  /// to avoid memory leak
  OfflineStream createStream() {
    final p = SherpaOnnxBindings.spokenLanguageIdentificationCreateOfflineStream
            ?.call(ptr) ??
        nullptr;
    return OfflineStream(ptr: p);
  }

  /// Compute the language of the given stream (向後相容方法)
  SpokenLanguageIdentificationResult compute(OfflineStream stream) {
    final resultPtr = SherpaOnnxBindings.spokenLanguageIdentificationCompute
            ?.call(ptr, stream.ptr) ??
        nullptr;

    if (resultPtr == nullptr) {
      return const SpokenLanguageIdentificationResult(
          language: 'unknown', confidence: 0.0);
    }

    final langPtr = resultPtr.ref.lang;
    final language = langPtr.toDartString();
    final confidence = resultPtr.ref.confidence;

    SherpaOnnxBindings.destroySpokenLanguageIdentificationResult
        ?.call(resultPtr);

    return SpokenLanguageIdentificationResult(
      language: language,
      confidence: confidence,
    );
  }

  /// Compute the language with complete probability distribution for all languages
  SpokenLanguageIdentificationResult computeWithAllProbabilities(
      OfflineStream stream) {
    final resultPtr = SherpaOnnxBindings.spokenLanguageIdentificationCompute
            ?.call(ptr, stream.ptr) ??
        nullptr;

    if (resultPtr == nullptr) {
      return const SpokenLanguageIdentificationResult(
          language: 'unknown', confidence: 0.0);
    }

    try {
      final langPtr = resultPtr.ref.lang;
      final topLanguage = langPtr.toDartString();
      final topConfidence = resultPtr.ref.confidence;
      final numLanguages = resultPtr.ref.numLanguages;

      List<String>? allLanguageCodes;
      List<double>? allConfidences;

      // 解析所有語言代碼和機率
      if (numLanguages > 0 &&
          resultPtr.ref.allLangCodes != nullptr &&
          resultPtr.ref.allConfidences != nullptr) {
        allLanguageCodes = <String>[];
        allConfidences = <double>[];

        // 讀取語言代碼陣列 (以 NULL 結尾)
        for (int i = 0; i < numLanguages; i++) {
          final codePtr = resultPtr.ref.allLangCodes.elementAt(i).value;
          if (codePtr != nullptr) {
            allLanguageCodes.add(codePtr.toDartString());
          }
        }

        // 讀取機率陣列
        for (int i = 0; i < numLanguages; i++) {
          final confidence = resultPtr.ref.allConfidences.elementAt(i).value;
          allConfidences.add(confidence);
        }
      }

      return SpokenLanguageIdentificationResult(
        language: topLanguage,
        confidence: topConfidence,
        allLanguageCodes: allLanguageCodes,
        allConfidences: allConfidences,
      );
    } finally {
      SherpaOnnxBindings.destroySpokenLanguageIdentificationResult
          ?.call(resultPtr);
    }
  }

  Pointer<SherpaOnnxSpokenLanguageIdentification> ptr;
}
