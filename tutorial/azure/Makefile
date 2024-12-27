.PHONY: all
all: init fmt validate apply

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
apply: 
	terraform apply

.PHONY: apply-approved
apply-approved: 
	terraform apply --auto-approve

.PHONY: destroy
destroy: 
	terraform destroy
