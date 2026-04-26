import { Controller } from "@hotwired/stimulus"

// Connetti automaticamente: app/javascript/controllers/index.js
//   import ClassificheController from "./classifiche_controller"
//   application.register("classifiche", ClassificheController)
//
// Oppure rigenera il manifest:  bin/rails stimulus:manifest:update

export default class extends Controller {
  static targets = [
    "panel", "tab", "tabMobile", "materia",
    "search", "editoreFilter", "toggleHide",
    "classeRoman", "materieCount", "titoliCount"
  ]
  static values = {
    storageKey: { type: String, default: "capo:demoted" },
    hideKey:    { type: String, default: "capo:hideDemoted" },
    tabKey:     { type: String, default: "capo:activeTab" }
  }

  connect() {
    this.demoted    = this._loadDemoted()
    this.hideDemoted = this._loadHide()
    this.activeTab  = this._loadTab() || (this.panelTargets[0]?.dataset.classe ?? "1")

    this._applyTab()
    this._initLayout()
    this._updateToggleLabel()
    this._updateHeaderStats()
  }

  // ── Tab ─────────────────────────────────────────────────
  selectTab(e) {
    this.activeTab = e.currentTarget.dataset.tab
    this._saveTab(this.activeTab)
    this._applyTab()
    this._updateHeaderStats()
    this.filter()
  }

  _applyTab() {
    this.panelTargets.forEach(p => { p.hidden = p.dataset.classe !== this.activeTab })
    const setTab = (btn) => {
      const isActive = btn.dataset.tab === this.activeTab
      btn.setAttribute("aria-selected", isActive)
    }
    this.tabTargets.forEach(setTab)
    if (this.hasTabMobileTarget) this.tabMobileTargets.forEach(setTab)
  }

  // ── Demote / Promote ────────────────────────────────────
  _initLayout() {
    this.panelTargets.forEach(panel => {
      const classe = panel.dataset.classe
      panel.querySelectorAll("[data-materia-codice]").forEach(materia => {
        const key = `${classe}:${materia.dataset.materiaCodice}`
        const isDemoted = this.demoted.has(key)
        this._move(panel, materia, isDemoted)
        materia.open = !isDemoted
        materia.dataset.demoted = isDemoted
      })
      this._refreshZone(panel)
    })
  }

  // Bound via inline data-action="demote" / "promote" su <button>
  // (delegated through clickCapture)
  click(e) {} // placeholder; usa toggleRow via il button

  // Stimulus: catch dei bottoni interni alle materie
  // li gestiamo con un listener delegato sui targets materia
  materiaTargetConnected(materia) {
    materia.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-action='demote'], [data-action='promote']")
      if (!btn) return
      e.preventDefault()
      e.stopPropagation()
      const panel = materia.closest("[data-classe-section]")
      const key = `${panel.dataset.classe}:${materia.dataset.materiaCodice}`
      const isDemoting = btn.dataset.action === "demote"
      isDemoting ? this.demoted.add(key) : this.demoted.delete(key)
      this._saveDemoted()
      this._move(panel, materia, isDemoting)
      materia.open = !isDemoting
      materia.dataset.demoted = isDemoting
      this._refreshZone(panel)
      this._updateHeaderStats()
    })
  }

  _move(panel, materia, isDemoted) {
    const target = panel.querySelector(isDemoted ? '[data-zone="demoted"]' : '[data-zone="primary"]')
    if (materia.parentNode !== target) target.appendChild(materia)
    const down = materia.querySelector("[data-action='demote']")
    const up   = materia.querySelector("[data-action='promote']")
    if (down) down.hidden = isDemoted
    if (up)   up.hidden   = !isDemoted
  }

  _refreshZone(panel) {
    const demotedZone = panel.querySelector('[data-zone="demoted"]')
    const divider = panel.querySelector("[data-divider]")
    const hasDemoted = demotedZone.children.length > 0
    divider.hidden    = !hasDemoted || this.hideDemoted
    demotedZone.hidden = !hasDemoted || this.hideDemoted
  }

  toggleDemoted() {
    this.hideDemoted = !this.hideDemoted
    this._saveHide(this.hideDemoted)
    this._updateToggleLabel()
    this.panelTargets.forEach(p => this._refreshZone(p))
  }

  _updateToggleLabel() {
    if (!this.hasToggleHideTarget) return
    this.toggleHideTarget.textContent = this.hideDemoted ? "Mostra 👎" : "Nascondi 👎"
  }

  // ── Filtri ──────────────────────────────────────────────
  filter() {
    const q  = (this.hasSearchTarget ? this.searchTarget.value : "").trim().toLowerCase()
    const ed = this.hasEditoreFilterTarget ? this.editoreFilterTarget.value : "all"
    const panel = this.panelTargets.find(p => p.dataset.classe === this.activeTab)
    if (!panel) return

    panel.querySelectorAll("[data-materia-codice]").forEach(materia => {
      let visibleCount = 0
      materia.querySelectorAll("[data-row]").forEach(row => {
        const matchesEd = (ed === "all") || row.dataset.editore === ed
        const matchesQ  = !q ||
          row.dataset.titolo.includes(q) ||
          row.dataset.autore.includes(q) ||
          row.dataset.isbn.includes(q)
        const showByFilters = matchesEd && matchesQ
        const showAll = materia.dataset.showAll === "true"
        const isExtra = row.dataset.extra === "true"
        const visible = showByFilters && (showAll || !isExtra || q || ed !== "all")
        row.hidden = !visible
        if (visible) visibleCount++
      })
      // nascondi materia se 0 risultati con filtri attivi
      const hasFilter = q || ed !== "all"
      materia.hidden = hasFilter && visibleCount === 0
    })
  }

  showAll(e) {
    const materia = e.currentTarget.closest("[data-materia-codice]")
    materia.dataset.showAll = "true"
    materia.querySelectorAll("[data-row][data-extra='true']").forEach(r => r.hidden = false)
    e.currentTarget.parentElement.hidden = true
  }

  // ── Stats header ────────────────────────────────────────
  _updateHeaderStats() {
    const panel = this.panelTargets.find(p => p.dataset.classe === this.activeTab)
    if (!panel) return
    if (this.hasClasseRomanTarget) this.classeRomanTarget.textContent = panel.dataset.roman
    if (this.hasMaterieCountTarget) {
      const n = panel.querySelectorAll('[data-zone="primary"] [data-materia-codice]').length
      this.materieCountTarget.textContent = n
    }
    if (this.hasTitoliCountTarget) {
      const n = panel.querySelectorAll('[data-zone="primary"] [data-row]').length
      this.titoliCountTarget.textContent = n
    }
  }

  // ── Persistence ─────────────────────────────────────────
  _loadDemoted() {
    try {
      const raw = localStorage.getItem(this.storageKeyValue)
      const arr = raw ? JSON.parse(raw) : []
      return new Set(Array.isArray(arr) ? arr : [])
    } catch { return new Set() }
  }
  _saveDemoted() {
    try { localStorage.setItem(this.storageKeyValue, JSON.stringify([...this.demoted])) } catch {}
  }
  _loadHide() { try { return localStorage.getItem(this.hideKeyValue) === "true" } catch { return false } }
  _saveHide(v) { try { localStorage.setItem(this.hideKeyValue, v ? "true" : "false") } catch {} }
  _loadTab()  { try { return localStorage.getItem(this.tabKeyValue) } catch { return null } }
  _saveTab(v) { try { localStorage.setItem(this.tabKeyValue, v) } catch {} }
}
