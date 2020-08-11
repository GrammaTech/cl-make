#!/usr/bin/env python3

"""
Update the readme.py tests in this repository.
"""

import glob
import os
import re
import subprocess
import tempfile

from readme import slurp


def normalize(output):
    """
    Replace nondeterministic parts from readme.py output.

    >>> normed = normalize('''=== test session starts ===
    ... platform linux -- Python 3.8.5
    ... rootdir: /dir/cl-make, configfile: pytest.ini
    ... plugins: subtests-0.3.2
    ... collected 42 items
    ...   blah blah
    ... debugger invoked on a SB-KERNEL:CASE-FAILURE in thread
    ... #<THREAD "main thread" RUNNING {123456789A}>:
    ...   blah blah
    ...     sbcl --load /tmp/foo_abcd_efg.lisp
    ...   blah blah
    ... === 1 failed, 23 passed in 1.23s ===
    ... ''')
    >>> normed['tmp']
    '/tmp/foo_abcd_efg.lisp'
    >>> print(normed['out'], end='')
    === test session starts ===
    platform linux -- Python 0.0.0
    rootdir: cl-make, configfile: pytest.ini
    collected 42 items
      blah blah
    debugger invoked on a SB-KERNEL:CASE-FAILURE in thread
    #<THREAD "main thread" RUNNING {1000000000}>:
      blah blah
        sbcl --load /tmp/foo_________.lisp
      blah blah
    === 1 failed, 23 passed in 0.00s ===

    >>> normed = normalize('''=== test session starts ===
    ... platform linux -- Python 3.8.5
    ... rootdir: /dir/cl-make, configfile: pytest.ini
    ... collected 1 item
    ...   blah blah
    ... === 1 passed in 1.23s ===
    ... ''')
    >>> normed['tmp'] is None
    True
    >>> print(normed['out'], end='')
    === test session starts ===
    platform linux -- Python 0.0.0
    rootdir: cl-make, configfile: pytest.ini
    collected 1 item
      blah blah
    === 1 passed in 0.00s ===
    """
    # random temorary filename
    obj = {'tmp': None}

    def tmp_replace(m):
        obj['tmp'] = m.group(0)
        return f'{m.group(1)}{"_"*8}{m.group(2)}'

    output = re.sub(r'(/tmp/\w+_)\w{8}(.lisp)', tmp_replace, output)
    # pointers from Lisp
    output = re.sub(r' \{[0-9A-F]{10}\}>', f' {{1{"0"*9}}}>', output)
    lines = output.splitlines(keepends=True)
    # dependency version numbers
    lines[1] = re.sub(r'\d+\.\d+\.\d+', '0.0.0', lines[1])
    # local directory names
    lines[2] = re.sub(r'^(rootdir: ).*(cl-make)', r'\1\2', lines[2])
    # plugins may or may not be installed
    if re.match(r'^plugins:', lines[3]):
        del lines[3]
    # runtime
    lines[-1] = re.sub(r'\d\.\d{2}s', '0.00s', lines[-1])
    obj['out'] = ''.join(lines)
    return obj


def cmd(args):
    """
    Return the output from running a command whether it succeeds or not.
    """
    try:
        return {
            'exit_code': 0,
            'output': subprocess.check_output(args, encoding='utf-8'),
        }
    except subprocess.CalledProcessError as error:
        return {'exit_code': error.returncode, 'output': error.output}


def collect():
    """
    Return normalized outputs for all files in the test directory.
    """
    os.chdir('test')  # to catch possible bug with --dashes.md
    for filename in glob.glob('*.md'):
        stem, _ = os.path.splitext(filename)
        args = ['../readme.py', '--timeout=1', '--', filename]
        result = cmd(args)
        obj = normalize(result['output'])
        tmp = obj['tmp']
        lisp = slurp(tmp) if tmp else None
        yield stem, result['exit_code'], obj['out'], lisp


def spit(filename, contents):
    """
    Write the string contents contents to the file.

    >>> path = tempfile.mktemp()
    >>> spit(path, 'Hello, world!')
    >>> slurp(path)
    'Hello, world!'
    """
    with open(filename, 'w') as file:
        file.write(contents)


if __name__ == '__main__':
    for stem, _, output, lisp in collect():
        print(stem)  # to show progress, since these runs are a bit slow
        spit(f'{stem}.txt', output)
        if lisp is not None:
            spit(f'{stem}.lisp', lisp)
