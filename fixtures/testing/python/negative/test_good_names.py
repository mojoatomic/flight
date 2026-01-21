# N1: Good Test Names - NO VIOLATIONS
# These should NOT be flagged

def test_returns_user_when_valid_id():
    assert True

def test_handles_empty_list():
    assert True

def test_validates_email_format():
    assert True

def test_raises_error_on_invalid_input():
    assert True

# Descriptive names with numbers in context (OK)
def test_handles_http_404_response():
    assert True

def test_parses_iso_8601_dates():
    assert True
