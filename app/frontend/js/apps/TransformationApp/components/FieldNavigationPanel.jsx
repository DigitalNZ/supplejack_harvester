import React, { useState } from "react";
import { useSelector, useDispatch } from "react-redux";
import { selectAllFields } from "~/js/features/TransformationApp/FieldsSlice";
import { selectAllSchemas } from "~/js/features/TransformationApp/SchemasSlice";
import { find, filter, map, includes } from "lodash";
import FieldNavigationListItem from "./FieldNavigationListItem";
import AddField from "~/js/apps/TransformationApp/components/AddField";
import { toggleDisplayFields } from "~/js/features/TransformationApp/UiFieldsSlice";
import Tooltip from "~/js/components/Tooltip";

import Button from "react-bootstrap/Button";
import Modal from "react-bootstrap/Modal";

const FieldNavigationPanel = () => {
  const dispatch = useDispatch();
  const allFields = useSelector(selectAllFields);
  const allSchemas = useSelector(selectAllSchemas);

  const [showModal, setShowModal] = useState(false);

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const [schemaValue, setSchemaValue] = useState('');
  const [fieldValues, setFieldValues] = useState([]);

  const updateFieldValues = (id) => {
    if (includes(fieldValues, id)) {
      const filteredValues = filter(fieldValues, (value) => {
        return value != id;
      });
      setFieldValues(
        filteredValues
      )
    } else {
      setFieldValues(
        [
          ...fieldValues,
          id
        ]
      )
    }
  }

  const fields = filter(allFields, ["kind", "field"]);
  const conditions = filter(allFields, ["kind", "reject_if"]).concat(
    filter(allFields, ["kind", "delete_if"])
  );

  const customFields = filter(fields, ["schema", false]);
  const schemaFields = filter(fields, ["schema", true]);

  return (
    <div className="card field-nav-panel">
      <div className="d-flex flex-column overflow-auto">
        <div className="field-nav-panel__header">
          <Tooltip data-bs-title="Conditions allow you to define rules to reject or delete records.">
            <h5>Conditions</h5>
          </Tooltip>

          <div className="btn-group card__control">
            <i
              className="bi bi-three-dots-vertical"
              data-bs-toggle="dropdown"
            ></i>
            <ul className="dropdown-menu dropdown-menu-end">
              <li
                className="dropdown-item card__control-acton"
                onClick={() => {
                  dispatch(
                    toggleDisplayFields({
                      fields: conditions,
                      displayed: false,
                    })
                  );
                }}
              >
                <i className="bi bi-eye-slash me-2"></i> Hide all conditions
              </li>

              <li
                className="dropdown-item card__control-acton"
                onClick={() => {
                  dispatch(
                    toggleDisplayFields({ fields: conditions, displayed: true })
                  );
                }}
              >
                <i className="bi bi-eye me-2"></i> Show all conditions
              </li>
            </ul>
          </div>
        </div>

        <div className="field-nav-panel__content">
          <AddField kind="reject_if" />

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">
            {conditions.map((condition) => {
              return (
                <FieldNavigationListItem id={condition.id} key={condition.id} />
              );
            })}
          </ul>
        </div>

        <div className="field-nav-panel__header field-nav-panel__header--fields">
          <h5>Schema Fields</h5>
        </div>

        <div className="field-nav-panel__content">
          <button
            className="btn btn-outline-primary"
            onClick={handleShow}
          >
            <i className="bi bi-download me-2"></i>
            Load schema
          </button>

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">
            {schemaFields.map((field) => {
              return <FieldNavigationListItem id={field.id} key={field.id} />;
            })}
          </ul>
        </div>

        <div className="field-nav-panel__header field-nav-panel__header--fields">
          <Tooltip data-bs-title="Fields define the resulting attributes of your transformed record">
            <h5>Custom Fields</h5>
          </Tooltip>

          <div className="btn-group card__control">
            <i
              className="bi bi-three-dots-vertical"
              data-bs-toggle="dropdown"
            ></i>
            <ul className="dropdown-menu dropdown-menu-end">
              <li
                className="dropdown-item card__control-acton"
                onClick={() => {
                  dispatch(
                    toggleDisplayFields({ fields: fields, displayed: false })
                  );
                }}
              >
                <i className="bi bi-eye-slash me-2"></i> Hide all fields
              </li>

              <li
                className="dropdown-item card__control-acton"
                onClick={() => {
                  dispatch(
                    toggleDisplayFields({ fields: fields, displayed: true })
                  );
                }}
              >
                <i className="bi bi-eye me-2"></i> Show all fields
              </li>
            </ul>
          </div>
        </div>

        <div className="field-nav-panel__content">
          <AddField kind="field" />

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">
            {customFields.map((field) => {
              return <FieldNavigationListItem id={field.id} key={field.id} />;
            })}
          </ul>
        </div>
      </div>

      <Modal show={showModal} onHide={handleClose}>
        <Modal.Header closeButton>
          <Modal.Title>Load schema</Modal.Title>
        </Modal.Header>
        <Modal.Body>

          <select
            className="form-select"
            defaultValue={schemaValue}
            onChange={(e) => setSchemaValue(e.target.value)}
          >
            <option value="">
              Please select a schema to load fields from...
            </option>
            {map(allSchemas, (schema) => {
              return (
                <option value={schema.id} key={schema.id}>
                  {schema.name}
                </option>
              );
            })}
          </select>

          {schemaValue && map(find(allSchemas, (schema) => { return schema.id == schemaValue }).fields, (field) => {
            return (

              <div className="form-check" key={field.id}>
                <input className="form-check-input" type="checkbox" value={field.id} id={field.id} onChange={() => { updateFieldValues(field.id) }} />
                <label className="form-check-label" htmlFor={field.id}>
                  {field.name} ({field.kind})
                </label>
              </div>
            )
          })}

        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={handleClose}>
            Close
          </Button>

        </Modal.Footer>
      </Modal>

    </div>
  );
};

export default FieldNavigationPanel;
