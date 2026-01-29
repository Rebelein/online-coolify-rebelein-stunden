---
description: Erstellt ein neues Release durch Erhöhen der App-Version und des Service-Worker-Caches
---

Um ein Update technisch sauber durchzuführen, müssen Version und Cache aktualisiert werden.

1.  **Version erhöhen (`package.json`)**:
    - Lese die aktuelle Version in `package.json`.
    - Erhöhe die Patch-Version (z.B. 1.1.10 -> 1.1.11).

2.  **Cache aktualisieren (`public/sw.js`)**:
    - Lese `public/sw.js`.
    - Suche nach `const CACHE_NAME = 'zeiterfassung-vXX';`.
    - Erhöhe die Nummer (z.B. v62 -> v63).
    - **Wichtig**: Das Ändern dieser Datei zwingt den Browser, das Update zu erkennen.

3.  **Git Commit** (optional, aber empfohlen):
    - `git add package.json public/sw.js`
    - `git commit -m "chore: release v1.1.X"`
    - `git push`

Anschließend wird der Deployment-Prozess (z.B. via Coolify/GitHub Actions) das Update ausrollen. Durch den geänderten SW-Cache wird die Update-Meldung beim Client erscheinen.
