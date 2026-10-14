RESOURCE_GROUP ?= rg-aiplatform-shared-swc
PARAMETERS     := infra/main.bicepparam
BICEP_FILES    := $(wildcard infra/*.bicep infra/modules/*.bicep)

.PHONY: validate whatif deploy outputs destroy

validate:
	@for f in $(BICEP_FILES); do az bicep build --file $$f --stdout > /dev/null || exit 1; done
	@for f in $(BICEP_FILES); do az bicep lint --file $$f || exit 1; done
	@echo "validate: $(words $(BICEP_FILES)) files built and linted"

whatif: validate
	az deployment group what-if --resource-group $(RESOURCE_GROUP) --parameters $(PARAMETERS) --only-show-errors

deploy:
	azd provision --no-prompt

outputs:
	azd env get-values

destroy:
	azd down --force --purge
