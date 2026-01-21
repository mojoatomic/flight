# N3: Hardcoded Sleep/Delays - VIOLATIONS
import time

def test_with_time_sleep():
    time.sleep(1)
    assert True

def test_with_longer_sleep():
    time.sleep(2.5)
    assert True
