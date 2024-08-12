import {
  createAsyncThunk,
  createSlice,
  createEntityAdapter,
} from "@reduxjs/toolkit";
import { request } from "~/js/utils/request";

const SchemasSlice = createSlice({
  name: "schemas",
  initialState: {},
  reducers: {},
  extraReducers: (builder) => {},
});

const schemasAdapter = createEntityAdapter();

export const {
  selectById: selectSchemaById,
  selectIds: selectSchemaIds,
  selectAll: selectAllSchemas,
} = schemasAdapter.getSelectors((state) => state.entities.schemas);

const { actions, reducer } = SchemasSlice;

export default reducer;
