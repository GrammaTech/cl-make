#!/usr/bin/env python3

"""
Check Lisp examples in a Markdown file.

To run (assuming this repo is a submodule in a dir called .cl-make):

    $ pip3 install -r .cl-make/requirements.txt
    $ .cl-make/readme.py README.md

The return code is zero iff all Lisp examples in the file run without
errors in an SBCL REPL and their outputs match the given outputs. Such
output can be specified in a language-less code block immediately
following the Lisp code block.

The whole REPL session is printed to stdout. If the REPL session exits
unexpectedly, or any evaluation takes longer than 30 seconds, or an
error occurs, or the output doesn't match, then a descriptive error
message is printed to stderr and an exit code of 1 is returned. A
standalone Lisp file is created to reproduce the environment for the
failing Lisp form, and all this reproduction information is included in
the error message.

This script uses pytest internally, and thus can also return other exit
codes: https://docs.pytest.org/en/6.0.1/usage.html#possible-exit-codes
"""

import argparse
import difflib
import logging
import os
import pathlib
import sys
import tempfile

import marko.block as block
from marko.ext.gfm import gfm
import pexpect
import pytest


def pairwise(things):
    """
    Return a list of pairs of adjacent elements from things.

    The last element of this list is the pair (things[-1], None).

    >>> list(pairwise(['a', 'b', 'c']))
    [('a', 'b'), ('b', 'c'), ('c', None)]

    >>> list(pairwise([]))
    []
    """
    return zip(things, things[1:] + [None])


def is_code_block(element):
    """
    Return truthy iff the Marko element is a code block.

    >>> is_code_block(gfm.parse('''    foo''').children[0])
    True

    >>> is_code_block(gfm.parse('''```
    ... bar
    ... ```''').children[0])
    True

    >>> is_code_block(gfm.parse('''> baz''').children[0])
    False
    """
    types = [block.CodeBlock, block.FencedCode]
    return any(isinstance(element, t) for t in types)


def code_block_to_dict(code_block):
    r"""
    Return a dict of the lang and text of the Marko code block.

    >>> code_block_to_dict(gfm.parse('''```lisp
    ... (+ 2
    ...    2)
    ... ```''').children[0])
    {'lang': 'lisp', 'text': '(+ 2\n   2)\n'}

    >>> code_block_to_dict(gfm.parse('''    foo''').children[0])
    {'lang': '', 'text': 'foo\n'}
    """
    return {
        'lang': code_block.lang,
        # should only have one child but just in case; also, children of
        # the child is just a string holding the text
        'text': ''.join(child.children for child in code_block.children),
    }


def slurp(filename):
    """
    Return the contents of filename as a string.

    >>> 'public domain' in slurp('LICENSE.txt')
    True
    """
    with open(filename) as file:
        return file.read()


def lisp_examples(element):
    r"""
    Return a list of all Lisp examples in the Marko element.

    A Lisp example is a code block whose language is 'lisp', and is
    returned as a dictionary whose key 'code' holds the text of that
    code block. If the Lisp code block is immediately followed by
    another code block whose language is the empty string, then the text
    of that second block is also included in the dictionary, under the
    key 'output'.

    >>> from pprint import pprint
    >>> examples = lisp_examples(gfm.parse(slurp('test/example.md')))
    >>> pprint(examples, width=68)
    [{'code': '(format t "Hello, world 1!")\n',
      'output': 'Hello, world 1!\nNIL\n'},
     {'code': '(format t "Hello, world 4!")\n',
      'output': 'Hello, world 4!\nNIL\n'},
     {'code': '(format nil "Hello, world 5!")\n'}]
    """
    examples = []
    if hasattr(element, 'children'):
        children = element.children
        # sometimes the children are just a string holding the text
        if isinstance(children, list):
            # don't let blank lines get in the middle of an example
            pared = [x for x in children if not isinstance(x, block.BlankLine)]
            for a, b in pairwise(pared):
                if is_code_block(a):
                    code = code_block_to_dict(a)
                    if code['lang'] == 'lisp':
                        example = {'code': code['text']}
                        if is_code_block(b):
                            output = code_block_to_dict(b)
                            if not output['lang']:
                                example['output'] = output['text']
                        examples.append(example)
                else:
                    # will safely skip when a has no grandchildren
                    examples.extend(lisp_examples(a))
    return examples


