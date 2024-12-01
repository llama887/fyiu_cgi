package main

import (
	"bytes"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const (
	publicDir = "../public" // Directory for static files
	cgiDir    = "../bin"    // Directory for CGI scripts
)

func handleRequest(w http.ResponseWriter, r *http.Request) {
	// Sanitize the requested path
	requestedPath := r.URL.Path
	if requestedPath == "/" || strings.HasSuffix(requestedPath, "/") {
		requestedPath = filepath.Join(publicDir, "main.html")
	} else {
		requestedPath = filepath.Join(publicDir, requestedPath)
	}

	// Check if the requested path is a valid file in the public directory
	sanitizedPath, err := filepath.Abs(requestedPath)
	if err != nil || !strings.HasPrefix(sanitizedPath, filepath.Clean(publicDir)) {
		http.Error(w, "Access forbidden", http.StatusForbidden)
		return
	}

	if _, err := os.Stat(sanitizedPath); err == nil {
		// Serve static files if the file exists
		http.ServeFile(w, r, sanitizedPath)
		return
	}

	// Handle CGI scripts if the file is not found in the public directory
	cgiPath := filepath.Join(cgiDir, r.URL.Path)
	if _, err := os.Stat(cgiPath); err == nil {
		executeCGI(w, r, cgiPath)
		return
	}

	// If neither a static file nor a CGI script is found, return 404
	http.Error(w, "Not found", http.StatusNotFound)
}

func executeCGI(w http.ResponseWriter, r *http.Request, cgiPath string) {
	// Prepare the environment variables for the CGI script
	env := os.Environ()
	env = append(env, fmt.Sprintf("REQUEST_METHOD=%s", r.Method))
	env = append(env, fmt.Sprintf("QUERY_STRING=%s", r.URL.Query().Encode()))

	// Handle POST request: pass form data to stdin of the CGI script
	var input io.Reader
	if r.Method == http.MethodPost {
		if err := r.ParseForm(); err != nil {
			http.Error(w, "Failed to parse form data", http.StatusBadRequest)
			return
		}
		env = append(env, fmt.Sprintf("CONTENT_LENGTH=%d", r.ContentLength))
		env = append(env, fmt.Sprintf("CONTENT_TYPE=%s", r.Header.Get("Content-Type")))
		body, err := ioutil.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read body", http.StatusInternalServerError)
			return
		}
		input = bytes.NewReader(body)
	}

	// Set up the CGI script command
	cmd := exec.Command(cgiPath)
	cmd.Env = env
	if input != nil {
		cmd.Stdin = input
	}

	// Capture the output of the CGI script
	output, err := cmd.Output()
	if err != nil {
		http.Error(w, fmt.Sprintf("CGI script error: %v", err), http.StatusInternalServerError)
		return
	}

	// Parse and write CGI headers
	outputParts := bytes.SplitN(output, []byte("\n\n"), 2)
	if len(outputParts) != 2 {
		http.Error(w, "Invalid CGI response", http.StatusInternalServerError)
		return
	}

	headers := string(outputParts[0])
	for _, line := range strings.Split(headers, "\n") {
		parts := strings.SplitN(line, ": ", 2)
		if len(parts) == 2 {
			w.Header().Set(parts[0], parts[1])
		}
	}

	// Write the CGI body to the HTTP response
	w.Write(outputParts[1])
}

func main() {
	// Create an HTTP server and route all requests to handleRequest
	http.HandleFunc("/", handleRequest)

	addr := ":8080"
	fmt.Printf("Starting server on %s\n", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		fmt.Printf("Server error: %v\n", err)
	}
}
