import React, { useState } from "react";

import { useSelector, useDispatch } from 'react-redux';
import { selectSchemaFieldValueById, deleteSchemaFieldValue } from "~/js/features/SchemaApp/SchemaFieldValuesSlice";

import { selectAppDetails } from '~/js/features/SchemaApp/AppDetailsSlice';

import Button from "react-bootstrap/Button";
import Modal from "react-bootstrap/Modal";

const SchemaFieldValue = ({ id, fieldId }) => {
  const appDetails = useSelector(selectAppDetails);
  const dispatch = useDispatch();

  const [showModal, setShowModal] = useState(false);

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const { value } = useSelector((state) =>
    selectSchemaFieldValueById(state, id)
  );

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
      <div className='border-bottom py-3'>
        <div className="float-start">
          {value}
        </div>

        <div className="float-end">
          <ul className="list-inline my-0">
            <li className="list-inline-item text-success">
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

        <div className='clearfix'></div>
      </div>

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