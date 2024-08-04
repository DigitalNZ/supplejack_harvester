import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

export const addFieldValue = createAsyncThunk(
  "fields/addFieldValueStatus",
  async (payload) => {
    const {
      value,
      schemaId,
      schemaFieldId
    } = payload;

    const response = request
      .post(
        `/schemas/${schemaId}/schema_fields/${schemaFieldId}/schema_field_values`,
        {
          schema_field_value: {
            value: value,
            schema_field_id: schemaFieldId,
            schema_id: schemaId
          },
        }
      )
      .then(function (response) {
        return response.data;
      });

    return response;
  }
);

export const deleteFieldValue = createAsyncThunk(
  "fields/deleteFieldValueStatus",
  async (payload) => {

    const {
      id,
      schemaId,
      schemaFieldId
    } = payload;

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

// export const updateField = createAsyncThunk(
//   "fields/updateFieldStatus",
//   async (payload) => {
//     const {
//       id,
//       schemaId,
//       name,
//       kind,
//     } = payload;

//     const response = request
//       .patch(
//         `/schemas/${schemaId}/schema_fields/${id}`,
//         {
//           schema_field: {
//             name: name,
//             kind: kind,
//           },
//         }
//       )
//       .then((response) => {
//         return response.data;
//       });

//     return response;
//   }
// );

const fieldValuesAdapter = createEntityAdapter({
  sortComparer: (fieldOne, fieldTwo) =>
    fieldTwo.created_at.localeCompare(fieldOne.created_at),
});

const fieldValuesSlice = createSlice({
  name: "fieldValuesSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(addFieldValue.fulfilled, (state, action) => {
        fieldValuesAdapter.upsertOne(state, action.payload);
      })
    // .addCase(deleteField.fulfilled, (state, action) => {
    //   fieldsAdapter.removeOne(state, action.payload);
    // })
    // .addCase(updateField.fulfilled, (state, action) => {
    //   fieldsAdapter.setOne(state, action.payload);
    // });
  },
});

const { actions, reducer } = fieldValuesSlice;

export const {
  selectById: selectFieldValueById,
  selectIds: selectFieldValueIds,
  selectAll: selectAllFieldValues,
} = fieldValuesAdapter.getSelectors((state) => state.entities.fieldValues);

export const { } = actions;

export default reducer;
