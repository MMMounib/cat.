# cat

**Addon serveur Garry's Mod pour l'anti-ESP, la vérification des scripts et la capture d'écran.**

Cat est un outil de modération simple et autonome.

Il permet aux administrateurs de :

- protéger les joueurs contre les ESP grâce au filtrage réseau ;
- vérifier les fichiers présents dans le dossier Garry's Mod d'un joueur ;
- demander une capture de ce que le joueur voit dans le jeu ;
- consulter les actions effectuées avec Cat.

L'interface est directement accessible en jeu et reste volontairement simple.

Compatible avec DarkRP, TTT, Sandbox et les gamemodes personnalisés.

---

## Fonctionnalités

### Anti-ESP

L'anti-ESP est la fonction principale de Cat.

Le serveur décide quelles informations doivent être transmises à chaque joueur. Lorsqu'un joueur ne peut pas être vu, son entité peut être masquée côté réseau afin qu'un ESP ne puisse pas simplement récupérer sa position.

Le système utilise notamment :

- la distance ;
- le PVS de Garry's Mod ;
- un cache des mouvements ;
- des vérifications de visibilité lorsque c'est nécessaire ;
- un délai de masquage pour éviter les changements brusques ;
- une anticipation des mouvements pour limiter les apparitions tardives.

Les décisions importantes sont prises côté serveur.

Le système est conçu pour rester utilisable sur des serveurs pouvant atteindre environ 128 joueurs.

### Vérification des scripts

Un administrateur peut analyser les fichiers accessibles dans le dossier Garry's Mod du joueur.

Les fichiers peuvent être signalés lorsqu'ils correspondent à une signature connue, par exemple :

- ESP ;
- API de cheat ;
- script suspect ;
- fichier anormalement volumineux.

Le contenu d'un fichier peut ensuite être consulté directement dans le menu.

Un fichier signalé n'est pas considéré comme une preuve de triche. Cat sert à faciliter la vérification manuelle par l'administrateur.

### Capture

Un administrateur peut demander une capture de ce que le joueur voit dans Garry's Mod.

La capture :

- concerne uniquement le rendu du jeu ;
- est enregistrée côté serveur ;
- ne capture pas le bureau ni les autres applications ;
- peut être consultée depuis le menu Cat.

La capture reste un outil complémentaire. Un cheat capable de modifier son rendu spécifiquement pour éviter une capture peut ne pas apparaître sur celle-ci. L'anti-ESP protège alors en amont en limitant les informations envoyées au client.

### Logs

Cat peut conserver un historique des actions importantes :

- analyses ;
- captures ;
- modifications de configuration ;
- actions des administrateurs.

Les logs sont uniquement destinés au suivi et au dépannage.

---

## Installation

Placez le dossier `cat` dans :

```text
garrysmod/addons/
```

Vous devez obtenir une structure similaire à :

```text
garrysmod/
└── addons/
    └── cat/
        └── lua/
            └── autorun/
                └── cat_init.lua
```

Configurez ensuite les administrateurs autorisés dans :

```text
lua/cat/sv_config.lua
```

Exemple :

```lua
admins_autorises = {
    ["76561198XXXXXXXXX"] = true,
}
```

Remplacez le SteamID64 d'exemple par celui des administrateurs concernés.

Aucune dépendance externe n'est nécessaire.

Redémarrez ensuite le serveur.

Cat crée automatiquement les dossiers dont il a besoin dans `data/cat/`.

---

## Utilisation

Les administrateurs autorisés peuvent ouvrir Cat avec :

```text
!cat
```

ou depuis la console :

```text
cat_menu
```

Le menu contient quatre sections :

- **Anti-ESP**
- **Vérification**
- **Capture**
- **Logs**

Chaque section reste volontairement limitée à ce qui est nécessaire.

---

## Configuration

Les principaux réglages de l'anti-ESP sont disponibles depuis Cat ou via les ConVars du serveur.

| ConVar | Défaut | Description |
|---|---:|---|
| `cat_actif` | `1` | Active l'anti-ESP |
| `cat_distance_proche` | `350` | Distance en dessous de laquelle les joueurs restent visibles |
| `cat_distance_max` | `0` | Distance maximale de transmission, `0` pour désactiver |
| `cat_delai_masquage` | `0.6` | Délai avant de masquer un joueur |
| `cat_anticipation` | `0.15` | Anticipe légèrement les mouvements |
| `cat_props_bloquent` | `0` | Utilise les props et les portes pour déterminer la visibilité |
| `cat_traces_par_tick` | `120` | Nombre maximal de vérifications de visibilité par tick |

Les réglages plus sensibles, comme les administrateurs autorisés, les signatures et la conservation des captures, restent dans `sv_config.lua`.

Pour vérifier rapidement le fonctionnement de l'anti-ESP :

```text
cat_stats
```

---

## Sécurité

Cat effectue les contrôles importants côté serveur.

- Les permissions sont vérifiées avec une whitelist SteamID64.
- Les clients ne peuvent pas décider de leurs propres permissions.
- Les messages réseau sont vérifiés côté serveur.
- Les chemins de fichiers sont contrôlés.
- Les transferts importants sont limités et envoyés par morceaux lorsque nécessaire.
- Aucun secret n'est placé dans le code client.
- Les fonctions d'administration ne sont accessibles qu'aux personnes autorisées.

---

## Limites

Cat ne cherche pas à détecter tous les types de cheats.

Il ne s'agit pas d'un système de détection d'aimbot, de bhop ou de speedhack.

La vérification des scripts repose sur les fichiers auxquels Garry's Mod permet d'accéder. Un fichier inconnu ou chiffré peut donc ne pas être identifié.

La capture montre le rendu de Garry's Mod au moment où elle est effectuée. Elle ne permet pas de garantir qu'un cheat ne modifie pas son affichage pour la masquer.

L'anti-ESP reste donc la protection principale.

---

## Licence

Cat est distribué sous licence **MIT**.

Vous pouvez l'utiliser, le modifier et le redistribuer librement, y compris dans un projet commercial.

Voir le fichier `LICENSE` pour les conditions complètes.
