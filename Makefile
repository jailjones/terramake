#########################################################
# Automates common terraform usage						# 
# Requirements:											#
#	- Terraform: https://www.terraform.io/				#
#	- AWS CLI: https://aws.amazon.com/cli/				#
#	- GNU Make 4.2.1: https://ftp.gnu.org/gnu/make/		#
#	- Bash: https://www.gnu.org/software/bash/			#
#########################################################

#########################################################
# Makefile Settings										#
#########################################################
.SHELL: /bin/bash
.ONESHELL: # Use sae shell for all commands within a target
.SILENT: # Disable command echoing
.NOTPARALLEL:
.DEFAULT_GOAL=usage

#########################################################
# Shell Coloring										#
#########################################################
override bold	:= $(shell tput bold)
override error	:= $(shell tput setaf 1)
override ok		:= $(shell tput setaf 2)
override info	:= $(shell tput setaf 3)
override reset	:= $(shell tput sgr0)

#########################################################
# File Paths						   					#
#########################################################
working_dir 			:= $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
modules			:= $(working_dir)/modules
project			:= $(project:%/=%)
source 			:= $(realpath $(project))
terraform 		:= $(source)/.terraform
plans			:= $(source)/.tfplan
tfvars			:= $(notdir $(wildcard $(working_dir)/$(env.tfvars) $(working_dir)/*.$(env.tfvars) $(source)/$(env).tfvars) $(source)/*.$(env).tfvars)
var-files 		:= $(tfvars:%=-var-file=%)
plan			:= $(plans)/$(env).tfplan
destroy-plan	:= $(plans)/$(env).destroy.tfplan

#########################################################
# Environment flag used to control per env 				#
# configuration and statefiles							#
# https://www.terraform.io/docs/state/workspaces.html	#
#########################################################
env ?= default
override TF_WORKSPACE := $(env)

#==============================================================================
# Make File Includes
#------------------------------------------------------------------------------
-include $(working_dir)/*.mk 
-include $(source)/*.mk

#==============================================================================
# Environment Variable File Includes
#------------------------------------------------------------------------------
-include $(working_dir)/.env $(working_dir)/$(env).env $(working_dir)/*.$(env).env 
-include $(source)/.env $(source)/$(env).env $(source)/*.$(env).env

# Print help for the target terraform command if help is 
# specified as a build target
args += $(if $(findstring help,$(MAKECMDGOALS)), "--help")

#==============================================================================
# Print usage instructions		
#------------------------------------------------------------------------------
.PHONY: usage
usage:
	echo
	echo "Usage:"
	echo "---------------"
	# TODO: Auto extract usage docs and print here see https://github.com/pgporada/terraform-makefile/blob/master/Makefile
#==============================================================================

#################################
# Cleanup temp build files		#
#################################
.PHONY: clean clean\:plans
clean:
	rm -rf $(terraform) $(plans)	
clean\:plans:
	rm -rf $(plans)

#########################################################
# Sanity Checks											#
#########################################################
override error	:= $(shell tput setaf 1)
override ok		:= $(shell tput setaf 2)
override info	:= $(shell tput setaf 3)
override reset	:= $(shell tput sgr0)

define log
	case $2 in
	info)
		code=2
		;;
	warn)
		code=3
		;;
	error)
		code=1
		;;
	esac)
	tput setaf $code
	echo $1
	tput sgr0
endef

check:	
	$(call log, No project defined)

$(terraform): check
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
$(plans): mkdir -p $@;


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