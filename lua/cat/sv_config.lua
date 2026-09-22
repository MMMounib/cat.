--[[
    CONFIGURATION CAT
    Ce fichier reste sur le serveur : il n'est jamais envoyé aux joueurs.
    Seule une personne ayant accès aux fichiers du serveur peut le modifier.
    Redémarrer le serveur après modification.
]]

Cat = Cat or {}

Cat.Config = {

    -- Qui peut ouvrir le menu (SteamID64 uniquement, trouvable sur steamid.io)
    admins_autorises = {
        ["76561198000000000"] = true,   -- exemple : à remplacer
    },

    -- Commande pour ouvrir le menu (aussi : cat_menu dans la console)
    commande_chat = "!cat",

    -- Dossiers analysés chez le joueur (uniquement dans garrysmod/)
    -- zone "MOD"  = garrysmod/
    -- zone "DATA" = garrysmod/data/
    dossiers_analyses = {
        { chemin = "lua/",    zone = "MOD"  },
        { chemin = "addons/", zone = "MOD"  },
        { chemin = "cfg/",    zone = "MOD"  },
        { chemin = "",        zone = "DATA" },
    },

    -- Types de fichiers analysés
    extensions = { lua = true, txt = true, cfg = true, json = true },

    -- Signatures : un fichier est signalé s'il contient TOUS les mots d'une ligne
    signatures = {
        { nom = "API du cheat oink",        mots = { "oink." } },
        { nom = "ESP (dessin des joueurs)", mots = { "player.GetAll", "ToScreen", "HUDPaint" } },
        { nom = "ESP (dessin des joueurs)", mots = { "player.Iterator", "ToScreen", "HUDPaint" } },
        { nom = "ESP (dessin des entités)", mots = { "ents.GetAll", "ToScreen", "HUDPaint" } },
        { nom = "Lancement de script",      mots = { "lua_openscript_cl" } },
    },

    fichiers_max          = 3000,    -- nombre max de fichiers listés par analyse
    taille_max_analyse    = 524288,  -- fichiers plus gros : listés mais non analysés (512 Ko)
    taille_max_lecture    = 131072,  -- taille max affichée quand on ouvre un fichier (128 Ko)
    delai_reponse         = 30,      -- secondes avant de considérer que le joueur ne répond pas
    delai_entre_analyses  = 5,       -- secondes minimum entre deux analyses d'un même admin

    -- Capture d'écran
    -- LIMITE : un cheat qui contrôle le rendu (comme oink) peut masquer son
    -- affichage pendant la capture. La capture attrape les ESP en Lua pur, les
    -- menus de triche ouverts et les cheats mal réglés, pas un cheat "screenproof"
    -- bien configuré. L'anti-ESP serveur, lui, retire l'information en amont.
    capture_qualite       = 40,   -- qualité JPEG 0-100 (40 = bon compromis poids/lisibilité)
    capture_auto_analyse  = true, -- lancer aussi l'analyse des fichiers avec la capture
    capture_conservation_jours = 7, -- suppression auto des captures plus vieilles (0 = jamais)
}
