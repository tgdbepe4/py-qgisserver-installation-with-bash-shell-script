"use strict";
const fs = require("fs");
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat, HeadingLevel,
  BorderStyle, WidthType, ShadingType, PageNumber, PageBreak,
  TableOfContents, ExternalHyperlink
} = require("docx");

// ── Helpers ──────────────────────────────────────────────────────────────────
const W = 11906;          // A4 width  DXA
const H = 16838;          // A4 height DXA
const ML = 1134, MR = 1134, MT = 1134, MB = 1134; // ~2 cm margins
const CW = W - ML - MR;  // content width = 9638

const BLUE  = "1F4E79";
const LBLUE = "2E75B6";
const DGRAY = "404040";
const LGRAY = "F2F2F2";
const MGRAY = "D9D9D9";
const WHITE = "FFFFFF";
const CODBG = "F4F4F4";

const nb = (opts = {}) => ({ style: BorderStyle.NONE, size: 0, color: "FFFFFF", ...opts });
const sb = (color = MGRAY, size = 4) => ({ style: BorderStyle.SINGLE, size, color });

function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 360, after: 120 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: LBLUE, space: 4 } },
    children: [new TextRun({ text, font: "Arial", size: 32, bold: true, color: BLUE })]
  });
}
function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 280, after: 80 },
    children: [new TextRun({ text, font: "Arial", size: 26, bold: true, color: LBLUE })]
  });
}
function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 200, after: 60 },
    children: [new TextRun({ text, font: "Arial", size: 22, bold: true, color: DGRAY })]
  });
}
function para(runs, opts = {}) {
  const children = typeof runs === "string"
    ? [new TextRun({ text: runs, font: "Arial", size: 20, color: DGRAY })]
    : runs;
  return new Paragraph({ spacing: { before: 60, after: 100 }, ...opts, children });
}
function note(text, color = "7B5C00", bg = "FFF8E1") {
  return new Table({
    width: { size: CW, type: WidthType.DXA },
    columnWidths: [CW],
    rows: [new TableRow({ children: [new TableCell({
      borders: { top: sb("F0A500",12), bottom: nb(), left: nb(), right: nb() },
      shading: { fill: bg, type: ShadingType.CLEAR },
      margins: { top: 100, bottom: 100, left: 160, right: 160 },
      width: { size: CW, type: WidthType.DXA },
      children: [new Paragraph({ spacing: { before: 0, after: 0 },
        children: [new TextRun({ text: "  " + text, font: "Arial", size: 18, color, italics: true })] })]
    })]})],
    margins: { top: 80, bottom: 80 }
  });
}
function warn(text) { return note("Warning: " + text, "7B1A1A", "FFF0F0"); }
function tip(text)  { return note("Tip: " + text, "1A5C1A", "F0FFF0"); }

function bullet(text, level = 0) {
  return new Paragraph({
    numbering: { reference: "bullets", level },
    spacing: { before: 40, after: 40 },
    children: [typeof text === "string"
      ? new TextRun({ text, font: "Arial", size: 20, color: DGRAY })
      : text]
  });
}
function numbered(text, level = 0) {
  return new Paragraph({
    numbering: { reference: "numbers", level },
    spacing: { before: 40, after: 40 },
    children: [typeof text === "string"
      ? new TextRun({ text, font: "Arial", size: 20, color: DGRAY })
      : text]
  });
}
function code(text) {
  return new Table({
    width: { size: CW, type: WidthType.DXA },
    columnWidths: [CW],
    rows: [new TableRow({ children: [new TableCell({
      borders: { top: sb(MGRAY,4), bottom: sb(MGRAY,4), left: sb(LBLUE,12), right: nb() },
      shading: { fill: CODBG, type: ShadingType.CLEAR },
      margins: { top: 80, bottom: 80, left: 160, right: 80 },
      width: { size: CW, type: WidthType.DXA },
      children: text.split("\n").map(line =>
        new Paragraph({ spacing: { before: 0, after: 0 },
          children: [new TextRun({ text: line || " ", font: "Courier New", size: 16, color: "1A1A2E" })] })
      )
    })]})],
    margins: { top: 60, bottom: 60 }
  });
}
function sep() {
  return new Paragraph({
    spacing: { before: 60, after: 60 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: MGRAY, space: 1 } },
    children: []
  });
}
function space(before = 120) {
  return new Paragraph({ spacing: { before, after: 0 }, children: [] });
}

