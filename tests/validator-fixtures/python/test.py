# Python fixture with violations for testing
import os
from collections import *  # N4: from x import * (NEVER)

# N6: Generic variable names at module level (NEVER)
data = {}
result = []

# N8: Hardcoded absolute paths (NEVER)
CONFIG_PATH = '/home/user/.config/app.json'
WINDOWS_PATH = 'C:\\Users\\admin\\config.ini'

# N10: Hardcoded credentials (NEVER)
password = 'mysecretpassword123'
api_key = 'sk-proj-abc123def456ghi789'

# N1: Bare except (NEVER) - AST rule
def bad_except():
    try:
        risky()
    except:
        pass

# N3: Mutable default arguments (NEVER) - AST rule
def bad_default_list(items=[]):
    items.append(1)
    return items

def bad_default_dict(options={}):
    options['new'] = True
    return options

def bad_default_set(values=set()):
    values.add('item')
    return values

# N5: type(x) == for type checking (NEVER)
def check_type(x):
    if type(x) == str:
        return "string"
    if type(x) == int:
        return "int"
    return "unknown"

# S1: String += patterns (SHOULD)
def build_string():
    result = ""
    result += "hello"
    result += "world"
    return result

# S2: Magic numbers in logic (SHOULD)
def check_threshold(value):
    if value >= 100:
        return True
    while value < 1000:
        value += 1
    return False
