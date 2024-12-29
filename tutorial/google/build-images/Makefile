.PHONY: all
all: init fmt validate build

.PHONY: init
init: 
	packer init .
	
.PHONY: fmt
fmt: 
	packer fmt .

.PHONY: validate
validate: 
	packer validate .
	
.PHONY: build
build: 
	# On error, the best strategy I've found is to ssh in, figure out what isn't there
	# (where it failed) and debug
	packer build --on-error=ask flux-build.pkr.hcl
