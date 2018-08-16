#
# Copyright (c) 2014 Rick Salevsky <rsalevsky@suse.de>
# Copyright (c) 2016 Stefan Knorr <sknorr@suse.de>
#

# How to use this makefile:
# * After updating the XML: $ make po
# * When creating output:   $ make linguas; make all
# * To clean up:            $ make clean

.PHONY: clean po pot pdf text single-html yast-html translatedxml profile

ifndef LANGS
  LANGS := $(shell cat po/LINGUAS)
endif
LANGSEN := $(LANGS) en
ifndef STYLEROOT
  STYLEROOT := /usr/share/xml/docbook/stylesheet/opensuse2013-ns
endif
ifndef VERSION
  VERSION := unreleased
endif
ifndef DATE
  DATE := $(shell date +%Y-%0m-%0d)
endif

# Allows for DocBook profiling (hiding/showing some text).
LIFECYCLE_VALID := beta pre maintained unmaintained
ifndef LIFECYCLE
  LIFECYCLE := maintained
endif
ifneq "$(LIFECYCLE)" "$(filter $(LIFECYCLE),$(LIFECYCLE_VALID))"
  override LIFECYCLE := maintained
endif


# Update all PO files
PO_FILES := $(wildcard po/*.po)

# For output, use only those files that have at least 60% translations
XML_FILES := $(foreach l, $(LANGS), xml/release-notes.$(l).xml)
PDF_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/release-notes.$(l)_color_$(l).pdf)
SINGLE_HTML_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/single-html/release-notes.$(l)/index.html)
YAST_PROFILED_FILES := $(foreach l, $(LANGSEN), build/.profiled/general_$(LIFECYCLE)/release-notes.$(l).xml)
YAST_HTML_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/yast-html/release-notes.$(l).html)
TXT_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/release-notes.$(l).txt)
DIRS := $(foreach l, $(LANGSEN), build/release-notes.$(l)/yast-html/)

# Gets the language code: release-notes.en.xml => en
LANG_COMMAND = `echo $@ | awk -F '.' '{gsub("/.*","",$$2); print($$2)}'`
LANG_COMMAND_PROFILE = `echo $@ | awk -F '.' '{gsub("/.*","",$$3); print($$3)}'`
DAPS_COMMAND_BASIC = daps -vv --styleroot $(STYLEROOT)
DAPS_COMMAND = $(DAPS_COMMAND_BASIC) -m xml/release-notes.$${lang}.xml

ITSTOOL = itstool -i /usr/share/itstool/its/docbook5.its

XSLTPROC_COMMAND = xsltproc \
--stringparam generate.toc "book toc" \
--stringparam generate.section.toc.level 0 \
--stringparam section.autolabel 1 \
--stringparam section.label.includes.component.label 2 \
--stringparam variablelist.as.blocks 1 \
--stringparam toc.max.depth 3 \
--stringparam show.comments 0 \
--xinclude --nonet

# Fetch correct Report Bug link values, so translations get the correct
# version
XPATHPREFIX := //*[local-name()='docmanager']/*[local-name()='bugtracker']/*[local-name()
URL = `xmllint --noent --xpath "$(XPATHPREFIX)='url']/text()" xml/release-notes.xml`
PRODUCT = `xmllint --noent --xpath "$(XPATHPREFIX)='product']/text()" xml/release-notes.xml`
COMPONENT = `xmllint --noent --xpath "$(XPATHPREFIX)='component']/text()" xml/release-notes.xml`
ASSIGNEE = `xmllint --noent --xpath "$(XPATHPREFIX)='assignee']/text()" xml/release-notes.xml`


all: single-html yast-html pdf text

linguas: po/LINGUAS

po/LINGUAS: po/*.po po/po-selector
	po/po-selector

pot: release-notes.pot
release-notes.pot: xml/release-notes.xml xml/release-notes.ent
	$(DAPS_COMMAND_BASIC) -m $< validate
	$(ITSTOOL) -o $@ $<

po: $(PO_FILES)
po/%.po: release-notes.pot
	if [ -r $@ ]; then \
       msgmerge  --previous --update $@ $<; \
   else \
       msgen -o $@ $<; \
   fi

po/%.mo: po/%.po
	msgfmt $< -o $@

# FIXME: Enable use of its:translate attribute in GeekoDoc/DocBook...
xml/release-notes.%.xml: po/%.mo xml/release-notes.ent xml/release-notes.xml
	$(ITSTOOL) -m $< -o $@.0 xml/release-notes.xml
	sed -i -r \
	  -e 's_\t+_ _' -e 's_\s+$$__' \
	  $@.0
	xsltproc \
	  --stringparam 'version' "$(VERSION)" \
	  --stringparam 'dmurl' "$(URL)" \
	  --stringparam 'dmproduct' "$(PRODUCT)" \
	  --stringparam 'dmcomponent' "$(COMPONENT)" \
	  --stringparam 'dmassignee' "$(ASSIGNEE)" \
	  --stringparam 'date' "$(DATE)" \
	  fix-up.xsl $@.0 \
	  > $@
	rm $@.0
	daps-xmlformat -i $@
	$(DAPS_COMMAND_BASIC) -m $@ validate


translatedxml: xml/release-notes.xml xml/release-notes.ent $(XML_FILES)
	xsltproc \
	  --stringparam 'version' "$(VERSION)" \
	  --stringparam 'dmurl' "$(URL)" \
	  --stringparam 'dmproduct' "$(PRODUCT)" \
	  --stringparam 'dmcomponent' "$(COMPONENT)" \
	  --stringparam 'dmassignee' "$(ASSIGNEE)" \
	  --stringparam 'date' "$(DATE)" \
	  fix-up.xsl $< \
	  > xml/release-notes.en.xml

pdf: $(PDF_FILES)
$(PDF_FILES): po/LINGUAS translatedxml
	lang=$(LANG_COMMAND) ; \
	$(DAPS_COMMAND) pdf PROFCONDITION="general\;$(LIFECYCLE)"

single-html: $(SINGLE_HTML_FILES)
$(SINGLE_HTML_FILES): po/LINGUAS translatedxml
	lang=$(LANG_COMMAND) ; \
	$(DAPS_COMMAND) html --single \
	--stringparam "homepage='https://www.opensuse.org'" \
	PROFCONDITION="general\;$(LIFECYCLE)"

yast-html: | $(DIRS) $(YAST_HTML_FILES)
$(YAST_HTML_FILES): po/LINGUAS $(YAST_PROFILED_FILES)
	lang=$(LANG_COMMAND) ; \
	  $(XSLTPROC_COMMAND) /usr/share/daps/daps-xslt/relnotes/yast.xsl build/.profiled/general_$(LIFECYCLE)/release-notes.$${lang}.xml > $@

# xsltproc by itself does not support profiling, so we need to do this
# beforehand for YaST HTML
profile: $(YAST_PROFILED_FILES)
$(YAST_PROFILED_FILES): po/LINGUAS translatedxml
	lang=$(LANG_COMMAND_PROFILE) ; \
	$(DAPS_COMMAND) profile \
	PROFCONDITION="general\;$(LIFECYCLE)"

text: $(TXT_FILES)
$(TXT_FILES): po/LINGUAS translatedxml
	lang=$(LANG_COMMAND) ; \
	LANG=$${lang} $(DAPS_COMMAND) text \
	PROFCONDITION="general\;$(LIFECYCLE)"

$(DIRS):
	mkdir -p $@

clean:
rm -rf po/*~ po/*.mo po/LINGUAS build/ xml/release-notes.*.xml xml/release-notes.*.xml.0 release-notes.pot
