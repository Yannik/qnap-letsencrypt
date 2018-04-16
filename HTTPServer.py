import socket

from threading import Thread
try: # Python 2
  from BaseHTTPServer import HTTPServer
  from SimpleHTTPServer import SimpleHTTPRequestHandler
except ImportError: # Python 3
  from http.server import SimpleHTTPRequestHandler,HTTPServer

class HTTPServerV6(HTTPServer):
  address_family = socket.AF_INET6

def main():
  Thread(target=servev4).start()
  try:
    servev6()
  except OSError, e:
    if not e == errno.EAFNOSUPPORT:
      raise
  
def servev6():
  server = HTTPServerV6(('::', 80), SimpleHTTPRequestHandler)
  server.serve_forever()
  
def servev4():
  server = HTTPServer(('0.0.0.0', 80), SimpleHTTPRequestHandler)
  server.serve_forever()

if __name__ == '__main__':
  main()
