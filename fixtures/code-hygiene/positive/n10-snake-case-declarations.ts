// Code hygiene test fixture - SHOULD trigger N10_js violations
// snake_case declarations in TypeScript (should be camelCase)

// BAD: snake_case variable declarations
const user_name = 'alice';
const user_email = 'alice@example.com';
let user_age = 30;
var api_key = 'secret';

// BAD: snake_case function declaration
function get_user_by_id(id: string) {
  return { id };
}

// BAD: snake_case arrow function
const fetch_user_data = async () => {
  return {};
};

// BAD: snake_case method in class
class UserService {
  get_all_users() {
    return [];
  }

  update_user_profile(id: string) {
    return id;
  }
}

export { user_name, user_email, get_user_by_id, fetch_user_data };
