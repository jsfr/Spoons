TMPDIR=.tmp
ZIPDIR=Spoons
SRCDIR=Source
SOURCES:=$(wildcard $(SRCDIR)/*.spoon)
SPOONS:=$(patsubst $(SRCDIR)/%, $(ZIPDIR)/%.zip, $(SOURCES))

all: $(SPOONS) docs/docs.json

clean:
	rm -rf $(TMPDIR)
	rm -f $(ZIPDIR)/*.zip

$(TMPDIR)/%: $(SRCDIR)/%
	rm -rf $@
	mkdir -p $@
	cd $< ; fennel --require-as-include --compile init.fnl > ../../$@/init.lua
	cd $@ ; hs -c "hs.doc.builder.genJSON(\"$(pwd)\")" | grep -v "^--" > docs.json

$(ZIPDIR)/%.zip: $(TMPDIR)/%
	rm -f $@
	cd $(TMPDIR) ; zip -9 -r ../$@ $(patsubst $(TMPDIR)/%, %, $<)

docs/docs.json: $(SPOONS)
	scripts/build_docs.sh


.PHONY: clean
