import { createSlice, createEntityAdapter } from "@reduxjs/toolkit";

import { addParameter, updateParameter } from "./ParametersSlice";

const uiParametersAdapter = createEntityAdapter();

const uiParametersSlice = createSlice({
  name: "parametersSlice",
  initialState: {},
  reducers: {
    toggleDisplayParameter(state, action) {
      uiParametersAdapter.updateOne(state, {
        id: action.payload.id,
        changes: { displayed: action.payload.displayed },
      });
    },
    setActiveParameter(state, action) {
      uiParametersAdapter.updateMany(
        state,
        state.ids.map((id) => {
          return { id: id, changes: { active: false } };
        })
      );

      uiParametersAdapter.updateOne(state, {
        id: action.payload,
        changes: { active: true },
      });
    },
    toggleDisplayParameters(state, action) {
      const { parameters, displayed } = action.payload;

      uiParametersAdapter.updateMany(
        state,
        parameters.map((parameter) => {
          return { id: parameter.id, changes: { displayed: displayed } };
        })
      );
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(addParameter.fulfilled, (state, action) => {
        uiParametersAdapter.updateMany(
          state,
          state.ids.map((id) => {
            return { id: id, changes: { active: false } };
          })
        );

        uiParametersAdapter.upsertOne(state, {
          id: action.payload.id,
          saved: true,
          deleting: false,
          saving: false,
          expanded: true,
          displayed: true,
          active: true,
        });
      })
      .addCase(updateParameter.pending, (state, action) => {
        uiParametersAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { saving: true, hasRun: false, errors: [] },
        });
      })
      .addCase(updateParameter.fulfilled, (state, action) => {
        uiParametersAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { saving: false, errors: [] },
        });
      })
      // Without this the parameter saves forever: pending sets saving, and only
      // fulfilled used to clear it. The messages are what the model refused.
      .addCase(updateParameter.rejected, (state, action) => {
        uiParametersAdapter.updateOne(state, {
          id: action.meta.arg.id,
          changes: { saving: false, errors: action.payload },
        });
      });
  },
});

const { actions, reducer } = uiParametersSlice;

export const {
  selectById: selectUiParameterById,
  selectIds: selectUiParameterIds,
  selectAll: selectAllUiParameters,
} = uiParametersAdapter.getSelectors((state) => state.ui.parameters);

export const selectDisplayedParameterIds = (state) => {
  return selectAllUiParameters(state)
    .filter((parameter) => parameter.displayed)
    .map((parameter) => parameter.id);
};

export const {
  toggleDisplayParameter,
  toggleDisplayParameters,
  setActiveParameter,
} = actions;

export default reducer;
