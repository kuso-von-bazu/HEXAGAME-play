# HEXAGAME-play — ブラウザで遊べる HEXAGAME

ヘックス戦略ゲーム **[genova699/HEXAGAME](https://github.com/genova699/HEXAGAME)** を、そのままブラウザで遊べるように自動ビルド・公開するためのリポジトリです。

## ▶ 遊ぶ

**https://kuso-von-bazu.github.io/HEXAGAME-play/**

（初回の公開後に有効になります。Ctrl+F5 で最新に更新できます）

## 仕組み（無人・自動）

このリポジトリの GitHub Actions が、**AI もローカルPCも使わず GitHub のクラウド上だけ**で次を自動実行します。

1. ゲーム本体 `genova699/HEXAGAME` の最新 `main` を取得
2. Godot 4.6.1 で Web(HTML5) 書き出し（Web 用にレンダラを gl_compatibility へ自動変換）
3. 成果物を GitHub Pages へ公開

これが以下のタイミングで走ります。

| きっかけ | 説明 |
|---|---|
| **毎時（cron）** | 本体を **誰が更新しても**、最大1時間で自動的に反映されます |
| **手動** | Actions 画面の「Run workflow」で即時ビルド |
| **push** | このリポジトリ（ビルド手順）を更新したときも再ビルド |

ビルドの中身は [`ci/build.sh`](ci/build.sh)、ワークフロー定義は `.github/workflows/deploy.yml`（内容は [`ci/deploy.yml`](ci/deploy.yml) と同一）です。

## 構成

```
ci/build.sh     … ビルド本体（Godot 取得 → 本体 clone → Web 書き出し → dist/ 出力）
ci/deploy.yml   … ワークフローの参照用コピー（.github/workflows/deploy.yml と同じ内容）
dist/           … 書き出し成果物（CI が生成。リポジトリには含めない）
```
