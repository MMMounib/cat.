--[[
    ANTI-ESP (côté serveur) — addon générique, compatible avec tout gamemode
    Fichier : addons/cat/lua/cat/sv_esp.lua (chargé par cat_init.lua)

    Principe : le serveur n'envoie un joueur (et ses armes) à un autre joueur
    que si celui-ci peut réellement le voir. Un joueur derrière un mur n'est
    plus envoyé : l'ESP n'a donc plus rien à afficher.

    Tous les réglages sont des ConVars (à mettre dans server.cfg).
    Liste complète en jeu : find cat_
]]

if CLIENT then return end

---------------------------------------------------------------------------
-- RÉGLAGES
---------------------------------------------------------------------------
Cat = Cat or {}
Cat.ListeReglages = {}   -- utilisée par le menu en jeu

-- section et type servent uniquement à l'affichage dans le menu
local function Reglage(section, nom, valeur, type, description)
    table.insert(Cat.ListeReglages, { nom = "cat_" .. nom, section = section, type = type, description = description })
    return CreateConVar("cat_" .. nom, valeur, FCVAR_ARCHIVE, description)
end

-- Général
local reglage_actif            = Reglage("Général",     "actif",             "1",    "bool",   "Anti-ESP activé")
local reglage_groupes_staff    = Reglage("Général",     "groupes_staff",     "superadmin,admin", "texte", "Groupes staff qui voient tout (séparés par des virgules)")

-- Visibilité
local reglage_distance_proche  = Reglage("Visibilité",  "distance_proche",   "350",  "nombre", "Distance où les joueurs restent toujours visibles")
local reglage_distance_max     = Reglage("Visibilité",  "distance_max",      "0",    "nombre", "Distance au-delà de laquelle rien n'est envoyé (0 = off)")
local reglage_props_bloquent   = Reglage("Visibilité",  "props_bloquent",    "0",    "bool",   "Les props et portes bloquent la vue")

-- Confort (éviter apparitions en retard et clignotements)
local reglage_delai_masquage   = Reglage("Confort",     "delai_masquage",    "0.6",  "nombre", "Délai avant de cacher un joueur (s)")
local reglage_anticipation     = Reglage("Confort",     "anticipation",      "0.15", "nombre", "Anticipation des mouvements (s, ajoutée au ping)")
local reglage_distance_tp      = Reglage("Confort",     "distance_teleport", "200",  "nombre", "Déplacement en 1 tick traité comme un dash / TP")

-- Fréquence des vérifications (joueur caché ; un joueur visible est vérifié 2x moins souvent)
local reglage_zone_proche      = Reglage("Fréquence",   "zone_proche",       "2500", "nombre", "Rayon de la zone proche")
local reglage_zone_moyenne     = Reglage("Fréquence",   "zone_moyenne",      "5000", "nombre", "Rayon de la zone moyenne")
local reglage_verif_proche     = Reglage("Fréquence",   "verif_proche",      "0.1",  "nombre", "Intervalle en zone proche (s)")
local reglage_verif_moyenne    = Reglage("Fréquence",   "verif_moyenne",     "0.3",  "nombre", "Intervalle en zone moyenne (s)")
local reglage_verif_loin       = Reglage("Fréquence",   "verif_loin",        "0.8",  "nombre", "Intervalle en zone lointaine (s)")

-- Performance
local reglage_traces_par_tick  = Reglage("Performance", "traces_par_tick",   "120",  "nombre", "Vérifications de vue max par tick")
local reglage_paires_par_tick  = Reglage("Performance", "paires_par_tick",   "1500", "nombre", "Paires de joueurs parcourues max par tick")
local reglage_mouvement_min    = Reglage("Performance", "mouvement_minimum", "16",   "nombre", "Déplacement sous lequel le résultat est réutilisé")
local reglage_duree_resultat   = Reglage("Performance", "duree_resultat",    "1",    "nombre", "Durée max de réutilisation d'un résultat (s)")

---------------------------------------------------------------------------
-- MÉMOIRE DU SYSTÈME
---------------------------------------------------------------------------
Cat = Cat or {}
Cat.caches = Cat.caches or {}   -- garde l'état même après un rechargement du fichier
local caches = Cat.caches           -- [cible, spectateur] = true si la cible est cachée au spectateur

