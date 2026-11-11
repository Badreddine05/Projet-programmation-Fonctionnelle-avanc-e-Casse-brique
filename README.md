# REBOUND — casse-briques en OCaml

Une refonte du projet de programmation fonctionnelle avancée de 2024 : le moteur est écrit en OCaml, testé en natif et compilé en JavaScript avec **js_of_ocaml**. Le navigateur affiche l'état du même moteur ; il ne possède pas une seconde simulation.

> La refonte du moteur et sa chaîne de compilation sont en cours de validation. Le frontend est développé séparément. La coque présente dans `web/` est provisoire ; aucune démo finale n'est annoncée tant que sa vérification n'est pas terminée.

## Ce qui change

- Cinq niveaux avec des dispositions différentes et des briques à plusieurs points de résistance.
- Trois vies, score, combos, progression et états explicites : menu, préparation, partie, pause, niveau terminé, victoire et défaite.
- Trois difficultés. Deux modes de raquette : classique, avec angle de rebond piloté par le point d'impact ; Héritage, à trois segments séparés comme dans le projet de 2024.
- Simulation déterministe à 120 Hz, indépendante de la fréquence de rafraîchissement. Détection continue des collisions cercle/rectangle avec coins arrondis ; résolution des contacts simultanés et séparation des chevauchements.
- Tests du moteur natif, tests du vrai bridge compilé et construction d'un site statique sans dépendance réseau au runtime.

Les fichiers de 2024 restent disponibles dans `casse_briques 3/`. Leurs auteurs et leurs dates Git ne sont pas modifiés. La refonte ne présente pas le squelette pédagogique ECS/gfx comme du code entièrement écrit par l'auteur du dépôt ; voir [les crédits et notices](NOTICE.md).

## Construire et lancer

