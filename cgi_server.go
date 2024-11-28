package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Path to the CGI scripts directory
const cgiDir = "./cgi"

// Function to execute the CGI script
func executeCGI(w http.ResponseWriter, r *http.Request) {
	// Construct the path to the CGI script based on the URL
	cgiPath := filepath.Join(cgiDir, r.URL.Path)

	// Ensure the requested CGI script exists
	if _, err := os.Stat(cgiPath); os.IsNotExist(err) {
		http.Error(w, "CGI script not found", http.StatusNotFound)
		return
	}

	// Prepare the environment variables for the CGI script
	env := os.Environ()
	env = append(env, fmt.Sprintf("REQUEST_METHOD=%s", r.Method))
	env = append(env, fmt.Sprintf("QUERY_STRING=%s", r.URL.Query().Encode()))

	// Handle POST request: pass form data to stdin of the CGI script
	if r.Method == http.MethodPost {
		if err := r.ParseForm(); err != nil {
			http.Error(w, "Failed to parse form data", http.StatusBadRequest)
			return
		}
		env = append(env, fmt.Sprintf("CONTENT_LENGTH=%d", r.ContentLength))
		env = append(env, fmt.Sprintf("CONTENT_TYPE=%s", r.Header.Get("Content-Type")))
	}

	// Set up the CGI script command
	cmd := exec.Command(cgiPath)
	cmd.Env = env

	// If it's a POST request, pipe the request body into the CGI script's stdin
	if r.Method == http.MethodPost {
		stdin, err := cmd.StdinPipe()
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to open stdin pipe: %v", err), http.StatusInternalServerError)
			return
		}
		defer stdin.Close()

		// Read the body from the HTTP request and write it to stdin of the CGI script
		body, err := ioutil.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read body", http.StatusInternalServerError)
			return
		}
		stdin.Write(body)
	}

	// Get the output of the CGI script and write it back to the HTTP response
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get stdout pipe: %v", err), http.StatusInternalServerError)
		return
	}

	err = cmd.Start()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to start CGI script: %v", err), http.StatusInternalServerError)
		return
	}

	// Copy the output from the CGI script to the HTTP response
	_, err = io.Copy(w, stdout)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to copy output: %v", err), http.StatusInternalServerError)
		return
	}

	// Wait for the CGI script to finish execution
	cmd.Wait()
}

// Static file server to serve the CGI folder (optional)
func serveStaticFiles() {
	http.Handle("/cgi/", http.StripPrefix("/cgi/", http.FileServer(http.Dir(cgiDir))))
}

func main() {
	// Serve static files from the CGI folder (optional)
	serveStaticFiles()

	// Route all requests to the CGI handler
	http.HandleFunc("/", executeCGI)

	// Start the server on port 8080
	fmt.Println("Starting CGI server on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Println("Error starting server:", err)
	}
}
