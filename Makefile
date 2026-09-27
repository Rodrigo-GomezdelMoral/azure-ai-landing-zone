# Entry points shared by local runs and .github/workflows. Every az call carries --only-show-errors.
LOCATION    ?= swedencentral
DEPLOYMENT  ?= aiplatform-landing-zone
PARAMS      := infra/main.bicepparam
BICEP       := $(wildcard infra/*.bicep infra/modules/*.bicep)
DEPLOY_ARGS  = --name $(DEPLOYMENT) --location $(LOCATION) --parameters $(PARAMS) --only-show-errors

.PHONY: build lint what-if deploy

build:
	@for f in $(BICEP); do az bicep build --file $$f --stdout --only-show-errors > /dev/null || exit 1; done
	@az bicep build-params --file $(PARAMS) --stdout --only-show-errors > /dev/null

# --only-show-errors also hides linter warnings, so any SARIF result fails the target.
lint:
	@status=0; for f in $(BICEP); do \
		out=$$(az bicep lint --file $$f --diagnostics-format sarif --only-show-errors); \
		if printf '%s' "$$out" | grep -q '"ruleId"'; then \
			echo "$$f"; printf '%s\n' "$$out" | grep -E '"(ruleId|text|startLine)"'; status=1; \
		fi; \
	done; exit $$status

what-if: build lint
	az deployment sub what-if $(DEPLOY_ARGS)

deploy: build lint
	az deployment sub create $(DEPLOY_ARGS)
