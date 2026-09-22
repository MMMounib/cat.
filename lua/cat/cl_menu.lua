--[[
    cat — menu admin (côté client)
    Ce fichier est envoyé à tous les joueurs, mais le menu ne s'ouvre que si le
    serveur l'autorise, et chaque action est revérifiée par le serveur.

    Performance : aucun hook Think, listes dessinées uniquement sur les lignes
    visibles, polices créées une seule fois, pages créées une seule fois.
]]

---------------------------------------------------------------------------
-- STYLE
---------------------------------------------------------------------------
local couleurs = {
    fond          = Color(8, 8, 8),
    fenetre       = Color(13, 13, 13),
    panneau       = Color(17, 17, 17),
    panneau_clair = Color(21, 21, 21),
    element       = Color(26, 26, 26),
    bordure       = Color(37, 37, 37),
    bordure_forte = Color(48, 48, 48),
    texte         = Color(245, 245, 245),
    texte_code    = Color(212, 212, 212),
    texte_gris    = Color(144, 144, 144),
    texte_discret = Color(88, 88, 88),
    danger        = Color(200, 85, 85),
    danger_fond   = Color(200, 85, 85, 20),
    succes        = Color(110, 170, 120),
}

local echelle = 1
local function T(valeur) return math.Round(valeur * echelle) end

local function CreerPolices()
    echelle = math.Clamp(ScrH() / 1080, 0.75, 1.4)
    local function Police(nom, base, taille, epaisseur)
        surface.CreateFont(nom, { font = base, size = T(taille), weight = epaisseur, extended = true, antialias = true })
    end
    Police("Cat.Logo",      "Roboto", 22, 700)
    Police("Cat.Titre",     "Roboto", 19, 600)
    Police("Cat.Texte",     "Roboto", 15, 400)
    Police("Cat.TexteGras", "Roboto", 15, 600)
    Police("Cat.Petit",     "Roboto", 13, 400)
    Police("Cat.Section",   "Roboto", 12, 700)
    Police("Cat.Code",      "Consolas", 14, 400)
    Police("Cat.CodePetit", "Consolas", 12, 400)
end
CreerPolices()
hook.Add("OnScreenSizeChanged", "Cat_Polices", CreerPolices)

local function Lisser(actuel, cible, vitesse)
    return Lerp(math.min(FrameTime() * (vitesse or 14), 1), actuel, cible)
end

local function Melanger(a, b, t)
    return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a, b.a))
end

-- Rectangle arrondi avec bordure d'1 pixel
local function Cadre(x, y, w, h, rayon, couleur_bordure, couleur_fond)
    draw.RoundedBox(rayon, x, y, w, h, couleur_bordure)
    draw.RoundedBox(math.max(rayon - 1, 0), x + 1, y + 1, w - 2, h - 2, couleur_fond)
end

-- string.upper ne gère pas les accents
local accents = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["â"] = "Â", ["ç"] = "Ç", ["ô"] = "Ô", ["î"] = "Î", ["û"] = "Û", ["ù"] = "Ù" }
local function Majuscules(texte)
    return (string.upper(texte):gsub("[\195][\128-\191]", accents))
end

-- Coupe un texte trop long ; "debut = true" garde la fin (utile pour les chemins)
local function Couper(texte, police, largeur, debut)
    surface.SetFont(police)
    if surface.GetTextSize(texte) <= largeur then return texte end
    local longueur = #texte
    while longueur > 1 do
        longueur = longueur - 1
        local essai = debut and ("…" .. string.sub(texte, -longueur)) or (string.sub(texte, 1, longueur) .. "…")
        if surface.GetTextSize(essai) <= largeur then return essai end
    end
    return "…"
end

---------------------------------------------------------------------------
-- COMPOSANTS
---------------------------------------------------------------------------
local function StyliserDefilement(defilement)
    local barre = defilement:GetVBar()
    barre:SetWide(T(6))
    barre:SetHideButtons(true)
    barre.Paint = nil
    barre.btnGrip.survol = 0
    barre.btnGrip.Paint = function(s, w, h)
        s.survol = Lisser(s.survol, (s:IsHovered() or s.Depressed) and 1 or 0)
        draw.RoundedBox(math.floor(w / 2), 0, 0, w, h, Melanger(couleurs.bordure, couleurs.bordure_forte, s.survol))
    end
end

-- style : "principal" (blanc), "secondaire" (gris), "discret" (texte seul)
local function Bouton(parent, texte, style)
    local bouton = vgui.Create("DButton", parent)
    bouton:SetText("")
    bouton.texte = texte
    bouton.style = style or "secondaire"
    bouton.survol = 0

    bouton.Paint = function(s, w, h)
        local actif = s:IsEnabled()
        s.survol = Lisser(s.survol, (actif and s:IsHovered()) and 1 or 0)
        local rayon = T(6)

        if s.style == "principal" then
            local fond = actif and Melanger(Color(228, 228, 228), couleurs.texte, s.survol) or couleurs.element
            draw.RoundedBox(rayon, 0, 0, w, h, fond)
            draw.SimpleText(s.texte, "Cat.TexteGras", w / 2, h / 2, actif and couleurs.fond or couleurs.texte_discret, 1, 1)
        elseif s.style == "secondaire" then
            Cadre(0, 0, w, h, rayon, Melanger(couleurs.bordure, couleurs.bordure_forte, s.survol), Melanger(couleurs.panneau_clair, couleurs.element, s.survol))
            draw.SimpleText(s.texte, "Cat.Texte", w / 2, h / 2, actif and couleurs.texte or couleurs.texte_discret, 1, 1)
        else
            if s.survol > 0.01 then draw.RoundedBox(rayon, 0, 0, w, h, ColorAlpha(couleurs.element, 255 * s.survol)) end
            draw.SimpleText(s.texte, "Cat.Texte", w / 2, h / 2, Melanger(couleurs.texte_gris, couleurs.texte, s.survol), 1, 1)
        end
    end
    return bouton
end

local function Champ(parent, texte_vide)
    local champ = vgui.Create("DTextEntry", parent)
    champ:SetFont("Cat.Texte")
    champ:SetDrawLanguageID(false)
    champ.texte_vide = texte_vide
    champ.Paint = function(s, w, h)
        local focus = s:HasFocus()
        Cadre(0, 0, w, h, T(6), focus and couleurs.bordure_forte or couleurs.bordure, couleurs.fond)
        if s:GetText() == "" and s.texte_vide and not focus then
            draw.SimpleText(s.texte_vide, "Cat.Texte", T(8), h / 2, couleurs.texte_discret, 0, 1)
        end
        s:DrawTextEntryText(couleurs.texte, couleurs.bordure_forte, couleurs.texte)
    end
    return champ
end

