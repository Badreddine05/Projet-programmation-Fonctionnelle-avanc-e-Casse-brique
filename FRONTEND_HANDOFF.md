# REBOUND — passage au frontend

Le frontend et le moteur sont développés séparément. Le moteur, ses tests et le bridge relèvent de l'équipe moteur ; le rendu et les contrôles relèvent de l'équipe interface. La coque actuelle est minimale et n'est pas un rendu final. Aucun fichier historique de `casse_briques 3/` n'a été réécrit. La nouvelle démo doit utiliser le moteur OCaml compilé ; aucune physique parallèle en JavaScript n'est nécessaire.

## Fichiers à reprendre

- `web/index.html`, `web/style.css`, `web/app.js`, `web/favicon.svg` : interface, rendu Canvas, contrôles, sons facultatifs et effets visuels. Ces quatre fichiers sont réservés à l'équipe interface après le commit `fda3803` pour éviter les écrasements.
- `web/main.ml` : bridge maintenu par l'équipe moteur. Ne pas remplacer par une simulation JavaScript.
- `core/` et `test/core_tests.ml` : modèle OCaml et tests natifs maintenus par l'équipe moteur.
- `scripts/package.mjs` copie les quatre fichiers frontend et le vrai `_build/default/web/main.bc.js` dans `dist/`, ainsi que les notices depuis `licenses/`. Les nouveaux assets doivent être déclarés dans ce script ou placés dans un dossier explicitement copié ; coordonner cette modification.
- `dist/` et `_build/` sont générés, ignorés par Git. Ne pas y développer directement.

La CI compile avec OCaml 5.3.0, Dune 3.20.2 et js_of_ocaml 6.2.0. L'artefact `rebound-web` contient `dist/` et le résultat des tests. Un bundle peut être récupéré par root pour vérifier l'interface sur Windows sans installer OCaml localement.

## Chargement et API

Charger `game.bc.js` **avant** `app.js` avec deux scripts `defer` classiques. Le bridge exporte `globalThis.BreakoutCore` dans le navigateur. Dans Node, l'objet est sous `require('./game.bc.js').BreakoutCore`. Les quatre méthodes renvoient une **chaîne JSON**, à passer à `JSON.parse`.

```js
const core = globalThis.BreakoutCore;
if (!core) {
  // Afficher un vrai état d'échec de chargement et désactiver Jouer.
}
const initial = JSON.parse(core.snapshot());
const configured = JSON.parse(core.configure('normal', 'solid'));
const ready = JSON.parse(core.command('start'));
const playing = JSON.parse(core.command('launch'));
// secondes réelles entre deux requestAnimationFrame, pas nombre de frames
const frame = JSON.parse(core.step(deltaSeconds, axis, pointerX));
```

| Méthode | Entrées | Effet |
| --- | --- | --- |
| `snapshot()` | aucune | Lecture de l'état courant, sans mutation. |
| `configure(difficulty, mode)` | `calm`, `normal`, `expert` ; `solid`, `split` | Nouvelle partie remise au menu, score et progression effacés. Valeurs inconnues : normal/solid. |
| `command(name)` | commande ci-dessous | Transition autorisée ; commande inconnue ou invalide dans l'état courant : aucun effet. |
| `step(dt, axis, pointerX)` | secondes, axe entre −1 et +1, coordonnée horizontale du pointeur dans le terrain logique | Avance la simulation. `NaN` comme pointeur active les commandes clavier. Un pointeur fini a priorité sur l'axe. |

Le terrain logique mesure **1000 × 640** ; le redimensionnement du Canvas n'affecte pas la physique. Convertir le pointeur depuis son rectangle d'affichage vers ces coordonnées. Les positions désignent le centre de la balle, le coin supérieur gauche des briques et la gauche de la raquette. Les murs intérieurs sont à `x=24`, `x=976` et `y=24` ; le bas reste ouvert. La raquette suit la cible avec une vitesse maximale : elle ne se téléporte pas.

Le moteur accumule le temps en pas fixes de **1/120 s**, bornant chaque appel à 0,25 s. En arrière-plan, suspendre les appels et remettre l'horodatage de la boucle à zéro au retour. Le moteur ne lit ni clavier, ni DOM, ni horloge globale.

## États et commandes

| État `phase` | Sens et actions disponibles |
| --- | --- |
| `menu` | Aperçu initial. Choix difficulté/mode, puis `start`. |
| `ready` | Balle posée sur la raquette. Déplacement autorisé ; `launch` pour lancer. Apparaît aussi après perte d'une vie. |
| `playing` | Jeu actif. `pause` ou `toggle_pause`. |
| `paused` | Temps et positions gelés. `resume` ou `toggle_pause`. |
| `level_clear` | Niveau terminé. `next` conserve vies et score puis prépare le niveau suivant. |
| `won` | Cinquième niveau terminé. Résumé et `restart` ou `menu`. |
| `lost` | Plus de vie. Résumé et `restart` ou `menu`. |

