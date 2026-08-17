import React from "react";
import { map } from "lodash";

import CodeEditor from "~/js/components/CodeEditor";

const PreviewPanel = ({
  preview,
  format,
  loading = false,
  view = "accordion",
}) => {
  const formattedPayload = () => {
    return (
      <>
        <br />
        <br />
        <pre>{JSON.stringify(preview.params, null, 2)}</pre>
      </>
    );
  };

  const accordionView = () => {
    return (
      <>
        <div className="accordion mt-4">
          <div className="accordion-item">
            <h2 className="accordion-header">
              <button
                className="accordion-button"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#request"
                aria-expanded="true"
                aria-controls="request"
              >
                Request ({preview.method})
              </button>
            </h2>
            <div id="request" className="accordion-collapse collapse show">
              <div className="accordion-body">
                {preview.method == "GET" && (
                  <a href={preview.url} target="_blank">
                    {preview.url}
                  </a>
                )}
                {preview.method == "POST" && preview.url}
                {preview.method == "POST" && formattedPayload()}
              </div>
            </div>
          </div>

          <div className="accordion-item">
            <h2 className="accordion-header">
              <button
                className="accordion-button"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#headers"
                aria-expanded="true"
                aria-controls="response"
              >
                Request Headers
              </button>
            </h2>
            <div id="headers" className="accordion-collapse collapse">
              <div className="accordion-body">
                {map(preview.request_headers, (value, key) => {
                  return (
                    <p key={key}>
                      {key}: {value}
                    </p>
                  );
                })}
              </div>
            </div>
          </div>

          <div className="accordion-item">
            <h2 className="accordion-header">
              <button
                className="accordion-button"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#response"
                aria-expanded="true"
                aria-controls="response"
              >
                Response Body
              </button>
            </h2>
            <div id="response" className="accordion-collapse collapse show">
              <div className="accordion-body">
                <CodeEditor initContent={preview.body} format={format} />
              </div>
            </div>
          </div>

          <div className="accordion-item">
            <h2 className="accordion-header">
              <button
                className="accordion-button"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#response-headers"
                aria-expanded="true"
                aria-controls="response-headers"
              >
                Response Headers
              </button>
            </h2>
            <div id="response-headers" className="accordion-collapse collapse">
              <div className="accordion-body">
                {map(preview.response_headers, (value, key) => {
                  return (
                    <p key={key}>
                      {key}: {value}
                    </p>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      </>
    );
  };

  const apiRecordView = () => {
    return (
      <>
        <div className="card p-4 mt-4">
          <strong className="mb-4">API Response</strong>
          <CodeEditor initContent={preview.body} format="JSON" />
        </div>
      </>
    );
  };

  return (
    <>
      {loading && (
        <div className="d-flex justify-content-center">
          <div className="spinner-border text-primary" role="status">
            <span className="visually-hidden">Loading...</span>
          </div>
        </div>
      )}
      {!loading && view == "accordion" && preview && accordionView()}
      {!loading && view == "apiRecord" && preview && apiRecordView()}
    </>
  );
};

export default PreviewPanel;
