import socket, errno

from http.server import SimpleHTTPRequestHandler,HTTPServer

class HTTPServerV6(HTTPServer):
  address_family = socket.AF_INET6

def main():
  try:
    serve()
  except OSError as e:
    if e.errno == errno.EAFNOSUPPORT: # system doesn't support ipv6
      print("Serving v4 only")
      servev4only()
    else:
      raise
  
# serves both v4 and v6
def serve():
  server = HTTPServerV6(('::', 80), SimpleHTTPRequestHandler)
  server.serve_forever()
 
def servev4only():
  server = HTTPServer(('0.0.0.0', 80), SimpleHTTPRequestHandler)
  server.serve_forever()

if __name__ == '__main__':
  main()
