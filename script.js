// ================================
// CHCG INVENTORY - CLEAN SCRIPT
// Versiune curată fără erori
// ================================

let inventory = {
    isOpen: false,
    currentType: 'player',
    playerItems: {},
    equipmentItems: {},
    secondaryItems: {},
    draggedItem: null,
    currentSlot: null
};

// ================================
// INITIALIZATION
// ================================

document.addEventListener('DOMContentLoaded', function() {
    console.log('[CHCG-INVENTORY] Starting initialization...');
    setupEventListeners();
    createInventorySlots();
    hideInventory();
    console.log('[CHCG-INVENTORY] Initialization complete!');
});

// ================================
// EVENT LISTENERS
// ================================

function setupEventListeners() {
    // ESC key to close
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && inventory.isOpen) {
            closeInventory();
        }
    });
    
    // Click outside to close
    const container = document.getElementById('inventory-container');
    if (container) {
        container.addEventListener('click', function(e) {
            if (e.target.id === 'inventory-container') {
                closeInventory();
            }
        });
    }
    
    // Hotbar clicks
    document.querySelectorAll('.hotbar-slot').forEach((slot, index) => {
        slot.addEventListener('click', () => useHotbarItem(index + 1));
    });
    
    // Quality filter
    const qualityDropdown = document.getElementById('quality-dropdown');
    if (qualityDropdown) {
        qualityDropdown.addEventListener('change', filterByQuality);
    }
    
    setupContextMenu();
    setupModalButtons();
    
    console.log('[CHCG-INVENTORY] Event listeners setup complete');
}

function setupContextMenu() {
    const contextMenu = document.getElementById('context-menu');
    
    document.addEventListener('click', () => hideContextMenu());
    
    document.querySelectorAll('.context-item').forEach(item => {
        item.addEventListener('click', function(e) {
            e.stopPropagation();
            const action = this.getAttribute('data-action');
            handleContextAction(action);
            hideContextMenu();
        });
    });
}

function setupModalButtons() {
    document.querySelectorAll('.close-modal').forEach(btn => {
        btn.addEventListener('click', function() {
            const modal = this.closest('.modal');
            if (modal) {
                hideModal(modal.id);
            }
        });
    });
    
    const confirmGiveBtn = document.getElementById('confirm-give');
    if (confirmGiveBtn) {
        confirmGiveBtn.addEventListener('click', confirmGiveItem);
    }
    
    const cancelGiveBtn = document.getElementById('cancel-give');
    if (cancelGiveBtn) {
        cancelGiveBtn.addEventListener('click', () => hideModal('give-item-modal'));
    }
    
    const confirmDropBtn = document.getElementById('confirm-drop');
    if (confirmDropBtn) {
        confirmDropBtn.addEventListener('click', confirmDropItem);
    }
    
    const cancelDropBtn = document.getElementById('cancel-drop');
    if (cancelDropBtn) {
        cancelDropBtn.addEventListener('click', () => hideModal('drop-item-modal'));
    }
}

// ================================
// INVENTORY MANAGEMENT
// ================================

function openInventory(type, data) {
    type = type || 'player';
    data = data || {};
    
    inventory.isOpen = true;
    inventory.currentType = type;
    
    const container = document.getElementById('inventory-container');
    if (container) {
        container.classList.remove('hidden');
        container.classList.add('show');
    }
    
    updateSecondaryInventory(type, data);
    
    console.log('[CHCG-INVENTORY] Inventory opened:', type);
}

function closeInventory() {
    inventory.isOpen = false;
    
    const container = document.getElementById('inventory-container');
    if (container) {
        container.classList.remove('show');
        container.classList.add('hidden');
    }
    
    hideContextMenu();
    hideAllModals();
    
    // Notify Lua
    fetch('https://chcg-inventar/closeInventory', {
        method: 'POST',
        body: JSON.stringify({})
    }).catch(() => {
        console.log('[CHCG-INVENTORY] Fetch error (normal in browser)');
    });
    
    console.log('[CHCG-INVENTORY] Inventory closed');
}

function hideInventory() {
    const container = document.getElementById('inventory-container');
    if (container) {
        container.classList.add('hidden');
        container.classList.remove('show');
    }
    inventory.isOpen = false;
}

function updateInventory(items, type) {
    items = items || {};
    type = type || 'player';
    
    if (type === 'player') {
        inventory.playerItems = items;
        renderPocketsInventory(items);
        updatePocketsStats(items);
        updateHotbar();
    } else if (type === 'equipment') {
        inventory.equipmentItems = items;
        renderEquipmentSlots(items);
    } else {
        inventory.secondaryItems = items;
        renderSecondaryInventory(items);
    }
    
    console.log('[CHCG-INVENTORY] Inventory updated:', type, Object.keys(items).length, 'items');
}

// ================================
// POCKETS INVENTORY RENDERING
// ================================

function renderPocketsInventory(items) {
    const container = document.getElementById('pockets-inventory');
    if (!container) return;
    
    const slots = container.querySelectorAll('.inventory-slot');
    
    // Clear all slots
    slots.forEach(slot => {
        slot.classList.remove('occupied');
        slot.innerHTML = '';
    });
    
    // Fill slots with items
    Object.keys(items).forEach(slotNumber => {
        const item = items[slotNumber];
        if (item && item.amount > 0) {
            const slotIndex = parseInt(slotNumber) - 1;
            if (slots[slotIndex]) {
                renderSlot(slots[slotIndex], item, slotNumber);
            }
        }
    });
}

