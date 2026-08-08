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

# Text Summarizer and Text Proofreader (200m gemma .litertlm bundles) are pending public release —
# no download link exists yet, so only these two publicly-available bundles are fetched here.
download "https://storage.googleapis.com/mediapipe-models/text_embedder/embedding_gemma/int4int8/latest/embedding_gemma.task" "$MODELS_DIR/embedding_gemma.task"
download "https://storage.googleapis.com/mediapipe-models/interactive_segmenter_v2/magic_touch/int8/1/interactive_segmentation.task" "$MODELS_DIR/interactive_segmentation.task"

echo "All models ready in $MODELS_DIR"
