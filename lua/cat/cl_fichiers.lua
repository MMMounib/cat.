--[[
    cat — réponse aux demandes du serveur (côté joueur)

    Deux tâches, déclenchées uniquement par le serveur :
      - lister/lire les fichiers du dossier garrysmod/ (limite imposée par le jeu)
      - capturer l'écran (render.Capture)

    LIMITE de la capture : un cheat qui contrôle le rendu (oink et similaires) sait
    quand une capture a lieu et masque son affichage pendant cette frame. La capture
    attrape les ESP en Lua pur, les menus de triche ouverts et les cheats mal réglés,
    pas un cheat "screenproof" bien configuré. C'est l'anti-ESP serveur qui couvre ce
    cas, en retirant l'information avant qu'elle n'arrive au client.

    Le travail est réparti sur plusieurs frames pour ne pas faire ramer le joueur.
]]

local TAILLE_PARTIE = 60000
local FICHIERS_PAR_IMAGE = 40

-- Envoie une chaîne au serveur, découpée et compressée, en une partie par frame
local function EnvoyerParParties(id, donnees)
    local compresse = util.Compress(donnees) or ""
    local total = math.max(1, math.ceil(#compresse / TAILLE_PARTIE))

    for numero = 1, total do
        timer.Simple((numero - 1) * 0.1, function()
            local morceau = string.sub(compresse, (numero - 1) * TAILLE_PARTIE + 1, numero * TAILLE_PARTIE)
            net.Start("Cat_Reponse")
            net.WriteUInt(id, 32)
            net.WriteUInt(numero, 16)
            net.WriteUInt(total, 16)
            net.WriteUInt(#morceau, 16)
            net.WriteData(morceau, #morceau)
            net.SendToServer()
        end)
    end
end

---------------------------------------------------------------------------
-- ANALYSE DES FICHIERS
---------------------------------------------------------------------------
local function ContientTout(contenu, mots)
    for _, mot in ipairs(mots) do
        if not string.find(contenu, mot, 1, true) then return false end
    end
    return true
end

local function AnalyserFichiers(id, demande)
    local a_traiter = {}

    local function Parcourir(chemin, zone)
        if #a_traiter >= demande.fichiers_max then return end
        local fichiers, dossiers = file.Find(chemin .. "*", zone)

        for _, nom in ipairs(fichiers or {}) do
            local extension = string.lower(string.GetExtensionFromFilename(nom) or "")
            if demande.extensions[extension] and #a_traiter < demande.fichiers_max then
                table.insert(a_traiter, { chemin = chemin .. nom, zone = zone })
            end
        end
        for _, dossier in ipairs(dossiers or {}) do
            Parcourir(chemin .. dossier .. "/", zone)
        end
    end

    for _, dossier in ipairs(demande.dossiers) do
        Parcourir(dossier.chemin, dossier.zone)
    end

    local resultats, position = {}, 0

    hook.Add("Think", "Cat_Analyse_" .. id, function()
        for _ = 1, FICHIERS_PAR_IMAGE do
            position = position + 1
            local fichier = a_traiter[position]

            if not fichier then
                hook.Remove("Think", "Cat_Analyse_" .. id)
                EnvoyerParParties(id, util.TableToJSON({ type = "liste", fichiers = resultats }))
                return
            end

            local taille = file.Size(fichier.chemin, fichier.zone) or 0
            local alertes = {}

            if taille <= demande.taille_max then
                local contenu = file.Read(fichier.chemin, fichier.zone) or ""
                for _, signature in ipairs(demande.signatures) do
                    if ContientTout(contenu, signature.mots) and not table.HasValue(alertes, signature.nom) then
                        table.insert(alertes, signature.nom)
                    end
                end
            else
                table.insert(alertes, "Trop gros, non analysé")
            end

            table.insert(resultats, {
                chemin = fichier.chemin,
                zone = fichier.zone,
                taille = taille,
                date = file.Time(fichier.chemin, fichier.zone) or 0,
                alertes = alertes,
            })
        end
    end)
end

---------------------------------------------------------------------------
-- LECTURE D'UN FICHIER
---------------------------------------------------------------------------
local function LireFichier(id, demande)
    local contenu = file.Read(demande.chemin, demande.zone)
    if not contenu then
        contenu = "[fichier introuvable ou illisible]"
    elseif #contenu > demande.taille_max then
        contenu = string.sub(contenu, 1, demande.taille_max) .. "\n\n[... fichier tronqué ...]"
    end

    EnvoyerParParties(id, util.TableToJSON({
        type = "lire", chemin = demande.chemin, zone = demande.zone, contenu = contenu,
    }))
end

---------------------------------------------------------------------------
-- CAPTURE D'ÉCRAN
--   render.Capture ne fonctionne que pendant le rendu : on attend la prochaine
--   frame via PostRender. On renvoie un JPEG en base64 par le canal découpé.
--   La qualité règle le poids ; on ne redimensionne pas (le faire en Lua est
--   fragile), un JPEG qualité 40 en 1080p pèse ~150-250 Ko, ce qui passe.
---------------------------------------------------------------------------
local function CapturerEcran(id, demande)
    hook.Add("PostRender", "Cat_Capture_" .. id, function()
        hook.Remove("PostRender", "Cat_Capture_" .. id)

        local donnees = render.Capture({
            format  = "jpeg",
            quality = math.Clamp(demande.qualite or 40, 10, 100),
            x = 0, y = 0, w = ScrW(), h = ScrH(),
            alpha = false,
        })

        EnvoyerParParties(id, util.TableToJSON({
            type = "capture",
            largeur = ScrW(),
            hauteur = ScrH(),
            image = util.Base64Encode(donnees or "", true),   -- true = sans retours à la ligne
        }))
    end)
end

---------------------------------------------------------------------------
-- RÉCEPTION DES DEMANDES
---------------------------------------------------------------------------
net.Receive("Cat_Demande", function()
    local id = net.ReadUInt(32)
    local demande = util.JSONToTable(net.ReadString())
    if not demande then return end

    if demande.type == "liste" then
        AnalyserFichiers(id, demande)
    elseif demande.type == "lire" then
        LireFichier(id, demande)
    elseif demande.type == "capture" then
        CapturerEcran(id, demande)
    end
end)
