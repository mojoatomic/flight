# S4: Logic in Tests - VIOLATIONS

def test_with_if_logic():
    items = get_items()
    if len(items) > 0:
        assert items[0] is not None

def test_with_for_loop():
    items = get_items()
    for item in items:
        assert item.valid == True

def test_with_while_loop():
    count = 0
    while count < 5:
        assert get_data(count) is not None
        count += 1