local derniere_vue     = {}  -- [paire] = dernier moment où les deux joueurs se voyaient
local prochaine_verif  = {}  -- [paire] = moment de la prochaine vérification
local resultat_garde   = {}  -- [paire] = dernier résultat de vue calculé
local moment_garde     = {}  -- [paire] = moment de ce calcul
local position_garde_a = {}  -- [paire] = position du 1er joueur lors du calcul
local position_garde_b = {}  -- [paire] = position du 2e joueur lors du calcul
local position_avant   = {}  -- [numéro joueur] = position au tick précédent
local groupes_staff    = {}  -- [nom du groupe] = true

local liste_joueurs, nombre_joueurs = {}, 0
local curseur_a, curseur_b = 1, 2

local stats_temps, stats_traces, stats_ticks = 0, 0, 0

---------------------------------------------------------------------------
-- OUTILS
---------------------------------------------------------------------------
local function LireGroupesStaff()
    groupes_staff = {}
    for nom in string.gmatch(reglage_groupes_staff:GetString(), "[^,%s]+") do
        groupes_staff[nom] = true
    end
end
LireGroupesStaff()
cvars.AddChangeCallback("cat_groupes_staff", LireGroupesStaff, "Cat")

local function CleCache(cible, spectateur)
    return cible:EntIndex() * 256 + spectateur:EntIndex()
end

local function ClePaire(numero_a, numero_b)
    if numero_a < numero_b then return numero_a * 256 + numero_b end
    return numero_b * 256 + numero_a
end

-- Le spectateur reçoit-il tout le monde sans vérification ?
local function VoitTout(joueur)
    if not joueur:Alive() then return true end
    if joueur:GetObserverMode() ~= OBS_MODE_NONE then return true end
    if groupes_staff[joueur:GetUserGroup()] then return true end
    return false
end

-- Cache ou montre un joueur (et ses armes) à un autre joueur
local function Cacher(cible, spectateur, cacher)
    local cle = CleCache(cible, spectateur)
    if (caches[cle] == true) == cacher then return end  -- rien ne change
    caches[cle] = cacher or nil

    cible:SetPreventTransmit(spectateur, cacher)
    for _, arme in ipairs(cible:GetWeapons()) do
        if IsValid(arme) then arme:SetPreventTransmit(spectateur, cacher) end
    end
end

---------------------------------------------------------------------------
-- LIGNE DE VUE
---------------------------------------------------------------------------
local function FiltreMapSeulement(entite)
    return entite:IsWorld()
end

local function FiltreMapEtProps(entite)
    return not entite:IsPlayer() and not entite:IsWeapon()
end

local resultat_trace = {}
local donnees_trace = { mask = MASK_VISIBLE, filter = FiltreMapSeulement, output = resultat_trace }

local function RienEntre(depart, arrivee)
    donnees_trace.start = depart
    donnees_trace.endpos = arrivee
    util.TraceLine(donnees_trace)
    stats_traces = stats_traces + 1
    return not resultat_trace.Hit
end

