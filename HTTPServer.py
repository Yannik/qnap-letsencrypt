import socket
from BaseHTTPServer import HTTPServer
from SimpleHTTPServer import SimpleHTTPRequestHandler
from threading import Thread

class HTTPServerV6(HTTPServer):
  address_family = socket.AF_INET6

def main():
  Thread(target=servev4).start()
  servev6()
  
def servev6():
  server = HTTPServerV6(('::', 80), SimpleHTTPRequestHandler)
  server.serve_forever()
  
def servev4():
  server = HTTPServer(('0.0.0.0', 80), SimpleHTTPRequestHandler)
  server.serve_forever()

if __name__ == '__main__':
  main()
