# Estran

**« C'est un bon moment pour sortir ? »** — une app iOS 27 qui répond **Oui /
Non** pour cinq activités côtières sur le bassin d'Arcachon et le Médoc. Tout
est calculé sur l'appareil : pas de compte, pas de serveur, pas de pub, pas
d'abonnement. Interface en français.

🇬🇧 **[English version](README.md)**

---

## Ce que fait l'app

Choisis une activité, obtiens un verdict pour le spot où tu es, avec le prochain
bon créneau et les quatre conditions qui l'ont produit.

| | |
|---|---|
| **Activités** | pêche à pied · surf · bateau · balade · baignade |
| **Spots (v1)** | Arcachon-Eyrac (jauge 190) · Pointe de Grave / Le Verdon (jauge 15) |
| **Écrans** | Maintenant · Spots (carte focus) · Alertes · Réglages |

Deux spots seulement, et c'est volontaire : un verdict n'est rendu que là où le
modèle de marée est validé contre une jauge réelle. Les 12 autres spots de la
côte restent une feuille de route post-v1, pas un catalogue caché.

Tout est calculé **sur l'appareil** :

- **la marée** — un modèle harmonique ajusté sur les observations REFMAR
  ouvertes, embarqué sous forme de constantes (aucun appel d'API de marée au
  runtime, fonctionne hors ligne) ;
- **la météo** — Apple WeatherKit (vent, température, précipitations,
  visibilité) ;
- **la houle** — Open-Meteo Marine (hauteur et période).

Pas de compte, pas de mesure d'audience, pas de SDK tiers, pas de backend.

**La baignade n'est pas une permission.** Dans le bassin comme sur la côte
médocaine, l'eau est dangereuse toute l'année, quel que soit le temps. La
baignade est présentée comme un **niveau de risque**, avec un avertissement
permanent sur les baïnes et les courants — jamais un « Oui » vert. Détail dans
[`ARCHITECTURE_PLAN.md` §7.3](ARCHITECTURE_PLAN.md).

## État

| Jalon | État |
|---|---|
| **M0 — Setup** | fait |
| **M1 — Moteur + dataset de marée** | fait — schema 6, 3 stations × 25 constituants, 2 spots jaugés |
| **M2 — Météo** | **pas commencé** — WeatherKit et Open-Meteo Marine |
| **M3 — UI** | écrite, **jamais compilée sur macOS** |
| **M4 — Intelligence** | pas commencé — Foundation Models, Siri, notifications |
| **M5 — Widgets / Live Activity** | vues écrites, données non branchées |

Points utiles pour une release :

- `u_t` et `u_h` sont par station et calculés en **leave-one-year-out** (la pire
  année de la série, pas une année de test) ;
- le dataset de marée est valide jusqu'en **2029** ; il est régénéré une fois
  par an comme maintenance, pas comme une date de péremption produit ;
- le coefficient national de Brest est calculé mais **non validé et non
  affiché** ; il ne pilote aucune décision de sécurité ;
- `EstranCore` sous Linux : **164 tests, 0 échec**, SwiftFormat propre.

L'hôte Linux n'a pas de SDK Apple : la couche SwiftUI n'est que parsée. Tout
build, test et archive Apple est **en attente** tant que ça n'a pas tourné sur
macOS ou en CI.

## Prérequis

- macOS avec Xcode 26+ et le SDK iOS 27 ;
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — le `.xcodeproj` est généré
  depuis `project.yml` et n'est pas versionné ;
- SwiftLint et SwiftFormat pour le style ;
- Swift 6 pour les checks Linux du package.

## Build

```sh
brew install xcodegen
xcodegen generate
open Estran.xcodeproj
```

Checks :

```sh
./scripts/check-linux.sh          # build + tests EstranCore
./scripts/check-macos.sh          # XcodeGen, xcodebuild build/test, lint
./scripts/check-macos.sh --archive
```

Signature, App Group, capability WeatherKit et TestFlight sont documentés pas à
pas dans [`BUILD.md`](BUILD.md).

## Le modèle de marée

La marée n'est pas récupérée au runtime. `scripts/tides/refresh` télécharge les
observations REFMAR (Licence Ouverte 2.0), lance une analyse harmonique aux
moindres carrés sur 25 constituants, fait le contrôle qualité, et écrit les
constantes plus un rapport de précision. L'app embarque ces constantes et
prédit localement.

Mesuré contre les jauges sur l'année tenue à l'écart
(`docs/data-sourcing/accuracy-2026.1.md`) : RMSE ≈ 0,16 m, médiane des horaires
d'événement ≈ 10 min, p95 ≈ 32 min. Les enveloppes d'incertitude sont
dimensionnées sur la pire année de la série, pas sur la moyenne.

## Arborescence

```
Estran/                 Cible app (SwiftUI)
EstranWidgets/          Extension WidgetKit, Live Activity, Dynamic Island
Packages/EstranCore/    Domaine : modèles, moteur de marée, règles, dataset
EstranTests/            Tests unitaires de l'app
EstranUITests/          Tests UI
scripts/                Checks locaux + générateur de marée
docs/                   Rapports de sourcing et de précision
project.yml             Définition XcodeGen
```

## Documentation

| Fichier | Contenu |
|---|---|
| [`ARCHITECTURE_PLAN.md`](ARCHITECTURE_PLAN.md) | source de vérité technique |
| [`DESIGN_REFERENCE.md`](DESIGN_REFERENCE.md) | spec UI extraite du fichier Figma |
| [`BUILD.md`](BUILD.md) | build, signature, TestFlight, refresh annuel |
| [`worksplit.md`](worksplit.md) | contrat de jalons et critères d'acceptation |
| [`review.md`](review.md) | historique des revues (points bloquants et leur fermeture) |
| [`docs/data-sourcing/`](docs/data-sourcing/) | rapport de sourcing et précision mesurée |

## Identifiants

- App : `com.forgedigitale.estran`
- Extension widget : `com.forgedigitale.estran.widgets`
- App Group : `group.com.forgedigitale.estran`

Aucun secret, clé d'API, certificat ou profil de provisionnement n'est versionné.

## Données et attribution

Observations de marée : **REFMAR / Shom**, Licence Ouverte 2.0. Les constantes
sont notre propre ajustement harmonique — « modèle local », jamais une
prédiction du SHOM, jamais des « données officielles ». Météo : Apple
WeatherKit. Houle : Open-Meteo.

## Licence

La licence du code **n'est pas décidée**. Le dépôt est privé et aucun fichier de
licence n'est fourni ; il faudra en choisir une avant de le rendre public.
L'attribution des données ci-dessus s'applique quoi qu'il arrive.
