.PHONY: help infra-init infra-plan infra-apply infra-destroy infra-output \
        docker-build docker-push deploy app-run app-test

PROJECT  ?= webapp
ENV      ?= dev
ACR_NAME  = $(shell cd infra && terraform output -raw acr_login_server 2>/dev/null)
APP_NAME  = $(shell cd infra && terraform output -raw app_service_name 2>/dev/null)
IMAGE     = $(ACR_NAME)/$(PROJECT):latest

help: ## ヘルプ表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ---------- Infra ----------
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

# ---------- App ----------
app-run: ## ローカルでアプリ起動
	cd app && go run main.go

app-test: ## アプリのテスト
	cd app && go test ./...

# ---------- Docker ----------
docker-build: ## Docker イメージビルド
	docker build -t $(IMAGE) app/

docker-push: docker-build ## ACR へプッシュ
	az acr login --name $(shell cd infra && terraform output -raw acr_name 2>/dev/null)
	docker push $(IMAGE)

# ---------- Deploy ----------
deploy: ## App Service のコンテナイメージ更新
	az webapp config container set \
		--name $(APP_NAME) \
		--resource-group $(PROJECT)-$(ENV)-rg \
		--container-image-name $(IMAGE) \
		--container-registry-url https://$(ACR_NAME)
