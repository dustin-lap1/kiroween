// CloudFront Function (viewer request, S3 behavior only).
// Extensionless paths like /about or /items/42 serve the SPA shell.
function handler(event) {
  var request = event.request;
  var last = request.uri.split('/').pop();
  if (last.indexOf('.') === -1) {
    request.uri = '/index.html';
  }
  return request;
}
