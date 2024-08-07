import React, { useState } from "react";

import { useSelector, useDispatch } from 'react-redux';
import { selectSchemaFieldValueById, deleteSchemaFieldValue, updateSchemaFieldValue } from "~/js/features/SchemaApp/SchemaFieldValuesSlice";

import { selectAppDetails } from '~/js/features/SchemaApp/AppDetailsSlice';

import Button from "react-bootstrap/Button";
import Modal from "react-bootstrap/Modal";

const SchemaFieldValue = ({ id, fieldId }) => {
  const appDetails = useSelector(selectAppDetails);
  const dispatch = useDispatch();

  const [showModal, setShowModal] = useState(false);

  const [editing, setEditing] = useState(false);

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const { value } = useSelector((state) =>
    selectSchemaFieldValueById(state, id)
  );

  const [schemaFieldValue, setSchemaFieldValue] = useState(value);

  const handleUpdateSchemaFieldValueClick = () => {
    dispatch(
      updateSchemaFieldValue({
        id: id,
        schemaId: appDetails.schema.id,
        schemaFieldId: fieldId,
        value: schemaFieldValue
      })
    )

    setEditing(false);
  }

  const handleDeleteClick = () => {
    dispatch(
      deleteSchemaFieldValue({
        id: id,
        schemaId: appDetails.schema.id,
        schemaFieldId: fieldId
      })
    );
    handleClose();
  };

  return (
    <>


      {!editing && (
        <div className='border-bottom py-3 d-flex justify-content-between'>
          {value}

          <ul className="list-inline my-0">
            <li
              className="list-inline-item text-success"
              onClick={() => setEditing(true)}
            >
              Edit
            </li>
            <li
              className="list-inline-item text-danger"
              onClick={() => handleShow()}
            >
              Delete
            </li>
          </ul>
        </div>
      )
      }

      {
        editing && (
          <div className='border-bottom row py-3 justify-content-between'>

            <div className='col-8'>
              <div className="row">
                <label className="col-form-label col-sm-3" htmlFor="add-value">
                  <strong>Edit value </strong>
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

            <div className='col-2'>
              <button
                className="btn btn-outline-primary mx-2"
                onClick={() => handleUpdateSchemaFieldValueClick()}
              >
                Update
              </button>
              <span
                className="text-danger mx-1"
                onClick={() => setEditing(false)}
              >
                Cancel
              </span>
            </div>

          </div>
        )
      }


      <Modal show={showModal} onHide={handleClose}>
        <Modal.Header closeButton>
          <Modal.Title>Delete</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          Are you sure you want to delete the value "{value}"?
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

export default SchemaFieldValue;