function renderSlot(slotElement, item, slotNumber) {
    if (!slotElement || !item) return;
    
    slotElement.classList.add('occupied');
    
    const itemImage = getItemImage(item.name);
    const quality = getItemQuality(item);
    
    slotElement.innerHTML = `
        <div class="slot-item" data-quality="${quality}" draggable="true">
            <div class="slot-item-image" style="background-image: url('${itemImage}')"></div>
            <div class="slot-item-amount">${item.amount}</div>
        </div>
    `;
    
    addSlotEventListeners(slotElement, item, slotNumber);
}

// ================================
// EQUIPMENT SLOTS RENDERING
// ================================

function renderEquipmentSlots(equipmentItems) {
    const equipmentSlots = {
        'backpack': document.querySelector('[data-slot="backpack"] .slot-icon'),
        'armor': document.querySelector('[data-slot="armor"] .slot-icon'),
        'phone': document.querySelector('[data-slot="phone"] .slot-icon'),
        'parachute': document.querySelector('[data-slot="parachute"] .slot-icon'),
        'weapon1': document.querySelector('[data-slot="weapon1"] .slot-icon'),
        'weapon2': document.querySelector('[data-slot="weapon2"] .slot-icon'),
        'hotkey1': document.querySelector('[data-slot="hotkey1"] .slot-icon'),
        'hotkey2': document.querySelector('[data-slot="hotkey2"] .slot-icon'),
        'hotkey3': document.querySelector('[data-slot="hotkey3"] .slot-icon')
    };
    
    Object.keys(equipmentSlots).forEach(slotType => {
        const slotElement = equipmentSlots[slotType];
        const item = equipmentItems[slotType];
        
        if (slotElement) {
            if (item && item.amount > 0) {
                slotElement.style.backgroundImage = `url('${getItemImage(item.name)}')`;
                slotElement.parentElement.classList.add('occupied');
            } else {
                slotElement.style.backgroundImage = '';
                slotElement.parentElement.classList.remove('occupied');
            }
        }
    });
}

// ================================
// SECONDARY INVENTORY
// ================================

function updateSecondaryInventory(type, data) {
    const container = document.getElementById('secondary-container');
    const title = document.getElementById('secondary-title-text');
    const icon = document.getElementById('secondary-icon');
    const maxWeight = document.getElementById('secondary-max-weight');
    
    if (!container) return;
    
    if (type === 'player') {
        container.style.display = 'none';
        return;
    }
    
    container.style.display = 'block';
    
    switch (type) {
        case 'trunk':
            if (title) title.textContent = 'Vehicle Trunk';
            if (icon) icon.className = 'fas fa-car';
            if (maxWeight) maxWeight.textContent = Math.floor((data.maxWeight || 300000) / 1000);
            break;
        case 'glovebox':
            if (title) title.textContent = 'Glovebox';
            if (icon) icon.className = 'fas fa-archive';
            if (maxWeight) maxWeight.textContent = Math.floor((data.maxWeight || 10000) / 1000);
            break;
        case 'stash':
            if (title) title.textContent = 'Personal Stash';
            if (icon) icon.className = 'fas fa-box';
            if (maxWeight) maxWeight.textContent = Math.floor((data.maxWeight || 1000000) / 1000);
            break;
        default:
            if (title) title.textContent = 'Secondary Storage';
            if (icon) icon.className = 'fas fa-box';
            if (maxWeight) maxWeight.textContent = '300';
            break;
    }
}

function renderSecondaryInventory(items) {
    const container = document.getElementById('secondary-inventory');
    if (!container) return;
    
    const slots = container.querySelectorAll('.inventory-slot');
    
    slots.forEach(slot => {
        slot.classList.remove('occupied');
        slot.innerHTML = '';
    });
    
    Object.keys(items).forEach(slotNumber => {
        const item = items[slotNumber];
        if (item && item.amount > 0) {
            const slotIndex = parseInt(slotNumber) - 1;
            if (slots[slotIndex]) {
                renderSlot(slots[slotIndex], item, slotNumber);
            }
        }
    });
}

// ================================
// STATS AND UI UPDATES
// ================================

function updatePocketsStats(items) {
    let totalWeight = 0;
    
    Object.keys(items).forEach(slot => {
        const item = items[slot];
        if (item && item.amount > 0) {
            totalWeight += (item.weight || 0) * item.amount;
        }
    });
    
    const weightElement = document.getElementById('pockets-weight');
    if (weightElement) {
        weightElement.textContent = Math.floor(totalWeight / 1000);
    }
}

function updateHotbar() {
    const hotbarSlots = document.querySelectorAll('.hotbar-slot');
    
    hotbarSlots.forEach((slot, index) => {
        const slotNumber = index + 1;
        const item = inventory.playerItems[slotNumber];
        
        const icon = slot.querySelector('.item-icon');
        const amount = slot.querySelector('.item-amount');
        
        if (item && item.amount > 0) {
            slot.classList.add('occupied');
            if (icon) {
                icon.style.backgroundImage = `url('${getItemImage(item.name)}')`;
            }
            if (amount) {
                amount.textContent = item.amount;
                amount.style.display = 'block';
            }
        } else {
            slot.classList.remove('occupied');
            if (icon) {
                icon.style.backgroundImage = '';
            }
            if (amount) {
                amount.style.display = 'none';
            }
        }
    });
}

// ================================
// QUALITY FILTER
// ================================

