/* Deeds Office Register — client (no external dependencies) */
(function () {
  "use strict";

  const app = document.getElementById("app");

  function qs(sel, el) { return (el || document).querySelector(sel); }
  function qsa(sel, el) { return Array.from((el || document).querySelectorAll(sel)); }

  async function api(path, opts) {
    const res = await fetch(path, Object.assign({
      headers: { "Accept": "application/json", "Content-Type": "application/json" }
    }, opts || {}));
    const text = await res.text();
    let data;
    try { data = text ? JSON.parse(text) : {}; }
    catch (e) { throw new Error("The server returned a non-JSON response."); }
    if (!res.ok && data && data.error) {
      const err = new Error(data.error);
      err.status = res.status;
      err.data = data;
      throw err;
    }
    return data;
  }

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;")
      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function route() {
    const hash = (location.hash || "#/").replace(/^#/, "");
    const parts = hash.split("/").filter(Boolean);
    return { parts, path: "/" + parts.join("/") };
  }

  function setNav() {
    const r = route();
    const top = r.parts[0] || "";
    qsa(".nav a").forEach(function (a) {
      const href = (a.getAttribute("href") || "#/").replace(/^#/, "");
      const key = href === "/" ? "" : href.replace(/^\//, "").split("/")[0];
      a.classList.toggle("active", key === top);
    });
  }

  function pillBonded(bonded) {
    return bonded
      ? '<span class="pill bonded">Bonded</span>'
      : '<span class="pill free">Unencumbered</span>';
  }

  function sevPill(sev) {
    return '<span class="pill sev-' + esc(sev) + '">' + esc(sev) + "</span>";
  }

  function findingsHtml(list) {
    if (!list || !list.length) {
      return '<p class="muted">No issues flagged by the rule-based advisor.</p>';
    }
    return list.map(function (f) {
      return '<article class="finding ' + esc(f.severity) + '">' +
        "<header>" + sevPill(f.severity) + " " +
        '<h3 style="display:inline;margin-left:6px">' + esc(f.title) + "</h3></header>" +
        "<p>" + esc(f.message) + "</p>" +
        '<p class="rec"><strong>Recommendation.</strong> ' + esc(f.recommendation) + "</p>" +
        "</article>";
    }).join("");
  }

  async function renderDashboard() {
    const d = await api("/api/dashboard");
    const c = d.counts;
    app.innerHTML =
      "<h1>Dashboard</h1>" +
      '<p class="lede">A working prototype of a South African deeds register. Counts, recent registrations and the most urgent advisor flags are below. All data is fictional.</p>' +
      '<div class="cards">' +
        card("Properties", c.properties) +
        card("Parties", c.parties) +
        card("Title deeds", c.titles) +
        card("Active bonds", c.active_bonds) +
        card("Servitudes", c.servitudes) +
        card("Advisor flags", c.advisor_flags, c.advisor_flags ? "alert" : "") +
      "</div>" +
      '<div class="split">' +
        '<section class="panel"><h2>Recent registrations</h2>' + recentTable(d.recent) + "</section>" +
        '<section class="panel"><h2>Advisor highlights</h2>' +
          (d.advisor_preview.length
            ? findingsHtml(d.advisor_preview) + '<p><a href="#/advisor">Open the full advisor</a></p>'
            : '<p class="muted">No critical or warning flags.</p>') +
        "</section>" +
      "</div>";
  }

  function card(k, v, cls) {
    return '<div class="card ' + (cls || "") + '"><div class="k">' + esc(k) +
      '</div><div class="v">' + esc(v) + "</div></div>";
  }

  function recentTable(rows) {
    if (!rows.length) return '<p class="muted">No registrations yet.</p>';
    return "<table><thead><tr><th>Date</th><th>Type</th><th>Deed</th><th>Summary</th></tr></thead><tbody>" +
      rows.map(function (r) {
        const href = r.property ? "#/properties/" + encodeURIComponent(r.property) : "";
        return "<tr><td class=\"mono\">" + esc(r.date) + "</td><td>" + esc(r.type) +
          "</td><td class=\"mono\">" + esc(r.deed_no) + "</td><td>" +
          (href ? '<a href="' + href + '">' + esc(r.summary) + "</a>" : esc(r.summary)) +
          "</td></tr>";
      }).join("") + "</tbody></table>";
  }

  async function renderProperties(q) {
    const data = await api("/api/properties?q=" + encodeURIComponent(q || ""));
    app.innerHTML =
      '<div class="page-head"><h1>Properties</h1><a class="btn secondary" href="#/register/property">Register a property</a></div>' +
      '<div class="toolbar"><input class="search" id="prop-q" placeholder="Search by description, owner, deed, township…" value="' +
        esc(q || "") + '"></div>' +
      '<div class="panel">' + propTable(data.properties) + "</div>";
    const input = qs("#prop-q");
    let t;
    input.addEventListener("input", function () {
      clearTimeout(t);
      t = setTimeout(function () { renderProperties(input.value); }, 200);
    });
    input.focus();
    input.selectionStart = input.value.length;
  }

  function propTable(rows) {
    if (!rows.length) return '<p class="muted">No properties match.</p>';
    return "<table><thead><tr><th>Property</th><th>Kind</th><th>Current owner</th><th>Title</th><th></th></tr></thead><tbody>" +
      rows.map(function (p) {
        return "<tr><td><a href=\"#/properties/" + encodeURIComponent(p.id) + "\">" +
          esc(p.description) + '</a><div class="muted mono">' + esc(p.id) + "</div></td>" +
          '<td class="kind">' + esc(p.kind) + "</td><td>" + esc(p.owner) +
          "</td><td class=\"mono\">" + esc(p.current_title || "—") + "</td><td>" +
          pillBonded(p.bonded) + "</td></tr>";
      }).join("") + "</tbody></table>";
  }

  async function renderProperty(id) {
    const p = await api("/api/property?id=" + encodeURIComponent(id));
    const details = detailsHtml(p.details);
    const chain = (p.title_chain || []).map(function (t, i) {
      return "<li><div class=\"deed\">" + (i + 1) + ". " + esc(t.deed_no) +
        " <span class=\"muted\">dated " + esc(t.date) + "</span></div>" +
        "<div>Owner: <a href=\"#/parties/" + encodeURIComponent(t.owner_id) + "\">" +
        esc(t.owner) + "</a></div>" +
        "<div class=\"muted\">Previous deed: " + esc(t.previous_deed) +
        " · Consideration: " + esc(t.consideration) + "</div></li>";
    }).join("");
    const enc = p.encumbrances || {};
    app.innerHTML =
      '<div class="page-head"><div><p class="kind">' + esc(p.kind) + " · " + esc(p.id) + "</p>" +
      "<h1>" + esc(p.description) + "</h1></div>" +
      '<div>' + pillBonded((p.active_bonds || []).length > 0) + "</div></div>" +
      '<div class="split">' +
        '<div><section class="panel"><h2>Current owner</h2>' +
          (p.owner_id
            ? '<p><a href="#/parties/' + encodeURIComponent(p.owner_id) + '">' + esc(p.owner) + "</a></p>" +
              '<p class="muted">Current title <span class="mono">' + esc(p.current_title) + "</span></p>"
            : '<p class="muted">No registered title.</p>') +
          details + "</section>" +
          '<section class="panel"><h2>Title chain</h2>' +
            (chain ? '<ol class="chain">' + chain + "</ol>" : '<p class="muted">No titles on this property.</p>') +
          "</section>" +
          '<section class="panel"><h2>Encumbrances</h2>' + encHtml(enc) + "</section>" +
          '<p class="toolbar">' +
            '<a class="btn" href="#/register/transfer?property=' + encodeURIComponent(p.id) + '">Register a transfer</a>' +
            '<a class="btn secondary" href="#/register/bond?property=' + encodeURIComponent(p.id) + '">Register a bond</a>' +
            '<a class="btn secondary" href="#/register/cancel_bond">Cancel a bond</a>' +
          "</p>" +
        "</div>" +
        '<div><section class="panel" id="advisor-panel"><h2>Advisor</h2>' +
          findingsHtml(p.advisor) +
          '<div id="ai-slot"></div>' +
          '<p class="form-actions"><button type="button" class="gold" id="ask-ai">Ask the model for advice</button></p>' +
        "</section></div>" +
      "</div>";
    wireAiButton({ property: p.id });
  }

  function detailsHtml(d) {
    if (!d) return "";
    const rows = [];
    Object.keys(d).forEach(function (k) {
      if (k === "type") return;
      rows.push("<dt>" + esc(k.replace(/_/g, " ")) + "</dt><dd>" + esc(d[k]) + "</dd>");
    });
    return rows.length ? '<dl class="dl">' + rows.join("") + "</dl>" : "";
  }

  function encHtml(enc) {
    const parts = [];
    parts.push("<h3>Active mortgage bonds</h3>" + bondList(enc.active_bonds, false));
    parts.push("<h3>Cancelled mortgage bonds</h3>" + bondList(enc.cancelled_bonds, true));
    parts.push("<h3>Servitudes</h3>");
    if (!(enc.servitudes || []).length) parts.push('<p class="muted">None.</p>');
    else parts.push("<ul>" + enc.servitudes.map(function (s) {
      return "<li><span class=\"mono\">" + esc(s.deed_no) + "</span> — " + esc(s.type) +
        " in favour of " + esc(s.in_favour_of) + " (registered " + esc(s.date) + ")<div class=\"muted\">" +
        esc(s.description) + "</div></li>";
    }).join("") + "</ul>");
    return parts.join("");
  }

  function bondList(list, cancelled) {
    if (!list || !list.length) return '<p class="muted">None.</p>';
    return "<ul>" + list.map(function (b) {
      return "<li><span class=\"mono\">" + esc(b.bond_no) + "</span> — " + esc(b.mortgagee) +
        " · " + esc(b.amount_text) + " (registered " + esc(b.date) +
        (cancelled && b.cancelled_on ? ", cancelled " + esc(b.cancelled_on) : "") + ")</li>";
    }).join("") + "</ul>";
  }

  async function renderParties() {
    const data = await api("/api/parties");
    app.innerHTML =
      '<div class="page-head"><h1>Parties</h1><a class="btn secondary" href="#/register/party">Register a party</a></div>' +
      '<div class="panel"><table><thead><tr><th>Name</th><th>Kind</th><th>Identifier</th><th>Holdings</th></tr></thead><tbody>' +
      data.parties.map(function (p) {
        return "<tr><td><a href=\"#/parties/" + encodeURIComponent(p.id) + "\">" + esc(p.name) +
          '</a><div class="muted mono">' + esc(p.id) + "</div></td><td class=\"kind\">" +
          esc(p.kind) + "</td><td>" + esc(p.identifier || "—") + "</td><td>" +
          esc(p.holding_count) + "</td></tr>";
      }).join("") + "</tbody></table></div>";
  }

  async function renderParty(id) {
    const p = await api("/api/party?id=" + encodeURIComponent(id));
    app.innerHTML =
      '<p class="kind">' + esc(p.kind) + "</p><h1>" + esc(p.name) + "</h1>" +
      '<section class="panel"><dl class="dl"><dt>Internal id</dt><dd class="mono">' + esc(p.id) +
      "</dd><dt>Identifier</dt><dd>" + esc(p.identifier || "— not recorded —") + "</dd></dl></section>" +
      '<section class="panel"><h2>Current holdings</h2>' +
      (p.holdings.length ? propTable(p.holdings) : '<p class="muted">This party does not currently own any property on the register.</p>') +
      "</section>";
  }

  async function renderDeeds(preset) {
    app.innerHTML =
      "<h1>Deed lookup</h1>" +
      '<p class="lede">Search by official number — title (T…/YYYY or ST…/YYYY), bond (B…/YYYY) or servitude (K…/YYYYS).</p>' +
      '<div class="panel"><form id="deed-form" class="toolbar">' +
        '<input class="search" name="no" placeholder="e.g. T9100/2024" value="' + esc(preset || "") + '">' +
        '<button type="submit">Look up</button></form><div id="deed-result"></div></div>';
    qs("#deed-form").addEventListener("submit", function (ev) {
      ev.preventDefault();
      const no = ev.target.no.value.trim();
      location.hash = "#/deeds/" + encodeURIComponent(no);
    });
    if (preset) showDeed(preset);
  }

  async function showDeed(no) {
    const box = qs("#deed-result") || app;
    try {
      const data = await api("/api/deeds?no=" + encodeURIComponent(no));
      if (!data.found) {
        box.innerHTML = '<div class="flash warn">No deed, bond or servitude found for <span class="mono">' +
          esc(no) + "</span>.</div>";
        return;
      }
      const r = data.record;
      let body = '<dl class="dl">';
      function row(k, v) { if (v != null && v !== "") body += "<dt>" + k + "</dt><dd>" + v + "</dd>"; }
      row("Type", esc(r.type));
      row("Number", '<span class="mono">' + esc(r.deed_no) + "</span>");
      row("Property", r.property ? '<a href="#/properties/' + encodeURIComponent(r.property) + '">' +
        esc(r.property_label || r.property) + "</a>" : "");
      if (r.type === "title") {
        row("Registered to", esc(r.owner));
        row("Date", esc(r.date));
        row("Previous deed", esc(r.previous_deed));
        row("Consideration", esc(r.consideration));
        row("Status", r.next && r.next.status === "current"
          ? "Current title (end of chain)"
          : "Later transferred by " + esc(r.next && r.next.next_deed) + " on " + esc(r.next && r.next.date));
      } else if (r.type === "bond") {
        row("Mortgagee", esc(r.mortgagee));
        row("Mortgagor", esc(r.mortgagor));
        row("Amount", esc(r.amount_text));
        row("Registered", esc(r.date));
        row("Title", esc(r.title));
        row("Status", r.status === "cancelled"
          ? "Cancelled on " + esc(r.status_detail.cancelled_on)
          : "ACTIVE");
      } else {
        row("Servitude type", esc(r.servitude_type));
        row("In favour of", esc(r.in_favour_of));
        row("Date", esc(r.date));
        row("Description", esc(r.description));
      }
      body += "</dl>";
      const target = qs("#deed-result");
      if (target) target.innerHTML = body;
      else app.innerHTML += '<section class="panel">' + body + "</section>";
    } catch (e) {
      box.innerHTML = '<div class="flash error">' + esc(e.message) + "</div>";
    }
  }

  async function renderAdvisor() {
    const data = await api("/api/advisor");
    app.innerHTML =
      "<h1>Register advisor</h1>" +
      '<p class="lede">Rule-based findings for the whole register, with optional model commentary if you have configured an advice endpoint.</p>' +
      '<section class="panel"><h2>Rule-based findings</h2>' + findingsHtml(data.findings) + "</section>" +
      '<section class="panel"><h2>Model advice</h2><div id="ai-slot"></div>' +
      '<p class="form-actions"><button type="button" class="gold" id="ask-ai">Ask the model for advice</button></p></section>';
    const slot = qs("#ai-slot");
    if (!data.ai.configured) {
      slot.innerHTML = '<div class="ai-box off">Optional model advice is off. Rule-based findings above still apply. ' +
        'Set an API key and an OpenAI-compatible endpoint under <a href="#/settings">Settings</a>.</div>';
    }
    wireAiButton({});
  }

  function wireAiButton(payload) {
    const btn = qs("#ask-ai");
    if (!btn) return;
    btn.addEventListener("click", async function () {
      const slot = qs("#ai-slot");
      slot.innerHTML = '<p class="loading">Asking the configured model…</p>';
      btn.disabled = true;
      try {
        const r = await api("/api/advisor/ai", { method: "POST", body: JSON.stringify(payload || {}) });
        if (r.status === "disabled") {
          slot.innerHTML = '<div class="ai-box off">' + esc(r.message) +
            ' <a href="#/settings">Open Settings</a>.</div>';
        } else if (r.status === "ok") {
          slot.innerHTML = '<div class="ai-box">' + esc(r.advice) + "</div>";
        } else {
          slot.innerHTML = '<div class="flash error">' + esc(r.error || "Advice request failed.") + "</div>";
        }
      } catch (e) {
        slot.innerHTML = '<div class="flash error">' + esc(e.message) + "</div>";
      } finally {
        btn.disabled = false;
      }
    });
  }

  function formVal(form, name) {
    const el = form.elements[name];
    return el ? String(el.value || "").trim() : "";
  }
  function formInt(form, name) {
    const v = formVal(form, name).replace(/[, ]/g, "");
    if (!v) return 0;
    const n = Number(v);
    return Number.isFinite(n) ? Math.round(n) : 0;
  }

  async function submitForm(form, path, body, okMsg) {
    const box = qs("#form-msg", form.parentElement) || qs("#form-msg");
    box.innerHTML = "";
    try {
      const r = await api(path, { method: "POST", body: JSON.stringify(body) });
      if (r.ok) {
        box.innerHTML = '<div class="flash ok">' + esc(okMsg || "Registered successfully.") + "</div>";
        form.reset();
      } else {
        box.innerHTML = '<div class="flash error">' + esc(r.error || "Rejected.") + "</div>";
      }
    } catch (e) {
      box.innerHTML = '<div class="flash error">' + esc(e.message) + "</div>";
    }
  }

  async function partyOptions(selected) {
    const data = await api("/api/parties");
    return data.parties.map(function (p) {
      const sel = p.id === selected ? " selected" : "";
      return "<option value=\"" + esc(p.id) + "\"" + sel + ">" + esc(p.name) + " (" + esc(p.id) + ")</option>";
    }).join("");
  }

  async function propertyOptions(selected) {
    const data = await api("/api/properties");
    return data.properties.map(function (p) {
      const sel = p.id === selected ? " selected" : "";
      return "<option value=\"" + esc(p.id) + "\"" + sel + ">" + esc(p.description) + "</option>";
    }).join("");
  }

  async function renderRegister(kind, params) {
    const tabs = ["party", "property", "first_title", "transfer", "bond", "cancel_bond", "servitude"];
    const labels = {
      party: "Party", property: "Property", first_title: "First title",
      transfer: "Transfer", bond: "Bond", cancel_bond: "Cancel bond", servitude: "Servitude"
    };
    const k = kind && tabs.indexOf(kind) >= 0 ? kind : "transfer";
    const tabHtml = '<div class="tabs">' + tabs.map(function (t) {
      return '<button type="button" class="' + (t === k ? "active" : "") +
        '" data-tab="' + t + '">' + labels[t] + "</button>";
    }).join("") + "</div>";
    app.innerHTML = "<h1>Register</h1>" +
      '<p class="lede">New entries are validated by the same Prolog rules as the command-line register. Errors are shown in full below the form.</p>' +
      tabHtml + '<div id="form-msg"></div><section class="panel" id="reg-form"></section>';
    qsa(".tabs button").forEach(function (b) {
      b.addEventListener("click", function () { location.hash = "#/register/" + b.getAttribute("data-tab"); });
    });
    const box = qs("#reg-form");
    const parties = await partyOptions(params.to || params.owner || "");
    const props = await propertyOptions(params.property || "");
    if (k === "party") {
      box.innerHTML = fieldForm([
        inp("id", "Party id", "e.g. siya"),
        sel("kind", "Kind", [["natural", "Natural person"], ["company", "Company"], ["trust", "Trust"]]),
        inp("name", "Full name"),
        inp("identifier", "Identifier (ID / company no. / trust ref.)")
      ], "Register party");
      box.querySelector("form").addEventListener("submit", function (ev) {
        ev.preventDefault();
        const f = ev.target;
        submitForm(f, "/api/register/party", {
          id: formVal(f, "id"), kind: formVal(f, "kind"),
          name: formVal(f, "name"), identifier: formVal(f, "identifier")
        }, "Party registered.");
      });
    } else if (k === "property") {
      box.innerHTML = fieldForm([
        inp("id", "Property id", "e.g. prop_erf_10"),
        sel("kind", "Kind", [["erf", "Erf"], ["farm", "Farm"], ["sectional", "Sectional title"]]),
        inp("description", "Short description"),
        inp("erf_no", "Erf / farm / section number"),
        inp("township", "Township / farm name / scheme name"),
        inp("municipality", "Municipality / division"),
        inp("province", "Province"),
        inp("extent", "Extent (m², or farm extent text)"),
        inp("portion", "Portion (farms)", "remainder"),
        inp("scheme_no", "Scheme number (sectional)", "SS 88/2019")
      ], "Register property");
      box.querySelector("form").addEventListener("submit", function (ev) {
        ev.preventDefault();
        const f = ev.target;
        const kind = formVal(f, "kind");
        const body = {
          id: formVal(f, "id"), kind: kind, description: formVal(f, "description"),
          erf_no: formVal(f, "erf_no"), township: formVal(f, "township"),
          municipality: formVal(f, "municipality"), province: formVal(f, "province"),
          extent: formVal(f, "extent"), portion: formVal(f, "portion") || "remainder",
          farm_name: formVal(f, "township"), farm_no: formVal(f, "erf_no"),
          division: formVal(f, "municipality"), section: formInt(f, "erf_no"),
          scheme: formVal(f, "township"), scheme_no: formVal(f, "scheme_no")
        };
        submitForm(f, "/api/register/property", body, "Property registered.");
      });
    } else if (k === "first_title") {
      box.innerHTML = fieldForm([
        inp("deed_no", "New title deed number", "T12345/2025"),
        '<label><span>Property</span><select name="property">' + props + "</select></label>",
        '<label><span>Owner</span><select name="owner">' + parties + "</select></label>",
        inp("date", "Date (YYYY-MM-DD)", "2025-01-15"),
        sel("consideration", "Consideration", [["grant", "Grant / first registration"], ["rands", "Price in rands"]]),
        inp("amount", "Amount in rands (if priced)")
      ], "Register first title");
      box.querySelector("form").addEventListener("submit", function (ev) {
        ev.preventDefault();
        const f = ev.target;
        const body = {
          deed_no: formVal(f, "deed_no"), property: formVal(f, "property"),
          owner: formVal(f, "owner"), date: formVal(f, "date"),
          consideration: formVal(f, "consideration")
        };
        if (body.consideration === "rands") body.amount = formInt(f, "amount");
        submitForm(f, "/api/register/first_title", body, "Opening title registered.");
      });
    } else if (k === "transfer") {
      box.innerHTML = fieldForm([
        inp("deed_no", "New title deed number", "T12345/2025"),
        '<label><span>Property</span><select name="property">' + props + "</select></label>",
        '<label><span>Transferor (must be the current owner)</span><select name="from">' + parties + "</select></label>",
        '<label><span>Transferee</span><select name="to">' + parties + "</select></label>",
        inp("date", "Date (YYYY-MM-DD)", "2025-03-01"),
        inp("price", "Price in rands (whole number)")
      ], "Register transfer");
      box.querySelector("form").addEventListener("submit", function (ev) {
        ev.preventDefault();
        const f = ev.target;
        submitForm(f, "/api/register/transfer", {
          deed_no: formVal(f, "deed_no"), property: formVal(f, "property"),
          from: formVal(f, "from"), to: formVal(f, "to"),
          date: formVal(f, "date"), price: formInt(f, "price")
        }, "Transfer registered.");
      });
    } else if (k === "bond") {
      box.innerHTML = fieldForm([
        inp("bond_no", "Bond number", "B6789/2025"),
        '<label><span>Property</span><select name="property">' + props + "</select></label>",
        inp("mortgagee", "Mortgagee (bank name)", "Atlantic Commercial Bank Limited"),
        inp("amount", "Amount in rands"),
        inp("date", "Date (YYYY-MM-DD)")
      ], "Register bond");
      box.querySelector("form").addEventListener("submit", function (ev) {
        ev.preventDefault();
        const f = ev.target;
        submitForm(f, "/api/register/bond", {
          bond_no: formVal(f, "bond_no"), property: formVal(f, "property"),
          mortgagee: formVal(f, "mortgagee"), amount: formInt(f, "amount"),
          date: formVal(f, "date")
        }, "Bond registered.");
      });
    } else if (k === "cancel_bond") {
      box.innerHTML = fieldForm([
        inp("bond_no", "Bond number", "B2100/2021"),
        inp("date", "Cancellation date (YYYY-MM-DD)")
      ], "Cancel bond");
      box.querySelector("form").addEventListener("submit", function (ev) {
        ev.preventDefault();
        const f = ev.target;
        submitForm(f, "/api/register/cancel_bond", {
          bond_no: formVal(f, "bond_no"), date: formVal(f, "date")
        }, "Bond cancelled.");
      });
    } else {
      box.innerHTML = fieldForm([
        inp("deed_no", "Servitude number", "K1234/2025S"),
        '<label><span>Property (servient tenement)</span><select name="property">' + props + "</select></label>",
        inp("type", "Type", "right of way"),
        inp("in_favour_of", "In favour of"),
        inp("date", "Date (YYYY-MM-DD)"),
        inp("description", "Description")
      ], "Register servitude");
      box.querySelector("form").addEventListener("submit", function (ev) {
        ev.preventDefault();
        const f = ev.target;
        submitForm(f, "/api/register/servitude", {
          deed_no: formVal(f, "deed_no"), property: formVal(f, "property"),
          type: formVal(f, "type"), in_favour_of: formVal(f, "in_favour_of"),
          date: formVal(f, "date"), description: formVal(f, "description")
        }, "Servitude registered.");
      });
    }
  }

  function inp(name, label, ph) {
    return '<label><span>' + esc(label) + '</span><input name="' + name +
      '" placeholder="' + esc(ph || "") + '"></label>';
  }
  function sel(name, label, opts) {
    return '<label><span>' + esc(label) + '</span><select name="' + name + '">' +
      opts.map(function (o) { return '<option value="' + esc(o[0]) + '">' + esc(o[1]) + "</option>"; }).join("") +
      "</select></label>";
  }
  function fieldForm(fields, submit) {
    return '<form class="reg"><div class="form-grid">' + fields.join("") +
      '</div><div class="form-actions"><button type="submit">' + esc(submit) + "</button></div></form>";
  }

  async function renderSettings() {
    const s = await api("/api/settings");
    const status = s.configured
      ? '<div class="flash ok">Model advice is configured' +
        (s.key_source === "environment" ? " from an environment variable (the key is not stored in the settings file)." : " from the local settings file.") +
        " Endpoint source: " + esc(s.endpoint_source) + ".</div>"
      : '<div class="flash warn">Model advice is off. Rule-based advice still runs. Add an API key below, or set the DEEDS_AI_API_KEY and DEEDS_AI_ENDPOINT environment variables. Keys are never hardcoded.</div>';
    app.innerHTML =
      "<h1>Settings</h1>" +
      '<p class="lede">Optional OpenAI-compatible chat completions hook for richer commentary on the advisor findings. The key is stored only in data/ai_settings.json on this machine, or read from the environment. It is never returned by the API.</p>' +
      status +
      '<section class="panel"><form id="ai-form" class="form-grid">' +
        '<label class="field" style="grid-column:1/-1"><span>Endpoint (chat completions URL)</span>' +
        '<input name="endpoint" value="' + esc(s.endpoint) + '"></label>' +
        '<label class="field"><span>Model name</span><input name="model" value="' + esc(s.model) + '"></label>' +
        '<label class="field"><span>API key ' + (s.has_key ? "(leave blank to keep the existing key)" : "") + "</span>" +
        '<input name="api_key" type="password" autocomplete="off" placeholder="sk-…"></label>' +
      '</form><div class="form-actions">' +
        '<button type="button" id="save-ai">Save settings</button>' +
        '<button type="button" class="secondary" id="clear-key">Clear stored key</button>' +
      '</div><div id="form-msg"></div></section>' +
      '<section class="panel"><h2>Demo data</h2>' +
        '<p>Replace the current register with the fictional sample (15 properties, 13 parties, including seeded irregularities for the advisor).</p>' +
        '<button type="button" class="danger" id="reset-demo">Reset demo data</button>' +
        '<div id="reset-msg"></div></section>';
    qs("#save-ai").addEventListener("click", async function () {
      const f = qs("#ai-form");
      const body = { endpoint: formVal(f, "endpoint"), model: formVal(f, "model") };
      const key = formVal(f, "api_key");
      if (key) body.api_key = key;
      const box = qs("#form-msg");
      try {
        await api("/api/settings", { method: "POST", body: JSON.stringify(body) });
        box.innerHTML = '<div class="flash ok">Settings saved.</div>';
        setTimeout(renderSettings, 400);
      } catch (e) {
        box.innerHTML = '<div class="flash error">' + esc(e.message) + "</div>";
      }
    });
    qs("#clear-key").addEventListener("click", async function () {
      await api("/api/settings/clear_key", { method: "POST", body: "{}" });
      renderSettings();
    });
    qs("#reset-demo").addEventListener("click", async function () {
      if (!confirm("Wipe the register and reload the fictional sample data? This cannot be undone.")) return;
      const box = qs("#reset-msg");
      try {
        const r = await api("/api/reset", { method: "POST", body: "{}" });
        box.innerHTML = '<div class="flash ok">Demo data reloaded (' +
          esc(r.properties) + " properties, " + esc(r.parties) + " parties).</div>";
      } catch (e) {
        box.innerHTML = '<div class="flash error">' + esc(e.message) + "</div>";
      }
    });
  }

  function paramsFrom(part) {
    const q = {};
    const s = (part || "").split("?")[1] || "";
    s.split("&").forEach(function (kv) {
      if (!kv) return;
      const i = kv.indexOf("=");
      q[decodeURIComponent(i < 0 ? kv : kv.slice(0, i))] =
        decodeURIComponent(i < 0 ? "" : kv.slice(i + 1));
    });
    return q;
  }

  async function dispatch() {
    setNav();
    const r = route();
    const p0 = r.parts[0] || "";
    try {
      if (!p0) await renderDashboard();
      else if (p0 === "properties" && r.parts[1]) await renderProperty(decodeURIComponent(r.parts[1]));
      else if (p0 === "properties") await renderProperties("");
      else if (p0 === "parties" && r.parts[1]) await renderParty(decodeURIComponent(r.parts[1]));
      else if (p0 === "parties") await renderParties();
      else if (p0 === "deeds" && r.parts[1]) {
        await renderDeeds(decodeURIComponent(r.parts[1]));
      } else if (p0 === "deeds") await renderDeeds("");
      else if (p0 === "register") {
        const kind = (r.parts[1] || "transfer").split("?")[0];
        const raw = location.hash.split("?")[1] || "";
        const params = {};
        raw.split("&").forEach(function (kv) {
          if (!kv) return;
          const i = kv.indexOf("=");
          params[decodeURIComponent(i < 0 ? kv : kv.slice(0, i))] =
            decodeURIComponent(i < 0 ? "" : kv.slice(i + 1));
        });
        await renderRegister(kind, params);
      } else if (p0 === "advisor") await renderAdvisor();
      else if (p0 === "settings") await renderSettings();
      else app.innerHTML = '<div class="flash warn">Unknown page. <a href="#/">Return to the dashboard.</a></div>';
    } catch (e) {
      app.innerHTML = '<div class="flash error">' + esc(e.message) + "</div>";
    }
  }

  window.addEventListener("hashchange", dispatch);
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", dispatch);
  else dispatch();
})();
