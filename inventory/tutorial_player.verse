using { /Verse.org/Simulation }

using { TutorialInventory }

tutorial_player<public> := class
{
    Player<public> : player
    Inventory<public> : tutorial_inventory = tutorial_inventory{}

    OnPlayerRemoved<public> : event() = event(){}

    var OptionalInventoryMenu<public> : ?inventory_menu = false
}