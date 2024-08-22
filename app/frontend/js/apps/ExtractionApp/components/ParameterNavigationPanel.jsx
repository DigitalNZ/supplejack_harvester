import React from "react";
import { useSelector, useDispatch } from "react-redux";

import { filter } from "lodash";

import { selectAllParameters } from "~/js/features/ExtractionApp/ParametersSlice";
import { toggleDisplayParameters } from "~/js/features/ExtractionApp/UiParametersSlice";
import { selectUiAppDetails } from "~/js/features/ExtractionApp/UiAppDetailsSlice";
import { selectRequestById } from "~/js/features/ExtractionApp/RequestsSlice";
import Tooltip from "~/js/components/Tooltip";

import AddParameter from "./AddParameter";
import ParameterNavigationList from "./ParameterNavigationList";

import { selectAppDetails } from "~/js/features/TransformationApp/AppDetailsSlice";

const ParameterNavigationPanel = () => {
  const dispatch = useDispatch();
  const appDetails = useSelector(selectAppDetails);
  const uiAppDetails = useSelector(selectUiAppDetails);

  let allParameters = useSelector(selectAllParameters);
  allParameters = filter(allParameters, [
    "request_id",
    uiAppDetails.activeRequest,
  ]);

  const queryParameters = filter(allParameters, ["kind", "query"]);
  const headerParameters = filter(allParameters, ["kind", "header"]);
  const slugParameters = filter(allParameters, ["kind", "slug"]);

  const request = useSelector((state) =>
    selectRequestById(state, uiAppDetails.activeRequest)
  );

  const queryHeading = () => {
    if (request.http_method == "POST") {
      return "Payload";
    }

    return "Query";
  };

  return (
    <div className="card field-nav-panel">
      <div className="d-flex flex-column overflow-auto">
        <div className="field-nav-panel__header">
          <Tooltip data-bs-title="Query parameters will make up the majority of your request. They are appended to the base url after the question mark.">
            <h5>{queryHeading()}</h5>
          </Tooltip>

          <div className="btn-group card__control">
            <i
              className="bi bi-three-dots-vertical"
              data-bs-toggle="dropdown"
            ></i>
            <ul className="dropdown-menu dropdown-menu-end">
              <li
                className="dropdown-item card__control-action"
                onClick={() => {
                  dispatch(
                    toggleDisplayParameters({
                      parameters: queryParameters,
                      displayed: false,
                    })
                  );
                }}
              >
                <i className="bi bi-eye-slash me-2"></i> Hide all
              </li>

              <li
                className="dropdown-item card__control-action"
                onClick={() => {
                  dispatch(
                    toggleDisplayParameters({
                      parameters: queryParameters,
                      displayed: true,
                    })
                  );
                }}
              >
                <i className="bi bi-eye me-2"></i> Show all
              </li>
            </ul>
          </div>
        </div>

        <div className="field-nav-panel__content">
          <AddParameter buttonText="+ Add" kind="query" />

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">
            <ParameterNavigationList
              requestId={uiAppDetails.activeRequest}
              kind="query"
            />
          </ul>
        </div>

        <div className="field-nav-panel__header field-nav-panel__header--fields">
          <Tooltip data-bs-title="Header parameters are sent in the headers of the request. They are often used for authentication.">
            <h5>Header</h5>
          </Tooltip>

          <div className="btn-group card__control">
            <i
              className="bi bi-three-dots-vertical"
              data-bs-toggle="dropdown"
            ></i>
            <ul className="dropdown-menu dropdown-menu-end">
              <li
                className="dropdown-item card__control-action"
                onClick={() => {
                  dispatch(
                    toggleDisplayParameters({
                      parameters: headerParameters,
                      displayed: false,
                    })
                  );
                }}
              >
                <i className="bi bi-eye-slash me-2"></i> Hide all
              </li>

              <li
                className="dropdown-item card__control-action"
                onClick={() => {
                  dispatch(
                    toggleDisplayParameters({
                      parameters: headerParameters,
                      displayed: true,
                    })
                  );
                }}
              >
                <i className="bi bi-eye me-2"></i> Show all
              </li>
            </ul>
          </div>
        </div>

        <div className="field-nav-panel__content">
          {!appDetails.extractionDefinition.evaluate_javascript && (
            <AddParameter buttonText="+ Add" kind="header" />
          )}

          {appDetails.extractionDefinition.evaluate_javascript && (
            <Tooltip data-bs-title="You cannot add a header parameter when your extraction needs to be evaluated with JavaScript">
              <div className="d-grid gap-2">
                <button disabled="true" className="btn btn-outline-primary">
                  + Add
                </button>
              </div>
            </Tooltip>
          )}

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">
            <ParameterNavigationList
              requestId={uiAppDetails.activeRequest}
              kind="header"
            />
          </ul>
        </div>

        <div className="field-nav-panel__header field-nav-panel__header--fields">
          <Tooltip data-bs-title="Slug parameters are sometimes required for particular use cases. They are appended to the base url after the forward slash.">
            <h5>Slug</h5>
          </Tooltip>

          <div className="btn-group card__control">
            <i
              className="bi bi-three-dots-vertical"
              data-bs-toggle="dropdown"
            ></i>
            <ul className="dropdown-menu dropdown-menu-end">
              <li
                className="dropdown-item card__control-action"
                onClick={() => {
                  dispatch(
                    toggleDisplayParameters({
                      parameters: slugParameters,
                      displayed: false,
                    })
                  );
                }}
              >
                <i className="bi bi-eye-slash me-2"></i> Hide all
              </li>

              <li
                className="dropdown-item card__control-action"
                onClick={() => {
                  dispatch(
                    toggleDisplayParameters({
                      parameters: slugParameters,
                      displayed: true,
                    })
                  );
                }}
              >
                <i className="bi bi-eye me-2"></i> Show all
              </li>
            </ul>
          </div>
        </div>

        <div className="field-nav-panel__content">
          <AddParameter buttonText="+ Add" kind="slug" />

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">
            <ParameterNavigationList
              requestId={uiAppDetails.activeRequest}
              kind="slug"
            />
          </ul>
        </div>
      </div>
    </div>
  );
};

export default ParameterNavigationPanel;
