--[[
    cat — logique serveur (menu, réglages, analyse, capture, logs)
    Le serveur décide de tout : chaque message reçu d'un client est revérifié ici.
]]

local Config = Cat.Config

util.AddNetworkString("Cat_Menu")         -- serveur -> admin : ouvrir le menu
util.AddNetworkString("Cat_Reglage")      -- admin -> serveur : modifier un réglage
util.AddNetworkString("Cat_Analyser")     -- admin -> serveur : analyser un joueur
util.AddNetworkString("Cat_LireFichier")  -- admin -> serveur : lire un fichier d'un joueur
util.AddNetworkString("Cat_Capturer")     -- admin -> serveur : demander une capture
util.AddNetworkString("Cat_Demande")      -- serveur -> joueur : demande (analyse/lecture/capture)
util.AddNetworkString("Cat_Reponse")      -- joueur -> serveur : réponse en morceaux
util.AddNetworkString("Cat_Resultat")     -- serveur -> admin : réponse transmise
util.AddNetworkString("Cat_Message")      -- serveur -> admin : message d'info
util.AddNetworkString("Cat_Capture")      -- serveur -> admin : capture prête
util.AddNetworkString("Cat_Logs")         -- admin <-> serveur : lecture des logs

local PARTIES_MAX = 220          -- ~13 Mo max par réponse (captures comprises)
local TAILLE_PARTIE_MAX = 60000

---------------------------------------------------------------------------
-- OUTILS
---------------------------------------------------------------------------
local function EstAutorise(joueur)
    return IsValid(joueur) and Config.admins_autorises[joueur:SteamID64()] == true
end

-- genre : "info", "succes" ou "erreur" (pour la couleur de la notification)
local function Message(admin, texte, genre)
    if not IsValid(admin) then return end
    net.Start("Cat_Message")
    net.WriteString(texte)
    net.WriteString(genre or "info")
    net.Send(admin)
end

local function Journal(texte)
    file.CreateDir("cat")
    file.Append("cat/journal.txt", os.date("[%d/%m/%Y %H:%M:%S] ") .. texte .. "\n")
    print("[cat] " .. texte)
end

local function Identite(joueur)
    return joueur:Nick() .. " (" .. joueur:SteamID64() .. ")"
end

-- Nom de dossier sûr à partir du pseudo + SteamID
local function NomDossier(joueur)
    local nom = string.gsub(joueur:Nick(), "[^%w%-_]", "_")
    if nom == "" then nom = "joueur" end
    return nom .. "_" .. joueur:SteamID64()
end

---------------------------------------------------------------------------
-- OUVERTURE DU MENU
---------------------------------------------------------------------------
local function OuvrirMenu(joueur)
    if not EstAutorise(joueur) then return end

    local reglages = {}
    for _, reglage in ipairs(Cat.ListeReglages) do
        table.insert(reglages, {
            nom = reglage.nom,
            section = reglage.section,
            type = reglage.type,
            description = reglage.description,
            valeur = GetConVar(reglage.nom):GetString(),
        })
    end

    -- mots des signatures, pour surligner les lignes suspectes à l'écran
    local mots = {}
    for _, signature in ipairs(Config.signatures) do
        for _, mot in ipairs(signature.mots) do mots[mot] = true end
    end

    net.Start("Cat_Menu")
    net.WriteString(util.TableToJSON({ reglages = reglages, mots = table.GetKeys(mots) }))
    net.Send(joueur)
end

concommand.Add("cat_menu", OuvrirMenu)

hook.Add("PlayerSay", "Cat_Menu", function(joueur, texte)
    if string.lower(string.Trim(texte)) ~= Config.commande_chat then return end
    OuvrirMenu(joueur)
    return ""
end)

---------------------------------------------------------------------------
-- MODIFICATION D'UN RÉGLAGE
---------------------------------------------------------------------------
local function ReglageExiste(nom)
    for _, reglage in ipairs(Cat.ListeReglages) do
        if reglage.nom == nom then return true end
    end
    return false
end

