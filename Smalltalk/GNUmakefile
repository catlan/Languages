include $(GNUSTEP_MAKEFILES)/common.make

# We reset PROJECT_DIR provided by etoile.make to match the subproject since 
# etoile.make doesn't detect and handle such embedded project
PROJECT_DIR = $(CURDIR)

SUBPROJECTS = Support
#
# Library
#
VERSION = 0.7
BUNDLE_NAME = Smalltalk
BUNDLE_EXTENSION = .language
BUNDLE_INSTALL_DIR = $(GNUSTEP_BUNDLES)/LanguageKit

${BUNDLE_NAME}_PRINCIPAL_CLASS = SmalltalkCompiler

${BUNDLE_NAME}_OBJC_FILES = \
	smalltalk.m\
	SmalltalkCompiler.m\
	SmalltalkParser.m

${BUNDLE_NAME}_OBJCFLAGS = -std=c99 -g -Wno-unused-value
${BUNDLE_NAME}_LDFLAGS += -g -lEtoileFoundation -lLanguageKit \
	-lSmalltalkSupport
${BUNDLE_NAME}_CFLAGS += -Wno-implicit -g

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/bundle.make
-include ../../etoile.make

smalltalk.h: smalltalk.m

smalltalk.m: smalltalk.y lempar.c lemon
	@echo Generating parser...
	@./lemon smalltalk.y ; mv smalltalk.c smalltalk.m

lemon: lemon.c
	@echo Compiling parser generator
	@$(CC) lemon.c -o lemon

clean::
	@rm -f smalltalk.h smalltalk.m smalltalk.out lemon

test:
	@cd Tests && sh runall.sh -q
