# Minetest Mod: Jukebox

Par Luffy0805
Crédits : turrican
Version : 1.0.1
Licence : MIT

---

## Description

Ce mod ajoute divers éléments liés à la musique dans Minetest :

* Jukeboxes, platines et platines DJ fonctionnelles
* Consoles décoratives (classiques ou DJ) avec inventaire intégré
* Disques vinyles personnalisés
* Système de son spatial avec distance d'écoute
* Particules musicales animées
* Ejection automatique du vinyle

## Installation

1. Placez le mod dans le dossier `mods/` de Minetest
2. Activez le mod dans le monde souhaité
3. Tous les fichiers audio doivent être au format `.ogg` et **MONO**, pas *STEREO*
4. Optionnel : dépendance à `basic_materials` pour fabriquer les vinyles avec du plastique

## Ajouter un vinyle

1. Placez le fichier `.ogg` dans le dossier `sounds/` du mod (ex : `song4.ogg` — vous pouvez choisir n'importe quel nom tant qu'il est bien référencé dans le code)

2. Dans `init.lua`, ajoutez une entrée dans la table `music_discs` (environ ligne 60) :

   ```lua
   ["jukebox:vinyl4"] = {  -- ou vinyl5, vinyl6... selon le nombre
       name = "S4", -- doit être "S" suivi du numéro
       description = "Nom de l'artiste ou titre",
       file = "song4", -- n'importe quel nom
       duration = 195, -- en secondes
       color = "#FF8800", -- code couleur hexadécimal du jukebox
       texture = "s4.png" -- peut être modifié
   }
   ```

Les recettes de fabrication des vinyles sont généralement préremplies. Vous devez seulement ajouter la durée et le nom. Si vous en ajoutez un nouveau, copiez le code ci-dessus, changez le numéro du vinyle (ex : vinyl10), et ajoutez une nouvelle texture.
Dans ce cas, modifiez cette ligne (ligne 725) :

```lua
for i = 1, 7 do
    core.register_craft({
        output = "jukebox:vinyl" .. i,
        recipe = {
            {plastic, "dye:black", plastic},
            {plastic, "dye:" .. dyes[i], plastic},
            {plastic, "dye:black", plastic}
        }
    })
end
```

Changez "7" pour correspondre au nombre total de vinyles.

3. Vérifiez que la limite de textures pour les vinyles n'est pas dépassée. Le mod en inclut 7 par défaut. Si besoin, ajoutez d'autres textures et mettez le code à jour en conséquence.

4. Ajoutez la couleur du vinyle à la liste `vinyle_crafts` des recettes (ligne 722) :

```lua
local dyes = {"red", "green", "yellow", "white", "blue", "cyan", "black", "yourcolor"}
```

Insérez simplement la couleur de votre vinyle dans le bon ordre.

## Fabrication des vinyles

Chaque vinyle se fabrique avec un matériau noir + un colorant. Exemple de recette :

\[ plastique ]\[ colorant noir ]\[ plastique ]
\[ plastique ]\[ colorant blanc ]\[ plastique ]
\[ plastique ]\[ colorant noir ]\[ plastique ]

## Fonctionnement

* Clic gauche avec un vinyle pour jouer la musique
* Clic gauche à nouveau pour arrêter la musique et éjecter le vinyle
* Le son est spatialisé : seuls les joueurs proches peuvent l'entendre
* Particules musicales (note1.png à note9.png), sans teinte de couleur
* Infotexte dynamique affichant le titre, l'artiste et la durée
* Éjection automatique du disque à la fin de la musique
* Clic droit sur les consoles pour ouvrir l'inventaire intégré

## Blocs inclus

| Nom du bloc          | Fonction                              | Hauteur   |
| -------------------- | ------------------------------------- | --------- |
| jukebox\:juke-box    | Joue les vinyles                      | 1 bloc    |
| jukebox\:platine     | Version stylisée                      | 1 bloc    |
| jukebox\:platine\_dj | Platine DJ fonctionnelle              | 0.25 bloc |
| jukebox\:console     | Console décorative avec inventaire    | 1 bloc    |
| jukebox\:console\_dj | Console DJ décorative avec inventaire | 0.25 bloc |
| jukebox\:bloc\_dj    | Bloc DJ décoratif                     | 1 bloc    |

## Paramètres audio par défaut (dans init.lua, ligne 4)

```lua
particle_lifetime = 1.5, -- Durée de vie d'une particule avant disparition
fade_in_time = 0, -- Le volume diminue avec la distance
particle_spawn_interval = 0.75, -- Une particule est créée toutes les 0.75 sec
max_hear_distance = 50, -- Distance maximale d'écoute de la musique
sound_gain = 0.85, -- Volume sonore
sound_check_interval = 1.0, -- Fréquence de vérification de la distance des joueurs
```

## Remarques importantes

* Tous les fichiers audio doivent être en MONO (sinon ils ne se jouent pas)
* Utilisez Audacity pour convertir : `Pistes > Mixage > Mono`
* Pour convertir des MP3, utilisez des outils comme convertio.co — assurez-vous de sélectionner MONO dans les options
* Les textures de vinyle et de particules doivent être dans le dossier `textures/`

## Structure de dossier recommandée

```
mods/
└── jukebox/
    ├── mod.conf
    ├── LICENSE.txt
    ├── README.md
    ├── README-fr.txt
    ├── init.lua
    ├── sounds/
    │   └── songX.ogg
    ├── textures/
    │   ├── sX.png
    │   ├── note1.png ... note9.png
    │   └── jukebox_top.png, platine_top.png ...
    └── locale/
        ├── jukebox.en.tr
        └── jukebox.fr.tr
```

## Fin.
