.PHONY: build test clean deep-clean bundle

MAKEFILE_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Build the project
build:
	cd $(MAKEFILE_DIR) && cjpm build

# Run tests
test:
	cd $(MAKEFILE_DIR) && cjpm test

# Clean build artifacts (cjpm clean)
clean:
	cd $(MAKEFILE_DIR) && cjpm clean

# Deep clean: remove target/ and .cache/ to force full rebuild
# Use this when stale cache causes phantom compilation errors
deep-clean:
	cd $(MAKEFILE_DIR) && rm -rf target .cache

# Build + test + lint (full CI check)
bundle:
	cd $(MAKEFILE_DIR) && cjpm bundle
