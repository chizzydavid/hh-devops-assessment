# ============================================================
# Kubernetes Deployment & Operations
# ============================================================

K8S_DIR := kubernetes
K8S_NAMESPACE := hh-demo-api

.PHONY: k8s-apply k8s-delete k8s-status k8s-logs k8s-port-forward

k8s-apply:
	kubectl apply -f $(K8S_DIR)/namespace.yaml
	kubectl apply -f $(K8S_DIR)/configmap.yaml
	kubectl apply -f $(K8S_DIR)/secrets.yaml
	kubectl apply -f $(K8S_DIR)/serviceaccount.yaml
	kubectl apply -f $(K8S_DIR)/deployment.yaml
	kubectl apply -f $(K8S_DIR)/service.yaml
	kubectl apply -f $(K8S_DIR)/ingress.yaml
	kubectl apply -f $(K8S_DIR)/networkpolicy.yaml

k8s-delete:
	kubectl delete -f $(K8S_DIR)/networkpolicy.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/ingress.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/service.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/deployment.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/serviceaccount.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/secrets.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/configmap.yaml --ignore-not-found
	kubectl delete -f $(K8S_DIR)/namespace.yaml --ignore-not-found

k8s-status:
	kubectl -n $(K8S_NAMESPACE) get all
	kubectl -n $(K8S_NAMESPACE) get ingress

k8s-logs:
	kubectl -n $(K8S_NAMESPACE) logs deployment/hh-demo-api -f

k8s-port-forward:
	kubectl -n $(K8S_NAMESPACE) port-forward service/hh-demo-api-service 8080:80


# ============================================================
# Terraform Infrastructure Management
# ============================================================

TF_DIR := terraform

.PHONY: tf-init tf-validate tf-plan tf-apply

tf-init:
	cd $(TF_DIR) && terraform init

tf-validate:
	cd $(TF_DIR) && terraform fmt -check -recursive && terraform validate

tf-plan:
	cd $(TF_DIR) && terraform plan -out=tfplan

tf-apply:
	cd $(TF_DIR) && terraform apply tfplan
