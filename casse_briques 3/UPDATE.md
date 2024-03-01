# Mise à jour avec du graphisme

La mise à jour se fait en plusieurs étapes par rapport au 
[code du TP3](https://www.lri.fr/~kn/teaching/ppfa/tp03/ppfa_l3_info_tp03_answers.zip)

### 1 Ajout d'un type plus complexe pour représenter les textures

On ajoute le module `src/utils/texture.ml` qui contient un type `t`. Ce dernier comporte maintenant deux cas simples:

- une couleur (comme avant)
- une surface (qui représente une image fixe)

Il est possible de l'enrichir, par exemple avec un cas :
```
type t = ... (* autre cas *)
 | Animation of {
    frames : Gfx.surface array;
    mutable current : int;
 }
```
où chaque case du tableau est une image indépendante et `current` est l'indice du tableau auquel on est, i.e. la *frame* courante dans l'animation.

### 2 Mise à jour de `src/component_defs.ml`

Les objets n'ont maintenant plus une propriété `color` trop basique mais une propriété `texture` qui est l'un de cas prévu dans le type `Texture.t`.

### 3 Mise à jour de `src/systems/draw_system.ml`

Permet de dessiner l'image sur la fenêtre (avant on dessinait juste un rectangle
de couleurs).


### 4 Création de `utils/surface_manager.ml/.mli`

La gestion des images est un peu complexe. En effet, l'API de la bibliothèque `Gfx` impose de procéder en plusieurs étapes:

- charger la ressource (nom de fichier ou URL) contenant l'image. On obtient ainsi une valeur du type `Gfx.surface Gfx.resource`.
- interroger à intervale répété la ressource avec `Gfx.resource_ready` qui renvoie `true` lorsque la ressource est disponible
- extraire la ressource avec `Gfx.get_resource` quand elle est disponible.

Le module `Surface_manager` permet de charger une collection d'images puis de tester lorsqu'elles sont *toutes* disponibles.


### 5 Modification du `src/gamle.ml`

Dans le programme principal, on apporte les modifications suivantes:
 - chargement des fichiers d'images dans le `surface_manager`. On ne charge qu'une image mais on pourrait en rajouter plusieurs dans la liste.
 - utilisation de ces images dans les constructeurs des rochers
 - écriture d'une fonction qui attends que toutes les images soient disponibles.
 - écriture d'une fonction auxiliaire qui prend en argument une liste de
   fonctions telles qu'attendues individuellement par `Gfx.main_loop` et les
   exécutes les unes à la suite des autres, passant à la suivante dès que la
   fonction courante renvoie false.

### 6 Ajout de fichier d'image
Un fichier `rock.png`. Est ajouté au répertoire `resources/images`. Ce fichier a été trouvé sur [OpenGameArt](https://opengameart.org/).



