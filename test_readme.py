import os

from readme import slurp
from update_tests import collect


def test_files(subtests):
    keys = set()
    for stem, output, lisp in collect():
        # get informative test output in case one of the files fails
        with subtests.test(msg=stem):
            keys.add(stem)
            assert output == slurp(f'{stem}.txt')
            lisp_path = f'{stem}.lisp'
            # only exists if one of the examples in the file fails
            lisp_exists = os.path.isfile(lisp_path)
            if lisp:
                assert lisp_exists
                assert lisp == slurp(lisp_path)
            else:
                assert not lisp_exists
    # make sure we didn't forget anything
    assert keys == {
        '--dashes',
        'diff',
        'empty',
        'error',
        'example',
        'exit',
        'last',
        'math',
        'multiline',
        'success',
    }