function filterByQuality() {
    const qualityDropdown = document.getElementById('quality-dropdown');
    if (!qualityDropdown) return;
    
    const selectedQuality = qualityDropdown.value;
    const slots = document.querySelectorAll('#pockets-inventory .inventory-slot');
    
    slots.forEach(slot => {
        const slotItem = slot.querySelector('.slot-item');
        if (slotItem) {
            const itemQuality = slotItem.getAttribute('data-quality');
            
            if (selectedQuality === 'all' || itemQuality === selectedQuality) {
                slot.style.display = 'flex';
            } else {
                slot.style.display = 'none';
            }
        }
    });
    
    console.log('[CHCG-INVENTORY] Filtered by quality:', selectedQuality);
}

// ================================
// SLOT CREATION
// ================================

function createInventorySlots() {
    createSlotsForGrid('main-inventory', 42); // 7x6 = 42 slots
    createSlotsForGrid('secondary-inventory', 30); // 6x5 = 30 slots
    
    // Add drop listeners to all slots after creation
    setTimeout(() => {
        addDropListenersToAllSlots();
        console.log('[CHCG-INVENTORY] ✅ All drop listeners added');
    }, 100);
}

function createSlotsForGrid(gridId, slotCount) {
    const grid = document.getElementById(gridId);
    if (!grid) {
        console.error('[CHCG-INVENTORY] Grid not found:', gridId);
        return;
    }
    
    console.log('[CHCG-INVENTORY] Creating slots for:', gridId, 'count:', slotCount);
    
    grid.innerHTML = '';
    
    for (let i = 1; i <= slotCount; i++) {
        const slot = document.createElement('div');
        slot.className = 'inventory-slot';
        slot.setAttribute('data-slot', i);
        
        // Adaugă un background temporar pentru a vedea sloturile
        slot.style.cssText += `
            min-height: 60px;
            min-width: 60px;
            border: 2px solid rgba(14, 165, 233, 0.3);
            background: rgba(71, 85, 105, 0.3);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 10px;
            color: rgba(255,255,255,0.5);
        `;
        slot.textContent = i; // Arată numărul slotului
        
        // Add basic drag and drop events for testing
        slot.addEventListener('dragover', function(e) {
            e.preventDefault();
            slot.style.background = 'rgba(251, 191, 36, 0.3)';
            console.log('[CHCG-INVENTORY] Drag over slot:', i);
        });
        
        slot.addEventListener('dragleave', function() {
            slot.style.background = 'rgba(71, 85, 105, 0.3)';
        });
        
        slot.addEventListener('drop', function(e) {
            e.preventDefault();
            slot.style.background = 'rgba(71, 85, 105, 0.3)';
            console.log('[CHCG-INVENTORY] Drop on slot:', i);
            handleDrop(e, i);
        });
        
        // Click pentru debug
        slot.addEventListener('click', function() {
            console.log('[CHCG-INVENTORY] Clicked slot:', i);
            slot.style.background = 'rgba(76, 175, 80, 0.3)';
            setTimeout(() => {
                slot.style.background = 'rgba(71, 85, 105, 0.3)';
            }, 500);
        });
        
        grid.appendChild(slot);
    }
    
    console.log('[CHCG-INVENTORY] ✅ Created', slotCount, 'slots for', gridId);
    
    // Verifică dacă sloturile sunt vizibile
    setTimeout(() => {
        const slots = grid.querySelectorAll('.inventory-slot');
        console.log('[CHCG-INVENTORY] Verification - found', slots.length, 'slots in DOM');
        
        // Test vizual - colorează primul slot
        if (slots[0]) {
            slots[0].style.background = 'rgba(76, 175, 80, 0.5)';
            slots[0].textContent = '1✓';
        }
    }, 100);
}

// ================================
// MAIN INVENTORY RENDERING (7x6)
// ================================

function renderMainInventory(items) {
    const container = document.getElementById('main-inventory');
    if (!container) return;
    
    const slots = container.querySelectorAll('.inventory-slot');
    
    // Clear all slots
    slots.forEach(slot => {
        slot.classList.remove('occupied');
        slot.innerHTML = '';
    });
    
    // Fill slots with items
    Object.keys(items).forEach(slotNumber => {
        const item = items[slotNumber];
        if (item && item.amount > 0) {
            const slotIndex = parseInt(slotNumber) - 1;
            if (slots[slotIndex]) {
                renderSlot(slots[slotIndex], item, slotNumber);
            }
        }
    });
}

// ================================
// QUICKSLOTS RENDERING (SEPARATE FROM HOTBAR)
// ================================

function renderQuickSlots(quickSlotItems) {
    const quickSlots = {
        'hotkey1': document.querySelector('[data-slot="hotkey1"] .slot-icon'),
        'hotkey2': document.querySelector('[data-slot="hotkey2"] .slot-icon'),
        'hotkey3': document.querySelector('[data-slot="hotkey3"] .slot-icon'),
        'hotkey4': document.querySelector('[data-slot="hotkey4"] .slot-icon'),
        'hotkey5': document.querySelector('[data-slot="hotkey5"] .slot-icon')
    };
    
    Object.keys(quickSlots).forEach(slotType => {
        const slotElement = quickSlots[slotType];
        const item = quickSlotItems[slotType];
        
        if (slotElement) {
            if (item && item.amount > 0) {
                slotElement.style.backgroundImage = `url('${getItemImage(item.name)}')`;
                slotElement.parentElement.classList.add('occupied');
            } else {
                slotElement.style.backgroundImage = '';
                slotElement.parentElement.classList.remove('occupied');
            }
        }
    });
}

