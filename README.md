# A shared Makefile to be use in CL projects

- [Makefile Configuration](makefile-configuration)
- [Repository Configuration](repository-configuration)

## Makefile Configuration

To use this file first define the following variables in your makefile
and then include cl.mk.

| Variable Name        | Description                                       | Default value |
|----------------------|---------------------------------------------------|---------------|
| `PACKAGE_NAME`       | The full name of the CL package                   |               |
| `PACKAGE_NICKNAME`   | The nickname of the CL package                    | PACKAGE_NAME  |
| `DOC_PACKAGES`       | Names of the packages to document                 | PACKAGE_NAME  |
| `DOC_DEPS`           | Optional additional Makefile doc targets          |               |
| `BINS`               | Names of binaries to build with buildapp          |               |
| `TEST_ARTIFACTS`     | Name of dependencies for testing                  |               |
| `TEST_BINS`          | Names of lisp binaries needed for testing         |               |
| `TEST_BIN_DIR`       | Directory of the lisp binaries needed for testing |               |
| `LISP_DEPS`          | Files required to build CL package                |               |
| `TEST_LISP_DEPS`     | Files required to build CL test package           |               |
| `BIN_TEST_DIR`       | Directory holding command line tests              |               |
| `BIN_TESTS`          | List of command line tests                        |               |
| `LONG_BIN_TESTS`     | List of longer running command line tests         |               |

An example usage would be the following Makefile.

```make
.PHONY: doc

# Set personal or machine-local flags in a file named local.mk
ifneq ("$(wildcard local.mk)","")
include .cl-make/local.mk
endif

PACKAGE_NAME = software-evolution
PACKAGE_NICKNAME = se
LISP_DEPS =				\
	$(wildcard *.lisp) 		\
	$(wildcard src/*.lisp)		\
	$(wildcard software/*.lisp)	\
	$(wildcard utility/*.lisp)

TEST_ARTIFACTS = \
	test/etc/gcd/gcd \
	test/etc/gcd/gcd.s

BINS = example-se-executable

include cl.mk

test/etc/gcd/gcd: test/etc/gcd/gcd.c
	$(CC) $< -o $@

test/etc/gcd/gcd.s: test/etc/gcd/gcd.c
	$(CC) $< -S -o $@


## Documentation
doc:
	make -C doc
```

### Building binaries
For each name in the `BINS` variable, a binary will be built with that 
name, which calls `$PACKAGE_NICKNAME:$NAME` as its main entry function.

### Running tests
Your project should include a package named `$PACKAGE_NICKNAME-test`, 
which includes the functions `run-batch` (to run tests and print results
to the console) and `run-testbot` (to run tests and submit results to
datamanager). 

The make targets `$PACKAGE_NICKNAME-test`, `$PACKAGE_NICKNAME-testbot`, 
`check`, and `check-testbot` are defined automatically. The first two are 
the test executables, and the last two will run the corresponding 
executable as well as building it.

## Repository Configuration

It is probably best to include this project as a git submodule into
your existing Common Lisp project git repository.  The example
Makefile above assumes that you have cloned this into the `.cl-make/`
sub-directory of your project, e.g. with the following:

```shell
git submodule add https://github.com/grammatech/cl-make.git .cl-make
```
