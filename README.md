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

To include this into a git repository try the following, taken from
the
[Subtree Merging](https://git-scm.com/book/en/v1/Git-Tools-Subtree-Merging)
instructions in the git book.  Here's an abbreviated example.

    $ git init .
    Initialized empty Git repository in /tmp/example-cl/.git/

    $ git add .

    $ echo "a test CL repo" > README.md

    $ git commit -m "initial commit"
    [master (root-commit) 5eafa2d] initial commit
     1 file changed, 1 insertion(+)
     create mode 100644 README.md

    $ git remote add cl-make git@git:synthesis/cl-make.git

    $ git fetch cl-make
    warning: no common commits
    remote: Counting objects: 4, done.
    remote: Compressing objects: 100% (4/4), done.
    remote: Total 4 (delta 0), reused 0 (delta 0)
    Unpacking objects: 100% (4/4), done.
    From git:synthesis/cl-make
     * [new branch]      master     -> cl-make/master

    $ git checkout -b cl-make cl-make/master
    Branch cl-make set up to track remote branch master from cl-make.
    Switched to a new branch 'cl-make'

    $ git checkout master
    Switched to branch 'master'

    $ git read-tree --prefix=.cl-make/ -u cl-make

    $ git status
    On branch master
    Changes to be committed:
      (use "git reset HEAD <file>..." to unstage)

            new file:   .cl-make/README.md
            new file:   .cl-make/cl.mk

    $ git commit -m "brought in cl-make to .cl-make"
    [master 47ceba0] brought in cl-make to .cl-make
     2 files changed, 192 insertions(+)
     create mode 100644 .cl-make/README.md
     create mode 100644 .cl-make/cl.mk

Merging in later changes works but wasn't (in my case) quite as easy
and is described in
[Subtree Merging](https://git-scm.com/book/en/v1/Git-Tools-Subtree-Merging)
because I had to add the `--allow-unrelated-histories` option to the
`git merge` command and then manually fix a trivial merge conflict.

    $ git checkout cl-make
    Switched to branch 'cl-make'
    Your branch is up-to-date with 'cl-make/master'.

    $ git pull
    remote: Counting objects: 3, done.
    remote: Compressing objects: 100% (3/3), done.
    remote: Total 3 (delta 0), reused 0 (delta 0)
    Unpacking objects: 100% (3/3), done.
    From git:synthesis/cl-make
       28371b9..15878ce  master     -> cl-make/master
    Updating 28371b9..15878ce
    Fast-forward
     README.md | 54 ++++++++++++++++++++++++++++++++++++++++++++++++++++++
     1 file changed, 54 insertions(+)

    $ git checkout master
    Switched to branch 'master'

    $ git merge --squash -s subtree --no-commit cl-make
    fatal: refusing to merge unrelated histories

    $ git merge --squash -s subtree --no-commit --allow-unrelated-histories cl-make
    Auto-merging .cl-make/README.md
    CONFLICT (add/add): Merge conflict in .cl-make/README.md
    Squash commit -- not updating HEAD
    Automatic merge failed; fix conflicts and then commit the result.

    # Manually do trivial merge conflict resolution.

    $ git commit -m "updated from remote (with some merge resolutions)"
    [master 6ee2b7b] updated from remote (with some merge resolutions)
     1 file changed, 54 insertions(+)
