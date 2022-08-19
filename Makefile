MAKEFLAGS += --warn-undefined-variables
.SHELLFLAGS := -eu -o pipefail -c

all: help
.PHONY: all, help, run-compose, run-connect, run-disconnect, run-status, clean
# https://medium.com/freestoneinfotech/simplifying-docker-compose-operations-using-makefile-26d451456d63

# Use bash for inline if-statements
SHELL:=bash

##@ Helpers
help: ## display this help
	@echo "Debezium Showcase"
	@echo "================="
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m"} /^[a-zA-Z0-9_%/-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@printf "\n"

stack = simple
##@ Setup
run-compose: ## set up Kafka stack, vars: stack=[simple, extended]
	docker-compose -f docker-compose-postgres-$(stack).yaml up -d $(c)

stack = simple
##@ Configuring the Kafka connectors
run-connect: ## connecting sources and sinks, vars: stack=[simple, extended]
	@echo 'Launching default connectors...'
	curl -i -X POST -H "Accept:application/json" -H \
		"Content-Type:application/json" http://localhost:8083/connectors/ \
		-d @config/register-postgres-dbserver1_$(stack).json
	curl -i -X POST -H "Accept:application/json" -H \
		"Content-Type:application/json" http://localhost:8083/connectors/ \
		-d @config/register-sink-schema_$(stack).json
ifeq ($(stack), simple)
	@echo 'Launching additional simple-stack connectors...'
	curl -i -X POST -H "Accept:application/json" -H \
		"Content-Type:application/json" http://localhost:8083/connectors/ \
		-d @config/register-postgres-dbserver2_$(stack).json
else ifeq ($(stack), extended)
	@echo 'Launching additional extended-stack connectors...'
	curl -i -X POST -H "Accept:application/json" -H \
		"Content-Type:application/json" http://localhost:8083/connectors/ \
		-d @config/register-sink-noschema_$(stack).json
else
	@echo 'Nothing else to do...'
endif

stack = simple
##@ Disabling the Kafka connectors
run-disconnect: ## disconnecting sources and sinks, vars: stack=[simple, extended]
	curl -X DELETE http://localhost:8083/connectors/db1-inventory-connector
	curl -X DELETE http://localhost:8083/connectors/sink-connector-schema
ifeq ($(stack), simple)
	curl -X DELETE http://localhost:8083/connectors/db2-country-connector
else ifeq ($(stack), extended)
	curl -X DELETE http://localhost:8083/connectors/sink-connector-noschema
endif
	@echo 'Connectors cleared...'

##@ Show actice Kafka connectors
run-status: ## display active connectors
	curl -X GET http://localhost:8083/connectors

stack = simple
##@ Tear-down
clean: ## clean up Kafka stack, vars: stack=[simple, extended]
	docker-compose -f docker-compose-postgres-$(stack).yaml down $(c)