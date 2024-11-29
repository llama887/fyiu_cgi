#include <iostream>
#include <ctime>

int main() {
    // Get current time
    std::time_t now = std::time(0);
    char* dt = std::ctime(&now);
    
    // Output the necessary CGI headers
    std::cout << "Content-Type: text/html\n\n";
    
    // Output the HTML content
    std::cout << "<html><head><title>C++ Program Output</title></head>";
    std::cout << "<body><h1>Hello from C++!</h1>";
    std::cout << "<p>Current system time: " << dt << "</p>";
    std::cout << "</body></html>";
    
    return 0;
}