// Two-column key/value table
function kvTable(rows) {
  const col0 = Math.round(CW * 0.35);
  const col1 = CW - col0;
  const bdr = { top: sb(MGRAY,2), bottom: sb(MGRAY,2), left: sb(MGRAY,2), right: sb(MGRAY,2) };
  return new Table({
    width: { size: CW, type: WidthType.DXA },
    columnWidths: [col0, col1],
    rows: rows.map(([k, v], i) => new TableRow({
      children: [
        new TableCell({
          borders: bdr,
          shading: { fill: i === 0 ? BLUE : LGRAY, type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          width: { size: col0, type: WidthType.DXA },
          children: [new Paragraph({ spacing: { before: 0, after: 0 }, children: [
            new TextRun({ text: k, font: "Arial", size: 18, bold: true, color: i === 0 ? WHITE : BLUE })
          ]})]
        }),
        new TableCell({
          borders: bdr,
          shading: { fill: i === 0 ? LBLUE : WHITE, type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          width: { size: col1, type: WidthType.DXA },
          children: [new Paragraph({ spacing: { before: 0, after: 0 }, children: [
            new TextRun({ text: v, font: "Arial", size: 18, color: i === 0 ? WHITE : DGRAY })
          ]})]
        })
      ]
    }))
  });
}

// Generic multi-column table
function multiTable(headers, rows, colWidths) {
  const bdr = { top: sb(MGRAY,2), bottom: sb(MGRAY,2), left: sb(MGRAY,2), right: sb(MGRAY,2) };
  return new Table({
    width: { size: CW, type: WidthType.DXA },
    columnWidths: colWidths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: headers.map((txt, ci) => new TableCell({
          borders: bdr,
          shading: { fill: BLUE, type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          width: { size: colWidths[ci], type: WidthType.DXA },
          children: [new Paragraph({ spacing: { before: 0, after: 0 }, children: [
            new TextRun({ text: txt, font: "Arial", size: 18, bold: true, color: WHITE })
          ]})]
        }))
      }),
      ...rows.map((r, ri) => new TableRow({
        children: r.map((txt, ci) => new TableCell({
          borders: bdr,
          shading: { fill: ri % 2 === 0 ? LGRAY : WHITE, type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          width: { size: colWidths[ci], type: WidthType.DXA },
          children: [new Paragraph({ spacing: { before: 0, after: 0 }, children: [
            new TextRun({ text: txt, font: "Arial", size: 18, color: DGRAY })
          ]})]
        }))
      }))
    ]
  });
}

function bold(text) {
  return new TextRun({ text, font: "Arial", size: 20, bold: true, color: DGRAY });
}
function mono(text) {
  return new TextRun({ text, font: "Courier New", size: 18, color: "1A1A2E" });
}

// ── PAGE BREAK ────────────────────────────────────────────────────────────────
const PB = () => new Paragraph({ children: [new PageBreak()] });

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT ASSEMBLY
// ─────────────────────────────────────────────────────────────────────────────
const doc = new Document({
  styles: {
    default: { document: { run: { font: "Arial", size: 20, color: DGRAY } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 32, bold: true, font: "Arial", color: BLUE },
        paragraph: { spacing: { before: 360, after: 120 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 26, bold: true, font: "Arial", color: LBLUE },
        paragraph: { spacing: { before: 280, after: 80 }, outlineLevel: 1 } },
      { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 22, bold: true, font: "Arial", color: DGRAY },
        paragraph: { spacing: { before: 200, after: 60 }, outlineLevel: 2 } },
    ]
  },
  numbering: {
    config: [
      { reference: "bullets",
        levels: [
          { level: 0, format: LevelFormat.BULLET, text: "\u2022", alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
          { level: 1, format: LevelFormat.BULLET, text: "\u25E6", alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 1080, hanging: 360 } } } },
        ]
      },
      { reference: "numbers",
        levels: [
          { level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
          { level: 1, format: LevelFormat.LOWER_LETTER, text: "%2.", alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 1080, hanging: 360 } } } },
        ]
      },
    ]
  },
  sections: [
  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — Cover page
  // ═══════════════════════════════════════════════════════════════════════════
  {
    properties: {
      page: { size: { width: W, height: H }, margin: { top: MT, right: MR, bottom: MB, left: ML } }
    },
    headers: { default: new Header({ children: [] }) },
    footers: {
      default: new Footer({ children: [
        new Paragraph({
          alignment: AlignmentType.RIGHT,
          spacing: { before: 0, after: 0 },
          border: { top: { style: BorderStyle.SINGLE, size: 4, color: MGRAY, space: 4 } },
          children: [
            new TextRun({ text: "Lizmap + py-qgis-server Installation Guide  |  Page ", font: "Arial", size: 16, color: "888888" }),
            new TextRun({ children: [PageNumber.CURRENT], font: "Arial", size: 16, color: "888888" }),
            new TextRun({ text: " of ", font: "Arial", size: 16, color: "888888" }),
            new TextRun({ children: [PageNumber.TOTAL_PAGES], font: "Arial", size: 16, color: "888888" }),
          ]
        })
      ]})
    },
    children: [
      // Top blue band
      new Table({
        width: { size: CW, type: WidthType.DXA }, columnWidths: [CW],
        rows: [new TableRow({ children: [new TableCell({
          borders: { top: nb(), bottom: nb(), left: nb(), right: nb() },
          shading: { fill: BLUE, type: ShadingType.CLEAR },
          margins: { top: 300, bottom: 300, left: 200, right: 200 },
          width: { size: CW, type: WidthType.DXA },
          children: [
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 0, after: 80 }, children: [
              new TextRun({ text: "Installation & Administration Guide", font: "Arial", size: 24, color: "AACCEE", allCaps: true })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 0, after: 0 }, children: [
              new TextRun({ text: "Lizmap Web Client + py-qgis-server", font: "Arial", size: 52, bold: true, color: WHITE })
            ]}),
            new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 60, after: 0 }, children: [
              new TextRun({ text: "on Ubuntu 24.04 LTS (Noble Numbat)", font: "Arial", size: 28, color: "BBDDFF" })
            ]}),
          ]
        })]})],
        margins: { top: 0, bottom: 0 }
      }),
      space(400),
      // Component overview table
      multiTable(
        ["Component", "Version / Package", "Role"],
        [
          ["QGIS Server LTR",    "qgis-server (apt)",                "OGC WMS/WFS/WCS map server"],
          ["QGIS Desktop LTR",   "qgis (apt)",                       "Project authoring (via RDP)"],
          ["py-qgis-server",     "1.9.6 (PyPI venv)",                "HTTP wrapper + load balancer (port 7200)"],
          ["QGIS Server plugins","lizmap_server 2.14.1 + atlasprint + wfsOutputExtension", "Server-side plugins"],
          ["Xvfb",               "xvfb (apt)",                       "Virtual X11 display for Qt rendering"],
          ["Lizmap Web Client",  "3.9.7 (GitHub release)",           "Web GIS portal (PHP)"],
          ["Nginx",              "nginx (apt)",                       "Reverse proxy / static file server"],
          ["PHP",                "8.3-FPM (apt)",                    "Lizmap application runtime"],
          ["PostgreSQL",         "16 + PostGIS (apt, optional)",     "Lizmap log & session storage"],
          ["xRDP + XFCE4",       "xrdp / xfce4 (apt)",              "Remote desktop access (port 3389)"],
        ],
        [Math.round(CW*0.24), Math.round(CW*0.3), CW - Math.round(CW*0.24) - Math.round(CW*0.3)]
      ),
      space(360),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 0, after: 40 }, children: [
        new TextRun({ text: "Document version 3.0  |  June 2026 — Validated on live Ubuntu 24.04 deployment (all checks green)", font: "Arial", size: 18, color: "888888" })
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 0, after: 0 }, children: [
        new TextRun({ text: "Generated automatically from install_lizmap_qgisserver.sh  •  check_installation.sh  •  backup_lizmap_system.sh", font: "Arial", size: 16, color: "AAAAAA", italics: true })
      ]}),
    ]
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — Main body (TOC + all chapters)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    properties: {
      page: { size: { width: W, height: H }, margin: { top: MT, right: MR, bottom: MB, left: ML } }
    },
    headers: {
      default: new Header({ children: [
        new Paragraph({
          border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: LBLUE, space: 4 } },
          spacing: { before: 0, after: 80 },
          children: [
            new TextRun({ text: "Lizmap + py-qgis-server", font: "Arial", size: 18, bold: true, color: LBLUE }),
            new TextRun({ text: "   |   Installation & Administration Guide  v3.0", font: "Arial", size: 18, color: "888888" }),
          ]
        })
      ]})
    },
    footers: {
      default: new Footer({ children: [
        new Paragraph({
          alignment: AlignmentType.RIGHT,
          border: { top: { style: BorderStyle.SINGLE, size: 4, color: MGRAY, space: 4 } },
          spacing: { before: 0, after: 0 },
          children: [
            new TextRun({ text: "Page ", font: "Arial", size: 16, color: "888888" }),
            new TextRun({ children: [PageNumber.CURRENT], font: "Arial", size: 16, color: "888888" }),
            new TextRun({ text: " of ", font: "Arial", size: 16, color: "888888" }),
            new TextRun({ children: [PageNumber.TOTAL_PAGES], font: "Arial", size: 16, color: "888888" }),
          ]
        })
      ]})
    },
    children: [
      // ── Table of Contents ──────────────────────────────────────────────────
      new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 0, after: 120 },
        children: [new TextRun({ text: "Table of Contents", font: "Arial", size: 32, bold: true, color: BLUE })] }),
      new TableOfContents("Table of Contents", { hyperlink: true, headingStyleRange: "1-3" }),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 1 — INTRODUCTION
      // ══════════════════════════════════════════════════════════════════════
      h1("1. Introduction"),
      para("This document describes the automated installation of a complete open-source GIS server stack on Ubuntu 24.04 LTS using the script install_lizmap_qgisserver.sh. The stack consists of Lizmap Web Client (web GIS portal), QGIS Server (OGC map backend), py-qgis-server (Python HTTP wrapper with worker pool management), and xRDP with XFCE4 for remote desktop access. Version 3.0 documents the architecture after full live-deployment validation — all 40+ diagnostic checks in check_installation.sh pass green on a fresh Ubuntu 24.04 install."),
      space(80),

      h2("1.1 Purpose"),
      para("The installation script automates the full provisioning of a production-ready GIS server. It is designed to be run once on a fresh Ubuntu 24.04 minimal installation and requires no manual steps beyond editing the configurable variables at the top of the script. The companion check_installation.sh script verifies every aspect of the installation and can fix common issues automatically with --fix mode."),

      h2("1.2 What Changed in Version 3.0"),
      para("Version 3.0 incorporates all fixes discovered during live deployment validation:"),
      multiTable(
        ["Change", "v2.0 (old)", "v3.0 (current)"],
        [
          ["py-qgis-server install",   "pip3 --break-system-packages",          "Python venv at /opt/local/py-qgis-server"],
          ["Nginx → QGIS connection",  "FastCGI upstream (qgis-fcgi)",          "HTTP proxy to port 7200 (/ows/ /lizmap/)"],
          ["Supervisor command flag",  "--conf",                                  "-c (official docs)"],
          ["QGIS config location",     "/etc/qgis-server/env",                   "/srv/qgis/config/qgis-service.env"],
          ["Server config location",   "/etc/py-qgisserver/server.conf",         "/srv/qgis/server.conf"],
          ["QGIS_OPTIONS_PATH",        "not set",                                 "/srv/qgis/ (required for QGIS3.ini)"],
          ["QGIS_AUTH_DB_DIR_PATH",    "not set",                                 "/srv/qgis/ (required for auth DB)"],
          ["SQLite databases",         "not created",                             "qgis-auth.db, qgis.db, symbology-style.db created"],
          ["Lizmap REST API",          "QGSRV_API_ENABLED_LIZMAP not set (=no)", "QGSRV_API_ENABLED_LIZMAP=yes explicitly set"],
          ["Plugin install method",    "find -name __init__.py",                  "find -type d -name plugin_name"],
          ["Nginx default vhost",      "left active (blocked port 80)",           "rm -f /etc/nginx/sites-enabled/default"],
          ["REVEAL_SETTINGS case",     "True (wrong)",                            "TRUE (uppercase, required)"],
        ],
        [Math.round(CW*0.28), Math.round(CW*0.3), CW - Math.round(CW*0.28) - Math.round(CW*0.3)]
      ),
      space(80),

      h2("1.3 Architecture Overview"),
      para("The diagram below shows the request flow from a browser client to the map data. All QGIS map requests go through py-qgis-server via HTTP (not FastCGI) — this is the architecture required by Lizmap 3.9+."),
      space(60),
      code(
        "Browser / Remmina RDP Client\n" +
        "        |\n" +
        "        |  HTTP :80            RDP :3389\n" +
        "        v                          v\n" +
        "    [ Nginx ]                 [ xRDP ]\n" +
        "     /      \\                 [ XFCE4 ]\n" +
        "    /        \\                [ QGIS Desktop ]\n" +
        "   v          v\n" +
        "[ PHP-FPM ]  [ HTTP proxy  →  py-qgis-server :7200 ]\n" +
        "[ Lizmap  ]   /ows/             |    /lizmap/\n" +
        "    |         |                 v\n" +
        "    |    [ QGIS Server workers (Python) ]\n" +
        "    |    [ lizmap_server plugin          ]\n" +
        "    |    [ atlasprint + wfsOutputExtension]\n" +
        "    |         |         ^\n" +
        "    |    [ Xvfb :99 ]  |  (Qt rendering, headless)\n" +
        "    |         |\n" +
        "    +--[ PostgreSQL ]  (sessions / logs, optional)\n" +
        "    |\n" +
        "    +--[ /srv/data/*.qgs ]  (QGIS project files)"
      ),
      space(120),

      h2("1.4 Audience"),
      para("This guide is intended for:"),
      bullet("GIS administrators responsible for publishing QGIS projects to the web"),
      bullet("System administrators deploying the stack on-premises or in the cloud"),
      bullet("Developers extending or troubleshooting the installation"),

      h2("1.5 What the Script Does NOT Do"),
      bullet("Configure Let's Encrypt / HTTPS (see post-install steps)"),
      bullet("Tune PostgreSQL for production workloads"),
      bullet("Configure LDAP/SSO authentication for Lizmap"),
      warn("Run the script only on a fresh Ubuntu 24.04 server. Running it on an existing production system may overwrite configuration files."),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 2 — PREREQUISITES
      // ══════════════════════════════════════════════════════════════════════
      h1("2. Prerequisites"),

      h2("2.1 Hardware Requirements"),
      multiTable(
        ["Resource", "Minimum", "Recommended"],
        [
          ["CPU",     "2 cores",   "4+ cores (one per QGIS worker)"],
          ["RAM",     "4 GB",      "8-16 GB"],
          ["Disk",    "20 GB",     "100 GB+ (depends on raster data)"],
          ["Network", "100 Mbit",  "1 Gbit"],
        ],
        [Math.round(CW*0.22), Math.round(CW*0.28), CW - Math.round(CW*0.22) - Math.round(CW*0.28)]
      ),
      space(100),

      h2("2.2 Software Requirements"),
      bullet("Ubuntu 24.04 LTS (Noble Numbat) — fresh minimal installation"),
      bullet("Root or sudo access"),
      bullet("Internet connectivity to reach apt, PyPI, GitHub, and plugins.qgis.org"),
      bullet("Outbound HTTPS (port 443) not blocked by firewall"),

      h2("2.3 Network Ports Used"),
      multiTable(
        ["Port", "Protocol", "Service", "Direction"],
        [
          ["80",   "TCP", "Nginx — Lizmap web portal + QGIS WMS/WFS proxy", "Inbound"],
          ["443",  "TCP", "Nginx HTTPS (post-install with Certbot)",         "Inbound"],
          ["3389", "TCP", "xRDP remote desktop",                             "Inbound"],
          ["22",   "TCP", "SSH administration",                              "Inbound"],
          ["7200", "TCP", "py-qgis-server HTTP (localhost only)",            "Internal"],
          ["5432", "TCP", "PostgreSQL (localhost only)",                     "Internal"],
        ],
        [Math.round(CW*0.12), Math.round(CW*0.14), Math.round(CW*0.42), CW - Math.round(CW*0.12) - Math.round(CW*0.14) - Math.round(CW*0.42)]
      ),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 3 — CONFIGURATION
      // ══════════════════════════════════════════════════════════════════════
      h1("3. Configuration Variables"),
      para("All user-facing settings are declared at the top of the script in the CONFIGURABLE VARIABLES block. Edit these before running the script."),
      space(80),
      multiTable(
        ["Variable", "Default", "Description"],
        [
          ["LIZMAP_VERSION",    "3.9.7",               "Lizmap Web Client release to download from GitHub"],
          ["LIZMAP_DIR",        "/var/www/lizmap",     "Web root for Lizmap (nginx serves lizmap/www/ inside this)"],
          ["QGIS_PROJECTS_DIR", "/srv/data",           "Directory for .qgs / .qgz project files"],
          ["QGIS_WORKER_COUNT", "4",                   "Number of parallel QGIS Server worker processes in py-qgis-server"],
          ["SERVER_NAME",       "localhost",            "Nginx server_name directive (domain or IP)"],
          ["LIZMAP_USER",       "www-data",            "Linux user running Nginx/PHP-FPM"],
          ["INSTALL_POSTGRESQL","true",                 "Set false to skip PostgreSQL + PostGIS installation"],
          ["PG_LIZMAP_DB",      "lizmap",              "PostgreSQL database name"],
          ["PG_LIZMAP_USER",    "lizmap",              "PostgreSQL user"],
          ["PG_LIZMAP_PASS",    "(auto-generated)",    "PostgreSQL password — random hex suffix, shown once at end"],
          ["INSTALL_XRDP",      "true",                "Set false to skip xRDP + XFCE4 desktop installation"],
          ["XRDP_USER",         "gisadmin",            "Dedicated RDP login user (created if not existing)"],
          ["XRDP_PASS",         "(auto-generated)",    "RDP password — auto-generated, shown once at end"],
          ["XRDP_PORT",         "3389",                "xRDP listening port"],
          ["LOG_FILE",          "/var/log/install_lizmap_qgisserver.log", "Full installation transcript log path"],
        ],
        [Math.round(CW*0.27), Math.round(CW*0.25), CW - Math.round(CW*0.27) - Math.round(CW*0.25)]
      ),
      space(100),
      tip("Set QGIS_WORKER_COUNT equal to the number of CPU cores to maximise parallel map rendering throughput."),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 4 — RUNNING THE SCRIPT
      // ══════════════════════════════════════════════════════════════════════
      h1("4. Running the Script"),

      h2("4.1 Upload the Scripts"),
      para("Copy the three scripts to the Ubuntu server:"),
      code(
        "scp install_lizmap_qgisserver.sh \\\n" +
        "    check_installation.sh \\\n" +
        "    backup_lizmap_system.sh \\\n" +
        "    root@<server-ip>:~/"
      ),

      h2("4.2 Edit Configuration"),
      para("Open the install script and adjust the variables in the CONFIGURABLE VARIABLES block at the top:"),
      code("nano install_lizmap_qgisserver.sh"),

      h2("4.3 Execute"),
      code("chmod +x install_lizmap_qgisserver.sh\nsudo bash install_lizmap_qgisserver.sh"),
      para("The script runs non-interactively. All output is shown on the terminal and simultaneously written to the log file defined by LOG_FILE."),

      h2("4.4 Verify Installation"),
      para("After the install script completes, run the check script to verify every component:"),
      code("sudo bash check_installation.sh"),
      para("A fully successful installation ends with:"),
      code("  \u2713 Alles OK \u2014 Stack l\u00e4uft korrekt."),
      para("If any check fails, run with --fix to attempt automatic repair:"),
      code("sudo bash check_installation.sh --fix"),

      h2("4.5 Installation Log"),
      para("The very first action the script performs is redirecting all output through tee to the log file:"),
      code("exec > >(tee -a \"${LOG_FILE}\") 2>&1"),
      para("This means every apt-get line, wget progress, PHP installer message, and any error traceback is captured."),
      bullet("Log location: /var/log/install_lizmap_qgisserver.log"),
      bullet("Every section header, [INFO], [WARN], and [ERROR] message is recorded"),
      bullet("set -uo pipefail ensures the script stops immediately on unhandled errors"),
      space(80),
      note("If the script fails mid-way, check the log for the exact error line. Re-running the script is safe — most steps are idempotent."),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 5 — INSTALLATION STEPS
      // ══════════════════════════════════════════════════════════════════════
      h1("5. Installation Steps Detail"),

      // ── Step 1 ──
      h2("Step 1 — System Update and Base Dependencies"),
      para("The script sets DEBIAN_FRONTEND=noninteractive to suppress apt prompts, then runs apt-get update and apt-get upgrade before installing the following base packages:"),
      space(60),
      multiTable(
        ["Package", "Purpose"],
        [
          ["apt-transport-https, ca-certificates", "Secure apt repository access"],
          ["curl, wget, unzip, git",               "File downloads and archive handling"],
          ["gnupg, software-properties-common",   "GPG key management and PPA support"],
          ["python3, python3-pip, python3-venv, python3-dev", "Python runtime for py-qgis-server venv"],
          ["build-essential, libzmq3-dev",        "Compilation tools and ZeroMQ library"],
          ["supervisor",                           "Process manager for py-qgis-server"],
          ["nginx",                                "Web server and reverse proxy"],
          ["openssl",                              "TLS certificate generation"],
          ["xvfb, x11-utils",                     "Virtual framebuffer (X11 display for QGIS Qt)"],
          ["libgl1, libgl1-mesa-dri, mesa-utils",  "Software OpenGL — note: libgl1 replaces libgl1-mesa-glx on Ubuntu 24.04"],
        ],
        [Math.round(CW*0.45), CW - Math.round(CW*0.45)]
      ),

      // ── Step 2 ──
      h2("Step 2 — QGIS Server LTR Installation"),
      para("The official QGIS Long-Term Release repository for Ubuntu Noble (24.04) is added:"),
      code(
        "# APT signing key\nwget -qO /etc/apt/keyrings/qgis-archive-keyring.gpg \\\n" +
        "    https://download.qgis.org/downloads/qgis-archive-keyring.gpg\n\n" +
        "# /etc/apt/sources.list.d/qgis.sources\n" +
        "Types: deb deb-src\n" +
        "URIs: https://qgis.org/ubuntu-ltr\n" +
        "Suites: noble\n" +
        "Architectures: amd64\n" +
        "Components: main\n" +
        "Signed-By: /etc/apt/keyrings/qgis-archive-keyring.gpg"
      ),
      para("Packages installed from the QGIS LTR repository:"),
      bullet("qgis-server — the QGIS Server binary (/usr/lib/cgi-bin/qgis_mapserv.fcgi)"),
      bullet("qgis — QGIS Desktop for project authoring inside the RDP session"),
      bullet("python3-qgis — Python bindings (PyQGIS) required by py-qgis-server"),
      bullet("qgis-plugin-grass, qgis-providers — additional data format providers"),

      // ── Step 3 ──
      h2("Step 3 — PHP 8.3-FPM"),
      para("PHP 8.3 with all extensions required by Lizmap is installed and configured:"),
      multiTable(
        ["PHP Extension", "Lizmap Use"],
        [
          ["dom, simplexml",  "XML project file parsing"],
          ["curl",            "Remote WMS/WFS calls from Lizmap to QGIS Server"],
          ["gd",              "Image manipulation (map thumbnails)"],
          ["mbstring",        "Multi-byte string handling"],
          ["pgsql, pdo_pgsql","PostgreSQL connection (must be explicitly enabled)"],
          ["sqlite3",         "Local session/cache storage (SQLite mode)"],
          ["zip",             "Map export packaging"],
          ["intl, ldap",      "Internationalisation / optional LDAP authentication"],
        ],
        [Math.round(CW*0.35), CW - Math.round(CW*0.35)]
      ),
      space(80),
      para("php.ini tuning applied:"),
      code(
        "upload_max_filesize = 200M\n" +
        "post_max_size       = 200M\n" +
        "memory_limit        = 256M\n" +
        "max_execution_time  = 300"
      ),
      note("Note: Ubuntu 24.04 PHP packages do NOT auto-enable extensions. The script calls phpenmod -v 8.3 pgsql pdo_pgsql explicitly."),

      // ── Step 4 ──
      h2("Step 4 — PostgreSQL + PostGIS (Optional)"),
      para("When INSTALL_POSTGRESQL=true, PostgreSQL 16 and PostGIS are installed, and a dedicated database and user are created for Lizmap:"),
      code(
        "CREATE USER lizmap WITH PASSWORD '<auto-generated>';\n" +
        "CREATE DATABASE lizmap OWNER lizmap;\n" +
        "-- PostGIS extension\n" +
        "CREATE EXTENSION IF NOT EXISTS postgis;\n" +
        "-- PostgreSQL 15/16: must grant schema explicitly\n" +
        "GRANT ALL ON SCHEMA public TO lizmap;"
      ),
      para("The script writes a clean profiles.ini.php with three sections: [jdb:default], [jdb:jauth], [jdb:lizlog]. Using host=127.0.0.1 (not localhost) avoids IPv6 socket ambiguity. An md5 entry is added to pg_hba.conf."),
      note("The generated password is displayed once at the end of the installation. Save it immediately — it is not stored elsewhere."),

      // ── Step 5 ──
      h2("Step 5 — py-qgis-server (Python Venv)"),
      para("py-qgis-server is a Python WSGI application by 3liz that wraps QGIS Server with HTTP load balancing, worker pool management, and project caching. It is installed in a dedicated Python virtual environment to avoid conflicts with system packages:"),
      code(
        "# Create venv with access to system PyQGIS bindings\npython3 -m venv /opt/local/py-qgis-server --system-site-packages\n\n" +
        "# Install dependencies + py-qgis-server\n/opt/local/py-qgis-server/bin/pip install -U pip setuptools wheel pysocks typing_extensions\n" +
        "/opt/local/py-qgis-server/bin/pip install py-qgis-server\n\n" +
        "# Convenience symlink\nln -sf /opt/local/py-qgis-server/bin/qgisserver /usr/local/bin/qgisserver"
      ),
      para("The --system-site-packages flag is critical: it gives the venv access to python3-qgis (PyQGIS) which is installed via apt and cannot be pip-installed."),
      warn("Do NOT use 'pip3 install --break-system-packages py-qgis-server'. This approach was used in v2.0 but is unreliable on Ubuntu 24.04. The venv approach is documented at docs.lizmap.com."),
      space(60),

      h2("Step 5a — QGIS Server Directory Structure"),
      para("A dedicated system user qgis is created with home /srv/qgis. All QGIS Server configuration is co-located under /srv/qgis/ — this matches the layout documented at docs.lizmap.com/3.9/en/install/py-qgis-server.html:"),
      code(
        "/srv/qgis/\n" +
        "  QGIS/\n" +
        "    QGIS3.ini          <- QGIS options (plugin path, cache config)\n" +
        "  cache/\n" +
        "    prepared/          <- QGIS Server symbol/tile cache\n" +
        "  config/\n" +
        "    qgis-service.env   <- environment variables for all workers\n" +
        "  plugins/             <- QGIS Server plugins directory\n" +
        "    lizmap_server/\n" +
        "    atlasprint/\n" +
        "    wfsOutputExtension/\n" +
        "  fonts/               <- custom fonts for map rendering\n" +
        "  qgis-auth.db         <- QGIS authentication database (auto-created)\n" +
        "  qgis.db              <- QGIS internal database (auto-created)\n" +
        "  symbology-style.db   <- symbology/style database (auto-created)\n" +
        "  server.conf          <- py-qgis-server configuration\n" +
        "  bookmarks.xml        <- empty bookmarks file (required by QGIS)\n" +
        "\n/srv/data/              <- QGIS project files (.qgs, .qgz)"
      ),

      h2("Step 5b — SQLite Databases"),
      para("QGIS Server requires three SQLite database files to be present at the path specified by QGIS_AUTH_DB_DIR_PATH. Without them, QGIS Server initialisation is incomplete and plugins fail to register their API endpoints. The script creates these as empty SQLite files; QGIS initialises the schema on first start:"),
      code(
        "python3 - <<'PYDB'\n" +
        "import sqlite3, os\n" +
        "for db in ['/srv/qgis/qgis-auth.db', '/srv/qgis/qgis.db', '/srv/qgis/symbology-style.db']:\n" +
        "    if not os.path.exists(db):\n" +
        "        sqlite3.connect(db).close()\n" +
        "        print(f'Created: {db}')\n" +
        "PYDB"
      ),
      warn("If these databases are missing, lizmap_server loads but registers no API paths — resulting in \\\"paths\\\": {} and /lizmap/server.json returning 404. This was the root cause of the API failure in earlier deployments."),

      h2("Step 5c — Environment File (qgis-service.env)"),
      para("The environment file /srv/qgis/config/qgis-service.env is read by the systemd QGIS Server workers. It contains all variables required by QGIS Server and py-qgis-server:"),
      code(
        "# Locale\n" +
        "LC_ALL=en_US.UTF-8\n\n" +
        "# X11 virtual display (Xvfb :99)\n" +
        "DISPLAY=:99\n" +
        "QT_QPA_PLATFORM=xcb\n" +
        "LIBGL_ALWAYS_SOFTWARE=1\n\n" +
        "# QGIS paths (critical — without these QGIS ignores QGIS3.ini)\n" +
        "QGIS_OPTIONS_PATH=/srv/qgis/\n" +
        "QGIS_AUTH_DB_DIR_PATH=/srv/qgis/\n" +
        "HOME=/srv/qgis\n\n" +
        "# QGIS Server settings\n" +
        "QGIS_SERVER_LOG_LEVEL=1\n" +
        "QGIS_SERVER_FORCE_READONLY_LAYERS=TRUE\n" +
        "QGIS_SERVER_LIZMAP_REVEAL_SETTINGS=TRUE   # uppercase! enables /lizmap/server.json\n\n" +
        "# Plugin path (both variables for compatibility)\n" +
        "QGSRV_SERVER_PLUGINPATH=/srv/qgis/plugins\n" +
        "QGIS_PLUGINPATH=/srv/qgis/plugins\n\n" +
        "# Lizmap REST API — disabled by default in py-qgis-server!\n" +
        "QGSRV_API_ENABLED_LIZMAP=yes           # REQUIRED\n" +
        "QGSRV_API_ENDPOINTS_LIZMAP=/lizmap     # sets path prefix\n" +
        "QGSRV_API_ENABLED_LANDING_PAGE=no"
      ),
      note("QGSRV_API_ENABLED_LIZMAP defaults to 'no' in py-qgis-server 1.9.6. Without setting it to 'yes', /lizmap/server.json returns 404 regardless of whether lizmap_server plugin is loaded."),

      h2("Step 5d — py-qgis-server Configuration (server.conf)"),
      code(
        "# /srv/qgis/server.conf\n" +
        "[server]\n" +
        "port=7200\n" +
        "workers=4\n" +
        "timeout=300\n" +
        "pluginpath=/srv/qgis/plugins\n\n" +
        "[projects.cache]\n" +
        "rootdir=/srv/data\n" +
        "size=10\n\n" +
        "[logging]\n" +
        "level=WARNING"
      ),
      note("rootdir belongs under [projects.cache], NOT under [server]. This is a common misconfiguration."),

      h2("Step 5e — QGIS Server Plugins"),
      para("Three QGIS Server plugins are installed to /srv/qgis/plugins/:"),
      multiTable(
        ["Plugin", "Source", "Function"],
        [
          ["lizmap_server 2.14.1", "plugins.qgis.org (primary) → GitHub (fallback)", "Lizmap REST API, GetFeatureInfo extensions"],
          ["atlasprint",           "GitHub releases API → master branch",              "Atlas PDF printing from Lizmap"],
          ["wfsOutputExtension",   "GitHub releases API → master branch",              "Additional WFS output formats (GeoJSON, CSV)"],
        ],
        [Math.round(CW*0.26), Math.round(CW*0.36), CW - Math.round(CW*0.26) - Math.round(CW*0.36)]
      ),
      space(60),
      para("The install function uses find -type d -name \"plugin_name\" to locate the plugin directory inside the ZIP archive — reliable regardless of archive structure or nesting depth:"),
      code(
        "install_lizmap_server_plugin() {\n" +
        "    local dest=\"/srv/qgis/plugins/lizmap_server\"\n" +
        "    try_install_from_zip() {\n" +
        "        local url=\"$1\" label=\"$2\"\n" +
        "        curl -L --silent --max-time 60 -o /tmp/lzm.zip \"${url}\" || return 1\n" +
        "        file /tmp/lzm.zip | grep -qi \"zip\"         || return 1\n" +
        "        unzip -q /tmp/lzm.zip -d /tmp/lzm_ex\n" +
        "        local src\n" +
        "        # find by directory name — works regardless of archive structure\n" +
        "        src=$(find /tmp/lzm_ex -type d -name \"lizmap_server\" \\\n" +
        "              | while read -r d; do\n" +
        "                  [ -f \"${d}/metadata.txt\" ] && echo \"${d}\" && break\n" +
        "                done)\n" +
        "        [ -n \"${src}\" ] && mv \"${src}\" \"${dest}\" || return 1\n" +
        "    }\n" +
        "    # Method 1: plugins.qgis.org\n" +
        "    try_install_from_zip \\\n" +
        "        \"https://plugins.qgis.org/plugins/lizmap_server/version/2.14.1/download/\" \\\n" +
        "        \"plugins.qgis.org\" && return\n" +
        "    # Method 2: GitHub master branch\n" +
        "    try_install_from_zip \\\n" +
        "        \"https://github.com/3liz/qgis-server-lizmap-plugin/archive/refs/heads/master.zip\" \\\n" +
        "        \"GitHub master\" && return\n" +
        "    # Method 3: GitHub releases API (latest release)\n" +
        "    ...\n" +
        "}"
      ),
      warn("Using find -name __init__.py to locate a plugin inside an archive is unreliable: Python packages inside plugins (e.g. definitions/__init__.py) are also matched, causing the wrong directory to be moved. Always use find -type d -name <plugin_name>."),

      // ── Step 5b (Xvfb) ──
      h2("Step 5f — Xvfb Virtual Display :99"),
      para("QGIS Server uses Qt for all map output. Qt requires a QScreen object, which can only be created when a valid X11 display is available. On a headless server this fails without Xvfb:"),
      code("QXcbConnection: Could not connect to display :99\nAborted (core dumped)"),
      para("A persistent Xvfb process is started on display :99 and managed by systemd:"),
      code(
        "# /etc/systemd/system/xvfb.service\n" +
        "[Service]\n" +
        "ExecStart=/usr/bin/Xvfb :99 \\\n" +
        "  -screen 0 1280x1024x24 \\\n" +
        "  -ac                     \\\n" +
        "  +extension GLX          \\\n" +
        "  +extension RANDR        \\\n" +
        "  -nolisten tcp           \\\n" +
        "  -noreset\n" +
        "User=www-data\n" +
        "Restart=always"
      ),
      multiTable(
        ["Xvfb Flag", "Reason"],
        [
          ["-screen 0 1280x1024x24", "24-bit colour; Qt refuses 8-bit palettised modes"],
          ["-ac",                    "Disable access control so workers connect without xhost"],
          ["+extension GLX",         "Qt OpenGL renderer probes GLX on startup"],
          ["+extension RANDR",        "Some QGIS symbol renderers call XRRGetScreenResources"],
          ["-nolisten tcp",           "No TCP socket; Unix socket only (security)"],
          ["-noreset",               "Keep Xvfb alive after last client disconnect"],
        ],
        [Math.round(CW*0.38), CW - Math.round(CW*0.38)]
      ),

      // ── Step 6 ──
      h2("Step 6 — Systemd Units (QGIS FastCGI workers)"),
      para("QGIS Server FastCGI workers are managed by systemd template units. py-qgis-server connects to these workers internally. One socket + service pair is created per worker:"),
      code(
        "# /etc/systemd/system/qgis-server@.socket\n" +
        "ListenStream=/run/qgis-server-%i.sock\n" +
        "SocketUser=www-data\n\n" +
        "# /etc/systemd/system/qgis-server@.service\n" +
        "Requires=qgis-server@%i.socket xvfb.service\n" +
        "After=network.target xvfb.service\n" +
        "EnvironmentFile=/srv/qgis/config/qgis-service.env\n" +
        "ExecStart=/usr/lib/cgi-bin/qgis_mapserv.fcgi"
      ),
      para("Additionally, a meta-unit qgis.service is created that starts/stops the entire stack with a single command:"),
      code(
        "service qgis start    # starts Xvfb + workers + py-qgis-server\n" +
        "service qgis stop     # stops all QGIS components\n" +
        "service qgis restart  # full restart"
      ),

      // ── Step 7 ──
      h2("Step 7 — py-qgis-server Supervisor Configuration"),
      para("py-qgis-server is registered with Supervisor and starts automatically on boot:"),
      code(
        "# /etc/supervisor/conf.d/py-qgisserver.conf\n" +
        "[program:py-qgisserver]\n" +
        "; venv binary — gives access to system PyQGIS via --system-site-packages\n" +
        "; flag is -c (not --conf) — as per official Lizmap documentation\n" +
        "command=/opt/local/py-qgis-server/bin/qgisserver -c /srv/qgis/server.conf\n" +
        "user=qgis\n" +
        "environment=LC_ALL=\"en_US.UTF-8\",HOME=\"/srv/qgis\",DISPLAY=\":99\",\n" +
        "            QT_QPA_PLATFORM=\"xcb\",LIBGL_ALWAYS_SOFTWARE=\"1\",\n" +
        "            QGIS_OPTIONS_PATH=\"/srv/qgis/\",\n" +
        "            QGIS_AUTH_DB_DIR_PATH=\"/srv/qgis/\",\n" +
        "            QGIS_SERVER_LOG_LEVEL=\"1\",QGIS_DEBUG=\"0\",\n" +
        "            QGSRV_SERVER_PLUGINPATH=\"/srv/qgis/plugins\",\n" +
        "            QGIS_PLUGINPATH=\"/srv/qgis/plugins\",\n" +
        "            QGIS_SERVER_LIZMAP_REVEAL_SETTINGS=\"TRUE\",\n" +
        "            QGIS_SERVER_FORCE_READONLY_LAYERS=\"TRUE\",\n" +
        "            QGSRV_API_ENABLED_LIZMAP=\"yes\",\n" +
        "            QGSRV_API_ENDPOINTS_LIZMAP=\"/lizmap\"\n" +
        "autostart=true\n" +
        "autorestart=true\n" +
        "stdout_logfile=/var/log/supervisor/py-qgisserver.log\n" +
        "stderr_logfile=/var/log/supervisor/py-qgisserver-err.log"
      ),
      note("Supervisor does not read EnvironmentFile — all environment variables must be listed explicitly in the environment= line. The env file (qgis-service.env) is only read by systemd units."),

      // ── Step 8 ──
      h2("Step 8 — Lizmap Web Client 3.9.7"),
      para("Lizmap is downloaded from the official GitHub releases page, extracted to /var/www/lizmap, and configured:"),
      numbered("Download and extract the release ZIP from GitHub"),
      numbered("Copy .dist config templates to live config files"),
      numbered("Set wmsServerURL=http://127.0.0.1:7200/ows/ in lizmapConfig.ini.php"),
      numbered("Set wmsServerType=py-qgis-server in lizmapConfig.ini.php"),
      numbered("Set lizmapPluginAPIURL=http://127.0.0.1:7200/lizmap/ in lizmapConfig.ini.php"),
      numbered("Write complete profiles.ini.php with PostgreSQL sections (no duplicates)"),
      numbered("Create temp/, temp/lizmap/, var/cache/, var/log/ with absolute paths"),
      numbered("Run lizmap/install/set_rights.sh + chown -R www-data to set permissions"),
      numbered("Run php lizmap/install/installer.php as www-data to initialise the schema"),
      space(80),
      kvTable([
        ["Config key",   "Value"],
        ["Web root",     "/var/www/lizmap/lizmap/www   (index.php lives here — NOT in /var/www/lizmap)"],
        ["Config dir",   "/var/www/lizmap/lizmap/var/config/"],
        ["wmsServerURL", "http://127.0.0.1:7200/ows/"],
        ["wmsServerType","py-qgis-server"],
        ["PluginAPIURL", "http://127.0.0.1:7200/lizmap/"],
        ["Default login","admin / admin  (change immediately after install)"],
      ]),
      space(60),
      warn("The Nginx root directive must point to lizmap/www/ (with /lizmap/www suffix), not to the lizmap/ project root. Nginx serving the wrong directory causes 403 errors."),

      // ── Step 9 ──
      h2("Step 9 — Nginx Virtual Host"),
      para("Nginx serves Lizmap via PHP-FPM and proxies map requests to py-qgis-server on port 7200 via HTTP (not FastCGI). The default Nginx vhost is removed to prevent it from intercepting port 80:"),
      code(
        "# Remove default vhost (would intercept port 80)\nrm -f /etc/nginx/sites-enabled/default\n\n" +
        "server {\n" +
        "    listen 80;\n" +
        "    root /var/www/lizmap/lizmap/www;   # must include /lizmap/www\n" +
        "    index index.php;\n\n" +
        "    # PHP-FPM for Lizmap application\n" +
        "    location ~ [^/]\\.php(/$) {\n" +
        "        fastcgi_pass unix:/run/php/php8.3-fpm.sock;\n" +
        "        ...\n" +
        "    }\n\n" +
        "    # HTTP proxy to py-qgis-server (NOT FastCGI)\n" +
        "    location /ows/ {\n" +
        "        proxy_pass http://127.0.0.1:7200/ows/;\n" +
        "        proxy_read_timeout 120s;\n" +
        "        add_header 'Access-Control-Allow-Origin' '*' always;\n" +
        "    }\n\n" +
        "    location /lizmap/api/ {\n" +
        "        proxy_pass http://127.0.0.1:7200/lizmap/;\n" +
        "    }\n\n" +
        "    location /api/ {\n" +
        "        proxy_pass http://127.0.0.1:7200/api/;\n" +
        "    }\n" +
        "}"
      ),
      multiTable(
        ["Nginx Location", "Proxy Target", "Purpose"],
        [
          ["/ows/",        "http://127.0.0.1:7200/ows/",    "OGC WMS/WFS/WCS requests"],
          ["/lizmap/api/", "http://127.0.0.1:7200/lizmap/", "Lizmap REST API (server info, feature queries)"],
          ["/api/",        "http://127.0.0.1:7200/api/",    "py-qgis-server management API"],
          ["/",            "PHP-FPM socket",                  "Lizmap web portal"],
        ],
        [Math.round(CW*0.22), Math.round(CW*0.35), CW - Math.round(CW*0.22) - Math.round(CW*0.35)]
      ),

      // ── Step 10 ──
      h2("Step 10 — xRDP + XFCE4 Remote Desktop"),
      para("When INSTALL_XRDP=true, a full XFCE4 desktop environment and xRDP are installed to allow GIS administrators to author QGIS projects remotely."),

      h3("Packages Installed"),
      bullet("xfce4, xfce4-goodies, xfce4-terminal — lightweight desktop environment"),
      bullet("xorg, dbus-x11 — X11 server and D-Bus session"),
      bullet("xrdp, xorgxrdp — RDP server and X.Org driver"),
      bullet("mate-polkit — PolicyKit agent (prevents black screen on login in Ubuntu 24.04)"),
      bullet("Firefox (native .deb via Mozilla PPA — works in RDP sessions unlike snap)"),

      h3("Common Fixes Applied"),
      multiTable(
        ["Issue", "Fix Applied"],
        [
          ["Black screen on login",         "mate-polkit autostart .desktop added to /etc/xdg/autostart/"],
          ["polkit-gnome not found",         "Replaced with mate-polkit (polkit-gnome removed in Ubuntu 24.04)"],
          ["Colour glitches",               "max_bpp=32, xserverbpp=24 set in xrdp.ini"],
          ["Session bus conflict",          "Unset DBUS_SESSION_BUS_ADDRESS in .xsessionrc"],
          ["Slow performance",              "tcp_nodelay=true, tcp_keepalive=true, bulk_compression=true"],
          ["Firefox snap unusable in RDP",  "Mozilla PPA used for native .deb Firefox instead of snap"],
        ],
        [Math.round(CW*0.38), CW - Math.round(CW*0.38)]
      ),

      // ── Step 11 ──
      h2("Step 11 — Firewall (UFW)"),
      code(
        "ufw allow OpenSSH\n" +
        "ufw allow 'Nginx Full'   # ports 80 and 443\n" +
        "ufw allow 3389/tcp       # xRDP (only when INSTALL_XRDP=true)\n" +
        "ufw --force enable"
      ),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 6 — POST-INSTALLATION
      // ══════════════════════════════════════════════════════════════════════
      h1("6. Post-Installation Steps"),

      h2("6.1 Change Lizmap Admin Password"),
      numbered("Open http://<server-ip>/ in a browser"),
      numbered("Log in with admin / admin"),
      numbered("Click user icon (top right) → Administration → Users"),
      numbered("Change the admin password immediately"),
      warn("Leaving the default admin/admin password is a critical security risk. Change it before publishing any project."),

      h2("6.2 Connect via Remote Desktop"),
      code(
        "# Windows\nmstsc /v:<server-ip>:3389\n\n" +
        "# Linux (Remmina)\nremmina -c rdp://<server-ip>:3389"
      ),
      para("Log in with the gisadmin user and the password shown at the end of the installation log."),

      h2("6.3 Publish a QGIS Project"),
      numbered("In the RDP session, open QGIS Desktop"),
      numbered("Install the Lizmap QGIS plugin (Plugins > Manage and Install Plugins > search Lizmap)"),
      numbered("Create or open a QGIS project and save to /srv/data/myproject.qgs"),
      numbered("In the Lizmap plugin, configure layers, popups, and base maps, then click Save"),
      numbered("In the Lizmap web interface, go to Administration > Lizmap repositories"),
      numbered("Add a repository pointing to /srv/data"),
      numbered("The project will appear in the map list"),

      h2("6.4 Enable HTTPS"),
      code(
        "sudo apt install certbot python3-certbot-nginx\n" +
        "sudo certbot --nginx -d yourdomain.com"
      ),
      para("Certbot automatically updates the Nginx configuration to redirect HTTP to HTTPS and sets up certificate auto-renewal via a systemd timer."),

      h2("6.5 Verify the Lizmap Plugin API"),
      para("After install, verify that the Lizmap REST API responds correctly:"),
      code(
        "curl -s http://127.0.0.1:7200/lizmap/server.json | python3 -m json.tool\n\n" +
        "# Expected output (abbreviated):\n" +
        "{\n" +
        "  \"qgis_server\": {\n" +
        "    \"version\": \"3.44.8\",\n" +
        "    \"py_qgis_server\": { \"version\": \"1.9.6\" },\n" +
        "    \"plugins\": {\n" +
        "      \"lizmap_server\": { \"version\": \"2.14.1\" },\n" +
        "      \"atlasprint\":    { \"version\": \"3.4.3\" },\n" +
        "      \"wfsOutputExtension\": { \"version\": \"1.8.3\" }\n" +
        "    }\n" +
        "  }\n" +
        "}"
      ),
      para("If this returns 404 or {\"paths\": {}}, see Troubleshooting section 10.7."),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 7 — CHECK INSTALLATION SCRIPT
      // ══════════════════════════════════════════════════════════════════════
      h1("7. Installation Verification — check_installation.sh"),
      para("check_installation.sh is a comprehensive diagnostic script that tests every component of the stack. It produces colour-coded output and an overall pass/fail summary. Run it after installation or at any time to diagnose issues."),

      h2("7.1 Usage"),
      code(
        "# Read-only diagnostic\nsudo bash check_installation.sh\n\n" +
        "# Attempt automatic repairs where possible\nsudo bash check_installation.sh --fix"
      ),

      h2("7.2 What is Checked"),
      multiTable(
        ["Section", "Checks"],
        [
          ["1. Services",      "nginx, php8.3-fpm, xvfb, supervisor, postgresql, xrdp, py-qgisserver (RUNNING)"],
          ["2. Ports",         "80 (nginx), 7200 (py-qgis-server), 5432 (PostgreSQL), 3389 (xRDP), 443 (optional)"],
          ["3. py-qgis-server","server.conf rootdir/port, WMS response, /lizmap/server.json API, venv binary, error log"],
          ["4. Nginx",         "config test, vhost active, default vhost removed, root/index.php, proxy_pass, HTTP 200"],
          ["5. PHP",           "version, all required extensions, FPM socket"],
          ["6. Lizmap",        "web root, lizmapConfig.ini.php, wmsServerType, wmsServerURL, installer marker, permissions"],
          ["7. PostgreSQL",    "database accessible, PostGIS version, PHP→PostgreSQL connection test"],
          ["8. Xvfb",          "service active, display :99 reachable, env vars, supervisor venv path"],
          ["9. Plugins",       "atlasprint, lizmap_server, wfsOutputExtension (dir + __init__.py + metadata.txt)"],
          ["10. xRDP",         "service, startwm.sh, XFCE4, gdm3 absent, mate-polkit autostart"],
          ["11. Directories",  "owner/permissions of /srv/qgis, /srv/data, SQLite DBs, Lizmap var/temp"],
        ],
        [Math.round(CW*0.22), CW - Math.round(CW*0.22)]
      ),
      space(80),

      h2("7.3 Expected Output (All Green)"),
      code(
        "  [OK]    systemctl: nginx aktiv\n" +
        "  [OK]    py-qgisserver l\u00e4uft (uptime: 0:03:20)\n" +
        "  [OK]    Port 7200 offen (py-qgis-server)\n" +
        "  [INFO]  Port 443 nicht offen (Nginx HTTPS \u2014 optional)\n" +
        "  [OK]    Lizmap Plugin API /lizmap/server.json antwortet (lizmap_server v2.14.1)\n" +
        "  [OK]    py-qgis-server venv: /opt/local/py-qgis-server/bin/qgisserver\n" +
        "  [OK]    Nginx: default-Vhost deaktiviert \u2713\n" +
        "  [OK]    Plugin: lizmap_server (v2.14.1)\n" +
        "  [OK]    QGIS DB: /srv/qgis/qgis-auth.db \u2713\n" +
        "  [OK]    Verzeichnis: /var/www/lizmap/temp/lizmap (www-data)\n" +
        "  ...\n" +
        "  \u2713 Alles OK \u2014 Stack l\u00e4uft korrekt."
      ),

      h2("7.4 --fix Mode"),
      para("When run with --fix, the script attempts to automatically repair common failures:"),
      multiTable(
        ["Failure", "--fix Action"],
        [
          ["Service not running",             "systemctl start <service>"],
          ["py-qgis-server not running",      "supervisorctl start py-qgisserver"],
          ["QGSRV_API_ENABLED_LIZMAP missing","Appends to env file + updates supervisor conf + restarts"],
          ["Plugin directory incomplete",     "Downloads and reinstalls from GitHub/plugins.qgis.org"],
          ["SQLite DB missing",               "Creates empty SQLite file via python3"],
          ["Directory missing/wrong owner",   "mkdir -p + chown"],
          ["Nginx default vhost active",      "rm /etc/nginx/sites-enabled/default + nginx restart"],
          ["REVEAL_SETTINGS=True (wrong case)","sed -i to correct to TRUE"],
          ["Supervisor uses wrong binary",    "Updates command= to venv path + supervisorctl reload"],
        ],
        [Math.round(CW*0.38), CW - Math.round(CW*0.38)]
      ),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 8 — BACKUP SCRIPT
      // ══════════════════════════════════════════════════════════════════════
      h1("8. Backup — backup_lizmap_system.sh"),
      para("backup_lizmap_system.sh creates a complete, timestamped snapshot of the running stack at /root/lizmap_backup_YYYYMMDD_HHMMSS.tar.gz. Run it before any major change or before migrating to a new server."),

      h2("8.1 Usage"),
      code(
        "sudo bash backup_lizmap_system.sh\n\n" +
        "# Download the backup to your local PC:\n" +
        "scp root@<server-ip>:/root/lizmap_backup_*.tar.gz ."
      ),

      h2("8.2 What is Backed Up"),
      multiTable(
        ["Section", "Content", "Notes"],
        [
          ["1. /srv/qgis",          "Complete QGIS Server config, plugins, env files, SQLite DBs", "Cache directories excluded (regenerable)"],
          ["2. /srv/data",          "All QGIS project files (.qgs, .qgz, .qml, data)",             "Only if directory is not empty"],
          ["3. Lizmap config",      "/var/www/lizmap/lizmap/var/config/",                           "lizmapConfig, profiles, localconfig"],
          ["4. Nginx",              "/etc/nginx/sites-available/, sites-enabled/, nginx.conf",       ""],
          ["5. Supervisor",         "/etc/supervisor/conf.d/",                                       ""],
          ["6. PHP",                "/etc/php/8.3/fpm/php.ini and pool.d/",                         ""],
          ["7. PostgreSQL",         "pg_dump lizmap + pg_dumpall --globals-only",                    "Skipped if PostgreSQL not active"],
          ["8. Systemd units",      "xvfb.service, qgis.service, qgis-server@.service/.socket",     ""],
          ["9. xRDP",               "/etc/xrdp/startwm.sh, xrdp.ini",                               "Only if xRDP is installed"],
          ["10. System info",       "OS version, installed packages, service status, plugin versions","Written to system_info.txt in archive"],
        ],
        [Math.round(CW*0.2), Math.round(CW*0.35), CW - Math.round(CW*0.2) - Math.round(CW*0.35)]
      ),
      space(60),
      tip("After downloading the backup, restore it on a new server with: sudo bash restore_lizmap_system.sh lizmap_backup_*.tar.gz"),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 9 — FILE & DIRECTORY REFERENCE
      // ══════════════════════════════════════════════════════════════════════
      h1("9. File and Directory Reference"),
      multiTable(
        ["Path", "Description"],
        [
          ["/var/www/lizmap/",                          "Lizmap Web Client root (extracted GitHub release)"],
          ["/var/www/lizmap/lizmap/www/",               "Nginx document root — index.php lives here"],
          ["/var/www/lizmap/lizmap/var/config/",        "Lizmap configuration: lizmapConfig, profiles, localconfig"],
          ["/var/www/lizmap/temp/lizmap/",              "Lizmap temporary files (must be owned by www-data)"],
          ["/srv/data/",                                "QGIS project files (.qgs, .qgz)"],
          ["/srv/qgis/",                                "All QGIS Server configuration (owner: qgis)"],
          ["/srv/qgis/QGIS/QGIS3.ini",                 "QGIS options (plugin path, cache config)"],
          ["/srv/qgis/config/qgis-service.env",        "Environment variables for QGIS Server workers"],
          ["/srv/qgis/server.conf",                    "py-qgis-server configuration (port, workers, cache)"],
          ["/srv/qgis/plugins/",                       "QGIS Server plugins directory"],
          ["/srv/qgis/qgis-auth.db",                   "QGIS authentication database (QGIS_AUTH_DB_DIR_PATH)"],
          ["/srv/qgis/qgis.db",                        "QGIS internal database"],
          ["/srv/qgis/symbology-style.db",             "QGIS symbology/style database"],
          ["/opt/local/py-qgis-server/",               "Python venv for py-qgis-server"],
          ["/opt/local/py-qgis-server/bin/qgisserver", "py-qgis-server executable (used by supervisor)"],
          ["/etc/supervisor/conf.d/py-qgisserver.conf","Supervisor config for py-qgis-server"],
          ["/etc/nginx/sites-available/lizmap",        "Nginx virtual host configuration"],
          ["/etc/systemd/system/xvfb.service",         "Xvfb virtual display systemd unit"],
          ["/etc/systemd/system/qgis-server@.socket",  "QGIS Server socket template unit"],
          ["/etc/systemd/system/qgis-server@.service", "QGIS Server service template unit"],
          ["/etc/systemd/system/qgis.service",         "Meta-unit: start/stop entire QGIS stack"],
          ["/etc/xrdp/startwm.sh",                     "xRDP session startup (launches XFCE4)"],
          ["/usr/bin/qgis-reload",                     "Helper: touch restart monitor for graceful reload"],
        ],
        [Math.round(CW*0.5), CW - Math.round(CW*0.5)]
      ),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 10 — LOG FILES
      // ══════════════════════════════════════════════════════════════════════
      h1("10. Log Files Reference"),
      multiTable(
        ["Log File / Command", "What It Contains"],
        [
          ["/var/log/install_lizmap_qgisserver.log",   "Complete installation transcript with timestamps"],
          ["/var/log/nginx/lizmap-access.log",         "All HTTP requests to Lizmap and QGIS Server"],
          ["/var/log/nginx/lizmap-error.log",          "Nginx errors (500, upstream failures, PHP errors)"],
          ["journalctl -u xvfb.service",               "Xvfb startup/crash messages"],
          ["journalctl -u 'qgis-server@*.service'",    "QGIS worker stdout/stderr (rendering errors)"],
          ["/var/log/supervisor/py-qgisserver.log",    "py-qgis-server stdout (startup, plugin loading)"],
          ["/var/log/supervisor/py-qgisserver-err.log","py-qgis-server stderr (errors, warnings)"],
          ["/var/log/xrdp.log",                        "xRDP server connection events"],
          ["/var/log/xrdp-sesman.log",                 "xRDP session manager / authentication events"],
          ["/var/log/php8.3-fpm.log",                  "PHP-FPM startup and worker errors"],
        ],
        [Math.round(CW*0.5), CW - Math.round(CW*0.5)]
      ),
      space(80),
      tip("Expected non-critical messages in py-qgisserver-err.log: 'No project defined', 'Invalid resource path', 'ServiceException'. These are normal when no project is loaded."),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 11 — SERVICE MANAGEMENT
      // ══════════════════════════════════════════════════════════════════════
      h1("11. Service Management Quick Reference"),
      multiTable(
        ["Action", "Command"],
        [
          ["Start entire QGIS stack",        "service qgis start"],
          ["Stop entire QGIS stack",         "service qgis stop"],
          ["Restart entire QGIS stack",      "service qgis restart"],
          ["Restart py-qgis-server only",    "supervisorctl restart py-qgisserver"],
          ["View Supervisor status",         "supervisorctl status"],
          ["Reload Nginx config",            "systemctl reload nginx"],
          ["Restart PHP-FPM",                "systemctl restart php8.3-fpm"],
          ["Restart Xvfb",                   "systemctl restart xvfb"],
          ["Restart xRDP",                   "systemctl restart xrdp xrdp-sesman"],
          ["Graceful QGIS worker reload",    "touch /var/lib/py-qgis-server/py-qgis-restartmon  (or: qgis-reload)"],
          ["Check UFW status",               "ufw status verbose"],
          ["Verify Lizmap API",              "curl -s http://127.0.0.1:7200/lizmap/server.json | python3 -m json.tool"],
          ["Run full diagnostic check",      "sudo bash check_installation.sh"],
          ["Run diagnostic with auto-fix",   "sudo bash check_installation.sh --fix"],
          ["Create backup",                  "sudo bash backup_lizmap_system.sh"],
        ],
        [Math.round(CW*0.44), CW - Math.round(CW*0.44)]
      ),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 12 — TROUBLESHOOTING
      // ══════════════════════════════════════════════════════════════════════
      h1("12. Troubleshooting"),

      h2("12.1 QGIS Server returns blank or error maps"),
      bullet("Check: journalctl -u 'qgis-server@*.service' -n 50"),
      bullet("If 'Could not connect to display': Xvfb may be down — systemctl status xvfb"),
      bullet("Restart Xvfb first, then py-qgis-server: service qgis restart"),
      bullet("Verify DISPLAY=:99 in supervisor env: supervisorctl status py-qgisserver"),

      h2("12.2 Lizmap shows 'QGIS Server not responding'"),
      bullet("Test directly: curl -s 'http://127.0.0.1:7200/ows/?SERVICE=WMS&REQUEST=GetCapabilities'"),
      bullet("Check py-qgis-server is running: supervisorctl status py-qgisserver"),
      bullet("Check Nginx proxy config: grep proxy_pass /etc/nginx/sites-enabled/lizmap"),

      h2("12.3 /lizmap/server.json returns 404 or {\"paths\": {}}"),
      bullet("Root cause: QGSRV_API_ENABLED_LIZMAP is not set to 'yes'"),
      bullet("Check: grep QGSRV_API_ENABLED_LIZMAP /srv/qgis/config/qgis-service.env"),
      bullet("Also check supervisor conf: grep QGSRV_API /etc/supervisor/conf.d/py-qgisserver.conf"),
      code(
        "# Quick fix:\necho 'QGSRV_API_ENABLED_LIZMAP=yes' >> /srv/qgis/config/qgis-service.env\necho 'QGSRV_API_ENDPOINTS_LIZMAP=/lizmap' >> /srv/qgis/config/qgis-service.env\nsupervisorctl restart py-qgisserver\n# Wait 10 seconds then test:\ncurl -s http://127.0.0.1:7200/lizmap/server.json | python3 -m json.tool"
      ),
      bullet("Alternative: sudo bash check_installation.sh --fix  (fixes automatically)"),

      h2("12.4 lizmap_server plugin 'unvollständig' (incomplete)"),
      bullet("Symptom: /srv/qgis/plugins/lizmap_server/ exists but __init__.py or metadata.txt is missing"),
      bullet("Cause: Plugin was extracted from wrong subdirectory inside the ZIP archive"),
      bullet("Fix: Remove and reinstall:"),
      code(
        "rm -rf /srv/qgis/plugins/lizmap_server\ncurl -L -o /tmp/lzm.zip \\\n    https://plugins.qgis.org/plugins/lizmap_server/version/2.14.1/download/\nunzip /tmp/lzm.zip -d /tmp/lzm_ex\n# find plugin directory by name (NOT by __init__.py)\nfind /tmp/lzm_ex -type d -name 'lizmap_server' \\\n    | while read d; do [ -f \"${d}/metadata.txt\" ] && echo \"${d}\" && break; done\n# move it:\nmv /tmp/lzm_ex/<found_path>/lizmap_server /srv/qgis/plugins/\nchown -R qgis:qgis /srv/qgis/plugins/lizmap_server\nsupervisorctl restart py-qgisserver"
      ),

      h2("12.5 xRDP shows black screen after login"),
      bullet("Ubuntu 24.04 uses mate-polkit — ensure the autostart file is present:"),
      bullet("ls /etc/xdg/autostart/mate-polkit-autostart.desktop", 1),
      bullet("Check Exec path points to: /usr/lib/x86_64-linux-gnu/mate-polkit/polkit-mate-authentication-agent-1", 1),
      bullet("Check .xsessionrc: cat /home/gisadmin/.xsessionrc"),
      bullet("Check xrdp logs: tail -50 /var/log/xrdp-sesman.log"),

      h2("12.6 Lizmap PHP 500 errors"),
      bullet("Check: tail -50 /var/log/nginx/lizmap-error.log"),
      bullet("Check PHP-FPM: journalctl -u php8.3-fpm -n 30"),
      bullet("Fix permissions: bash /var/www/lizmap/lizmap/install/set_rights.sh www-data www-data"),
      bullet("Fix temp/ owner: chown -R www-data:www-data /var/www/lizmap/temp/"),

      h2("12.7 PostgreSQL connection refused / jcommunity error"),
      bullet("Ensure PostgreSQL is running: systemctl status postgresql"),
      bullet("Test connection: psql -U lizmap -d lizmap -h 127.0.0.1"),
      bullet("Verify host=127.0.0.1 (not localhost) in profiles.ini.php"),
      bullet("Check pg_hba.conf has an md5 entry: grep lizmap /etc/postgresql/*/main/pg_hba.conf"),
      bullet("Check schema grants on PostgreSQL 15/16: psql -U postgres -c '\\dn+ public'"),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 13 — DEPLOYMENT FIXES
      // ══════════════════════════════════════════════════════════════════════
      h1("13. Deployment Fixes — All Issues Found During Live Ubuntu 24.04 Testing"),
      para("This chapter documents every error encountered during repeated live deployments on Ubuntu 24.04 LTS and the fixes incorporated into the install script. All fixes below are implemented in the current version of install_lizmap_qgisserver.sh."),
      space(60),

      h2("13.1 libgl1-mesa-glx: no installation candidate"),
      code("E: Package 'libgl1-mesa-glx' has no installation candidate"),
      para("Cause: The package was renamed to libgl1 in Ubuntu 22.04+. Fix: replace libgl1-mesa-glx with libgl1."),

      h2("13.2 polkit-gnome: no installation candidate"),
      code("E: Package 'polkit-gnome' has no installation candidate"),
      para("Cause: Ubuntu 24.04 ships mate-polkit as the PolicyKit agent for XFCE4. Fix: use apt install mate-polkit and write the correct autostart .desktop file pointing to the mate-polkit binary."),

      h2("13.3 Lizmap jcommunity: error during the connection"),
      code("[error] An error occurred during the installation of the module\njcommunity: error during the connection localhost"),
      para("Multiple root causes fixed together:"),
      bullet("PHP pgsql/pdo_pgsql not auto-enabled → phpenmod -v 8.3 pgsql pdo_pgsql"),
      bullet("PostgreSQL 15/16 revokes public schema CREATE → GRANT ALL ON SCHEMA public TO lizmap"),
      bullet("host=localhost resolved to IPv6 → changed to host=127.0.0.1"),
      bullet("Duplicate [jdb:jauth] sections in profiles.ini.php → complete overwrite with 3 clean sections"),
      bullet("Installer ran as root → changed to sudo -u www-data php installer.php"),

      h2("13.4 /lizmap/server.json returns 404 — QGSRV_API_ENABLED_LIZMAP"),
      code("curl http://127.0.0.1:7200/lizmap/server.json\n{\"detail\": \"Invalid resource path\"}"),
      para("Cause: py-qgis-server 1.9.6 ships with QGSRV_API_ENABLED_LIZMAP=no as the default. The Lizmap REST API is completely disabled unless explicitly activated. Fix: add to env file and supervisor conf:"),
      code("QGSRV_API_ENABLED_LIZMAP=yes\nQGSRV_API_ENDPOINTS_LIZMAP=/lizmap"),

      h2("13.5 lizmap_server plugin loads but registers no API paths — SQLite DBs"),
      code("# py-qgis-server log shows plugin loaded,\n# but /lizmap/server.json returns: {\"paths\": {}}"),
      para("Cause: QGIS Server needs qgis-auth.db, qgis.db, and symbology-style.db at QGIS_AUTH_DB_DIR_PATH to fully initialise. Without them plugins load but cannot register REST endpoints. Also QGIS_OPTIONS_PATH must be set so QGIS finds QGIS3.ini. Fix:"),
      code(
        "# Create minimal SQLite databases\npython3 -c \"\nimport sqlite3, os\nfor db in ['qgis-auth.db', 'qgis.db', 'symbology-style.db']:\n    p = f'/srv/qgis/{db}'\n    if not os.path.exists(p):\n        sqlite3.connect(p).close()\n\"\n# Set env vars\necho 'QGIS_OPTIONS_PATH=/srv/qgis/' >> /srv/qgis/config/qgis-service.env\necho 'QGIS_AUTH_DB_DIR_PATH=/srv/qgis/' >> /srv/qgis/config/qgis-service.env"
      ),

      h2("13.6 lizmap_server plugin extracted from wrong subdirectory"),
      para("Cause: Using find -name \"__init__.py\" to locate a plugin inside a ZIP archive matches nested Python packages (e.g. definitions/__init__.py), resulting in a subdirectory being installed as the plugin instead of the plugin root. Fix: use find -type d -name \"lizmap_server\" which searches by directory name and is archive-structure independent."),

      h2("13.7 temp/ directory owned by root"),
      code("[WARN]  Verzeichnis /var/www/lizmap/temp: owner=root (erwartet: www-data)"),
      para("Cause: Using relative paths (mkdir temp/lizmap) from CWD /var/www/lizmap created /var/www/lizmap/lizmap/temp/ (wrong level) and mkdir -p temp ran from a different CWD, leaving the parent temp/ owned by root. Fix: use absolute paths throughout:"),
      code(
        "mkdir -p \"${LIZMAP_DIR}/temp\"\n" +
        "mkdir -p \"${LIZMAP_DIR}/temp/lizmap\"\n" +
        "chown -R \"${LIZMAP_USER}:${LIZMAP_GROUP}\" \"${LIZMAP_DIR}/temp/\""
      ),

      h2("13.8 Supervisor --conf flag rejected"),
      code("Error: invalid option '--conf'"),
      para("Cause: The official Lizmap documentation uses -c (short form). The older --conf flag was not accepted by all versions of py-qgis-server. Fix: change command to use -c:"),
      code("command=/opt/local/py-qgis-server/bin/qgisserver -c /srv/qgis/server.conf"),

      h2("13.9 Nginx default vhost intercepting port 80"),
      code("[FAIL]  HTTP http://127.0.0.1/ -> 404\nNginx: default-Vhost aktiv"),
      para("Cause: Ubuntu installs Nginx with a default vhost in /etc/nginx/sites-enabled/default that listens on port 80 and returns 404 for all requests, blocking the lizmap vhost. Fix:"),
      code("rm -f /etc/nginx/sites-enabled/default\nsystemctl restart nginx"),

      h2("13.10 QGIS_SERVER_LIZMAP_REVEAL_SETTINGS case sensitivity"),
      para("Cause: Setting QGIS_SERVER_LIZMAP_REVEAL_SETTINGS=True (Python-style capitalisation) has no effect. The variable must be exactly TRUE (all uppercase). Fix: use uppercase in both the env file and the supervisor conf environment= line."),
      PB(),

      // ══════════════════════════════════════════════════════════════════════
      // CH 14 — SECURITY CHECKLIST
      // ══════════════════════════════════════════════════════════════════════
      h1("14. Security Checklist"),
      multiTable(
        ["Item", "Status after script", "Action Required"],
        [
          ["Lizmap admin password",   "Default (admin/admin)",  "Change immediately on first login"],
          ["HTTPS / TLS",             "HTTP only (port 80)",    "Install Let's Encrypt via certbot"],
          ["xRDP TLS certificate",    "Self-signed (10 years)", "Replace with CA-signed cert in production"],
          ["PostgreSQL password",     "Auto-generated random",  "Save from install log; restrict pg_hba.conf to specific IPs"],
          ["Firewall (UFW)",          "Enabled — ports 22,80,443,3389", "Review: ufw status verbose"],
          ["QGIS Server access",      "No authentication on /ows/", "Restrict /ows/ in Nginx by IP if needed"],
          ["SSH hardening",           "Default Ubuntu config",  "Disable root login, enforce key-based auth"],
          ["Automatic updates",       "Not configured",         "Enable: apt install unattended-upgrades"],
          ["Lizmap repositories",     "Admin access required",  "Set proper permissions per repository in Lizmap admin panel"],
        ],
        [Math.round(CW*0.3), Math.round(CW*0.25), CW - Math.round(CW*0.3) - Math.round(CW*0.25)]
      ),
    ]
  }]
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync("Lizmap_QGIS_Server_Installation_Guide_v3.docx", buffer);
  console.log("Done: Lizmap_QGIS_Server_Installation_Guide_v3.docx");
}).catch(err => {
  console.error("Error generating document:", err);
  process.exit(1);
});
