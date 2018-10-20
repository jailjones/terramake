#########################################################
# Automates common terraform usage						# 
# Requirements:											#
#	- Terraform: https://www.terraform.io/				#
#	- AWS CLI: https://aws.amazon.com/cli/				#
#	- GNU Make 4.2.1: https://ftp.gnu.org/gnu/make/		#
#	- Bash: https://www.gnu.org/software/bash/			#
#########################################################

.SHELL: /bin/bash
.ONESHELL: # Use one shell for all commands within a target
#.SILENT: # Disable command echoing
.DEFAULT_GOAL=usage

# Environment flag used to control per env configuration and statefiles
# https://www.terraform.io/docs/state/workspaces.html
env := default
TF_WORKSPACE := $(env)

ifndef project
$(error No project defined)
endif 

#################################
# Paths						   	#
#################################
root 			:= $(realpath .)
project			:= $(project:%/=%)
source 			:= $(realpath $(project))
terraform 		:= $(source)/.terraform
plans			:= $(source)/.tfplan
tfvars			:= $(notdir $(wildcard $(source)/$(env).tfvars))
var-files 		:= $(tfvars:%=-var-file=%)
plan			:= $(plans)/$(env).tfplan
destroy-plan	:= $(plans)/$(env).destroy.tfplan

ifndef source
$(error $(project) is not a valid path)
endif

# Include arguments from general and project specific environment files
-include .env $(env).env $(source)/.env $(source)/$(env).env
export # Export all variables as ENNVAR to child processes/shells

# Print help for the target terraform command if help is specified as a build target
args += $(if $(findstring help,$(MAKECMDGOALS)), "--help")

#################################
# Print usage instructions		#
#################################
.PHONY: usage
usage:
	echo
	echo "Usage:"
	echo "---------------"	
	
#################################
# Cleanup temp build files		#
#################################
.PHONY: clean clean\:plans
clean:
	rm -rf $(terraform) $(plans)	
clean\:plans:
	rm -rf $(plans)

$(terraform):
	echo "Initializing $(project) ..."
	cd $(source)
	terraform init -get $(args)	-upgrade=true

#################################
# Initialize Terraform			#
#################################
.PHONY: init
init: clean $(terraform)
	
#################################
# Build Stack Plan				#
#################################
$(plans):
	mkdir -p $@

.PHONY: plan
plan: $(terraform) $(plans)
	echo "Creating Plan for $(project) ..."
	cd $(source)
	terraform plan $(var-files) -out=$(plan) $(args)

.PHONY: plan\:destroy
plan\:destroy: $(terraform) $(plans)
	echo "Creating Destroy Plan for $(project) ..."
	cd $(source)
	terraform plan $(var-files) -out=$(destroy-plan) -destroy $(args)

#################################
# Build Stack					#
#################################
.PHONY: apply apply\:destroy
define apply-plan
	echo "Applying $(project) ..."
	cd $(source)
	if [ -f $(1) ]; then		
		terraform apply $(var-files) $(args) $(1) && rm -f $(1)
	else
		terraform apply $(var-files) $(args)
	fi
endef

apply: $(terraform)
	$(call apply-plan, $(plan))

apply\:destroy: $(terraform)
	$(call apply-plan, $(destroy-plan))

#################################
# Destroy Stack					#
#################################
.PHONY: destroy
destroy: $(terraform)
	echo "Destroying $(project) ..."
	cd $(source)
	terraform destroy $(var-files) $(args)	