using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

using { TutorialInventory }

TutorialInventory<public> := module
{}

player_manager_device := class(creative_device)
{
    @editable
    InventoryInputTrigger : input_trigger_device = input_trigger_device{}

    var TutorialPlayers : [player]tutorial_player = map{}

    OnBegin<override>()<suspends> : void =
    {
        tutorial_item_system.CreateItems()

        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerRemoved)

        InventoryInputTrigger.PressedEvent.Subscribe(OnInventoryTriggerPressed)

        # call on player added/spawned for existing players
        for (Player : GetPlayspace().GetPlayers())
        {
            OnPlayerAdded(Player)
        }
    }

    OnPlayerAdded<private>(Player : player) : void =
    {
        TutorialPlayer := tutorial_player{ Player := Player }
        TutorialPlayer.Inventory.SetOwner(option{TutorialPlayer})

        # load player's data
        tutorial_player_data.LoadPlayer(Player)

        if(InventoryMap := tutorial_player_data.GetInventoryMap[Player])
        {
            TutorialPlayer.Inventory.InitSlots(InventoryMap)
        }
        
        if(set TutorialPlayers[Player] = TutorialPlayer)
        {
            Print("Created tutorial player.")
        }
        else
        {
            Err("Failed to create tutorial player.")
        }

        CreateInventoryUI(TutorialPlayer)
    }

    OnPlayerRemoved<private>(Player : player) : void =
    {
        if(TutorialPlayer := TutorialPlayers[Player])
        {
            TutorialPlayer.OnPlayerRemoved.Signal()
        }

        var NewMap : [player]tutorial_player = map{}
        for(OtherPlayer -> OtherTutorialPlayer : TutorialPlayers, OtherPlayer <> Player)
        {
            logic{set NewMap[OtherPlayer] = OtherTutorialPlayer}
        }

        set TutorialPlayers = NewMap
    }

    CreateInventoryUI<private>(TutorialPlayer : tutorial_player) : void =
    {
        InventoryMenu := inventory_menu{ Owner := TutorialPlayer }
        InventoryMenu.SetupWidget()

        set TutorialPlayer.OptionalInventoryMenu = option{InventoryMenu}
    }

    OnInventoryTriggerPressed<private>(Agent : agent) : void =
    {
        if(TutorialPlayer := TutorialPlayers[Agent], InventoryMenu := TutorialPlayer.OptionalInventoryMenu?)
        {
            InventoryMenu.Open()
        }
    }
}