import { createSlice } from "@reduxjs/toolkit";

const AppDetailsSlice = createSlice({
  name: "appDetails",
  initialState: {
    stopConditionsTabActive: false,
  },
  reducers: {},
});

export const selectAppDetails = (state) => state.entities.appDetails;

const { reducer } = AppDetailsSlice;

export default reducer;
