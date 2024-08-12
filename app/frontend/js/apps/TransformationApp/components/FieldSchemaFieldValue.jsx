import React from "react";
import { useSelector, useDispatch } from "react-redux";

import { map } from "lodash";

import {
  selectFieldSchemaFieldValueById,
  updateFieldSchemaFieldValue,
  deleteFieldSchemaFieldValue,
} from "~/js/features/TransformationApp/FieldSchemaFieldValuesSlice";

const FieldSchemaFieldValue = ({ id, schemaFieldValues, fieldId }) => {
  const fieldSchemaFieldValue = useSelector((state) =>
    selectFieldSchemaFieldValueById(state, id)
  );

  const dispatch = useDispatch();

  const handleRemoveFieldSchemaFieldValueClick = () => {
    dispatch(
      deleteFieldSchemaFieldValue({
        id: id,
        fieldId: fieldId,
      })
    );
  };

  const handleFieldSchemaFieldValueChange = (value) => {
    dispatch(
      updateFieldSchemaFieldValue({
        id: id,
        schemaFieldValueId: value,
      })
    );
  };

  return (
    <>
      <div className="row my-2">
        <div className="col-12">
          <div className="row">
            <label className="col-form-label col-sm-2" htmlFor="name">
              <strong>Fixed value </strong>
            </label>

            <div className="col-sm-4">
              <select
                className="form-select"
                aria-label="Condition type"
                defaultValue={fieldSchemaFieldValue.schema_field_value_id}
                onChange={(e) => {
                  handleFieldSchemaFieldValueChange(e.target.value);
                }}
              >
                {map(schemaFieldValues, (value) => {
                  return (
                    <option key={value.id} value={value.id}>
                      {value.value}
                    </option>
                  );
                })}
              </select>
            </div>

            <div className="col-sm-4">
              <p
                className="text-danger"
                onClick={() => {
                  handleRemoveFieldSchemaFieldValueClick();
                }}
              >
                Remove
              </p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default FieldSchemaFieldValue;
