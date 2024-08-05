import { combineReducers, configureStore } from "@reduxjs/toolkit";
import {
  displayedFieldsListener,
  loadDisplayedFields,
} from "../../displayedFieldsListener";

// entities
import fields from "/js/features/TransformationApp/FieldsSlice";
import rawRecord from "/js/features/TransformationApp/RawRecordSlice";
import appDetails from "/js/features/TransformationApp/AppDetailsSlice";
import schemas from "/js/features/TransformationApp/SchemasSlice";

// shared slice?

// import schemaFields from '/js/features/SchemaApp/FieldsSlice';

// ui
import uiFields from "/js/features/TransformationApp/UiFieldsSlice";
import uiAppDetails from "/js/features/TransformationApp/UiAppDetailsSlice";

// config
import config from "/js/features/ConfigSlice";
import sharedDefinitions from "/js/features/SharedDefinitionsSlice";

export default function configureAppStore(preloadedState) {
  loadDisplayedFields(preloadedState);

  const store = configureStore({
    reducer: combineReducers({
      entities: combineReducers({
        fields,
        rawRecord,
        appDetails,
        sharedDefinitions,
        schemas,
      }),
      ui: combineReducers({
        fields: uiFields,
        appDetails: uiAppDetails,
      }),
      config,
    }),
    middleware: (getDefaultMiddleware) =>
      getDefaultMiddleware().concat(displayedFieldsListener.middleware),
    preloadedState,
  });

  return store;
}
