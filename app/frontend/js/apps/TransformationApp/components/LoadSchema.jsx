import React, { useState } from "react";
import { useSelector, useDispatch } from "react-redux";
import { addField } from "~/js/features/TransformationApp/FieldsSlice";
import { find, filter, map, includes, each } from "lodash";

import { selectAppDetails } from "~/js/features/TransformationApp/AppDetailsSlice";
import { selectAllSchemas } from "~/js/features/TransformationApp/SchemasSlice";
import { selectAllSchemaFields } from "~/js/features/SchemaApp/SchemaFieldsSlice";
import Modal from "react-bootstrap/Modal";

const LoadSchema = () => {
  const dispatch = useDispatch();
  const allSchemas = useSelector(selectAllSchemas);
  const appDetails = useSelector(selectAppDetails);

  const allSchemaFields = useSelector(selectAllSchemaFields);

  const [showModal, setShowModal] = useState(false);

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const [schemaValue, setSchemaValue] = useState('');
  const [schemaFieldIds, setSchemaFieldIds] = useState([]);

  const schemaFields = () => {
    const activeSchema = find(allSchemas, (schema) => { return schema.id == schemaValue });

    const fields = filter(allSchemaFields, (field) => {
      return includes(activeSchema.schema_field_ids, field.id)
    })

    return fields;
  }

  const updateSchemaFieldIds = (id) => {
    if (includes(schemaFieldIds, id)) {
      const filteredValues = filter(schemaFieldIds, (value) => {
        return value != id;
      });
      setSchemaFieldIds(
        filteredValues
      )
    } else {
      setSchemaFieldIds(
        [
          ...schemaFieldIds,
          id
        ]
      )
    }
  }

  const handleLoadFieldsClick = () => {
    each(schemaFieldIds, (schemaFieldId) => {
      dispatch(
        addField({
          name: "",
          block: "",
          kind: 'field',
          harvestDefinitionId: appDetails.harvestDefinition.id,
          pipelineId: appDetails.pipeline.id,
          transformationDefinitionId: appDetails.transformationDefinition.id,
          schemaFieldId: schemaFieldId
        })
      );
    })

    setSchemaFieldIds([]);
    handleClose();
  }

  return (
    <>
      <div className="d-grid gap-2">
        <button
          className="btn btn-outline-primary"
          onClick={() => { handleShow() }}
        >
          <i className="bi bi-download me-2"></i>
          Load schema
        </button>
      </div>

      <Modal show={showModal} onHide={handleClose}>
        <Modal.Header closeButton>
          <Modal.Title>Load schema</Modal.Title>
        </Modal.Header>
        <Modal.Body>

          <select
            className="form-select mb-3"
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

          {schemaValue && map(schemaFields(), (field) => {
            return (

              <div className="form-check" key={field.id}>
                <input className="form-check-input" type="checkbox" value={field.id} id={field.id} onChange={() => { updateSchemaFieldIds(field.id) }} />
                <label className="form-check-label" htmlFor={field.id}>
                  {field.name} ({field.kind})
                </label>
              </div>
            )
          })}

          {schemaValue && (
            <div className="d-grid gap-2 mt-3">
              <button className="btn btn-primary" type="button" onClick={() => handleLoadFieldsClick()}>
                <i className="bi bi-download me-2"></i>
                Load selected fields
              </button>
            </div>
          )}

        </Modal.Body>
      </Modal>
    </>

  );
};

export default LoadSchema;
