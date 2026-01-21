// Code hygiene test fixture - Should NOT trigger N10_js violations
// Correct camelCase declarations in TypeScript

// GOOD: camelCase variable declarations
const userName = 'alice';
const userEmail = 'alice@example.com';
let userAge = 30;

// GOOD: camelCase function declaration
function getUserById(id: string) {
  return { id };
}

// GOOD: camelCase arrow function
const fetchUserData = async () => {
  return {};
};

// GOOD: camelCase method in class
class UserService {
  getAllUsers() {
    return [];
  }
}

// GOOD: Object literals with snake_case properties (external API mapping)
// This should NOT trigger - it's property access, not declarations
const apiResponse = {
  user_id: 123,
  created_at: new Date(),
  first_name: 'Alice',
};

// GOOD: Destructuring from external data
const { user_id, created_at } = apiResponse;

// GOOD: Interface for external API (properties, not declarations)
interface ApiUser {
  user_id: number;
  user_name: string;
  created_at: string;
}

// GOOD: Type mapping function - uses camelCase for declaration
function mapApiUser(data: ApiUser) {
  return {
    id: data.user_id,
    name: data.user_name,
  };
}

export { userName, getUserById, fetchUserData, mapApiUser };
