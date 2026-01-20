# N1: Bare except violations (should be caught)

def risky_operation():
    try:
        do_something()
    except:  # VIOLATION
        pass

def another_risky():
    try:
        another_thing()
    except:  # VIOLATION
        log_error()

class ErrorHandler:
    def handle(self):
        try:
            self.process()
        except:  # VIOLATION
            self.recover()
