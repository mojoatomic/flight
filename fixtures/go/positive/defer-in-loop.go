package main

import "os"

func example() {
	files := []string{"a.txt", "b.txt"}
	for i := 0; i < len(files); i++ {
		f, err := os.Open(files[i])
		if err != nil {
			continue
		}
		defer f.Close()
	}
}
