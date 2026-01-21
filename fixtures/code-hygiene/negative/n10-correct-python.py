# Code hygiene test fixture - Should NOT trigger N10_py violations
# Correct snake_case declarations in Python

# GOOD: snake_case function definitions
def get_user_by_id(user_id):
    return {"id": user_id}

def fetch_user_data():
    return {}

def process_api_response(response):
    return response

# GOOD: snake_case variable assignments
user_name = "alice"
user_email = "alice@example.com"
api_key = "secret"

# GOOD: PascalCase for class names (not flagged)
class UserManager:
    # GOOD: snake_case method
    def get_all_users(self):
        return []

# GOOD: Constants in UPPER_CASE (not flagged)
MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30

# GOOD: Accessing external API data with camelCase keys
# This should NOT trigger - it's attribute/key access, not declarations
api_response = {
    "userId": 123,
    "userName": "alice",
}

# The variable names are snake_case (correct)
user_id = api_response["userId"]
user_name_from_api = api_response["userName"]
