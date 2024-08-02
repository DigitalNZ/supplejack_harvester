import { createSlice, createEntityAdapter } from "@reduxjs/toolkit";

import { addField, deleteField, updateField } from "./FieldsSlice";

const uiFieldsAdapter = createEntityAdapter();

const uiFieldsSlice = createSlice({
  name: "fieldsSlice",
  initialState: {},
  reducers: {
    toggleDisplayField(state, action) {
      uiFieldsAdapter.updateOne(state, {
        id: action.payload.id,
        changes: { displayed: action.payload.displayed },
      });
    },
    setActiveField(state, action) {
      uiFieldsAdapter.updateMany(
        state,
        state.ids.map((id) => {
          return { id: id, changes: { active: false } };
        })
      );

      uiFieldsAdapter.updateOne(state, {
        id: action.payload,
        changes: { active: true },
      });
    },
    toggleDisplayFields(state, action) {
      const { fields, displayed } = action.payload;

      uiFieldsAdapter.updateMany(
        state,
        fields.map((field) => {
          return { id: field.id, changes: { displayed: displayed } };
        })
      );
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(addField.fulfilled, (state, action) => {
        uiFieldsAdapter.updateMany(
          state,
          state.ids.map((id) => {
            return { id: id, changes: { active: false } };
          })
        );

        uiFieldsAdapter.upsertOne(state, {
          id: action.payload.id,
          saved: true,
          deleting: false,
          saving: false,
          expanded: true,
          displayed: true,
          active: true,
        });
      })

      .addCase(updateField.pending, (state, action) => {
        uiFieldsAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { saving: true },
        });
      })
      .addCase(updateField.fulfilled, (state, action) => {
        uiFieldsAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { saving: false },
        });
      })
      .addCase(deleteField.pending, (state, action) => {
        uiFieldsAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { deleting: true },
        });
      });
  },
});

const { actions, reducer } = uiFieldsSlice;

export const {
  selectById: selectUiFieldById,
  selectIds: selectUiFieldIds,
  selectAll: selectAllUiFields,
} = uiFieldsAdapter.getSelectors((state) => state.ui.fields);

export const selectDisplayedFieldIds = (state) => {
  return selectAllUiFields(state)
    .filter((field) => field.displayed)
    .map((field) => field.id);
};

export const { toggleDisplayField, toggleDisplayFields, setActiveField } =
  actions;

export default reducer;