function updateInventory(items, type) {
    items = items || {};
    type = type || 'player';
    
    if (type === 'player') {
        inventory.playerItems = items;
        renderMainInventory(items);
        updateMainInventoryStats(items);
        updateHotbar(); // Bottom hotbar stays the same
    } else if (type === 'equipment') {
        inventory.equipmentItems = items;
        renderEquipmentSlots(items);
    } else if (type === 'quickslots') {
        renderQuickSlots(items);
    } else {
        inventory.secondaryItems = items;
        renderSecondaryInventory(items);
    }
    
    console.log('[CHCG-INVENTORY] Inventory updated:', type, Object.keys(items).length, 'items');
}

function updateMainInventoryStats(items) {
    let totalWeight = 0;
    let usedSlots = 0;
    
    Object.keys(items).forEach(slot => {
        const item = items[slot];
        if (item && item.amount > 0) {
            totalWeight += (item.weight || 0) * item.amount;
            usedSlots++;
        }
    });
    
    const weightElement = document.getElementById('current-weight');
    const slotsElement = document.getElementById('used-slots');
    
    if (weightElement) {
        weightElement.textContent = Math.floor(totalWeight / 1000);
    }
    if (slotsElement) {
        slotsElement.textContent = usedSlots;
    }
}

function updateSecondaryInventory(type, data) {
    const container = document.getElementById('secondary-inventory-panel');
    const title = document.getElementById('secondary-title');
    const icon = document.getElementById('secondary-icon');
    const maxWeight = document.getElementById('secondary-max-weight');
    
    if (!container) return;
    
    if (type === 'player') {
        container.style.display = 'none';
        return;
    }
    
    container.style.display = 'block';
    
    switch (type) {
        case 'trunk':
            if (title) title.textContent = 'Vehicle Trunk';
            if (icon) icon.className = 'fas fa-car';
            if (maxWeight) maxWeight.textContent = Math.floor((data.maxWeight || 300000) / 1000);
            break;
        case 'glovebox':
            if (title) title.textContent = 'Glovebox';
            if (icon) icon.className = 'fas fa-archive';
            if (maxWeight) maxWeight.textContent = Math.floor((data.maxWeight || 10000) / 1000);
            break;
        case 'stash':
            if (title) title.textContent = 'Personal Stash';
            if (icon) icon.className = 'fas fa-box';
            if (maxWeight) maxWeight.textContent = Math.floor((data.maxWeight || 1000000) / 1000);
            break;
        default:
            if (title) title.textContent = 'Secondary Storage';
            if (icon) icon.className = 'fas fa-box';
            if (maxWeight) maxWeight.textContent = '300';
            break;
    }
}

function getCurrentInventoryType(element) {
    if (element.closest('#main-inventory')) return 'player';
    if (element.closest('#secondary-inventory')) return 'secondary';
    if (element.closest('.quickslot')) return 'quickslots';
    return 'equipment';
}

// ================================
// EVENT HANDLERS
// ================================

function addSlotEventListeners(slotElement, item, slotNumber) {
    // Right click context menu
    slotElement.addEventListener('contextmenu', function(e) {
        e.preventDefault();
        showContextMenu(e, item, slotNumber);
    });
    
    // Double click to use
    slotElement.addEventListener('dblclick', function() {
        useItem(item, slotNumber);
    });
    
    // Drag events
    const slotItem = slotElement.querySelector('.slot-item');
    if (slotItem) {
        slotItem.addEventListener('dragstart', function(e) {
            handleDragStart(e, item, slotNumber);
        });
    }
}

function handleDragStart(e, item, slotNumber) {
    inventory.draggedItem = {
        item: item,
        slot: slotNumber,
        inventory: getCurrentInventoryType(e.target)
    };
    
    e.target.classList.add('dragging');
    console.log('[CHCG-INVENTORY] Drag started:', item.name, 'from slot', slotNumber);
}

function handleDrop(e, targetSlot) {
    if (!inventory.draggedItem) return;
    
    const targetInventory = getCurrentInventoryType(e.target);
    
    // Remove visual effects
    document.querySelectorAll('.dragging').forEach(el => el.classList.remove('dragging'));
    document.querySelectorAll('.drag-over').forEach(el => el.classList.remove('drag-over'));
    
    moveItem(
        inventory.draggedItem.slot,
        targetSlot,
        inventory.draggedItem.inventory,
        targetInventory
    );
    
    inventory.draggedItem = null;
}

function getCurrentInventoryType(element) {
    if (element.closest('#pockets-inventory')) return 'player';
    if (element.closest('#secondary-inventory')) return 'secondary';
    return 'equipment';
}

// ================================
// ITEM ACTIONS
// ================================

function moveItem(fromSlot, toSlot, fromInventory, toInventory) {
    console.log('[CHCG-INVENTORY] Moving item from', fromSlot, 'to', toSlot);
    
    fetch('https://chcg-inventar/moveItem', {
        method: 'POST',
        body: JSON.stringify({
            fromSlot: fromSlot,
            toSlot: toSlot,
            fromInventory: fromInventory,
            toInventory: toInventory,
            amount: 1
        })
    }).catch(() => {
        console.log('[CHCG-INVENTORY] Fetch error (normal in browser)');
    });
}

function useItem(item, slotNumber) {
    console.log('[CHCG-INVENTORY] Using item:', item.name, 'from slot', slotNumber);
    
    fetch('https://chcg-inventar/useItem', {
        method: 'POST',
        body: JSON.stringify({
            slot: slotNumber,
            item: item
        })
    }).catch(() => {
        console.log('[CHCG-INVENTORY] Fetch error (normal in browser)');
    });
}

