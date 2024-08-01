import React from "react";
import { useDispatch, useSelector } from "react-redux";
import {
  addField,
  hasEmptyFields,
} from "~/js/features/SchemaApp/FieldsSlice";
import { selectAppDetails } from "~/js/features/SchemaApp/AppDetailsSlice";

const AddField = () => {
  const dispatch = useDispatch();
  const appDetails = useSelector(selectAppDetails);
  const emptyFields = useSelector(hasEmptyFields);

  const addNewField = () => {
    dispatch(
      addField({
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
