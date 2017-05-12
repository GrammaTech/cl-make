# A shared Makefile to be use in CL projects

To use this file first define the following variables in your makefile
and then include cl.mk.

| Variable Name        | Description                               | Default value |
|----------------------+-------------------------------------------+---------------|
| `PACKAGE_NAME`       | The full name of the CL package           |               |
| `PACKAGE_NICKNAME`   | The nickname of the CL package            | PACKAGE_NAME  |
| `PACKAGE_NAME_FIRST` | The first package name to require         | PACKAGE_NAME  |
| `BINS`               | Names of binaries to build with buildapp  |               |
| `TEST_ARTIFACTS`     | Name of dependencies for testing          |               |
| `LISP_DEPS`          | Packages require to build CL package      |               |
| `TEST_LISP_DEPS`     | Packages require to build CL test package |               |

An example usage would be the following Makefile.

```make
.PHONY: doc

# Set personal or machine-local flags in a file named local.mk
ifneq ("$(wildcard local.mk)","")
include local.mk
endif

PACKAGE_NAME = software-evolution
PACKAGE_NICKNAME = se
PACKAGE_NAME_FIRST = software-evolution-utility
LISP_DEPS =				\
	$(wildcard *.lisp) 		\
	$(wildcard src/*.lisp)		\
	$(wildcard software/*.lisp)	\
	$(wildcard utility/*.lisp)

test/etc/gcd/gcd: test/etc/gcd/gcd.c
	$(CC) $< -o $@

test/etc/gcd/gcd.s: test/etc/gcd/gcd.c
	$(CC) $< -S -o $@

TEST_ARTIFACTS = \
	test/etc/gcd/gcd \
	test/etc/gcd/gcd.s

include cl.mk


## Documentation
doc:
	make -C doc
```
