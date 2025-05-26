// Copyright (c)  2024  Xiaomi Corporation
import 'dart:ffi';
import 'package:ffi/ffi.dart';

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
  });

  @override
  String toString() {
    return 'SpokenLanguageIdentificationResult(language: $language)';
  }

  final String language;
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

  /// Compute the language of the given stream
  SpokenLanguageIdentificationResult compute(OfflineStream stream) {
    final resultPtr = SherpaOnnxBindings.spokenLanguageIdentificationCompute
            ?.call(ptr, stream.ptr) ??
        nullptr;

    if (resultPtr == nullptr) {
      return const SpokenLanguageIdentificationResult(language: 'unknown');
    }

    final langPtr = resultPtr.ref.lang;
    final language = langPtr.toDartString();

    SherpaOnnxBindings.destroySpokenLanguageIdentificationResult
        ?.call(resultPtr);

    return SpokenLanguageIdentificationResult(language: language);
  }

  Pointer<SherpaOnnxSpokenLanguageIdentification> ptr;
}
