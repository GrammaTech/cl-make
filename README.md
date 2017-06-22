# A shared Makefile to be use in CL projects

- [Makefile Configuration](makefile-configuration)
- [Repository Configuration](repository-configuration)

## Makefile Configuration

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
| `HARD_QUIT`          | Compile bins to exit on error             |               |

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

TEST_ARTIFACTS = \
	test/etc/gcd/gcd \
	test/etc/gcd/gcd.s

HARD_QUIT = yes

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

## Repository Configuration

To include this into a git repository try the following, markedly
simplified from the
[Subtree Merging](https://git-scm.com/book/en/v1/Git-Tools-Subtree-Merging)
instructions in the git book.

The first time, you will create a local `cl-make` branch pointing to
the `wo-readme` branch of the cl-make git repository.

    $ git remote add cl-make git@git:synthesis/cl-make.git

    $ git fetch cl-make

    $ git checkout -b cl-make cl-make/wo-readme

    $ git checkout master

Then you'll merge this branch into your master branch bringing the
`cl.mk` file into your repository.

    $ git merge cl-make --allow-unrelated-histories

On subsequent updates you can `git pull` from the remote cl-make
repository into your `cl-make` branch, and then merge those changes
into your master branch.  The `--allow-unrelated-histories` flag
should not be required for subsequent merges.

## Splitting out `wo-readme` branch

Was done with the following.

    git checkout -b wo-readme master
    git filter-branch -f --prune-empty --index-filter 'git rm -f -q README.md;fi' -- wo-readme
