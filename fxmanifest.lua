fx_version 'cerulean'
game 'gta5'

description 'CHCG Custom Inventory System'
version '1.0.0'
author 'CHCG Development'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}

dependencies {
    'qb-core',
    'oxmysql'
}

lua54 'yes'