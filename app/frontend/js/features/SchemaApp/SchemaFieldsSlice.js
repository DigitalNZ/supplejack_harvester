import { some, filter } from "lodash";

import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

import {
  addSchemaFieldValue,
  deleteSchemaFieldValue,
} from "~/js/features/SchemaApp/SchemaFieldValuesSlice";

export const addSchemaField = createAsyncThunk(
  "fields/addSchemaFieldStatus",
  async (payload) => {
    const { name, schemaId } = payload;

    const response = request
      .post(`/schemas/${schemaId}/schema_fields`, {
        schema_field: {
          name: name,
          schema_id: schemaId,
        },
      })
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

export const deleteSchemaField = createAsyncThunk(
  "fields/deleteSchemaFieldStatus",
  async (payload) => {
    const { id, schemaId } = payload;

    const response = request
      .delete(`/schemas/${schemaId}/schema_fields/${id}`)
      .then((response) => {
        return id;
      });

    return response;
  }
);

export const updateSchemaField = createAsyncThunk(
  "fields/updateSchemaFieldStatus",
  async (payload) => {
    const { id, schemaId, name, kind } = payload;

    const response = request
      .patch(`/schemas/${schemaId}/schema_fields/${id}`, {
        schema_field: {
          name: name,
          kind: kind,
        },
      })
      .then((response) => {
        return response.data;
      });

    return response;
  }
);

export const hasEmptySchemaFields = (state) => {
  return some(selectAllSchemaFields(state), { name: "" });
};

const schemaFieldsAdapter = createEntityAdapter();

const schemaFieldsSlice = createSlice({
  name: "schemaFieldsSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(addSchemaField.fulfilled, (state, action) => {
        schemaFieldsAdapter.upsertOne(state, action.payload);
      })
      .addCase(deleteSchemaField.fulfilled, (state, action) => {
        schemaFieldsAdapter.removeOne(state, action.payload);
      })
      .addCase(updateSchemaField.fulfilled, (state, action) => {
        schemaFieldsAdapter.setOne(state, action.payload);
      })
      .addCase(addSchemaFieldValue.fulfilled, (state, action) => {
        state.entities[
          action.payload.schema_field_id
        ].schema_field_value_ids.push(action.payload.id);
      })
      .addCase(deleteSchemaFieldValue.fulfilled, (state, action) => {
        const ids = filter(
          state.entities[action.meta.arg.schemaFieldId].schema_field_value_ids,
          (fieldId) => {
            return fieldId != action.payload;
          }
        );

        state.entities[action.meta.arg.schemaFieldId].schema_field_value_ids =
          ids;
      });
  },
});

const { actions, reducer } = schemaFieldsSlice;

export const {
  selectById: selectSchemaFieldById,
  selectIds: selectSchemaFieldIds,
  selectAll: selectAllSchemaFields,
} = schemaFieldsAdapter.getSelectors((state) => state.entities.schemaFields);

export const {} = actions;

export default reducer;
