#!/bin/bash
set -euo pipefail

MODELS_DIR="$(cd "$(dirname "$0")/.." && pwd)/MediaPipeIODemo/Resources/Models"
mkdir -p "$MODELS_DIR"

download() {
  local url="$1"
  local dest="$2"
  if [ -f "$dest" ]; then
    echo "INFO: $(basename "$dest") already exists, skipping."
  else
    echo "Downloading $(basename "$dest")..."
    curl -fL -o "$dest" "$url"
  fi
}

# Same three model bundles the Android sibling app uses — .litertlm/.task bundles are a
# cross-platform format, so these are the identical files, just fetched into an iOS resource dir.
download "https://storage.googleapis.com/mediapipe-models/text_summarizer/gemma_200m/1/summarization_quant_200m_2modes.litertlm" "$MODELS_DIR/summarization_quant_200m_2modes.litertlm"
download "https://storage.googleapis.com/mediapipe-models/text_proofreader/gemma_200m/1/proofread_quant_200m.litertlm" "$MODELS_DIR/proofread_quant_200m.litertlm"
download "https://storage.googleapis.com/mediapipe-models/text_embedder/embedding_gemma/int4int8/latest/embedding_gemma.task" "$MODELS_DIR/embedding_gemma.task"

echo "All models ready in $MODELS_DIR"
