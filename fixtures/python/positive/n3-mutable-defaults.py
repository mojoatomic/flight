# N3: Mutable default argument violations (should be caught)

def add_item(item, items=[]):  # VIOLATION
    items.append(item)
    return items

def merge_data(data, result={}):  # VIOLATION
    result.update(data)
    return result

def collect_unique(item, seen=set()):  # VIOLATION
    seen.add(item)
    return seen

class DataCollector:
    def accumulate(self, value, cache=[]):  # VIOLATION
        cache.append(value)
        return cache