function useHotbarItem(slotNumber) {
    const item = inventory.playerItems[slotNumber];
    if (item && item.amount > 0) {
        useItem(item, slotNumber);
        console.log('[CHCG-INVENTORY] Used hotbar item:', slotNumber);
    }
}

// ================================
// CONTEXT MENU
// ================================

function showContextMenu(e, item, slotNumber) {
    inventory.currentSlot = { item, slotNumber };
    
    const menu = document.getElementById('context-menu');
    if (menu) {
        menu.style.left = e.pageX + 'px';
        menu.style.top = e.pageY + 'px';
        menu.classList.remove('hidden');
        menu.classList.add('show');
    }
    
    console.log('[CHCG-INVENTORY] Context menu shown for:', item.name);
}

function hideContextMenu() {
    const menu = document.getElementById('context-menu');
    if (menu) {
        menu.classList.add('hidden');
        menu.classList.remove('show');
    }
}

function handleContextAction(action) {
    if (!inventory.currentSlot) return;
    
    const item = inventory.currentSlot.item;
    const slotNumber = inventory.currentSlot.slotNumber;
    
    console.log('[CHCG-INVENTORY] Context action:', action, 'for', item.name);
    
    switch (action) {
        case 'use':
            useItem(item, slotNumber);
            break;
        case 'give':
            showGiveModal(item, slotNumber);
            break;
        case 'drop':
            showDropModal(item, slotNumber);
            break;
        case 'info':
            showItemInfo(item);
            break;
    }
}

// ================================
// MODALS
// ================================

function showModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.remove('hidden');
        modal.classList.add('show');
    }
}

function hideModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.add('hidden');
        modal.classList.remove('show');
    }
}

function hideAllModals() {
    document.querySelectorAll('.modal').forEach(modal => {
        modal.classList.add('hidden');
        modal.classList.remove('show');
    });
}

function showGiveModal(item, slotNumber) {
    inventory.currentSlot = { item, slotNumber };
    
    const giveAmount = document.getElementById('give-amount');
    const playerId = document.getElementById('player-id');
    
    if (giveAmount) {
        giveAmount.max = item.amount;
        giveAmount.value = 1;
    }
    if (playerId) {
        playerId.value = '';
    }
    
    showModal('give-item-modal');
}

function showDropModal(item, slotNumber) {
    inventory.currentSlot = { item, slotNumber };
    
    const dropAmount = document.getElementById('drop-amount');
    if (dropAmount) {
        dropAmount.max = item.amount;
        dropAmount.value = item.amount;
    }
    
    showModal('drop-item-modal');
}

function showItemInfo(item) {
    const modalItemName = document.getElementById('modal-item-name');
    const modalItemDescription = document.getElementById('modal-item-description');
    const modalItemWeight = document.getElementById('modal-item-weight');
    const modalItemAmount = document.getElementById('modal-item-amount');
    const modalItemType = document.getElementById('modal-item-type');
    const modalItemImage = document.getElementById('modal-item-image');
    
    if (modalItemName) modalItemName.textContent = item.label || item.name;
    if (modalItemDescription) modalItemDescription.textContent = item.description || 'No description';
    if (modalItemWeight) modalItemWeight.textContent = item.weight || 0;
    if (modalItemAmount) modalItemAmount.textContent = item.amount || 0;
    if (modalItemType) modalItemType.textContent = item.type || 'item';
    
    if (modalItemImage) {
        modalItemImage.src = getItemImage(item.name);
        modalItemImage.alt = item.label || item.name;
    }
    
    showModal('item-info-modal');
}

function confirmGiveItem() {
    const playerIdElement = document.getElementById('player-id');
    const giveAmountElement = document.getElementById('give-amount');
    
    if (!playerIdElement || !giveAmountElement) return;
    
    const playerId = parseInt(playerIdElement.value);
    const amount = parseInt(giveAmountElement.value);
    
    if (!playerId || !amount || amount <= 0) {
        showNotification('Please fill all fields!', 'error');
        return;
    }
    
    if (amount > inventory.currentSlot.item.amount) {
        showNotification('Not enough items!', 'error');
        return;
    }
    
    fetch('https://chcg-inventar/giveItem', {
        method: 'POST',
        body: JSON.stringify({
            targetPlayer: playerId,
            slot: inventory.currentSlot.slotNumber,
            item: inventory.currentSlot.item,
            amount: amount
        })
    }).catch(() => {
        console.log('[CHCG-INVENTORY] Fetch error (normal in browser)');
    });
    
    hideModal('give-item-modal');
    console.log('[CHCG-INVENTORY] Give item:', inventory.currentSlot.item.name, 'x', amount, 'to player', playerId);
}

function confirmDropItem() {
    const dropAmountElement = document.getElementById('drop-amount');
    if (!dropAmountElement) return;
    
    const amount = parseInt(dropAmountElement.value);
    
    if (!amount || amount <= 0) {
        showNotification('Invalid amount!', 'error');
        return;
    }
    
    if (amount > inventory.currentSlot.item.amount) {
        showNotification('Not enough items!', 'error');
        return;
    }
    
    fetch('https://chcg-inventar/dropItem', {
        method: 'POST',
        body: JSON.stringify({
            slot: inventory.currentSlot.slotNumber,
            item: inventory.currentSlot.item,
            amount: amount
        })
    }).catch(() => {
        console.log('[CHCG-INVENTORY] Fetch error (normal in browser)');
    });
    
    hideModal('drop-item-modal');
    console.log('[CHCG-INVENTORY] Drop item:', inventory.currentSlot.item.name, 'x', amount);
}

