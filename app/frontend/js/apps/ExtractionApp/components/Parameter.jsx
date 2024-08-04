import React, { useEffect, useState, useRef } from "react";
import { useSelector, useDispatch } from "react-redux";
import classNames from "classnames";
import { capitalize, filter, map } from "lodash";

import ParameterDeleteModal from "~/js/apps/ExtractionApp/components/ParameterDeleteModal";
import CodeEditor from "~/js/components/CodeEditor";

import {
  selectParameterById,
  selectAllParameters,
  updateParameter,
} from "~/js/features/ExtractionApp/ParametersSlice";

import { selectAppDetails } from "~/js/features/ExtractionApp/AppDetailsSlice";
import { selectUiAppDetails } from "~/js/features/ExtractionApp/UiAppDetailsSlice";
import { selectRequestIds } from "~/js/features/ExtractionApp/RequestsSlice";

import {
  selectUiParameterById,
  toggleDisplayParameter,
  setActiveParameter,
} from "~/js/features/ExtractionApp/UiParametersSlice";

import Tooltip from "~/js/components/Tooltip";

const Parameter = ({ id }) => {
  const appDetails = useSelector(selectAppDetails);
  const uiAppDetails = useSelector(selectUiAppDetails);
  let allParameters = useSelector(selectAllParameters);

  const requestIds = useSelector(selectRequestIds);
  const initialRequestId = requestIds[0];
  const mainRequestId = requestIds[1];

  allParameters = filter(allParameters, ["request_id", initialRequestId]);

  const initialRequestQueryParameters = filter(allParameters, [
    "kind",
    "query",
  ]);

  const { name, content, content_type, kind } = useSelector((state) =>
    selectParameterById(state, id)
  );

  const { saved, deleting, saving, displayed, active } = useSelector((state) =>
    selectUiParameterById(state, id)
  );

  const dispatch = useDispatch();

  const [nameValue, setNameValue] = useState(name);
  const [contentValue, setContentValue] = useState(content);
  const [kindValue] = useState(kind);
  const [showModal, setShowModal] = useState(false);

  const nameInputRef = useRef(null);
  const contentInputRef = useRef(null);

  useEffect(() => {
    if (kind === "slug") {
      contentInputRef.current?.focus();
    } else {
      nameInputRef.current?.focus();
    }
  }, [kind]);

  const handleSaveClick = () => {
    dispatch(
      updateParameter({
        id: id,
        name: nameValue,
        content: contentValue,
        kind: kindValue,
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        extractionDefinitionId: appDetails.extractionDefinition.id,
        requestId: uiAppDetails.activeRequest,
      })
    );
  };

  const isValid = () => {
    if (kind == "slug") {
      return contentValue.trim() !== "";
    }

    return nameValue.trim() !== "" && contentValue.trim() !== "";
  };

  const hasChanged = () => {
    return name !== nameValue || content !== contentValue || kind !== kindValue;
  };

  const isSaveable = () => {
    return isValid() && hasChanged() && !saving;
  };

  const badgeText = () => {
    if (hasChanged()) {
      return "unsaved";
    } else if (saved) {
      return "saved";
    }
  };

  const parameterClasses = classNames(
    "col-12",
    "collapse",
    "mt-4",
    "border",
    "rounded",
    {
      show: displayed,
      "border-primary": active,
    }
  );

  const badgeClasses = classNames({
    badge: true,
    "ms-2": true,
    "bg-primary": saved,
    "bg-secondary": hasChanged(),
  });

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const handleHideClick = () => {
    dispatch(toggleDisplayParameter({ id: id, displayed: false }));
  };

  const valueColumnClasses = classNames({
    "col-sm-11": kind == "slug",
    "col-sm-6": kind != "slug",
  });

  const displayName = () => {
    if (kind == "slug") {
      return content;
    }

    return name;
  };

  const handleDropdownClick = (value) => {
    dispatch(
      updateParameter({
        id: id,
        content_type: value,
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        extractionDefinitionId: appDetails.extractionDefinition.id,
        requestId: uiAppDetails.activeRequest,
      })
    );
  };

  return (
    <>
      <div
        id={`parameter-${id}`}
        className={parameterClasses}
        onClick={() => dispatch(setActiveParameter(id))}
      >
        <div className="card">
          <div className="card-body">
            <div className="d-flex d-row justify-content-between align-items-center">
              <div>
                <h5 className="m-0 d-inline">{displayName()}</h5>

                <span className={badgeClasses}>{badgeText()}</span>
              </div>

              <div className="hstack gap-2">
                <button
                  className="btn btn-outline-primary"
                  disabled={!isSaveable()}
                  onClick={handleSaveClick}
                >
                  <i className="bi bi-save" aria-hidden="true"></i>
                  {saving ? " Saving..." : " Save"}
                </button>

                <button
                  className="btn btn-outline-primary"
                  onClick={handleHideClick}
                >
                  <i className="bi bi-eye-slash" aria-hidden="true"></i> Hide
                </button>

                <div className="dropdown">
                  <button
                    className="btn btn-outline-primary dropdown-toggle"
                    type="button"
                    data-bs-toggle="dropdown"
                    aria-expanded="false"
                  >
                    <i className="bi bi-code-square" aria-hidden="true"></i>{" "}
                    {capitalize(content_type)}
                  </button>
                  <ul className="dropdown-menu">
                    <li>
                      <a
                        className="dropdown-item"
                        onClick={() => {
                          handleDropdownClick(0);
                        }}
                      >
                        Static
                      </a>
                    </li>
                    <li>
                      <a
                        className="dropdown-item"
                        onClick={() => {
                          handleDropdownClick(1);
                        }}
                      >
                        Dynamic
                      </a>
                    </li>
                    {uiAppDetails.activeRequest == mainRequestId &&
                      kind == "query" && (
                        <li>
                          <a
                            className="dropdown-item"
                            onClick={() => {
                              handleDropdownClick(2);
                            }}
                          >
                            Incremental
                          </a>
                        </li>
                      )}
                  </ul>
                </div>

                <button className="btn btn-outline-danger" onClick={handleShow}>
                  <i className="bi bi-trash" aria-hidden="true"></i>
                  {deleting ? " Deleting..." : " Delete"}
                </button>
              </div>
            </div>

            <div className="row align-items-center mt-4">
              {kind != "slug" && (
                <>
                  <div className="col-6">
                    <div className="row">
                      <div className="col-1">
                        {content_type == "incremental" && (
                          <Tooltip data-bs-title="Please select the key of the first request that you want to be incremented.">
                            <label className="col-form-label">Key </label>
                          </Tooltip>
                        )}

                        {content_type != "incremental" && (
                          <label className="col-form-label">Key </label>
                        )}
                      </div>

                      <div className="col-11">
                        {content_type != "incremental" && (
                          <input
                            type="text"
                            className="form-control"
                            defaultValue={name}
                            onChange={(e) => setNameValue(e.target.value)}
                            ref={nameInputRef}
                          />
                        )}

                        {content_type == "incremental" && kind == "query" && (
                          <select
                            className="form-select"
                            defaultValue={name}
                            onChange={(e) => setNameValue(e.target.value)}
                            ref={nameInputRef}
                          >
                            <option value="">
                              Please select a parameter to be incremented...
                            </option>
                            {map(initialRequestQueryParameters, (parameter) => {
                              return (
                                <option
                                  value={parameter.name}
                                  ref={valueInputRef}
                                >
                                  {parameter.name}
                                </option>
                              );
                            })}
                          </select>
                        )}
                      </div>
                    </div>
                  </div>
                </>
              )}

              <div className={valueColumnClasses}>
                <div className="row">
                  <div className="col-1">
                    {content_type == "incremental" && (
                      <Tooltip data-bs-title="Please input the amount you want the value of this key to be incremented by">
                        <label className="col-form-label">Value </label>
                      </Tooltip>
                    )}

                    {content_type != "incremental" && (
                      <label className="col-form-label">Value </label>
                    )}
                  </div>

                  <div className="col-11">
                    {content_type != "dynamic" && (
                      <input
                        type="text"
                        className="form-control"
                        required="required"
                        defaultValue={contentValue}
                        onChange={(e) => setContentValue(e.target.value)}
                        ref={contentInputRef}
                      />
                    )}

                    {content_type == "dynamic" && (
                      <CodeEditor
                        initContent={content}
                        onChange={(e) => setContentValue(e.target.value)}
                      />
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <ParameterDeleteModal
        showModal={showModal}
        handleClose={handleClose}
        id={id}
        name={name}
      />
    </>
  );
};

export default Parameter;
