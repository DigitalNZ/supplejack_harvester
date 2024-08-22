import React from "react";

import { map, filter } from "lodash";
import { useSelector, useDispatch } from "react-redux";
import { selectAllParameters } from "~/js/features/ExtractionApp/ParametersSlice";
import {
  selectRequestById,
  selectRequestIds,
  updateRequest,
} from "~/js/features/ExtractionApp/RequestsSlice";
import { selectAppDetails } from "~/js/features/ExtractionApp/AppDetailsSlice";
import { selectUiAppDetails } from "~/js/features/ExtractionApp/UiAppDetailsSlice";
import Tooltip from "~/js/components/Tooltip";

import RequestFragment from "~/js/apps/ExtractionApp/components/RequestFragment";

const Request = ({}) => {
  const dispatch = useDispatch();
  const appDetails = useSelector(selectAppDetails);
  const requestIds = useSelector(selectRequestIds);
  const uiAppDetails = useSelector(selectUiAppDetails);

  const { id, base_url, http_method } = useSelector((state) =>
    selectRequestById(state, uiAppDetails.activeRequest)
  );

  const initialRequestId = requestIds[0];

  let allParameters = useSelector(selectAllParameters);
  allParameters = filter(allParameters, [
    "request_id",
    uiAppDetails.activeRequest,
  ]);

  const slugParameters = filter(allParameters, ["kind", "slug"]);
  const queryParameters = filter(allParameters, ["kind", "query"]);
  const headerParameters = filter(allParameters, ["kind", "header"]);

  const handleHttpMethodClick = (method) => {
    dispatch(
      updateRequest({
        id: id,
        base_url: base_url,
        http_method: method,
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        extractionDefinitionId: appDetails.extractionDefinition.id,
      })
    );
  };

  const requestText = () => {
    if (!appDetails.extractionDefinition.paginated) {
      return "Request URL";
    }

    if (id == initialRequestId) {
      return "First Request URL";
    } else {
      return "Following Requests URL";
    }
  };

  const formattedSlugParameters = () => {
    return map(slugParameters, (slugParameter, index) => {
      return (
        <RequestFragment
          id={slugParameter.id}
          index={index}
          key={slugParameter.id}
        />
      );
    });
  };

  const formattedQueryParameters = () => {
    return map(queryParameters, (queryParameter, index) => {
      return (
        <RequestFragment
          id={queryParameter.id}
          index={index}
          key={queryParameter.id}
        />
      );
    });
  };

  const formattedPayload = () => {
    const params = map(queryParameters, (queryParameter) => {
      return { [queryParameter.name]: queryParameter.content };
    });

    return (
      <>
        <br />
        <br />
        <pre>{JSON.stringify(Object.assign({}, ...params), null, 2)}</pre>
      </>
    );
  };

  return (
    <div className="card">
      <div className="card-body">
        <div className="d-flex d-row justify-content-between align-items-center">
          <div>
            <h5 className="m-0 d-inline">{requestText()}</h5>
            <p>
              {queryParameters.length} query parameters, {slugParameters.length}{" "}
              slug parameters, and {headerParameters.length} header parameters.
            </p>
          </div>

          {!appDetails.extractionDefinition.evaluate_javascript && (
            <div className="dropdown">
              <button
                className="btn btn-outline-primary dropdown-toggle"
                type="button"
                data-bs-toggle="dropdown"
                aria-expanded="false"
              >
                <i className="bi bi-arrow-down-up" aria-hidden="true"></i>{" "}
                {http_method}
              </button>
              <ul className="dropdown-menu">
                <li>
                  <a
                    className="dropdown-item"
                    onClick={() => {
                      handleHttpMethodClick("GET");
                    }}
                  >
                    GET
                  </a>
                </li>
                <li>
                  <a
                    className="dropdown-item"
                    onClick={() => {
                      handleHttpMethodClick("POST");
                    }}
                  >
                    POST
                  </a>
                </li>
              </ul>
            </div>
          )}

          {appDetails.extractionDefinition.evaluate_javascript && (
            <Tooltip data-bs-title="You cannot add change the HTTP method when your extraction needs to be evaluated with JavaScript">
              <div className="d-grid gap-2">
                <button disabled="true" className="btn btn-outline-primary">
                  <i className="bi bi-arrow-down-up" aria-hidden="true"></i> GET
                </button>
              </div>
            </Tooltip>
          )}
        </div>

        <strong className="float-start me-2">URL</strong>

        <p>
          <span className="text-secondary">{base_url}</span>
          {formattedSlugParameters()}
          {http_method == "GET" && formattedQueryParameters()}
        </p>

        {http_method == "POST" && (
          <strong className="float-start me-2">Payload</strong>
        )}
        {http_method == "POST" && formattedPayload()}
      </div>
    </div>
  );
};

export default Request;
