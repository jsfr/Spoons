ZIPDIR=Spoons
SRCDIR=Source
SOURCES := $(wildcard $(SRCDIR)/*.spoon)
SPOONS := $(patsubst $(SRCDIR)/%, $(ZIPDIR)/%.zip, $(SOURCES))
ZIP=/usr/bin/zip
FENNEL=./fennel-1.0.0

all: $(SPOONS)

clean:
	rm -f $(ZIPDIR)/*.zip

%.lua: %.fnl
	$(FENNEL) --compile $< > $@

$(SRCDIR)/%/docs.json: $(wildcard $(SRCDIR)/%/*.lua)
	cd $(SRCDIR) ; hs -c "hs.doc.builder.genJSON(\"$(pwd)\")" | grep -v "^--" > docs.json

$(ZIPDIR)/%.zip: $(SRCDIR)/%
	rm -f $@
	cd $(SRCDIR) ; $(ZIP) -9 -r ../$@ $(patsubst $(SRCDIR)/%, %, $<)

.PHONY: clean
