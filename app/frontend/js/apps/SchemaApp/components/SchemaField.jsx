import React, { useState } from "react";

import { map, orderBy, filter, includes } from "lodash";

import { useSelector, useDispatch } from "react-redux";
import classNames from "classnames";

import { selectAppDetails } from "~/js/features/SchemaApp/AppDetailsSlice";

import {
  selectSchemaFieldById,
  updateSchemaField,
  deleteSchemaField,
} from "~/js/features/SchemaApp/SchemaFieldsSlice";

import {
  selectUiSchemaFieldById,
  toggleDisplaySchemaField,
  setActiveSchemaField,
} from "~/js/features/SchemaApp/UiSchemaFieldsSlice";

import {
  addSchemaFieldValue,
  selectAllSchemaFieldValues,
} from "~/js/features/SchemaApp/SchemaFieldValuesSlice";

import Button from "react-bootstrap/Button";
import Modal from "react-bootstrap/Modal";

import SchemaFieldValue from "./SchemaFieldValue";

const SchemaField = ({ id }) => {
  const appDetails = useSelector(selectAppDetails);

  const { name, kind, schema_field_value_ids, referenced_pipelines } =
    useSelector((state) => selectSchemaFieldById(state, id));

  const allSchemaFieldValues = useSelector(selectAllSchemaFieldValues);
  const schemaFieldValues = filter(allSchemaFieldValues, (fieldValue) => {
    return includes(schema_field_value_ids, fieldValue.id);
  });

  const sortedSchemaFieldValues = orderBy(
    schemaFieldValues,
    [(schemaFieldValue) => schemaFieldValue.value.toLowerCase()],
    ["asc"]
  );
  const dispatch = useDispatch();

  const [nameValue, setNameValue] = useState(name);
  const [kindValue, setKindValue] = useState(kind);
  const [schemaFieldValue, setSchemaFieldValue] = useState("");
  const [showModal, setShowModal] = useState(false);

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const handleSaveClick = () => {
    dispatch(
      updateSchemaField({
        id: id,
        name: nameValue,
        kind: kindValue,
        schemaId: appDetails.schema.id,
      })
    );
  };

  const handleHideClick = () => {
    dispatch(toggleDisplaySchemaField({ id: id, displayed: false }));
  };

  const handleDeleteClick = () => {
    dispatch(
      deleteSchemaField({
        id: id,
        schemaId: appDetails.schema.id,
      })
    );
    handleClose();
  };

  const { saved, deleting, saving, displayed, active } = useSelector((state) =>
    selectUiSchemaFieldById(state, id)
  );

  const fieldClasses = classNames("col-12", "collapse", {
    show: displayed,
    "border-primary": active,
  });

  const cardClasses = classNames("card", "border", "rounded", {
    "border-primary": active,
  });

  const isValid = () => {
    return nameValue.trim() !== "";
  };

  const hasChanged = () => {
    return name !== nameValue || kind !== kindValue;
  };

  const isSaveable = () => {
    return isValid() && hasChanged() && !saving;
  };

  const badgeClasses = classNames({
    badge: true,
    "ms-2": true,
    "bg-primary": saved,
    "bg-secondary": hasChanged(),
  });

  const badgeText = () => {
    if (hasChanged()) {
      return "unsaved";
    } else if (saved) {
      return "saved";
    }
  };

  const handleAddSchemaFieldValueClick = () => {
    dispatch(
      addSchemaFieldValue({
        value: schemaFieldValue,
        schemaFieldId: id,
        schemaId: appDetails.schema.id,
      })
    );

    setSchemaFieldValue("");
  };

  return (
    <>
      <div
        id={`field-${id}`}
        className={fieldClasses}
        data-testid="field"
        onClick={() => dispatch(setActiveSchemaField(id))}
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
                <div className="col-8">
                  <div className="row">
                    <label className="col-form-label col-sm-3" htmlFor="name">
                      <strong>Field name </strong>
                    </label>

                    <div className="col-sm-9">
                      <input
                        id="name"
                        type="text"
                        className="form-control"
                        required="required"
                        defaultValue={name}
                        onChange={(e) => setNameValue(e.target.value)}
                      />
                    </div>
                  </div>
                </div>

                <div className="col-4">
                  <div className="row">
                    <label className="col-form-label col-sm-4" htmlFor="name">
                      <strong>Field Type </strong>
                    </label>

                    <div className="col-sm-8">
                      <select
                        className="form-select"
                        aria-label="Condition type"
                        defaultValue={kind}
                        onChange={(e) => setKindValue(e.target.value)}
                      >
                        <option value="dynamic">Dynamic</option>
                        <option value="fixed">Fixed</option>
                      </select>
                    </div>
                  </div>
                </div>
              </div>

              {kind == "fixed" && (
                <div className="row my-4 justify-content-between">
                  <div className="col-8">
                    <div className="row">
                      <label
                        className="col-form-label col-sm-3"
                        htmlFor="add-value"
                      >
                        <strong>Add value </strong>
                      </label>

                      <div className="col-sm-9">
                        <input
                          id="add-value"
                          type="text"
                          className="form-control"
                          required="required"
                          value={schemaFieldValue}
                          onChange={(e) => setSchemaFieldValue(e.target.value)}
                        />
                      </div>
                    </div>
                  </div>

                  <div className="col-1">
                    <button
                      className="btn btn-outline-primary"
                      onClick={() => handleAddSchemaFieldValueClick()}
                    >
                      Add
                    </button>
                  </div>
                </div>
              )}

              {schema_field_value_ids.length > 0 && (
                <div className="border-top">
                  {map(sortedSchemaFieldValues, (schemaFieldValue) => (
                    <SchemaFieldValue
                      id={schemaFieldValue.id}
                      key={schemaFieldValue.id}
                      fieldId={id}
                    />
                  ))}
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
          <p>Are you sure you want to delete the Schema field "{name}"?</p>

          {referenced_pipelines.length > 0 && (
            <>
              <p className="text-danger">
                It is being used in the following pipelines:
              </p>

              <ul className="list-unstyled mt-2">
                {map(referenced_pipelines, (pipeline) => {
                  return (
                    <li key={pipeline.id}>
                      <a href={`/pipelines/${pipeline.id}`} target="_blank">
                        {pipeline.name}
                      </a>
                    </li>
                  );
                })}
              </ul>
            </>
          )}
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

export default SchemaField;
