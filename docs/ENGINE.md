# Notes techniques du moteur

Ces notes complètent le contrat [FRONTEND_HANDOFF.md](../FRONTEND_HANDOFF.md). Elles ne décrivent pas l'état d'avancement de l'interface.

## Trajectoires et collisions

`Physics.sweep_circle_rect` cherche l'instant du premier contact d'un cercle en translation avec un rectangle fixe. Les faces planes et les quatre coins arrondis sont traités séparément. Le calcul est purement géométrique et ne contient ni score, ni effet visuel. Les rectangles fournis doivent être finis et avoir des dimensions positives ; les rectangles du jeu sont des constantes internes. Les entrées non finies de position, vitesse, rayon ou durée sont rejetées.

Les rebonds simultanés sont résolus comme un ensemble. Pour chaque normale de contact `n`, le solveur cherche une vitesse sortante satisfaisant `n · sortie ≥ max(0, −n · entrée)`. Il choisit la plus petite impulsion admissible en examinant les contraintes actives seules et par paires. Un tri canonique des normales rend ce calcul indépendant de l'ordre de stockage des briques. Deux coins symétriques renvoient une balle verticale verticalement ; deux murs orthogonaux inversent ses deux composantes. Des chevauchements incompatibles peuvent ne pas admettre de solution élastique : un repli déterministe sur la normale la plus approchée s'applique alors.

Le jeu applique aussi ses règles : rebond dirigé sur le dessus d'une raquette, accélération sur les briques et plafond de vitesse. Une composante verticale minimale de **16 % de la vitesse** est recherchée après les contacts. Sans cette règle d'arcade, un rebond sur un coin arrondi peut produire une trajectoire parfaitement horizontale et laisser la balle aller indéfiniment d'un mur à l'autre sous les dernières briques. La norme de la vitesse est conservée par cette correction ; seule la direction change. Le signe vertical courant est essayé d'abord (vers le haut s'il est nul), puis le signe inverse. Le candidat doit rester sortant par rapport à **toutes** les normales du groupe ; sinon la réflexion physique est conservée. Cela évite de réentrer immédiatement dans la même brique blindée. Cette règle appartient à `Game`, pas à la primitive de collision.

Le moteur intègre au maximum huit contacts par pas de 1/120 s. Si cette limite est atteinte dans une configuration pathologique, le temps restant de ce pas est abandonné. Une séparation de 0,001 px et une réduction de temps de 0,0000001 s après chaque contact évitent de retraiter indéfiniment le même instant. Il s'agit de tolérances numériques explicites.

La raquette se déplace avant le calcul des collisions de chaque pas. Son mouvement est borné à 740 px/s ; sa collision utilise sa position à cet instant, sans balayage de la trajectoire complète de la raquette. La balle bénéficie d'un balayage continu. Cette limite est distincte de la correction des rebonds et reste à considérer si la vitesse de la raquette est modifiée.

## État et reproductibilité

Le core ne consulte aucune horloge ni générateur aléatoire. Le temps arrive comme argument de `advance`. Les records sont immuables ; leur représentation reste exposée dans `game.mli` pour créer des scénarios de test précis, mais le bridge ne permet pas d'injecter un état arbitraire depuis JavaScript.

Une égalité du temps total ne suffit pas à garantir le même résultat si les entrées changent à des instants différents. Le test 30/60/144 Hz compare une seconde avec les mêmes entrées constantes et vérifie la position, les ticks et le score. Le test de 30 000 frames utilise un générateur OCaml initialisé avec une graine fixe ; il contrôle des invariants sans prétendre explorer tous les états possibles.

Les événements du snapshot ne constituent pas un journal exhaustif. L'interface doit comparer les vies, phases et résistances des briques entre deux snapshots pour produire ses effets, car plusieurs collisions peuvent survenir pendant un seul appel de `step`.
