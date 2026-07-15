#!/usr/bin/env bash
# HEXAGAME ブラウザ版 ビルドスクリプト（GitHub Actions ubuntu-latest 上で実行）
#
# 役割: genova699/HEXAGAME の最新 main を取得し、Godot 4.6.1 で Web(HTML5) 書き出しして
#       ./dist に出力する。ここがビルドの本体で、ワークフロー(.yml)は「これを呼ぶだけ」。
#       調整は基本このスクリプトを直せば済む（.yml は触らなくてよい）。
#
# 必要な環境変数:
#   SRC_TOKEN … genova699/HEXAGAME(private) を読める GitHub トークン（Secret から渡す）
set -euo pipefail

# ───────── 設定 ─────────
GODOT_VERSION="4.6.1-stable"          # エディタ本体＋テンプレのバージョン（両者一致が必須）
TPL_VERSION="4.6.1.stable"            # export_templates の設置ディレクトリ名（x.y.z.status 形式）
SRC_OWNER_REPO="genova699/HEXAGAME"   # ソース（ゲーム本体）
SRC_BRANCH="main"
PROJECT_SUBDIR="hex_strategy_game_20260615"   # リポジトリ内の Godot プロジェクト直下
OUT_DIR="${GITHUB_WORKSPACE:-$PWD}/dist"
WORK="${RUNNER_TEMP:-/tmp}/hexbuild"

rm -rf "$WORK" "$OUT_DIR"; mkdir -p "$WORK" "$OUT_DIR"

# ───────── 1. Godot 本体＋書き出しテンプレを取得 ─────────
echo "::group::Download Godot ${GODOT_VERSION}"
cd "$WORK"
curl -fSL -o godot.zip \
  "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
unzip -q godot.zip
GODOT_BIN="$WORK/Godot_v${GODOT_VERSION}_linux.x86_64"
chmod +x "$GODOT_BIN"
curl -fSL -o templates.tpz \
  "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
unzip -q templates.tpz     # -> ./templates/ 以下に web_release.zip 等が展開される
mkdir -p "$HOME/.local/share/godot/export_templates/${TPL_VERSION}"
mv templates/* "$HOME/.local/share/godot/export_templates/${TPL_VERSION}/"
echo "::endgroup::"

# ───────── 2. ゲーム本体を取得 ─────────
echo "::group::Clone ${SRC_OWNER_REPO}@${SRC_BRANCH}"
AUTH=""
if [ -n "${SRC_TOKEN:-}" ]; then AUTH="x-access-token:${SRC_TOKEN}@"; fi
git clone --depth 1 --branch "$SRC_BRANCH" \
  "https://${AUTH}github.com/${SRC_OWNER_REPO}.git" "$WORK/src" 2>&1 | sed "s#${SRC_TOKEN:-__none__}#***#g"
PROJ="$WORK/src/${PROJECT_SUBDIR}"
[ -f "$PROJ/project.godot" ] || { echo "ERROR: project.godot not found at $PROJ"; exit 1; }
echo "::endgroup::"

# ───────── 3. レンダラを gl_compatibility に差し替え（Web は Vulkan 非対応） ─────────
echo "::group::Patch renderer -> gl_compatibility"
python3 - "$PROJ/project.godot" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('"Forward Plus"', '"GL Compatibility"')
if 'renderer/rendering_method' not in s:
    s = s.replace('[rendering]\n',
                  '[rendering]\n\nrenderer/rendering_method="gl_compatibility"\n'
                  'renderer/rendering_method.mobile="gl_compatibility"\n', 1)
open(p, 'w', encoding='utf-8').write(s)
print("patched project.godot")
PY
echo "::endgroup::"

# ───────── 4. インポート（初回はエラーが出ても続行） ─────────
echo "::group::Import"
"$GODOT_BIN" --headless --path "$PROJ" --import 2>&1 | tail -30 || true
echo "::endgroup::"

# ───────── 5. Web 書き出し ─────────
echo "::group::Export Web"
"$GODOT_BIN" --headless --path "$PROJ" --export-release "Web" "$OUT_DIR/index.html" 2>&1 | tail -40
echo "::endgroup::"

# ───────── 6. Pages 用の仕上げ・検証 ─────────
touch "$OUT_DIR/.nojekyll"     # _ で始まるファイルも配信させる／Jekyll を通さない
[ -f "$OUT_DIR/index.html" ] || { echo "ERROR: index.html が生成されていません"; exit 1; }
[ -f "$OUT_DIR/index.wasm" ] || { echo "ERROR: index.wasm が生成されていません（書き出し失敗の可能性）"; exit 1; }
echo "----- dist -----"; ls -la "$OUT_DIR"
echo "Build OK: $(du -sh "$OUT_DIR" | cut -f1)"