// ================================
// UTILITY FUNCTIONS
// ================================

function getItemImage(itemName) {
    // Folosește imaginile locale din folderul html/images
    return `images/${itemName}.png`;
}

function getItemQuality(item) {
    if (!item.info || !item.info.quality) return 'common';
    
    const quality = item.info.quality;
    if (quality >= 90) return 'legendary';
    if (quality >= 70) return 'epic';
    if (quality >= 50) return 'rare';
    if (quality >= 30) return 'uncommon';
    return 'common';
}

function showNotification(message, type) {
    type = type || 'info';
    console.log('[CHCG-INVENTORY] Notification:', type, message);
    
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${type === 'error' ? '#ef4444' : '#4ade80'};
        color: ${type === 'error' ? '#ffffff' : '#000000'};
        padding: 12px 20px;
        border-radius: 8px;
        z-index: 5000;
        opacity: 0;
        transition: opacity 0.3s ease;
        font-family: Inter, sans-serif;
        font-weight: 600;
        font-size: 12px;
    `;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => notification.style.opacity = '1', 10);
    setTimeout(() => {
        notification.style.opacity = '0';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// ================================
// NUI MESSAGE HANDLER - ENHANCED
// ================================

window.addEventListener('message', function(event) {
    const data = event.data;
    
    console.log('[CHCG-INVENTORY] Received message:', data.action, data);
    
    switch (data.action) {
        case 'openInventory':
            openInventory(data.type, data.data);
            break;
        case 'closeInventory':
            closeInventory();
            break;
        case 'updateInventory':
            console.log('[CHCG-INVENTORY] Updating inventory with items:', data.items);
            updateInventory(data.items, data.type);
            break;
        case 'updateHotbar':
            updateHotbar();
            break;
        case 'updateStats':
            console.log('[CHCG-INVENTORY] Updating stats:', data);
            updateStatsDisplay(data);
            break;
        case 'debugFiles':
            console.log('[CHCG-INVENTORY] 🔍 Starting file debug...');
            debugImageFiles();
            break;
        default:
            console.log('[CHCG-INVENTORY] Unknown action:', data.action);
            break;
    }
});

// ================================
// ADD updateStatsDisplay FUNCTION
// ================================

function updateStatsDisplay(data) {
    if (data.weight !== undefined) {
        const weightElement = document.getElementById('current-weight');
        if (weightElement) {
            weightElement.textContent = Math.floor(data.weight / 1000);
        }
    }
    
    if (data.slots !== undefined) {
        const slotsElement = document.getElementById('used-slots');
        if (slotsElement) {
            slotsElement.textContent = data.slots;
        }
    }
    
    console.log('[CHCG-INVENTORY] Stats updated:', data);
}

// ================================
// ENHANCED UPDATE INVENTORY
// ================================

function updateInventory(items, type) {
    items = items || {};
    type = type || 'player';
    
    console.log('[CHCG-INVENTORY] updateInventory called with:', {
        type: type,
        itemCount: Object.keys(items).length,
        items: items
    });
    
    if (type === 'player') {
        inventory.playerItems = items;
        renderMainInventory(items);
        updateMainInventoryStats(items);
        updateHotbar(); // Bottom hotbar stays the same
    } else if (type === 'equipment') {
        inventory.equipmentItems = items;
        renderEquipmentSlots(items);
    } else if (type === 'quickslots') {
        renderQuickSlots(items);
    } else {
        inventory.secondaryItems = items;
        renderSecondaryInventory(items);
    }
    
    console.log('[CHCG-INVENTORY] Inventory updated successfully:', type);
}

// ================================
// ENHANCED RENDER FUNCTIONS
// ================================

function setItemImage(element, itemName) {
    // Încearcă multiple path-uri pentru imagini
    const imagePaths = [
        `images/${itemName}.png`,
        `./images/${itemName}.png`,
        `../images/${itemName}.png`,
        `nui://chcg-inventar/html/images/${itemName}.png`
    ];
    
    let currentIndex = 0;
    
    function tryNextImage() {
        if (currentIndex >= imagePaths.length) {
            // Toate path-urile au eșuat, folosește placeholder
            element.style.backgroundImage = 'linear-gradient(135deg, #0ea5e9, #06b6d4)';
            element.style.display = 'flex';
            element.style.alignItems = 'center';
            element.style.justifyContent = 'center';
            element.style.color = '#ffffff';
            element.style.fontSize = '8px';
            element.style.fontWeight = 'bold';
            element.style.textTransform = 'uppercase';
            element.textContent = itemName.replace('weapon_', '').substring(0, 3);
            console.warn('[CHCG-INVENTORY] All image paths failed for:', itemName);
            return;
        }
        
        const imagePath = imagePaths[currentIndex];
        const img = new Image();
        
        img.onload = function() {
            element.style.backgroundImage = `url('${imagePath}')`;
            element.style.backgroundSize = 'contain';
            element.style.backgroundRepeat = 'no-repeat';
            element.style.backgroundPosition = 'center';
            element.textContent = '';
            console.log('[CHCG-INVENTORY] ✅ Image loaded:', imagePath);
        };
        
        img.onerror = function() {
            console.warn('[CHCG-INVENTORY] ❌ Image failed:', imagePath);
            currentIndex++;
            tryNextImage();
        };
        
        img.src = imagePath;
    }
    
    tryNextImage();
}

