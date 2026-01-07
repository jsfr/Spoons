SPOONS_TMPDIR=.spoons_tmp
DOCS_TMPDIR=.docs_tmp
ZIPDIR=Spoons
SRCDIR=Source
DOCSDIR=docs
HAMMERSPOON_PATH=hammerspoon
SOURCES:=$(wildcard $(SRCDIR)/*.spoon)
SPOONS:=$(patsubst $(SRCDIR)/%, $(ZIPDIR)/%.zip, $(SOURCES))

all: $(SPOONS) $(DOCSDIR)/docs.json

.PHONY: clean
clean:
	rm -rf $(SPOONS_TMPDIR) $(DOCS_TMPDIR) $(DOCSDIR)/* $(ZIPDIR)/*.zip

.PRECIOUS: $(SPOONS_TMPDIR)/%
$(SPOONS_TMPDIR)/%: $(SRCDIR)/%
	rm -rf $@
	mkdir -p $@
	cp -r $</* $@/
	cd $@ ; fennel --require-as-include --compile init.fnl > init.lua
	cd $@ ; echo "[]" > docs.json # TODO: fix generation of docs
	cd $@ ; rm *.fnl

$(ZIPDIR)/%.zip: $(SPOONS_TMPDIR)/%
	rm -f $@
	cd $(SPOONS_TMPDIR) ; zip -9 -r ../$@ $(patsubst $(SPOONS_TMPDIR)/%, %, $<)

$(DOCSDIR)/docs.json: $(SPOONS)
	mkdir -p "$(DOCS_TMPDIR)"
	uv run --with-requirements $(HAMMERSPOON_PATH)/requirements.txt \
		$(HAMMERSPOON_PATH)/scripts/docs/bin/build_docs.py \
		-e $(HAMMERSPOON_PATH)/scripts/docs/templates/ \
		-o $(DOCS_TMPDIR) \
		-i "jsfr's Spoons" \
		-u "https://github.com/jsfr/Spoons/blob/main/" \
		-j \
		-t \
		-n $(SRCDIR)/
	cp $(HAMMERSPOON_PATH)/scripts/docs/templates/docs.css $(DOCS_TMPDIR)/html/
	cp $(HAMMERSPOON_PATH)/scripts/docs/templates/jquery.js $(DOCS_TMPDIR)/html/
	mv $(DOCS_TMPDIR)/html/* $(DOCSDIR)/
	mv $(DOCS_TMPDIR)/docs{,_index}.json $(DOCSDIR)/
