# slide-image-from-template

テンプレート画像をベースに、テキストから「スライド風の一枚絵（PNG）」を生成するスキルです。  
`OpenAI` と `Gemini` の両方に対応し、同条件で比較生成もできます。

## できること

- テンプレート画像の雰囲気を維持したまま文字を配置
- 入力テキスト（txt / md）を使って1枚のスライド画像を生成
- `--provider both` で OpenAI / Gemini の同時生成

## 前提環境

- macOS / Linux
- `python3`（OpenAI利用時に使用）
- `node`（Gemini利用時に使用）
- ネットワーク接続（APIアクセスが必要）

## セットアップ

1. このディレクトリに移動

```bash
cd /Users/ryota/Desktop/dev_test/slide-creation/.agents/skills/slide-image-from-template
```

2. APIキー設定ファイルを作成

```bash
cp .env.example .env
```

3. `.env` を編集してキーを設定

```dotenv
OPENAI_API_KEY=your_openai_api_key
GEMINI_API_KEY=your_gemini_api_key
```

- OpenAIだけ使うなら `OPENAI_API_KEY` のみでOK
- Geminiだけ使うなら `GEMINI_API_KEY` のみでOK

## 最短で使う

### 1) 入力テキストを用意

- 既定ファイル: `input.txt`
- 任意ファイル（例: `my_input.md`）も指定可能

### 2) 実行

OpenAI（デフォルト）:

```bash
scripts/run_from_input.sh
```

Gemini:

```bash
scripts/run_from_input.sh --provider gemini
```

両方生成して比較:

```bash
scripts/run_from_input.sh --provider both --out out/slide.png
```

`--provider both` の出力:

- `out/slide.openai.png`
- `out/slide.gemini.png`

## よく使う指定

任意の入力ファイルを使う:

```bash
scripts/run_from_input.sh ./my_input.md
```

入力ファイルと出力ファイルを明示:

```bash
scripts/run_from_input.sh --input ./my_input.md --out ./out/custom.png
```

テンプレート画像を変更:

```bash
scripts/run_from_input.sh --template ./assets/template.png
```

アスペクト比を変更:

```bash
scripts/run_from_input.sh --aspect 4:3
```

モデルを指定:

```bash
scripts/run_from_input.sh --provider openai --openai-model gpt-image-1.5
scripts/run_from_input.sh --provider gemini --gemini-model gemini-3-pro-image-preview
```

## 主要オプション

- `--provider openai|gemini|both`
- `--input <path>`
- `--template <path>`
- `--out <path>`
- `--aspect <w:h>`
- `--openai-model <model>`
- `--gemini-model <model>`
- `--no-install`（OpenAI用依存の自動インストールを無効化）

ヘルプ表示:

```bash
scripts/run_from_input.sh --help
```

## ファイル構成

- `scripts/run_from_input.sh`: 入口スクリプト（通常はこれを実行）
- `scripts/render_slide.py`: OpenAI画像編集実装
- `scripts/render_slide_gemini.mjs`: Gemini画像生成実装
- `assets/template.png`: テンプレート画像
- `input.txt`: 既定の入力テキスト
- `out/`: 出力先

## トラブルシュート

- `OPENAI_API_KEY is missing`:
  - `.env` に `OPENAI_API_KEY` を設定
- `GEMINI_API_KEY is missing`:
  - `.env` に `GEMINI_API_KEY` を設定
- `Cannot resolve api.openai.com` / `Cannot resolve generativelanguage.googleapis.com`:
  - ネットワークまたはDNS制限を確認
- `node is required for Gemini mode`:
  - Node.js をインストール
- OpenAI実行時に依存不足:
  - 通常は初回実行時に自動インストールされる
  - 手動の場合は `python3 -m pip install -r requirements.txt`

## 注意

- API利用料金が発生する場合があります
- 入力が長すぎる場合、モデル側で要約して配置されます
- 出力品質を上げたい場合は、入力を「タイトル + 要点（3〜6点）」程度に絞ると安定します
