-- Chargeur de l'addon Cat
if SERVER then
    AddCSLuaFile("cat/cl_menu.lua")      -- menu (admins uniquement, vérifié côté serveur)
    AddCSLuaFile("cat/cl_fichiers.lua")  -- réponse aux demandes d'analyse

    resource.AddFile("materials/cat/logo.png")  -- logo envoyé aux clients

    include("cat/sv_config.lua")         -- JAMAIS envoyé aux joueurs
    include("cat/sv_esp.lua")
    include("cat/sv_panel.lua")
else
    include("cat/cl_menu.lua")
    include("cat/cl_fichiers.lua")
end
