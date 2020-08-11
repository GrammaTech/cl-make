import os

from readme import slurp
from update_tests import collect

# filenames in test dir (sans .md) and exit codes
cases = {
    '--dashes': 0,
    'diff': 1,
    'empty': 0,
    'error': 1,
    'example': 0,
    'exit': 1,
    'last': 1,
    'math': 1,
    'multiline': 1,
    'success': 0,
}


def test_files(subtests):
    keys = set()
    for stem, exit_code, output, lisp in collect():
        # get informative test output in case one of the files fails
        with subtests.test(msg=stem):
            keys.add(stem)
            assert exit_code == cases[stem]
            assert output == slurp(f'{stem}.txt')
            lisp_path = f'{stem}.lisp'
            # only exists if one of the examples in the file fails
            lisp_exists = os.path.isfile(lisp_path)
            if lisp is not None:
                assert exit_code != 0
                assert lisp_exists
                assert lisp == slurp(lisp_path)
            else:
                assert exit_code == 0
                assert not lisp_exists
    # make sure we didn't forget anything
    assert keys == cases.keys()