local function Interrupteur(parent, actif, au_changement)
    local bouton = vgui.Create("DButton", parent)
    bouton:SetText("")
    bouton:SetWide(T(40))
    bouton.actif = actif
    bouton.position = actif and 1 or 0

    bouton.DoClick = function(s)
        s.actif = not s.actif
        au_changement(s.actif)
    end

    bouton.Paint = function(s, w, h)
        s.position = Lisser(s.position, s.actif and 1 or 0, 18)
        local hauteur = T(22)
        local y = math.floor((h - hauteur) / 2)
        local bordure = s:IsHovered() and couleurs.bordure_forte or couleurs.bordure
        Cadre(0, y, w, hauteur, math.floor(hauteur / 2), bordure, Melanger(couleurs.element, couleurs.texte, s.position))

        local taille = hauteur - T(8)
        local x = Lerp(s.position, T(4), w - taille - T(4))
        draw.RoundedBox(math.floor(taille / 2), x, y + T(4), taille, taille, Melanger(couleurs.texte_gris, couleurs.fenetre, s.position))
    end
    return bouton
end

-- Fond de carte réutilisé partout
local function PeindreCarte(_, w, h)
    Cadre(0, 0, w, h, T(8), couleurs.bordure, couleurs.panneau)
end

-- Logo chat (image), chargé une seule fois
local logo_chat = Material("cat/logo.png", "smooth")
local function DessinerLogo(x, y, taille)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(logo_chat)
    surface.DrawTexturedRect(x, y, taille, taille)
end

---------------------------------------------------------------------------
-- ÉTAT DU MENU
---------------------------------------------------------------------------
local fenetre, notification
local pages, page_active, liste_pages = {}, nil, {}
local mots_suspects = {}
local receptions = {}          -- [id] = morceaux reçus

-- vérification des scripts
local zone_droite, colonne_joueurs, panneau_resultats, visionneuse
local toile_fichiers, defilement_fichiers
local fichiers_actuels, joueur_actuel = {}, nil
local en_attente = nil         -- nom du joueur analysé, tant que la réponse n'est pas arrivée
local filtre_texte, signales_seulement = "", false
local tri_colonne, tri_inverse = "signalement", false

-- capture d'écran (matériaux gardés le temps de l'affichage)
local capture_afficher = nil   -- fonction posée par la page Capture
local logs_afficher = nil      -- fonction posée par la page Logs

---------------------------------------------------------------------------
-- NOTIFICATIONS
---------------------------------------------------------------------------
local couleur_genre = { info = couleurs.texte_gris, succes = couleurs.succes, erreur = couleurs.danger }

local function Notifier(texte, genre)
    if not IsValid(fenetre) then
        chat.AddText(couleurs.texte_gris, "[cat] ", couleurs.texte, texte)
        return
    end
    if IsValid(notification) then notification:Remove() end

    surface.SetFont("Cat.Texte")
    local largeur = math.min(surface.GetTextSize(texte) + T(46), fenetre:GetWide() - T(40))
    local hauteur = T(40)
    local x, y = fenetre:GetWide() - largeur - T(20), fenetre:GetTall() - hauteur - T(20)

    notification = vgui.Create("DPanel", fenetre)
    notification:SetSize(largeur, hauteur)
    notification:SetPos(x, y + T(10))
    notification:SetAlpha(0)
    notification:MoveTo(x, y, 0.18, 0, 0.3)
    notification:AlphaTo(255, 0.18)
    notification:AlphaTo(0, 0.25, 3, function(_, panneau) if IsValid(panneau) then panneau:Remove() end end)
    notification:MoveToFront()

    local couleur = couleur_genre[genre] or couleurs.texte_gris
    local texte_affiche = Couper(texte, "Cat.Texte", largeur - T(46))
    notification.Paint = function(_, w, h)
        Cadre(0, 0, w, h, T(8), couleurs.bordure_forte, couleurs.panneau_clair)
        draw.RoundedBox(T(3), T(16), h / 2 - T(3), T(6), T(6), couleur)
        draw.SimpleText(texte_affiche, "Cat.Texte", T(32), h / 2, couleurs.texte, 0, 1)
    end
end

local function EnvoyerReglage(nom, valeur)
    net.Start("Cat_Reglage")
    net.WriteString(nom)
    net.WriteString(valeur)
    net.SendToServer()
end

---------------------------------------------------------------------------
-- EN-TÊTE DE PAGE
---------------------------------------------------------------------------
local function EnTete(parent, titre, description)
    local entete = vgui.Create("DPanel", parent)
    entete:Dock(TOP)
    entete:SetTall(T(56))
    entete:DockMargin(0, 0, 0, T(12))
    entete.Paint = function()
        draw.SimpleText(titre, "Cat.Titre", 0, T(4), couleurs.texte)
        draw.SimpleText(description, "Cat.Petit", 0, T(32), couleurs.texte_gris)
    end
    return entete
end

---------------------------------------------------------------------------
-- PAGE ANTI-ESP
---------------------------------------------------------------------------
local HAUTEUR_LIGNE_REGLAGE = 60

local function LigneReglage(parent, reglage)
    local ligne = vgui.Create("DPanel", parent)
    ligne:Dock(TOP)
    ligne:SetTall(T(HAUTEUR_LIGNE_REGLAGE))
    ligne:DockPadding(T(18), 0, T(18), 0)
    ligne:SetTooltip(reglage.description)

    local controle
    if reglage.type == "bool" then
        controle = Interrupteur(ligne, reglage.valeur == "1", function(actif)
            EnvoyerReglage(reglage.nom, actif and "1" or "0")
        end)
        controle:Dock(RIGHT)
    else
        controle = Champ(ligne)
        controle:Dock(RIGHT)
        controle:SetWide(reglage.type == "texte" and T(230) or T(100))
        controle:DockMargin(0, T(15), 0, T(15))
        controle:SetValue(reglage.valeur)
        if reglage.type == "nombre" then controle:SetNumeric(true) end

        controle.valeur_envoyee = reglage.valeur
        local function Valider()
            local valeur = controle:GetValue()
            if valeur == controle.valeur_envoyee then return end
            controle.valeur_envoyee = valeur
            EnvoyerReglage(reglage.nom, valeur)
        end
        controle.OnEnter = Valider
        controle.OnLoseFocus = function(s)
            vgui.GetControlTable("DTextEntry").OnLoseFocus(s)
            Valider()
        end
    end

    ligne.PerformLayout = function(s, w)
        local place = w - T(18) - controle:GetWide() - T(18) - T(24)
        s.description = Couper(reglage.description, "Cat.Texte", place)
        s.nom = Couper(reglage.nom, "Cat.CodePetit", place)
    end

    ligne.Paint = function(s, _, h)
        draw.SimpleText(s.description or "", "Cat.Texte", T(18), h / 2 - T(9), couleurs.texte, 0, 1)
        draw.SimpleText(s.nom or "", "Cat.CodePetit", T(18), h / 2 + T(11), couleurs.texte_discret, 0, 1)
    end
