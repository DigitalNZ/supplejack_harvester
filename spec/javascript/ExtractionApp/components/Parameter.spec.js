import React from "react";
import { screen } from "@testing-library/react";
import { render } from "@testing-library/react";
import { configureStore, combineReducers } from "@reduxjs/toolkit";
import { Provider } from "react-redux";

import Parameter from "~/js/apps/ExtractionApp/components/Parameter";

// entities
import requests from "~/js/features/ExtractionApp/RequestsSlice";
import parameters from "~/js/features/ExtractionApp/ParametersSlice";
import appDetails from "~/js/features/ExtractionApp/AppDetailsSlice";

// ui
import uiParameters from "~/js/features/ExtractionApp/UiParametersSlice";
import uiAppDetails from "~/js/features/ExtractionApp/UiAppDetailsSlice";

function renderParameter({ parameter = {}, ui = {} }) {
  const store = configureStore({
    reducer: combineReducers({
      entities: combineReducers({ requests, parameters, appDetails }),
      ui: combineReducers({ parameters: uiParameters, appDetails: uiAppDetails }),
    }),
    preloadedState: {
      entities: {
        requests: { ids: [10], entities: { 10: { id: 10 } } },
        parameters: {
          ids: [1],
          entities: {
            1: {
              id: 1,
              request_id: 10,
              kind: "query",
              name: "record",
              content: '{"status": "deleted"}',
              content_type: "static",
              value_type: "string",
              ...parameter,
            },
          },
        },
        appDetails: {
          pipeline: { id: 1 },
          harvestDefinition: { id: 1 },
          extractionDefinition: { id: 1 },
        },
      },
      ui: {
        parameters: {
          ids: [1],
          entities: {
            1: { id: 1, saved: true, saving: false, displayed: true, ...ui },
          },
        },
        appDetails: { activeRequest: 10 },
      },
    },
  });

  return render(
    <Provider store={store}>
      <Parameter id={1} />
    </Provider>
  );
}

describe("<Parameter />", () => {
  beforeEach(() => {
    const portalTarget = document.createElement("div");
    portalTarget.setAttribute("id", "react-modals");
    document.body.appendChild(portalTarget);
  });

  afterEach(() => {
    document.getElementById("react-modals").remove();
  });

  // Only a static query or header parameter declares a type - the same rule the model
  // validates.
  it("offers a type for a static query parameter", () => {
    renderParameter({});

    expect(screen.getAllByText("String").length).toBeGreaterThan(0);
    expect(screen.getByText("JSON")).toBeTruthy();
  });

  it("offers no type for a dynamic parameter", () => {
    renderParameter({ parameter: { content_type: "dynamic", content: "1 + 1" } });

    expect(screen.queryByText("JSON")).toBeNull();
  });

  it("offers no type for a slug parameter", () => {
    renderParameter({ parameter: { kind: "slug", content: "2" } });

    expect(screen.queryByText("JSON")).toBeNull();
  });

  // Bootstrap opens the menu it finds as the toggle's next sibling, so a wrapper
  // between them - a Tooltip's span, for instance - leaves a dropdown that cannot open.
  it("leaves the type menu where the dropdown can open it", () => {
    const { container } = renderParameter({});

    const toggle = container.querySelector(
      ".dropdown-toggle .bi-braces"
    ).parentElement;

    expect(toggle.nextElementSibling.classList.contains("dropdown-menu")).toBe(
      true
    );
  });

  it("shows the type the parameter declares", () => {
    renderParameter({ parameter: { value_type: "json" } });

    expect(screen.getAllByText("JSON").length).toBeGreaterThan(1);
  });

  it("says why a save was refused", () => {
    renderParameter({
      ui: { errors: ["Content must be valid JSON - unexpected token"] },
    });

    expect(
      screen.getByText("Content must be valid JSON - unexpected token")
    ).toBeTruthy();
  });
});