function renderMainInventory(items) {
    console.log('[CHCG-INVENTORY] Rendering inventory with items:', items);
    
    const container = document.getElementById('main-inventory');
    if (!container) {
        console.error('[CHCG-INVENTORY] main-inventory container not found!');
        return;
    }
    
    const slots = container.querySelectorAll('.inventory-slot');
    console.log('[CHCG-INVENTORY] Found', slots.length, 'slots');
    
    // Clear all slots
    slots.forEach((slot, index) => {
        slot.classList.remove('occupied');
        slot.innerHTML = '';
        slot.removeAttribute('style');
        slot.setAttribute('data-slot', index + 1);
    });
    
    // Fill slots with items
    let itemsRendered = 0;
    Object.keys(items || {}).forEach(slotNumber => {
        const item = items[slotNumber];
        
        if (item && item.amount > 0) {
            const slotIndex = parseInt(slotNumber) - 1;
            
            if (slots[slotIndex]) {
                // Create slot content
                slots[slotIndex].innerHTML = `
                    <div class="slot-item" data-quality="common" draggable="true" data-slot="${slotNumber}" data-item-name="${item.name}">
                        <div class="slot-item-image"></div>
                        <div class="slot-item-amount">${item.amount}</div>
                    </div>
                `;
                
                // Set image
                const imageElement = slots[slotIndex].querySelector('.slot-item-image');
                setItemImage(imageElement, item.name);
                
                slots[slotIndex].classList.add('occupied');
                
                // Add event listeners
                addSlotEventListeners(slots[slotIndex], item, slotNumber);
                
                itemsRendered++;
                console.log('[CHCG-INVENTORY] ✅ Rendered:', item.name, 'in slot', slotNumber);
            }
        }
    });
    
    console.log('[CHCG-INVENTORY] Total items rendered:', itemsRendered);
}

// ================================
// ENHANCED addSlotEventListeners
// ================================

function addSlotEventListeners(slotElement, item, slotNumber) {
    console.log('[CHCG-INVENTORY] Adding listeners to slot:', slotNumber, 'item:', item.name);
    
    const slotItem = slotElement.querySelector('.slot-item');
    if (!slotItem) {
        console.error('[CHCG-INVENTORY] No .slot-item found in slot');
        return;
    }
    
    // DRAG START
    slotItem.addEventListener('dragstart', function(e) {
        console.log('[CHCG-INVENTORY] 🟢 DRAG START:', item.name, 'from slot', slotNumber);
        
        inventory.draggedItem = {
            item: item,
            slot: slotNumber,
            inventory: 'player'
        };
        
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', slotNumber);
        
        // Visual feedback
        slotItem.style.opacity = '0.5';
        slotItem.style.transform = 'scale(0.95)';
        
        // Add class for styling
        slotItem.classList.add('dragging');
    });
    
    // DRAG END
    slotItem.addEventListener('dragend', function(e) {
        console.log('[CHCG-INVENTORY] 🔴 DRAG END');
        
        // Reset visual
        slotItem.style.opacity = '1';
        slotItem.style.transform = 'scale(1)';
        slotItem.classList.remove('dragging');
        
        // Clean up drag over effects
        document.querySelectorAll('.drag-over').forEach(el => {
            el.classList.remove('drag-over');
        });
    });
    
    // CONTEXT MENU
    slotElement.addEventListener('contextmenu', function(e) {
        e.preventDefault();
        console.log('[CHCG-INVENTORY] 🖱️ CONTEXT MENU:', item.name);
        showContextMenu(e, item, slotNumber);
    });
    
    // DOUBLE CLICK
    slotElement.addEventListener('dblclick', function(e) {
        e.preventDefault();
        console.log('[CHCG-INVENTORY] 🖱️ DOUBLE CLICK:', item.name);
        useItem(item, slotNumber);
    });
}

// Adaugă listeners pentru toate sloturile (inclusiv goale)
function addDropListenersToAllSlots() {
    console.log('[CHCG-INVENTORY] Adding drop listeners to all slots');
    
    const allSlots = document.querySelectorAll('.inventory-slot');
    
    allSlots.forEach((slot, index) => {
        const slotNumber = index + 1;
        
        // DRAG OVER
        slot.addEventListener('dragover', function(e) {
            e.preventDefault();
            e.dataTransfer.dropEffect = 'move';
            
            if (!slot.classList.contains('drag-over')) {
                slot.classList.add('drag-over');
                console.log('[CHCG-INVENTORY] 🟡 DRAG OVER slot:', slotNumber);
            }
        });
        
        // DRAG LEAVE
        slot.addEventListener('dragleave', function(e) {
            // Only remove if not dragging over a child element
            if (!slot.contains(e.relatedTarget)) {
                slot.classList.remove('drag-over');
                console.log('[CHCG-INVENTORY] 🟠 DRAG LEAVE slot:', slotNumber);
            }
        });
        
        // DROP
        slot.addEventListener('drop', function(e) {
            e.preventDefault();
            slot.classList.remove('drag-over');
            
            console.log('[CHCG-INVENTORY] 🟢 DROP on slot:', slotNumber);
            
            if (inventory.draggedItem) {
                const fromSlot = inventory.draggedItem.slot;
                const toSlot = slotNumber;
                
                console.log('[CHCG-INVENTORY] Moving from', fromSlot, 'to', toSlot);
                
                // Call move function
                moveItem(fromSlot, toSlot, 'player', 'player');
                
                // Reset dragged item
                inventory.draggedItem = null;
            } else {
                console.warn('[CHCG-INVENTORY] No dragged item found');
            }
        });
    });
}

