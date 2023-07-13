import React from "react";
import { useDispatch, useSelector } from "react-redux";
import { addField, hasEmptyFields } from "~/js/features/FieldsSlice";
import { selectAppDetails } from "~/js/features/AppDetailsSlice";

const AddField = () => {
  const dispatch = useDispatch();
  const appDetails = useSelector(selectAppDetails);
  const emptyFields = useSelector(hasEmptyFields);

  const addNewField = () => {
    dispatch(
      addField({
        name: "",
        block: "",
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        transformationDefinitionId: appDetails.transformationDefinition.id,
      })
    );
  };

  return (
    <button
      disabled={emptyFields}
      className="btn btn-primary mx-1"
      onClick={() => addNewField()}
    >
      Add Field
    </button>
  );
};

export default AddField;
