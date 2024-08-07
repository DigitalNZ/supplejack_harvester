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
import fieldSchemaFieldValues from "/js/features/TransformationApp/FieldSchemaFieldValuesSlice";

import schemaFields from '/js/features/SchemaApp/SchemaFieldsSlice';
import schemaFieldValues from '/js/features/SchemaApp/SchemaFieldValuesSlice';

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
        schemaFields,
        schemaFieldValues,
        fieldSchemaFieldValues
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
