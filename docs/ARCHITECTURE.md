# Architecture, physique et vérifications

Les notes détaillées sur les trajectoires, les collisions et la reproductibilité sont dans [ENGINE.md](ENGINE.md).

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

Le contrat détaillé du bridge, les commandes et les exigences du frontend sont dans [FRONTEND_HANDOFF.md](../FRONTEND_HANDOFF.md).

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
