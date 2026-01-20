# N3: False positives - mutable defaults in strings (should NOT be caught)

def documented_function():
    """Bad example:

    def bad(items=[]):
        pass

    Good example:

    def good(items=None):
        if items is None:
            items = []
    """
    pass

code_example = "def example(data={}):"

pattern_string = '''
Anti-pattern: def collect(s=set())
'''

# Comment: def bad_func(x=[])

def proper_defaults(items=None, data=None):
    """This function uses None defaults properly."""
    if items is None:
        items = []
    if data is None:
        data = {}
    return items, data