La voie de référence est Linux avec [opam](https://opam.ocaml.org/doc/Install.html), OCaml **5.3.0**, Dune **3.20.2**, js_of_ocaml **6.2.0** et Node.js **22 ou plus**. Les versions directes sont fixées dans `rebound.opam`. Le résolveur opam choisit encore certaines dépendances transitives : ce n'est pas une image hermétique complète.

```sh
git clone https://github.com/Badreddine05/Projet-programmation-Fonctionnelle-avanc-e-Casse-brique.git
cd Projet-programmation-Fonctionnelle-avanc-e-Casse-brique
opam switch create . 5.3.0 --no-install
opam install . --deps-only --with-test -y
opam exec -- dune runtest
opam exec -- dune build --profile release web/main.bc.js
node scripts/package.mjs
node test/bridge.test.cjs
python3 -m http.server 8080 --directory dist
```

Ouvrir ensuite `http://localhost:8080`. Le serveur Python ne compile rien : il sert seulement le dossier statique. Un autre serveur HTTP statique convient. Aucun secret, compte, backend ou service distant n'est nécessaire pour jouer.

Sans OCaml local, lancer le workflow **OCaml core and browser bundle** depuis l'onglet Actions. L'artefact `rebound-web` rassemble le site dans `dist/` et la sortie des tests natifs. Il permet de vérifier le vrai programme compilé sur une autre machine. Le workflow ne déploie pas automatiquement le site.

Le packaging utilise uniquement les modules standards de Node. Il copie le moteur généré et les assets déclarés, ajoute les notices et un `build-info.json` avec le commit source et l'heure réelle de construction. Ne pas éditer le JavaScript produit : modifier les sources OCaml puis recompiler.

## Architecture

```text
Entrées clavier / pointeur
           │
           ▼
    web/app.js ── commandes + temps écoulé ──► web/main.ml
           ▲                                     │
           │                                     ▼
           │                               core/game.ml
           │                           états, niveaux, score
           │                                     │
           │                                     ▼
           │                              core/physics.ml
           │                             impacts et rebonds
           │                                     │
           └────────── snapshot JSON ─────────────┘
           │
           ▼
       Canvas + HUD
```

`core/` dépend seulement de la bibliothèque standard OCaml. Une étape reçoit un état immuable, un intervalle de temps et des entrées ; elle produit l'état suivant. Le bridge gère une référence vers l'état courant et expose quatre fonctions. JavaScript s'occupe du rendu, des périphériques et des effets visuels.

La racine Dune ne parcourt que `core`, `web` et `test`. Le projet historique conserve sa propre configuration et ses dépendances SDL dans son dossier ; il n'interfère pas avec la nouvelle compilation web. La version native moderne sert aux tests, pas à une nouvelle interface SDL.

Le contrat détaillé du bridge, les commandes et les exigences du frontend sont dans [FRONTEND_HANDOFF.md](FRONTEND_HANDOFF.md).

## Physique et règles

Le terrain logique mesure 1000 × 640 pixels. Les vitesses sont exprimées en pixels par seconde. Un accumulateur consomme le temps en pas de 1/120 s ; chaque appel est limité à 0,25 s et 30 pas pour éviter une longue reprise après suspension. Une pause ne consomme aucun temps de simulation.

Pour chaque pas, le moteur cherche le premier instant de contact du cercle mobile avec les murs, les raquettes et les briques vivantes. Les faces utilisent une intersection analytique ; les coins utilisent l'intersection avec un cercle. Cette approche évite à la fois la traversée d'une brique à haute vitesse et les faux contacts dans les coins d'un simple rectangle agrandi. Les contacts ayant le même instant sont regroupés. La normale reste définie même quand le centre de la balle est exactement sur un bord ou dans un rectangle.

Après un impact, la balle est légèrement séparée de la surface, les briques touchées perdent un point de résistance et le temps restant est simulé. Le nombre de résolutions est borné à huit par pas. Ce moteur est conçu pour ce casse-briques : il n'est pas un solveur universel de corps rigides et ne simule ni rotation, ni masse, ni rebond entre plusieurs balles.

Le déplacement de la raquette est borné à 740 px/s. La balle accélère légèrement lorsqu'elle frappe une brique, avec un plafond propre à chaque difficulté. Les trous de la raquette Héritage sont réellement traversables.

Le score est déterminé par le moteur : 25 points par point de résistance retiré, puis `75 + 10 × min(combo, 10)` par brique détruite, et 500 points par niveau terminé. Un contact sur le dessus de la raquette ou une vie perdue remet le combo courant à zéro. Les cinq niveaux sont finis, sans génération aléatoire ; les mêmes commandes et intervalles de temps donnent les mêmes résultats.

## Vérifications

`test/core_tests.ml` couvre notamment la collision à haute vitesse, le centre sur un bord, les coins, le contact en séparation, deux murs simultanés, l'équivalence à 30/60/144 Hz, la pause, les vies, les armures, la progression, les angles de raquette, les vrais trous du mode Héritage, les entrées non finies et la limitation des longues frames. Une simulation de 30 000 frames utilise une graine fixe et contrôle les invariants de position, vies et résistance.

`test/bridge.test.cjs` charge le véritable artefact produit par js_of_ocaml, configure une partie, simule 300 frames, vérifie les nombres finis et exerce pause, reprise, menu et réinitialisation. Il ne substitue aucun moteur JavaScript au code OCaml. La CI exécute ces vérifications sur chaque push et pull request, puis fournit le site construit en artefact.

La vérification visuelle et les interactions de la nouvelle interface doivent être complétées après intégration du frontend. Une réussite des tests du moteur ne constitue pas une validation d'accessibilité ou de navigation mobile.

## Présenter ce projet en entretien

- Expliquer le défaut initial de normalisation d'un vecteur nul et montrer le test d'un centre exactement sur un bord.
- Comparer une détection après déplacement à la recherche d'un instant de collision : une balle rapide peut traverser une brique dans le premier cas.
- Justifier le pas fixe : une vitesse en pixels par frame accélère le jeu sur un écran à 144 Hz ; une vitesse en pixels par seconde et un accumulateur conservent les règles.
- Montrer la séparation modèle/rendu et le même core utilisé par les tests natifs et le navigateur.
- Présenter les limites sans les masquer : cinq niveaux écrits à la main, une balle, raquette déplacée à chaque pas, résolution bornée et projet historique conservé séparément.

## Licence et historique

Le nouveau code dispose d'une [licence MIT dont la portée est explicitée](LICENSE-new-code.txt). Les fichiers historiques, le rapport et l'archive ne sont pas requalifiés par cette licence. Les notices OCaml et js_of_ocaml sont conservées à l'identique dans `licenses/` et distribuées avec le bundle. Le code original date de 2024 ; les améliorations actuelles portent leurs dates réelles de commit.
