#!/usr/bin/env python3
import argparse
import base64
import os
from io import BytesIO
from pathlib import Path

from PIL import Image
from openai import OpenAI

# API上の横長候補（16:9は直指定できないため、生成後にクロップで合わせる）
DEFAULT_SIZE = "1536x1024"


def ensure_out_dir(out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)


def crop_to_aspect(img: Image.Image, aspect: str) -> Image.Image:
    """
    Center-crop to target aspect ratio.
    aspect example: "16:9", "4:3"
    """
    w, h = img.size
    a, b = aspect.split(":")
    target = float(a) / float(b)

    current = w / h
    if abs(current - target) < 1e-6:
        return img

    if current > target:
        # too wide -> crop width
        new_w = int(h * target)
        left = (w - new_w) // 2
        return img.crop((left, 0, left + new_w, h))
    else:
        # too tall -> crop height
        new_h = int(w / target)
        top = (h - new_h) // 2
        return img.crop((0, top, w, top + new_h))


def build_prompt(user_text: str) -> str:
    # 日本語で “テンプレ維持 + 可読性最優先 + 要約” を強める
    return f"""
あなたはプレゼン資料デザイナーです。
添付のテンプレ画像の「レイアウト・配色・余白・装飾・雰囲気」を最大限維持したまま、
以下のテキストを“日本語の一枚スライド画像”として読みやすく配置してください。

必須要件:
- 日本語で出力する（見出し + 箇条書き中心）
- 情報量は絞る：長文は要約して、最大でも箇条書き6点程度
- 文字は大きく、コントラストを強くして可読性を最優先
- テンプレの枠/帯/余白/区切りを活かして自然に収める
- 新しいイラストやアイコンは基本追加しない（必要最小限）
- “スライド1枚”として視認性を高くする（詰め込み禁止）
- 元の図形・矢印・アイコン位置をできる限り動かさない

入力テキスト:
{user_text}
""".strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--text", required=True, help="User input text for the slide")
    parser.add_argument("--template", required=True, help="Path to template image (png/jpg)")
    parser.add_argument("--out", default="./out/slide.png", help="Output PNG path")
    parser.add_argument("--model", default="gpt-image-1.5", help="Image model")
    parser.add_argument("--size", default=DEFAULT_SIZE, help='API size, e.g. "1536x1024"')
    parser.add_argument(
        "--aspect",
        default=None,
        help='Optional crop aspect like "16:9" (center-crop after generation)',
    )
    parser.add_argument("--quality", default="high", choices=["low", "medium", "high", "auto"])
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is not set. Example: export OPENAI_API_KEY='...'")


    template_path = Path(args.template)
    if not template_path.exists():
        raise SystemExit(f"Template not found: {template_path}")

    out_path = Path(args.out)
    ensure_out_dir(out_path)

    client = OpenAI(api_key=api_key)

    prompt = build_prompt(args.text)

    # 画像編集（テンプレ画像を土台にして編集）
    # input_fidelity="high" でテンプレの構図維持寄りにする
    with template_path.open("rb") as f:
        result = client.images.edit(
            model=args.model,
            image=[f],
            prompt=prompt,
            size=args.size,
            quality=args.quality,
            input_fidelity="high",
            output_format="png",
        )

    b64 = result.data[0].b64_json
    raw = base64.b64decode(b64)

    img = Image.open(BytesIO(raw)).convert("RGBA")

    if args.aspect:
        img = crop_to_aspect(img, args.aspect)

    img.save(out_path, format="PNG")
    print(str(out_path))


if __name__ == "__main__":
    main()