`restart` ou `start` réinitialise la campagne au niveau 1, trois vies et zéro point en conservant les options. `menu` quitte la partie active ; l'état courant demeure visible en aperçu jusqu'au prochain `start`. La pause n'est valide que pendant `playing`. Les overlays d'aide/options doivent appeler `pause` avant de s'ouvrir si une balle est en jeu. Sur `blur` / `visibilitychange`, effacer les touches maintenues et mettre en pause ; ne pas reprendre automatiquement au retour.

## Contrat du snapshot

```js
{
  engine: 'ocaml', version: '1.0.0',
  phase: 'ready', difficulty: 'normal', mode: 'solid',
  level: 1, levelCount: 5, lives: 3,
  score: 0, combo: 0, bestCombo: 0, broken: 0,
  paddleX: 428, paddleWidth: 144, paddleY: 586,
  ball: {x: 500, y: 573, vx: 0, vy: 0, radius: 8},
  elapsed: 0, tick: 0, event: 'start',
  bricks: [{id: 0, x: 62, y: 92, w: 78, h: 24, hp: 1, maxHp: 1, color: 0}]
}
```

- `level` va de 1 à 5. Noms suggérés pour l'interface : Prise d'élan, Décalage, Onde, Bastion, Dernière orbite.
- `elapsed` compte seulement les secondes réellement simulées en `playing`. `tick` compte aussi les déplacements en `ready` ; ne pas le présenter comme un temps de jeu.
- Les briques détruites restent dans la liste avec `hp: 0` : ne pas les dessiner. `maxHp` vaut de 1 à 3. `color` est un index de palette 0 à 4, pas un code CSS. L'identifiant est unique dans un niveau ; inclure le niveau si utilisé comme clé de particules.
- `combo` compte les briques détruites entre deux rebonds sur le dessus de la raquette. Un contact sur le dessus de la raquette ou une vie perdue le remet à zéro. `bestCombo` et `broken` concernent toute la campagne.
- `event` est un signal **indicatif du dernier événement traité** dans l'appel : chaîne vide, `start`, `launch`, `pause`, `resume`, `next`, `menu`, `brick`, `armor`, `paddle`, `wall`, `clear`, `life`. Ce n'est pas une file d'événements complète : plusieurs collisions peuvent se produire dans un appel. Comparer deux snapshots pour les particules de briques et transitions de vies/niveau, plutôt que supposer que chaque événement est livré une fois.
- Les seules données conservées par le moteur sont en mémoire. Un record local facultatif peut être stocké par l'interface, séparé par difficulté et mode ; ne pas inventer de classement mondial ou de joueurs en ligne.

## Mécaniques à rendre visibles

Trois vies, cinq dispositions de briques, armures à partir du niveau 3, vitesse progressive et bonus de niveau. Le mode classique utilise une seule raquette (176/144/118 px selon difficulté) et l'angle du rebond dépend du point de contact. Le mode **Héritage · 2024** reprend l'idée du projet original : trois segments de 40, 60 et 40 px, séparés par deux espaces de 30 px. Dessiner les segments à `paddleX`, `paddleX+70`, `paddleX+160`, hauteur 14 px. Les deux trous sont réels et peuvent laisser passer la balle ; les segments extérieurs renvoient respectivement à gauche et à droite. `paddleWidth: 200` est l'enveloppe totale, pas une barre pleine.

Score : 25 points par point d'armure retiré, plus `75 + 10 × min(combo, 10)` par brique détruite, et 500 points par niveau terminé. Les contacts simultanés utilisent le combo après destruction du groupe. Le HUD doit afficher la valeur OCaml, sans recalculer le score.

## Interface et QA attendues

Prévoir menu, choix difficulté/mode, lancement explicite, pause/reprise, recommencer, retour menu, fin de niveau et fin de campagne. Clavier : flèches ou A/D ; espace pour lancer ; P/Échap pour pause. Ignorer `event.repeat` pour les actions instantanées. Ne pas intercepter les raccourcis quand la cible est un champ/bouton de dialogue. Effacer la cible souris quand le clavier reprend le contrôle.

Pour le tactile : `touch-action: none` seulement sur la zone de contrôle, pointer capture pendant un geste, coordonnées relatives au Canvas. Garder la page défilable ailleurs. Un contrôle de raquette accessible au clavier (curseur ou boutons maintenus) complète le Canvas ; donner un nom accessible au terrain et exposer vies/score/état dans le DOM. N'annoncer via `aria-live` que les transitions utiles, pas chaque frame. Gérer focus des menus et boutons.

Les effets de traînée, particules, son et secousse restent purement visuels ; ils ne modifient jamais les snapshots. Respecter `prefers-reduced-motion` pour les effets et transitions, sans modifier la vitesse réelle du jeu. Les sons éventuels doivent être désactivables et créés après interaction humaine. Aucune image ancienne à provenance inconnue n'est nécessaire : les formes Canvas suffisent.

Vérifier en vrai navigateur à 1440 px et 390 px : première partie, déplacement clavier/tactile, pause immobile, vie perdue puis relance, redémarrage, sélection des deux modes, état d'erreur si bundle absent, absence de débordement, focus clavier et animations réduites. Les assertions de physique sont dans le core natif et le bridge compilé, pas dans un faux moteur de test JavaScript.
