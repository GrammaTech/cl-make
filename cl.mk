# To use this file first define the following variables in your
# makefile and then include cl.mk.
#
# PACKAGE_NAME ------- The full name of the CL package
# PACKAGE_NICKNAME --- The nickname of the CL package
#                      (default: PACKAGE_NAME)
# DOC_PACKAGES ------- Names of packages to document
#                      (default: PACKAGE_NAME)
# DOC_DEPS ----------- Optional additional Makefile targets for doc
# API_TITLE ---------- Title of the API section in the doc
# API_NEXT ----------- Title of the section after the API in the doc
# API_PREV ----------- Title of the section before the API in the doc
# BINS --------------- Names of binaries to build
# TEST_ARTIFACTS ----- Name of dependencies for testing
# TEST_BINS ---------- Name of lisp binaries needed for testing
# TEST_BIN_DIR ------- Directory of lisp binaries needed for testing
# LISP_DEPS ---------- Packages require to build CL package
# TEST_LISP_DEPS ----- Packages require to build CL test package
# BIN_TEST_DIR ------- Directory holding command-line tests
# BIN_TESTS ---------- List of command line tests
# LONG_BIN_TESTS ----- List of longer running command line tests
#                      Used by the `real-check' target.
# LISP_HEAP ---------- Size of the LISP heap (Mb)
# LISP_STACK --------- Size of the LISP stack (Mb)
SHELL=bash

.PHONY: test-artifacts check unit-check long-unit-check real-check \
        $(PACKAGE_NAME)-clean clean more-clean real-clean \
        doc api info html check-readme dependencies

.SECONDARY:

# Set default values of PACKAGE_NICKNAME
PACKAGE_NICKNAME ?= $(PACKAGE_NAME)
DOC_PACKAGES ?= $(PACKAGE_NAME)
API_TITLE ?= "$(PACKAGE_NAME) API"
API_NEXT ?= ""
API_PREV ?= ""

# You can set this as an environment variable to point to an alternate
# quicklisp install location.  If you do, ensure that it ends in a "/"
# character, and that you use the $HOME variable instead of ~.
INSTDIR ?= $(HOME)
QUICK_LISP ?= $(INSTDIR)/quicklisp/

MANIFEST=$(QUICK_LISP)/local-projects/system-index.txt

ifeq "$(wildcard $(QUICK_LISP)/setup.lisp)" ""
$(warning $(QUICK_LISP) does not appear to be a valid quicklisp install)
$(error Please point QUICK_LISP to your quicklisp installation)
endif

