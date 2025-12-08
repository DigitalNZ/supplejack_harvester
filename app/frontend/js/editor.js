import { EditorState } from "@codemirror/state";
import { EditorView, basicSetup } from "codemirror";
import { json } from "@codemirror/lang-json";
import xmlFormat from "xml-formatter";

import { StreamLanguage } from "@codemirror/language";
import { ruby } from "@codemirror/legacy-modes/mode/ruby";
import { xml } from "@codemirror/legacy-modes/mode/xml";

export function editorExtensions(format, readOnly, formField) {
  if (format == "JSON" || format == "ARCHIVE_JSON") {
    return [basicSetup, json(), EditorState.readOnly.of(readOnly)];
  } else if (format == "XML" || format == "HTML") {
    return [
      basicSetup,
      StreamLanguage.define(xml),
      EditorState.readOnly.of(readOnly),
    ];
  } else if (format == "FormField") {
    return [
      basicSetup,
      StreamLanguage.define(ruby),
      EditorView.updateListener.of(function (e) {
        formField.value = e.state.doc.toString();
      }),
    ];
  }
}

export default function editor(editorID, format, readOnly, results, formField) {
  const editorHTMLElement = document.querySelector(editorID);

  let editor = new EditorView({
    state: EditorState.create({
      extensions: editorExtensions(format, readOnly, formField),
      doc: results,
    }),
    parent: document.body,
  });

  document.querySelector(editorID).innerHTML = "";
  document.querySelector(editorID).append(editor.dom);
}

// Job Extraction Result Viewer

const extractionResultViewer = document.querySelector(
  "#extraction-result-viewer"
);

if (extractionResultViewer) {
  const format = extractionResultViewer.dataset.format;
  let results = extractionResultViewer.dataset.results;

  if (format == "JSON" || format == "ARCHIVE_JSON") {
    results = JSON.stringify(JSON.parse(results), null, 2);
  } else if (format == "XML") {
    results = xmlFormat(results, { indentation: "  ", lineSeparator: "\n" });
  }

  editor("#extraction-result-viewer", format, true, results);
}

// Extraction Initial Params Editor

const initialParamsField = document.querySelector("#js-initial-params");

if (initialParamsField) {
  editor(
    "#js-initial-params-editor",
    "FormField",
    true,
    initialParamsField.value,
    initialParamsField
  );
}

// Enrichment URL Editor
const enrichmentField = document.querySelector("#js-enrichment-url");

if (enrichmentField) {
  editor(
    "#js-enrichment-editor",
    "FormField",
    true,
    enrichmentField.value,
    enrichmentField
  );
}
