#!/bin/bash

# sherpa-onnx Flutter 語言辨識模型下載腳本
# 使用方法: ./download_models.sh [模型類型]

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印帶顏色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 檢查必要工具
check_dependencies() {
    print_info "檢查必要工具..."
    
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        print_error "需要 wget 或 curl 來下載檔案"
        exit 1
    fi
    
    if ! command -v tar &> /dev/null; then
        print_error "需要 tar 來解壓檔案"
        exit 1
    fi
    
    print_success "所有必要工具已安裝"
}

# 下載檔案函數
download_file() {
    local url=$1
    local output=$2
    
    print_info "下載: $url"
    
    if command -v wget &> /dev/null; then
        wget -O "$output" "$url"
    elif command -v curl &> /dev/null; then
        curl -L -o "$output" "$url"
    else
        print_error "無法下載檔案，缺少 wget 或 curl"
        return 1
    fi
}

# 創建目錄結構
create_directories() {
    print_info "創建目錄結構..."
    mkdir -p models/whisper-lang-id
    mkdir -p models/whisper-tiny
    mkdir -p models/whisper-base
    mkdir -p models/whisper-small
}

# 下載 Whisper 語言辨識模型
download_whisper_lang_id() {
    print_info "下載 Whisper 語言辨識模型..."
    
    local model_dir="models/whisper-lang-id"
    local base_url="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models"
    
    # 下載 tiny 模型（推薦用於語言辨識）
    local model_name="sherpa-onnx-whisper-tiny"
    local archive_name="${model_name}.tar.bz2"
    
    if [ ! -f "$archive_name" ]; then
        download_file "$base_url/$archive_name" "$archive_name"
    else
        print_warning "檔案 $archive_name 已存在，跳過下載"
    fi
    
    print_info "解壓模型檔案..."
    tar -xf "$archive_name"
    
    # 移動檔案到正確位置
    if [ -d "$model_name" ]; then
        cp "$model_name"/*.onnx "$model_dir/"
        cp "$model_name"/*.txt "$model_dir/" 2>/dev/null || true
        rm -rf "$model_name"
        print_success "Whisper 語言辨識模型下載完成"
    else
        print_error "解壓失敗或目錄結構不正確"
        return 1
    fi
}

# 下載其他 Whisper 模型
download_whisper_model() {
    local model_size=$1
    print_info "下載 Whisper $model_size 模型..."
    
    local model_dir="models/whisper-$model_size"
    local base_url="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models"
    local model_name="sherpa-onnx-whisper-$model_size"
    local archive_name="${model_name}.tar.bz2"
    
    if [ ! -f "$archive_name" ]; then
        download_file "$base_url/$archive_name" "$archive_name"
    else
        print_warning "檔案 $archive_name 已存在，跳過下載"
    fi
    
    print_info "解壓模型檔案..."
    tar -xf "$archive_name"
    
    if [ -d "$model_name" ]; then
        cp "$model_name"/*.onnx "$model_dir/"
        cp "$model_name"/*.txt "$model_dir/" 2>/dev/null || true
        rm -rf "$model_name"
        print_success "Whisper $model_size 模型下載完成"
    else
        print_error "解壓失敗或目錄結構不正確"
        return 1
    fi
}

# 生成配置檔案
generate_config() {
    print_info "生成配置檔案..."
    
    cat > models/model_config.dart << EOF
// 自動生成的模型配置檔案
// 請根據您的需求修改路徑

class ModelConfig {
  // Whisper 語言辨識模型路徑
  static const String whisperLangIdEncoder = 'models/whisper-lang-id/encoder.onnx';
  static const String whisperLangIdDecoder = 'models/whisper-lang-id/decoder.onnx';
  
  // 其他 Whisper 模型路徑
  static const String whisperTinyEncoder = 'models/whisper-tiny/encoder.onnx';
  static const String whisperTinyDecoder = 'models/whisper-tiny/decoder.onnx';
  
  static const String whisperBaseEncoder = 'models/whisper-base/encoder.onnx';
  static const String whisperBaseDecoder = 'models/whisper-base/decoder.onnx';
  
  static const String whisperSmallEncoder = 'models/whisper-small/encoder.onnx';
  static const String whisperSmallDecoder = 'models/whisper-small/decoder.onnx';
}
EOF
    
    print_success "配置檔案已生成: models/model_config.dart"
}

# 清理臨時檔案
cleanup() {
    print_info "清理臨時檔案..."
    rm -f *.tar.bz2
    print_success "清理完成"
}

# 顯示使用說明
show_usage() {
    echo "使用方法: $0 [選項]"
    echo ""
    echo "選項:"
    echo "  lang-id    下載語言辨識專用模型（推薦）"
    echo "  tiny       下載 Whisper tiny 模型"
    echo "  base       下載 Whisper base 模型"
    echo "  small      下載 Whisper small 模型"
    echo "  all        下載所有模型"
    echo "  help       顯示此幫助信息"
    echo ""
    echo "範例:"
    echo "  $0 lang-id    # 只下載語言辨識模型"
    echo "  $0 all        # 下載所有模型"
}

# 主函數
main() {
    print_info "sherpa-onnx Flutter 語言辨識模型下載工具"
    print_info "============================================"
    
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    check_dependencies
    create_directories
    
    case $1 in
        "lang-id")
            download_whisper_lang_id
            ;;
        "tiny")
            download_whisper_model "tiny"
            ;;
        "base")
            download_whisper_model "base"
            ;;
        "small")
            download_whisper_model "small"
            ;;
        "all")
            download_whisper_lang_id
            download_whisper_model "tiny"
            download_whisper_model "base"
            download_whisper_model "small"
            ;;
        "help"|"-h"|"--help")
            show_usage
            exit 0
            ;;
        *)
            print_error "未知選項: $1"
            show_usage
            exit 1
            ;;
    esac
    
    generate_config
    cleanup
    
    print_success "所有操作完成！"
    print_info "模型檔案位於 models/ 目錄中"
    print_info "配置檔案: models/model_config.dart"
    print_info "請將 models/ 目錄複製到您的 Flutter 專案的 assets/ 目錄中"
}

# 執行主函數
main "$@" 