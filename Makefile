.PHONY: help infra-init infra-plan infra-apply infra-destroy infra-output infra-fmt infra-validate \
        docker-build docker-push deploy deploy-staging swap rollback \
        app-run app-test app-logs \
        gen-questions gen-questions-check web-install web-dev web-build \
        fd-purge redis-cli db-connect slot-url

PROJECT  ?= webapp
ENV      ?= dev
ACR_NAME  = $(shell cd infra && terraform output -raw acr_name 2>/dev/null)
ACR_URL   = $(shell cd infra && terraform output -raw acr_login_server 2>/dev/null)
APP_NAME  = $(shell cd infra && terraform output -raw app_service_name 2>/dev/null)
RG_NAME   = $(shell cd infra && terraform output -raw resource_group_name 2>/dev/null)
IMAGE     = $(ACR_URL)/$(PROJECT):latest

help: ## ヘルプ表示
	@echo ""
	@echo "  Azure WebApp Monorepo - Make Targets"
	@echo "  ====================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ==================== Infra ====================

infra-init: ## Terraform 初期化
	cd infra && terraform init

infra-plan: ## Terraform 実行計画
	cd infra && terraform plan

infra-apply: ## Terraform 適用
	cd infra && terraform apply

infra-destroy: ## Terraform リソース削除
	cd infra && terraform destroy

infra-output: ## Terraform 出力値の表示
	cd infra && terraform output

infra-fmt: ## Terraform フォーマット
	cd infra && terraform fmt -recursive

infra-validate: ## Terraform 構文検証
	cd infra && terraform validate

# ==================== App ====================

app-run: web-build gen-questions ## ローカルでアプリ起動 (SPA+questions.json生成込み)
	cd app && go run .

app-test: ## アプリのテスト
	cd app && go test -v -race ./...

app-logs: ## App Service のライブログ表示
	az webapp log tail --name $(APP_NAME) --resource-group $(RG_NAME)

# ==================== AZ-104 学習アプリ ====================

gen-questions: ## AZ-104 Study Guide から questions.json を生成
	cd app && go run ./cmd/gen-questions -in ../docs/AZ-104_STUDY_GUIDE.md -out data/questions.json

gen-questions-check: ## questions.json が最新か検証 (CI用)
	cd app && go run ./cmd/gen-questions -in ../docs/AZ-104_STUDY_GUIDE.md -out data/questions.json -check

web-install: ## フロントエンド依存関係をインストール
	cd app/web && npm ci

web-dev: ## Vite dev server 起動 (HMR、別ターミナルで `cd app && go run .` も起動)
	cd app/web && npm run dev

web-build: ## React SPA をビルド
	cd app/web && npm run build

# ==================== Docker ====================

docker-build: ## Docker イメージビルド (リポジトリルートを context に使用)
	docker build -f app/Dockerfile -t $(IMAGE) .

docker-push: docker-build ## ACR へプッシュ
	az acr login --name $(ACR_NAME)
	docker push $(IMAGE)

# ==================== Deploy ====================

deploy: ## App Service のコンテナイメージ更新（直接）
	az webapp config container set \
		--name $(APP_NAME) \
		--resource-group $(RG_NAME) \
		--container-image-name $(IMAGE) \
		--container-registry-url https://$(ACR_URL)

deploy-staging: ## ステージングスロットへデプロイ
	az webapp config container set \
		--name $(APP_NAME) \
		--resource-group $(RG_NAME) \
		--slot staging \
		--container-image-name $(IMAGE) \
		--container-registry-url https://$(ACR_URL)

swap: ## ステージング -> プロダクションにスワップ
	az webapp deployment slot swap \
		--name $(APP_NAME) \
		--resource-group $(RG_NAME) \
		--slot staging \
		--target-slot production
	@echo "✅ Swap complete. Verify: https://$(APP_NAME).azurewebsites.net/health"

rollback: ## プロダクションをロールバック（再スワップ）
	@echo "⚠️  Rolling back production by re-swapping with staging..."
	az webapp deployment slot swap \
		--name $(APP_NAME) \
		--resource-group $(RG_NAME) \
		--slot staging \
		--target-slot production
	@echo "✅ Rollback complete."

slot-url: ## ステージングスロットのURL表示
	@echo "Staging: https://$(APP_NAME)-staging.azurewebsites.net"
	@echo "Production: https://$(APP_NAME).azurewebsites.net"

# ==================== Front Door ====================

fd-purge: ## Front Door キャッシュパージ
	@FD_PROFILE=$$(cd infra && terraform output -raw frontdoor_endpoint_url 2>/dev/null | grep -v disabled); \
	if [ -z "$$FD_PROFILE" ]; then echo "Front Door is not enabled"; exit 1; fi; \
	az afd endpoint purge \
		--resource-group $(RG_NAME) \
		--profile-name $(PROJECT)-$(ENV)-fd \
		--endpoint-name $(PROJECT)-$(ENV)-endpoint \
		--content-paths '/*'

# ==================== Database ====================

db-connect: ## PostgreSQL に接続（psql）
	@echo "Connecting to PostgreSQL..."
	@PG_FQDN=$$(cd infra && terraform output -raw postgresql_fqdn); \
	psql "postgresql://$(PROJECT)admin@$$PG_FQDN:5432/$(PROJECT)db?sslmode=require"

# ==================== Redis ====================

redis-cli: ## Redis に接続（redis-cli）
	@REDIS_HOST=$$(cd infra && terraform output -raw redis_hostname 2>/dev/null | grep -v disabled); \
	if [ -z "$$REDIS_HOST" ]; then echo "Redis is not enabled"; exit 1; fi; \
	REDIS_PORT=$$(cd infra && terraform output -raw redis_ssl_port); \
	echo "Connecting to $$REDIS_HOST:$$REDIS_PORT (TLS)..."; \
	redis-cli -h "$$REDIS_HOST" -p "$$REDIS_PORT" --tls

# ==================== Utility ====================

status: ## 全リソースのステータス確認
	@echo "=== App Service ==="
	@az webapp show --name $(APP_NAME) --resource-group $(RG_NAME) --query '{state:state, url:defaultHostName}' -o table 2>/dev/null || echo "(not found)"
	@echo ""
	@echo "=== PostgreSQL ==="
	@az postgres flexible-server show --name $(PROJECT)-$(ENV)-pgserver --resource-group $(RG_NAME) --query '{state:state, fqdn:fullyQualifiedDomainName}' -o table 2>/dev/null || echo "(not found)"
	@echo ""
	@echo "=== ACR ==="
	@az acr show --name $(ACR_NAME) --query '{loginServer:loginServer, sku:sku.name}' -o table 2>/dev/null || echo "(not found)"
