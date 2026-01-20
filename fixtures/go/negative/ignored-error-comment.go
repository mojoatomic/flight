package main

// Example: result, _ := Call() should be avoided
// Don't do: data, _ := json.Marshal(obj)
func valid() {
	result, err := SomeFunction()
	if err != nil {
		return
	}
	_ = result
}

func SomeFunction() (int, error) {
	return 0, nil
}
