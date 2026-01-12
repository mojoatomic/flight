# Exercise 03: Contact Form with Validation

## Difficulty
Intermediate-Advanced

## Task
Create a contact form with client-side validation using useReducer for form state management.

## Requirements
- Fields: name, email, message
- Validation on blur and submit
- Name: required, min 2 characters
- Email: required, valid format
- Message: required, min 10 characters, max 500
- Submit button disabled until valid
- Show character count for message
- Clear form after successful submit

## Output
Single file: `ContactForm.tsx`

---

## Evaluation Criteria

### Must Pass (Invariants)

- [ ] useReducer for form state (values, errors, touched)
- [ ] Action types as discriminated union
- [ ] Reducer is pure (no side effects)
- [ ] Handlers: `handleChange`, `handleBlur`, `handleSubmit`
- [ ] Props interface above component (even if empty/onSubmit only)
- [ ] Validation logic extracted to helper functions
- [ ] No nested ternaries
- [ ] Tailwind styling
- [ ] Named export only

### Should Pass (Guidelines)

- [ ] Under 170 lines total
- [ ] Reducer under 40 lines
- [ ] Clear section comments
- [ ] Accessible form labels
- [ ] Error messages associated with inputs

### Must Not Have (Forbidden)

- [ ] Multiple useState for form fields
- [ ] Validation in render
- [ ] `any` type
- [ ] Direct state mutation in reducer
- [ ] Inline handlers in JSX (except for field-specific onChange/onBlur with params)

---

## Reference Solution

