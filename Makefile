XMLFILES := $(wildcard xml/*.xml)
LANGDIRS := $(patsubst po/%.po, l10n/%/xml, $(wildcard po/*.po))

all : xml2pot po2xml

xml2pot : po/template.pot

po/template.pot : $(XMLFILES)
	itstool -o $@ xml/*.xml

po2xml : $(LANGDIRS)

l10n/%/xml: po/%.mo $(XMLFILES)
	mkdir -p $@ && itstool -m $< -o $@ xml/*.xml && touch $@

po/%.mo : po/%.po
	msgfmt -o $@ $<

# Do not remove intermediate mo files...
.SECONDARY:

clean : clean_mo clean_l10nxml

clean_mo :
	rm po/*.mo

# Remove translated XML in language folders, generated from PO files
clean_l10nxml :
	rm -f l10n/*/*.xml
