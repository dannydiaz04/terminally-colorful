.PHONY: test preview

test:
	/bin/bash tests/run.sh

preview:
	./bin/harness-tint preview
