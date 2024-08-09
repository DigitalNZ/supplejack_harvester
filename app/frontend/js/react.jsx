// Use this file for importing React apps

import React from "react";
import ReactDOM from "react-dom/client";

import TransformationApp from "/js/apps/TransformationApp/TransformationApp";

import { Provider } from "react-redux";
import configureAppStore from "/js/apps/TransformationApp/store";

import ErrorBoundary from "./components/ErrorBoundary";

const transformationAppHTMLElement = document.querySelector(
  "#js-transformation-app"
);

if (transformationAppHTMLElement !== null) {
  const root = ReactDOM.createRoot(transformationAppHTMLElement);
  const props = JSON.parse(transformationAppHTMLElement.dataset.props);

  if (props.entities.rawRecord.body != null) {
    root.render(
      <React.StrictMode>
        <ErrorBoundary environment={props.config.environment}>
          <Provider store={configureAppStore(props)}>
            <TransformationApp />
          </Provider>
        </ErrorBoundary>
      </React.StrictMode>
    );
  } else {
    root.render(
      <p className="text-danger">
        Something went wrong when attempting to display this Transformation.
        This could mean that the provided record selector doesn't return
        anything or if the document is over 10 megabytes you will need to split
        it before it can be used in a Transformation.
      </p>
    );
  }
}

// Extraction App

import ExtractionApp from "/js/apps/ExtractionApp/ExtractionApp";
import configureExtractionAppStore from "/js/apps/ExtractionApp/store";

const extractionAppHTMLElement = document.querySelector("#js-extraction-app");

if (extractionAppHTMLElement !== null) {
  const root = ReactDOM.createRoot(extractionAppHTMLElement);
  const props = JSON.parse(extractionAppHTMLElement.dataset.props);

  root.render(
    <React.StrictMode>
      <ErrorBoundary environment={props.config.environment}>
        <Provider store={configureExtractionAppStore(props)}>
          <ExtractionApp />
        </Provider>
      </ErrorBoundary>
    </React.StrictMode>
  );
}

// Schema App

import SchemaApp from "/js/apps/SchemaApp/SchemaApp";
import configureSchemaAppStore from "/js/apps/SchemaApp/store";

const schemaAppHTMLElement = document.querySelector("#js-schema-app");

if (schemaAppHTMLElement !== null) {
  const root = ReactDOM.createRoot(schemaAppHTMLElement);
  const props = JSON.parse(schemaAppHTMLElement.dataset.props);

  root.render(
    <React.StrictMode>
      <ErrorBoundary environment={props.config.environment}>
        <Provider store={configureSchemaAppStore(props)}>
          <SchemaApp />
        </Provider>
      </ErrorBoundary>
    </React.StrictMode>
  );
}
