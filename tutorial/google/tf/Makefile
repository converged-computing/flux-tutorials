.PHONY: all
all: init fmt validate deploy

.PHONY: init
init: 
	terraform init --upgrade
	
.PHONY: fmt
fmt: 
	terraform fmt

.PHONY: validate
validate: 
	terraform validate
	
.PHONY: deploy
deploy: 
	export GOOGLE_PROJECT=$(gcloud config get-value core/project)
	terraform apply -var-file basic.tfvars -var region=us-central1 -var project_id=$(gcloud config get-value core/project) -var network_name=foundation-net -var zone=us-central1-a

# TODO write script that takes number of instances... check exported here.
.PHONY: destroy
destroy: 
	export GOOGLE_PROJECT=$(gcloud config get-value core/project)
	gcloud compute instances delete nfs-001 --zone=us-central1-a --quiet || echo "nfs-001 must already be deleted"
	/bin/bash ./delete.sh || echo "All instances are deleted"
	terraform destroy -var-file basic.tfvars -var region=us-central1 -var project_id=$(gcloud config get-value core/project) -var network_name=foundation-net -var zone=us-central1-a
