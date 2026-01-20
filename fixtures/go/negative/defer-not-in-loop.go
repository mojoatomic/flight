package main

import "os"

func valid() {
	f, err := os.Open("file.txt")
	if err != nil {
		return
	}
	defer f.Close()
}
