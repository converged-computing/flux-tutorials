.PHONY: all
all: apply

.PHONY: init
init: 
	terraform init	

.PHONY: fmt
fmt: 
	terraform fmt

.PHONY: validate
validate: 
	terraform validate
	
.PHONY: apply
apply: init fmt validate
	terraform apply

.PHONY: apply-approved
apply-approved: init fmt validate
	terraform apply --auto-approve

.PHONY: destroy
destroy: 
	terraform destroy
