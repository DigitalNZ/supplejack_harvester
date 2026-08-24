import React from "react";
import { render, screen } from "@testing-library/react";

import PreviewPanel from "~/js/apps/ExtractionApp/components/PreviewPanel";

const preview = {
  url: "https://api.figshare.com/records/2",
  method: "PUT",
  params: { record: { status: "deleted" } },
  request_headers: { "Content-Type": "application/json" },
  status: 200,
  response_headers: {},
  body: "{}",
};

describe("<PreviewPanel />", () => {
  it("shows the status the response came back with", () => {
    render(<PreviewPanel preview={preview} format="JSON" />);

    expect(screen.getByText("Response Headers (status = 200)")).toBeTruthy();
  });

  it("shows a failing status the same way, rather than hiding it", () => {
    render(<PreviewPanel preview={{ ...preview, status: 422 }} format="JSON" />);

    expect(screen.getByText("Response Headers (status = 422)")).toBeTruthy();
  });

  // A preview that never reached the content source has no status to show - see
  // RequestsController#failed_response.
  it("says nothing about a status when there is none", () => {
    render(
      <PreviewPanel preview={{ ...preview, status: null }} format="JSON" />
    );

    expect(screen.getByText("Response Headers")).toBeTruthy();
  });
});
