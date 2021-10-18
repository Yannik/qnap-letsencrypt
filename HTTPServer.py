import socket, errno, sys

from http.server import SimpleHTTPRequestHandler,HTTPServer

class HTTPServerV6(HTTPServer):
  address_family = socket.AF_INET6

def main():
  port = 80  # default port
  if len(sys.argv)>1:
    port = int(sys.argv[1])
  try:
    serve(port)
  except OSError as e:
    if e.errno == errno.EAFNOSUPPORT or str(e) == 'getsockaddrarg: bad family':
      print("Serving v4 only")
      servev4only(port)
    else:
      raise

# serves both v4 and v6
def serve( port ):
  server = HTTPServerV6(('::', port), SimpleHTTPRequestHandler)
  server.serve_forever()

def servev4only( port ):
  server = HTTPServer(('0.0.0.0', port), SimpleHTTPRequestHandler)
  server.serve_forever()

if __name__ == '__main__':
  main()
