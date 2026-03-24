PREFIX ?= /usr/local
BINARY = apfel

.PHONY: build install uninstall clean

build:
	swift build -c release

install: build
	install -d $(PREFIX)/bin
	install .build/release/$(BINARY) $(PREFIX)/bin/$(BINARY)

uninstall:
	rm -f $(PREFIX)/bin/$(BINARY)

clean:
	swift package clean
