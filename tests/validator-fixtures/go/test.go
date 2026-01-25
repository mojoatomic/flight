package main

import (
    "fmt"
    "os"
)

// N1: Ignored error
func badErrorHandling() {
    f, _ := os.Open("file.txt")
    fmt.Println(f)
}

// N2: panic in library code
func libraryFunc() {
    panic("something went wrong")
}

// N3: Global variables
var globalCounter int = 0

// N4: init() function
func init() {
    globalCounter = 1
}

// M1: Exported function without comment
func PublicFunction() {
    fmt.Println("no doc comment")
}