LISP_DEPS ?=				\
	$(wildcard *.lisp) 		\
	$(wildcard src/*.lisp)

# Default lisp to build manifest file.
LISP ?= sbcl
ifneq (,$(findstring sbcl, $(LISP)))
ifeq ("$(SBCL_HOME)","")
LISP_HOME = SBCL_HOME=$(dir $(shell which $(LISP)))../lib/sbcl
endif
endif
REPL_STARTUP ?= ()

LISP_HEAP ?= 32678
ifneq (,$(findstring sbcl, $(LISP)))
LISP_FLAGS += --dynamic-space-size $(LISP_HEAP)
else
ifneq (,$(findstring ccl, $(LISP)))
LISP_FLAGS += --heap-reserve $(LISP_HEAP)M
endif
endif

ifneq ($(LISP_STACK),)
ifneq (,$(findstring sbcl, $(LISP)))
LISP_FLAGS += --control-stack-size $(LISP_STACK)
else
ifneq (,$(findstring ccl, $(LISP)))
LISP_FLAGS += --stack-size $(LISP_STACK)M
endif
endif
endif

ifneq (,$(findstring sbcl, $(LISP)))
LISP_FLAGS += --noinform --disable-debugger --eval '(setf sb-impl::*default-external-format* :utf8)'
else
ifneq (,$(findstring ecl, $(LISP)))
LISP_FLAGS += --norc
else
LISP_FLAGS += --quiet --batch
endif
endif

ifneq ($(GT),)
LISP_FLAGS += --eval "(push :GT *features*)"
endif

ifneq ($(REPORT),)
LISP_FLAGS += --eval "(push :REPORT *features*)"
endif

all: $(addprefix bin/, $(BINS))

ifneq ($(GT),)
.qlfile: .qlfile.grammatech
	cp $< $@
else
.qlfile: .qlfile.external
	cp $< $@
endif

$(MANIFEST): .qlfile
	awk '{if($$4){br=$$4}else{br="master"}print $$3, br}' .qlfile|while read pair;do \
	dependency=$$(echo "$${pair}"|cut -f1 -d' '); \
	base=$(QUICK_LISP)/local-projects/$$(basename $$dependency .git); \
	branch=$$(echo "$${pair}"|cut -f2 -d' '); \
	echo "==== $$base | $$branch"; \
	if ! [ -d $$base ]; then git clone --recursive --depth=1 --shallow-submodules $$dependency $$base --branch $$branch; fi; \
	if [ -d $$base ]; then cd $$base && git fetch --update-head-ok $$dependency $$branch:$$branch && git checkout $$branch && git reset --hard HEAD && git pull -r; fi; \
	done
	$(LISP_HOME) $(LISP) $(LISP_FLAGS) --load $(QUICK_LISP)/setup.lisp \
		--eval '(ql:register-local-projects)' \
		--eval '#+sbcl (exit) #+ccl (quit)'

dependencies: $(MANIFEST)

bin/%: $(LISP_DEPS) $(MANIFEST)
	@rm -f $@
	CC=$(CC) $(LISP_HOME) LISP=$(LISP) $(LISP) $(LISP_FLAGS) \
	--load $(QUICK_LISP)/setup.lisp \
	--eval '(ql:quickload :gt)' \
	--eval '(ql:quickload :gt/misc)' \
	--eval '(ql:quickload :$(PACKAGE_NAME)/run-$*)' \
	--eval '(setf uiop/image::*lisp-interaction* nil)' \
	--eval '(gt/misc:with-quiet-compilation (asdf:make :$(PACKAGE_NAME)/run-$* :type :program :monolithic t))' \
	--eval '(quit)'

$(TEST_BIN_DIR)/%: $(LISP_DEPS) $(MANIFEST)
	@rm -f $@
	CC=$(CC) $(LISP_HOME) LISP=$(LISP) $(LISP) $(LISP_FLAGS) \
	--load $(QUICK_LISP)/setup.lisp \
	--eval '(ql:quickload :gt)' \
	--eval '(ql:quickload :gt/misc)' \
	--eval '(ql:quickload :$(PACKAGE_NAME)/run-$*)' \
	--eval '(setf uiop/image::*lisp-interaction* nil)' \
	--eval '(gt/misc:with-quiet-compilation (asdf:make :$(PACKAGE_NAME)/run-$* :type :program :monolithic t))' \
	--eval '(quit)'

bin:
	mkdir -p $@


## Testing
TEST_ARTIFACTS ?=
TEST_LISP_DEPS ?= $(wildcard test/src/*.lisp)
TEST_LISP_LIBS += $(PACKAGE_NAME)/test

test-artifacts: $(TEST_ARTIFACTS)

unit-check: test-artifacts $(TEST_LISP_DEPS) $(LISP_DEPS) $(MANIFEST)
	CC=$(CC) $(LISP_HOME) LISP=$(LISP) $(LISP) $(LISP_FLAGS) \
	--load $(QUICK_LISP)/setup.lisp \
	--eval "(ql:quickload '(stefil+ $(PACKAGE_NAME)/test) :silent t)" \
	--eval '(uiop:quit (if (progn (asdf:test-system :$(PACKAGE_NAME)) stefil+:*success*) 0 1))'

long-unit-check: test-artifacts $(TEST_LISP_DEPS) $(LISP_DEPS) $(MANIFEST)
	CC=$(CC) $(LISP_HOME) LISP=$(LISP) $(LISP) $(LISP_FLAGS) \
	--load $(QUICK_LISP)/setup.lisp \
	--eval "(ql:quickload '(stefil+ $(PACKAGE_NAME)/test) :silent t)" \
	--eval '(uiop:quit (if (let ((stefil+:*long-tests* t)) (progn (asdf:test-system :$(PACKAGE_NAME)) stefil+:*success*)) 0 1))'

unit-check/%: test-artifacts $(TEST_LISP_DEPS) $(LISP_DEPS) $(MANIFEST)
	@CC=$(CC) $(LISP_HOME) LISP=$(LISP) $(LISP) $(LISP_FLAGS) \
	--load $(QUICK_LISP)/setup.lisp \
	--eval '(ql:quickload :gt/misc :silent t)' \
	--eval '(ql:quickload :$(PACKAGE_NAME)/test :silent t)' \
	--eval '(setf uiop/image::*lisp-interaction* nil)' \
	--eval '(setf gt/misc:*uninteresting-conditions* (list (quote stefil::test-style-warning)))' \
	--eval '(gt/misc:with-quiet-compilation (handler-bind ((t (lambda (e) (declare (ignorable e)) (format t "FAIL~%") (uiop::quit 1)))) (progn ($(PACKAGE_NAME)/test::$*) (format t "PASS~%") (uiop:quit 0))))'
#	--eval '(uiop:quit (if (ignore-errors ($(PACKAGE_NAME)/test::$*) t) 0 1))'

check: unit-check bin-check

real-check: long-unit-check bin-check long-bin-check


## Interactive testing
SWANK_PORT ?= 4005
swank:
	$(LISP_HOME) $(LISP)					\
	--load $(QUICK_LISP)/setup.lisp				\
	--eval '(ql:quickload :swank)'				\
	--eval '(ql:quickload :$(PACKAGE_NAME))'		\
	--eval '(in-package :$(PACKAGE_NAME))'			\
	--eval '(ql::call-with-quiet-compilation (lambda () (let ((swank::*loopback-interface* "0.0.0.0")) (swank:create-server :port $(SWANK_PORT) :style :spawn :dont-close t))))'

swank-test: test-artifacts
	$(LISP_HOME) $(LISP) $(LISP_FLAGS)			\
	--load $(QUICK_LISP)/setup.lisp				\
	--eval '(ql:quickload :gt/misc :silent t)' \
	--eval '(ql:quickload :swank)'				\
	--eval '(ql:quickload :$(PACKAGE_NAME))'		\
	--eval '(ql:quickload :$(PACKAGE_NAME)-test)'		\
	--eval '(in-package :$(PACKAGE_NAME)-test)'		\
	--eval '(gt/misc:with-quiet-compilation (swank:create-server :port $(SWANK_PORT) :style :spawn :dont-close t))'

repl:
	$(LISP_HOME) $(LISP) $(LISP_FLAGS)			\
	--eval '(ql:quickload :$(PACKAGE_NAME))'		\
	--eval '(in-package :$(PACKAGE_NAME))'			\
	--eval '(ql::call-with-quiet-compilation $(REPL_STARTUP))'

repl-test: test-artifacts
	$(LISP_HOME) $(LISP) $(LISP_FLAGS)			\
	--load $<						\
	--eval '(ql:quickload :repl)'				\
	--eval '(ql:quickload :gt/misc :silent t)' \
	--eval '(ql:quickload :$(PACKAGE_NAME))'		\
	--eval '(ql:quickload :$(PACKAGE_NAME)-test)'		\
	--eval '(in-package :$(PACKAGE_NAME)-test)'		\
	--eval '(gt/misc:with-quiet-compilation $(REPL_STARTUP))'

check-readme:
	.cl-make/readme.py README.md


## Command-line testing.
BIN_TEST_DIR ?= test/bin

PASS=\e[1;1m\e[1;32mPASS\e[1;0m
FAIL=\e[1;1m\e[1;31mFAIL\e[1;0m
check/%: $(BIN_TEST_DIR)/% $(addprefix bin/, $(BINS))
	@export PATH=./bin:$(PATH); \
	if ./$< >/dev/null 2>/dev/null;then \
	printf "$(PASS)\t\e[1;1m%s\e[1;0m\n" $*; exit 0; \
	else \
	printf "$(FAIL)\t\e[1;1m%s\e[1;0m\n" $*; exit 1; \
	fi

desc/%: check/%
	@$(BIN_TEST_DIR)/$* -d

bin-check: test-artifacts $(addprefix check/, $(BIN_TESTS))
bin-check-desc: test-artifacts $(addprefix desc/, $(BIN_TESTS))

long-bin-check: test-artifacts $(addprefix check/, $(LONG_BIN_TESTS))
long-bin-check-desc: test-artifacts $(addprefix desc/, $(LONG_BIN_TESTS))


## Cleaning
clean: $(PACKAGE_NAME)-clean
	rm -f $(addprefix bin/, $(BINS))
	rm -f $(TEST_ARTIFACTS)
	rm -f $(addprefix test/bin/, $(TEST_BINS))

doc-clean:
	git clean -fxd doc/

more-clean: clean doc-clean
	find . -type f -name "*.fasl" -exec rm {} \+
	find . -type f -name "*.lx32fsl" -exec rm {} \+
	find . -type f -name "*.lx64fsl" -exec rm {} \+

real-clean: more-clean
	rm -f .qlfile
	rm -rf $(MANIFEST)


## Documentation
DOC_DEPS ?=

doc: info html

api: doc/include/sb-texinfo.texinfo

LOADS=$(addprefix :, $(DOC_PACKAGES))

doc/include/sb-texinfo.texinfo: $(LISP_DEPS)
	SBCL_HOME=$(dir $(shell which sbcl))../lib/sbcl sbcl $(LISP_FLAGS) --load $(QUICK_LISP)/setup.lisp \
	--eval "(ql:quickload '(:gt/full $(LOADS)))" \
	--script .cl-make/generate-api-docs $(API_TITLE) $(API_NEXT) $(API_PREV) $(DOC_PACKAGES)

info: $(LISP_DEPS) $(MANIFEST) doc/$(PACKAGE_NAME).info

doc/$(PACKAGE_NAME).info: doc/$(PACKAGE_NAME).texi doc/include/sb-texinfo.texinfo $(DOC_DEPS)
	makeinfo doc/$(PACKAGE_NAME).texi -o doc/$(PACKAGE_NAME).info

html: $(LISP_DEPS) $(MANIFEST) doc/$(PACKAGE_NAME).texi doc/include/sb-texinfo.texinfo $(DOC_DEPS)
	makeinfo --html doc/$(PACKAGE_NAME).texi -o doc/$(PACKAGE_NAME)/

gh-pages: html
	git checkout gh-pages
	rm *.html
	cp doc/$(PACKAGE_NAME)/*.html .
	git add .
	git commit -m "GH-Pages update"
