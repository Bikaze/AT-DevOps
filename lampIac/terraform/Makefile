# Makefile for Terraform LAMP Stack deployment

.PHONY: help init plan apply destroy status clean

# Default target
help:
	@echo "Available commands:"
	@echo "  make init     - Initialize Terraform"
	@echo "  make plan     - Create deployment plan"
	@echo "  make apply    - Apply the deployment"
	@echo "  make destroy  - Destroy infrastructure"
	@echo "  make status   - Show infrastructure status"
	@echo "  make clean    - Clean temporary files"
	@echo "  make deploy   - Full deployment workflow"

# Initialize Terraform
init:
	terraform init

# Validate configuration
validate:
	terraform validate

# Create deployment plan
plan: validate
	terraform plan

# Apply the deployment
apply: plan
	terraform apply

# Destroy infrastructure
destroy:
	terraform destroy

# Show infrastructure status
status:
	@echo "=== Terraform Outputs ==="
	terraform output
	@echo ""
	@echo "=== Auto Scaling Group Status ==="
	@ASG_NAME=$$(terraform output -raw auto_scaling_group_name 2>/dev/null) && \
	if [ ! -z "$$ASG_NAME" ]; then \
		aws autoscaling describe-auto-scaling-groups \
			--auto-scaling-group-names "$$ASG_NAME" \
			--query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
			--output table \
			--region eu-west-1; \
	fi

# Clean temporary files
clean:
	rm -f *.tfplan
	rm -f terraform.tfstate.backup

# Full deployment workflow
deploy: init apply status
	@echo "=== Deployment completed successfully! ==="

# Check configuration format
fmt:
	terraform fmt -recursive

# Security check (requires tfsec)
security:
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec .; \
	else \
		echo "tfsec not installed. Install with: go install github.com/aquasecurity/tfsec/cmd/tfsec@latest"; \
	fi
