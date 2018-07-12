XMLFILES  := $(wildcard xml/*.xml)
LANGS  := $(patsubst po/%.po, %, $(wildcard po/*.po))

all : xml2pot po2xml

xml2pot : po/template.pot

po/template.pot : $(XMLFILES)
	itstool -o $@ xml/*.xml

po2xml : $(LANGS)

%: po/%.mo $(XMLFILES)
	mkdir -p l10n/$@/xml && itstool -m $< -o l10n/$@/xml/ xml/*.xml

po/%.mo : po/%.po
	msgfmt -o $@ $<

clean : clean_l10nxml

# Remove translated XML in language folders, generated from PO files
clean_l10nxml :
	rm -f l10n/*/*.xml