net.Receive("Cat_Reglage", function(_, admin)
    if not EstAutorise(admin) then return end

    local nom, valeur = net.ReadString(), net.ReadString()
    if not ReglageExiste(nom) then return end
    if #valeur > 200 or string.find(valeur, "[\";\n]") then
        Message(admin, "Valeur refusée.", "erreur")
        return
    end

    local ancienne = GetConVar(nom):GetString()
    RunConsoleCommand(nom, valeur)
    Journal(Identite(admin) .. " a modifié " .. nom .. " : " .. ancienne .. " -> " .. valeur)
    Message(admin, nom .. " = " .. valeur, "succes")
end)

---------------------------------------------------------------------------
-- DEMANDES ENVOYÉES AUX JOUEURS
---------------------------------------------------------------------------
local demandes = {}          -- [id] = { admin, cible, fin, parties, capture, morceaux }
local prochain_id = 0
local prochaine_action = {}  -- [admin] = moment où il pourra relancer une action

local function EnvoyerDemande(admin, cible, contenu)
    prochain_id = prochain_id + 1
    demandes[prochain_id] = {
        admin = admin,
        cible = cible,
        fin = CurTime() + Config.delai_reponse,
        parties = 0,
        capture = contenu.type == "capture",
        morceaux = {},
    }

    net.Start("Cat_Demande")
    net.WriteUInt(prochain_id, 32)
    net.WriteString(util.TableToJSON(contenu))
    net.Send(cible)
end

local function CibleValide(cible)
    return IsValid(cible) and cible:IsPlayer() and not cible:IsBot()
end

-- Empêche un admin de spammer les demandes
local function TropTot(admin)
    if (prochaine_action[admin] or 0) > CurTime() then return true end
    prochaine_action[admin] = CurTime() + Config.delai_entre_analyses
    return false
end

local function DemandeAnalyse()
    return {
        type = "liste",
        dossiers = Config.dossiers_analyses,
        extensions = Config.extensions,
        signatures = Config.signatures,
        fichiers_max = Config.fichiers_max,
        taille_max = Config.taille_max_analyse,
    }
end

net.Receive("Cat_Analyser", function(_, admin)
    if not EstAutorise(admin) then return end
    local cible = net.ReadEntity()
    if not CibleValide(cible) then return end
    if TropTot(admin) then
        Message(admin, "Patiente quelques secondes avant une nouvelle analyse.", "erreur")
        return
    end

    EnvoyerDemande(admin, cible, DemandeAnalyse())
    Journal(Identite(admin) .. " analyse les scripts de " .. Identite(cible))
    Message(admin, "Analyse de " .. cible:Nick() .. " en cours...")
end)

net.Receive("Cat_Capturer", function(_, admin)
    if not EstAutorise(admin) then return end
    local cible = net.ReadEntity()
    if not CibleValide(cible) then return end
    if TropTot(admin) then
        Message(admin, "Patiente quelques secondes avant une nouvelle demande.", "erreur")
        return
    end

    -- capture silencieuse : rien n'est affiché chez le joueur
    EnvoyerDemande(admin, cible, { type = "capture", qualite = Config.capture_qualite })

    if Config.capture_auto_analyse then          -- analyse en parallèle (demande séparée)
        EnvoyerDemande(admin, cible, DemandeAnalyse())
    end

    Journal(Identite(admin) .. " capture l'écran de " .. Identite(cible))
    Message(admin, "Capture de " .. cible:Nick() .. " en cours...")
end)

net.Receive("Cat_LireFichier", function(_, admin)
    if not EstAutorise(admin) then return end
    local cible, chemin, zone = net.ReadEntity(), net.ReadString(), net.ReadString()
    if not CibleValide(cible) then return end
    if zone ~= "MOD" and zone ~= "DATA" then return end
    if string.find(chemin, "..", 1, true) then return end   -- pas de remontée de dossier

    EnvoyerDemande(admin, cible, { type = "lire", chemin = chemin, zone = zone, taille_max = Config.taille_max_lecture })
    Journal(Identite(admin) .. " ouvre " .. chemin .. " chez " .. Identite(cible))
end)

