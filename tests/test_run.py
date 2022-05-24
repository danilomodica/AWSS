import sys
sys.path.append("..")
from docker.src.run import check_string


def test_numbers():
    if check_string('12345') is False:
        assert True
    else:
        assert False


def test_wrong_dna_chars():
    if check_string('qwerty') is False:
        assert True
    else:
        assert False


def test_correct_dna_chars_upper():
    if check_string('ACTG') is False:
        assert False
    else:
        assert True


def test_correct_dna_chars_lower():
    if check_string('acTg') is False:
        assert False
    else:
        assert True
