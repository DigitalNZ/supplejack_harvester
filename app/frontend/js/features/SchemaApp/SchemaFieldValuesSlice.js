import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

export const addSchemaFieldValue = createAsyncThunk(
  "fields/addSchemaFieldValueStatus",
  async (payload) => {
    const { value, schemaId, schemaFieldId } = payload;

    const response = request
      .post(
        `/schemas/${schemaId}/schema_fields/${schemaFieldId}/schema_field_values`,
        {
          schema_field_value: {
            value: value,
            schema_field_id: schemaFieldId,
            schema_id: schemaId,
          },
        }
      )
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

export const deleteSchemaFieldValue = createAsyncThunk(
  "fields/deleteSchemaFieldValueStatus",
  async (payload) => {
    const { id, schemaId, schemaFieldId } = payload;

    const response = request
      .delete(
        `/schemas/${schemaId}/schema_fields/${schemaFieldId}/schema_field_values/${id}`
      )
      .then((response) => {
        return id;
      });

    return response;
  }
);

export const updateSchemaFieldValue = createAsyncThunk(
  "fields/updateSchemaFieldValueStatus",
  async (payload) => {
    const { id, value, schemaId, schemaFieldId } = payload;

    const response = request
      .patch(
        `/schemas/${schemaId}/schema_fields/${schemaFieldId}/schema_field_values/${id}`,
        {
          schema_field_value: {
            value: value,
            schema_field_id: schemaFieldId,
            schema_id: schemaId,
          },
        }
      )
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

const schemaFieldValuesAdapter = createEntityAdapter({
  sortComparer: (fieldOne, fieldTwo) =>
    fieldTwo.created_at.localeCompare(fieldOne.created_at),
});

const schemaFieldValuesSlice = createSlice({
  name: "schemaFieldValuesSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(addSchemaFieldValue.fulfilled, (state, action) => {
        schemaFieldValuesAdapter.upsertOne(state, action.payload);
      })
      .addCase(updateSchemaFieldValue.fulfilled, (state, action) => {
        schemaFieldValuesAdapter.setOne(state, action.payload);
      });
  },
});

const { actions, reducer } = schemaFieldValuesSlice;

export const {
  selectById: selectSchemaFieldValueById,
  selectIds: selectSchemaFieldValueIds,
  selectAll: selectAllSchemaFieldValues,
} = schemaFieldValuesAdapter.getSelectors(
  (state) => state.entities.schemaFieldValues
);

export const {} = actions;

export default reducer;
