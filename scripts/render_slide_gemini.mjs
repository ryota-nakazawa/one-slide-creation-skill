#!/usr/bin/env node
import fs from "fs";
import https from "https";
import path from "path";

const DEFAULT_MODEL = "gemini-3-pro-image-preview";
const DEFAULT_ASPECT = "16:9";

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (!a.startsWith("--")) continue;
    const k = a.slice(2);
    const v = argv[i + 1];
    if (typeof v === "undefined") {
      throw new Error(`Missing value for --${k}`);
    }
    args[k] = v;
    i += 1;
  }
  return args;
}

function buildPrompt(userText, aspect) {
  return [
    "あなたはプレゼン資料デザイナーです。",
    "添付のテンプレ画像のレイアウト・配色・余白・装飾・雰囲気を最大限維持して、",
    "日本語の一枚スライド画像として読みやすく再構成してください。",
    "",
    "必須要件:",
    "- 日本語で出力する（見出し + 箇条書き）",
    "- 長文は要約して、箇条書きは最大6点程度に整理",
    "- 文字は大きく、コントラストを確保して可読性を最優先",
    "- 新しいイラストやアイコンの追加は必要最小限",
    "- テンプレの図形・余白・構図をなるべく維持",
    `- 仕上がり比率は ${aspect} を意識`,
    "",
    "入力テキスト:",
    userText,
  ].join("\n");
}

function inferMimeType(imagePath) {
  const ext = path.extname(imagePath).toLowerCase();
  if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
  if (ext === ".webp") return "image/webp";
  return "image/png";
}

function requestGemini({ apiKey, model, prompt, templatePath }) {
  const endpoint = `/v1beta/models/${model}:generateContent`;
  const imageBuffer = fs.readFileSync(templatePath);
  const imageBase64 = imageBuffer.toString("base64");
  const mimeType = inferMimeType(templatePath);

  const requestData = {
    contents: [
      {
        parts: [
          { text: prompt },
          {
            inlineData: {
              mimeType,
              data: imageBase64,
            },
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 1.0,
      topP: 0.95,
      topK: 40,
      maxOutputTokens: 8192,
    },
  };

  const body = JSON.stringify(requestData);

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: "generativelanguage.googleapis.com",
        path: endpoint,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-goog-api-key": apiKey,
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => {
          data += chunk;
        });
        res.on("end", () => {
          try {
            const parsed = JSON.parse(data);
            if (res.statusCode && res.statusCode >= 400) {
              reject(
                new Error(
                  `Gemini API error (${res.statusCode}): ${JSON.stringify(parsed)}`
                )
              );
              return;
            }
            resolve(parsed);
          } catch (e) {
            reject(new Error(`Failed to parse Gemini response: ${e.message}`));
          }
        });
      }
    );

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function saveFirstImage(response, outPath) {
  const parts = response?.candidates?.[0]?.content?.parts || [];
  for (const part of parts) {
    if (part?.inlineData?.data) {
      const buf = Buffer.from(part.inlineData.data, "base64");
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      fs.writeFileSync(outPath, buf);
      return true;
    }
  }
  return false;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const text = args.text;
  const templatePath = args.template;
  const outPath = args.out;
  const aspect = args.aspect || DEFAULT_ASPECT;
  const model = args.model || DEFAULT_MODEL;

  if (!text || !templatePath || !outPath) {
    console.error(
      "Usage: node render_slide_gemini.mjs --text <text> --template <image> --out <output.png> [--aspect 16:9] [--model gemini-3-pro-image-preview]"
    );
    process.exit(1);
  }

  if (!fs.existsSync(templatePath)) {
    console.error(`Template not found: ${templatePath}`);
    process.exit(1);
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error("GEMINI_API_KEY is not set.");
    process.exit(1);
  }

  const prompt = buildPrompt(text, aspect);
  const response = await requestGemini({
    apiKey,
    model,
    prompt,
    templatePath,
  });

  const ok = saveFirstImage(response, outPath);
  if (!ok) {
    console.error("No image in Gemini response.");
    console.error(JSON.stringify(response, null, 2));
    process.exit(1);
  }

  console.log(outPath);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
