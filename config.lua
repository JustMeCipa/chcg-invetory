Config = {}

-- Setări generale
Config.MaxWeight = 120000 -- Greutate maximă în grame (120kg)
Config.MaxSlots = 40 -- Numărul maxim de sloturi pentru inventarul personal
Config.OpenKey = 'TAB' -- Tasta pentru deschiderea inventarului
Config.CloseOnClick = true -- Închide inventarul când dai click în afara lui
Config.Debug = true -- Activează mesajele de debug

-- Animații și efecte
Config.UseAnimations = true
Config.OpenAnimation = 'slideInUp'
Config.CloseAnimation = 'slideOutDown'
Config.ItemMoveSound = true

-- Tipuri de inventar cu configurații
Config.InventoryTypes = {
    ['player'] = {
        label = 'Inventar Personal',
        maxWeight = 120000,
        maxSlots = 40,
        icon = 'fas fa-user'
    },
    ['trunk'] = {
        label = 'Portbagaj',
        maxWeight = 500000,
        maxSlots = 50,
        icon = 'fas fa-car'
    },
    ['glovebox'] = {
        label = 'Torpedou',
        maxWeight = 10000,
        maxSlots = 10,
        icon = 'fas fa-archive'
    },
    ['stash'] = {
        label = 'Depozit Personal',
        maxWeight = 1000000,
        maxSlots = 100,
        icon = 'fas fa-box'
    },
    ['shop'] = {
        label = 'Magazin',
        maxWeight = 999999,
        maxSlots = 999,
        icon = 'fas fa-store'
    },
    ['drop'] = {
        label = 'Ground Drop',
        maxWeight = 100000,
        maxSlots = 20,
        icon = 'fas fa-map-marker-alt'
    }
}

-- Items care nu pot fi mutate din inventarul personal
Config.RestrictedItems = {
    ['id_card'] = true,
    ['driver_license'] = true,
    ['weapon_license'] = true,
    ['lawyerpass'] = true,
    ['police_stormram'] = true
}

-- Items care se pierd la moarte
Config.DropOnDeath = {
    ['money'] = false,
    ['bank'] = false,
    ['id_card'] = false,
    ['driver_license'] = false,
    ['weapon_license'] = false
}

-- Configurații pentru hotkeys
Config.Hotkeys = {
    ['inventory'] = {
        key = 'TAB',
        description = 'Deschide inventarul'
    },
    ['hotbar_1'] = {
        key = '1',
        description = 'Folosește slotul 1'
    },
    ['hotbar_2'] = {
        key = '2',
        description = 'Folosește slotul 2'
    },
    ['hotbar_3'] = {
        key = '3',
        description = 'Folosește slotul 3'
    },
    ['hotbar_4'] = {
        key = '4',
        description = 'Folosește slotul 4'
    },
    ['hotbar_5'] = {
        key = '5',
        description = 'Folosește slotul 5'
    }
}

-- Configurații pentru vehicule (portbagaj și torpedou)
Config.VehicleSettings = {
    -- Clase de vehicule și capacitățile lor
    ['compacts'] = { trunk = 200000, glovebox = 5000 },
    ['sedans'] = { trunk = 300000, glovebox = 8000 },
    ['suvs'] = { trunk = 400000, glovebox = 10000 },
    ['coupes'] = { trunk = 150000, glovebox = 5000 },
    ['muscle'] = { trunk = 250000, glovebox = 7000 },
    ['sports'] = { trunk = 180000, glovebox = 5000 },
    ['super'] = { trunk = 120000, glovebox = 3000 },
    ['motorcycles'] = { trunk = 20000, glovebox = 1000 },
    ['offroad'] = { trunk = 350000, glovebox = 12000 },
    ['industrial'] = { trunk = 800000, glovebox = 15000 },
    ['utility'] = { trunk = 600000, glovebox = 12000 },
    ['vans'] = { trunk = 700000, glovebox = 10000 },
    ['cycles'] = { trunk = 0, glovebox = 0 },
    ['boats'] = { trunk = 100000, glovebox = 5000 },
    ['helicopters'] = { trunk = 80000, glovebox = 3000 },
    ['planes'] = { trunk = 150000, glovebox = 5000 }
}

-- Configurații pentru magazinele
Config.Shops = {
    ['general'] = {
        label = 'Magazin General',
        items = {
            { name = 'water', price = 5, amount = 100 },
            { name = 'sandwich', price = 10, amount = 50 },
            { name = 'phone', price = 500, amount = 10 },
            { name = 'radio', price = 250, amount = 15 }
        }
    },
    ['hardware'] = {
        label = 'Magazin de Unelte',
        items = {
            { name = 'repairkit', price = 150, amount = 25 },
            { name = 'lockpick', price = 200, amount = 10 },
            { name = 'screwdriverset', price = 350, amount = 8 }
        }
    }
}

-- Configurații pentru drop-uri (obiecte aruncate pe jos)
Config.DropSettings = {
    MaxDropTime = 300, -- 5 minute în secunde
    MaxDropsPerArea = 10, -- Maxim 10 drop-uri într-o zonă de 50m
    CleanupInterval = 600, -- Curăță drop-urile vechi la fiecare 10 minute
    DropRadius = 2.0, -- Raza de pickup pentru drop-uri
    ShowDropText = true -- Arată text-ul pentru drop-uri
}

-- Mesaje pentru notificări
Config.Messages = {
    ['inventory_full'] = 'Nu ai destul spațiu în inventar!',
    ['item_used'] = 'Ai folosit %s',
    ['item_given'] = 'Ai dat %s bucăți de %s către %s',
    ['item_received'] = 'Ai primit %s bucăți de %s de la %s',
    ['invalid_amount'] = 'Cantitate invalidă!',
    ['item_not_exist'] = 'Acest obiect nu există!',
    ['player_not_found'] = 'Jucătorul nu a fost găsit!',
    ['too_far'] = 'Jucătorul este prea departe!',
    ['inventory_access_denied'] = 'Nu ai acces la acest inventar!',
    ['item_restricted'] = 'Acest obiect nu poate fi mutat!',
    ['weight_exceeded'] = 'Ai depășit limita de greutate!',
    ['slots_exceeded'] = 'Nu mai ai sloturi libere!'
}

-- Poziții pentru stash-urile statice
Config.Stashes = {
    ['police_evidence'] = {
        coords = vector3(441.2, -996.3, 30.7),
        maxWeight = 2000000,
        maxSlots = 200,
        job = 'police',
        label = 'Depozit Probe'
    },
    ['ems_storage'] = {
        coords = vector3(1151.4, -1529.8, 34.8),
        maxWeight = 1500000,
        maxSlots = 150,
        job = 'ambulance',
        label = 'Depozit Medical'
    }
}