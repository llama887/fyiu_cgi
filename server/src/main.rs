use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server};
use std::env;
use std::path::{PathBuf};
use std::process::{Command, Stdio};
use std::fs;
use std::io::{Read, Write};

async fn handle_request(req: Request<Body>) -> Result<Response<Body>, hyper::Error> {
    // Build the base path for the `html` folder and CGI scripts
    let mut html_base_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    html_base_path.push("../html");
    
    let mut cgi_base_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    cgi_base_path.push("../bin");

    // Determine the requested path
    let mut requested_path = req.uri().path().trim_start_matches('/').to_string();

    // Default to `main.html` if the requested path is `/` or a directory
    if requested_path.is_empty() || requested_path.ends_with('/') {
        requested_path.push_str("main.html");
    }

    // Full paths to the requested files in `html` and `cgi`
    let html_path = html_base_path.join(&requested_path);
    let cgi_path = cgi_base_path.join(&requested_path);

    // Serve static files from the `html` folder if the file exists
    if html_path.exists() && html_path.is_file() {
        return match fs::read(html_path) {
            Ok(content) => Ok(Response::new(Body::from(content))),
            Err(_) => Ok(Response::builder()
                .status(500)
                .body(Body::from("Failed to read the requested file"))
                .unwrap()),
        };
    }

    // Serve CGI scripts if they exist
    if cgi_path.exists() && cgi_path.is_file() {
        // Prepare the environment variables for the CGI script
        let mut env_vars = env::vars().collect::<Vec<_>>();
        env_vars.push(("REQUEST_METHOD".to_string(), req.method().to_string()));
        if let Some(query) = req.uri().query() {
            env_vars.push(("QUERY_STRING".to_string(), query.to_string()));
        }
        if req.method() == "POST" {
            if let Some(len) = req.headers().get("content-length") {
                env_vars.push(("CONTENT_LENGTH".to_string(), len.to_str().unwrap().to_string()));
            }
            if let Some(ct) = req.headers().get("content-type") {
                env_vars.push(("CONTENT_TYPE".to_string(), ct.to_str().unwrap().to_string()));
            }
        }

        // Set up the CGI script command
        let mut cmd = Command::new(cgi_path);
        cmd.envs(env_vars.iter().map(|(k, v)| (k.as_str(), v.as_str())));

        let mut child = if req.method() == "POST" {
            let mut child = cmd.stdin(Stdio::piped()).stdout(Stdio::piped()).spawn().unwrap();
            let mut stdin = child.stdin.take().unwrap();
            let body = hyper::body::to_bytes(req.into_body()).await.unwrap();
            stdin.write_all(&body).unwrap();
            child
        } else {
            cmd.stdout(Stdio::piped()).spawn().unwrap()
        };

        // Capture the output of the CGI script
        let mut stdout = child.stdout.take().unwrap();
        let mut output = Vec::new();
        stdout.read_to_end(&mut output).unwrap();

        let status = child.wait().unwrap();
        if !status.success() {
            return Ok(Response::builder()
                .status(500)
                .body(Body::from("CGI script error"))
                .unwrap());
        }

        // Split the output into headers and body
        let header_end = output.iter().position(|&b| b == b'\n').unwrap() + 1;
        let body = output[header_end..].to_vec(); // Copy the body part

        let response = Response::builder()
            .status(200) // Modify based on headers if needed
            .body(Body::from(body))
            .unwrap();

        return Ok(response);
    }

    // Return a 404 response if neither static files nor CGI scripts were found
    Ok(Response::builder()
        .status(404)
        .body(Body::from("Not found"))
        .unwrap())
}

#[tokio::main]
async fn main() {
    let make_svc = make_service_fn(|_conn| async { Ok::<_, hyper::Error>(service_fn(handle_request)) });

    let addr = ([127, 0, 0, 1], 8080).into();
    let server = Server::bind(&addr).serve(make_svc);

    println!("Starting server on http://{}", addr);
    if let Err(e) = server.await {
        eprintln!("server error: {}", e);
    }
}
