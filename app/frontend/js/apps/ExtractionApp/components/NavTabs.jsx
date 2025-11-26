import React from "react";
import { createPortal } from "react-dom";
import { useSelector, useDispatch } from "react-redux";
import classNames from "classnames";

import { selectRequestIds } from "~/js/features/ExtractionApp/RequestsSlice";
import { selectAllParameters } from "~/js/features/ExtractionApp/ParametersSlice";
import { selectAppDetails } from "~/js/features/TransformationApp/AppDetailsSlice";
import { selectAllSharedDefinitions } from "~/js/features/SharedDefinitionsSlice";
import { selectHarvestDefinition } from "/js/features/ExtractionApp/AppDetailsSlice";

import { toggleDisplayParameters } from "~/js/features/ExtractionApp/UiParametersSlice";

import {
  selectUiAppDetails,
  updateActiveRequest,
  activateSharedDefinitionsTab,
  activateStopConditionsTab,
} from "~/js/features/ExtractionApp/UiAppDetailsSlice";

const NavTabs = () => {
  const dispatch = useDispatch();
  const harvestDefinition = useSelector(selectHarvestDefinition);
  const appDetails = useSelector(selectAppDetails);
  const uiAppDetails = useSelector(selectUiAppDetails);
  const requestIds = useSelector(selectRequestIds);
  const initialRequestIndex = harvestDefinition.kind == "harvest" ? 0 : 1;
  const initialRequestId = requestIds[initialRequestIndex];
  const mainRequestId = requestIds[1];
  const sharedDefinitions = useSelector(selectAllSharedDefinitions);

  const initialRequestClasses = classNames("nav-link", {
    active: uiAppDetails.activeRequest == initialRequestId,
  });
  const mainRequestClasses = classNames("nav-link", {
    active: uiAppDetails.activeRequest == mainRequestId,
  });
  const sharedClasses = classNames("nav-link", {
    active: uiAppDetails.sharedDefinitionsTabActive == true,
  });
  const stopConditionsClasses = classNames("nav-link", {
    active: uiAppDetails.stopConditionsTabActive == true,
  });
  const allParameters = useSelector(selectAllParameters);

  const handleTabClick = (id) => {
    dispatch(
      toggleDisplayParameters({ parameters: allParameters, displayed: true })
    );
    dispatch(updateActiveRequest(id));
  };

  const requestTabText = () => {
    if (appDetails.extractionDefinition.paginated) {
      return "First Request";
    }

    return "Request";
  };

  const requestTab = () => {
    return (
      <li className="nav-item" role="presentation">
        <button
          className={initialRequestClasses}
          type="button"
          role="tab"
          onClick={() => {
            handleTabClick(initialRequestId);
          }}
        >
          {requestTabText()}
        </button>
      </li>
    );
  };

  const followingRequestsTab = () => {
    if (!appDetails.extractionDefinition.paginated) return;

    return (
      <li
        className="nav-item"
        role="presentation"
        onClick={() => {
          handleTabClick(mainRequestId);
        }}
      >
        <button className={mainRequestClasses} type="button" role="tab">
          Following Requests
        </button>
      </li>
    );
  };

  const stopConditionsTab = () => {
    return (
      <li
        className="nav-item"
        role="presentation"
        onClick={() => {
          dispatch(activateStopConditionsTab());
        }}
      >
        <button className={stopConditionsClasses} type="button" role="tab">
          Stop Conditions
        </button>
      </li>
    );
  };

  const sharedTab = () => {
    if (sharedDefinitions.length === 0) return;

    return (
      <li className="nav-item" role="presentation">
        <button
          className={sharedClasses}
          type="button"
          role="tab"
          onClick={() => {
            dispatch(activateSharedDefinitionsTab());
          }}
        >
          Shared ({sharedDefinitions.length} pipelines)
        </button>
      </li>
    );
  };

  return createPortal(
    <>
      <ul className="nav nav-tabs mt-4" role="tablist">
        {requestTab()}
        {followingRequestsTab()}
        {stopConditionsTab()}
        {sharedTab()}
      </ul>
    </>,
    document.getElementById("react-nav-tabs")
  );
};

export default NavTabs;
