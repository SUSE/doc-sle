#
# Copyright (c) 2014 Rick Salevsky <rsalevsky@suse.de>
# Copyright (c) 2016 Stefan Knorr <sknorr@suse.de>
# Copyright (c) 2018 Alessio Adamo <alessio@alessioadamo.com>
#

# How to use this makefile:
# * After updating the XML: $ make po
# * When creating output:   $ make linguas; make all
# * To clean up:            $ make clean

.PHONY: clean linguas po pot pdf text single-html translatedxml

ifndef LANGS
#  LANGS := $(shell cat LINGUAS)
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

# The list of available languages is retrieved by searching for subdirs with
# pattern lang/po and removing the '/po' suffix
LANG_LIST := $(subst /po,,$(wildcard */po))

# The list of source files is represented by all '.xml' files in xml/ dir
SOURCE_FILES := $(wildcard xml/*.xml)

# The PO domain list is generated by taking the basename of the source files
# and removing the dir part
DOMAIN_LIST := $(basename $(notdir $(SOURCE_FILES)))

# The list of POT files is generated by attaching the '50-pot/' prefix and the
# '.pot' suffix to each domain
POT_FILES := $(foreach DOMAIN,$(DOMAIN_LIST),50-pot/$(DOMAIN).pot)

# The list of PO files is generated as follows. First, for each available language
# it is generated a pattern like 'lang/po/_DOMAIN_NAME_.lang.po', then the placeholder
# _DOMAIN_NAME_ is substituted with each available domain to get a pattern like
# 'lang/po/domain.lang.po'
PO_FILES := $(foreach DOMAIN,$(DOMAIN_LIST),$(subst _DOMAIN_NAME_,$(DOMAIN),$(foreach LANG,$(LANG_LIST),$(LANG)/po/_DOMAIN_NAME_.$(LANG).po)))

# The list of MO files is generated by substituting the '.po' suffix of the
# PO files with a '.mo' suffix
MO_FILES := $(addsuffix .mo,$(basename $(PO_FILES)))

# If LANGS is not defined, for output, use only those files that have at least 60% translations
XML_FILES := $(foreach l, $(LANGS), xml/release-notes.$(l).xml)
PDF_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/release-notes.$(l)_color_$(l).pdf)
SINGLE_HTML_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/single-html/release-notes.$(l)/index.html)
TXT_FILES := $(foreach l, $(LANGSEN), build/release-notes.$(l)/release-notes.$(l).txt)

# Gets the language code: release-notes.en.xml => en
LANG_COMMAND = `echo $@ | awk -F '.' '{gsub("/.*","",$$2); print($$2)}'`
DAPS_COMMAND_BASIC = daps -vv --styleroot $(STYLEROOT)
DAPS_COMMAND = $(DAPS_COMMAND_BASIC) -m xml/release-notes.$${lang}.xml

# Gets the xml source starting from target POT
XML_SOURCE = `echo $(@F) | awk -F '.' '{print ("xml/" $$1 ".xml")}'`
# Gets the po template starting from target PO
PO_TEMPLATE = `echo $(@F) | awk -F '.' '{print ("50-pot/" $$1 ".pot")}'`
# Gets the input po starting from target MO
PO_FILE = $(addsuffix .mo,$(basename $@))

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


# all: single-html pdf text
all:
	@echo "$(LANG_LIST)"
	@echo "$(SOURCE_FILES)"
	@echo "$(DOMAIN_LIST)"
	@echo "$(POT_FILES)"
	@echo "$(PO_FILES)"
	@echo "$(MO_FILES)"

#linguas: LINGUAS
#LINGUAS: $(PO_FILES) 50-tools/po-selector
#	50-tools/po-selector

pot: $(POT_FILES)
$(POT_FILES): $(SOURCE_FILES)
	$(DAPS_COMMAND_BASIC) -m $(XML_SOURCE) validate
	$(ITSTOOL) -o $@ $(XML_SOURCE)

po: $(PO_FILES)
$(PO_FILES): $(POT_FILES)
	if [ -r $@ ]; then \
       msgmerge  --previous --update $@ $(PO_TEMPLATE); \
   else \
       msgen -o $@ $(PO_TEMPLATE); \
   fi

mo: $(MO_FILES)
$(MO_FILES): $(PO_FILES)
	msgfmt $(PO_FILE) -o $@

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
$(PDF_FILES): LINGUAS translatedxml
	lang=$(LANG_COMMAND) ; \
	$(DAPS_COMMAND) pdf PROFCONDITION="general\;$(LIFECYCLE)"

single-html: $(SINGLE_HTML_FILES)
$(SINGLE_HTML_FILES): LINGUAS translatedxml
	lang=$(LANG_COMMAND) ; \
	$(DAPS_COMMAND) html --single \
	--stringparam "homepage='https://www.opensuse.org'" \
	PROFCONDITION="general\;$(LIFECYCLE)"

text: $(TXT_FILES)
$(TXT_FILES): LINGUAS translatedxml
	lang=$(LANG_COMMAND) ; \
	LANG=$${lang} $(DAPS_COMMAND) text \
	PROFCONDITION="general\;$(LIFECYCLE)"

clean:
# rm -rf */po/~* $(MO_FILES) $(POT_FILES) LINGUAS build/ xml/release-notes.*.xml xml/release-notes.*.xml.0