-- Les deux joueurs peuvent-ils se voir ? On s'arrête au premier "oui".
local function SeVoient(joueur_a, joueur_b)
    local yeux_a, yeux_b = joueur_a:EyePos(), joueur_b:EyePos()

    -- 1. yeux contre yeux
    if RienEntre(yeux_a, yeux_b) then return true end

    -- 2. positions dans un court instant (joueur qui sort d'un coin)
    local vitesse_a, vitesse_b = joueur_a:GetVelocity(), joueur_b:GetVelocity()
    if vitesse_a:LengthSqr() + vitesse_b:LengthSqr() > 2500 then
        local ping_max = math.max(joueur_a:Ping(), joueur_b:Ping()) / 1000
        local temps = math.min(reglage_anticipation:GetFloat() + ping_max, 0.5)
        if RienEntre(yeux_a + vitesse_a * temps, yeux_b + vitesse_b * temps) then return true end
    end

    -- 3. yeux contre milieu du corps, dans les deux sens
    if RienEntre(yeux_a, joueur_b:WorldSpaceCenter()) then return true end
    if RienEntre(yeux_b, joueur_a:WorldSpaceCenter()) then return true end

    return false
end

---------------------------------------------------------------------------
-- VÉRIFICATION D'UNE PAIRE DE JOUEURS
---------------------------------------------------------------------------
local function VerifierPaire(joueur_a, joueur_b, paire, maintenant)
    local voit_tout_a, voit_tout_b = VoitTout(joueur_a), VoitTout(joueur_b)
    local position_a, position_b = joueur_a:GetPos(), joueur_b:GetPos()
    local distance = position_a:DistToSqr(position_b)

    local proche = reglage_distance_proche:GetFloat() ^ 2
    local loin = reglage_distance_max:GetFloat() ^ 2
    local mouvement = reglage_mouvement_min:GetFloat() ^ 2

    local se_voient
    if voit_tout_a and voit_tout_b then
        se_voient = true
    elseif distance < proche then
        se_voient = true
    elseif loin > 0 and distance > loin then
        se_voient = false
    elseif resultat_garde[paire] ~= nil
        and maintenant - moment_garde[paire] < reglage_duree_resultat:GetFloat()
        and position_garde_a[paire]:DistToSqr(position_a) < mouvement
        and position_garde_b[paire]:DistToSqr(position_b) < mouvement then
        se_voient = resultat_garde[paire]           -- personne n'a bougé : on réutilise
    else
        se_voient = SeVoient(joueur_a, joueur_b)
        resultat_garde[paire] = se_voient
        moment_garde[paire] = maintenant
        position_garde_a[paire] = position_a
        position_garde_b[paire] = position_b
    end

    -- tolérance : on ne cache qu'après un court délai sans se voir
    if se_voient then derniere_vue[paire] = maintenant end
    local visible = se_voient or (maintenant - (derniere_vue[paire] or -1000)) < reglage_delai_masquage:GetFloat()

    -- exceptions déclarées par d'autres addons (coéquipiers, radar, etc.)
    local montrer_b_a_a = visible or voit_tout_a or hook.Run("Cat_ToujoursVisible", joueur_a, joueur_b) == true
    local montrer_a_a_b = visible or voit_tout_b or hook.Run("Cat_ToujoursVisible", joueur_b, joueur_a) == true

    Cacher(joueur_b, joueur_a, not montrer_b_a_a)
    Cacher(joueur_a, joueur_b, not montrer_a_a_b)

    -- prochaine vérification : plus souvent si proche ou caché
    local attente
    if distance < reglage_zone_proche:GetFloat() ^ 2 then
        attente = reglage_verif_proche:GetFloat()
    elseif distance < reglage_zone_moyenne:GetFloat() ^ 2 then
        attente = reglage_verif_moyenne:GetFloat()
    else
        attente = reglage_verif_loin:GetFloat()
    end
    if se_voient then attente = attente * 2 end
    if visible and not se_voient then attente = reglage_verif_proche:GetFloat() end  -- le délai va bientôt expirer
    prochaine_verif[paire] = maintenant + attente
end

---------------------------------------------------------------------------
-- BOUCLE PRINCIPALE : un peu de travail à chaque tick, jamais tout d'un coup
---------------------------------------------------------------------------
local function RecommencerTour()
    liste_joueurs = player.GetAll()
    nombre_joueurs = #liste_joueurs
    curseur_a, curseur_b = 1, 2
end

hook.Add("Tick", "Cat", function()
    if not reglage_actif:GetBool() then return end
    local debut = SysTime()
    local maintenant = CurTime()
    local traces_au_debut = stats_traces

    donnees_trace.filter = reglage_props_bloquent:GetBool() and FiltreMapEtProps or FiltreMapSeulement

    -- téléportation / dash / respawn : revérifier ce joueur tout de suite
    local tous = player.GetAll()
    local distance_tp = reglage_distance_tp:GetFloat() ^ 2
    for _, joueur in ipairs(tous) do
        local numero = joueur:EntIndex()
        local position = joueur:GetPos()
        local avant = position_avant[numero]
        if avant and avant:DistToSqr(position) > distance_tp then
            for _, autre in ipairs(tous) do
                if autre ~= joueur then prochaine_verif[ClePaire(numero, autre:EntIndex())] = 0 end
            end
        end
        position_avant[numero] = position
    end

    -- parcours des paires, dans la limite du budget
    if nombre_joueurs < 2 then RecommencerTour() end
    local paires_vues = 0
    local paires_max = reglage_paires_par_tick:GetInt()
    local budget = reglage_traces_par_tick:GetInt()

    while nombre_joueurs >= 2 and paires_vues < paires_max and stats_traces - traces_au_debut < budget do
        if curseur_b > nombre_joueurs then
            curseur_a = curseur_a + 1
            curseur_b = curseur_a + 1
            if curseur_a >= nombre_joueurs then RecommencerTour() break end
        end

        local joueur_a, joueur_b = liste_joueurs[curseur_a], liste_joueurs[curseur_b]
        curseur_b = curseur_b + 1
        paires_vues = paires_vues + 1

        if IsValid(joueur_a) and IsValid(joueur_b) then
            local paire = ClePaire(joueur_a:EntIndex(), joueur_b:EntIndex())
            if (prochaine_verif[paire] or 0) <= maintenant then
                VerifierPaire(joueur_a, joueur_b, paire, maintenant)
            end
        end
    end

    stats_temps = stats_temps + (SysTime() - debut)
    stats_ticks = stats_ticks + 1
end)

---------------------------------------------------------------------------
-- ARMES : une arme ramassée suit l'état caché de son propriétaire
---------------------------------------------------------------------------
hook.Add("WeaponEquip", "Cat", function(arme, proprietaire)
    timer.Simple(0, function()
        if not IsValid(arme) or not IsValid(proprietaire) then return end
        for _, spectateur in ipairs(player.GetAll()) do
            if caches[CleCache(proprietaire, spectateur)] then
                arme:SetPreventTransmit(spectateur, true)
            end
        end
    end)
end)

hook.Add("PlayerDroppedWeapon", "Cat", function(_, arme)
    if not IsValid(arme) then return end
    for _, spectateur in ipairs(player.GetAll()) do
        arme:SetPreventTransmit(spectateur, false)
    end
end)

---------------------------------------------------------------------------
-- DÉCONNEXION : on nettoie pour le prochain joueur qui prendra la place
---------------------------------------------------------------------------
hook.Add("PlayerDisconnected", "Cat", function(joueur)
    local numero = joueur:EntIndex()
    for _, autre in ipairs(player.GetAll()) do
        if autre ~= joueur then
            Cacher(autre, joueur, false)
            caches[CleCache(joueur, autre)] = nil
            local paire = ClePaire(numero, autre:EntIndex())
            derniere_vue[paire], prochaine_verif[paire], resultat_garde[paire], moment_garde[paire] = nil, nil, nil, nil
            position_garde_a[paire], position_garde_b[paire] = nil, nil
        end
    end
    position_avant[numero] = nil
end)

---------------------------------------------------------------------------
-- DÉSACTIVATION : tout le monde redevient visible
---------------------------------------------------------------------------
cvars.AddChangeCallback("cat_actif", function(_, _, valeur)
    if valeur ~= "0" then return end
    local tous = player.GetAll()
    for _, cible in ipairs(tous) do
        for _, spectateur in ipairs(tous) do
            if cible ~= spectateur then Cacher(cible, spectateur, false) end
        end
    end
    resultat_garde, moment_garde, derniere_vue, prochaine_verif = {}, {}, {}, {}
end, "Cat")

---------------------------------------------------------------------------
-- COMMANDE : cat_stats (console serveur ou admin de la whitelist)
---------------------------------------------------------------------------
concommand.Add("cat_stats", function(joueur)
    if IsValid(joueur) and not Cat.Config.admins_autorises[joueur:SteamID64()] then return end

    local nombre_caches = 0
    for _ in pairs(caches) do nombre_caches = nombre_caches + 1 end
    local secondes = math.max(stats_ticks * engine.TickInterval(), 0.001)

    local message = string.format("[cat] %d joueurs | %.3f ms par tick | %d vérifications de vue/s | %d joueurs cachés actuellement",
        player.GetCount(), stats_temps / math.max(stats_ticks, 1) * 1000, stats_traces / secondes, nombre_caches)

    if IsValid(joueur) then joueur:PrintMessage(HUD_PRINTCONSOLE, message) else print(message) end
    stats_temps, stats_traces, stats_ticks = 0, 0, 0
end)
