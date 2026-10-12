JAVA ?= java
KICKASS_JAR ?= tools/KickAss.jar
PRG := build/mega65-explorer.prg
SOURCES := $(shell find src -name '*.asm')
.PHONY: all clean
all: $(PRG)
$(PRG): $(SOURCES) $(KICKASS_JAR)
	mkdir -p build
	$(JAVA) -jar "$(KICKASS_JAR)" src/main.asm -o $(PRG)
clean:
	rm -f build/*.prg build/*.sym src/*.sym
