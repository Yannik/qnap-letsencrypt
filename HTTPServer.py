import socket, errno

from threading import Thread
from http.server import SimpleHTTPRequestHandler,HTTPServer

class HTTPServerV6(HTTPServer):
  address_family = socket.AF_INET6

def main():
  try:
    serve()
  except OSError as e:
    if e.errno == errno.EAFNOSUPPORT:
      servev4only()
    else:
      raise
  
# serves both v4 and v6
def serve():
  try:
    server = HTTPServerV6(('::', 80), SimpleHTTPRequestHandler)
    server.serve_forever()
  except socket.error as e:
    if e.errno == errno.EAFNOSUPPORT: # system doesn't support ipv6
      pass
    else:
      raise
  
def servev4only():
  print("Serving v4 only")
  server = HTTPServer(('0.0.0.0', 80), SimpleHTTPRequestHandler)
  server.serve_forever()

if __name__ == '__main__':
  main()
