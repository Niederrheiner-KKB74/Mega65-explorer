JAVA ?= java
KICKASS_JAR ?= tools/KickAss.jar
PRG := build/mega65-explorer.prg
SOURCES := $(shell find src -name '*.asm')
.PHONY: all clean test
all: $(PRG)
$(PRG): Makefile $(SOURCES) $(KICKASS_JAR)
	mkdir -p build
	$(JAVA) -jar "$(KICKASS_JAR)" src/main.asm -o $(PRG) -symbolfile
clean:
	rm -f build/*.prg build/*.sym src/*.sym

# Optional binary logic tests: Python 3 + py65 (not an XEMU replacement).
test: $(PRG)
	python3 tests/test_stage1b.py
