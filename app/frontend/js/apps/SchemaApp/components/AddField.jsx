import React from "react";
import { useDispatch, useSelector } from "react-redux";
import {
  addSchemaField,
  hasEmptySchemaFields,
} from "~/js/features/SchemaApp/SchemaFieldsSlice";
import { selectAppDetails } from "~/js/features/SchemaApp/AppDetailsSlice";

const AddField = () => {
  const dispatch = useDispatch();
  const appDetails = useSelector(selectAppDetails);
  const emptyFields = useSelector(hasEmptySchemaFields);

  const addNewField = () => {
    dispatch(
      addSchemaField({
        name: "",
        schemaId: appDetails.schema.id
      })
    );
  };

  return (
    <div className="d-grid gap-2">
      <button
        disabled={emptyFields}
        className="btn btn-outline-primary"
        onClick={() => addNewField()}
      >
        + Add field
      </button>
    </div>
  );
};

export default AddField;
