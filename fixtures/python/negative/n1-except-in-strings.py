# N1: False positives - except: in strings (should NOT be caught)

def documented_function():
    """Example of exception handling:

    try:
        something()
    except:
        pass

    Note: The above shows what NOT to do.
    """
    pass

error_example = "try: foo() except: bar()"

multiline_string = '''
Some code example:
    except:
        handle_error()
'''

# This is a comment with except: in it

def proper_exception_handling():
    """This function handles ValueError properly."""
    try:
        risky_call()
    except ValueError as e:  # This is OK - specific exception
        handle_error(e)
