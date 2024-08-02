import React, { useEffect, useState, useRef } from "react";
import { useSelector, useDispatch } from "react-redux";
import classNames from "classnames";
import { isEmpty } from "lodash";

import Button from "react-bootstrap/Button";
import Modal from "react-bootstrap/Modal";

import {
  updateField,
  deleteField,
} from "~/js/features/TransformationApp/FieldsSlice";
import { selectFieldById } from "~/js/features/TransformationApp/FieldsSlice";
import {
  selectAppDetails,
  clickedOnRunFields,
} from "~/js/features/TransformationApp/AppDetailsSlice";
import {
  toggleDisplayField,
  setActiveField,
} from "~/js/features/TransformationApp/UiFieldsSlice";

import { selectRawRecord } from "/js/features/TransformationApp/RawRecordSlice";

import { selectUiFieldById } from "~/js/features/TransformationApp/UiFieldsSlice";
import Tooltip from "~/js/components/Tooltip";
import CodeEditor from "~/js/components/CodeEditor";

const Field = ({ id }) => {
  const appDetails = useSelector(selectAppDetails);
  const { name, block, kind } = useSelector((state) =>
    selectFieldById(state, id)
  );

  const rawRecord = useSelector(selectRawRecord);

  const { saved, deleting, saving, running, error, hasRun, displayed, active } =
    useSelector((state) => selectUiFieldById(state, id));

  const dispatch = useDispatch();

  const [nameValue, setNameValue] = useState(name);
  const [kindValue, setKindValue] = useState(kind);
  const [blockValue, setBlockValue] = useState(block);
  const [showModal, setShowModal] = useState(false);

  const nameInputRef = useRef(null);

  const handleSaveClick = () => {
    dispatch(
      updateField({
        id: id,
        name: nameValue,
        block: blockValue,
        kind: kindValue,
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        transformationDefinitionId: appDetails.transformationDefinition.id,
      })
    );
  };

  const handleHideClick = () => {
    dispatch(toggleDisplayField({ id: id, displayed: false }));
  };

  const handleDeleteClick = () => {
    dispatch(
      deleteField({
        id: id,
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        transformationDefinitionId: appDetails.transformationDefinition.id,
      })
    );
    handleClose();
  };

  const handleRunClick = () => {
    dispatch(
      clickedOnRunFields({
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        transformationDefinitionId: appDetails.transformationDefinition.id,
        page: rawRecord.page,
        record: rawRecord.record,
        fields: [id],
      })
    );
  };

  const isValid = () => {
    return nameValue.trim() !== "" && blockValue.trim() !== "";
  };

  const hasChanged = () => {
    return name !== nameValue || block !== blockValue || kind !== kindValue;
  };

  const isSaveable = () => {
    return isValid() && hasChanged() && !saving;
  };

  const badgeClasses = classNames({
    badge: true,
    "ms-2": true,
    "bg-primary": saved,
    "bg-success": hasRun && !error,
    "bg-danger": !hasChanged() && hasRun && error,
    "bg-secondary": hasChanged(),
  });

  const badgeText = () => {
    if (hasRun && !error) {
      return "success";
    } else if (hasChanged()) {
      return "unsaved";
    } else if (hasRun && error) {
      return "error";
    } else if (saved) {
      return "saved";
    }
  };

  useEffect(() => {
    // scroll on "Add field" click
    if (isEmpty(nameValue)) {
      const element = document.getElementById(`field-${id}`);
      element.scrollIntoView({ behaviour: "smooth" });
    }

    // Focus on the name input field
    if (nameInputRef.current) {
      nameInputRef.current?.focus();
    }
  }, []);

  const fieldClasses = classNames("col-12", "collapse", {
    show: displayed,
    "border-primary": active,
  });

  const cardClasses = classNames("card", "border", "rounded", {
    "border-primary": active,
  });

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const nameColumnClasses = classNames(
    { "col-8": kind != "field" },
    { "col-12": kind == "field" }
  );

  return (
    <>
      <div
        id={`field-${id}`}
        className={fieldClasses}
        data-testid="field"
        onClick={() => dispatch(setActiveField(id))}
      >
        <div className={cardClasses}>
          <div className="card-body">
            <div className="d-flex d-row justify-content-between align-items-center">
              <div>
                <h5 className="m-0 d-inline">{name}</h5>
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
                  disabled={!saved || hasChanged() || running}
                  onClick={handleRunClick}
                >
                  <i className="bi bi-play" aria-hidden="true"></i>
                  {running ? " Previewing..." : " Preview"}
                </button>

                <button
                  className="btn btn-outline-primary"
                  onClick={handleHideClick}
                >
                  <i className="bi bi-eye-slash" aria-hidden="true"></i> Hide
                </button>

                <button className="btn btn-outline-danger" onClick={handleShow}>
                  <i className="bi bi-trash" aria-hidden="true"></i>
                  {deleting ? " Deleting..." : " Delete"}
                </button>
              </div>
            </div>

            <div className="mt-3 show" id={`field-${id}-content`}>
              <div className="row">
                <div className={nameColumnClasses}>
                  <div className="row">
                    <label className="col-form-label col-sm-2" htmlFor="name">
                      <strong>Name </strong>
                      <Tooltip data-bs-title="This is the field name that the result of this transformation will appear under on the transformed record.">
                        <i
                          className="bi bi-question-circle"
                          aria-label="help text"
                        ></i>
                      </Tooltip>
                    </label>

                    <div className="col-sm-10">
                      <input
                        id="name"
                        type="text"
                        className="form-control"
                        required="required"
                        defaultValue={name}
                        onChange={(e) => setNameValue(e.target.value)}
                        ref={nameInputRef}
                      />
                    </div>
                  </div>
                </div>

                {kind != "field" && (
                  <div className="col-4">
                    <div className="row">
                      <label className="col-form-label col-sm-4" htmlFor="name">
                        <strong>Type </strong>
                        <Tooltip data-bs-title="A rejected record will be skipped during a harvest. A deleted record will be removed from the API if it has been harvested in the past.">
                          <i
                            className="bi bi-question-circle"
                            aria-label="help text"
                          ></i>
                        </Tooltip>
                      </label>

                      <div className="col-sm-8">
                        <select
                          className="form-select"
                          aria-label="Condition type"
                          defaultValue={kind}
                          onChange={(e) => setKindValue(e.target.value)}
                        >
                          <option value="reject_if">Reject if</option>
                          <option value="delete_if">Delete if</option>
                        </select>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              <label className="form-label mt-4" htmlFor="block">
                Block{" "}
                <Tooltip data-bs-title="This is the code that is applied to create this field on the transformed record.">
                  <i
                    className="bi bi-question-circle"
                    aria-label="help text"
                  ></i>
                </Tooltip>
              </label>

              <CodeEditor
                initContent={block}
                onChange={(e) => setBlockValue(e.target.value)}
              />

              {error && (
                <div className="alert alert-danger mt-4" role="alert">
                  <h4 className="alert-heading">{error.title}</h4>
                  <hr />
                  <p className="mb-0">{error.description}</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      <Modal show={showModal} onHide={handleClose}>
        <Modal.Header closeButton>
          <Modal.Title>Delete</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          Are you sure you want to delete the field "{name}"?
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={handleClose}>
            Close
          </Button>
          <Button variant="danger" onClick={handleDeleteClick}>
            Delete
          </Button>
        </Modal.Footer>
      </Modal>
    </>
  );
};

export default Field;