```tsx
// 1. Imports
import { useReducer } from 'react';
import { clsx } from 'clsx';

// 2. Types
interface ContactFormProps {
  onSubmit: (data: FormValues) => void;
}

interface FormValues {
  name: string;
  email: string;
  message: string;
}

interface FormState {
  values: FormValues;
  errors: Partial<Record<keyof FormValues, string>>;
  touched: Partial<Record<keyof FormValues, boolean>>;
  isSubmitting: boolean;
}

type FormAction =
  | { type: 'SET_FIELD'; field: keyof FormValues; value: string }
  | { type: 'SET_TOUCHED'; field: keyof FormValues }
  | { type: 'SET_ERRORS'; errors: FormState['errors'] }
  | { type: 'SUBMIT_START' }
  | { type: 'SUBMIT_SUCCESS' }
  | { type: 'RESET' };

// 3. Constants
const INITIAL_VALUES: FormValues = {
  name: '',
  email: '',
  message: '',
};

const INITIAL_STATE: FormState = {
  values: INITIAL_VALUES,
  errors: {},
  touched: {},
  isSubmitting: false,
};

const MESSAGE_MAX = 500;
const MESSAGE_MIN = 10;
const NAME_MIN = 2;

// 4. Validation helpers
function validateName(value: string): string | undefined {
  if (!value.trim()) {
    return 'Name is required';
  }
  if (value.trim().length < NAME_MIN) {
    return `Name must be at least ${NAME_MIN} characters`;
  }
  return undefined;
}

function validateEmail(value: string): string | undefined {
  if (!value.trim()) {
    return 'Email is required';
  }
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(value)) {
    return 'Invalid email format';
  }
  return undefined;
}

function validateMessage(value: string): string | undefined {
  if (!value.trim()) {
    return 'Message is required';
  }
  if (value.trim().length < MESSAGE_MIN) {
    return `Message must be at least ${MESSAGE_MIN} characters`;
  }
  if (value.length > MESSAGE_MAX) {
    return `Message must be under ${MESSAGE_MAX} characters`;
  }
  return undefined;
}

function validateAll(values: FormValues): FormState['errors'] {
  return {
    name: validateName(values.name),
    email: validateEmail(values.email),
    message: validateMessage(values.message),
  };
}

// 5. Reducer
function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case 'SET_FIELD':
      return {
        ...state,
        values: { ...state.values, [action.field]: action.value },
      };
    case 'SET_TOUCHED':
      return {
        ...state,
        touched: { ...state.touched, [action.field]: true },
      };
    case 'SET_ERRORS':
      return {
        ...state,
        errors: action.errors,
      };
    case 'SUBMIT_START':
      return {
        ...state,
        isSubmitting: true,
      };
    case 'SUBMIT_SUCCESS':
      return INITIAL_STATE;
    case 'RESET':
      return INITIAL_STATE;
    default:
      return state;
  }
}

// 6. Component
export function ContactForm({ onSubmit }: ContactFormProps) {
  // 6a. Hooks
  const [state, dispatch] = useReducer(formReducer, INITIAL_STATE);

  // 6b. Derived state
  const errors = validateAll(state.values);
  const isValid = !errors.name && !errors.email && !errors.message;
  const messageLength = state.values.message.length;

  // 6c. Handlers
  function handleChange(field: keyof FormValues, value: string) {
    dispatch({ type: 'SET_FIELD', field, value });
  }

  function handleBlur(field: keyof FormValues) {
    dispatch({ type: 'SET_TOUCHED', field });
    dispatch({ type: 'SET_ERRORS', errors });
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    
    dispatch({ type: 'SET_ERRORS', errors });
    
    if (!isValid) {
      return;
    }
    
    dispatch({ type: 'SUBMIT_START' });
    onSubmit(state.values);
    dispatch({ type: 'SUBMIT_SUCCESS' });
  }

  // 6d. Render helpers
  function fieldError(field: keyof FormValues): string | undefined {
    return state.touched[field] ? errors[field] : undefined;
  }

  // 6e. Render
  return (
    <form onSubmit={handleSubmit} className="space-y-4 max-w-md">
      <div>
        <label htmlFor="name" className="block text-sm font-medium mb-1">
          Name
        </label>
        <input
          id="name"
          type="text"
          value={state.values.name}
          onChange={(e) => handleChange('name', e.target.value)}
          onBlur={() => handleBlur('name')}
          className={clsx(
            'w-full px-3 py-2 border rounded',
            fieldError('name') ? 'border-red-500' : 'border-gray-300'
          )}
        />
        {fieldError('name') && (
          <p className="text-red-500 text-sm mt-1">{fieldError('name')}</p>
        )}
      </div>

      <div>
        <label htmlFor="email" className="block text-sm font-medium mb-1">
          Email
        </label>
        <input
          id="email"
          type="email"
          value={state.values.email}
          onChange={(e) => handleChange('email', e.target.value)}
          onBlur={() => handleBlur('email')}
          className={clsx(
            'w-full px-3 py-2 border rounded',
            fieldError('email') ? 'border-red-500' : 'border-gray-300'
          )}
        />
        {fieldError('email') && (
          <p className="text-red-500 text-sm mt-1">{fieldError('email')}</p>
        )}
      </div>

      <div>
        <label htmlFor="message" className="block text-sm font-medium mb-1">
          Message
        </label>
        <textarea
          id="message"
          rows={4}
          value={state.values.message}
          onChange={(e) => handleChange('message', e.target.value)}
          onBlur={() => handleBlur('message')}
          className={clsx(
            'w-full px-3 py-2 border rounded resize-none',
            fieldError('message') ? 'border-red-500' : 'border-gray-300'
          )}
        />
        <div className="flex justify-between text-sm mt-1">
          {fieldError('message') ? (
            <p className="text-red-500">{fieldError('message')}</p>
          ) : (
            <span />
          )}
          <span className={messageLength > MESSAGE_MAX ? 'text-red-500' : 'text-gray-500'}>
            {messageLength}/{MESSAGE_MAX}
          </span>
        </div>
      </div>

      <button
        type="submit"
        disabled={!isValid || state.isSubmitting}
        className={clsx(
          'w-full py-2 rounded font-medium',
          isValid && !state.isSubmitting
            ? 'bg-blue-500 text-white'
            : 'bg-gray-200 text-gray-400 cursor-not-allowed'
        )}
      >
        {state.isSubmitting ? 'Sending...' : 'Send Message'}
      </button>
    </form>
  );
}
```

---

## Common Failures

| Failure | Root Cause | Tightening |
|---------|------------|------------|
| Multiple useState | Doesn't recognize "3+ related fields" trigger | Invariant: "useReducer for 3+ related state fields" |
| Validation in JSX | Keeps logic compact | Invariant: "Extract validation to helpers" |
| Mutates state: `state.values[field] = value` | Reducer confusion | Invariant: "Reducer must be pure - no mutations" |
| Union type as string: `type: string` | TypeScript weakness | Invariant: "Action types as discriminated union" |
| No touched tracking | Incomplete validation UX | Add to Must Pass checklist |
| Shows errors before interaction | Eager validation | Invariant: "Show errors only after touched" |

---

## Tightenings Applied

*None yet - this is the baseline exercise.*
