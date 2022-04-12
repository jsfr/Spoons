TMPDIR=.tmp
ZIPDIR=Spoons
SRCDIR=Source
SOURCES:=$(wildcard $(SRCDIR)/*.spoon)
SPOONS:=$(patsubst $(SRCDIR)/%, $(ZIPDIR)/%.zip, $(SOURCES))

all: $(SPOONS) docs/docs.json

clean:
	rm -rf $(TMPDIR)
	rm -f $(ZIPDIR)/*.zip
	rm -rf docs/*

$(TMPDIR)/%: $(SRCDIR)/%
	rm -rf $@
	mkdir -p $@
	cp -r $</* $@/
	cd $@ ; fennel --require-as-include --compile init.fnl > init.lua
	cd $@ ; echo "[]" > docs.json # TODO: fix generation of docs
	cd $@ ; rm *.fnl

$(ZIPDIR)/%.zip: $(TMPDIR)/%
	rm -f $@
	cd $(TMPDIR) ; zip -9 -r ../$@ $(patsubst $(TMPDIR)/%, %, $<)

docs/docs.json: $(SPOONS)
	scripts/build_docs.sh


.PHONY: clean
