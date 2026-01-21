# Code hygiene test fixture - SHOULD trigger N10_py violations
# camelCase declarations in Python (should be snake_case)

# BAD: camelCase function definitions
def getUserById(user_id):
    return {"id": user_id}

def fetchUserData():
    return {}

def processApiResponse(response):
    return response

# BAD: camelCase variable assignments
userName = "alice"
userEmail = "alice@example.com"
apiKey = "secret"

# This class name is OK (PascalCase for classes)
class UserManager:
    # BAD: camelCase method
    def getAllUsers(self):
        return []
