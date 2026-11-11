# Construire et lancer REBOUND

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
