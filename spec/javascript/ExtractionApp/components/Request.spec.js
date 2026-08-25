import React from "react";
import { screen } from "@testing-library/react";
import { render } from "@testing-library/react";
import { configureStore, combineReducers } from "@reduxjs/toolkit";
import { Provider } from "react-redux";

import Request from "~/js/apps/ExtractionApp/components/Request";

// entities
import requests from "~/js/features/ExtractionApp/RequestsSlice";
import parameters from "~/js/features/ExtractionApp/ParametersSlice";
import appDetails from "~/js/features/ExtractionApp/AppDetailsSlice";

// ui
import uiAppDetails from "~/js/features/ExtractionApp/UiAppDetailsSlice";

const emptyEntities = { ids: [], entities: {} };

function renderRequest({ httpMethod, parameter }) {
  const store = configureStore({
    reducer: combineReducers({
      entities: combineReducers({ requests, parameters, appDetails }),
      ui: combineReducers({ appDetails: uiAppDetails }),
    }),
    preloadedState: {
      entities: {
        requests: {
          ids: [10],
          entities: {
            10: {
              id: 10,
              base_url: "https://api.figshare.com/records",
              http_method: httpMethod,
            },
          },
        },
        parameters: {
          ids: [1],
          entities: {
            1: {
              id: 1,
              request_id: 10,
              kind: "query",
              name: "status",
              content: "deleted",
              value_type: "string",
              ...parameter,
            },
          },
        },
        appDetails: {
          pipeline: { id: 1 },
          harvestDefinition: { id: 1 },
          extractionDefinition: { id: 1, paginated: false },
        },
      },
      ui: {
        appDetails: { activeRequest: 10 },
      },
    },
  });

  return render(
    <Provider store={store}>
      <Request />
    </Provider>
  );
}

describe("<Request />", () => {
  it("offers every verb the extraction stack can send", () => {
    renderRequest({ httpMethod: "GET" });

    ["GET", "POST", "PUT", "PATCH", "DELETE"].forEach((method) => {
      expect(screen.getAllByText(method).length).toBeGreaterThan(0);
    });
  });

  // The parameters travel in the body for POST, PUT and PATCH, and in the query
  // string for GET and DELETE - see Extraction::BaseConnection::PAYLOAD_METHODS.
  it.each(["POST", "PUT", "PATCH"])(
    "shows the parameters as a payload for %s",
    (httpMethod) => {
      renderRequest({ httpMethod });

      expect(screen.getByText("Payload")).toBeTruthy();
    }
  );

  it("shows a JSON parameter in the payload as the structure it describes", () => {
    renderRequest({
      httpMethod: "PUT",
      parameter: {
        name: "record",
        content: '{"status": "deleted"}',
        value_type: "json",
      },
    });

    expect(
      screen.getByText(/"record":/, { exact: false }).textContent
    ).toContain('"status": "deleted"');
  });

  it.each(["GET", "DELETE"])(
    "shows the parameters in the URL for %s",
    (httpMethod) => {
      renderRequest({ httpMethod });

      expect(screen.queryByText("Payload")).toBeNull();
      expect(screen.getByText("status", { exact: false })).toBeTruthy();
    }
  );
});