---------------------------------------------------------------------------
-- CAPTURE : décodage et sauvegarde côté serveur
---------------------------------------------------------------------------
local function SauvegarderCapture(admin, joueur, flux)
    local brut = util.JSONToTable(util.Decompress(flux) or "")
    local image = brut and brut.image and util.Base64Decode(brut.image)
    if not image or image == "" then
        Message(admin, "Capture de " .. joueur:Nick() .. " illisible.", "erreur")
        return
    end

    local dossier = "cat/captures/" .. NomDossier(joueur)
    file.CreateDir(dossier)
    local chemin = dossier .. "/" .. os.date("%Y-%m-%d_%Hh%Mm%Ss") .. ".jpg"
    file.Write(chemin, image)   -- data/cat/captures/<joueur>/<date>.jpg
    Journal("Capture de " .. Identite(joueur) .. " enregistrée : data/" .. chemin)

    if IsValid(admin) then
        net.Start("Cat_Capture")
        net.WriteEntity(joueur)
        net.WriteString(chemin)
        net.WriteUInt(#image, 32)
        net.WriteData(image, #image)
        net.Send(admin)
    end
end

---------------------------------------------------------------------------
-- RÉPONSES DES JOUEURS : vérifiées, relayées à l'admin, capture sauvegardée
---------------------------------------------------------------------------
net.Receive("Cat_Reponse", function(_, joueur)
    local id      = net.ReadUInt(32)
    local numero  = net.ReadUInt(16)
    local total   = net.ReadUInt(16)
    local longueur = net.ReadUInt(16)

    local demande = demandes[id]
    if not demande or demande.cible ~= joueur then return end   -- réponse non demandée

    if total > PARTIES_MAX or numero ~= demande.parties + 1 or longueur > TAILLE_PARTIE_MAX then
        demandes[id] = nil
        Message(demande.admin, joueur:Nick() .. " a envoyé une réponse invalide.", "erreur")
        Journal("Réponse invalide de " .. Identite(joueur))
        return
    end

    local morceau = net.ReadData(longueur)
    demande.parties = numero
    demande.morceaux[numero] = morceau

    -- une capture est renvoyée seulement une fois sauvegardée ; le reste est relayé au fil de l'eau
    if IsValid(demande.admin) and not demande.capture then
        net.Start("Cat_Resultat")
        net.WriteUInt(id, 32)
        net.WriteEntity(joueur)
        net.WriteUInt(numero, 16)
        net.WriteUInt(total, 16)
        net.WriteUInt(longueur, 16)
        net.WriteData(morceau, longueur)
        net.Send(demande.admin)
    end

    if numero ~= total then return end
    demandes[id] = nil

    if demande.capture then
        SauvegarderCapture(demande.admin, joueur, table.concat(demande.morceaux))
    end
end)

-- Joueur qui ne répond pas dans le délai : l'admin est prévenu
timer.Create("Cat_DelaiReponse", 5, 0, function()
    for id, demande in pairs(demandes) do
        if CurTime() > demande.fin then
            if IsValid(demande.cible) then
                Message(demande.admin, demande.cible:Nick() .. " n'a pas répondu (client modifié ou connexion lente).", "erreur")
                Journal("Pas de réponse de " .. Identite(demande.cible))
            end
            demandes[id] = nil
        end
    end
end)

---------------------------------------------------------------------------
-- LOGS : l'admin peut lire le journal depuis le menu
---------------------------------------------------------------------------
net.Receive("Cat_Logs", function(_, admin)
    if not EstAutorise(admin) then return end
    local contenu = file.Read("cat/journal.txt", "DATA") or ""
    if #contenu > 100000 then contenu = string.sub(contenu, -100000) end   -- on garde la fin
    net.Start("Cat_Logs")
    net.WriteString(contenu)
    net.Send(admin)
end)

---------------------------------------------------------------------------
-- NETTOYAGE : suppression des captures trop vieilles au démarrage
---------------------------------------------------------------------------
local function NettoyerCaptures()
    local jours = Config.capture_conservation_jours or 0
    if jours <= 0 then return end
    local limite = os.time() - jours * 86400
    local supprimees = 0

    local dossiers = select(2, file.Find("cat/captures/*", "DATA"))
    for _, dossier in ipairs(dossiers or {}) do
        local base = "cat/captures/" .. dossier .. "/"
        for _, nom in ipairs(file.Find(base .. "*.jpg", "DATA") or {}) do
            if (file.Time(base .. nom, "DATA") or 0) < limite then
                file.Delete(base .. nom)
                supprimees = supprimees + 1
            end
        end
    end

    if supprimees > 0 then
        Journal("Nettoyage : " .. supprimees .. " capture(s) de plus de " .. jours .. " jours supprimée(s)")
    end
end
hook.Add("InitPostEntity", "Cat_Nettoyage", NettoyerCaptures)