function moveItem(fromSlot, toSlot, fromInventory, toInventory) {
    console.log('[CHCG-INVENTORY] 📦 MOVE ITEM:', fromSlot, '=>', toSlot);
    
    const data = {
        fromSlot: parseInt(fromSlot),
        toSlot: parseInt(toSlot),
        fromInventory: fromInventory,
        toInventory: toInventory,
        amount: 1
    };
    
    console.log('[CHCG-INVENTORY] Sending move data:', data);
    
    fetch('https://chcg-inventar/moveItem', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data)
    }).then(response => {
        console.log('[CHCG-INVENTORY] ✅ Move request sent');
        return response.text();
    }).then(data => {
        console.log('[CHCG-INVENTORY] Server response:', data);
    }).catch(error => {
        console.log('[CHCG-INVENTORY] ❌ Fetch error (normal in browser):', error);
    });
}

function renderSlot(slotElement, item, slotNumber) {
    if (!slotElement || !item) {
        console.warn('[CHCG-INVENTORY] renderSlot called with invalid parameters');
        return;
    }
    
    slotElement.classList.add('occupied');
    
    const itemImage = getItemImage(item.name);
    const quality = getItemQuality(item);
    
    slotElement.innerHTML = `
        <div class="slot-item" data-quality="${quality}" draggable="true">
            <div class="slot-item-image" style="background-image: url('${itemImage}')"></div>
            <div class="slot-item-amount">${item.amount}</div>
        </div>
    `;
    
    addSlotEventListeners(slotElement, item, slotNumber);
    
    console.log('[CHCG-INVENTORY] Slot rendered:', {
        slot: slotNumber,
        item: item.name,
        amount: item.amount,
        image: itemImage
    });
}

// ================================
// TEST FUNCTIONS
// ================================

function loadTestData() {
    // Test data pentru inventarul principal (7x6)
    const testMainInventory = {
        1: { name: 'water', amount: 5, weight: 500, label: 'Water Bottle', info: { quality: 50 } },
        2: { name: 'bread', amount: 3, weight: 200, label: 'Bread', info: { quality: 30 } },
        3: { name: 'phone', amount: 1, weight: 300, label: 'Phone', info: { quality: 80 } },
        8: { name: 'money', amount: 1000, weight: 0, label: 'Cash', info: { quality: 100 } },
        12: { name: 'lockpick', amount: 2, weight: 50, label: 'Lockpick', info: { quality: 70 } },
        15: { name: 'radio', amount: 1, weight: 400, label: 'Radio', info: { quality: 60 } },
        18: { name: 'bandage', amount: 5, weight: 100, label: 'Bandage', info: { quality: 40 } },
        25: { name: 'key', amount: 3, weight: 10, label: 'Keys', info: { quality: 90 } },
        30: { name: 'cigarette', amount: 20, weight: 5, label: 'Cigarettes', info: { quality: 20 } },
        35: { name: 'lighter', amount: 1, weight: 50, label: 'Lighter', info: { quality: 60 } }
    };
    
    // Test data pentru equipment
    const testEquipment = {
        backpack: { name: 'backpack', amount: 1, weight: 1000, label: 'Tactical Backpack' },
        armor: { name: 'armor', amount: 1, weight: 2000, label: 'Body Armor' },
        phone: { name: 'phone', amount: 1, weight: 300, label: 'Smartphone' },
        parachute: { name: 'parachute', amount: 1, weight: 5000, label: 'Parachute' }
    };
    
    // Test data pentru weapon slots
    const testWeapons = {
        weapon1: { name: 'pistol', amount: 1, weight: 1200, label: 'Pistol' },
        weapon2: { name: 'rifle', amount: 1, weight: 3500, label: 'Assault Rifle' }
    };
    
    // Test data pentru quick slots (separate de hotbar)
    const testQuickSlots = {
        hotkey1: { name: 'medkit', amount: 3, weight: 200, label: 'First Aid Kit' },
        hotkey2: { name: 'energy', amount: 5, weight: 150, label: 'Energy Drink' },
        hotkey3: { name: 'repair', amount: 2, weight: 800, label: 'Repair Kit' },
        hotkey4: { name: 'flashlight', amount: 1, weight: 250, label: 'Flashlight' },
        hotkey5: { name: 'rope', amount: 1, weight: 500, label: 'Rope' }
    };
    
    updateInventory(testMainInventory, 'player');
    updateInventory(testEquipment, 'equipment');
    updateInventory(testWeapons, 'weapons');
    updateInventory(testQuickSlots, 'quickslots');
    
    console.log('[CHCG-INVENTORY] Test data loaded - Ocean Blue Theme');
}

// ================================
// GLOBAL TEST FUNCTIONS
// ================================

window.testInventory = {
    open: function() {
        openInventory('player');
    },
    close: closeInventory,
    loadTestData: loadTestData,
    openTrunk: function() {
        openInventory('trunk', { maxWeight: 300000 });
    },
    openStash: function() {
        openInventory('stash', { maxWeight: 1000000 });
    },
    filterUncommon: function() {
        const dropdown = document.getElementById('quality-dropdown');
        if (dropdown) {
            dropdown.value = 'uncommon';
            filterByQuality();
        }
    },
    filterRare: function() {
        const dropdown = document.getElementById('quality-dropdown');
        if (dropdown) {
            dropdown.value = 'rare';
            filterByQuality();
        }
    },
    showAll: function() {
        const dropdown = document.getElementById('quality-dropdown');
        if (dropdown) {
            dropdown.value = 'all';
            filterByQuality();
        }
    }
};

console.log('[CHCG-INVENTORY] Script loaded successfully!');
console.log('Test commands available: window.testInventory.open(), window.testInventory.loadTestData(), etc.');