---
name: slide-image-from-template
description: >
  ユーザーのテキスト内容と、テンプレート画像(1枚)を入力として、
  テンプレのレイアウト/配色/雰囲気を維持した「一枚絵のスライド画像(PNG)」を生成する。
  ユーザーが「スライドっぽい1枚画像がほしい」かつ「テンプレ画像を使いたい」と言っているときだけ使う。
  複数枚スライド、PPTX生成、テンプレ無しの画像生成には使わない。
---

# 目的
テンプレ画像を土台にして、指定テキストを読みやすい “一枚スライド” として配置したPNGを生成する。

## 入力
- ユーザーのテキスト（タイトル/要点/箇条書き等）
- テンプレート画像（1枚）

## 出力
- PNG画像（デフォルト: ./out/slide.png）
- `--provider both` 時は `./out/slide.openai.png` と `./out/slide.gemini.png`

# 実行の流れ
1. ユーザーのテキストを「タイトル + 要点（3〜6個）」程度に要約し、情報量を整える
2. 画像編集（Images Edit）でテンプレ画像をベースに使い、レイアウトを最大限維持したまま文字を配置する
3. 可読性（文字サイズ・コントラスト）を最優先し、装飾の追加は必要最小限にする
4. 出力サイズの制限があるため、必要なら生成後に16:9等へセンタークロップする

# ルール（重要）
- テンプレの構図、色、余白、装飾はできる限り維持する（input_fidelity=high）
- 文字は大きく、読みやすいコントラストにする
- 日本語入力は日本語で整形する（見出し/箇条書き）
- 長文は要約して収める（詰め込み禁止）
- 新しいイラスト/アイコンの追加は基本しない（必要最小限のみ）

# 実行コマンド例
## 0) 自動実行（推奨）
```bash
scripts/run_from_input.sh
```

```bash
# 任意の入力ファイルを指定（.txt/.md など）
scripts/run_from_input.sh ./my_input.md
```

```bash
# Geminiで生成
scripts/run_from_input.sh ./my_input.md --provider gemini
```

```bash
# OpenAI/Geminiを同時生成して比較
scripts/run_from_input.sh ./my_input.md --provider both --out ./out/slide.png
```

- 既定入力: `./input.txt`
- 既定テンプレ: `./assets/template.png`
- 既定出力: `./out/slide.png`
- 入力は `--input ./path/to/file` または位置引数 `scripts/run_from_input.sh ./path/to/file` で上書き可能
- プロバイダは `--provider openai|gemini|both`（既定: `openai`）
- OpenAI選択時、依存（`openai`, `pillow`）が無ければ自動で `pip install --user -r requirements.txt` を実行
- APIキーは環境変数、または `./.env` で指定可能
  - OpenAI: `OPENAI_API_KEY=...`
  - Gemini: `GEMINI_API_KEY=...`

## 1) 直接テキスト指定
python scripts/render_slide.py \
  --text "タイトル：生成AI導入の全体像\n- 現状課題\n- 解決アプローチ\n- 期待効果\n- 次アクション" \
  --template "assets/template.png" \
  --out "out/slide.png" \
  --aspect "16:9"

## 2) テキストファイルから読み込み（長文におすすめ）
python scripts/render_slide.py \
  --text "$(cat input.txt)" \
  --template "assets/template.png" \
  --out "out/slide.png" \
  --aspect "16:9"

# 使わないケース
- 複数枚のスライドが必要（PPTX生成など別手段）
- テンプレ画像が提供されていない
- スライドではなく写真/イラスト生成が主目的

# 注意
- OpenAI使用時は `OPENAI_API_KEY`、Gemini使用時は `GEMINI_API_KEY` を設定してください
- 出力サイズは API の制約により固定候補から選びます（生成後にクロップで 16:9 を作ります）
- DNS/ネットワーク制限環境では API 呼び出しに失敗します（OpenAI: `api.openai.com` / Gemini: `generativelanguage.googleapis.com`）
