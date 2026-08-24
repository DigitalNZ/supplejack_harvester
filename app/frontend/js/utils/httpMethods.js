// The verbs a request can be sent with. Kept in step with the http_method enum on
// the Request model, and with Extraction::BaseConnection::PAYLOAD_METHODS, which
// decides whether the parameters travel in the body or in the query string.

export const HTTP_METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE"];

export const PAYLOAD_HTTP_METHODS = ["POST", "PUT", "PATCH"];

export function sendsPayload(httpMethod) {
  return PAYLOAD_HTTP_METHODS.includes(httpMethod);
}
