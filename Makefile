.PHONY: build run install

build:
	chmod +x scripts/build.sh
	./scripts/build.sh

run: build
	pkill -x PRMenu >/dev/null 2>&1 || true
	open "$(CURDIR)/dist/PR Menu.app"

install: build
	rm -rf "/Applications/PR Menu.app"
	cp -R "$(CURDIR)/dist/PR Menu.app" /Applications/
	@echo "Installed /Applications/PR Menu.app"
