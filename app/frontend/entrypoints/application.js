// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.l
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
console.log("Vite ⚡️ Rails");

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

console.log(
  "Visit the guide for more information: ",
  "https://vite-ruby.netlify.app/guide/rails"
);

// Example: Load Rails libraries in Vite.
//
// import * as Turbo from '@hotwired/turbo'
// Turbo.start()
//
// import ActiveStorage from '@rails/activestorage'
// ActiveStorage.start()
//
// // Import all channels.
// const channels = import.meta.globEager('./**/*_channel.js')

// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'

import * as bootstrap from "bootstrap";
import "/js/ClearField";
import "/js/TestDestination";
import "/js/Tooltips";
import "/js/Toasts";
import "/js/CollapseScroll";
import "/js/modals/displayErroringModal";
import "/js/modals/transformationDefinitionSettingsModal";
import "/js/modals/harvestExtractionDefinitionModal";
import "/js/modals/enrichmentExtractionDefinitionModal";
import "/js/SubmittingSelect";
import "/js/AutoComplete";
import "/js/editor";
import "/js/form-header-submission";
import "/js/pipeline";
import "/js/schedules";
import "/js/inlineEditable";
import "/js/react";
