# apt-cache-apps

Ubuntu向けaptキャッシュサーバー（apt-cacher-ng）のKubernetesマニフェスト

## 概要

このリポジトリは、Kubernetes上でapt-cacher-ngを冗長化構成でデプロイするためのマニフェストを提供します。Argo CDによる継続的デプロイに対応しており、Kustomizeを使用した構成管理が可能です。

## 機能

- StatefulSetによる冗長化構成（デフォルト2レプリカ）
- Pod単位のアンチアフィニティによるノード分散配置
- Pod毎に専用のPersistent Volumeを使用
- MetalLBによるLoadBalancer Serviceでの固定IP割り当て
- PodDisruptionBudgetによる高可用性の確保
- Argo CDによる自動同期・自動プルーニング

## ディレクトリ構成

```
.
├── base/
│   ├── namespace.yaml       # Namespace定義
│   ├── configmap.yaml       # apt-cacher-ng設定ファイル
│   ├── statefulset.yaml     # StatefulSet定義
│   ├── service.yaml         # LoadBalancer Service
│   ├── pdb.yaml             # PodDisruptionBudget
│   └── kustomization.yaml   # Base Kustomization
├── overlays/
│   └── prod/
│       └── kustomization.yaml  # Production環境用オーバーレイ
└── argocd/
    └── application.yaml     # Argo CD Application定義
```

## 前提条件

- Kubernetes v1.33以降
- MetalLB（LoadBalancer Serviceの固定IP割り当て用）
- ストレージクラス（TrueNAS/NFSなど、RWO対応）
- Argo CD（Pull型デプロイを使用する場合）

## デプロイ方法

### 事前準備

以下の変数を環境に合わせて編集してください：

**base/statefulset.yaml**
- `image`: コンテナイメージ（例: `ghcr.io/<org>/apt-cacher-ng:stable`）
- `storageClassName`: ストレージクラス名（例: `truenas-nfs-csi`）
- `storage`: PVCサイズ（例: `300Gi`）

**base/configmap.yaml**
- `CacheDirSize`: キャッシュディレクトリサイズ（GB単位、例: `300`）

**base/service.yaml**
- `metallb.universe.tf/loadBalancerIPs`: MetalLBで割り当てる固定IP（例: `10.0.0.10`）

**overlays/prod/kustomization.yaml**
- `count`: レプリカ数（例: `2`）

**argocd/application.yaml**
- `repoURL`: GitリポジトリURL
- `targetRevision`: ブランチ名（例: `main`）
- `path`: マニフェストのパス（例: `overlays/prod`）

### Argo CDを使用したデプロイ

```bash
kubectl apply -f argocd/application.yaml
```

Argo CDが自動的にGitリポジトリを監視し、変更を検知して同期します。

### kubectlを使用した手動デプロイ

```bash
# マニフェストの検証
kubectl kustomize overlays/prod

# デプロイ
kubectl apply -k overlays/prod

# 状態確認
kubectl get all -n apt-cache
kubectl get pvc -n apt-cache
```

## 使用方法

### クライアント側の設定

デプロイ後、Ubuntuクライアントから以下のように設定します：

```bash
# /etc/apt/apt.conf.d/00aptproxy を作成
echo 'Acquire::http::Proxy "http://10.0.0.10:3142";' | sudo tee /etc/apt/apt.conf.d/00aptproxy

# テスト
sudo apt update
```

### キャッシュ統計の確認

ブラウザまたはcurlで以下にアクセス：

```bash
curl http://10.0.0.10:3142/acng-report.html
```

## カスタマイズ

### レプリカ数の変更

`overlays/prod/kustomization.yaml`:

```yaml
replicas:
- name: apt-cacher-ng
  count: 3  # 3に変更
```

### ConfigMapの上書き

`overlays/prod/kustomization.yaml`にconfigMapGeneratorを追加：

```yaml
configMapGenerator:
- name: apt-cacher-ng-config
  behavior: replace
  files:
  - acng.conf
```

### リソース制限の変更

`overlays/prod/`にパッチファイルを作成し、kustomization.yamlに追加：

```yaml
patches:
- path: statefulset-resources.yaml
```

## トラブルシューティング

### Podが起動しない

```bash
# Pod状態確認
kubectl get pods -n apt-cache

# ログ確認
kubectl logs -n apt-cache apt-cacher-ng-0

# イベント確認
kubectl describe pod -n apt-cache apt-cacher-ng-0
```

### PVCがバインドされない

```bash
# PVC状態確認
kubectl get pvc -n apt-cache

# StorageClassの確認
kubectl get storageclass

# PVC詳細確認
kubectl describe pvc -n apt-cache cache-apt-cacher-ng-0
```

### LoadBalancer IPが割り当てられない

```bash
# Service状態確認
kubectl get svc -n apt-cache

# MetalLBのログ確認
kubectl logs -n metallb-system -l component=controller
```

## 監視

### ヘルスチェック

StatefulSetには以下のProbeが設定されています：

- **Liveness Probe**: `/acng-report.html`へのHTTP GET（30秒後から10秒間隔）
- **Readiness Probe**: `/acng-report.html`へのHTTP GET（10秒後から5秒間隔）

### メトリクス

apt-cacher-ngはPrometheusメトリクスを直接公開しませんが、以下の方法で監視可能：

1. `/acng-report.html`をスクレイピング
2. ログベースの監視
3. PVCの使用量監視

## ライセンス

このプロジェクトのマニフェストはMITライセンスの下で提供されます。apt-cacher-ng自体のライセンスは別途確認してください。