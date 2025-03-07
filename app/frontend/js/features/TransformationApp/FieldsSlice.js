import { some } from "lodash";

import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

import {
  addFieldSchemaFieldValue,
  deleteFieldSchemaFieldValue,
} from "~/js/features/TransformationApp/FieldSchemaFieldValuesSlice";

import { filter } from "lodash";

export const addField = createAsyncThunk(
  "fields/addFieldStatus",
  async (payload) => {
    const {
      name,
      block,
      kind,
      pipelineId,
      harvestDefinitionId,
      transformationDefinitionId,
      schemaFieldId,
    } = payload;

    const response = request
      .post(
        `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/transformation_definitions/${transformationDefinitionId}/fields`,
        {
          field: {
            transformation_definition_id: transformationDefinitionId,
            name: name,
            kind: kind,
            block: block,
            schema_field_id: schemaFieldId,
          },
        }
      )
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

export const deleteField = createAsyncThunk(
  "fields/deleteFieldStatus",
  async (payload) => {
    const { id, pipelineId, harvestDefinitionId, transformationDefinitionId } =
      payload;

    const response = request
      .delete(
        `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/transformation_definitions/${transformationDefinitionId}/fields/${id}`
      )
      .then((response) => {
        return id;
      });

    return response;
  }
);

export const updateField = createAsyncThunk(
  "fields/updateFieldStatus",
  async (payload) => {
    const {
      id,
      pipelineId,
      harvestDefinitionId,
      transformationDefinitionId,
      name,
      block,
      kind,
      schemaFieldId,
    } = payload;

    const response = request
      .patch(
        `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/transformation_definitions/${transformationDefinitionId}/fields/${id}`,
        {
          field: {
            name: name,
            block: block,
            kind: kind,
            schema_field_id: schemaFieldId,
          },
        }
      )
      .then((response) => {
        return response.data;
      });

    return response;
  }
);

export const hasEmptyFields = (state) => {
  return some(selectAllFields(state), { name: "" });
};

const fieldsAdapter = createEntityAdapter({
  sortComparer: (fieldOne, fieldTwo) =>
    fieldTwo.created_at.localeCompare(fieldOne.created_at),
});

const fieldsSlice = createSlice({
  name: "fieldsSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(addField.fulfilled, (state, action) => {
        fieldsAdapter.upsertOne(state, action.payload);
      })
      .addCase(addFieldSchemaFieldValue.fulfilled, (state, action) => {
        state.entities[
          action.payload.field_id
        ].field_schema_field_value_ids.push(action.payload.id);
      })
      .addCase(deleteFieldSchemaFieldValue.fulfilled, (state, action) => {
        const ids = filter(
          state.entities[action.payload.fieldId].field_schema_field_value_ids,
          (fieldId) => {
            return fieldId != action.payload.id;
          }
        );

        state.entities[action.payload.fieldId].field_schema_field_value_ids =
          ids;
      })
      .addCase(deleteField.fulfilled, (state, action) => {
        fieldsAdapter.removeOne(state, action.payload);
      })
      .addCase(updateField.fulfilled, (state, action) => {
        fieldsAdapter.setOne(state, action.payload);
      });
  },
});

const { actions, reducer } = fieldsSlice;

export const {
  selectById: selectFieldById,
  selectIds: selectFieldIds,
  selectAll: selectAllFields,
} = fieldsAdapter.getSelectors((state) => state.entities.fields);

export const {} = actions;

export default reducer;
