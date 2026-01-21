# N4: Testing Private Methods - VIOLATIONS

def test_private_method():
    obj = create_object()
    assert obj._private_method() == True

def test_private_attribute():
    obj = create_object()
    assert obj._internal_value == 42

def test_dunder_private():
    obj = create_object()
    assert obj.__very_private is not None
