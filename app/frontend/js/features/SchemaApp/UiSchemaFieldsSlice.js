import { createSlice, createEntityAdapter } from "@reduxjs/toolkit";

import { addSchemaField, deleteSchemaField, updateSchemaField } from "./SchemaFieldsSlice";

const uiSchemaFieldsAdapter = createEntityAdapter();

const uiSchemaFieldsSlice = createSlice({
  name: "schemaFieldsSlice",
  initialState: {},
  reducers: {
    toggleDisplaySchemaField(state, action) {
      uiSchemaFieldsAdapter.updateOne(state, {
        id: action.payload.id,
        changes: { displayed: action.payload.displayed },
      });
    },
    setActiveSchemaField(state, action) {
      uiSchemaFieldsAdapter.updateMany(
        state,
        state.ids.map((id) => {
          return { id: id, changes: { active: false } };
        })
      );

      uiSchemaFieldsAdapter.updateOne(state, {
        id: action.payload,
        changes: { active: true },
      });
    },
    toggleDisplaySchemaFields(state, action) {
      const { fields, displayed } = action.payload;

      uiSchemaFieldsAdapter.updateMany(
        state,
        fields.map((field) => {
          return { id: field.id, changes: { displayed: displayed } };
        })
      );
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(addSchemaField.fulfilled, (state, action) => {
        uiSchemaFieldsAdapter.updateMany(
          state,
          state.ids.map((id) => {
            return { id: id, changes: { active: false } };
          })
        );

        uiSchemaFieldsAdapter.upsertOne(state, {
          id: action.payload.id,
          saved: true,
          deleting: false,
          saving: false,
          expanded: true,
          displayed: true,
          active: true,
        });
      })

      .addCase(updateSchemaField.pending, (state, action) => {
        uiSchemaFieldsAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { saving: true },
        });
      })
      .addCase(updateSchemaField.fulfilled, (state, action) => {
        uiSchemaFieldsAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { saving: false },
        });
      })
      .addCase(deleteSchemaField.pending, (state, action) => {
        uiSchemaFieldsAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { deleting: true },
        });
      });
  },
});

const { actions, reducer } = uiSchemaFieldsSlice;

export const {
  selectById: selectUiSchemaFieldById,
  selectIds: selectUiSchemaFieldIds,
  selectAll: selectAllUiSchemaFields,
} = uiSchemaFieldsAdapter.getSelectors((state) => state.ui.schemaFields);

export const selectDisplayedSchemaFieldIds = (state) => {
  return selectAllUiSchemaFields(state)
    .filter((field) => field.displayed)
    .map((field) => field.id);
};

export const { toggleDisplaySchemaField, toggleDisplaySchemaFields, setActiveSchemaField } =
  actions;

export default reducer;