end

local function PageReglages(reglages)
    local page = vgui.Create("DPanel")
    page:SetPaintBackground(false)
    page:DockPadding(T(32), T(28), T(24), T(24))
    EnTete(page, "Anti-ESP", "Les modifications sont appliquées immédiatement sur le serveur.")

    local defilement = vgui.Create("DScrollPanel", page)
    defilement:Dock(FILL)
    StyliserDefilement(defilement)

    -- regroupement par section, dans l'ordre d'origine
    local sections, ordre = {}, {}
    for _, reglage in ipairs(reglages) do
        local nom = reglage.section or "Réglages"
        if not sections[nom] then
            sections[nom] = {}
            table.insert(ordre, nom)
        end
        table.insert(sections[nom], reglage)
    end

    for index, nom in ipairs(ordre) do
        local titre = defilement:Add("DLabel")
        titre:Dock(TOP)
        titre:DockMargin(T(2), index == 1 and 0 or T(22), T(10), T(8))
        titre:SetFont("Cat.Section")
        titre:SetTextColor(couleurs.texte_gris)
        titre:SetText(Majuscules(nom))
        titre:SizeToContentsY()

        local liste = sections[nom]
        local carte = defilement:Add("DPanel")
        carte:Dock(TOP)
        carte:DockMargin(0, 0, T(10), 0)
        carte:SetTall(#liste * T(HAUTEUR_LIGNE_REGLAGE))
        carte.Paint = function(_, w, h)
            PeindreCarte(_, w, h)
            surface.SetDrawColor(couleurs.element)
            for separation = 1, #liste - 1 do
                surface.DrawRect(T(18), separation * T(HAUTEUR_LIGNE_REGLAGE), w - T(36), 1)
            end
        end

        for _, reglage in ipairs(liste) do LigneReglage(carte, reglage) end
    end

    return page
end

---------------------------------------------------------------------------
-- VÉRIFICATION : liste des fichiers (seules les lignes visibles sont dessinées)
---------------------------------------------------------------------------
local HAUTEUR_FICHIER = 36

local function Colonnes(w)
    local avec_date = w >= T(620)
    local droite = w - T(18)
    local date_x = droite
    local taille_x = avec_date and (droite - T(130)) or droite
    local signal_x = taille_x - T(80) - T(170)
    return {
        fichier_x = T(38),
        fichier_largeur = signal_x - T(38) - T(16),
        signal_x = signal_x,
        signal_largeur = T(160),
        taille_x = taille_x,
        date_x = avec_date and date_x or nil,
    }
end

local function Trier()
    table.sort(fichiers_actuels, function(a, b)
        local va, vb
        if tri_colonne == "signalement" then
            va, vb = (#a.alertes > 0) and 0 or 1, (#b.alertes > 0) and 0 or 1
            if va == vb then return a.chemin < b.chemin end
        elseif tri_colonne == "taille" then va, vb = a.taille, b.taille
        elseif tri_colonne == "date" then va, vb = a.date, b.date
        else va, vb = a.chemin, b.chemin end
        if va == vb then return a.chemin < b.chemin end
        if tri_inverse then return va > vb end
        return va < vb
    end)
end

local function RemplirFichiers()
    if not IsValid(toile_fichiers) then return end
    local recherche = string.lower(filtre_texte)
    local lignes = {}
    for _, fichier in ipairs(fichiers_actuels) do
        local garder = (not signales_seulement or #fichier.alertes > 0)
            and (recherche == "" or string.find(string.lower(fichier.nom_affiche), recherche, 1, true))
        if garder then table.insert(lignes, fichier) end
    end
    toile_fichiers.lignes = lignes
    toile_fichiers:SetTall(#lignes * T(HAUTEUR_FICHIER))
    defilement_fichiers:InvalidateLayout()
end

local function DemanderFichier(fichier)
    if not IsValid(joueur_actuel) then Notifier("Le joueur n'est plus connecté.", "erreur") return end
    net.Start("Cat_LireFichier")
    net.WriteEntity(joueur_actuel)
    net.WriteString(fichier.chemin)
    net.WriteString(fichier.zone)
    net.SendToServer()
end

local function ListeFichiers(parent)
    defilement_fichiers = vgui.Create("DScrollPanel", parent)
    defilement_fichiers:Dock(FILL)
    defilement_fichiers:DockMargin(T(6), 0, T(6), T(6))
    StyliserDefilement(defilement_fichiers)

    toile_fichiers = defilement_fichiers:Add("DPanel")
    toile_fichiers:Dock(TOP)
    toile_fichiers:SetTall(0)
    toile_fichiers.lignes = {}
    toile_fichiers:SetCursor("hand")

    toile_fichiers.Paint = function(s, w)
        local hauteur = T(HAUTEUR_FICHIER)
        local col = Colonnes(w)
        if s.largeur ~= w then       -- recalcul des textes coupés si la largeur change
            s.largeur = w
            for _, fichier in ipairs(fichiers_actuels) do fichier.coupe = nil end
        end

        local premier = math.max(1, math.floor(defilement_fichiers:GetVBar():GetScroll() / hauteur) + 1)
        local dernier = math.min(#s.lignes, premier + math.ceil(defilement_fichiers:GetTall() / hauteur) + 1)
        local _, souris_y = s:CursorPos()
        local survol = s:IsHovered() and (math.floor(souris_y / hauteur) + 1) or nil

        for index = premier, dernier do
            local fichier = s.lignes[index]
            local y = (index - 1) * hauteur
            local signale = #fichier.alertes > 0
            local couleur_alerte = fichier.seulement_trop_gros and couleurs.texte_gris or couleurs.danger

            if index == survol then draw.RoundedBox(T(6), 0, y + T(2), w, hauteur - T(4), couleurs.element) end
            if signale then draw.RoundedBox(T(3), T(16), y + hauteur / 2 - T(3), T(6), T(6), couleur_alerte) end

            fichier.coupe = fichier.coupe or {
                chemin = Couper(fichier.nom_affiche, "Cat.Texte", col.fichier_largeur, true),
                alerte = Couper(table.concat(fichier.alertes, ", "), "Cat.Petit", col.signal_largeur),
            }
            draw.SimpleText(fichier.coupe.chemin, "Cat.Texte", col.fichier_x, y + hauteur / 2, signale and couleurs.texte or couleurs.texte_code, 0, 1)
            draw.SimpleText(fichier.coupe.alerte, "Cat.Petit", col.signal_x, y + hauteur / 2, couleur_alerte, 0, 1)
            draw.SimpleText(string.NiceSize(fichier.taille), "Cat.Petit", col.taille_x, y + hauteur / 2, couleurs.texte_gris, 2, 1)
            if col.date_x then
                local date = fichier.date > 0 and os.date("%d/%m/%Y %H:%M", fichier.date) or "—"
                draw.SimpleText(date, "Cat.Petit", col.date_x, y + hauteur / 2, couleurs.texte_gris, 2, 1)
            end
        end
    end

    -- double-clic pour ouvrir
    toile_fichiers.OnMousePressed = function(s, touche)
        if touche ~= MOUSE_LEFT then return end
        local _, souris_y = s:CursorPos()
        local index = math.floor(souris_y / T(HAUTEUR_FICHIER)) + 1
        local fichier = s.lignes[index]
        if not fichier then return end
        if s.dernier_clic == index and SysTime() - (s.moment_clic or 0) < 0.35 then
            s.dernier_clic = nil
            DemanderFichier(fichier)
        else
            s.dernier_clic, s.moment_clic = index, SysTime()
        end
    end
end

local function EnTeteColonnes(parent)
    local entete = vgui.Create("DPanel", parent)
    entete:Dock(TOP)
    entete:SetTall(T(34))
    entete:DockMargin(T(6), 0, T(6), 0)

    local boutons = {}
    local function Colonne(cle, titre, alignement)
        local bouton = vgui.Create("DButton", entete)
        bouton:SetText("")
        bouton.Paint = function(s, w, h)
            local actif = tri_colonne == cle
            local couleur = (actif or s:IsHovered()) and couleurs.texte or couleurs.texte_gris
            local fleche = actif and T(10) or 0
            surface.SetFont("Cat.Section")
            local largeur = surface.GetTextSize(titre)
            local x = alignement == 2 and (w - largeur - fleche) or 0
            draw.SimpleText(titre, "Cat.Section", x, h / 2, couleur, 0, 1)
            if actif then   -- petite flèche de tri
                local fx, fy, t = x + largeur + T(6), h / 2, T(3)
                surface.SetDrawColor(couleur)
                if tri_inverse then
                    surface.DrawLine(fx - t, fy - 1, fx, fy + t - 1) surface.DrawLine(fx, fy + t - 1, fx + t + 1, fy - 2)
                else
                    surface.DrawLine(fx - t, fy + 1, fx, fy - t + 1) surface.DrawLine(fx, fy - t + 1, fx + t + 1, fy + 2)
                end
            end
        end
        bouton.DoClick = function()
            if tri_colonne == cle then tri_inverse = not tri_inverse else tri_colonne, tri_inverse = cle, false end
            Trier()
            RemplirFichiers()
        end
        boutons[cle] = bouton
    end
    Colonne("chemin", "FICHIER", 0)
    Colonne("signalement", "SIGNALEMENT", 0)
    Colonne("taille", "TAILLE", 2)
    Colonne("date", "MODIFIÉ", 2)

    entete.PerformLayout = function(_, w, h)
        local col = Colonnes(w - T(6))   -- même largeur que la liste (barre de défilement)
        boutons.chemin:SetPos(col.fichier_x, 0)         boutons.chemin:SetSize(T(90), h)
        boutons.signalement:SetPos(col.signal_x, 0)     boutons.signalement:SetSize(T(110), h)
        boutons.taille:SetPos(col.taille_x - T(70), 0)  boutons.taille:SetSize(T(70), h)
        boutons.date:SetVisible(col.date_x ~= nil)
        if col.date_x then boutons.date:SetPos(col.date_x - T(90), 0) boutons.date:SetSize(T(90), h) end
    end
    entete.Paint = function(_, w, h)
        surface.SetDrawColor(couleurs.element)
        surface.DrawRect(0, h - 1, w, 1)
    end
end

---------------------------------------------------------------------------
-- VÉRIFICATION : visionneuse de fichier
---------------------------------------------------------------------------
local function DecouperLignes(contenu, colonnes)
    local rangs, suspectes, total = {}, 0, 0
    for ligne in string.gmatch(contenu .. "\n", "(.-)\n") do
        total = total + 1
        ligne = ligne:gsub("\r", ""):gsub("\t", "    ")
        local suspecte = false
        for _, mot in ipairs(mots_suspects) do
            if string.find(ligne, mot, 1, true) then suspecte = true break end
        end
        if suspecte then suspectes = suspectes + 1 end

        -- retour à la ligne automatique (police à chasse fixe)
        local position, premier = 1, true
        repeat
            local fin = position + colonnes - 1
            while fin < #ligne and fin > position and bit.band(string.byte(ligne, fin + 1), 0xC0) == 0x80 do
                fin = fin - 1    -- ne pas couper au milieu d'un caractère accentué
            end
            table.insert(rangs, { numero = premier and total or nil, texte = string.sub(ligne, position, fin), suspecte = suspecte })
            position, premier = fin + 1, false
        until position > #ligne
    end
    return rangs, suspectes, total
end

local function FermerVisionneuse()
    if not IsValid(visionneuse) then return end
    local ancienne = visionneuse
    visionneuse = nil
    ancienne:AlphaTo(0, 0.1, 0, function() if IsValid(ancienne) then ancienne:Remove() end end)
    if IsValid(colonne_joueurs) then colonne_joueurs:SetVisible(true) colonne_joueurs:GetParent():InvalidateLayout() end
    if IsValid(panneau_resultats) then
        panneau_resultats:SetVisible(true)
        panneau_resultats:SetAlpha(0)
        panneau_resultats:AlphaTo(255, 0.12, 0.05)
    end
end

local function OuvrirVisionneuse(joueur, donnees)
    if not IsValid(zone_droite) then return end
    if IsValid(visionneuse) then visionneuse:Remove() end
    if IsValid(panneau_resultats) then panneau_resultats:SetVisible(false) end
    if IsValid(colonne_joueurs) then colonne_joueurs:SetVisible(false) colonne_joueurs:GetParent():InvalidateLayout() end

    local taille_fichier
    for _, fichier in ipairs(fichiers_actuels) do
        if fichier.chemin == donnees.chemin and fichier.zone == donnees.zone then taille_fichier = fichier.taille break end
    end
    local nom_affiche = (donnees.zone == "DATA" and "data/" or "") .. donnees.chemin

    visionneuse = vgui.Create("DPanel", zone_droite)
    visionneuse:Dock(FILL)
    visionneuse.Paint = PeindreCarte
    visionneuse:SetAlpha(0)
    visionneuse:AlphaTo(255, 0.14)

    -- barre du haut : retour | chemin + informations | copier
    local barre = vgui.Create("DPanel", visionneuse)
    barre:Dock(TOP)
    barre:SetTall(T(64))
    barre:DockPadding(T(10), T(14), T(14), T(14))

    local retour = Bouton(barre, "‹  Retour", "discret")
    retour:Dock(LEFT)
    retour:SetWide(T(96))
    retour.DoClick = FermerVisionneuse

    local copier = Bouton(barre, "Copier", "secondaire")
    copier:Dock(RIGHT)
    copier:SetWide(T(88))
    copier.DoClick = function()
        SetClipboardText(donnees.contenu)
        Notifier("Contenu copié.", "succes")
    end

    barre.Paint = function(s, w, h)
        surface.SetDrawColor(couleurs.element)
        surface.DrawRect(0, h - 1, w, 1)
        surface.SetDrawColor(couleurs.element)
        surface.DrawRect(T(10) + T(96) + T(12), T(16), 1, h - T(32))   -- séparateur après « Retour »
        local x = T(10) + T(96) + T(28)
        local place = w - x - T(88) - T(14) - T(20)
        s.chemin_coupe = s.chemin_coupe or Couper(nom_affiche, "Cat.Code", place, true)
        draw.SimpleText(s.chemin_coupe, "Cat.Code", x, h / 2 - T(9), couleurs.texte, 0, 1)
        draw.SimpleText(Couper(s.infos or "", "Cat.Petit", place), "Cat.Petit", x, h / 2 + T(11), couleurs.texte_gris, 0, 1)
    end
    barre.PerformLayout = function(s) s.chemin_coupe = nil end

    -- zone de code
    local defilement = vgui.Create("DScrollPanel", visionneuse)
    defilement:Dock(FILL)
    defilement:DockMargin(1, 0, 1, T(8))
    StyliserDefilement(defilement)
    defilement.Paint = function(_, w, h)
        surface.SetDrawColor(couleurs.fond)
        surface.DrawRect(0, 0, w, h)
    end

    local toile = defilement:Add("DPanel")
    toile:Dock(TOP)

    local joueur_nom = IsValid(joueur) and joueur:Nick() or "joueur déconnecté"
    toile.PerformLayout = function(s, w)
        if w < T(100) or s.largeur == w then return end
        s.largeur = w
        surface.SetFont("Cat.Code")
        s.car_largeur, s.car_hauteur = surface.GetTextSize("M")
        local lignes_total = select(2, string.gsub(donnees.contenu, "\n", "")) + 1
        s.marge = (#tostring(lignes_total)) * s.car_largeur + T(32)
        local colonnes = math.max(20, math.floor((w - s.marge - T(16)) / s.car_largeur))
        local suspectes, total
        s.rangs, suspectes, total = DecouperLignes(donnees.contenu, colonnes)

        local infos = total .. " lignes"
        if suspectes > 0 then infos = infos .. "  ·  " .. suspectes .. " suspecte" .. (suspectes > 1 and "s" or "") end
        if taille_fichier then infos = infos .. "  ·  " .. string.NiceSize(taille_fichier) end
        barre.infos = joueur_nom .. "  ·  " .. infos
        barre.chemin_coupe = nil

        s.hauteur_rang = s.car_hauteur + T(4)
        s:SetTall(#s.rangs * s.hauteur_rang + T(16))
    end

    toile.Paint = function(s, w)
        if not s.rangs then return end
        local hauteur = s.hauteur_rang
        -- gouttière des numéros de ligne
        surface.SetDrawColor(couleurs.fond)
        surface.DrawRect(0, 0, w, s:GetTall())
        surface.SetDrawColor(couleurs.panneau)
        surface.DrawRect(0, 0, s.marge - T(12), s:GetTall())

        local debut_y = T(8)
        local premier = math.max(1, math.floor((defilement:GetVBar():GetScroll() - debut_y) / hauteur) + 1)
        local dernier = math.min(#s.rangs, premier + math.ceil(defilement:GetTall() / hauteur) + 1)

        for index = premier, dernier do
            local rang = s.rangs[index]
            local y = debut_y + (index - 1) * hauteur
            if rang.suspecte then
                surface.SetDrawColor(couleurs.danger_fond)
                surface.DrawRect(s.marge - T(12), y, w, hauteur)
                surface.SetDrawColor(couleurs.danger)
                surface.DrawRect(s.marge - T(12), y, T(2), hauteur)
            end
            if rang.numero then
                draw.SimpleText(rang.numero, "Cat.Code", s.marge - T(24), y + T(2), rang.suspecte and couleurs.danger or couleurs.texte_discret, 2)
            end
            draw.SimpleText(rang.texte, "Cat.Code", s.marge, y + T(2), rang.suspecte and couleurs.texte or couleurs.texte_code)
        end
    end
end

---------------------------------------------------------------------------
-- VÉRIFICATION : page complète
---------------------------------------------------------------------------
local function ListeJoueurs(parent, au_choix)
    local defilement = vgui.Create("DScrollPanel", parent)
    defilement:Dock(FILL)
    StyliserDefilement(defilement)

    local selection
    local humains = player.GetHumans()
    for _, joueur in ipairs(humains) do
        local ligne = defilement:Add("DButton")
        ligne:Dock(TOP)
        ligne:SetTall(T(48))
        ligne:DockMargin(0, 0, T(4), T(2))
        ligne:SetText("")
        ligne.survol = 0
        local nom = joueur:Nick()
        local identifiant = joueur:SteamID()

        ligne.Paint = function(s, w, h)
            local choisi = selection == s
            s.survol = Lisser(s.survol, (choisi or s:IsHovered()) and 1 or 0)
            if s.survol > 0.01 then draw.RoundedBox(T(6), 0, 0, w, h, ColorAlpha(couleurs.element, 255 * s.survol)) end
            if choisi then draw.RoundedBox(0, 0, T(12), T(2), h - T(24), couleurs.texte) end

            local connecte = IsValid(joueur)
            s.nom_coupe = s.nom_coupe or Couper(nom, "Cat.Texte", w - T(28))
            draw.SimpleText(s.nom_coupe, "Cat.Texte", T(14), h / 2 - T(8), connecte and couleurs.texte or couleurs.texte_discret, 0, 1)
            draw.SimpleText(connecte and identifiant or "déconnecté", "Cat.CodePetit", T(14), h / 2 + T(10), couleurs.texte_discret, 0, 1)
        end
        ligne.DoClick = function(s)
            selection = s
            au_choix(joueur)
        end
    end

    return #humains
end

local function PageVerification()
    local page = vgui.Create("DPanel")
    page:SetPaintBackground(false)
    page:DockPadding(T(32), T(28), T(24), T(24))
    EnTete(page, "Vérification des scripts", "Analyse les fichiers du dossier Garry's Mod d'un joueur.")

    local corps = vgui.Create("DPanel", page)
    corps:Dock(FILL)
    corps:SetPaintBackground(false)

    -- colonne des joueurs
    local gauche = vgui.Create("DPanel", corps)
    colonne_joueurs = gauche
    gauche:Dock(LEFT)
    gauche:SetWide(T(240))
    gauche:DockMargin(0, 0, T(16), 0)
    gauche:DockPadding(T(8), T(48), T(8), T(8))

    local joueur_choisi
    local analyser = Bouton(gauche, "Analyser", "principal")
    analyser:Dock(BOTTOM)
    analyser:SetTall(T(38))
    analyser:DockMargin(0, T(8), 0, 0)
    analyser:SetEnabled(false)
    analyser.DoClick = function()
        if not IsValid(joueur_choisi) then Notifier("Ce joueur n'est plus connecté.", "erreur") return end
        en_attente = joueur_choisi:Nick()
        net.Start("Cat_Analyser")
        net.WriteEntity(joueur_choisi)
        net.SendToServer()
    end

    local nombre = ListeJoueurs(gauche, function(joueur)
        joueur_choisi = joueur
        analyser:SetEnabled(true)
    end)

    gauche.Paint = function(_, w, h)
        PeindreCarte(_, w, h)
        draw.SimpleText("Joueurs", "Cat.TexteGras", T(20), T(24), couleurs.texte, 0, 1)
        draw.SimpleText(nombre, "Cat.Petit", w - T(20), T(24), couleurs.texte_gris, 2, 1)
    end

    -- zone de droite : résultats ou visionneuse
    zone_droite = vgui.Create("DPanel", corps)
    zone_droite:Dock(FILL)
    zone_droite:SetPaintBackground(false)

    panneau_resultats = vgui.Create("DPanel", zone_droite)
    panneau_resultats:Dock(FILL)
    panneau_resultats.Paint = PeindreCarte

    local barre = vgui.Create("DPanel", panneau_resultats)
    barre:Dock(TOP)
    barre:SetTall(T(56))
    barre:DockPadding(T(20), T(12), T(12), T(12))

    local recherche = Champ(barre, "Filtrer par nom…")
    recherche:Dock(RIGHT)
    recherche:SetWide(T(200))
    recherche:SetUpdateOnType(true)
    recherche.OnValueChange = function(_, valeur)
        filtre_texte = valeur or ""
        RemplirFichiers()
    end

    local pastille = Bouton(barre, "Signalés uniquement", "secondaire")
    pastille:Dock(RIGHT)
    pastille:SetWide(T(176))
    pastille:DockMargin(0, 0, T(8), 0)
    local dessin_pastille = pastille.Paint
    pastille.Paint = function(s, w, h)
        if signales_seulement then
            Cadre(0, 0, w, h, T(6), couleurs.texte, couleurs.element)
            draw.SimpleText(s.texte, "Cat.Texte", w / 2, h / 2, couleurs.texte, 1, 1)
        else
            dessin_pastille(s, w, h)
        end
    end
    pastille.DoClick = function()
        signales_seulement = not signales_seulement
        RemplirFichiers()
    end

    barre.Paint = function(_, w, h)
        surface.SetDrawColor(couleurs.element)
        surface.DrawRect(0, h - 1, w, 1)
        if #fichiers_actuels == 0 then
            draw.SimpleText("Résultats", "Cat.TexteGras", T(20), h / 2, couleurs.texte, 0, 1)
            return
        end
        local signales = 0
        for _, fichier in ipairs(fichiers_actuels) do if #fichier.alertes > 0 then signales = signales + 1 end end
        local nom = IsValid(joueur_actuel) and joueur_actuel:Nick() or "joueur déconnecté"
        surface.SetFont("Cat.TexteGras")
        local place = w - T(20) - T(200) - T(176) - T(40)
        local nom_coupe = Couper(nom, "Cat.TexteGras", place * 0.5)
        local largeur_nom = surface.GetTextSize(nom_coupe)
        draw.SimpleText(nom_coupe, "Cat.TexteGras", T(20), h / 2, couleurs.texte, 0, 1)
        local x = T(20) + largeur_nom + T(12)
        local total = #fichiers_actuels .. " fichiers  ·  "
        local largeur_total = draw.SimpleText(total, "Cat.Petit", x, h / 2 + T(1), couleurs.texte_gris, 0, 1)
        local texte_signales = signales .. " signalé" .. (signales > 1 and "s" or "")
        draw.SimpleText(texte_signales, "Cat.Petit", x + largeur_total, h / 2 + T(1), signales > 0 and couleurs.danger or couleurs.texte_gris, 0, 1)
    end

    EnTeteColonnes(panneau_resultats)
    ListeFichiers(panneau_resultats)

    -- état vide / attente, dessiné par-dessus la liste vide
    local dessin_liste = defilement_fichiers.Paint
    defilement_fichiers.Paint = function(s, w, h)
        if dessin_liste then dessin_liste(s, w, h) end
        if #toile_fichiers.lignes > 0 then return end
        local message
        if en_attente then
            message = "Analyse de " .. en_attente .. " en cours" .. string.rep(".", math.floor(CurTime() * 3) % 4)
        elseif #fichiers_actuels > 0 then
            message = "Aucun fichier ne correspond au filtre."
        else
            message = "Sélectionnez un joueur puis lancez une analyse."
        end
        draw.SimpleText(message, "Cat.Texte", w / 2, h / 2 - T(20), couleurs.texte_gris, 1, 1)
    end

    return page
end

---------------------------------------------------------------------------
-- CAPTURE : visionneuse d'image (grande image, fond sombre, Retour)
---------------------------------------------------------------------------
local function AfficherCapture(parent, joueur, image_data, retour)
    -- On écrit l'image dans data/ puis on la charge en matériau (seul moyen fiable
    -- d'afficher un JPEG reçu par le réseau).
    file.CreateDir("cat/tmp")
    local nom = "cat/tmp/apercu_" .. os.time() .. ".jpg"
    file.Write(nom, image_data)
    local materiau = Material("../data/" .. nom, "noclamp smooth")

    local heure = os.date("%d/%m/%Y à %H:%M:%S")
    local pseudo = IsValid(joueur) and joueur:Nick() or "joueur déconnecté"

    local vue = vgui.Create("DPanel", parent)
    vue:Dock(FILL)
    vue.Paint = PeindreCarte
    vue:SetAlpha(0)
    vue:AlphaTo(255, 0.14)

    local barre = vgui.Create("DPanel", vue)
    barre:Dock(TOP)
    barre:SetTall(T(56))
    barre:DockPadding(T(10), T(12), T(14), T(12))
    barre.Paint = function(_, w, h)
        surface.SetDrawColor(couleurs.element)
        surface.DrawRect(0, h - 1, w, 1)
        draw.SimpleText(pseudo, "Cat.TexteGras", T(10) + T(96) + T(16), h / 2 - T(9), couleurs.texte, 0, 1)
        draw.SimpleText("Capturé le " .. heure, "Cat.Petit", T(10) + T(96) + T(16), h / 2 + T(11), couleurs.texte_gris, 0, 1)
    end

    local retour_bouton = Bouton(barre, "‹  Retour", "discret")
    retour_bouton:Dock(LEFT)
    retour_bouton:SetWide(T(96))
    retour_bouton.DoClick = function()
        vue:Remove()
        if retour then retour() end
    end

    local image = vgui.Create("DPanel", vue)
    image:Dock(FILL)
    image:DockMargin(T(10), T(6), T(10), T(10))
    image.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)
        -- image centrée en gardant les proportions
        local iw, ih = materiau:Width(), materiau:Height()
        if iw <= 0 or ih <= 0 then
            draw.SimpleText("Image indisponible.", "Cat.Texte", w / 2, h / 2, couleurs.texte_gris, 1, 1)
            return
        end
        local ratio = math.min(w / iw, h / ih)
        local dw, dh = iw * ratio, ih * ratio
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(materiau)
        surface.DrawTexturedRect((w - dw) / 2, (h - dh) / 2, dw, dh)
    end

    return vue
end

local function PageCapture()
    local page = vgui.Create("DPanel")
    page:SetPaintBackground(false)
    page:DockPadding(T(32), T(28), T(24), T(24))
    EnTete(page, "Capture", "Voir ce que le joueur a à l'écran. La capture est silencieuse.")

    local corps = vgui.Create("DPanel", page)
    corps:Dock(FILL)
    corps:SetPaintBackground(false)

    local droite   -- déclaré ici pour être vu par le bouton Capturer

    -- colonne des joueurs
    local gauche = vgui.Create("DPanel", corps)
    gauche:Dock(LEFT)
    gauche:SetWide(T(240))
    gauche:DockMargin(0, 0, T(16), 0)
    gauche:DockPadding(T(8), T(48), T(8), T(8))

    local joueur_choisi
    local capturer = Bouton(gauche, "Capturer", "principal")
    capturer:Dock(BOTTOM)
    capturer:SetTall(T(38))
    capturer:DockMargin(0, T(8), 0, 0)
    capturer:SetEnabled(false)
    capturer.DoClick = function()
        if not IsValid(joueur_choisi) then Notifier("Ce joueur n'est plus connecté.", "erreur") return end
        droite.attente = true
        net.Start("Cat_Capturer")
        net.WriteEntity(joueur_choisi)
        net.SendToServer()
    end

    local nombre = ListeJoueurs(gauche, function(joueur)
        joueur_choisi = joueur
        capturer:SetEnabled(true)
    end)

    gauche.Paint = function(_, w, h)
        PeindreCarte(_, w, h)
        draw.SimpleText("Joueurs", "Cat.TexteGras", T(20), T(24), couleurs.texte, 0, 1)
        draw.SimpleText(nombre, "Cat.Petit", w - T(20), T(24), couleurs.texte_gris, 2, 1)
    end

    -- zone de droite : message d'attente puis image
    droite = vgui.Create("DPanel", corps)
    droite:Dock(FILL)
    droite.Paint = function(s, w, h)
        PeindreCarte(s, w, h)
        if s.vue then return end
        local message = s.attente and "Capture en cours..." or "Sélectionnez un joueur puis lancez une capture."
        draw.SimpleText(message, "Cat.Texte", w / 2, h / 2, couleurs.texte_gris, 1, 1)
    end

    -- appelée quand une capture arrive (posée dans une variable globale au menu)
    capture_afficher = function(joueur, image_data)
        droite.attente = false
        if IsValid(droite.vue) then droite.vue:Remove() end
        droite.vue = AfficherCapture(droite, joueur, image_data, function()
            droite.vue = nil
        end)
    end

    return page
end

---------------------------------------------------------------------------
-- LOGS : lecture seule + copier
---------------------------------------------------------------------------
local function PageLogs()
    local page = vgui.Create("DPanel")
    page:SetPaintBackground(false)
    page:DockPadding(T(32), T(28), T(24), T(24))
    EnTete(page, "Logs", "Journal des actions de cat (analyses, captures, réglages).")

    local cadre = vgui.Create("DPanel", page)
    cadre:Dock(FILL)
    cadre.Paint = PeindreCarte

    local barre = vgui.Create("DPanel", cadre)
    barre:Dock(TOP)
    barre:SetTall(T(52))
    barre:DockPadding(T(16), T(10), T(12), T(10))
    barre.Paint = function(_, w, h)
        surface.SetDrawColor(couleurs.element)
        surface.DrawRect(0, h - 1, w, 1)
        draw.SimpleText("Journal", "Cat.TexteGras", T(4), h / 2, couleurs.texte, 0, 1)
    end

    local texte = vgui.Create("DTextEntry", cadre)
    texte:Dock(FILL)
    texte:DockMargin(T(10), T(8), T(10), T(10))
    texte:SetMultiline(true)
    texte:SetFont("Cat.CodePetit")
    texte:SetEditable(false)
    texte:SetDrawLanguageID(false)
    texte.Paint = function(s, w, h)
        surface.SetDrawColor(couleurs.fond)
        surface.DrawRect(0, 0, w, h)
        s:DrawTextEntryText(couleurs.texte_code, couleurs.bordure_forte, couleurs.texte)
    end

    local copier = Bouton(barre, "Copier", "secondaire")
    copier:Dock(RIGHT)
    copier:SetWide(T(90))
    copier.DoClick = function()
        SetClipboardText(texte:GetValue() or "")
        Notifier("Logs copiés dans le presse-papier.", "succes")
    end

    local rafraichir = Bouton(barre, "Rafraîchir", "discret")
    rafraichir:Dock(RIGHT)
    rafraichir:SetWide(T(96))
    rafraichir:DockMargin(0, 0, T(8), 0)
    rafraichir.DoClick = function()
        net.Start("Cat_Logs")
        net.SendToServer()
    end

    -- posée pour recevoir les logs du serveur
    logs_afficher = function(contenu)
        if not IsValid(texte) then return end
        texte:SetText(contenu ~= "" and contenu or "Journal vide.")
    end

    -- demande initiale
    net.Start("Cat_Logs")
    net.SendToServer()

    return page
end

---------------------------------------------------------------------------
-- FENÊTRE PRINCIPALE
---------------------------------------------------------------------------
local function AfficherPage(index)
    if page_active == index then return end
    page_active = index
    for _, page in pairs(pages) do if IsValid(page) then page:SetVisible(false) end end

    if not IsValid(pages[index]) then
        pages[index] = liste_pages[index].creer()
        pages[index]:SetParent(fenetre.contenu)
        pages[index]:Dock(FILL)
    end
    pages[index]:SetVisible(true)
    pages[index]:SetAlpha(0)
    pages[index]:AlphaTo(255, 0.12)
end

local function FermerFenetre()
    if not IsValid(fenetre) then return end
    local ancienne = fenetre
    fenetre = nil
    ancienne:SetMouseInputEnabled(false)
    ancienne:SetKeyboardInputEnabled(false)
    ancienne:AlphaTo(0, 0.12, 0, function() if IsValid(ancienne) then ancienne:Remove() end end)
end

local function OuvrirFenetre(reglages)
    if IsValid(fenetre) then fenetre:Remove() end
    pages, page_active = {}, nil
    fichiers_actuels, joueur_actuel, en_attente = {}, nil, nil
    filtre_texte, signales_seulement = "", false
    capture_afficher, logs_afficher = nil, nil

    local largeur = math.min(ScrW() * 0.9, math.max(T(1280), 1100))
    local hauteur = math.min(ScrH() * 0.88, math.max(T(760), 620))

    fenetre = vgui.Create("DFrame")
    fenetre:SetSize(largeur, hauteur)
    fenetre:Center()
    fenetre:SetTitle("")
    fenetre:ShowCloseButton(false)
    fenetre:DockPadding(0, T(60), 0, 0)
    fenetre:MakePopup()
    fenetre.Paint = function(_, w, h)
        Cadre(0, 0, w, h, T(10), couleurs.bordure, couleurs.fenetre)
        DessinerLogo(T(22), T(30) - T(15), T(30))   -- logo chat
        draw.SimpleText("cat", "Cat.Logo", T(60), T(30), couleurs.texte, 0, 1)
        surface.SetDrawColor(couleurs.element)
        surface.DrawRect(1, T(60) - 1, w - 2, 1)
    end

    -- apparition
    local x, y = fenetre:GetPos()
    fenetre:SetPos(x, y + T(10))
    fenetre:SetAlpha(0)
    fenetre:MoveTo(x, y, 0.2, 0, 0.3)
    fenetre:AlphaTo(255, 0.15)

    local fermer = vgui.Create("DButton", fenetre)
    fermer:SetText("")
    fermer:SetSize(T(34), T(34))
    fermer:SetPos(largeur - T(34) - T(14), T(13))
    fermer.survol = 0
    fermer.Paint = function(s, w, h)
        s.survol = Lisser(s.survol, s:IsHovered() and 1 or 0)
        if s.survol > 0.01 then draw.RoundedBox(T(6), 0, 0, w, h, ColorAlpha(couleurs.element, 255 * s.survol)) end
        local couleur = Melanger(couleurs.texte_gris, couleurs.texte, s.survol)
        local c, r = w / 2, T(5)
        surface.SetDrawColor(couleur)
        surface.DrawLine(c - r, c - r, c + r + 1, c + r + 1)
        surface.DrawLine(c + r, c - r, c - r - 1, c + r + 1)
    end
    fermer.DoClick = FermerFenetre

    -- navigation
    local navigation = vgui.Create("DPanel", fenetre)
    navigation:Dock(LEFT)
    navigation:SetWide(T(224))
    navigation:DockPadding(T(12), T(20), T(12), T(16))
    navigation.Paint = function(_, w, h)
        surface.SetDrawColor(couleurs.element)
        surface.DrawRect(w - 1, 0, 1, h - T(10))
    end

    fenetre.contenu = vgui.Create("DPanel", fenetre)
    fenetre.contenu:Dock(FILL)
    fenetre.contenu:SetPaintBackground(false)

    liste_pages = {
        { nom = "Anti-ESP", creer = function() return PageReglages(reglages) end },
        { nom = "Vérification", creer = PageVerification },
        { nom = "Capture", creer = PageCapture },
        { nom = "Logs", creer = PageLogs },
    }

    for index, element in ipairs(liste_pages) do
        local bouton = vgui.Create("DButton", navigation)
        bouton:Dock(TOP)
        bouton:SetTall(T(40))
        bouton:DockMargin(0, 0, 0, T(4))
        bouton:SetText("")
        bouton.survol = 0
        bouton.Paint = function(s, w, h)
            local actif = page_active == index
            s.survol = Lisser(s.survol, (actif and 1) or (s:IsHovered() and 0.6) or 0)
            if s.survol > 0.01 then draw.RoundedBox(T(6), 0, 0, w, h, ColorAlpha(couleurs.element, 255 * s.survol)) end
            if actif then draw.RoundedBox(0, 0, T(11), T(2), h - T(22), couleurs.texte) end
            draw.SimpleText(element.nom, "Cat.Texte", T(16), h / 2, actif and couleurs.texte or Melanger(couleurs.texte_gris, couleurs.texte, s.survol), 0, 1)
        end
        bouton.DoClick = function() AfficherPage(index) end
    end

    AfficherPage(1)
end

---------------------------------------------------------------------------
-- RÉSEAU
---------------------------------------------------------------------------
local function AfficherListe(joueur, fichiers)
    en_attente = nil
    fichiers_actuels, joueur_actuel = fichiers or {}, joueur
    for _, fichier in ipairs(fichiers_actuels) do
        fichier.alertes = fichier.alertes or {}
        fichier.nom_affiche = (fichier.zone == "DATA" and "data/" or "") .. fichier.chemin
        fichier.seulement_trop_gros = #fichier.alertes == 1 and fichier.alertes[1] == "Trop gros, non analysé"
    end
    Trier()
    if IsValid(visionneuse) then FermerVisionneuse() end
    RemplirFichiers()
    if IsValid(defilement_fichiers) then defilement_fichiers:GetVBar():SetScroll(0) end
    if IsValid(toile_fichiers) then
        toile_fichiers:SetAlpha(0)
        toile_fichiers:AlphaTo(255, 0.15)
    end
end

net.Receive("Cat_Resultat", function()
    local id = net.ReadUInt(32)
    local joueur = net.ReadEntity()
    local numero = net.ReadUInt(16)
    local total = net.ReadUInt(16)
    local morceau = net.ReadData(net.ReadUInt(16))

    receptions[id] = receptions[id] or {}
    receptions[id][numero] = morceau
    if numero < total then return end

    local donnees = util.JSONToTable(util.Decompress(table.concat(receptions[id])) or "")
    receptions[id] = nil
    if not IsValid(fenetre) then return end
    if not donnees then
        en_attente = nil
        Notifier("Réponse illisible.", "erreur")
        return
    end

    if donnees.type == "liste" then
        AfficherListe(joueur, donnees.fichiers)
    elseif donnees.type == "lire" then
        OuvrirVisionneuse(joueur, donnees)
    end
end)

net.Receive("Cat_Message", function()
    local texte, genre = net.ReadString(), net.ReadString()
    if genre == "erreur" then en_attente = nil end
    Notifier(texte, genre)
end)

net.Receive("Cat_Capture", function()
    local joueur = net.ReadEntity()
    net.ReadString()                       -- chemin serveur (non utilisé côté client)
    local image = net.ReadData(net.ReadUInt(32))
    if capture_afficher then
        capture_afficher(joueur, image)
    else
        Notifier("Capture reçue (ouvre l'onglet Capture).", "info")
    end
end)

net.Receive("Cat_Logs", function()
    local contenu = net.ReadString()
    if logs_afficher then logs_afficher(contenu) end
end)

net.Receive("Cat_Menu", function()
    local donnees = util.JSONToTable(net.ReadString())
    if not donnees then return end
    mots_suspects = donnees.mots or {}
    OuvrirFenetre(donnees.reglages or {})
end)
