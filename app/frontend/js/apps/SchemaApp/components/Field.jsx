import React, { useEffect, useState } from "react";

import { useSelector, useDispatch } from 'react-redux';
import classNames from "classnames";

import { selectAppDetails } from '~/js/features/SchemaApp/AppDetailsSlice';

import { selectFieldById, updateField, deleteField } from "~/js/features/SchemaApp/FieldsSlice";
import {
  selectUiFieldById, toggleDisplayField,
  setActiveField,
} from "~/js/features/SchemaApp/UiFieldsSlice";

import Button from "react-bootstrap/Button";
import Modal from "react-bootstrap/Modal";

const Field = ({ id }) => {
  const appDetails = useSelector(selectAppDetails);

  const { name, kind } = useSelector((state) =>
    selectFieldById(state, id)
  );

  const dispatch = useDispatch();

  const [nameValue, setNameValue] = useState(name);
  const [kindValue, setKindValue] = useState(kind);
  const [fieldValue, setFieldValue] = useState('')
  const [showModal, setShowModal] = useState(false);

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const handleSaveClick = () => {
    dispatch(
      updateField({
        id: id,
        name: nameValue,
        kind: kindValue,
        schemaId: appDetails.schema.id,
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
        schemaId: appDetails.schema.id,
      })
    );
    handleClose();
  };

  const { saved, deleting, saving, displayed, active } =
    useSelector((state) => selectUiFieldById(state, id));

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

                <div className='col-8'>
                  <div className="row">
                    <label className="col-form-label col-sm-2" htmlFor="name">
                      <strong>Field name </strong>
                    </label>

                    <div className="col-sm-8">
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

              <div className='row'>
                <div className='col-10'>
                  <div className="row">
                    <label className="col-form-label col-sm-2" htmlFor="add-value">
                      <strong>Add value </strong>
                    </label>

                    <div className="col-sm-10">
                      <input
                        id="add-value"
                        type="text"
                        className="form-control"
                        required="required"
                        onChange={(e) => setFieldValue(e.target.value)}
                      />
                    </div>
                  </div>
                </div>

              </div>

            </div>
          </div>
        </div>
      </div>

      <Modal show={showModal} onHide={handleClose}>
        <Modal.Header closeButton>
          <Modal.Title>Delete</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          Are you sure you want to delete the Schema field "{name}"?
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
  )
}

export default Field;