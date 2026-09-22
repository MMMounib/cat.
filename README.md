# cat

**Petit addon serveur pour Garry's Mod : anti-ESP + vérification des scripts + capture d'écran.**

`cat` est un outil de modération léger, sobre et autonome. Il fait trois choses, bien, et rien d'autre : il empêche les ESP de fonctionner, il permet à un admin d'inspecter les scripts d'un joueur, et il permet de voir ce qu'un joueur a à l'écran. Le tout se règle depuis un menu en jeu, réservé aux admins.

Compatible tout gamemode (DarkRP, TTT, Sandbox, RP custom…), pensé pour tenir jusqu'à ~128 joueurs.

---

## Fonctionnalités

### 1. Anti-ESP
Le cœur du projet. Un joueur (et ses armes) n'est envoyé aux autres joueurs **que s'il peut réellement être vu**. Un joueur derrière un mur n'existe tout simplement plus côté réseau : un ESP n'a alors plus aucune information à afficher.

Tout est décidé côté serveur, le client n'est jamais cru. Le système est optimisé pour un serveur peuplé :
- filtrage par distance avant tout calcul ;
- cache de mouvement (rien n'est recalculé si personne n'a bougé) ;
- lignes de vue vérifiées seulement quand nécessaire, réparties dans le temps ;
- délai et anticipation pour éviter les clignotements et les apparitions en retard.

### 2. Vérification des scripts
Un admin peut lister et lire les fichiers du dossier Garry's Mod d'un joueur (et **uniquement** ce dossier — le Lua ne peut pas lire ailleurs sur le PC). Les fichiers correspondant à une signature connue (ESP, API de cheat, etc.) sont signalés en rouge, avec un lecteur de code intégré qui surligne les lignes suspectes.

> Un fichier signalé n'est **pas** une preuve. C'est une aide à la vérification manuelle par l'admin.

### 3. Capture d'écran
Un admin peut demander une capture de ce qu'un joueur a à l'écran dans GMod. La capture est **silencieuse** (le joueur n'en est pas informé), limitée à la fenêtre du jeu, et enregistrée côté serveur.

> Limite honnête : un cheat qui contrôle le rendu peut masquer son affichage pendant la capture. La capture attrape les ESP en Lua, les menus de triche ouverts et les cheats mal réglés — pas un cheat « screenproof » bien configuré. C'est l'anti-ESP qui couvre ce cas, en amont.

### 4. Logs
Un journal en lecture seule de toutes les actions (analyses, captures, réglages modifiés), copiable en un clic pour le debug.

---

## Installation

1. Placer le dossier `cat` dans `garrysmod/addons/`.
   L'arborescence doit ressembler à : `garrysmod/addons/cat/lua/autorun/cat_init.lua`
2. Ouvrir `garrysmod/addons/cat/lua/cat/sv_config.lua` et remplacer le SteamID64 d'exemple par le vôtre et ceux de vos admins :
   ```lua
   admins_autorises = {
       ["76561198XXXXXXXXX"] = true,
   },
   ```
   (Un SteamID64 se trouve sur https://steamid.io )
3. Redémarrer le serveur.

`cat` crée tout seul les dossiers dont il a besoin (`data/cat/…`). Aucune dépendance, aucun autre addon requis.

---

## Utilisation

Ouvrir le menu en jeu (admins autorisés uniquement) :
- commande chat : `!cat`
- ou console : `cat_menu`

Le menu a quatre onglets : **Anti-ESP**, **Vérification**, **Capture**, **Logs**.

---

## Configuration

Tous les réglages de l'anti-ESP se modifient depuis l'onglet Anti-ESP, ou via ConVars dans `server.cfg`. Les principaux :

| ConVar | Défaut | Rôle |
|---|---|---|
| `cat_actif` | `1` | Active l'anti-ESP |
| `cat_distance_proche` | `350` | En deçà, les joueurs restent toujours visibles |
| `cat_distance_max` | `0` | Au-delà, plus rien n'est envoyé (0 = désactivé) |
| `cat_delai_masquage` | `0.6` | Délai avant de cacher un joueur (anti-clignotement) |
| `cat_anticipation` | `0.15` | Anticipation des mouvements (anti-apparition tardive) |
| `cat_props_bloquent` | `0` | Les props et portes bloquent la vue |
| `cat_traces_par_tick` | `120` | Budget de calcul par tick (baisser si le serveur rame) |

Les réglages sensibles (whitelist admin, signatures, conservation des captures) sont dans `sv_config.lua`, jamais envoyé aux clients.

Diagnostic performances en console : `cat_stats`.

---

## Sécurité

- Les permissions sont déterminées **côté serveur** par une whitelist de SteamID64. Le client ne décide de rien.
- Chaque message réseau est revérifié côté serveur.
- Les chemins de fichiers sont validés (pas de remontée de dossier).
- Les gros transferts (captures) passent par morceaux, avec un plafond de taille.
- Aucun secret n'est stocké dans le code client.

---

## Licence

Sous licence **MIT** (voir le fichier `LICENSE`). Usage, modification et redistribution **libres**, pour tout le monde, y compris à des fins commerciales. Remaniez-le à votre sauce.
