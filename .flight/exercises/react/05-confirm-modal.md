# Exercise 05: Confirm Delete Modal

## Difficulty
Intermediate

## Task
Create a reusable confirmation modal for delete actions.

## Requirements
- Backdrop that closes modal on click
- Title: "Delete {itemType}?"
- Message with item name and warning
- Cancel button (secondary)
- Delete button (destructive/red)
- Loading state while deleting
- Escape key closes modal

## Props
```ts
interface ConfirmDeleteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  itemType: string;
  itemName: string;
  isLoading?: boolean;
}
```

## Output
Single file: `ConfirmDeleteModal.tsx`

## Line Estimation
```
Formula: 45 + (sections × 8) + (actions × 5)
= 45 + (1 × 8) + (2 × 5) = 63 lines
Target: ~70 lines
```

---

## Evaluation Criteria

### Must Pass (Invariants)

- [ ] Named export `ConfirmDeleteModal`
- [ ] Props interface above component
- [ ] `isLoading = false` default in destructuring
- [ ] useEffect for Escape key handling
- [ ] Cleanup function removes event listener
- [ ] Dependency array `[isOpen, onClose]`
- [ ] `if (!isOpen) return null` early return
- [ ] Backdrop with `fixed inset-0`
- [ ] Backdrop onClick calls onClose
- [ ] Modal container stops event propagation
- [ ] Cancel button calls onClose
- [ ] Delete button calls onConfirm
- [ ] Delete button is red
- [ ] Delete button disabled when isLoading
- [ ] Delete text shows "Deleting..." when loading

### Should Aim For (Guidelines)

- [ ] Under 70 lines
- [ ] Semi-transparent backdrop (`bg-black/50`)
- [ ] Centered modal with shadow

### Must Not Have (Forbidden)

- [ ] Default export
- [ ] Missing useEffect cleanup
- [ ] `any` type
- [ ] Portal (keep simple)

---

## Reference Solution

```tsx
// 1. Imports
import { useEffect } from 'react';
import { clsx } from 'clsx';

// 2. Types
interface ConfirmDeleteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  itemType: string;
  itemName: string;
  isLoading?: boolean;
}

// 3. Component
export function ConfirmDeleteModal({
  isOpen,
  onClose,
  onConfirm,
  itemType,
  itemName,
  isLoading = false,
}: ConfirmDeleteModalProps) {
  // 3a. Hooks
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose();
    }
    if (isOpen) document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);
  // 3b. Handlers
  function handleBackdropClick() {
    onClose();
  }
  function handleModalClick(e: React.MouseEvent) {
    e.stopPropagation();
  }
  function handleConfirm() {
    onConfirm();
  }
  // 3c. Early return
  if (!isOpen) return null;
  // 3d. Render
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center" onClick={handleBackdropClick}>
      <div className="bg-white rounded-lg shadow-xl p-6 max-w-md w-full mx-4" onClick={handleModalClick}>
        <h2 className="text-xl font-bold mb-2">Delete {itemType}?</h2>
        <p className="text-gray-600 mb-6">
          Are you sure you want to delete <span className="font-medium">{itemName}</span>? This action cannot be undone.
        </p>
        <div className="flex justify-end gap-3">
          <button onClick={onClose} className="px-4 py-2 rounded font-medium bg-gray-200 text-gray-800">
            Cancel
          </button>
          <button
            onClick={handleConfirm}
            disabled={isLoading}
            className={clsx('px-4 py-2 rounded font-medium text-white', isLoading ? 'bg-red-300 cursor-not-allowed' : 'bg-red-500')}
          >
            {isLoading ? 'Deleting...' : 'Delete'}
          </button>
        </div>
      </div>
    </div>
  );
}
```

---

## Common Failures

| Failure | Root Cause | Fix |
|---------|------------|-----|
| Missing cleanup | Forgot return in useEffect | Invariant: always cleanup listeners |
| Wrong deps array | Stale closure | Invariant: include onClose in deps |
| No stopPropagation | Click bubbles to backdrop | Invariant: modal stops propagation |
| isLoading default in body | Wrong pattern | Invariant: default in destructuring |

---

## Tightenings Applied

*None yet - this is the baseline exercise.*
