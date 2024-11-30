package main

import (
    "fmt"
    "os"
)

func main() {
    // Print the required CGI headers
    fmt.Println("Content-Type: text/html")
    fmt.Println("")

    // Print the query string and the request method
    fmt.Println("<html><body>")
    fmt.Println("<h1>CGI Script Output</h1>")
    fmt.Printf("<p>QUERY_STRING: %s</p>", os.Getenv("QUERY_STRING"))
    fmt.Printf("<p>REQUEST_METHOD: %s</p>", os.Getenv("REQUEST_METHOD"))
    fmt.Println("</body></html>")

    // Ensure output is flushed
    os.Stdout.Sync()
}
