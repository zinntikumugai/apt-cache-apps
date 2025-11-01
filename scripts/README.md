# APT Proxy Auto-Detect

APT用のプロキシ自動検出スクリプトとインストーラー

## クイックインストール

```bash
# GitHubから直接インストール
curl -fsSL https://raw.githubusercontent.com/zinntikumugai/apt-cache-apps/master/scripts/install.sh | sudo bash
```

## カスタムインストール

```bash
# 環境変数で設定をカスタマイズ
export ALT_HOSTS="apt-cache.example.com:3142,10.0.0.20:3142"
export APT_VIP="172.16.99.17"
export APT_PORT="3142"
export APT_TIMEOUT_SEC="2"

curl -fsSL https://raw.githubusercontent.com/zinntikumugai/apt-cache-apps/master/scripts/install.sh | sudo -E bash
```

## 動作確認

```bash
# プロキシ検出スクリプトを直接実行
/usr/local/bin/apt-proxy-autodetect

# APTでテスト
sudo apt-get update
```

## アンインストール

```bash
curl -fsSL https://raw.githubusercontent.com/zinntikumugai/apt-cache-apps/master/scripts/uninstall.sh | sudo bash
```

## 設定

### 優先順位

1. **ALT_HOSTS** (プライマリ): `apt-cacher.service.z1n.in:3142` (デフォルト)
2. **VIP** (フォールバック): `172.16.99.17:3142`
3. **DIRECT** (最終): プロキシなし

### 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `ALT_HOSTS` | `apt-cacher.service.z1n.in:3142` | プライマリプロキシ (カンマ区切り) |
| `APT_VIP` | `172.16.99.17` | フォールバックVIP |
| `APT_PORT` | `3142` | フォールバックポート |
| `APT_TIMEOUT_SEC` | `1` | 接続タイムアウト (秒) |
| `DETECT_PATH` | `/usr/local/bin/apt-proxy-autodetect` | 検出スクリプトパス |
| `APT_CONF_PATH` | `/etc/apt/apt.conf.d/00proxy-auto` | APT設定ファイルパス |

## cloud-init

```yaml
#cloud-config
runcmd:
  - curl -fsSL https://raw.githubusercontent.com/zinntikumugai/apt-cache-apps/master/scripts/install.sh | bash
```

詳細な例: [cloud-init-proxy-auto.yaml](./cloud-init-proxy-auto.yaml)
