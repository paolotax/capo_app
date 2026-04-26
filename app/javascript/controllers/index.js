// Eager-load tutti i controllers via importmap.
// Aggiungi/rimuovi controller in app/javascript/controllers/ — vengono
// registrati automaticamente in base all'importmap.

import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
