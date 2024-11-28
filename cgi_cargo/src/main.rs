use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server};
use std::env;
use std::process::{Command, Stdio};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

async fn handle_request(req: Request<Body>) -> Result<Response<Body>, hyper::Error> {
    let cgi_path = format!("./cgi{}", req.uri().path());

    // Check if the CGI script exists
    if !std::path::Path::new(&cgi_path).exists() {
        return Ok(Response::builder()
            .status(404)
            .body(Body::from("CGI script not found"))
            .unwrap());
    }

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
    let mut cmd = Command::new(&cgi_path);
    cmd.envs(&env_vars);

    // Handle POST data
    let mut child = if req.method() == "POST" {
        let mut child = cmd.stdin(Stdio::piped()).stdout(Stdio::piped()).spawn().unwrap();
        let mut stdin = child.stdin.take().unwrap();
        let body = hyper::body::to_bytes(req.into_body()).await.unwrap();
        tokio::spawn(async move {
            stdin.write_all(&body).await.unwrap();
        });
        child
    } else {
        cmd.stdout(Stdio::piped()).spawn().unwrap()
    };

    // Capture the output of the CGI script
    let mut stdout = child.stdout.take().unwrap();
    let mut output = Vec::new();
    stdout.read_to_end(&mut output).await.unwrap();

    let status = child.wait().await.unwrap();
    if !status.success() {
        return Ok(Response::builder()
            .status(500)
            .body(Body::from("CGI script error"))
            .unwrap());
    }

    // Parse headers from CGI output
    let mut headers = [httparse::EMPTY_HEADER; 16];
    let mut res = httparse::Response::new(&mut headers);
    let _ = res.parse(&output).unwrap();

    let mut response = Response::builder().status(res.code.unwrap());
    for header in res.headers {
        response = response.header(header.name, header.value);
    }

    let body_start = output.iter().position(|&b| b == b'\n').unwrap() + 1;
    let body = output[body_start..].to_vec();
    Ok(response.body(Body::from(body)).unwrap())
}

#[tokio::main]
async fn main() {
    let make_svc = make_service_fn(|_conn| {
        async {
            Ok::<_, hyper::Error>(service_fn(handle_request))
        }
    });

    let addr = ([127, 0, 0, 1], 8080).into();
    let server = Server::bind(&addr).serve(make_svc);

    println!("Starting CGI server on http://{}", addr);
    if let Err(e) = server.await {
        eprintln!("server error: {}", e);
    }
}
