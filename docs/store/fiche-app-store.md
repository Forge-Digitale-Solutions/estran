# Estran — App Store product page (fr-FR)

Prepared 2026-11-13. Primary language: French (France). Keyword demand checked
with OpenSEO (Google France volumes, used as a proxy for App Store intent):
« marée arcachon » 18 100/month (KD 4), « horaire marée arcachon » 8 100,
« météo marine arcachon » 6 600, « baïnes » 5 400, « grande marée » 2 400,
« marnage » 2 400, « marée pointe de grave » 210, « marée le verdon » 260.

Every claim below matches the app (AGENTS.md invariants): no « Oui » for
swimming, never « officiel » / « SHOM », no coefficient (not shown in the app),
no location request, no data collected.

## Fields

| Field | Limit | Value | Length |
|---|---|---|---|
| Name | 30 | `Estran – Marées Arcachon Médoc` | 30 |
| Subtitle | 30 | `Pêche à pied, surf et bateau` | 28 |
| Keywords | 100 | `horaire,météo,marine,houle,vent,baignade,baïnes,balade,marnage,bassin,médoc,verdon,grave,plage` | 94 |
| Primary category | — | Météo | |
| Secondary category | — | Sports | |
| Age rating | — | 4+ (no objectionable content; answer « Aucun » everywhere) | |
| Price | — | Gratuit, no in-app purchase | |
| Copyright | — | `2026 EI Anthony Marcelin` | |
| Privacy policy URL | — | https://forgedigitalesolutions.com/estran/confidentialite/ | |
| Support URL | — | https://forgedigitalesolutions.com/estran/assistance/ | |
| Marketing URL | — | (optional) https://forgedigitalesolutions.com/estran/ if the page exists | |
| App Privacy | — | « Aucune donnée collectée » | |

Words already in the name or subtitle (marée, arcachon, pêche, pied, surf,
bateau) are left out of the keyword field: Apple indexes them already.
« Soulac » and « coefficient » are deliberately absent — not a spot, not shown.

## Promotional text (170, editable without review)

> Une marée basse, un vent qui tombe, une houle qui se lève : Estran te dit si c'est le bon moment pour sortir, à la Pointe de Grave et à Arcachon.

(145 characters)

## Description (4 000)

> **C'est un bon moment pour sortir ?**
>
> Estran répond en un coup d'œil, pour cinq sorties sur deux spots : la Pointe de Grave, dans le Médoc, et Arcachon-Eyrac, dans le Bassin.
>
> **Une réponse, pas un tableau de chiffres**
> Pêche à pied, surf, bateau, balade : Estran croise la marée, le vent, la houle, la pluie et la lumière du jour, et te répond Oui ou Non, avec la raison. « Vent trop fort », « coefficient trop faible », « pluie » : tu sais tout de suite pourquoi.
>
> **Le prochain bon créneau**
> Pas maintenant ? Estran cherche le prochain moment favorable dans les 48 heures et te dit quand y aller. S'il n'y en a pas, il te dit pourquoi.
>
> **La baignade, sans fausse promesse**
> Pour la baignade, Estran ne dit jamais « Oui ». Il donne un niveau de courants de marée estimé et rappelle, toute l'année, le danger des baïnes. L'app ne voit ni les baïnes, ni les maîtres-nageurs : baigne-toi entre les drapeaux.
>
> **Les marées, calculées sur ton iPhone**
> Hauteur d'eau, marée qui monte ou descend, prochaine basse mer, marnage du jour et grande marée : tout est calculé sur l'appareil, à partir d'un modèle local ajusté sur les observations REFMAR (Shom, Licence Ouverte 2.0). Pas de réseau nécessaire pour la marée.
>
> **Pensé pour iOS 27**
> • Liquid Glass partout, fond océan animé
> • Widgets sur l'écran d'accueil et l'écran verrouillé, réglables par spot et par activité
> • Live Activity et Dynamic Island pendant un bon créneau
> • Siri, Raccourcis et Spotlight : « Je peux faire du surf à la Pointe de Grave avec Estran ? »
> • Alertes une heure avant un bon créneau, jamais la nuit
> • VoiceOver, texte très grand et Réduire les animations pris en charge
>
> **Honnête par principe**
> Une donnée manque ? Estran affiche « — » ou « Données indisponibles », jamais un chiffre inventé. Le surf n'est proposé que là où l'on surfe. Les passes du Bassin sont toujours signalées comme dangereuses.
>
> **Gratuit, sans compte, sans pub**
> Aucune donnée collectée, aucune position demandée : la météo est celle du spot choisi (Apple Météo, Open-Meteo).
>
> Estran est un outil d'aide à la décision. Son modèle de marée n'est pas officiel et ne remplace pas les documents nautiques officiels ni les consignes locales de sécurité.

(≈ 2 300 characters)

## What's new (version 1.0.0)

> Première version d'Estran : cinq sorties, deux spots, des réponses claires et des widgets réglables.

## Screenshots (6.9" iPhone 18 Pro Max and 6.3" iPhone 18 Pro, fr-FR)

Six frames, real model data (Release build, not the « Données d'exemple »
badge), short caption above each:

1. **« C'est le bon moment ? »** — Home, Pointe de Grave, Surf, a big « Oui ».
2. **« Et si c'est non, tu sais pourquoi »** — Home, Bateau « Non · Vent trop fort » + prochain créneau.
3. **« La marée, d'un doigt »** — Spot detail, tide chart with the scrub callout and the marnage line.
4. **« La baignade, sans fausse promesse »** — Home, Baignade: risk level + baïnes warning.
5. **« Tes spots, sur ton écran »** — Home Screen with the large and medium widgets + Lock Screen widgets.
6. **« Pendant le créneau »** — Live Activity on the Lock Screen / Dynamic Island.

## App Review notes (English)

> Estran is a French-only, free app with no account and no data collection. It answers « is it a good time to go out? » for five coastal activities on two fixed spots in France (Pointe de Grave and Arcachon-Eyrac).
> - Swimming deliberately never shows « Oui »: it shows an estimated tidal-current risk level with a permanent rip-current (baïnes) warning.
> - Tide predictions are computed on device from a local harmonic model fitted on open REFMAR observations (Licence Ouverte 2.0); the app states it is not an official source.
> - Weather: Apple WeatherKit for the spot's fixed coordinates, Open-Meteo as fallback. The app never requests the user's location.
> - Surf is only offered where people surf (not at Arcachon-Eyrac).
> - Widgets and the Live Activity read a snapshot written by the app; no login, no demo account needed.
