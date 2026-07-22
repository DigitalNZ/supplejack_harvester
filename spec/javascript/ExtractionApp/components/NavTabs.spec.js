import React from "react";
import { fireEvent, screen } from "@testing-library/react";
import { render } from "@testing-library/react";
import { configureStore, combineReducers } from "@reduxjs/toolkit";
import { Provider } from "react-redux";

import NavTabs from "~/js/apps/ExtractionApp/components/NavTabs";

// entities
import requests from "~/js/features/ExtractionApp/RequestsSlice";
import parameters from "~/js/features/ExtractionApp/ParametersSlice";
import appDetails from "~/js/features/ExtractionApp/AppDetailsSlice";
import stopConditions from "~/js/features/ExtractionApp/StopConditionsSlice";
import sharedDefinitions from "~/js/features/SharedDefinitionsSlice";

// ui
import uiParameters from "~/js/features/ExtractionApp/UiParametersSlice";
import uiRequests from "~/js/features/ExtractionApp/UiRequestsSlice";
import uiAppDetails from "~/js/features/ExtractionApp/UiAppDetailsSlice";
import uiStopConditions from "~/js/features/ExtractionApp/UiStopConditionsSlice";

// config
import config from "~/js/features/ConfigSlice";

const emptyEntities = { ids: [], entities: {} };

function renderNavTabs({ harvestDefinitionKind, extractionDefinition, activeRequest }) {
  const store = configureStore({
    reducer: combineReducers({
      entities: combineReducers({
        requests,
        parameters,
        appDetails,
        sharedDefinitions,
        stopConditions,
      }),
      ui: combineReducers({
        parameters: uiParameters,
        requests: uiRequests,
        appDetails: uiAppDetails,
        stopConditions: uiStopConditions,
      }),
      config,
    }),
    preloadedState: {
      entities: {
        requests: {
          ids: [10, 11],
          entities: { 10: { id: 10 }, 11: { id: 11 } },
        },
        parameters: emptyEntities,
        appDetails: {
          harvestDefinition: { kind: harvestDefinitionKind },
          extractionDefinition,
        },
        sharedDefinitions: emptyEntities,
        stopConditions: emptyEntities,
      },
      ui: {
        parameters: emptyEntities,
        requests: emptyEntities,
        appDetails: {
          activeRequest,
          sharedDefinitionsTabActive: false,
          stopConditionsTabActive: false,
        },
        stopConditions: emptyEntities,
      },
      config: {},
    },
  });

  return render(
    <Provider store={store}>
      <NavTabs />
    </Provider>
  );
}

describe("<NavTabs />", () => {
  beforeEach(() => {
    const portalTarget = document.createElement("div");
    portalTarget.setAttribute("id", "react-nav-tabs");
    document.body.appendChild(portalTarget);
  });

  afterEach(() => {
    document.getElementById("react-nav-tabs").remove();
  });

  describe("when the extraction definition belongs to a pre-processing block", () => {
    // A pre-processing block's extraction definition is stored with
    // kind: 'harvest', so its configured request is the FIRST request -
    // the same as a harvest.
    const preprocessProps = {
      harvestDefinitionKind: "preprocess",
      extractionDefinition: { id: 1, kind: "harvest", paginated: true },
      activeRequest: 10,
    };

    it("marks the first request tab as active on load", () => {
      renderNavTabs(preprocessProps);

      expect(screen.getByText("First Request").classList.contains("active")).toBe(true);
      expect(screen.getByText("Following Requests").classList.contains("active")).toBe(false);
    });

    it("only activates one tab at a time when clicking between them", () => {
      renderNavTabs(preprocessProps);

      fireEvent.click(screen.getByText("Following Requests"));

      expect(screen.getByText("Following Requests").classList.contains("active")).toBe(true);
      expect(screen.getByText("First Request").classList.contains("active")).toBe(false);

      fireEvent.click(screen.getByText("First Request"));

      expect(screen.getByText("First Request").classList.contains("active")).toBe(true);
      expect(screen.getByText("Following Requests").classList.contains("active")).toBe(false);
    });
  });

  describe("when the extraction definition belongs to a harvest", () => {
    it("marks the first request tab as active on load", () => {
      renderNavTabs({
        harvestDefinitionKind: "harvest",
        extractionDefinition: { id: 1, kind: "harvest", paginated: true },
        activeRequest: 10,
      });

      expect(screen.getByText("First Request").classList.contains("active")).toBe(true);
      expect(screen.getByText("Following Requests").classList.contains("active")).toBe(false);
    });
  });

  describe("when the extraction definition belongs to an enrichment", () => {
    // An enrichment's configured request is the LAST request.
    it("marks the request tab as active on load", () => {
      renderNavTabs({
        harvestDefinitionKind: "enrichment",
        extractionDefinition: { id: 1, kind: "enrichment", paginated: false },
        activeRequest: 11,
      });

      expect(screen.getByText("Request").classList.contains("active")).toBe(true);
    });
  });
});
