import { some } from "lodash";

import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

// export const updateField = createAsyncThunk(
//   "fields/updateFieldStatus",
//   async (payload) => {
//     const {
//       id,
//       pipelineId,
//       harvestDefinitionId,
//       transformationDefinitionId,
//       name,
//       block,
//       kind,
//       schemaFieldId,
//       schemaFieldValueIds
//     } = payload;

//     console.log(schemaFieldValueIds);

//     const response = request
//       .patch(
//         `/pipelines/${pipelineId}/harvest_definitions/${harvestDefinitionId}/transformation_definitions/${transformationDefinitionId}/fields/${id}`,
//         {
//           field: {
//             name: name,
//             block: block,
//             kind: kind,
//             schema_field_id: schemaFieldId,
//             schema_field_value_ids: schemaFieldValueIds
//           },
//         }
//       )
//       .then((response) => {
//         return response.data;
//       });

//     return response;
//   }
// );

const fieldSchemaFieldValuesAdapter = createEntityAdapter();

const fieldSchemaFieldValuesSlice = createSlice({
  name: "fieldSchemaFieldValuesSlice",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {
    builder
    // .addCase(updateField.fulfilled, (state, action) => {
    //   fieldsAdapter.setOne(state, action.payload);
    // });
  },
});

const { actions, reducer } = fieldSchemaFieldValuesSlice;

export const {
  selectById: selectFieldSchemaFieldValueById,
  selectIds: selectFieldSchemaFieldValueIds,
  selectAll: selectAllFieldsSchemaFieldValues,
} = fieldSchemaFieldValuesAdapter.getSelectors((state) => state.entities.fieldSchemaFieldValues);

export const { } = actions;

export default reducer;
