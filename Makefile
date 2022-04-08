TMPDIR=.tmp
ZIPDIR=Spoons
SRCDIR=Source
SOURCES:=$(wildcard $(SRCDIR)/*.spoon)
SPOONS:=$(patsubst $(SRCDIR)/%, $(ZIPDIR)/%.zip, $(SOURCES))
FENNEL=./fennel-1.0.0

all: $(SPOONS)

clean:
	rm -rf $(TMPDIR)
	rm -f $(ZIPDIR)/*.zip

$(TMPDIR)/%: $(SRCDIR)/%
	rm -rf $@
	mkdir -p $@
	cd $< ; fd --strip-cwd-prefix -efnl | rargs -p '(.*)\.fnl' sh -c "fennel --compile {0} > ../../$@/{1}.lua"
	cd $@ ; hs -c "hs.doc.builder.genJSON(\"$(pwd)\")" | grep -v "^--" > docs.json

$(ZIPDIR)/%.zip: $(TMPDIR)/%
	rm -f $@
	cd $(TMPDIR) ; zip -9 -r ../$@ $(patsubst $(TMPDIR)/%, %, $<)

.PHONY: clean
