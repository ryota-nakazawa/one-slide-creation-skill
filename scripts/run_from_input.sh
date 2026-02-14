#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

INPUT_PATH="${SKILL_DIR}/input.txt"
TEMPLATE_PATH="${SKILL_DIR}/assets/template.png"
OUT_PATH="${SKILL_DIR}/out/slide.png"
ASPECT="16:9"
PROVIDER="openai"
OPENAI_MODEL="gpt-image-1.5"
GEMINI_MODEL="gemini-3-pro-image-preview"
NO_INSTALL="0"
INPUT_EXPLICIT="0"

print_usage() {
  cat <<EOF
Usage:
  $(basename "$0") [text_file] [--provider openai|gemini|both] [--template PATH] [--out PATH] [--aspect W:H] [--no-install]
  $(basename "$0") --input PATH [--provider openai|gemini|both] [--template PATH] [--out PATH] [--aspect W:H] [--no-install]

Examples:
  $(basename "$0")
  $(basename "$0") ./notes.txt
  $(basename "$0") ./notes.txt --provider gemini
  $(basename "$0") ./notes.txt --provider both --out ./out/compare.png
  $(basename "$0") --input ./my_brief.md --out ./out/custom.png
EOF
}

check_dns() {
  local host="$1"
  if ! python3 -c "import socket,sys
try:
    socket.gethostbyname('${host}')
except Exception:
    sys.exit(1)
"; then
    echo "Cannot resolve ${host}. Check network/DNS or run outside restricted sandbox." >&2
    exit 1
  fi
}

out_for_provider() {
  local base="$1"
  local suffix="$2"
  if [[ "${PROVIDER}" != "both" ]]; then
    printf '%s\n' "${base}"
    return
  fi

  local dir
  local file
  local stem
  local ext

  dir="$(dirname "${base}")"
  file="$(basename "${base}")"
  if [[ "${file}" == *.* && "${file}" != .* ]]; then
    stem="${file%.*}"
    ext=".${file##*.}"
  else
    stem="${file}"
    ext=""
  fi

  printf '%s/%s.%s%s\n' "${dir}" "${stem}" "${suffix}" "${ext}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --input)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --input" >&2
        exit 1
      fi
      INPUT_PATH="$2"
      INPUT_EXPLICIT="1"
      shift 2
      ;;
    --provider)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --provider" >&2
        exit 1
      fi
      case "$2" in
        openai|gemini|both) ;;
        *)
          echo "Invalid --provider value: $2 (use openai|gemini|both)" >&2
          exit 1
          ;;
      esac
      PROVIDER="$2"
      shift 2
      ;;
    --template)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --template" >&2
        exit 1
      fi
      TEMPLATE_PATH="$2"
      shift 2
      ;;
    --out)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --out" >&2
        exit 1
      fi
      OUT_PATH="$2"
      shift 2
      ;;
    --aspect)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --aspect" >&2
        exit 1
      fi
      ASPECT="$2"
      shift 2
      ;;
    --openai-model)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --openai-model" >&2
        exit 1
      fi
      OPENAI_MODEL="$2"
      shift 2
      ;;
    --gemini-model)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --gemini-model" >&2
        exit 1
      fi
      GEMINI_MODEL="$2"
      shift 2
      ;;
    --no-install)
      NO_INSTALL="1"
      shift 1
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ "${INPUT_EXPLICIT}" == "1" ]]; then
        echo "Input file was already specified. Extra argument: $1" >&2
        exit 1
      fi
      INPUT_PATH="$1"
      INPUT_EXPLICIT="1"
      shift 1
      ;;
  esac
done

if [[ -z "${OPENAI_API_KEY:-}" && -f "${SKILL_DIR}/.env" ]]; then
  # shellcheck disable=SC1090
  source "${SKILL_DIR}/.env"
fi

export OPENAI_API_KEY GEMINI_API_KEY

if [[ ! -f "${INPUT_PATH}" ]]; then
  echo "Input file not found: ${INPUT_PATH}" >&2
  exit 1
fi

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  echo "Template file not found: ${TEMPLATE_PATH}" >&2
  exit 1
fi

if [[ "${PROVIDER}" == "openai" || "${PROVIDER}" == "both" ]]; then
  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "OPENAI_API_KEY is missing." >&2
    echo "Set environment variable or create ${SKILL_DIR}/.env with OPENAI_API_KEY=..." >&2
    exit 1
  fi

  if ! python3 -c "import importlib.util,sys;sys.exit(0 if importlib.util.find_spec('openai') and importlib.util.find_spec('PIL') else 1)"; then
    if [[ "${NO_INSTALL}" == "1" ]]; then
      echo "Python dependencies are missing (openai, pillow)." >&2
      exit 1
    fi
    python3 -m pip install --user -r "${SKILL_DIR}/requirements.txt"
  fi

  check_dns "api.openai.com"
fi

if [[ "${PROVIDER}" == "gemini" || "${PROVIDER}" == "both" ]]; then
  if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "GEMINI_API_KEY is missing." >&2
    echo "Set environment variable or create ${SKILL_DIR}/.env with GEMINI_API_KEY=..." >&2
    exit 1
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "node is required for Gemini mode but was not found." >&2
    exit 1
  fi

  check_dns "generativelanguage.googleapis.com"
fi

TEXT_CONTENT="$(cat "${INPUT_PATH}")"

if [[ "${PROVIDER}" == "openai" || "${PROVIDER}" == "both" ]]; then
  OPENAI_OUT="$(out_for_provider "${OUT_PATH}" "openai")"
  python3 "${SCRIPT_DIR}/render_slide.py" \
    --text "${TEXT_CONTENT}" \
    --template "${TEMPLATE_PATH}" \
    --out "${OPENAI_OUT}" \
    --aspect "${ASPECT}" \
    --model "${OPENAI_MODEL}"
  echo "Generated (openai): ${OPENAI_OUT}"
fi

if [[ "${PROVIDER}" == "gemini" || "${PROVIDER}" == "both" ]]; then
  GEMINI_OUT="$(out_for_provider "${OUT_PATH}" "gemini")"
  node "${SCRIPT_DIR}/render_slide_gemini.mjs" \
    --text "${TEXT_CONTENT}" \
    --template "${TEMPLATE_PATH}" \
    --out "${GEMINI_OUT}" \
    --aspect "${ASPECT}" \
    --model "${GEMINI_MODEL}"
  echo "Generated (gemini): ${GEMINI_OUT}"
fi