# regex matching the default SBCL prompt, only at the start of a line
prompt = r'(?<![^\n])\* '
# possibilities when we eval
patterns = [prompt, pexpect.EOF, pexpect.TIMEOUT]


class ExitException(Exception):
    pass


class TimeoutException(Exception):
    pass


class MismatchException(Exception):
    def __init__(self, actual):
        self.actual = actual


class ReadmeItem(pytest.Item):
    def __init__(self, name, parent, code, output):
        super().__init__(name, parent)
        self.code = code
        self.output = output

    def runtest(self):
        code = self.code
        repl.send(code)
        index = repl.expect(patterns)
        # Pexpect returns CR/LF
        actual = repl.before.replace('\r\n', '\n')
        # print nicely as if input/output were in actual REPL session
        logging.info('* ' + '\n  '.join(code.splitlines()) + f'\n{actual}')
        if index == patterns.index(pexpect.EOF):
            raise ExitException()
        elif index == patterns.index(pexpect.TIMEOUT):
            # the error is (?) shown in the log to stdout
            raise TimeoutException()
        else:
            expected = self.output
            if expected and expected != actual:
                # the actual output is (?) shown in the log to stdout
                raise MismatchException(actual)
            else:
                # track all the forms we successfully evaluate up until
                # the first error (if any)
                forms.append(code)

    def reportinfo(self):
        return self.fspath, 0, f'[readme] Lisp example #{self.name}'

    def repr_failure(self, excinfo):
        tmp = tempfile.NamedTemporaryFile(
            mode='w',
            suffix='.lisp',
            prefix=f'{pathlib.Path(self.parent.fspath).stem}_',
            delete=False,
        )
        repro = tmp.name
        tmp.write('\n'.join(forms))
        tmp.close()

        if isinstance(excinfo.value, ExitException):
            reason = 'Exited REPL unexpectedly.\n'
        if isinstance(excinfo.value, TimeoutException):
            # the error is shown in the log to stdout
            reason = 'Timeout: either took too long or an error occurred.\n'
        if isinstance(excinfo.value, MismatchException):
            diff = list(difflib.ndiff(
                self.output.splitlines(keepends=True),
                excinfo.value.actual.splitlines(keepends=True),
            ))
            # the full actual output is shown in the log to stdout
            reason = '    '.join(
                ['Differences (ndiff with -expected +actual):\n\n'] + diff
            )

        return '\n'.join([
            reason,
            'To reproduce this in a REPL, first evaluate all the forms up to',
            'but not including this one by running the following command:',
            '',
            f'    sbcl --load {repro}',
            '',
            'Then evaluate the erroneous form:',
            '',
        ] + [f'    {line}' for line in self.code.splitlines()])


class ReadmeFile(pytest.File):
    def collect(self):
        examples = lisp_examples(gfm.parse(slurp(self.fspath)))
        for index, example in enumerate(examples):
            yield ReadmeItem.from_parent(
                self,
                name=str(index+1),
                code=example['code'],  # mandatory
                output=example.get('output'),  # might not be present
            )


class ReadmePlugin:
    def pytest_collect_file(self, parent, path):
        # we don't check the path because our pytest invocation
        # specifies only one file, and we assume user gave us Markdown
        return ReadmeFile.from_parent(parent, fspath=path)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--timeout',
        type=float,
        help='seconds allowed for each REPL form',
    )
    parser.add_argument('file', help='a Markdown file name')
    cli_args = parser.parse_args()

    # aggregate all the forms that we evaluate successfully, so that if
    # an error occurs, the user can easily reproduce it
    forms = []
    # Quicklisp isn't present by default in a raw SBCL in the Docker
    # image, but it is installed already so we just need to load it
    args = ['--load', f'{os.environ["QUICK_LISP"]}/setup.lisp']
    repl = pexpect.spawn(
        'sbcl',
        args,
        echo=False,  # otherwise we have to strip input from repl.before
        encoding='utf-8',  # otherwise repl.before gives binary strings
        timeout=cli_args.timeout,
    )
    # nothing should go wrong before we eval anything
    repl.expect(prompt)
    exit_code = pytest.main(
        ['--exitfirst',  # the REPL can get messed up if error or exit
         '--log-cli-level=INFO',  # print every input and output
         '--log-format=%(message)s',
         '--show-capture=no',  # don't reprint input/output on failure
         '--',  # don't choke on filenames starting with dashes
         cli_args.file],
        plugins=[ReadmePlugin()]
    )
    sys.exit(exit_code)
